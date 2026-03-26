class_name MatchStatePure
extends RefCounted
## Pure match state machine — no Node/scene tree dependencies.
## Tracks match state, score, and celebration timers.

enum State { PRE_MATCH, PLAYING, GOAL_SCORED, KICKOFF_SETUP, THROWIN_SETUP, THROWIN_ACTIVE }

const GOAL_CELEBRATION_TIME := 2.0

var state: int = State.PRE_MATCH
var score_home: int = 0
var score_away: int = 0
var goal_pause_timer: float = 0.0
var last_goal_team: String = ""

## Throw-in state.
var throwin_position: Vector2 = Vector2.ZERO  ## Where ball went out (on sideline)
var throwin_side: String = ""  ## "left" or "right"
var throwin_team_id: int = -1  ## Team that gets the throw-in


## Start the match — transition to PLAYING.
func start_play() -> void:
	state = State.PLAYING


## Record a goal scored in the given side ("top" or "bottom").
## Top goal = home team scores (attacking upward), bottom goal = away team scores.
func record_goal(side: String) -> void:
	if side == "top":
		score_home += 1
		last_goal_team = "home"
	elif side == "bottom":
		score_away += 1
		last_goal_team = "away"
	state = State.GOAL_SCORED
	goal_pause_timer = GOAL_CELEBRATION_TIME


## Advance the state machine by one frame.
func tick(delta: float) -> void:
	if state == State.GOAL_SCORED:
		goal_pause_timer -= delta
		if goal_pause_timer <= 0.0:
			goal_pause_timer = 0.0
			state = State.KICKOFF_SETUP


## True if the match is in active play.
func is_playing() -> bool:
	return state == State.PLAYING


## Get the current state.
func get_state() -> int:
	return state


## Get score as a formatted string.
func get_score_text() -> String:
	return "%d - %d" % [score_home, score_away]


## Transition from KICKOFF_SETUP back to PLAYING.
func kickoff_complete() -> void:
	if state == State.KICKOFF_SETUP:
		state = State.PLAYING


## Record a throw-in and enter THROWIN_SETUP.
func record_throwin(pos: Vector2, side: String, team_id: int) -> void:
	throwin_position = pos
	throwin_side = side
	throwin_team_id = team_id
	state = State.THROWIN_SETUP


## Thrower has reached the sideline — activate throw-in controls.
func throwin_ready() -> void:
	if state == State.THROWIN_SETUP:
		state = State.THROWIN_ACTIVE


## Throw-in completed — return to play.
func throwin_complete() -> void:
	if state == State.THROWIN_ACTIVE:
		state = State.PLAYING
