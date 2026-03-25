class_name CameraPure
extends RefCounted
## Pure camera logic — smooth ball-tracking with lerp, speed clamping, and boundary clamping.
## No Node/scene tree dependencies for testability.

## Tuning parameters (estimated from SWOS gameplay observation).
const SMOOTH_FACTOR := 0.08  ## Per-frame lerp weight. ~63% convergence in 12 frames (0.24s)
const MAX_SCROLL_SPEED := 6.0  ## Max px/frame camera can move. Prevents violent snaps on long balls
const SNAP_THRESHOLD := 2.0  ## Below this distance, snap to target to prevent sub-pixel jitter

var position := Vector2.ZERO
var target := Vector2.ZERO

## World boundaries for clamping (set from outside based on pitch dimensions).
var world_width := 0.0
var world_height := 0.0
var viewport_width := 0.0
var viewport_height := 0.0


## Configure the camera bounds. Must be called before use.
func setup(p_world_w: float, p_world_h: float, p_vp_w: float, p_vp_h: float) -> void:
	world_width = p_world_w
	world_height = p_world_h
	viewport_width = p_vp_w
	viewport_height = p_vp_h


## Advance one frame of camera tracking toward the given ball ground position.
## Returns the new camera position (integer-rounded for pixel-perfect rendering).
func tick(ball_ground_pos: Vector2) -> Vector2:
	target = ball_ground_pos

	var displacement := target - position
	var dist := displacement.length()

	if dist < SNAP_THRESHOLD:
		position = target
	else:
		var move := displacement * SMOOTH_FACTOR
		if move.length() > MAX_SCROLL_SPEED:
			move = move.normalized() * MAX_SCROLL_SPEED
		position += move

	_clamp_to_bounds()

	# Round to integer for pixel-perfect rendering
	return Vector2(roundf(position.x), roundf(position.y))


## Instantly move the camera to a position (for kickoff, half-time reset).
func snap_to(pos: Vector2) -> void:
	position = pos
	target = pos
	_clamp_to_bounds()


## Snap the camera to the center of the world.
func center_on_pitch() -> void:
	snap_to(Vector2(world_width / 2.0, world_height / 2.0))


## Clamp camera position so the viewport never shows area beyond world edges.
func _clamp_to_bounds() -> void:
	if world_width <= 0.0 or viewport_width <= 0.0:
		return
	var half_vp := Vector2(viewport_width / 2.0, viewport_height / 2.0)
	position.x = clampf(position.x, half_vp.x, world_width - half_vp.x)
	position.y = clampf(position.y, half_vp.y, world_height - half_vp.y)
