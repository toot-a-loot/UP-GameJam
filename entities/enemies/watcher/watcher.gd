extends EnemyBase
class_name Watcher

#watcher enemy(ward), can see but cant move, alerts others if it spots player

#vision settings
@export var vision_range: float = 15.0
@export var vision_angle: float = 90.0
@export var alert_cooldown: float = 5.0
@export var eyes_open_duration: float = 5.0
@export var eyes_closed_duration: float = 2.0

#nodes
@onready var vision_area: Area3D = $VisionArea
@onready var raycast: RayCast3D = $RayCast3D
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var vision_light: SpotLight3D = $VisionLight

#state
var player_in_vision_area: bool = false
var can_alert: bool = true
var alert_timer: float = 0.0
var eyes_open: bool = true
var eye_timer: float = 0.0
var player_currently_visible: bool = false

func _ready():
	super._ready()
	
	#watcher cannot move
	can_move = false
	speed = 0.0
	
	#start with eyes open
	eyes_open = true
	eye_timer = eyes_open_duration
	#connect vision area signals
	if vision_area:
		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)
		
func _physics_process(delta):
	super._physics_process(delta)
	
	if not can_alert:
		alert_timer -= delta
		if alert_timer <= 0:
			can_alert = true
			
	eye_timer -=delta
	if eye_timer <= 0:
		if eyes_open:
			#eye open cooldown, close eye
			eyes_open=false
			eye_timer= eyes_closed_duration
			_set_vision_light(false)
			_set_player_visible(false)
		else:
			#eyes closed cd, open eye
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
		
	# check if player is within cone vision
	var forward = -global_transform.basis.z #forward direction
	var direction_to_player = to_player.normalized()
	
	#flatten to horizontal plane to check angle
	forward.y = 0
	if forward.length() > 0.001:
		forward = forward.normalized()
	direction_to_player.y = 0
	if direction_to_player.length() > 0.001:
		direction_to_player = direction_to_player.normalized()
		
	var dot = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
	
	#player must be within visoin cone angle
	if angle > vision_angle:
		_set_player_visible(false)
		return
		
	#player is within cone and visible, alert others
	_set_player_visible(true)
	_alert_other_enemies()
	
func _set_player_visible(visible: bool):
	if player_currently_visible and not visible: #player was visible niya dili na visible na out of range or clos eyes
		if alert_sound and alert_sound.playing:
			alert_sound.stop()
	player_currently_visible = visible
	
func _alert_other_enemies():
	if not can_alert or player == null:
		return
		
	if alert_sound:
		alert_sound.play()
		
	EnemyManager.alert_enemies(player.global_position)
	
	#start cd
	can_alert = false
	alert_timer = alert_cooldown

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
