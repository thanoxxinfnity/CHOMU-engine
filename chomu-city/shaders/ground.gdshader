shader_type spatial;
// Procedural city ground: asphalt road grid with lane markings + crosswalks,
// grass outside the city. One draw call for the whole street network.
render_mode cull_back;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cell = 80.0;
uniform float road_half = 7.0;
uniform float city_half = 200.0;
uniform float wetness = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float stripe(float d, float w) {
	float aa = fwidth(d) * 0.75 + 0.001;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 q = p + city_half;
	vec2 m = mod(q + cell * 0.5, cell) - cell * 0.5; // signed distance to nearest grid line
	vec2 d = abs(m);
	bool inside = abs(p.x) < city_half + road_half && abs(p.y) < city_half + road_half;
	bool rx = d.x < road_half && inside; // road running along Z (vertical)
	bool rz = d.y < road_half && inside; // road running along X (horizontal)

	vec3 col;
	float rough = 0.85;
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	if (rx || rz) {
		vec2 uv = p * 0.11;
		col = texture(asphalt_tex, uv).rgb * 0.62;
		nrm = texture(asphalt_nrm, uv).rgb;
		// subtle tyre-track darkening
		float lane_c = rx ? d.x : d.y;
		col *= 1.0 - 0.06 * smoothstep(0.8, 0.0, abs(lane_c - 4.7) - 0.6);
		float mark = 0.0;
		vec3 mcol = vec3(0.92);
		if (!(rx && rz)) {
			float across = rx ? d.x : d.y;     // distance from centre line
			float along = rx ? p.y : p.x;      // coordinate along the road
			float cross_d = rx ? d.y : d.x;    // distance to the crossing road's centre
			float signed_across = rx ? m.x : m.y;
			// double yellow centre line
			float y = stripe(abs(across - 0.0) , 0.07) * 0.0 + stripe(abs(across - 0.16), 0.06);
			if (y > 0.0) { mark = y; mcol = vec3(0.95, 0.72, 0.12); }
			// dashed white lane divider
			float dash = step(mod(along, 9.0), 4.5);
			mark = max(mark, stripe(abs(across - 3.2), 0.07) * dash);
			// solid edge line
			mark = max(mark, stripe(abs(across - 6.55), 0.08));
			// zebra crosswalk + stop line right before the intersection
			if (cross_d > road_half + 0.6 && cross_d < road_half + 3.6 && across < 6.3) {
				float z = step(mod(signed_across + 50.0, 1.3), 0.65);
				mark = max(mark, z);
			}
			if (abs(cross_d - (road_half + 4.3)) < 0.18 && across < 6.3) {
				mark = max(mark, 1.0);
			}
		}
		col = mix(col, mcol, clamp(mark, 0.0, 1.0) * 0.9);
		rough = mix(0.82, 0.6, mark);
		rough = mix(rough, 0.15, wetness);
	} else {
		col = texture(grass_tex, p * 0.07).rgb * 0.85;
		rough = 0.95;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.6;
	SPECULAR = 0.4;
}
