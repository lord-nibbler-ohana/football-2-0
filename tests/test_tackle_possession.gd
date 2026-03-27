extends GutTest
## Tests for tackle → possession handoff.
## Verifies that downed players cannot retain possession via dribble leash.


func _info(pos: Vector2, team: int = 0, eligible: bool = true,
		gk: bool = false, vel: Vector2 = Vector2.ZERO) -> Dictionary:
	return {
		"position": pos,
		"team_id": team,
		"is_goalkeeper": gk,
		"is_home": team == 0,
		"velocity": vel,
		"eligible": eligible,
	}


## Simulate the exact post-tackle scenario:
## - Carrier (team 0) at (200, 300), knocked down (ineligible)
## - Ball kicked 7 px/frame to the right
## - Tackler (team 1) at (210, 300), eligible
## Verify: downed carrier does NOT retain possession via dribble leash.
func test_downed_carrier_loses_possession_after_tackle():
	var possession := PossessionPure.new()

	# Frame 0: carrier has possession normally
	var carrier_pos := Vector2(200, 300)
	var tackler_pos := Vector2(210, 300)
	var ball_pos := Vector2(200, 300)

	var infos := [
		_info(carrier_pos, 0, true),   # carrier - eligible
		_info(tackler_pos, 1, true),   # tackler - eligible
	]
	var idx := possession.check_possession(infos, ball_pos, 0.0, 0.0)
	assert_eq(idx, 0, "Carrier should have initial possession")

	# Tackle happens: ball kicked right at 7 px/frame, carrier now ineligible
	# Simulate 1 frame of ball movement
	ball_pos = Vector2(207, 300)  # Ball moved 7px right

	infos = [
		_info(carrier_pos, 0, false),  # carrier - knocked down, ineligible
		_info(tackler_pos, 1, true),   # tackler - eligible
	]
	idx = possession.check_possession(infos, ball_pos, 0.0, 0.0)
	# The downed carrier is 7px from ball (< DRIBBLE_RADIUS of 12)
	# but should NOT retain possession because they're ineligible
	assert_ne(idx, 0,
		"Downed carrier should NOT retain possession via dribble leash")


## Even if the ball hasn't moved far, an ineligible possessor must lose the ball.
func test_dribble_leash_respects_eligibility():
	var possession := PossessionPure.new()

	var player_pos := Vector2(200, 300)
	var ball_pos := Vector2(200, 300)

	# Give player possession
	var infos := [_info(player_pos, 0, true)]
	var idx := possession.check_possession(infos, ball_pos, 0.0, 0.0)
	assert_eq(idx, 0, "Player should have possession")

	# Ball barely moved, but player is now ineligible
	ball_pos = Vector2(201, 300)  # 1px away
	infos = [_info(player_pos, 0, false)]
	idx = possession.check_possession(infos, ball_pos, 0.0, 0.0)
	assert_eq(idx, -1,
		"Ineligible player should lose possession even within dribble radius")


## After tackle, nearby opponent should be able to pick up the ball.
func test_opponent_picks_up_after_tackle_knockdown():
	var possession := PossessionPure.new()

	# Initial: carrier has ball
	var carrier_pos := Vector2(200, 300)
	var opponent_pos := Vector2(206, 300)
	var ball_pos := Vector2(200, 300)

	var infos := [
		_info(carrier_pos, 0, true),
		_info(opponent_pos, 1, true),
	]
	var idx := possession.check_possession(infos, ball_pos, 0.0, 0.0)
	assert_eq(idx, 0, "Carrier starts with possession")

	# Tackle: ball nudged slightly, carrier downed, opponent eligible
	ball_pos = Vector2(203, 300)  # Ball moved 3px
	infos = [
		_info(carrier_pos, 0, false),   # carrier downed
		_info(opponent_pos, 1, true),   # opponent eligible, 3px from ball
	]
	idx = possession.check_possession(infos, ball_pos, 0.0, 0.0)
	assert_eq(idx, 1,
		"Opponent should pick up ball near downed carrier")


## Simulate multiple frames post-tackle to ensure no possession ping-pong.
func test_no_possession_retention_over_multiple_frames():
	var possession := PossessionPure.new()

	var carrier_pos := Vector2(200, 300)
	var opponent_pos := Vector2(208, 300)
	var ball_pos := Vector2(200, 300)
	var ball_vel := Vector2(7, 0)  # 7 px/frame kick to right

	# Frame 0: carrier has ball
	var infos := [
		_info(carrier_pos, 0, true),
		_info(opponent_pos, 1, true),
	]
	possession.check_possession(infos, ball_pos, 0.0, 0.0)

	# Simulate 5 frames post-tackle
	var carrier_had_ball_while_down := false
	for frame in range(5):
		ball_pos += ball_vel
		ball_vel *= BallPhysicsPure.AIR_FRICTION  # Slow down

		infos = [
			_info(carrier_pos, 0, false),  # carrier stays downed
			_info(opponent_pos, 1, true),  # opponent eligible
		]
		var idx := possession.check_possession(infos, ball_pos, 0.0,
			ball_vel.length())
		if idx == 0:
			carrier_had_ball_while_down = true

	assert_false(carrier_had_ball_while_down,
		"Downed carrier should never regain possession across any frame")
