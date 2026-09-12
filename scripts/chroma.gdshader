shader_type canvas_item;
render_mode unshaded;
uniform bool magenta_key = false;
uniform int outfit_palette = 0;
uniform int pack_palette = 0;
uniform bool orange_outfit = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dominance = magenta_key ? min(c.r, c.b) - c.g : c.g - max(c.r, c.b);
	float matte = 1.0 - smoothstep(0.17, 0.58, dominance);
	if (!magenta_key) { c.g = min(c.g, max(c.r, c.b) + 0.13); }
	if (!magenta_key && matte > 0.1) {
		bool blue = c.b > c.r * 1.35 && c.g > c.r * 1.25;
		bool gold = c.r > 0.42 && c.g > 0.30 && c.b < min(c.r, c.g) * 0.68;
		float light = max(c.r, max(c.g, c.b));
		if (outfit_palette > 0 && blue) c.rgb = (outfit_palette == 1 ? vec3(0.22, 0.85, 0.53) : vec3(0.65, 0.43, 0.94)) * light;
		if (pack_palette > 0 && (orange_outfit ? blue : gold)) c.rgb = (pack_palette == 1 ? vec3(1.0, 0.53, 0.39) : vec3(0.74, 0.52, 0.94)) * light;
	}
	COLOR = vec4(c.rgb, c.a * matte) * tint;
}
