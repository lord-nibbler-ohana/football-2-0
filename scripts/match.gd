extends Node2D
## Match orchestrator — manages game state, referee logic, and clock.

signal goal_scored(scoring_team: String)

var match_state: MatchStatePure
var match_time: float = 0.0

@onready var ball: CharacterBody2D = $Ball
@onready var scoreboard: Label = $UI/Scoreboard
@onready var clock: Label = $UI/Clock


func _ready() -> void:
	match_state = MatchStatePure.new()
	# Connect goal signals
	if has_node("GoalLeft"):
		$GoalLeft.goal_detected.connect(_on_goal_detected)
	if has_node("GoalRight"):
		$GoalRight.goal_detected.connect(_on_goal_detected)


func _physics_process(delta: float) -> void:
	match_state.tick(delta)

	match match_state.get_state():
		MatchStatePure.State.PLAYING:
			match_time += delta
			_update_clock()
		MatchStatePure.State.KICKOFF_SETUP:
			_reset_to_kickoff()
			match_state.kickoff_complete()


func _on_goal_detected(side: String) -> void:
	if not match_state.is_playing():
		return
	match_state.record_goal(side)
	_update_scoreboard()
	goal_scored.emit(match_state.last_goal_team)


func _reset_to_kickoff() -> void:
	ball.reset_ball()
	ball.position = Vector2(160, 120)


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
