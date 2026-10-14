shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.035, 0.145, 0.07, 0.94);
uniform vec4 line_color : source_color = vec4(0.22, 0.42, 0.24, 0.35);

void fragment() {
	float gx = step(0.96, fract(UV.x * 48.0));
	float gy = step(0.96, fract(UV.y * 27.0));
	COLOR = mix(bg_color, line_color, max(gx, gy));
}
