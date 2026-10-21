# Retro filter (F1) improvements

Files: `shaders/pixel_art.gdshader`, `ui/retro_filter.gd`, `ui/retro_filter.tscn`.
Coverage: `tests/objectives_ui_suite.gd` `--test-retro-filter`.

## Shader and preset fixes

- [ ] **Average each block instead of reading one pixel (main fix for shimmer).** Switch `screen_texture` to `filter_linear_mipmap` and sample with `textureLod(screen_texture, grid_uv, log2(pixel_size))`. Right now each block takes the color of its single center pixel (`filter_nearest`), so lane lines, poles and sign text flicker as the camera moves.
- [ ] **Use whole-number block sizes.** `ARCADE_8BIT` and `AMBER_CRT` set `pixel_size = 2.5`, which makes blocks alternate between 2 and 3 pixels wide. Change them to 2 or 3.
- [ ] **Make the dither visible.** The current math already sizes the dither to `dither_strength` color steps, so raise preset `dither_strength` to about 0.8–1.0 where full ordered dithering is wanted. Keep `SUBTLE_RETRO` lower on purpose.
- [ ] **Match Amber's dither to its palette.** The amber ramp has 8 steps, but the preset uses `color_depth = 12`. Set `color_depth = 8`. Game Boy (4 colors, `color_depth = 4`) already matches, and CGA (thresholds 0.18 and 0.65, `color_depth = 4`) is close enough.
- [ ] **Boost saturation before reducing colors.** `mix(vec3(lum), c, 1.15)` runs after rounding, which pushes colors back off the allowed levels. Move it before the `floor(c * color_depth + 0.5) / color_depth` step.
- [ ] **Draw outlines on one side only.** Blocks on both sides of a boundary pass the edge test, so outlines come out about 2 blocks thick. Ink only the darker side, for example only when the center block is darker than its brightest neighbor.

## Larger changes

- [ ] **Outlines based on depth and normals instead of color.**
  - `hint_depth_texture` and `hint_normal_roughness_texture` don't work in a `canvas_item` shader. Move the effect to a full-screen quad with a spatial shader on the camera, or to a `CompositorEffect`.
  - The web build uses the Compatibility renderer, which has no normal-roughness buffer. Keep the current color-based edge test as the fallback there.
  - The HUD stays unfiltered either way.
- [ ] **Render the 3D scene at low resolution.** Draw the 3D world into a `SubViewport` sized at screen size ÷ `pixel_size`, then scale it up with nearest filtering.
  - Benefits: about `pixel_size²` less fragment work, and crisp real pixels.
  - It doesn't fix shimmer by itself, because it's still one sample per pixel. Turn on MSAA in the viewport (`msaa_3d`) to match the block averaging fix above. FXAA also helps but softens edges.
  - Requires restructuring `main.tscn`: the camera, any mouse-picking code, and the web `scaling_3d/scale` setting must account for the viewport.
- [ ] **Real palettes instead of per-channel rounding.** Pick the nearest color from a small palette texture (PICO-8, NES, SNES-style). Make Game Boy, Amber and CGA palette textures too, replacing the hard-coded `if` chains.

## Rejected

- Snapping the camera to the pixel grid only works with an orthographic camera. The main `Camera3D` is perspective (`fov = 54`).
