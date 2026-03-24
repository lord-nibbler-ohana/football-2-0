class_name PlayerAnimationPure
## Pure logic for player animation — no Node dependencies.
## Determines animation name and flip state from velocity and action state.

enum State {
	IDLE,
	RUNNING,
	KICKING,
	SLIDING,
	CELEBRATING,
	KNOCKED_DOWN,
	GETTING_UP,
}

## 8-way direction names (5 unique + 3 mirrored).
enum Direction { S, SE, E, NE, N, NW, W, SW }

const DIRECTION_NAMES := ["s", "se", "e", "ne", "n"]

## Minimum speed to be considered running (px/frame at 50Hz).
const RUN_THRESHOLD := 0.5

## How many physics frames a one-shot animation lasts.
const KICK_DURATION := 6
const SLIDE_DURATION := 12
const CELEBRATE_DURATION := 50
const KNOCKDOWN_DURATION := 25
const GETUP_DURATION := 10

var state: State = State.IDLE
var direction: Direction = Direction.S
var _oneshot_timer: int = 0


## Update animation state based on velocity and return the result.
## velocity: current player movement vector.
## Returns: { "animation": String, "flip_h": bool }
func update(vel: Vector2) -> Dictionary:
	# Tick one-shot timer
	if _oneshot_timer > 0:
		_oneshot_timer -= 1
		if _oneshot_timer <= 0:
			if state == State.KNOCKED_DOWN:
				trigger_getup()
			else:
				state = State.IDLE

	# Update direction from velocity (only when moving)
	if vel.length() > RUN_THRESHOLD:
		direction = _velocity_to_direction(vel)
		if state == State.IDLE:
			state = State.RUNNING
	elif state == State.RUNNING:
		state = State.IDLE

	return get_animation_result()


## Get the current animation name and flip state.
func get_animation_result() -> Dictionary:
	var anim_name: String
	var flip_h: bool = false
	var dir_name: String
	var dir_flip: bool

	# Resolve direction to base name + flip
	var resolved := _resolve_direction(direction)
	dir_name = resolved["name"]
	dir_flip = resolved["flip"]

	match state:
		State.IDLE:
			anim_name = "idle_" + dir_name
			flip_h = dir_flip
		State.RUNNING:
			anim_name = "run_" + dir_name
			flip_h = dir_flip
		State.KICKING:
			anim_name = "kick_" + dir_name
			flip_h = dir_flip
		State.SLIDING:
			anim_name = "slide_" + dir_name
			flip_h = dir_flip
		State.CELEBRATING:
			anim_name = "celebrate"
			flip_h = false
		State.KNOCKED_DOWN:
			anim_name = "knocked_down"
			flip_h = false
		State.GETTING_UP:
			anim_name = "getting_up"
			flip_h = false

	return { "animation": anim_name, "flip_h": flip_h }


## Trigger a kick animation (one-shot).
func trigger_kick() -> void:
	state = State.KICKING
	_oneshot_timer = KICK_DURATION


## Trigger a slide tackle animation (one-shot).
func trigger_slide() -> void:
	state = State.SLIDING
	_oneshot_timer = SLIDE_DURATION


## Trigger celebration (one-shot).
func trigger_celebrate() -> void:
	state = State.CELEBRATING
	_oneshot_timer = CELEBRATE_DURATION


## Trigger knocked down (one-shot, transitions to getting up).
func trigger_knockdown() -> void:
	state = State.KNOCKED_DOWN
	_oneshot_timer = KNOCKDOWN_DURATION


## Transition from knocked down to getting up.
func trigger_getup() -> void:
	state = State.GETTING_UP
	_oneshot_timer = GETUP_DURATION


## Is the player in a one-shot animation that blocks other actions?
func is_locked() -> bool:
	return state in [State.KICKING, State.SLIDING, State.KNOCKED_DOWN, State.GETTING_UP]


## Convert a velocity vector to an 8-way Direction enum.
static func _velocity_to_direction(vel: Vector2) -> Direction:
	# Godot angles: 0=right, PI/2=down, -PI/2=up
	var angle := vel.angle()
	# Snap to 8 directions (PI/4 = 45 degrees)
	var snapped_angle: float = snapped(angle, PI / 4.0)
	# Map angle to direction index
	# 0=E, PI/4=SE, PI/2=S, 3PI/4=SW, PI=W, -3PI/4=NW, -PI/2=N, -PI/4=NE
	var index := int(round(snapped_angle / (PI / 4.0)))
	# Normalize to 0-7 range
	index = ((index % 8) + 8) % 8
	# Map: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	var mapping: Array[Direction] = [
		Direction.E, Direction.SE, Direction.S, Direction.SW,
		Direction.W, Direction.NW, Direction.N, Direction.NE
	]
	return mapping[index]


## Resolve a Direction to a base direction name and flip flag.
## SW/W/NW are mirrors of SE/E/NE.
static func _resolve_direction(dir: Direction) -> Dictionary:
	match dir:
		Direction.S:
			return { "name": "s", "flip": false }
		Direction.SE:
			return { "name": "se", "flip": false }
		Direction.E:
			return { "name": "e", "flip": false }
		Direction.NE:
			return { "name": "ne", "flip": false }
		Direction.N:
			return { "name": "n", "flip": false }
		Direction.SW:
			return { "name": "se", "flip": true }
		Direction.W:
			return { "name": "e", "flip": true }
		Direction.NW:
			return { "name": "ne", "flip": true }
	return { "name": "s", "flip": false }
