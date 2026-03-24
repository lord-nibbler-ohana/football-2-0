extends CharacterBody2D
## Ball physics and state.

const GROUND_FRICTION := 0.98
const AIR_FRICTION := 0.99
const GRAVITY := 0.4
const BOUNCE_DAMPING := 0.5

var height: float = 0.0
var vertical_velocity: float = 0.0


func _ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color.WHITE)
