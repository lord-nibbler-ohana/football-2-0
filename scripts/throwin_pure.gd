class_name ThrowinPure
extends RefCounted
## Pure throw-in logic — manages the throw-in sequence from setup to release.
## No Node/scene tree dependencies.

enum Phase {
	WALKING,     ## Thrower walking to the sideline spot
	AIMING,      ## At the line, aiming with joystick (waiting for button press)
	CHARGING,    ## Button held — increasing throw power
	THROWING,    ## Animation playing, ball released
	RETURNING,   ## Thrower returning to formation position
	DONE,        ## Sequence complete
}

## Walk speed (px/frame at 50 Hz) — slightly slower than normal.
const WALK_SPEED := 1.5
## How close the thrower must be to the spot to start aiming.
const ARRIVE_DISTANCE := 4.0
## Minimum throw power (short toss).
const MIN_THROW_SPEED := 1.5
## Maximum throw power (long throw — kept short, it's a throw-in not a goal kick).
const MAX_THROW_SPEED := 3.5
## Charge rate: frames to reach max power.
const MAX_CHARGE_FRAMES := 30
## Up velocity at max power (arc height).
const MAX_UP_VELOCITY := 1.0
## Minimum up velocity for a short throw.
const MIN_UP_VELOCITY := 0.3
## Throw animation duration in frames.
const THROW_ANIM_FRAMES := 9
## Frames before thrower starts returning to position.
const POST_THROW_DELAY := 10
## Return speed (px/frame at 50 Hz).
const RETURN_SPEED := 2.0
## Distance threshold for "arrived at formation".
const RETURN_ARRIVE_DISTANCE := 8.0
## Default aim direction if joystick is neutral.
const DEFAULT_INFIELD_LEFT := Vector2(1.0, 0.0)
const DEFAULT_INFIELD_RIGHT := Vector2(-1.0, 0.0)
## Number of dots in trajectory preview.
const TRAJECTORY_DOTS := 12
## Angular rotation speed (radians/frame) for aim steering.
const AIM_ROTATE_SPEED := 0.04

var phase: Phase = Phase.WALKING
var charge_frames: int = 0
var throw_timer: int = 0
var post_throw_timer: int = 0
var aim_direction: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0  ## Current aim angle in radians
var throwin_side: String = ""  ## "left" or "right"


## Initialize for a new throw-in.
func setup(side: String) -> void:
	phase = Phase.WALKING
	charge_frames = 0
	throw_timer = 0
	post_throw_timer = 0
	throwin_side = side
	# Aim angle: 0 = straight infield. Range: -PI/2 to PI/2 (up to down).
	aim_angle = 0.0
	_sync_aim_from_angle()


## Get the default facing direction (infield, away from sideline).
func get_default_aim() -> Vector2:
	return DEFAULT_INFIELD_LEFT if throwin_side == "left" else DEFAULT_INFIELD_RIGHT


## Sync aim_direction vector from the current aim_angle.
func _sync_aim_from_angle() -> void:
	# Base infield direction is (1,0) for left side, (-1,0) for right side.
	# Rotate by aim_angle: positive = downfield, negative = upfield.
	var base := DEFAULT_INFIELD_LEFT if throwin_side == "left" else DEFAULT_INFIELD_RIGHT
	aim_direction = base.rotated(aim_angle)


## Compute walk velocity toward the throw-in spot.
## Returns Vector2.ZERO when arrived.
func get_walk_velocity(player_pos: Vector2, target_pos: Vector2) -> Vector2:
	var to_target := target_pos - player_pos
	if to_target.length() < ARRIVE_DISTANCE:
		return Vector2.ZERO
	return to_target.normalized() * WALK_SPEED


## Check if thrower has arrived at the spot.
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
## Up/down on the stick rotates the aim smoothly through any angle.
## Clamped to the infield 180-degree arc (up ↔ down along the sideline).
func update_aim(joystick_dir: Vector2) -> void:
	if joystick_dir == Vector2.ZERO:
		return
	# Use the vertical component to steer: up = rotate toward upfield,
	# down = rotate toward downfield.
	var steer := joystick_dir.y * AIM_ROTATE_SPEED
	aim_angle = clampf(aim_angle + steer, -PI / 2.0, PI / 2.0)
	_sync_aim_from_angle()


## Release the throw — returns the ball velocity and up_velocity.
func release() -> Dictionary:
	if phase != Phase.CHARGING:
		return {"velocity": Vector2.ZERO, "up_velocity": 0.0}

	var power := clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES), 0.0, 1.0)
	var speed := lerpf(MIN_THROW_SPEED, MAX_THROW_SPEED, power)
	var up_vel := lerpf(MIN_UP_VELOCITY, MAX_UP_VELOCITY, power)

	phase = Phase.THROWING
	throw_timer = THROW_ANIM_FRAMES

	return {
		"velocity": aim_direction * speed,
		"up_velocity": up_vel,
	}


## Tick the throwing/post-throw phases. Returns true when DONE.
func tick_post_throw() -> bool:
	if phase == Phase.THROWING:
		throw_timer -= 1
		if throw_timer <= 0:
			phase = Phase.RETURNING
			post_throw_timer = POST_THROW_DELAY
		return false
	elif phase == Phase.RETURNING:
		return false  # match.gd handles return movement
	elif phase == Phase.DONE:
		return true
	return false


## Check if thrower has returned to formation.
func check_returned(player_pos: Vector2, formation_pos: Vector2) -> bool:
	if player_pos.distance_to(formation_pos) < RETURN_ARRIVE_DISTANCE:
		phase = Phase.DONE
		return true
	return false


## Get return velocity toward formation.
func get_return_velocity(player_pos: Vector2, formation_pos: Vector2) -> Vector2:
	var to_target := formation_pos - player_pos
	if to_target.length() < RETURN_ARRIVE_DISTANCE:
		phase = Phase.DONE
		return Vector2.ZERO
	return to_target.normalized() * RETURN_SPEED


## Get current throw power (0.0 to 1.0) for trajectory preview.
func get_charge_power() -> float:
	if phase != Phase.CHARGING:
		return 0.0
	return clampf(float(charge_frames) / float(MAX_CHARGE_FRAMES), 0.0, 1.0)


## Compute trajectory preview points for the dotted line.
## Returns an Array of Dictionaries: {"position": Vector2, "height": float}
## representing the arc of the throw from the thrower's position.
func compute_trajectory(start_pos: Vector2) -> Array:
	var power := get_charge_power()
	if power <= 0.0 and phase != Phase.AIMING:
		return []

	# Use minimum power for aiming phase preview
	var preview_power := maxf(power, 0.1)
	var speed := lerpf(MIN_THROW_SPEED, MAX_THROW_SPEED, preview_power)
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
