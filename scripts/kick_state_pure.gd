class_name KickStatePure
extends RefCounted
## Pure kick state machine — IDLE → CHARGING → AFTERTOUCH.
## Short tap = auto-targeted pass, long press = power shot.

enum State { IDLE, CHARGING, AFTERTOUCH }

const SHORT_TAP_FRAMES := 4
const MAX_CHARGE_FRAMES := 30
const MIN_KICK_POWER := 0.15
const MAX_KICK_POWER := 1.0
const MAX_KICK_SPEED := 8.0  # px/frame at 50 Hz
const MIN_PASS_SPEED := 4.5  # px/frame — must exceed possession speed threshold (4.0)
const AFTERTOUCH_WINDOW := 12  # frames — matches AftertouchPure.OPEN_PLAY_WINDOW

## Ball height during kicks — modeled on Sensible Soccer behavior.
## Passes stay on the ground. Shots get natural lift proportional to power.
## With GRAVITY=0.4, a max-power shot (lift=3.5) peaks at ~15px height
## and stays airborne for ~17 frames, creating a visible arc.
## Medium shots get less lift, producing low driven trajectories.
## Aftertouch can further loft or dip the ball during the aftertouch window.
const SHOT_LIFT_FACTOR := 3.5  # vertical_velocity = SHOT_LIFT_FACTOR * power
const SHOT_LIFT_THRESHOLD := 0.3  # power below this = ground shot (no lift)
const PASS_LIFT := 0.0  # passes are always ground balls

var state: State = State.IDLE
var charge_frames: int = 0
var aftertouch_timer: int = 0


## Begin charging (fire button just pressed).
func start_charge() -> void:
	if state != State.IDLE:
		return
	state = State.CHARGING
	charge_frames = 0


## Tick one frame of charging (fire button held).
func tick_charge() -> void:
	if state != State.CHARGING:
		return
	charge_frames = mini(charge_frames + 1, MAX_CHARGE_FRAMES)


## Release the kick (fire button just released).
## joystick_dir: 8-way direction at moment of release (or Vector2.ZERO).
## facing_dir: player's current facing direction (fallback).
## all_players: Array of dicts with "position" and "team_id".
## kicker_pos: kicker's position.
## kicker_team_id: kicker's team.
## kicker_index: kicker's index in all_players (to exclude from pass targets).
## Returns {"type": "pass"/"shot"/"none", "velocity": Vector2, "up_velocity": float}.
func release(joystick_dir: Vector2, facing_dir: Vector2,
		all_players: Array, kicker_pos: Vector2,
		kicker_team_id: int, kicker_index: int = -1) -> Dictionary:
	if state != State.CHARGING:
		return {"type": "none", "velocity": Vector2.ZERO, "up_velocity": 0.0}

	var result: Dictionary

	if charge_frames <= SHORT_TAP_FRAMES:
		result = _compute_pass(facing_dir, all_players, kicker_pos,
			kicker_team_id, kicker_index)
	else:
		result = _compute_shot(joystick_dir, facing_dir)

	# Transition to aftertouch
	state = State.AFTERTOUCH
	aftertouch_timer = AFTERTOUCH_WINDOW
	return result


## Tick one frame of aftertouch. Returns to IDLE when window expires.
func tick_aftertouch() -> void:
	if state != State.AFTERTOUCH:
		return
	aftertouch_timer -= 1
	if aftertouch_timer <= 0:
		state = State.IDLE


## True if currently charging a kick.
func is_charging() -> bool:
	return state == State.CHARGING


## True if in aftertouch window.
func is_in_aftertouch() -> bool:
	return state == State.AFTERTOUCH


## Reset to idle (e.g., lost possession while charging).
func reset() -> void:
	state = State.IDLE
	charge_frames = 0
	aftertouch_timer = 0


## Compute auto-targeted pass toward best teammate in cone.
func _compute_pass(facing_dir: Vector2, all_players: Array,
		kicker_pos: Vector2, kicker_team_id: int,
		kicker_index: int) -> Dictionary:
	var target := PassTargetingPure.find_best_target(
		kicker_pos, facing_dir, kicker_team_id, all_players, kicker_index)

	if target["found"]:
		var pass_result := PassTargetingPure.compute_pass_velocity(
			kicker_pos, target["position"], MAX_KICK_SPEED)
		# Ensure pass speed exceeds possession threshold
		var pass_vel: Vector2 = pass_result["velocity"]
		if pass_vel.length() < MIN_PASS_SPEED and pass_vel.length() > 0.001:
			pass_vel = pass_vel.normalized() * MIN_PASS_SPEED
		return {"type": "pass", "velocity": pass_vel, "up_velocity": 0.0}

	# No target found — push in facing direction at minimum pass speed
	var dir := facing_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	return {"type": "pass", "velocity": dir * MIN_PASS_SPEED,
		"up_velocity": 0.0}


## Compute power shot in joystick/facing direction.
## Height behavior matches Sensible Soccer: low-power shots stay on the ground,
## medium shots get slight lift, full-power shots arc visibly in the air.
## Aftertouch (loft/dip) further modifies height during the aftertouch window.
func _compute_shot(joystick_dir: Vector2, facing_dir: Vector2) -> Dictionary:
	var dir := joystick_dir.normalized() if joystick_dir != Vector2.ZERO \
		else facing_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var power := clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES),
		MIN_KICK_POWER, MAX_KICK_POWER)
	var speed := power * MAX_KICK_SPEED

	# Natural lift: low-power shots stay on the ground, harder shots arc up.
	# This creates the characteristic SWOS feel where taps produce ground balls
	# and held shots produce visible arcs that can be curled with aftertouch.
	var lift := 0.0
	if power > SHOT_LIFT_THRESHOLD:
		# Scale lift from 0 at threshold to full at max power
		var lift_power := (power - SHOT_LIFT_THRESHOLD) / (MAX_KICK_POWER - SHOT_LIFT_THRESHOLD)
		lift = lift_power * SHOT_LIFT_FACTOR

	return {"type": "shot", "velocity": dir * speed, "up_velocity": lift}
