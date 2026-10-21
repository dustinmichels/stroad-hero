// Full-screen depth + normal outline pass for the retro filter (F1).
// Drawn by a MeshInstance3D quad that RetroFilter creates at runtime; only
// used on Forward+, the one renderer with a normal-roughness buffer. Other
// renderers fall back to the color-based edge test in pixel_art.gdshader.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_nearest;

uniform vec4 ink_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float opacity : hint_range(0.0, 1.0, 0.05) = 0.7;
// Relative depth jump (fraction of distance) that marks a silhouette.
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.08;
// Normals whose dot product drops below this mark a crease.
uniform float normal_threshold : hint_range(-1.0, 1.0, 0.01) = 0.6;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float raw = textureLod(depth_texture, uv, 0.0).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return v.xyz / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(textureLod(normal_roughness_texture, uv, 0.0).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(depth_texture, 0));
	vec2 uv = SCREEN_UV;
	float edge = 0.0;

	// Sky / cleared pixels have no geometry to outline.
	if (textureLod(depth_texture, uv, 0.0).r > 0.0) {
		vec3 p = view_pos(uv, INV_PROJECTION_MATRIX);
		vec3 n = view_normal(uv);
		float dist = -p.z;
		// Raise the threshold on surfaces seen at grazing angles (distant road),
		// where neighboring pixels legitimately differ a lot in depth.
		float facing = max(abs(dot(n, normalize(-p))), 0.15);
		float depth_thr = depth_threshold / facing;

		vec2 offsets[4] = vec2[](
			vec2(texel.x, 0.0), vec2(-texel.x, 0.0),
			vec2(0.0, texel.y), vec2(0.0, -texel.y)
		);
		for (int i = 0; i < 4; i++) {
			float nd = -view_pos(uv + offsets[i], INV_PROJECTION_MATRIX).z;
			// Silhouette: ink only the nearer side so lines stay 1 pixel wide.
			if (nd - dist > dist * depth_thr) {
				edge = 1.0;
			}
		}
		// Crease: compare against right and down neighbors only, so a crease
		// is inked on one side. Skip neighbors across a depth jump.
		for (int i = 0; i < 4; i += 2) {
			vec2 nuv = uv + offsets[i];
			float nd = -view_pos(nuv, INV_PROJECTION_MATRIX).z;
			if (abs(nd - dist) < dist * depth_thr && dot(n, view_normal(nuv)) < normal_threshold) {
				edge = 1.0;
			}
		}
	}

	ALBEDO = ink_color.rgb;
	ALPHA = edge * opacity;
}
