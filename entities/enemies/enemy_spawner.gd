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
	
	# Spawn Watchers
	for i in range(num_watchers):
		_spawn_enemy(watcher_scene, "Watcher")
	
	# Spawn Listeners
	for i in range(num_listeners):
		_spawn_enemy(listener_scene, "Listener")
	
	# Spawn Chasers with patrol points
	for i in range(num_chasers):
		var chaser = _spawn_enemy(chaser_scene, "Chaser")
		if chaser:
			_assign_patrol_points(chaser)
	
	print("Enemy spawning complete!")

func _spawn_enemy(enemy_scene: PackedScene, enemy_type: String) -> Node3D:
	if enemy_scene == null:
		printerr("EnemySpawner: No scene assigned for " + enemy_type)
		return null
	
	print("EnemySpawner: Attempting to spawn " + enemy_type)
	
	# Find a valid spawn position
	var spawn_pos = _get_random_floor_position()
	if spawn_pos == Vector3.ZERO:
		printerr("EnemySpawner: Could not find valid spawn position for " + enemy_type)
		return null
	
	# Instance the enemy
	var enemy = enemy_scene.instantiate()
	
	if enemy == null:
		printerr("EnemySpawner: Failed to instantiate " + enemy_type)
		return null
		
	# Add to parent (MazeWorld)
	get_parent().add_child(enemy)
	
	print("EnemySpawner: Enemy added to scene tree")
	
	# Set position
	enemy.global_position = spawn_pos
	
	# Random rotation
	enemy.rotation.y = randf() * TAU
	
	return enemy

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

func _assign_patrol_points(chaser: Node3D):
	if not chaser.has_method("set_patrol_points"):
		return
	
	var num_patrol_points = 4
	var patrol_points: Array[Vector3] = []
	
	# Generate multiple patrol points around the chaser's spawn
	for i in range(num_patrol_points):
		var patrol_pos = _get_random_floor_position()
		if patrol_pos != Vector3.ZERO:
			patrol_points.append(patrol_pos)
	
	if patrol_points.size() > 0:
		chaser.set_patrol_points(patrol_points)
		print("Assigned %d patrol points to Chaser" % patrol_points.size())
