extends GutTest
## Tests for BoundaryPure — ball bounce and player clamping.


# ── Ball: inside bounds unchanged ──

func test_ball_inside_bounds_unchanged():
	var result := BoundaryPure.clamp_ball(
		Vector2(300, 360), Vector2(2.0, -1.5))
	assert_eq(result["position"], Vector2(300, 360))
	assert_eq(result["velocity"], Vector2(2.0, -1.5))


# ── Ball: left edge bounce ──

func test_ball_left_edge_bounces():
	var result := BoundaryPure.clamp_ball(
		Vector2(-5, 300), Vector2(-3.0, 1.0))
	assert_eq(result["position"].x, 0.0)
	assert_gt(result["velocity"].x, 0.0, "velocity.x should reflect positive")
	assert_almost_eq(result["velocity"].x, 3.0 * BoundaryPure.BALL_BOUNCE_DAMPING, 0.01)
	assert_eq(result["velocity"].y, 1.0, "velocity.y unchanged")


# ── Ball: right edge bounce ──

func test_ball_right_edge_bounces():
	var result := BoundaryPure.clamp_ball(
		Vector2(PitchGeometry.WORLD_W + 5, 300), Vector2(4.0, 0.0))
	assert_eq(result["position"].x, PitchGeometry.WORLD_W)
	assert_lt(result["velocity"].x, 0.0, "velocity.x should reflect negative")
	assert_almost_eq(result["velocity"].x, -4.0 * BoundaryPure.BALL_BOUNCE_DAMPING, 0.01)


# ── Ball: top edge bounce (outside goal mouth) ──

func test_ball_top_edge_bounces_outside_goal():
	var result := BoundaryPure.clamp_ball(
		Vector2(100, -3), Vector2(1.0, -5.0))
	assert_eq(result["position"].y, 0.0)
	assert_gt(result["velocity"].y, 0.0, "velocity.y should reflect positive")
	assert_almost_eq(result["velocity"].y, 5.0 * BoundaryPure.BALL_BOUNCE_DAMPING, 0.01)


# ── Ball: bottom edge bounce (outside goal mouth) ──

func test_ball_bottom_edge_bounces_outside_goal():
	var result := BoundaryPure.clamp_ball(
		Vector2(500, PitchGeometry.WORLD_H + 2), Vector2(0.0, 3.0))
	assert_eq(result["position"].y, PitchGeometry.WORLD_H)
	assert_lt(result["velocity"].y, 0.0, "velocity.y should reflect negative")


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


# ── Ball: corner — both axes bounce ──

func test_ball_corner_bounces_both_axes():
	var result := BoundaryPure.clamp_ball(
		Vector2(-2, -2), Vector2(-3.0, -4.0))
	assert_eq(result["position"].x, 0.0)
	assert_eq(result["position"].y, 0.0)
	assert_gt(result["velocity"].x, 0.0)
	assert_gt(result["velocity"].y, 0.0)


# ── Ball: goal mouth edge boundary ──

func test_ball_goal_mouth_left_edge_bounces():
	# Just outside goal mouth on the left — should bounce
	var x := PitchGeometry.GOAL_MOUTH_LEFT - 1.0
	var result := BoundaryPure.clamp_ball(
		Vector2(x, -3), Vector2(0.0, -5.0))
	assert_eq(result["position"].y, 0.0, "outside goal mouth should bounce")


func test_ball_goal_mouth_right_edge_no_bounce():
	# Just inside goal mouth on the right — should not bounce
	var x := PitchGeometry.GOAL_MOUTH_RIGHT
	var result := BoundaryPure.clamp_ball(
		Vector2(x, -3), Vector2(0.0, -5.0))
	assert_eq(result["position"].y, -3.0, "inside goal mouth should not bounce")


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
