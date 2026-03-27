class_name PitchGeometry
extends RefCounted
## Centralized pitch dimensions and geometry constants.
## All pitch-related positions should be derived from these values.
##
## Layout: vertical pitch with goals at top (Y=MARGIN_Y) and bottom (Y=MARGIN_Y+PLAY_H).
## Matches original Sensible Soccer / SWOS orientation.
## Dimensions chosen so the viewport shows ~65% of the cross-field axis (X)
## and ~42% of the goal-to-goal axis (Y), matching SWOS Amiga PAL ratios.

## Viewport (Amiga SWOS canonical).
const VIEWPORT_W := 336.0
const VIEWPORT_H := 272.0

## Playing area (touchline to touchline, goal line to goal line).
const PLAY_W := 520.0  ## Cross-field (X axis). Viewport shows ~65%
const PLAY_H := 640.0  ## Goal-to-goal (Y axis). Viewport shows ~42%

## Margins around the playing area (for goal nets, advertising boards, surrounds).
const MARGIN_X := 40.0
const MARGIN_Y := 40.0

## Full world size (playing area + margins).
const WORLD_W := PLAY_W + MARGIN_X * 2.0  # 600
const WORLD_H := PLAY_H + MARGIN_Y * 2.0  # 720

## Goal line positions (Y coordinates).
const GOAL_TOP_Y := MARGIN_Y  # 40
const GOAL_BOTTOM_Y := MARGIN_Y + PLAY_H  # 680

## Sideline positions (X coordinates).
const SIDELINE_LEFT := MARGIN_X  # 40
const SIDELINE_RIGHT := MARGIN_X + PLAY_W  # 560

## Pitch center.
const CENTER_X := WORLD_W / 2.0  # 300
const CENTER_Y := WORLD_H / 2.0  # 360
const CENTER := Vector2(CENTER_X, CENTER_Y)

## Goal mouth (X range, centered on pitch).
const GOAL_MOUTH_HALF := 42.0  ## Half-width of goal mouth
const GOAL_MOUTH_LEFT := CENTER_X - GOAL_MOUTH_HALF  # 258
const GOAL_MOUTH_RIGHT := CENTER_X + GOAL_MOUTH_HALF  # 342
const GOAL_DEPTH := 6.0
const GOAL_DEPTH_VISUAL := 11.0  ## Rendering depth (larger than collision depth for visual fidelity)

## Penalty area (16-meter box). Real: 16.5m deep, 40.3m wide.
## Scaled to pixel pitch: ~100px deep, ~308px wide.
const BOX_HALF_W := 154.0  ## Half-width of penalty area
const BOX_DEPTH := 100.0   ## Depth from goal line
const BOX_LEFT := CENTER_X - BOX_HALF_W   # 146
const BOX_RIGHT := CENTER_X + BOX_HALF_W  # 454

## Box Y ranges (goal-line-relative, inward toward pitch center).
const BOX_BOTTOM_Y_MIN := GOAL_BOTTOM_Y - BOX_DEPTH  # 580
const BOX_BOTTOM_Y_MAX := GOAL_BOTTOM_Y               # 680
const BOX_TOP_Y_MIN := GOAL_TOP_Y                     # 40
const BOX_TOP_Y_MAX := GOAL_TOP_Y + BOX_DEPTH         # 140


## 6-yard box (goal area) depth from goal line (~5.5m scaled).
const SIX_YARD_DEPTH := 33.0

## Corner flag positions (sideline/goal-line intersections).
const CORNER_TOP_LEFT := Vector2(SIDELINE_LEFT, GOAL_TOP_Y)      # (40, 40)
const CORNER_TOP_RIGHT := Vector2(SIDELINE_RIGHT, GOAL_TOP_Y)    # (560, 40)
const CORNER_BOTTOM_LEFT := Vector2(SIDELINE_LEFT, GOAL_BOTTOM_Y)   # (40, 680)
const CORNER_BOTTOM_RIGHT := Vector2(SIDELINE_RIGHT, GOAL_BOTTOM_Y) # (560, 680)

## Penalty spot positions (~12 yards / 72px from goal line).
const PENALTY_SPOT_TOP := Vector2(CENTER_X, GOAL_TOP_Y + 72.0)      # (300, 112)
const PENALTY_SPOT_BOTTOM := Vector2(CENTER_X, GOAL_BOTTOM_Y - 72.0) # (300, 608)

## Goal kick ball placement (6-yard box center).
const GOALKICK_TOP := Vector2(CENTER_X, GOAL_TOP_Y + SIX_YARD_DEPTH)      # (300, 73)
const GOALKICK_BOTTOM := Vector2(CENTER_X, GOAL_BOTTOM_Y - SIX_YARD_DEPTH) # (300, 647)


## Check if a position is inside a team's penalty area.
## is_home: true = bottom goal (home GK), false = top goal (away GK).
static func is_in_box(pos: Vector2, is_home: bool) -> bool:
	if pos.x < BOX_LEFT or pos.x > BOX_RIGHT:
		return false
	if is_home:
		return pos.y >= BOX_BOTTOM_Y_MIN and pos.y <= BOX_BOTTOM_Y_MAX
	else:
		return pos.y >= BOX_TOP_Y_MIN and pos.y <= BOX_TOP_Y_MAX
