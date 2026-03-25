extends CharacterBody2D
## Individual player — handles movement, animation, and actions.

var animation_state: PlayerAnimationPure
var _sprite_frames: SpriteFrames

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_arrow: Polygon2D = $SelectionArrow

## Kit style determines which sprite sheet to use.
enum KitStyle { SOLID, VERTICAL_STRIPES, HORIZONTAL_STRIPES }

var kit_style: KitStyle = KitStyle.SOLID
var kit_primary: Color = Color.RED
var kit_secondary: Color = Color.BLUE

## Movement and control state.
var is_human_controlled: bool = false
var is_selected: bool = false:
	set(value):
		is_selected = value
		if selection_arrow:
			selection_arrow.visible = value
var formation_position: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var has_possession: bool = false

## Reference to the ball node (set by match.gd).
var ball: CharacterBody2D = null

## Movement speed in px/frame at 50 Hz.
const PLAYER_SPEED := 2.0

## Kick speeds in px/frame at 50 Hz.
const KICK_SPEED_SHOT := 6.0

## Sprite sheet paths per kit style.
const SHEET_PATHS := {
	KitStyle.SOLID: "res://sprites/players/player_solid.png",
	KitStyle.VERTICAL_STRIPES: "res://sprites/players/player_vstripes.png",
	KitStyle.HORIZONTAL_STRIPES: "res://sprites/players/player_hstripes.png",
}

## Cell size in the sprite sheet.
const CELL_W := 16
const CELL_H := 16
const SHEET_COLS := 10

## Animation mapping: animation_name -> array of cell indices in the sprite sheet.
const ANIM_MAP := {
	# Running: 2 frames per direction
	"run_s":  [0, 1],
	"run_se": [2, 3],
	"run_e":  [4, 5],
	"run_ne": [6, 7],
	"run_n":  [8, 9],
	# Idle: first frame of each run direction
	"idle_s":  [0],
	"idle_se": [2],
	"idle_e":  [4],
	"idle_ne": [6],
	"idle_n":  [8],
	# Kick: from the wider sprites in top band
	"kick_s":  [14],
	"kick_se": [15],
	"kick_e":  [16],
	"kick_ne": [17],
	"kick_n":  [18],
	# Slide tackle: first 3 sprites from each direction band
	"slide_s":  [20, 21, 22],
	"slide_se": [30, 31, 32],
	"slide_e":  [36, 37, 38],
	"slide_ne": [42, 43, 44],
	"slide_n":  [48, 49, 50],
	# Celebrate and knocked down: use band1 extras
	"celebrate":   [26, 27, 28, 29],
	"knocked_down": [23],
	"getting_up":   [24, 25],
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
}


func _ready() -> void:
	animation_state = PlayerAnimationPure.new()
	_build_sprite_frames()
	_apply_kit_shader()
	anim_sprite.sprite_frames = _sprite_frames
	anim_sprite.play("idle_s")
	# Hide selection arrow by default
	if selection_arrow:
		selection_arrow.visible = is_selected


func _physics_process(_delta: float) -> void:
	if is_selected:
		_handle_human_input()
	else:
		# Non-controlled players stand at formation position (no AI yet)
		velocity = Vector2.ZERO

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
		velocity = input_dir * PLAYER_SPEED * 50.0
		move_and_slide()

	# Kick on space press
	if InputMapper.is_kick_just_pressed() and has_possession and ball:
		_do_kick()


## Perform a kick — send the ball in the facing direction.
func _do_kick() -> void:
	var kick_vel := facing_direction.normalized() * KICK_SPEED_SHOT
	ball.kick(kick_vel, 0.0, self)
	animation_state.trigger_kick()
	has_possession = false


## Get current joystick/keyboard input direction.
## Called by ball.gd for aftertouch after kicking.
func get_joystick_input() -> Vector2:
	if is_selected:
		return InputMapper.get_movement_input()
	return Vector2.ZERO


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
