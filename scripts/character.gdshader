shader_type canvas_item;
render_mode unshaded;
uniform int pack_palette = 0;
uniform bool teal_pack = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	// v9 sheets contain genuine alpha: no chroma key that damages clothing.
	vec4 c = texture(TEXTURE, UV);
	bool gold = c.r > 0.42 && c.g > 0.30 && c.g > c.r * 0.65 && c.b < c.g * 0.35;
	float frame_y = fract(UV.y * 3.0);
	if (pack_palette > 0 && frame_y > 0.32 && frame_y < 0.70 && gold) {
		float light = max(c.r, max(c.g, c.b));
		c.rgb = (pack_palette == 1 ? vec3(1.0, 0.53, 0.39) : vec3(0.74, 0.52, 0.94)) * light;
	}
	COLOR = c * tint;
}
