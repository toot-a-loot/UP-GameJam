extends Node

func _ready():
	# Wait for physics and navmesh to settle
	await get_tree().process_frame
	setup_test_scene()

func setup_test_scene():
	print("--- Initializing Test Arena ---")

	# 1. Chaser Setup
	var chaser = get_parent().get_node_or_null("Chaser")
	if is_instance_valid(chaser) and chaser.has_method("set_patrol_points"):
		var points: Array[Vector3] = [
			Vector3(0, 0.5, 15),
			Vector3(10, 0.5, 15),
			Vector3(10, 0.5, 5),
			Vector3(-10, 0.5, 5),
			Vector3(-10, 0.5, 15)
		]
		chaser.set_patrol_points(points)
		print("Success: Chaser patrol points configured.")

	# 2. Listener Setup
	var listener = get_parent().get_node_or_null("Listener")
	var player = get_parent().get_node_or_null("Player")
	if is_instance_valid(listener) and is_instance_valid(player):
		var dist = listener.global_position.distance_to(player.global_position)
		var radius = listener.get("hearing_radius") if "hearing_radius" in listener else 0.0
		print("Status: Listener is ", snapped(dist, 0.1), " units from player. (Radius: ", radius, ")")

	# 3. Watcher Setup
	var watcher = get_parent().get_node_or_null("Watcher")
	if is_instance_valid(watcher):
		# Using set() safely in case these variables aren't defined exactly this way
		watcher.set("eyes_open", false)
		watcher.set("eye_timer", 2.0)
		print("Success: Watcher eyes closed for 2 seconds.")

	print("--- Arena Ready! ---")
