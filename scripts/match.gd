extends Node2D
## Match orchestrator — manages game state, referee logic, clock, and possession.

signal goal_scored(scoring_team: String)

var match_state: MatchStatePure
var possession: PossessionPure
var match_time: float = 0.0
var all_players: Array = []
var selected_player: CharacterBody2D = null

## Throw-in state.
var throwin_logic: ThrowinPure = null
var throwin_player: CharacterBody2D = null  ## The player taking the throw-in
var throwin_prev_selected: CharacterBody2D = null  ## Who was selected before throw-in
var throwin_trajectory: Node2D = null  ## Trajectory preview node

@onready var ball: CharacterBody2D = $Ball
@onready var scoreboard: Label = $UI/Scoreboard
@onready var clock: Label = $UI/Clock
@onready var team_home: Node2D = $TeamHome
@onready var team_away: Node2D = $TeamAway
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	match_state = MatchStatePure.new()
	possession = PossessionPure.new()

	# Connect goal signals
	if has_node("GoalTop"):
		$GoalTop.goal_detected.connect(_on_goal_detected)
	if has_node("GoalBottom"):
		$GoalBottom.goal_detected.connect(_on_goal_detected)

	# Wire camera to ball
	camera.ball = ball

	# Wire ball reference to goals for ball-over-goal compositing
	if has_node("GoalTop"):
		$GoalTop.ball = ball
	if has_node("GoalBottom"):
		$GoalBottom.ball = ball

	# Set ball to pitch center before match starts
	ball.position = PitchGeometry.CENTER

	# Wait one frame for teams to spawn their players
	await get_tree().process_frame
	_setup_players()
	start_match()


## Collect all players and designate the human-controlled one.
func _setup_players() -> void:
	all_players = []
	var home_players: Array = team_home.get_players()
	var away_players: Array = team_away.get_players()
	all_players = home_players + away_players

	# Give every player a reference to the ball and all players, ensure none are selected
	for i in range(all_players.size()):
		var player: CharacterBody2D = all_players[i]
		player.ball = ball
		player.all_players_ref = all_players
		player.player_index = i
		player.is_human_controlled = false
		player.is_selected = false

	# Initialize AI for all players
	_setup_ai(home_players, away_players)

	# Start fully CPU-controlled by default (F2 to enable human player)
	selected_player = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_toggle_human_control()


## Toggle human control on/off — F2 makes the game fully CPU vs CPU.
func _toggle_human_control() -> void:
	if selected_player:
		# Deselect: let AI take over
		selected_player.is_selected = false
		selected_player.is_human_controlled = false
		selected_player = null
	else:
		# Re-select: give control back to home CF
		var home_players: Array = team_home.get_players()
		if home_players.size() > 0:
			selected_player = _find_forward(home_players)
			selected_player.is_human_controlled = true
			selected_player.is_selected = true


func _physics_process(delta: float) -> void:
	match_state.tick(delta)

	match match_state.get_state():
		MatchStatePure.State.PLAYING:
			match_time += delta
			_update_clock()
			_update_chasers()
			_update_teammate_flags()
			_update_possession()
			_check_tackles()
			_enforce_boundaries()
		MatchStatePure.State.KICKOFF_SETUP:
			_reset_to_kickoff()
			match_state.kickoff_complete()
		MatchStatePure.State.THROWIN_SETUP:
			_tick_throwin_setup()
		MatchStatePure.State.THROWIN_ACTIVE:
			_tick_throwin_active()


## Check proximity-based possession and handle dribbling.
## Supports ball passthrough: while the kicker holds fire, own teammates
## are excluded from possession checks so the ball passes through them.
func _update_possession() -> void:
	# Determine passthrough state
	var passthrough_team_id := -1
	if selected_player and selected_player.is_fire_held():
		passthrough_team_id = selected_player.team_id

	# Build player_infos for ALL players, marking eligibility.
	# All players are included so that PossessionPure.possessor_index stays
	# stable across frames (no filtered-array index drift).
	var player_infos: Array = []
	for i in range(all_players.size()):
		var player: CharacterBody2D = all_players[i]
		var eligible := true
		if player.has_kick_cooldown():
			eligible = false
		if player.has_loss_stun():
			eligible = false
		if passthrough_team_id >= 0 \
				and player.team_id == passthrough_team_id \
				and player != selected_player:
			eligible = false
		player_infos.append({
			"position": player.global_position,
			"team_id": player.team_id,
			"is_goalkeeper": player.is_goalkeeper,
			"velocity": player.velocity / 50.0,  # Convert to px/frame
			"eligible": eligible,
		})

	var ball_height: float = ball.physics.height
	var ball_speed: float = ball.physics.get_ground_speed()

	var possessor_idx := possession.check_possession(
		player_infos, ball.global_position, ball_height, ball_speed)

	# Clear old possession flags
	for player in all_players:
		player.has_possession = false

	# Apply new possession
	if possessor_idx >= 0 and possessor_idx < all_players.size():
		var possessor: CharacterBody2D = all_players[possessor_idx]
		possessor.has_possession = true

		# Auto-switch: if a teammate gains possession, switch control to them
		if selected_player \
				and possessor != selected_player \
				and possessor.team_id == selected_player.team_id:
			selected_player.is_selected = false
			selected_player.is_human_controlled = false
			possessor.is_selected = true
			possessor.is_human_controlled = true
			selected_player = possessor

		# Apply pickup damping on first frame of gaining possession
		if possession.was_pickup_this_frame:
			ball.apply_damping(PossessionPure.PICKUP_DAMPING)

		# Dribble: lerp ball toward target (tethered, not glued)
		var dribble_target := PossessionPure.get_dribble_target(
			possessor.global_position, possessor.facing_direction)
		ball.global_position = ball.global_position.lerp(
			dribble_target, PossessionPure.DRIBBLE_LERP_FACTOR)
		# Ball velocity matches possessor during dribble
		ball.physics.velocity = possessor.velocity / 50.0


## Enforce world boundaries — bounce ball, clamp players. Detect throw-ins.
func _enforce_boundaries() -> void:
	# Ball boundary check (with goal mouth exception and throw-in detection)
	var ball_result := BoundaryPure.clamp_ball(
		ball.global_position, ball.physics.velocity)
	ball.global_position = ball_result["position"]
	ball.physics.velocity = ball_result["velocity"]

	# Check for throw-in
	var throwin_side: String = ball_result["throwin"]
	if throwin_side != "":
		_trigger_throwin(throwin_side)
		return

	# Player boundary clamp
	for player in all_players:
		player.global_position = BoundaryPure.clamp_player(
			player.global_position)


func _on_goal_detected(side: String) -> void:
	if not match_state.is_playing():
		return
	match_state.record_goal(side)
	_update_scoreboard()
	goal_scored.emit(match_state.last_goal_team)


func _reset_to_kickoff() -> void:
	ball.reset_ball()
	ball.position = PitchGeometry.CENTER
	possession.reset()
	camera.center_on_pitch()

	# Reset players to formation positions
	for player in all_players:
		player.has_possession = false
		player.position = player.formation_position


func _update_scoreboard() -> void:
	scoreboard.text = match_state.get_score_text()


func _update_clock() -> void:
	var minutes := int(match_time) / 60
	var seconds := int(match_time) % 60
	clock.text = "%02d:%02d" % [minutes, seconds]


## Start the match.
func start_match() -> void:
	match_state.start_play()
	_update_scoreboard()


## Find the center forward in a player list (fallback: last player).
func _find_forward(players: Array) -> CharacterBody2D:
	for player in players:
		if player.role == FormationPure.Role.CENTER_FORWARD:
			return player
	return players[players.size() - 1]


## Initialize AI instances and precompute zone targets for all players.
func _setup_ai(home_players: Array, away_players: Array) -> void:
	# Precompute zone targets for each team
	var home_slots := FormationPure.get_positions(team_home.formation)
	var away_slots := FormationPure.get_away_positions(team_away.formation)
	var home_targets := ZoneLookupPure.generate_targets(home_slots, true)
	var away_targets := ZoneLookupPure.generate_targets(away_slots, false)

	for player in home_players:
		player._zone_targets = home_targets
		if player.is_goalkeeper:
			player.goalkeeper_ai = GoalkeeperAiPure.new()
		else:
			player.outfield_ai = OutfieldAiPure.new()

	for player in away_players:
		player._zone_targets = away_targets
		if player.is_goalkeeper:
			player.goalkeeper_ai = GoalkeeperAiPure.new()
		else:
			player.outfield_ai = OutfieldAiPure.new()


## Current chaser for each team (for hysteresis).
var _home_chaser: CharacterBody2D = null
var _away_chaser: CharacterBody2D = null


## Designate one ball-chaser per team each frame.
## A team only chases when the ball is loose or the OTHER team has it.
func _update_chasers() -> void:
	var possessing_team := -1
	for player in all_players:
		if player.has_possession:
			possessing_team = player.team_id
			break

	# Only chase when ball is loose (possessing_team == -1) or opponent has it
	if possessing_team != 0:
		_home_chaser = _pick_chaser(0, _home_chaser)
	else:
		_home_chaser = null
	if possessing_team != 1:
		_away_chaser = _pick_chaser(1, _away_chaser)
	else:
		_away_chaser = null

	for player in all_players:
		player._is_chaser = (player == _home_chaser or player == _away_chaser)


## Pick the best chaser for a team, with hysteresis to prevent flickering.
func _pick_chaser(target_team_id: int, current_chaser: CharacterBody2D) -> CharacterBody2D:
	var best_dist := INF
	var best_player: CharacterBody2D = null

	for player in all_players:
		if player.team_id != target_team_id:
			continue
		if player.is_goalkeeper:
			continue
		# Don't assign human-controlled player as chaser (they control themselves)
		if player.is_selected:
			continue
		# Don't assign player who has possession (they're ON_BALL, not chasing)
		if player.has_possession:
			continue
		var dist: float = player.global_position.distance_to(ball.global_position)
		if dist < best_dist:
			best_dist = dist
			best_player = player

	# Hysteresis: keep current chaser unless new one is significantly closer
	if current_chaser and current_chaser.team_id == target_team_id \
			and not current_chaser.is_goalkeeper \
			and not current_chaser.is_selected \
			and not current_chaser.has_possession:
		var current_dist: float = current_chaser.global_position.distance_to(ball.global_position)
		if best_dist + AiConstants.CHASER_SWITCH_HYSTERESIS > current_dist:
			return current_chaser

	return best_player


## Update the teammate_has_ball flag on all players.
func _update_teammate_flags() -> void:
	# Determine which team has possession
	var possessing_team := -1
	for player in all_players:
		if player.has_possession:
			possessing_team = player.team_id
			break

	for player in all_players:
		player._teammate_has_ball = (possessing_team == player.team_id \
			and not player.has_possession)


## Check for AI tackles: opponents near ball carrier can force dispossession.
## Knocks the ball loose by applying a small velocity impulse, breaking the
## dribble leash. Only AI chasers can tackle (not human-controlled players).
func _check_tackles() -> void:
	# Find current possessor
	var possessor: CharacterBody2D = null
	for player in all_players:
		if player.has_possession:
			possessor = player
			break
	if not possessor:
		return

	# Check if any opponent chaser is within tackle range
	for player in all_players:
		if player.team_id == possessor.team_id:
			continue
		if player.is_goalkeeper:
			continue
		if not player._is_chaser:
			continue
		if player.has_kick_cooldown() or player.has_loss_stun():
			continue
		var dist: float = player.global_position.distance_to(ball.global_position)
		if dist > AiConstants.TACKLE_RANGE:
			continue

		# Roll for tackle success
		if randf() < AiConstants.TACKLE_SUCCESS_CHANCE:
			# Knock ball loose — push it away from tackler
			var knock_dir: Vector2 = (ball.global_position - player.global_position).normalized()
			if knock_dir.length() < 0.1:
				knock_dir = possessor.facing_direction
			ball.kick(knock_dir * 2.5, 0.0, player)
			possessor.has_possession = false
			possessor.kick_cooldown = possessor.KICK_COOLDOWN_FRAMES
			break  # Only one tackle per frame


# ── Throw-in ────────────────────────────────────────────────────────────────

## Trigger a throw-in when ball crosses the sideline.
func _trigger_throwin(side: String) -> void:
	# Determine which team gets the throw (opposite of last touch)
	var throwing_team_id := 0
	if ball.last_kicker:
		throwing_team_id = 1 if ball.last_kicker.team_id == 0 else 0
	else:
		# No last kicker — give to home team by default
		throwing_team_id = 0

	# Clamp throw-in Y to within the playing area
	var throwin_y := clampf(ball.global_position.y,
		PitchGeometry.GOAL_TOP_Y + 10.0, PitchGeometry.GOAL_BOTTOM_Y - 10.0)
	var throwin_x: float
	if side == "left":
		throwin_x = PitchGeometry.SIDELINE_LEFT
	else:
		throwin_x = PitchGeometry.SIDELINE_RIGHT

	var throwin_pos := Vector2(throwin_x, throwin_y)

	# Stop the ball and place it at the throw-in spot
	ball.reset_ball()
	ball.global_position = throwin_pos
	ball.visible = false

	# Clear all possession
	possession.reset()
	for player in all_players:
		player.has_possession = false

	# Find nearest non-goalkeeper outfield player from throwing team
	throwin_player = _find_nearest_thrower(throwin_pos, throwing_team_id)
	if not throwin_player:
		# Fallback: resume play (shouldn't happen with 10 outfield players)
		ball.visible = true
		return

	# Save who was selected before and switch control to thrower
	throwin_prev_selected = selected_player
	if selected_player:
		selected_player.is_selected = false
		selected_player.is_human_controlled = false

	# Set up throw-in logic
	throwin_logic = ThrowinPure.new()
	throwin_logic.setup(side)

	# Record in match state
	match_state.record_throwin(throwin_pos, side, throwing_team_id)

	# Mark thrower as in throw-in mode, freeze everyone else
	throwin_player.throwin_mode = true
	throwin_player.is_selected = true
	throwin_player.is_human_controlled = true
	for player in all_players:
		if player != throwin_player:
			player.match_frozen = true

	# Create trajectory preview node
	if not throwin_trajectory:
		throwin_trajectory = Node2D.new()
		throwin_trajectory.set_script(
			load("res://scripts/throwin_trajectory.gd"))
		add_child(throwin_trajectory)


## Tick THROWIN_SETUP: walk thrower to sideline.
func _tick_throwin_setup() -> void:
	if not throwin_player or not throwin_logic:
		match_state.throwin_complete()
		return

	var target_pos := match_state.throwin_position

	# Walk toward the spot
	var walk_vel := throwin_logic.get_walk_velocity(
		throwin_player.global_position, target_pos)

	if walk_vel == Vector2.ZERO or throwin_logic.check_arrived(
			throwin_player.global_position, target_pos):
		# Arrived — snap to position and enter aiming phase
		throwin_player.global_position = target_pos
		throwin_player.velocity = Vector2.ZERO
		throwin_logic.phase = ThrowinPure.Phase.AIMING
		# Face infield
		throwin_player.facing_direction = throwin_logic.get_default_aim()
		match_state.throwin_ready()
	else:
		throwin_player.facing_direction = walk_vel.normalized()
		throwin_player.velocity = walk_vel * 50.0
		throwin_player.move_and_slide()


## Tick THROWIN_ACTIVE: aim, charge, release, return.
func _tick_throwin_active() -> void:
	if not throwin_player or not throwin_logic:
		_finish_throwin()
		return

	match throwin_logic.phase:
		ThrowinPure.Phase.AIMING:
			_throwin_handle_input()
			_update_throwin_trajectory()
		ThrowinPure.Phase.CHARGING:
			_throwin_handle_input()
			_update_throwin_trajectory()
		ThrowinPure.Phase.THROWING:
			throwin_logic.tick_post_throw()
			throwin_player.velocity = Vector2.ZERO
			# Unfreeze other players when throw animation ends (entering RETURNING)
			if throwin_logic.phase == ThrowinPure.Phase.RETURNING:
				for player in all_players:
					player.match_frozen = false
		ThrowinPure.Phase.RETURNING:
			_tick_throwin_return()
		ThrowinPure.Phase.DONE:
			_finish_throwin()


## Handle input during throw-in aiming/charging.
## Uses raw analog input (not 8-way quantised) for smooth curve aiming.
func _throwin_handle_input() -> void:
	var input_dir := InputMapper.get_raw_movement_input()

	# Update aim direction
	throwin_logic.update_aim(input_dir)
	if input_dir != Vector2.ZERO:
		throwin_player.facing_direction = throwin_logic.aim_direction

	# Freeze thrower position
	throwin_player.velocity = Vector2.ZERO

	# Button handling
	if throwin_logic.phase == ThrowinPure.Phase.AIMING:
		if InputMapper.is_kick_just_pressed():
			throwin_logic.start_charge()
	elif throwin_logic.phase == ThrowinPure.Phase.CHARGING:
		if InputMapper.is_kick_held():
			throwin_logic.tick_charge()
		if InputMapper.is_kick_just_released() or not InputMapper.is_kick_held():
			_perform_throwin()


## Perform the actual throw.
func _perform_throwin() -> void:
	var result := throwin_logic.release()

	# Show and kick ball
	ball.visible = true
	ball.global_position = match_state.throwin_position
	ball.kick(result["velocity"], result["up_velocity"], throwin_player, true)

	# Play throw-in animation
	throwin_player.animation_state.direction = \
		PlayerAnimationPure._velocity_to_direction(throwin_logic.aim_direction)
	throwin_player.animation_state.trigger_throwin()

	# Give thrower a kick cooldown so they don't immediately repossess
	throwin_player.kick_cooldown = throwin_player.KICK_COOLDOWN_FRAMES

	# Hide trajectory
	if throwin_trajectory:
		throwin_trajectory.hide_trajectory()


## Update the trajectory preview dots.
func _update_throwin_trajectory() -> void:
	if not throwin_trajectory or not throwin_logic:
		return
	var points := throwin_logic.compute_trajectory(match_state.throwin_position)
	throwin_trajectory.update_trajectory(points)


## Tick the thrower returning to position.
func _tick_throwin_return() -> void:
	# Resume play for all other players
	# (they'll be handled by normal _physics_process on next PLAYING tick)

	var return_vel := throwin_logic.get_return_velocity(
		throwin_player.global_position, throwin_player.formation_position)

	if return_vel == Vector2.ZERO:
		_finish_throwin()
	else:
		throwin_player.facing_direction = return_vel.normalized()
		throwin_player.velocity = return_vel * 50.0
		throwin_player.move_and_slide()

	# Let other players resume normal play during return phase
	_update_clock()
	_update_chasers()
	_update_teammate_flags()
	_update_possession()
	match_time += 1.0 / 50.0  # Manual delta since we're not in PLAYING state


## Finish the throw-in sequence and return to normal play.
func _finish_throwin() -> void:
	# Unfreeze all players
	for player in all_players:
		player.match_frozen = false

	if throwin_player:
		throwin_player.throwin_mode = false
		throwin_player.is_selected = false
		throwin_player.is_human_controlled = false

	# Restore previous selected player (or auto-switch will handle it)
	if throwin_prev_selected:
		throwin_prev_selected.is_selected = true
		throwin_prev_selected.is_human_controlled = true
		selected_player = throwin_prev_selected
	elif throwin_player:
		# If no previous selection, keep the thrower selected
		throwin_player.is_selected = true
		throwin_player.is_human_controlled = true
		selected_player = throwin_player

	throwin_player = null
	throwin_prev_selected = null
	throwin_logic = null

	if throwin_trajectory:
		throwin_trajectory.hide_trajectory()

	match_state.throwin_complete()


## Find the nearest non-goalkeeper player from the given team to the position.
func _find_nearest_thrower(pos: Vector2, team_id: int) -> CharacterBody2D:
	var best_player: CharacterBody2D = null
	var best_dist := INF

	for player in all_players:
		if player.team_id != team_id:
			continue
		if player.is_goalkeeper:
			continue
		var dist: float = player.global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_player = player

	return best_player
