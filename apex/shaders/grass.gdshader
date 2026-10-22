shader_type spatial;
// Wind-swayed grass blades. Instance colour comes from MultiMesh colours.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_strength = 0.35;
uniform float sway_speed = 1.6;
uniform vec3 base_color : source_color = vec3(0.30, 0.24, 0.10);
uniform vec3 tip_color : source_color = vec3(0.92, 0.78, 0.42);

varying float v_height;
varying vec3 v_tint;

void vertex() {
	v_height = UV.y;
	v_tint = COLOR.rgb;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(world_origin.xz, vec2(0.13, 0.09));
	float gust = sin(TIME * 0.45 + world_origin.x * 0.02) * 0.5 + 0.5;
	float sway = (sin(TIME * sway_speed + phase) * 0.5 + 0.7) * wind_strength * (0.6 + gust * 0.8);
	float bend = UV.y * UV.y;
	// Bend in world space, convert back into model space.
	vec3 offset_world = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * bend;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
	// Up-facing normals make blades light like a soft field instead of flat cards.
	NORMAL = mix(NORMAL, (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.75);
}

void fragment() {
	vec3 col = mix(base_color, tip_color, smoothstep(0.0, 1.0, v_height));
	ALBEDO = col * v_tint;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35, 0.28, 0.1) * v_height;
}
