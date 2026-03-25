extends GutTest
## Tests for BallPhysicsPure — ball physics logic.
## Physics model: square-root ground friction, spin-based curl,
## air friction on vertical, realistic bounce with horizontal loss.

var physics: BallPhysicsPure


func before_each() -> void:
	physics = BallPhysicsPure.new()


# --- Square-Root Ground Friction ---


func test_ground_friction_reduces_velocity() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.tick()
	# sqrt(4.0) = 2.0, decel = 0.08 * 2.0 = 0.16, new = 3.84
	assert_almost_eq(physics.velocity.x, 3.84, 0.01,
		"Square-root friction should reduce velocity")


func test_fast_ball_loses_less_percentage_than_slow() -> void:
	# Fast ball
	var fast := BallPhysicsPure.new()
	fast.velocity = Vector2(8.0, 0.0)
	fast.tick()
	var fast_loss := (8.0 - fast.velocity.x) / 8.0

	# Slow ball
	var slow := BallPhysicsPure.new()
	slow.velocity = Vector2(1.0, 0.0)
	slow.tick()
	var slow_loss := (1.0 - slow.velocity.x) / 1.0

	assert_lt(fast_loss, slow_loss,
		"Fast ball should lose smaller percentage than slow ball (sqrt damping)")


func test_ground_friction_both_axes() -> void:
	physics.velocity = Vector2(3.0, 4.0)  # speed = 5.0
	var initial_speed := 5.0
	physics.tick()
	var new_speed := physics.velocity.length()
	# decel = 0.08 * sqrt(5) = 0.08 * 2.236 = 0.179
	assert_almost_eq(new_speed, initial_speed - 0.08 * sqrt(5.0), 0.01)


# --- Air Friction ---


func test_air_friction_horizontal_when_airborne() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.height = 5.0
	physics.tick()
	assert_almost_eq(physics.velocity.x, 4.0 * BallPhysicsPure.AIR_FRICTION, 0.01,
		"Airborne ball should use air friction on horizontal")


func test_air_friction_applied_to_vertical_velocity() -> void:
	physics.height = 10.0
	physics.vertical_velocity = 1.0
	# After tick: vv = (1.0 - 0.07) * 0.994 = 0.93 * 0.994 = 0.924
	physics.tick()
	# vv should be less than 1.0 - GRAVITY due to air friction
	assert_lt(physics.vertical_velocity, 1.0 - BallPhysicsPure.GRAVITY,
		"Air friction should also apply to vertical velocity")


# --- Gravity ---


func test_gravity_reduces_height() -> void:
	physics.height = 5.0
	physics.vertical_velocity = 0.0
	physics.tick()
	# vv = (0.0 - 0.07) * 0.994 = -0.0696
	# height = 5.0 + (-0.0696) = 4.93
	assert_lt(physics.height, 5.0, "Gravity should reduce height")
	assert_lt(physics.vertical_velocity, 0.0, "Gravity should create downward velocity")


func test_gravity_accumulates() -> void:
	physics.height = 20.0
	physics.vertical_velocity = 0.0
	physics.tick()
	physics.tick()
	assert_lt(physics.vertical_velocity, -0.1,
		"Vertical velocity should accumulate from gravity")


# --- Bounce ---


func test_ball_bounces_on_ground_impact() -> void:
	physics.height = 0.1
	physics.vertical_velocity = -1.0
	physics.tick()
	assert_eq(physics.height, 0.0, "Height should clamp to 0 on impact")
	assert_gt(physics.vertical_velocity, 0.0, "Ball should bounce upward")


func test_bounce_damping_matches_constant() -> void:
	physics.height = 0.5
	physics.vertical_velocity = -1.0
	physics.tick()
	# vv after gravity+air = (-1.0 - 0.07) * 0.994 = -1.063
	# bounce: -(-1.063) * 0.585 = 0.622
	assert_almost_eq(physics.vertical_velocity,
		absf((-1.0 - BallPhysicsPure.GRAVITY) * BallPhysicsPure.AIR_FRICTION) * BallPhysicsPure.BOUNCE_DAMPING,
		0.02, "Bounce should retain BOUNCE_DAMPING fraction of impact velocity")


func test_bounce_stops_when_velocity_too_small() -> void:
	physics.height = 0.01
	physics.vertical_velocity = -0.05
	physics.tick()
	assert_eq(physics.height, 0.0)
	assert_eq(physics.vertical_velocity, 0.0,
		"Ball should stop bouncing when vertical velocity is small")


func test_bounce_reduces_horizontal_speed() -> void:
	physics.height = 0.5
	physics.vertical_velocity = -2.0
	physics.velocity = Vector2(4.0, 0.0)
	var initial_speed := 4.0
	physics.tick()
	assert_lt(physics.velocity.length(), initial_speed,
		"Horizontal speed should decrease on bounce impact")


# --- Ball Stopping ---


func test_ball_stops_when_velocity_below_threshold() -> void:
	physics.velocity = Vector2(0.02, 0.02)
	physics.tick()
	assert_eq(physics.velocity, Vector2.ZERO,
		"Ball should snap to zero when velocity < MIN_VELOCITY")


func test_is_stopped_when_stationary_on_ground() -> void:
	assert_true(physics.is_stopped(),
		"Ball with no velocity on ground is stopped")


func test_is_not_stopped_when_moving() -> void:
	physics.velocity = Vector2(5.0, 0.0)
	assert_false(physics.is_stopped())


func test_is_not_stopped_when_airborne() -> void:
	physics.height = 5.0
	assert_false(physics.is_stopped())


func test_ball_eventually_stops_from_ground_roll() -> void:
	physics.velocity = Vector2(5.0, 0.0)
	for i in range(500):
		physics.tick()
	assert_true(physics.is_stopped(),
		"Ball should eventually stop from friction alone")


# --- Spin (Curl) ---


func test_spin_rotates_velocity() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.spin = 5.0
	physics.tick()
	assert_ne(physics.velocity.y, 0.0,
		"Spin should deflect ball laterally")


func test_spin_decays_each_frame() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.spin = 5.0
	physics.tick()
	assert_almost_eq(physics.spin, 5.0 * BallPhysicsPure.SPIN_DAMPEN, 0.01,
		"Spin should decay by SPIN_DAMPEN each frame")


func test_spin_snaps_to_zero() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.spin = 0.005
	physics.tick()
	assert_eq(physics.spin, 0.0,
		"Small spin should snap to zero")


func test_positive_spin_curls_counterclockwise() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	physics.spin = 5.0
	physics.tick()
	# Positive rotation in Godot is clockwise, so positive spin should curve down (+Y)
	assert_gt(physics.velocity.y, 0.0,
		"Positive spin on rightward ball should deflect downward (Godot coords)")


func test_apply_spin_accumulates() -> void:
	physics.apply_spin(3.0)
	physics.apply_spin(2.0)
	assert_eq(physics.spin, 5.0)


# --- Sprite Offset ---


func test_sprite_offset_zero_on_ground() -> void:
	assert_eq(physics.get_sprite_offset_y(), 0.0)


func test_sprite_offset_negative_when_airborne() -> void:
	physics.height = 10.0
	assert_almost_eq(physics.get_sprite_offset_y(), -10.0, 0.01,
		"Sprite offset should match height 1:1 (PERSPECTIVE_SCALE = 1.0)")


# --- Shadow Opacity ---


func test_shadow_full_opacity_on_ground() -> void:
	assert_eq(physics.get_shadow_opacity(), 1.0)


func test_shadow_fades_with_height() -> void:
	physics.height = 20.0
	var opacity := physics.get_shadow_opacity()
	assert_lt(opacity, 1.0, "Shadow should fade when ball is airborne")
	assert_gt(opacity, 0.0, "Shadow should never fully disappear")


func test_shadow_opacity_minimum() -> void:
	physics.height = 1000.0
	assert_almost_eq(physics.get_shadow_opacity(), 0.2, 0.01,
		"Shadow opacity should not go below 0.2")


# --- apply_kick ---


func test_apply_kick_sets_velocity() -> void:
	physics.apply_kick(Vector2(5.0, -3.0))
	assert_eq(physics.velocity, Vector2(5.0, -3.0))
	assert_eq(physics.vertical_velocity, 0.0)


func test_apply_kick_with_loft() -> void:
	physics.apply_kick(Vector2(4.0, 0.0), 1.5)
	assert_eq(physics.velocity, Vector2(4.0, 0.0))
	assert_eq(physics.vertical_velocity, 1.5)
	assert_true(physics.is_airborne(),
		"Lofted kick should make ball airborne")


# --- tick return value ---


func test_tick_returns_displacement() -> void:
	physics.velocity = Vector2(4.0, 0.0)
	var displacement := physics.tick()
	# After sqrt friction: speed = 4.0 - 0.08*sqrt(4) = 4.0 - 0.16 = 3.84
	assert_almost_eq(displacement.x, 3.84, 0.02)


# --- Reset ---


func test_reset_clears_all_state() -> void:
	physics.velocity = Vector2(5.0, 3.0)
	physics.height = 15.0
	physics.vertical_velocity = 2.0
	physics.spin = 3.0
	physics.reset()
	assert_eq(physics.velocity, Vector2.ZERO)
	assert_eq(physics.height, 0.0)
	assert_eq(physics.vertical_velocity, 0.0)
	assert_eq(physics.spin, 0.0)


# --- Integration ---


func test_lofted_kick_goes_up_and_comes_back_down() -> void:
	physics.apply_kick(Vector2(4.0, 0.0), 1.5)
	var max_height := 0.0
	var frames := 0
	while not physics.is_stopped() and frames < 2000:
		physics.tick()
		if physics.height > max_height:
			max_height = physics.height
		frames += 1
	assert_gt(max_height, 0.0, "Ball should reach some height")
	assert_eq(physics.height, 0.0, "Ball should end on the ground")
	assert_true(physics.is_stopped(), "Ball should eventually stop")
	assert_lt(frames, 2000, "Ball should stop in reasonable time")


func test_medium_kick_airborne_duration() -> void:
	# Medium kick: up_vel = 1.2 (SHOT_LIFT_MEDIUM * power ~1.0)
	physics.apply_kick(Vector2(4.0, 0.0), 1.2)
	var frames_airborne := 0
	for i in range(500):
		physics.tick()
		if physics.is_airborne():
			frames_airborne += 1
		elif frames_airborne > 0:
			break  # Landed for good (first ground contact)
	# At 50 Hz, with low gravity (0.07), expect longer flights.
	# 1.2 up_vel / 0.07 gravity ≈ 17 frames to peak, ~34 frames first flight.
	# With bounces, total airborne frames will be higher.
	assert_gt(frames_airborne, 20,
		"Medium kick should stay airborne for meaningful duration")
	assert_lt(frames_airborne, 100,
		"Medium kick should not stay airborne too long")


func test_ball_bounces_multiple_times() -> void:
	physics.apply_kick(Vector2(3.0, 0.0), 1.5)
	var bounce_count := 0
	var prev_vv := physics.vertical_velocity
	for i in range(500):
		physics.tick()
		# Detect bounce: vertical velocity flips from negative to positive
		if prev_vv < -BallPhysicsPure.MIN_BOUNCE_VELOCITY and physics.vertical_velocity > 0:
			bounce_count += 1
		prev_vv = physics.vertical_velocity
		if physics.is_stopped():
			break
	assert_gt(bounce_count, 1,
		"Ball should bounce multiple times before settling")
