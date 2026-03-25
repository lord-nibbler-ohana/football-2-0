class_name BallPhysicsPure
extends RefCounted
## Pure ball physics logic — no Node/scene tree dependencies.
## Simulates 3D ball movement on a 2D pitch with height as a separate axis.

const GROUND_FRICTION := 0.98
const AIR_FRICTION := 0.99
const GRAVITY := 0.4
const BOUNCE_DAMPING := 0.5
const PERSPECTIVE_SCALE := 2.0
const MIN_VELOCITY := 0.1
const MIN_BOUNCE_VELOCITY := 0.5

var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_velocity: float = 0.0


## Advance physics by one frame (called at 50 Hz).
## Returns the pitch-plane displacement vector for this frame.
func tick() -> Vector2:
	# Apply gravity when airborne
	if height > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= GRAVITY
		height += vertical_velocity

		# Bounce check
		if height <= 0.0:
			height = 0.0
			if absf(vertical_velocity) > MIN_BOUNCE_VELOCITY:
				vertical_velocity = -vertical_velocity * BOUNCE_DAMPING
			else:
				vertical_velocity = 0.0

	# Apply friction
	if is_airborne():
		velocity *= AIR_FRICTION
	else:
		velocity *= GROUND_FRICTION

	# Snap small velocities to zero
	if velocity.length() < MIN_VELOCITY:
		velocity = Vector2.ZERO

	return velocity


## Apply an instantaneous kick to the ball.
func apply_kick(ground_vel: Vector2, up_vel: float = 0.0) -> void:
	velocity = ground_vel
	vertical_velocity = up_vel
	if up_vel > 0.0:
		height = maxf(height, 0.01)


## True if ball is above the ground.
func is_airborne() -> bool:
	return height > 0.0 or vertical_velocity > 0.0


## True if ball has effectively stopped (on ground and no velocity).
func is_stopped() -> bool:
	return not is_airborne() and velocity == Vector2.ZERO


## Get the Y-offset for the ball sprite (negative = up on screen).
func get_sprite_offset_y() -> float:
	return -height * PERSPECTIVE_SCALE


## Get shadow opacity (1.0 on ground, fading toward 0.2 at max height).
func get_shadow_opacity() -> float:
	if height <= 0.0:
		return 1.0
	return clampf(1.0 / (1.0 + height * 0.05), 0.2, 1.0)


## Ground speed magnitude (px/frame).
func get_ground_speed() -> float:
	return velocity.length()


## Reset all state.
func reset() -> void:
	velocity = Vector2.ZERO
	height = 0.0
	vertical_velocity = 0.0
