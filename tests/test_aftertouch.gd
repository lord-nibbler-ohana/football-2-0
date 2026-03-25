extends GutTest
## Tests for AftertouchPure — aftertouch logic (spin curl, loft, dip).

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
		"Should still be active after open play window with set piece")
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
	assert_gt(absf(first["spin_offset"]), absf(second["spin_offset"]),
		"Frame 0 should produce strongest spin effect")


func test_strength_decays_each_frame() -> void:
	at.activate(Vector2.RIGHT)
	var prev_spin := 999.0
	for i in range(AftertouchPure.OPEN_PLAY_WINDOW):
		var result := at.tick(Vector2.UP)
		var cur_spin: float = absf(result["spin_offset"])
		if cur_spin > 0.0:
			assert_lt(cur_spin, prev_spin, "Spin offset should decrease each frame")
			prev_spin = cur_spin


func test_decay_rate_matches_constant() -> void:
	at.activate(Vector2.RIGHT)
	var frame0 := at.tick(Vector2.UP)
	at.reset()
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.ZERO)  # skip frame 0
	var frame1 := at.tick(Vector2.UP)
	var ratio: float = absf(frame1["spin_offset"]) / absf(frame0["spin_offset"])
	assert_almost_eq(ratio, AftertouchPure.DECAY_RATE, 0.01,
		"Decay between frames should match DECAY_RATE")


# --- Spin Curl (perpendicular input) ---


func test_perpendicular_input_produces_spin() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.UP)
	assert_ne(result["spin_offset"], 0.0,
		"Perpendicular input should produce spin offset")
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001,
		"Pure perpendicular input should not affect vertical")


func test_opposite_perpendicular_spins_other_way() -> void:
	at.activate(Vector2.RIGHT)
	var result_up := at.tick(Vector2.UP)
	at.reset()
	at.activate(Vector2.RIGHT)
	var result_down := at.tick(Vector2.DOWN)
	# Spin offsets should be opposite signs
	assert_lt(result_up["spin_offset"] * result_down["spin_offset"], 0.0,
		"Opposite perpendicular inputs should produce opposite spin")


func test_no_spin_from_parallel_input() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.RIGHT)
	assert_almost_eq(result["spin_offset"], 0.0, 0.001,
		"Parallel input should produce no spin")


# --- Loft (opposite to travel direction) ---


func test_opposite_input_produces_loft() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.LEFT)
	assert_gt(result["vertical_offset"], 0.0,
		"Opposite input should produce positive vertical offset (loft)")


func test_loft_magnitude_at_frame_zero() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.LEFT)
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
	assert_almost_eq(result["vertical_offset"], -AftertouchPure.DIP_FACTOR, 0.01,
		"Full same-direction input at frame 0 should give -DIP_FACTOR vertical offset")


# --- Compound / Diagonal ---


func test_diagonal_produces_spin_and_loft() -> void:
	at.activate(Vector2.RIGHT)
	var input := Vector2(-1, 1).normalized()
	var result := at.tick(input)
	assert_ne(result["spin_offset"], 0.0, "Should have spin component")
	assert_gt(result["vertical_offset"], 0.0, "Should have loft component")


func test_diagonal_produces_spin_and_dip() -> void:
	at.activate(Vector2.RIGHT)
	var input := Vector2(1, 1).normalized()
	var result := at.tick(input)
	assert_ne(result["spin_offset"], 0.0, "Should have spin component")
	assert_lt(result["vertical_offset"], 0.0, "Should have dip component")


# --- Zero Input ---


func test_zero_input_produces_zero_offset() -> void:
	at.activate(Vector2.RIGHT)
	var result := at.tick(Vector2.ZERO)
	assert_eq(result["spin_offset"], 0.0)
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001)


func test_zero_input_still_counts_down_window() -> void:
	at.activate(Vector2.RIGHT)
	at.tick(Vector2.ZERO)
	assert_eq(at.timer, AftertouchPure.OPEN_PLAY_WINDOW - 1,
		"Timer should decrement even with zero input")


# --- Inactive aftertouch returns zero ---


func test_tick_when_inactive_returns_zero() -> void:
	var result := at.tick(Vector2.UP)
	assert_eq(result["spin_offset"], 0.0)
	assert_almost_eq(result["vertical_offset"], 0.0, 0.001)


# --- Integration: AftertouchPure + BallPhysicsPure ---


func test_spin_curl_changes_ball_trajectory() -> void:
	var ball := BallPhysicsPure.new()
	var ball_no_curl := BallPhysicsPure.new()

	var kick_vel := Vector2(4.0, 0.0)
	ball.apply_kick(kick_vel, 1.0)
	ball_no_curl.apply_kick(kick_vel, 1.0)

	at.activate(kick_vel)
	for i in range(40):
		if at.is_active():
			var result := at.tick(Vector2.UP)
			ball.apply_spin(result["spin_offset"])
			ball.vertical_velocity += result["vertical_offset"]
		ball.tick()
		ball_no_curl.tick()

	# Ball with spin should have different Y velocity than without
	assert_ne(ball.velocity.y, ball_no_curl.velocity.y,
		"Spin curl should deflect ball laterally compared to no-curl kick")


func test_loft_increases_max_height() -> void:
	var ball := BallPhysicsPure.new()
	var ball_no_loft := BallPhysicsPure.new()
	var at_loft := AftertouchPure.new()

	var kick_vel := Vector2(4.0, 0.0)
	ball.apply_kick(kick_vel, 1.0)
	ball_no_loft.apply_kick(kick_vel, 1.0)

	at_loft.activate(kick_vel)
	var max_h := 0.0
	var max_h_no := 0.0
	for i in range(80):
		if at_loft.is_active():
			var result := at_loft.tick(Vector2.LEFT)  # opposite = loft
			ball.apply_spin(result["spin_offset"])
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

	var kick_vel := Vector2(4.0, 0.0)
	ball.apply_kick(kick_vel, 1.5)
	ball_no_dip.apply_kick(kick_vel, 1.5)

	at_dip.activate(kick_vel)
	var max_h := 0.0
	var max_h_no := 0.0
	for i in range(80):
		if at_dip.is_active():
			var result := at_dip.tick(Vector2.RIGHT)  # same direction = dip
			ball.apply_spin(result["spin_offset"])
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
