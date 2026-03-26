class_name AiConstants
extends RefCounted
## All AI tuning constants in one place.

## Zone grid dimensions.
const ZONE_COLS := 5
const ZONE_ROWS := 7

## Movement.
const APPROACH_STOP_DISTANCE := 3.0  ## px — stop when this close to target
const GK_SPEED_FACTOR := 0.9  ## Relative to PLAYER_SPEED
const GK_RUSH_SPEED_FACTOR := 1.1

## Chaser designation.
const CHASER_SWITCH_HYSTERESIS := 15.0  ## px — don't switch unless clearly closer

## On-ball timing (50 Hz tick rate).
const REACTION_DELAY := 15  ## Frames before first kick decision (0.3s)
const DRIBBLE_MIN_FRAMES := 50  ## Minimum dribble before passing (1.0s)
const DRIBBLE_MAX_FRAMES := 150  ## Maximum dribble — force a pass (3.0s)
const PRESSURE_PASS_FRAMES := 25  ## Pass sooner when opponent nearby (0.5s)
const GK_HOLD_FRAMES := 25  ## Frames GK holds ball before distributing (0.5s)

## Shooting.
const SHOOT_RANGE := 180.0  ## px from goal center
const MIN_SHOOT_ANGLE_DEG := 10.0  ## Degrees of goal mouth visible
const SHOT_CHARGE_MIN := 8  ## Frames
const SHOT_CHARGE_MAX := 12  ## Frames
const SHOT_AIM_RANDOMNESS := 20.0  ## px offset from goal center

## Passing.
const PANIC_CLEAR_DISTANCE := 30.0  ## Opponent proximity triggers clear
const PANIC_CLEAR_CHARGE := 6  ## Frames of charge for clearance
const PRESSURE_DISTANCE := 50.0  ## Opponent this close triggers early forward pass
const WING_PASS_X_THRESHOLD := 180.0  ## If ball is central (within this of center X), consider wing pass
const WING_TARGET_X_OFFSET := 180.0  ## How far wide the wing pass target is from center
const CROSS_RANGE := 200.0  ## px from goal — winger should cross instead of dribble
const CROSS_CHARGE := 4  ## Charge frames for a cross (medium power pass)

## Goalkeeper.
const GK_ARC_RADIUS := 40.0  ## px from goal center
const GK_RUSH_TRIGGER_DISTANCE := 120.0
const GK_RUSH_BALL_SPEED_MIN := 1.0  ## Ball must be moving toward goal
const GK_X_MARGIN := 15.0  ## px beyond goal mouth GK can move
const GK_MAX_Y_FROM_GOAL := 60.0  ## px GK can advance from goal line

## Support runs.
const SUPPORT_RUN_DISTANCE := 100.0  ## px ahead of ball carrier
const SUPPORT_RUN_LATERAL := 60.0  ## px lateral spread
const MAX_SUPPORT_RUNNERS := 2

## Teammate avoidance — keep off-ball teammates away from ball carrier.
const TEAMMATE_AVOIDANCE_RADIUS := 35.0  ## px — teammates steer away from ball carrier
const TEAMMATE_AVOIDANCE_STRENGTH := 1.5  ## Multiplier on avoidance push

## Tackling / ball contest.
const TACKLE_RANGE := 12.0  ## px — chaser can contest possession at this distance
const TACKLE_SUCCESS_CHANCE := 0.35  ## Per-frame probability of winning the ball when in range

## Role shift weights for zone target generation.
## Keys are FormationPure.Role values, values are {x_weight, y_weight, y_min_offset, y_max_offset}.
## Offsets are relative to formation_position.y — clamp target within this range of own half.
const ROLE_SHIFT_WEIGHTS := {
	FormationPure.Role.GOALKEEPER: {"x": 0.05, "y": 0.02},
	FormationPure.Role.CENTER_BACK: {"x": 0.15, "y": 0.25},
	FormationPure.Role.LEFT_BACK: {"x": 0.25, "y": 0.30},
	FormationPure.Role.RIGHT_BACK: {"x": 0.25, "y": 0.30},
	FormationPure.Role.SWEEPER: {"x": 0.15, "y": 0.25},
	FormationPure.Role.LEFT_WING_BACK: {"x": 0.25, "y": 0.30},
	FormationPure.Role.RIGHT_WING_BACK: {"x": 0.25, "y": 0.30},
	FormationPure.Role.DEFENSIVE_MID: {"x": 0.20, "y": 0.35},
	FormationPure.Role.CENTER_MID: {"x": 0.30, "y": 0.45},
	FormationPure.Role.LEFT_MID: {"x": 0.40, "y": 0.40},
	FormationPure.Role.RIGHT_MID: {"x": 0.40, "y": 0.40},
	FormationPure.Role.ATTACKING_MID: {"x": 0.30, "y": 0.50},
	FormationPure.Role.LEFT_WINGER: {"x": 0.45, "y": 0.50},
	FormationPure.Role.RIGHT_WINGER: {"x": 0.45, "y": 0.50},
	FormationPure.Role.CENTER_FORWARD: {"x": 0.25, "y": 0.55},
	FormationPure.Role.SECOND_STRIKER: {"x": 0.25, "y": 0.55},
}
