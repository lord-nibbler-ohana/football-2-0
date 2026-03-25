class_name BoundaryPure
extends RefCounted
## Pure boundary enforcement — ball bounce and player clamping at world edges.
## No goal kicks, corners, or throw-ins — just bounce the ball back with dampening.

const BALL_BOUNCE_DAMPING := 0.5
const PLAYER_MARGIN := 2.0


## Clamp ball position within world bounds. Reflects and dampens velocity on edge hit.
## Returns {"position": Vector2, "velocity": Vector2}.
## Exception: does NOT bounce within the goal mouth at top/bottom edges (lets goals work).
static func clamp_ball(pos: Vector2, vel: Vector2) -> Dictionary:
	var out_pos := pos
	var out_vel := vel

	# Left edge
	if out_pos.x < 0.0:
		out_pos.x = 0.0
		out_vel.x = absf(out_vel.x) * BALL_BOUNCE_DAMPING

	# Right edge
	if out_pos.x > PitchGeometry.WORLD_W:
		out_pos.x = PitchGeometry.WORLD_W
		out_vel.x = -absf(out_vel.x) * BALL_BOUNCE_DAMPING

	# Top edge — skip goal mouth
	if out_pos.y < 0.0:
		if _is_in_goal_mouth_x(out_pos.x):
			pass  # Let goal detection handle it
		else:
			out_pos.y = 0.0
			out_vel.y = absf(out_vel.y) * BALL_BOUNCE_DAMPING

	# Bottom edge — skip goal mouth
	if out_pos.y > PitchGeometry.WORLD_H:
		if _is_in_goal_mouth_x(out_pos.x):
			pass  # Let goal detection handle it
		else:
			out_pos.y = PitchGeometry.WORLD_H
			out_vel.y = -absf(out_vel.y) * BALL_BOUNCE_DAMPING

	return {"position": out_pos, "velocity": out_vel}


## Clamp player position within world bounds (with small margin).
static func clamp_player(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, PLAYER_MARGIN, PitchGeometry.WORLD_W - PLAYER_MARGIN),
		clampf(pos.y, PLAYER_MARGIN, PitchGeometry.WORLD_H - PLAYER_MARGIN))


## Check if X coordinate falls within the goal mouth range.
static func _is_in_goal_mouth_x(x: float) -> bool:
	return x >= PitchGeometry.GOAL_MOUTH_LEFT and x <= PitchGeometry.GOAL_MOUTH_RIGHT
