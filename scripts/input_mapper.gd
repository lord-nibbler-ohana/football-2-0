class_name InputMapper
extends RefCounted
## Reads Godot input actions and returns quantised 8-way vectors.


## Get the current movement direction as a quantised 8-way vector.
static func get_movement_input() -> Vector2:
	var raw := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	return InputQuantiserPure.quantise(raw)


## True on the frame the kick button is first pressed.
static func is_kick_just_pressed() -> bool:
	return Input.is_action_just_pressed("action_kick")


## True while the kick button is held down.
static func is_kick_held() -> bool:
	return Input.is_action_pressed("action_kick")


## True on the frame the kick button is released.
static func is_kick_just_released() -> bool:
	return Input.is_action_just_released("action_kick")
