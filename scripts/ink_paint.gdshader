shader_type canvas_item;
render_mode unshaded;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	// The seeded collision-free splat silhouette defines coverage. Sample the
	// approved paint only for its color; its alpha must not shrink the effect.
	if (UV.x > 0.0) {
		vec3 paint = texture(TEXTURE, UV).rgb;
		COLOR = vec4(mix(vec3(0.012, 0.025, 0.05), paint, 0.70), 1.0) * tint;
	} else {
		COLOR = tint;
	}
}
