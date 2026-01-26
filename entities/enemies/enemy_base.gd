extends CharacterBody3D
class_name EnemyBase

#movement settings
@export var speed: float = 5.0
@export var gravity: float = 9.8
@export var can_move: bool = false

#navigation
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

#state
var player: CharacterBody3D = null
var chase_target: Vector3 = Vector3.ZERO
var is_chasing: bool = false
var navigation_ready: bool = false
var chase_player_directly: bool = false

func _ready():
	EnemyManager.register_enemy(self)
	EnemyManager.player_spotted.connect(_on_player_spotted)
	player = EnemyManager.get_player()
	call_deferred("_setup_navigation")
	
func _setup_navigation():
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		navigation_ready = true
		print("%s: Navigation ready at position %v" % [name, global_position])
	else:
		printerr("%s: No NavigationAgent3D found!" % name)
		
func _exit_tree():
	EnemyManager.unregister_enemy(self)
	if EnemyManager.player_spotted.is_connected(_on_player_spotted):
		EnemyManager.player_spotted.disconnect(_on_player_spotted)

func _physics_process(delta):
	if player == null:
		player = EnemyManager.get_player()
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if not navigation_ready:
		move_and_slide()
		return
	
	if can_move and is_chasing:
		_move_toward_target(delta)
	elif can_move:
		_idle_behavior(delta)
	else:
		velocity.x = 0
		velocity.z = 0
		
	move_and_slide()
	
func _move_toward_target(_delta):
	if nav_agent == null:
		return
		
	if not is_chasing or chase_target == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
		return
	
	#only update to player's current position if we're directly chasing them
	#kung dili chase last known position like watcher info
	if chase_player_directly and player:
		nav_agent.target_position = player.global_position
	else:
		#chase the static position from alert
		nav_agent.target_position = chase_target
	
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var distance_to_next = global_position.distance_to(next_pos)
	
	if distance_to_next < 0.1:
		velocity.x = 0
		velocity.z = 0
		return
	
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _idle_behavior(_delta):
	velocity.x = 0
	velocity.z = 0

func set_chase_target(target_pos: Vector3, direct_chase: bool = false):
	if not navigation_ready:
		print("%s: Tried to chase but navigation not ready!" % name)
		return
		
	chase_target = target_pos
	is_chasing = true
	chase_player_directly = direct_chase
	
	if nav_agent:
		nav_agent.target_position = target_pos
		print("%s: Set nav target to %v (direct=%s)" % [name, target_pos, direct_chase])
		
func alert(player_position: Vector3):
	set_chase_target(player_position, false)

func _on_player_spotted(position: Vector3):
	alert(position)

func get_distance_to_player() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return INF

func can_see_player() -> bool:
	return false

func can_hear_player() -> bool:
	return false
