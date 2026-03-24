class_name AftertouchPure
extends RefCounted
## Pure aftertouch logic — no Node/scene tree dependencies.
## After any kick, joystick input curls, lofts, or dips the ball for a limited window.

const DECAY_RATE := 0.85
const OPEN_PLAY_WINDOW := 12
const SET_PIECE_WINDOW := 18
const CURL_FACTOR := 0.15
const LOFT_FACTOR := 0.3
const DIP_FACTOR := 0.25

var timer: int = 0
var window: int = 0
var active: bool = false
var kick_direction: Vector2 = Vector2.ZERO


## Activate aftertouch after a kick.
## kick_dir: the ground velocity direction of the kick (will be normalized).
## is_set_piece: true for corners, free kicks, goal kicks.
func activate(kick_dir: Vector2, is_set_piece: bool = false) -> void:
	if kick_dir.length() < 0.001:
		return
	kick_direction = kick_dir.normalized()
	window = SET_PIECE_WINDOW if is_set_piece else OPEN_PLAY_WINDOW
	timer = window
	active = true


## Process one frame of aftertouch.
## joystick_input: 8-way quantised Vector2 from the kicking player.
## Returns Dictionary with "velocity_offset" (Vector2) and "vertical_offset" (float).
func tick(joystick_input: Vector2) -> Dictionary:
	if not active or timer <= 0:
		return {"velocity_offset": Vector2.ZERO, "vertical_offset": 0.0}

	timer -= 1
	if timer <= 0:
		active = false

	if joystick_input == Vector2.ZERO:
		return {"velocity_offset": Vector2.ZERO, "vertical_offset": 0.0}

	# Decay: strength is strongest at frame 0, decays each elapsed frame
	var frames_elapsed := window - timer - 1
	var strength := pow(DECAY_RATE, float(frames_elapsed))

	# Decompose input relative to frozen kick direction
	var perpendicular := Vector2(-kick_direction.y, kick_direction.x)

	var parallel_component := joystick_input.dot(kick_direction)
	var perp_component := joystick_input.dot(perpendicular)

	# Lateral curl from perpendicular input
	var velocity_offset := perpendicular * perp_component * CURL_FACTOR * strength

	# Vertical effects from parallel component
	var vertical_offset := 0.0
	if parallel_component < 0.0:
		# Opposite to travel direction = loft
		vertical_offset = absf(parallel_component) * LOFT_FACTOR * strength
	elif parallel_component > 0.0:
		# Same as travel direction = dip
		vertical_offset = -parallel_component * DIP_FACTOR * strength

	return {"velocity_offset": velocity_offset, "vertical_offset": vertical_offset}


## Cancel aftertouch immediately.
func cancel() -> void:
	active = false
	timer = 0


## True if aftertouch is currently active.
func is_active() -> bool:
	return active


## Reset all state.
func reset() -> void:
	timer = 0
	window = 0
	active = false
	kick_direction = Vector2.ZERO
