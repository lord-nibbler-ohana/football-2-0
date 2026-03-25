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

	# Give every player a reference to the ball, ensure none are selected
	for player in all_players:
		player.ball = ball
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
		MatchStatePure.State.KICKOFF_SETUP:
			_reset_to_kickoff()
			match_state.kickoff_complete()


## Check proximity-based possession and handle dribbling.
func _update_possession() -> void:
	var ball_airborne: bool = ball.physics.is_airborne()

	# Build position array matching all_players order
	var positions: Array = []
	for player in all_players:
		positions.append(player.global_position)

	var possessor_idx := possession.check_possession(
		positions, ball.global_position, ball_airborne)

	# Clear old possession
	for player in all_players:
		player.has_possession = false

	# Apply new possession
	if possessor_idx >= 0 and possessor_idx < all_players.size():
		var possessor: CharacterBody2D = all_players[possessor_idx]
		possessor.has_possession = true

		# Dribble: move ball to follow the possessing player
		if possessor.is_selected:
			var dribble_pos := PossessionPure.get_dribble_position(
				possessor.global_position, possessor.facing_direction)
			ball.global_position = dribble_pos
			ball.physics.velocity = Vector2.ZERO


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
