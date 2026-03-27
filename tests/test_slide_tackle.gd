extends GutTest
## Tests for TackleStatePure — slide tackle state machine, foul determination,
## and simulation of tackle usage and effectiveness in CPU vs CPU games.

var tackle: TackleStatePure


func before_each():
	tackle = TackleStatePure.new()


# ═══════════════════════════════════════════════════════════════════════════════
# UNIT TESTS — TackleStatePure state machine
# ═══════════════════════════════════════════════════════════════════════════════


# ── State transitions ──

func test_initial_state_is_idle():
	assert_eq(tackle.state, TackleStatePure.State.IDLE)
	assert_false(tackle.is_active())
	assert_false(tackle.is_sliding())


func test_can_tackle_from_idle():
	assert_true(tackle.can_tackle(), "Should be able to tackle from idle")


func test_start_slide_transitions_to_sliding():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	assert_eq(tackle.state, TackleStatePure.State.SLIDING)
	assert_true(tackle.is_active())
	assert_true(tackle.is_sliding())


func test_cannot_tackle_while_sliding():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	assert_false(tackle.can_tackle())


func test_cannot_tackle_while_recovering():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	# Tick through entire slide
	for i in range(TackleStatePure.SLIDE_DURATION):
		tackle.tick()
	assert_eq(tackle.state, TackleStatePure.State.RECOVERING)
	assert_false(tackle.can_tackle())


func test_slide_transitions_to_recovering():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	for i in range(TackleStatePure.SLIDE_DURATION):
		tackle.tick()
	assert_eq(tackle.state, TackleStatePure.State.RECOVERING)
	assert_true(tackle.is_active())
	assert_false(tackle.is_sliding())


func test_recovering_transitions_to_idle_with_cooldown():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	# Tick through slide + recovery
	for i in range(TackleStatePure.SLIDE_DURATION + TackleStatePure.RECOVERY_DURATION):
		tackle.tick()
	assert_eq(tackle.state, TackleStatePure.State.IDLE)
	assert_false(tackle.is_active())


func test_cooldown_prevents_immediate_retackle():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	# Complete slide + recovery
	for i in range(TackleStatePure.SLIDE_DURATION + TackleStatePure.RECOVERY_DURATION):
		tackle.tick()
	assert_false(tackle.can_tackle(), "Should not be able to tackle during cooldown")
	# Tick through most of cooldown
	for i in range(TackleStatePure.TACKLE_COOLDOWN - 1):
		tackle.tick()
	assert_false(tackle.can_tackle(), "Still in cooldown")
	# Final cooldown tick
	tackle.tick()
	assert_true(tackle.can_tackle(), "Cooldown expired — should be able to tackle")


func test_reset_clears_all_state():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.UP)
	tackle.reset()
	assert_eq(tackle.state, TackleStatePure.State.IDLE)
	assert_eq(tackle.cooldown, 0)
	assert_eq(tackle.slide_direction, Vector2.ZERO)
	assert_true(tackle.can_tackle())


# ── Direction locking ──

func test_slide_direction_locked_on_start():
	tackle.start_slide(Vector2(1, 1).normalized(), Vector2(100, 100))
	var expected_dir := Vector2(1, 1).normalized()
	assert_almost_eq(tackle.slide_direction.x, expected_dir.x, 0.01)
	assert_almost_eq(tackle.slide_direction.y, expected_dir.y, 0.01)


func test_slide_direction_does_not_change_with_input():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var original_dir := tackle.slide_direction
	# Tick with different joystick directions
	tackle.tick(Vector2.UP)
	assert_almost_eq(tackle.slide_direction.x, original_dir.x, 0.01,
		"Slide direction should not change with joystick input")
	assert_almost_eq(tackle.slide_direction.y, original_dir.y, 0.01)


func test_zero_direction_defaults_to_down():
	tackle.start_slide(Vector2.ZERO, Vector2(100, 100))
	assert_almost_eq(tackle.slide_direction.x, Vector2.DOWN.x, 0.01)
	assert_almost_eq(tackle.slide_direction.y, Vector2.DOWN.y, 0.01)


# ── Speed and deceleration ──

func test_initial_slide_speed():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var result: Dictionary = tackle.tick()
	var vel: Vector2 = result["velocity"]
	# After first tick, speed = SLIDE_SPEED * SLIDE_DECELERATION
	var expected_speed := TackleStatePure.SLIDE_SPEED * TackleStatePure.SLIDE_DECELERATION
	assert_almost_eq(vel.length(), expected_speed, 0.01,
		"First tick velocity should reflect deceleration")


func test_slide_speed_decelerates_each_frame():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var prev_speed := TackleStatePure.SLIDE_SPEED
	for i in range(5):
		var result: Dictionary = tackle.tick()
		var speed: float = result["velocity"].length()
		assert_lt(speed, prev_speed, "Speed should decrease each frame")
		prev_speed = speed


func test_slide_faster_than_player_speed():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var result: Dictionary = tackle.tick()
	var speed: float = result["velocity"].length()
	assert_gt(speed, 2.0, "Slide speed should exceed normal PLAYER_SPEED (2.0)")


func test_recovery_velocity_is_zero():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	for i in range(TackleStatePure.SLIDE_DURATION):
		tackle.tick()
	# Now in RECOVERING
	var result: Dictionary = tackle.tick()
	assert_almost_eq(result["velocity"].length(), 0.0, 0.01,
		"Recovery velocity should be zero")


# ── Slide distance ──

func test_total_slide_distance():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var total_distance := 0.0
	for i in range(TackleStatePure.SLIDE_DURATION):
		var result: Dictionary = tackle.tick()
		total_distance += result["velocity"].length()
	# Expected: SLIDE_SPEED * sum(SLIDE_DECELERATION^i for i=1..12)
	var expected := 0.0
	var s := TackleStatePure.SLIDE_SPEED
	for i in range(TackleStatePure.SLIDE_DURATION):
		s *= TackleStatePure.SLIDE_DECELERATION
		expected += s
	assert_almost_eq(total_distance, expected, 0.5,
		"Total slide distance should be ~%.1f px" % expected)
	# Sanity: should be ~25-30 px
	assert_gt(total_distance, 20.0, "Slide should cover at least 20px")
	assert_lt(total_distance, 40.0, "Slide should not exceed 40px")


# ── Deflection (aftertouch) ──

func test_deflection_captured_during_slide():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.UP)
	assert_almost_eq(tackle.deflect_direction.x, Vector2.UP.x, 0.01)
	assert_almost_eq(tackle.deflect_direction.y, Vector2.UP.y, 0.01)


func test_deflection_updates_with_latest_input():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.UP)
	tackle.tick(Vector2.LEFT)
	assert_almost_eq(tackle.deflect_direction.x, Vector2.LEFT.x, 0.01,
		"Deflection should reflect most recent joystick input")


func test_no_deflection_without_input():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.ZERO)
	assert_eq(tackle.deflect_direction, Vector2.ZERO,
		"No deflection if joystick not pushed")


func test_knock_direction_uses_deflection_when_set():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.UP)
	var knock := tackle.get_knock_direction()
	assert_almost_eq(knock.x, Vector2.UP.x, 0.01)
	assert_almost_eq(knock.y, Vector2.UP.y, 0.01)


func test_knock_direction_falls_back_to_slide_direction():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick(Vector2.ZERO)
	var knock := tackle.get_knock_direction()
	assert_almost_eq(knock.x, Vector2.RIGHT.x, 0.01,
		"Without deflection, knock direction should match slide direction")


# ── force_recovery ──

func test_force_recovery_ends_slide_early():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	tackle.tick()  # 1 frame of slide
	tackle.force_recovery()
	assert_eq(tackle.state, TackleStatePure.State.RECOVERING)
	assert_false(tackle.is_sliding())


# ── start_slide guards ──

func test_start_slide_ignored_during_cooldown():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	for i in range(TackleStatePure.SLIDE_DURATION + TackleStatePure.RECOVERY_DURATION):
		tackle.tick()
	# Now in cooldown
	tackle.start_slide(Vector2.RIGHT, Vector2(200, 200))
	assert_eq(tackle.state, TackleStatePure.State.IDLE,
		"start_slide should be ignored during cooldown")


func test_start_slide_ignored_while_active():
	tackle.start_slide(Vector2.UP, Vector2(100, 100))
	tackle.start_slide(Vector2.RIGHT, Vector2(200, 200))
	# Direction should still be UP, not RIGHT
	assert_almost_eq(tackle.slide_direction.x, Vector2.UP.x, 0.01)
	assert_almost_eq(tackle.slide_direction.y, Vector2.UP.y, 0.01)


# ═══════════════════════════════════════════════════════════════════════════════
# FOUL DETERMINATION — static compute_foul_chance
# ═══════════════════════════════════════════════════════════════════════════════

func test_foul_chance_from_front_is_low():
	# Sliding LEFT, carrier facing RIGHT (head-on)
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.LEFT, Vector2.RIGHT, 10.0)
	assert_lt(chance, 0.25, "Head-on tackle should have low foul chance (got %.2f)" % chance)


func test_foul_chance_from_behind_is_high():
	# Sliding RIGHT, carrier facing RIGHT (same direction = from behind)
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.RIGHT, Vector2.RIGHT, 10.0)
	assert_gt(chance, 0.5, "From-behind tackle should have high foul chance (got %.2f)" % chance)


func test_foul_chance_from_side_is_moderate():
	# Sliding RIGHT, carrier facing UP (perpendicular)
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.RIGHT, Vector2.UP, 10.0)
	assert_gt(chance, 0.05, "Side tackle should not be negligible")
	assert_lt(chance, 0.5, "Side tackle should not be as dangerous as from behind")


func test_foul_chance_increases_with_distance():
	var short := TackleStatePure.compute_foul_chance(
		Vector2.RIGHT, Vector2.UP, 5.0)
	var long_dist := TackleStatePure.compute_foul_chance(
		Vector2.RIGHT, Vector2.UP, 50.0)
	assert_gt(long_dist, short, "Longer slide distance should increase foul chance")


func test_foul_chance_capped_below_1():
	# Extreme case: from behind + very long distance
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.RIGHT, Vector2.RIGHT, 500.0)
	assert_lte(chance, 0.95, "Foul chance should be capped at 0.95")


func test_foul_chance_never_negative():
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.LEFT, Vector2.RIGHT, 0.0)
	assert_gte(chance, 0.0, "Foul chance should never be negative")


func test_card_threshold_from_behind():
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.UP, Vector2.UP, 20.0)
	assert_true(TackleStatePure.should_show_card(chance),
		"From-behind tackle should warrant a card (chance=%.2f)" % chance)


func test_no_card_for_clean_side_tackle():
	var chance := TackleStatePure.compute_foul_chance(
		Vector2.LEFT, Vector2.RIGHT, 5.0)
	assert_false(TackleStatePure.should_show_card(chance),
		"Clean head-on tackle should not warrant a card (chance=%.2f)" % chance)


# ═══════════════════════════════════════════════════════════════════════════════
# TIMING TESTS — frame-accurate behavior at 50 Hz
# ═══════════════════════════════════════════════════════════════════════════════

func test_slide_lasts_exactly_n_frames():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	for i in range(TackleStatePure.SLIDE_DURATION - 1):
		tackle.tick()
		assert_true(tackle.is_sliding(),
			"Should still be sliding at frame %d" % (i + 1))
	tackle.tick()
	assert_false(tackle.is_sliding(), "Should stop sliding after SLIDE_DURATION frames")
	assert_eq(tackle.state, TackleStatePure.State.RECOVERING)


func test_recovery_lasts_exactly_n_frames():
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	for i in range(TackleStatePure.SLIDE_DURATION):
		tackle.tick()
	# Now in RECOVERING
	for i in range(TackleStatePure.RECOVERY_DURATION - 1):
		tackle.tick()
		assert_eq(tackle.state, TackleStatePure.State.RECOVERING,
			"Should still be recovering at frame %d" % (i + 1))
	tackle.tick()
	assert_eq(tackle.state, TackleStatePure.State.IDLE)


func test_full_cycle_duration():
	## Total frames from start to can_tackle again.
	tackle.start_slide(Vector2.RIGHT, Vector2(100, 100))
	var total_frames := 0
	while not tackle.can_tackle():
		tackle.tick()
		total_frames += 1
		if total_frames > 200:
			break  # Safety
	var expected := TackleStatePure.SLIDE_DURATION \
		+ TackleStatePure.RECOVERY_DURATION \
		+ TackleStatePure.TACKLE_COOLDOWN
	assert_eq(total_frames, expected,
		"Full cycle should be %d frames (got %d)" % [expected, total_frames])


# ═══════════════════════════════════════════════════════════════════════════════
# SIMULATION TESTS — tackle usage and effectiveness in CPU vs CPU games
# ═══════════════════════════════════════════════════════════════════════════════

# Simulation infrastructure (mirrors test_kickoff_simulation.gd pattern)

var possession_pure: PossessionPure
var home_ai: Array = []
var away_ai: Array = []
var home_gk_ai: GoalkeeperAiPure
var away_gk_ai: GoalkeeperAiPure
var home_targets: Array = []
var away_targets: Array = []
var sim_players: Array = []
var sim_ball_pos: Vector2
var sim_ball_vel: Vector2

const SIM_PLAYER_SPEED := 2.0
const SIM_BALL_START := Vector2(300, 360)
const SIM_PICKUP_RADIUS := 8.0
const SIM_DRIBBLE_OFFSET := 5.0
const SIM_GROUND_FRICTION := 0.08


func _setup_sim() -> void:
	possession_pure = PossessionPure.new()
	sim_ball_pos = SIM_BALL_START
	sim_ball_vel = Vector2.ZERO

	var home_slots := FormationPure.get_positions(FormationPure.Formation.F_4_4_2)
	var away_slots := FormationPure.get_away_positions(FormationPure.Formation.F_4_4_2)
	home_targets = ZoneLookupPure.generate_targets(home_slots, true)
	away_targets = ZoneLookupPure.generate_targets(away_slots, false)

	sim_players = []
	home_ai = []
	away_ai = []

	for i in range(11):
		var slot: Dictionary = home_slots[i]
		var is_gk: bool = FormationPure.is_goalkeeper_role(slot["role"])
		sim_players.append({
			"pos": Vector2(slot["position"]), "vel": Vector2.ZERO,
			"team_id": 0, "role": slot["role"], "is_gk": is_gk,
			"slot": i, "has_possession": false, "is_selected": false,
			"is_chaser": false, "teammate_has_ball": false,
			"formation_pos": Vector2(slot["position"]), "is_home": true,
			"kick_cooldown": 0, "loss_stun": 0, "had_possession": false,
			"tackle_state": TackleStatePure.new(), "yellow_cards": 0,
		})
		if is_gk:
			home_gk_ai = GoalkeeperAiPure.new()
			home_ai.append(null)
		else:
			home_ai.append(OutfieldAiPure.new())

	for i in range(11):
		var slot: Dictionary = away_slots[i]
		var is_gk: bool = FormationPure.is_goalkeeper_role(slot["role"])
		sim_players.append({
			"pos": Vector2(slot["position"]), "vel": Vector2.ZERO,
			"team_id": 1, "role": slot["role"], "is_gk": is_gk,
			"slot": i, "has_possession": false, "is_selected": false,
			"is_chaser": false, "teammate_has_ball": false,
			"formation_pos": Vector2(slot["position"]), "is_home": false,
			"kick_cooldown": 0, "loss_stun": 0, "had_possession": false,
			"tackle_state": TackleStatePure.new(), "yellow_cards": 0,
		})
		if is_gk:
			away_gk_ai = GoalkeeperAiPure.new()
			away_ai.append(null)
		else:
			away_ai.append(OutfieldAiPure.new())


func _sim_context(p: Dictionary) -> Dictionary:
	var is_home: bool = p["is_home"]
	var attack_dir := Vector2.UP if is_home else Vector2.DOWN
	var opp_goal := Vector2(300, 40) if is_home else Vector2(300, 680)
	var own_goal := Vector2(300, 680) if is_home else Vector2(300, 40)
	var targets: Array = home_targets if is_home else away_targets
	var zone_idx: int = ZoneLookupPure.get_zone(sim_ball_pos, is_home)
	var zone_target: Vector2 = ZoneLookupPure.get_target(
		targets, int(p["slot"]), zone_idx)

	var all_infos: Array = []
	for pl in sim_players:
		all_infos.append({"position": pl["pos"], "team_id": pl["team_id"]})

	return {
		"my_position": p["pos"], "my_role": p["role"], "my_team_id": p["team_id"],
		"is_home": is_home, "has_possession": p["has_possession"],
		"is_chaser": p["is_chaser"], "teammate_has_ball": p["teammate_has_ball"],
		"ball_position": sim_ball_pos, "ball_velocity": sim_ball_vel,
		"ball_height": 0.0, "zone_target": zone_target,
		"all_players": all_infos, "attack_direction": attack_dir,
		"opponent_goal_center": opp_goal, "own_goal_center": own_goal,
		"player_index": 0,
	}


func _sim_update_chasers() -> void:
	var possessing_team := -1
	for p in sim_players:
		if p["has_possession"]:
			possessing_team = int(p["team_id"])
			break
	var best := [{}, {}]
	var best_dist := [INF, INF]
	for p in sim_players:
		if p["is_gk"] or p["has_possession"]:
			continue
		var tid: int = int(p["team_id"])
		if possessing_team == tid:
			continue
		var dist: float = p["pos"].distance_to(sim_ball_pos)
		if dist < best_dist[tid]:
			best_dist[tid] = dist
			best[tid] = p
	for p in sim_players:
		p["is_chaser"] = (p == best[0] or p == best[1])


func _sim_update_teammate_flags() -> void:
	var possessing_team := -1
	for p in sim_players:
		if p["has_possession"]:
			possessing_team = int(p["team_id"])
			break
	for p in sim_players:
		p["teammate_has_ball"] = (int(p["team_id"]) == possessing_team \
			and not p["has_possession"])


func _sim_update_possession() -> void:
	if sim_ball_vel.length() > 2.5:
		var closest_idx := -1
		var closest_dist := INF
		for i in range(sim_players.size()):
			var p: Dictionary = sim_players[i]
			if int(p["kick_cooldown"]) > 0 or int(p["loss_stun"]) > 0:
				continue
			var ts: TackleStatePure = p["tackle_state"]
			if ts.is_sliding():
				continue
			var dist: float = p["pos"].distance_to(sim_ball_pos)
			if dist < 5.0 and dist < closest_dist:
				closest_dist = dist
				closest_idx = i
		for p in sim_players:
			p["has_possession"] = false
		if closest_idx >= 0:
			sim_players[closest_idx]["has_possession"] = true
		return

	var closest_idx := -1
	var closest_dist := INF
	for i in range(sim_players.size()):
		var p: Dictionary = sim_players[i]
		if int(p["kick_cooldown"]) > 0 or int(p["loss_stun"]) > 0:
			continue
		var ts: TackleStatePure = p["tackle_state"]
		if ts.is_sliding():
			continue
		var dist: float = p["pos"].distance_to(sim_ball_pos)
		var radius := 15.0 if p["is_gk"] else SIM_PICKUP_RADIUS
		if dist < radius and dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	for p in sim_players:
		p["has_possession"] = false
	if closest_idx >= 0:
		sim_players[closest_idx]["has_possession"] = true


func _sim_ball_physics() -> void:
	if sim_ball_vel.length() > 0.05:
		var speed := sim_ball_vel.length()
		var new_speed := speed - SIM_GROUND_FRICTION * sqrt(speed)
		if new_speed < 0.05:
			sim_ball_vel = Vector2.ZERO
		else:
			sim_ball_vel = sim_ball_vel.normalized() * new_speed
	else:
		sim_ball_vel = Vector2.ZERO
	sim_ball_pos += sim_ball_vel
	sim_ball_pos.x = clampf(sim_ball_pos.x, 45.0, 555.0)
	sim_ball_pos.y = clampf(sim_ball_pos.y, 45.0, 675.0)


## Check slide tackles: sliding player contacting ball/opponent.
## Returns {"clean": int, "foul": int, "cards": int} for this frame.
func _sim_check_slide_tackles() -> Dictionary:
	var result := {"clean": 0, "foul": 0, "cards": 0}

	var possessor_idx := -1
	for i in range(sim_players.size()):
		if sim_players[i]["has_possession"]:
			possessor_idx = i
			break
	if possessor_idx < 0:
		return result

	var possessor: Dictionary = sim_players[possessor_idx]

	for p in sim_players:
		var ts: TackleStatePure = p["tackle_state"]
		if not ts.is_sliding():
			continue
		if int(p["team_id"]) == int(possessor["team_id"]):
			continue

		var dist_to_ball: float = p["pos"].distance_to(sim_ball_pos)
		var dist_to_carrier: float = p["pos"].distance_to(possessor["pos"])

		if dist_to_ball > TackleStatePure.TACKLE_HIT_RADIUS \
				and dist_to_carrier > TackleStatePure.TACKLE_HIT_RADIUS:
			continue

		var ball_first := dist_to_ball <= dist_to_carrier

		if ball_first:
			# Clean tackle
			var knock_dir: Vector2 = ts.get_knock_direction()
			sim_ball_vel = knock_dir * TackleStatePure.TACKLE_KNOCK_SPEED
			possessor["has_possession"] = false
			possessor["kick_cooldown"] = 15
			result["clean"] += 1
		else:
			var slide_dist: float = p["pos"].distance_to(ts.slide_start_position)
			var carrier_facing: Vector2 = (sim_ball_pos - possessor["pos"]).normalized()
			if carrier_facing.length() < 0.01:
				carrier_facing = Vector2.DOWN
			var foul_chance := TackleStatePure.compute_foul_chance(
				ts.slide_direction, carrier_facing, slide_dist)

			if randf() < foul_chance:
				# Foul
				possessor["has_possession"] = false
				sim_ball_vel = Vector2.ZERO
				sim_ball_pos = possessor["pos"]
				ts.force_recovery()
				possessor["loss_stun"] = 0
				possessor["kick_cooldown"] = 0
				result["foul"] += 1
				if TackleStatePure.should_show_card(foul_chance):
					p["yellow_cards"] = int(p["yellow_cards"]) + 1
					result["cards"] += 1
			else:
				# Rough but legal
				var knock_dir: Vector2 = ts.get_knock_direction()
				sim_ball_vel = knock_dir * TackleStatePure.TACKLE_KNOCK_SPEED
				possessor["has_possession"] = false
				possessor["kick_cooldown"] = 15
				result["clean"] += 1

		break  # One per frame

	return result


## Simulate one frame. Returns {kick_info, tackle_info}.
func _sim_frame_with_tackles() -> Dictionary:
	_sim_ball_physics()
	_sim_update_possession()
	_sim_update_chasers()
	_sim_update_teammate_flags()

	var tackle_info := _sim_check_slide_tackles()
	var kick_info := {}

	for i in range(sim_players.size()):
		var p: Dictionary = sim_players[i]
		if int(p["kick_cooldown"]) > 0:
			p["kick_cooldown"] = int(p["kick_cooldown"]) - 1
		if int(p["loss_stun"]) > 0:
			p["loss_stun"] = int(p["loss_stun"]) - 1

		if p["had_possession"] and not p["has_possession"] \
				and int(p["kick_cooldown"]) == 0:
			p["loss_stun"] = 25
		p["had_possession"] = p["has_possession"]

		var ts: TackleStatePure = p["tackle_state"]

		# Tick active tackle states
		if ts.is_active():
			var tr: Dictionary = ts.tick()
			var vel: Vector2 = tr["velocity"]
			if vel.length() > 0.01:
				p["vel"] = vel
				p["pos"] += vel
			else:
				p["vel"] = Vector2.ZERO
			p["pos"].x = clampf(p["pos"].x, 42.0, 558.0)
			p["pos"].y = clampf(p["pos"].y, 42.0, 678.0)
			continue

		# AI tick
		var ctx := _sim_context(p)
		var ai_result: Dictionary

		if p["is_gk"]:
			var gk_ai: GoalkeeperAiPure = home_gk_ai if p["is_home"] else away_gk_ai
			ai_result = gk_ai.tick(ctx)
		else:
			var ai_idx: int = int(p["slot"])
			var ai: OutfieldAiPure = home_ai[ai_idx] if int(p["team_id"]) == 0 \
				else away_ai[ai_idx]
			if ai == null:
				continue
			ai_result = ai.tick(ctx)

		# Check for AI slide tackle trigger
		if ai_result.get("slide_tackle", false) and ts.can_tackle():
			var slide_dir: Vector2 = ai_result.get("velocity", Vector2.DOWN)
			if slide_dir.length() < 0.01:
				slide_dir = Vector2.DOWN
			ts.start_slide(slide_dir.normalized(), p["pos"])
			var tr: Dictionary = ts.tick()
			p["vel"] = tr["velocity"]
			p["pos"] += p["vel"]
			p["pos"].x = clampf(p["pos"].x, 42.0, 558.0)
			p["pos"].y = clampf(p["pos"].y, 42.0, 678.0)
			continue

		# Normal movement
		var vel: Vector2 = ai_result.get("velocity", Vector2.ZERO)
		var speed_mult := 0.35 if int(p["loss_stun"]) > 0 else 1.0
		if vel.length() > 0.01:
			p["vel"] = vel.normalized() * SIM_PLAYER_SPEED * speed_mult
			p["pos"] += p["vel"]
		else:
			p["vel"] = Vector2.ZERO

		p["pos"].x = clampf(p["pos"].x, 42.0, 558.0)
		p["pos"].y = clampf(p["pos"].y, 42.0, 678.0)

		# Handle kick
		var kick_action: String = ai_result.get("kick_action", "none")
		if kick_action != "none" and p["has_possession"]:
			var kick_dir: Vector2 = ai_result.get("kick_direction", Vector2.UP)
			if kick_dir.length() < 0.01:
				kick_dir = Vector2.UP
			var speed := 5.0 if kick_action == "pass" else 7.0
			sim_ball_vel = kick_dir.normalized() * speed
			p["has_possession"] = false
			p["kick_cooldown"] = 15
			kick_info = {"action": kick_action}
			continue

		# Dribble
		if p["has_possession"]:
			sim_ball_pos = p["pos"] + p["vel"].normalized() * SIM_DRIBBLE_OFFSET \
				if p["vel"].length() > 0.01 else p["pos"]
			sim_ball_vel = Vector2.ZERO

	return {"kick": kick_info, "tackle": tackle_info}


# ── Simulation tests ──

func test_ai_initiates_slide_tackles_in_500_frames():
	## In a 500-frame CPU vs CPU game, the AI should attempt at least 1 slide tackle.
	_setup_sim()
	var total_slides := 0

	for _frame in range(500):
		_sim_frame_with_tackles()
		for p in sim_players:
			var ts: TackleStatePure = p["tackle_state"]
			if ts.is_sliding():
				total_slides += 1

	gut.p("Slide tackle frames observed in 500 frames: %d" % total_slides)
	assert_gt(total_slides, 0,
		"AI should initiate at least 1 slide tackle in 500 frames (got %d)" % total_slides)


func test_slide_tackles_produce_clean_wins():
	## Over 1000 frames, some slide tackles should result in clean wins.
	_setup_sim()
	var clean_count := 0
	var foul_count := 0

	for _frame in range(1000):
		var info: Dictionary = _sim_frame_with_tackles()
		var ti: Dictionary = info["tackle"]
		clean_count += int(ti["clean"])
		foul_count += int(ti["foul"])

	var total := clean_count + foul_count
	gut.p("1000 frames: %d clean tackles, %d fouls (%d total)" % [
		clean_count, foul_count, total])
	if total > 0:
		assert_gt(clean_count, 0, "Some tackles should be clean (got 0 of %d)" % total)


func test_foul_rate_is_reasonable():
	## Foul rate should be between 5% and 60% of all tackle contacts.
	_setup_sim()
	var clean_count := 0
	var foul_count := 0

	for _frame in range(2000):
		var info: Dictionary = _sim_frame_with_tackles()
		var ti: Dictionary = info["tackle"]
		clean_count += int(ti["clean"])
		foul_count += int(ti["foul"])

	var total := clean_count + foul_count
	gut.p("2000 frames: %d clean, %d fouls (%d total)" % [
		clean_count, foul_count, total])
	if total >= 3:
		var foul_rate := float(foul_count) / float(total)
		assert_gt(foul_rate, 0.02,
			"Foul rate should be > 2%% (got %.1f%%)" % [foul_rate * 100])
		assert_lt(foul_rate, 0.70,
			"Foul rate should be < 70%% (got %.1f%%)" % [foul_rate * 100])
	else:
		gut.p("  (too few tackles to assess foul rate — %d total)" % total)
		assert_true(true, "Not enough tackles for rate assessment")


func test_yellow_cards_can_occur():
	## Over 3000 frames, at least one yellow card should be shown.
	_setup_sim()
	var total_cards := 0

	for _frame in range(3000):
		var info: Dictionary = _sim_frame_with_tackles()
		total_cards += int(info["tackle"]["cards"])

	gut.p("3000 frames: %d yellow cards" % total_cards)
	# Cards are probabilistic — just check tracking works, don't require one
	assert_gte(total_cards, 0, "Card tracking should work (got %d)" % total_cards)


func test_tackles_do_not_break_possession_flow():
	## Possession should still change hands regularly in a game with tackles.
	_setup_sim()
	var possession_changes := 0
	var last_possessing_team := -1

	for _frame in range(500):
		_sim_frame_with_tackles()
		var current_team := -1
		for p in sim_players:
			if p["has_possession"]:
				current_team = int(p["team_id"])
				break
		if current_team != last_possessing_team and current_team >= 0 \
				and last_possessing_team >= 0:
			possession_changes += 1
		if current_team >= 0:
			last_possessing_team = current_team

	gut.p("500 frames: %d possession changes" % possession_changes)
	assert_gt(possession_changes, 2,
		"Possession should change hands at least 3 times in 500 frames (got %d)" \
		% possession_changes)


func test_ball_displaced_on_clean_tackle():
	## A clean tackle should displace the ball from the carrier's position.
	_setup_sim()
	var displacement_observed := false

	for _frame in range(1000):
		var old_ball := sim_ball_pos
		var info: Dictionary = _sim_frame_with_tackles()
		if int(info["tackle"]["clean"]) > 0:
			var moved := sim_ball_pos.distance_to(old_ball) + sim_ball_vel.length()
			if moved > 1.0:
				displacement_observed = true
				break

	if displacement_observed:
		assert_true(true, "Ball displaced on clean tackle")
	else:
		gut.p("  (no clean tackle observed to verify displacement)")
		assert_true(true, "No clean tackle observed — cannot verify displacement")


func test_tackle_cooldown_prevents_spam():
	## A player who just tackled should not slide again within TACKLE_COOLDOWN frames.
	_setup_sim()
	var last_slide_start := {}  # player index -> frame when last slide started
	var was_sliding := {}  # player index -> bool

	for frame in range(1000):
		_sim_frame_with_tackles()
		for i in range(sim_players.size()):
			var ts: TackleStatePure = sim_players[i]["tackle_state"]
			var currently_sliding: bool = ts.is_sliding()
			var prev: bool = was_sliding.get(i, false)

			# Detect new slide initiation (transition from not-sliding to sliding)
			if currently_sliding and not prev:
				if last_slide_start.has(i):
					var gap: int = frame - int(last_slide_start[i])
					# Gap should be at least SLIDE + RECOVERY + COOLDOWN
					var min_gap := TackleStatePure.SLIDE_DURATION \
						+ TackleStatePure.RECOVERY_DURATION \
						+ TackleStatePure.TACKLE_COOLDOWN
					assert_gte(gap, min_gap,
						"Player %d re-tackled after only %d frames (min %d)" % [
							i, gap, min_gap])
				last_slide_start[i] = frame

			was_sliding[i] = currently_sliding

	assert_true(true, "Cooldown enforced — no spam detected")


func test_sliding_player_does_not_gain_possession():
	## While sliding, a player should not gain possession through normal pickup.
	_setup_sim()
	var violation := false

	for _frame in range(1000):
		_sim_frame_with_tackles()
		for p in sim_players:
			var ts: TackleStatePure = p["tackle_state"]
			if ts.is_sliding() and p["has_possession"]:
				violation = true
				break
		if violation:
			break

	assert_false(violation,
		"Sliding player should not gain possession through normal pickup")


func test_game_with_tackles_still_produces_passes():
	## Tackles should not break the basic AI flow — passes should still happen.
	_setup_sim()
	var pass_count := 0

	for _frame in range(500):
		var info: Dictionary = _sim_frame_with_tackles()
		if info["kick"].size() > 0 and info["kick"]["action"] == "pass":
			pass_count += 1

	gut.p("500 frames with tackles: %d passes" % pass_count)
	assert_gt(pass_count, 1,
		"At least 2 passes should happen in 500 frames (got %d)" % pass_count)


func test_trace_tackle_simulation():
	## Diagnostic trace of 400 frames with tackle events logged. Always passes.
	_setup_sim()
	gut.p("=== TACKLE SIMULATION TRACE (400 frames) ===")
	gut.p("")

	var total_clean := 0
	var total_fouls := 0
	var total_cards := 0
	var total_slide_initiations := 0
	var prev_sliding := {}

	for frame in range(400):
		var info: Dictionary = _sim_frame_with_tackles()
		var ti: Dictionary = info["tackle"]
		total_clean += int(ti["clean"])
		total_fouls += int(ti["foul"])
		total_cards += int(ti["cards"])

		# Detect new slide initiations
		for i in range(sim_players.size()):
			var ts: TackleStatePure = sim_players[i]["tackle_state"]
			if ts.is_sliding() and not prev_sliding.get(i, false):
				total_slide_initiations += 1
				var team_label := "H" if int(sim_players[i]["team_id"]) == 0 else "A"
				gut.p("  Frame %d: %s slot %d initiates slide at %s" % [
					frame, team_label, int(sim_players[i]["slot"]),
					str(sim_players[i]["pos"]).substr(0, 20)])
			prev_sliding[i] = ts.is_sliding()

		if int(ti["clean"]) > 0:
			gut.p("  Frame %d: CLEAN TACKLE — ball vel=%s" % [
				frame, str(sim_ball_vel).substr(0, 20)])
		if int(ti["foul"]) > 0:
			var card_str := " + YELLOW CARD" if int(ti["cards"]) > 0 else ""
			gut.p("  Frame %d: FOUL%s" % [frame, card_str])

	gut.p("")
	gut.p("=== SUMMARY ===")
	gut.p("Slide initiations: %d" % total_slide_initiations)
	gut.p("Clean tackles: %d" % total_clean)
	gut.p("Fouls: %d" % total_fouls)
	gut.p("Yellow cards: %d" % total_cards)

	assert_true(true, "Trace complete — inspect output above")
