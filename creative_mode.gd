extends Camera3D

# Settings
var move_speed = 50.0
var mouse_sensitivity = 0.002

func _ready():
	# Capture the mouse cursor so it doesn't leave the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Handle mouse movement for rotation
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity
		
		# Prevent the camera from flipping upside down (clamp pitch)
		rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))

	# Toggle mouse capture with ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	var input_dir = Vector3.ZERO

	# Check keys for movement (W/A/S/D) relative to where we are looking
	if Input.is_key_pressed(KEY_W):
		input_dir -= global_transform.basis.z # Forward
	if Input.is_key_pressed(KEY_S):
		input_dir += global_transform.basis.z # Backward
	if Input.is_key_pressed(KEY_A):
		input_dir -= global_transform.basis.x # Left
	if Input.is_key_pressed(KEY_D):
		input_dir += global_transform.basis.x # Right
	
	# Check keys for vertical movement (Q/E) in global space
	if Input.is_key_pressed(KEY_SPACE):
		input_dir += Vector3.UP # Up
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir -= Vector3.UP # Down

	# Normalize vector so moving diagonally isn't faster
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
	
	# Apply movement
	global_position += input_dir * move_speed * delta
