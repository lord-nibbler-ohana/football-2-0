class_name AftertouchPure
extends RefCounted
## Pure aftertouch logic — no Node/scene tree dependencies.
## After any kick, joystick input controls loft/dip and adds spin for curl.
## Curl is handled via spin (continuous angular deflection in BallPhysicsPure),
## not direct velocity offset — this produces visible, gradual curves.

const DECAY_RATE := 0.88
const OPEN_PLAY_WINDOW := 16
const SET_PIECE_WINDOW := 24
const LOFT_FACTOR := 0.08
const DIP_FACTOR := 0.06
const SPIN_AFTERTOUCH_FACTOR := 2.0

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
## Returns Dictionary with "spin_offset" (float) and "vertical_offset" (float).
func tick(joystick_input: Vector2) -> Dictionary:
	if not active or timer <= 0:
		return {"spin_offset": 0.0, "vertical_offset": 0.0}

	timer -= 1
	if timer <= 0:
		active = false

	if joystick_input == Vector2.ZERO:
		return {"spin_offset": 0.0, "vertical_offset": 0.0}

	# Decay: strength is strongest at frame 0, decays each elapsed frame
	var frames_elapsed := window - timer - 1
	var strength := pow(DECAY_RATE, float(frames_elapsed))

	# Decompose input relative to frozen kick direction
	var perpendicular := Vector2(-kick_direction.y, kick_direction.x)

	var parallel_component := joystick_input.dot(kick_direction)
	var perp_component := joystick_input.dot(perpendicular)

	# Spin from perpendicular input (curl via spin system)
	var spin_offset := perp_component * SPIN_AFTERTOUCH_FACTOR * strength

	# Vertical effects from parallel component
	var vertical_offset := 0.0
	if parallel_component < 0.0:
		# Opposite to travel direction = loft
		vertical_offset = absf(parallel_component) * LOFT_FACTOR * strength
	elif parallel_component > 0.0:
		# Same as travel direction = dip
		vertical_offset = -parallel_component * DIP_FACTOR * strength

	return {"spin_offset": spin_offset, "vertical_offset": vertical_offset}


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
