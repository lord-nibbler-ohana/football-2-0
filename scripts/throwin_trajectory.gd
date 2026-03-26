extends Node2D
## Draws a dotted arc trajectory preview for throw-ins.
## Shows dots along the throw path with shadow dots on the ground below.

var points: Array = []  ## Array of {"position": Vector2, "height": float}
var visible_dots: bool = false

const DOT_RADIUS := 1.5
const SHADOW_RADIUS := 1.0
const DOT_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)


func _draw() -> void:
	if not visible_dots or points.is_empty():
		return

	for i in range(points.size()):
		var pt: Dictionary = points[i]
		var ground_pos: Vector2 = pt["position"] - global_position
		var height: float = pt["height"]

		# Fade out dots toward the end
		var alpha := 1.0 - float(i) / float(points.size()) * 0.5

		# Shadow dot on the ground
		draw_circle(ground_pos, SHADOW_RADIUS,
			Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * alpha))

		# Ball dot elevated by height
		var ball_pos := Vector2(ground_pos.x, ground_pos.y - height)
		draw_circle(ball_pos, DOT_RADIUS,
			Color(DOT_COLOR.r, DOT_COLOR.g, DOT_COLOR.b, DOT_COLOR.a * alpha))


## Update the trajectory points and redraw.
func update_trajectory(new_points: Array) -> void:
	points = new_points
	visible_dots = not new_points.is_empty()
	queue_redraw()


## Hide the trajectory.
func hide_trajectory() -> void:
	points = []
	visible_dots = false
	queue_redraw()
