# Browser Optimization Todo List

Goal: make the Web build load reliably and run at 30 FPS on modern phones and 60 FPS on typical desktops.

## Current Baseline

Measured against the local and deployed Godot 4.7.2 Web builds on October 19, 2026.

| Metric                             | Observed value |
| ---------------------------------- | -------------: |
| Compressed WebAssembly transfer    |    9.6–10.3 MB |
| Compressed game package transfer   |     1.9–2.7 MB |
| Deployed startup to `godotReady()` |    6.0 seconds |
| Local startup to `godotReady()`    |    6.9 seconds |
| Draw calls during gameplay         |          1,703 |
| Rendered objects during gameplay   |          2,032 |
| Deployed physics time sample       |         8.9 ms |
| Browser frame interval, p99        |        33.7 ms |
| Longest sampled frame interval     |        67.3 ms |

## 1. Fix the Deployed Font Resources

- [ ] Reproduce the deployed `Unrecognized binary resource file` errors in the GitHub Actions export.
- [ ] Build the Pages artifact with the official Godot 4.7.2 binary and matching export templates instead of relying on a potentially mismatched third-party image.
- [ ] Confirm that `Overpass-SemiBold.ttf` and `ArchivoBlack-Regular.ttf` load without errors.
- [ ] Add a deployment smoke check that opens the exported game and fails on `ERROR: Failed loading resource`.
- [ ] Verify that the local and deployed builds show the same fonts and start-screen layout.

## 2. Reduce the WebAssembly Build

- [ ] Generate and review a `.gdbuild` profile with Godot's Engine Compilation Configuration Editor.
- [ ] Keep classes that are created dynamically from GDScript even if automatic detection misses them.
- [ ] Build a custom Web release template with `optimize=size_extra`.
- [ ] Test replacing the advanced text server with the fallback text server:
  - `module_text_server_adv_enabled=no`
  - `module_text_server_fb_enabled=yes`
- [ ] Configure `custom_template/release` in `export_presets.cfg`.
- [ ] Cache the custom template in CI by Godot version and build-profile hash.
- [ ] Record compressed WASM size and startup time before and after the change.
- [ ] Smoke-test the start screen, HUD, phone call, signs, objective markers, and character editor.

## 3. Cut Web Physics to 30 Hz

- [ ] Add `physics/common/physics_ticks_per_second.web=30` to `project.godot`.
- [ ] Enable physics interpolation for the Web build.
- [ ] Reset interpolation after vehicle spawns, teleports, and state transitions that directly replace transforms.
- [ ] Verify camera motion remains smooth through `get_global_transform_interpolated()`.
- [ ] Test Mats against fast lane traffic to ensure collisions are not skipped at 30 Hz.
- [ ] Test vehicle following, parking, reversing, drive-through queues, and lane changes.
- [ ] Compare physics time and frame pacing against the baseline.

## 4. Reduce Draw Calls and Rendered Objects

- [ ] Use the F3 overlay to record draw calls and rendered objects at the same camera position for every comparison.
- [ ] Extend `MeshBaker` to combine surfaces that can share one material, rather than only combining mesh nodes.
- [ ] Collapse materials that differ only by color using vertex color where the result remains visually equivalent.
- [ ] Disable shadow casting on labels, signs, lights, logos, vehicle lights, and other small details that do not need shadows.
- [ ] Add sensible `visibility_range_end` values to small signs, `Label3D` nodes, flags, wheel details, and distant props.
- [ ] Check whether repeated remaining props can use `MultiMeshInstance3D` without losing required behavior.
- [ ] Verify all buildings, vehicles, paint colors, signals, wheels, signs, and shadows in the exported browser build.
- [ ] Record draw calls, rendered objects, p95 frame interval, and p99 frame interval after each group of changes.

## 5. Remove Traffic Hot-Loop Allocations

- [ ] Cache entry, reverse, and exit `Curve3D` routes on each `ParkingSpot` instead of rebuilding them while cars wait.
- [ ] Replace `_car_sweep()`'s eight-element array cache key with a scalar revision counter on `Car`.
- [ ] Increment the sweep revision whenever transform, path, path distance, speed, state, length, or width changes.
- [ ] Remove per-tick `get_overlapping_bodies()` polling from moving cars; use the existing `body_entered` signal or one centralized player overlap check.
- [ ] Profile `find_blocker()` after the allocation fixes.
- [ ] If conflict solving remains expensive, partition candidate cars by north lot, south lot, drive-through, or active driveway.
- [ ] Run the traffic, parking, drive-through, collision, and Mats death tests.
- [ ] Compare process time, physics time, and frame pacing against the baseline.

## 6. Capture Browser Crash Causes

- [ ] Handle `webglcontextlost` on the game canvas without attempting an unsafe automatic restart.
- [ ] Handle `window.onerror` and `unhandledrejection` during and after startup.
- [ ] Show a concise failure message containing the error, browser, platform, canvas dimensions, and WebGL renderer.
- [ ] Distinguish startup failure, WebGL context loss, and an unexpected JavaScript or WASM exception.
- [ ] Capture the console output from at least one reported crash before making crash-specific changes.

## 7. Add a Lower Web Quality Option if Needed

Do this only if the earlier changes do not hold 30 FPS on target phones.

- [ ] Test `rendering/scaling_3d/scale.web=0.5` against the current `0.75` setting.
- [ ] Keep the 2D HUD and text at native resolution.
- [ ] Compare readability, GPU load, frame pacing, and WebGL stability on a high-DPI phone.
- [ ] Keep the lower scale as the Web default or expose one simple quality toggle only if measurements justify it.

## Release Checks

- [ ] Export with `mise run export-web`.
- [ ] Open the exported build in Chromium, Firefox, and Safari.
- [ ] Verify a clean browser console from page load through gameplay.
- [ ] Measure cold-cache startup and ten seconds of idle gameplay.
- [ ] Test one non-Apple-Silicon laptop and one physical phone.
- [ ] Confirm the game holds 30 FPS on the target phone without a WebGL context loss.
- [ ] Update the baseline table with final measurements.
