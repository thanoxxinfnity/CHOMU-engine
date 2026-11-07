// CHoMU Ultra - water: two-wave vertex swell, two scrolling detail normal maps, depth-based colour
// (Beer-Lambert absorption from the depth buffer), screen-space refraction, shoreline + crest foam, fresnel.
// Transparent pass (needs the depth + screen textures): Forward+, Mobile and Compatibility (4.3+).
// Use a subdivided PlaneMesh (e.g. 64x64) so the vertex waves have vertices to move.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

group_uniforms colour;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.55, 0.55);
uniform vec3 deep_color : source_color = vec3(0.01, 0.09, 0.16);
uniform float depth_distance = 4.0;     // metres until fully deep colour
uniform float clarity : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.04;

group_uniforms normals;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_tiling = 0.08;
uniform vec2 scroll_a = vec2(0.02, 0.012);
uniform vec2 scroll_b = vec2(-0.015, 0.02);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
uniform float refraction : hint_range(0.0, 0.2) = 0.04;

group_uniforms foam;
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 1.0);
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float foam_distance = 0.8;      // shoreline foam width (metres of water depth)
uniform float foam_tiling = 0.35;
uniform float crest_foam : hint_range(0.0, 1.0) = 0.25;

group_uniforms waves;
uniform float wave_height = 0.15;
uniform float wave_length = 9.0;
uniform float wave_speed = 1.0;
uniform vec2 wave_dir_a = vec2(1.0, 0.2);
uniform vec2 wave_dir_b = vec2(-0.4, 1.0);

group_uniforms fresnel_g;
uniform float fresnel_power = 5.0;
uniform float fresnel_boost : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_pos;
varying float crest;

float wave(vec2 p, vec2 dir, float len, float spd, out vec2 grad) {
	vec2 d = normalize(dir);
	float k = 6.2831853 / len;
	float ph = dot(p, d) * k + TIME * spd * sqrt(9.8 * k);
	grad = d * k * cos(ph);
	return sin(ph);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g1;
	vec2 g2;
	float h1 = wave(wp.xz, wave_dir_a, wave_length, wave_speed, g1);
	float h2 = wave(wp.xz, wave_dir_b, wave_length * 0.61, wave_speed, g2);
	float h = (h1 + h2 * 0.5) * wave_height;
	VERTEX.y += h;
	vec2 grad = (g1 + g2 * 0.5) * wave_height;
	NORMAL = normalize(vec3(-grad.x, 1.0, -grad.y));
	TANGENT = normalize(vec3(1.0, grad.x, 0.0));
	BINORMAL = normalize(vec3(0.0, grad.y, 1.0));
	crest = clamp((h1 + h2 * 0.5) * 0.5 + 0.5, 0.0, 1.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float linear_depth(vec2 suv, mat4 inv_proj) {
	float d = texture(depth_tex, suv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(suv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(suv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 uva = world_pos.xz * normal_tiling + TIME * scroll_a;
	vec2 uvb = world_pos.xz * normal_tiling * 1.37 + TIME * scroll_b;
	vec3 na = texture(normal_a, uva).rgb * 2.0 - 1.0;
	vec3 nb = texture(normal_b, uvb).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3((na.xy + nb.xy) * normal_strength, na.z * nb.z));

	float surf = -VERTEX.z;
	float thick = max(linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX) - surf, 0.0);
	// Refraction: offset scaled by thickness, rejected where the offset sample is in front of the water.
	vec2 ruv = SCREEN_UV + n.xy * refraction * clamp(thick, 0.0, 1.0);
	float rthick = linear_depth(ruv, INV_PROJECTION_MATRIX) - surf;
	if (rthick < 0.0) {
		ruv = SCREEN_UV;
		rthick = thick;
	}
	rthick = max(rthick, 0.0);
	vec3 behind = texture(screen_tex, ruv).rgb;
	float absorb = 1.0 - exp(-rthick / max(depth_distance, 0.01));
	vec3 water = mix(behind * mix(shallow_color, vec3(1.0), clarity * (1.0 - absorb)), deep_color, absorb);
	water = mix(water, shallow_color * 0.6, (1.0 - clarity) * (1.0 - absorb) * 0.5);

	// Foam: shoreline (thin water) + wave crests, broken up by a foam texture.
	float ftex = texture(foam_tex, world_pos.xz * foam_tiling + TIME * 0.03).r;
	float shore = 1.0 - smoothstep(0.0, foam_distance, thick);
	float foam = smoothstep(0.35, 0.75, shore * (0.6 + ftex)) + smoothstep(0.85, 1.0, crest) * crest_foam * ftex;
	foam = clamp(foam, 0.0, 1.0);

	vec3 nrm = normalize(TANGENT * n.x + BINORMAL * n.y + NORMAL * n.z);
	float fres = pow(1.0 - clamp(dot(nrm, VIEW), 0.0, 1.0), fresnel_power);

	// Transmitted (already lit) light goes to EMISSION so it isn't lit twice; the engine adds sky/sun specular.
	ALBEDO = foam_color * foam;
	EMISSION = water * (1.0 - fres) * (1.0 - foam);
	NORMAL = nrm;
	ROUGHNESS = mix(roughness, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 1.0, fresnel_boost);
	ALPHA = 1.0;
}
