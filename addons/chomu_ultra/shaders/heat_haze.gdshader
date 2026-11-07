// CHoMU Ultra - heat haze (optional). Put on a QuadMesh / billboard above fire, exhausts or hot ground.
// Distorts what is behind it using the screen texture, fading at the quad edges. Transparent pass.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D distortion_noise : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float strength : hint_range(0.0, 0.05) = 0.012;
uniform float speed = 0.6;
uniform float noise_tiling = 1.5;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 n = texture(distortion_noise, UV * noise_tiling + vec2(0.0, -TIME * speed)).rg - 0.5;
	vec2 e = UV * (1.0 - UV) * 4.0;
	float mask = clamp(e.x * e.y, 0.0, 1.0);
	mask *= smoothstep(0.0, 0.4, 1.0 - UV.y); // stronger near the bottom (heat source)
	ALBEDO = texture(screen_tex, SCREEN_UV + n * strength * mask).rgb;
	ALPHA = mask;
}
