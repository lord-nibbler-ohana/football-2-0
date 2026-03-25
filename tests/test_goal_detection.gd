extends GutTest
## Tests for GoalDetectionPure and MatchStatePure.

var gd: GoalDetectionPure
var ms: MatchStatePure


func before_each() -> void:
	gd = GoalDetectionPure.new()
	ms = MatchStatePure.new()


# --- GoalDetectionPure: Goal Detection ---


func test_goal_detected_top_side() -> void:
	var goal_x := PitchGeometry.CENTER_X  # Center of goal mouth
	var result := gd.check_goal(Vector2(goal_x, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, true)
	assert_true(result["is_goal"], "Ball past top goal line, between posts, on ground")
	assert_eq(result["side"], "top")


func test_goal_detected_bottom_side() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(Vector2(goal_x, PitchGeometry.GOAL_BOTTOM_Y + 1.0), 0.0, true)
	assert_true(result["is_goal"], "Ball past bottom goal line, between posts, on ground")
	assert_eq(result["side"], "bottom")


func test_no_goal_above_crossbar() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(Vector2(goal_x, PitchGeometry.GOAL_TOP_Y - 1.0), 10.0, true)
	assert_false(result["is_goal"],
		"Ball above crossbar height should not be a goal")


func test_no_goal_outside_posts_left() -> void:
	var result := gd.check_goal(
		Vector2(PitchGeometry.GOAL_MOUTH_LEFT - 6.0, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, true)
	assert_false(result["is_goal"],
		"Ball outside left post should not be a goal")


func test_no_goal_outside_posts_right() -> void:
	var result := gd.check_goal(
		Vector2(PitchGeometry.GOAL_MOUTH_RIGHT + 6.0, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, true)
	assert_false(result["is_goal"],
		"Ball outside right post should not be a goal")


func test_no_goal_ball_not_in_play() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(Vector2(goal_x, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, false)
	assert_false(result["is_goal"],
		"Ball not in play should not be a goal")


func test_no_goal_ball_on_pitch() -> void:
	var result := gd.check_goal(PitchGeometry.CENTER, 0.0, true)
	assert_false(result["is_goal"],
		"Ball in middle of pitch should not be a goal")


func test_goal_at_exactly_crossbar_height() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(
		Vector2(goal_x, PitchGeometry.GOAL_TOP_Y - 1.0), GoalDetectionPure.CROSSBAR_HEIGHT, true)
	assert_true(result["is_goal"],
		"Ball at exactly crossbar height should be a goal (<=)")


func test_goal_at_left_post_boundary() -> void:
	var result := gd.check_goal(
		Vector2(GoalDetectionPure.GOAL_MOUTH_LEFT, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, true)
	assert_true(result["is_goal"],
		"Ball at exactly left post X should be a goal")


func test_goal_at_right_post_boundary() -> void:
	var result := gd.check_goal(
		Vector2(GoalDetectionPure.GOAL_MOUTH_RIGHT, PitchGeometry.GOAL_TOP_Y - 1.0), 0.0, true)
	assert_true(result["is_goal"],
		"Ball at exactly right post X should be a goal")


func test_goal_at_exactly_goal_line_top() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(
		Vector2(goal_x, GoalDetectionPure.GOAL_TOP_Y), 0.0, true)
	assert_true(result["is_goal"],
		"Ball at exactly top goal line Y should be a goal")


func test_goal_at_exactly_goal_line_bottom() -> void:
	var goal_x := PitchGeometry.CENTER_X
	var result := gd.check_goal(
		Vector2(goal_x, GoalDetectionPure.GOAL_BOTTOM_Y), 0.0, true)
	assert_true(result["is_goal"],
		"Ball at exactly bottom goal line Y should be a goal")


# --- GoalDetectionPure: Goal Mouth Check ---


func test_in_goal_mouth_center() -> void:
	assert_true(gd.is_in_goal_mouth(PitchGeometry.CENTER_X))


func test_not_in_goal_mouth_left() -> void:
	assert_false(gd.is_in_goal_mouth(PitchGeometry.GOAL_MOUTH_LEFT - 5.0))


func test_not_in_goal_mouth_right() -> void:
	assert_false(gd.is_in_goal_mouth(PitchGeometry.GOAL_MOUTH_RIGHT + 5.0))


# --- GoalDetectionPure: Post Energy Loss ---


func test_post_energy_loss() -> void:
	var vel := Vector2(10.0, 5.0)
	var result := gd.apply_post_energy_loss(vel)
	assert_almost_eq(result.x, 7.0, 0.01)
	assert_almost_eq(result.y, 3.5, 0.01)


func test_post_energy_loss_zero_velocity() -> void:
	var result := gd.apply_post_energy_loss(Vector2.ZERO)
	assert_eq(result, Vector2.ZERO)


# --- MatchStatePure: Initial State ---


func test_initial_state_is_pre_match() -> void:
	assert_eq(ms.get_state(), MatchStatePure.State.PRE_MATCH)


func test_initial_score_is_zero() -> void:
	assert_eq(ms.score_home, 0)
	assert_eq(ms.score_away, 0)


func test_not_playing_initially() -> void:
	assert_false(ms.is_playing())


# --- MatchStatePure: Start Play ---


func test_start_play_transitions_to_playing() -> void:
	ms.start_play()
	assert_eq(ms.get_state(), MatchStatePure.State.PLAYING)
	assert_true(ms.is_playing())


# --- MatchStatePure: Record Goal ---


func test_top_goal_scores_for_home() -> void:
	ms.start_play()
	ms.record_goal("top")
	assert_eq(ms.score_home, 1)
	assert_eq(ms.score_away, 0)
	assert_eq(ms.last_goal_team, "home")


func test_bottom_goal_scores_for_away() -> void:
	ms.start_play()
	ms.record_goal("bottom")
	assert_eq(ms.score_away, 1)
	assert_eq(ms.score_home, 0)
	assert_eq(ms.last_goal_team, "away")


func test_goal_transitions_to_goal_scored() -> void:
	ms.start_play()
	ms.record_goal("top")
	assert_eq(ms.get_state(), MatchStatePure.State.GOAL_SCORED)
	assert_false(ms.is_playing())


func test_goal_sets_celebration_timer() -> void:
	ms.start_play()
	ms.record_goal("top")
	assert_almost_eq(ms.goal_pause_timer,
		MatchStatePure.GOAL_CELEBRATION_TIME, 0.01)


# --- MatchStatePure: Celebration Timer ---


func test_celebration_timer_counts_down() -> void:
	ms.start_play()
	ms.record_goal("top")
	ms.tick(1.0)
	assert_almost_eq(ms.goal_pause_timer, 1.0, 0.01)
	assert_eq(ms.get_state(), MatchStatePure.State.GOAL_SCORED)


func test_celebration_ends_transitions_to_kickoff_setup() -> void:
	ms.start_play()
	ms.record_goal("top")
	ms.tick(2.0)
	assert_eq(ms.get_state(), MatchStatePure.State.KICKOFF_SETUP)


func test_kickoff_complete_returns_to_playing() -> void:
	ms.start_play()
	ms.record_goal("top")
	ms.tick(2.0)
	ms.kickoff_complete()
	assert_eq(ms.get_state(), MatchStatePure.State.PLAYING)


# --- MatchStatePure: Multiple Goals ---


func test_multiple_goals_tracked() -> void:
	ms.start_play()
	ms.record_goal("top")
	ms.tick(2.0)
	ms.kickoff_complete()
	ms.record_goal("bottom")
	assert_eq(ms.score_home, 1)
	assert_eq(ms.score_away, 1)


# --- MatchStatePure: Score Text ---


func test_score_text_format() -> void:
	ms.record_goal("top")
	assert_eq(ms.get_score_text(), "1 - 0")
	ms.tick(2.0)
	ms.kickoff_complete()
	ms.record_goal("bottom")
	assert_eq(ms.get_score_text(), "1 - 1")
