extends CharacterBody2D

@export var speed = 300.0
@onready var hands_blackout = $CanvasLayer/ColorRect

func _physics_process(delt):
	# Mechanic: are we covering eyes?
	if Input.is_action_pressed("cover_eyes"):
		hands_blackout.visible = true
		velocity = Vector2.ZERO
	
	else:
		hands_blackout.visible = false
		move_normally()
		
	move_and_slide()
	
func move_normally():
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction:
		velocity = direction * speed
	
	else:
		velocity = Vector2.ZERO
