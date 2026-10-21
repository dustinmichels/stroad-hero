# Performance Optimizations and Profiling Findings

Technical record of profiling discoveries, architectural bottlenecks, and optimization implementations across desktop (Forward+) and web (Compatibility) renderers.

---

## 1. Summary of Results

Measured on Apple M2 (2940×1782 window, Godot 4.7.2) via standardized 20-second phase gameplay benchmarks (`--bench-gameplay` and `--bench-gameplay-compat`).

| Metric / Scenario                        | Baseline (Before)                 | Optimized (After)                       | Impact / Delta                                   |
| ---------------------------------------- | --------------------------------- | --------------------------------------- | ------------------------------------------------ |
| **Forward+ Day Frame Time**              | 16.7 ms (p95: 17.9 ms)            | 17.36 ms (p50: 16.66 ms, p95: 16.98 ms) | Steady 60 fps vsync lock                         |
| **Forward+ Night Frame Time**            | 17.3 ms (p95: 20.7 ms)            | 16.68 ms (p50: 16.65 ms, p95: 18.11 ms) | Stable 59.9 fps average; night p95 ~1 ms of day  |
| **Forward+ Dusk Hitch (Max)**            | **153.0 ms**                      | **38.38 ms**                            | **4.0× reduction** (eliminated shader stall)     |
| **Compatibility Day Frame Time**         | 25.4 ms (p95: 34.2 ms)            | 22.44 ms (p50: 20.15 ms, p95: 27.86 ms) | **+14.4% framerate** (39 fps → 44.6 fps)         |
| **Compatibility Night Frame Time**       | 41.8 ms (p95: 50.9 ms)            | 32.27 ms (p50: 31.76 ms, p95: 41.32 ms) | **+29.2% framerate** (24 fps → 31.0 fps)         |
| **Compatibility Dusk Hitch (Max)**       | **852.0 ms**                      | **60.70 ms**                            | **14.0× reduction** (eliminated near-1s stall)   |
| **Compatibility Draw Calls (Day)**       | ~3,400                            | 1,565.1 (p50: 1,557)                    | **54.0% reduction** (>1,830 fewer calls/frame)   |
| **Compatibility Render Objects (Day)**   | ~3,800                            | 1,834.6 (p50: 1,831)                    | **51.7% reduction** (>1,960 fewer objects)       |
| **Scene Primitives (Forward+)**          | 5,360,826                         | 841,060                                 | **84.3% reduction** (4.52M fewer primitives)     |
| **Traffic Script Time (`find_blocker`)** | 144.0 ms / sim sec (2.4 ms/frame) | 52.3 ms / sim sec (~0.87 ms/frame)      | **2.75× faster**; 99.88% array allocations saved |
| **Forest Startup Build Time**            | >350 ms                           | 9.6 ms                                  | **>97% faster** startup                          |

---

## 2. Identified Bottlenecks

1. **Shader Compilation Stall at Dusk**:
   - `WorldWarmup` originally warmed only daytime shaders.
   - Transitioning from day to night triggered simultaneous first-time compilation of emissive materials (`Car._headlight_mat_on`, `EnvironmentController._get_lamp_bulb_on_mat`) and active `SpotLight3D` pipelines, creating 153 ms hitches in Forward+ and 852 ms freezes in Compatibility.
2. **Nighttime Lighting Scale**:
   - 103 active `SpotLight3D` nodes (headlamps on every moving car plus streetlights) overloaded the Compatibility renderer, which shades lights per object.
   - Streetlight cones (16 m range at 55°) had excessive overlap and wasted fill volume underground.
3. **Traffic Manager Quadratic Lookups & Allocation Churn**:
   - `TrafficManager.find_blocker` accounted for ~11.6% of single-core CPU time (~1.9 ms/frame).
   - Rebuilt candidate lists on every check via linear scanning (`candidates.has(ghost)`), causing $O(n^2)$ behavior as lots filled.
   - Moving vehicles cleared and reallocated arrays/dictionaries in `CarSweep.car_sweep` every physics tick.
   - `Time.get_ticks_usec()` and statistics dictionary logging ran on every single evaluation.
4. **Shadow Cascade Draw Call Duplication**:
   - Directional shadow cascades doubled draw call volume across both renderers.
   - Flat, small, or distant visual assets (road markings, parking stall stripes, logos, sign borders, chainlink fabric) were unnecessarily submitting shadow passes.
5. **Forest Geometry & Node Overhead**:
   - `Forest.build_forest` instantiated 708 `StreetTree` instances. Each instance loaded 7 variants (including two `.blend` models) and freed 6 in `_ready()`, generating 560k+ primitives, 708 `StaticBody3D` nodes, and 708 `CollisionShape3D` nodes for inaccessible background trees.
   - Procedural tree meshes used excessive tessellation (64 radial segments for trunks, 64×32 for foliage spheres).
6. **Unculled 3D Text (`Label3D`)**:
   - 280 `Label3D` nodes across commercial signs, reader boards, and highway overheads lacked distance limits, causing continuous font glyph raster submission and transform evaluation regardless of distance.
   - Distant labels lacked alpha transition margins, leading to jarring pop-in/pop-out.

---

## 3. Implemented Solutions

### 3.1 Dusk Shader Warmup & Staggered Switching

- **Pipeline Pre-warming** (`world/world_warmup.gd`):
  - Behind the loading screen, `WorldWarmup` forces a single-frame render pass with emissive headlamp and streetlight materials and a dummy active `SpotLight3D`.
  - Compiles the lit shader variants before gameplay begins.
- **Staggered Activation** (`cars/car.gd`):
  - Evening headlight ignition spreads over random time offsets per vehicle rather than flipping all vehicles and streetlamps in the identical frame.

### 3.2 Night Lighting & Headlamp LOD

- **Headlamp Level of Detail** (`traffic/traffic_manager.gd`):
  - `TrafficManager._update_headlamp_lod()` restricts real `SpotLight3D` hardware illumination to the closest 12 moving vehicles (`MAX_ACTIVE_HEADLAMPS`) relative to the camera.
  - Distant and parked vehicles retain their visual emissive lens shader (`_headlight_mat_on`) without spawning a dynamic light source.
- **Distance Culling & Range Tuning** (`props/street_lamp.tscn`, `cars/car.gd`):
  - Headlamp and streetlamp lights enable `distance_fade_enabled` (begin ~35 m, length ~10 m).
  - Streetlamp `spot_range` reduced from 16.0 m to 12.0 m (height is 6.2 m with a 55° cone; 10.8 m hypotenuse covers the ground fully while eliminating underground light volume and cross-stroad cone overlap).
  - Pinned `rendering/limits/opengl/max_lights_per_object = 8` for web compatibility.

### 3.3 Traffic CPU & Sweep Memory Cache

- **Single-Pass Candidate Extraction** (`traffic/traffic_manager.gd`):
  - Candidates are collected once per physics tick in `_update_lot_cars` using instance-ID dictionary deduplication (`seen` dict), eliminating $O(n^2)$ array searches.
- **Early Rejection Pipeline**:
  - Checks opposite-side $z$-axis alignment and squared Euclidean distance (`my_pos.distance_squared_to(other_pos) > reach * reach`) before evaluating spline lookaheads or swept footprints.
- **Sweep Cache Persistence** (`traffic/car_sweep.gd`, `cars/car.gd`):
  - Retained `_sweep_cache` across ticks with periodic 60-tick cleanup for destroyed instances instead of wiping every frame.
  - Guarded `Car.speed` setter to update only on distinct values (`speed != value`).
  - Moving vehicles reuse pre-allocated rect/dist arrays (7,458 reuses vs 22 initial allocations in test runs; 99.88% reduction in heap churn). Stopped cars hit the `sweep_rev` cache directly (59.6% hit rate).
- **Profiling Decoupling**:
  - Per-call microsecond timing and dictionary writes gated behind `profile_find_blocker` (CLI `--profile-traffic`). Production runs bypass profiling overhead entirely.

### 3.4 Shadow Draw Call Elimination

- **Shadow Caster Audit**:
  - Configured `cast_shadow = SHADOW_CASTING_SETTING_OFF` (`0`) on:
    - 161 striping meshes in `world/road.tscn`.
    - 41 stall, lot, rut, and desire-path meshes in `world/parking.tscn`.
    - Drive-thru striping and directional arrows in `booger_king_site.tscn` and `taco_hell.tscn`.
    - Parking stripes in frontage commercial and retail scenes.
    - Flat signage borders, logo trims, and billboards (`props/overhead_road_sign.tscn`, `booger_king_sign.tscn`, `booger_king_logo.tscn`, `smell_logo.tscn`, `abominos_logo.tscn`, `dorf_logo.tscn`, `props/billboard.tscn`).
    - Chainlink fence fabric mesh in `props/chainlink_fence.gd` (retaining solid post and top-rail shadows).
    - Van wheel hubcaps and beauty rings in `cars/van.tscn`.
- **Web Shadow Overrides** (`world/environment_controller.gd`):
  - When running under Web (`OS.has_feature("web")`) or `--force-web-shadows`, `EnvironmentController.apply_web_shadow_overrides()` switches directional sunlight to 1-split orthogonal shadows (`DirectionalLight3D.SHADOW_ORTHOGONAL`) and caps max shadow distance to 45.0 m.
  - Slashes Compatibility draw calls from ~3,300 to ~2,212 without degrading character or vehicle contact shadows.

### 3.5 Procedural Forest & Geometry Consolidation

- **MultiMesh Instancing** (`props/forest.gd`):
  - Replaced 688 individual `StreetTree` instances outside the fence with 36 `MultiMeshInstance3D` nodes (18 variant mesh components partitioned into East/West and Near/Far buckets).
  - Completely removed 688 `StaticBody3D` nodes and 688 `CollisionShape3D` nodes from physics memory.
- **On-Demand Tree Variant Assembly** (`props/tree.gd`, `props/tree.tscn`):
  - Stripped 7 pre-baked variant sub-scenes from `tree.tscn`.
  - Procedural cylinders and spheres are generated and shared via static caches; `.blend` assets (`tree1.blend`, `tree2.blend`) load lazily only when requested.
- **Distance & Shadow Culling**:
  - Forest multimeshes configure `visibility_range_end = 160.0`, `visibility_range_end_margin = 25.0`, and `visibility_range_fade_mode = VISIBILITY_RANGE_FADE_SELF`.
  - Trees beyond 40 m from the stroad fence (`Far` multimeshes, 42% of forest) have shadow casting disabled.
- **Tessellation Tuning**:
  - Procedural tree trunk cylinders reduced from 64 radial segments to 10 (1 ring).
  - Foliage spheres reduced from 64×32 segments down to 16×8 segments.
  - Overall scene primitives plummeted by 84.3% (from 5,360,826 to 841,060).

### 3.6 Sign Text (`Label3D`) Visibility Culling and Smooth Fading

- **Distance Hierarchy Across All 3D Labels**:
  - Audited and assigned explicit `visibility_range_end` distances (35 m to 120 m) across 100% of scene-authored `Label3D` nodes (274 total active instances):
    - Overhead highway green signs: 85 m.
    - Highway gantry truss route markers: 120 m.
    - Large pylon signs (Booger King, Smell, Dorf, Cramped Inn): 60 m to 80 m.
    - Storefront fascias and strip mall tenant signage: 45 m to 60 m.
    - Window posters, reader boards, and fuel pump labels: 35 m to 40 m.
    - Runtime debug labels (`traffic/traffic_debug.gd`, `props/tunnel.gd`): 35 m to 60 m.
- **Dynamic Fade Margin & Self-Fade Configuration** (`main.gd`):
  - In `Main._ready()`, tree crawls and dynamic `node_added` signal connections route through `_configure_label_fade`:
    ```gdscript
    const LABEL_FADE_MARGIN_METERS := 12.0

    func _configure_label_fade(node: Node) -> void:
        if node is not Label3D:
            return
        var label := node as Label3D
        if label.visibility_range_end <= 0.0:
            return
        label.visibility_range_end_margin = minf(
            LABEL_FADE_MARGIN_METERS, label.visibility_range_end * 0.3
        )
        label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    ```
  - Automatically calculates a proportional fade margin (up to 12 m) and applies `VISIBILITY_RANGE_FADE_SELF` to prevent text from popping abruptly or submitting render passes at long ranges.
- **Automated Regression Verification** (`tests/benchmarks_suite.gd`):
  - `_run_verify_render_test()` asserts that 100% of `Label3D` instances in the active scene tree satisfy:
    1. `visibility_range_end > 0.0`
    2. `visibility_range_end_margin > 0.0`
    3. `visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF`

### 3.7 CPU Lifecycle & Update Throttling

- **Environment Update Throttling** (`world/environment_controller.gd`):
  - `apply_time_hours` throttled by `TIME_THROTTLE_HOURS = 0.005` (~18 in-game seconds, ~3.33 Hz at standard day speed). Discrete TOD events still apply immediately.
- **Turn Signal Material Debouncing** (`cars/car.gd`):
  - State tracking `_signal_blink_is_on` ensures `material_override` is only set when the blink state flips between on and off, rather than every physics tick.

---

## 4. Profiling Tools & Benchmark Suite

- **Accurate Physics Timers** (`tests/benchmarks_suite.gd`):
  - Replaced Godot's built-in `Performance.TIME_PHYSICS_PROCESS` (which reports the 1-second rolling maximum rather than true per-step cost) with per-tick stopwatch probes hooked to `SceneTree.physics_frame` at priority $1 \ll 30$.
- **Fixed-FPS CPU Benchmarking** (`scripts/run_tests.py`):
  - Added `--fixed-fps 60` execution mode. Decouples frame progression from display vsync and OS power throttling, allowing wall time to represent CPU execution demand directly.
- **Windowed Realtime Gameplay Benchmark**:
  - `mise run bench -- --bench-gameplay` (Forward+) and `mise run bench -- --bench-gameplay-compat` (Compatibility):
    - Executes 20 s day phase, transitions time to dusk (19.9 h), and executes 20 s night phase with an active camera follow.
    - Records frame time distributions (avg, p50, p95, p99, max), spike counts (>20 ms, >33 ms), draw calls, and rendered object counts.
- **Web Export Headless Automation** (`scripts/smoke_check_web.js`):
  - Uses Chrome DevTools Protocol (CDP) to drive the exported WebAssembly build headlessly.
  - Bypasses the start screen via bridge hook `window.godotStartGame()`, programmatically sets time of day via `window.godotSetTimeHours()`, and samples `requestAnimationFrame` intervals to verify browser performance without manual interaction.
