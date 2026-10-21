shader_type canvas_item;
render_mode unshaded;

// Nearest: RetroFilter renders 3D at screen ÷ pixel_size with MSAA, so each
// block center already holds one antialiased pixel. (Screen-texture mipmaps are
// gaussian-blurred in Godot, so they can't be used for block averaging.)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform bool enabled = true;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float color_depth : hint_range(2.0, 64.0, 1.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform bool enable_outlines = true;
uniform float outline_threshold : hint_range(0.01, 1.0, 0.01) = 0.25;
uniform float outline_opacity : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
// 0: per-channel rounding  1: Game Boy  2: Amber  3: CGA  4: PICO-8
uniform int palette_mode : hint_range(0, 4) = 0;
// palette_texture / palette_size used for modes 1–4 (set from GDScript).
// hint_depth_texture is NOT available in canvas_item shaders; depth-based
// outlines need a camera-child spatial quad or a CompositorEffect.
uniform sampler2D palette_texture : hint_default_white, filter_nearest;
uniform int palette_size = 4;

const float bayer4[16] = float[](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

float get_bayer(vec2 pos) {
	int x = int(floor(mod(pos.x + 10000.0, 4.0)));
	int y = int(floor(mod(pos.y + 10000.0, 4.0)));
	return bayer4[y * 4 + x] - 0.5;
}

// Nearest-color palette lookup – replaces the hard-coded rgb_to_* if-chains.
// Searches palette_texture (N×1 pixels) for the closest RGB entry.
vec3 nearest_palette(vec3 c) {
	vec3 best = vec3(0.0);
	float best_d = 1.0e9;
	for (int i = 0; i < palette_size; i++) {
		float u = (float(i) + 0.5) / float(palette_size);
		vec3 p = texture(palette_texture, vec2(u, 0.5)).rgb;
		float d = dot(c - p, c - p);
		if (d < best_d) {
			best_d = d;
			best = p;
		}
	}
	return best;
}

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 tex_size = vec2(textureSize(screen_texture, 0));
		vec2 p_size = vec2(pixel_size) / tex_size;
		vec2 grid_uv = (floor(SCREEN_UV / p_size) + 0.5) * p_size;

		vec3 c = texture(screen_texture, grid_uv).rgb;

		// ── Edge detection (color-based) ───────────────────────────────────
		bool is_edge = false;
		if (enable_outlines) {
			vec3 up    = texture(screen_texture, grid_uv + vec2(0.0,     -p_size.y)).rgb;
			vec3 down  = texture(screen_texture, grid_uv + vec2(0.0,      p_size.y)).rgb;
			vec3 left  = texture(screen_texture, grid_uv + vec2(-p_size.x, 0.0)).rgb;
			vec3 right = texture(screen_texture, grid_uv + vec2( p_size.x, 0.0)).rgb;

			float lum_c     = dot(c,     vec3(0.299, 0.587, 0.114));
			float lum_up    = dot(up,    vec3(0.299, 0.587, 0.114));
			float lum_down  = dot(down,  vec3(0.299, 0.587, 0.114));
			float lum_left  = dot(left,  vec3(0.299, 0.587, 0.114));
			float lum_right = dot(right, vec3(0.299, 0.587, 0.114));

			float lum_grad = abs(lum_c - lum_up)    + abs(lum_c - lum_down)
						   + abs(lum_c - lum_left)   + abs(lum_c - lum_right);
			float col_grad = distance(c, up) + distance(c, down)
						   + distance(c, left) + distance(c, right);

			float lum_max_neighbor = max(max(lum_up, lum_down), max(lum_left, lum_right));
			// Only ink the darker side of the boundary to keep outlines 1-block wide.
			if ((lum_grad * 0.6 + col_grad * 0.3) > outline_threshold && lum_c < lum_max_neighbor) {
				is_edge = true;
			}
		}

		// ── Ordered Bayer dither ───────────────────────────────────────────
		vec2 pixel_coord = floor(SCREEN_UV / p_size);
		float dither = get_bayer(pixel_coord) * (dither_strength / max(color_depth, 2.0));
		c = clamp(c + vec3(dither), 0.0, 1.0);

		// ── Outline compositing (before quantization so inked blocks stay
		// on-palette). Palette modes ink with entry 0, the darkest color.
		if (is_edge) {
			vec3 ink = palette_mode >= 1
				? texelFetch(palette_texture, ivec2(0, 0), 0).rgb
				: outline_color.rgb;
			c = mix(c, ink, outline_opacity);
		}

		// ── Color quantization & palette mapping ───────────────────────────
		if (palette_mode >= 1) {
			// Modes 1–4: nearest-color lookup against a small palette texture
			// set from GDScript.
			c = nearest_palette(c);
		} else {
			// Mode 0: per-channel quantization.
			// Boost saturation before rounding so colors snap to the right level.
			float lum = dot(c, vec3(0.299, 0.587, 0.114));
			c = clamp(mix(vec3(lum), c, 1.15), 0.0, 1.0);
			c = floor(c * color_depth + 0.5) / color_depth;
		}

		COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
	}
}
