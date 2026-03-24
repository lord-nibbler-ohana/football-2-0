extends Node2D
## Goal node — positions goalposts and detects when the ball enters the goal.

signal goal_detected(side: String)

@export var is_left_goal: bool = true

@onready var goal_area: Area2D = $GoalArea
@onready var top_post: StaticBody2D = $TopPost
@onready var bottom_post: StaticBody2D = $BottomPost
@onready var goal_sprite: Sprite2D = $GoalSprite

var _goal_left_tex := preload("res://sprites/pitch/goal_left.png")
var _goal_right_tex := preload("res://sprites/pitch/goal_right.png")


func _ready() -> void:
	var goal_x: float
	var area_offset_x: float
	if is_left_goal:
		goal_x = GoalDetectionPure.GOAL_LEFT_X
		area_offset_x = -GoalDetectionPure.GOAL_DEPTH / 2.0
		goal_sprite.texture = _goal_left_tex
	else:
		goal_x = GoalDetectionPure.GOAL_RIGHT_X
		area_offset_x = GoalDetectionPure.GOAL_DEPTH / 2.0
		goal_sprite.texture = _goal_right_tex

	var mouth_center_y := (GoalDetectionPure.GOAL_MOUTH_TOP + GoalDetectionPure.GOAL_MOUTH_BOTTOM) / 2.0

	# Position the goal area behind the goal line
	goal_area.position = Vector2(goal_x + area_offset_x, mouth_center_y)

	# Position posts at the edges of the goal mouth
	top_post.position = Vector2(goal_x, GoalDetectionPure.GOAL_MOUTH_TOP)
	bottom_post.position = Vector2(goal_x, GoalDetectionPure.GOAL_MOUTH_BOTTOM)

	# Position goal sprite centered on the goal mouth
	goal_sprite.position = Vector2(goal_x, mouth_center_y)

	# Add posts to goalpost group for collision detection
	top_post.add_to_group("goalpost")
	bottom_post.add_to_group("goalpost")

	goal_area.body_entered.connect(_on_goal_area_body_entered)


func _on_goal_area_body_entered(body: Node2D) -> void:
	if body.has_node("BallSprite") and body.has_method("kick"):
		# It's the ball — check crossbar height
		var ball_height: float = body.physics.height
		if ball_height <= GoalDetectionPure.CROSSBAR_HEIGHT:
			var side := "left" if is_left_goal else "right"
			goal_detected.emit(side)
