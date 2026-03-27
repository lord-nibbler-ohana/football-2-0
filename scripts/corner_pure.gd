class_name CornerPure
extends RefCounted
## Pure corner kick logic — manages the corner kick sequence from setup to release.
## No Node/scene tree dependencies. Modeled on ThrowinPure with stronger kick constants.

enum Phase {
	WALKING,     ## Corner taker walking to the flag
	AIMING,      ## At the flag, aiming with joystick (waiting for button press)
	CHARGING,    ## Button held — increasing kick power
	KICKING,     ## Animation playing, ball released
	DONE,        ## Sequence complete
}

## Walk speed (px/frame at 50 Hz).
const WALK_SPEED := 1.5
## How close the taker must be to the flag to start aiming.
const ARRIVE_DISTANCE := 4.0
## Minimum kick speed (short corner to nearby player).
const MIN_CORNER_SPEED := 2.5
## Maximum kick speed (hard driven corner — significantly stronger than throw-in's 3.5).
const MAX_CORNER_SPEED := 7.0
## Charge rate: frames to reach max power.
const MAX_CHARGE_FRAMES := 30
## Default charge frames — produces a corner that lands near the penalty spot.
const DEFAULT_CHARGE_FRAMES := 18
## Up velocity at max power (high arc).
const MAX_UP_VELOCITY := 2.0
## Minimum up velocity for a short/flat corner.
const MIN_UP_VELOCITY := 0.3
## Kick animation duration in frames.
const KICK_ANIM_FRAMES := 9
## Number of dots in trajectory preview.
const TRAJECTORY_DOTS := 12
## Angular rotation speed (radians/frame) for aim steering.
const AIM_ROTATE_SPEED := 0.04

var phase: Phase = Phase.WALKING
var charge_frames: int = 0
var kick_timer: int = 0
var aim_direction: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0  ## Current aim offset from default direction
var default_aim: Vector2 = Vector2.ZERO  ## Points from corner toward penalty area
var corner_side: String = ""  ## "top" or "bottom" (which goal line)
var facing_toward_line: Vector2 = Vector2.ZERO  ## Direction to face while at the corner flag


## Initialize for a new corner kick.
func setup(corner_pos: Vector2, side: String) -> void:
	phase = Phase.WALKING
	charge_frames = 0
	kick_timer = 0
	corner_side = side

	# Compute default aim toward penalty spot
	var penalty_spot: Vector2
	if side == "top":
		penalty_spot = PitchGeometry.PENALTY_SPOT_TOP
	else:
		penalty_spot = PitchGeometry.PENALTY_SPOT_BOTTOM

	default_aim = (penalty_spot - corner_pos).normalized()
	aim_angle = 0.0
	aim_direction = default_aim

	# Face toward the nearest goal line while standing at the flag.
	# At top corners face down (toward pitch), at bottom corners face up.
	if side == "top":
		facing_toward_line = Vector2.DOWN
	else:
		facing_toward_line = Vector2.UP


## Get the default facing direction (toward penalty area).
func get_default_aim() -> Vector2:
	return default_aim


## Sync aim_direction vector from the current aim_angle offset.
func _sync_aim_from_angle() -> void:
	aim_direction = default_aim.rotated(aim_angle)


## Compute walk velocity toward the corner flag.
## Returns Vector2.ZERO when arrived.
func get_walk_velocity(player_pos: Vector2, target_pos: Vector2) -> Vector2:
	var to_target := target_pos - player_pos
	if to_target.length() < ARRIVE_DISTANCE:
		return Vector2.ZERO
	return to_target.normalized() * WALK_SPEED


## Check if corner taker has arrived at the flag.
func check_arrived(player_pos: Vector2, target_pos: Vector2) -> bool:
	return player_pos.distance_to(target_pos) < ARRIVE_DISTANCE


## Start charging (button pressed).
func start_charge() -> void:
	if phase == Phase.AIMING:
		phase = Phase.CHARGING
		charge_frames = 0


## Tick charge (button held).
func tick_charge() -> void:
	if phase == Phase.CHARGING:
		charge_frames = mini(charge_frames + 1, MAX_CHARGE_FRAMES)


## Update aim direction from joystick input via angular rotation.
## Stick input rotates the aim around the default direction.
## Clamped to +/- 90 degrees from the default aim.
func update_aim(joystick_dir: Vector2) -> void:
	if joystick_dir == Vector2.ZERO:
		return
	# Use perpendicular component relative to default aim for steering.
	# Project joystick onto the perpendicular axis of the default aim.
	var perp := Vector2(-default_aim.y, default_aim.x)
	var steer := joystick_dir.dot(perp) * AIM_ROTATE_SPEED
	aim_angle = clampf(aim_angle + steer, -PI / 2.0, PI / 2.0)
	_sync_aim_from_angle()


## Release the kick — returns the ball velocity and up_velocity.
func release() -> Dictionary:
	if phase != Phase.CHARGING:
		return {"velocity": Vector2.ZERO, "up_velocity": 0.0}

	var power := clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES), 0.0, 1.0)
	var speed := lerpf(MIN_CORNER_SPEED, MAX_CORNER_SPEED, power)
	var up_vel := lerpf(MIN_UP_VELOCITY, MAX_UP_VELOCITY, power)

	phase = Phase.KICKING
	kick_timer = KICK_ANIM_FRAMES

	return {
		"velocity": aim_direction * speed,
		"up_velocity": up_vel,
	}


## Tick the kicking phase. Returns true when DONE.
func tick_post_kick() -> bool:
	if phase == Phase.KICKING:
		kick_timer -= 1
		if kick_timer <= 0:
			phase = Phase.DONE
		return false
	elif phase == Phase.DONE:
		return true
	return false


## Get current kick power (0.0 to 1.0) for trajectory preview.
func get_charge_power() -> float:
	if phase != Phase.CHARGING:
		return 0.0
	return clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES), 0.0, 1.0)


## Compute trajectory preview points for the dotted line.
## Returns an Array of Dictionaries: {"position": Vector2, "height": float}.
func compute_trajectory(start_pos: Vector2) -> Array:
	var power := get_charge_power()
	if power <= 0.0 and phase != Phase.AIMING:
		return []

	# Use minimum power for aiming phase preview
	var preview_power := maxf(power, 0.1)
	var speed := lerpf(MIN_CORNER_SPEED, MAX_CORNER_SPEED, preview_power)
	var up_vel := lerpf(MIN_UP_VELOCITY, MAX_UP_VELOCITY, preview_power)

	var vel := aim_direction * speed
	var height := 0.0
	var vv := up_vel
	var pos := start_pos
	var points: Array = []

	for i in range(TRAJECTORY_DOTS):
		# Simulate 3 frames per dot for spacing
		for _f in range(3):
			pos += vel
			vel *= BallPhysicsPure.AIR_FRICTION
			vv -= BallPhysicsPure.GRAVITY
			vv *= BallPhysicsPure.AIR_FRICTION
			height += vv
			if height < 0.0:
				height = 0.0
				vv = 0.0
			# Apply ground friction when on ground
			if height <= 0.0:
				var spd := vel.length()
				if spd > 0.0:
					var decel := BallPhysicsPure.GROUND_FRICTION_K * sqrt(spd)
					vel = vel.normalized() * maxf(spd - decel, 0.0)

		points.append({"position": pos, "height": height})

	return points
