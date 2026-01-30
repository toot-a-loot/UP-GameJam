extends Node

#monster scenes
@export var watcher_scene: PackedScene
@export var listener_scene: PackedScene
@export var chaser_scene: PackedScene

#spawn config - will be calculated per level
var num_watchers: int = 4
var num_listeners: int = 4
var num_chasers: int = 4

@export var min_distance_from_player: float = 15.0

#reference to maze
var maze_world: Node3D
var map_data: Array
var width: int
var height: int
var cell_size: float = 7.0
var active_enemies: Array[Node] = []
var current_level: int = 1

func _ready():
	# Wait for maze to be ready
	await get_tree().process_frame
	_find_maze_reference()

func start_spawning(data: Array, w: int, h: int, grid_size: float, level: int = 1):
	print("EnemySpawner: Received command to spawn for Level %d..." % level)
	
	map_data = data
	width = w
	height = h
	cell_size = grid_size
	current_level = level
	
	# Calculate enemy counts based on level
	_calculate_enemy_counts_for_level(level)
	
	# Find maze_world reference if we don't have it
	if not maze_world:
		maze_world = get_parent()
	
	await get_tree().create_timer(0.5).timeout
	
	# Spawn enemies
	_spawn_all_enemies()

func _calculate_enemy_counts_for_level(level: int):
	match level:
		1:
			num_watchers = 4; num_listeners = 4; num_chasers = 4
		2:
			num_watchers = 7; num_listeners = 7; num_chasers = 7
		3:
			num_watchers = 10; num_listeners = 10; num_chasers = 10
		_:
			num_watchers = 4 + (level - 1) * 3
			num_listeners = 4 + (level - 1) * 3
			num_chasers = 4 + (level - 1) * 3

func clear_enemies():
	print("EnemySpawner: Clearing %d old enemies." % active_enemies.size())
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
func _find_maze_reference():
	maze_world = get_parent()
	if not maze_world.has_method("get_optimal_path"):
		printerr("EnemySpawner: Parent is not MazeWorld!")

func _spawn_all_enemies():
	if not maze_world or map_data.is_empty(): return
	if width == 0 or height == 0: return
	
	var exit_pos = _find_exit_position()
	if exit_pos == Vector2i(-1, -1): return
		
	var path_points = maze_world.astar.get_id_path(Vector2i(1,1), exit_pos)
	
	print("EnemySpawner: Spawning %d Watchers, %d Listeners, %d Chasers" % [num_watchers, num_listeners, num_chasers])
	
	# --- 1. SPAWN CHASERS (Guardians of the Exit) ---
	# Retained Logic: Last 30% of the maze
	for i in range(num_chasers):
		var random_index = randi_range(int(path_points.size() * 0.7), path_points.size() - 2)
		random_index = clampi(random_index, 0, path_points.size() - 1)
		var grid_pos = path_points[random_index]
		_spawn_enemy_at_grid(chaser_scene, grid_pos.x, grid_pos.y, "Chaser_%d" % (i + 1))

	# --- 2. SPAWN WATCHERS (Corridor Sentries) ---
	# New Logic: Find position AND direction to look
	for i in range(num_watchers):
		var spawn_data = _find_watcher_position_and_direction(path_points)
		
		if spawn_data.has("pos"):
			var enemy = _spawn_enemy_at_world(watcher_scene, spawn_data.pos, "Watcher_%d" % (i + 1))
			if enemy:
				# IMPORTANT: Look down the corridor
				var look_target = spawn_data.pos + spawn_data.direction
				enemy.look_at(look_target, Vector3.UP)
				enemy.rotation.x = 0 # Keep upright
				enemy.rotation.z = 0
		else:
			# Fallback if no good corridor found
			var pos = _get_random_floor_position_away_from_player(20.0)
			_spawn_enemy_at_world(watcher_scene, pos, "Watcher_%d" % (i + 1))

	# --- 3. SPAWN LISTENERS (Roamers) ---
	# Retained Logic: Middle 20%-60% of path with Jitter
	for i in range(num_listeners):
		var random_index = randi_range(int(path_points.size() * 0.2), int(path_points.size() * 0.6))
		random_index = clampi(random_index, 0, path_points.size() - 1)
		var grid_pos = path_points[random_index] 
		
		# Add jitter
		grid_pos.x += randi_range(-2, 2)
		grid_pos.y += randi_range(-2, 2)
		
		if _is_valid_floor(grid_pos):
			_spawn_enemy_at_grid(listener_scene, grid_pos.x, grid_pos.y, "Listener_%d" % (i + 1))
		else:
			# Fallback
			var pos = _get_random_floor_position_away_from_player(15.0)
			_spawn_enemy_at_world(listener_scene, pos, "Listener_%d" % (i + 1))

# --- Helper to validate grid positions ---
func _is_valid_floor(pos: Vector2i) -> bool:
	if pos.x <= 0 or pos.x >= width - 1: return false
	if pos.y <= 0 or pos.y >= height - 1: return false
	return map_data[pos.x][pos.y] == 0

# --- NEW: Smart Watcher Placement Logic ---
func _find_watcher_position_and_direction(path_points: Array) -> Dictionary:
	var max_attempts = 30
	
	for attempt in range(max_attempts):
		# Pick random spot near path (using 30% to 80% range from original)
		var path_idx = randi_range(int(path_points.size() * 0.3), int(path_points.size() * 0.8))
		path_idx = clampi(path_idx, 0, path_points.size() - 1)
		var grid_pos = path_points[path_idx]
		
		# Jitter nearby to find corners/halls
		grid_pos.x += randi_range(-3, 3)
		grid_pos.y += randi_range(-3, 3)
		
		if not _is_valid_floor(grid_pos): continue
		
		# Check which way creates the longest sightline
		var best_dir = _get_longest_sight_direction(grid_pos)
		
		if best_dir != Vector3.ZERO:
			# We found a good spot!
			var grid_map = maze_world.get_node("GridMap")
			var world_pos = grid_map.map_to_local(Vector3i(grid_pos.x, 0, grid_pos.y))
			world_pos.y += 1.5
			return {"pos": world_pos, "direction": best_dir}
			
	return {}

func _get_longest_sight_direction(grid_pos: Vector2i) -> Vector3:
	var directions = {
		Vector2i(1, 0): Vector3.RIGHT,
		Vector2i(-1, 0): Vector3.LEFT,
		Vector2i(0, 1): Vector3.BACK,
		Vector2i(0, -1): Vector3.FORWARD
	}
	
	var best_dir = Vector3.ZERO
	var max_len = 0
	
	for dir_vec in directions:
		var current_len = 0
		# Look up to 10 tiles away to see if it's a "Corridor"
		for dist in range(1, 10): 
			var test_pos = grid_pos + (dir_vec * dist)
			if _is_valid_floor(test_pos):
				current_len += 1
			else:
				break
		
		# Requirement: At least 4 tiles of visibility to matter
		if current_len >= 4 and current_len > max_len:
			max_len = current_len
			best_dir = directions[dir_vec]
			
	return best_dir

func _find_exit_position() -> Vector2i:
	for y in range(height - 1, 0, -1):
		if map_data[width - 1][y] == 0: return Vector2i(width - 1, y)
	for x in range(width - 1, 0, -1):
		if map_data[x][height - 1] == 0: return Vector2i(x, height - 1)
	for x in range(1, width):
		if map_data[x][0] == 0: return Vector2i(x, 0)
	for y in range(1, height):
		if map_data[0][y] == 0: return Vector2i(0, y)
	return Vector2i(-1, -1)

func _spawn_enemy_at_grid(scene, x, y, type):
	if not maze_world or not maze_world.has_node("GridMap"): return
	var grid_map = maze_world.get_node("GridMap")
	var world_pos = grid_map.map_to_local(Vector3i(x, 0, y))
	world_pos.y += 1.5
	_spawn_enemy_at_world(scene, world_pos, type)

func _spawn_enemy_at_world(scene, pos, type) -> Node:
	if scene == null: return null
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos
	active_enemies.append(enemy)
	print("EnemySpawner: Spawned %s at %s" % [type, pos])
	return enemy

func _get_random_floor_position_away_from_player(min_dist: float) -> Vector3:
	var player_grid_pos = Vector2i(1, 1)
	var max_attempts = 100
	
	for attempt in range(max_attempts):
		var grid_x = randi_range(1, width - 2)
		var grid_z = randi_range(1, height - 2)
		
		if map_data[grid_x][grid_z] == 0:
			var distance_from_player = Vector2(grid_x, grid_z).distance_to(Vector2(player_grid_pos.x, player_grid_pos.y))
			if distance_from_player * cell_size >= min_dist:
				var grid_map = maze_world.get_node("GridMap")
				var world_pos = grid_map.map_to_local(Vector3i(grid_x, 0, grid_z))
				world_pos.y += 1.5 
				return world_pos
	
	return _get_random_floor_position()

func _get_random_floor_position() -> Vector3:
	var player_grid_pos = Vector2i(1, 1)
	var max_attempts = 100
	for attempt in range(max_attempts):
		var grid_x = randi_range(1, width - 2)
		var grid_z = randi_range(1, height - 2)
		if map_data[grid_x][grid_z] == 0:
			var distance_from_player = Vector2(grid_x, grid_z).distance_to(Vector2(player_grid_pos.x, player_grid_pos.y))
			if distance_from_player * cell_size >= min_distance_from_player:
				var grid_map = maze_world.get_node("GridMap")
				var world_pos = grid_map.map_to_local(Vector3i(grid_x, 0, grid_z))
				world_pos.y += 1.5
				return world_pos
	return Vector3.ZERO
