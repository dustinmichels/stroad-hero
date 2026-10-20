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
- [ ] Replace `_car_sweep()`'s eight-element array cache key with a scalar revision counter on `Car`.
  - Note: Initial work in progress in `cars/car.gd` (`sweep_rev`) and `traffic/traffic_manager.gd` (`_car_sweep()`). Investigating geometry handling in `--test-find-blocker`.
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
