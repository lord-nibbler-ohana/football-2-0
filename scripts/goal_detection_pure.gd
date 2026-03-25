class_name GoalDetectionPure
extends RefCounted
## Pure goal detection logic — no Node/scene tree dependencies.
## Checks if the ball has crossed the goal line between posts and below the crossbar.
## Vertical pitch: goals at top and bottom, mouth extends along X axis.

const GOAL_MOUTH_LEFT := PitchGeometry.GOAL_MOUTH_LEFT
const GOAL_MOUTH_RIGHT := PitchGeometry.GOAL_MOUTH_RIGHT
const GOAL_TOP_Y := PitchGeometry.GOAL_TOP_Y
const GOAL_BOTTOM_Y := PitchGeometry.GOAL_BOTTOM_Y
const GOAL_DEPTH := PitchGeometry.GOAL_DEPTH
const CROSSBAR_HEIGHT := 8.0
const POST_HIT_ENERGY_FACTOR := 0.7


## Check if the ball position constitutes a goal.
## Returns {"is_goal": bool, "side": String} where side is "top" or "bottom".
func check_goal(ball_pos: Vector2, ball_height: float, ball_in_play: bool) -> Dictionary:
	if not ball_in_play:
		return {"is_goal": false, "side": ""}

	if ball_height > CROSSBAR_HEIGHT:
		return {"is_goal": false, "side": ""}

	if not is_in_goal_mouth(ball_pos.x):
		return {"is_goal": false, "side": ""}

	if ball_pos.y <= GOAL_TOP_Y:
		return {"is_goal": true, "side": "top"}
	elif ball_pos.y >= GOAL_BOTTOM_Y:
		return {"is_goal": true, "side": "bottom"}

	return {"is_goal": false, "side": ""}


## Check if the ball X position is between the goalposts.
func is_in_goal_mouth(ball_x: float) -> bool:
	return ball_x >= GOAL_MOUTH_LEFT and ball_x <= GOAL_MOUTH_RIGHT


## Apply energy loss after hitting a goalpost.
func apply_post_energy_loss(vel: Vector2) -> Vector2:
	return vel * POST_HIT_ENERGY_FACTOR
