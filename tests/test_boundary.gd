extends GutTest
## Tests for BoundaryPure — ball bounce and player clamping.


# ── Ball: inside bounds unchanged ──

func test_ball_inside_bounds_unchanged():
	var result := BoundaryPure.clamp_ball(
		Vector2(300, 360), Vector2(2.0, -1.5))
	assert_eq(result["position"], Vector2(300, 360))
	assert_eq(result["velocity"], Vector2(2.0, -1.5))
	assert_eq(result["throwin"], "", "no throw-in inside bounds")
	assert_eq(result["goal_line"], "", "no goal line inside bounds")


# ── Ball: left sideline triggers throw-in ──

func test_ball_left_sideline_throwin():
	var result := BoundaryPure.clamp_ball(
		Vector2(PitchGeometry.SIDELINE_LEFT - 5, 300), Vector2(-3.0, 1.0))
	assert_eq(result["position"].x, PitchGeometry.SIDELINE_LEFT, "clamped to sideline")
	assert_eq(result["velocity"], Vector2.ZERO, "velocity zeroed on throw-in")
	assert_eq(result["throwin"], "left", "left throw-in triggered")


# ── Ball: right sideline triggers throw-in ──

func test_ball_right_sideline_throwin():
	var result := BoundaryPure.clamp_ball(
		Vector2(PitchGeometry.SIDELINE_RIGHT + 5, 300), Vector2(4.0, 0.0))
	assert_eq(result["position"].x, PitchGeometry.SIDELINE_RIGHT, "clamped to sideline")
	assert_eq(result["velocity"], Vector2.ZERO, "velocity zeroed on throw-in")
	assert_eq(result["throwin"], "right", "right throw-in triggered")


# ── Ball: top goal line triggers goal_line (outside goal mouth) ──

func test_ball_top_goal_line_outside_goal_mouth():
	var result := BoundaryPure.clamp_ball(
		Vector2(100, PitchGeometry.GOAL_TOP_Y - 3), Vector2(1.0, -5.0))
	assert_eq(result["position"].y, PitchGeometry.GOAL_TOP_Y, "clamped to goal line")
	assert_eq(result["velocity"], Vector2.ZERO, "velocity zeroed on goal line out")
	assert_eq(result["goal_line"], "top", "top goal line triggered")


# ── Ball: bottom goal line triggers goal_line (outside goal mouth) ──

func test_ball_bottom_goal_line_outside_goal_mouth():
	var result := BoundaryPure.clamp_ball(
		Vector2(500, PitchGeometry.GOAL_BOTTOM_Y + 2), Vector2(0.0, 3.0))
	assert_eq(result["position"].y, PitchGeometry.GOAL_BOTTOM_Y, "clamped to goal line")
	assert_eq(result["velocity"], Vector2.ZERO, "velocity zeroed on goal line out")
	assert_eq(result["goal_line"], "bottom", "bottom goal line triggered")


# ── Ball: top goal mouth — no bounce ──

func test_ball_top_goal_mouth_no_bounce():
	var result := BoundaryPure.clamp_ball(
		Vector2(300, -3), Vector2(0.0, -5.0))
	# Position and velocity should pass through (goal detection handles it)
	assert_eq(result["position"].y, -3.0, "should not clamp within goal mouth")
	assert_eq(result["velocity"].y, -5.0, "velocity should not reflect in goal mouth")


# ── Ball: bottom goal mouth — no bounce ──

func test_ball_bottom_goal_mouth_no_bounce():
	var result := BoundaryPure.clamp_ball(
		Vector2(300, PitchGeometry.WORLD_H + 5), Vector2(0.0, 4.0))
	assert_eq(result["position"].y, PitchGeometry.WORLD_H + 5, "should not clamp within goal mouth")
	assert_eq(result["velocity"].y, 4.0, "velocity should not reflect in goal mouth")


# ── Ball: corner — sideline triggers throw-in (takes priority over goal line bounce) ──

func test_ball_corner_triggers_throwin():
	var result := BoundaryPure.clamp_ball(
		Vector2(PitchGeometry.SIDELINE_LEFT - 5, -2), Vector2(-3.0, -4.0))
	assert_eq(result["throwin"], "left", "sideline crossing triggers throw-in")
	assert_eq(result["velocity"], Vector2.ZERO, "velocity zeroed on throw-in")


# ── Ball: goal mouth edge boundary ──

func test_ball_goal_mouth_left_edge_triggers_goal_line():
	# Just outside goal mouth on the left — should trigger goal line out
	var x := PitchGeometry.GOAL_MOUTH_LEFT - 1.0
	var result := BoundaryPure.clamp_ball(
		Vector2(x, PitchGeometry.GOAL_TOP_Y - 3), Vector2(0.0, -5.0))
	assert_eq(result["goal_line"], "top", "outside goal mouth should trigger goal line")
	assert_eq(result["position"].y, PitchGeometry.GOAL_TOP_Y, "clamped to goal line")


func test_ball_goal_mouth_right_edge_no_goal_line():
	# Just inside goal mouth on the right — should pass through for goal detection
	var x := PitchGeometry.GOAL_MOUTH_RIGHT
	var result := BoundaryPure.clamp_ball(
		Vector2(x, PitchGeometry.GOAL_TOP_Y - 3), Vector2(0.0, -5.0))
	assert_eq(result["goal_line"], "", "inside goal mouth should not trigger goal line")
	assert_eq(result["position"].y, PitchGeometry.GOAL_TOP_Y - 3, "inside goal mouth should not clamp")


# ── Player: inside bounds unchanged ──

func test_player_inside_bounds_unchanged():
	var result := BoundaryPure.clamp_player(Vector2(300, 360))
	assert_eq(result, Vector2(300, 360))


# ── Player: clamped at edges ──

func test_player_clamped_at_left_edge():
	var result := BoundaryPure.clamp_player(Vector2(-10, 300))
	assert_eq(result.x, BoundaryPure.PLAYER_MARGIN)


func test_player_clamped_at_right_edge():
	var result := BoundaryPure.clamp_player(Vector2(700, 300))
	assert_eq(result.x, PitchGeometry.WORLD_W - BoundaryPure.PLAYER_MARGIN)


func test_player_clamped_at_top_edge():
	var result := BoundaryPure.clamp_player(Vector2(300, -5))
	assert_eq(result.y, BoundaryPure.PLAYER_MARGIN)


func test_player_clamped_at_bottom_edge():
	var result := BoundaryPure.clamp_player(Vector2(300, 800))
	assert_eq(result.y, PitchGeometry.WORLD_H - BoundaryPure.PLAYER_MARGIN)
