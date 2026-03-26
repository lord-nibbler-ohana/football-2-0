extends CharacterBody2D
## Individual player — handles movement, animation, and actions.

var animation_state: PlayerAnimationPure
var _sprite_frames: SpriteFrames

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jersey_label: Label = $JerseyLabel

## Kit style determines which sprite sheet to use.
enum KitStyle { SOLID, VERTICAL_STRIPES, HORIZONTAL_STRIPES }

var kit_style: KitStyle = KitStyle.SOLID
var kit_primary: Color = Color.RED
var kit_secondary: Color = Color.BLUE

## Team and role metadata (set by team.gd on spawn).
var team_id: int = 0
var is_goalkeeper: bool = false
var role: int = FormationPure.Role.CENTER_MID

## Jersey number (set by team.gd on spawn).
var jersey_number: int = 0

## Movement and control state.
var is_human_controlled: bool = false
var is_selected: bool = false:
	set(value):
		is_selected = value
		if jersey_label:
			jersey_label.visible = value
var formation_position: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var has_possession: bool = false

## Kick state machine (pure logic).
var kick_state: KickStatePure

## Fire button held flag — used for ball passthrough (ball ignores own team while held).
var fire_held: bool = false

## AI instances (set by match.gd during setup).
var outfield_ai: OutfieldAiPure = null
var goalkeeper_ai: GoalkeeperAiPure = null

## Team side flag (set by team.gd on spawn).
var is_home: bool = true

## Zone lookup data (set by match.gd during setup).
var _zone_targets: Array = []
var _formation_slot: int = 0

## Chaser flag — set each frame by match.gd.
var _is_chaser: bool = false

## Whether a teammate on this team has possession (set by match.gd).
var _teammate_has_ball: bool = false

## Throw-in mode — when true, match.gd handles movement and animation directly.
var throwin_mode: bool = false

## Match-level freeze — when true, player holds position (e.g. during set pieces).
var match_frozen: bool = false

## Post-kick cooldown — prevents immediate re-possession after kicking.
const KICK_COOLDOWN_FRAMES := 15
var kick_cooldown: int = 0

## Loss-of-possession stun — brief stutter when dispossessed (not from kicking).
## Prevents rapid back-and-forth possession ping-pong in AI games.
const LOSS_STUN_FRAMES := 50  ## 1.0s at 50 Hz
const LOSS_STUN_SPEED_FACTOR := 0.25  ## Movement speed multiplier during stun
var loss_stun: int = 0
var _had_possession_last_frame: bool = false

## Reference to the ball node (set by match.gd).
var ball: CharacterBody2D = null

## Reference to all players (set by match.gd for pass targeting).
var all_players_ref: Array = []

## This player's index in all_players_ref (set by match.gd).
var player_index: int = -1

## Movement speed in px/frame at 50 Hz.
const PLAYER_SPEED := 2.0

## Sprite sheet paths per kit style.
const SHEET_PATHS := {
	KitStyle.SOLID: "res://sprites/players/player_solid.png",
	KitStyle.VERTICAL_STRIPES: "res://sprites/players/player_vstripes.png",
	KitStyle.HORIZONTAL_STRIPES: "res://sprites/players/player_hstripes.png",
}

## Cell size in the sprite sheet.
const CELL_W := 16
const CELL_H := 32
const SHEET_COLS := 10

## Animation mapping: animation_name -> array of cell indices in the sprite sheet.
## Packed layout (16×32 cells, 10 cols):
##   0-9:   Running (S, SE, E, NE, N) × 2 frames
##   10-14: Idle (S, SE, E, NE, N)
##   15-19: Kick = idle (S, SE, E, NE, N)
##   20-27: Slide single-frame (S, SE, E, NE, N, W, SW, NW)
##   28-35: Down/knocked (N, S, SE, NE, E, W, SW, NW)
##   36-56: Heading (S, E, W, SW, SE, NW, NE) × 3 frames
##   57-77: Throw-in (S, E, W, SW, SE, NW, NE) × 3 frames
const ANIM_MAP := {
	# Running: 2 frames per direction
	"run_s":  [0, 1],
	"run_se": [2, 3],
	"run_e":  [4, 5],
	"run_ne": [6, 7],
	"run_n":  [8, 9],
	# Idle: 1 frame per direction
	"idle_s":  [10],
	"idle_se": [11],
	"idle_e":  [12],
	"idle_ne": [13],
	"idle_n":  [14],
	# Kick: reuses idle sprites (no separate kick frames in original)
	"kick_s":  [15],
	"kick_se": [16],
	"kick_e":  [17],
	"kick_ne": [18],
	"kick_n":  [19],
	# Slide: single-frame per direction
	"slide_s":  [20],
	"slide_se": [21],
	"slide_e":  [22],
	"slide_ne": [23],
	"slide_n":  [24],
	# Knocked down / getting up / celebrate
	"knocked_down": [28],
	"getting_up":   [28, 29],
	"celebrate":    [10, 14, 12],
	# Heading: 3 frames per direction (7 directions, all explicit)
	"head_s":  [36, 37, 38],
	"head_e":  [39, 40, 41],
	"head_w":  [42, 43, 44],
	"head_sw": [45, 46, 47],
	"head_se": [48, 49, 50],
	"head_nw": [51, 52, 53],
	"head_ne": [54, 55, 56],
	# Throw-in: 3 frames per direction (ball visible on frame 3 only)
	"throwin_s":  [57, 58, 59],
	"throwin_e":  [60, 61, 62],
	"throwin_w":  [63, 64, 65],
	"throwin_sw": [66, 67, 68],
	"throwin_se": [69, 70, 71],
	"throwin_nw": [72, 73, 74],
	"throwin_ne": [75, 76, 77],
}

## Animation speeds (FPS).
const ANIM_SPEEDS := {
	"run": 10.0,
	"idle": 1.0,
	"kick": 8.0,
	"slide": 8.0,
	"celebrate": 6.0,
	"knocked_down": 1.0,
	"getting_up": 6.0,
	"head": 8.0,
	"throwin": 6.0,
}


func _ready() -> void:
	animation_state = PlayerAnimationPure.new()
	kick_state = KickStatePure.new()
	_build_sprite_frames()
	_apply_kit_shader()
	anim_sprite.sprite_frames = _sprite_frames
	anim_sprite.play("idle_s")
	# Set jersey number text and hide by default
	if jersey_label:
		jersey_label.text = str(jersey_number)
		jersey_label.visible = is_selected


func _physics_process(_delta: float) -> void:
	# Tick down kick cooldown
	if kick_cooldown > 0:
		kick_cooldown -= 1

	# Tick down loss-of-possession stun
	if loss_stun > 0:
		loss_stun -= 1

	# Detect dispossession (lost ball without kicking) and apply stun
	if _had_possession_last_frame and not has_possession and kick_cooldown == 0:
		loss_stun = LOSS_STUN_FRAMES
	_had_possession_last_frame = has_possession

	# Throw-in mode: match.gd drives movement and animation, skip everything.
	if throwin_mode:
		# Resolve sprite direction from facing_direction
		var dir := PlayerAnimationPure._velocity_to_direction(facing_direction)
		var ti := PlayerAnimationPure._resolve_throwin_direction(dir)

		if animation_state.state == PlayerAnimationPure.State.THROWING_IN:
			# Full throw animation playing — tick the oneshot timer
			if animation_state._oneshot_timer > 0:
				animation_state._oneshot_timer -= 1
				if animation_state._oneshot_timer <= 0:
					animation_state.state = PlayerAnimationPure.State.IDLE
			var anim_n: String = "throwin_" + ti["name"]
			anim_sprite.flip_h = ti["flip"]
			if _sprite_frames.has_animation(anim_n) and anim_sprite.animation != anim_n:
				anim_sprite.play(anim_n)
		elif velocity.length() > 1.0:
			# Walking to the throw-in spot — show run animation
			animation_state.direction = dir
			var anim_result := animation_state.update(velocity / 50.0)
			anim_sprite.flip_h = anim_result["flip_h"]
			var anim_n: String = anim_result["animation"]
			if _sprite_frames.has_animation(anim_n) and anim_sprite.animation != anim_n:
				anim_sprite.play(anim_n)
		else:
			# Aiming/charging — show first frame of throwin anim, paused
			var anim_n: String = "throwin_" + ti["name"]
			anim_sprite.flip_h = ti["flip"]
			if anim_sprite.animation != anim_n:
				anim_sprite.play(anim_n)
			anim_sprite.stop()
			anim_sprite.frame = 0
		return

	# Match frozen: hold position, show idle in current direction.
	if match_frozen:
		velocity = Vector2.ZERO
		var anim_result := animation_state.update(Vector2.ZERO)
		anim_sprite.flip_h = anim_result["flip_h"]
		var anim_n: String = anim_result["animation"]
		if _sprite_frames.has_animation(anim_n) and anim_sprite.animation != anim_n:
			anim_sprite.play(anim_n)
		return

	if is_selected:
		_handle_human_input()
	else:
		# Reset kick state if deselected mid-kick (e.g., after passing)
		if kick_state.state != KickStatePure.State.IDLE:
			kick_state.reset()
			fire_held = false
		_handle_ai()

	# Update animation from velocity (animation system reads px/frame)
	var result := animation_state.update(velocity / 50.0)
	var anim_name: String = result["animation"]
	var flip: bool = result["flip_h"]

	anim_sprite.flip_h = flip

	if _sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)
	else:
		if anim_sprite.animation != "idle_s":
			anim_sprite.play("idle_s")


## Handle keyboard input for the human-controlled player.
func _handle_human_input() -> void:
	var input_dir := InputMapper.get_movement_input()

	if input_dir != Vector2.ZERO:
		facing_direction = input_dir

	if not animation_state.is_locked():
		# velocity in px/sec for move_and_slide
		var speed_mult := LOSS_STUN_SPEED_FACTOR if loss_stun > 0 else 1.0
		velocity = input_dir * PLAYER_SPEED * speed_mult * 50.0
		move_and_slide()

	# Cancel charge if possession lost
	if kick_state.is_charging() and not has_possession:
		kick_state.reset()
		fire_held = false

	# Kick state machine
	match kick_state.state:
		KickStatePure.State.IDLE:
			if InputMapper.is_kick_just_pressed() and has_possession and ball:
				kick_state.start_charge()
				fire_held = true
		KickStatePure.State.CHARGING:
			# Tick charge while held
			if InputMapper.is_kick_held():
				kick_state.tick_charge()
			# Release on button up — also handle single-frame press where
			# just_released fires same frame as just_pressed (missed by match branch)
			if InputMapper.is_kick_just_released() or not InputMapper.is_kick_held():
				_perform_kick(input_dir)
		KickStatePure.State.AFTERTOUCH:
			kick_state.tick_aftertouch()
			if not InputMapper.is_kick_held():
				fire_held = false


## Perform the kick — delegates to KickStatePure for pass/shot decision.
func _perform_kick(input_dir: Vector2) -> void:
	if not ball:
		return
	var player_infos := _get_all_player_infos()
	var result := kick_state.release(
		input_dir, facing_direction, player_infos,
		global_position, team_id, player_index)
	if result["type"] != "none":
		var kick_spin: float = result.get("spin", 0.0)
		ball.kick(result["velocity"], result["up_velocity"], self, false, kick_spin)
		animation_state.trigger_kick()
		has_possession = false
		kick_cooldown = KICK_COOLDOWN_FRAMES


## Build player info dicts for pass targeting.
func _get_all_player_infos() -> Array:
	var infos: Array = []
	for player in all_players_ref:
		infos.append({
			"position": player.global_position,
			"team_id": player.team_id,
		})
	return infos


## True if fire button is currently held (for ball passthrough).
func is_fire_held() -> bool:
	return fire_held


## True if player just kicked and can't re-possess yet.
func has_kick_cooldown() -> bool:
	return kick_cooldown > 0


## True if player is stunned from losing the ball and can't re-possess yet.
func has_loss_stun() -> bool:
	return loss_stun > 0


## Get current joystick/keyboard input direction.
## Called by ball.gd for aftertouch after kicking.
func get_joystick_input() -> Vector2:
	if is_selected:
		return InputMapper.get_movement_input()
	return Vector2.ZERO


## --- AI Logic ---

## Handle AI-controlled movement and actions.
func _handle_ai() -> void:
	if not ball:
		velocity = Vector2.ZERO
		return

	var context := _build_ai_context()
	var ai_result: Dictionary

	if is_goalkeeper and goalkeeper_ai:
		ai_result = goalkeeper_ai.tick(context)
	elif outfield_ai:
		ai_result = outfield_ai.tick(context)
	else:
		velocity = Vector2.ZERO
		return

	# Apply movement (slowed during loss stun)
	var move_dir: Vector2 = ai_result.get("velocity", Vector2.ZERO)
	var speed_mult := LOSS_STUN_SPEED_FACTOR if loss_stun > 0 else 1.0
	if move_dir.length() > 0.01:
		facing_direction = move_dir.normalized()
		velocity = move_dir.normalized() * PLAYER_SPEED * speed_mult * 50.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# Apply kick action
	var kick_action: String = ai_result.get("kick_action", "none")
	if kick_action != "none" and has_possession and ball:
		_ai_perform_kick(ai_result)


## Build context dictionary for AI tick.
func _build_ai_context() -> Dictionary:
	var attack_dir := Vector2.UP if is_home else Vector2.DOWN
	var opponent_goal_center: Vector2
	var own_goal_center: Vector2
	if is_home:
		opponent_goal_center = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_TOP_Y)
		own_goal_center = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_BOTTOM_Y)
	else:
		opponent_goal_center = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_BOTTOM_Y)
		own_goal_center = Vector2(PitchGeometry.CENTER_X, PitchGeometry.GOAL_TOP_Y)

	# Zone target from precomputed table
	var zone_target := formation_position
	if _zone_targets.size() > 0:
		var zone_idx := ZoneLookupPure.get_zone(ball.global_position, is_home)
		zone_target = ZoneLookupPure.get_target(
			_zone_targets, _formation_slot, zone_idx)

	# Build lightweight player info array for AI decisions
	var player_infos: Array = []
	for p in all_players_ref:
		player_infos.append({
			"position": p.global_position,
			"team_id": p.team_id,
		})

	return {
		"my_position": global_position,
		"my_role": role,
		"my_team_id": team_id,
		"is_home": is_home,
		"has_possession": has_possession,
		"is_chaser": _is_chaser,
		"teammate_has_ball": _teammate_has_ball,
		"ball_position": ball.global_position,
		"ball_velocity": ball.physics.velocity,
		"ball_height": ball.physics.height,
		"zone_target": zone_target,
		"all_players": player_infos,
		"attack_direction": attack_dir,
		"opponent_goal_center": opponent_goal_center,
		"own_goal_center": own_goal_center,
		"player_index": player_index,
	}


## Execute an AI kick using the existing kick state machine.
func _ai_perform_kick(ai_result: Dictionary) -> void:
	if not ball:
		return
	var kick_dir: Vector2 = ai_result.get("kick_direction", facing_direction)
	var charge_frames: int = ai_result.get("kick_charge", 1)

	# Set facing toward kick direction so pass targeting cone is correct
	if kick_dir.length() > 0.01:
		facing_direction = kick_dir.normalized()

	# Simulate the charge
	kick_state.start_charge()
	for i in range(charge_frames):
		kick_state.tick_charge()

	# Release — facing_direction is the cone center for passes,
	# kick_dir is the joystick direction for shots
	var player_infos := _get_all_player_infos()
	var result := kick_state.release(
		kick_dir, facing_direction, player_infos,
		global_position, team_id, player_index)

	if result["type"] != "none":
		var kick_spin: float = result.get("spin", 0.0)
		ball.kick(result["velocity"], result["up_velocity"], self, false, kick_spin)
		animation_state.trigger_kick()
		has_possession = false
		kick_cooldown = KICK_COOLDOWN_FRAMES


## Build SpriteFrames resource from the sprite sheet.
func _build_sprite_frames() -> void:
	_sprite_frames = SpriteFrames.new()

	var sheet_path: String = SHEET_PATHS.get(kit_style, SHEET_PATHS[KitStyle.SOLID])
	var sheet: Texture2D = load(sheet_path)

	# Remove the default animation
	if _sprite_frames.has_animation("default"):
		_sprite_frames.remove_animation("default")

	for anim_name: String in ANIM_MAP:
		var cells: Array = ANIM_MAP[anim_name]
		_sprite_frames.add_animation(anim_name)

		# Determine speed from prefix
		var speed := 8.0
		for prefix: String in ANIM_SPEEDS:
			if anim_name.begins_with(prefix):
				speed = ANIM_SPEEDS[prefix]
				break
		_sprite_frames.set_animation_speed(anim_name, speed)

		# Loop running and idle, one-shot for others
		var should_loop: bool = anim_name.begins_with("run") or anim_name.begins_with("idle")
		_sprite_frames.set_animation_loop(anim_name, should_loop)

		for cell_idx: int in cells:
			var col: int = cell_idx % SHEET_COLS
			var row: int = cell_idx / SHEET_COLS
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				col * CELL_W,
				row * CELL_H,
				CELL_W,
				CELL_H
			)
			_sprite_frames.add_frame(anim_name, atlas)


## Apply the palette swap shader with kit colors.
func _apply_kit_shader() -> void:
	var shader := preload("res://shaders/palette_swap.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("kit_primary", kit_primary)
	mat.set_shader_parameter("kit_secondary", kit_secondary)
	anim_sprite.material = mat


## Set kit colors (called by team.gd before match).
func set_kit(style: KitStyle, primary: Color, secondary: Color) -> void:
	kit_style = style
	kit_primary = primary
	kit_secondary = secondary
	if anim_sprite:
		_build_sprite_frames()
		_apply_kit_shader()
		anim_sprite.sprite_frames = _sprite_frames
