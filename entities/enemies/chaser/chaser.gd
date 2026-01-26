extends EnemyBase
class_name Chaser

# chaser ang ngan pero slow kato ning monster 3
# slower than player 
# mu patrol2 guro ni siyas maze for idle behavior like walking around

#chase settings
@export var detection_radius: float = 8.0
@export var give_up_distance: float = 15.0
@export var give_up_time: float = 8.0

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
var patrol_wait_timer: float = 0.0
var is_waiting: bool = false
var no_stimulus_timer: float = 0.0 #para di forever mu chase sa player
var footstep_timer: float = 0.0

func _ready():
	super._ready()
	speed = 4.5
	can_move = true
	
	print("Chaser: Ready at position ", global_position)
	print("Chaser: Has %d patrol points" % patrol_points.size())
	print("Chaser: can_move = ", can_move, " speed = ", speed)
	
	#connect signals sa detect area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		print("Chaser: Detection area connected")
	else:
		printerr("Chaser: No DetectionArea found!")
	
func _physics_process(delta):
	if player == null:
		player = EnemyManager.get_player()
		if player:
			print("Chaser: Found player at ", player.global_position)
			
	if player:
		_check_player_proximity()
	
	if is_chasing:
		no_stimulus_timer += delta
		
		if no_stimulus_timer >= give_up_time:
			print("Chaser: Gave up chase, returning to patrol")
			is_chasing = false
			
	if is_waiting:
		patrol_wait_timer -= delta
		
		if patrol_wait_timer <= 0:
			is_waiting = false
			_next_patrol_point()
	
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
	
	# Only set target when starting chase, not every frame
	if not is_chasing:
		set_chase_target(player.global_position)
		
	no_stimulus_timer = 0.0
	is_chasing = true

func _idle_behavior(_delta):
	if not navigation_ready:
		velocity.x = 0
		velocity.z = 0
		return
		
	if patrol_points.is_empty():
		# No patrol points, just stand still
		velocity.x = 0
		velocity.z = 0
		return
	
	if is_waiting:
		velocity.x = 0
		velocity.z = 0
		return
	
	var target = patrol_points[current_patrol_index]
	
	nav_agent.target_position = target
	
	# Check if reached patrol point
	if nav_agent.is_navigation_finished():
		is_waiting = true
		patrol_wait_timer = patrol_wait_time
		velocity.x = 0
		velocity.z = 0
		print("Chaser: Reached patrol point %d" % current_patrol_index)
	else:
		# Follow the navigation path
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
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
	print("Chaser: Body entered detection area: ", body.name)
	if body == player or body.name == "Player":
		player_in_detection_range = true
		print("Chaser: Player in detection range!")
		
func _on_detection_area_body_exited(body: Node3D):
	if body == player or body.name == "Player":
		player_in_detection_range = false
		print("Chaser: Player left detection range")
		
func _on_player_spotted(position: Vector3):
	set_chase_target(position)
	no_stimulus_timer = 0.0
	is_chasing = true
