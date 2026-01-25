extends EnemyBase
class_name Chaser

# chaser ang ngan pero slow kato ning monster 3
# slower than player 
# mu patrol2 guro ni siyas maze for idle behavior like walking around

#chase settings
@export var detection_radius: float = 8.0
@export var give_up_distance: float = 15.0
@export var give_up_time: float = 2.0

#patrol settings
@export var patrol_points: Array[Vector3] = []
@export var patrol_wait_time: float = 2.0

#footstep
@export var footstep_interval: float = 0.5

#nodes
@onready var detection_area: Area3D = $DetectionArea
@onready var footstep_sound: AudioStreamPlayer3D= $FootstepSound

#state variables niya
var player_in_detection_range: bool = false 
var current_patrol_index: int = 0
var patrol_wait_timer: float =0.0
var is_waiting: bool = false
var no_stimulus_timer: float = 0.0 #para di forever mu chase sa player
var footstep_timer: float = 0.0

func _ready():
	super._ready()
	speed = 3.5
	can_move = true
	
	#connect signals sa detect area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
func _physics_process(delta):
	if player:
		_check_player_proximity()
		
		if is_chasing: #stop chasing if layo na
			var distance = global_position.distance_to(player.global_position)
			if distance > give_up_distance:
				is_chasing = false
				print("too far stop chase")

	if is_chasing:
		no_stimulus_timer += delta
		if no_stimulus_timer >= give_up_time:
			is_chasing = false
			print("lost track of player stop case")
	
	if is_waiting:
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0:
			is_waiting = false
			_next_patrol_point()
			
	if velocity.length() > 0.1: #play footstep sound if moving
		footstep_timer -= delta
		if footstep_timer <= 0:
			_play_footstep()
			footstep_timer =footstep_interval
	else: #not moving
		if footstep_sound and footstep_sound.playing:
			footstep_sound.stop()
	
	super._physics_process(delta)
	
func _play_footstep():
	if footstep_sound and not footstep_sound.playing:
		footstep_sound.play()

func _check_player_proximity():
	if player == null:
		return
	var distance = global_position.distance_to(player.global_position)
	if distance <= detection_radius:
		_start_chase()
		
func _start_chase():
	if player == null:
		return
	
	set_chase_target(player.global_position)
	no_stimulus_timer = 0.0
	
	is_chasing = true

func _idle_behavior(_delta):
	if patrol_points.is_empty():
		velocity.x = 0
		velocity.z = 0
		return
	
	if is_waiting:
		velocity.x = 0
		velocity.z = 0
		return
	
	var target = patrol_points[current_patrol_index]
	var distance = global_position.distance_to(target)
	
	if distance < 1.0:
		is_waiting = true
		patrol_wait_timer = patrol_wait_time
		velocity.x = 0
		velocity.z = 0
	else:
		var direction = (target - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
func _next_patrol_point():
	if patrol_points.is_empty():
		return
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	
func set_patrol_points(points: Array[Vector3]):
	patrol_points = points
	current_patrol_index = 0
	
func _on_detection_area_body_entered(body: Node3D):
	if body == player:
		player_in_detection_range = true
		
func _on_detection_area_body_exited(body: Node3D):
	if body == player:
		player_in_detection_range = false
		
func _on_player_spotted(position: Vector3):
	set_chase_target(position)
	no_stimulus_timer = 0.0
	is_chasing = true
