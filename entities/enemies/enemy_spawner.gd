extends Node

#monster scenes
@export var watcher_scene: PackedScene
@export var listener_scene: PackedScene
@export var chaser_scene: PackedScene

#spawn config
var num_watchers: int = 4
var num_listeners: int = 4
var num_chasers: int = 4

@export var min_distance_from_player: float = 20.0

#reference to maze
var maze_world: Node3D
var map_data: Array
var width: int
var height: int
var cell_size: float = 7.0
var active_enemies: Array[Node] = []
var current_level: int = 1

func _ready():
	await get_tree().process_frame
	_find_maze_reference()

func start_spawning(data: Array, w: int, h: int, grid_size: float, level: int = 1):
	print("EnemySpawner: Received command to spawn for Level %d..." % level)
	
	map_data = data
	width = w
	height = h
	cell_size = grid_size
	current_level = level
	
	_calculate_enemy_counts_for_level(level)
	
	if not maze_world:
		maze_world = get_parent()
	
	await get_tree().create_timer(0.5).timeout
	
	_spawn_enemies_balanced()

func _calculate_enemy_counts_for_level(level: int):
	match level:
		1:
			num_watchers = 3; num_listeners = 3; num_chasers = 2
		2:
			num_watchers = 5; num_listeners = 5; num_chasers = 4
		3:
			num_watchers = 8; num_listeners = 8; num_chasers = 6
		_:
			num_watchers = 4 + (level - 1) * 2
			num_listeners = 4 + (level - 1) * 2
			num_chasers = 3 + (level - 1) * 2

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

func _spawn_enemies_balanced():
	if not maze_world or map_data.is_empty(): return
	
	var exit_pos = _find_exit_position()
	if exit_pos == Vector2i(-1, -1): return
	
	var path_points = maze_world.astar.get_id_path(Vector2i(1,1), exit_pos)
	if path_points.size() < 10: return
	
	var enemy_deck = []
	for i in range(num_watchers): enemy_deck.append("watcher")
	for i in range(num_listeners): enemy_deck.append("listener")
	for i in range(num_chasers): enemy_deck.append("chaser")
	
	enemy_deck.shuffle()
	
	var total_enemies = enemy_deck.size()
	if total_enemies == 0: return

	var start_index = int(path_points.size() * 0.15) 
	var valid_path_length = path_points.size() - start_index
	var segment_size = valid_path_length / float(total_enemies)
	
	print("EnemySpawner: Spawning %d enemies over %d segments." % [total_enemies, valid_path_length])

	for i in range(total_enemies):
		var enemy_type = enemy_deck[i]
		
		var seg_start = start_index + (i * segment_size)
		var seg_end = seg_start + segment_size
		
		var random_idx = randi_range(int(seg_start), int(seg_end))
		random_idx = clampi(random_idx, start_index, path_points.size() - 2)
		
		var grid_pos = path_points[random_idx]
		
		var attempts = 0
		var valid_spawn_found = false
		
		while attempts < 20:
			var test_pos = grid_pos
			# Search a wider area to find rooms or intersections
			test_pos.x += randi_range(-4, 4)
			test_pos.y += randi_range(-4, 4)
			
			# CRITICAL CHANGE: Added "not _is_chokepoint(test_pos)"
			if _is_valid_floor(test_pos) and _is_safe_distance_from_player(test_pos) and not _is_chokepoint(test_pos):
				
				if enemy_type == "watcher":
					var sight_info = _get_watcher_alignment(test_pos)
					if sight_info.valid:
						_spawn_watcher(test_pos, sight_info.direction, i)
						valid_spawn_found = true
						break
				else:
					_spawn_generic(test_pos, enemy_type, i) 
					valid_spawn_found = true
					break
			attempts += 1
		
		if not valid_spawn_found:
			print("EnemySpawner: Skipped enemy %d (Could not find non-chokepoint spawn)." % i)

func _spawn_watcher(grid_pos: Vector2i, direction: Vector3, index: int):
	var grid_map = maze_world.get_node("GridMap")
	var world_pos = grid_map.map_to_local(Vector3i(grid_pos.x, 0, grid_pos.y))
	world_pos.y += 1.5
	
	var enemy = _spawn_enemy_at_world(watcher_scene, world_pos, "Watcher_%d" % index)
	if enemy:
		var look_target = world_pos + direction
		enemy.look_at(look_target, Vector3.UP)
		enemy.rotation.x = 0
		enemy.rotation.z = 0

func _spawn_generic(grid_pos: Vector2i, type: String, index: int):
	var scene = listener_scene if type == "listener" else chaser_scene
	var name_prefix = "Listener" if type == "listener" else "Chaser"
	_spawn_enemy_at_grid(scene, grid_pos.x, grid_pos.y, "%s_%d" % [name_prefix, index])

func _scan_area_for_watcher_spot(center: Vector2i) -> Dictionary:
	for x in range(-2, 3):
		for y in range(-2, 3):
			var check_pos = center + Vector2i(x, y)
			if _is_valid_floor(check_pos):
				var alignment = _get_watcher_alignment(check_pos)
				if alignment.valid:
					return {"valid": true, "pos": check_pos, "direction": alignment.direction}
	return {"valid": false}

func _get_watcher_alignment(grid_pos: Vector2i) -> Dictionary:
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var world_dirs = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	
	var best_dir = Vector3.ZERO
	var max_len = 0
	
	for i in range(directions.size()):
		var dir_vec = directions[i]
		var current_len = 0
		for dist in range(1, 12): 
			var test_pos = grid_pos + (dir_vec * dist)
			if _is_valid_floor(test_pos):
				current_len += 1
			else:
				break
		
		if current_len >= 4 and current_len > max_len:
			max_len = current_len
			best_dir = world_dirs[i]
			
	if max_len >= 4:
		return {"valid": true, "direction": best_dir}
	return {"valid": false}

func _is_safe_distance_from_player(grid_pos: Vector2i) -> bool:
	var grid_map = maze_world.get_node("GridMap")
	var enemy_world_pos = grid_map.map_to_local(Vector3i(grid_pos.x, 0, grid_pos.y))
	
	var player_node = get_tree().get_first_node_in_group("player")
	var player_pos = Vector3.ZERO
	
	if player_node:
		player_pos = player_node.global_position
	else:
		player_pos = grid_map.map_to_local(Vector3i(1, 0, 1))
		
	var dist = enemy_world_pos.distance_to(player_pos)
	return dist > min_distance_from_player

func _is_valid_floor(pos: Vector2i) -> bool:
	if pos.x <= 0 or pos.x >= width - 1: return false
	if pos.y <= 0 or pos.y >= height - 1: return false
	return map_data[pos.x][pos.y] == 0

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

func _spawn_enemy_at_grid(scene, x, y, name_str):
	if not maze_world or not maze_world.has_node("GridMap"): return
	var grid_map = maze_world.get_node("GridMap")
	var world_pos = grid_map.map_to_local(Vector3i(x, 0, y))
	world_pos.y += 1.5
	_spawn_enemy_at_world(scene, world_pos, name_str)

func _spawn_enemy_at_world(scene, pos, name_str) -> Node:
	if scene == null: return null
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos
	enemy.name = name_str
	active_enemies.append(enemy)
	return enemy
func _is_chokepoint(pos: Vector2i) -> bool:
	var floor_neighbors = 0
	
	var neighbors = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	
	for n in neighbors:
		var check = pos + n
		if _is_valid_floor(check):
			floor_neighbors += 1
			
	return floor_neighbors <= 2
