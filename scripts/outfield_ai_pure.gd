class_name OutfieldAiPure
extends RefCounted
## Outfield player AI state machine — SWOS-inspired.
## Handles positioning, ball chasing, passing, shooting, and dribbling.
## Pure logic class: no Node or scene tree dependencies.

enum State {
	HOLD_POSITION,  ## Move toward zone-based target position
	CHASE_BALL,     ## Nearest eligible player pursues the ball
	SUPPORT_RUN,    ## Forward run when teammate has ball
	ON_BALL,        ## Has possession — decide pass/shot/dribble
}

var state: State = State.HOLD_POSITION
var on_ball_frames: int = 0
var _shot_charge_target: int = 0  ## Random charge frames for current shot attempt
var _has_decided_kick: bool = false  ## True once a kick decision is made this possession
var _dribble_target_frames: int = 75  ## How many frames to dribble before passing (randomized)


## Main AI tick. Returns a Dictionary:
## {
##   "velocity": Vector2 (px/frame direction, normalized or zero),
##   "kick_action": String ("none", "pass", "shot", "clear"),
##   "kick_direction": Vector2 (for shots/clears),
##   "kick_charge": int (charge frames to simulate),
## }
func tick(context: Dictionary) -> Dictionary:
	var result := {
		"velocity": Vector2.ZERO,
		"kick_action": "none",
		"kick_direction": Vector2.ZERO,
		"kick_charge": 1,
	}

	_update_state(context)

	match state:
		State.HOLD_POSITION:
			result = _tick_hold_position(context)
		State.CHASE_BALL:
			result = _tick_chase_ball(context)
		State.SUPPORT_RUN:
			result = _tick_support_run(context)
		State.ON_BALL:
			result = _tick_on_ball(context)

	return result


## State transitions based on current context.
func _update_state(context: Dictionary) -> void:
	var has_possession: bool = context["has_possession"]
	var is_chaser: bool = context["is_chaser"]

	var teammate_has_ball: bool = context.get("teammate_has_ball", false)

	match state:
		State.HOLD_POSITION:
			if has_possession:
				_enter_on_ball()
			elif is_chaser and not teammate_has_ball:
				state = State.CHASE_BALL
			elif _should_support_run(context):
				state = State.SUPPORT_RUN
		State.CHASE_BALL:
			if has_possession:
				_enter_on_ball()
			elif not is_chaser or teammate_has_ball:
				state = State.HOLD_POSITION
		State.SUPPORT_RUN:
			if has_possession:
				_enter_on_ball()
			elif not _should_support_run(context):
				state = State.HOLD_POSITION
		State.ON_BALL:
			if not has_possession:
				state = State.HOLD_POSITION
				on_ball_frames = 0
				_has_decided_kick = false


func _enter_on_ball() -> void:
	state = State.ON_BALL
	on_ball_frames = 0
	_has_decided_kick = false
	_shot_charge_target = AiConstants.SHOT_CHARGE_MIN + \
		randi() % (AiConstants.SHOT_CHARGE_MAX - AiConstants.SHOT_CHARGE_MIN + 1)
	# Randomize dribble duration within 1-3s range
	_dribble_target_frames = AiConstants.DRIBBLE_MIN_FRAMES + \
		randi() % (AiConstants.DRIBBLE_MAX_FRAMES - AiConstants.DRIBBLE_MIN_FRAMES + 1)


## HOLD_POSITION: move toward zone target, face the ball.
## When a teammate has the ball nearby, steer away to avoid stacking.
func _tick_hold_position(context: Dictionary) -> Dictionary:
	var target: Vector2 = context["zone_target"]
	var my_pos: Vector2 = context["my_position"]
	var ball_pos: Vector2 = context["ball_position"]
	var teammate_has_ball: bool = context.get("teammate_has_ball", false)

	var to_target := target - my_pos
	var vel := Vector2.ZERO
	if to_target.length() > AiConstants.APPROACH_STOP_DISTANCE:
		vel = to_target.normalized()

	# Steer away from ball carrier if teammate has the ball and we're too close
	if teammate_has_ball:
		var to_ball := my_pos - ball_pos  # AWAY from ball
		var dist_to_ball := to_ball.length()
		if dist_to_ball < AiConstants.TEAMMATE_AVOIDANCE_RADIUS and dist_to_ball > 0.1:
			var push := to_ball.normalized() * AiConstants.TEAMMATE_AVOIDANCE_STRENGTH
			vel = (vel + push).normalized() if (vel + push).length() > 0.01 else push.normalized()

	return {
		"velocity": vel,
		"kick_action": "none",
		"kick_direction": (ball_pos - my_pos).normalized() if my_pos.distance_to(ball_pos) > 0.1 else Vector2.ZERO,
		"kick_charge": 1,
	}


## CHASE_BALL: move toward ball position. When close enough, attempt tackle.
func _tick_chase_ball(context: Dictionary) -> Dictionary:
	var ball_pos: Vector2 = context["ball_position"]
	var my_pos: Vector2 = context["my_position"]
	var my_team_id: int = context["my_team_id"]

	var to_ball := ball_pos - my_pos
	var dist := to_ball.length()

	# When within tackle range of an opponent who has the ball, attempt to steal
	if dist < AiConstants.TACKLE_RANGE:
		var opponent_has_ball := false
		for p in context["all_players"]:
			# Check if any opponent is very close to ball (i.e. has it)
			if int(p["team_id"]) != my_team_id:
				var p_pos: Vector2 = Vector2(p["position"])
				if p_pos.distance_to(ball_pos) < 10.0:
					opponent_has_ball = true
					break
		if opponent_has_ball and randf() < AiConstants.TACKLE_SUCCESS_CHANCE:
			# Successful tackle — kick ball away from opponent
			var attack_dir: Vector2 = context["attack_direction"]
			return {
				"velocity": to_ball.normalized(),
				"kick_action": "clear",
				"kick_direction": attack_dir,
				"kick_charge": 2,
			}

	# Keep chasing
	var vel := Vector2.ZERO
	if dist > 2.0:
		vel = to_ball.normalized()

	return {
		"velocity": vel,
		"kick_action": "none",
		"kick_direction": to_ball.normalized() if dist > 0.1 else Vector2.ZERO,
		"kick_charge": 1,
	}


## SUPPORT_RUN: move to position ahead of ball carrier.
func _tick_support_run(context: Dictionary) -> Dictionary:
	var my_pos: Vector2 = context["my_position"]
	var ball_pos: Vector2 = context["ball_position"]
	var attack_dir: Vector2 = context["attack_direction"]

	# Target: ahead of ball in attack direction, with lateral offset
	var lateral := Vector2(attack_dir.y, -attack_dir.x)  # Perpendicular
	var side := 1.0 if my_pos.x > ball_pos.x else -1.0
	var run_target := ball_pos + attack_dir * AiConstants.SUPPORT_RUN_DISTANCE \
		+ lateral * side * AiConstants.SUPPORT_RUN_LATERAL

	# Clamp to pitch
	run_target.x = clampf(run_target.x, PitchGeometry.SIDELINE_LEFT + 10.0,
		PitchGeometry.SIDELINE_RIGHT - 10.0)
	run_target.y = clampf(run_target.y, PitchGeometry.GOAL_TOP_Y + 10.0,
		PitchGeometry.GOAL_BOTTOM_Y - 10.0)

	var to_target := run_target - my_pos
	var vel := Vector2.ZERO
	if to_target.length() > AiConstants.APPROACH_STOP_DISTANCE:
		vel = to_target.normalized()

	return {
		"velocity": vel,
		"kick_action": "none",
		"kick_direction": Vector2.ZERO,
		"kick_charge": 1,
	}


## ON_BALL: decide pass/shot/dribble.
## Decision priority:
##   1. Reaction delay — short dribble before any decision
##   2. Shoot — if close to goal with angle
##   3. Panic clear — in own third under heavy pressure
##   4. Early forward pass — opponent approaching, pass before they block
##   5. Wing pass — play ball wide for a cross
##   6. Cross — winger near goal, cross into box
##   7. Normal pass — dribble timer expired (1-3s), pass forward
##   8. Forced pass — max dribble time reached, must pass
##   9. Dribble — carry ball forward
func _tick_on_ball(context: Dictionary) -> Dictionary:
	on_ball_frames += 1
	var my_pos: Vector2 = context["my_position"]
	var attack_dir: Vector2 = context["attack_direction"]
	var goal_center: Vector2 = context["opponent_goal_center"]
	var is_home: bool = context["is_home"]

	# Reaction delay: dribble forward first (0.3s)
	if on_ball_frames < AiConstants.REACTION_DELAY:
		return _dribble_result(my_pos, attack_dir, goal_center)

	# Already decided a kick this possession — dribble until it executes
	if _has_decided_kick:
		return _dribble_result(my_pos, attack_dir, goal_center)

	var dist_to_goal := my_pos.distance_to(goal_center)
	var all_players: Array = context["all_players"]
	var my_team_id: int = context["my_team_id"]
	var my_role: int = context["my_role"]
	var under_pressure := _nearest_opponent_distance(my_pos, all_players, my_team_id)

	# 1. SHOOT — if in scoring position
	if dist_to_goal < AiConstants.SHOOT_RANGE:
		var shoot_angle := _goal_angle(my_pos, goal_center)
		if shoot_angle > AiConstants.MIN_SHOOT_ANGLE_DEG:
			if not _is_shot_blocked(my_pos, goal_center, all_players, my_team_id):
				_has_decided_kick = true
				var aim_dir := _compute_shot_direction(my_pos, goal_center)
				return {
					"velocity": aim_dir.normalized() * 0.5,
					"kick_action": "shot",
					"kick_direction": aim_dir,
					"kick_charge": _shot_charge_target,
				}

	# 2. PANIC CLEAR — under pressure in own third
	if under_pressure < AiConstants.PANIC_CLEAR_DISTANCE:
		if _is_in_own_third(my_pos, is_home):
			_has_decided_kick = true
			return {
				"velocity": attack_dir * 0.3,
				"kick_action": "clear",
				"kick_direction": attack_dir,
				"kick_charge": AiConstants.PANIC_CLEAR_CHARGE,
			}

	# 3. EARLY FORWARD PASS — opponent approaching, pass before they block the lane
	if under_pressure < AiConstants.PRESSURE_DISTANCE \
			and on_ball_frames >= AiConstants.PRESSURE_PASS_FRAMES:
		_has_decided_kick = true
		# Pass forward in attack direction (auto-targeted finds best teammate)
		return _make_pass_result(attack_dir)

	# 4. CROSS — winger near opponent goal, cross into the box
	if _is_wing_role(my_role) and dist_to_goal < AiConstants.CROSS_RANGE:
		if on_ball_frames >= AiConstants.PRESSURE_PASS_FRAMES:
			_has_decided_kick = true
			# Aim cross toward far post area
			var cross_dir := _compute_cross_direction(my_pos, goal_center, attack_dir)
			return {
				"velocity": cross_dir.normalized() * 0.3,
				"kick_action": "pass",
				"kick_direction": cross_dir,
				"kick_charge": AiConstants.CROSS_CHARGE,
			}

	# 5. WING PASS — if in central area, play ball out wide
	if _is_central(my_pos) and on_ball_frames >= _dribble_target_frames / 2:
		if randf() < 0.4:  # 40% chance each frame to pass wide vs continue
			var wing_dir := _find_wing_direction(my_pos, attack_dir)
			if wing_dir != Vector2.ZERO:
				_has_decided_kick = true
				return _make_pass_result(wing_dir)

	# 6. NORMAL PASS — dribble timer expired, pass forward
	if on_ball_frames >= _dribble_target_frames:
		_has_decided_kick = true
		return _make_pass_result(attack_dir)

	# 7. FORCED PASS — absolute max dribble time, must pass now
	if on_ball_frames >= AiConstants.DRIBBLE_MAX_FRAMES:
		_has_decided_kick = true
		return _make_pass_result(attack_dir)

	# 8. DRIBBLE — carry ball forward
	return _dribble_result(my_pos, attack_dir, goal_center)


func _dribble_result(my_pos: Vector2, attack_dir: Vector2,
		goal_center: Vector2) -> Dictionary:
	# Dribble toward goal, slightly toward center
	var to_goal := (goal_center - my_pos).normalized()
	var dribble_dir := (attack_dir + to_goal * 0.3).normalized()
	return {
		"velocity": dribble_dir,
		"kick_action": "none",
		"kick_direction": Vector2.ZERO,
		"kick_charge": 1,
	}


## Build a pass result dict (tap pass = auto-targeted by PassTargetingPure).
func _make_pass_result(direction: Vector2) -> Dictionary:
	return {
		"velocity": direction.normalized() * 0.3,
		"kick_action": "pass",
		"kick_direction": direction,
		"kick_charge": 1,
	}


## Distance to nearest opponent.
func _nearest_opponent_distance(my_pos: Vector2, all_players: Array,
		my_team_id: int) -> float:
	var min_dist := INF
	for p in all_players:
		if int(p["team_id"]) == my_team_id:
			continue
		var dist: float = Vector2(p["position"]).distance_to(my_pos)
		if dist < min_dist:
			min_dist = dist
	return min_dist


## True if this role is a winger.
func _is_wing_role(role: int) -> bool:
	return role in [
		FormationPure.Role.LEFT_WINGER,
		FormationPure.Role.RIGHT_WINGER,
		FormationPure.Role.LEFT_MID,
		FormationPure.Role.RIGHT_MID,
		FormationPure.Role.LEFT_WING_BACK,
		FormationPure.Role.RIGHT_WING_BACK,
	]


## True if position is in the central area of the pitch.
func _is_central(pos: Vector2) -> bool:
	return absf(pos.x - PitchGeometry.CENTER_X) < AiConstants.WING_PASS_X_THRESHOLD


## Find the best direction to pass out to a wing.
## Prefers the wider side (away from nearest sideline).
func _find_wing_direction(my_pos: Vector2, attack_dir: Vector2) -> Vector2:
	var dist_to_left := my_pos.x - PitchGeometry.SIDELINE_LEFT
	var dist_to_right := PitchGeometry.SIDELINE_RIGHT - my_pos.x

	# Pass toward the side with more space, angled forward
	var lateral: float
	if dist_to_right > dist_to_left:
		lateral = 1.0  # Pass right
	else:
		lateral = -1.0  # Pass left

	# Wing pass: mostly sideways, slightly forward
	var wing_dir := Vector2(lateral * 0.8, attack_dir.y * 0.6).normalized()
	return wing_dir


## Compute cross direction — aim toward far post / center of box.
func _compute_cross_direction(my_pos: Vector2, goal_center: Vector2,
		attack_dir: Vector2) -> Vector2:
	# Aim toward the far post (opposite side from winger)
	var far_post_x: float
	if my_pos.x < PitchGeometry.CENTER_X:
		far_post_x = PitchGeometry.GOAL_MOUTH_RIGHT - 10.0  # Far post
	else:
		far_post_x = PitchGeometry.GOAL_MOUTH_LEFT + 10.0

	var cross_target := Vector2(far_post_x, goal_center.y + attack_dir.y * -30.0)
	return (cross_target - my_pos).normalized()


## Check if a support run is appropriate for this player.
func _should_support_run(context: Dictionary) -> bool:
	var role: int = context["my_role"]
	# Only forwards, wingers, and attacking mids make support runs
	var attacking_roles := [
		FormationPure.Role.CENTER_FORWARD,
		FormationPure.Role.SECOND_STRIKER,
		FormationPure.Role.LEFT_WINGER,
		FormationPure.Role.RIGHT_WINGER,
		FormationPure.Role.ATTACKING_MID,
	]
	if role not in attacking_roles:
		return false

	# Only when own team has possession (but not this player)
	var has_possession: bool = context["has_possession"]
	if has_possession:
		return false
	var teammate_has_ball: bool = context.get("teammate_has_ball", false)
	return teammate_has_ball


## Calculate the angle (degrees) that the goal mouth subtends from a position.
func _goal_angle(pos: Vector2, goal_center: Vector2) -> float:
	var left := Vector2(PitchGeometry.GOAL_MOUTH_LEFT, goal_center.y)
	var right := Vector2(PitchGeometry.GOAL_MOUTH_RIGHT, goal_center.y)
	var to_left := (left - pos).normalized()
	var to_right := (right - pos).normalized()
	return rad_to_deg(acos(clampf(to_left.dot(to_right), -1.0, 1.0)))


## Check if the shot lane to goal is blocked by an opponent.
func _is_shot_blocked(my_pos: Vector2, goal_center: Vector2,
		all_players: Array, my_team_id: int) -> bool:
	var to_goal := (goal_center - my_pos).normalized()
	var dist := my_pos.distance_to(goal_center)
	for p in all_players:
		if p["team_id"] == my_team_id:
			continue
		var to_player: Vector2 = Vector2(p["position"]) - my_pos
		var proj: float = to_player.dot(to_goal)
		if proj < 10.0 or proj > dist:
			continue
		var perp_dist := absf(to_player.cross(to_goal))
		if perp_dist < 20.0:
			return true
	return false


## Compute shot direction toward goal with randomness.
func _compute_shot_direction(my_pos: Vector2, goal_center: Vector2) -> Vector2:
	var aim_x := goal_center.x + randf_range(
		-AiConstants.SHOT_AIM_RANDOMNESS, AiConstants.SHOT_AIM_RANDOMNESS)
	var aim_pos := Vector2(aim_x, goal_center.y)
	return (aim_pos - my_pos).normalized()


## Check if under pressure (opponent within panic distance).
func _is_under_pressure(my_pos: Vector2, all_players: Array,
		my_team_id: int) -> bool:
	for p in all_players:
		if p["team_id"] == my_team_id:
			continue
		if my_pos.distance_to(p["position"]) < AiConstants.PANIC_CLEAR_DISTANCE:
			return true
	return false


## Check if position is in own defensive third.
func _is_in_own_third(pos: Vector2, is_home: bool) -> bool:
	var third_height := PitchGeometry.PLAY_H / 3.0
	if is_home:
		return pos.y > PitchGeometry.GOAL_BOTTOM_Y - third_height
	else:
		return pos.y < PitchGeometry.GOAL_TOP_Y + third_height
