shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.0;
uniform float aspect = 1.777;

void fragment() {
	vec2 p = UV - center;
	p.x *= aspect;
	float d = length(p);
	float hole = smoothstep(radius - 0.05, radius, d);
	float rim = exp(-pow((d - radius) / 0.04, 2.0));
	vec3 light = vec3(1.0, 0.97, 0.88) * rim;
	COLOR = vec4(light, hole);
}
