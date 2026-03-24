class_name GoalDetectionPure
extends RefCounted
## Pure goal detection logic — no Node/scene tree dependencies.
## Checks if the ball has crossed the goal line between posts and below the crossbar.

const GOAL_MOUTH_TOP := 96.0
const GOAL_MOUTH_BOTTOM := 144.0
const GOAL_LEFT_X := 0.0
const GOAL_RIGHT_X := 320.0
const GOAL_DEPTH := 6.0
const CROSSBAR_HEIGHT := 8.0
const POST_HIT_ENERGY_FACTOR := 0.7


## Check if the ball position constitutes a goal.
## Returns {"is_goal": bool, "side": String} where side is "left" or "right".
func check_goal(ball_pos: Vector2, ball_height: float, ball_in_play: bool) -> Dictionary:
	if not ball_in_play:
		return {"is_goal": false, "side": ""}

	if ball_height > CROSSBAR_HEIGHT:
		return {"is_goal": false, "side": ""}

	if not is_in_goal_mouth(ball_pos.y):
		return {"is_goal": false, "side": ""}

	if ball_pos.x <= GOAL_LEFT_X:
		return {"is_goal": true, "side": "left"}
	elif ball_pos.x >= GOAL_RIGHT_X:
		return {"is_goal": true, "side": "right"}

	return {"is_goal": false, "side": ""}


## Check if the ball Y position is between the goalposts.
func is_in_goal_mouth(ball_y: float) -> bool:
	return ball_y >= GOAL_MOUTH_TOP and ball_y <= GOAL_MOUTH_BOTTOM


## Apply energy loss after hitting a goalpost.
func apply_post_energy_loss(vel: Vector2) -> Vector2:
	return vel * POST_HIT_ENERGY_FACTOR
