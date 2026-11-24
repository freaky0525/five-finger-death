shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = smoothstep(0.34, 0.98, length(p * vec2(1.18, 1.02)));
	float foot = smoothstep(0.78, 1.0, UV.y);
	COLOR = vec4(0.06, 0.02, 0.0, max(edge * 0.58, foot * 0.42));
}
