extends Area3D

@export var time_bonus: float = 15.0 

func _ready():
	# Ensure it detects the player (Layer 2)
	collision_layer = 0
	collision_mask = 2 
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("add_time"):
		body.add_time(time_bonus)
		queue_free() # Disappear after pickup
