class_name MatchStatePure
extends RefCounted
## Pure match state machine — no Node/scene tree dependencies.
## Tracks match state, score, and celebration timers.

enum State {
	PRE_MATCH, PLAYING, GOAL_SCORED, KICKOFF_SETUP,
	THROWIN_SETUP, THROWIN_ACTIVE,
	GOALKICK_SETUP,
	CORNER_SETUP, CORNER_ACTIVE,
}

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

## Corner state.
var corner_position: Vector2 = Vector2.ZERO  ## Corner flag position
var corner_side: String = ""  ## "top" or "bottom" (which goal line)
var corner_team_id: int = -1  ## Team taking the corner

## Goal kick state.
var goalkick_position: Vector2 = Vector2.ZERO  ## Ball placement in 6-yard box
var goalkick_side: String = ""  ## "top" or "bottom"
var goalkick_team_id: int = -1  ## Team taking the goal kick


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


## Record a goal kick and enter GOALKICK_SETUP.
func record_goalkick(pos: Vector2, side: String, team_id: int) -> void:
	goalkick_position = pos
	goalkick_side = side
	goalkick_team_id = team_id
	state = State.GOALKICK_SETUP


## Goal kick setup complete — return to play.
func goalkick_complete() -> void:
	if state == State.GOALKICK_SETUP:
		state = State.PLAYING


## Record a corner kick and enter CORNER_SETUP.
func record_corner(pos: Vector2, side: String, team_id: int) -> void:
	corner_position = pos
	corner_side = side
	corner_team_id = team_id
	state = State.CORNER_SETUP


## Corner taker has reached the flag — activate corner controls.
func corner_ready() -> void:
	if state == State.CORNER_SETUP:
		state = State.CORNER_ACTIVE


## Corner kick completed — return to play.
func corner_complete() -> void:
	if state == State.CORNER_ACTIVE:
		state = State.PLAYING
