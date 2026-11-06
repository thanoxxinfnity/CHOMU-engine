// CHoMU Character Studio - inverted-hull outline pass (MIT).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform float outline_width : hint_range(0.0, 0.05) = 0.006;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
