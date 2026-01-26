extends EnemyBase
class_name Watcher

#vision settings
@export var vision_range: float = 15.0
@export var vision_angle: float = 45.0
@export var alert_interval: float = 0.5
@export var eyes_open_duration: float = 5.0
@export var eyes_closed_duration: float = 2.0

#nodes
@onready var vision_area: Area3D = $VisionArea
@onready var raycast: RayCast3D = $RayCast3D
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var vision_light: SpotLight3D = $VisionLight

#state
var player_in_vision_area: bool = false
var eyes_open: bool = true
var eye_timer: float = 0.0
var player_currently_visible: bool = false
var alert_timer: float = 0.0
var audio_playing: bool = false

func _ready():
	super._ready()
	
	can_move = false
	speed = 0.0
	
	eyes_open = true
	eye_timer = eyes_open_duration
	
	raycast.collision_mask = 3
	raycast.add_exception(self)
	
	if vision_area:
		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)
	
	if alert_sound:
		alert_sound.finished.connect(_on_alert_sound_finished)
	
func _physics_process(delta):
	super._physics_process(delta)
	
	# Update alert timer
	if alert_timer > 0:
		alert_timer -= delta
	
	eye_timer -= delta
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
	
	if eyes_open:
		if player == null:
			player = EnemyManager.get_player()
		if player:
			_check_player_visibility()

func _check_player_visibility():
	if player == null:
		_set_player_visible(false)
		return
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	
	if distance > vision_range:
		_set_player_visible(false)
		return
		
	var forward = -global_transform.basis.z
	var direction_to_player = to_player.normalized()
	
	forward.y = 0
	if forward.length() > 0.001:
		forward = forward.normalized()
	direction_to_player.y = 0
	if direction_to_player.length() > 0.001:
		direction_to_player = direction_to_player.normalized()
		
	var dot = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
	
	if angle > vision_angle:
		_set_player_visible(false)
		return
		
	raycast.look_at(player.global_position)
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider != player:
			_set_player_visible(false)
			return
			
	_set_player_visible(true)
	_alert_other_enemies() #call kada frame nga visible
	
func _set_player_visible(visible: bool):
	if player_currently_visible and not visible:
		#stop audio cause player not visible
		if alert_sound and alert_sound.playing:
			alert_sound.stop()
			audio_playing = false
	player_currently_visible = visible
	
func _alert_other_enemies():
	if player == null:
		return
	
	#start if not already playing
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
