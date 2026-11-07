// CHoMU Ultra - hero PBR material: albedo + ORM (AO/Roughness/Metal) + normal + tiling detail normal,
// rain wetness (darker porous albedo, glossy roughness, flat puddles on up-facing surfaces), emission and rim.
// Works on Forward+, Mobile and Compatibility. ~6 texture samples.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
// ORM packed: R = ambient occlusion, G = roughness, B = metallic (glTF / Unreal convention)
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

group_uniforms normals;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D detail_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_tiling = 8.0;
uniform float detail_strength : hint_range(0.0, 2.0) = 0.5;
uniform float detail_fade_distance = 25.0; // detail normal fades out with distance (saves shimmer)

group_uniforms wetness;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float porosity : hint_range(0.0, 1.0) = 0.6;      // how much albedo darkens when wet
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D puddle_noise : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float puddle_scale = 0.25;                        // world-space tiling of the puddle mask

group_uniforms emission_rim;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec3 emission_color : source_color = vec3(1.0);
uniform float emission_energy = 0.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec4 alb = texture(albedo_tex, uv) * albedo_color;
	vec3 orm = texture(orm_tex, uv).rgb;
	float rough = orm.g * roughness;
	float metal = orm.b * metallic;

	vec3 n1 = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	n1.xy *= normal_strength;
	float dist = length(VERTEX);
	float dfade = 1.0 - smoothstep(detail_fade_distance * 0.6, detail_fade_distance, dist);
	vec3 n2 = texture(detail_normal_tex, uv * detail_tiling).rgb * 2.0 - 1.0;
	n2.xy *= detail_strength * dfade;
	// Whiteout blend of base + detail tangent-space normals
	vec3 n = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));

	// Wetness: up-facing surfaces collect water; puddles flatten the normal and become mirror-like.
	float up = clamp(world_normal.y, 0.0, 1.0);
	float wet = wetness * mix(0.6, 1.0, up);
	float puddle = 0.0;
	if (puddle_amount > 0.0) {
		float pn = texture(puddle_noise, world_pos.xz * puddle_scale).r;
		puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.12, pn) * smoothstep(0.85, 0.97, up) * wetness;
	}
	alb.rgb *= mix(1.0, 1.0 - porosity * 0.55, wet * (1.0 - metal));
	rough = mix(rough, 0.08, wet * 0.85);
	rough = mix(rough, 0.02, puddle);
	n = normalize(mix(n, vec3(0.0, 0.0, 1.0), max(wet * 0.35, puddle)));

	ALBEDO = alb.rgb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(specular, 0.6, wet);
	AO = mix(1.0, orm.r, ao_strength);
	AO_LIGHT_AFFECT = 0.25;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	vec3 em = texture(emission_tex, uv).rgb * emission_color * emission_energy;
	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * rim_strength;
		em += mix(vec3(1.0), alb.rgb, rim_tint) * rim;
	}
	EMISSION = em;
}
