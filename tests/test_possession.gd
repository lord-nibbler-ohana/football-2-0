extends GutTest
## Tests for PossessionPure — proximity-based possession, dribbling,
## contested balls, goalkeeper handling, linger, and query API.

var possession: PossessionPure


func before_each():
	possession = PossessionPure.new()


## Helper to build a player info dictionary.
func _info(pos: Vector2, team: int = 0, gk: bool = false,
		vel: Vector2 = Vector2.ZERO) -> Dictionary:
	return {
		"position": pos,
		"team_id": team,
		"is_goalkeeper": gk,
		"velocity": vel,
	}


# ===== Basic possession =====

func test_no_players_no_possession():
	var result := possession.check_possession([], Vector2(100, 100))
	assert_eq(result, -1, "No players should mean no possession")


func test_player_within_pickup_radius():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100))
	assert_eq(result, 0, "Player within pickup radius should gain possession")


func test_player_outside_pickup_radius():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(120, 100))
	assert_eq(result, -1, "Player outside pickup radius should not gain possession")


func test_player_exactly_at_pickup_radius():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(110, 100))
	assert_eq(result, -1, "Player at pickup radius edge should not gain possession")


func test_closest_player_wins():
	var infos: Array = [
		_info(Vector2(100, 100)),  # 8px away
		_info(Vector2(105, 100)),  # 3px away — closer
	]
	var result := possession.check_possession(infos, Vector2(108, 100))
	assert_eq(result, 1, "Closest player should win possession")


func test_possessor_index_persists():
	var infos: Array = [_info(Vector2(100, 100))]
	possession.check_possession(infos, Vector2(105, 100))
	assert_eq(possession.possessor_index, 0, "possessor_index should persist")


func test_reset_clears_possession():
	var infos: Array = [_info(Vector2(100, 100))]
	possession.check_possession(infos, Vector2(105, 100))
	possession.reset()
	assert_eq(possession.possessor_index, -1, "Reset should clear possession")
	assert_eq(possession.possessing_team_id, -1, "Reset should clear team")
	assert_eq(possession.linger_frames_remaining, 0, "Reset should clear linger")


# ===== Height threshold =====

func test_ball_below_min_height_allows_pickup():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100), 5.0)
	assert_eq(result, 0, "Ball below MIN_HEIGHT should allow pickup")


func test_ball_above_min_height_blocks_pickup():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100), 10.0)
	assert_eq(result, -1, "Ball above MIN_HEIGHT should block pickup")


func test_ball_at_exact_min_height_blocks_pickup():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100), 8.0)
	assert_eq(result, -1, "Ball at exactly MIN_HEIGHT should block pickup")


# ===== Goalkeeper special radius =====

func test_goalkeeper_larger_pickup_radius():
	var infos: Array = [_info(Vector2(100, 100), 0, true)]  # GK
	# 15px away: outside 10px normal, inside 18px GK radius
	var result := possession.check_possession(infos, Vector2(115, 100))
	assert_eq(result, 0, "GK should pick up within GK_PICKUP_RADIUS")


func test_goalkeeper_aerial_catch():
	var infos: Array = [_info(Vector2(100, 100), 0, true)]
	# Ball at height 40 — above 8px normal limit, below 60px GK limit
	var result := possession.check_possession(infos, Vector2(105, 100), 40.0)
	assert_eq(result, 0, "GK should catch aerial ball below GK_MAX_CATCH_HEIGHT")


func test_goalkeeper_cannot_catch_too_high():
	var infos: Array = [_info(Vector2(100, 100), 0, true)]
	var result := possession.check_possession(infos, Vector2(105, 100), 65.0)
	assert_eq(result, -1, "GK should not catch ball above GK_MAX_CATCH_HEIGHT")


func test_non_goalkeeper_cannot_use_gk_radius():
	var infos: Array = [_info(Vector2(100, 100), 0, false)]  # Not GK
	# 15px away: outside 10px normal radius
	var result := possession.check_possession(infos, Vector2(115, 100))
	assert_eq(result, -1, "Non-GK should not use GK radius")


# ===== Loose ball speed threshold =====

func test_fast_ball_blocks_pickup():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100), 0.0, 5.0)
	assert_eq(result, -1, "Fast ball should block pickup")


func test_slow_ball_allows_pickup():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(infos, Vector2(105, 100), 0.0, 2.0)
	assert_eq(result, 0, "Slow ball should allow pickup")


func test_ball_at_exact_speed_threshold_blocks():
	var infos: Array = [_info(Vector2(100, 100))]
	var result := possession.check_possession(
		infos, Vector2(105, 100), 0.0, 4.0)
	assert_eq(result, -1, "Ball at exact speed threshold should block pickup")


# ===== Dribble leash =====

func test_possession_retained_within_dribble_radius():
	var infos: Array = [_info(Vector2(100, 100))]
	# Gain possession first
	possession.check_possession(infos, Vector2(105, 100))
	assert_eq(possession.possessor_index, 0)
	# Ball drifts to 12px away — still within 14px DRIBBLE_RADIUS
	var result := possession.check_possession(infos, Vector2(112, 100))
	assert_eq(result, 0, "Should retain possession within dribble radius")


func test_possession_lost_beyond_dribble_radius():
	var infos: Array = [_info(Vector2(100, 100))]
	# Gain possession
	possession.check_possession(infos, Vector2(105, 100))
	# Ball moves to 20px away — beyond 14px DRIBBLE_RADIUS
	var result := possession.check_possession(infos, Vector2(120, 100))
	assert_eq(result, -1, "Should lose possession beyond dribble radius")


# ===== Contested ball =====

func test_contested_different_teams_approach_speed_wins():
	# Two players at roughly the same distance but different approach speeds
	var ball_pos := Vector2(100, 100)
	var infos: Array = [
		# Team 0 — 8px away, moving toward ball
		_info(Vector2(92, 100), 0, false, Vector2(2.0, 0.0)),
		# Team 1 — 8px away, stationary
		_info(Vector2(108, 100), 1, false, Vector2.ZERO),
	]
	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, 0, "Player with higher approach speed should win contested ball")


func test_contested_one_approaching_one_retreating():
	var ball_pos := Vector2(100, 100)
	var infos: Array = [
		# Team 0 — 8px away, moving away from ball
		_info(Vector2(92, 100), 0, false, Vector2(-2.0, 0.0)),
		# Team 1 — 8px away, moving toward ball
		_info(Vector2(108, 100), 1, false, Vector2(-2.0, 0.0)),
	]
	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, 1, "Approaching player should beat retreating player")


func test_same_team_candidates_closest_wins():
	var ball_pos := Vector2(100, 100)
	var infos: Array = [
		_info(Vector2(93, 100), 0),  # 7px away
		_info(Vector2(95, 100), 0),  # 5px away — closer
	]
	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, 1, "Same-team: closest player should win")


# ===== Dribble target (6px offset) =====

func test_dribble_target_right():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2.RIGHT)
	assert_almost_eq(pos.x, 106.0, 0.1, "Dribble target right X = player + 6")
	assert_almost_eq(pos.y, 100.0, 0.1, "Dribble target right Y unchanged")


func test_dribble_target_down():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2.DOWN)
	assert_almost_eq(pos.x, 100.0, 0.1, "Dribble target down X unchanged")
	assert_almost_eq(pos.y, 106.0, 0.1, "Dribble target down Y = player + 6")


func test_dribble_target_diagonal():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2(1, 1).normalized())
	var expected_offset := 6.0 * 0.707107
	assert_almost_eq(pos.x, 100.0 + expected_offset, 0.2, "Dribble target SE X")
	assert_almost_eq(pos.y, 100.0 + expected_offset, 0.2, "Dribble target SE Y")


func test_dribble_target_zero_facing_defaults_to_down():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2.ZERO)
	assert_almost_eq(pos.x, 100.0, 0.1, "Default X unchanged")
	assert_almost_eq(pos.y, 106.0, 0.1, "Default Y = player + 6 (south)")


func test_dribble_target_left():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2.LEFT)
	assert_almost_eq(pos.x, 94.0, 0.1, "Dribble target left X = player - 6")
	assert_almost_eq(pos.y, 100.0, 0.1, "Dribble target left Y unchanged")


func test_dribble_target_up():
	var pos := PossessionPure.get_dribble_target(
		Vector2(100, 100), Vector2.UP)
	assert_almost_eq(pos.x, 100.0, 0.1, "Dribble target up X unchanged")
	assert_almost_eq(pos.y, 94.0, 0.1, "Dribble target up Y = player - 6")


# ===== Pickup damping flag =====

func test_was_pickup_set_on_gain():
	var infos: Array = [_info(Vector2(100, 100))]
	possession.check_possession(infos, Vector2(105, 100))
	assert_true(possession.was_pickup_this_frame,
		"was_pickup_this_frame should be true on first possession")


func test_was_pickup_cleared_on_retain():
	var infos: Array = [_info(Vector2(100, 100))]
	# Gain possession
	possession.check_possession(infos, Vector2(105, 100))
	assert_true(possession.was_pickup_this_frame)
	# Retain possession — flag should clear
	possession.check_possession(infos, Vector2(105, 100))
	assert_false(possession.was_pickup_this_frame,
		"was_pickup_this_frame should be false when retaining possession")


# ===== Possession linger =====

func test_team_has_ball_during_linger():
	var infos: Array = [_info(Vector2(100, 100), 0)]
	# Gain possession for team 0
	possession.check_possession(infos, Vector2(105, 100))
	assert_true(possession.team_has_ball(0))
	# Lose possession (ball far away)
	possession.check_possession(infos, Vector2(200, 200))
	# Team 0 should still register during linger
	assert_true(possession.team_has_ball(0),
		"Team should still 'have ball' during linger period")


func test_linger_expires_after_frames():
	var infos: Array = [_info(Vector2(100, 100), 0)]
	# Gain then lose possession
	possession.check_possession(infos, Vector2(105, 100))
	possession.check_possession(infos, Vector2(200, 200))
	# Tick through full linger period
	for i in range(PossessionPure.LINGER_FRAMES):
		possession.check_possession(infos, Vector2(200, 200))
	assert_false(possession.team_has_ball(0),
		"Linger should expire after LINGER_FRAMES ticks")


func test_linger_resets_on_new_possession():
	var infos: Array = [
		_info(Vector2(100, 100), 0),
		_info(Vector2(200, 200), 1),
	]
	# Team 0 gains possession
	possession.check_possession(infos, Vector2(105, 100))
	# Lose it
	possession.check_possession(infos, Vector2(300, 300))
	# Tick a few frames (not full linger)
	for i in range(5):
		possession.check_possession(infos, Vector2(300, 300))
	# Team 1 gains possession
	possession.check_possession(infos, Vector2(205, 200))
	assert_true(possession.team_has_ball(1),
		"New possession should update linger team")
	assert_eq(possession.team_linger_id, 1)


# ===== Query API =====

func test_player_has_ball():
	var infos: Array = [_info(Vector2(100, 100)), _info(Vector2(200, 200))]
	possession.check_possession(infos, Vector2(105, 100))
	assert_true(possession.player_has_ball(0), "Player 0 should have ball")
	assert_false(possession.player_has_ball(1), "Player 1 should not have ball")


func test_is_ball_loose():
	assert_true(possession.is_ball_loose(), "Ball should start loose")
	var infos: Array = [_info(Vector2(100, 100))]
	possession.check_possession(infos, Vector2(105, 100))
	assert_false(possession.is_ball_loose(), "Ball should not be loose after pickup")


func test_get_possessing_team():
	var infos: Array = [_info(Vector2(100, 100), 1)]
	possession.check_possession(infos, Vector2(105, 100))
	assert_eq(possession.get_possessing_team(), 1, "Should return team_id of possessor")


func test_get_possessor():
	var infos: Array = [_info(Vector2(100, 100)), _info(Vector2(105, 100))]
	possession.check_possession(infos, Vector2(104, 100))
	assert_eq(possession.get_possessor(), 1, "Should return index of closest player")
