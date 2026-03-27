extends GutTest
## Tests for CornerPure — corner kick logic, trajectory, and state machine.


var corner: CornerPure


func before_each():
	corner = CornerPure.new()


# ===== Setup and default aim =====

func test_setup_top_left_corner_aims_at_penalty_area():
	corner.setup(PitchGeometry.CORNER_TOP_LEFT, "top")
	# Default aim should point roughly toward penalty spot (300, 112) from (40, 40)
	var expected_dir := (PitchGeometry.PENALTY_SPOT_TOP - PitchGeometry.CORNER_TOP_LEFT).normalized()
	var dot := corner.aim_direction.dot(expected_dir)
	assert_gt(dot, 0.99, "Default aim should point at penalty area (dot=%.4f)" % dot)


func test_setup_bottom_right_corner_aims_at_penalty_area():
	corner.setup(PitchGeometry.CORNER_BOTTOM_RIGHT, "bottom")
	var expected_dir := (PitchGeometry.PENALTY_SPOT_BOTTOM - PitchGeometry.CORNER_BOTTOM_RIGHT).normalized()
	var dot := corner.aim_direction.dot(expected_dir)
	assert_gt(dot, 0.99, "Default aim should point at penalty area (dot=%.4f)" % dot)


func test_facing_toward_line_top():
	corner.setup(PitchGeometry.CORNER_TOP_LEFT, "top")
	assert_eq(corner.facing_toward_line, Vector2.DOWN, "Top corner should face down")


func test_facing_toward_line_bottom():
	corner.setup(PitchGeometry.CORNER_BOTTOM_LEFT, "bottom")
	assert_eq(corner.facing_toward_line, Vector2.UP, "Bottom corner should face up")


# ===== Phase transitions =====

func test_phase_walking_to_aiming():
	corner.setup(Vector2(40, 40), "top")
	assert_eq(corner.phase, CornerPure.Phase.WALKING)
	corner.phase = CornerPure.Phase.AIMING
	assert_eq(corner.phase, CornerPure.Phase.AIMING)


func test_charge_and_release():
	corner.setup(Vector2(40, 40), "top")
	corner.phase = CornerPure.Phase.AIMING
	corner.start_charge()
	assert_eq(corner.phase, CornerPure.Phase.CHARGING)

	# Charge to max
	for i in range(CornerPure.MAX_CHARGE_FRAMES):
		corner.tick_charge()
	assert_eq(corner.charge_frames, CornerPure.MAX_CHARGE_FRAMES)

	var result := corner.release()
	assert_eq(corner.phase, CornerPure.Phase.KICKING)
	assert_gt(result["velocity"].length(), 0.0, "Should have velocity after release")
	assert_gt(result["up_velocity"], 0.0, "Should have up velocity after release")


func test_kick_phase_transitions_to_done():
	corner.setup(Vector2(40, 40), "top")
	corner.phase = CornerPure.Phase.AIMING
	corner.start_charge()
	for i in range(CornerPure.MAX_CHARGE_FRAMES):
		corner.tick_charge()
	corner.release()

	# Tick through kick animation
	for i in range(CornerPure.KICK_ANIM_FRAMES + 1):
		corner.tick_post_kick()
	assert_eq(corner.phase, CornerPure.Phase.DONE)


# ===== Corner is significantly stronger than throw-in =====

func test_corner_max_speed_much_greater_than_throwin():
	assert_gt(CornerPure.MAX_CORNER_SPEED, ThrowinPure.MAX_THROW_SPEED * 1.5,
		"Corner max speed (%.1f) should be significantly > throw-in (%.1f)"
		% [CornerPure.MAX_CORNER_SPEED, ThrowinPure.MAX_THROW_SPEED])


# ===== Trajectory: default corner lands near penalty spot =====

func _simulate_ball_landing(start_pos: Vector2, vel: Vector2, up_vel: float) -> Vector2:
	## Simulate ball flight using BallPhysicsPure constants. Returns landing position.
	var pos := start_pos
	var height := 0.01
	var vv := up_vel
	var landed := false

	for i in range(300):  # Safety: max frames
		vv -= BallPhysicsPure.GRAVITY
		vv *= BallPhysicsPure.AIR_FRICTION
		height += vv

		if height <= 0.0:
			height = 0.0
			if absf(vv) > BallPhysicsPure.MIN_BOUNCE_VELOCITY:
				vel *= (1.0 + vv / BallPhysicsPure.BOUNCE_H_LOSS)
				vv = -vv * BallPhysicsPure.BOUNCE_DAMPING
			else:
				vv = 0.0
				landed = true

		if height > 0.0:
			vel *= BallPhysicsPure.AIR_FRICTION
		else:
			var spd := vel.length()
			if spd > 0.0:
				var decel := BallPhysicsPure.GROUND_FRICTION_K * sqrt(spd)
				vel = vel.normalized() * maxf(spd - decel, 0.0)

		pos += vel

		# Stop once ball has landed and is slow
		if landed and vel.length() < 0.5:
			break

	return pos


func _charge_and_release(charge_frames: int) -> Dictionary:
	## Helper: charge for N frames and release.
	corner.phase = CornerPure.Phase.AIMING
	corner.start_charge()
	for i in range(charge_frames):
		corner.tick_charge()
	return corner.release()


func test_default_corner_top_left_lands_near_penalty_spot():
	corner.setup(PitchGeometry.CORNER_TOP_LEFT, "top")
	# Use DEFAULT_CHARGE_FRAMES to test the "default" corner power
	var result := _charge_and_release(CornerPure.DEFAULT_CHARGE_FRAMES)

	var landing := _simulate_ball_landing(
		PitchGeometry.CORNER_TOP_LEFT, result["velocity"], result["up_velocity"])
	var penalty_spot := PitchGeometry.PENALTY_SPOT_TOP
	var dist := landing.distance_to(penalty_spot)
	assert_lt(dist, 50.0,
		"Default corner from top-left should land near penalty spot (300,112). Landed at (%d,%d), dist=%.1f"
		% [int(landing.x), int(landing.y), dist])


func test_default_corner_bottom_right_lands_near_penalty_spot():
	corner.setup(PitchGeometry.CORNER_BOTTOM_RIGHT, "bottom")
	var result := _charge_and_release(CornerPure.DEFAULT_CHARGE_FRAMES)

	var landing := _simulate_ball_landing(
		PitchGeometry.CORNER_BOTTOM_RIGHT, result["velocity"], result["up_velocity"])
	var penalty_spot := PitchGeometry.PENALTY_SPOT_BOTTOM
	var dist := landing.distance_to(penalty_spot)
	assert_lt(dist, 50.0,
		"Default corner from bottom-right should land near penalty spot (300,608). Landed at (%d,%d), dist=%.1f"
		% [int(landing.x), int(landing.y), dist])


func test_default_corner_top_right_lands_near_penalty_spot():
	corner.setup(PitchGeometry.CORNER_TOP_RIGHT, "top")
	var result := _charge_and_release(CornerPure.DEFAULT_CHARGE_FRAMES)

	var landing := _simulate_ball_landing(
		PitchGeometry.CORNER_TOP_RIGHT, result["velocity"], result["up_velocity"])
	var penalty_spot := PitchGeometry.PENALTY_SPOT_TOP
	var dist := landing.distance_to(penalty_spot)
	assert_lt(dist, 50.0,
		"Default corner from top-right should land near penalty spot (300,112). Landed at (%d,%d), dist=%.1f"
		% [int(landing.x), int(landing.y), dist])


func test_default_corner_bottom_left_lands_near_penalty_spot():
	corner.setup(PitchGeometry.CORNER_BOTTOM_LEFT, "bottom")
	var result := _charge_and_release(CornerPure.DEFAULT_CHARGE_FRAMES)

	var landing := _simulate_ball_landing(
		PitchGeometry.CORNER_BOTTOM_LEFT, result["velocity"], result["up_velocity"])
	var penalty_spot := PitchGeometry.PENALTY_SPOT_BOTTOM
	var dist := landing.distance_to(penalty_spot)
	assert_lt(dist, 50.0,
		"Default corner from bottom-left should land near penalty spot (300,608). Landed at (%d,%d), dist=%.1f"
		% [int(landing.x), int(landing.y), dist])
