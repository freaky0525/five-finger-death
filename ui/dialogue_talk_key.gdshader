shader_type canvas_item;

uniform float black_threshold : hint_range(0.0, 0.5, 0.01) = 0.12;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float brightness = max(max(col.r, col.g), col.b);
	if (brightness < black_threshold) {
		discard;
	}
	COLOR = col;
}
