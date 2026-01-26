extends CharacterBody3D
class_name EnemyBase

#Base class for all enemies

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

func _ready():
	EnemyManager.register_enemy(self)
	
	#connect sa alert signal
	EnemyManager.player_spotted.connect(_on_player_spotted)
	
	#get player
	player = EnemyManager.get_player()
	
	call_deferred("_setup_navigation")
	
func _setup_navigation():
	await get_tree().physics_frame
	await get_tree().physics_frame  #wait 2 ka frames para ready tanan
	
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
	
	# Only move if navigation is ready
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
		
	# Check if we have a valid target
	if not is_chasing or chase_target == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
		return
	
	# Update target position every frame while chasing player
	if player and is_chasing:
		nav_agent.target_position = player.global_position
	
	
	# Check if we have a valid path
	if nav_agent.is_navigation_finished():
		if int(Time.get_ticks_msec()) % 1000 < 16:
			print("%s: Warning - Navigation finished but still chasing!" % name)
		velocity.x = 0
		velocity.z = 0
		return
	
	# Get next position and move
	var next_pos = nav_agent.get_next_path_position()
	var distance_to_next = global_position.distance_to(next_pos)
	
	# If next position is too close, we might be stuck
	if distance_to_next < 0.1:
		velocity.x = 0
		velocity.z = 0
		return
	
	var direction = (next_pos - global_position).normalized()
	direction.y = 0  # horizontal only
	
	# Apply velocity
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _idle_behavior(_delta):
	# e override ni if nay unique idle ang monster
	velocity.x = 0
	velocity.z = 0

func set_chase_target(target_pos: Vector3):
	if not navigation_ready:
		print("%s: Tried to chase but navigation not ready!" % name)
		return
		
	chase_target = target_pos
	is_chasing = true
	
	if nav_agent:
		nav_agent.target_position = target_pos
		print("%s: Set nav target to %v" % [name, target_pos])
		
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
