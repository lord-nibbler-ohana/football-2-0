class_name KickStatePure
extends RefCounted
## Pure kick state machine — IDLE → CHARGING → AFTERTOUCH.
## Short tap = auto-targeted pass, long press = power shot.
## Height and spin based on ysoccer mechanics: joystick direction relative to
## kick direction controls low/medium/high shots and initial spin.

enum State { IDLE, CHARGING, AFTERTOUCH }

const SHORT_TAP_FRAMES := 4
const MAX_CHARGE_FRAMES := 15
const MIN_KICK_POWER := 0.15
const MAX_KICK_POWER := 1.0
const MAX_KICK_SPEED := 8.0  # px/frame at 50 Hz
const MIN_PASS_SPEED := 3.0  # px/frame — must exceed possession speed threshold
const AFTERTOUCH_WINDOW := 16  # frames — matches AftertouchPure.OPEN_PLAY_WINDOW

## Directional height control (ysoccer model).
## Joystick direction relative to kick direction selects low/medium/high.
const SHOT_LIFT_LOW := 0.5  ## Forward input: driven/ground shot
const SHOT_LIFT_MEDIUM := 1.2  ## Sideways or no input: standard arc
const SHOT_LIFT_HIGH := 1.8  ## Backward input: lob/chip
const SHOT_ANGLE_LOW := 67.5  ## Degrees from kick direction
const SHOT_ANGLE_HIGH := 112.5  ## Degrees from kick direction

## Spin on angled kicks (ysoccer model).
const SPIN_STRENGTH := 3.0  ## Initial spin magnitude on angled kicks
const SPIN_ANGLE_MIN := 22.5  ## Minimum angle_diff for spin (degrees)
const SPIN_ANGLE_MAX := 157.5  ## Maximum angle_diff for spin (degrees)

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
## Returns {"type", "velocity", "up_velocity", "spin"}.
func release(joystick_dir: Vector2, facing_dir: Vector2,
		all_players: Array, kicker_pos: Vector2,
		kicker_team_id: int, kicker_index: int = -1) -> Dictionary:
	if state != State.CHARGING:
		return {"type": "none", "velocity": Vector2.ZERO,
			"up_velocity": 0.0, "spin": 0.0}

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
		return {"type": "pass", "velocity": pass_vel,
			"up_velocity": 0.0, "spin": 0.0}

	# No target found — push in facing direction at minimum pass speed
	var dir := facing_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	return {"type": "pass", "velocity": dir * MIN_PASS_SPEED,
		"up_velocity": 0.0, "spin": 0.0}


## Compute power shot in joystick/facing direction.
## Height is directional (ysoccer model): forward input = low, sideways = medium,
## backward = high. Spin is added for angled kicks.
func _compute_shot(joystick_dir: Vector2, facing_dir: Vector2) -> Dictionary:
	var dir := joystick_dir.normalized() if joystick_dir != Vector2.ZERO \
		else facing_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var power := clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES),
		MIN_KICK_POWER, MAX_KICK_POWER)
	var speed := power * MAX_KICK_SPEED

	# Shot height scales with power. Low-power shots stay on the ground,
	# higher power produces progressively more lift. This matches the feel
	# of SWOS where tapping produces ground balls and holding produces arcs.
	# Aftertouch (pulling back on stick after kick) provides additional loft.
	var height_factor := SHOT_LIFT_MEDIUM
	var kick_spin := 0.0

	# Spin from angled kicks: angle between facing and kick direction
	if joystick_dir != Vector2.ZERO and facing_dir != Vector2.ZERO:
		var angle_diff := rad_to_deg(absf(facing_dir.angle_to(joystick_dir)))
		if angle_diff > SPIN_ANGLE_MIN and angle_diff < SPIN_ANGLE_MAX:
			var signed_angle := rad_to_deg(facing_dir.angle_to(joystick_dir))
			kick_spin = signf(signed_angle) * SPIN_STRENGTH * power

	var lift := power * height_factor

	return {"type": "shot", "velocity": dir * speed,
		"up_velocity": lift, "spin": kick_spin}
