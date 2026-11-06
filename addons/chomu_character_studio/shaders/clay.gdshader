// CHoMU Character Studio - sculpt clay / weight preview (MIT). Uses vertex colour when present.
shader_type spatial;
render_mode cull_back;

uniform vec4 clay_color : source_color = vec4(0.47, 0.5, 0.55, 1.0);
uniform bool use_vertex_color = false;

void fragment() {
	vec3 c = use_vertex_color ? COLOR.rgb : clay_color.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	EMISSION = c * 0.05 + vec3(0.2, 0.42, 0.6) * rim * 0.22;
}
