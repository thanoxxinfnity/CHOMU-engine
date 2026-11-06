shader_type canvas_item;
// CHoMU stress post-FX: vignette + radial chromatic aberration + film grain.
// Colours stay neutral (black vignette) - no tinting.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette : hint_range(0.0, 1.5) = 0.3;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;
uniform float aberration : hint_range(0.0, 0.02) = 0.0;
uniform float grain : hint_range(0.0, 0.2) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * aberration * (0.5 + r2 * 4.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);
	float v = smoothstep(0.75, 0.75 - vignette_softness, sqrt(r2) * (0.9 + vignette));
	col *= mix(1.0, v, clamp(vignette, 0.0, 1.0));
	col += (hash(uv * 1000.0 + TIME) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
