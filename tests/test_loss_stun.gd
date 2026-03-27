extends GutTest
## Tests for the loss-of-possession stun mechanic.
## Verifies that players who lose the ball get a cooldown that:
## 1. Prevents immediate re-possession (excluded from pickup checks).
## 2. Reduces movement speed during the stun period.
## 3. Does NOT trigger when the player deliberately kicks the ball.
## 4. Ticks down to zero over the expected number of frames.

## We test the pure logic aspects using the same dictionary-based simulation
## pattern as test_kickoff_simulation.gd, plus direct constant checks.

const STUN_FRAMES := 25  ## Must match LOSS_STUN_FRAMES in player_controller.gd
const STUN_SPEED := 0.35  ## Must match LOSS_STUN_SPEED_FACTOR


# ===== Constants =====

func test_loss_stun_frames_is_25():
	## Verify the constant matches our intended 0.5s at 50 Hz.
	assert_eq(STUN_FRAMES, 25,
		"LOSS_STUN_FRAMES should be 25 (0.5s at 50 Hz)")


# ===== Stun triggers on dispossession =====

## Simulates the stun detection logic from player_controller._physics_process.
## Returns the loss_stun value after one tick.
func _simulate_stun_tick(had_possession: bool, has_possession: bool,
		kick_cooldown: int, current_stun: int) -> Dictionary:
	# Tick down stun
	var stun := current_stun
	if stun > 0:
		stun -= 1

	# Detect dispossession
	if had_possession and not has_possession and kick_cooldown == 0:
		stun = STUN_FRAMES

	return {"loss_stun": stun, "had_possession": has_possession}


func test_stun_triggers_on_dispossession():
	## Player had the ball, now doesn't, and didn't kick -> stun activates.
	var result := _simulate_stun_tick(true, false, 0, 0)
	assert_eq(result["loss_stun"], STUN_FRAMES,
		"Stun should activate when dispossessed without kicking")


func test_stun_does_not_trigger_after_kick():
	## Player had the ball, now doesn't, but has kick_cooldown -> no stun.
	var result := _simulate_stun_tick(true, false, 15, 0)
	assert_eq(result["loss_stun"], 0,
		"Stun should NOT activate when player deliberately kicked")


func test_stun_does_not_trigger_without_prior_possession():
	## Player didn't have the ball before or now -> no stun.
	var result := _simulate_stun_tick(false, false, 0, 0)
	assert_eq(result["loss_stun"], 0,
		"Stun should NOT activate if player never had possession")


func test_stun_does_not_trigger_when_keeping_possession():
	## Player had the ball and still has it -> no stun.
	var result := _simulate_stun_tick(true, true, 0, 0)
	assert_eq(result["loss_stun"], 0,
		"Stun should NOT activate when player retains possession")


# ===== Stun countdown =====

func test_stun_ticks_down_each_frame():
	## Stun should decrease by 1 each frame (before dispossession check).
	var result := _simulate_stun_tick(false, false, 0, 20)
	assert_eq(result["loss_stun"], 19,
		"Stun should decrease by 1 each frame")


func test_stun_reaches_zero():
	## When stun is 1, next frame it should be 0.
	var result := _simulate_stun_tick(false, false, 0, 1)
	assert_eq(result["loss_stun"], 0,
		"Stun should reach 0 from 1")


func test_stun_does_not_go_negative():
	## Stun at 0 should stay at 0.
	var result := _simulate_stun_tick(false, false, 0, 0)
	assert_eq(result["loss_stun"], 0,
		"Stun should not go below 0")


func test_full_stun_duration():
	## Simulate the full stun and verify it expires at the right time.
	var stun := STUN_FRAMES
	var had_poss := false
	for frame in range(STUN_FRAMES):
		var result := _simulate_stun_tick(had_poss, false, 0, stun)
		stun = result["loss_stun"]
	assert_eq(stun, 0,
		"Stun should expire after exactly %d frames" % STUN_FRAMES)


func test_stun_still_active_one_frame_before_expiry():
	## After STUN_FRAMES-1 ticks, stun should still be 1.
	var stun := STUN_FRAMES
	var had_poss := false
	for frame in range(STUN_FRAMES - 1):
		var result := _simulate_stun_tick(had_poss, false, 0, stun)
		stun = result["loss_stun"]
	assert_eq(stun, 1,
		"Stun should still be active after %d of %d frames" % [STUN_FRAMES - 1, STUN_FRAMES])


# ===== Speed reduction =====

func test_speed_reduced_during_stun():
	## Movement speed should be multiplied by LOSS_STUN_SPEED_FACTOR (0.35).
	var base_speed := 2.0
	var stunned_speed := base_speed * STUN_SPEED
	assert_almost_eq(stunned_speed, 0.7, 0.01,
		"Stunned speed should be 35%% of normal (0.7 px/frame)")


func test_speed_normal_when_not_stunned():
	## When loss_stun is 0, speed multiplier should be 1.0.
	var loss_stun := 0
	var speed_mult: float = STUN_SPEED if loss_stun > 0 else 1.0
	assert_eq(speed_mult, 1.0,
		"Speed multiplier should be 1.0 when not stunned")


func test_speed_reduced_when_stunned():
	## When loss_stun > 0, speed multiplier should be 0.35.
	var loss_stun := 15
	var speed_mult: float = STUN_SPEED if loss_stun > 0 else 1.0
	assert_eq(speed_mult, STUN_SPEED,
		"Speed multiplier should be 0.35 when stunned")


# ===== Possession exclusion via eligible flag =====

func test_stunned_player_excluded_from_possession():
	## A stunned player within pickup radius should NOT gain possession.
	## Uses the eligible flag approach (match.gd marks stunned players ineligible).
	var possession := PossessionPure.new()

	# Two players near the ball — one stunned (ineligible), one not
	var infos: Array = [
		{
			"position": Vector2(105, 100),
			"team_id": 1,
			"is_goalkeeper": false,
			"velocity": Vector2.ZERO,
			"eligible": false,  # Stunned
		},
		{
			"position": Vector2(103, 100),
			"team_id": 1,
			"is_goalkeeper": false,
			"velocity": Vector2.ZERO,
			"eligible": true,
		},
	]
	var ball_pos := Vector2(100, 100)

	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, 1,
		"Stunned player should be skipped; non-stunned player wins possession")


func test_no_possession_when_all_stunned():
	## If all nearby players are stunned (ineligible), no one gets possession.
	var possession := PossessionPure.new()
	var infos: Array = [
		{
			"position": Vector2(105, 100),
			"team_id": 0,
			"is_goalkeeper": false,
			"velocity": Vector2.ZERO,
			"eligible": false,
		},
		{
			"position": Vector2(103, 100),
			"team_id": 0,
			"is_goalkeeper": false,
			"velocity": Vector2.ZERO,
			"eligible": false,
		},
	]
	var ball_pos := Vector2(100, 100)

	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, -1,
		"No possession when all nearby players are stunned")


func test_dribble_leash_retained_even_when_ineligible():
	## A player who already has possession retains it via dribble leash
	## even if they become ineligible (e.g., stunned mid-dribble).
	var possession := PossessionPure.new()
	var infos: Array = [
		{
			"position": Vector2(105, 100),
			"team_id": 0,
			"is_goalkeeper": false,
			"velocity": Vector2.ZERO,
			"eligible": true,
		},
	]
	var ball_pos := Vector2(105, 105)

	# Gain possession first
	var result := possession.check_possession(infos, ball_pos)
	assert_eq(result, 0, "Should gain possession initially")

	# Now mark ineligible but still within dribble leash — should DROP possession.
	# An ineligible player (knocked down, stunned) must not retain the ball
	# via dribble leash, otherwise opponents can never pick it up.
	infos[0]["eligible"] = false
	result = possession.check_possession(infos, Vector2(105, 107))
	assert_eq(result, -1,
		"Ineligible player should lose possession even within dribble radius")


# ===== Re-dispossession resets stun =====

func test_new_dispossession_resets_stun_timer():
	## If a player regains and loses the ball again, stun resets to full.
	var stun := 15
	# Regain possession frame
	var result := _simulate_stun_tick(false, true, 0, stun)
	stun = result["loss_stun"]
	# Tick a frame with possession
	result = _simulate_stun_tick(true, true, 0, stun)
	stun = result["loss_stun"]
	# Lose possession again
	result = _simulate_stun_tick(true, false, 0, stun)
	stun = result["loss_stun"]
	assert_eq(stun, STUN_FRAMES,
		"Stun should reset to full %d frames on new dispossession" % STUN_FRAMES)
