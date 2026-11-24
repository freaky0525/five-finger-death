shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_end = 0.09;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float wrist = smoothstep(0.0, fade_end, UV.x);
	COLOR = vec4(color.rgb * tint.rgb, color.a * wrist * tint.a);
}
