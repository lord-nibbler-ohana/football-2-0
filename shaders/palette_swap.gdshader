shader_type canvas_item;

// Kit colours — set per team before match
uniform vec4 kit_primary   : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 kit_secondary : source_color = vec4(0.0, 0.0, 1.0, 1.0);

// Marker colours in the base sprite (from original Amiga palette)
const vec3 MARKER_PRIMARY   = vec3(1.0, 0.0, 0.0);  // #FF0000 — kit color A
const vec3 MARKER_SECONDARY = vec3(0.0, 0.0, 1.0);  // #0000FF — kit color B

const float THRESHOLD = 0.05;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);

	if (pixel.a < 0.01) {
		COLOR = pixel;
		return;
	}

	if (distance(pixel.rgb, MARKER_PRIMARY) < THRESHOLD) {
		COLOR = vec4(kit_primary.rgb, pixel.a);
	} else if (distance(pixel.rgb, MARKER_SECONDARY) < THRESHOLD) {
		COLOR = vec4(kit_secondary.rgb, pixel.a);
	} else {
		COLOR = pixel;
	}
}
