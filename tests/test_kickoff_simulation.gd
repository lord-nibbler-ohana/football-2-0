extends GutTest
## Headless kickoff simulation — fully CPU-controlled (no human player).
## Validates that the AI produces a vibrant game: players spread out,
## chase the ball, pass/shoot, and never stack on top of each other.

var possession_pure: PossessionPure
var home_ai: Array = []  # OutfieldAiPure per slot (null for GK)
var away_ai: Array = []
var home_gk_ai: GoalkeeperAiPure
var away_gk_ai: GoalkeeperAiPure
var home_targets: Array = []
var away_targets: Array = []

## Simulated player state.
var players: Array = []

## Ball state.
var ball_pos: Vector2
var ball_vel: Vector2
var ball_height: float

const PLAYER_SPEED := 2.0
const BALL_START := Vector2(300, 360)
const PICKUP_RADIUS := 8.0
const DRIBBLE_OFFSET := 5.0
const GROUND_FRICTION := 0.08  # Simplified


func before_each() -> void:
	possession_pure = PossessionPure.new()
	ball_pos = BALL_START
	ball_vel = Vector2.ZERO
	ball_height = 0.0

	var home_slots := FormationPure.get_positions(FormationPure.Formation.F_4_4_2)
	var away_slots := FormationPure.get_away_positions(FormationPure.Formation.F_4_4_2)
	home_targets = ZoneLookupPure.generate_targets(home_slots, true)
	away_targets = ZoneLookupPure.generate_targets(away_slots, false)

	players = []
	home_ai = []
	away_ai = []

	for i in range(11):
		var slot: Dictionary = home_slots[i]
		var is_gk: bool = FormationPure.is_goalkeeper_role(slot["role"])
		players.append({
			"pos": Vector2(slot["position"]),
			"vel": Vector2.ZERO,
			"team_id": 0, "role": slot["role"], "is_gk": is_gk,
			"slot": i, "has_possession": false, "is_selected": false,
			"is_chaser": false, "teammate_has_ball": false,
			"formation_pos": Vector2(slot["position"]), "is_home": true,
			"kick_cooldown": 0, "loss_stun": 0,
			"had_possession": false,
		})
		if is_gk:
			home_gk_ai = GoalkeeperAiPure.new()
			home_ai.append(null)
		else:
			home_ai.append(OutfieldAiPure.new())

	for i in range(11):
		var slot: Dictionary = away_slots[i]
		var is_gk: bool = FormationPure.is_goalkeeper_role(slot["role"])
		players.append({
			"pos": Vector2(slot["position"]),
			"vel": Vector2.ZERO,
			"team_id": 1, "role": slot["role"], "is_gk": is_gk,
			"slot": i, "has_possession": false, "is_selected": false,
			"is_chaser": false, "teammate_has_ball": false,
			"formation_pos": Vector2(slot["position"]), "is_home": false,
			"kick_cooldown": 0, "loss_stun": 0,
			"had_possession": false,
		})
		if is_gk:
			away_gk_ai = GoalkeeperAiPure.new()
			away_ai.append(null)
		else:
			away_ai.append(OutfieldAiPure.new())


func _label(p: Dictionary) -> String:
	var team := "H" if int(p["team_id"]) == 0 else "A"
	return "%s-%s#%d" % [team, FormationPure.role_name(int(p["role"])), int(p["slot"]) + 1]


func _context(p: Dictionary) -> Dictionary:
	var is_home: bool = p["is_home"]
	var attack_dir := Vector2.UP if is_home else Vector2.DOWN
	var opp_goal := Vector2(300, 40) if is_home else Vector2(300, 680)
	var own_goal := Vector2(300, 680) if is_home else Vector2(300, 40)
	var targets: Array = home_targets if is_home else away_targets
	var zone_idx: int = ZoneLookupPure.get_zone(ball_pos, is_home)
	var zone_target: Vector2 = ZoneLookupPure.get_target(targets, int(p["slot"]), zone_idx)

	var all_infos: Array = []
	for pl in players:
		all_infos.append({"position": pl["pos"], "team_id": pl["team_id"]})

	return {
		"my_position": p["pos"], "my_role": p["role"], "my_team_id": p["team_id"],
		"is_home": is_home, "has_possession": p["has_possession"],
		"is_chaser": p["is_chaser"], "teammate_has_ball": p["teammate_has_ball"],
		"ball_position": ball_pos, "ball_velocity": ball_vel, "ball_height": ball_height,
		"zone_target": zone_target, "all_players": all_infos,
		"attack_direction": attack_dir, "opponent_goal_center": opp_goal,
		"own_goal_center": own_goal, "player_index": 0,
	}


func _update_chasers() -> void:
	var possessing_team := -1
	for p in players:
		if p["has_possession"]:
			possessing_team = int(p["team_id"])
			break

	var best := [{}, {}]
	var best_dist := [INF, INF]
	for p in players:
		if p["is_gk"] or p["has_possession"]:
			continue
		var tid: int = int(p["team_id"])
		if possessing_team == tid:
			continue
		var dist: float = p["pos"].distance_to(ball_pos)
		if dist < best_dist[tid]:
			best_dist[tid] = dist
			best[tid] = p

	for p in players:
		p["is_chaser"] = (p == best[0] or p == best[1])


func _update_teammate_flags() -> void:
	var possessing_team := -1
	for p in players:
		if p["has_possession"]:
			possessing_team = int(p["team_id"])
			break
	for p in players:
		p["teammate_has_ball"] = (int(p["team_id"]) == possessing_team \
			and not p["has_possession"])


func _update_possession() -> void:
	# Simple proximity possession — skip if ball is moving fast (just kicked)
	if ball_vel.length() > 2.5:
		# Ball too fast for pickup — only very close players can intercept
		var closest_idx := -1
		var closest_dist := INF
		for i in range(players.size()):
			var p: Dictionary = players[i]
			if int(p["kick_cooldown"]) > 0 or int(p["loss_stun"]) > 0:
				continue
			var dist: float = p["pos"].distance_to(ball_pos)
			if dist < 5.0 and dist < closest_dist:  # Very tight radius for fast ball
				closest_dist = dist
				closest_idx = i
		for p in players:
			p["has_possession"] = false
		if closest_idx >= 0:
			players[closest_idx]["has_possession"] = true
		return

	# Normal proximity possession for slow/stationary ball
	var closest_idx := -1
	var closest_dist := INF
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if int(p["kick_cooldown"]) > 0 or int(p["loss_stun"]) > 0:
			continue
		var dist: float = p["pos"].distance_to(ball_pos)
		var radius := 15.0 if p["is_gk"] else PICKUP_RADIUS
		if dist < radius and dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	for p in players:
		p["has_possession"] = false
	if closest_idx >= 0:
		players[closest_idx]["has_possession"] = true


func _apply_ball_physics() -> void:
	# Simple friction
	if ball_vel.length() > 0.05:
		var speed := ball_vel.length()
		var new_speed := speed - GROUND_FRICTION * sqrt(speed)
		if new_speed < 0.05:
			ball_vel = Vector2.ZERO
		else:
			ball_vel = ball_vel.normalized() * new_speed
	else:
		ball_vel = Vector2.ZERO
	ball_pos += ball_vel

	# Clamp to pitch
	ball_pos.x = clampf(ball_pos.x, 45.0, 555.0)
	ball_pos.y = clampf(ball_pos.y, 45.0, 675.0)


## Simulate one frame. Returns kick info if a kick happened.
func _sim_frame() -> Dictionary:
	_apply_ball_physics()
	_update_possession()
	_update_chasers()
	_update_teammate_flags()

	var kick_info := {}

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if int(p["kick_cooldown"]) > 0:
			p["kick_cooldown"] = int(p["kick_cooldown"]) - 1
		if int(p["loss_stun"]) > 0:
			p["loss_stun"] = int(p["loss_stun"]) - 1

		# Detect dispossession -> apply loss stun
		if p["had_possession"] and not p["has_possession"] \
				and int(p["kick_cooldown"]) == 0:
			p["loss_stun"] = 25  # LOSS_STUN_FRAMES
		p["had_possession"] = p["has_possession"]

		var ctx := _context(p)
		var result: Dictionary

		if p["is_gk"]:
			var gk_ai: GoalkeeperAiPure = home_gk_ai if p["is_home"] else away_gk_ai
			result = gk_ai.tick(ctx)
		else:
			var ai_idx: int = int(p["slot"])
			var ai: OutfieldAiPure = home_ai[ai_idx] if int(p["team_id"]) == 0 else away_ai[ai_idx]
			if ai == null:
				continue
			result = ai.tick(ctx)

		# Apply movement (slowed during loss stun)
		var vel: Vector2 = result.get("velocity", Vector2.ZERO)
		var speed_mult := 0.35 if int(p["loss_stun"]) > 0 else 1.0
		if vel.length() > 0.01:
			p["vel"] = vel.normalized() * PLAYER_SPEED * speed_mult
			p["pos"] += p["vel"]
		else:
			p["vel"] = Vector2.ZERO

		# Clamp player to pitch
		p["pos"].x = clampf(p["pos"].x, 42.0, 558.0)
		p["pos"].y = clampf(p["pos"].y, 42.0, 678.0)

		# Handle kick — ball gets velocity, kicker loses possession + cooldown
		var kick_action: String = result.get("kick_action", "none")
		if kick_action != "none" and p["has_possession"]:
			var kick_dir: Vector2 = result.get("kick_direction", Vector2.UP)
			if kick_dir.length() < 0.01:
				kick_dir = Vector2.UP
			var speed := 5.0 if kick_action == "pass" else 7.0
			ball_vel = kick_dir.normalized() * speed
			p["has_possession"] = false
			p["kick_cooldown"] = 15
			kick_info = {"player": _label(p), "action": kick_action, "frame": -1}
			# Don't let dribble overwrite ball_pos this frame
			continue

		# Dribble: ball follows possessor
		if p["has_possession"]:
			ball_pos = p["pos"] + p["vel"].normalized() * DRIBBLE_OFFSET if p["vel"].length() > 0.01 else p["pos"]
			ball_vel = Vector2.ZERO  # Ball moves with player during dribble

	return kick_info


## Count pairs of players closer than min_dist (excluding GKs).
func _count_overlapping_pairs(min_dist: float) -> int:
	var count := 0
	for i in range(players.size()):
		if players[i]["is_gk"]:
			continue
		for j in range(i + 1, players.size()):
			if players[j]["is_gk"]:
				continue
			if players[i]["pos"].distance_to(players[j]["pos"]) < min_dist:
				count += 1
	return count


## Count players within radius of ball (excluding GKs).
func _count_near_ball(radius: float) -> int:
	var count := 0
	for p in players:
		if p["is_gk"]:
			continue
		if p["pos"].distance_to(ball_pos) < radius:
			count += 1
	return count


# ===== TESTS =====


func test_one_chaser_per_team_when_ball_loose():
	_update_chasers()
	var chasers := [0, 0]
	for p in players:
		if p["is_chaser"]:
			chasers[int(p["team_id"])] += 1
	assert_eq(chasers[0], 1, "One home chaser when ball is loose")
	assert_eq(chasers[1], 1, "One away chaser when ball is loose")


func test_no_own_team_chaser_when_has_possession():
	players[9]["has_possession"] = true  # Home CF
	_update_chasers()
	for p in players:
		if p["is_chaser"] and int(p["team_id"]) == 0:
			assert_true(false, "%s chases despite teammate having ball" % _label(p))
			return
	assert_true(true, "No home chaser when home team has ball")


func test_opponent_presses_when_other_team_has_ball():
	players[9]["has_possession"] = true  # Home CF
	_update_chasers()
	var away_chasers := 0
	for p in players:
		if p["is_chaser"] and int(p["team_id"]) == 1:
			away_chasers += 1
	assert_eq(away_chasers, 1, "Away team presses when home has ball")


func test_kickoff_no_excessive_crowding_50_frames():
	## Full CPU kickoff: both teams compete for the ball.
	## No more than 3 outfield players within 15px of each other at any frame.
	var max_overlaps := 0

	for frame in range(50):
		_sim_frame()
		var overlaps := _count_overlapping_pairs(15.0)
		if overlaps > max_overlaps:
			max_overlaps = overlaps

	assert_lt(max_overlaps, 4,
		"At most 3 overlapping player pairs in 50 frames (got %d)" % max_overlaps)


func test_kickoff_ball_moves_within_60_frames():
	## Within 60 frames, someone should reach the ball and kick it.
	var ball_moved := false
	var kick_happened := false

	for frame in range(60):
		var info := _sim_frame()
		if info.size() > 0:
			kick_happened = true
		if ball_pos.distance_to(BALL_START) > 10.0:
			ball_moved = true
			break

	assert_true(ball_moved or kick_happened,
		"Ball should move or be kicked within 60 frames")


func test_full_match_100_frames_no_stacking():
	## 100-frame simulation. At no point should more than 4 outfield
	## players be within 20px of the ball.
	var max_near_ball := 0

	for frame in range(100):
		_sim_frame()
		var near := _count_near_ball(20.0)
		if near > max_near_ball:
			max_near_ball = near

	assert_lt(max_near_ball, 5,
		"At most 4 outfield players within 20px of ball (got %d)" % max_near_ball)


func test_players_spread_after_50_frames():
	## After 50 frames, average distance between same-team outfield players
	## should be > 50px (good spread, not bunching).
	for _frame in range(50):
		_sim_frame()

	for tid in [0, 1]:
		var team_label := "Home" if tid == 0 else "Away"
		var positions: Array = []
		for p in players:
			if int(p["team_id"]) == tid and not p["is_gk"]:
				positions.append(Vector2(p["pos"]))

		var total_dist := 0.0
		var pair_count := 0
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				total_dist += positions[i].distance_to(positions[j])
				pair_count += 1

		var avg_dist := total_dist / float(pair_count) if pair_count > 0 else 0.0
		assert_gt(avg_dist, 50.0,
			"%s team avg player spread should be > 50px (got %.1f)" % [team_label, avg_dist])


func test_passes_happen_in_200_frames():
	## In 200 frames of CPU vs CPU, at least 3 passes should occur.
	var pass_count := 0
	var kick_count := 0

	for _frame in range(200):
		var info := _sim_frame()
		if info.size() > 0:
			kick_count += 1
			if info["action"] == "pass":
				pass_count += 1

	gut.p("In 200 frames: %d kicks total, %d passes" % [kick_count, pass_count])
	assert_gt(pass_count, 2,
		"At least 3 passes in 200 frames (got %d passes, %d total kicks)" % [pass_count, kick_count])


func test_ball_travels_distance_on_pass():
	## After a pass, the ball should travel at least 40px total.
	## Track maximum distance the ball reaches from any kick origin.
	var max_travel := 0.0
	var last_kick_pos := ball_pos
	var kick_count := 0

	for _frame in range(300):
		var info := _sim_frame()
		if info.size() > 0:
			last_kick_pos = ball_pos
			kick_count += 1
		if kick_count > 0:
			var travel: float = ball_pos.distance_to(last_kick_pos)
			if travel > max_travel:
				max_travel = travel

	gut.p("Max ball travel from any kick: %.1f px (%d kicks)" % [max_travel, kick_count])
	assert_gt(max_travel, 40.0,
		"Ball should travel at least 40px from a kick (got %.1f)" % max_travel)


func test_trace_full_kickoff():
	## Diagnostic trace of 80 frames. Always passes — check output for behavior.
	gut.p("=== FULL CPU KICKOFF TRACE (80 frames) ===")
	gut.p("Both teams AI-controlled, 4-4-2 formation")
	gut.p("")

	for frame in range(80):
		var info := _sim_frame()

		if frame % 20 == 0 or info.size() > 0 or frame < 5:
			var near := _count_near_ball(20.0)
			var overlaps := _count_overlapping_pairs(15.0)
			gut.p("--- Frame %d --- ball=%s vel=%s near_ball=%d overlaps=%d" % [
				frame, str(ball_pos).substr(0, 20), str(ball_vel).substr(0, 20),
				near, overlaps])

			if info.size() > 0:
				gut.p("  KICK: %s does %s" % [info["player"], info["action"]])

			for p in players:
				var dist: float = p["pos"].distance_to(ball_pos)
				if dist < 50.0 or p["is_chaser"] or p["has_possession"]:
					var flags := ""
					if p["is_chaser"]:
						flags += " [CHASE]"
					if p["has_possession"]:
						flags += " [BALL]"
					if p["teammate_has_ball"]:
						flags += " [TMATE]"
					gut.p("    %s pos=%s dist=%.0f%s" % [
						_label(p), str(p["pos"]).substr(0, 20), dist, flags])
			gut.p("")

	assert_true(true, "Trace complete — inspect output above")
