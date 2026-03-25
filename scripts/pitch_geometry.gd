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
