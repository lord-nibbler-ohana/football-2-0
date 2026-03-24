extends GutTest
## Tests for AftertouchPure — aftertouch logic (curl, loft, dip).

var at: AftertouchPure


func before_each() -> void:
	at = AftertouchPure.new()


# --- Activation / Deactivation ---


func test_not_active_by_default() -> void:
	assert_false(at.is_active(), "Should not be active on creation")


func test_active_after_activation() -> void:
	at.activate(Vector2.RIGHT)
	assert_true(at.is_active(), "Should be active after activate()")


func test_deactivates_after_open_play_window() -> void:
	at.activate(Vector2.RIGHT)
	for i in range(AftertouchPure.OPEN_PLAY_WINDOW):
		at.tick(Vector2.ZERO)
	assert_false(at.is_active(),
		"Should deactivate after OPEN_PLAY_WINDOW ticks")


func test_set_piece_uses_extended_window() -> void:
	at.activate(Vector2.RIGHT, true)
	for i in range(AftertouchPure.OPEN_PLAY_WINDOW):
		at.tick(Vector2.ZERO)
	assert_true(at.is_active(),
		"Should still be active after 12 ticks with set piece window")
	for i in range(AftertouchPure.SET_PIECE_WINDOW - AftertouchPure.OPEN_PLAY_WINDOW):
		at.tick(Vector2.ZERO)
	assert_false(at.is_active(),
		"Should deactivate after SET_PIECE_WINDOW ticks")


func test_cancel_deactivates() -> void:
	at.activate(Vector2.RIGHT)
	at.cancel()
	assert_false(at.is_active(), "cancel() should deactivate immediately")


func test_reset_clears_state() -> void:
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.UP)
	at.reset()
	assert_false(at.is_active())
	assert_eq(at.timer, 0)
	assert_eq(at.kick_direction, Vector2.ZERO)


func test_activate_with_zero_velocity_does_not_activate() -> void:
	at.activate(Vector2.ZERO)
	assert_false(at.is_active(),
		"Zero velocity kick should not activate aftertouch")


func test_reactivation_resets_timer() -> void:
	at.activate(Vector2.RIGHT)
	for i in range(6):
		at.tick(Vector2.ZERO)
	at.activate(Vector2.UP)
	assert_eq(at.timer, AftertouchPure.OPEN_PLAY_WINDOW,
		"Re-activation should reset timer to full window")


# --- Decay ---


func test_strength_is_strongest_at_frame_zero() -> void:
	at.activate(Vector2.RIGHT)
	var first := at.tick(Vector2.UP)
	at.reset()
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.ZERO)  # skip frame 0
	var second := at.tick(Vector2.UP)
	assert_gt(first["velocity_offset"].length(), second["velocity_offset"].length(),
		"Frame 0 should produce strongest effect")


func test_strength_decays_each_frame() -> void:
	at.activate(Vector2.RIGHT)
	var prev_len := 999.0
	for i in range(AftertouchPure.OPEN_PLAY_WINDOW):
		var result := at.tick(Vector2.UP)
		var cur_len: float = result["velocity_offset"].length()
		if cur_len > 0.0:
			assert_lt(cur_len, prev_len, "Offset should decrease each frame")
			prev_len = cur_len


func test_decay_rate_matches_constant() -> void:
	at.activate(Vector2.RIGHT)
	var frame0 := at.tick(Vector2.UP)
	at.reset()
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.ZERO)  # skip frame 0
	var frame1 := at.tick(Vector2.UP)
	var ratio: float = frame1["velocity_offset"].length() / frame0["velocity_offset"].length()
	assert_almost_eq(ratio, AftertouchPure.DECAY_RATE, 0.01,
		"Decay between frames should match DECAY_RATE")


# --- Curl (perpendicular input) ---


func test_perpendicular_input_produces_curl() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.UP)
	assert_gt(result["velocity_offset"].length(), 0.0,
		"Perpendicular input should produce lateral offset")
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001,
		"Pure perpendicular input should not affect vertical")


func test_opposite_perpendicular_curls_other_way() -> void:
	at.activate(Vector2.RIGHT)
	var result_up := at.tick(Vector2.UP)
	at.reset()
	at.activate(Vector2.RIGHT)
	var result_down := at.tick(Vector2.DOWN)
	# Offsets should be opposite directions
	var dot: float = result_up["velocity_offset"].dot(result_down["velocity_offset"])
	assert_lt(dot, 0.0, "Opposite perpendicular inputs should curl in opposite directions")


func test_curl_direction_correct_for_kick_right_input_up() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.UP)
	# perpendicular = Vector2(-kick_dir.y, kick_dir.x) = Vector2(0, 1)
	# UP in Godot is Vector2(0, -1), so dot(UP, perp) = -1
	# offset = Vector2(0, 1) * -1 * CURL_FACTOR = (0, -0.15)
	assert_almost_eq(result["velocity_offset"].y, -AftertouchPure.CURL_FACTOR, 0.01,
		"Kick right + input up should curl in negative Y direction (screen up)")


func test_no_curl_from_parallel_input() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.RIGHT)
	assert_almost_eq(result["velocity_offset"].length(), 0.0, 0.001,
		"Parallel input should produce no lateral curl")


# --- Loft (opposite to travel direction) ---


func test_opposite_input_produces_loft() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.LEFT)
	assert_gt(result["vertical_offset"], 0.0,
		"Opposite input should produce positive vertical offset (loft)")


func test_loft_magnitude_at_frame_zero() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.LEFT)
	# parallel_component = LEFT.dot(RIGHT) = -1, loft = abs(-1) * 0.3 * 1.0
	assert_almost_eq(result["vertical_offset"], AftertouchPure.LOFT_FACTOR, 0.01,
		"Full opposite input at frame 0 should give LOFT_FACTOR vertical offset")


# --- Dip (same as travel direction) ---


func test_same_direction_produces_dip() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.RIGHT)
	assert_lt(result["vertical_offset"], 0.0,
		"Same-direction input should produce negative vertical offset (dip)")


func test_dip_magnitude_at_frame_zero() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.RIGHT)
	# parallel_component = 1, dip = -1 * 0.25 * 1.0
	assert_almost_eq(result["vertical_offset"], -AftertouchPure.DIP_FACTOR, 0.01,
		"Full same-direction input at frame 0 should give -DIP_FACTOR vertical offset")


# --- Compound / Diagonal ---


func test_diagonal_produces_curl_and_loft() -> void:
	# Kick right, input up-left → curl (from up) + loft (from left)
	at.activate(Vector2.RIGHT)
	var input := Vector2(-1, 1).normalized()
	var result := at.tick(input)
	assert_gt(result["velocity_offset"].length(), 0.0, "Should have curl component")
	assert_gt(result["vertical_offset"], 0.0, "Should have loft component")


func test_diagonal_produces_curl_and_dip() -> void:
	# Kick right, input up-right → curl (from up) + dip (from right)
	at.activate(Vector2.RIGHT)
	var input := Vector2(1, 1).normalized()
	var result := at.tick(input)
	assert_gt(result["velocity_offset"].length(), 0.0, "Should have curl component")
	assert_lt(result["vertical_offset"], 0.0, "Should have dip component")


# --- Zero Input ---


func test_zero_input_produces_zero_offset() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.ZERO)
	assert_eq(result["velocity_offset"], Vector2.ZERO)
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001)


func test_zero_input_still_counts_down_window() -> void:
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.ZERO)
	assert_eq(at.timer, AftertouchPure.OPEN_PLAY_WINDOW - 1,
		"Timer should decrement even with zero input")


# --- Inactive aftertouch returns zero ---


func test_tick_when_inactive_returns_zero() -> void:
	var result := at.tick(Vector2.UP)
	assert_eq(result["velocity_offset"], Vector2.ZERO)
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001)


# --- Integration: AftertouchPure + BallPhysicsPure ---


func test_curl_changes_ball_trajectory() -> void:
	var ball := BallPhysicsPure.new()
	var ball_no_curl := BallPhysicsPure.new()

	var kick_vel := Vector2(6.0, 0.0)
	ball.apply_kick(kick_vel, 2.0)
	ball_no_curl.apply_kick(kick_vel, 2.0)

	at.activate(kick_vel)
	for i in range(30):
		if at.is_active():
			var result := at.tick(Vector2.UP)
			ball.velocity += result["velocity_offset"]
			ball.vertical_velocity += result["vertical_offset"]
		ball.tick()
		ball_no_curl.tick()

	# Ball with curl should have different Y velocity than without
	assert_ne(ball.velocity.y, ball_no_curl.velocity.y,
		"Curl should deflect ball laterally compared to no-curl kick")


func test_loft_increases_max_height() -> void:
	var ball := BallPhysicsPure.new()
	var ball_no_loft := BallPhysicsPure.new()
	var at_loft := AftertouchPure.new()

	var kick_vel := Vector2(6.0, 0.0)
	ball.apply_kick(kick_vel, 3.0)
	ball_no_loft.apply_kick(kick_vel, 3.0)

	at_loft.activate(kick_vel)
	var max_h := 0.0
	var max_h_no := 0.0
	for i in range(60):
		if at_loft.is_active():
			var result := at_loft.tick(Vector2.LEFT)  # opposite = loft
			ball.velocity += result["velocity_offset"]
			ball.vertical_velocity += result["vertical_offset"]
		ball.tick()
		ball_no_loft.tick()
		if ball.height > max_h:
			max_h = ball.height
		if ball_no_loft.height > max_h_no:
			max_h_no = ball_no_loft.height

	assert_gt(max_h, max_h_no,
		"Loft aftertouch should increase max height")


func test_dip_reduces_max_height() -> void:
	var ball := BallPhysicsPure.new()
	var ball_no_dip := BallPhysicsPure.new()
	var at_dip := AftertouchPure.new()

	var kick_vel := Vector2(6.0, 0.0)
	ball.apply_kick(kick_vel, 4.0)
	ball_no_dip.apply_kick(kick_vel, 4.0)

	at_dip.activate(kick_vel)
	var max_h := 0.0
	var max_h_no := 0.0
	for i in range(60):
		if at_dip.is_active():
			var result := at_dip.tick(Vector2.RIGHT)  # same direction = dip
			ball.velocity += result["velocity_offset"]
			ball.vertical_velocity = maxf(
				ball.vertical_velocity + result["vertical_offset"], 0.0)
		ball.tick()
		ball_no_dip.tick()
		if ball.height > max_h:
			max_h = ball.height
		if ball_no_dip.height > max_h_no:
			max_h_no = ball_no_dip.height

	assert_lt(max_h, max_h_no,
		"Dip aftertouch should reduce max height")
