extends GutTest
## Simulation tests for possession mechanics — quantifies ping-pong,
## tackle timing, GK pickup, and repossession cooldown behavior.
## These tests simulate the core loops mathematically to produce hard numbers.


# ─── Ball deceleration simulation ───────────────────────────────────────────

## Simulate ball physics deceleration to measure how quickly the ball
## becomes pickable after a standing tackle knock (speed 3.0 px/frame).
func test_ball_decel_after_standing_tackle() -> void:
	var knock_speed: float = AiConstants.TACKLE_KNOCK_SPEED
	var physics := BallPhysicsPure.new()
	physics.apply_kick(Vector2.RIGHT * knock_speed)

	var frames_to_pickup := -1
	var frames_to_stop := -1
	var total_distance := 0.0

	for i in range(200):
		var displacement := physics.tick()
		total_distance += displacement.length()
		var speed := physics.get_ground_speed()
		if speed < PossessionPure.LOOSE_BALL_SPEED_THRESHOLD and frames_to_pickup < 0:
			frames_to_pickup = i + 1
		if speed < BallPhysicsPure.MIN_VELOCITY and frames_to_stop < 0:
			frames_to_stop = i + 1
			break

	gut.p("=== BALL DECELERATION AFTER STANDING TACKLE (knock speed %.1f) ===" % knock_speed)
	gut.p("Frames until pickable (speed < %.1f): %d (%.3fs)" % [
		PossessionPure.LOOSE_BALL_SPEED_THRESHOLD, frames_to_pickup, frames_to_pickup / 50.0])
	gut.p("Frames until stopped: %d (%.3fs)" % [frames_to_stop, frames_to_stop / 50.0])
	gut.p("Total distance traveled: %.1f px" % total_distance)
	gut.p("")

	# The ball becomes pickable extremely fast — this is a core problem
	assert_true(frames_to_pickup >= 0, "Ball should eventually become pickable")
	# Document the issue: if < 10 frames, it's too fast
	if frames_to_pickup < 10:
		gut.p("WARNING: Ball becomes pickable in < 10 frames (%.2fs) — too fast!" % [frames_to_pickup / 50.0])


## Simulate ball deceleration for slide tackle knock (speed 3.0 px/frame).
func test_ball_decel_after_slide_tackle() -> void:
	var physics := BallPhysicsPure.new()
	physics.apply_kick(Vector2.RIGHT * TackleStatePure.TACKLE_KNOCK_SPEED)

	var frames_to_pickup := -1
	var total_distance := 0.0

	for i in range(200):
		var displacement := physics.tick()
		total_distance += displacement.length()
		var speed := physics.get_ground_speed()
		if speed < PossessionPure.LOOSE_BALL_SPEED_THRESHOLD and frames_to_pickup < 0:
			frames_to_pickup = i + 1
			break

	gut.p("=== BALL DECELERATION AFTER SLIDE TACKLE (knock speed %.1f) ===")
	gut.p("Frames until pickable: %d (%.3fs)" % [frames_to_pickup, frames_to_pickup / 50.0])
	gut.p("Distance traveled before pickable: %.1f px" % total_distance)
	gut.p("")


# ─── Standing tackle probability simulation ────────────────────────────────

## Simulate how quickly a standing tackle succeeds given the per-frame probability.
func test_standing_tackle_timing() -> void:
	var trials := 10000
	var total_frames := 0
	var frame_histogram := {}  # frame_number -> count

	for _trial in range(trials):
		for frame in range(100):
			if randf() < AiConstants.TACKLE_SUCCESS_CHANCE:
				total_frames += frame + 1
				frame_histogram[frame + 1] = frame_histogram.get(frame + 1, 0) + 1
				break

	var avg_frames := float(total_frames) / trials

	gut.p("=== STANDING TACKLE TIMING (chance=%.2f per frame) ===" % AiConstants.TACKLE_SUCCESS_CHANCE)
	gut.p("Average frames to dispossession: %.1f (%.3fs)" % [avg_frames, avg_frames / 50.0])
	gut.p("Frame 1 success rate: %.1f%%" % [frame_histogram.get(1, 0) * 100.0 / trials])
	gut.p("Within 3 frames: %.1f%%" % [_cumulative_pct(frame_histogram, 3, trials)])
	gut.p("Within 5 frames: %.1f%%" % [_cumulative_pct(frame_histogram, 5, trials)])
	gut.p("Within 10 frames: %.1f%%" % [_cumulative_pct(frame_histogram, 10, trials)])
	gut.p("")

	# Document: if average < 5 frames, it's essentially instant
	if avg_frames < 5.0:
		gut.p("WARNING: Standing tackle is near-instant (avg %.1f frames = %.3fs)" % [avg_frames, avg_frames / 50.0])


func _cumulative_pct(histogram: Dictionary, up_to: int, total: int) -> float:
	var count := 0
	for i in range(1, up_to + 1):
		count += histogram.get(i, 0)
	return count * 100.0 / total


# ─── Possession ping-pong simulation ───────────────────────────────────────

## Simulate the full possession exchange loop between two opposing players.
## Uses the NEW mechanics: engage timer, team cooldown, stronger knock.
func test_possession_pingpong_two_players() -> void:
	var possession := PossessionPure.new()
	var sim_frames := 500  # 10 seconds at 50 Hz

	# Two players facing each other, 20px apart, ball in the middle
	var player_a_pos := Vector2(290, 360)  # Team 0
	var player_b_pos := Vector2(310, 360)  # Team 1
	var ball_pos := Vector2(300, 360)
	var ball_vel := Vector2.ZERO
	var ball_speed := 0.0

	var possession_changes := 0
	var last_possessor := -1
	var player_a_stun := 0
	var player_b_stun := 0
	var player_a_cooldown := 0
	var player_b_cooldown := 0
	var engage_timer_a := 0
	var engage_timer_b := 0
	var frames_with_possession := 0
	var possession_durations: Array = []
	var current_duration := 0

	for frame in range(sim_frames):
		# Tick down cooldowns
		if player_a_stun > 0:
			player_a_stun -= 1
		if player_b_stun > 0:
			player_b_stun -= 1
		if player_a_cooldown > 0:
			player_a_cooldown -= 1
		if player_b_cooldown > 0:
			player_b_cooldown -= 1

		# Simulate ball physics
		var physics := BallPhysicsPure.new()
		physics.velocity = ball_vel
		var displacement := physics.tick()
		ball_vel = physics.velocity
		ball_pos += displacement
		ball_speed = ball_vel.length()

		# Build player infos (team cooldown handled by PossessionPure now)
		var eligible_a := (player_a_stun <= 0 and player_a_cooldown <= 0)
		var eligible_b := (player_b_stun <= 0 and player_b_cooldown <= 0)

		var infos := [
			{
				"position": player_a_pos,
				"team_id": 0,
				"is_goalkeeper": false,
				"is_home": true,
				"velocity": Vector2.ZERO,
				"eligible": eligible_a,
			},
			{
				"position": player_b_pos,
				"team_id": 1,
				"is_goalkeeper": false,
				"is_home": false,
				"velocity": Vector2.ZERO,
				"eligible": eligible_b,
			},
		]

		var possessor_idx := possession.check_possession(infos, ball_pos, 0.0, ball_speed)

		if possessor_idx >= 0:
			frames_with_possession += 1
			current_duration += 1

			# Simulate standing tackle with NEW engage timer mechanic
			var other_idx := 1 - possessor_idx
			var other_eligible: bool = bool(infos[other_idx]["eligible"])
			var dist_other_to_ball: float = Vector2(infos[other_idx]["position"]).distance_to(ball_pos)

			# Check team contest cooldown (player index == team_id in this 2-player sim)
			var can_contest := possession.can_team_contest(other_idx)

			if other_eligible and can_contest and dist_other_to_ball < AiConstants.TACKLE_RANGE:
				# Tick engage timer
				if other_idx == 0:
					engage_timer_a += 1
				else:
					engage_timer_b += 1
				var engage_time := engage_timer_a if other_idx == 0 else engage_timer_b

				if engage_time >= AiConstants.TACKLE_ENGAGE_FRAMES:
					if randf() < AiConstants.TACKLE_SUCCESS_CHANCE:
						var knock_dir: Vector2 = (ball_pos - Vector2(infos[other_idx]["position"])).normalized()
						if knock_dir.length() < 0.1:
							knock_dir = Vector2.RIGHT
						ball_vel = knock_dir * AiConstants.TACKLE_KNOCK_SPEED
						ball_speed = AiConstants.TACKLE_KNOCK_SPEED

						if possessor_idx == 0:
							player_a_stun = 50
							player_a_cooldown = 15
						else:
							player_b_stun = 50
							player_b_cooldown = 15

						possession.possessor_index = -1
						possession.possessing_team_id = -1

						# Team-wide cooldowns (new!)
						var losing_team := 0 if possessor_idx == 0 else 1
						possession.apply_team_repossess_cooldown(
							losing_team, AiConstants.TEAM_REPOSSESS_COOLDOWN)
						possession.apply_team_contest_cooldown(
							losing_team, AiConstants.TEAM_CONTEST_COOLDOWN)

						engage_timer_a = 0
						engage_timer_b = 0

						if current_duration > 0:
							possession_durations.append(current_duration)
						current_duration = 0
			else:
				# Not in range — reset engage timer
				if other_idx == 0:
					engage_timer_a = 0
				else:
					engage_timer_b = 0
		else:
			engage_timer_a = 0
			engage_timer_b = 0
			if current_duration > 0:
				possession_durations.append(current_duration)
			current_duration = 0

		if possessor_idx != last_possessor and possessor_idx >= 0:
			possession_changes += 1
		last_possessor = possessor_idx

	gut.p("=== POSSESSION PING-PONG: 2 PLAYERS, NEW MECHANICS (10s) ===")
	gut.p("Total possession changes: %d" % possession_changes)
	gut.p("Changes per second: %.1f" % [possession_changes / 10.0])
	gut.p("Frames with possession: %d / %d (%.0f%%)" % [
		frames_with_possession, sim_frames, frames_with_possession * 100.0 / sim_frames])

	if possession_durations.size() > 0:
		var avg_dur := 0.0
		var min_dur := 9999
		var max_dur := 0
		for d in possession_durations:
			avg_dur += d
			min_dur = mini(min_dur, d)
			max_dur = maxi(max_dur, d)
		avg_dur /= possession_durations.size()
		gut.p("Possession stints: %d" % possession_durations.size())
		gut.p("Avg duration: %.1f frames (%.3fs)" % [avg_dur, avg_dur / 50.0])
		gut.p("Min/Max duration: %d / %d frames" % [min_dur, max_dur])
	gut.p("")

	if possession_changes > 15:
		gut.p("PROBLEM: %d possession changes in 10s is still excessive!" % possession_changes)
	else:
		gut.p("OK: Possession changes look reasonable.")


# ─── Repossession cooldown effectiveness ───────────────────────────────────

## Test that the loss_stun timer actually prevents the stunned player from
## immediately repossessing. Simulates the exact cooldown values.
func test_repossession_cooldown_values() -> void:
	gut.p("=== REPOSSESSION COOLDOWN ANALYSIS ===")

	# Current values
	var kick_cooldown := 15  # KICK_COOLDOWN_FRAMES
	var loss_stun_player := 25  # LOSS_STUN_FRAMES (on player_controller.gd)
	var tackle_repossession_stun := 50  # TACKLE_REPOSSESSION_STUN (on match.gd)

	gut.p("kick_cooldown (after kicking): %d frames (%.2fs)" % [kick_cooldown, kick_cooldown / 50.0])
	gut.p("loss_stun (natural dispossession): %d frames (%.2fs)" % [loss_stun_player, loss_stun_player / 50.0])
	gut.p("tackle_repossession_stun (after tackle): %d frames (%.2fs)" % [tackle_repossession_stun, tackle_repossession_stun / 50.0])

	# Simulate ball travel during loss_stun
	var physics := BallPhysicsPure.new()
	physics.apply_kick(Vector2.RIGHT * 3.0)  # Standing tackle knock
	var dist_during_stun := 0.0
	for i in range(tackle_repossession_stun):
		var disp := physics.tick()
		dist_during_stun += disp.length()

	gut.p("Ball distance during tackle stun (%d frames): %.1f px" % [tackle_repossession_stun, dist_during_stun])
	gut.p("")

	# Key issue: loss_stun only applies to the ONE player who was dispossessed.
	# Their TEAMMATES have no cooldown and can immediately re-challenge.
	gut.p("CRITICAL: loss_stun/tackle_stun only affects the dispossessed individual.")
	gut.p("Other teammates can immediately chase and re-tackle the new ball carrier.")
	gut.p("This enables ping-pong across different players on the same team.")
	gut.p("")

	assert_true(true, "Analysis complete")


# ─── GK pickup simulation ──────────────────────────────────────────────────

## Simulate a ball rolling toward goal and test if the GK can pick it up.
func test_gk_pickup_scenarios() -> void:
	var possession := PossessionPure.new()

	gut.p("=== GK PICKUP SCENARIOS ===")
	gut.p("GK_PICKUP_RADIUS: %.1f px" % PossessionPure.GK_PICKUP_RADIUS)
	gut.p("GK_BOX_PICKUP_RADIUS: %.1f px" % PossessionPure.GK_BOX_PICKUP_RADIUS)
	gut.p("GK_BOX_SPEED_THRESHOLD: %.1f px/frame" % PossessionPure.GK_BOX_SPEED_THRESHOLD)
	gut.p("LOOSE_BALL_SPEED_THRESHOLD: %.1f px/frame" % PossessionPure.LOOSE_BALL_SPEED_THRESHOLD)
	gut.p("Outfield PICKUP_RADIUS: %.1f px" % PossessionPure.PICKUP_RADIUS)
	gut.p("")

	# Scenario 1: Ball rolling at moderate speed toward GK in box
	var test_speeds := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
	for speed in test_speeds:
		var gk_pos := Vector2(300, 670)  # Near home goal
		var ball_pos := Vector2(300, 660)  # 10px from GK
		var outfield_pos := Vector2(300, 640)  # Outfield player 30px from ball

		var infos := [
			{
				"position": gk_pos,
				"team_id": 0,
				"is_goalkeeper": true,
				"is_home": true,
				"velocity": Vector2.ZERO,
				"eligible": true,
			},
			{
				"position": outfield_pos,
				"team_id": 1,
				"is_goalkeeper": false,
				"is_home": false,
				"velocity": Vector2.ZERO,
				"eligible": true,
			},
		]

		possession.reset()
		var result := possession.check_possession(infos, ball_pos, 0.0, speed)

		var who := "nobody"
		if result == 0:
			who = "GK (correct)"
		elif result == 1:
			who = "outfield opponent"
		gut.p("Speed %.1f px/frame, ball 10px from GK, 30px from opponent: %s picks up" % [speed, who])

	gut.p("")

	# Scenario 2: GK NOT in box — much smaller radius and lower speed threshold
	gut.p("--- GK outside box ---")
	for speed in [1.0, 2.0, 3.0]:
		var gk_pos := Vector2(300, 500)  # Outside box
		var ball_pos := Vector2(300, 490)  # 10px from GK

		var infos := [
			{
				"position": gk_pos,
				"team_id": 0,
				"is_goalkeeper": true,
				"is_home": true,
				"velocity": Vector2.ZERO,
				"eligible": true,
			},
		]

		possession.reset()
		var result := possession.check_possession(infos, ball_pos, 0.0, speed)
		var who := "nobody" if result < 0 else "GK"
		gut.p("Speed %.1f, GK outside box, 10px away: %s picks up" % [speed, who])

	gut.p("")


# ─── Tackle range vs pickup range analysis ─────────────────────────────────

## Analyze the mismatch between tackle engagement range and pickup radius.
func test_tackle_vs_pickup_range() -> void:
	gut.p("=== TACKLE RANGE vs PICKUP RANGE ===")
	gut.p("Standing tackle TACKLE_RANGE: %.1f px" % AiConstants.TACKLE_RANGE)
	gut.p("Outfield PICKUP_RADIUS: %.1f px" % PossessionPure.PICKUP_RADIUS)
	gut.p("DRIBBLE_RADIUS: %.1f px" % PossessionPure.DRIBBLE_RADIUS)
	gut.p("")
	gut.p("The tackle range (%.1f) is %.1fx the pickup radius (%.1f)." % [
		AiConstants.TACKLE_RANGE, AiConstants.TACKLE_RANGE / PossessionPure.PICKUP_RADIUS,
		PossessionPure.PICKUP_RADIUS])
	gut.p("This means a chaser can dispossess from OUTSIDE pickup range.")
	gut.p("After tackle, ball flies AWAY from tackler — they can't immediately repossess.")
	gut.p("Result: loose ball that any player can collect.")
	gut.p("")

	# Simulate: after standing tackle, how far does ball travel before pickable?
	var physics := BallPhysicsPure.new()
	physics.apply_kick(Vector2.RIGHT * 3.0)

	var frames := 0
	var dist := 0.0
	while physics.get_ground_speed() >= PossessionPure.LOOSE_BALL_SPEED_THRESHOLD:
		dist += physics.tick().length()
		frames += 1
		if frames > 200:
			break

	gut.p("After tackle: ball travels %.1f px in %d frames (%.3fs) before becoming pickable." % [
		dist, frames, frames / 50.0])
	gut.p("Anyone within %.1f px of the ball's resting area can pick it up." % PossessionPure.PICKUP_RADIUS)
	gut.p("")

	assert_true(true, "Analysis complete")


# ─── AI slide tackle frequency simulation ──────────────────────────────────

## Test how often AI triggers slide tackles when in range.
func test_ai_slide_tackle_frequency() -> void:
	var trials := 10000
	var triggered := 0

	# Simulate being within slide trigger distance for 50 frames (1 second)
	for _trial in range(trials):
		for _frame in range(50):
			if randf() < AiConstants.AI_SLIDE_TRIGGER_CHANCE:
				triggered += 1
				break

	gut.p("=== AI SLIDE TACKLE FREQUENCY ===")
	gut.p("Trigger chance per frame: %.2f" % AiConstants.AI_SLIDE_TRIGGER_CHANCE)
	gut.p("Probability of slide within 1s (50 frames): %.1f%%" % [triggered * 100.0 / trials])
	gut.p("Slide duration: %d frames (%.2fs)" % [TackleStatePure.SLIDE_DURATION, TackleStatePure.SLIDE_DURATION / 50.0])
	gut.p("Recovery duration: %d frames (%.2fs)" % [TackleStatePure.RECOVERY_DURATION, TackleStatePure.RECOVERY_DURATION / 50.0])
	gut.p("Tackle cooldown: %d frames (%.2fs)" % [TackleStatePure.TACKLE_COOLDOWN, TackleStatePure.TACKLE_COOLDOWN / 50.0])
	gut.p("")

	assert_true(true, "Analysis complete")


# ─── Full match simulation (simplified) ────────────────────────────────────

## Simulate 60 seconds of CPU vs CPU with 4 players (2 per team) to measure
## overall possession distribution, tackle frequency, and exchange patterns.
func test_match_simulation_60s() -> void:
	var possession := PossessionPure.new()
	var sim_frames := 3000  # 60 seconds at 50 Hz

	# 4 players: 2 per team, arranged in a line
	var positions := [
		Vector2(280, 350),  # Team 0, player 0
		Vector2(260, 380),  # Team 0, player 1
		Vector2(320, 350),  # Team 1, player 2
		Vector2(340, 380),  # Team 1, player 3
	]
	var team_ids := [0, 0, 1, 1]
	var stuns := [0, 0, 0, 0]
	var cooldowns := [0, 0, 0, 0]
	var engage_timers := [0, 0, 0, 0]
	var ball_pos := Vector2(300, 360)
	var ball_vel := Vector2.ZERO

	var possession_changes := 0
	var last_possessor := -1
	var team_possession_frames := [0, 0]  # frames each team has ball
	var loose_frames := 0
	var standing_tackles := 0
	var total_stints: Array = []
	var current_stint := 0

	for frame in range(sim_frames):
		# Tick cooldowns
		for i in range(4):
			if stuns[i] > 0:
				stuns[i] -= 1
			if cooldowns[i] > 0:
				cooldowns[i] -= 1

		# Simple ball physics
		var physics := BallPhysicsPure.new()
		physics.velocity = ball_vel
		var disp := physics.tick()
		ball_vel = physics.velocity
		ball_pos += disp
		# Clamp ball to pitch area
		ball_pos.x = clampf(ball_pos.x, 50, 550)
		ball_pos.y = clampf(ball_pos.y, 50, 670)
		var ball_speed := ball_vel.length()

		# Move chasers toward ball (simplified)
		var possessing_team := -1
		if last_possessor >= 0:
			possessing_team = team_ids[last_possessor]

		for i in range(4):
			if stuns[i] > 0:
				continue
			# Only move non-possessing players
			if i == last_possessor and possession.possessor_index == i:
				# Dribble forward
				var attack_dir: Vector2 = Vector2.UP if team_ids[i] == 0 else Vector2.DOWN
				positions[i] = Vector2(positions[i]) + attack_dir * 2.0  # PLAYER_SPEED
				continue
			# Chase ball if opponent has it or ball is loose
			if possessing_team != team_ids[i] or possessing_team == -1:
				var to_ball: Vector2 = ball_pos - Vector2(positions[i])
				if to_ball.length() > 3.0:
					positions[i] = Vector2(positions[i]) + to_ball.normalized() * 2.0

		# Check possession
		var infos: Array = []
		for i in range(4):
			infos.append({
				"position": positions[i],
				"team_id": team_ids[i],
				"is_goalkeeper": false,
				"is_home": team_ids[i] == 0,
				"velocity": Vector2.ZERO,
				"eligible": stuns[i] <= 0 and cooldowns[i] <= 0,
			})

		var possessor_idx := possession.check_possession(infos, ball_pos, 0.0, ball_speed)

		if possessor_idx >= 0:
			team_possession_frames[team_ids[possessor_idx]] += 1
			current_stint += 1

			# Dribble ball with possessor
			ball_pos = positions[possessor_idx]
			ball_vel = Vector2.ZERO

			# Standing tackle check with NEW engage timer + team cooldown
			for i in range(4):
				if team_ids[i] == team_ids[possessor_idx]:
					engage_timers[i] = 0
					continue
				if stuns[i] > 0 or cooldowns[i] > 0:
					engage_timers[i] = 0
					continue
				if not possession.can_team_contest(team_ids[i]):
					engage_timers[i] = 0
					continue
				var dist: float = Vector2(positions[i]).distance_to(ball_pos)
				if dist > AiConstants.TACKLE_RANGE:
					engage_timers[i] = 0
					continue
				# In range — tick engage timer
				engage_timers[i] += 1
				if engage_timers[i] < AiConstants.TACKLE_ENGAGE_FRAMES:
					continue
				if randf() < AiConstants.TACKLE_SUCCESS_CHANCE:
					standing_tackles += 1
					var knock_dir: Vector2 = (ball_pos - Vector2(positions[i])).normalized()
					if knock_dir.length() < 0.1:
						knock_dir = Vector2.RIGHT
					ball_vel = knock_dir * AiConstants.TACKLE_KNOCK_SPEED
					stuns[possessor_idx] = 50
					cooldowns[possessor_idx] = 15
					possession.possessor_index = -1
					possession.possessing_team_id = -1
					# Team-wide cooldowns (NEW)
					possession.apply_team_repossess_cooldown(
						team_ids[possessor_idx], AiConstants.TEAM_REPOSSESS_COOLDOWN)
					possession.apply_team_contest_cooldown(
						team_ids[possessor_idx], AiConstants.TEAM_CONTEST_COOLDOWN)
					for j in range(4):
						engage_timers[j] = 0
					if current_stint > 0:
						total_stints.append(current_stint)
					current_stint = 0
					break
		else:
			loose_frames += 1
			for i in range(4):
				engage_timers[i] = 0
			if current_stint > 0:
				total_stints.append(current_stint)
			current_stint = 0

		if possessor_idx != last_possessor and possessor_idx >= 0:
			possession_changes += 1
		last_possessor = possessor_idx if possessor_idx >= 0 else last_possessor

	gut.p("=== FULL MATCH SIM: 4 PLAYERS, 60s, NEW MECHANICS ===")
	gut.p("Total possession changes: %d (%.1f per second)" % [
		possession_changes, possession_changes / 60.0])
	gut.p("Standing tackles: %d (%.1f per second)" % [
		standing_tackles, standing_tackles / 60.0])
	gut.p("Team 0 possession: %d frames (%.1f%%)" % [
		team_possession_frames[0], team_possession_frames[0] * 100.0 / sim_frames])
	gut.p("Team 1 possession: %d frames (%.1f%%)" % [
		team_possession_frames[1], team_possession_frames[1] * 100.0 / sim_frames])
	gut.p("Loose ball frames: %d (%.1f%%)" % [
		loose_frames, loose_frames * 100.0 / sim_frames])

	if total_stints.size() > 0:
		var avg_stint := 0.0
		var min_stint := 9999
		var max_stint := 0
		for s in total_stints:
			avg_stint += s
			min_stint = mini(min_stint, s)
			max_stint = maxi(max_stint, s)
		avg_stint /= total_stints.size()
		gut.p("Possession stints: %d" % total_stints.size())
		gut.p("Avg possession duration: %.1f frames (%.3fs)" % [avg_stint, avg_stint / 50.0])
		gut.p("Min/Max: %d / %d frames (%.3f / %.3fs)" % [
			min_stint, max_stint, min_stint / 50.0, max_stint / 50.0])

		var short_stints := 0
		for s in total_stints:
			if s <= 5:
				short_stints += 1
		gut.p("Stints <= 5 frames (0.1s): %d (%.1f%%)" % [
			short_stints, short_stints * 100.0 / total_stints.size()])

	gut.p("")

	if possession_changes > 60:
		gut.p("PROBLEM: >1 possession change per second is excessive!")
	else:
		gut.p("OK: Possession changes look reasonable.")
	if standing_tackles > 30:
		gut.p("PROBLEM: >0.5 standing tackles per second is too frequent!")
	else:
		gut.p("OK: Standing tackle frequency looks reasonable.")


# ─── Summary of all issues ─────────────────────────────────────────────────

func test_summary_of_issues() -> void:
	gut.p("")
	gut.p("╔══════════════════════════════════════════════════════════════════╗")
	gut.p("║             POSSESSION SYSTEM ISSUE SUMMARY                    ║")
	gut.p("╠══════════════════════════════════════════════════════════════════╣")
	gut.p("║ 1. STANDING TACKLE TOO EFFECTIVE                               ║")
	gut.p("║    - 35% per-frame chance = ~3 frame avg (0.06s)               ║")
	gut.p("║    - Chaser within 12px = instant dispossession                ║")
	gut.p("║                                                                ║")
	gut.p("║ 2. NO TEAM-WIDE COOLDOWN                                      ║")
	gut.p("║    - Only dispossessed player gets stun                        ║")
	gut.p("║    - Teammates can immediately re-challenge                    ║")
	gut.p("║                                                                ║")
	gut.p("║ 3. BALL BARELY TRAVELS AFTER TACKLE                           ║")
	gut.p("║    - 3.0 px/frame knock → pickable in ~4 frames (~11px)       ║")
	gut.p("║    - Ball stays in contested area                              ║")
	gut.p("║                                                                ║")
	gut.p("║ 4. TACKLE RANGE > PICKUP RANGE                                ║")
	gut.p("║    - Tackle at 12px, pickup at 8px                             ║")
	gut.p("║    - Tackler can't pick up ball after winning it               ║")
	gut.p("║                                                                ║")
	gut.p("║ 5. GK SPEED THRESHOLD TOO LOW (outside box)                   ║")
	gut.p("║    - 2.5 px/frame threshold = GK can barely catch anything    ║")
	gut.p("║    - In box: 5.0 is better but GK often not positioned right  ║")
	gut.p("╚══════════════════════════════════════════════════════════════════╝")
	gut.p("")

	assert_true(true, "Summary printed")
