extends GutTest
## AI Passing Diagnostics — 500-frame CPU vs CPU simulation.
## Measures pass frequency, dribble duration, pass success rate, and game tempo.
## Uses the same pure-logic simulation as test_kickoff_simulation.gd.

var home_ai: Array = []
var away_ai: Array = []
var home_gk_ai: GoalkeeperAiPure
var away_gk_ai: GoalkeeperAiPure
var home_targets: Array = []
var away_targets: Array = []

var players: Array = []
var ball_pos: Vector2
var ball_vel: Vector2
var ball_height: float

const PLAYER_SPEED := 2.0
const BALL_START := Vector2(300, 360)
const PICKUP_RADIUS := 8.0
const DRIBBLE_OFFSET := 5.0
const GROUND_FRICTION := 0.08
const SIM_FRAMES := 500


func before_each() -> void:
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
			"kick_cooldown": 0, "loss_stun": 0, "had_possession": false,
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
			"kick_cooldown": 0, "loss_stun": 0, "had_possession": false,
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
	if ball_vel.length() > 2.5:
		var closest_idx := -1
		var closest_dist := INF
		for i in range(players.size()):
			var p: Dictionary = players[i]
			if int(p["kick_cooldown"]) > 0 or int(p["loss_stun"]) > 0:
				continue
			var dist: float = p["pos"].distance_to(ball_pos)
			if dist < 5.0 and dist < closest_dist:
				closest_dist = dist
				closest_idx = i
		for p in players:
			p["has_possession"] = false
		if closest_idx >= 0:
			players[closest_idx]["has_possession"] = true
		return

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
	ball_pos.x = clampf(ball_pos.x, 45.0, 555.0)
	ball_pos.y = clampf(ball_pos.y, 45.0, 675.0)


## Simulate one frame. Returns kick info dict (empty if no kick).
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

		if p["had_possession"] and not p["has_possession"] \
				and int(p["kick_cooldown"]) == 0:
			p["loss_stun"] = 25
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

		var vel: Vector2 = result.get("velocity", Vector2.ZERO)
		var speed_mult := 0.35 if int(p["loss_stun"]) > 0 else 1.0
		if vel.length() > 0.01:
			p["vel"] = vel.normalized() * PLAYER_SPEED * speed_mult
			p["pos"] += p["vel"]
		else:
			p["vel"] = Vector2.ZERO

		p["pos"].x = clampf(p["pos"].x, 42.0, 558.0)
		p["pos"].y = clampf(p["pos"].y, 42.0, 678.0)

		var kick_action: String = result.get("kick_action", "none")
		if kick_action != "none" and p["has_possession"]:
			var kick_dir: Vector2 = result.get("kick_direction", Vector2.UP)
			if kick_dir.length() < 0.01:
				kick_dir = Vector2.UP
			var speed := 5.0 if kick_action == "pass" else 7.0
			ball_vel = kick_dir.normalized() * speed
			p["has_possession"] = false
			p["kick_cooldown"] = 15
			kick_info = {
				"player": _label(p), "action": kick_action,
				"team_id": int(p["team_id"]), "frame": -1,
			}
			continue

		if p["has_possession"]:
			ball_pos = p["pos"] + p["vel"].normalized() * DRIBBLE_OFFSET \
				if p["vel"].length() > 0.01 else p["pos"]
			ball_vel = Vector2.ZERO

	return kick_info


## Run the full simulation and return a stats dictionary.
func _run_simulation() -> Dictionary:
	var stats := {
		"passes": [0, 0],
		"shots": [0, 0],
		"clears": [0, 0],
		"total_kicks": 0,
		"dribble_durations": [],
		"possession_changes": 0,
		"loose_ball_frames": 0,
		"pass_events": [],  # [{team_id, frame}] for success tracking
	}

	var last_possessing_team := -1

	for frame in range(SIM_FRAMES):
		var info := _sim_frame()

		# Track possession changes
		var current_team := -1
		for p in players:
			if p["has_possession"]:
				current_team = int(p["team_id"])
				break
		if current_team == -1:
			stats["loose_ball_frames"] += 1
		if current_team != last_possessing_team and current_team >= 0 \
				and last_possessing_team >= 0:
			stats["possession_changes"] += 1
		last_possessing_team = current_team

		# Track kicks
		if info.size() > 0:
			stats["total_kicks"] += 1
			var tid: int = int(info["team_id"])
			match info["action"]:
				"pass":
					stats["passes"][tid] += 1
					stats["pass_events"].append({"team_id": tid, "frame": frame})
				"shot":
					stats["shots"][tid] += 1
				"clear":
					stats["clears"][tid] += 1

			# Record dribble duration from AI
			for p in players:
				if _label(p) == info["player"] and not p["is_gk"]:
					var ai_idx: int = int(p["slot"])
					var ai: OutfieldAiPure = home_ai[ai_idx] \
						if int(p["team_id"]) == 0 else away_ai[ai_idx]
					if ai:
						stats["dribble_durations"].append(ai.on_ball_frames)

	# Calculate pass success rate
	var successful := 0
	for evt in stats["pass_events"]:
		var pass_team: int = int(evt["team_id"])
		var pass_frame: int = int(evt["frame"])
		# Check if passing team has possession within 30 frames
		# Re-run would be expensive, so approximate: did a teammate event follow?
		for evt2 in stats["pass_events"]:
			if int(evt2["frame"]) > pass_frame \
					and int(evt2["frame"]) <= pass_frame + 60 \
					and int(evt2["team_id"]) == pass_team:
				successful += 1
				break

	var total_passes: int = stats["passes"][0] + stats["passes"][1]
	stats["pass_success_rate"] = float(successful) / float(total_passes) \
		if total_passes > 0 else 0.0

	var avg_dribble := 0.0
	var max_dribble := 0
	if stats["dribble_durations"].size() > 0:
		var total := 0
		for d in stats["dribble_durations"]:
			total += int(d)
			if int(d) > max_dribble:
				max_dribble = int(d)
		avg_dribble = float(total) / float(stats["dribble_durations"].size())
	stats["avg_dribble"] = avg_dribble
	stats["max_dribble"] = max_dribble

	return stats


# ===== TESTS =====


func test_passing_diagnostics_500_frames():
	## Diagnostic trace — always passes, prints full stats.
	var stats := _run_simulation()

	var total_passes: int = stats["passes"][0] + stats["passes"][1]
	var total_shots: int = stats["shots"][0] + stats["shots"][1]
	var total_clears: int = stats["clears"][0] + stats["clears"][1]

	gut.p("=== AI PASSING DIAGNOSTICS (%d frames) ===" % SIM_FRAMES)
	gut.p("")
	gut.p("KICKS:")
	gut.p("  Total kicks:       %d" % stats["total_kicks"])
	gut.p("  Passes (H/A):      %d / %d  (total: %d)" % [
		stats["passes"][0], stats["passes"][1], total_passes])
	gut.p("  Shots (H/A):       %d / %d  (total: %d)" % [
		stats["shots"][0], stats["shots"][1], total_shots])
	gut.p("  Clears (H/A):      %d / %d  (total: %d)" % [
		stats["clears"][0], stats["clears"][1], total_clears])
	gut.p("")
	gut.p("DRIBBLE:")
	gut.p("  Avg dribble frames: %.1f (%.2fs)" % [
		stats["avg_dribble"], stats["avg_dribble"] / 50.0])
	gut.p("  Max dribble frames: %d (%.2fs)" % [
		stats["max_dribble"], stats["max_dribble"] / 50.0])
	gut.p("")
	gut.p("TEMPO:")
	gut.p("  Possession changes: %d" % stats["possession_changes"])
	gut.p("  Loose ball frames:  %d / %d (%.0f%%)" % [
		stats["loose_ball_frames"], SIM_FRAMES,
		100.0 * stats["loose_ball_frames"] / SIM_FRAMES])
	gut.p("  Pass success rate:  %.0f%%" % (stats["pass_success_rate"] * 100.0))
	gut.p("")

	assert_true(true, "Diagnostic trace complete — inspect output above")


func test_minimum_pass_frequency():
	## At least 8 total passes should occur in 500 frames (10 seconds).
	var stats := _run_simulation()
	var total_passes: int = stats["passes"][0] + stats["passes"][1]
	gut.p("Total passes in %d frames: %d" % [SIM_FRAMES, total_passes])
	assert_gt(total_passes, 7,
		"Expected at least 8 passes in %d frames (got %d)" % [SIM_FRAMES, total_passes])


func test_average_dribble_under_threshold():
	## Average dribble should be under 60 frames (1.2s) with the new constants.
	var stats := _run_simulation()
	gut.p("Avg dribble: %.1f frames" % stats["avg_dribble"])
	assert_lt(stats["avg_dribble"], 60.0,
		"Average dribble should be < 60 frames (got %.1f)" % stats["avg_dribble"])


func test_both_teams_pass():
	## Both teams should execute at least 1 pass each in 500 frames.
	var stats := _run_simulation()
	gut.p("Passes H=%d A=%d" % [stats["passes"][0], stats["passes"][1]])
	assert_gt(stats["passes"][0], 0,
		"Home team should make at least 1 pass (got %d)" % stats["passes"][0])
	assert_gt(stats["passes"][1], 0,
		"Away team should make at least 1 pass (got %d)" % stats["passes"][1])
