class_name PassTargetingPure
extends RefCounted
## Pure pass targeting logic — finds best teammate in a cone for auto-targeted passes.

const PASS_CONE_HALF_ANGLE := deg_to_rad(30.0)
const AIM_ASSIST_ANGLE := deg_to_rad(15.0)
const TOTAL_CONE_HALF := PASS_CONE_HALF_ANGLE + AIM_ASSIST_ANGLE  # 45 degrees
const BLOCKED_LANE_PENALTY := 500.0
const MAX_PASS_POWER := 0.5
const MIN_PASS_POWER := 0.15
const MIN_PASS_DISTANCE := 20.0
const MAX_PASS_DISTANCE := 300.0
const LANE_WIDTH := 15.0


## Find the best pass target in a cone around the kicker's facing direction.
## all_players: Array of dicts with "position" (Vector2), "team_id" (int).
## kicker_index: index of the kicker in all_players (to exclude self).
## Returns {"found": bool, "position": Vector2, "distance": float}.
static func find_best_target(
		kicker_pos: Vector2, facing_dir: Vector2, kicker_team_id: int,
		all_players: Array, kicker_index: int = -1) -> Dictionary:
	if facing_dir == Vector2.ZERO:
		return {"found": false}

	var kick_angle := facing_dir.angle()
	var best_score := INF
	var best_pos := Vector2.ZERO
	var best_dist := 0.0

	# Collect opponent positions for lane blocking check
	var opponents: Array[Vector2] = []
	for i in range(all_players.size()):
		var info: Dictionary = all_players[i]
		if info["team_id"] != kicker_team_id:
			opponents.append(info["position"])

	for i in range(all_players.size()):
		if i == kicker_index:
			continue
		var info: Dictionary = all_players[i]
		if info["team_id"] != kicker_team_id:
			continue

		var mate_pos: Vector2 = info["position"]
		var to_mate := mate_pos - kicker_pos
		var dist := to_mate.length()

		# Reject too close or too far
		if dist < MIN_PASS_DISTANCE or dist > MAX_PASS_DISTANCE:
			continue

		# Check angle within cone
		var angle_to_mate := to_mate.angle()
		var angle_diff := absf(angle_difference(kick_angle, angle_to_mate))
		if angle_diff > TOTAL_CONE_HALF:
			continue

		# Score: prefer closer teammates, penalise off-angle
		var score := dist + angle_diff * 2.0

		# Penalise blocked passing lanes
		if is_lane_blocked(kicker_pos, mate_pos, opponents, LANE_WIDTH):
			score += BLOCKED_LANE_PENALTY

		if score < best_score:
			best_score = score
			best_pos = mate_pos
			best_dist = dist

	if best_score < INF:
		return {"found": true, "position": best_pos, "distance": best_dist}
	return {"found": false}


## Compute pass velocity toward a target position.
## Returns {"velocity": Vector2, "up_velocity": float}.
static func compute_pass_velocity(
		kicker_pos: Vector2, target_pos: Vector2,
		max_kick_speed: float) -> Dictionary:
	var to_target := target_pos - kicker_pos
	var dist := to_target.length()
	if dist < 0.001:
		return {"velocity": Vector2.ZERO, "up_velocity": 0.0}

	var power := clampf(dist / MAX_PASS_DISTANCE, MIN_PASS_POWER, MAX_PASS_POWER)
	var direction := to_target.normalized()
	var speed := power * max_kick_speed
	return {"velocity": direction * speed, "up_velocity": 0.0}


## Check if any opponent is within lane_width of the line from → to.
static func is_lane_blocked(
		from: Vector2, to: Vector2, opponents: Array,
		lane_width: float = 15.0) -> bool:
	var line := to - from
	var line_len_sq := line.length_squared()
	if line_len_sq < 0.001:
		return false

	for opp_pos: Vector2 in opponents:
		# Project opponent onto the line segment
		var t := (opp_pos - from).dot(line) / line_len_sq
		# Only check between kicker and target (not behind or beyond)
		if t < 0.1 or t > 0.9:
			continue
		var closest := from + line * t
		if closest.distance_to(opp_pos) < lane_width:
			return true
	return false
