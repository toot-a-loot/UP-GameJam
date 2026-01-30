extends EnemyBase
class_name Chaser

#wander and detect settings
@export var detection_radius: float = 10.0
@export var give_up_time: float = 5.0
@export var wander_radius: float = 15.0
@export var wander_wait_time: float = 2.0

#nodes
@onready var detection_area: Area3D = $DetectionArea
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var raycast: RayCast3D = $RayCast3D

#state
var player_in_detection_area: bool = false
var no_stimulus_timer: float = 0.0
var wander_wait_timer: float = 0.0
var is_investigating: bool = false

func _ready():
	super._ready()
	speed = 5.5
	can_move = true
	
	footstep_interval = 0.5
	
	if not has_node("RayCast3D"):
		var new_ray = RayCast3D.new()
		new_ray.name = "RayCast3D"
		new_ray.target_position = Vector3(0, 0, -detection_radius)
		new_ray.enabled = true
		add_child(new_ray)
		raycast = new_ray
	
	#start with a wander point
	await get_tree().create_timer(0.6).timeout
	if navigation_ready:
		_pick_random_wander_point()
	else:
		await get_tree().create_timer(0.4).timeout
		_pick_random_wander_point()

func _physics_process(delta):
	if player:
		_check_for_player_sight()
		_check_if_touching_player()
	
	if is_chasing:
		no_stimulus_timer += delta
		if no_stimulus_timer >= give_up_time:
			is_chasing = false
			chase_player_directly = false
			is_investigating = false
			speed = 5.5
			wander_wait_timer = 0.0
			_pick_random_wander_point()
	
	if footstep_sound and velocity.length() > 0.1:
		footstep_timer -= delta
		if footstep_timer <= 0:
			_play_custom_footstep()
			footstep_timer = footstep_interval
	elif footstep_sound and footstep_sound.playing:
		footstep_sound.stop()
	
	super._physics_process(delta)

func _check_if_touching_player():
	if player == null:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	#kill player if within this range
	if distance_to_player < 1.5:
		_kill_player()

func _play_custom_footstep():
	if footstep_sound:
		if not footstep_sound.playing:
			footstep_sound.pitch_scale = randf_range(0.9, 1.1)
			footstep_sound.play()

func _check_for_player_sight():
	if player == null: 
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist > detection_radius: 
		return
	
	#raycast to not see through walls
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1, 0), 
		player.global_position + Vector3(0, 1, 0)
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		#nakitan and duol
		_start_chase(player.global_position)

func _start_chase(target_pos: Vector3):
	no_stimulus_timer = 0.0
	if not is_chasing:
		is_chasing = true
		is_investigating = false
		speed = 10.0
	
	set_chase_target(target_pos, true)

func _idle_behavior(_delta):
	"""
	Called by EnemyBase when not chasing.
	This handles wandering behavior by keeping chase_target set.
	"""
	if not navigation_ready: 
		return
	
	if chase_target == Vector3.ZERO or nav_agent.is_navigation_finished():
		wander_wait_timer += _delta
		if wander_wait_timer >= wander_wait_time:
			wander_wait_timer = 0.0
			_pick_random_wander_point()
	
	#lose target
	if chase_target == Vector3.ZERO:
		_pick_random_wander_point()

func _pick_random_wander_point():
	if not navigation_ready:
		return
	
	#generate random distance and angle
	var random_angle = randf() * TAU
	var random_distance = randf_range(wander_radius * 0.6, wander_radius)
	
	var random_dir = Vector3(
		cos(random_angle) * random_distance,
		0,
		sin(random_angle) * random_distance
	)
	
	var target_pos = global_position + random_dir
	
	var map = get_world_3d().navigation_map
	var valid_point = NavigationServer3D.map_get_closest_point(map, target_pos)
	
	var distance_to_point = valid_point.distance_to(global_position)
	if distance_to_point > 3.0:
		chase_target = valid_point
		chase_player_directly = false
		nav_agent.target_position = valid_point
	else:
		await get_tree().create_timer(0.1).timeout
		_pick_random_wander_point()

func alert(player_position: Vector3):
	"""Called by EnemyManager when Watcher spots player"""
	is_investigating = true
	no_stimulus_timer = 0.0
	speed = 6.0  # Investigation speed
	set_chase_target(player_position, false)  #false=investigate

func _on_player_spotted(position: Vector3):
	"""Called by EnemyManager signal"""
	is_investigating = true
	no_stimulus_timer = 0.0
	speed = 6.0
	set_chase_target(position, false)

func _kill_player():
	if player and player.has_method("die"):
		print("Chaser: KILLED PLAYER!")
		player.die()
