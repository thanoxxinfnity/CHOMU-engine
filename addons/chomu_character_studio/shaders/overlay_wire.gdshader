// CHoMU Character Studio - edit overlay lines / face tint. Pulled slightly toward the camera.
// (No POINT_SIZE here: the Compatibility renderer draws any shader that writes it as points.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float pull = 0.004;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz *= (1.0 - pull);
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
