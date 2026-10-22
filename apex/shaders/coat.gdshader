shader_type spatial;
// Procedural animal coat: base colour, pale belly, optional spots.
// Works on primitive meshes without UVs by using the body-local position.

uniform vec3 base_color : source_color = vec3(0.85, 0.62, 0.28);
uniform vec3 belly_color : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 spot_color : source_color = vec3(0.12, 0.08, 0.05);
uniform float spot_scale = 7.0;
uniform float spot_amount = 0.0;      // 0 = no spots, ~0.3 = cheetah
uniform float belly_height = 0.55;    // body-local y below which the belly colour fades in
uniform float roughness_val = 0.85;
uniform vec3 stripe_color : source_color = vec3(0.05, 0.05, 0.05);
uniform float stripe_amount = 0.0;    // 0 = none, ~0.5 = zebra
uniform float stripe_scale = 22.0;

varying vec3 v_local;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

float cell_dist(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d = 10.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = hash3(i + g);
		d = min(d, length(g + o - f));
	}
	return d;
}

void vertex() {
	// Model-space position keeps spots stuck to each body part as it moves.
	v_local = VERTEX;
}

void fragment() {
	vec3 col = base_color;
	float belly = smoothstep(belly_height, belly_height - 0.25, v_local.y);
	col = mix(col, belly_color, belly);
	if (spot_amount > 0.0) {
		float d = cell_dist(v_local * spot_scale);
		float spot = 1.0 - smoothstep(spot_amount - 0.05, spot_amount + 0.02, d);
		col = mix(col, spot_color, spot * (1.0 - belly * 0.7));
	}
	if (stripe_amount > 0.0) {
		// Bands across the body, wobbled by a little noise so they don't look ruled.
		float w = sin(v_local.z * stripe_scale + sin(v_local.y * 9.0) * 1.4 + cell_dist(v_local * 3.0) * 2.0);
		float stripe = smoothstep(1.0 - stripe_amount * 2.0, 1.0 - stripe_amount * 2.0 + 0.15, w * 0.5 + 0.5);
		col = mix(col, stripe_color, stripe * (1.0 - belly * 0.4));
	}
	ALBEDO = col;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.25;
}
