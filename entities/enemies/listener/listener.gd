extends EnemyBase
class_name Listener

# listener enemy can hear but cannot see, faster than layer, detects if player is moving(footsteps), wanders around when not chasing

#hearing settings
@export var hearing_radius: float = 12.0
@export var memory_duration: float = 5.0#how long to chase last known location

# wandering settings
@export var wander_direction_change_time: float = 3.0
@export var wander_pause_chance: float = 0.2 #20% chance mu pause
@export var wander_pause_duration: float = 2.0

#nodes
@onready var hearing_area: Area3D = $HearingArea
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound

#footstep
@export var chase_speed: float = 9.5
@export var walk_speed: float = 6.0
@export var footstep_chase_sound: AudioStream
@export var footstep_walk_sound: AudioStream
@export var footstep_interval: float = 0.3

#state
var player_in_hearing_range: bool = false
var last_heard_time: float = 0.0
var search_timer: float = 0.0
var footstep_timer: float = 0.0

#wandering
var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var is_paused: bool =false
var pause_timer: float = 0.0

func _ready():
	super._ready()
	
	speed = walk_speed
	can_move = true
	
	#initialize wandering
	_choose_new_wander_direction()
	
	#connect hearing signals
	if hearing_area:
		hearing_area.body_entered.connect(_on_hearing_area_body_entered)
		hearing_area.body_exited.connect(_on_hearing_area_body_exited)
		
func _physics_process(delta):
	if player == null:
		player = EnemyManager.get_player()
	if player:
		_check_for_footsteps()
		
	if is_chasing:
		speed = chase_speed
		search_timer -= delta
		if search_timer <= 0:#lost the player start wander
			speed = walk_speed
			is_chasing = false
			_choose_new_wander_direction()
			
	if velocity.length() > 0.1:
		footstep_timer -= delta
		if footstep_timer <= 0:
			_play_footstep()
			footstep_timer = footstep_interval
	else:
		if footstep_sound and footstep_sound.playing:
			footstep_sound.stop()
			
	super._physics_process(delta)
	
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
	
	if player.velocity.length() > 0.1:
		_hear_player()
		
func _hear_player():
	if player == null:
		return
		
	var heard_position = player.global_position
	
	set_chase_target(heard_position)
	search_timer = memory_duration
	
	is_chasing = true
	
func _idle_behavior(delta):
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
	var random_offset = Vector3(randf_range(-15,15),0,randf_range(-15,15))
	var target_pos = global_position + random_offset
	
	nav_agent.target_position = target_pos
	is_paused = false
		
func _on_hearing_area_body_entered(body: Node3D):
	if body == player:
		player_in_hearing_range = true
		
func _on_hearing_area_body_exited(body: Node3D):
	if body == player:
		player_in_hearing_range = false
		
func _on_player_spotted(position: Vector3):
	#receives alert from watcher dili kani nga monster mismo ang makakita
	set_chase_target(position)
	search_timer = memory_duration
	is_chasing = true
	
func can_hear_player() -> bool:
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	return distance <= hearing_radius and player.velocity.length() > 0.1
