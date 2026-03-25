extends GutTest
## Tests for PossessionPure — proximity-based possession and dribbling.

var possession: PossessionPure


func before_each():
	possession = PossessionPure.new()


func test_no_players_no_possession():
	var result := possession.check_possession([], Vector2(100, 100))
	assert_eq(result, -1, "No players should mean no possession")


func test_player_within_pickup_radius():
	var positions: Array = [Vector2(100, 100)]
	var ball_pos := Vector2(105, 100)  # 5px away, within 10px radius
	var result := possession.check_possession(positions, ball_pos)
	assert_eq(result, 0, "Player within pickup radius should gain possession")


func test_player_outside_pickup_radius():
	var positions: Array = [Vector2(100, 100)]
	var ball_pos := Vector2(120, 100)  # 20px away, outside 10px radius
	var result := possession.check_possession(positions, ball_pos)
	assert_eq(result, -1, "Player outside pickup radius should not gain possession")


func test_player_exactly_at_pickup_radius():
	var positions: Array = [Vector2(100, 100)]
	var ball_pos := Vector2(110, 100)  # Exactly 10px away
	var result := possession.check_possession(positions, ball_pos)
	assert_eq(result, -1, "Player exactly at pickup radius edge should not gain possession")


func test_closest_player_wins():
	var positions: Array = [
		Vector2(100, 100),  # 8px away
		Vector2(105, 100),  # 3px away — closer
	]
	var ball_pos := Vector2(108, 100)
	var result := possession.check_possession(positions, ball_pos)
	assert_eq(result, 1, "Closest player should win possession")


func test_airborne_ball_no_possession():
	var positions: Array = [Vector2(100, 100)]
	var ball_pos := Vector2(102, 100)  # 2px away
	var result := possession.check_possession(positions, ball_pos, true)
	assert_eq(result, -1, "Airborne ball should not grant possession")


func test_possessor_index_persists():
	var positions: Array = [Vector2(100, 100)]
	var ball_pos := Vector2(105, 100)
	possession.check_possession(positions, ball_pos)
	assert_eq(possession.possessor_index, 0, "possessor_index should persist after check")


func test_reset_clears_possession():
	var positions: Array = [Vector2(100, 100)]
	possession.check_possession(positions, Vector2(105, 100))
	possession.reset()
	assert_eq(possession.possessor_index, -1, "Reset should clear possession")


# --- Dribble position tests ---

func test_dribble_position_right():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2.RIGHT)
	assert_almost_eq(pos.x, 114.0, 0.1, "Dribble right X should be player + 14")
	assert_almost_eq(pos.y, 100.0, 0.1, "Dribble right Y should match player")


func test_dribble_position_down():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2.DOWN)
	assert_almost_eq(pos.x, 100.0, 0.1, "Dribble down X should match player")
	assert_almost_eq(pos.y, 114.0, 0.1, "Dribble down Y should be player + 14")


func test_dribble_position_diagonal():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2(1, 1).normalized())
	var expected_offset := 14.0 * 0.707107
	assert_almost_eq(pos.x, 100.0 + expected_offset, 0.2, "Dribble SE X")
	assert_almost_eq(pos.y, 100.0 + expected_offset, 0.2, "Dribble SE Y")


func test_dribble_position_zero_facing_defaults_to_down():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2.ZERO)
	assert_almost_eq(pos.x, 100.0, 0.1, "Dribble default X should match player")
	assert_almost_eq(pos.y, 114.0, 0.1, "Dribble default Y should be player + 14 (south)")


func test_dribble_position_left():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2.LEFT)
	assert_almost_eq(pos.x, 86.0, 0.1, "Dribble left X should be player - 14")
	assert_almost_eq(pos.y, 100.0, 0.1, "Dribble left Y should match player")


func test_dribble_position_up():
	var pos := PossessionPure.get_dribble_position(
		Vector2(100, 100), Vector2.UP)
	assert_almost_eq(pos.x, 100.0, 0.1, "Dribble up X should match player")
	assert_almost_eq(pos.y, 86.0, 0.1, "Dribble up Y should be player - 14")
