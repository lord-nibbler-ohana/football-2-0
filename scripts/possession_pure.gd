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
const GK_BOX_PICKUP_RADIUS := 28.0  ## Even larger when inside own penalty area (was 22)
const GK_BOX_SPEED_THRESHOLD := 8.0  ## GK can collect much faster balls in the box (was 5.0)

# --- Thresholds ---
const MIN_HEIGHT_FOR_PICKUP := 8.0
const GK_MAX_CATCH_HEIGHT := 60.0
const LOOSE_BALL_SPEED_THRESHOLD := 3.0  ## Outfield pickup threshold (was 2.5)
const PICKUP_DAMPING := 0.3

# --- Linger ---
const LINGER_FRAMES := 15  # 0.3s at 50 Hz

# --- Contested resolution ---
const CONTESTED_DISTANCE_TOLERANCE := 1.0  # px — within this counts as "equal"

# --- Anti-oscillation ---
# Detects A→B→A possession pattern and applies escalating per-player cooldown.
const OSCILLATION_COOLDOWN_BASE := 50  # 1.0s at 50 Hz
const OSCILLATION_COOLDOWN_ESCALATION := 25  # +0.5s per repeat
const OSCILLATION_COOLDOWN_MAX := 100  # 2.0s cap

# --- State ---
var possessor_index: int = -1
var possessing_team_id: int = -1
var team_linger_id: int = -1
var linger_frames_remaining: int = 0
var was_pickup_this_frame: bool = false

# --- Anti-oscillation state ---
# Tracks the last two distinct possessors (persists through loose-ball gaps).
var _last_possessor: int = -1  # Most recent player who had the ball
var _prev_possessor: int = -1  # Player who had the ball before _last_possessor
var _oscillation_count: Dictionary = {}  # {player_index -> consecutive oscillations}
var _player_pickup_cooldown: Dictionary = {}  # {player_index -> frames_remaining}

# --- Team-wide cooldown (set externally by match.gd after tackles) ---
# Team ID -> frames remaining. Players on this team can't pick up the ball.
var team_repossess_cooldown: Dictionary = {}  # {team_id: int -> frames_remaining: int}

# --- Tackle exclusive window (set externally by match.gd after tackles) ---
# Only the specified team can pick up the ball during this window.
var tackle_exclusive_team: int = -1
var tackle_exclusive_frames: int = 0


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

	# --- Tick team repossess cooldowns ---
	_tick_team_cooldowns()

	# --- Retain existing possession if within dribble leash ---
	if possessor_index >= 0 and possessor_index < player_infos.size():
		var info: Dictionary = player_infos[possessor_index]
		# Dribble leash only holds if the player is still eligible
		if info.get("eligible", true):
			var dist: float = info["position"].distance_to(ball_pos)
			if dist < DRIBBLE_RADIUS:
				_update_linger(possessor_index, player_infos)
				return possessor_index
		# Lost — ball went beyond leash or player became ineligible
		possessor_index = -1
		possessing_team_id = -1

	# --- Find pickup candidates ---
	var candidates: Array = []  # [{index, dist, info}]

	for i in range(player_infos.size()):
		var info: Dictionary = player_infos[i]

		# Skip ineligible players (stunned, cooldown, passthrough)
		if not info.get("eligible", true):
			continue

		# Skip players whose team is on repossess cooldown
		var tid: int = info.get("team_id", -1)
		if team_repossess_cooldown.get(tid, 0) > 0:
			continue

		# Tackle exclusive window: only the winning team can pick up
		if tackle_exclusive_frames > 0 and tid != tackle_exclusive_team:
			continue

		# Per-player oscillation cooldown
		if _player_pickup_cooldown.get(i, 0) > 0:
			continue

		var is_gk: bool = info.get("is_goalkeeper", false)
		var gk_in_box: bool = false
		if is_gk:
			var is_home: bool = info.get("is_home", true)
			gk_in_box = PitchGeometry.is_in_box(info["position"], is_home)

		# Height check
		var max_height: float = GK_MAX_CATCH_HEIGHT if is_gk else MIN_HEIGHT_FOR_PICKUP
		if ball_height >= max_height:
			continue

		# Speed check — GK in own box can collect much faster balls
		var speed_threshold: float = LOOSE_BALL_SPEED_THRESHOLD
		if gk_in_box:
			speed_threshold = GK_BOX_SPEED_THRESHOLD
		if ball_speed >= speed_threshold:
			continue

		# Radius check — GK in own box has a larger pickup zone
		var radius: float = PICKUP_RADIUS
		if is_gk:
			radius = GK_BOX_PICKUP_RADIUS if gk_in_box else GK_PICKUP_RADIUS
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

	# --- Detect oscillation before applying possession ---
	if winner_idx != _last_possessor:
		if _last_possessor >= 0:
			# Different player gaining — check for A→B→A pattern
			if winner_idx == _prev_possessor and _prev_possessor >= 0:
				# A→B→A: the player who just lost (_last_possessor) gets cooldown
				var loser: int = _last_possessor
				var count: int = _oscillation_count.get(loser, 0) + 1
				_oscillation_count[loser] = count
				var cd: int = mini(
					OSCILLATION_COOLDOWN_BASE + OSCILLATION_COOLDOWN_ESCALATION * (count - 1),
					OSCILLATION_COOLDOWN_MAX)
				_player_pickup_cooldown[loser] = cd
			else:
				_oscillation_count.erase(_last_possessor)
			_prev_possessor = _last_possessor
		_last_possessor = winner_idx

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
	team_repossess_cooldown.clear()
	tackle_exclusive_team = -1
	tackle_exclusive_frames = 0
	_last_possessor = -1
	_prev_possessor = -1
	_oscillation_count.clear()
	_player_pickup_cooldown.clear()


## Apply team-wide repossess cooldown (called by match.gd after tackles).
## Prevents the entire team from picking up the ball for N frames.
func apply_team_repossess_cooldown(team_id: int, frames: int) -> void:
	team_repossess_cooldown[team_id] = frames


## Apply team-wide contest cooldown (for standing tackle eligibility).
## This is queried by match.gd, not used internally.
var team_contest_cooldown: Dictionary = {}  # {team_id: int -> frames: int}

func apply_team_contest_cooldown(team_id: int, frames: int) -> void:
	team_contest_cooldown[team_id] = frames

func can_team_contest(team_id: int) -> bool:
	return team_contest_cooldown.get(team_id, 0) <= 0


## Set tackle exclusive window — only the given team can pick up the ball.
func set_tackle_exclusive(team_id: int, frames: int) -> void:
	tackle_exclusive_team = team_id
	tackle_exclusive_frames = frames


# --- Private helpers ---

## Resolve multiple candidates. GK in own box always wins if eligible.
## Contested (different teams within tolerance) is decided by approach speed.
## Same-team or clear distance winner: closest wins.
func _resolve_candidates(candidates: Array, ball_pos: Vector2) -> int:
	# GK in own box gets absolute priority (they "claim" the ball)
	for c: Dictionary in candidates:
		if c["info"].get("is_goalkeeper", false):
			var is_home: bool = c["info"].get("is_home", true)
			if PitchGeometry.is_in_box(c["info"]["position"], is_home):
				return c["index"]

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


## Tick down team-wide cooldowns each frame.
func _tick_team_cooldowns() -> void:
	for tid in team_repossess_cooldown.keys():
		if team_repossess_cooldown[tid] > 0:
			team_repossess_cooldown[tid] -= 1
	for tid in team_contest_cooldown.keys():
		if team_contest_cooldown[tid] > 0:
			team_contest_cooldown[tid] -= 1
	if tackle_exclusive_frames > 0:
		tackle_exclusive_frames -= 1
		if tackle_exclusive_frames <= 0:
			tackle_exclusive_team = -1
	# Per-player oscillation cooldowns
	for pid in _player_pickup_cooldown.keys():
		if _player_pickup_cooldown[pid] > 0:
			_player_pickup_cooldown[pid] -= 1
			if _player_pickup_cooldown[pid] <= 0:
				_player_pickup_cooldown.erase(pid)


## Update linger timer. Called every check_possession tick.
func _update_linger(new_possessor: int, player_infos: Array) -> void:
	if new_possessor >= 0:
		var tid: int = player_infos[new_possessor].get("team_id", -1)
		team_linger_id = tid
		linger_frames_remaining = LINGER_FRAMES
	else:
		if linger_frames_remaining > 0:
			linger_frames_remaining -= 1
