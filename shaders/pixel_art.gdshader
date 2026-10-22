shader_type canvas_item;
render_mode unshaded;

// Nearest: RetroFilter renders 3D at screen ÷ pixel_size with MSAA, so each
// block center already holds one antialiased pixel. (Screen-texture mipmaps are
// gaussian-blurred in Godot, so they can't be used for block averaging.)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform bool enabled = true;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
// Color steps per channel (or ramp steps − 1); sizes the dither to one step.
uniform float color_depth : hint_range(1.0, 64.0, 1.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
// 0: ordered 4×4 Bayer  1: clustered-dot halftone
uniform int dither_pattern : hint_range(0, 1) = 0;
uniform bool enable_outlines = true;
uniform float outline_threshold : hint_range(0.01, 1.0, 0.01) = 0.25;
uniform float outline_opacity : hint_range(0.0, 1.0, 0.05) = 0.7;
// Ink for outlines; RetroFilter sets it to palette entry 0 in palette modes.
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
// 0: per-channel rounding; ≥1: palette id registered in RetroFilter.
uniform int palette_mode = 0;
// palette_texture / palette_size used when palette_mode ≥ 1 (set from GDScript).
// hint_depth_texture is NOT available in canvas_item shaders; depth-based
// outlines need a camera-child spatial quad or a CompositorEffect.
uniform sampler2D palette_texture : hint_default_white, filter_nearest;
uniform int palette_size = 4;
// Pick the palette entry by luminance (dark→bright ramp) instead of nearest RGB.
uniform bool luma_ramp = false;
// Saturation multiplier applied before dither and quantization (1.0 = unchanged).
// Pushes muted scene colors past a palette's greys toward its hues.
uniform float saturation : hint_range(0.0, 3.0, 0.05) = 1.0;

// ── Display effects (applied after quantization) ──────────────────────────────
// Darkens the gap between block rows, one scanline per block.
uniform float scanline_strength : hint_range(0.0, 1.0, 0.05) = 0.0;
// RGB aperture-grille stripes, one screen pixel per phosphor.
uniform float mask_strength : hint_range(0.0, 1.0, 0.05) = 0.0;
// Barrel distortion of the image; pixels outside the tube go black.
uniform float curvature : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform float vignette : hint_range(0.0, 2.0, 0.05) = 0.0;
// Per-block noise, re-rolled every frame.
uniform float grain : hint_range(0.0, 0.5, 0.01) = 0.0;

const float bayer4[16] = float[](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

// Clustered-dot threshold map: dots grow from the cell center, like print.
const float halftone4[16] = float[](
	12.0 / 16.0,  5.0 / 16.0,  6.0 / 16.0, 13.0 / 16.0,
	 4.0 / 16.0,  0.0 / 16.0,  1.0 / 16.0,  7.0 / 16.0,
	11.0 / 16.0,  3.0 / 16.0,  2.0 / 16.0,  8.0 / 16.0,
	15.0 / 16.0, 10.0 / 16.0,  9.0 / 16.0, 14.0 / 16.0
);

float get_threshold(vec2 pos) {
	int x = int(floor(mod(pos.x + 10000.0, 4.0)));
	int y = int(floor(mod(pos.y + 10000.0, 4.0)));
	float t = dither_pattern == 1 ? halftone4[y * 4 + x] : bayer4[y * 4 + x];
	return t - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Nearest-color palette lookup.
// Searches palette_texture (N×1 pixels) for the closest RGB entry.
vec3 nearest_palette(vec3 c) {
	vec3 best = vec3(0.0);
	float best_d = 1.0e9;
	for (int i = 0; i < palette_size; i++) {
		vec3 p = texelFetch(palette_texture, ivec2(i, 0), 0).rgb;
		float d = dot(c - p, c - p);
		if (d < best_d) {
			best_d = d;
			best = p;
		}
	}
	return best;
}

vec3 ramp_palette(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	int i = int(floor(clamp(lum, 0.0, 1.0) * float(palette_size - 1) + 0.5));
	return texelFetch(palette_texture, ivec2(i, 0), 0).rgb;
}

vec2 warp(vec2 uv) {
	vec2 d = uv * 2.0 - 1.0;
	d *= 1.0 + curvature * dot(d, d);
	return d * 0.5 + 0.5;
}

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = curvature > 0.0 ? warp(SCREEN_UV) : SCREEN_UV;
		vec2 tex_size = vec2(textureSize(screen_texture, 0));
		vec2 p_size = vec2(pixel_size) / tex_size;
		vec2 grid_uv = (floor(uv / p_size) + 0.5) * p_size;

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

		if (saturation != 1.0) {
			float sat_lum = dot(c, vec3(0.299, 0.587, 0.114));
			c = clamp(mix(vec3(sat_lum), c, saturation), 0.0, 1.0);
		}

		// ── Ordered dither + grain ─────────────────────────────────────────
		vec2 pixel_coord = floor(uv / p_size);
		float dither = get_threshold(pixel_coord) * (dither_strength / color_depth);
		if (grain > 0.0) {
			dither += (hash(pixel_coord + fract(TIME) * 61.7) - 0.5) * grain;
		}
		c = clamp(c + vec3(dither), 0.0, 1.0);

		// ── Outline compositing (before quantization so inked blocks stay
		// on-palette).
		if (is_edge) {
			c = mix(c, outline_color.rgb, outline_opacity);
		}

		// ── Color quantization & palette mapping ───────────────────────────
		if (palette_mode >= 1) {
			c = luma_ramp ? ramp_palette(c) : nearest_palette(c);
		} else {
			// Per-channel quantization.
			// Boost saturation before rounding so colors snap to the right level.
			float lum = dot(c, vec3(0.299, 0.587, 0.114));
			c = clamp(mix(vec3(lum), c, 1.15), 0.0, 1.0);
			c = floor(c * color_depth + 0.5) / color_depth;
		}

		// ── Display effects ────────────────────────────────────────────────
		if (scanline_strength > 0.0) {
			float row = fract(uv.y / p_size.y);
			// Bright in the middle of each block row, dark at its edges.
			float beam = 1.0 - scanline_strength * pow(abs(row - 0.5) * 2.0, 2.0);
			c *= beam * (1.0 + scanline_strength * 0.35);
		}
		if (mask_strength > 0.0) {
			int phosphor = int(mod(FRAGCOORD.x, 3.0));
			vec3 m = vec3(phosphor == 0 ? 1.0 : 0.0, phosphor == 1 ? 1.0 : 0.0, phosphor == 2 ? 1.0 : 0.0);
			c *= mix(vec3(1.0), m * 2.2 + 0.25, mask_strength);
		}
		if (vignette > 0.0) {
			vec2 d = SCREEN_UV - 0.5;
			c *= clamp(1.0 - vignette * dot(d, d) * 1.6, 0.0, 1.0);
		}
		if (curvature > 0.0 && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
			c = vec3(0.0);
		}

		COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
	}
}
