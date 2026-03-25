class_name BallPhysicsPure
extends RefCounted
## Pure ball physics logic — no Node/scene tree dependencies.
## Simulates 3D ball movement on a 2D pitch with height as a separate axis.
## Physics model based on ysoccer analysis: square-root ground friction,
## air friction on vertical velocity, spin-based curl, realistic bounce.

## Ground friction: square-root damping (ysoccer model).
## Fast balls lose less speed proportionally than slow balls.
const GROUND_FRICTION_K := 0.08

## Air friction: multiplicative, applied to both horizontal and vertical velocity.
const AIR_FRICTION := 0.994

## Gravity: tuned so medium kicks stay airborne ~0.7s.
const GRAVITY := 0.07

## Bounce: energy retained on ground impact (ysoccer: 0.9 * 0.65 grass = 0.585).
const BOUNCE_DAMPING := 0.585

## Horizontal speed loss on bounce: v *= (1 + vv / BOUNCE_H_LOSS).
## vv is negative at impact, so this reduces ground speed proportionally to impact force.
const BOUNCE_H_LOSS := 30.0

## Height-to-sprite-offset ratio (1:1 matching ysoccer rendering).
const PERSPECTIVE_SCALE := 1.0

## Minimum velocity before snapping to zero.
const MIN_VELOCITY := 0.05

## Minimum vertical velocity to trigger a bounce (below this, ball settles).
const MIN_BOUNCE_VELOCITY := 0.15

## Spin: continuous angular deflection of velocity (ysoccer curl model).
const SPIN_RATE := 0.24  ## Degrees rotation per spin unit per frame
const SPIN_DAMPEN := 0.87  ## Spin decay per frame
const SPIN_MIN := 0.01  ## Snap-to-zero threshold for spin

var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_velocity: float = 0.0
var spin: float = 0.0


## Advance physics by one frame (called at 50 Hz).
## Returns the pitch-plane displacement vector for this frame.
func tick() -> Vector2:
	# Apply gravity when airborne
	if height > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= GRAVITY
		vertical_velocity *= AIR_FRICTION  # Air resistance on vertical too
		height += vertical_velocity

		# Bounce check
		if height <= 0.0:
			height = 0.0
			if absf(vertical_velocity) > MIN_BOUNCE_VELOCITY:
				# Horizontal speed loss on impact (harder impact = more loss)
				velocity *= (1.0 + vertical_velocity / BOUNCE_H_LOSS)
				vertical_velocity = -vertical_velocity * BOUNCE_DAMPING
			else:
				vertical_velocity = 0.0

	# Apply spin curl (rotate velocity direction)
	if spin != 0.0 and velocity.length() > MIN_VELOCITY:
		velocity = velocity.rotated(deg_to_rad(spin * SPIN_RATE))
		spin *= SPIN_DAMPEN
		if absf(spin) < SPIN_MIN:
			spin = 0.0

	# Apply friction
	if is_airborne():
		velocity *= AIR_FRICTION
	else:
		# Square-root ground friction: deceleration proportional to sqrt(speed)
		var speed := velocity.length()
		if speed > 0.0:
			var decel := GROUND_FRICTION_K * sqrt(speed)
			var new_speed := maxf(speed - decel, 0.0)
			velocity = velocity.normalized() * new_speed

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


## Apply spin to the ball (e.g., from a kick or aftertouch).
func apply_spin(amount: float) -> void:
	spin += amount


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
	spin = 0.0
