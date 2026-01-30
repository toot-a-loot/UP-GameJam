extends EnemyBase
class_name Watcher

#vision 
@export_group("Vision Stats")
@export var vision_range: float = 15.0
@export var vision_angle: float = 45.0
@export var kill_range: float = 1.0

#behavior
@export_group("Surveillance Behavior")
@export var rotate_360: bool = true
@export var rotation_speed: float = 1.0

#timer
@export var alert_interval: float = 0.5

#nodes
@onready var vision_area: Area3D = $VisionArea
@onready var raycast: RayCast3D = $RayCast3D
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var vision_light: SpotLight3D = $VisionLight

#state
var player_in_vision_area: bool = false
var player_currently_visible: bool = false
var alert_timer: float = 0.0
var audio_playing: bool = false

func _ready():
	super._ready()
	
	can_move = false
	speed = 0.0
	
	#raycast config
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
		vision_light.visible = true
		vision_light.shadow_enabled = true
		vision_light.spot_angle = vision_angle
		vision_light.spot_range = vision_range
		
func _physics_process(delta):
	super._physics_process(delta)
	
	if alert_timer > 0:
		alert_timer -= delta
	
	#only rotate if we not locked on to player
	if rotate_360 and not player_currently_visible:
		_process_rotation(delta)
	
	if player == null:
		player = EnemyManager.get_player()
	if player:
		_check_player_visibility()
		_check_if_close_enough_to_kill()

func _process_rotation(delta: float):
	rotate_y(rotation_speed * delta)

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
	
	var eye_pos = vision_light.global_position if vision_light else global_position + Vector3(0, 1.5, 0)
	var to_player = player.global_position - eye_pos
	var distance = to_player.length()
	
	#distance
	if distance > vision_range:
		_set_player_visible(false)
		return
	
	#angle
	var forward = -vision_light.global_transform.basis.z if vision_light else -global_transform.basis.z
	var direction_to_player = to_player.normalized()
	
	var dot = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
	
	if angle > vision_angle:
		_set_player_visible(false)
		return
	
	#raycast check
	var ray_target = player.global_position + Vector3(0, 1.0, 0)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(eye_pos, ray_target)
	query.collision_mask = 3
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
	if player == null:
		return false
	return player_currently_visible

func _kill_player():
	if player and player.has_method("die"):
		print("Watcher: KILLED PLAYER!")
		player.die()
