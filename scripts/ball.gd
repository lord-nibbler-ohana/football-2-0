extends CharacterBody2D
## Ball node — delegates physics to BallPhysicsPure, handles visuals and collision.

var physics: BallPhysicsPure

@onready var ball_sprite: Sprite2D = $BallSprite
@onready var shadow_sprite: Sprite2D = $ShadowSprite


func _ready() -> void:
	physics = BallPhysicsPure.new()


func _physics_process(_delta: float) -> void:
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
func kick(ground_vel: Vector2, up_vel: float = 0.0) -> void:
	physics.apply_kick(ground_vel, up_vel)


## Reset ball state (e.g., for kickoff).
func reset_ball() -> void:
	physics.reset()
