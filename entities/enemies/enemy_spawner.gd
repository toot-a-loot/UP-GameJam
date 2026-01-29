extends Node

#monster scenes
@export var watcher_scene: PackedScene
@export var listener_scene: PackedScene
@export var chaser_scene: PackedScene

#spawn config pila kabuok
@export var num_watchers: int = 3
@export var num_listeners: int = 2
@export var num_chasers: int = 2

@export var min_distance_from_player: float = 15.0

#reference to maze
var maze_world: Node3D
var map_data: Array
var width: int
var height: int
var cell_size: float = 7.0
var active_enemies: Array[Node] = []

func _ready():
	# Wait for maze to be ready
	await get_tree().process_frame
	_find_maze_reference()

func start_spawning(data: Array, w: int, h: int, grid_size: float):
	print("EnemySpawner: Received command to spawn...")
	
	map_data = data
	width = w
	height = h
	cell_size = grid_size
	
	await get_tree().create_timer(0.5).timeout
	
	# 3. Spawn
	_spawn_all_enemies()

func clear_enemies():
	print("EnemySpawner: Clearing %d old enemies." % active_enemies.size())
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
func _find_maze_reference():
	
	# Find the MazeWorld node - adjust path based on where spawner is added
	maze_world = get_parent()
	
	# Verify it's actually the MazeWorld
	if not maze_world.has_method("get_optimal_path"):
		printerr("EnemySpawner: Parent is not MazeWorld!")
		return
	
	# Get maze data
	map_data = maze_world.map_data
	width = maze_world.width
	height = maze_world.height
	
	
	# Wait a bit more to ensure navigation is baked
	await get_tree().create_timer(0.5).timeout
	
	# Spawn enemies
	_spawn_all_enemies()

func _spawn_all_enemies():
	# Get the solution path from Start(1,1) to Exit
	# We assume 'astar' is accessible from maze_world (see Source 36)
	var exit_pos = maze_world.create_exit() # This might need adjusting if exit is already made
	var path_points = maze_world.astar.get_id_path(Vector2i(1,1), exit_pos)
	
	print("Spawner: Calculated path length: ", path_points.size())
	
	# --- 1. SPAWN CHASERS (Guardians of the Exit) ---
	# Spawn them near the end of the path (last 30% of the maze)
	for i in range(num_chasers):
		var random_index = randi_range(int(path_points.size() * 0.7), path_points.size() - 2)
		var grid_pos = path_points[random_index]
		_spawn_enemy_at_grid(chaser_scene, grid_pos.x, grid_pos.y, "Chaser")

	# --- 2. SPAWN WATCHERS (Corridor Sentries) ---
	# They should be positioned with good line of sight to corridors, not facing walls
	for i in range(num_watchers):
		var spawn_pos = _find_watcher_position(path_points)
		if spawn_pos != Vector3.ZERO:
			_spawn_enemy_at_world(watcher_scene, spawn_pos, "Watcher")
		else:
			# Fallback to random position if can't find good spot
			var pos = _get_random_floor_position_away_from_player(20.0)
			_spawn_enemy_at_world(watcher_scene, pos, "Watcher")

	# --- 3. SPAWN LISTENERS (Roamers) ---
	# Spawn in the middle section
	for i in range(num_listeners):
		var random_index = randi_range(int(path_points.size() * 0.2), int(path_points.size() * 0.6))
		# Spawn slightly off-path so they aren't instantly blocking
		var grid_pos = path_points[random_index] 
		# Add jitter
		grid_pos.x += randi_range(-2, 2)
		grid_pos.y += randi_range(-2, 2)
		
		# Validate
		if grid_pos.x > 0 and grid_pos.x < width and map_data[grid_pos.x][grid_pos.y] == 0:
			_spawn_enemy_at_grid(listener_scene, grid_pos.x, grid_pos.y, "Listener")
		else:
			# Fallback
			var pos = _get_random_floor_position_away_from_player(15.0)
			_spawn_enemy_at_world(listener_scene, pos, "Listener")

func _find_watcher_position(path_points: Array) -> Vector3:
	# Try to find a position that has good line of sight down a corridor
	var max_attempts = 50
	
	for attempt in range(max_attempts):
		# Pick a random point along the path
		var path_index = randi_range(int(path_points.size() * 0.3), int(path_points.size() * 0.8))
		var grid_pos = path_points[path_index]
		
		# Try positions near the path (within 2-4 cells)
		var offset_distance = randi_range(2, 4)
		var directions = [
			Vector2i(offset_distance, 0),
			Vector2i(-offset_distance, 0),
			Vector2i(0, offset_distance),
			Vector2i(0, -offset_distance)
		]
		
		# Shuffle directions for randomness
		directions.shuffle()
		
		for direction in directions:
			var test_pos = grid_pos + direction
			
			# Check if position is valid (floor tile and in bounds)
			if test_pos.x <= 0 or test_pos.x >= width - 1:
				continue
			if test_pos.y <= 0 or test_pos.y >= height - 1:
				continue
			if map_data[test_pos.x][test_pos.y] != 0:
				continue
			
			# Check if this position has good line of sight
			if _has_good_line_of_sight(test_pos):
				# Convert to world position
				var grid_map = maze_world.get_node("GridMap")
				var world_pos = grid_map.map_to_local(Vector3i(test_pos.x, 0, test_pos.y))
				world_pos.y += 1.5
				
				# Check distance from player
				var player_grid_pos = Vector2i(1, 1)
				var distance_from_player = Vector2(test_pos.x, test_pos.y).distance_to(Vector2(player_grid_pos.x, player_grid_pos.y))
				
				if distance_from_player * cell_size >= 20.0:
					return world_pos
	
	return Vector3.ZERO  # Failed to find good position

func _has_good_line_of_sight(grid_pos: Vector2i) -> bool:
	# Check if there's a clear corridor in at least one direction
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	for direction in directions:
		var clear_tiles = 0
		var test_pos = grid_pos
		
		# Check how many consecutive floor tiles in this direction
		for distance in range(1, 8):  # Check up to 8 tiles away
			test_pos = grid_pos + (direction * distance)
			
			if test_pos.x <= 0 or test_pos.x >= width - 1:
				break
			if test_pos.y <= 0 or test_pos.y >= height - 1:
				break
			
			if map_data[test_pos.x][test_pos.y] == 0:  # Floor tile
				clear_tiles += 1
			else:
				break
		
		# If we have at least 4 consecutive floor tiles, this is a good corridor
		if clear_tiles >= 4:
			return true
	
	return false

func _spawn_enemy_at_grid(scene, x, y, type):
	var world_pos = maze_world.grid_map.map_to_local(Vector3i(x, 0, y))
	world_pos.y += 1.5
	_spawn_enemy_at_world(scene, world_pos, type)

func _spawn_enemy_at_world(scene, pos, type):
	if scene == null:
		printerr("EnemySpawner: Scene is null for type: ", type)
		return
		
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos
	active_enemies.append(enemy)
	print("EnemySpawner: Spawned %s at %s" % [type, pos])

func _get_random_floor_position_away_from_player(min_dist: float) -> Vector3:
	var player_grid_pos = Vector2i(1, 1)  # Player always spawns at (1,1)
	var max_attempts = 100
	
	for attempt in range(max_attempts):
		# Pick random grid coordinates
		var grid_x = randi_range(1, width - 2)
		var grid_z = randi_range(1, height - 2)
		
		# Check if it's a floor tile (0 = floor, 1 = wall)
		if map_data[grid_x][grid_z] == 0:
			# Check distance from player
			var distance_from_player = Vector2(grid_x, grid_z).distance_to(Vector2(player_grid_pos.x, player_grid_pos.y))
			
			if distance_from_player * cell_size >= min_dist:
				# Convert grid to world position using GridMap's map_to_local
				var grid_map = maze_world.get_node("GridMap")
				var world_pos = grid_map.map_to_local(Vector3i(grid_x, 0, grid_z))
				world_pos.y += 1.5  # Add enemy height above floor
				
				return world_pos
	
	printerr("EnemySpawner: Failed to find valid position after %d attempts" % max_attempts)
	# Fallback to any random floor position
	return _get_random_floor_position()

func _get_random_floor_position() -> Vector3:
	var player_grid_pos = Vector2i(1, 1)  # Player always spawns at (1,1)
	var max_attempts = 100
	
	for attempt in range(max_attempts):
		# Pick random grid coordinates
		var grid_x = randi_range(1, width - 2)
		var grid_z = randi_range(1, height - 2)
		
		# Check if it's a floor tile (0 = floor, 1 = wall)
		if map_data[grid_x][grid_z] == 0:
			# Check distance from player
			var distance_from_player = Vector2(grid_x, grid_z).distance_to(Vector2(player_grid_pos.x, player_grid_pos.y))
			
			if distance_from_player * cell_size >= min_distance_from_player:
				# Convert grid to world position using GridMap's map_to_local
				var grid_map = maze_world.get_node("GridMap")
				var world_pos = grid_map.map_to_local(Vector3i(grid_x, 0, grid_z))
				world_pos.y += 1.5  # Add enemy height above floor
				
				return world_pos
	
	printerr("EnemySpawner: Failed to find valid position after %d attempts" % max_attempts)
	return Vector3.ZERO
