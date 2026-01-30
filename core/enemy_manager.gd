extends Node

signal player_spotted(position: Vector3)

var player: CharacterBody3D = null
var enemies: Array[Node] = []

func register_enemy(enemy: Node) -> void:
	if enemy not in enemies:
		enemies.append(enemy)
		if enemy.has_method("_on_player_spotted"):
			player_spotted.connect(enemy._on_player_spotted)
		
func unregister_enemy(enemy: Node) -> void:
	if enemy.has_method("_on_player_spotted"):
		if player_spotted.is_connected(enemy._on_player_spotted):
			player_spotted.disconnect(enemy._on_player_spotted)
	enemies.erase(enemy)
	
func register_player(player_node: CharacterBody3D) -> void:
	player = player_node
	
#global alert 1st option
func alert_enemies(spotted_position: Vector3) -> void:
	player_spotted.emit(spotted_position)

#ranged alert 2nd option
func alert_enemies_in_range(spotted_position: Vector3, alert_range: float = 50.0) -> void:
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = enemy.global_position.distance_to(spotted_position)
			if distance <= alert_range and enemy.has_method("_on_player_spotted"):
				enemy._on_player_spotted(spotted_position)
	
func get_player() -> CharacterBody3D:
	return player
