shader_type canvas_item;

// 這些 uniform 變數會變成右側 Inspector 的滑桿，可以直接微調
uniform float hue_speed : hint_range(-1.0, 1.0) = 0.05;
uniform float brightness_speed : hint_range(0.0, 5.0) = 1.0;
uniform float brightness_min : hint_range(0.0, 2.0) = 0.8;
uniform float brightness_max : hint_range(0.0, 2.0) = 1.15;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    // COLOR 在 Godot 4 已經包含原圖像素與節點的 Modulate 顏色
    vec4 tex_color = COLOR;
    vec3 hsv = rgb2hsv(tex_color.rgb);

    // 1. 持續循環偏移 Hue（色相）
    hsv.x = fract(hsv.x + TIME * hue_speed);

    // 2. 用正弦波平滑循環改變 Brightness（明度）
    float wave = (sin(TIME * brightness_speed) + 1.0) * 0.5;
    float brightness = mix(brightness_min, brightness_max, wave);
    hsv.z = clamp(hsv.z * brightness, 0.0, 1.0);

    COLOR = vec4(hsv2rgb(hsv), tex_color.a);
}