// CHoMU Ultra - sky: analytic atmosphere (Rayleigh-style zenith/horizon gradient + Mie sun glow),
// sun disk from the first DirectionalLight3D, soft horizon haze, ground colour and optional 2D clouds.
// Deliberately does NOT use TIME: a sky that uses TIME re-renders its radiance map every frame (expensive on
// phones). Animate clouds by changing `cloud_offset` from a script only if you can afford it (PC).
shader_type sky;

group_uniforms atmosphere;
uniform vec3 zenith_color : source_color = vec3(0.16, 0.36, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.76, 0.92);
uniform vec3 ground_color : source_color = vec3(0.24, 0.24, 0.22);
uniform float horizon_sharpness = 3.0;
uniform float sky_energy = 1.0;
uniform float sunset_tint : hint_range(0.0, 1.0) = 0.6;  // warms the horizon as the sun gets low

group_uniforms sun;
uniform float sun_size_deg = 0.9;
uniform float sun_softness = 0.25;
uniform float sun_disk_energy = 12.0;
uniform float mie_strength = 0.35;
uniform float mie_g : hint_range(0.0, 0.99) = 0.76;

group_uniforms clouds;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.25;
uniform float cloud_scale = 0.35;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.55, 0.6, 0.7);

float hg_phase(float mu, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (12.566371 * pow(max(1.0 + g2 - 2.0 * g * mu, 0.0001), 1.5));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.3, 0.6, -0.7));
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(1.0);
	float sun_h = clamp(sun_dir.y, -0.2, 1.0);
	float mu = dot(dir, sun_dir);

	// Sky gradient
	float h = max(dir.y, 0.0);
	float t = pow(1.0 - h, horizon_sharpness);
	vec3 hz = mix(horizon_color, horizon_color * vec3(1.25, 0.85, 0.6), sunset_tint * (1.0 - smoothstep(0.0, 0.35, sun_h)));
	vec3 col = mix(zenith_color, hz, t);
	col *= mix(0.15, 1.0, smoothstep(-0.15, 0.2, sun_h)); // night darkening
	// Rayleigh-ish brightening opposite and around the sun, Mie forward glow
	col *= 1.0 + 0.25 * (1.0 + mu * mu) * 0.5;
	col += sun_col * hg_phase(mu, mie_g) * mie_strength * (0.5 + t);

	// Clouds (planar projection), skipped below horizon
	if (dir.y > 0.0) {
		vec2 cuv = dir.xz / (dir.y + 0.12) * cloud_scale + cloud_offset;
		float n = texture(cloud_tex, cuv).r;
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		c *= smoothstep(0.0, 0.12, dir.y);
		float lit = clamp(0.5 + 0.5 * mu, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow_color, cloud_color, lit) * mix(0.3, 1.0, smoothstep(-0.1, 0.25, sun_h));
		cc += sun_col * hg_phase(mu, 0.6) * 0.4;
		col = mix(col, cc, c);
	}

	// Ground
	float below = smoothstep(0.0, -0.06, dir.y);
	col = mix(col, ground_color * mix(0.2, 1.0, smoothstep(-0.1, 0.3, sun_h)), below);

	// Sun disk (kept out of the radiance cubemap; the light itself provides the specular highlight)
	if (!AT_CUBEMAP_PASS) {
		float cs = cos(radians(sun_size_deg));
		float disk = smoothstep(cs - (1.0 - cs) * sun_softness * 4.0, cs, mu) * (1.0 - below);
		col += sun_col * disk * sun_disk_energy;
	}
	COLOR = col * sky_energy;
}
