extends GutTest
## Tests for KickStatePure — kick state machine.

var kick: KickStatePure


func before_each():
	kick = KickStatePure.new()


func _player(pos: Vector2, team_id: int = 0) -> Dictionary:
	return {"position": pos, "team_id": team_id}


# ── State transitions ──

func test_initial_state_is_idle():
	assert_eq(kick.state, KickStatePure.State.IDLE)


func test_start_charge_transitions_to_charging():
	kick.start_charge()
	assert_eq(kick.state, KickStatePure.State.CHARGING)


func test_start_charge_only_from_idle():
	kick.start_charge()
	kick.state = KickStatePure.State.AFTERTOUCH
	kick.start_charge()  # Should not transition
	assert_eq(kick.state, KickStatePure.State.AFTERTOUCH)


func test_release_transitions_to_aftertouch():
	kick.start_charge()
	kick.tick_charge()
	kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(kick.state, KickStatePure.State.AFTERTOUCH)


func test_aftertouch_returns_to_idle():
	kick.start_charge()
	kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	for i in range(KickStatePure.AFTERTOUCH_WINDOW):
		kick.tick_aftertouch()
	assert_eq(kick.state, KickStatePure.State.IDLE)


func test_reset_returns_to_idle():
	kick.start_charge()
	kick.tick_charge()
	kick.reset()
	assert_eq(kick.state, KickStatePure.State.IDLE)
	assert_eq(kick.charge_frames, 0)


# ── Charging ──

func test_charge_frames_increment():
	kick.start_charge()
	for i in range(10):
		kick.tick_charge()
	assert_eq(kick.charge_frames, 10)


func test_charge_frames_cap_at_max():
	kick.start_charge()
	for i in range(50):
		kick.tick_charge()
	assert_eq(kick.charge_frames, KickStatePure.MAX_CHARGE_FRAMES)


# ── Short tap (pass) ──

func test_short_tap_returns_pass_type():
	kick.start_charge()
	for i in range(3):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(result["type"], "pass")


func test_short_tap_ground_pass_no_lift():
	kick.start_charge()
	kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(result["up_velocity"], 0.0)


func test_short_tap_targets_teammate_in_cone():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker
		_player(Vector2(300, 300), 0),  # teammate ahead
	]
	kick.start_charge()
	kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, players,
		Vector2(300, 400), 0, 0)
	assert_eq(result["type"], "pass")
	# Velocity should point upward (toward teammate at y=300)
	assert_lt(result["velocity"].y, 0.0, "pass should go up toward teammate")


func test_short_tap_no_target_uses_facing():
	kick.start_charge()
	kick.tick_charge()
	var result := kick.release(Vector2.ZERO, Vector2.RIGHT, [], Vector2(300, 400), 0)
	assert_eq(result["type"], "pass")
	assert_gt(result["velocity"].x, 0.0, "should kick in facing direction (right)")
	assert_gte(result["velocity"].length(), KickStatePure.MIN_PASS_SPEED - 0.01,
		"pass speed should exceed possession threshold")


# ── Long press (shot) ──

func test_long_press_returns_shot_type():
	kick.start_charge()
	for i in range(10):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(result["type"], "shot")


func test_shot_power_scales_with_charge():
	# Short charge
	var kick_a := KickStatePure.new()
	kick_a.start_charge()
	for i in range(10):
		kick_a.tick_charge()
	var result_a := kick_a.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)

	# Long charge
	var kick_b := KickStatePure.new()
	kick_b.start_charge()
	for i in range(25):
		kick_b.tick_charge()
	var result_b := kick_b.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)

	assert_gt(result_b["velocity"].length(), result_a["velocity"].length(),
		"longer charge = more power")


func test_shot_uses_joystick_direction():
	kick.start_charge()
	for i in range(15):
		kick.tick_charge()
	var result := kick.release(Vector2.RIGHT, Vector2.UP, [], Vector2(300, 400), 0)
	assert_gt(result["velocity"].x, 0.0, "should kick right (joystick)")
	assert_almost_eq(result["velocity"].y, 0.0, 0.01, "should not go up")


func test_shot_falls_back_to_facing():
	kick.start_charge()
	for i in range(15):
		kick.tick_charge()
	var result := kick.release(Vector2.ZERO, Vector2.LEFT, [], Vector2(300, 400), 0)
	assert_lt(result["velocity"].x, 0.0, "should kick left (facing)")


func test_shot_has_lift_when_powerful():
	kick.start_charge()
	for i in range(20):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_gt(result["up_velocity"], 0.0, "hard shots should have lift")


func test_shot_no_lift_when_weak():
	# Just above SHORT_TAP_FRAMES but below SHOT_LIFT_THRESHOLD
	kick.start_charge()
	for i in range(6):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	# power = 6/30 = 0.2, below threshold of 0.3
	assert_eq(result["up_velocity"], 0.0, "weak shots stay on the ground")


func test_shot_lift_scales_with_power():
	# Medium charge
	var kick_a := KickStatePure.new()
	kick_a.start_charge()
	for i in range(15):
		kick_a.tick_charge()
	var result_a := kick_a.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)

	# Full charge
	var kick_b := KickStatePure.new()
	kick_b.start_charge()
	for i in range(KickStatePure.MAX_CHARGE_FRAMES):
		kick_b.tick_charge()
	var result_b := kick_b.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)

	assert_gt(result_b["up_velocity"], result_a["up_velocity"],
		"harder shots should have more lift")


func test_max_shot_lift():
	kick.start_charge()
	for i in range(KickStatePure.MAX_CHARGE_FRAMES):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_almost_eq(result["up_velocity"], KickStatePure.SHOT_LIFT_FACTOR, 0.01,
		"max power shot should have full lift")


func test_min_power_clamp():
	kick.start_charge()
	kick.tick_charge()  # 1 frame — very low raw power
	# Force > SHORT_TAP to get shot path (need > 4 frames)
	var kick2 := KickStatePure.new()
	kick2.start_charge()
	for i in range(5):
		kick2.tick_charge()
	var result := kick2.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	var speed: float = result["velocity"].length()
	var min_speed := KickStatePure.MIN_KICK_POWER * KickStatePure.MAX_KICK_SPEED
	assert_gte(speed, min_speed - 0.01, "power should be at least MIN_KICK_POWER")


func test_max_power_clamp():
	kick.start_charge()
	for i in range(KickStatePure.MAX_CHARGE_FRAMES):
		kick.tick_charge()
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	var speed: float = result["velocity"].length()
	var max_speed := KickStatePure.MAX_KICK_POWER * KickStatePure.MAX_KICK_SPEED
	assert_almost_eq(speed, max_speed, 0.01, "should be capped at MAX_KICK_POWER")


# ── Edge cases ──

func test_release_from_idle_returns_none():
	var result := kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(result["type"], "none")


func test_aftertouch_timer_decrements():
	kick.start_charge()
	kick.release(Vector2.UP, Vector2.UP, [], Vector2(300, 400), 0)
	assert_eq(kick.aftertouch_timer, KickStatePure.AFTERTOUCH_WINDOW)
	kick.tick_aftertouch()
	assert_eq(kick.aftertouch_timer, KickStatePure.AFTERTOUCH_WINDOW - 1)


func test_tick_charge_ignored_when_not_charging():
	kick.tick_charge()  # Should do nothing in IDLE
	assert_eq(kick.charge_frames, 0)
