extends Node2D
## Standalone test scene for goal rendering.
## Run with: godot --path . scenes/test_goal_rendering.tscn
##
## Controls:
##   Arrow keys: move ball X/Y
##   PgUp/PgDn: change ball height
##   R: reset ball to center
##   T: toggle between top/bottom goal area
##   1-5: preset positions (center, top goal, behind top, bottom goal, behind bottom)

const MOVE_SPEED := 2.0
const HEIGHT_STEP := 1.0

var ball_world_pos := PitchGeometry.CENTER
var ball_height := 0.0

@onready var info_label: Label = $UI/InfoLabel
@onready var test_ball: Sprite2D = $TestBall
@onready var ball_shadow: Sprite2D = $BallShadow
@onready var top_goal_netting: Sprite2D = $TopGoalNetting
@onready var top_goal_frame: Sprite2D = $TopGoalFrame
@onready var bottom_goal_frame: Sprite2D = $BottomGoalFrame
@onready var top_ball_overlay: Sprite2D = $TopBallOverlay
@onready var bottom_ball_overlay: Sprite2D = $BottomBallOverlay


func _ready() -> void:
	_setup_goals()
	_setup_ball()
	_update_display()


func _setup_goals() -> void:
	var mouth_cx := PitchGeometry.CENTER_X

	# --- Top goal ---
	# GoalNetting (goal_top_b) — back netting strip, positioned behind goal line
	var netting_tex := load("res://sprites/pitch/goal_top_b.png") as Texture2D
	top_goal_netting.texture = netting_tex
	top_goal_netting.position = Vector2(mouth_cx, PitchGeometry.GOAL_TOP_Y - 11.0)
	top_goal_netting.z_index = -1

	# GoalFrame (goal_top_a) — front posts + crossbar at goal line
	var frame_tex := load("res://sprites/pitch/goal_top_a.png") as Texture2D
	top_goal_frame.texture = frame_tex
	top_goal_frame.position = Vector2(mouth_cx, PitchGeometry.GOAL_TOP_Y)
	# Offset so bottom of sprite aligns with goal line
	top_goal_frame.offset.y = -frame_tex.get_height() / 2.0
	top_goal_frame.z_index = 0

	# --- Bottom goal ---
	# GoalFrame (goal_bottom_new) — full mesh, flipped vertically
	var bottom_tex := load("res://sprites/pitch/goal_bottom_new.png") as Texture2D
	bottom_goal_frame.texture = bottom_tex
	bottom_goal_frame.position = Vector2(mouth_cx, PitchGeometry.GOAL_BOTTOM_Y)
	# Offset so top of sprite aligns with goal line
	bottom_goal_frame.offset.y = bottom_tex.get_height() / 2.0
	bottom_goal_frame.flip_v = true
	bottom_goal_frame.z_index = 10

	# --- Ball overlays ---
	var ball_tex := load("res://sprites/ball/ball.png") as Texture2D
	top_ball_overlay.texture = ball_tex
	top_ball_overlay.hframes = 4
	top_ball_overlay.frame = 0
	top_ball_overlay.visible = false
	top_ball_overlay.z_index = 1

	bottom_ball_overlay.texture = ball_tex
	bottom_ball_overlay.hframes = 4
	bottom_ball_overlay.frame = 0
	bottom_ball_overlay.visible = false
	bottom_ball_overlay.z_index = 11


func _setup_ball() -> void:
	var ball_tex := load("res://sprites/ball/ball.png") as Texture2D
	test_ball.texture = ball_tex
	test_ball.hframes = 4
	test_ball.frame = 0

	ball_shadow.texture = load("res://sprites/ball/ball_shadow.png") as Texture2D


func _process(_delta: float) -> void:
	# Movement
	if Input.is_key_pressed(KEY_LEFT):
		ball_world_pos.x -= MOVE_SPEED
	if Input.is_key_pressed(KEY_RIGHT):
		ball_world_pos.x += MOVE_SPEED
	if Input.is_key_pressed(KEY_UP):
		ball_world_pos.y -= MOVE_SPEED
	if Input.is_key_pressed(KEY_DOWN):
		ball_world_pos.y += MOVE_SPEED
	if Input.is_key_pressed(KEY_PAGEUP):
		ball_height = minf(ball_height + HEIGHT_STEP * 0.5, 50.0)
	if Input.is_key_pressed(KEY_PAGEDOWN):
		ball_height = maxf(ball_height - HEIGHT_STEP * 0.5, 0.0)

	# Presets
	if Input.is_action_just_pressed("ui_text_delete"):  # R key workaround
		ball_world_pos = PitchGeometry.CENTER
		ball_height = 0.0

	if Input.is_key_pressed(KEY_1):
		ball_world_pos = PitchGeometry.CENTER
		ball_height = 0.0
	elif Input.is_key_pressed(KEY_2):
		ball_world_pos = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_TOP_Y + 5)
		ball_height = 0.0
	elif Input.is_key_pressed(KEY_3):
		ball_world_pos = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_TOP_Y - 8)
		ball_height = 12.0
	elif Input.is_key_pressed(KEY_4):
		ball_world_pos = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_BOTTOM_Y - 5)
		ball_height = 0.0
	elif Input.is_key_pressed(KEY_5):
		ball_world_pos = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_BOTTOM_Y + 8)
		ball_height = 12.0

	_update_display()


func _update_display() -> void:
	# Position ball sprite (height raises it visually)
	test_ball.position = Vector2(ball_world_pos.x, ball_world_pos.y - ball_height)
	ball_shadow.position = ball_world_pos

	# --- Top goal compositing ---
	var top_compositing := _check_top_compositing()
	top_ball_overlay.visible = top_compositing
	if top_compositing:
		top_ball_overlay.position = test_ball.position
		top_ball_overlay.frame = test_ball.frame

	# --- Bottom goal compositing ---
	var bottom_compositing := _check_bottom_compositing()
	bottom_ball_overlay.visible = bottom_compositing
	if bottom_compositing:
		bottom_ball_overlay.position = test_ball.position
		bottom_ball_overlay.frame = test_ball.frame

	# --- Info display ---
	var top_str := "ON" if top_compositing else "off"
	var btm_str := "ON" if bottom_compositing else "off"
	info_label.text = "Ball: (%.0f, %.0f) h=%.1f\nTop overlay: %s | Bottom overlay: %s\nArrows=move PgUp/Dn=height 1-5=presets" % [
		ball_world_pos.x, ball_world_pos.y, ball_height, top_str, btm_str
	]


func _check_top_compositing() -> bool:
	var in_posts := ball_world_pos.x >= PitchGeometry.GOAL_MOUTH_LEFT and ball_world_pos.x <= PitchGeometry.GOAL_MOUTH_RIGHT
	var behind_line := ball_world_pos.y < PitchGeometry.GOAL_TOP_Y
	var depth_past := absf(ball_world_pos.y - PitchGeometry.GOAL_TOP_Y)
	var high_enough := ball_height > (GoalDetectionPure.CROSSBAR_HEIGHT - depth_past / 3.0)
	return in_posts and behind_line and high_enough


func _check_bottom_compositing() -> bool:
	var in_posts := ball_world_pos.x >= PitchGeometry.GOAL_MOUTH_LEFT and ball_world_pos.x <= PitchGeometry.GOAL_MOUTH_RIGHT
	var well_past := ball_world_pos.y >= PitchGeometry.GOAL_BOTTOM_Y + 21
	var depth_past := absf(ball_world_pos.y - PitchGeometry.GOAL_BOTTOM_Y)
	var high_enough := ball_height > (GoalDetectionPure.CROSSBAR_HEIGHT - depth_past / 3.0)
	return in_posts and (well_past or (ball_world_pos.y > PitchGeometry.GOAL_BOTTOM_Y and high_enough))
