extends GutTest
## Tests for CameraPure — smooth ball-tracking camera logic.

var cam: CameraPure

const WORLD_W := 600.0
const WORLD_H := 720.0
const VP_W := 336.0
const VP_H := 272.0


func before_each() -> void:
	cam = CameraPure.new()
	cam.setup(WORLD_W, WORLD_H, VP_W, VP_H)


# --- Setup ---


func test_initial_position_is_zero() -> void:
	assert_eq(cam.position, Vector2.ZERO)


func test_center_on_pitch() -> void:
	cam.center_on_pitch()
	assert_eq(cam.position, Vector2(WORLD_W / 2.0, WORLD_H / 2.0))


# --- Snap ---


func test_snap_to_position() -> void:
	cam.snap_to(Vector2(400.0, 200.0))
	assert_eq(cam.position, Vector2(400.0, 200.0))
	assert_eq(cam.target, Vector2(400.0, 200.0))


func test_snap_clamps_to_bounds() -> void:
	# Snap to top-left corner — should clamp so viewport stays in world
	cam.snap_to(Vector2(0.0, 0.0))
	assert_eq(cam.position, Vector2(VP_W / 2.0, VP_H / 2.0))


func test_snap_clamps_bottom_right() -> void:
	cam.snap_to(Vector2(WORLD_W + 100.0, WORLD_H + 100.0))
	assert_eq(cam.position, Vector2(WORLD_W - VP_W / 2.0, WORLD_H - VP_H / 2.0))


# --- Lerp Convergence ---


func test_tick_moves_toward_target() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	var target := Vector2(WORLD_W / 2.0 + 100.0, WORLD_H / 2.0)
	var result := cam.tick(target)
	# Camera should have moved toward the target
	assert_gt(result.x, WORLD_W / 2.0, "Camera should move right toward target")
	# But not all the way (smooth interpolation)
	assert_lt(result.x, WORLD_W / 2.0 + 100.0, "Camera should not snap to target")


func test_tick_converges_over_many_frames() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	var target := Vector2(WORLD_W / 2.0 + 50.0, WORLD_H / 2.0)
	# Run 120 frames (~2.4 seconds at 50fps) — should converge
	for i in range(120):
		cam.tick(target)
	var dist := cam.position.distance_to(target)
	assert_lt(dist, CameraPure.SNAP_THRESHOLD,
		"Camera should converge to target within snap threshold after many frames")


func test_tick_63_percent_convergence_in_12_frames() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	var initial_pos := cam.position
	var target := Vector2(WORLD_W / 2.0 + 50.0, WORLD_H / 2.0)
	var initial_dist := initial_pos.distance_to(target)
	for i in range(12):
		cam.tick(target)
	var final_dist := cam.position.distance_to(target)
	var convergence := 1.0 - (final_dist / initial_dist)
	# At SMOOTH_FACTOR=0.08, 12 frames: 1 - 0.92^12 ≈ 0.633
	assert_gt(convergence, 0.55, "Should converge at least 55% in 12 frames")
	assert_lt(convergence, 0.75, "Should not converge more than 75% in 12 frames")


# --- Snap Threshold ---


func test_snap_threshold_prevents_jitter() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	var target := Vector2(WORLD_W / 2.0 + 1.0, WORLD_H / 2.0)  # Within threshold
	cam.tick(target)
	assert_eq(cam.position, target,
		"Camera should snap directly when within threshold")


# --- Speed Clamping ---


func test_max_scroll_speed_clamping() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	# Target very far away along Y (vertical pitch has more room) — movement per frame should be clamped
	var target := Vector2(WORLD_W / 2.0, WORLD_H / 2.0 + 500.0)
	var before := cam.position
	cam.tick(target)
	var moved := cam.position.distance_to(before)
	assert_lte(moved, CameraPure.MAX_SCROLL_SPEED + 0.01,
		"Movement per frame should not exceed MAX_SCROLL_SPEED")


# --- Boundary Clamping ---


func test_camera_clamps_left_boundary() -> void:
	cam.snap_to(Vector2(VP_W / 2.0, WORLD_H / 2.0))
	# Target outside left boundary
	cam.tick(Vector2(-100.0, WORLD_H / 2.0))
	assert_gte(cam.position.x, VP_W / 2.0,
		"Camera X should not go below half viewport width")


func test_camera_clamps_right_boundary() -> void:
	cam.snap_to(Vector2(WORLD_W - VP_W / 2.0, WORLD_H / 2.0))
	cam.tick(Vector2(WORLD_W + 100.0, WORLD_H / 2.0))
	assert_lte(cam.position.x, WORLD_W - VP_W / 2.0,
		"Camera X should not exceed world width minus half viewport")


func test_camera_clamps_top_boundary() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, VP_H / 2.0))
	cam.tick(Vector2(WORLD_W / 2.0, -100.0))
	assert_gte(cam.position.y, VP_H / 2.0,
		"Camera Y should not go below half viewport height")


func test_camera_clamps_bottom_boundary() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H - VP_H / 2.0))
	cam.tick(Vector2(WORLD_W / 2.0, WORLD_H + 100.0))
	assert_lte(cam.position.y, WORLD_H - VP_H / 2.0,
		"Camera Y should not exceed world height minus half viewport")


# --- Pixel-Perfect Output ---


func test_tick_returns_integer_position() -> void:
	cam.snap_to(Vector2(WORLD_W / 2.0, WORLD_H / 2.0))
	var result := cam.tick(Vector2(WORLD_W / 2.0 + 33.7, WORLD_H / 2.0 + 17.3))
	assert_eq(result.x, roundf(result.x), "Result X should be integer")
	assert_eq(result.y, roundf(result.y), "Result Y should be integer")


# --- Stationary Ball ---


func test_camera_stays_still_when_ball_stationary() -> void:
	cam.center_on_pitch()
	var center := Vector2(WORLD_W / 2.0, WORLD_H / 2.0)
	# Tick several times with ball at center
	for i in range(10):
		cam.tick(center)
	assert_eq(cam.position, center, "Camera should stay at center when ball is stationary there")
