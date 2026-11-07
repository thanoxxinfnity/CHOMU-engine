// CHoMU Ultra - foliage (grass, bushes, leaf cards). Alpha-scissor, double-sided, wind sway driven by
// world-space noise (gusts) + sine (flutter), height-weighted so roots stay planted, and a cheap
// subsurface approximation via BACKLIGHT (light through leaves). Works with MultiMeshInstance3D.
// Height weight: UV.y (0 = top of card, 1 = root) by default, or vertex colour red if use_vertex_color_weight.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

group_uniforms look;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 root_color : source_color = vec4(0.16, 0.26, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.55, 0.68, 0.24, 1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform float color_variation : hint_range(0.0, 1.0) = 0.25;
uniform float up_normal_blend : hint_range(0.0, 1.0) = 0.6; // grass looks softer with normals bent upward

group_uniforms subsurface;
uniform vec3 backlight_color : source_color = vec3(0.45, 0.6, 0.15);
uniform float subsurface : hint_range(0.0, 1.0) = 0.6;

group_uniforms wind;
uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength = 0.25;
uniform float wind_speed = 1.2;
uniform float gust_scale = 0.03;    // world-space size of gusts
uniform float flutter = 0.04;       // small fast leaf motion
uniform bool use_vertex_color_weight = false;

varying float v_height;
varying float v_var;

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = use_vertex_color_weight ? COLOR.r : clamp(1.0 - UV.y, 0.0, 1.0);
	v_height = h;
	vec2 wdir = normalize(wind_direction + vec2(0.0001));
	float t = TIME * wind_speed;
	float gust = textureLod(wind_noise, wpos.xz * gust_scale - wdir * t * 0.05, 0.0).r;
	v_var = textureLod(wind_noise, wpos.xz * 0.11, 0.0).r;
	float sway = (gust - 0.35) * 1.6 + sin(t * 1.7 + wpos.x * 0.6 + wpos.z * 0.4) * 0.25;
	float flut = sin(t * 7.0 + (wpos.x + wpos.z) * 3.0) * flutter;
	vec3 offs = vec3(wdir.x, 0.0, wdir.y) * sway * wind_strength + vec3(flut, flut * 0.3, -flut);
	offs *= h * h;
	offs.y -= length(offs.xz) * 0.3; // bend down a little instead of stretching
	// world offset -> local (exact for rotation + uniform scale, which is what instancing uses)
	mat3 m = mat3(MODEL_MATRIX);
	VERTEX += (offs * m) / max(dot(m[0], m[0]), 0.0001);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 col = mix(root_color.rgb, tip_color.rgb, v_height);
	col *= mix(1.0, 0.7 + v_var * 0.6, color_variation);
	ALBEDO = col * tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(n, up_v, up_normal_blend));
	BACKLIGHT = backlight_color * subsurface;
	AO = mix(0.55, 1.0, v_height);
	AO_LIGHT_AFFECT = 0.3;
}
