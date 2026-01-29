extends EnemyBase
class_name Chaser

#wander and detect settings
@export var detection_radius: float = 10.0
@export var give_up_time: float = 5.0
@export var wander_radius: float = 15.0

#nodes
@onready var detection_area: Area3D = $DetectionArea
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var raycast: RayCast3D = $RayCast3D

#state
var player_in_detection_area: bool = false
var no_stimulus_timer: float = 0.0

func _ready():
	super._ready()
	speed = 5.0  #slower than player run and walk
	can_move = true
	
	# Set footstep interval from parent
	footstep_interval = 0.5
	
	# Setup Raycast for Line of Sight
	if not has_node("RayCast3D"):
		var new_ray = RayCast3D.new()
		new_ray.name = "RayCast3D"
		new_ray.target_position = Vector3(0, 0, -detection_radius)
		new_ray.enabled = true
		add_child(new_ray)
		raycast = new_ray
		
	_pick_random_wander_point()

func _physics_process(delta):
	#1 detect logic
	if player:
		_check_for_player_sight()
		_check_if_touching_player()
	
	#2 state management
	if is_chasing:
		no_stimulus_timer += delta
		if no_stimulus_timer >= give_up_time:
			print("Chaser: Lost interest. Returning to wander.")
			is_chasing = false
			speed = 4.5
			_pick_random_wander_point()
	
	# Handle footsteps
	if velocity.length() > 0.1:
		footstep_timer -= delta
		if footstep_timer <= 0:
			_play_footstep()
			footstep_timer = footstep_interval
	else:
		if footstep_sound and footstep_sound.playing:
			footstep_sound.stop()
	
	super._physics_process(delta)

func _check_if_touching_player():
	if player == null:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Kill player if within 1.5 units
	if distance_to_player < 1.5:
		_kill_player()

func _play_footstep():
	if footstep_sound:
		if not footstep_sound.playing:
			footstep_sound.play()

func _check_for_player_sight():
	if player == null: return
	
	var dist = global_position.distance_to(player.global_position)
	
	#dont raycast if too far
	if dist > detection_radius: return
	
	#raycast check to prevent seeing through walls
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0,1,0), player.global_position + Vector3(0,1,0))
	query.exclude = [self] #ayaw igo self
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		#visible and close
		_start_chase(player.global_position)

func _start_chase(target_pos: Vector3):
	no_stimulus_timer = 0.0
	if not is_chasing:
		print("Chaser: SAW PLAYER! CHASING!")
		is_chasing = true
		speed = 6.5 #chasing speed
	
	#update target to current player position
	set_chase_target(target_pos, true)

func _idle_behavior(_delta):
	if not navigation_ready: return
	
	if nav_agent.is_navigation_finished():
		_pick_random_wander_point()
		return
		
	if chase_target == Vector3.ZERO:
		_pick_random_wander_point()

func _pick_random_wander_point():
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_pos = global_position + (random_dir * wander_radius)
	
	var map = get_world_3d().navigation_map
	var valid_point = NavigationServer3D.map_get_closest_point(map, random_pos)
	
	set_chase_target(valid_point, false) #false = not chasing player direct

func _kill_player():
	if player and player.has_method("die"):
		print("Chaser: KILLED PLAYER!")
		player.die()
