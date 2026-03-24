extends CharacterBody2D
## Ball node — delegates physics to BallPhysicsPure, handles visuals and collision.

var physics: BallPhysicsPure
var aftertouch: AftertouchPure
var last_kicker: Node = null

@onready var ball_sprite: Sprite2D = $BallSprite
@onready var shadow_sprite: Sprite2D = $ShadowSprite


func _ready() -> void:
	physics = BallPhysicsPure.new()
	aftertouch = AftertouchPure.new()


func _physics_process(_delta: float) -> void:
	# Apply aftertouch before physics tick (modifies physics state)
	if aftertouch.is_active():
		var input := _get_kicker_input()
		var result := aftertouch.tick(input)
		physics.velocity += result["velocity_offset"]
		physics.vertical_velocity += result["vertical_offset"]
		# Clamp: dip should not push ball underground
		if physics.height > 0.0:
			physics.vertical_velocity = maxf(
				physics.vertical_velocity, -physics.height)
		else:
			physics.vertical_velocity = maxf(physics.vertical_velocity, 0.0)

	var displacement := physics.tick()

	# CharacterBody2D.velocity is px/sec; displacement is px/frame at 50 Hz
	velocity = displacement * 50.0
	move_and_slide()

	# Update visuals
	ball_sprite.position.y = physics.get_sprite_offset_y()
	shadow_sprite.modulate.a = physics.get_shadow_opacity()
	queue_redraw()


func _draw() -> void:
	# Debug visuals until real sprites are added
	var shadow_alpha := physics.get_shadow_opacity() if physics else 1.0
	draw_circle(Vector2.ZERO, 4, Color(0, 0, 0, shadow_alpha * 0.5))
	var offset_y := physics.get_sprite_offset_y() if physics else 0.0
	draw_circle(Vector2(0, offset_y), 4, Color.WHITE)


## Kick the ball with a ground velocity and optional upward velocity.
## kicker: the player node that kicked (for aftertouch input tracking).
## is_set_piece: true for corners, free kicks, goal kicks (extended aftertouch window).
func kick(ground_vel: Vector2, up_vel: float = 0.0,
		kicker: Node = null, is_set_piece: bool = false) -> void:
	physics.apply_kick(ground_vel, up_vel)
	last_kicker = kicker
	if ground_vel.length() > 0.0:
		aftertouch.activate(ground_vel, is_set_piece)
	else:
		aftertouch.cancel()


## Get the kicking player's current joystick input.
## Returns Vector2.ZERO until the input system is implemented.
func _get_kicker_input() -> Vector2:
	if last_kicker and last_kicker.has_method("get_joystick_input"):
		return last_kicker.get_joystick_input()
	return Vector2.ZERO


## Reset ball state (e.g., for kickoff).
func reset_ball() -> void:
	physics.reset()
	aftertouch.reset()
	last_kicker = null
