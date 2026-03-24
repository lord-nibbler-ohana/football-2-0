extends Node2D
## Team logic — formation, player switching, team-level state.

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

	# Apply kit to all child players
	_apply_kit_to_players()


## Apply kit colors to all player children.
func _apply_kit_to_players() -> void:
	for child in get_children():
		if child.has_method("set_kit"):
			child.set_kit(kit_style, kit_primary, kit_secondary)
