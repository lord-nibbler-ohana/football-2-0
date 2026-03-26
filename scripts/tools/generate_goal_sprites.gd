extends SceneTree
## Standalone sprite generator for goal rendering.
## Run with: godot --headless --path . --script scripts/tools/generate_goal_sprites.gd
##
## Generates three PNGs in sprites/pitch/:
##   goal_top_a.png  — front posts + crossbar + side netting (top goal view)
##   goal_top_b.png  — back netting strip (depth detail)
##   goal_bottom_new.png — full netting mesh (bottom goal, drawn flipped)
##
## Based on ysoccer goal sprite analysis, scaled from 142px to 84px goal mouth.

# --- Palette (matches ysoccer grayscale tones) ---
const WHITE := Color8(231, 231, 231)
const LIGHT_GRAY := Color8(206, 206, 206)
const MID_GRAY := Color8(173, 173, 173)
const DARK_GRAY := Color8(156, 156, 156)
const SHADOW := Color8(140, 140, 140)
const DARK_SHADOW := Color8(41, 41, 41)
const BLACK := Color8(0, 0, 0)
const TRANSPARENT := Color(0, 0, 0, 0)

# --- Dimensions (scaled for 84px goal mouth) ---
const GOAL_MOUTH_W := 84  # pixels between posts
const POST_W := 2  # post thickness
const SHADOW_W := 1  # shadow thickness
const SPRITE_W := GOAL_MOUTH_W + (POST_W + SHADOW_W + 1) * 2  # ~92px total width
const CROSSBAR_H := 2  # crossbar thickness

# goal_top_a: posts extend ~10px below crossbar, netting fans ~18px above
const TOP_A_NETTING_H := 18  # rows of side netting above crossbar
const TOP_A_POST_H := 10  # rows of posts below crossbar
const TOP_A_H := TOP_A_NETTING_H + CROSSBAR_H + TOP_A_POST_H  # ~30px

# goal_top_b: back netting strip
const TOP_B_W := GOAL_MOUTH_W - 4  # slightly narrower than mouth
const TOP_B_H := 8

# goal_bottom: full netting mesh
const BOTTOM_H := 34
const BOTTOM_W := SPRITE_W


func _init() -> void:
	var dir := DirAccess.open("res://sprites/pitch")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://sprites/pitch")

	_generate_goal_top_a()
	_generate_goal_top_b()
	_generate_goal_bottom()

	print("Goal sprites generated successfully.")
	quit()


## goal_top_a.png — Front posts + crossbar + side netting fans.
## Orientation: as drawn, row 0 is the back of the net (furthest from field).
## In-game this is flipped vertically for the top goal, so posts are closest to field.
func _generate_goal_top_a() -> void:
	var img := Image.create(SPRITE_W, TOP_A_H, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)

	var left_post_x := (SPRITE_W - GOAL_MOUTH_W) / 2 - POST_W  # left edge of left post
	var right_post_x := (SPRITE_W + GOAL_MOUTH_W) / 2  # left edge of right post
	var crossbar_y := TOP_A_NETTING_H  # row where crossbar starts

	# --- Draw posts (below crossbar) ---
	for y in range(crossbar_y, TOP_A_H):
		# Left post
		for x in range(left_post_x, left_post_x + POST_W):
			img.set_pixel(x, y, WHITE)
		# Left post shadow (right side)
		img.set_pixel(left_post_x + POST_W, y, DARK_GRAY)
		img.set_pixel(left_post_x + POST_W + 1, y, DARK_SHADOW)

		# Right post
		for x in range(right_post_x, right_post_x + POST_W):
			img.set_pixel(x, y, WHITE)
		# Right post shadow (right side)
		if right_post_x + POST_W < SPRITE_W:
			img.set_pixel(right_post_x + POST_W, y, DARK_GRAY)
		if right_post_x + POST_W + 1 < SPRITE_W:
			img.set_pixel(right_post_x + POST_W + 1, y, DARK_SHADOW)

	# --- Draw crossbar ---
	for y in range(crossbar_y, crossbar_y + CROSSBAR_H):
		for x in range(left_post_x, right_post_x + POST_W):
			img.set_pixel(x, y, WHITE)
		# Shadow below crossbar
		if y == crossbar_y + CROSSBAR_H - 1:
			for x in range(left_post_x + POST_W, right_post_x):
				if crossbar_y + CROSSBAR_H < TOP_A_H:
					img.set_pixel(x, crossbar_y + CROSSBAR_H, DARK_GRAY)

	# --- Draw side netting (fans from post tops to corners) ---
	# Left side netting: diagonal lines from left post top going left & up
	var left_anchor_x := left_post_x + POST_W - 1
	var right_anchor_x := right_post_x

	for i in range(6):
		# Left side: lines fanning from left post to top-left area
		var target_x: int = maxi(0, left_post_x - TOP_A_NETTING_H + i * 3)
		_draw_line(img, left_anchor_x, crossbar_y, target_x, i * 3, MID_GRAY)

		# Right side: lines fanning from right post to top-right area
		var rtarget_x: int = mini(SPRITE_W - 1, right_anchor_x + TOP_A_NETTING_H - i * 3)
		_draw_line(img, right_anchor_x, crossbar_y, rtarget_x, i * 3, MID_GRAY)

	# Horizontal support bars across the side netting
	for y in range(0, crossbar_y, 4):
		# Left side
		for x in range(0, left_post_x):
			# Only draw if within the netting fan area
			var progress := float(crossbar_y - y) / float(TOP_A_NETTING_H)
			var fan_edge := left_anchor_x - int(progress * TOP_A_NETTING_H)
			if x >= fan_edge:
				img.set_pixel(x, y, MID_GRAY)
		# Right side
		for x in range(right_post_x + POST_W, SPRITE_W):
			var progress := float(crossbar_y - y) / float(TOP_A_NETTING_H)
			var fan_edge := right_anchor_x + int(progress * TOP_A_NETTING_H)
			if x <= fan_edge:
				img.set_pixel(x, y, MID_GRAY)

	# --- Draw top netting between posts (back of net, diamond pattern) ---
	for y in range(0, crossbar_y):
		for x in range(left_post_x + POST_W, right_post_x):
			if (x + y) % 4 == 0 or (x - y) % 4 == 0:
				img.set_pixel(x, y, MID_GRAY)

	img.save_png("res://sprites/pitch/goal_top_a.png")
	print("  Generated goal_top_a.png (%dx%d)" % [SPRITE_W, TOP_A_H])


## goal_top_b.png — Back netting strip (thin horizontal strip behind goal).
func _generate_goal_top_b() -> void:
	var img := Image.create(TOP_B_W, TOP_B_H, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)

	# Diamond/crosshatch netting pattern
	for y in range(TOP_B_H):
		for x in range(TOP_B_W):
			if (x + y) % 4 == 0 or (x - y) % 4 == 0:
				img.set_pixel(x, y, MID_GRAY)

	# Horizontal support bars every 3 rows
	for y in range(0, TOP_B_H, 3):
		for x in range(TOP_B_W):
			img.set_pixel(x, y, MID_GRAY)

	img.save_png("res://sprites/pitch/goal_top_b.png")
	print("  Generated goal_top_b.png (%dx%d)" % [TOP_B_W, TOP_B_H])


## goal_bottom_new.png — Full netting mesh for bottom goal.
## Orientation: row 0 = crossbar (field side), rows increase going behind goal.
## In-game this is flipped vertically for the bottom goal.
func _generate_goal_bottom() -> void:
	var img := Image.create(BOTTOM_W, BOTTOM_H, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)

	var left_post_x := (BOTTOM_W - GOAL_MOUTH_W) / 2 - POST_W
	var right_post_x := (BOTTOM_W + GOAL_MOUTH_W) / 2
	var inner_left := left_post_x + POST_W
	var inner_right := right_post_x

	# --- Row 0-1: Crossbar (solid white bar across top) ---
	for y in range(CROSSBAR_H):
		for x in range(left_post_x, right_post_x + POST_W):
			img.set_pixel(x, y, WHITE)

	# --- Row 2: Light gray border under crossbar ---
	for x in range(left_post_x, right_post_x + POST_W):
		img.set_pixel(x, CROSSBAR_H, LIGHT_GRAY)

	# --- Rows 3+: Posts on sides + netting fill ---
	for y in range(CROSSBAR_H + 1, BOTTOM_H):
		# Left post + shadow
		for x in range(left_post_x, left_post_x + POST_W):
			img.set_pixel(x, y, WHITE)
		img.set_pixel(inner_left, y, DARK_GRAY)
		img.set_pixel(inner_left + 1, y, DARK_GRAY)

		# Right post + shadow
		for x in range(right_post_x, right_post_x + POST_W):
			img.set_pixel(x, y, WHITE)
		if right_post_x + POST_W < BOTTOM_W:
			img.set_pixel(right_post_x + POST_W, y, DARK_GRAY)
		if right_post_x + POST_W + 1 < BOTTOM_W:
			img.set_pixel(right_post_x + POST_W + 1, y, DARK_SHADOW)

		# Left border inside post
		img.set_pixel(left_post_x - 1, y, DARK_GRAY) if left_post_x > 0 else null
		img.set_pixel(left_post_x - 2, y, SHADOW) if left_post_x > 1 else null

	# --- Netting fill: diamond/crosshatch pattern ---
	for y in range(CROSSBAR_H + 1, BOTTOM_H):
		for x in range(inner_left + 2, inner_right):
			if (x + y) % 4 == 0 or (x - y) % 4 == 0:
				img.set_pixel(x, y, MID_GRAY)

	# --- Horizontal support bars every 5 rows ---
	for bar_y in range(CROSSBAR_H + 4, BOTTOM_H, 5):
		for x in range(inner_left + 2, inner_right):
			img.set_pixel(x, bar_y, WHITE)

	# --- Vertical support bars every ~10px ---
	for bar_x in range(inner_left + 8, inner_right, 10):
		for y in range(CROSSBAR_H + 1, BOTTOM_H):
			img.set_pixel(bar_x, y, WHITE)

	# --- Side netting (left and right of posts, subtle) ---
	for y in range(CROSSBAR_H + 1, BOTTOM_H):
		var depth := y - CROSSBAR_H
		# Left side netting: fans out from left post
		var fan_extent := mini(depth, 6)
		for dx in range(1, fan_extent + 1):
			var sx := left_post_x - dx
			if sx >= 0 and (sx + y) % 3 == 0:
				img.set_pixel(sx, y, SHADOW)

		# Right side netting: fans out from right post
		for dx in range(1, fan_extent + 1):
			var sx := right_post_x + POST_W + 1 + dx
			if sx < BOTTOM_W and (sx + y) % 3 == 0:
				img.set_pixel(sx, y, SHADOW)

	# --- Bottom edge (gray border) ---
	for x in range(BOTTOM_W):
		if img.get_pixel(x, BOTTOM_H - 1).a > 0 or \
		   (x >= left_post_x - 6 and x <= right_post_x + POST_W + 6):
			img.set_pixel(x, BOTTOM_H - 1, DARK_GRAY)
			if BOTTOM_H > 1:
				img.set_pixel(x, BOTTOM_H - 2, SHADOW)

	img.save_png("res://sprites/pitch/goal_bottom_new.png")
	print("  Generated goal_bottom_new.png (%dx%d)" % [BOTTOM_W, BOTTOM_H])


## Bresenham line drawing helper.
func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0

	while true:
		if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
			img.set_pixel(x, y, color)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
