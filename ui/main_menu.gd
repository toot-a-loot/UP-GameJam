extends Control

const INGAME = preload("uid://bcvlx6vixaf87")

# --- Nodes ---
@onready var camera_3d: Camera3D = $"../Camera3D"
@onready var character_pivot: Marker3D = $"../CharacterPivot"

# UI Containers
@onready var main_menu_ui: Control = $MainMenu
@onready var char_menu_ui: Control = $CharacterMenu

# UI Elements (Character Menu)
@onready var lbl_name: Label = $CharacterMenu/HBoxContainer/InfoBox/Name
@onready var lbl_desc: Label = $CharacterMenu/HBoxContainer/InfoBox/Description

# --- Configuration ---
@export var transition_duration: float = 1.5

# COORDINATES: Adjust these numbers to fit your specific scene visually
# 1. Main Menu View
var cam_pos_main = Vector3(-0.15, 2.6, 2.0)
var model_pos_main = Vector3(0.35, 0.5, 0.77) 
var model_rotation_main = Vector3(0.0,-27,0.0)

# 2. Character Select View (x=7 area)
var cam_pos_char = Vector3(7.0, 2.6, 2.0)
var model_pos_char = Vector3(7.0, 1.0, 0.0) 
var model_rotation_char = Vector3(0.0, 0.0,0.0)

# --- Data ---
@export var character_scenes: Array[PackedScene]
@export var character_names: Array[String] = ["John", "Jane", "Soldier"]
@export var character_descs: Array[String] = ["Basic guy", "Basic girl", "Combat ready"]

var current_index: int = 0

func _ready() -> void:
	# 1. Set initial Visibility
	main_menu_ui.visible = true
	char_menu_ui.visible = false
	
	# 2. Set initial positions
	camera_3d.start_position = cam_pos_main # Update variable in camera script
	character_pivot.position = model_pos_main
	character_pivot.rotation_degrees = model_rotation_main
	
	# 3. Load first model
	update_character_model()

# --- Transition Logic ---

func switch_to_char_menu():
	# Move Camera to X=7
	tween_transition(camera_3d, "start_position", cam_pos_char)
	# Move Model to X=7
	tween_transition(character_pivot, "position", model_pos_char)
	tween_transition(character_pivot, "rotation", model_rotation_char)
	
	# Swap UI
	main_menu_ui.visible = false
	char_menu_ui.visible = true

func switch_to_main_menu():
	# Move Camera back
	tween_transition(camera_3d, "start_position", cam_pos_main)
	# Move Model back (It stays selected!)
	tween_transition(character_pivot, "position", model_pos_main)
	tween_transition(character_pivot, "rotation", (model_rotation_main + Vector3(0.0,20.0,0.0)))
	# Swap UI
	char_menu_ui.visible = false
	main_menu_ui.visible = true

func tween_transition(obj, property, target_val):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(obj, property, target_val, transition_duration)

# --- Signal Connections ---

# Main Menu Buttons
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(INGAME)

func _on_character_button_pressed() -> void:
	switch_to_char_menu()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

# Character Menu Buttons
func _on_prev_button_pressed() -> void: # Connect BtnPrev
	current_index = (current_index - 1 + character_scenes.size()) % character_scenes.size()
	update_character_model()

func _on_next_button_pressed() -> void: # Connect BtnNext
	current_index = (current_index + 1) % character_scenes.size()
	update_character_model()

func _on_back_button_pressed() -> void: # Connect BtnBack
	switch_to_main_menu()

func _on_select_button_pressed() -> void: # Connect BtnSelect
	switch_to_main_menu()

# --- Model Swapping ---

func update_character_model() -> void:
	# Update Text
	if current_index < character_names.size():
		lbl_name.text = character_names[current_index]
	if current_index < character_descs.size():
		lbl_desc.text = character_descs[current_index]

	# Swap 3D Model
	for child in character_pivot.get_children():
		child.queue_free()
	
	if character_scenes.size() > current_index and character_scenes[current_index]:
		var new_model = character_scenes[current_index].instantiate()
		character_pivot.add_child(new_model)
