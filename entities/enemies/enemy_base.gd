extends CharacterBody3D
class_name EnemyBase

#Base class for all enemies

#movement settings
@export var speed: float = 5.0
@export var gravity: float = 9.8
@export var can_move: bool = false

#navigation
@onready var nav_agent: NavigationAgent3D= $NavigationAgent3D

#state
var player: CharacterBody3D = null
var chase_target: Vector3= Vector3.ZERO
var is_chasing: bool= false

func _ready():
	EnemyManager.register_enemy(self)
	
	#connect sa alert signal
	EnemyManager.player_spotted.connect(_on_player_spotted)
	
	#get player
	player = EnemyManager.get_player()
	
	call_deferred("_setup_navigation")
	
func _setup_navigation():
	await get_tree().physics_frame
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance= 0.5
		
func _exit_tree():
	EnemyManager.unregister_enemy(self)
	if EnemyManager.player_spotted.is_connected(_on_player_spotted):
		EnemyManager.player_spotted.disconnect(_on_player_spotted)

func _physics_process(delta):
	if player == null:
		player = EnemyManager.get_player()
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if can_move and is_chasing:
		_move_toward_target(delta)
	elif can_move:
		_idle_behavior(delta)
	else:
		velocity.x = 0
		velocity.y = 0
	move_and_slide()
	
func _move_toward_target(_delta):
	if nav_agent == null or nav_agent.is_navigation_finished():
		is_chasing= false
		return
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0 #horizontal ra di mag lupad2 ang mga bro
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _idle_behavior(_delta):
	# e override ni if nay unique idle ang monster
	velocity.x = 0
	velocity.y = 0

func set_chase_target(target_pos: Vector3):
	chase_target = target_pos
	is_chasing = true
	if nav_agent:
		nav_agent.target_position = target_pos
		
func alert(player_position: Vector3):
	set_chase_target(player_position)

func _on_player_spotted(position: Vector3):
	#Response to global alert signal from EnemyManager
	alert(position)

func get_distance_to_player() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return INF

func can_see_player() -> bool:
	#check if kakita sa player override sa child classes
	return false

func can_hear_player() -> bool:
	#check if kadungog sa player ovveride sa child 
	return false
