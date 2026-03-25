extends GutTest
## Tests for InputQuantiserPure — 8-way input quantisation.


func test_zero_input_returns_zero():
	var result := InputQuantiserPure.quantise(Vector2.ZERO)
	assert_eq(result, Vector2.ZERO, "Zero input should return zero vector")


func test_below_deadzone_returns_zero():
	var result := InputQuantiserPure.quantise(Vector2(0.1, 0.1))
	assert_eq(result, Vector2.ZERO, "Input below deadzone should return zero")


func test_pure_right():
	var result := InputQuantiserPure.quantise(Vector2(1.0, 0.0))
	assert_almost_eq(result.x, 1.0, 0.01, "Right input X should be 1")
	assert_almost_eq(result.y, 0.0, 0.01, "Right input Y should be 0")


func test_pure_left():
	var result := InputQuantiserPure.quantise(Vector2(-1.0, 0.0))
	assert_almost_eq(result.x, -1.0, 0.01, "Left input X should be -1")
	assert_almost_eq(result.y, 0.0, 0.01, "Left input Y should be 0")


func test_pure_down():
	var result := InputQuantiserPure.quantise(Vector2(0.0, 1.0))
	assert_almost_eq(result.x, 0.0, 0.01, "Down input X should be 0")
	assert_almost_eq(result.y, 1.0, 0.01, "Down input Y should be 1")


func test_pure_up():
	var result := InputQuantiserPure.quantise(Vector2(0.0, -1.0))
	assert_almost_eq(result.x, 0.0, 0.01, "Up input X should be 0")
	assert_almost_eq(result.y, -1.0, 0.01, "Up input Y should be -1")


func test_diagonal_down_right():
	var result := InputQuantiserPure.quantise(Vector2(1.0, 1.0))
	assert_almost_eq(result.x, 0.707, 0.01, "SE X should be ~0.707")
	assert_almost_eq(result.y, 0.707, 0.01, "SE Y should be ~0.707")


func test_diagonal_up_left():
	var result := InputQuantiserPure.quantise(Vector2(-1.0, -1.0))
	assert_almost_eq(result.x, -0.707, 0.01, "NW X should be ~-0.707")
	assert_almost_eq(result.y, -0.707, 0.01, "NW Y should be ~-0.707")


func test_diagonal_down_left():
	var result := InputQuantiserPure.quantise(Vector2(-1.0, 1.0))
	assert_almost_eq(result.x, -0.707, 0.01, "SW X should be ~-0.707")
	assert_almost_eq(result.y, 0.707, 0.01, "SW Y should be ~0.707")


func test_diagonal_up_right():
	var result := InputQuantiserPure.quantise(Vector2(1.0, -1.0))
	assert_almost_eq(result.x, 0.707, 0.01, "NE X should be ~0.707")
	assert_almost_eq(result.y, -0.707, 0.01, "NE Y should be ~-0.707")


func test_slight_off_axis_snaps_to_cardinal():
	# Slightly off from pure right — should still snap to right
	var result := InputQuantiserPure.quantise(Vector2(1.0, 0.1))
	assert_almost_eq(result.x, 1.0, 0.01, "Near-right should snap to pure right X")
	assert_almost_eq(result.y, 0.0, 0.01, "Near-right should snap to pure right Y")


func test_output_is_unit_vector():
	var directions := [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1),
	]
	for dir in directions:
		var result := InputQuantiserPure.quantise(dir)
		assert_almost_eq(result.length(), 1.0, 0.01,
			"Output should be unit vector for input %s" % str(dir))


func test_exactly_at_deadzone_returns_zero():
	# Length of (0.14, 0.14) is ~0.198, below 0.2 deadzone
	var result := InputQuantiserPure.quantise(Vector2(0.14, 0.14))
	assert_eq(result, Vector2.ZERO, "Input at deadzone boundary should return zero")


func test_just_above_deadzone_returns_direction():
	# Length of (0.2, 0.2) is ~0.283, above 0.2 deadzone
	var result := InputQuantiserPure.quantise(Vector2(0.2, 0.2))
	assert_ne(result, Vector2.ZERO, "Input above deadzone should return a direction")
