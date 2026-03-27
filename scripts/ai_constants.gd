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
const DRIBBLE_MIN_FRAMES := 20  ## Minimum dribble before passing (0.4s)
const DRIBBLE_MAX_FRAMES := 75  ## Maximum dribble — force a pass (1.5s)
const PRESSURE_PASS_FRAMES := 15  ## Pass sooner when opponent nearby (0.3s)

## Shooting.
const SHOOT_RANGE := 140.0  ## px from goal center
const MIN_SHOOT_ANGLE_DEG := 10.0  ## Degrees of goal mouth visible
const SHOT_CHARGE_MIN := 8  ## Frames
const SHOT_CHARGE_MAX := 12  ## Frames
const SHOT_AIM_RANDOMNESS := 20.0  ## px offset from goal center

## Passing.
const PANIC_CLEAR_DISTANCE := 30.0  ## Opponent proximity triggers clear
const PANIC_CLEAR_CHARGE := 6  ## Frames of charge for clearance
const PRESSURE_DISTANCE := 80.0  ## Opponent this close triggers early forward pass
const WING_PASS_X_THRESHOLD := 180.0  ## If ball is central (within this of center X), consider wing pass
const WING_TARGET_X_OFFSET := 180.0  ## How far wide the wing pass target is from center
const CROSS_RANGE := 200.0  ## px from goal — winger should cross instead of dribble
const CROSS_CHARGE := 4  ## Charge frames for a cross (medium power pass)

## Goalkeeper.
const GK_ARC_RADIUS := 40.0  ## px from goal center
const GK_RUSH_TRIGGER_DISTANCE := 140.0  ## Slightly larger to give GK more time
const GK_RUSH_BALL_SPEED_MIN := 0.5  ## Ball must be moving toward goal (lower = more reactive)
const GK_X_MARGIN := 15.0  ## px beyond goal mouth GK can move
const GK_MAX_Y_FROM_GOAL := 60.0  ## px GK can advance from goal line
const GK_HOLD_FRAMES := 15  ## Frames GK holds ball before moving (0.3s)
const GK_DISTRIBUTE_SPEED := 0.7  ## Walk speed while carrying ball (relative to PLAYER_SPEED)
const GK_DISTRIBUTE_MAX_FRAMES := 100  ## Max frames before forced kick (2s)
const GK_DISTRIBUTE_ADVANCE := 70.0  ## How far GK runs out of goal before stopping
const GK_CLEAR_CHARGE := 8  ## Charge frames for a clearing kick outside the box
const GK_LONG_KICK_CHARGE := 10  ## Charge frames for a long distribution kick
const GK_TEAMMATE_CLEAR_RADIUS := 80.0  ## Teammates stay this far from GK with ball

## Support runs.
const SUPPORT_RUN_DISTANCE := 100.0  ## px ahead of ball carrier
const SUPPORT_RUN_LATERAL := 60.0  ## px lateral spread
const MAX_SUPPORT_RUNNERS := 2

## Teammate avoidance — keep off-ball teammates away from ball carrier.
const TEAMMATE_AVOIDANCE_RADIUS := 35.0  ## px — teammates steer away from ball carrier
const TEAMMATE_AVOIDANCE_STRENGTH := 1.5  ## Multiplier on avoidance push

## Tackling / ball contest.
const TACKLE_RANGE := 10.0  ## px — chaser can contest possession at this distance (standing tackle)
const TACKLE_ENGAGE_FRAMES := 8  ## Frames chaser must stay in range before tackle can trigger (0.16s)
const TACKLE_SUCCESS_CHANCE := 0.12  ## Per-frame probability AFTER engage period (was 0.35)
const TACKLE_KNOCK_SPEED := 7.0  ## px/frame — strong knock to clear contested zone
const TACKLE_KNOCK_LOFT := 0.5  ## Vertical velocity on tackle knock — ball goes briefly airborne
const TACKLE_EXCLUSIVE_FRAMES := 25  ## Frames (0.5s) — only tackler's team can pick up ball

## Team-wide contest cooldown — prevents ping-pong across different players.
const TEAM_CONTEST_COOLDOWN := 25  ## Frames (0.5s) — after losing ball via tackle, whole team can't re-tackle
const TEAM_REPOSSESS_COOLDOWN := 30  ## Frames (0.6s) — after losing ball, whole team can't pick up ball

## AI slide tackle.
const AI_SLIDE_TRIGGER_DISTANCE := 22.0  ## px — AI initiates slide when this close to opponent with ball
const AI_SLIDE_TRIGGER_CHANCE := 0.03  ## Per-frame probability of deciding to slide when in range (was 0.08)

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
