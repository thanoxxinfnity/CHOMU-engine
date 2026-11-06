// CHoMU Character Studio - anime toon shader (MIT). Cel bands + rim + soft specular.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 shade_color : source_color = vec4(0.55, 0.62, 0.78, 1.0);
uniform float bands : hint_range(1.0, 5.0, 1.0) = 2.0;
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.04;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
uniform float rim_width : hint_range(0.0, 1.0) = 0.25;
uniform float specular_size : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec4 t = texture(base_texture, UV) * base_color;
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl);
	if (bands > 1.0) {
		lit = floor(clamp(ndl * 0.5 + 0.5, 0.0, 0.999) * bands) / (bands - 1.0);
		lit = clamp(lit, 0.0, 1.0);
	}
	vec3 shade = mix(shade_color.rgb, vec3(1.0), lit);
	float att = ATTENUATION;
	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR * att / 3.14159;
	vec3 h = normalize(VIEW + LIGHT);
	float spec = step(1.0 - specular_size * 0.2, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * att * 0.25;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.02, rim) * lit;
	DIFFUSE_LIGHT += rim * rim_amount * rim_color.rgb * LIGHT_COLOR * att;
}
