extends Camera2D
## Camera controller — smooth ball-tracking faithful to Sensible Soccer / SWOS.
## Tracks ball ground position (shadow, not airborne sprite) with lerp interpolation.
## Delegates logic to CameraPure for testability.

var camera_logic: CameraPure

## Ball node reference — set by match.gd.
var ball: Node2D = null


func _ready() -> void:
	camera_logic = CameraPure.new()
	camera_logic.setup(
		PitchGeometry.WORLD_W,
		PitchGeometry.WORLD_H,
		PitchGeometry.VIEWPORT_W,
		PitchGeometry.VIEWPORT_H,
	)

	# Disable Godot's built-in smoothing — we handle it manually
	position_smoothing_enabled = false

	# Set camera limits to world bounds
	limit_left = 0
	limit_top = 0
	limit_right = int(PitchGeometry.WORLD_W)
	limit_bottom = int(PitchGeometry.WORLD_H)

	# Start centered
	camera_logic.center_on_pitch()
	global_position = camera_logic.position


func _physics_process(_delta: float) -> void:
	if ball == null:
		return

	# Track ball's ground position (global_position ignores visual sprite offset)
	var new_pos := camera_logic.tick(ball.global_position)
	global_position = new_pos


## Instantly snap camera to a position (kickoff, half-time).
func snap_to_position(pos: Vector2) -> void:
	camera_logic.snap_to(pos)
	global_position = camera_logic.position


## Center camera on the pitch (kickoff, half-time reset).
func center_on_pitch() -> void:
	camera_logic.center_on_pitch()
	global_position = camera_logic.position
