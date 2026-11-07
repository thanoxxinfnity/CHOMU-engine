// CHoMU Ultra - full-screen colour grade + sharpen + vignette + film grain + chromatic aberration.
// Used by post/chomu_post_layer.gd on a full-screen ColorRect (CanvasLayer 100).
// Runs after Godot's tonemapper, so it grades the final display-space image (like a LUT in a photo app).
// Cost: 1 screen copy + 5 taps (sharpen) + 2 LUT taps (+2 taps when chromatic aberration > 0).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

group_uniforms lut;
// 2D LUT strip: 16 slices of 16x16 laid out horizontally (256 x 16). Blue picks the slice.
uniform bool use_lut = false;
uniform sampler2D lut_tex : filter_linear, repeat_disable, hint_default_white;
uniform float lut_size = 16.0;
uniform float lut_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms grade;
uniform float exposure : hint_range(-2.0, 2.0) = 0.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec3 lift = vec3(0.0);
uniform vec3 gamma = vec3(1.0);
uniform vec3 gain = vec3(1.0);
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float tint : hint_range(-1.0, 1.0) = 0.0;

group_uniforms detail;
uniform float sharpen : hint_range(0.0, 2.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0;

group_uniforms lens;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.8;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.45;
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float grain_amount : hint_range(0.0, 0.2) = 0.0;
uniform float grain_speed = 24.0;

vec3 apply_lut(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	float n = lut_size;
	float b = c.b * (n - 1.0);
	float s0 = floor(b);
	float s1 = min(s0 + 1.0, n - 1.0);
	float f = b - s0;
	float x = c.r * (n - 1.0) + 0.5;
	float y = (c.g * (n - 1.0) + 0.5) / n;
	vec3 a = texture(lut_tex, vec2((s0 * n + x) / (n * n), y)).rgb;
	vec3 d = texture(lut_tex, vec2((s1 * n + x) / (n * n), y)).rgb;
	return mix(a, d, f);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c;
	if (chromatic_aberration > 0.0) {
		vec2 dir = (uv - 0.5) * chromatic_aberration;
		c.r = texture(screen_tex, uv + dir).r;
		c.g = texture(screen_tex, uv).g;
		c.b = texture(screen_tex, uv - dir).b;
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	if (sharpen > 0.0) {
		vec3 nb = texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
				+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
		c = max(c + (c * 4.0 - nb) * sharpen * 0.25, vec3(0.0));
	}
	// Exposure / white balance
	c *= exp2(exposure);
	c *= vec3(1.0 + temperature * 0.1, 1.0 + tint * 0.1, 1.0 - temperature * 0.1);
	// Lift / gamma / gain
	c = gain * (c + lift * (1.0 - c));
	c = pow(max(c, vec3(0.0)), 1.0 / max(gamma, vec3(0.01)));
	// Contrast around mid-grey, saturation around luma
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	if (use_lut) {
		c = mix(c, apply_lut(c), lut_strength);
	}
	// Vignette
	vec2 vuv = (uv - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float v = smoothstep(vignette_radius, vignette_radius - vignette_softness, length(vuv) * 1.2);
	c = mix(vignette_color, c, mix(1.0, v, vignette_strength));
	// Film grain (luma-weighted so blacks stay clean)
	if (grain_amount > 0.0) {
		float g = hash12(FRAGCOORD.xy + fract(TIME * grain_speed) * 1000.0) - 0.5;
		c += g * grain_amount * (0.35 + 0.65 * (1.0 - l));
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
