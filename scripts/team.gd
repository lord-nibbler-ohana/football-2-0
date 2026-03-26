extends Node2D
## Team logic — formation, player spawning, team-level state.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@export var team_name: String = ""
@export var is_home: bool = true
@export_enum("4-4-2", "4-5-1", "4-3-3", "5-4-1") var formation: int = 0

## Kit configuration.
@export var team_id: int = 0

@export var kit_primary: Color = Color.RED
@export var kit_secondary: Color = Color.BLUE
@export var kit_style: int = 0  # 0=SOLID, 1=VSTRIPES, 2=HSTRIPES


func _ready() -> void:
	# Derive team_id from home/away
	team_id = 0 if is_home else 1

	# Set default kit colors based on home/away
	if is_home:
		kit_primary = Color(0.8, 0.1, 0.1)   # Red
		kit_secondary = Color(1.0, 1.0, 1.0)  # White
	else:
		kit_primary = Color(0.1, 0.3, 0.8)   # Blue
		kit_secondary = Color(1.0, 0.8, 0.0)  # Yellow

	_spawn_players()
	_apply_kit_to_players()


## Spawn player instances at formation positions.
func _spawn_players() -> void:
	var slots: Array
	if is_home:
		slots = FormationPure.get_positions(formation)
	else:
		slots = FormationPure.get_away_positions(formation)

	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		var player: CharacterBody2D = PLAYER_SCENE.instantiate()
		player.position = slot["position"]
		player.formation_position = slot["position"]
		player.team_id = team_id
		player.role = slot["role"]
		player.is_goalkeeper = FormationPure.is_goalkeeper_role(slot["role"])
		player.jersey_number = i + 1
		player.is_home = is_home
		player._formation_slot = i
		add_child(player)


## Apply kit colors to all player children.
func _apply_kit_to_players() -> void:
	for child in get_children():
		if child.has_method("set_kit"):
			child.set_kit(kit_style, kit_primary, kit_secondary)


## Get all player nodes.
func get_players() -> Array:
	var players: Array = []
	for child in get_children():
		if child is CharacterBody2D:
			players.append(child)
	return players
