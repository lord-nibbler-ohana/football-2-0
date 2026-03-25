extends Node2D
## Goal node — positions goalposts and detects when the ball enters the goal.
## Vertical pitch: goals at top and bottom, mouth extends along X axis.

signal goal_detected(side: String)

@export var is_top_goal: bool = true

@onready var goal_area: Area2D = $GoalArea
@onready var left_post: StaticBody2D = $LeftPost
@onready var right_post: StaticBody2D = $RightPost
@onready var goal_sprite: Sprite2D = $GoalSprite

var _goal_top_tex := preload("res://sprites/pitch/goal_top.png")
var _goal_bottom_tex := preload("res://sprites/pitch/goal_bottom.png")


func _ready() -> void:
	var goal_y: float
	var area_offset_y: float
	if is_top_goal:
		goal_y = GoalDetectionPure.GOAL_TOP_Y
		area_offset_y = -GoalDetectionPure.GOAL_DEPTH / 2.0
		goal_sprite.texture = _goal_top_tex
	else:
		goal_y = GoalDetectionPure.GOAL_BOTTOM_Y
		area_offset_y = GoalDetectionPure.GOAL_DEPTH / 2.0
		goal_sprite.texture = _goal_bottom_tex

	var mouth_center_x := (GoalDetectionPure.GOAL_MOUTH_LEFT + GoalDetectionPure.GOAL_MOUTH_RIGHT) / 2.0

	# Position the goal area behind the goal line
	goal_area.position = Vector2(mouth_center_x, goal_y + area_offset_y)

	# Position posts at the edges of the goal mouth
	left_post.position = Vector2(GoalDetectionPure.GOAL_MOUTH_LEFT, goal_y)
	right_post.position = Vector2(GoalDetectionPure.GOAL_MOUTH_RIGHT, goal_y)

	# Position goal sprite centered on the goal mouth
	goal_sprite.position = Vector2(mouth_center_x, goal_y)

	# Add posts to goalpost group for collision detection
	left_post.add_to_group("goalpost")
	right_post.add_to_group("goalpost")

	goal_area.body_entered.connect(_on_goal_area_body_entered)


func _on_goal_area_body_entered(body: Node2D) -> void:
	if body.has_node("BallSprite") and body.has_method("kick"):
		# It's the ball — check crossbar height
		var ball_height: float = body.physics.height
		if ball_height <= GoalDetectionPure.CROSSBAR_HEIGHT:
			var side := "top" if is_top_goal else "bottom"
			goal_detected.emit(side)
