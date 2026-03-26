extends Node2D
## Goal node — multi-layer rendering with ball depth compositing.
## Vertical pitch: goals at top and bottom, mouth extends along X axis.
##
## Rendering layers (ysoccer-style):
##   GoalNetting  — back netting strip (top goal only)
##   GoalFrame    — front posts + crossbar (both goals)
##   BallOverlay  — ball duplicate shown above goal netting when conditions met

signal goal_detected(side: String)

@export var is_top_goal: bool = true

@onready var goal_area: Area2D = $GoalArea
@onready var left_post: StaticBody2D = $LeftPost
@onready var right_post: StaticBody2D = $RightPost
@onready var goal_netting: Sprite2D = $GoalNetting
@onready var goal_frame: Sprite2D = $GoalFrame
@onready var ball_overlay: Sprite2D = $BallOverlay

## Set by match.gd after scene is ready.
var ball: CharacterBody2D = null

var _goal_top_a_tex := preload("res://sprites/pitch/goal_top_a.png")
var _goal_top_b_tex := preload("res://sprites/pitch/goal_top_b.png")
var _goal_bottom_tex := preload("res://sprites/pitch/goal_bottom_new.png")
var _ball_tex := preload("res://sprites/ball/ball.png")

const GOAL_DEPTH_VISUAL := 11.0


func _ready() -> void:
	var goal_y: float
	var area_offset_y: float
	var mouth_cx := (GoalDetectionPure.GOAL_MOUTH_LEFT + GoalDetectionPure.GOAL_MOUTH_RIGHT) / 2.0

	if is_top_goal:
		goal_y = GoalDetectionPure.GOAL_TOP_Y
		area_offset_y = -GoalDetectionPure.GOAL_DEPTH / 2.0
		_setup_top_goal(mouth_cx, goal_y)
	else:
		goal_y = GoalDetectionPure.GOAL_BOTTOM_Y
		area_offset_y = GoalDetectionPure.GOAL_DEPTH / 2.0
		_setup_bottom_goal(mouth_cx, goal_y)

	# Position collision shapes (unchanged from original)
	goal_area.position = Vector2(mouth_cx, goal_y + area_offset_y)
	left_post.position = Vector2(GoalDetectionPure.GOAL_MOUTH_LEFT, goal_y)
	right_post.position = Vector2(GoalDetectionPure.GOAL_MOUTH_RIGHT, goal_y)
	left_post.add_to_group("goalpost")
	right_post.add_to_group("goalpost")

	# Setup ball overlay
	ball_overlay.texture = _ball_tex
	ball_overlay.hframes = 4
	ball_overlay.visible = false

	goal_area.body_entered.connect(_on_goal_area_body_entered)


func _setup_top_goal(mouth_cx: float, goal_y: float) -> void:
	# GoalNetting (goal_top_b): back netting strip, behind goal line
	goal_netting.texture = _goal_top_b_tex
	goal_netting.position = Vector2(mouth_cx, goal_y - GOAL_DEPTH_VISUAL)
	goal_netting.z_index = -1

	# GoalFrame (goal_top_a): front posts + crossbar at goal line
	goal_frame.texture = _goal_top_a_tex
	goal_frame.position = Vector2(mouth_cx, goal_y)
	# Bottom of sprite aligns with goal line
	goal_frame.offset.y = -_goal_top_a_tex.get_height() / 2.0
	goal_frame.z_index = 0

	# Ball overlay above goal frame
	ball_overlay.z_index = 1


func _setup_bottom_goal(mouth_cx: float, goal_y: float) -> void:
	# No separate netting layer for bottom goal (single full-mesh sprite)
	goal_netting.visible = false

	# GoalFrame (goal_bottom_new): full mesh, flipped vertically
	goal_frame.texture = _goal_bottom_tex
	goal_frame.position = Vector2(mouth_cx, goal_y)
	# Top of sprite aligns with goal line (sprite extends downward behind goal)
	goal_frame.offset.y = _goal_bottom_tex.get_height() / 2.0
	goal_frame.flip_v = true
	# High z_index so bottom goal draws ON TOP of all Y-sorted players
	goal_frame.z_index = 10

	# Ball overlay above bottom goal frame
	ball_overlay.z_index = 11


func _process(_delta: float) -> void:
	if ball == null:
		return
	_update_ball_overlay()


func _update_ball_overlay() -> void:
	var show_overlay := false

	var ball_pos := ball.global_position
	var ball_height: float = ball.physics.height
	var in_posts := ball_pos.x >= GoalDetectionPure.GOAL_MOUTH_LEFT and ball_pos.x <= GoalDetectionPure.GOAL_MOUTH_RIGHT

	if is_top_goal:
		# Show overlay when ball is behind top goal line AND high enough
		var behind_line := ball_pos.y < PitchGeometry.GOAL_TOP_Y
		var depth_past := absf(ball_pos.y - PitchGeometry.GOAL_TOP_Y)
		var high_enough := ball_height > (GoalDetectionPure.CROSSBAR_HEIGHT - depth_past / 3.0)
		show_overlay = in_posts and behind_line and high_enough
	else:
		# Show overlay when ball is past bottom goal line AND high enough or deep enough
		var past_line := ball_pos.y > PitchGeometry.GOAL_BOTTOM_Y
		var well_past := ball_pos.y >= PitchGeometry.GOAL_BOTTOM_Y + 21
		var depth_past := absf(ball_pos.y - PitchGeometry.GOAL_BOTTOM_Y)
		var high_enough := ball_height > (GoalDetectionPure.CROSSBAR_HEIGHT - depth_past / 3.0)
		show_overlay = in_posts and (well_past or (past_line and high_enough))

	ball_overlay.visible = show_overlay
	if show_overlay:
		# Copy ball visual position (global coords converted to local)
		ball_overlay.global_position = Vector2(ball_pos.x, ball_pos.y - ball_height)
		# Copy ball rotation frame from BallSprite child
		var ball_sprite := ball.get_node_or_null("BallSprite") as Sprite2D
		if ball_sprite:
			ball_overlay.frame = ball_sprite.frame


func _on_goal_area_body_entered(body: Node2D) -> void:
	if body.has_node("BallSprite") and body.has_method("kick"):
		var ball_height: float = body.physics.height
		if ball_height <= GoalDetectionPure.CROSSBAR_HEIGHT:
			var side := "top" if is_top_goal else "bottom"
			goal_detected.emit(side)
