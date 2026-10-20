shader_type spatial;

uniform vec3 concrete_base : source_color = vec3(0.67, 0.66, 0.65);
uniform vec3 curb_color : source_color = vec3(0.72, 0.71, 0.70);
uniform vec3 joint_color : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 dirt_color : source_color = vec3(0.30, 0.26, 0.22);
uniform vec3 weed_color : source_color = vec3(0.22, 0.40, 0.12);
uniform vec3 weed_color_alt : source_color = vec3(0.44, 0.56, 0.15);
uniform float slab_length = 1.5;
uniform float joint_width = 0.052;
uniform float roughness_base = 0.78;
uniform float crack_frequency : hint_range(0.0, 1.0) = 0.55;
uniform float weed_frequency : hint_range(0.0, 1.0) = 0.60;
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
	float wy = world_position.y;
	float wz = world_position.z;
	bool is_top = world_normal.y > 0.6;
	float abs_z = abs(wz);
	bool on_stroad = (abs_z >= 12.8 && abs_z <= 15.0);

	// Slab cell index and local slab coordinates
	float slab_idx = floor(wx / slab_length);
	float local_x = (fract(wx / slab_length) - 0.5) * slab_length;
	float dist_x = abs(fract(wx / slab_length + 0.5) - 0.5) * slab_length;

	float dist_z;
	if (on_stroad) {
		dist_z = 10.0;
	} else {
		dist_z = abs(fract(wz / slab_length + 0.5) - 0.5) * slab_length;
	}
	float dist_joint = min(dist_x, dist_z);

	// Distances to curb edge (roadside) and back edge (lot/grass side)
	float dist_to_curb = abs(abs_z - 13.0);
	float dist_to_back = abs(abs_z - 14.7);
	float local_z = abs_z - 13.85; // -0.85 at street curb to +0.85 at back edge

	// Slab-level pseudo-random hashes
	vec2 slab_cell = vec2(slab_idx, step(0.0, wz) * 3.0);
	float h0 = hash(slab_cell * 17.17 + vec2(3.1, 9.3));
	float h1 = hash(slab_cell * 31.41 + vec2(7.9, 1.5));
	float h2 = hash(slab_cell * 53.83 + vec2(2.4, 8.7));
	float h3 = hash(slab_cell * 79.19 + vec2(5.2, 4.3));

	// Joint crevice calculation with subtle erosion along edges
	float joint_erode = (noise(vec2(wx * 5.0, wz * 5.0)) - 0.5) * 0.014;
	float half_w = joint_width * 0.5 + joint_erode;
	float aa = max(fwidth(dist_joint), 0.002);
	float joint_crevice = 1.0 - smoothstep(half_w - aa, half_w + aa, dist_joint);
	float shoulder = smoothstep(half_w, half_w + aa * 2.0, dist_joint)
		* (1.0 - smoothstep(half_w + aa * 2.0, half_w + aa * 4.5, dist_joint));

	// Authentic slab-to-slab weathering variation
	vec3 slab_color;
	if (h0 < 0.12) {
		// Mismatched newer replacement slab (paler concrete mix, unweathered)
		slab_color = concrete_base * mix(1.10, 1.18, h1) * vec3(0.98, 1.00, 1.02);
	} else if (h0 > 0.70) {
		// Old heavily weathered slab (darkened, stained with soot and age)
		slab_color = concrete_base * mix(0.76, 0.87, h1) * vec3(1.03, 0.99, 0.93);
	} else {
		// Standard weathered slab with moderate tone and color shift
		float tone_shift = mix(0.88, 1.06, h0);
		vec3 tint = mix(vec3(0.96, 0.98, 1.02), vec3(1.03, 1.00, 0.96), h1);
		slab_color = concrete_base * tone_shift * tint;
	}

	// Surface grime & moisture/weathering stains
	float broad_stain = noise(vec2(wx * 0.28, wz * 0.85)) * 0.65 + noise(vec2(wx * 1.3, wz * 2.4)) * 0.35;
	float stain_mask = smoothstep(0.38, 0.72, broad_stain);
	slab_color = mix(slab_color, slab_color * 0.80, stain_mask * 0.40);

	// Gutter street-splash dirt pooling along curb and back-edge runoff
	if (on_stroad) {
		float curb_splash = (1.0 - smoothstep(0.0, 0.42, dist_to_curb)) * (0.6 + 0.4 * noise(vec2(wx * 1.8, wz * 3.5)));
		float back_runoff = (1.0 - smoothstep(0.0, 0.28, dist_to_back)) * (0.5 + 0.5 * noise(vec2(wx * 1.5, wz * 2.8)));
		slab_color = mix(slab_color, dirt_color, curb_splash * 0.45);
		slab_color = mix(slab_color, dirt_color * 0.9, back_runoff * 0.35);
	}

	// Procedural cracks on neglected slabs (~46% of slabs)
	float crack_fissure = 0.0;
	float crack_margin = 0.0;
	float dist_crack = 10.0;

	if (is_top && on_stroad && h1 < crack_frequency) {
		float jagged = (noise(vec2(wx * 4.5, wz * 7.5)) - 0.5) * 0.16
		             + (noise(vec2(wx * 13.0, wz * 20.0)) - 0.5) * 0.05;

		if (h2 < 0.45) {
			// Diagonal corner fracture (break cutting from joint to curb edge)
			float corner_x = (h3 < 0.5) ? -0.75 : 0.75;
			float dx = abs(local_x - corner_x);
			float dz = dist_to_curb;
			float corner_size = 0.35 + h3 * 0.35;
			dist_crack = abs(dx * 1.1 + dz * 0.95 - corner_size + jagged);
			// Restrict to the corner quadrant
			if (dx + dz > corner_size * 1.45) {
				dist_crack = 10.0;
			}
		} else {
			// Transverse jagged fracture across the slab
			float mid_x = (h3 - 0.5) * 0.65 * slab_length;
			float slope = (h0 - 0.5) * 0.85;
			dist_crack = abs(local_x - (mid_x + slope * local_z) + jagged);
		}

		float c_aa = max(fwidth(dist_crack), 0.003);
		float crack_w = 0.024;
		crack_fissure = 1.0 - smoothstep(crack_w - c_aa, crack_w + c_aa, dist_crack);
		crack_margin = 1.0 - smoothstep(0.0, 0.08, dist_crack);
	}

	// Weeds & crabgrass sprouting out of expansion joints, cracks, and curb gutters
	float weed_mask = 0.0;
	vec3 current_weed = weed_color;
	if (is_top) {
		float weed_cluster = noise(vec2(wx * 1.5 + h0 * 6.0, wz * 1.2));
		if (weed_cluster > (1.0 - weed_frequency)) {
			float leaf_n1 = noise(vec2(wx * 14.0, wz * 20.0));
			float leaf_n2 = noise(vec2(wx * 28.0, wz * 38.0));
			float leaf_shape = smoothstep(0.30, 0.56, leaf_n1 * 0.65 + leaf_n2 * 0.35);

			float joint_reach = 1.0 - smoothstep(0.01, 0.14, dist_joint);
			float crack_reach = (crack_margin > 0.05) ? (1.0 - smoothstep(0.01, 0.12, dist_crack)) : 0.0;
			float curb_reach = (on_stroad) ? (1.0 - smoothstep(0.0, 0.10, dist_to_curb)) : 0.0;
			float crevice_reach = max(joint_reach, max(crack_reach, curb_reach));

			weed_mask = leaf_shape * crevice_reach * smoothstep(1.0 - weed_frequency, (1.0 - weed_frequency) + 0.14, weed_cluster);

			float weed_tone = noise(vec2(wx * 8.0, wz * 8.0));
			current_weed = mix(weed_color, weed_color_alt, weed_tone);
			current_weed = mix(current_weed, vec3(0.58, 0.52, 0.22), step(0.76, leaf_n2));
			// Dandelion flower yellow bloom dots in cluster centers
			if (weed_tone > 0.82 && leaf_n1 > 0.66 && crevice_reach > 0.3) {
				current_weed = vec3(0.96, 0.84, 0.14);
			}
		}
	}

	// Curb edge chipping / broken concrete notches
	float curb_chip = 0.0;
	if (is_top && on_stroad && dist_to_curb < 0.10) {
		float chip_n = noise(vec2(wx * 3.8, 15.0)) * 0.7 + noise(vec2(wx * 15.0, 25.0)) * 0.3;
		curb_chip = smoothstep(0.56, 0.70, chip_n) * (1.0 - smoothstep(0.01, 0.08, dist_to_curb));
	}

	// Spalling / chipped surface patches exposing rough aggregate on older slabs
	float spall_mask = 0.0;
	if (is_top && h2 > 0.60) {
		float spall_n = noise(vec2(wx * 2.8 + h1 * 4.0, wz * 3.6));
		spall_mask = smoothstep(0.64, 0.76, spall_n);
	}
	// Flattened chewing gum spots and dark drops
	float gum_mask = 0.0;
	if (is_top) {
		vec2 gum_cell = floor(vec2(wx * 2.2, wz * 2.6));
		float gh = hash(gum_cell * 21.73 + vec2(4.3, 8.1));
		if (gh > 0.86) {
			vec2 gum_pos = (gum_cell + vec2(hash(gum_cell + 0.2), hash(gum_cell + 0.7))) / vec2(2.2, 2.6);
			float d_gum = length((vec2(wx, wz) - gum_pos) * vec2(1.0, 1.25));
			float g_rad = 0.035 + gh * 0.025;
			float g_aa = max(fwidth(d_gum), 0.003);
			gum_mask = 1.0 - smoothstep(g_rad - g_aa, g_rad + g_aa, d_gum);
		}
	}

	// Base concrete with tooled shoulder
	vec3 color = mix(slab_color, slab_color * 1.025, shoulder);

	// Apply spalling patch
	if (spall_mask > 0.0) {
		float agg_hash = step(0.5, hash(floor(vec2(wx, wz) * 26.0)));
		vec3 spall_col = mix(slab_color * 0.72, vec3(0.38, 0.36, 0.34), agg_hash * 0.4);
		color = mix(color, spall_col, spall_mask * 0.85);
	}

	// Apply chipped curb edge
	if (curb_chip > 0.0) {
		vec3 chip_col = mix(slab_color * 0.65, vec3(0.35, 0.33, 0.30), 0.6);
		color = mix(color, chip_col, curb_chip * 0.90);
	}
	// Apply weathered crack margin
	if (crack_margin > 0.0) {
		color = mix(color, slab_color * 0.70, crack_margin * 0.55);
	}

	// Apply dark recessed expansion joint
	color = mix(color, joint_color, joint_crevice * 0.90);

	// Apply deep crack fissure
	if (crack_fissure > 0.0) {
		vec3 fissure_color = vec3(0.14, 0.13, 0.13);
		color = mix(color, fissure_color, crack_fissure * 0.95);
	}

	// Apply chewing gum spots
	if (gum_mask > 0.0) {
		vec3 gum_col = vec3(0.16, 0.16, 0.17);
		color = mix(color, gum_col, gum_mask * 0.92);
	}

	// Apply weeds & crabgrass
	if (weed_mask > 0.0) {
		color = mix(color, current_weed, weed_mask * 0.95);
	}

	// Vertical curb face weathering (tire scuffs, gutter sludge, joint)
	if (!is_top) {
		float curb_hash = hash(vec2(slab_idx, step(0.0, wz)));
		vec3 base_curb = curb_color * 0.88 * mix(0.92, 1.04, curb_hash);

		// Tire rubber scrub streaks along curb face
		float scrub_n = noise(vec2(wx * 0.75, wy * 16.0));
		float tire_scrub = smoothstep(0.54, 0.78, scrub_n) * smoothstep(0.03, 0.12, wy) * (1.0 - smoothstep(0.20, 0.25, wy));
		vec3 rubber_black = vec3(0.12, 0.12, 0.13);
		base_curb = mix(base_curb, rubber_black, tire_scrub * 0.65);

		// Gutter silt and dirt splash along bottom of curb face
		float gutter_splash = 1.0 - smoothstep(0.0, 0.13, wy);
		base_curb = mix(base_curb, dirt_color * 0.82, gutter_splash * 0.55);

		// Transverse joint on curb face
		float aa_x = max(fwidth(dist_x), 0.002);
		float curb_joint = 1.0 - smoothstep(half_w - aa_x, half_w + aa_x, dist_x);
		color = mix(base_curb, joint_color, curb_joint * 0.88);
	}

	// Normal bevel and slab settling relief
	if (is_top) {
		float x_grad = (fract(wx / slab_length + 0.5) - 0.5);
		float x_slope = -sign(x_grad) * smoothstep(half_w * 2.0, half_w * 0.5, dist_x);
		float z_slope = 0.0;
		if (!on_stroad) {
			float z_grad = (fract(wz / slab_length + 0.5) - 0.5);
			z_slope = -sign(z_grad) * smoothstep(half_w * 2.0, half_w * 0.5, dist_z);
		}

		// Uneven slab settling / trip hazard lip between slabs
		float settle_x = (h0 - 0.5) * 0.12;
		float settle_z = (h2 - 0.5) * 0.08;
		// Lip step discontinuity right along the joint
		float joint_lip = sign(local_x) * (h1 - 0.5) * 0.25 * (1.0 - smoothstep(0.01, 0.08, dist_x));

		// Crack relief
		float crack_relief = -0.35 * crack_fissure;

		// Spalling surface relief
		float spall_relief = spall_mask * (noise(vec2(wx * 20.0, wz * 20.0)) - 0.5) * 0.25;

		// Chipped curb relief
		float chip_relief = -0.30 * curb_chip;

		vec3 n_perturb = vec3(
			x_slope * 0.35 + settle_x + joint_lip,
			0.0,
			z_slope * 0.35 + settle_z + crack_relief + spall_relief + chip_relief
		);
		vec3 view_perturb = (VIEW_MATRIX * vec4(n_perturb, 0.0)).xyz;
		NORMAL = normalize(NORMAL + view_perturb);
	}

	ALBEDO = color;
	float r = roughness_base;
	r = mix(r, 0.94, joint_crevice);
	r = mix(r, 0.96, crack_fissure);
	r = mix(r, 0.92, spall_mask * 0.8);
	r = mix(r, 0.94, curb_chip * 0.9);
	r = mix(r, 0.88, weed_mask);
	r = mix(r, 0.48, gum_mask);
	ROUGHNESS = r;
	AO = 1.0 - (joint_crevice * 0.55 + crack_fissure * 0.65 + curb_chip * 0.4) * 0.5;
	AO_LIGHT_AFFECT = 0.45;
}
