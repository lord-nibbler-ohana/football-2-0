class_name PossessionPure
extends RefCounted
## Pure possession and dribble logic — no Node dependencies.
## Central authority for who has the ball, based on proximity, height, speed,
## team affiliation, and goalkeeper rules.

# --- Radii and distances ---
const PICKUP_RADIUS := 8.0
const DRIBBLE_RADIUS := 12.0
const DRIBBLE_OFFSET := 5.0
const DRIBBLE_LERP_FACTOR := 0.4
const GK_PICKUP_RADIUS := 15.0

# --- Thresholds ---
const MIN_HEIGHT_FOR_PICKUP := 8.0
const GK_MAX_CATCH_HEIGHT := 60.0
const LOOSE_BALL_SPEED_THRESHOLD := 2.5
const PICKUP_DAMPING := 0.3

# --- Linger ---
const LINGER_FRAMES := 15  # 0.3s at 50 Hz

# --- Contested resolution ---
const CONTESTED_DISTANCE_TOLERANCE := 1.0  # px — within this counts as "equal"

# --- State ---
var possessor_index: int = -1
var possessing_team_id: int = -1
var team_linger_id: int = -1
var linger_frames_remaining: int = 0
var was_pickup_this_frame: bool = false


## Check which player (if any) should have possession.
## player_infos: Array of {position: Vector2, team_id: int,
##     is_goalkeeper: bool, velocity: Vector2}.
## ball_pos: current ball position on pitch.
## ball_height: ball height above ground (px).
## ball_speed: ball ground velocity magnitude (px/frame).
## Returns the index of the possessing player, or -1.
func check_possession(player_infos: Array, ball_pos: Vector2,
		ball_height: float = 0.0, ball_speed: float = 0.0) -> int:
	was_pickup_this_frame = false

	# --- Retain existing possession if within dribble leash ---
	if possessor_index >= 0 and possessor_index < player_infos.size():
		var info: Dictionary = player_infos[possessor_index]
		var dist: float = info["position"].distance_to(ball_pos)
		if dist < DRIBBLE_RADIUS:
			_update_linger(possessor_index, player_infos)
			return possessor_index
		# Lost — ball went beyond leash
		possessor_index = -1
		possessing_team_id = -1

	# --- Find pickup candidates ---
	var candidates: Array = []  # [{index, dist, info}]

	for i in range(player_infos.size()):
		var info: Dictionary = player_infos[i]

		# Skip ineligible players (stunned, cooldown, passthrough)
		if not info.get("eligible", true):
			continue

		var is_gk: bool = info.get("is_goalkeeper", false)

		# Height check
		var max_height: float = GK_MAX_CATCH_HEIGHT if is_gk else MIN_HEIGHT_FOR_PICKUP
		if ball_height >= max_height:
			continue

		# Speed check
		if ball_speed >= LOOSE_BALL_SPEED_THRESHOLD:
			continue

		# Radius check
		var radius: float = GK_PICKUP_RADIUS if is_gk else PICKUP_RADIUS
		var dist: float = info["position"].distance_to(ball_pos)
		if dist >= radius:
			continue

		candidates.append({"index": i, "dist": dist, "info": info})

	if candidates.is_empty():
		possessor_index = -1
		possessing_team_id = -1
		_update_linger(-1, player_infos)
		return possessor_index

	# --- Resolve candidates ---
	var winner_idx: int
	if candidates.size() == 1:
		winner_idx = candidates[0]["index"]
	else:
		winner_idx = _resolve_candidates(candidates, ball_pos)

	# --- Apply possession ---
	possessor_index = winner_idx
	possessing_team_id = player_infos[winner_idx].get("team_id", -1)
	was_pickup_this_frame = true
	_update_linger(possessor_index, player_infos)
	return possessor_index


## Calculate the dribble target position (where ball should lerp toward).
## facing: normalised direction the player is facing.
static func get_dribble_target(player_pos: Vector2, facing: Vector2) -> Vector2:
	if facing == Vector2.ZERO:
		return player_pos + Vector2.DOWN * DRIBBLE_OFFSET
	return player_pos + facing.normalized() * DRIBBLE_OFFSET


# --- Query API ---

## True if the given player index currently has the ball.
func player_has_ball(player_index: int) -> bool:
	return possessor_index == player_index


## True if the given team currently has the ball (includes linger period).
func team_has_ball(team_id: int) -> bool:
	if possessing_team_id == team_id:
		return true
	if linger_frames_remaining > 0 and team_linger_id == team_id:
		return true
	return false


## True if no player has possession.
func is_ball_loose() -> bool:
	return possessor_index == -1


## Index of the current possessor, or -1.
func get_possessor() -> int:
	return possessor_index


## Team id of the current possessor, or -1.
func get_possessing_team() -> int:
	return possessing_team_id


## Reset all possession state.
func reset() -> void:
	possessor_index = -1
	possessing_team_id = -1
	team_linger_id = -1
	linger_frames_remaining = 0
	was_pickup_this_frame = false


# --- Private helpers ---

## Resolve multiple candidates. Contested (different teams within tolerance)
## is decided by approach speed. Same-team or clear distance winner: closest wins.
func _resolve_candidates(candidates: Array, ball_pos: Vector2) -> int:
	# Sort by distance ascending
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist"] < b["dist"]
	)

	var best: Dictionary = candidates[0]
	var runner_up: Dictionary = candidates[1]

	# Check if contested: different teams and distances within tolerance
	var distance_gap: float = absf(runner_up["dist"] - best["dist"])
	var same_team: bool = (best["info"].get("team_id", -1)
		== runner_up["info"].get("team_id", -1))

	if not same_team and distance_gap < CONTESTED_DISTANCE_TOLERANCE:
		return _resolve_contested(candidates, ball_pos)

	# Not contested — closest wins (already sorted)
	return best["index"]


## Contested resolution: highest approach speed toward ball wins.
## Approach speed = velocity dot direction-to-ball.
func _resolve_contested(candidates: Array, ball_pos: Vector2) -> int:
	var best_approach: float = -INF
	var best_idx: int = candidates[0]["index"]

	for c: Dictionary in candidates:
		var info: Dictionary = c["info"]
		var to_ball: Vector2 = ball_pos - info["position"]
		var dist: float = to_ball.length()
		if dist < 0.001:
			# On top of ball — max approach
			return c["index"]
		var approach: float = info.get("velocity", Vector2.ZERO).dot(
			to_ball / dist)
		if approach > best_approach or (
				approach == best_approach and c["index"] < best_idx):
			best_approach = approach
			best_idx = c["index"]

	return best_idx


## Update linger timer. Called every check_possession tick.
func _update_linger(new_possessor: int, player_infos: Array) -> void:
	if new_possessor >= 0:
		var tid: int = player_infos[new_possessor].get("team_id", -1)
		team_linger_id = tid
		linger_frames_remaining = LINGER_FRAMES
	else:
		if linger_frames_remaining > 0:
			linger_frames_remaining -= 1
