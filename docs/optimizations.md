# Performance Optimizations and Profiling Findings

Technical record of profiling discoveries, architectural bottlenecks, and optimization implementations for the desktop (Forward+) renderer. Compatibility measurements below were the proxy for the Web build, which was dropped on Oct 28, 2026, along with `--bench-gameplay-compat` and the web-only shadow overrides.

---

## 1. Summary of Results

Measured on Apple M2 (2940×1782 window, Godot 4.7.2) via standardized 20-second phase gameplay benchmarks (`--bench-gameplay` and the since-removed `--bench-gameplay-compat`).

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

### 3.5 Procedural Forest & Geometry Consolidation

- **MultiMesh Instancing** (`props/forest.gd`):
  - Replaced 688 individual `StreetTree` instances outside the fence with per-tile `MultiMeshInstance3D` nodes (18 variant mesh components × 40 m tiles × Near/Far; see §5.8).
  - Completely removed 688 `StaticBody3D` nodes and 688 `CollisionShape3D` nodes from physics memory.
- **On-Demand Tree Variant Assembly** (`props/tree.gd`, `props/tree.tscn`):
  - Stripped 7 pre-baked variant sub-scenes from `tree.tscn`.
  - Procedural cylinders and spheres are generated and shared via static caches; `.blend` assets (`tree1.blend`, `tree2.blend`) load lazily only when requested.
- **Distance & Shadow Culling**:
  - Forest tiles configure `visibility_range_end = 160.0` plus the tile half-diagonal (≈188 m, measured to the tile center), `visibility_range_end_margin = 25.0`, and `visibility_range_fade_mode = VISIBILITY_RANGE_FADE_SELF`.
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
- **Waypoint Tour Benchmark** (`tests/benchmarks_suite.gd`, `--bench-tour`):
  - Teleports Mats through 11 fixed waypoints, day and night, after a congestion warmup (default 120 s). Reports per-waypoint p50/p95/max for frame interval, physics steps, TrafficManager / Mats / other physics script ms (priority stamp nodes), render CPU, GPU (Vulkan only), draw calls, and primitives, plus every spike with its `tm` share and clock hour.
  - Between day and night, a `dusk` phase holds the first waypoint and sweeps the clock 18.0 → 19.6 h in 10 s (the in-game rate is ~96 s), recording every frame so the lights-on (18.25 h) and night (19.5 h) switches are sampled. `--tour-phases=` picks any of `day,dusk,night`.
  - `--gpu-profile` (runner flag) switches to Vulkan, passes the engine's `--gpu-profile`, and prints per-pass GPU means per phase/waypoint from the engine's ~1 s blocks (attributed via `BENCH_TOUR_SAMPLE:` markers). The raw blocks are dropped from the log.
  - `mise run export-mac-pack` writes a baked `/tmp/stroad_mac.pck`. `mise run bench --bench-tour --main-pack=/tmp/stroad_mac.pck` benchmarks the shipped build instead of the unbaked editor scene.
- **TrafficManager Section Timers** (`--profile-traffic`):
  - Prints `TM_PROFILE:` every 600 ticks with avg/max ms for each `_physics_process` section (stops, lane traffic, lane spawning, transfers, lot cars, despawn) and per-tick `find_blocker` cost. Production ticks take the untimed path.
- **Windowed Realtime Gameplay Benchmark**:
  - `mise run bench -- --bench-gameplay`:
    - Executes 20 s day phase, transitions time to dusk (19.9 h), and executes 20 s night phase with an active camera follow.
    - Records frame time distributions (avg, p50, p95, p99, max), spike counts (>20 ms, >33 ms), draw calls, and rendered object counts.

---

## 5. Desktop Performance Plan Baseline (Oct 22, 2026)

Before-numbers for `docs/plans/desktop_performance.md`; each item records its after-numbers here. Run: `mise run export-mac-pack && mise run bench --bench-tour --main-pack=/tmp/stroad_mac.pck --profile-traffic --seed=1` (Metal, M2, 2940×1782, vsync, 120 s warmup, about 64 cars).

| Phase | Frame interval p50 / p95 (worst waypoint)         | Worst frame           | `tm` p95 range (ms) | Waypoints with p95 = 2 steps | Spikes |
| ----- | ------------------------------------------------- | --------------------- | ------------------- | ---------------------------- | ------ |
| Day   | 19.1 / 27.0 (car_care), 18.7 / 29.9 (cramped_inn) | 40.2 ms (cramped_inn) | 3.2–7.9             | 5 of 11                      | 102    |
| Night | 24.7 / 28.8 (cramped_inn), 23.5 / 26.2 (car_care) | 112.4 ms (west_road)  | 3.3–13.6            | 8 of 11                      | 150    |

- Night congestion is CPU-bound in traffic. Wherever `tm` p95 tops 10 ms, the frame runs 2 physics steps (booger_king, car_care, cramped_inn, east_road, strip_mall, west_road). Render CPU p95 is 3–5 ms at those waypoints, versus 1–2 ms in the day.
- `TM_PROFILE` (21 windows): `lot_cars` dominates at 1.3–4.7 ms/tick avg (max 9.9 ms), most of it in `find_blocker` (7–19 calls/tick, 0.9–4.3 ms/tick). `lane_traffic` is 0.6–1.2 ms. `lane_spawning` averages about 0.06 ms but peaks at 24 ms (car `instantiate()`).
- Baked pack: 0.44–1.44M primitives and 610–1,690 draw calls per waypoint.

### 5.1 `max_physics_steps_per_frame=3` on all platforms

Same command, after the change (`project.godot`: the `.web` override became the global setting).

| Phase | Frame interval p50 / p95 (worst waypoint)          | Worst frame           | `tm` p95 range (ms) | Max steps in a frame | Spikes |
| ----- | -------------------------------------------------- | --------------------- | ------------------- | -------------------- | ------ |
| Day   | 16.6 / 21.6 (west_road), 16.6 / 20.7 (cramped_inn) | 101.3 ms (east_road)  | 3.5–8.0             | 3                    | 17     |
| Night | 16.5 / 19.7 (smell_gas), 16.7 / 19.8 (booger_king) | 53.2 ms (booger_king) | 2.7–6.3             | 3                    | 5      |

- No frame ran more than 3 physics steps. The single 101 ms day frame ran 1 step with `tm` 5.2 ms, so it was not a catch-up stack.
- This run congested less than the baseline: `lot_cars` 1.1–4.6 ms/tick avg (max 9.6), `find_blocker` 7–16 calls/tick and 0.7–4.1 ms/tick. Part of the spike drop is run-to-run variance in congestion, not the cap. `lane_spawning` still peaks at 12.8 ms.

### 5.2 `CarSweep` broadphase

Each sweep caches its whole-route `Rect2` plus per-footprint centers and radii; `candidate_conflict_distance` rejects the pair on the `Rect2`s before any per-rect work, and the SAT test is unrolled (no per-call array). A throwaway fuzz against the old implementation (200k random sweep pairs, both reversing flags) gave 0 mismatches; 89% of pairs were rejected by the `Rect2` test.

| Metric (`TM_PROFILE`, 21 windows) | 5.1 (before)      | After             |
| --------------------------------- | ----------------- | ----------------- |
| `find_blocker` calls/tick         | 7–16              | 8–16              |
| `find_blocker` ms/tick            | 0.7–4.1           | 0.4–1.9           |
| `lot_cars` avg (max) ms/tick      | 1.1–4.6 (9.6)     | 0.8–2.3 (5.0)     |
| TM `total` avg ms/tick            | —                 | 1.7–3.1           |
| Tour `tm` p95 range, day / night  | 3.5–8.0 / 2.7–6.3 | 3.2–4.3 / 3.2–4.5 |

- Spikes rose (day 28, night 112), but they are not traffic: the night spikes are ~30 ms frames with `tm` 2–5 ms, and 8 of 11 night waypoints sit at a 31 ms p95 with `tm` p95 under 4 ms. This was the third back-to-back pack run, so thermal drift is the likely cause (see the caveats in `docs/plans/desktop_performance.md` §0).
- `lane_traffic` (0.7–1.0 ms avg) is now as large as `find_blocker`.

### 5.3 Per-pair candidate cache

`candidate_conflict_distance` is asymmetric (hard check uses `mine["look"]` vs `theirs[0]`, soft loop indexes `i ≥ 0` vs `j ≥ 1`, reversing flags are per-side), so the reverse query cannot be mirrored. Instead `TrafficManager._candidate_conflict` caches each directed pair keyed by both cars' `sweep_rev`; a rev covers every sweep input (transform, state, speed, path, `path_distance`, dimensions), so a hit is exact. Cleared with the 60-tick sweep-cache sweep.

A/B on the same build and `--seed=1`, back to back; "off" temporarily called `CarSweep.candidate_conflict_distance` directly. §5.2 is not a valid baseline: its run may already have included the cache (same uncommitted diff).

| Metric (`TM_PROFILE`, 21 windows)  | Cache off         | Cache on          |
| ---------------------------------- | ----------------- | ----------------- |
| `find_blocker` calls/tick (avg)    | 9.5–16.1 (11.7)   | 7.8–14.6 (11.5)   |
| `find_blocker` ms/tick (avg)       | 0.58–2.15 (1.00)  | 0.44–1.56 (0.86)  |
| `find_blocker` ms/call (avg)       | 0.086             | 0.075             |
| Pair-cache hits/tick (avg)         | 0                 | 0.1–10.9 (3.1)    |
| `lot_cars` avg ms/tick (worst max) | 0.97–2.53 (4.1)   | 0.83–1.96 (3.5)   |
| TM `total` avg ms/tick             | 1.83–3.36         | 1.76–2.83         |
| Tour `tm` p95 range, day / night   | 2.6–6.4 / 4.5–8.4 | 2.4–5.0 / 3.5–5.2 |

- About 13% less `find_blocker` time per call. Hits come from jams (stopped cars keep their rev), so the gain grows with congestion: the high end of each range drops most. Even with the same seed, congestion differs between runs, so the tick-level ranges are noisy.
- Spikes in the cache-on run (day 103, night 258) are ~30 ms frames with `tm` 1.5–2 ms and render CPU under 2 ms, the same non-traffic drift as §5.2.

### 5.4 x-sorted blocker candidates

`_update_lot_cars` sorts the tick's candidates by tick-start `x` (`_index_blocker_candidates`: native `Vector2(x, index)` sort, reaches cached eagerly), and `_find_blocker_impl` bsearches an x-window of `my_reach + max reach + CANDIDATE_X_SLACK` (2 m, covers cars that moved earlier in the loop). Equal distances still go to the earliest candidate in list order. A throwaway in-sim cross-check against a full scan, and against a full scan with no reach filter, gave 0 mismatches in 120k `find_blocker` calls.

Headless `mise run bench --bench-physics --profile-traffic --seed=1 --duration=70`, same build with the index toggled. `TM_PROFILE` now prints `cand` (candidates past the z-filter per call) and `reach` (past the reach test per call). Overhead is `find_blocker` time minus `_conflict_distance`, so it is less sensitive than ms/tick to congestion drift between runs.

| Metric (7 windows)                     | Full scan | x-window |
| -------------------------------------- | --------- | -------- |
| `cand` per call                        | 4.8–8.5   | 1.9–4.4  |
| Non-conflict overhead µs/call          | 49–57     | 36–48    |
| Index build µs/tick (14–22 candidates) | —         | 30–41    |

- Net about 0.1 ms/tick (~11 µs/call × ~14 calls, minus the index build). `_conflict_distance` is ~60% of `find_blocker`. The remaining overhead (sweep builds, `_is_ignoring`, reach tests, loop) was not split further; `_car_sweep` rebuilds are the likely bulk. The gain grows with candidate count, so it matters most in the 80+ car jams.
- The baked-pack tour from §5 was not rerun for this item. A ~0.1 ms/tick change is below its run-to-run congestion noise (see §5.3), so the same-build headless A/B is the evidence.

### 5.5 `_update_lane_traffic` scratch arrays and lot-car buckets

`_bucket_lot_cars_by_lane` sorts the tick's PATH lot cars into `Lane.lot_path_cars` once, before the lane loop (it was 4 full `lot_cars` scans). `valid_cars` / `shouldered_cars` are reused `Lane` members, `surviving_cars` double-buffers with `lane.cars` via `Lane.spare_cars`, and the `sort_custom` lambda became a stable insertion sort (`_sort_by_lane_distance_desc`). Direct `_update_lane_traffic` calls (tests) still scan `lot_cars`. A throwaway in-sim cross-check gave 0 mismatches in 25,200 lane updates for both the buckets (vs a full scan) and the sort (vs `sort_custom`; max 12 cars per lane, and Godot's sort is the same stable insertion sort up to 16 elements).

Same headless command as §5.4, with section timers temporarily added (ms/tick, all 4 lanes, 7 windows):

| Section                                      | Before                | After                             |
| -------------------------------------------- | --------------------- | --------------------------------- |
| Register PATH lot cars                       | 0.140–0.153           | 0.058–0.064 (+0.043–0.050 bucket) |
| Filter + sort + shoulder list                | 0.087–0.105           | 0.080–0.104                       |
| Per-car loop (of which `advance_simulation`) | 0.68–0.83 (0.36–0.45) | not re-timed (code untouched)     |
| `lane_traffic` total avg (congestion noise)  | 0.96–1.15             | 0.87–1.12                         |

- Net ~0.04 ms/tick. The allocations and the sort were never the cost (~0.1 ms combined, unchanged after reuse); a per-lane membership `Dictionary` was skipped because `lane.cars.has` only runs for the 0–3 in-apron PATH cars per lane, and `lane.cars` is mutated from ~8 sites including tests.
- The real cost is per car: `Car.advance_simulation` (lateral bias/wander, `update_presentation` transform writes, `_update_blocker_layer`) is ~0.4 ms/tick, about 10 µs per lane car.

### 5.6 Car spawn hitches

Timed `instantiate()` / `add_child()` / `setup()` per `_spawn_car_at` in windowed baked-pack runs (`--profile-traffic --seed=1 --warmup=40 --tour-phases=night --tour-wps=start,car_care`, temporary timers, ~160 lane spawns per run). `instantiate()` is never the cost (p50 0.08 ms).

- **Double body build.** `_spawn_car_at` set `car_type` only in `setup()`, so every passenger car's `_ready` built a default sedan body (wheels, signals, lamps, exhaust, paint) and `setup()` freed it and built the real one. It now sets `car_type` before `add_child`. `setup` p50 0.38 → 0.20 ms, `add` p50 0.55 → 0.42 ms, whole spawn p50 1.07 → 0.74 ms, p95 2.6 → 2.3 ms.
- **First-use loads.** Car scenes and passenger bodies were `load()`ed lazily on first spawn of each type, and the police siren synthesized its wail on the first police car (headless pack: wail 12.9 ms, police body 2.8 ms, van 7 ms, others 1–3 ms). These could land mid-game for rare types. `TrafficManager._load_car_scenes()` now runs them at the start of the staged initial spawn, behind the loading screen.
- **Remaining peak: police SUV body attach.** Police spawns (13 of 159) took 2.0–8.3 ms each, mostly in `add_child`. About 0.6–2 ms of that is `police_siren.gd` duplicating 12 lens materials; the rest is the body's subtree entering the tree. Other spawns: p50 0.74 ms, p95 1.3 ms, one 5.7 ms outlier (truck `setup`). `lane_spawning` max per 600-tick window is now 2.2–8.3 ms, set by police spawns. It was 12.8–24 ms in §5/§5.1, probably from first-use loads, which no longer run in the game loop.
- Car pooling was not done: the steady-state cost is ~0.75 ms per spawn, and only the police body exceeds a few ms. Pooling would need a full `Car` state reset. If police spawns still show up, pool or reuse the police body (or share its lens materials until the siren first turns on) instead of pooling whole cars.

### 5.7 Congestion growth investigation

Congestion does not grow over time or at night, and night frame drops are not traffic. No code change.

- **Night-first tour** (`--tour-phases=night,day --seed=1`, baked pack, fresh machine). Night TM `total` 1.76–2.01 ms/tick avg, then day 1.77–2.17; `find_blocker` 0.41–0.70 vs 0.49–0.73 ms/tick; 65–67 cars. Night still had 148 spikes vs 25 in day, and 6 of 11 waypoints at a ~32 ms p95. Spike frames have `tm` ≤ 4.2 ms and render CPU ≤ 3.5 ms. So the night drops are neither thermal (night ran first) nor traffic CPU. They are likely GPU/present-bound night lighting (§3; Metal GPU time is not captured).
- **No closing-time rush.** Traffic reads the clock only for headlamp LOD (`_update_headlamp_lod`). Commit 6507779 added the stall despawn and the `MAX_LIVE_CARS` cap, not an exit rush. The tour also holds the clock (`time_paused`).
- **No growth over time.** Headless 10-minute runs (`--fixed-fps 60 --seed=1`, 5 min day then 5 min night, throwaway SceneTree probe) logged every 10 s. Bench fixtures (`tests/main_tests.tscn`, `parking_fill_floor = 0`): 66–85 live cars, 19 watchdog fires, 0 stuck despawns, `find_blocker` 0.52 ms/tick avg. Production `main.tscn` (floor 0.5, staged spawn): 71–87 live cars (cap 110 never hit), 38 watchdog fires, 5 stuck despawns, 0.59 ms/tick avg. Night windows match day windows in both.
- **Jams are slow to clear but cheap.** Every stuck despawn was a deadlock the watchdog re-fires on without resolving: `SHORTCUT` vs `TO_EXIT` (x2), `SHORTCUT` vs `SHORTCUT`, and two `WAITING_TO_MERGE` cars with no blocker. The worst held 18 stalled cars (12 `CRUISING` queued behind) for ~40 s until the 30 s `STUCK_DESPAWN_TIME` removed the root. `find_blocker` stayed at 0.28–0.95 ms/tick during jams. Stalled cars cut lot motion, so cost tracks moving lot cars (`calls/tick`), not jams. A faster jam clear is a gameplay fix, not a CPU fix.
- The baseline's 88 cars and 4.7 ms/tick `find_blocker` came before §5.2–§5.4. With them, the same seed now peaks near 1.4 ms/tick headless and 1.4 ms/tick (window avg) windowed.

### 5.8 Forest spatial tiles

`Forest._build_multimeshes` now buckets trees by 40 m tile (`forest_tile_size`) × Near/Far instead of East/West × Near/Far, so frustum culling and visibility range work per tile. Same meshes and transforms. Tiles pad `visibility_range_end` by the tile half-diagonal: Godot measures the range to the tile's AABB center, and an unpadded 160 m faded back rows that whole-side buckets always drew.

Forest-only scene (everything but `Props/Forest` hidden, day, clock paused, Vulkan, 2940×1782, throwaway SceneTree probe, 120-frame averages; GPU includes sky/glow/tonemap and is single-run, so ±0.5 ms):

| Camera (Mats + bench offset) | Primitives before → after | Draws before → after | GPU ms before → after |
| ---------------------------- | ------------------------- | -------------------- | --------------------- |
| bench (start)                | 518k → 96k                | 177 → 244            | 8.4–8.6 → 6.9–7.1     |
| strip_mall                   | 518k → 113k               | 177 → 273            | 8.8 → 7.5–7.9         |
| west_road                    | 252k → 123k               | 120 → 291            | 8.0–8.5 → 7.4–7.8     |
| car_care                     | 448k → 135k               | 163 → 305            | 9.1–9.4 → 8.3–8.4     |

Screenshot diffs (pixels off by > 8/255): bench and west_road match the before-vs-before noise floor (live-oak foliage shimmer). strip_mall and car_care differ only where an old whole-side bucket sat in its fade band, so half the forest was dithered or hidden at once; tiles draw those trees fully.

### 5.9 Forest LOD

The `.blend` trees already import with LODs (`meshes/generate_lods=true`). `Forest._get_variant_mesh_parts` now rebuilds the procedural tree parts (`PrimitiveMesh` cylinders/spheres) through `ImporterMesh.generate_lods()` so per-tile LOD selection applies to them too. Skipped when `ImporterMesh` is absent (the web template strips it). `lod_change/threshold_pixels` stays at default.

Same probe and cameras as §5.8; "before" is the same code with the `_with_lods` pass disabled, at the default threshold. Primitives: bench 96k → 84k, strip_mall 113k → 98k, west_road 123k → 112k, car_care 135k → 118k; draws unchanged. GPU unchanged within noise (single runs, ±0.5 ms). The `.blend` LODs did most of the work: forcing LOD0 everywhere (`mesh_lod_threshold = 0`) gives 186–357k.

Screenshot diffs (pixels off by > 8/255): before vs after 1.9k–3.9k pixels (0.04–0.07%), after vs a repeat run 0.2k–1.0k. Every differing pixel is on the live-oak foliage, a wind-animated `.blend` mesh that `_with_lods` does not touch, so the extra count is wind phase between runs; the procedural trees show no differing pixels.

Export: the macOS release template (baked `export-mac-pack` pck) has `ImporterMesh` and generates 3–5 LODs per procedural part (11 parts). The whole variant cache, including the `.blend` loads, builds in ~6 ms.

### 5.10 Shadow caster audit

No code change. Each group's shadows were turned off in turn on a frozen scene: day, tree paused after 10 s of traffic, Vulkan, 2940×1782, 60-frame averages, a throwaway SceneTree probe. Shadow-pass draws and primitives at the bench camera (strip mall is similar):

| Group                   | Unbaked editor scene (draws / prims) | Baked `export-mac-pack` pck (draws / prims)                 |
| ----------------------- | ------------------------------------ | ----------------------------------------------------------- |
| Cars                    | 472 / 110k                           | 448 / 300k                                                  |
| Buildings (site scenes) | 131 / 34k                            | 122 / 130k                                                  |
| Props                   | 108 / 42k                            | 76 / 36k                                                    |
| Forest Near tiles       | 0                                    | 0 (beyond the sun's 65 m `directional_shadow_max_distance`) |
| Mats                    | 0 (27 at strip mall)                 | 0 (27 at strip mall)                                        |
| `Label3D`               | none cast                            | none cast                                                   |
| Whole sun shadow        | 715 / 185k                           | 650 / 466k                                                  |

- **Tiny casters do not pay.** The candidates the plan named are parts that add at most 2 cm to the shadow: a part inside a `BoxMesh` caster of the same scene instance (grown by 2 cm), or a part under 8 cm. They include grille slots, mirror glass, door gaps and seams, plates, bezels, stripes, flush signage panels, and hinges. In the unbaked scene that is 443 casters, −52 draws and −12k prims. In the baked pck it is 58 casters and −3 draws, because the baker has already merged the rest into each scene's `Body`/`Trim`/`BakedStaticMesh`. GPU did not change measurably in either build.
- **The shadow cost is mostly fixed.** In the baked pck (3 interleaved runs each), turning off every caster except Mats saved 0.1–0.4 ms GPU at bench and 0.5–0.6 ms at strip mall. Turning off the sun's shadow saved 2.6–2.8 ms. So about 2.2 ms is shadow-atlas and sampling cost that does not depend on casters. Trimming casters is bounded at ~0.5 ms even with zero casters, so nothing was turned off.
- **Baking dropped per-part `cast_shadow`.** `bake_static_scene`, `bake_car_body`, and `bake_vehicle_model` merged shadow-off parts into shadow-casting meshes, so the §3.4 trims (signage borders, logo trims) cast shadows again in exports. Fixed in §5.12.

`directional_shadow/soft_shadow_filter_quality` 2 → 1 (soft high → soft low; set before the first frame through `RenderingServer.directional_soft_shadow_filter_set_quality`, baked pck, 4 interleaved runs): GPU at bench went from 14.56–14.82 to 13.37–13.92 ms (≈ −0.9) and at strip mall from 15.51–15.91 to 14.29–14.56 ms (≈ −1.2). In same-frame screenshots of a frozen scene (pixels off by > 8/255), quality 2 against a second quality-2 shot (the noise floor) differs by 21.8k / 22.2k / 0.7k pixels (bench / strip mall / a close camera at 6 m). Quality 2 against quality 1 differs by 31.6k / 26.7k / 6.0k pixels. The densest 600×400 diff crop at the close camera (Mats and cars) shows no difference that is obvious at a glance. Not applied: this needs a human visual sign-off (`desktop_performance.md` §3).

### 5.11 Glow upscale bicubic → linear (not applied)

Night (7:51 PM, frozen scene, unbaked `main_tests.tscn`, Metal 2940×1782, toggled through `RenderingServer.environment_glow_set_use_bicubic_upscale`). Pixels off by > 8/255, bicubic vs a second bicubic shot (noise floor) and bicubic vs linear: 13.5k / 13.2k at bench, 14.6k / 13.8k at strip mall, 56 / 31 at a close camera (6 m, headlights). Linear is at the noise floor at > 8/255. Only at > 2/255 does it touch pixels the noise doesn't (121 close, 4.3–4.6k wide), which are faint glow halos around headlights and lamps. GPU saving is the profiled −0.4 ms (tonemap 1.71 → 1.34, §0 of the plan). Not applied: needs a human visual sign-off (`desktop_performance.md` §3). Probe: `/tmp/glow_shot.gd`.

### 5.12 Export bake culling granularity

`MeshBaker` merges now split by render key (`cast_shadow` plus the visibility range begin/end/margins/fade mode) and, in `bake_static_scene`, by 30 m grid cell (`BAKE_CELL_SIZE`, anchored at the parts' minimum corner, so anything smaller stays whole; ranged keys use `min(30 m, range / 4)`). Each group keeps its key on the merged instance. Car bodies (`Body`/`Stripe`/`Trim`), vehicle models, wheels (shadowless, 35 m rims/caps become child meshes, the first named `Spoke`), tree trunks, and flag poles use the same grouping. Merged meshes get LODs through `ImporterMesh.generate_lods()` (SurfaceTool merges dropped the sedan `.glb`/`.blend` LODs). Hidden subtrees stay unbaked. MultiMesh templates (lamp, bollard) still bake to one mesh (`single_mesh`). Two old bugs went with it: merged parts with no range took the group's longest range (flag poles vanished at 35 m), and color-collapsed surfaces read their vertex colors as linear, washing out every baked building (`vertex_color_is_srgb`).

Full scene with traffic (bake-cull probe, Metal 2940×1782, day, frozen; cars vary by run):

| Camera     | Unbaked editor (draws / prims) | Old bake pck | New bake pck |
| ---------- | ------------------------------ | ------------ | ------------ |
| start      | 1537 / 466k                    | 1470 / 870k  | 1232 / 234k  |
| strip_mall | 1750 / 578k                    | 1665 / 1050k | 1459 / 265k  |
| taco_hell  | 722 / 250k                     | 696 / 460k   | 576 / 140k   |
| car_care   | 1662 / 424k                    | 1731 / 764k  | 1629 / 312k  |
| west_road  | 899 / 235k                     | 817 / 303k   | 853 / 178k   |

Buildings at start: 72k unbaked, 204k old bake, 27k new; cars 254k / 531k / 90k. The pack now draws fewer primitives than the unbaked scene because merged meshes have LODs that the unbaked `PrimitiveMesh` parts lack.

Static screenshots (cars, forest, Mats, particles hidden; pixels off by > 8/255 against the unbaked scene, 8 cameras): the old pack differed by 85k–821k pixels (washed-out colors); the new pack by 2.4k–57k. Unbaked against a second unbaked shot is 0–36k (foliage wind). What remains is streetlights and the Taco Hell bell shading. Both match the old pack, so they are not from this change:

- **Streetlights do not render in the pack.** `Props/Streetlights/BakedMultiMesh` loads with 15 identity transforms (empty AABB), and the lamp instances render nothing either. This is the same in the old pack. Fixed in §5.13.
- The Taco Hell bell picks up a brighter highlight after color collapsing. Fixed in §5.20 (wrong normals under non-uniform scale, not color collapsing).

Probes: `/tmp/bake_cull.gd` (per-group draws/prims), `/tmp/bake_shot.gd` (static shots), `/tmp/bake_key_neg.gd`. `--test-verify-render` now checks that baking Taco Hell keeps the triangles per render key.

### 5.13 Duplicate loads in the baked pack; desktop presets

Two export-only bugs, both present since the main-scene bake was added:

- **Empty MultiMesh buffers.** The headless exporter runs on the dummy RenderingServer, which drops `MultiMesh.set_instance_transform`, so the streetlight and bollard MultiMeshes saved no transforms. `MeshBaker.set_multimesh_transforms` writes `MultiMesh.buffer` directly (the dummy server keeps that). Their visibility ranges are padded by half the instances' spread, because Godot measures the range to the MultiMesh AABB center. Without the padding, the far Frontage lamp vanished at the car_care camera.
- **Instanced sub-scenes loaded twice.** A packed scene cannot delete an instance's children. When `bake_main_scene` merged meshes inside an instance (`Road`, `Parking`, `Streetlights`, `Trees`, `Flags`, every building), the instance still loaded its own children, and the main scene added the baked copy on top. 122 duplicate-named nodes showed up, including 15 extra lamps with their own SpotLights and collision, and every building drawn twice (its own baked `.scn` plus the main-scene merge). Sedan/F150 bodies also gained a second set of `Spoke` meshes from baking the inherited `.tscn` over the already-baked `.blend`. Fixes: `MeshBaker.make_local` saves edited instances inline. The main bake skips sub-scenes that `bake_scene_for_path` bakes on their own (buildings, listed props, carts) and scripted props that build meshes in `_ready` (billboards, tunnels, forest). Inherited scenes whose base is baked are not baked again. Bollards now merge inside each building's own bake and keep their shadows. Runtime `--bake` still bakes those sub-scenes in place (`bake_instanced`).

Static shots (same probe as §5.12, no traffic), draws / prims, unbaked editor vs pack before and after:

| Camera     | Unbaked    | Before    | After     |
| ---------- | ---------- | --------- | --------- |
| start      | 524 / 128k | 427 / 59k | 411 / 60k |
| strip_mall | 585 / 151k | 548 / 70k | 523 / 70k |
| taco_hell  | 303 / 129k | 232 / 32k | 226 / 25k |
| car_care   | 588 / 90k  | 688 / 90k | 627 / 84k |
| far_east   | 777 / 193k | 689 / 87k | 629 / 84k |
| far_west   | 569 / 153k | 523 / 70k | 492 / 70k |

Pixels off by > 6% from the unbaked shot drop at most cameras (far_west 14.8k → 1.5k, strip_mall 7.3k → 0.7k, close_sign 2.5k → 0.2k). What remains is live-oak wind, lamp shadow details, and distant thin poles. Night shots with lit streetlights match the unbaked scene (216 px).

Desktop presets `macOS` (universal, ad-hoc signed `.zip`), `Windows Desktop` (x86_64), and `Linux` (x86_64) are in `export_presets.cfg`. `mise run export-desktop` exports all three, baked, to `build/{macos,windows,linux}`, and `export-mac-pack` now reuses the `macOS` preset. Universal/arm64 macOS exports require `rendering/textures/vram_compression/import_etc2_astc=true` (now set; the Web preset still ships desktop formats only). The exported `Stroad Hero.app` runs 600 frames clean on M2/Metal, and the Windows/Linux `.pck`s load with no duplicate nodes. Probes: `/tmp/dup_probe.gd` (duplicate-named siblings), `/tmp/count_probe.gd`, `/tmp/body_probe.gd`, `/tmp/night_shot.gd`.

### 5.14 Labels (not significant)

No code change. The baked `export-mac-pack` pck was run with Vulkan, default window, on a frozen scene (clock paused, 4 interleaved runs, 80-frame averages). Hiding every visible `Label3D` (229 by day, 244 at night) removes 38–90 draws and under 1.4k prims per camera. GPU changes by −0.2 to +0.2 ms at bench, strip_mall, and a close camera, by day and at night, which is within run-to-run spread (±0.3 ms). Render CPU changes by ≤ 0.1 ms. The earlier ~1 ms (noisy) was measured before the forest and bake work. Probe: `/tmp/label_probe.gd` (`-- --night`).

### 5.15 MetalFX vs FSR1 (Metal GPU time)

Metal frame pacing is capped at the display rate (windowed `--disable-vsync` still gives p50 16.6 ms), and `viewport_get_measured_render_time_gpu` returns 0 on Metal. So GPU time came from Instruments: `xctrace record --template 'Metal System Trace' --attach <pid> --time-limit 4s`, then `metal-gpu-intervals` filtered to the Godot process, with the per-frame union of Vertex/Fragment/Compute intervals (busy ms per frame). Setup: unbaked `main_tests.tscn`, Metal, M2, 2940×1782, strip mall day, frozen scene, 2 interleaved runs per config (Firefox was also using the GPU).

| Config                | GPU busy p50 (ms) | Δ vs native |
| --------------------- | ----------------- | ----------- |
| Native 1.0            | 14.0–14.2         | —           |
| FSR1 0.75             | 11.9–12.0         | −2.1        |
| MetalFX spatial 0.75  | 11.1–11.2         | −2.9        |
| MetalFX temporal 0.75 | 18.1–18.5         | **+4.2**    |
| MetalFX temporal 0.5  | 13.5–16.0         | ≈ 0 to +2   |

MetalFX spatial was the cheapest upscaler on M2, about 0.8 ms below FSR1 at the same scale. That gap is small for 2 runs with a competing GPU process, so treat it as tentative. Image quality has not been ranked: differences from native mostly measure sharpening and blur, not quality. Side-by-side shots are kept for human review. MetalFX temporal costs more than native at 0.75 and saves nothing at 0.5, so it is ruled out, like FSR2. MetalFX modes exist only on the Metal driver, so a fallback needs FSR1 for Vulkan/D3D12. Probe: `/tmp/metalfx_probe.gd` (`--only=cam:cfg`, `--shot`), sweep `/tmp/mfx_all.sh`, shots `/tmp/mfx_shot_*.png`.

### 5.16 Adaptive V-Sync

`project.godot` sets `display/window/vsync/vsync_mode=2` (Adaptive) and `vsync_mode.macos=1` (Enabled). On Vulkan, Adaptive selects `FIFO_RELAXED`: a frame that misses vblank is presented right away (it may tear) instead of waiting for the next vblank. A 17–18 ms frame should then show at about 18 ms instead of 33 ms. Frames within budget stay synced. Where the mode isn't supported, the engine falls back to Enabled.

- **macOS:** pinned to Enabled. Metal would treat Adaptive as Enabled anyway (`RenderingContextDriverMetal` sets `setDisplaySyncEnabled(true)` for it), and MoltenVK can't do it ("requested V-Sync mode Adaptive is not available", then a fallback). The override keeps the reported mode accurate and removes that warning. Both drivers report mode 1, with p50 at 16.67 ms windowed on M2.
- **Web/Compatibility:** behaves like Enabled.
- **Windows/Linux:** the 4.7 defaults resolve to `vulkan` (the project has no driver override), which is the target. Untested (no hardware): whether over-budget frames tear instead of halving the frame rate. If the driver lacks FIFO_RELAXED, it falls back to Enabled and logs the warning above.

`--disable-vsync` still overrides the setting for benchmarks. Probe: `/tmp/vsync_probe.gd`.

### 5.17 Hitch recheck after P0/P1

Same command as the baseline (seed 1, baked pack, 120 s warmup, `--profile-traffic`), after all of §5.1–5.16. 62–64 cars.

| Phase | Frame interval p50 / p95 (worst waypoint)         | Worst frame           | `tm` p95 range (ms) | Max steps in a frame | Spikes |
| ----- | ------------------------------------------------- | --------------------- | ------------------- | -------------------- | ------ |
| Day   | 16.6 / 18.8 (car_care), 16.7 / 18.3 (cramped_inn) | 34.1 ms (taco_hell)   | 2.2–2.9             | 2                    | 5      |
| Night | 16.7 / 32.0 (start), 16.8 / 20.0 (booger_king)    | 33.5 ms (booger_king) | 2.0–3.3             | 2                    | 28     |

- The 93–112 ms multi-step frames are gone. No frame exceeded 34.1 ms, and every spike (27–34 ms) ran 1 physics step with `tm` 1.4–2.6 ms and render CPU 1.2–2.2 ms. They are single missed vblanks (vsync rounds a 17–18 ms frame up to 33 ms), not traffic catch-up or shader compiles.
- Night spikes cluster at the busiest views (start 13, booger_king 6, car_care 5, east_road 3; 1,050–1,450 draws). `start` runs at ~32 ms in bursts, so it sits right at the GPU budget there. That is the §4 GPU/vsync cliff, not a hitch.
- `TM_PROFILE`: `total` 1.7–2.5 ms/tick avg (max 7.4), `find_blocker` 0.40–1.13 ms/tick, `lane_spawning` peaks 1.1–5.1 ms. `stuck_despawns` 0, 2 watchdog fires.

### 5.18 Dusk transition and night GPU pass sweep

Dusk: the baseline command (seed 1, baked Metal pack, 120 s warmup, `--profile-traffic`), now with the default `day,dusk,night` phases; the dusk sweep holds `start`, 58–61 cars. Day and night match §5.17 (worst frame 33.2 / 35.0 ms, all single missed vblanks).

- No dusk hitch: worst frame 33.9 ms (the old `--bench-gameplay` max was 38.4 ms). The lights-on frame (18.25 h) took 25.2 ms with 2 physics steps and render CPU 2.5 ms, so no pipeline compile stalled it.
- The 59 dusk spikes (25–34 ms, ≤ 2 steps, `tm` ≤ 4.7 ms, render CPU ≤ 2.5 ms) run from 18.25 h to 19.52 h, and none came before lights-on. Dusk p50/p95 is 17.0 / 30.7 ms vs night `start` at 17.0 / 32.6: with lights on, `start` is over the GPU budget (the §5.17 vsync cliff).

Night GPU sweep: `mise run bench --bench-tour --main-pack=/tmp/stroad_mac.pck --seed=1 --tour-phases=night --gpu-profile` (Vulkan/MoltenVK, so ~20% slower than Metal, 120 s warmup, 3 engine blocks per waypoint).

| Waypoint    | GPU total | Opaque | Tonemap | Glow | CanvasItems | Sky | Transparent | Shadows |
| ----------- | --------- | ------ | ------- | ---- | ----------- | --- | ----------- | ------- |
| start       | 21.9      | 9.1    | 1.8     | 1.2  | 1.1         | 0.9 | 0.5         | 0.5     |
| cramped_inn | 21.1      | 8.3    | 1.8     | 1.2  | 1.0         | 1.0 | 0.4         | 0.5     |
| car_care    | 21.3      | 8.0    | 1.9     | 1.2  | 1.1         | 1.0 | 0.7         | 0.5     |
| strip_mall  | 20.5      | 7.6    | 1.8     | 1.2  | 1.1         | 1.0 | 0.7         | 0.5     |
| west_road   | 20.6      | 7.6    | 1.9     | 1.3  | 1.1         | 1.1 | 0.3         | < 0.3   |
| booger_king | 18.1      | 7.9    | 1.9     | 1.1  | 1.0         | 1.0 | 0.6         | 0.5     |
| dorf        | 15.9      | 5.5    | 1.8     | 1.2  | 1.0         | 1.0 | 0.8         | 0.4     |

- Opaque is the only pass that varies by view (5.5–9.1 ms). Tonemap + glow (~3.0 ms), CanvasItems + canvas cull (~1.8 ms), and sky (~1.0 ms) are fixed per frame. Directional/spot shadows are ≤ 0.5 ms at night.
- `start` costs the most at night (opaque 9.1 ms; §0 measured 6.9 at strip_mall by day). It is also where the Metal dusk/night p95 reaches 31–33 ms.

### 5.19 Acceptance run (`desktop_performance.md` §6)

Re-exported pack, `mise run bench --bench-tour --main-pack=/tmp/stroad_mac.pck --seed=1 --tour-phases=day,night` (Metal, M2, 2940×1782, 120 s warmup), run A with `--profile-traffic` and run B without. 56–68 cars.

| Run | Phase | fi95 range (worst waypoints)                                 | Worst frame | Max steps | `tm` p95/frame | Spikes |
| --- | ----- | ------------------------------------------------------------ | ----------- | --------- | -------------- | ------ |
| A   | Day   | 17.1–19.7 (car_care 19.7, cramped_inn 18.2)                  | 33.2        | 2         | 2.3–3.5        | 8      |
| A   | Night | 17.2–31.0 (start 31.0, strip_mall 21.7, booger_king 19.8)    | 33.5        | 2         | 2.5–3.2        | 28     |
| B   | Day   | 17.1–18.6 (car_care 18.6, cramped_inn 18.3, strip_mall 18.1) | 20.6        | 1         | 2.2–3.2        | 0      |
| B   | Night | 17.2–31.8 (start 31.8, cramped_inn 31.5, car_care 19.4)      | 34.0        | 2         | 2.7–4.5        | 45     |

- Fails frame p95 ≤ 18 ms (night `start`/`cramped_inn` sit at ~32 ms, the vsync cliff; several day/night views at 18–22 ms) and no frame > 33 ms (worst 33.2–34.0, single missed vblanks: 1 step, `tm` ≤ 3 ms, render CPU ≤ 2 ms). Passes ≤ 2 physics steps per frame.
- `TM_PROFILE` (run A, 21 windows): `total` 1.74–2.84 ms/tick avg (max 4.2–19.7), `lot_cars` 0.80–1.99, `lane_traffic` 0.68–0.86, `find_blocker` 0.42–1.46 ms/tick. Avg alone exceeds 2 ms in 18 of 21 windows, so the ≤ 2 ms p95 target is not met.
- Vulkan GPU at strip mall (`--tour-wps=strip_mall --gpu-profile`, MoltenVK, 120 s warmup): day 16.0 ms pass total / 18.1 ms `gpu` column, night 19.5 / 19.9 (opaque 6.6 / 8.0, tonemap + glow 3.0, CanvasItems + cull 1.7–1.9, sky 1.0). §0 measured ~17 by day, so P1 saved about 1 ms here; the ≤ 13 ms target is not met.

### 5.20 Acceptance screenshots (`desktop_performance.md` §6)

Static shots (cars, Mats, particles hidden; forest kept) from the bench camera and the strip_mall, taco_hell, and car_care waypoints, day (15:30) and night (19:30), Metal 2940×1782. Shots compared: `before` (unbaked `HEAD` worktree `/tmp/stroad-before`, taken twice to get the noise floor), `unbaked` (current editor scene), and `pack` (current baked `/tmp/stroad_mac.pck`). A diff counts only pixels off by > 32/255, outside the dilated before-vs-before noise mask, after a 1 px opening.

The first pass found two bake regressions, both now fixed:

- **Street lamp heads cast shadows in the pack.** `bake_static_scene(single_mesh)` forced one shadow-casting mesh, so the shadowless `Lamp` head joined the pole's shadow (a blob at the end of each lamp shadow; 514 px at bench). Template bakes now produce one mesh per `cast_shadow`, and `create_multimesh_from_instances` builds one MultiMesh per template (`BakedMultiMesh`, `BakedMultiMesh2`). `EnvironmentController._update_baked_streetlights` swaps the lit bulb on each one. `--test-verify-render` checks that the lamp template keeps its triangles per shadow setting.
- **Wrong normals in merged meshes under non-uniform scale.** `SurfaceTool.append_from` transforms normals by the basis instead of its inverse transpose (up to 81° off on a sphere scaled 0.08 in z). This is what made the flattened Taco Hell bells shade brighter (§5.12) in every pack, web included. `MeshBaker._append_arrays` now transforms vertices, normals, and tangents itself. Export cache hash 15 → 16.

After the fixes, unbaked → pack is 0–158 px per shot (scattered 5–37 px specks). `before` → `pack` is 0–59 px except in the forest. The only visible change is the far forest in day strip_mall (6.4k px) and car_care (9.2k px): trees that the old whole-side buckets drew mid-fade (translucent) now draw solid, as their visibility range says (§5.8). No difference at night beyond 42 px. Probes: `/tmp/accept_shot.gd`, `/tmp/acc_excess.py`.
