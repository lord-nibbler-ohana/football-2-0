extends Node2D
## Temporary debug scene: displays player sprites from the packed sprite sheet
## grouped by animation type and direction, with animated run pairs and triples.
## Run with:  godot --path . res://scenes/test_sprites.tscn

const SCALE := 4
const PAIR_GAP := 8
const COL_SPACING := 24
const SECTION_GAP := 30

const CELL_W := 16
const CELL_H := 32
const COLS := 10

## Labels for direction pairs: S, SE, E, NE, N
const DIR_LABELS := ["S", "SE", "E", "NE", "N"]

## Labels for heading/throw-in directions (7 directions, all explicit)
const HEAD_THROWIN_DIRS := ["S", "E", "W", "SW", "SE", "NW", "NE"]

var _anim_frame := 0
var _anim_groups: Array = []  # Each entry: Array of Sprite2D nodes (2 or 3 frames)


func _ready() -> void:
	get_window().size = Vector2i(1200, 1400)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var tex: Texture2D = load("res://sprites/players/player_solid.png")

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, 1.0)
	bg.size = Vector2(1200, 1400)
	bg.z_index = -1
	add_child(bg)

	var y := 10

	# --- Running (cells 0-9): animated pairs ---
	_add_label("RUNNING (cells 0-9) — animated", 10, y)
	y += 20
	for i in range(5):
		var c0 := i * 2
		var c1 := c0 + 1
		_add_animated_group(tex, [c0, c1], DIR_LABELS[i], 10 + i * (CELL_W * 2 * SCALE + PAIR_GAP + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Idle (cells 10-14) ---
	_add_label("IDLE (cells 10-14)", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 10 + i, DIR_LABELS[i], 10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Kick (cells 15-19) ---
	_add_label("KICK (cells 15-19) — same as idle", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 15 + i, DIR_LABELS[i], 10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Slides (cells 20-24) ---
	_add_label("SLIDE single-frame (cells 20-24)", 10, y)
	y += 20
	for i in range(5):
		_add_single_sprite(tex, 20 + i, DIR_LABELS[i], 10 + i * (CELL_W * SCALE + COL_SPACING), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Slide tackle 3-frame (cells 25-48) ---
	_add_label("SLIDE TACKLE 3-frame (cells 25+)", 10, y)
	y += 20
	var slide_dirs := ["S", "N", "E", "W", "NE", "SW", "SE", "NW"]
	for d in range(min(4, slide_dirs.size())):
		var base := 25 + d * 6
		for f in range(3):
			var cell := base + f
			if cell < 49:
				_add_single_sprite(tex, cell, slide_dirs[d] + str(f), 10 + (d * 3 + f) * (CELL_W * SCALE + 8), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Heading (cells 36-56): 3-frame animated, 7 directions ---
	_add_label("HEADING (cells 36-56) — 3-frame animated, 7 directions", 10, y)
	y += 20
	for i in range(HEAD_THROWIN_DIRS.size()):
		var base := 36 + i * 3
		var cells := [base, base + 1, base + 2]
		_add_animated_group(tex, cells, HEAD_THROWIN_DIRS[i], 10 + i * (CELL_W * SCALE + COL_SPACING + 16), y)
	y += CELL_H * SCALE + SECTION_GAP

	# --- Throw-in (cells 57-77): 3-frame animated, 7 directions ---
	_add_label("THROW-IN (cells 57-77) — 3-frame, ball visible on frame 3 only", 10, y)
	y += 20
	for i in range(HEAD_THROWIN_DIRS.size()):
		var base := 57 + i * 3
		var cells := [base, base + 1, base + 2]
		_add_animated_group(tex, cells, HEAD_THROWIN_DIRS[i], 10 + i * (CELL_W * SCALE + COL_SPACING + 16), y)
	y += CELL_H * SCALE + SECTION_GAP

	# Timer for animation
	var timer := Timer.new()
	timer.wait_time = 0.3
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


func _add_single_sprite(tex: Texture2D, cell: int, label_text: String, x: int, y: int) -> void:
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


func _add_animated_group(tex: Texture2D, cells: Array, label_text: String, x: int, y: int) -> void:
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
