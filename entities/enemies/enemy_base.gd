extends CharacterBody3D
class_name EnemyBase

#settings
@export var speed: float = 5.0
@export var gravity: float = 9.8
@export var can_move: bool = false
@export var kill_distance: float = 0.7

#audio
@export var footstep_interval: float = 0.5
var footstep_timer: float = 0.0

#nodes
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
# Try to find the node, but don't crash if it doesn't exist (optional for Watcher)
@onready var footstep_audio_player: AudioStreamPlayer3D = get_node_or_null("FootstepSound") 

#stae
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
	# Wait for physics to settle before querying navigation
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if nav_agent:
		#fix to getting stuck
		nav_agent.path_desired_distance = 1.0 
		nav_agent.target_desired_distance = 1.0
		
		nav_agent.avoidance_enabled = true 
		
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
		
	#apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	#check if kill
	if player and is_game_active():
		var dist = global_position.distance_to(player.global_position)
		if dist < kill_distance:
			_kill_player()
	
	if not navigation_ready:
		move_and_slide()
		return
	
	var desired_velocity = Vector3.ZERO
	
	if can_move:
		if is_chasing:
			_update_chase_target()
			desired_velocity = _get_nav_velocity(delta)
		else:
			_idle_behavior(delta)
			if chase_target != Vector3.ZERO:
				desired_velocity = _get_nav_velocity(delta)
		
		if is_chasing or chase_target != Vector3.ZERO:
			desired_velocity = _get_nav_velocity(delta)
		elif not is_chasing:
			_idle_behavior(delta)
	
	if desired_velocity.length() > 0:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
		
		#rotate to face movement direction
		var look_dir = Vector2(velocity.z, velocity.x).angle()
		rotation.y = lerp_angle(rotation.y, look_dir, delta * 10.0)
		
		#footsteps
		footstep_timer -= delta
		if footstep_timer <= 0:
			_play_footstep()
			footstep_timer = footstep_interval
	else:
		#decelerate if stopping
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
		
	move_and_slide()

func _get_nav_velocity(_delta) -> Vector3:
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
		
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	
	return direction * speed

func _update_chase_target():
	if chase_player_directly and player:
		nav_agent.target_position = player.global_position

func _idle_behavior(_delta):
	#override in child classes
	pass

func set_chase_target(target_pos: Vector3, direct_chase: bool = false):
	if not navigation_ready: return
		
	chase_target = target_pos
	is_chasing = true
	chase_player_directly = direct_chase
	nav_agent.target_position = target_pos

func alert(player_position: Vector3):
	set_chase_target(player_position, false)

func _on_player_spotted(position: Vector3):
	alert(position)

#footsteps system
func _play_footstep():
	if footstep_audio_player and not footstep_audio_player.playing:
		#pitch variation for realism
		footstep_audio_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio_player.play()

#kill system
func is_game_active() -> bool:
	if player.has_method("is_alive"):
		return player.is_alive()
	return true

func _kill_player():
	print(name + " CAUGHT THE PLAYER!")
	if player.has_method("die"):
		player.die()
	set_physics_process(false)
	can_move = false
