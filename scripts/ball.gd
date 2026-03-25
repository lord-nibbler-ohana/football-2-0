extends CharacterBody2D
## Ball node — delegates physics to BallPhysicsPure, handles visuals and collision.

signal post_hit

var physics: BallPhysicsPure
var aftertouch: AftertouchPure
var last_kicker: Node = null
var _rotation_accum: float = 0.0

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
		# Spin-based curl from perpendicular input
		physics.apply_spin(result["spin_offset"])
		# Vertical loft/dip
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

	# Sync reflected velocity back after collisions and apply post energy loss
	if get_slide_collision_count() > 0:
		physics.velocity = self.velocity / 50.0
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			if collision.get_collider().is_in_group("goalpost"):
				physics.velocity *= GoalDetectionPure.POST_HIT_ENERGY_FACTOR
				post_hit.emit()
				break

	# Update visuals
	ball_sprite.position.y = physics.get_sprite_offset_y()
	shadow_sprite.modulate.a = physics.get_shadow_opacity()

	# Cycle ball rotation frame based on distance traveled
	var speed := physics.velocity.length()
	if speed > 0.2:
		_rotation_accum += speed
		if _rotation_accum > 2.0:
			_rotation_accum = 0.0
			ball_sprite.frame = (ball_sprite.frame + 1) % 4


## Kick the ball with a ground velocity, optional upward velocity, and optional spin.
## kicker: the player node that kicked (for aftertouch input tracking).
## is_set_piece: true for corners, free kicks, goal kicks (extended aftertouch window).
func kick(ground_vel: Vector2, up_vel: float = 0.0,
		kicker: Node = null, is_set_piece: bool = false,
		kick_spin: float = 0.0) -> void:
	physics.apply_kick(ground_vel, up_vel)
	physics.spin = kick_spin
	last_kicker = kicker
	if ground_vel.length() > 0.0:
		aftertouch.activate(ground_vel, is_set_piece)
	else:
		aftertouch.cancel()


## Get the kicking player's current joystick input.
func _get_kicker_input() -> Vector2:
	if last_kicker and last_kicker.has_method("get_joystick_input"):
		return last_kicker.get_joystick_input()
	return Vector2.ZERO


## Dampen ball velocity (e.g., on pickup — the "trapping" feel).
func apply_damping(factor: float) -> void:
	physics.velocity *= factor


## Reset ball state (e.g., for kickoff).
func reset_ball() -> void:
	physics.reset()
	aftertouch.reset()
	last_kicker = null
