extends GutTest
## Smoke test to verify project setup and scene loading.

var ball_scene = load("res://scenes/ball.tscn")
var player_scene = load("res://scenes/player.tscn")
var main_scene = load("res://scenes/main.tscn")


func test_ball_scene_loads() -> void:
	assert_not_null(ball_scene, "ball.tscn should load")


func test_player_scene_loads() -> void:
	assert_not_null(player_scene, "player.tscn should load")


func test_main_scene_loads() -> void:
	assert_not_null(main_scene, "main.tscn should load")


func test_ball_is_character_body_2d() -> void:
	var ball = ball_scene.instantiate()
	assert_is(ball, CharacterBody2D, "Ball should be CharacterBody2D")
	ball.queue_free()


func test_player_is_character_body_2d() -> void:
	var player = player_scene.instantiate()
	assert_is(player, CharacterBody2D, "Player should be CharacterBody2D")
	player.queue_free()


func test_player_does_not_collide_with_players() -> void:
	var player = player_scene.instantiate()
	var collides_with_players = (player.collision_mask & 4) != 0
	assert_false(collides_with_players, "Players must not collide with each other")
	player.queue_free()


func test_ball_collision_layer() -> void:
	var ball = ball_scene.instantiate()
	assert_eq(ball.collision_layer, 2, "Ball should be on collision layer 2")
	ball.queue_free()


func test_physics_tick_rate() -> void:
	var tick_rate = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	assert_eq(tick_rate, 50, "Physics tick rate should be 50 Hz (PAL)")
