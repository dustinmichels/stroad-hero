# Retro filter (F1) improvements

Files: `shaders/pixel_art.gdshader`, `ui/retro_filter.gd`, `ui/retro_filter.tscn`.
Coverage: `tests/objectives_ui_suite.gd` `--test-retro-filter`.

## Shader and preset fixes

- [x] **Average each block instead of reading one pixel (main fix for shimmer).** Each block used to take the color of its single center pixel, so lane lines, poles and sign text flickered as the camera moved.
  - First attempt sampled `filter_linear_mipmap` at `log2(pixel_size)`, but Godot's screen-texture mipmaps are gaussian-blurred, so the image went soft. Replaced by the low-res render below: each block is one MSAA-resolved pixel, sampled with `filter_nearest`.
- [x] **Use whole-number block sizes.** `ARCADE_8BIT` and `AMBER_CRT` set `pixel_size = 2.5`, which makes blocks alternate between 2 and 3 pixels wide. Change them to 2 or 3.
- [x] **Make the dither visible.** The current math already sizes the dither to `dither_strength` color steps, so raise preset `dither_strength` to about 0.8–1.0 where full ordered dithering is wanted. Keep `SUBTLE_RETRO` lower on purpose.
- [x] **Match Amber's dither to its palette.** The amber ramp has 8 steps, but the preset uses `color_depth = 12`. Set `color_depth = 8`. Game Boy (4 colors, `color_depth = 4`) already matches, and CGA (thresholds 0.18 and 0.65, `color_depth = 4`) is close enough.
- [x] **Boost saturation before reducing colors.** `mix(vec3(lum), c, 1.15)` runs after rounding, which pushes colors back off the allowed levels. Move it before the `floor(c * color_depth + 0.5) / color_depth` step.
- [x] **Draw outlines on one side only.** Blocks on both sides of a boundary pass the edge test, so outlines come out about 2 blocks thick. Ink only the darker side, for example only when the center block is darker than its brightest neighbor.

## Larger changes

- [x] **Outlines based on depth and normals instead of color.**
  - Done: `shaders/pixel_outline.gdshader` on a full-screen `MeshInstance3D` quad that `RetroFilter._ensure_outline_quad()` creates (clip-space vertex shader, `render_priority` min so signs draw on top). Silhouettes ink the nearer side; creases compare right/down neighbors only; the depth threshold scales with grazing angle.
  - Forward+ only (`_uses_depth_outlines()`); Mobile and Compatibility (web) keep the color edge test in `pixel_art.gdshader`. The two never stack.
  - The HUD stays unfiltered either way.
- [x] **Render the 3D scene at low resolution.**
  - Done without restructuring `main.tscn`: while a preset is on, `RetroFilter` sets the root viewport's `scaling_3d_scale = 1 / pixel_size` and `msaa_3d` to at least 2×, then restores the previous values on OFF or `_exit_tree`. 2D/HUD still render at full resolution, and camera/picking code is untouched. Works in Compatibility too.
  - Known overlap: F2 (`HUD.cycle_render_scale`) still changes the scale while a preset is on; the next preset change or OFF overrides it.
- [x] **Real palettes instead of per-channel rounding.** Pick the nearest color from a small palette texture (PICO-8, NES, SNES-style). Make Game Boy, Amber and CGA palette textures too, replacing the hard-coded `if` chains.
  - Done: `nearest_palette()` in the shader; palettes are built in `RetroFilter._build_palette_textures()`. `ARCADE_8BIT` uses PICO-8. The subtle/16-bit presets still round per channel on purpose.

## Rejected

- Snapping the camera to the pixel grid only works with an orthographic camera. The main `Camera3D` is perspective (`fov = 54`).
