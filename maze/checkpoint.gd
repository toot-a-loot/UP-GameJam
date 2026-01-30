extends Area3D

signal exit_reached

@export var time_bonus: float = 30.0 # More time since it's the end of the level

func _ready():
	# Monitor Layer 2 (Player)
	collision_layer = 0
	collision_mask = 2 
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# 1. Add Time
		if body.has_method("add_time"):
			body.add_time(time_bonus)
			print("Checkpoint Reached! Time Added.")
		
		# 2. Tell the world to change levels
		exit_reached.emit()
		
		# Turn off to prevent double triggers
		set_deferred("monitoring", false)
