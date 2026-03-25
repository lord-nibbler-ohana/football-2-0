extends GutTest
## Tests for PassTargetingPure — auto-targeted pass finding.

const MAX_KICK_SPEED := 8.0  # Matches KickStatePure.MAX_KICK_SPEED


func _player(pos: Vector2, team_id: int = 0) -> Dictionary:
	return {"position": pos, "team_id": team_id}


# ── No teammates ──

func test_no_players_returns_not_found():
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, [], 0)
	assert_false(result["found"])


func test_only_opponents_returns_not_found():
	var players := [_player(Vector2(300, 400), 0), _player(Vector2(300, 300), 1)]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_false(result["found"])


# ── Teammate in cone ──

func test_teammate_directly_ahead_found():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker
		_player(Vector2(300, 300), 0),  # teammate ahead (UP = -Y)
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_true(result["found"])
	assert_eq(result["position"], Vector2(300, 300))


# ── Teammate outside cone rejected ──

func test_teammate_behind_rejected():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker facing UP
		_player(Vector2(300, 500), 0),  # teammate behind
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_false(result["found"])


func test_teammate_at_90_degrees_rejected():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker facing UP
		_player(Vector2(450, 400), 0),  # teammate to the right (90 deg off)
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_false(result["found"])


# ── Closest teammate preferred ──

func test_closer_teammate_preferred():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker
		_player(Vector2(300, 350), 0),  # close teammate
		_player(Vector2(300, 200), 0),  # far teammate
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_true(result["found"])
	assert_eq(result["position"], Vector2(300, 350))


# ── Angle penalty affects scoring ──

func test_angled_teammate_loses_to_direct():
	# Both at same distance, but one is more on-angle
	var players := [
		_player(Vector2(300, 400), 0),  # kicker facing UP
		_player(Vector2(300, 300), 0),  # directly ahead (100px, 0 angle)
		_player(Vector2(370, 300), 0),  # off angle (~35 deg, ~116px)
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_eq(result["position"], Vector2(300, 300), "direct teammate should win")


# ── Distance thresholds ──

func test_too_close_teammate_rejected():
	var players := [
		_player(Vector2(300, 400), 0),
		_player(Vector2(300, 390), 0),  # 10px away, under MIN_PASS_DISTANCE
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_false(result["found"])


func test_too_far_teammate_rejected():
	var players := [
		_player(Vector2(300, 600), 0),
		_player(Vector2(300, 50), 0),  # 550px away, over MAX_PASS_DISTANCE
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 600), Vector2.UP, 0, players, 0)
	assert_false(result["found"])


# ── Blocked lane penalty ──

func test_blocked_lane_penalises_target():
	# Two teammates ahead, one has opponent in the lane
	var players := [
		_player(Vector2(300, 400), 0),  # kicker
		_player(Vector2(300, 300), 0),  # teammate A (direct)
		_player(Vector2(340, 300), 0),  # teammate B (slightly angled)
		_player(Vector2(300, 350), 1),  # opponent blocking lane to A
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_true(result["found"])
	# Teammate B should win because A's lane is blocked
	assert_eq(result["position"], Vector2(340, 300))


# ── Lane blocking detection ──

func test_lane_blocked_with_opponent_in_path():
	var blocked := PassTargetingPure.is_lane_blocked(
		Vector2(300, 400), Vector2(300, 200),
		[Vector2(300, 300)], 15.0)
	assert_true(blocked)


func test_lane_clear_no_opponents():
	var blocked := PassTargetingPure.is_lane_blocked(
		Vector2(300, 400), Vector2(300, 200),
		[Vector2(400, 300)], 15.0)
	assert_false(blocked)


func test_lane_not_blocked_by_opponent_behind():
	var blocked := PassTargetingPure.is_lane_blocked(
		Vector2(300, 400), Vector2(300, 200),
		[Vector2(300, 450)], 15.0)
	assert_false(blocked)


# ── Pass velocity computation ──

func test_pass_velocity_direction_correct():
	var result := PassTargetingPure.compute_pass_velocity(
		Vector2(300, 400), Vector2(300, 300), MAX_KICK_SPEED)
	var vel: Vector2 = result["velocity"]
	assert_almost_eq(vel.normalized().x, 0.0, 0.01)
	assert_lt(vel.y, 0.0, "should point upward (negative Y)")
	assert_eq(result["up_velocity"], 0.0, "ground pass")


func test_pass_velocity_power_scales_with_distance():
	var close := PassTargetingPure.compute_pass_velocity(
		Vector2(300, 400), Vector2(300, 370), MAX_KICK_SPEED)
	var far := PassTargetingPure.compute_pass_velocity(
		Vector2(300, 400), Vector2(300, 200), MAX_KICK_SPEED)
	assert_gt(far["velocity"].length(), close["velocity"].length(),
		"farther target = more power")


func test_pass_velocity_capped_at_max():
	# Very far target — power should still be capped
	var result := PassTargetingPure.compute_pass_velocity(
		Vector2(300, 600), Vector2(300, 100), MAX_KICK_SPEED)
	var speed: float = result["velocity"].length()
	var max_speed := PassTargetingPure.MAX_PASS_POWER * MAX_KICK_SPEED
	assert_almost_eq(speed, max_speed, 0.01, "should be capped at MAX_PASS_POWER")


# ── Kicker exclusion ──

func test_kicker_excluded_from_targets():
	var players := [
		_player(Vector2(300, 400), 0),  # kicker at index 0
	]
	var result := PassTargetingPure.find_best_target(
		Vector2(300, 400), Vector2.UP, 0, players, 0)
	assert_false(result["found"], "should not target self")
