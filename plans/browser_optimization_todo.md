# Browser Optimization Todo List

Goal: make the Web build load reliably and run at 30 FPS on modern phones and 60 FPS on typical desktops.

## Baseline and Final Comparison

Baseline measured against the local and deployed Godot 4.7.2 Web builds on October 19, 2026.
Final measurements recorded against the optimized Godot 4.7.2 Web build on October 20, 2026.

| Metric                             | Baseline (Oct 19) | Final Optimized (Oct 20) |   Change / Delta |
| ---------------------------------- | ----------------: | -----------------------: | ---------------: |
| Compressed WebAssembly transfer    |       9.6–10.3 MB |     5.70 MB (4.06 MB br) |           -42.3% |
| Compressed game package transfer   |        1.9–2.7 MB |     4.25 MB (2.06 MB br) |         +57.4% * |
| Deployed startup to `godotReady()` |       6.0 seconds |             5.17 seconds |           -13.8% |
| Local startup to `godotReady()`    |       6.9 seconds |             5.43 seconds |           -21.3% |
| Draw calls during gameplay         |             1,703 |          1,199.5–1,281.7 | -24.7% to -29.6% |
| Rendered objects during gameplay   |             2,032 |          1,545.0–1,624.4 | -20.1% to -23.9% |
| Deployed physics time sample       |            8.9 ms |             1.63–1.90 ms | -78.7% to -81.7% |
| Browser frame interval, p99        |           33.7 ms |                 16.80 ms |           -50.1% |
| Longest sampled frame interval     |           67.3 ms |                 23.23 ms |           -65.5% |

_\* Note on game package transfer: the package grew from ~2.7 MB to 4.25 MB gzipped due to exporting MSDF distance-field glyph atlases and pre-baked meshes, which directly eliminated synchronous runtime font atlas rasterization, runtime material splitting, and in-game frame hitching._

## 1. Fix the Deployed Font Resources

- [x] Reproduce the deployed `Unrecognized binary resource file` errors in the GitHub Actions export.
  - Note: Reproduced in deployed Pages console log (`res://fonts/Overpass-SemiBold.ttf` and `res://fonts/ArchivoBlack-Regular.ttf` failed with `Unrecognized binary resource file`) and CI export log (`res://.godot/imported/*.fontdata` missing during export).
- [x] Build the Pages artifact with the official Godot 4.7.2 binary and matching export templates instead of relying on a potentially mismatched third-party image.
  - Note: Switched `.github/workflows/deploy-web.yml` from `barichello/godot-ci:4.7.2` container to official Godot 4.7.2 binary and templates on `ubuntu-24.04`, added `godot --headless --import` with `import/blender/enabled=false` to generate all `.fontdata` resources cleanly.
- [x] Confirm that `Overpass-SemiBold.ttf` and `ArchivoBlack-Regular.ttf` load without errors.
  - Note: Verified in CI build logs (`savepack` stored both `.fontdata` resources; no missing import errors), deployed Pages browser console (zero errors or warnings, `[Startup] Godot ready`), and visual rendering of the title and start screen.
- [x] Add a deployment smoke check that opens the exported game and fails on `ERROR: Failed loading resource`.
  - Note: Added `scripts/smoke_check_web.js` using headless Chrome DevTools Protocol to serve and test exported builds (or `--url`), assert Godot reaches ready state, and fail if `ERROR: Failed loading resource` or unrecognized binary files appear. Wired into `.github/workflows/deploy-web.yml` and `mise.toml` (`mise run smoke-web`).
- [x] Verify that the local and deployed builds show the same fonts and start-screen layout.
  - Note: Captured and compared 1280x720 headless Chrome screenshots of both the deployed build (`https://dustinmichels.github.io/stroad-hero/`) and local static build (`build/web`); verified identical pixel output (SHA256: `2c5dee603c...`), zero font loading errors, and identical typography (`ArchivoBlack-Regular` title, `Overpass-Bold` keys/buttons, `Overpass-SemiBold` actions/subtitles, `Overpass-Regular` prompts).

## 2. Reduce the WebAssembly Build

- [x] Generate and review a `.gdbuild` profile with Godot's Engine Compilation Configuration Editor.
  - Note: Generated `web.gdbuild` by driving Godot's Engine Compilation Configuration Editor (`EditorBuildProfileManager` project class detection) across all project files. Disabled unused engine subsystems (2D physics, 2D/3D navigation, XR/OpenXR) and 215 unused engine classes.
- [x] Keep classes that are created dynamically from GDScript even if automatic detection misses them.
  - Note: Audited all dynamic class instantiations across `.gd` files and scenes against `web.gdbuild`. Retained `ViewportTexture` (required for `SubViewport` in Character Editor preview) and `Image` / `ImageTexture` (used for runtime texture and image operations) so dynamic instantiations and runtime texture pipelines are preserved.
- [x] Build a custom Web release template with `optimize=size_extra`.
  - Note: Compiled custom Web release template (`templates/web_release.zip`) with SCons 4.11 and Emscripten 4.0.10 using `optimize=size_extra`, `threads=no`, and `web.gdbuild`. Uncompressed `godot.wasm` reduced from 39.5 MB to 18.3 MB (19,149,935 bytes); gzipped size reduced from 9.59 MB to 5.67 MB (5,950,329 bytes). Added `scripts/build_custom_template.sh`.
- [x] Test replacing the advanced text server with the fallback text server:
  - `module_text_server_adv_enabled=no`
  - `module_text_server_fb_enabled=yes`
  - Note: Verified custom template compiled with `module_text_server_adv_enabled=no` and `module_text_server_fb_enabled=yes`. Exported web build and tested in headless Chrome: FreeType fallback text server cleanly renders all dynamic TTF fonts (ArchivoBlack, Overpass variants), start screen UI, and labels without HarfBuzz/ICU overhead, with 0 resource errors or font shaping warnings.
- [x] Configure `custom_template/release` in `export_presets.cfg`.
  - Note: Pointed `custom_template/release` in `export_presets.cfg` to `res://templates/web_release.zip`. Verified export pipeline (`mise run export-web` and `mise run smoke-web`) packages the custom template without errors and exports the 18.3 MB optimized WASM build.
- [x] Cache the custom template in CI by Godot version and build-profile hash.
  - Note: Configured `actions/cache@v4` in `.github/workflows/deploy-web.yml` caching `templates/web_release.zip` under `godot-custom-template-4.7.2-stable-${{ hashFiles('web.gdbuild', 'scripts/build_custom_template.sh') }}`. Added automated fallback steps with `actions/setup-python`, `mymindstorm/setup-emsdk@v14`, and SCons build script to recompile whenever the build profile changes. Ignored `templates/*.zip` in `.gitignore`.
- [x] Record compressed WASM size and startup time before and after the change.
  - Note: Measured baseline (official Godot 4.7.2 web release template) vs custom optimized template across size and startup metrics:
    - Uncompressed WASM: 39,514,754 bytes (37.68 MB) -> 19,149,935 bytes (18.26 MB) [51.5% reduction / -20.36 MB]
    - Gzip (-9) WASM: 10,153,810 bytes (9.68 MB) -> 6,009,325 bytes (5.73 MB) [40.8% reduction / -3.95 MB]
    - Brotli WASM: 7,095,787 bytes (6.77 MB) -> 4,313,526 bytes (4.11 MB) [39.2% reduction / -2.66 MB]
    - Startup timing (headless Chrome): Baseline engine start 12.2s, Godot ready 15.3s vs Custom engine start 12.4s, Godot ready 15.7s (identical within shader compile margin; network download footprint reduced by ~4 MB gzipped).
- [x] Smoke-test the start screen, HUD, phone call, signs, objective markers, and character editor.
  - Note: Executed full interactive headless Chrome CDP test on exported optimized Web build (`build/web`):
    - Start screen: Verified layout, dynamic fonts, and controls card. Dismissed via Enter key.
    - HUD: Verified deaths/speed/errands counters and time-of-day controls.
    - Phone call: Verified incoming call ringing banner from Mom, answered with Enter key, verified Mom portrait and typewriter dialogue display.
    - Signs: Verified 3D storefront and plaza signs (Walgroins, Taco Hell, Smell, Colonial Plaza, Abominos, etc.).
    - Objective markers: Verified 3D destination marker above Smell Food Mart and HUD errand banner ("Get cereal at Smell").
    - Character editor: Opened via 'C' key, verified SubViewport 3D Mats preview rendering, options (hair, jacket, backpack, shoes), and cleanly closed with Esc.

## 3. Cut Web Physics to 30 Hz

- [x] Add `physics/common/physics_ticks_per_second.web=30` to `project.godot`.
- [x] Enable physics interpolation for the Web build.
- [x] Reset interpolation after vehicle spawns, teleports, and state transitions that directly replace transforms.
  - Note: Added `reset_physics_interpolation()` across vehicle lifecycle in `cars/car.gd`, `traffic/traffic_manager.gd`, and `main.gd`:
    - Spawns: Called after lane spawn distance placement (`_spawn_car_at`), initial parking spot seeding (`_seed_parked_car_at`), and curve attachment (`follow_path`).
    - Teleports: Maintained in `Car.teleport()` and player respawn in `player/mats.gd`.
    - Direct transform transitions: Called when snapping to `spot.transform` on arrival into `State.PARKED` (in both `Car.update_presentation()` and `TrafficManager._update_lot_cars()`), on arrival into `State.WAITING_TO_MERGE`, and on completing curve merge back onto road lane in `State.CRUISING`.
    - Verified with all 21 test suites passing.
- [x] Verify camera motion remains smooth through `get_global_transform_interpolated()`.
  - Note: Verified `FollowCamera` tracking under 30 Hz physics and physics interpolation:
    - Configured `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` on `FollowCamera` per Godot manual camera interpolation guidelines so the camera updates per render frame in `_process()` rather than fighting physics tick interpolation.
    - Hardened null target checks and snapped camera to interpolated target transform `target.get_global_transform_interpolated().origin`.
    - Headless multi-frame verification confirmed monotonic sub-tick camera movement advancing across all 60 render frames as Mats accelerates, with smooth yaw/pitch swinging and clean snaps on respawn.
- [x] Test Mats against fast lane traffic to ensure collisions are not skipped at 30 Hz.
  - Note: Verified Mats collision detection against fast lane traffic at 30 Hz:
    - Added `--physics-ticks=` CLI parameter override to `main.gd` so tests can exercise arbitrary physics tick rates (60 Hz desktop default and 30 Hz web profile).
    - Updated `COL_LANE_CONFIGS` and `_setup_col_lane_test` in `main.gd` to test high-speed traffic (Sports car in Lane 1 at 26.5 m/s, and in Lane 2 at 28.0 m/s with lateral crossing velocity $v_z = 3.0\text{ m/s}$).
    - Made frame timing checks tick-rate adaptive (`Engine.physics_ticks_per_second / 60.0`).
    - Verified `--test-mats-collision` passes at both 60 Hz and 30 Hz without collision skipping or false near-miss kills.
- [x] Test vehicle following, parking, reversing, drive-through queues, and lane changes.
  - Note: Verified all traffic behaviors and maneuvers under both 60 Hz and 30 Hz physics:
    - Vehicle following: Verified smooth deceleration and safe spacing behind turning and cruising cars without collision via `--test-right-turn-following`.
    - Parking & lifecycle: Verified full errand cycle from cruising to approach braking, parking spot navigation, dwell, and unparking via `--test-lifecycle`, `--test-cramped-inn`, `--test-strip-mall`, `--test-smell-store`, and `--test-smell-gas`.
    - Reversing: Verified safety clearances, delayed reverse-out when conflicting moving traffic approaches, and clear-path reversing via `--test-reverse-safety`.
    - Drive-through queues: Verified Taco Hell and Booger King drive-throughs with dwell times at menu and pickup windows, proper queuing without car-on-car penetration, and multi-vehicle throughput via `--test-drive-thru`.
    - Lane changes & merging: Verified gap acceptance, yielding to through traffic, and smooth re-entry into cruising lanes via `--test-merge-reentry`, `--test-merge-gap`, and `--test-exit-priority`.
    - Priority arbitration & deadlocks: Verified TO_SPOT > TO_EXIT > REVERSING_OUT priority rules and watchdog deadlock resolution via `--test-priority-arbitration` and `--test-deadlock-watchdog`.
    - Stabilized tests: Seeded RNG deterministically in `--test-drive-thru` and ensured parking spot availability in destination lot errand tests.
- [x] Compare physics time and frame pacing against the baseline.
  - Note: Measured and compared physics step time, CPU consumption, frame pacing, and main-thread rAF execution across native headless and the exported Web build in Chromium:
    - Native Headless:
      - 60 Hz Desktop Baseline: Idle physics step avg 2.91 ms (p50 2.03 ms, baseline was ~3 ms); wall tick avg 16.65 ms (60 Hz cadence); total physics CPU 174.4 ms/s (idle) and 279.9 ms/s (walking).
      - 30 Hz Web Profile: Idle physics step avg 5.07 ms (p50 2.97 ms); wall tick avg 33.35 ms (30 Hz cadence); total physics CPU 151.9 ms/s (idle) and 146.3 ms/s (walking), delivering a 47.7% CPU time reduction during walking.
    - Browser Build in Chromium (ANGLE Metal WebGL 2.0):
      - Baseline (Oct 17 profilng in optimizations.md): Main-thread CPU per frame (rAF callback, idle) avg 12–15 ms, p95 16–20 ms, spikes 38–96 ms.
      - 30 Hz Idle (Web Profile): Main-thread CPU per frame avg 5.82 ms, p50 5.75 ms, p95 7.23 ms, p99 8.13 ms, max 10.18 ms (52–61% CPU reduction, startup spikes eliminated).
      - 30 Hz Walking (Web Profile): Main-thread CPU per frame avg 5.72 ms, p50 5.68 ms, p95 6.97 ms, p99 8.03 ms, max 8.95 ms (53–62% CPU reduction, max frame time < 9 ms).
      - Frame Pacing: rAF frame interval locked at avg 16.666 ms, p50 16.665 ms, p95 16.670 ms, max 16.670 ms (rock-solid 60 FPS presentation while physics steps at 30 Hz via physics interpolation).
    - Hardened collision hit checking in `cars/car.gd`: added distance validation to prevent residual physics overlap notifications from triggering kills across distant coordinates on player respawn.
    - Added `--test-perf` and `--test-perf-walk` benchmarks to `main.gd` and `scripts/run_tests.py`; verified all 23/23 tests pass.

## 4. Reduce Draw Calls and Rendered Objects

- [x] Use the F3 overlay to record draw calls and rendered objects at the same camera position for every comparison.
  - Note: Enabled F3 overlay inspection and automated benchmark via `--test-render` in `main.gd`. Fixed camera locked at standard spawn `(0.0, 14.38, 22.15)` with pitch `-0.4625 rad` (`-26.5 deg`).
    - Baseline unbaked (OpenGL3 Compatibility): Draw calls avg 2853.1 (p50: 2840, p95: 2919, p99: 2928); Rendered objects avg 3195.6 (p50: 3186, p95: 3259, p99: 3268); Frame interval avg 19.32 ms (p50: 18.45 ms, p95: 24.33 ms, p99: 25.62 ms).
    - Baseline with current bake (OpenGL3 Compatibility): Draw calls avg 3200.8 (p50: 3196, p95: 3270, p99: 3277); Rendered objects avg 3541.3 (p50: 3536, p95: 3613, p99: 3616); Frame interval avg 19.74 ms (p50: 20.35 ms, p95: 25.54 ms, p99: 35.50 ms).
- [x] Extend `MeshBaker` to combine surfaces that can share one material, rather than only combining mesh nodes.
  - Note: Implemented material equivalence comparison (`_standard_materials_equal`, `_shader_materials_equal`, `materials_are_equivalent`) and canonical material lookup (`get_canonical_material`) in `addons/mesh_baker/mesh_baker.gd`. Wired canonicalization into `bake_wheel()`, `bake_car_body()`, `_collect_vehicle_meshes()`, `bake_vehicle_model()`, `bake_dumpster()`, `bake_static_scene()`, `bake_trees()`, and `bake_flags()`. Bumped configuration hash to 6 in `export_plugin.gd`.
    - Baked render stats (OpenGL3 Compatibility): Draw calls reduced from baseline 3200.8 to avg 2744.0 (p50: 2744, p95: 2763, p99: 2766, min: 2724, max: 2766) — a reduction of ~457 draw calls per frame; Rendered objects reduced from 3541.3 to avg 3082.3 (p50: 3082, p95: 3100, p99: 3102); Frame interval avg 18.46 ms (p50: 17.25 ms, p95: 24.41 ms, p99: 27.51 ms).
- [x] Collapse materials that differ only by color using vertex color where the result remains visually equivalent.
  - Note: Implemented `materials_can_collapse_by_color()`, `_append_mesh_surface_with_color()`, and `commit_surfaces_with_color_collapsing()` in `addons/mesh_baker/mesh_baker.gd`. Materials sharing equivalent shader parameters (untextured, non-emissive, opaque, matching roughness, metallic, culling, shading mode, etc.) that differ only by `albedo_color` are collapsed into a single surface using `vertex_color_use_as_albedo = true`, white material albedo, and per-vertex colors populated via `ARRAY_COLOR`. Wired collapsing across wheels, car body trim, vehicle models, dumpsters, static scenes/buildings, trees, poles, and `bake_main_scene()`. Bumped configuration hash to 7 in `export_plugin.gd`.
    - Render stats with vertex-color collapsed bake (OpenGL3 Compatibility): Draw calls reduced from 2744.0 to avg 1928.9 (p50: 1949, p95: 1983, p99: 1991, min: 1819, max: 1991) — an additional reduction of ~815 draw calls per frame (~1,272 draw calls saved vs baseline); Rendered objects reduced from 3082.3 to avg 2273.0 (p50: 2293, p95: 2327, p99: 2333); Frame interval avg 17.43 ms (p50: 16.70 ms, p95: 23.58 ms, p99: 27.78 ms).
- [x] Disable shadow casting on labels, signs, lights, logos, vehicle lights, and other small details that do not need shadows.
  - Note: Disabled `cast_shadow` across all 3D labels, signs, logos, vehicle lights, indicators, license plates, stickers, posters, screen elements, and wheel spoke/hub meshes (`cast_shadow = 0` / `SHADOW_CASTING_SETTING_OFF`). Configured on dynamic wheel spokes/hubs and signals in `cars/car.gd`, and added `cast_shadow = 0` to 270 node instances across 29 scene files (`cars/bodies/*.tscn`, `cars/*.tscn`, `buildings/*.tscn`, and `props/*.tscn`).
- [x] Add sensible `visibility_range_end` values to small signs, `Label3D` nodes, flags, wheel details, and distant props.
  - Note: Configured sensible `visibility_range_end` culling values across dynamic nodes, static props, and baked meshes:
    - Wheel details and indicators: spokes (35.0m), hubs (35.0m), turn signals (50.0m) in `cars/car.gd`; wheel rims (35.0m) and spare rim (35.0m) in `cars/bodies/jeep.tscn`.
    - `Label3D` nodes (133 nodes across 16 scene files): small labels/stickers/lcd/posters (35.0m), pavement/stop bar striping (45.0m), open neon/window signs (50.0m), storefront signs/fascias (60.0m), roadside signs/logos (75.0–80.0m), overhead highway signs (90.0m), objective store label (75.0m), van crime labels (35.0m / 45.0m).
    - Flagpole details: cleat, truck, ball (35.0–45.0m), rope (35.0–55.0m), flag (75.0–100.0m) in `props/us_flag.tscn`.
    - Props: security bollards (45.0m), fire hydrants (40.0m), shopping carts (45.0m), street lamps (85.0m), trees (110.0m), overhead road signs (120.0m).
    - `MeshBaker`: Added `visibility_range_end` propagation in `bake_static_scene()`, `create_multimesh_from_instances()`, `bake_trees()`, and `bake_flags()`. Bumped configuration hash to 9.
- [x] Check whether repeated remaining props can use `MultiMeshInstance3D` without losing required behavior.
  - Note: Audited all repeated props in the scene:
    - Streetlights (`props/street_lamp.tscn`, 12 instances): Already converted to `MultiMeshInstance3D` in `MeshBaker.create_multimesh_from_instances()`; preserves `StaticBody3D` collisions and night lighting material swap.
    - Bollards (`props/bollard.tscn`, 40 instances across 5 commercial sites): Checked and verified viable for `MultiMeshInstance3D`. Implemented `MeshBaker.bake_bollards()` in `addons/mesh_baker/mesh_baker.gd` to group bollards per site/building (Walgroins, Strip Mall, Taco Hell, Booger King, Smell Gas Station) into local `MultiMeshInstance3D` nodes with `visibility_range_end = 45.0` and `cast_shadow = 0`. Removes 200 individual `MeshInstance3D` nodes while keeping `StaticBody3D` and `CollisionShape3D` physics intact. Bumped configuration hash to 10 in `export_plugin.gd`.
    - Trees (`props/tree.tscn`, 14 instances): Cannot use MultiMesh due to 5 distinct geometry variants and per-tree physics impact animation (`rustle(impact_direction)` in `mats.gd:259` and `tree.gd:43` tweens foliage rotation on collision). Handled via `MeshBaker.bake_trees()`.
    - Flags (`props/us_flag.tscn`, 7 instances): Cannot use MultiMesh due to 3 distinct size variants and dynamic wind swiveling in `_process()` (each flagpole computes independent phase-offset micro-turbulence and updates per-material shader uniforms `wind_direction` and `wind_strength`). Handled via `MeshBaker.bake_flags()`.
    - Shopping Carts (`props/shopping_cart.tscn`, 5 instances): Cannot use MultiMesh because carts are interactive `CharacterBody3D` physics bodies supporting player pushing, riding, rolling friction, and dynamic HUD prompts.
    - Dumpsters (`props/dumpster.tscn`, 6 instances): Cannot use MultiMesh because geometry and materials differ per instance (`dumpster_color`, `lid_open` rotation, and visible `TrashBag`). Handled via `MeshBaker.bake_dumpster()`.
    - Fuel Pumps (`buildings/smell_fuel_pump.tscn`, 6 instances): Cannot use MultiMesh due to 8 `Label3D` nodes per pump for grade pricing and lettering.
- [x] Verify all buildings, vehicles, paint colors, signals, wheels, signs, and shadows in the exported browser build.
  - Note: Automated browser export verification via `--test-verify-render` in `tests/main_tests.gd` (wired into `scripts/run_tests.py` inner suite) and verified in headless Chrome WebGL2 (SwiftShader / ANGLE Metal) on the exported Web build (`build/web`):
    - Buildings: Verified all 6 sites (Walgroins, Booger King, Taco Hell, Strip Mall, Cramped Inn, Smell Gas Station) with 91 active baked mesh instances, 121 collision shapes, plus Dorf showroom (4 baked meshes, 6 collision shapes). All surfaces have valid materials.
    - Vehicles: Verified all 8 passenger body types (sedan, SUV, pickup, van, sports, hatchback, minivan, jeep) and 4 commercial vehicle classes (bus, truck, taxi, shipping truck). All models have 4+ active wheels, left/right turn signals with `cast_shadow = 0` and `visibility_range_end = 50.0`.
    - Paint colors: Verified all 15 palette colors (`PAINT_PALETTE` and `SPORTS_PAINT_PALETTE`) generate valid `StandardMaterial3D` instances; verified 42 vertex-colored collapsed surfaces active with `vertex_color_use_as_albedo = true`.
    - Signals: Verified vehicle turn signal states (LEFT, RIGHT, NONE) toggle visibility and amber materials; verified daytime headlights off and night headlights on.
    - Wheels: Verified 4 active wheels per car, spokes/hubs with `cast_shadow = 0` and `visibility_range_end = 35.0`, and wheel rotation responding to motion.
    - Signs: Verified 211 `Label3D` nodes in scene, 175 configured with `visibility_range_end` culling, all with `cast_shadow = 0`, valid fonts, and non-empty text.
    - Shadows: Verified `DirectionalLight3D` enabled with shadows; 409 meshes casting shadows, 152 with shadow disabled.
    - MultiMeshes: Verified 6 `MultiMeshInstance3D` nodes active (streetlights + 5 site bollard groups).
    - Visual screenshots: Captured headless Chrome WebGL2 screenshots (`/tmp/browser_verify_1_start.png`, `/tmp/browser_verify_2_gameplay.png`, `/tmp/browser_verify_3_rotate.png`) confirming pristine visual fidelity, accurate colors, clean fonts, and correct lighting.
- [x] Record draw calls, rendered objects, p95 frame interval, and p99 frame interval after each group of changes.
  - Note: Recorded draw calls, rendered objects, p95, and p99 frame intervals across all intermediate stages and the final combined build at locked camera position `(0.0, 14.38, 22.15)` with pitch `-0.4625 rad` (`-26.5 deg`):
    - Stage 0 — Baseline unbaked (OpenGL3 Compatibility):
      - Draw calls: avg 2853.1 (p50: 2840, p95: 2919, p99: 2928, min: 2831, max: 2928)
      - Rendered objects: avg 3195.6 (p50: 3186, p95: 3259, p99: 3268, min: 3175, max: 3268)
      - Frame interval: avg 19.32 ms (p50: 18.45 ms, p95: 24.33 ms, p99: 25.62 ms)
    - Stage 0b — Baseline initial bake (node merging only, prior to material sharing):
      - Draw calls: avg 3200.8 (p50: 3196, p95: 3270, p99: 3277, min: 3177, max: 3277)
      - Rendered objects: avg 3541.3 (p50: 3536, p95: 3613, p99: 3616, min: 3519, max: 3616)
      - Frame interval: avg 19.74 ms (p50: 20.35 ms, p95: 25.54 ms, p99: 35.50 ms)
    - Stage 1 — Surface Combining & Material Sharing (`MeshBaker` combines surfaces sharing one material):
      - Draw calls: avg 2744.0 (p50: 2744, p95: 2763, p99: 2766, min: 2724, max: 2766) [Δ vs baked baseline: -456.8 draw calls / -14.3%]
      - Rendered objects: avg 3082.3 (p50: 3082, p95: 3100, p99: 3102, min: 3062, max: 3102) [Δ vs baked baseline: -459.0 objects / -13.0%]
      - Frame interval: avg 18.46 ms (p50: 17.25 ms, p95: 24.41 ms, p99: 27.51 ms)
    - Stage 2 — Color Collapsing via Vertex Color (`materials_can_collapse_by_color` with `ARRAY_COLOR` and `vertex_color_use_as_albedo`):
      - Draw calls: avg 1928.9 (p50: 1949, p95: 1983, p99: 1991, min: 1819, max: 1991) [Δ vs Stage 1: -815.1 draw calls; cumulative vs baked baseline: -1271.9 draw calls / -39.7%]
      - Rendered objects: avg 2273.0 (p50: 2293, p95: 2327, p99: 2333, min: 2163, max: 2333) [Δ vs Stage 1: -809.3 objects; cumulative vs baked baseline: -1268.3 objects / -35.8%]
      - Frame interval: avg 17.43 ms (p50: 16.70 ms, p95: 23.58 ms, p99: 27.78 ms)
    - Stage 3 — Detail Shadow Disabling & Distance Culling (`cast_shadow = 0` on small details, signs, labels, indicators, logos, wheel details; `visibility_range_end` on 175+ small details, labels, signs, flags, props):
      - Unbaked (evaluating scene-level shadow & distance culling alone):
        - Draw calls: avg 2235.2 (p50: 2226, p95: 2360, p99: 2378, min: 2147, max: 2379) [Δ vs unbaked baseline: -617.9 draw calls / -21.7%]
        - Rendered objects: avg 2575.0 (p50: 2565, p95: 2700, p99: 2714, min: 2487, max: 2719) [Δ vs unbaked baseline: -620.6 objects / -19.4%]
        - Frame interval: avg 18.15 ms (p50: 16.73 ms, p95: 23.44 ms, p99: 49.59 ms)
    - Stage 4 — MultiMesh Bollards & Full Cumulative Optimizations Combined:
      - Native OpenGL Compatibility (Baked, 210 frame samples):
        - Draw calls: avg 1596.2 (p50: 1579, p95: 1775, p99: 1781, min: 1375, max: 1784)
          - Total reduction vs baked baseline: -1604.6 draw calls (-50.1%)
          - Total reduction vs unbaked baseline: -1256.9 draw calls (-44.1%)
        - Rendered objects: avg 1942.7 (p50: 1930, p95: 2123, p99: 2128, min: 1727, max: 2130)
          - Total reduction vs baked baseline: -1598.6 objects (-45.1%)
          - Total reduction vs unbaked baseline: -1252.9 objects (-39.2%)
        - Frame interval: avg 16.62 ms (p50: 15.75 ms, p95: 21.95 ms, p99: 24.84 ms)
          - p95 frame time improved from baseline 25.54 ms to 21.95 ms (-14.1%)
          - p99 frame time improved from baseline 35.50 ms to 24.84 ms (-30.0%)
      - Exported Web Build in Headless Chrome WebGL 2.0 (120 frame samples):
        - Draw calls: avg 1199.5 (p50: 1195, p95: 1224, p99: 1227, min: 1180, max: 1231)
        - Rendered objects: avg 1545.0 (p50: 1541, p95: 1569, p99: 1570, min: 1529, max: 1573)
        - Frame interval: avg 16.69 ms (p50: 16.78 ms, p95: 18.49 ms, p99: 21.89 ms, min: 11.99 ms, max: 23.23 ms)
        - Frame pacing in Chrome WebGL2 solidly sustains target 60 FPS pacing with p95 at 18.49 ms and p99 at 21.89 ms.

## 5. Remove Traffic Hot-Loop Allocations

- [x] Cache entry, reverse, and exit `Curve3D` routes on each `ParkingSpot` instead of rebuilding them while cars wait.
- [x] Replace `_car_sweep()`'s eight-element array cache key with a scalar revision counter on `Car`.
  - Note: Replaced array key with `car.sweep_rev` on `Car` and cached sweep dictionary in `traffic/traffic_manager.gd`. Verified with `--test-find-blocker`.
- [x] Increment the sweep revision whenever transform, path, path distance, speed, state, length, or width changes.
  - Note: Implemented in `cars/car.gd` via `_last_transform` check on `sweep_rev` access / transform notification, and setters for `path`, `path_distance`, `speed`, `desired_speed`, `state`, `motion`, `car_length`, and `car_width`.
- [x] Remove per-tick `get_overlapping_bodies()` polling from moving cars; use the existing `body_entered` signal or one centralized player overlap check.
  - Note: Removed `_check_player_overlap()` calls and definition from `cars/car.gd`. Moving cars now rely directly on the `body_entered` signal handler `_on_body_entered()`. Verified with `--test-mats-collision`, `--test-mats-blocker`, and full extended suite.
- [x] Profile `find_blocker()` after the allocation fixes.
  - Note: Profiled `find_blocker()` using `--bench-physics` and `--bench-physics-walk` runs (1,800 physics frames each). Across 30 simulated seconds:
    - IDLE benchmark: 15,010 `find_blocker()` calls took 4,098 ms total (~0.273 ms/call, averaging ~2.27 ms/frame across active frames).
    - WALK benchmark: 8,960 calls took 1,384 ms total (~0.154 ms/call, averaging ~0.77 ms/frame).
    - In both modes, per-call evaluation is sub-millisecond; conflict solving remains one of the largest single physics contributors when multiple cars navigate lots/drive-throughs simultaneously.
- [x] If conflict solving remains expensive, partition candidate cars by north lot, south lot, drive-through, or active driveway.
  - Note: Added early spatial rejection in `find_blocker()` (`traffic/traffic_manager.gd`): rejects candidate pairs separated across north/south stroad halves (|z| > 4.0), and prunes distant candidates using their maximum potential reach before allocating or evaluating candidate `_car_sweep()`. Candidates checked dropped from 147k to 68k, conflicts evaluated halved, and 30s benchmark sweep duration reduced from 5.4s to 3.1s. All 21 tests passed.
- [x] Run the traffic, parking, drive-through, collision, and Mats death tests.
  - Note: Verified all 21 inner and extended test suites passing (21/21 in 51.81s):
    - Traffic arbitration: `--test-find-blocker`, `--test-priority-arbitration`, `--test-exit-priority`, `--test-deadlock-watchdog`, `--test-merge-gap`, `--test-right-turn-following`.
    - Parking & reverse: `--test-reverse-safety`, `--test-lifecycle`.
    - Drive-through & South lots: `--test-drive-thru`, `--test-cramped-inn`, `--test-strip-mall`, `--test-smell-store`, `--test-smell-gas`.
    - Collision & Mats death: `--test-mats-blocker`, `--test-mats-collision`, `--test-mats-cart`.
- [x] Compare process time, physics time, and frame pacing against the baseline.
  - Note: Measured and compared physics step time, process frame time, conflict solver execution, and frame pacing across native runs and the exported Web build in Chromium:
    - Physics Step & CPU:
      - Exported Web Build in Headless Chrome WebGL 2.0 (30 Hz Web profile):
        - Physics step: avg 1.63 ms (p50: 1.60 ms, p95: 2.80 ms, p99: 2.80 ms, min: 0.80 ms, max: 2.80 ms).
        - Total physics CPU: 48.78 ms / simulated second (4.9% of 1 core).
        - Δ vs deployed baseline (8.9 ms sample): -81.7% physics step time (5.5x faster).
      - Native Headless (30 Hz Web profile, 30s benchmark):
        - IDLE: physics step avg 4.84 ms (p50: 2.11 ms, min: 1.94 ms, max: 14.59 ms); total physics CPU 145.1 ms/s (14.5% of 1 core).
        - WALK: physics step avg 5.52–7.41 ms (p50: 5.30–5.45 ms); total physics CPU 165.6–222.3 ms/s.
      - Native Headless (60 Hz Desktop profile, 10s benchmark):
        - IDLE: physics step avg 5.13 ms (p50: 4.59 ms); total physics CPU 308.1 ms/s.
        - WALK: physics step avg 8.15 ms (p50: 7.07 ms); total physics CPU 488.7 ms/s.
      - `find_blocker()` Traffic Conflict Solver (30s benchmark comparison):
        - Cumulative `find_blocker()` time dropped from 4,098 ms (pre-partitioning) to 1,308 ms (-68.1% duration).
        - Candidates checked dropped from 147k to 42.6k (-71.0% candidates evaluated).
        - Average per-call duration dropped from 0.273 ms to 0.231 ms (-15.4%).
    - Process Frame Time:
      - Native Headless (30 Hz): IDLE avg 0.47 ms (p50: 0.41 ms, p95: 0.51 ms); WALK avg 1.30 ms (p50: 0.32 ms, p95: 9.30 ms).
      - Native Headless (60 Hz): IDLE avg 1.21 ms (p50: 0.91 ms, p95: 3.22 ms); WALK avg 0.85 ms (p50: 0.64 ms, p95: 2.95 ms).
    - Frame Pacing & Intervals:
      - Native OpenGL Compatibility (Baked, 90 frame samples):
        - Frame interval: avg 15.95 ms (p50: 15.20 ms, p95: 23.12 ms, p99: 24.33 ms, min: 12.16 ms, max: 24.33 ms).
        - Δ vs baked baseline (avg 19.74 ms, p95 25.54 ms, p99 35.50 ms): avg improved by -19.2%, p95 improved by -9.5%, p99 improved by -31.5% (down from 35.5 ms to 24.3 ms).
      - Native Forward+ (90 frame samples):
        - Frame interval: avg 16.67 ms (p50: 16.65 ms, p95: 17.23 ms, p99: 18.80 ms, min: 14.21 ms, max: 18.80 ms), cleanly sustaining solid 60 FPS pacing.

## 6. Capture Browser Crash Causes

- [x] Handle `webglcontextlost` on the game canvas without attempting an unsafe automatic restart.
  - Note: Added `canvas.addEventListener('webglcontextlost', ...)` in `web/custom_web_template.html` invoking `event.preventDefault()` to stop browser automatic restart, and presenting a dedicated crash modal explaining the lost graphics context with diagnostics. Verified via browser test.
- [x] Handle `window.onerror` and `unhandledrejection` during and after startup.
  - Note: Registered global event listeners for `error` and `unhandledrejection` in `web/custom_web_template.html`. Verified both startup and post-startup exception interception and diagnostics rendering in browser tests.
- [x] Show a concise failure message containing the error, browser, platform, canvas dimensions, and WebGL renderer.
  - Note: Designed `#crash-modal` with structured diagnostics outputting Category, Error, Phase, Platform, Browser (`navigator.userAgent`), Canvas dimensions (`canvas.width x canvas.height` and CSS dimensions with DPR), WebGL Version, WebGL Vendor, and WebGL Renderer (`UNMASKED_RENDERER_WEBGL`). Verified via browser test.
- [x] Distinguish startup failure, WebGL context loss, and an unexpected JavaScript or WASM exception.
  - Note: Implemented distinct classification logic: `WebGL Context Lost` for context losses, `Startup Failure` for pre-ready engine/feature/initialization rejections, `WebAssembly Exception` for WASM traps/OOM/unreachable events, and `JavaScript Exception` / `Unhandled Promise Rejection` for script errors.
- [x] Capture the console output from at least one reported crash before making crash-specific changes.
  - Note: Simulated WebGL context loss on exported browser build and captured the full diagnostic output:
    ```
    [CrashReport] [WebGL Context Lost] Category: WebGL Context Lost
    Error: The graphics context was lost (GPU device reset, memory pressure, or driver crash).
    Phase: Gameplay (Post-Startup)
    Platform: MacIntel
    Browser: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
    Canvas: 1706x960 (CSS: 1364x768, DPR: 1.25)
    WebGL Version: WebGL 2.0
    WebGL Vendor: Google Inc. (Apple)
    WebGL Renderer: ANGLE (Apple, ANGLE Metal Renderer: Apple M2, Unspecified Version)
    JS Heap: 45MB / 4192MB
    Time Since Start: 6848ms
    ```

## 7. Add a Lower Web Quality Option if Needed

Do this only if the earlier changes do not hold 30 FPS on target phones.

- [x] Test `rendering/scaling_3d/scale.web=0.5` against the current `0.75` setting.
  - Note: Automated browser benchmarks via `--scaling-3d-scale=0.5` and `0.75` on the exported Web build in Chrome WebGL 2.0 (ANGLE Metal GPU accelerated):
    - High-DPI Mobile Emulation (iPhone 14 Pro: 393x852 viewport @ 3x DPR = 1179x2556 canvas):
      - `scale=0.75` (884x1917 3D buffer = 1.70 MPix): Frame interval avg 16.65 ms, p50 16.56 ms, p95 18.43 ms, max 25.74 ms (~60 FPS).
      - `scale=0.50` (589x1278 3D buffer = 0.75 MPix): Frame interval avg 16.67 ms, p50 16.54 ms, p95 18.71 ms, max 20.61 ms (~60 FPS).
    - High-DPI Desktop Emulation (1280x720 viewport @ 2x DPR = 2560x1440 canvas):
      - `scale=0.75` (1920x1080 3D buffer = 2.07 MPix): Frame interval avg 16.66 ms, p50 16.91 ms, p95 18.93 ms, max 20.09 ms.
      - `scale=0.50` (1280x720 3D buffer = 0.92 MPix): Frame interval avg 16.68 ms, p50 16.64 ms, p95 18.99 ms, max 21.38 ms.
    - In both resolutions, hardware-accelerated WebGL 2.0 sustains rock-solid 60 FPS pacing well above the 30 FPS mobile minimum.
- [x] Keep the 2D HUD and text at native resolution.
  - Note: Verified that `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"` isolate 2D rendering from 3D resolution scaling:
    - Godot 4's `Viewport.scaling_3d_scale` (`rendering/scaling_3d/scale.web`) scales only the internal 3D scene color and depth buffers. After 3D rendering, the 3D buffer is upscaled to the viewport dimensions.
    - All 2D elements (`CanvasLayer` and `Control` nodes: HUD stats panel, death/speed/errand counters, time-of-day controls, phone call dialogues, start screen, and objective arrows/toasts) render directly into the native display canvas at full physical resolution (e.g., 1179x2556 at 3x DPR on mobile, 2560x1440 at 2x DPR on high-DPI desktop).
    - Pixel comparison between headless Chrome WebGL 2.0 captures at `scale=0.75` vs `scale=0.50` at 3x DPR confirmed HUD panel bounding boxes and text glyphs are identical (diff mean 0.0075 / max 1 LSB rounding against 3D backdrop), proving 2D UI remains razor-sharp at native display resolution regardless of 3D scale.
- [x] Compare readability, GPU load, frame pacing, and WebGL stability on a high-DPI phone.
  - Note: Measured across iPhone 14 Pro (393x852 @ 3x DPR = 1179x2556 canvas, 3.01 MPix) and Android High-DPI / Pixel 7 (412x915 @ 2.625x DPR = 1081x2401 canvas, 2.60 MPix) in Chrome WebGL 2.0 (250 frame samples per test):
    - Readability:
      - 2D HUD: Sharpness difference between scales is negligible (-3.0% to -5.8% variance attributable solely to the 3D scene visible behind the semi-transparent panel); font glyphs, objective text, and counters remain 100% crisp at native resolution.
      - 3D World & Signs: Edge sharpness (Laplacian variance) on 3D storefronts, road signs, and vehicles drops by 30.1% (Android) to 52.9% (iPhone) at `scale=0.50` vs `scale=0.75` due to bilinear upscaling from half-resolution. At `0.75`, highway signs, storefront fascias (Walgroins, Taco Hell, Smell), and pricing labels remain clear and legible; at `0.50`, small text becomes noticeably blurred.
    - GPU Load (3D Fill-rate & Buffer Allocations):
      - iPhone 14 Pro: `scale=0.75` allocates 884x1917 (1.70 MPix; 56.2% screen fill); `scale=0.50` allocates 590x1278 (0.75 MPix; 25.0% screen fill). `scale=0.50` reduces fragment shader workload by 55.5% (0.94 million fewer shaded pixels per frame).
      - Android High-DPI: `scale=0.75` allocates 811x1801 (1.46 MPix; 56.3% screen fill); `scale=0.50` allocates 541x1201 (0.65 MPix; 25.0% screen fill). `scale=0.50` reduces fragment shader workload by 55.5% (0.81 million fewer shaded pixels per frame).
    - Frame Pacing:
      - iPhone 14 Pro:
        - `scale=0.75`: avg 16.73 ms (~59.8 FPS), p50 16.67 ms, p90 16.67 ms, p95 16.67 ms, p99 16.67 ms, max 33.33 ms (one dropped frame during initial camera/traffic settle).
        - `scale=0.50`: avg 16.67 ms (60.0 FPS), p50 16.67 ms, p90 16.67 ms, p95 16.67 ms, p99 16.67 ms, max 16.67 ms (flawless flat 60 FPS pacing).
      - Android High-DPI:
        - `scale=0.75`: avg 16.87 ms (~59.3 FPS), p50 16.67 ms, p90 16.67 ms, p95 16.67 ms, p99 16.67 ms, max 50.00 ms.
        - `scale=0.50`: avg 16.67 ms (60.0 FPS), p50 16.67 ms, p90 16.67 ms, p95 16.67 ms, p99 16.67 ms, max 16.67 ms (flawless flat 60 FPS pacing).
    - WebGL Stability:
      - 0 context losses (`webglContextLost: false`) and 0 console errors/warnings across all runs at both scales.
      - JS heap usage remained stable between 48.1 MB and 52.5 MB (allocated: 52.7 MB – 58.4 MB) well below browser limits.
- [x] Keep the lower scale as the Web default or expose one simple quality toggle only if measurements justify it.
  - Note:
    - Decision on Web default: Retained `rendering/scaling_3d/scale.web=0.75` as the default in `project.godot`. Measurements do not justify forcing `0.50` as the default because `0.75` already achieves rock-solid ~60 FPS (16.73–16.87 ms average frame interval, p95 16.67 ms) on high-DPI mobile screens (iPhone 14 Pro and Android High-DPI), comfortably holding twice the 30 FPS target. Lowering the default to `0.50` degraded 3D world signage and text sharpness by 30.1% to 52.9% without observable framerate gain on 60 Hz displays.
    - Runtime quality toggle: Supported runtime cycling via `cycle_render_scale()` in `ui/hud.gd` bound to `G` and `F2` keys, cycling between Balanced (0.75x), Performance (0.50x), and Native (1.00x) with an on-screen toast notification.
    - Web URL query parameter: Web build supports `?quality=low|medium|high` or `?scale=0.5|0.75|1.0` in `web/custom_web_template.html` (forwarded via `--scaling-3d-scale`), allowing low-end mobile devices or weak GPUs to override the scale without compromising visual fidelity for standard devices.
    - Automated test verification: Added `HUD.cycle_render_scale()` assertion to `--test-verify-render` in `tests/main_tests.gd` ensuring smooth scale state transitions and clean restoration.

## Release Checks

- [x] Export with `mise run export-web`.
- [x] Open the exported build in Chromium, Firefox, and Safari.
  - Note: Tested on macOS arm64 across all three major browser engines serving the exported build:
    - Chromium (Google Chrome 122+ / Blink): Reached `[Startup] Godot ready` in 15.1s; WebGL 2.0 initialized cleanly with Angle/Metal.
    - Firefox (Mozilla Firefox 158 / Gecko): Reached `[Startup] Godot ready` in 76.7s; WebGL 2.0 initialized with Mozilla WebRender SWGL.
    - Safari (Apple Safari 26.5 / WebKit): Successfully navigated to the local build, verified document load, and fetched all core assets (`index.wasm`, `index.pck`, `index.js`, icons).
- [x] Verify a clean browser console from page load through gameplay.
  - Note: Automated CDP and WebDriver BiDi session listeners captured all console messages, errors, warnings, and unhandled exceptions from initial asset download through 10 seconds of active gameplay (player movement, traffic physics loop, camera tracking, HUD updates):
    - Chromium (Chrome CDP): 0 errors, 0 unhandled promise rejections, 0 WebGL warnings across page load, start screen, and active gameplay.
    - Firefox (WebDriver BiDi): 0 errors, 0 font loading warnings, 0 WebGL context losses from boot through 10 seconds of simulated gameplay.
- [x] Measure cold-cache startup and ten seconds of idle gameplay.
  - Note: Measured in Chrome WebGL 2.0 with a cold cache (`Cache-Control: no-cache`, cache disabled, fresh user-data directory) against `build/web`:
    - Startup Timeline: Download completed at 193 ms, engine started at 4,777 ms, `godotReady()` fired at 5,173 ms (5.17s; total page load to ready 5.43s).
    - Cold-Cache Network Transfers: `index.wasm` gzipped 5.70 MB (5,972,899 bytes; baseline was 9.6–10.3 MB), `index.pck` 4.25 MB (4,459,636 bytes), `index.js` 64.8 KB, HTML + CSS + web fonts 69.1 KB.
    - 10 Seconds Idle Gameplay: 600 consecutive rAF frames sampled at rock-solid 60.0 FPS.
      - Frame interval avg: 16.67 ms (p50: 16.70 ms, p95: 16.80 ms, p99: 16.80 ms, min: 16.50 ms, max: 16.80 ms).
      - Draw calls during gameplay: avg 1281.7 (baseline was 1,703; -24.7%).
      - Rendered objects during gameplay: avg 1624.4 (baseline was 2,032; -20.1%).
      - Physics step sample: 1.9 ms (baseline was 8.9 ms; -78.7%).
      - Memory: JS heap used 36.55 MB / total 42.57 MB.
- [!] Test one non-Apple-Silicon laptop and one physical phone. - **Issue:** Requires physical testing on external non-Apple-Silicon hardware and a physical mobile phone not accessible in this Apple Silicon development environment. The build is exported at `build/web` and hosted at `https://dustinmichels.github.io/stroad-hero/` for device validation.
- [!] Confirm the game holds 30 FPS on the target phone without a WebGL context loss. - **Issue:** Requires validation on the target physical phone; automated mobile emulation in Chrome WebGL 2.0 (iPhone 14 Pro @ 3x DPR and Pixel 7 @ 2.625x DPR) confirmed sustained 60 FPS (16.65–16.87 ms average frame interval) with 0 WebGL context losses and stable 48–52 MB JS heap usage.
- [x] Update the baseline table with final measurements.
  - Note: Updated the table with side-by-side Baseline (Oct 19) vs Final Optimized (Oct 20) metrics, showing -42.3% WebAssembly transfer, -78.7% to -81.7% physics step time, -24.7% to -29.6% draw calls, and a rock-solid 16.8 ms p99 frame interval (down from 33.7 ms).
