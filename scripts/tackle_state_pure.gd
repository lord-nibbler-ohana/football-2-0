class_name TackleStatePure
extends RefCounted
## Pure slide tackle state machine — IDLE → SLIDING → RECOVERING.
## Direction-locked slide with speed boost, deceleration, and deflection input.
## Faithful to SWOS: committed action, aftertouch deflection, foul determination.

enum State { IDLE, SLIDING, RECOVERING }

## Slide parameters (tuned for 50 Hz tick rate).
const SLIDE_DURATION := 12  ## frames (0.24s) — must match PlayerAnimationPure.SLIDE_DURATION
const SLIDE_SPEED := 3.5  ## px/frame — faster than PLAYER_SPEED (2.0)
const SLIDE_DECELERATION := 0.92  ## Speed multiplier per frame
const RECOVERY_DURATION := 10  ## frames (0.2s) — brief pause after slide
const TACKLE_COOLDOWN := 50  ## frames (1.0s) — prevents spam

## Hit detection radius during slide.
const TACKLE_HIT_RADIUS := 14.0  ## px — contact zone for ball and opponents

## Ball knock speed on clean tackle (slide tackle).
const TACKLE_KNOCK_SPEED := 5.0  ## px/frame (was 3.0 — stronger to clear contested zone)

## Foul determination.
const FOUL_BEHIND_THRESHOLD := 0.3  ## Dot product: slide_dir · carrier_facing > this = "from behind"
const FOUL_BASE_CHANCE := 0.15  ## Base foul probability on player contact
const FOUL_BEHIND_CHANCE := 0.75  ## Foul probability when tackling from behind
const FOUL_DISTANCE_FACTOR := 0.003  ## Per-px increase from long-distance slide
const FOUL_CARD_THRESHOLD := 0.5  ## Above this foul_chance → yellow card

## Knockdown duration for fouled player (must match PlayerAnimationPure.KNOCKDOWN_DURATION + GETUP_DURATION).
const VICTIM_KNOCKDOWN_FRAMES := 150  ## frames (3.0s)

var state: State = State.IDLE
var slide_direction: Vector2 = Vector2.ZERO
var slide_speed: float = 0.0
var timer: int = 0
var cooldown: int = 0
var deflect_direction: Vector2 = Vector2.ZERO  ## Aftertouch: joystick during slide
var slide_start_position: Vector2 = Vector2.ZERO  ## For distance-based foul calc


## True if a new slide tackle can be initiated.
func can_tackle() -> bool:
	return state == State.IDLE and cooldown <= 0


## Begin a slide in the given direction from the given position.
func start_slide(direction: Vector2, start_pos: Vector2) -> void:
	if not can_tackle():
		return
	state = State.SLIDING
	slide_direction = direction.normalized() if direction.length() > 0.01 else Vector2.DOWN
	slide_speed = SLIDE_SPEED
	timer = SLIDE_DURATION
	deflect_direction = Vector2.ZERO
	slide_start_position = start_pos


## Advance one frame. joystick_dir captures deflection input during slide.
## Returns {"velocity": Vector2} — the movement to apply this frame.
func tick(joystick_dir: Vector2 = Vector2.ZERO) -> Dictionary:
	if cooldown > 0:
		cooldown -= 1

	match state:
		State.SLIDING:
			timer -= 1
			slide_speed *= SLIDE_DECELERATION
			if joystick_dir != Vector2.ZERO:
				deflect_direction = joystick_dir.normalized()
			if timer <= 0:
				_enter_recovery()
			return {"velocity": slide_direction * slide_speed}
		State.RECOVERING:
			timer -= 1
			if timer <= 0:
				state = State.IDLE
				cooldown = TACKLE_COOLDOWN
			return {"velocity": Vector2.ZERO}
		_:
			return {"velocity": Vector2.ZERO}


## True if in any non-idle state (blocks normal input).
func is_active() -> bool:
	return state != State.IDLE


## True if currently in the slide phase (hit detection active).
func is_sliding() -> bool:
	return state == State.SLIDING


## Direction to knock the ball on a clean tackle.
## Uses deflection input if set, otherwise slide direction.
func get_knock_direction() -> Vector2:
	if deflect_direction != Vector2.ZERO:
		return deflect_direction
	return slide_direction


## Compute foul probability from approach angle and slide distance.
## slide_dir: direction of the slide (normalized).
## carrier_facing: direction the ball carrier is facing (normalized).
## slide_distance: px traveled from slide start to contact point.
static func compute_foul_chance(slide_dir: Vector2, carrier_facing: Vector2,
		slide_distance: float) -> float:
	# "From behind": tackler sliding in same direction as carrier is facing
	var behind_dot := slide_dir.dot(carrier_facing.normalized())

	var chance := FOUL_BASE_CHANCE

	if behind_dot > FOUL_BEHIND_THRESHOLD:
		# Sliding in roughly the same direction carrier faces = from behind
		chance = lerpf(FOUL_BASE_CHANCE, FOUL_BEHIND_CHANCE,
			clampf((behind_dot - FOUL_BEHIND_THRESHOLD) / (1.0 - FOUL_BEHIND_THRESHOLD), 0.0, 1.0))

	# Longer slides are riskier
	chance += slide_distance * FOUL_DISTANCE_FACTOR

	return clampf(chance, 0.0, 0.95)


## Whether a foul this severe warrants a yellow card.
static func should_show_card(foul_chance: float) -> bool:
	return foul_chance > FOUL_CARD_THRESHOLD


## Force transition to recovery (e.g., on foul resolution).
func force_recovery() -> void:
	_enter_recovery()


## Reset all state.
func reset() -> void:
	state = State.IDLE
	slide_direction = Vector2.ZERO
	slide_speed = 0.0
	timer = 0
	cooldown = 0
	deflect_direction = Vector2.ZERO
	slide_start_position = Vector2.ZERO


func _enter_recovery() -> void:
	state = State.RECOVERING
	timer = RECOVERY_DURATION
