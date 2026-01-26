extends CharacterBody3D

# Settings
@export var run_speed = 15.0
@export var walk_speed = 8.0
@export var gravity = 9.8

# --- NEW: Mouse Sensitivity Setting ---
@export var mouse_sensitivity = 0.003

# Timer Settings
@export var level_time_limit = 120.0
var time_left = 0.0
var is_game_active = true

# Nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var flashlight = $Head/OmniLight3D
@onready var blindfold = $CanvasLayer/ColorRect
@onready var timer_label = $CanvasLayer/TimerLabel

# STATE VARIABLE
# false = Sight Mode (Can see, can't move)
# true = Move Mode (Can't see well, can move)
var is_covering_eyes = false 

func _ready():
	# --- NEW: Capture Mouse ---
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#ayaw ni e check gang kay maguba jud, matic lng e register ang player
	EnemyManager.register_player(self)
	
	time_left = level_time_limit

# --- NEW: Input Function for Mouse Look ---
func _input(event):
	if event is InputEventMouseMotion:
		# Horizontal: Rotate the entire Player Body (affects movement direction)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Vertical: Rotate only the Head (Camera + Flashlight)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp the look up/down to prevent flipping (-90 to 90 degrees)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if is_game_active:
		time_left -= delta
		
		# Time format
		var minutes = floor(time_left / 60)
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		if time_left <= 0:
			time_left = 0
			timer_label.text = "00:00"
			#function here for game_over
			game_over()
			
	# --- 1. THE SWITCH (Toggle Mode) ---
	if Input.is_action_just_pressed("cover_eyes"):
		is_covering_eyes = !is_covering_eyes 

	# --- 2. BEHAVIOR ---
	if is_covering_eyes:
		# MODE: MOVING (Hands over eyes)
		set_state_moving()
		
		var current_speed = walk_speed
		if Input.is_action_pressed("run"):
			current_speed = run_speed
		
		# Allow Movement logic
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			# Note: transform.basis is now updated by our mouse rotation!
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
			
	else:
		# MODE: SIGHT (Hands over ears)
		set_state_sight()
		
		# DISABLE Movement (Feet are glued to floor)
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

# --- VISUAL HELPERS ---

func set_state_moving():
	# Darken screen, allow flashlight
	blindfold.visible = true
	blindfold.color.a = 0.3 
	flashlight.visible = true 

func set_state_sight():
	# Crystal clear vision
	blindfold.visible = false
	blindfold.color.a = 0.0
	flashlight.visible = true

func game_over():
	# Placeholder for what happens when time runs out
	print("GAME OVER - TIME IS UP")
	is_game_active = false
	# You can add logic here later to reload the scene
