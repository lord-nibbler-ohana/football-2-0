extends Node2D
## Match orchestrator — manages game state, referee logic, clock, and possession.

signal goal_scored(scoring_team: String)

var match_state: MatchStatePure
var possession: PossessionPure
var match_time: float = 0.0
var all_players: Array = []
var selected_player: CharacterBody2D = null

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

	# Select the home forward (last spawned = FWD) as human-controlled
	if home_players.size() > 0:
		selected_player = home_players[home_players.size() - 1]  # Last = FWD
		selected_player.is_human_controlled = true
		selected_player.is_selected = true


func _physics_process(delta: float) -> void:
	match_state.tick(delta)

	match match_state.get_state():
		MatchStatePure.State.PLAYING:
			match_time += delta
			_update_clock()
			_update_possession()
			_enforce_boundaries()
		MatchStatePure.State.KICKOFF_SETUP:
			_reset_to_kickoff()
			match_state.kickoff_complete()


## Check proximity-based possession and handle dribbling.
## Supports ball passthrough: while the kicker holds fire, own teammates
## are excluded from possession checks so the ball passes through them.
func _update_possession() -> void:
	# Determine passthrough state
	var passthrough_team_id := -1
	if selected_player and selected_player.is_fire_held():
		passthrough_team_id = selected_player.team_id

	# Build player_infos, filtering out passthrough teammates and cooldown players
	var player_infos: Array = []
	var index_map: Array = []  # Maps filtered index -> all_players index
	for i in range(all_players.size()):
		var player: CharacterBody2D = all_players[i]

		# Skip players with post-kick cooldown (prevents immediate re-possession)
		if player.has_kick_cooldown():
			continue

		# Skip same-team non-kicker players during passthrough
		if passthrough_team_id >= 0 \
				and player.team_id == passthrough_team_id \
				and player != selected_player:
			continue

		player_infos.append({
			"position": player.global_position,
			"team_id": player.team_id,
			"is_goalkeeper": player.is_goalkeeper,
			"velocity": player.velocity / 50.0,  # Convert to px/frame
		})
		index_map.append(i)

	var ball_height: float = ball.physics.height
	var ball_speed: float = ball.physics.get_ground_speed()

	var possessor_filtered_idx := possession.check_possession(
		player_infos, ball.global_position, ball_height, ball_speed)

	# Map filtered index back to all_players index
	var possessor_idx := -1
	if possessor_filtered_idx >= 0 and possessor_filtered_idx < index_map.size():
		possessor_idx = index_map[possessor_filtered_idx]

	# Clear old possession flags
	for player in all_players:
		player.has_possession = false

	# Apply new possession
	if possessor_idx >= 0 and possessor_idx < all_players.size():
		var possessor: CharacterBody2D = all_players[possessor_idx]
		possessor.has_possession = true

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


## Enforce world boundaries — bounce ball, clamp players.
func _enforce_boundaries() -> void:
	# Ball boundary bounce (with goal mouth exception)
	var ball_result := BoundaryPure.clamp_ball(
		ball.global_position, ball.physics.velocity)
	ball.global_position = ball_result["position"]
	ball.physics.velocity = ball_result["velocity"]

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
