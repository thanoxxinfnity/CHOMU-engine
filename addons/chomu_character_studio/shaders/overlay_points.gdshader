// CHoMU Character Studio - vertex / joint points overlay.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float pull = 0.004;
uniform float point_size = 7.0;

void vertex() {
	POINT_SIZE = point_size;
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz *= (1.0 - pull);
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
