extends Node2D
## Team logic — formation, player spawning, team-level state.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

## 5v5 formation positions for each team half.
## Vertical pitch: home at bottom (attacks upward), away at top (attacks downward).
## Positions derived from PitchGeometry: playing area 520×640, margins 40×40.
const HOME_POSITIONS: Array[Vector2] = [
	Vector2(300, 600),   # GK — near bottom goal
	Vector2(220, 545),   # DEF (left)
	Vector2(380, 545),   # DEF (right)
	Vector2(300, 460),   # MID
	Vector2(300, 392),   # FWD — near center
]
const AWAY_POSITIONS: Array[Vector2] = [
	Vector2(300, 120),   # GK — near top goal
	Vector2(220, 175),   # DEF (left)
	Vector2(380, 175),   # DEF (right)
	Vector2(300, 260),   # MID
	Vector2(300, 328),   # FWD — near center
]

@export var team_name: String = ""
@export var is_home: bool = true

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
	var positions: Array[Vector2] = HOME_POSITIONS if is_home else AWAY_POSITIONS
	for i in range(positions.size()):
		var player: CharacterBody2D = PLAYER_SCENE.instantiate()
		player.position = positions[i]
		player.formation_position = positions[i]
		player.team_id = team_id
		player.is_goalkeeper = (i == 0)
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
