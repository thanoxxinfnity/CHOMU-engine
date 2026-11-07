// CHoMU Ultra - procedural lens flare (additive, full screen). Driven by post/lens_flare.gd.
// No textures; a sun glow, a horizontal streak, a halo ring and 4 ghosts mirrored through the screen centre.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 sun_screen = vec2(0.5);
uniform float aspect = 1.7778;
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec3 flare_color : source_color = vec3(1.0, 0.92, 0.8);
uniform float streak = 0.35;

float disc(vec2 p, vec2 c, float r, float soft) {
	return 1.0 - smoothstep(r - soft, r, length(p - c));
}

void fragment() {
	if (intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = SCREEN_UV;
		vec2 a = vec2(aspect, 1.0);
		vec2 s = sun_screen;
		vec2 d = (p - s) * a;
		float r = length(d);
		vec3 col = vec3(0.0);
		col += flare_color * pow(max(0.0, 1.0 - r * 2.2), 6.0) * 0.8;                 // glow
		col += flare_color * exp(-abs(d.y) * 220.0) * exp(-abs(d.x) * 2.5) * streak; // anamorphic streak
		col += vec3(0.5, 0.75, 1.0) * (smoothstep(0.33, 0.35, r) - smoothstep(0.35, 0.37, r)) * 0.08; // halo
		vec2 axis = vec2(0.5) - s;
		col += vec3(0.30, 0.55, 1.00) * disc(p * a, (s + axis * 0.6) * a, 0.035, 0.02) * 0.25;
		col += vec3(0.25, 1.00, 0.70) * disc(p * a, (s + axis * 1.2) * a, 0.060, 0.04) * 0.15;
		col += vec3(1.00, 0.70, 0.25) * disc(p * a, (s + axis * 1.6) * a, 0.020, 0.01) * 0.30;
		col += vec3(0.50, 0.80, 1.00) * disc(p * a, (s + axis * 2.0) * a, 0.090, 0.07) * 0.10;
		COLOR = vec4(col * intensity, 1.0);
	}
}
