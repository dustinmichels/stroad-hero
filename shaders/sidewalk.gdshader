shader_type spatial;

uniform vec3 concrete_base : source_color = vec3(0.74, 0.74, 0.76);
uniform vec3 curb_color : source_color = vec3(0.79, 0.79, 0.81);
uniform vec3 joint_color : source_color = vec3(0.38, 0.38, 0.41);
uniform float slab_length = 1.5;
uniform float joint_width = 0.045;
uniform float roughness_base = 0.72;

varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float wx = world_position.x;
	float wz = world_position.z;
	bool is_top = world_normal.y > 0.6;
	float abs_z = abs(wz);
	bool on_stroad = (abs_z >= 12.8 && abs_z <= 15.0);

	// Transverse expansion joints every slab_length along X
	float dist_x = abs(fract(wx / slab_length + 0.5) - 0.5) * slab_length;

	float dist_z;
	float dist_curb_line = 10.0;
	bool is_curb_band = false;

	if (on_stroad) {
		// Narrow sidewalk: single slab spans full width, no center split
		dist_z = 10.0;
	} else {
		dist_z = abs(fract(wz / slab_length + 0.5) - 0.5) * slab_length;
	}

	float dist_joint = min(dist_x, min(dist_z, dist_curb_line));

	// Screen-space derivative anti-aliasing to eliminate sub-pixel shimmer and moiré at distance
	float half_w = joint_width * 0.5;
	float aa = max(fwidth(dist_joint), 0.002);
	float joint_crevice = 1.0 - smoothstep(half_w - aa, half_w + aa, dist_joint);
	float shoulder = smoothstep(half_w, half_w + aa * 2.0, dist_joint)
		* (1.0 - smoothstep(half_w + aa * 2.0, half_w + aa * 5.0, dist_joint));

	// Clean modular slab color variation (discrete uniform tone per slab, no fractal noise)
	vec3 slab_color;
	if (is_curb_band) {
		float curb_hash = hash(vec2(floor(wx / slab_length), step(0.0, wz) * 5.0 + 1.0));
		slab_color = curb_color * mix(0.98, 1.02, curb_hash);
	} else {
		vec2 slab_cell = vec2(floor(wx / slab_length), step(0.0, wz) * 2.0);
		float slab_hash = hash(slab_cell * 17.17 + vec2(3.1, 9.3));
		float tone_shift = mix(0.97, 1.03, slab_hash);
		vec3 tint = mix(vec3(0.99, 1.00, 1.01), vec3(1.01, 1.00, 0.99), slab_hash);
		slab_color = concrete_base * tone_shift * tint;
	}

	// Apply tooled shoulder highlight (+3% brightness along groove rim)
	vec3 color = mix(slab_color, slab_color * 1.035, shoulder);

	// Apply dark recessed expansion joint
	color = mix(color, joint_color, joint_crevice * 0.85);

	// Clean vertical curb face handling
	if (!is_top) {
		float curb_hash = hash(vec2(floor(wx / slab_length), step(0.0, wz)));
		color = curb_color * 0.93 * mix(0.98, 1.02, curb_hash);
		float aa_x = max(fwidth(dist_x), 0.002);
		float curb_joint = 1.0 - smoothstep(half_w - aa_x, half_w + aa_x, dist_x);
		color = mix(color, joint_color, curb_joint * 0.85);
	}

	// Normal bevel for joint edges (transformed into view space for consistent directional sun relief)
	if (is_top) {
		float x_grad = (fract(wx / slab_length + 0.5) - 0.5);
		float x_slope = -sign(x_grad) * smoothstep(half_w * 2.0, half_w * 0.5, dist_x);
		float z_slope = 0.0;
		if (!on_stroad) {
			float z_grad = (fract(wz / slab_length + 0.5) - 0.5);
			z_slope = -sign(z_grad) * smoothstep(half_w * 2.0, half_w * 0.5, dist_z);
		}
		vec3 n_perturb = vec3(x_slope * 0.35, 0.0, z_slope * 0.35);
		vec3 view_perturb = (VIEW_MATRIX * vec4(n_perturb, 0.0)).xyz;
		NORMAL = normalize(NORMAL + view_perturb);
	}

	ALBEDO = color;
	ROUGHNESS = mix(roughness_base, 0.92, joint_crevice);
	ROUGHNESS = mix(ROUGHNESS, 0.65, shoulder * (1.0 - joint_crevice));
	AO = 1.0 - joint_crevice * 0.55;
	AO_LIGHT_AFFECT = 0.4;
}
