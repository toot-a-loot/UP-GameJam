extends EnemyBase
class_name Listener

# listener enemy can hear but cannot see, faster than player, detects if player is moving(footsteps), wanders around when not chasing

#hearing settings
@export var hearing_radius: float = 20.0
@export var memory_duration: float = 0.08 #how long to chase last known location

# wandering settings
@export var wander_distance_min: float = 10.0
@export var wander_distance_max: float = 25.0
@export var wander_pause_chance: float = 1.0
@export var wander_pause_duration: float = 2.0

# stamina/tired system
@export var max_chase_duration: float = 3.5 # how long can chase before tired
@export var tired_duration: float = 1.5 # how long stunned when tired

#nodes
@onready var hearing_area: Area3D = $HearingArea
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound

#footstep
@export var chase_speed: float = 15.5
@export var walk_speed: float = 6.0
@export var footstep_chase_sound: AudioStream
@export var footstep_walk_sound: AudioStream

#state
var player_in_hearing_range: bool = false
var last_heard_time: float = 0.0
var search_timer: float = 0.0

# stamina state
var chase_timer: float = 0.0
var is_tired: bool = false
var tired_timer: float = 0.0

#wandering
var wander_target: Vector3 = Vector3.ZERO
var is_paused: bool = false
var pause_timer: float = 0.0
var stuck_timer: float = 0.0
var last_position: Vector3 = Vector3.ZERO

func _ready():
	super._ready()
	
	speed = walk_speed
	can_move = true
	
	# Set footstep interval from parent
	footstep_interval = 0.3
	
	#initialize wandering
	last_position = global_position
	_choose_new_wander_direction()
	
	#connect hearing signals
	if hearing_area:
		hearing_area.body_entered.connect(_on_hearing_area_body_entered)
		hearing_area.body_exited.connect(_on_hearing_area_body_exited)
	else:
		printerr("Listener: No HearingArea found!")
		
func _physics_process(delta):
	if player == null:
		player = EnemyManager.get_player()
	
	# Handle tired state first - enemy is stunned and cannot move
	if is_tired:
		tired_timer -= delta
		velocity.x = 0
		velocity.z = 0
		
		if tired_timer <= 0:
			is_tired = false
			chase_timer = 0.0
			_choose_new_wander_direction()
		
		# Stop footstep sound when tired
		if footstep_sound and footstep_sound.playing:
			footstep_sound.stop()
			
		# Still apply gravity
		super._physics_process(delta)
		return
			
	if player:
		_check_for_footsteps()
		_check_if_touching_player()
		
	if is_chasing:
		speed = chase_speed
		chase_timer += delta
		
		# Check if tired from chasing too long
		if chase_timer >= max_chase_duration:
			is_tired = true
			tired_timer = tired_duration
			is_chasing = false
			speed = walk_speed
			# Stop immediately
			velocity.x = 0
			velocity.z = 0
			return
		
		search_timer -= delta
		if search_timer <= 0: #lost the player start wander
			speed = walk_speed
			is_chasing = false
			chase_timer = 0.0  # Reset chase timer
			_choose_new_wander_direction()
	else:
		# Check if stuck while wandering (not moving much)
		var distance_moved = global_position.distance_to(last_position)
		if distance_moved < 0.1 and not is_paused:
			stuck_timer += delta
			if stuck_timer > 2.0:
				_choose_new_wander_direction()
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		
		last_position = global_position
			
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
		var target_stream = footstep_chase_sound if is_chasing else footstep_walk_sound
		if footstep_sound.stream != target_stream:
			footstep_sound.stream = target_stream
			footstep_sound.stop()
		if not footstep_sound.playing:
			footstep_sound.play()
		
func _check_for_footsteps():
	if player == null:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > hearing_radius:
		return
	
	# Check if player is moving
	if player.velocity.length() > 0.1:
		_hear_player()
		
func _hear_player():
	if player == null:
		return
	
	# Don't start chasing if tired
	if is_tired:
		return
		
	var heard_position = player.global_position
	
	set_chase_target(heard_position, true)
	search_timer = memory_duration
	
	# Only start chase if not already chasing (to preserve chase_timer)
	if not is_chasing:
		is_chasing = true
		chase_timer = 0.0  # Reset timer when starting new chase
	
func _idle_behavior(delta):
	if not navigation_ready:
		velocity.x = 0
		velocity.z = 0
		return
		
	if is_paused:
		pause_timer -= delta
		velocity.x = 0
		velocity.z = 0
		if pause_timer <= 0:
			is_paused = false
			_choose_new_wander_direction()
		return
	
	if nav_agent.is_navigation_finished():
		if randf() < wander_pause_chance:
			is_paused = true
			pause_timer = wander_pause_duration
		else:
			_choose_new_wander_direction()
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _choose_new_wander_direction():
	if not navigation_ready:
		return
		
	# Try multiple times to find a valid wander target
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		# Generate a random direction
		var random_angle = randf() * TAU  # Random angle in radians (0 to 2π)
		var random_distance = randf_range(wander_distance_min, wander_distance_max)
		
		# Calculate target position
		var offset = Vector3(
			cos(random_angle) * random_distance,
			0,
			sin(random_angle) * random_distance
		)
		var target_pos = global_position + offset
		
		# Set the navigation target
		nav_agent.target_position = target_pos
		
		# Wait a frame for navigation to calculate
		await get_tree().process_frame
		
		# Check if the path is valid and not too short
		if not nav_agent.is_navigation_finished():
			var path = nav_agent.get_current_navigation_path()
			if path.size() > 3:  # Ensure path has reasonable length
				is_paused = false
				return
		
		attempts += 1
	
	# Fallback: just pick a point in a random cardinal direction
	var cardinal_directions = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1)
	]
	var fallback_dir = cardinal_directions.pick_random()
	var fallback_target = global_position + (fallback_dir * wander_distance_min)
	nav_agent.target_position = fallback_target
	is_paused = false
		
func _on_hearing_area_body_entered(body: Node3D):
	if body == player or body.name == "Player":
		player_in_hearing_range = true
		
func _on_hearing_area_body_exited(body: Node3D):
	if body == player or body.name == "Player":
		player_in_hearing_range = false
		
func _on_player_spotted(position: Vector3):
	# Don't respond to alerts if tired
	if is_tired:
		return
		
	#receives alert from watcher
	set_chase_target(position, false)
	search_timer = memory_duration
	
	# Only start chase if not already chasing
	if not is_chasing:
		is_chasing = true
		chase_timer = 0.0
	
func can_hear_player() -> bool:
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	return distance <= hearing_radius and player.velocity.length() > 0.1

func _kill_player():
	if player and player.has_method("die"):
		print("Listener: KILLED PLAYER!")
		player.die()
