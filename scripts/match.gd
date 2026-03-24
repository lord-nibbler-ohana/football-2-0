extends Node2D
## Match orchestrator — manages game state, referee logic, and clock.

var score_home: int = 0
var score_away: int = 0
var match_time: float = 0.0
var is_playing: bool = false


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_playing:
		match_time += delta
