class_name GoalkeeperAiPure
extends RefCounted
## Goalkeeper AI — positioning, rushing, distribution, and clearing.
## Pure logic class: no Node or scene tree dependencies.
##
## When the GK picks up the ball inside the penalty area, it enters DISTRIBUTING:
## the AI walks forward with the ball while the human player controls only the kick.
## Short tap + direction = pass to nearby defender, long press = kick to midfield.
## Outside the box, the GK auto-clears immediately.

enum State {
	TEND_GOAL,     ## Position on arc between ball and goal center
	RUSH_OUT,      ## Rush toward ball when close and dangerous
	RETURN_HOME,   ## Return to goal line after rushing
	DISTRIBUTING,  ## Carrying ball out of goal, waiting for player kick
}

var state: State = State.TEND_GOAL
var hold_timer: int = 0  ## Frames holding ball before moving
var distribute_timer: int = 0  ## Frames since starting distribution
var _distribute_target: Vector2 = Vector2.ZERO  ## Where GK runs to


## Main AI tick. Returns:
## {
##   "velocity": Vector2 (direction, normalized or zero),
##   "kick_action": String ("none", "pass", "clear"),
##   "kick_direction": Vector2,
##   "kick_charge": int,
##   "gk_distributing": bool — true when GK is carrying ball (player controls kick),
## }
func tick(context: Dictionary) -> Dictionary:
	var has_possession: bool = context["has_possession"]
	var ball_pos: Vector2 = context["ball_position"]
	var my_pos: Vector2 = context["my_position"]
	var is_home: bool = context["is_home"]

	# If holding ball, manage distribution
	if has_possession:
		var in_box := PitchGeometry.is_in_box(my_pos, is_home)
		if in_box:
			return _tick_with_ball_in_box(context)
		else:
			return _tick_with_ball_outside_box(context)

	# Lost the ball — reset distribution state
	if state == State.DISTRIBUTING:
		state = State.RETURN_HOME
		hold_timer = 0
		distribute_timer = 0

	# State transitions
	_update_state(context)

	match state:
		State.TEND_GOAL:
			return _tick_tend_goal(context)
		State.RUSH_OUT:
			return _tick_rush_out(context)
		State.RETURN_HOME:
			return _tick_return_home(context)

	return _no_action()


func _update_state(context: Dictionary) -> void:
	var ball_pos: Vector2 = context["ball_position"]
	var my_pos: Vector2 = context["my_position"]
	var goal_center: Vector2 = context["own_goal_center"]
	var ball_vel: Vector2 = context["ball_velocity"]
	var ball_height: float = context["ball_height"]

	match state:
		State.TEND_GOAL:
			if _should_rush(ball_pos, goal_center, ball_vel, ball_height):
				state = State.RUSH_OUT
		State.RUSH_OUT:
			var dist_to_goal := ball_pos.distance_to(goal_center)
			if dist_to_goal > AiConstants.GK_RUSH_TRIGGER_DISTANCE * 1.3:
				state = State.RETURN_HOME
			elif ball_height > 30.0:
				state = State.RETURN_HOME
		State.RETURN_HOME:
			var home_pos := _goal_home_position(goal_center, context["is_home"])
			if my_pos.distance_to(home_pos) < 5.0:
				state = State.TEND_GOAL


## TEND_GOAL: position on arc between ball and goal center.
func _tick_tend_goal(context: Dictionary) -> Dictionary:
	var target := _compute_tend_position(context)
	var my_pos: Vector2 = context["my_position"]
	var to_target := target - my_pos
	var vel := Vector2.ZERO
	if to_target.length() > 2.0:
		vel = to_target.normalized() * AiConstants.GK_SPEED_FACTOR

	return _make_result(vel)


## RUSH_OUT: move toward ball at increased speed.
func _tick_rush_out(context: Dictionary) -> Dictionary:
	var ball_pos: Vector2 = context["ball_position"]
	var my_pos: Vector2 = context["my_position"]
	var to_ball := ball_pos - my_pos
	var vel := Vector2.ZERO
	if to_ball.length() > 2.0:
		vel = to_ball.normalized() * AiConstants.GK_RUSH_SPEED_FACTOR

	return _make_result(vel)


## RETURN_HOME: go back to goal position.
func _tick_return_home(context: Dictionary) -> Dictionary:
	var goal_center: Vector2 = context["own_goal_center"]
	var is_home: bool = context["is_home"]
	var home := _goal_home_position(goal_center, is_home)
	var my_pos: Vector2 = context["my_position"]
	var to_home := home - my_pos
	var vel := Vector2.ZERO
	if to_home.length() > 2.0:
		vel = to_home.normalized() * AiConstants.GK_SPEED_FACTOR

	return _make_result(vel)


## GK with ball INSIDE the penalty area: hold briefly, then walk forward.
## Player controls the kick — AI only provides movement.
func _tick_with_ball_in_box(context: Dictionary) -> Dictionary:
	var my_pos: Vector2 = context["my_position"]
	var attack_dir: Vector2 = context["attack_direction"]
	var goal_center: Vector2 = context["own_goal_center"]

	if state != State.DISTRIBUTING:
		# Initial hold — stand still for a moment
		hold_timer += 1
		if hold_timer >= AiConstants.GK_HOLD_FRAMES:
			state = State.DISTRIBUTING
			distribute_timer = 0
			# Set target: advance from goal toward pitch center
			_distribute_target = goal_center + attack_dir * AiConstants.GK_DISTRIBUTE_ADVANCE
		return _make_result(Vector2.ZERO, true)

	# DISTRIBUTING: walk toward target
	distribute_timer += 1
	var to_target := _distribute_target - my_pos
	var vel := Vector2.ZERO
	if to_target.length() > 5.0:
		vel = to_target.normalized() * AiConstants.GK_DISTRIBUTE_SPEED

	# AI auto-kick if max time exceeded (safety valve)
	if distribute_timer >= AiConstants.GK_DISTRIBUTE_MAX_FRAMES:
		return _force_distribute(context)

	return _make_result(vel, true)


## GK with ball OUTSIDE the penalty area: immediate clearing kick.
func _tick_with_ball_outside_box(context: Dictionary) -> Dictionary:
	var attack_dir: Vector2 = context["attack_direction"]
	hold_timer = 0
	distribute_timer = 0
	state = State.RETURN_HOME
	return {
		"velocity": Vector2.ZERO,
		"kick_action": "clear",
		"kick_direction": attack_dir,
		"kick_charge": AiConstants.GK_CLEAR_CHARGE,
		"gk_distributing": false,
	}


## Force distribution when max time reached (AI fallback).
func _force_distribute(context: Dictionary) -> Dictionary:
	var attack_dir: Vector2 = context["attack_direction"]
	hold_timer = 0
	distribute_timer = 0
	state = State.RETURN_HOME
	return {
		"velocity": Vector2.ZERO,
		"kick_action": "pass",
		"kick_direction": attack_dir,
		"kick_charge": AiConstants.GK_LONG_KICK_CHARGE,
		"gk_distributing": false,
	}


## Compute the ideal tend position on arc.
func _compute_tend_position(context: Dictionary) -> Vector2:
	var ball_pos: Vector2 = context["ball_position"]
	var goal_center: Vector2 = context["own_goal_center"]
	var is_home: bool = context["is_home"]

	var to_ball := (ball_pos - goal_center)
	if to_ball.length() < 1.0:
		to_ball = Vector2.UP if is_home else Vector2.DOWN
	to_ball = to_ball.normalized()

	var target := goal_center + to_ball * AiConstants.GK_ARC_RADIUS

	# Clamp X to goal mouth with margin
	target.x = clampf(target.x,
		PitchGeometry.GOAL_MOUTH_LEFT - AiConstants.GK_X_MARGIN,
		PitchGeometry.GOAL_MOUTH_RIGHT + AiConstants.GK_X_MARGIN)

	# Clamp Y to stay near goal line
	if is_home:
		target.y = clampf(target.y,
			PitchGeometry.GOAL_BOTTOM_Y - AiConstants.GK_MAX_Y_FROM_GOAL,
			PitchGeometry.GOAL_BOTTOM_Y)
	else:
		target.y = clampf(target.y,
			PitchGeometry.GOAL_TOP_Y,
			PitchGeometry.GOAL_TOP_Y + AiConstants.GK_MAX_Y_FROM_GOAL)

	return target


## Check if GK should rush out.
func _should_rush(ball_pos: Vector2, goal_center: Vector2,
		ball_vel: Vector2, ball_height: float) -> bool:
	if ball_height > 12.0:  # More generous height threshold (was 8.0)
		return false
	var dist := ball_pos.distance_to(goal_center)
	if dist > AiConstants.GK_RUSH_TRIGGER_DISTANCE:
		return false
	# Ball must be moving toward goal OR be very close (loose ball in box)
	var to_goal := (goal_center - ball_pos).normalized()
	var approach_speed := ball_vel.dot(to_goal)
	# Rush for close loose balls even if not moving toward goal
	if dist < 60.0 and ball_vel.length() < 1.0:
		return true
	return approach_speed > AiConstants.GK_RUSH_BALL_SPEED_MIN


## Default goal position (slightly in front of goal center).
func _goal_home_position(goal_center: Vector2, is_home: bool) -> Vector2:
	if is_home:
		return Vector2(goal_center.x, goal_center.y - 15.0)
	else:
		return Vector2(goal_center.x, goal_center.y + 15.0)


## True if the GK is currently distributing the ball (carrying it out).
func is_distributing() -> bool:
	return state == State.DISTRIBUTING


func _make_result(vel: Vector2, distributing: bool = false) -> Dictionary:
	return {
		"velocity": vel,
		"kick_action": "none",
		"kick_direction": Vector2.ZERO,
		"kick_charge": 1,
		"gk_distributing": distributing,
	}


func _no_action() -> Dictionary:
	return _make_result(Vector2.ZERO)
