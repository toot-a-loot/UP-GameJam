extends CharacterBody3D

# Settings
@export var speed = 5.0
@export var gravity = 9.8

# Nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var flashlight = $Head/SpotLight3D
@onready var blindfold = $CanvasLayer/ColorRect

# STATE VARIABLE (Keeps track of which mode we are in)
# false = Sight Mode (Can see, can't move)
# true = Move Mode (Can't see well, can move)
var is_covering_eyes = false 

func _ready():
	#register ang player sa enemy manager
	EnemyManager.register_player(self)

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- 1. THE SWITCH (Toggle Mode) ---
	if Input.is_action_just_pressed("cover_eyes"):
		is_covering_eyes = !is_covering_eyes # Flip the boolean (True becomes False, False becomes True)

	# --- 2. BEHAVIOR ---
	if is_covering_eyes:
		# MODE: MOVING (Hands over eyes)
		set_state_moving()
		
		# Allow Movement logic
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			
	else:
		# MODE: SIGHT (Hands over ears)
		set_state_sight()
		
		# DISABLE Movement (Feet are glued to floor)
		velocity.x = 0
		velocity.z = 0

	move_and_slide()


# --- VISUAL HELPERS ---

func set_state_moving():
	# Darken screen, allow flashlight?
	blindfold.visible = true
	blindfold.color.a = 0.3 # 30% Dark (Adjust this number to make it harder!)
	flashlight.visible = true 

func set_state_sight():
	# Crystal clear vision
	blindfold.visible = false
	blindfold.color.a = 0.0
	flashlight.visible = true
