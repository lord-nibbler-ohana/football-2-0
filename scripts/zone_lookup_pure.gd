class_name ZoneLookupPure
extends RefCounted
## SWOS-style 35-zone position lookup table.
## Divides the pitch into a 5x7 grid and precomputes a target position
## for each player slot in each zone, based on the formation and role weights.

## Zone grid boundaries (derived from PitchGeometry playing area).
const ZONE_X_MIN := PitchGeometry.SIDELINE_LEFT  # 40
const ZONE_X_MAX := PitchGeometry.SIDELINE_RIGHT  # 560
const ZONE_Y_MIN := PitchGeometry.GOAL_TOP_Y  # 40
const ZONE_Y_MAX := PitchGeometry.GOAL_BOTTOM_Y  # 680

const ZONE_W := (ZONE_X_MAX - ZONE_X_MIN) / float(AiConstants.ZONE_COLS)  # 104
const ZONE_H := (ZONE_Y_MAX - ZONE_Y_MIN) / float(AiConstants.ZONE_ROWS)  # ~91.4


## Get zone index (0..34) for a ball position.
## For home team (attacks upward), row 0 = opponent's goal area (top).
## For away team (attacks downward), rows are flipped so row 0 = their opponent's area (bottom).
static func get_zone(ball_pos: Vector2, is_home: bool) -> int:
	var col := clampi(int((ball_pos.x - ZONE_X_MIN) / ZONE_W), 0, AiConstants.ZONE_COLS - 1)
	var row := clampi(int((ball_pos.y - ZONE_Y_MIN) / ZONE_H), 0, AiConstants.ZONE_ROWS - 1)
	if not is_home:
		row = AiConstants.ZONE_ROWS - 1 - row
	return row * AiConstants.ZONE_COLS + col


## Get the center position of a zone by index.
static func zone_center(zone_idx: int) -> Vector2:
	var col := zone_idx % AiConstants.ZONE_COLS
	var row := zone_idx / AiConstants.ZONE_COLS
	var x := ZONE_X_MIN + (col + 0.5) * ZONE_W
	var y := ZONE_Y_MIN + (row + 0.5) * ZONE_H
	return Vector2(x, y)


## Precompute all target positions for a team's formation.
## formation_slots: Array of 11 {role: int, position: Vector2} from FormationPure.
## is_home: true for home team.
## Returns: flat Array of Vector2, length = 11 * 35.
## Access: targets[player_slot * 35 + zone_index]
static func generate_targets(formation_slots: Array, is_home: bool) -> Array:
	var targets: Array = []
	targets.resize(formation_slots.size() * 35)

	for slot_idx in range(formation_slots.size()):
		var slot: Dictionary = formation_slots[slot_idx]
		var base_pos: Vector2 = slot["position"]
		var role: int = slot["role"]

		var weights: Dictionary = AiConstants.ROLE_SHIFT_WEIGHTS.get(
			role, {"x": 0.3, "y": 0.4})
		var x_weight: float = weights["x"]
		var y_weight: float = weights["y"]

		# Determine Y clamp range based on role and team side
		var y_clamps := _get_y_clamps(role, is_home)
		var y_clamp_min: float = y_clamps.x
		var y_clamp_max: float = y_clamps.y

		for zone_idx in range(35):
			# Zone center in absolute world coordinates
			var zc := zone_center(zone_idx)
			# For away team, the zone centers need to be un-flipped since
			# generate_targets gets called with away positions (already mirrored)
			# but zone_center returns absolute coordinates for row order.
			# The row flip is already handled in get_zone(), so here we just
			# use absolute zone centers directly.

			var x_shift := (zc.x - PitchGeometry.CENTER_X) * x_weight
			var y_shift := (zc.y - PitchGeometry.CENTER_Y) * y_weight

			var target := Vector2(
				base_pos.x + x_shift,
				base_pos.y + y_shift)

			# Clamp to playing area with margin
			target.x = clampf(target.x, ZONE_X_MIN + 5.0, ZONE_X_MAX - 5.0)
			target.y = clampf(target.y, y_clamp_min, y_clamp_max)

			targets[slot_idx * 35 + zone_idx] = target

	return targets


## Look up a single target position.
static func get_target(targets: Array, player_slot: int, zone_idx: int) -> Vector2:
	var idx := player_slot * 35 + zone_idx
	if idx >= 0 and idx < targets.size():
		return targets[idx]
	return PitchGeometry.CENTER


## Determine Y clamp range for a role so players stay in reasonable areas.
## Returns Vector2(y_min, y_max).
static func _get_y_clamps(role: int, is_home: bool) -> Vector2:
	var top := ZONE_Y_MIN + 5.0
	var bottom := ZONE_Y_MAX - 5.0
	var center_y := PitchGeometry.CENTER_Y  # 360

	match role:
		FormationPure.Role.GOALKEEPER:
			if is_home:
				return Vector2(ZONE_Y_MAX - 70.0, ZONE_Y_MAX - 5.0)
			else:
				return Vector2(ZONE_Y_MIN + 5.0, ZONE_Y_MIN + 70.0)
		FormationPure.Role.CENTER_BACK, FormationPure.Role.SWEEPER:
			if is_home:
				return Vector2(center_y - 30.0, bottom)
			else:
				return Vector2(top, center_y + 30.0)
		FormationPure.Role.LEFT_BACK, FormationPure.Role.RIGHT_BACK, \
		FormationPure.Role.LEFT_WING_BACK, FormationPure.Role.RIGHT_WING_BACK:
			if is_home:
				return Vector2(center_y - 80.0, bottom)
			else:
				return Vector2(top, center_y + 80.0)
		FormationPure.Role.DEFENSIVE_MID:
			if is_home:
				return Vector2(center_y - 120.0, bottom - 60.0)
			else:
				return Vector2(top + 60.0, center_y + 120.0)
		FormationPure.Role.CENTER_MID, FormationPure.Role.LEFT_MID, \
		FormationPure.Role.RIGHT_MID:
			return Vector2(top + 60.0, bottom - 60.0)
		FormationPure.Role.ATTACKING_MID:
			if is_home:
				return Vector2(top + 40.0, center_y + 60.0)
			else:
				return Vector2(center_y - 60.0, bottom - 40.0)
		FormationPure.Role.LEFT_WINGER, FormationPure.Role.RIGHT_WINGER, \
		FormationPure.Role.CENTER_FORWARD, FormationPure.Role.SECOND_STRIKER:
			if is_home:
				return Vector2(top + 20.0, center_y + 30.0)
			else:
				return Vector2(center_y - 30.0, bottom - 20.0)

	return Vector2(top, bottom)
