shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 fence_color : source_color = vec3(0.70, 0.73, 0.76);
uniform vec3 wire_highlight : source_color = vec3(0.85, 0.88, 0.92);
uniform vec3 rust_color : source_color = vec3(0.42, 0.32, 0.24);

uniform float diamond_width = 0.055;
uniform float diamond_height = 0.070;
uniform float wire_thickness = 0.0036;
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float fade_distance_start = 45.0;
uniform float fade_distance_end = 60.0;

varying vec2 fence_coords;
varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	fence_coords = UV;
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = fence_coords;
	float u = p.x / diamond_width + p.y / diamond_height;
	float v = p.x / diamond_width - p.y / diamond_height;

	float grad_len = length(vec2(1.0 / diamond_width, 1.0 / diamond_height));
	float u_idx = floor(u + 0.5);
	float v_idx = floor(v + 0.5);

	float u_fract = fract(u + 0.5) - 0.5;
	float v_fract = fract(v + 0.5) - 0.5;

	float dist_u = abs(u_fract) / grad_len;
	float dist_v = abs(v_fract) / grad_len;

	float r = wire_thickness * 0.5;
	float min_dist = min(dist_u, dist_v);

	// Distance fade: fence only visible as character/camera gets closer to it
	if (fade_distance_end > 0.0) {
		float cam_dist = length(VERTEX);
		if (cam_dist > fade_distance_end) {
			discard;
		}
		if (cam_dist > fade_distance_start) {
			float fade = (cam_dist - fade_distance_start) / (fade_distance_end - fade_distance_start);
			int dither_x = int(FRAGCOORD.x) % 4;
			int dither_y = int(FRAGCOORD.y) % 4;
			int dither_idx = dither_y * 4 + dither_x;
			const float bayer[16] = float[16](
				0.0625, 0.5625, 0.1875, 0.6875,
				0.8125, 0.3125, 0.9375, 0.4375,
				0.2500, 0.7500, 0.1250, 0.6250,
				1.0000, 0.5000, 0.8750, 0.3750
			);
			if (fade > bayer[dither_idx]) {
				discard;
			}
		}
	}

	// Discard outside wire boundaries
	if (min_dist > r) {
		discard;
	}

	// Determine wire weaving: alternate which wire is in front
	float cell_parity = mod(u_idx + v_idx, 2.0);
	bool u_in_front = cell_parity < 0.5;

	bool is_u = false;
	if (dist_u <= r && dist_v <= r) {
		// Both wires overlap at knuckle: choose the one on top
		is_u = u_in_front;
	} else {
		is_u = dist_u < dist_v;
	}

	// Normal calculation for rounded wire cylinder
	vec2 perp_u = normalize(vec2(1.0 / diamond_width, 1.0 / diamond_height));
	vec2 perp_v = normalize(vec2(1.0 / diamond_width, -1.0 / diamond_height));

	float s = is_u ? (u_fract / (grad_len * r)) : (v_fract / (grad_len * r));
	s = clamp(s, -1.0, 1.0);
	float nz = sqrt(max(0.0, 1.0 - s * s));
	vec2 perp = is_u ? perp_u : perp_v;

	vec3 wire_norm = vec3(perp * s, nz);
	if (!FRONT_FACING) {
		wire_norm.z = -wire_norm.z;
	}

	// Convert wire local normal to tangent space normal
	NORMAL = normalize(TANGENT * wire_norm.x + BINORMAL * wire_norm.y + NORMAL * wire_norm.z);

	// Galvanized zinc spangle variation per wire strand
	float wire_seed = is_u ? u_idx : (v_idx + 100.0);
	float spangle = hash(vec2(wire_seed, floor(p.y * 12.0)));
	float subtle_wear = hash(vec2(u_idx, v_idx));

	vec3 albedo = mix(fence_color, wire_highlight, clamp(nz * 0.6 + spangle * 0.25, 0.0, 1.0));

	// Slight crevice grime where wires touch
	if (dist_u <= r && dist_v <= r) {
		float crevice = smoothstep(r * 0.6, 0.0, abs(dist_u - dist_v));
		albedo = mix(albedo, rust_color, crevice * 0.35);
	}

	ALBEDO = albedo;
	METALLIC = metallic * mix(0.9, 1.0, spangle);
	ROUGHNESS = mix(roughness, roughness * 1.3, subtle_wear);
}
