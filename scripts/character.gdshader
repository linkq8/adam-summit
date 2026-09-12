shader_type canvas_item;
render_mode unshaded;
uniform int pack_palette = 0;
uniform bool teal_pack = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Magenta has matched red/blue and little green. Hue distance preserves
	// violet clothing while removing blended magenta along dark hair edges.
	float brightness = max(c.r, max(c.g, c.b));
	float key_distance = length(vec2(c.r - c.b, c.g)) / max(brightness, 0.001);
	float matte = brightness < 0.03 ? 1.0 : smoothstep(0.12, 0.38, key_distance);
	float spill = (1.0 - smoothstep(0.20, 0.42, key_distance)) * min(c.r, c.b);
	c.r -= spill; c.b -= spill;
	if (c.r > 0.3 && abs(c.r - c.b) < 0.12 && c.g < min(c.r, c.b) * 0.65) {
		c.b = min(c.b, c.g + 0.08);
		c.r = min(c.r, c.g + 0.35);
	}
	bool gold = c.r > 0.42 && c.g > 0.30 && c.b < min(c.r, c.g) * 0.60;
	bool teal = c.g > c.r * 1.5 && c.b > c.r * 1.4;
	// Bags and straps occupy the torso band; shoes and hair retain their colors.
	float frame_y = fract(UV.y * 3.0);
	if (pack_palette > 0 && frame_y > 0.32 && frame_y < 0.70 && (teal_pack ? teal : gold)) {
		float light = max(c.r, max(c.g, c.b));
		c.rgb = (pack_palette == 1 ? vec3(1.0, 0.53, 0.39) : vec3(0.74, 0.52, 0.94)) * light;
	}
	COLOR = vec4(c.rgb, c.a * matte) * tint;
}
