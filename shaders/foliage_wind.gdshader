shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Foliage color and material properties
uniform vec3 albedo_color : source_color = vec3(0.3656, 0.542, 0.3035);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float specular : hint_range(0.0, 1.0) = 0.2;

// Wind simulation uniforms (fed from GameState or defaults)
uniform vec2 wind_direction = vec2(0.978, 0.208);
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform float time_offset = 0.0;

// Sway (macro branch motion) parameters
uniform float sway_amplitude : hint_range(0.0, 0.5) = 0.07;
uniform float sway_frequency : hint_range(0.1, 5.0) = 1.3;

// Rustle / Flutter (micro leaf card motion) parameters
uniform float flutter_amplitude : hint_range(0.0, 0.2) = 0.035;
uniform float flutter_frequency : hint_range(1.0, 16.0) = 6.5;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = (TIME + time_offset) * (0.8 + 0.2 * wind_strength);

	// Normalized horizontal wind vector in world space
	vec2 w_dir = length(wind_direction) > 0.001 ? normalize(wind_direction) : vec2(1.0, 0.0);

	// Transform wind vector to local/model space so rotation doesn't warp wind alignment
	mat3 inv_model = inverse(mat3(MODEL_MATRIX));
	vec3 local_wind_3d = inv_model * vec3(w_dir.x, 0.0, w_dir.y);
	vec2 local_w_dir = length(local_wind_3d.xz) > 0.001 ? normalize(local_wind_3d.xz) : vec2(1.0, 0.0);
	vec2 local_perp = vec2(-local_w_dir.y, local_w_dir.x);

	// Height weighting: lower trunk is rigid, canopy leaf cards (y >= 2.8m) sway and rustle
	float height_factor = clamp((VERTEX.y - 2.8) / 2.6, 0.0, 1.4);
	// Outer branch distance weighting
	float dist_factor = length(VERTEX.xz) * 0.22;
	float branch_weight = height_factor * (0.55 + 0.45 * dist_factor);

	// Macro canopy sway: traveling wave across the world along wind direction
	float spatial_phase = dot(world_pos.xz, w_dir) * 0.28;
	float main_sway = sin(t * sway_frequency + spatial_phase) * sway_amplitude * wind_strength * branch_weight;
	float cross_sway = cos(t * sway_frequency * 1.31 + spatial_phase * 1.4 + world_pos.y * 0.35) * (sway_amplitude * 0.32) * wind_strength * branch_weight;

	// Micro leaf-card flutter (rustle): high-frequency 3D spatial oscillation
	// Each leaf card is at a different world coordinate, giving distinct phase per card cluster
	float leaf_hash = dot(world_pos, vec3(5.17, 8.43, 6.29));
	float flutter_t = t * flutter_frequency;
	float leaf_flutter_1 = sin(flutter_t + leaf_hash) * flutter_amplitude * wind_strength * height_factor;
	float leaf_flutter_2 = cos(flutter_t * 1.37 + leaf_hash * 1.53) * (flutter_amplitude * 0.45) * wind_strength * height_factor;

	// Apply displacement in local coordinates:
	// - Lateral displacement along wind direction and cross-wind
	VERTEX.xz += local_w_dir * (main_sway + leaf_flutter_2 * 0.4) + local_perp * (cross_sway + leaf_flutter_1 * 0.6);
	// - Vertical flutter and subtle wind sag
	VERTEX.y += (leaf_flutter_1 + leaf_flutter_2 * 0.5) - abs(main_sway) * 0.15;

	// Subtle normal perturbation so fluttering leaves catch sunlight / shimmer dynamically
	vec3 local_flutter_norm = vec3(leaf_flutter_1 * local_perp.x, leaf_flutter_2 * 1.5, leaf_flutter_1 * local_perp.y) * 4.0;
	NORMAL = normalize(NORMAL + local_flutter_norm);
}

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
