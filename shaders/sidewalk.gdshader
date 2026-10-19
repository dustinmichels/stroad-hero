shader_type spatial;

uniform vec3 concrete_base : source_color = vec3(0.72, 0.72, 0.74);
uniform vec3 concrete_dark : source_color = vec3(0.56, 0.56, 0.58);
uniform vec3 concrete_light : source_color = vec3(0.80, 0.80, 0.82);
uniform vec3 joint_color : source_color = vec3(0.25, 0.25, 0.28);
uniform float slab_length = 1.5;
uniform float joint_width = 0.024;
uniform float roughness_base = 0.75;

varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x),
		blend.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float wx = world_position.x;
	float wz = world_position.z;
	vec2 pos = vec2(wx, wz);
	bool is_top = world_normal.y > 0.6;
	float abs_z = abs(wz);
	bool on_stroad = (abs_z >= 7.3 && abs_z <= 10.9);

	float dist_x = abs(fract(wx / slab_length + 0.5) - 0.5) * slab_length;
	float dist_z;
	float dist_curb;
	float curb_grime = 0.0;
	float back_dirt = 0.0;
	float z_offset = 0.0;

	if (on_stroad) {
		z_offset = abs_z - 9.1;
		dist_z = abs(z_offset);
		dist_curb = abs(abs_z - 7.68);
		curb_grime = (1.0 - smoothstep(0.0, 0.35, abs(abs_z - 7.5))) * 0.24;
		back_dirt = (1.0 - smoothstep(0.0, 0.28, abs(abs_z - 10.7))) * 0.18;
	} else {
		dist_z = abs(fract(wz / slab_length + 0.5) - 0.5) * slab_length;
		dist_curb = 10.0;
	}

	float dist_joint = min(dist_x, min(dist_z, dist_curb));

	// Joint crevice profile with tooled rounded shoulder
	float joint_crevice = 1.0 - smoothstep(joint_width * 0.15, joint_width * 0.5, dist_joint);
	float shoulder = smoothstep(joint_width * 0.5, joint_width * 1.0, dist_joint)
		* (1.0 - smoothstep(joint_width * 1.0, joint_width * 2.5, dist_joint));

	// Per-slab variation: discrete index for each poured concrete slab
	vec2 slab_cell = vec2(floor(wx / slab_length), step(0.0, z_offset) + step(0.0, wz) * 2.0);
	float slab_hash = hash(slab_cell * 19.19 + vec2(7.3, 11.1));
	float tone_mult = mix(0.93, 1.05, slab_hash);
	// Occasional newer repoured slab patch (lighter) or weathered older slab (darker)
	float is_new_patch = step(0.90, slab_hash);
	tone_mult = mix(tone_mult, 1.10, is_new_patch);
	float is_old_slab = step(slab_hash, 0.12);
	tone_mult = mix(tone_mult, 0.88, is_old_slab);
	vec3 slab_tint = mix(vec3(0.98, 0.99, 1.02), vec3(1.02, 1.01, 0.97), hash(slab_cell * 7.7 + 3.1));

	// Surface grain, aggregates, and fine texture
	float broad_wear = noise(pos * 0.09 + vec2(13.0, 7.0));
	float mid_wear = noise(pos * 0.55 + vec2(3.0, 19.0));
	float fine_grain = noise(pos * 36.0);
	float micro_tooth = noise(pos * 80.0);

	// Stone aggregates flecked in concrete
	float agg_hash = hash(floor(pos * 24.0));
	float aggregate = step(0.88, agg_hash);
	vec3 agg_color = mix(concrete_base * 0.65, vec3(0.40, 0.39, 0.37), hash(floor(pos * 24.0) + 1.7));

	// Subtle quartz sand shimmer when lit
	float sand_sparkle = step(0.97, hash(floor(pos * 48.0))) * (1.0 - joint_crevice);

	// Chewing gum / dark spots scattered on sidewalk
	vec2 gum_cell = floor(pos * 3.5);
	float gum_rand = hash(gum_cell * 43.17 + 8.1);
	float dist_to_gum = length(fract(pos * 3.5) - vec2(0.5));
	float gum_spot = step(0.982, gum_rand) * (1.0 - smoothstep(0.08, 0.20, dist_to_gum));

	// Hairline crack on occasional weathered slab (~12% of slabs)
	float crack = 0.0;
	if (slab_hash < 0.16) {
		vec2 local;
		local.x = fract((wx + slab_length * 0.5) / slab_length) - 0.5;
		if (on_stroad) {
			local.y = fract(z_offset / 1.6 + 0.5) - 0.5;
		} else {
			local.y = fract(wz / slab_length + 0.5) - 0.5;
		}
		float angle = hash(slab_cell * 5.5) * 3.14159;
		vec2 perp_dir = vec2(-sin(angle), cos(angle));
		float wave = sin(local.x * 20.0 + slab_hash * 10.0) * 0.04;
		float crack_dist = abs(dot(local, perp_dir) + wave);
		float crack_mask = 1.0 - smoothstep(0.002, 0.012, crack_dist);
		float crack_span = 1.0 - smoothstep(0.35, 0.48, length(local));
		crack = crack_mask * crack_span * (1.0 - joint_crevice);
	}

	// Base color assembly
	vec3 color = concrete_base * tone_mult * slab_tint;
	color = mix(color, concrete_dark, broad_wear * 0.15 + mid_wear * 0.09);
	color = mix(color, concrete_light, shoulder * 0.08);
	color = mix(color, agg_color, aggregate * 0.18);
	color *= mix(0.94, 1.04, fine_grain);
	color *= mix(0.97, 1.03, micro_tooth);

	// Apply grime & stains
	color = mix(color, concrete_dark * 0.82, curb_grime + back_dirt);
	color = mix(color, vec3(0.20, 0.20, 0.22), gum_spot * 0.80);
	color = mix(color, joint_color * 0.75, crack * 0.65);

	// Apply expansion joint crevice
	color = mix(color, joint_color, joint_crevice * 0.88);

	// Handle vertical curb and side faces
	if (!is_top) {
		float splash = (1.0 - smoothstep(0.0, 0.18, world_position.y)) * 0.32;
		float vertical_grain = noise(vec2(wx * 24.0, world_position.y * 8.0));
		color = mix(concrete_base * 0.93, concrete_dark * 0.78, splash);
		color *= mix(0.92, 1.05, vertical_grain);
		float curb_joint = 1.0 - smoothstep(joint_width * 0.15, joint_width * 0.5, dist_x);
		color = mix(color, joint_color, curb_joint * 0.85);
	}

	// Normal perturbation for joints and surface relief (converted to view space)
	if (is_top) {
		float x_grad = (fract(wx / slab_length + 0.5) - 0.5);
		float x_slope = -sign(x_grad) * smoothstep(joint_width * 1.6, joint_width * 0.3, dist_x);
		float z_slope = 0.0;
		if (on_stroad) {
			z_slope = -sign(z_offset) * smoothstep(joint_width * 1.6, joint_width * 0.3, dist_z) * sign(wz);
		}
		vec3 n_perturb = vec3(x_slope * 0.42, 0.0, z_slope * 0.42);
		n_perturb.x += (noise(pos * 28.0 + 0.1) - 0.5) * 0.06;
		n_perturb.z += (noise(pos * 28.0 + 5.2) - 0.5) * 0.06;
		vec3 view_perturb = (VIEW_MATRIX * vec4(n_perturb, 0.0)).xyz;
		NORMAL = normalize(NORMAL + view_perturb);
	}

	ALBEDO = color;
	ROUGHNESS = mix(roughness_base, 0.96, joint_crevice);
	ROUGHNESS = mix(ROUGHNESS, 0.62, shoulder * (1.0 - joint_crevice));
	ROUGHNESS = mix(ROUGHNESS, 0.90, curb_grime + back_dirt);
	ROUGHNESS = mix(ROUGHNESS, 0.38, sand_sparkle * 0.6);
	AO = 1.0 - joint_crevice * 0.70 - curb_grime * 0.30 - crack * 0.45;
	AO_LIGHT_AFFECT = 0.55;
}
