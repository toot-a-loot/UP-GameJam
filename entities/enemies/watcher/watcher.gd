extends EnemyBase
class_name Watcher

# --- Vision Settings ---
@export_group("Vision Stats")
@export var vision_range: float = 15.0
@export var vision_angle: float = 45.0
@export var kill_range: float = 1.0

# --- Behavior Settings (New) ---
@export_group("Security Camera Behavior")
@export var is_sweeping: bool = true       # If true, rotates left/right while idle
@export var sweep_angle: float = 60.0      # How far to rotate in degrees
@export var sweep_speed: float = 0.5       # Speed of rotation

# --- Timers ---
@export var alert_interval: float = 0.5
@export var eyes_open_duration: float = 5.0
@export var eyes_closed_duration: float = 2.0

# --- Nodes ---
@onready var vision_area: Area3D = $VisionArea
@onready var raycast: RayCast3D = $RayCast3D
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var vision_light: SpotLight3D = $VisionLight

# --- State ---
var player_in_vision_area: bool = false
var eyes_open: bool = true
var eye_timer: float = 0.0
var player_currently_visible: bool = false
var alert_timer: float = 0.0
var audio_playing: bool = false

# Sweeping State
var initial_rotation_y: float = 0.0
var current_sweep_time: float = 0.0

func _ready():
	super._ready()
	
	can_move = false
	speed = 0.0
	
	# Capture the spawn rotation so we sweep around this center point
	initial_rotation_y = rotation.y
	
	eyes_open = true
	eye_timer = eyes_open_duration
	
	# Configure raycast
	if raycast:
		raycast.collision_mask = 3
		raycast.enabled = true
		raycast.exclude_parent = true
	
	if vision_area:
		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)
	
	if alert_sound:
		alert_sound.finished.connect(_on_alert_sound_finished)
	
	if vision_light:
		vision_light.shadow_enabled = true
		vision_light.spot_angle = vision_angle
		vision_light.spot_range = vision_range
		
func _physics_process(delta):
	super._physics_process(delta)
	
	# Update timers
	if alert_timer > 0:
		alert_timer -= delta
	
	eye_timer -= delta
	
	# Handle Blinking Cycle
	if eye_timer <= 0:
		if eyes_open:
			eyes_open = false
			eye_timer = eyes_closed_duration
			_set_vision_light(false)
			_set_player_visible(false)
		else:
			eyes_open = true
			eye_timer = eyes_open_duration
			_set_vision_light(true)
			# Reset sweep time to prevent snapping when eyes open? 
			# Optional, but keeping it continuous is usually smoother.
	
	# Handle Sweeping Logic (Security Camera)
	# Only sweep if eyes are open and we haven't locked onto the player
	if eyes_open and is_sweeping and not player_currently_visible:
		_process_sweeping(delta)
	
	# Vision Logic
	if eyes_open:
		if player == null:
			player = EnemyManager.get_player()
		if player:
			_check_player_visibility()
			_check_if_close_enough_to_kill()

func _process_sweeping(delta: float):
	current_sweep_time += delta * sweep_speed
	# Calculate offset using sine wave
	var angle_offset = sin(current_sweep_time) * deg_to_rad(sweep_angle)
	rotation.y = initial_rotation_y + angle_offset

func _check_if_close_enough_to_kill():
	if player == null or not player_currently_visible:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player < kill_range:
		_kill_player()

func _check_player_visibility():
	if player == null:
		_set_player_visible(false)
		return
	
	# --- FIX: Use Light Position (Head) vs Body Position (Feet) ---
	var eye_pos = vision_light.global_position if vision_light else global_position + Vector3(0, 1.5, 0)
	var to_player = player.global_position - eye_pos
	var distance = to_player.length()
	
	# 1. Distance Check
	if distance > vision_range:
		_set_player_visible(false)
		return
	
	# 2. Angle Check (Using Light's forward vector)
	# SpotLights face -Z locally. 
	var forward = -vision_light.global_transform.basis.z if vision_light else -global_transform.basis.z
	var direction_to_player = to_player.normalized()
	
	var dot = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
	
	if angle > vision_angle:
		_set_player_visible(false)
		return
	
	# 3. Raycast Check (Physical occlusion)
	# Raycast from Eyes -> Player Center (approx 1.0m up from feet)
	var ray_target = player.global_position + Vector3(0, 1.0, 0)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(eye_pos, ray_target)
	query.collision_mask = 3  # Walls (1) and Player (2)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == player:
			_set_player_visible(true)
			_alert_other_enemies()
		else:
			_set_player_visible(false)
	else:
		_set_player_visible(false)

func _set_player_visible(visible: bool):
	if player_currently_visible and not visible:
		# Stop audio if we lost them
		if alert_sound and alert_sound.playing:
			alert_sound.stop()
			audio_playing = false
	player_currently_visible = visible
	
func _alert_other_enemies():
	if player == null: return
	
	if alert_sound and not audio_playing:
		alert_sound.play()
		audio_playing = true
	
	if alert_timer <= 0:
		EnemyManager.alert_enemies(player.global_position)
		alert_timer = alert_interval

func _on_alert_sound_finished():
	audio_playing = false

func _on_vision_area_body_entered(body: Node3D):
	if body == player or body.name == "Player":
		player_in_vision_area = true

func _on_vision_area_body_exited(body: Node3D):
	if body == player or body.name == "Player":
		player_in_vision_area = false
		
func _on_player_spotted(_position: Vector3):
	pass
	
func can_see_player() -> bool:
	if player == null or not eyes_open:
		return false
	return player_currently_visible

func _set_vision_light(enabled: bool):
	if vision_light:
		vision_light.visible = enabled

func _kill_player():
	if player and player.has_method("die"):
		print("Watcher: KILLED PLAYER!")
		player.die()
