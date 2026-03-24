extends CharacterBody2D
## Individual player — handles movement, animation, and actions.
## Uses a colored placeholder sprite until the full animation system is implemented (#25).

var _placeholder_tex: ImageTexture


func _ready() -> void:
	_create_placeholder_sprite()


func _physics_process(_delta: float) -> void:
	pass


## Create a simple colored rectangle as a placeholder sprite.
func _create_placeholder_sprite() -> void:
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	# Default red kit color — will be set per-team in future
	var body_color := Color(0.8, 0.2, 0.1)
	var shorts_color := Color(0.1, 0.1, 0.6)
	var skin_color := Color(0.9, 0.65, 0.45)
	var boot_color := Color(0.0, 0.0, 0.0)

	for x in range(8):
		for y in range(16):
			if y < 3:
				# Head (skin)
				if x >= 2 and x <= 5:
					img.set_pixel(x, y, skin_color)
			elif y < 9:
				# Shirt (kit color)
				if x >= 1 and x <= 6:
					img.set_pixel(x, y, body_color)
			elif y < 11:
				# Shorts
				if x >= 2 and x <= 5:
					img.set_pixel(x, y, shorts_color)
			elif y < 14:
				# Legs (skin)
				if x == 2 or x == 3 or x == 4 or x == 5:
					if x <= 3 or x >= 4:
						img.set_pixel(x, y, skin_color)
			else:
				# Boots
				if x == 2 or x == 3 or x == 4 or x == 5:
					img.set_pixel(x, y, boot_color)

	_placeholder_tex = ImageTexture.create_from_image(img)
	$PlayerSprite.texture = _placeholder_tex
	$PlayerSprite.offset = Vector2(0, -4)  # Center vertically on feet
