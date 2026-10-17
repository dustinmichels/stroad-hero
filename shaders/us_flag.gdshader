shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Wave animation parameters
uniform float wave_amplitude : hint_range(0.0, 0.6) = 0.14;
uniform float wave_frequency : hint_range(0.5, 10.0) = 3.8;
uniform float wave_speed : hint_range(0.5, 12.0) = 4.2;
uniform float flag_width = 2.47;
uniform float flag_height = 1.30;
uniform float time_offset = 0.0;
uniform vec2 wind_direction = vec2(0.978, 0.208);
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;

// Flag colors (Official US Flag / Old Glory specs)
uniform vec3 red_color : source_color = vec3(0.698, 0.133, 0.204);
uniform vec3 white_color : source_color = vec3(0.97, 0.97, 0.98);
uniform vec3 blue_color : source_color = vec3(0.08, 0.14, 0.36);

varying vec3 v_world_pos;

float get_displacement(vec2 uv, float t, vec3 w_pos) {
	// Firmly attached at pole (uv.x = 0), increasing amplitude toward fly (uv.x = 1)
	float x = clamp(uv.x, 0.0, 1.0);
	float wave_factor = pow(x, 1.25);
	
	// Spatial wind wave propagation across the map aligned with wind direction
	vec2 w_dir = length(wind_direction) > 0.001 ? normalize(wind_direction) : vec2(1.0, 0.0);
	float spatial_phase = dot(w_pos.xz, w_dir) * 0.22;
	
	// Primary traveling wave from pole to fly
	float w1 = sin(x * wave_frequency - t * wave_speed + spatial_phase);
	// Secondary harmonic with diagonal wave crests (cloth folds)
	float w2 = sin((x * 2.1 + uv.y * 1.3) * wave_frequency * 0.7 - t * wave_speed * 1.35 + spatial_phase * 1.4) * 0.38;
	// Fast trailing-edge flutter
	float w3 = sin((x * 4.2 - uv.y * 2.1) * wave_frequency * 0.5 - t * wave_speed * 2.2) * (0.16 * smoothstep(0.25, 1.0, x));
	
	return (w1 + w2 + w3) * (wave_amplitude * (0.85 + 0.15 * wind_strength)) * wave_factor;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = (TIME + time_offset) * (0.85 + 0.15 * wind_strength);
	
	float d0 = get_displacement(UV, t, v_world_pos);
	
	// Finite differences for dynamic normal calculation
	float eps_x = 0.025;
	float eps_y = 0.025;
	float dx = get_displacement(vec2(UV.x + eps_x, UV.y), t, v_world_pos) - d0;
	float dy = get_displacement(vec2(UV.x, UV.y + eps_y), t, v_world_pos) - d0;
	
	// tangent points +X; bitangent points -Y in 3D (since UV.y increases downward)
	// cross(bitangent, tangent) points along +Z matching PlaneMesh FACE_Z
	vec3 tangent = normalize(vec3(eps_x * flag_width, 0.0, dx));
	vec3 bitangent = normalize(vec3(0.0, -eps_y * flag_height, dy));
	NORMAL = normalize(cross(bitangent, tangent));
	
	VERTEX.z += d0;
	
	float x = clamp(UV.x, 0.0, 1.0);
	float wave_factor = pow(x, 1.25);
	// Vertical flutter & gravity sag
	float flutter_y = cos(x * wave_frequency * 1.1 - t * wave_speed * 0.95 + v_world_pos.x * 0.2) * (wave_amplitude * 0.22) * wave_factor;
	VERTEX.y += flutter_y;
	// Slight horizontal contraction along X as cloth folds
	VERTEX.x -= (wave_amplitude * 0.14) * wave_factor * wave_factor;
}

void fragment() {
	// US Flag specification proportions:
	// Canton width = 0.40 of flag length
	// Canton height = 7/13 of flag height
	float canton_w = 0.40;
	float canton_h = 7.0 / 13.0;
	
	// 13 alternating red and white stripes
	float stripe = UV.y * 13.0;
	float is_white = mod(floor(stripe), 2.0);
	vec3 stripe_col = (is_white > 0.5) ? white_color : red_color;
	
	// Canton: 50 stars in 9 alternating rows (6, 5, 6, 5, 6, 5, 6, 5, 6)
	float cu = UV.x / canton_w;
	float cv = UV.y / canton_h;
	float canton_aspect = (canton_w * flag_width) / (canton_h * flag_height);
	
	// Determine row (0..8)
	int r = clamp(int(round(cv * 10.0 - 1.0)), 0, 8);
	float row_y = (float(r) + 1.0) / 10.0;
	
	// Determine star column in this row
	float star_center_x;
	if (r % 2 == 0) {
		int c = clamp(int(floor(cu * 6.0)), 0, 5);
		star_center_x = (float(c) + 0.5) / 6.0;
	} else {
		int c = clamp(int(round(cu * 6.0 - 1.0)), 0, 4);
		star_center_x = (float(c) + 1.0) / 6.0;
	}
	
	float dx = (cu - star_center_x) * canton_aspect;
	float dy = cv - row_y;
	float dist = sqrt(dx * dx + dy * dy);
	
	// Title 4 spec star radius ≈ 0.056 in canton-height units
	float r_outer = 0.056;
	float r_inner = r_outer * 0.381966;
	float sin_half = 0.58778525; // sin(pi/5)
	
	vec3 canton_col = blue_color;
	if (dist < r_outer * 1.15) {
		float angle = atan(-dy, dx) - 1.5707963;
		float sector = 1.25663706; // 2*pi/5
		float half_sector = 0.62831853;
		float a = mod(angle + half_sector, sector) - half_sector;
		float r_star = (r_outer * r_inner * sin_half) / (r_inner * sin(half_sector - abs(a)) + r_outer * sin(abs(a)));
		
		float fw = max(fwidth(dist), 0.003);
		float star_mask = 1.0 - smoothstep(r_star - fw, r_star + fw, dist);
		canton_col = mix(blue_color, white_color, star_mask);
	}
	
	// Antialiased transition at canton border
	float ex = clamp((canton_w - UV.x) / max(fwidth(UV.x), 0.001), 0.0, 1.0);
	float ey = clamp((canton_h - UV.y) / max(fwidth(UV.y), 0.001), 0.0, 1.0);
	float in_canton = ex * ey;
	
	ALBEDO = mix(stripe_col, canton_col, in_canton);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
