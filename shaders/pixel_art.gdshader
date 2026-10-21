shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform bool enabled = true;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float color_depth : hint_range(2.0, 64.0, 1.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform bool enable_outlines = true;
uniform float outline_threshold : hint_range(0.01, 1.0, 0.01) = 0.25;
uniform float outline_opacity : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform int palette_mode : hint_range(0, 3) = 0; // 0: 16-Bit Arcade, 1: Game Boy Classic, 2: Amber Monochrome, 3: CGA Cyber

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

vec3 rgb_to_gameboy(float lum) {
	vec3 gb0 = vec3(0.06, 0.22, 0.06); // Darkest forest
	vec3 gb1 = vec3(0.19, 0.38, 0.19); // Deep olive
	vec3 gb2 = vec3(0.55, 0.67, 0.06); // Olive lime
	vec3 gb3 = vec3(0.61, 0.73, 0.06); // Crisp bright pea-green
	if (lum < 0.25) return gb0;
	if (lum < 0.50) return gb1;
	if (lum < 0.75) return gb2;
	return gb3;
}

vec3 rgb_to_amber(float lum) {
	vec3 dark = vec3(0.08, 0.04, 0.01);
	vec3 bright = vec3(1.0, 0.72, 0.15);
	float stepped = floor(lum * 8.0 + 0.5) / 8.0;
	return mix(dark, bright, stepped);
}

vec3 rgb_to_cga(float lum, vec3 original) {
	vec3 c0 = vec3(0.02, 0.02, 0.04);
	vec3 c1 = vec3(0.0, 0.85, 0.85);  // Cyan
	vec3 c2 = vec3(0.95, 0.15, 0.65); // Magenta
	vec3 c3 = vec3(1.0, 1.0, 1.0);     // White
	if (lum < 0.18) return c0;
	if (original.b > original.r) return (lum < 0.65) ? c1 : c3;
	return (lum < 0.65) ? c2 : c3;
}

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 tex_size = vec2(textureSize(screen_texture, 0));
		vec2 p_size = vec2(pixel_size) / tex_size;
		vec2 grid_uv = (floor(SCREEN_UV / p_size) + 0.5) * p_size;

		vec3 c = texture(screen_texture, grid_uv).rgb;

		// Silhouette and edge detection
		bool is_edge = false;
		if (enable_outlines) {
			vec3 up = texture(screen_texture, grid_uv + vec2(0.0, -p_size.y)).rgb;
			vec3 down = texture(screen_texture, grid_uv + vec2(0.0, p_size.y)).rgb;
			vec3 left = texture(screen_texture, grid_uv + vec2(-p_size.x, 0.0)).rgb;
			vec3 right = texture(screen_texture, grid_uv + vec2(p_size.x, 0.0)).rgb;

			float lum_c = dot(c, vec3(0.299, 0.587, 0.114));
			float lum_up = dot(up, vec3(0.299, 0.587, 0.114));
			float lum_down = dot(down, vec3(0.299, 0.587, 0.114));
			float lum_left = dot(left, vec3(0.299, 0.587, 0.114));
			float lum_right = dot(right, vec3(0.299, 0.587, 0.114));

			float lum_grad = abs(lum_c - lum_up) + abs(lum_c - lum_down)
						   + abs(lum_c - lum_left) + abs(lum_c - lum_right);
			float col_grad = distance(c, up) + distance(c, down) + distance(c, left) + distance(c, right);

			if ((lum_grad * 0.6 + col_grad * 0.3) > outline_threshold) {
				is_edge = true;
			}
		}

		// Ordered Bayer Dither
		vec2 pixel_coord = floor(SCREEN_UV / p_size);
		float dither = get_bayer(pixel_coord) * (dither_strength / max(color_depth, 2.0));
		c = clamp(c + vec3(dither), 0.0, 1.0);

		// Color Quantization & Palette Mapping
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		if (palette_mode == 1) {
			c = rgb_to_gameboy(lum);
		} else if (palette_mode == 2) {
			c = rgb_to_amber(lum);
		} else if (palette_mode == 3) {
			c = rgb_to_cga(lum, c);
		} else {
			// 16-Bit Arcade: stepped channels with slight saturation boost
			c = floor(c * color_depth + 0.5) / color_depth;
			c = mix(vec3(lum), c, 1.15); // Subtle arcade vibrancy boost
		}

		if (is_edge) {
			vec3 ink = outline_color.rgb;
			if (palette_mode == 1) {
				ink = vec3(0.06, 0.22, 0.06);
			} else if (palette_mode == 2) {
				ink = vec3(0.05, 0.02, 0.0);
			} else if (palette_mode == 3) {
				ink = vec3(0.0, 0.0, 0.0);
			}
			c = mix(c, ink, outline_opacity);
		}

		COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
	}
}
