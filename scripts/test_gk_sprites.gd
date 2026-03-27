extends Node2D
## Test scene: displays goalkeeper sprites from the packed sprite sheet,
## including standard animations and GK-specific catch/dive animations.
## Run with:  godot --path . res://scenes/test_gk_sprites.tscn

const SCALE := 4
const PAIR_GAP := 8
const COL_SPACING := 24
const SECTION_GAP := 30

const CELL_W := 16
const CELL_H := 32
const COLS := 10

const DIR_LABELS := ["S", "SE", "E", "NE", "N"]

var _anim_frame := 0
var _anim_groups: Array = []


func _ready() -> void:
	get_window().size = Vector2i(1200, 1200)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var tex: Texture2D = load("res://sprites/players/goalkeeper.png")

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, 1.0)
	bg.size = Vector2(1200, 1200)
	bg.z_index = -1
	add_child(bg)

	var y := 10

	# --- Running (cells 0-9): animated pairs ---
	_add_label("RUNNING (cells 0-9) -- animated", 10, y)
	y += 20
	for i in range(5):
		var c0 := i * 2
		var c1 := c0 + 1
		_add_animated_group(tex, [c0, c1], DIR_LABELS[i],
			10 + i * (CELL_W * 2 * SCALE + PAIR_GAP + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Idle (cells 10-14) ---
	_add_label("IDLE (cells 10-14)", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 10 + i, DIR_LABELS[i],
			10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Kick (cells 15-19) ---
	_add_label("KICK (cells 15-19)", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 15 + i, DIR_LABELS[i],
			10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Slides (cells 20-24, 5 base directions) ---
	_add_label("SLIDE (cells 20-24)", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 20 + i, DIR_LABELS[i],
			10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Catch North (cells 36-38): 3-frame animated ---
	_add_label("GK CATCH NORTH (cells 36-38) -- 3-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [36, 37, 38], "Catch N", 10, y)
	# Also show individual frames side by side
	for f in range(3):
		_add_single_sprite(tex, 36 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Catch South (cells 39-41): 3-frame animated ---
	_add_label("GK CATCH SOUTH (cells 39-41) -- 3-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [39, 40, 41], "Catch S", 10, y)
	for f in range(3):
		_add_single_sprite(tex, 39 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Dive E facing S (cells 42-47): 6-frame animated ---
	_add_label("GK DIVE EAST facing SOUTH (cells 42-47) -- 6-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [42, 43, 44, 45, 46, 47], "Dive E/S", 10, y)
	for f in range(6):
		_add_single_sprite(tex, 42 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Dive W facing S (cells 48-53): 6-frame animated ---
	_add_label("GK DIVE WEST facing SOUTH (cells 48-53) -- 6-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [48, 49, 50, 51, 52, 53], "Dive W/S", 10, y)
	for f in range(6):
		_add_single_sprite(tex, 48 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Dive E facing N (cells 54-59): 6-frame animated ---
	_add_label("GK DIVE EAST facing NORTH (cells 54-59) -- 6-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [54, 55, 56, 57, 58, 59], "Dive E/N", 10, y)
	for f in range(6):
		_add_single_sprite(tex, 54 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- GK Dive W facing N (cells 60-65): 6-frame animated ---
	_add_label("GK DIVE WEST facing NORTH (cells 60-65) -- 6-frame animated", 10, y)
	y += 20
	_add_animated_group(tex, [60, 61, 62, 63, 64, 65], "Dive W/N", 10, y)
	for f in range(6):
		_add_single_sprite(tex, 60 + f, "f%d" % f,
			200 + f * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# Timer for animation
	var timer := Timer.new()
	timer.wait_time = 0.15
	timer.timeout.connect(_toggle_anim)
	add_child(timer)
	timer.start()


func _cell_region(cell: int) -> Rect2:
	var col := cell % COLS
	var row := cell / COLS
	return Rect2(col * CELL_W, row * CELL_H, CELL_W, CELL_H)


func _add_label(text: String, x: int, y: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 14)
	add_child(lbl)


func _add_single_sprite(tex: Texture2D, cell: int, label_text: String,
		x: int, y: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = _cell_region(cell)
	var spr := Sprite2D.new()
	spr.texture = atlas
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(SCALE, SCALE)
	spr.position = Vector2(x, y)
	add_child(spr)

	var lbl := Label.new()
	lbl.text = "%s [%d]" % [label_text, cell]
	lbl.position = Vector2(x, y + CELL_H * SCALE + 2)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	add_child(lbl)


func _add_animated_group(tex: Texture2D, cells: Array, label_text: String,
		x: int, y: int) -> void:
	var group: Array = []
	for i in range(cells.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = _cell_region(cells[i])
		var spr := Sprite2D.new()
		spr.texture = atlas
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(SCALE, SCALE)
		spr.position = Vector2(x, y)
		spr.visible = (i == 0)
		add_child(spr)
		group.append(spr)
	_anim_groups.append(group)

	var cell_labels := ",".join(cells.map(func(c): return str(c)))
	var lbl := Label.new()
	lbl.text = "%s [%s]" % [label_text, cell_labels]
	lbl.position = Vector2(x, y + CELL_H * SCALE + 2)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	add_child(lbl)


func _toggle_anim() -> void:
	_anim_frame += 1
	for group in _anim_groups:
		var count: int = group.size()
		for i in range(count):
			group[i].visible = (i == _anim_frame % count)


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1
	if Input.is_key_pressed(KEY_UP):
		pan.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		pan.y += 1
	if pan != Vector2.ZERO:
		position -= pan * 300 * delta
