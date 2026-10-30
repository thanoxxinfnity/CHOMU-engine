shader_type sky;
// HDRI day sky blended with a procedural sunset / night sky (stars + moon).
uniform sampler2D hdri : source_color, filter_linear, repeat_enable;
uniform float day = 1.0;            // 0 night .. 1 day
uniform float sunset = 0.0;         // 0..1 warm horizon tint
uniform float hdri_energy = 1.0;
uniform float hdri_rotation = 0.0;
uniform vec3 night_top : source_color = vec3(0.01, 0.015, 0.04);
uniform vec3 night_horizon : source_color = vec3(0.05, 0.06, 0.12);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.45, 0.2);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = EYEDIR;
	float u = atan(dir.x, -dir.z) / (2.0 * PI) + 0.5 + hdri_rotation;
	float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
	vec3 h = texture(hdri, vec2(u, v)).rgb * hdri_energy;
	float up = clamp(dir.y, 0.0, 1.0);
	// below horizon: soft ground haze instead of the HDRI's empty bottom
	if (dir.y < 0.0) {
		h = mix(texture(hdri, vec2(u, 0.499)).rgb * hdri_energy, vec3(0.35, 0.37, 0.4) * hdri_energy, clamp(-dir.y * 4.0, 0.0, 1.0));
	}
	float horizon = pow(1.0 - up, 6.0);
	h = mix(h, h * sunset_color * 1.6, sunset * (0.35 + horizon * 0.65));

	vec3 night = mix(night_horizon, night_top, pow(up, 0.5));
	// stars
	if (AT_CUBEMAP_PASS == false) {
		vec3 sp = floor(dir * 300.0);
		float s = hash(sp);
		night += vec3(smoothstep(0.997, 1.0, s)) * up * 1.4;
	}
	// moon opposite to the sun direction (LIGHT1 is the moon light)
	if (LIGHT1_ENABLED) {
		float md = dot(dir, LIGHT1_DIRECTION);
		night += vec3(0.8, 0.85, 1.0) * smoothstep(0.9993, 0.9996, md) * 2.0;
		night += vec3(0.08, 0.1, 0.16) * pow(max(md, 0.0), 40.0);
	}
	// sun disc (LIGHT0 is the sun)
	vec3 sun = vec3(0.0);
	if (LIGHT0_ENABLED) {
		float sd = dot(dir, LIGHT0_DIRECTION);
		sun = LIGHT0_COLOR * LIGHT0_ENERGY * (smoothstep(0.9990, 0.9995, sd) * 18.0 + pow(max(sd, 0.0), 300.0) * 1.2);
	}
	COLOR = mix(night, h, day) + sun * day;
}
