extends Node3D

# --- Configuration ---
@export var base_width: int = 21
@export var base_height: int = 21
@export var removal_chance: float = 0.1
@export var player_scene: PackedScene 
@export var checkpoint_scene: PackedScene
@export var checkpoints_per_level: int = 3

# --- Nodes ---
@onready var grid_map: GridMap = $GridMap
@onready var enemy_spawner = $EnemySpawner

# --- State Variables ---
var current_level: int = 1
var max_levels: int = 3
var current_width: int
var current_height: int

var map_data: Array = []
var astar: AStarGrid2D
var navigation_region: NavigationRegion3D
var player_instance: Node3D
var exit_area: Area3D

func _ready():
	# Start the game at level 1
	start_level(1)

func start_level(level_number: int):
	print("\n--- Starting Level %d ---" % level_number)
	current_level = level_number
	
	# 1. CLEANUP: Clear old map, triggers, and navigation
	cleanup_level()
	
	# 2. SETUP DIMENSIONS: Increase size slightly per level (optional)
	# Level 1 uses base size. Level 2 adds 4 tiles, etc.
	current_width = base_width + ((level_number - 1) * 4)
	current_height = base_height + ((level_number - 1) * 4)
	
	# 3. INITIALIZE DATA: Fill map with walls (1)
	map_data = []
	for x in range(current_width):
		var col = []
		for y in range(current_height):
			col.append(1)
		map_data.append(col)

	# 4. GENERATE MAZE
	randomize()
	generate_recursive_backtracker()
	add_loops()
	
	# 5. CREATE EXIT: We capture the position to place the trigger later
	var exit_coords = create_exit()
	
	# 6. RENDER VISUALS & LOGIC
	render_to_gridmap()
	setup_astar()
	setup_navigation()
	
	# 7. PLACE PLAYER
	spawn_or_reset_player()
	
	# 8. PLACE EXIT TRIGGER
	spawn_exit_trigger(exit_coords)
	
	spawn_checkpoints()
	
	# 9. SPAWN ENEMIES - Wait for navigation to be ready first
	await get_tree().create_timer(0.5).timeout
	spawn_enemies_for_level()

func spawn_enemies_for_level():
	if has_node("EnemySpawner"):
		print("MazeWorld: Spawning enemies for Level %d..." % current_level)
		# Pass current_level to the spawner so it can scale enemy counts
		$EnemySpawner.start_spawning(map_data, current_width, current_height, grid_map.cell_size.x, current_level)
	else:
		printerr("MazeWorld: No EnemySpawner found!")

func cleanup_level():
	grid_map.clear()
	
	# Clear old enemies
	if has_node("EnemySpawner"):
		$EnemySpawner.clear_enemies()

	if navigation_region:
		navigation_region.queue_free()
		navigation_region = null
		
	if exit_area:
		exit_area.queue_free()
		exit_area = null

func spawn_or_reset_player():
	if not player_scene:
		printerr("No Player Scene assigned in Inspector!")
		return

	# Start is always (1, 1) based on generation logic
	var start_x = 1
	var start_y = 1
	
	# Convert grid coords to world coords
	var world_pos = grid_map.map_to_local(Vector3i(start_x, 0, start_y))
	world_pos.y += 1.5 
	
	# If player doesn't exist, spawn them. If they do, just move them.
	if not player_instance:
		player_instance = player_scene.instantiate()
		add_child(player_instance)
	
	player_instance.global_position = world_pos
	
	# Reset rotation (optional, so they face forward)
	player_instance.rotation = Vector3.ZERO
	
	if player_instance.has_method("initialize_minimap"):
		player_instance.initialize_minimap(map_data, current_width, current_height, grid_map.cell_size.x)
		
	print("Player positioned at: ", world_pos)

func spawn_exit_trigger(grid_pos: Vector2i):
	if exit_area: exit_area.queue_free()
	
	exit_area = Area3D.new()
	exit_area.name = "LevelExitTrigger"
	add_child(exit_area)
	
	# 1. COLLISION SETUP
	# We set the "Mask" to 2. This means this Area only scans for objects on Layer 2.
	exit_area.collision_layer = 0   # The trigger itself is invisible to others
	exit_area.collision_mask = 2    # The trigger ONLY looks for Layer 2 (The Player)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	# Make it slightly smaller than the cell so it doesn't clip neighbor walls
	var size_ratio = grid_map.cell_size.x * 0.8 
	box.size = Vector3(size_ratio, 4.0, size_ratio) 
	col.shape = box
	exit_area.add_child(col)
	
	# 2. POSITIONING
	var world_pos = grid_map.map_to_local(Vector3i(grid_pos.x, 0, grid_pos.y))
	world_pos.y += 1.0
	exit_area.global_position = world_pos
	
	exit_area.body_entered.connect(_on_exit_entered)
	print("DEBUG: Exit Trigger set. Waiting for Player on Layer 2...")

func _on_exit_entered(body):
	# Ignore the GridMap explicitly if it still slips through
	if body is GridMap:
		return
		
	print("DEBUG: Something entered exit: ", body.name)
	
	# Check for group OR just assume it's player if it's on Layer 2
	if body.is_in_group("player"):
		print("DEBUG: Player detected! Loading next level...")
		exit_area.set_deferred("monitoring", false)
		call_deferred("next_level_logic")

func next_level_logic():
	print("DEBUG: Logic executing for Level transition.")
	if current_level < max_levels:
		start_level(current_level + 1)
	else:
		game_over_win()

func game_over_win():
	print("################################")
	print("   YOU BEAT ALL 3 MAZES!        ")
	print("################################")
	# Here you could get_tree().quit() or load a 'Victory' scene
	set_process(false) # Stop game logic if necessary

# --- Generation Logic (Updated to use current_width/height) ---

func create_exit() -> Vector2i:
	# Search right edge
	for y in range(current_height - 2, 0, -1):
		if map_data[current_width - 2][y] == 0:
			map_data[current_width - 1][y] = 0
			return Vector2i(current_width - 1, y)

	# Fallback: Search bottom edge
	for x in range(current_width - 2, 0, -1):
		if map_data[x][current_height - 2] == 0:
			map_data[x][current_height - 1] = 0
			return Vector2i(x, current_height - 1)
	
	return Vector2i(1, 1) # Emergency fallback (should not happen)

func generate_recursive_backtracker():	
	var current = Vector2i(1, 1)
	map_data[current.x][current.y] = 0
	
	var stack: Array[Vector2i] = []
	stack.append(current)
	
	while stack.size() > 0:
		current = stack.back()
		var neighbors = get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			var next_cell = neighbors.pick_random()
			
			var wall_to_remove = current + (next_cell - current) / 2
			map_data[wall_to_remove.x][wall_to_remove.y] = 0
			map_data[next_cell.x][next_cell.y] = 0
			
			stack.append(next_cell)
		else:
			stack.pop_back()

func get_unvisited_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var directions = [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]
	
	for dir in directions:
		var neighbor = cell + dir
		if neighbor.x > 0 and neighbor.x < current_width - 1 and neighbor.y > 0 and neighbor.y < current_height - 1:
			if map_data[neighbor.x][neighbor.y] == 1:
				list.append(neighbor)
	return list

func add_loops():
	for x in range(1, current_width - 1):
		for y in range(1, current_height - 1):
			if map_data[x][y] == 1:
				if randf() < removal_chance:
					map_data[x][y] = 0

func render_to_gridmap():
	# Note: We called grid_map.clear() in cleanup_level()
	for x in range(current_width):
		for y in range(current_height):
			if map_data[x][y] == 1:
				grid_map.set_cell_item(Vector3i(x, 3, y), 0)
			else:
				grid_map.set_cell_item(Vector3i(x, 0, y), 1)
				grid_map.set_cell_item(Vector3i(x, 10, y), 5)

func setup_astar():
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, current_width, current_height)
	astar.cell_size = Vector2(2, 2)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	for x in range(current_width):
		for y in range(current_height):
			astar.set_point_solid(Vector2i(x, y), map_data[x][y] == 1)

func setup_navigation():
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)
	
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 1.5
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	var cell_size_vector = grid_map.cell_size
	var half_size = cell_size_vector.x / 2.0
	
	for x in range(current_width):
		for z in range(current_height):
			if map_data[x][z] == 0:
				var world_pos = grid_map.map_to_local(Vector3i(x, 0, z))
				var nav_y = world_pos.y
				
				var base_idx = vertices.size()
				vertices.append(Vector3(world_pos.x - half_size, nav_y, world_pos.z - half_size))
				vertices.append(Vector3(world_pos.x + half_size, nav_y, world_pos.z - half_size))
				vertices.append(Vector3(world_pos.x + half_size, nav_y, world_pos.z + half_size))
				vertices.append(Vector3(world_pos.x - half_size, nav_y, world_pos.z + half_size))
				
				polygons.append(PackedInt32Array([base_idx, base_idx + 1, base_idx + 2, base_idx + 3]))
	
	nav_mesh.vertices = vertices
	nav_mesh.polygons = polygons
	navigation_region.navigation_mesh = nav_mesh
	
	# Bake is not needed because we manually constructed the mesh above
	print("Navigation mesh created for Level ", current_level)

func get_optimal_path(from: Vector2i, to: Vector2i) -> Array:
	if astar:
		return astar.get_id_path(from, to)
	return []

func spawn_checkpoints():
	if not checkpoint_scene: return
	
	print("Spawning Checkpoints at Fixed Locations...")

	# --- DEFINE YOUR SPOTS HERE ---
	# You can add as many as you want to this list.
	var desired_locations = [
		Vector2i(current_width / 2, current_height / 2), # 1. The Exact Center
		Vector2i(current_width - 3, 3),                 # 2. Top-Right Corner
		Vector2i(current_width - 5, current_height - 5)               # 3. Bottom-Left Corner
	]
	
	for target in desired_locations:
		# Use our new helper to find the closest valid floor to that spot
		var valid_spot = find_nearest_floor(target)
		
		# Instantiate the checkpoint
		var cp = checkpoint_scene.instantiate()
		add_child(cp)
		
		# Place it in the world
		var world_pos = grid_map.map_to_local(Vector3i(valid_spot.x, 0, valid_spot.y))
		world_pos.y += 1.0
		cp.global_position = world_pos

func find_nearest_floor(target_pos: Vector2i) -> Vector2i:
	# 1. Sanity Check: Is the target inside the map?
	if target_pos.x <= 0 or target_pos.x >= current_width - 1:
		target_pos.x = clamp(target_pos.x, 1, current_width - 2)
	if target_pos.y <= 0 or target_pos.y >= current_height - 1:
		target_pos.y = clamp(target_pos.y, 1, current_height - 2)

	# 2. Search Logic (Breadth-First Search)
	# We start at the target and spiral out until we hit a floor (0)
	var queue: Array[Vector2i] = [target_pos]
	var visited = {target_pos: true}
	var attempts = 0
	
	while queue.size() > 0 and attempts < 1000:
		var current = queue.pop_front()
		attempts += 1
		
		# If we found a floor (0), Stop! Return this spot.
		if map_data[current.x][current.y] == 0:
			return current
			
		# Otherwise, check neighbors (Up, Down, Left, Right)
		var neighbors = [
			Vector2i(0, 1), Vector2i(0, -1), 
			Vector2i(1, 0), Vector2i(-1, 0)
		]
		
		for n in neighbors:
			var next_cell = current + n
			# Keep within bounds
			if next_cell.x > 0 and next_cell.x < current_width - 1 and \
			   next_cell.y > 0 and next_cell.y < current_height - 1:
				if not visited.has(next_cell):
					visited[next_cell] = true
					queue.append(next_cell)
	
	return Vector2i(1, 1) # Fallback to start if something goes wrong
