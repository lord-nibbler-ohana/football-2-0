class_name BoundaryPure
extends RefCounted
## Pure boundary enforcement — ball bounce and player clamping at world edges.
## Detects throw-ins at sidelines, bounces at goal-line edges.

const BALL_BOUNCE_DAMPING := 0.5
const PLAYER_MARGIN := 2.0

## How far past the sideline the ball must travel to trigger a throw-in.
## Using the actual sideline positions (not world edges) for realism.
const THROWIN_MARGIN := 2.0


## Clamp ball position within world bounds. Reflects and dampens velocity on edge hit.
## Returns {"position": Vector2, "velocity": Vector2, "throwin": String}.
## "throwin" is "" for no throw-in, "left" or "right" when ball crosses a sideline.
## Exception: does NOT bounce within the goal mouth at top/bottom edges (lets goals work).
static func clamp_ball(pos: Vector2, vel: Vector2) -> Dictionary:
	var out_pos := pos
	var out_vel := vel
	var throwin := ""
	var goal_line := ""

	# Left sideline — throw-in
	if out_pos.x < PitchGeometry.SIDELINE_LEFT - THROWIN_MARGIN:
		throwin = "left"
		out_pos.x = PitchGeometry.SIDELINE_LEFT
		out_vel = Vector2.ZERO

	# Right sideline — throw-in
	elif out_pos.x > PitchGeometry.SIDELINE_RIGHT + THROWIN_MARGIN:
		throwin = "right"
		out_pos.x = PitchGeometry.SIDELINE_RIGHT
		out_vel = Vector2.ZERO

	# Goal line detection — outside goal mouth triggers goal kick / corner.
	# Inside goal mouth, let goal detection handle it.
	if throwin == "":
		# Top goal line
		if out_pos.y <= PitchGeometry.GOAL_TOP_Y:
			if _is_in_goal_mouth_x(out_pos.x):
				# Safety clamp at world edge for goal-mouth pass-through
				if out_pos.y < 0.0:
					pass  # Let goal detection handle it
			else:
				goal_line = "top"
				out_pos.y = PitchGeometry.GOAL_TOP_Y
				out_vel = Vector2.ZERO

		# Bottom goal line
		elif out_pos.y >= PitchGeometry.GOAL_BOTTOM_Y:
			if _is_in_goal_mouth_x(out_pos.x):
				# Safety clamp at world edge for goal-mouth pass-through
				if out_pos.y > PitchGeometry.WORLD_H:
					pass  # Let goal detection handle it
			else:
				goal_line = "bottom"
				out_pos.y = PitchGeometry.GOAL_BOTTOM_Y
				out_vel = Vector2.ZERO

	return {"position": out_pos, "velocity": out_vel, "throwin": throwin,
		"goal_line": goal_line}


## Clamp player position within world bounds (with small margin).
static func clamp_player(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, PLAYER_MARGIN, PitchGeometry.WORLD_W - PLAYER_MARGIN),
		clampf(pos.y, PLAYER_MARGIN, PitchGeometry.WORLD_H - PLAYER_MARGIN))


## Check if X coordinate falls within the goal mouth range.
static func _is_in_goal_mouth_x(x: float) -> bool:
	return x >= PitchGeometry.GOAL_MOUTH_LEFT and x <= PitchGeometry.GOAL_MOUTH_RIGHT
