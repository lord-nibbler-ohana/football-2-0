class_name PossessionPure
extends RefCounted
## Pure possession and dribble logic — no Node dependencies.
## Determines which player has the ball based on proximity.

const PICKUP_RADIUS := 10.0
const DRIBBLE_RADIUS := 14.0

## Index of the player currently possessing the ball, or -1.
var possessor_index: int = -1


## Check which player (if any) should have possession.
## player_positions: Array of Vector2 positions.
## ball_pos: current ball position.
## ball_airborne: true if ball is in the air (no pickup while airborne).
## Returns the index of the possessing player, or -1 if nobody.
func check_possession(player_positions: Array, ball_pos: Vector2,
		ball_airborne: bool = false) -> int:
	if ball_airborne:
		possessor_index = -1
		return possessor_index

	var closest_dist := PICKUP_RADIUS
	var closest_idx := -1

	for i in range(player_positions.size()):
		var dist: float = player_positions[i].distance_to(ball_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	possessor_index = closest_idx
	return possessor_index


## Calculate where the ball should be when dribbled by a player.
## facing: normalised direction the player is facing.
static func get_dribble_position(player_pos: Vector2, facing: Vector2) -> Vector2:
	if facing == Vector2.ZERO:
		# Default to dribbling south if no direction set
		return player_pos + Vector2.DOWN * DRIBBLE_RADIUS
	return player_pos + facing.normalized() * DRIBBLE_RADIUS


## Reset possession state.
func reset() -> void:
	possessor_index = -1
