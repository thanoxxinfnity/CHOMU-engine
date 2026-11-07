// CHoMU Ultra - terrain: 3 layers (grass / rock / sand) blended by slope, height and noise.
// Rock is triplanar (no stretching on cliffs); grass and sand are top-down planar (cheaper).
// Normal maps use a world-space whiteout blend, so no mesh tangents are needed.
// Optional vertex height from a heightmap (height_scale > 0) for flat PlaneMesh terrain.
// Cost: up to 10 texture samples per pixel. Set rock_triplanar = false on Low to use 6.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms grass;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 grass_tint : source_color = vec4(0.30, 0.42, 0.14, 1.0);
uniform float grass_tiling = 0.25;
uniform float grass_roughness = 0.85;

group_uniforms rock;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 rock_tint : source_color = vec4(0.42, 0.40, 0.37, 1.0);
uniform float rock_tiling = 0.12;
uniform float rock_roughness = 0.7;
uniform bool rock_triplanar = true;

group_uniforms sand;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 sand_tint : source_color = vec4(0.62, 0.55, 0.40, 1.0);
uniform float sand_tiling = 0.3;
uniform float sand_roughness = 0.9;

group_uniforms blending;
uniform float slope_start : hint_range(0.0, 1.0) = 0.82;   // world normal.y where rock begins
uniform float slope_end : hint_range(0.0, 1.0) = 0.65;     // fully rock below this
uniform float sand_height = 0.8;                            // world Y below which sand appears
uniform float sand_blend = 0.8;
uniform float triplanar_sharpness = 4.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float macro_tiling = 0.02;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.35;
uniform float wet_shore : hint_range(0.0, 1.0) = 0.5;      // darken + gloss just above the waterline
uniform float water_level = 0.0;

group_uniforms height;
uniform sampler2D height_map : filter_linear, repeat_disable, hint_default_black;
uniform float height_scale = 0.0;
uniform float height_offset = 0.0;
uniform float height_world_size = 128.0;

varying vec3 wpos;
varying vec3 wnrm;

float hsample(vec2 xz) {
	return textureLod(height_map, xz / height_world_size + 0.5, 0.0).r * height_scale + height_offset;
}

void vertex() {
	if (height_scale > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float e = height_world_size / 256.0;
		VERTEX.y += hsample(wp.xz);
		float hl = hsample(wp.xz - vec2(e, 0.0));
		float hr = hsample(wp.xz + vec2(e, 0.0));
		float hd = hsample(wp.xz - vec2(0.0, e));
		float hu = hsample(wp.xz + vec2(0.0, e));
		NORMAL = normalize(vec3(hl - hr, 2.0 * e, hd - hu));
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Whiteout blend of a tangent-space normal sampled on the XZ plane onto the world normal.
vec3 top_normal(sampler2D tex, vec2 uv, vec3 n) {
	vec3 t = texture(tex, uv).rgb * 2.0 - 1.0;
	t.xy *= normal_strength;
	return normalize(vec3(t.x + n.x, abs(t.z) * n.y, t.y + n.z));
}

void fragment() {
	vec3 n = normalize(wnrm);
	// --- grass + sand (planar)
	vec2 guv = wpos.xz * grass_tiling;
	vec2 suv = wpos.xz * sand_tiling;
	vec3 g_alb = texture(grass_albedo, guv).rgb * grass_tint.rgb;
	vec3 s_alb = texture(sand_albedo, suv).rgb * sand_tint.rgb;
	vec3 g_n = top_normal(grass_normal, guv, n);
	vec3 s_n = top_normal(sand_normal, suv, n);
	// --- rock (triplanar or planar)
	vec3 r_alb;
	vec3 r_n;
	if (rock_triplanar) {
		vec3 w = pow(abs(n), vec3(triplanar_sharpness));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec2 uvx = wpos.zy * rock_tiling;
		vec2 uvy = wpos.xz * rock_tiling;
		vec2 uvz = wpos.xy * rock_tiling;
		r_alb = (texture(rock_albedo, uvx).rgb * w.x + texture(rock_albedo, uvy).rgb * w.y + texture(rock_albedo, uvz).rgb * w.z) * rock_tint.rgb;
		vec3 tx = texture(rock_normal, uvx).rgb * 2.0 - 1.0;
		vec3 ty = texture(rock_normal, uvy).rgb * 2.0 - 1.0;
		vec3 tz = texture(rock_normal, uvz).rgb * 2.0 - 1.0;
		tx.xy *= normal_strength;
		ty.xy *= normal_strength;
		tz.xy *= normal_strength;
		// Whiteout triplanar (Ben Golus)
		tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
		ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
		tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
		r_n = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
	} else {
		vec2 ruv = wpos.xz * rock_tiling;
		r_alb = texture(rock_albedo, ruv).rgb * rock_tint.rgb;
		r_n = top_normal(rock_normal, ruv, n);
	}
	// --- masks
	float macro = texture(macro_noise, wpos.xz * macro_tiling).r;
	float rock_m = 1.0 - smoothstep(slope_end, slope_start, n.y + (macro - 0.5) * 0.08);
	float sand_m = 1.0 - smoothstep(sand_height, sand_height + sand_blend, wpos.y + (macro - 0.5) * 0.6);
	sand_m *= 1.0 - rock_m;
	float grass_m = clamp(1.0 - rock_m - sand_m, 0.0, 1.0);

	vec3 alb = g_alb * grass_m + r_alb * rock_m + s_alb * sand_m;
	alb *= mix(1.0, 0.75 + macro * 0.5, macro_variation);
	float rough = grass_roughness * grass_m + rock_roughness * rock_m + sand_roughness * sand_m;
	vec3 nw = normalize(g_n * grass_m + r_n * rock_m + s_n * sand_m);

	// Wet band just above the water line
	float wet = (1.0 - smoothstep(water_level, water_level + 0.6, wpos.y)) * wet_shore;
	alb *= 1.0 - wet * 0.4;
	rough = mix(rough, 0.25, wet);

	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
