extends Node2D
## Team logic — formation, player spawning, team-level state.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

## 5v5 formation positions for each team half.
const HOME_POSITIONS: Array[Vector2] = [
	Vector2(24, 120),   # GK
	Vector2(64, 80),    # DEF (top)
	Vector2(64, 160),   # DEF (bottom)
	Vector2(110, 120),  # MID
	Vector2(145, 120),  # FWD
]
const AWAY_POSITIONS: Array[Vector2] = [
	Vector2(296, 120),  # GK
	Vector2(256, 80),   # DEF (top)
	Vector2(256, 160),  # DEF (bottom)
	Vector2(210, 120),  # MID
	Vector2(175, 120),  # FWD
]

@export var team_name: String = ""
@export var is_home: bool = true

## Kit configuration.
@export var kit_primary: Color = Color.RED
@export var kit_secondary: Color = Color.BLUE
@export var kit_style: int = 0  # 0=SOLID, 1=VSTRIPES, 2=HSTRIPES


func _ready() -> void:
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
	var positions: Array[Vector2] = HOME_POSITIONS if is_home else AWAY_POSITIONS
	for i in range(positions.size()):
		var player: CharacterBody2D = PLAYER_SCENE.instantiate()
		player.position = positions[i]
		player.formation_position = positions[i]
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
