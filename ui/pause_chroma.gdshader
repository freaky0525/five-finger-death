shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0) = 0.14;
uniform float softness : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float luma = (color.r + color.g + color.b) / 3.0;
	float alpha = smoothstep(cutoff, cutoff + softness, luma);
	COLOR = vec4(color.rgb, color.a * alpha);
}
