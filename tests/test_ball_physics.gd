extends GutTest
## Tests for BallPhysicsPure — ball physics logic.

var physics: BallPhysicsPure


func before_each() -> void:
	physics = BallPhysicsPure.new()


# --- Ground Friction ---


func test_ground_friction_reduces_velocity() -> void:
	physics.velocity = Vector2(10.0, 0.0)
	physics.tick()
	assert_almost_eq(physics.velocity.x, 9.8, 0.01,
		"Ground friction should reduce velocity by 2% per frame")


func test_ground_friction_applied_each_frame() -> void:
	physics.velocity = Vector2(10.0, 0.0)
	physics.tick()
	physics.tick()
	assert_almost_eq(physics.velocity.x, 9.604, 0.01,
		"Friction compounds each frame")


func test_ground_friction_both_axes() -> void:
	physics.velocity = Vector2(10.0, 5.0)
	physics.tick()
	assert_almost_eq(physics.velocity.x, 9.8, 0.01)
	assert_almost_eq(physics.velocity.y, 4.9, 0.01)


# --- Air Friction ---


func test_air_friction_when_airborne() -> void:
	physics.velocity = Vector2(10.0, 0.0)
	physics.height = 5.0
	physics.tick()
	assert_almost_eq(physics.velocity.x, 9.9, 0.01,
		"Airborne ball should use air friction (0.99)")


func test_air_friction_with_vertical_velocity() -> void:
	physics.velocity = Vector2(10.0, 0.0)
	physics.vertical_velocity = 3.0
	physics.tick()
	assert_almost_eq(physics.velocity.x, 9.9, 0.01,
		"Ball with upward velocity is airborne, uses air friction")


# --- Gravity ---


func test_gravity_reduces_height() -> void:
	physics.height = 10.0
	physics.vertical_velocity = 0.0
	physics.tick()
	assert_almost_eq(physics.height, 9.6, 0.01)
	assert_almost_eq(physics.vertical_velocity, -0.4, 0.01)


func test_gravity_accumulates() -> void:
	physics.height = 20.0
	physics.vertical_velocity = 0.0
	physics.tick()
	physics.tick()
	assert_almost_eq(physics.vertical_velocity, -0.8, 0.01)
	assert_almost_eq(physics.height, 18.8, 0.01)


# --- Bounce ---


func test_ball_bounces_on_ground_impact() -> void:
	physics.height = 0.5
	physics.vertical_velocity = -2.0
	physics.tick()
	# vv = -2.0 - 0.4 = -2.4, h = 0.5 + (-2.4) = -1.9 -> clamped to 0
	# abs(-2.4) = 2.4 > 0.5 -> bounce: 2.4 * 0.5 = 1.2
	assert_eq(physics.height, 0.0, "Height should clamp to 0 on impact")
	assert_almost_eq(physics.vertical_velocity, 1.2, 0.01,
		"Ball should bounce with damping 0.5")


func test_bounce_stops_when_velocity_too_small() -> void:
	physics.height = 0.01
	physics.vertical_velocity = -0.1
	physics.tick()
	# vv = -0.1 - 0.4 = -0.5, h = 0.01 + (-0.5) = -0.49 -> clamped 0
	# abs(-0.5) == 0.5, NOT > 0.5, so ball lands
	assert_eq(physics.height, 0.0)
	assert_eq(physics.vertical_velocity, 0.0,
		"Ball should stop bouncing when velocity is small")


# --- Ball Stopping ---


func test_ball_stops_when_velocity_below_threshold() -> void:
	physics.velocity = Vector2(0.05, 0.05)
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
	physics.velocity = Vector2(10.0, 0.0)
	for i in range(500):
		physics.tick()
	assert_true(physics.is_stopped(),
		"Ball should eventually stop from friction alone")


# --- Sprite Offset ---


func test_sprite_offset_zero_on_ground() -> void:
	assert_eq(physics.get_sprite_offset_y(), 0.0)


func test_sprite_offset_negative_when_airborne() -> void:
	physics.height = 10.0
	assert_almost_eq(physics.get_sprite_offset_y(), -20.0, 0.01,
		"Sprite should move up (negative Y) proportional to height")


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
	physics.apply_kick(Vector2(8.0, -3.0))
	assert_eq(physics.velocity, Vector2(8.0, -3.0))
	assert_eq(physics.vertical_velocity, 0.0)


func test_apply_kick_with_loft() -> void:
	physics.apply_kick(Vector2(5.0, 0.0), 4.0)
	assert_eq(physics.velocity, Vector2(5.0, 0.0))
	assert_eq(physics.vertical_velocity, 4.0)
	assert_true(physics.is_airborne(),
		"Lofted kick should make ball airborne")


# --- tick return value ---


func test_tick_returns_displacement() -> void:
	physics.velocity = Vector2(10.0, 5.0)
	var displacement := physics.tick()
	assert_almost_eq(displacement.x, 9.8, 0.01)
	assert_almost_eq(displacement.y, 4.9, 0.01)


# --- Reset ---


func test_reset_clears_all_state() -> void:
	physics.velocity = Vector2(10.0, 5.0)
	physics.height = 15.0
	physics.vertical_velocity = 3.0
	physics.reset()
	assert_eq(physics.velocity, Vector2.ZERO)
	assert_eq(physics.height, 0.0)
	assert_eq(physics.vertical_velocity, 0.0)


# --- Integration ---


func test_lofted_kick_goes_up_and_comes_back_down() -> void:
	physics.apply_kick(Vector2(6.0, 0.0), 5.0)
	var max_height := 0.0
	var frames := 0
	while not physics.is_stopped() and frames < 1000:
		physics.tick()
		if physics.height > max_height:
			max_height = physics.height
		frames += 1
	assert_gt(max_height, 0.0, "Ball should reach some height")
	assert_eq(physics.height, 0.0, "Ball should end on the ground")
	assert_true(physics.is_stopped(), "Ball should eventually stop")
	assert_lt(frames, 1000, "Ball should stop in reasonable time")
