extends Node

#enemy manager- autoload singleton for enemy comms

signal player_spotted(position: Vector3)

#reference to player
var player: CharacterBody3D = null

#list of all active enemies
var enemies: Array[Node] = []

func register_enemy(enemy: Node) -> void:
	if enemy not in enemies:
		enemies.append(enemy)
		
func unregister_enemy(enemy: Node) -> void:
	enemies.erase(enemy)
	
func register_player(player_node: CharacterBody3D) -> void:
	player = player_node

func alert_enemies(spotted_position: Vector3) -> void:
	player_spotted.emit(spotted_position)
	
func get_player() -> CharacterBody3D:
	return player
