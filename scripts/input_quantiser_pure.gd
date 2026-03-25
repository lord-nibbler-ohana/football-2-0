class_name InputQuantiserPure
extends RefCounted
## Pure 8-way input quantisation — no Node dependencies.
## Snaps any analog input vector to one of 8 cardinal/diagonal directions.

const DEADZONE := 0.2

## 8 unit vectors for the quantised directions.
const DIRECTIONS: Array[Vector2] = [
	Vector2.RIGHT,                              # E   (0°)
	Vector2(0.707107, 0.707107),                # SE  (45°)
	Vector2.DOWN,                               # S   (90°)
	Vector2(-0.707107, 0.707107),               # SW  (135°)
	Vector2.LEFT,                               # W   (180°)
	Vector2(-0.707107, -0.707107),              # NW  (225°)
	Vector2.UP,                                 # N   (270°)
	Vector2(0.707107, -0.707107),               # NE  (315°)
]


## Quantise a raw input vector to 8-way digital.
## Returns a unit vector in one of 8 directions, or Vector2.ZERO if below deadzone.
static func quantise(raw: Vector2) -> Vector2:
	if raw.length() < DEADZONE:
		return Vector2.ZERO

	var angle := raw.angle()
	# Snap to nearest 45 degrees (PI/4)
	var snapped_angle := snappedf(angle, PI / 4.0)
	# Convert to index (0-7): 0=E, 1=SE, 2=S, 3=SW, 4=W, ...
	var index := int(round(snapped_angle / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return DIRECTIONS[index]
