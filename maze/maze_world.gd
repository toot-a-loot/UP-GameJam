extends Node3D

# Configuration
@export var width: int = 21
@export var height: int = 21
@export var removal_chance: float = 0.1

# --- NEW: Assign your player.tscn here in the Inspector ---
@export var player_scene: PackedScene 

@onready var grid_map: GridMap = $GridMap

var map_data: Array = []
var astar: AStarGrid2D
var navigation_region: NavigationRegion3D

func _ready():
	# Initialize map with all walls
	for x in range(width):
		var col = []
		for y in range(height):
			col.append(1)
		map_data.append(col)

	# Generate maze	
	randomize()
	generate_recursive_backtracker()
	
	# Add loops (multiple paths)
	add_loops()
	
	# --- NEW: Carve an exit in the outer wall ---
	create_exit()
	
	# Render to 3D
	render_to_gridmap()
	
	# Setup A* for optimal path
	setup_astar()
	
	# Setup navigation for monsters
	setup_navigation()
	
	# --- NEW: Spawn the player AFTER the maze exists ---
	spawn_player()

func spawn_player():
	if not player_scene:
		printerr("No Player Scene assigned in Inspector!")
		return

	# We know (1, 1) is always the starting floor based on your generator logic
	var start_x = 1
	var start_y = 1
	
	# 1. Instance the player
	var player = player_scene.instantiate()
	add_child(player)
	
	# 2. Get the real world position of the grid cell (1, 1)
	var world_pos = grid_map.map_to_local(Vector3i(start_x, 0, start_y))
	
	# 3. Apply position with a slight Y offset
	world_pos.y += 1.5 
	
	player.global_position = world_pos
	
	print("Player spawned at: ", world_pos)
	
	# Initialize minimap if the player script supports it
	if player.has_method("initialize_minimap"):
		player.initialize_minimap(map_data, width, height)

func create_exit():
	# Search the bottom/right edges for a valid floor tile to connect to.
	# Try to find a floor on the far right column (width - 2)
	for y in range(height - 2, 0, -1):
		if map_data[width - 2][y] == 0:
			map_data[width - 1][y] = 0 # Knock down the rightmost wall
			print("Exit created at: ", Vector2i(width - 1, y))
			return

	# Fallback: Try to find a floor on the bottom row (height - 2)
	for x in range(width - 2, 0, -1):
		if map_data[x][height - 2] == 0:
			map_data[x][height - 1] = 0 # Knock down the bottom wall
			print("Exit created at: ", Vector2i(x, height - 1))
			return

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
			
			# Remove wall between current and next
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
		if neighbor.x > 0 and neighbor.x < width - 1 and neighbor.y > 0 and neighbor.y < height - 1:
			if map_data[neighbor.x][neighbor.y] == 1:
				list.append(neighbor)
	return list

func add_loops():
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if map_data[x][y] == 1:
				if randf() < removal_chance:
					map_data[x][y] = 0

func render_to_gridmap():
	grid_map.clear()
	for x in range(width):
		for y in range(height):
			if map_data[x][y] == 1:
				grid_map.set_cell_item(Vector3i(x, 0 , y), 0)
			else:
				grid_map.set_cell_item(Vector3i(x, 0, y), 1)

func setup_astar():
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(2, 2)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	for x in range(width):
		for y in range(height):
			astar.set_point_solid(Vector2i(x, y), map_data[x][y] == 1)

func get_optimal_path(start: Vector2i, end: Vector2i) -> PackedVector2Array:
	return astar.get_id_path(start, end)

func setup_navigation():
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)
	
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.5
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	var cell_size_vector = grid_map.cell_size
	var half_size = cell_size_vector.x / 2.0
	
	for x in range(width):
		for z in range(height):
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
	
	print("Navigation mesh created with %d polygons" % polygons.size())
