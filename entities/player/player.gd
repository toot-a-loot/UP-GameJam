extends CharacterBody3D

# Settings
@export var run_speed = 15.0
@export var walk_speed = 8.0
@export var gravity = 9.8

# --- Mouse Sensitivity Setting ---
@export var mouse_sensitivity = 0.003

# Timer Settings
@export var level_time_limit = 300.0
var elapsed_time = 0.0
var time_left = 0.0
var is_game_active = true
var is_dead = false
var is_winner = false 


# Nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var blindfold = $CanvasLayer/ColorRect
@onready var pause_screen = $CanvasLayer/PauseMenu
# MAP NODES
@onready var minimap_container = $CanvasLayer/MinimapContainer
@onready var map_texture_rect = $CanvasLayer/MinimapContainer/MapTexture
@onready var player_marker = $CanvasLayer/MinimapContainer/MapTexture/PlayerMarker
@onready var message_label: Label

# Minimap data
var map_width_cells: float = 21.0
var map_height_cells: float = 21.0
var cell_size_world: float = 7.0 # grid size
@onready var timer_label = $CanvasLayer/TimerLabel

# Screens
@onready var death_screen: ColorRect
@onready var win_screen: ColorRect
@onready var win_label: Label
@onready var death_label: Label

# SFX
@onready var walk: AudioStreamPlayer = $walk
@onready var run: AudioStreamPlayer = $run
@onready var breathing: AudioStreamPlayer = $breathing
var breathing_tween: Tween
var breathing_run_timer = 0.0
var default_breathing_volume = -5.0 #

# STATE VARIABLE
var is_covering_eyes = false 

func _ready():
	add_to_group("player")
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create the Message Label
	if not has_node("CanvasLayer/MessageLabel"):
		message_label = Label.new()
		message_label.name = "MessageLabel"
		message_label.text = ""
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		message_label.position.y = 100 # Move it down a bit from top
		message_label.add_theme_font_size_override("font_size", 32)
		message_label.add_theme_color_override("font_color", Color.YELLOW)
		message_label.modulate.a = 0.0 # Start invisible
		$CanvasLayer.add_child(message_label)
	else:
		message_label = $CanvasLayer/MessageLabel
	
	# Create death screen if it doesn't exist
	if not has_node("CanvasLayer/DeathScreen"):
		death_screen = ColorRect.new()
		death_screen.name = "DeathScreen"
		death_screen.color = Color.BLACK
		death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		death_screen.visible = false
		death_screen.z_index = 100
		
		death_label = Label.new()
		death_label.text = "YOU DIED\n\nPress R to Restart\nPress M for Main Menu"
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		death_label.add_theme_font_size_override("font_size", 48)
		death_label.add_theme_color_override("font_color", Color.RED)
		death_screen.add_child(death_label)
		
		$CanvasLayer.add_child(death_screen)
	else:
		death_screen = $CanvasLayer/DeathScreen
		if death_screen.get_child_count() > 0:
			death_label = death_screen.get_child(0)
		
	# Create Win Screen
	if not has_node("CanvasLayer/WinScreen"):
		win_screen = ColorRect.new()
		win_screen.name = "WinScreen"
		win_screen.color = Color(0, 0.2, 0, 0.9) # Dark Green background
		win_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		win_screen.visible = false
		win_screen.z_index = 101 # Above death screen
		
		win_label = Label.new()
		win_label.text = "CONGRATULATIONS!"
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		win_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		win_label.add_theme_font_size_override("font_size", 48)
		win_label.add_theme_color_override("font_color", Color.GREEN)
		win_screen.add_child(win_label)
		
		$CanvasLayer.add_child(win_screen)
	else:
		win_screen = $CanvasLayer/WinScreen
		if win_screen.get_child_count() > 0:
			win_label = win_screen.get_child(0)
	
	EnemyManager.register_player(self)
	time_left = level_time_limit

func _input(event):
	# Handle Pause (Only if playing)
	if event.is_action_pressed("pause") and not is_dead and not is_winner:
		toggle_pause()
	
	if get_tree().paused:
		return
		
	# Handle Restart OR Main Menu (Available in Win OR Death screen)
	if is_dead or is_winner:
		if event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
		if Input.is_action_just_pressed("restart"):
			restart_game()
			
		# Press 'M' to go to Main Menu
		if event is InputEventKey and event.pressed and event.keycode == KEY_M:
			return_to_main_menu()
			
		return
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	# Stop if dead, paused, OR won
	if is_dead or get_tree().paused or is_winner:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if is_game_active:
		time_left -= delta
		elapsed_time += delta
		var minutes = floor(time_left / 60)
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		if time_left <= 0:
			time_left = 0
			timer_label.text = "00:00"
			game_over()
			
	if Input.is_action_just_pressed("cover_eyes"):
		is_covering_eyes = !is_covering_eyes 

	# Check for 'minimap_container.visible' to prevent movement
	if is_covering_eyes and not minimap_container.visible:
		set_state_moving()
		
		var current_speed = walk_speed
		
		var is_running = Input.is_action_pressed("run")
		
		if Input.is_action_pressed("run"):
			current_speed = run_speed
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			if is_running:
				# 1. Count up time
				breathing_run_timer += delta 
				
				if not run.playing:
					run.play()
				
				# 2. Only play breathing if timer > 2.0 seconds
				if breathing_run_timer >= 2.0 and not breathing.playing:
					if breathing_tween: breathing_tween.kill()
				
					breathing.volume_db = default_breathing_volume 
					breathing.play()
					
				walk.stop()
			else:
				# Reset timer and stop breathing if we switch to walking
				breathing_run_timer = 0.0
				stop_breathing_softly()
				
				if not walk.playing:
					walk.play()
				run.stop()

			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			# Reset timer and stop breathing if we stop moving completely
			breathing_run_timer = 0.0
			stop_breathing_softly()
			
			walk.stop()
			run.stop()
			
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
			
	else:
		if not is_covering_eyes:
			set_state_sight()
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	check_looking_up()
	update_minimap_marker()

# --- VISUAL HELPERS ---
func set_state_moving():
	blindfold.visible = true
	blindfold.color.a = 0.6

func set_state_sight():
	blindfold.visible = false
	blindfold.color.a = 0.0

func initialize_minimap(map_data: Array, w: int, h: int, grid_cell_size: float = 2.0):
	map_width_cells = float(w)
	map_height_cells = float(h)
	cell_size_world = grid_cell_size
	
	print("Minimap Initialized: ", w, "x", h, " CellSize:", cell_size_world)
	
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for x in range(w):
		for y in range(h):
			if map_data[x][y] == 1:
				img.set_pixel(x, y, Color.BLACK)
			else:
				img.set_pixel(x, y, Color(0.8, 0.8, 0.8, 0.5))
	
	var tex = ImageTexture.create_from_image(img)
	map_texture_rect.texture = tex
	
func check_looking_up():
	var _forward = camera.global_transform.basis.z
	var look_dir = -camera.global_transform.basis.z
	var dot = look_dir.dot(Vector3.UP)
	
	if dot > 0.85:
		minimap_container.visible = true
	else:
		minimap_container.visible = false
		
func update_minimap_marker():
	if not minimap_container.visible: return
	
	var grid_pos_x = global_position.x / cell_size_world
	var grid_pos_z = global_position.z / cell_size_world
	
	var ratio_x = grid_pos_x / map_width_cells
	var ratio_y = grid_pos_z / map_height_cells
	
	var ui_width = map_texture_rect.size.x
	var ui_height = map_texture_rect.size.y
	
	var final_x = (ratio_x * ui_width) - (player_marker.size.x / 2.0)
	var final_y = (ratio_y * ui_height) - (player_marker.size.y / 2.0)
	
	player_marker.position = Vector2(final_x, final_y)
	player_marker.rotation = -rotation.y
	
func game_over():
	print("GAME OVER - TIME IS UP")
	is_game_active = false
	die()

func die():
	if is_dead: return
	print("PLAYER DIED!")
	is_dead = true
	is_game_active = false
	
	if death_screen:
		death_screen.visible = true
		if death_label:
			death_label.text = "YOU DIED\n\nPress R to Restart\nPress M for Main Menu"
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	velocity = Vector3.ZERO
	
func restart_game():
	get_tree().paused = false # Unpause if coming from pause menu
	get_tree().reload_current_scene()
	
func toggle_pause():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	
	if new_pause_state:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pause_screen: pause_screen.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if pause_screen: pause_screen.visible = false

# --- ADD TIME FUNCTION ---
func add_time(amount: float):
	time_left += amount
	
	# Show the popup text!
	show_message("Checkpoint Reached!\n+%d Seconds" % amount)
	
	# (Your existing timer update code...)
	var minutes = floor(time_left / 60)
	var seconds = int(time_left) % 60
	if timer_label:
		timer_label.text = "%02d:%02d" % [minutes, seconds]
	

# --- WIN FUNCTION ---
func win_game():
	if is_dead or is_winner: return
	
	is_winner = true
	is_game_active = false
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- 1. Calculate Time Taken (Elapsed) ---
	var taken_min = floor(elapsed_time / 60)
	var taken_sec = int(elapsed_time) % 60
	
	# --- 2. Calculate Time Remaining (Left) ---
	var left_min = floor(time_left / 60)
	var left_sec = int(time_left) % 60
	
	# Updated text with instructions
	if win_label:
		# We use a multi-line string to show both stats nicely
		win_label.text = "CONGRATULATIONS!\n\nTime Taken: %02d:%02d\nTime Bonus: %02d:%02d\n\nPress R to Play Again\nPress M for Main Menu" % [taken_min, taken_sec, left_min, left_sec]
	
	if win_screen:
		win_screen.visible = true
	
	velocity = Vector3.ZERO

func return_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
	
	
func show_message(text: String, duration: float = 2.0):
	if message_label:
		message_label.text = text
		message_label.modulate.a = 1.0 # Make visible
		
		# Create a tween to fade it out
		var tween = create_tween()
		tween.tween_interval(duration) # Wait
		tween.tween_property(message_label, "modulate:a", 0.0, 1.0) # Fade out

func stop_breathing_softly():
	# If it's not playing, we don't need to fade
	if not breathing.playing:
		return
		
	# If we are already fading out (tween exists and is running), don't start a new one
	if breathing_tween and breathing_tween.is_valid():
		return

	# Create a new tween
	breathing_tween = create_tween()
	
	# 1. Fade volume to -80 dB (silence) over 1.0 second
	breathing_tween.tween_property(breathing, "volume_db", -80.0, 8.0)
	
	# 2. When the fade is done, actually stop the player
	breathing_tween.tween_callback(breathing.stop)
