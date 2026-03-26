extends Control
## Debug overlay — draws AI state info on screen during gameplay.
## Add as a child of a CanvasLayer in the Main scene.
## Toggle with F1 key.

var enabled := true
var all_players: Array = []
var ball: CharacterBody2D = null


func _ready() -> void:
	# Stretch to fill viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Find references after players spawn
	await get_tree().process_frame
	await get_tree().process_frame
	var main := get_parent().get_parent()  # DebugDraw -> DebugOverlay -> Main
	if main.has_method("start_match"):
		all_players = main.all_players
		ball = main.ball


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		enabled = not enabled
		queue_redraw()


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or all_players.is_empty() or not ball:
		return

	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var cam_pos := camera.global_position
	var vp_size := get_viewport().get_visible_rect().size
	var offset := vp_size / 2.0 - cam_pos

	var font := ThemeDB.fallback_font

	for player in all_players:
		var screen_pos: Vector2 = player.global_position + offset
		var color := Color.WHITE

		var role_name: String = FormationPure.role_name(player.role)
		var team_prefix := "H" if player.is_home else "A"

		var state_name := ""
		if player.is_selected:
			state_name = "HUMAN"
			color = Color.YELLOW
		elif player.is_goalkeeper:
			if player.goalkeeper_ai:
				match player.goalkeeper_ai.state:
					GoalkeeperAiPure.State.TEND_GOAL:
						state_name = "TEND"
						color = Color.CYAN
					GoalkeeperAiPure.State.RUSH_OUT:
						state_name = "RUSH"
						color = Color.RED
					GoalkeeperAiPure.State.RETURN_HOME:
						state_name = "RTN"
						color = Color.CYAN
		elif player.outfield_ai:
			match player.outfield_ai.state:
				OutfieldAiPure.State.HOLD_POSITION:
					state_name = "HOLD"
					color = Color(0.6, 0.6, 0.6)
				OutfieldAiPure.State.CHASE_BALL:
					state_name = "CHASE"
					color = Color.ORANGE
				OutfieldAiPure.State.SUPPORT_RUN:
					state_name = "RUN"
					color = Color.GREEN
				OutfieldAiPure.State.ON_BALL:
					state_name = "BALL"
					color = Color.RED

		var chaser_mark := "*" if player._is_chaser else ""
		var label := "%s-%s %s%s" % [team_prefix, role_name, state_name, chaser_mark]

		var dist: float = player.global_position.distance_to(ball.global_position)
		if dist < 50.0:
			label += " d=%.0f" % dist

		draw_string(font, screen_pos + Vector2(-20, -22), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)

		# Draw zone target line
		if not player.is_selected and player._zone_targets.size() > 0:
			var zone_idx: int = ZoneLookupPure.get_zone(
				ball.global_position, player.is_home)
			var zone_target: Vector2 = ZoneLookupPure.get_target(
				player._zone_targets, player._formation_slot, zone_idx)
			var target_screen := zone_target + offset
			draw_line(screen_pos, target_screen, Color(color, 0.2), 1.0)
			draw_circle(target_screen, 2.0, Color(color, 0.4))

	# Ball velocity
	var ball_screen := ball.global_position + offset
	draw_string(font, ball_screen + Vector2(-15, 14),
		"v=%.1f" % ball.physics.velocity.length(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

	# Help text
	draw_string(font, Vector2(5, vp_size.y - 8), "F1: toggle debug overlay",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.4))
