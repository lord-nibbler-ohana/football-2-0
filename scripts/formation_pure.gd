class_name FormationPure
extends RefCounted
## Formation data — role definitions and position tables for each formation.
## Pure logic class: no Node or scene tree dependencies.

## Player roles — used by AI for positioning and decision-making.
enum Role {
	GOALKEEPER,
	CENTER_BACK,
	LEFT_BACK,
	RIGHT_BACK,
	SWEEPER,
	LEFT_WING_BACK,
	RIGHT_WING_BACK,
	DEFENSIVE_MID,
	CENTER_MID,
	LEFT_MID,
	RIGHT_MID,
	ATTACKING_MID,
	LEFT_WINGER,
	RIGHT_WINGER,
	CENTER_FORWARD,
	SECOND_STRIKER,
}

## Formation identifiers.
enum Formation {
	F_4_4_2,
	F_4_5_1,
	F_4_3_3,
	F_5_4_1,
}

## Home team formation positions (attacks upward, GK near bottom goal).
## Each formation is an Array of 11 Dictionaries: { "role": Role, "position": Vector2 }.
## Away positions are derived by mirroring Y around pitch center.
const FORMATIONS := {
	Formation.F_4_4_2: [
		{"role": Role.GOALKEEPER, "position": Vector2(300, 660)},
		{"role": Role.LEFT_BACK, "position": Vector2(100, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(230, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(370, 560)},
		{"role": Role.RIGHT_BACK, "position": Vector2(500, 560)},
		{"role": Role.LEFT_MID, "position": Vector2(100, 460)},
		{"role": Role.CENTER_MID, "position": Vector2(230, 460)},
		{"role": Role.CENTER_MID, "position": Vector2(370, 460)},
		{"role": Role.RIGHT_MID, "position": Vector2(500, 460)},
		{"role": Role.CENTER_FORWARD, "position": Vector2(240, 385)},
		{"role": Role.SECOND_STRIKER, "position": Vector2(360, 385)},
	],
	Formation.F_4_5_1: [
		{"role": Role.GOALKEEPER, "position": Vector2(300, 660)},
		{"role": Role.LEFT_BACK, "position": Vector2(100, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(230, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(370, 560)},
		{"role": Role.RIGHT_BACK, "position": Vector2(500, 560)},
		{"role": Role.LEFT_MID, "position": Vector2(100, 450)},
		{"role": Role.CENTER_MID, "position": Vector2(220, 470)},
		{"role": Role.DEFENSIVE_MID, "position": Vector2(300, 490)},
		{"role": Role.CENTER_MID, "position": Vector2(380, 470)},
		{"role": Role.RIGHT_MID, "position": Vector2(500, 450)},
		{"role": Role.CENTER_FORWARD, "position": Vector2(300, 385)},
	],
	Formation.F_4_3_3: [
		{"role": Role.GOALKEEPER, "position": Vector2(300, 660)},
		{"role": Role.LEFT_BACK, "position": Vector2(100, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(230, 560)},
		{"role": Role.CENTER_BACK, "position": Vector2(370, 560)},
		{"role": Role.RIGHT_BACK, "position": Vector2(500, 560)},
		{"role": Role.CENTER_MID, "position": Vector2(200, 465)},
		{"role": Role.CENTER_MID, "position": Vector2(300, 475)},
		{"role": Role.CENTER_MID, "position": Vector2(400, 465)},
		{"role": Role.LEFT_WINGER, "position": Vector2(120, 390)},
		{"role": Role.CENTER_FORWARD, "position": Vector2(300, 385)},
		{"role": Role.RIGHT_WINGER, "position": Vector2(480, 390)},
	],
	Formation.F_5_4_1: [
		{"role": Role.GOALKEEPER, "position": Vector2(300, 660)},
		{"role": Role.LEFT_WING_BACK, "position": Vector2(80, 540)},
		{"role": Role.CENTER_BACK, "position": Vector2(200, 570)},
		{"role": Role.SWEEPER, "position": Vector2(300, 590)},
		{"role": Role.CENTER_BACK, "position": Vector2(400, 570)},
		{"role": Role.RIGHT_WING_BACK, "position": Vector2(520, 540)},
		{"role": Role.LEFT_MID, "position": Vector2(130, 450)},
		{"role": Role.CENTER_MID, "position": Vector2(240, 460)},
		{"role": Role.CENTER_MID, "position": Vector2(360, 460)},
		{"role": Role.RIGHT_MID, "position": Vector2(470, 450)},
		{"role": Role.CENTER_FORWARD, "position": Vector2(300, 385)},
	],
}

## Short display names for each role.
const ROLE_NAMES := {
	Role.GOALKEEPER: "GK",
	Role.CENTER_BACK: "CB",
	Role.LEFT_BACK: "LB",
	Role.RIGHT_BACK: "RB",
	Role.SWEEPER: "SW",
	Role.LEFT_WING_BACK: "LWB",
	Role.RIGHT_WING_BACK: "RWB",
	Role.DEFENSIVE_MID: "DM",
	Role.CENTER_MID: "CM",
	Role.LEFT_MID: "LM",
	Role.RIGHT_MID: "RM",
	Role.ATTACKING_MID: "AM",
	Role.LEFT_WINGER: "LW",
	Role.RIGHT_WINGER: "RW",
	Role.CENTER_FORWARD: "CF",
	Role.SECOND_STRIKER: "SS",
}


## Get home team positions for a formation (11 slots).
static func get_positions(formation: int) -> Array:
	return FORMATIONS[formation]


## Get away team positions (Y-mirrored around pitch center).
static func get_away_positions(formation: int) -> Array:
	var home: Array = FORMATIONS[formation]
	var away: Array = []
	for slot in home:
		away.append({
			"role": slot["role"],
			"position": _mirror_y(slot["position"]),
		})
	return away


## Mirror a position across the horizontal center line.
static func _mirror_y(pos: Vector2) -> Vector2:
	return Vector2(pos.x, PitchGeometry.CENTER_Y * 2.0 - pos.y)


## Returns true if the role is a goalkeeper.
static func is_goalkeeper_role(role: int) -> bool:
	return role == Role.GOALKEEPER


## Get the short display name for a role.
static func role_name(role: int) -> String:
	return ROLE_NAMES.get(role, "??")
