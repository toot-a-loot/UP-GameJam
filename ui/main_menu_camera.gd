extends Camera3D

# Controls how far the camera moves (in meters)
# X is left/right, Y is up/down
@export var max_offset: Vector2 = Vector2(0.07, 0.07) 
@export var smooth_speed: float = 5.0

var start_position: Vector3

func _ready() -> void:
	# Save the position you set in the editor as the "center" point
	start_position = global_position

func _process(delta: float) -> void:
	# 1. Get Screen Data
	var viewport_rect = get_viewport().get_visible_rect()
	var mouse_pos = get_viewport().get_mouse_position()
	var center = viewport_rect.size / 2.0

	# 2. Calculate percentage from center (-1.0 to 1.0)
	var input_vector = (mouse_pos - center) / center
	
	# 3. Create a Local Offset (Relative to Camera Rotation)
	# We invert Y because Screen Y is Down, but 3D Y is Up.
	var target_local_offset = Vector3(
		input_vector.x * max_offset.x, 
		-input_vector.y * max_offset.y, 
		0.0
	)
	
	# 4. Convert Local Offset to Global World Space
	# This ensures the camera moves "Up" relative to the screen, not the world.
	var target_global_offset = global_transform.basis * target_local_offset

	# 5. Apply with Smoothing
	global_position = global_position.lerp(start_position + target_global_offset, delta * smooth_speed)
