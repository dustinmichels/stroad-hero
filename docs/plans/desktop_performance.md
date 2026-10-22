# Desktop Performance Plan

Goal: no lag on desktop/laptop (Forward+), with no visible loss of quality. Web is covered in `web_optimization.md`.

Prior work: `docs/optimizations.md`. Items marked **`[HUMAN REVIEW NEEDED]`** need a design or visual decision.

---

## 0. Profiling Summary (Oct 21, 2026)

Machine: Apple M2, Godot 4.7.2, window 2940×1782 (Retina, `scaling_3d_scale = 1.0`), Forward+.

### Headline

1. **The lag is CPU, not GPU.** `TrafficManager._physics_process` grows from ~3 ms to 12–17 ms per physics tick as the lots congest. A tick longer than the 16.7 ms frame makes Godot run 3–4 ticks the next frame (max is 8). Frames then reach 45–67 ms (≈15–20 fps) and stay there.
2. **The GPU is at budget on M2 at Retina resolution.** On Metal with traffic frozen, the frame median is a vsync-locked 16.7 ms, and p95 is 17.5–17.8 ms. With MoltenVK GPU timers, strip mall daytime takes 16.5–18 ms, and night adds only ~0.4–1.6 ms (hiding all lights at night changed nothing measurable). Weaker laptop GPUs have no headroom. Sun shadows (3.6–4.1 ms) and the forest (~3–4 ms; single runs, noisy) cost the most.
3. **Export baking does not reduce GPU cost.** It cuts render-thread CPU by about 40–50%, but scene primitives go up 30–40% because merged meshes lose culling granularity.

### Tour: shipped build (baked export pck, Metal, vsync)

Teleports Mats through 11 waypoints with 3 s samples each. `tm` is TrafficManager physics script ms per frame.

| Phase | Waypoint    | Frame p50 (ms) | Frame p95 (ms) | Frame max (ms) | `tm` avg (ms) | `tm` p95 (ms) |
| ----- | ----------- | -------------- | -------------- | -------------- | ------------- | ------------- |
| Day   | start       | 16.6           | 17.4           | 18.0           | 2.8           | 4.1           |
| Day   | strip_mall  | 16.6           | 18.8           | 20.2           | 2.8           | 3.8           |
| Day   | car_care    | 16.6           | 18.3           | 23.1           | 4.7           | 6.4           |
| Night | taco_hell   | 16.6           | 20.4           | 29.3           | 9.4           | 11.9          |
| Night | cramped_inn | 17.0           | 26.6           | 33.6           | 5.3           | 12.0          |
| Night | car_care    | 27.5           | 60.0           | 67.4           | 19.1          | 49.7          |
| Night | west_road   | 17.7           | 46.5           | 61.8           | 13.3          | 33.8          |

In the night run, 119 frames went over 25 ms. In every frame over 45 ms, TrafficManager was 33–55 ms of it and the frame ran 3–4 physics steps. The editor run (unbaked) had 44 frames over 25 ms during the day tour.

### TrafficManager per tick (60 Hz, instrumented scratch copy)

| Section                                                  | Avg ms/tick             | Max ms/tick |
| -------------------------------------------------------- | ----------------------- | ----------- |
| `_update_lane_traffic` (4 lanes)                         | 1.0–1.3                 | 1.6         |
| `_update_lot_cars`                                       | 0.9–5.3                 | 5.1+        |
| ↳ `find_blocker` (inside `_update_car_yielding`)         | 0.5–4.7                 | —           |
| `_update_lane_spawning` (car `instantiate()`)            | 0.1                     | 11.4        |
| `_refresh_site_occupancy`                                | 0.08                    | —           |
| `_despawn_stalled_car`, headlamp LOD, stops              | < 0.1                   | —           |
| Other: Mats physics / all cars' own physics / `_process` | 0.1 / 0.2–0.5 / 0.2–0.4 | —           |

`find_blocker` cost grows with lot congestion (as the lot fills and watchdog deadlocks fire), not with time of day. Night runs simply hit more congestion.

### GPU pass breakdown (Vulkan/MoltenVK `--gpu-profile`, strip mall, day)

MoltenVK runs ~20% slower than native Metal, so compare these numbers with each other, not with Metal frame times.

| Pass                  | ms  |
| --------------------- | --- |
| Opaque                | 6.9 |
| Tonemap (+glow blend) | 1.7 |
| Transparent           | 1.4 |
| Directional shadows   | 1.3 |
| Glow                  | 1.0 |
| Sky                   | 0.9 |
| CanvasItems (HUD)     | 0.8 |
| Depth prepass         | 0.7 |
| **Total**             | ~17 |

### GPU A/B deltas (strip mall, same method)

| Change                                       | GPU Δ (ms)       | Notes                                                                                                                                                                                                                  |
| -------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hide `Props/Forest`                          | ~−3 to −4        | Single runs, noisy. Only runs where traffic was ticking count (unbaked 18.0 → 14.0; the baked −7.3 run had a thermally high base). Primitives roughly halve. Opaque barely moves; depth, shadow, and transparent drop. |
| Sun `shadow_enabled = false`                 | −3.6 to −4.1     | Draw calls 1,650 → 766. Shadow pass 1.3 plus ~1.5 of shadow sampling in opaque.                                                                                                                                        |
| `glow_enabled = false`                       | −0.9 to −2.8     | Glow 1.0 + tonemap 0.9                                                                                                                                                                                                 |
| Glow upscale bicubic → linear                | −0.4             | Tonemap 1.71 → 1.34                                                                                                                                                                                                    |
| `scaling_3d_scale` 0.75 / 0.5                | −4.0 / −4.3      | Opaque only halves at 0.5× (vertex-bound), so resolution scaling has limited payoff                                                                                                                                    |
| FSR2 at 0.75                                 | **+11**          | FSR2 is expensive on M2. MetalFX temporal at 0.67 also paced worse (p50 18.5–20.6 ms).                                                                                                                                 |
| Hide all `Label3D`                           | ~−1 (noisy)      |                                                                                                                                                                                                                        |
| Hide cars                                    | −0.6 GPU (noise) | Within run-to-run noise for GPU. Unbaked render CPU 2.5 → 1.0 ms is the real signal. Each car is 25–100 `MeshInstance3D` (shipping truck: 100).                                                                        |
| Forest `visibility_range_fade_mode` disabled | ≈0 net           | Transparent 1.4 → 0.2, but opaque and prepass rise by about as much. The fading forest goes through the transparent pass.                                                                                              |
| Main-scene `--bake` (editor)                 | ≈0               | Draw calls −10%                                                                                                                                                                                                        |
| Full export bake (pck)                       | ≈0 GPU           | Render CPU 2.5 → 1.1–1.6 ms. Primitives 1.05M → 1.3–1.65M.                                                                                                                                                             |

### Measurement caveats (learned while profiling)

- On Metal, `viewport_get_measured_render_time_gpu` returns 0. Use `--rendering-driver vulkan` for GPU timing.
- On macOS, the windowed compositor locks presentation to vsync even with `--disable-vsync`. Frame intervals cluster at 16.7 / 33 ms.
- `Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` report rolling maxima, not per-frame cost. Use stamp nodes at priorities ±1 around the target node.
- Thermal drift on M2 is ±2 ms over back-to-back runs (base repeats ranged 16.5–19.1 ms). Interleave A/B runs and repeat the baseline. Deltas under ~1.5 ms from single runs are noise.
- Use Vulkan runs only for GPU pass timings: their pipeline cache was cold, so their spike counts aren't representative. Take spike counts from Metal runs with no sampler attached (`sample` suspends the process and inflates frame times).
- Changing `soft_shadow_filter_quality` at runtime recompiles pipelines (0.8–1.0 s hitch), which invalidated those A/B runs.
- The official binary has no symbols, so `sample` only splits the time into engine, script, and drawable waits.

---

## 1. Measurement (do first)

- [x] **Add `--bench-tour` to `tests/benchmarks_suite.gd`**
  - Port the throwaway probe (`/tmp/perf_probe.gd`). It teleports Mats through fixed waypoints (start, walgroins, taco_hell, smell_gas, dorf, booger_king, strip_mall, cramped_inn, car_care, east_road, west_road), samples for 3 s after a 1 s settle, and runs day and night.
  - Per frame, record: frame interval, physics steps, TrafficManager / Mats / remaining physics script ms (stamp nodes at priorities −1001/−999 and −501/−499 around TM at −1000 and Mats at −500), render CPU, GPU (Vulkan only), draw calls, and primitives.
  - Report p50/p95/max per waypoint. Print each spike with its `tm` share and step count.
  - Accept `--seed=` and a congestion warmup (`--warmup=120` s) so the night/congested case reproduces. The current day tour starts with empty lots and misses the spiral.
  - Done: `mise run bench --bench-tour [--seed=N] [--warmup=SEC] [--tour-phases=night,day] [--tour-wps=a,b] [--bake]` (warmup defaults to 120 s; the runner raises the timeout to cover it).
- [x] **Benchmark the shipped build, not the editor scene**
  - Add `mise run export-mac-pack`: rsync to `/tmp`, enable `mesh_baker` (same as `export-web`), and `--export-pack` a macOS preset to `/tmp/stroad_mac.pck`.
  - The bench must run with `--main-pack /tmp/stroad_mac.pck`.
  - Done: `mise run export-mac-pack && mise run bench --bench-tour --main-pack=/tmp/stroad_mac.pck`. The macOS preset is appended only in the `/tmp/stroad-hero-export-mac` copy; the repo's `export_presets.cfg` stays Web-only. The tour header prints `exported=true` under a pack, and `--bake` is skipped there (the pack is baked at export). Re-export after script changes: the pack holds its own compiled scripts.
- [x] **TrafficManager section timers**
  - Extend the existing `profile_find_blocker` gate (`--profile-traffic`) to time the `_physics_process` sections (lane traffic, lane spawning, lot cars, despawn), with avg/max per 600 ticks. Production stays zero-cost.
  - Done: `mise run bench --bench-tour --profile-traffic` prints `TM_PROFILE:` every 600 ticks (sections `stops`, `lane_traffic`, `lane_spawning`, `transfers`, `lot_cars`, `despawn`, `bookkeeping`, `total`, each avg/max ms, plus `find_blocker` calls and ms per tick). The timed path is `_physics_process_profiled`; production pays only a single bool check. First night run (20 s warmup): `lot_cars` averaged 1.4–2.7 ms (max 7 ms), and `lane_spawning` maxed at 11–19 ms, which looks like an `instantiate()` hitch.
- [x] Record before/after numbers for every item below in `docs/optimizations.md`.
  - Done: baseline (before) numbers are in `docs/optimizations.md` §5 (seed 1, baked Metal pack, 120 s warmup, `--profile-traffic`). Each later item adds its after-numbers there, rerun with the same command.

---

## 2. P0: Stop the Traffic CPU Spiral

Target: TrafficManager ≤ 2 ms/tick p95 under congestion, and never more than 2 physics steps per frame on M2.

- [x] **Cap physics catch-up on desktop**
  - Set `physics/common/max_physics_steps_per_frame=3` for all platforms (web already uses 3; the default is 8).
  - When a tick overruns, the simulation slows briefly instead of stacking 4–8 ticks into one frame.
  - Safe: no visual change, one setting. Do this first; it bounds the worst case while the items below land.
  - Done: `project.godot` sets `common/max_physics_steps_per_frame=3` globally (replaced the `.web` override). After-numbers in `docs/optimizations.md` §5.1.
- [x] **Broadphase in `find_blocker` / `CarSweep`**
  - `CarSweep.candidate_conflict_distance` (`traffic/car_sweep.gd:163`) runs a SAT test for every footprint pair (`a.size() × b.size()`), with no whole-sweep bound.
  - Store each sweep's 2D `Rect2` (union of its footprints) in the sweep cache next to `rects`/`dists`. Reject the car pair when the two `Rect2`s don't intersect, before any per-rect work.
  - In `footprints_overlap`: precompute each footprint's center and radius once per sweep instead of two `distance_to` calls per pair, and drop the `for poly in [a, b]` array allocated on every call (unroll the two polygons).
  - Behavior must stay identical. `mise run test` (traffic contracts) is the guard.
  - Done: `CarSweep.car_sweep` caches `bounds` (`Rect2`, grown by `BOUNDS_MARGIN`), `centers`, `radii`; `candidate_conflict_distance` uses them via `_overlap_with_circles` / `_separated_on`. Fuzz vs. the old code: 0 mismatches in 200k pairs. `find_blocker` 0.7–4.1 → 0.4–1.9 ms/tick (`docs/optimizations.md` §5.2). Note for the pair cache: `candidate_conflict_distance` is not symmetric even without reversing (hard check uses `mine` look and `theirs[0]`; soft loop is `i ≥ 0` vs `j ≥ 1`).
- [x] **Per-tick pair cache**
  - When both cars of a pair are lot cars, `_conflict_distance(a, b)` and `(b, a)` each rebuild the same footprint overlap. Cache `candidate_conflict_distance` per tick by (min id, max id) and swap the result for the reverse query, if the function is symmetric. Verify symmetry first: the `reversing_*` branches are not symmetric.
  - Done: not symmetric, so no mirroring. `TrafficManager._candidate_conflict` caches each directed pair in `_pair_cache` keyed by both cars' `sweep_rev` (exact; persists across ticks while revs hold, cleared every 60 ticks). Same-seed A/B: `find_blocker` 1.00 → 0.86 ms/tick avg (−13%/call), ~3 hits/tick (`docs/optimizations.md` §5.3).
- [x] **Spatial bucketing of candidates**
  - `_build_blocker_candidates` returns every non-parked lot car plus every PATH ghost, and each lot car tests all of them. Sort the candidates by `x` once per tick (or use a 10 m grid), so each car only scans neighbors within its `reach`.
  - Handoff: `_find_blocker_impl` keeps the first candidate on equal distance (strict `<`), so a re-sort must preserve original candidate order on ties (else `current_blocker`/`blocked_time`/watchdog timing shift). The reach test is pairwise (`my_reach + _get_car_reach(other)`): the x-window must be `my_reach + max reach` over the tick's candidates (reversing cars' `path_distance` horizon makes it large), not a fixed 10 m.
  - Done: `_index_blocker_candidates` (called in `_update_lot_cars`) x-sorts the candidates; `_find_blocker_impl` bsearches `my_reach + max reach + CANDIDATE_X_SLACK` and breaks distance ties by original index. Only the array passed from `_update_lot_cars` is indexed (`is_same`); other callers full-scan. 0 mismatches vs a full scan in 120k calls. `cand`/call 4.8–8.5 → 1.9–4.4, ~0.1 ms/tick net (`docs/optimizations.md` §5.4).
- [x] **`_update_lane_traffic` allocations (1.0–1.3 ms/tick)**
  - Each of the 4 lanes loops over all `lot_cars`, calls `lane.cars.has(car)` (linear), allocates `valid_cars` / `shouldered_cars` / `surviving_cars`, and runs `sort_custom` with a lambda.
  - Bucket `lot_cars` by lane once per tick. Keep a per-lane membership `Dictionary`. Reuse the arrays as members. Use an insertion sort, since lane order barely changes between ticks.
  - Done: `_bucket_lot_cars_by_lane` fills `Lane.lot_path_cars` once per tick (only inside the `_physics_process` lane loop, gated by `_lane_buckets_valid`; direct test calls still scan `lot_cars`). `valid_cars`/`shouldered_cars` are `Lane` members, `surviving_cars` double-buffers with `lane.cars` via `Lane.spare_cars`, and `_sort_by_lane_distance_desc` is a stable insertion sort. Membership `Dictionary` skipped (`has` runs only for 0–3 in-apron PATH cars/lane; `lane.cars` has ~8 mutation sites). 0 mismatches in 25,200 lane updates. Net only ~0.04 ms/tick: allocations were never the cost. The real lane cost is `Car.advance_simulation` (~0.4 of ~1.0 ms/tick, `docs/optimizations.md` §5.5).
- [x] **Car spawn hitches (time the spawn path first)**
  - `_update_lane_spawning` peaked at 11.4 ms for one call in a windowed run. A headless `instantiate()` test is not representative: passenger-car bodies attach during `setup()`, and render instances and materials only exist in a windowed run.
  - Time `instantiate()` / `add_child()` / `setup()` separately in a windowed run. If body attach or the first render instance dominates, pool cars per scene type and reset them in `setup()` instead of `queue_free()`.
  - Spawns are global (not tied to the camera), so these hitches can hit at any time.
  - Done: timed in windowed baked-pack runs. `instantiate()` is never the cost (p50 0.08 ms). Two fixes: `_spawn_car_at` sets `car_type` before `add_child` (passenger `_ready` had built a sedan body that `setup()` then swapped), and `TrafficManager._load_car_scenes()` loads all car/body scenes and the siren wail (12.9 ms) at the start of the staged initial spawn. Spawn p50 1.07 → 0.74 ms. The remaining peak is police SUV body attach, 2–8 ms per police spawn (~8% of spawns). Car pooling was not done; if needed, pool the police body or defer its lens-material duplication (`docs/optimizations.md` §5.6).
- [!] [HUMAN REVIEW NEEDED] **Desktop physics at 30 Hz with interpolation** - **Issue:** needs a human play-feel decision (Mats' movement/jump arc and car-vs-Mats collision at 30 Hz can't be judged headless), and a choice between global 30 Hz and the staggered-blocker alternative below. Not started.
  - Web already runs `physics_ticks_per_second=30` with `physics_interpolation=true`. `FollowCamera` already reads `get_global_transform_interpolated()`, and cars call `reset_physics_interpolation()` on teleports.
  - This halves every physics script cost (TrafficManager, cars, Mats).
  - Risks: Mats' movement feel and jump arc, the car-vs-Mats collision response, and tests that assume 60 ticks (`--physics-ticks=` exists for overrides).
  - Alternative with less risk to how controls feel: keep 60 Hz physics, but run `TrafficManager._update_lot_cars` blocker evaluation at 30 Hz, staggered by car id (even and odd cars alternate ticks), while path integration stays every tick.
- [x] **Investigate congestion growth**
  - The night runs showed watchdog deadlocks (`TO_SPOT` vs `TO_EXIT`) and up to 88 live cars. TrafficManager cost tracks congestion, and `find_blocker` grew to 4.7 ms/tick.
  - Not yet ruled out: (a) the night tour always ran right after the day tour, so run night first once to exclude thermal throttling; (b) a closing-time exit rush from the recent days-end change (commit 6507779) inflating lot conflicts.
  - Check whether `_despawn_stalled_car` and the watchdog clear jams fast enough. A jam costs CPU every tick it persists.
  - Done (no code change; `docs/optimizations.md` §5.7): a night-first tour still shows the night frame drops (148 spikes vs 25 day, ~32 ms frames with `tm` ≤ 4.2 ms and render CPU ≤ 3.5 ms), so they are not thermal and not traffic. They are likely GPU/present-bound night lighting (→ §3). TM cost was equal: night 1.76–2.01 ms/tick, day 1.77–2.17. No exit rush: traffic reads the clock only for headlamp LOD, and 6507779 added the stall despawn and car cap. Headless 10-minute day→night runs hold 66–87 live cars with no growth. Jams are watchdog-unresolvable `SHORTCUT`↔`TO_EXIT`/`SHORTCUT` deadlocks that only the 30 s stuck despawn clears (worst: 18 cars stalled ~40 s). They don't raise `find_blocker` (0.28–0.95 ms/tick), so speeding up jam recovery is a gameplay call, not a perf item.

---

## 3. P1: GPU Headroom With No Visual Change

Target: ≥ 4 ms GPU headroom at Retina native on M2 (Vulkan strip mall ≤ 13 ms), which covers weaker laptop GPUs.

- [x] **Chunk the forest MultiMeshes spatially** (biggest GPU item, ~3–4 ms)
  - `props/forest.gd:250` builds 36 `MultiMeshInstance3D` (18 mesh parts × East/West × Near/Far). Each covers a whole side of the map, so frustum culling almost never rejects one, and every tree's vertices go through the depth prepass, shadow, and opaque passes.
  - Split each bucket into ~40 m tiles (same meshes and transforms, so the result looks identical). Culling and `visibility_range` then work per tile.
  - With tiles, only the tiles inside the 135–160 m fade band go through the transparent pass. Today whole buckets do (transparent 1.4 → 0.2 ms when the fade is disabled).
  - Verify: screenshot diff from the bench camera and a tour waypoint; compare forest primitives per frame before and after.
  - Done: `Forest._build_multimeshes` buckets by 40 m tile (`forest_tile_size`) × Near/Far (East/West split dropped). Tiles pad `visibility_range_end` by the tile half-diagonal (Godot measures to the AABB center; unpadded 160 m faded back rows). Forest-only scene: primitives 518k → 96k at the bench camera, GPU ~1 ms lower; screenshot diffs at noise except where old whole-side buckets were mid-fade (`docs/optimizations.md` §5.8). Throwaway probe: `/tmp/forest_shot.gd` (forest-only shots + prims/draws/GPU per camera).
- [x] **Forest LOD**
  - After chunking, Godot picks mesh LOD per tile AABB. Procedural tree meshes (`props/tree.gd` cylinders/spheres) are plain `ArrayMesh` with no LODs. Generate them via `ImporterMesh.generate_lods()` when building the cache. Check that the `.blend` trees import with LODs enabled.
  - Keep `rendering/mesh_lod/lod_change/threshold_pixels` at its default so the change is not visible.
  - Done: `.blend` trees already import with `meshes/generate_lods=true`. `Forest._get_variant_mesh_parts` rebuilds procedural `PrimitiveMesh` parts via `ImporterMesh.generate_lods()` (`Forest._with_lods`; skipped on web, where `ImporterMesh` is stripped). Verified in the macOS release template: 3–5 LODs per part, cache build ~6 ms. Forest primitives −11–13% per camera vs the same code without the pass; GPU flat within noise; screenshot diffs only on wind-animated live-oak foliage (untouched by the pass), none on procedural trees (`docs/optimizations.md` §5.9). Probe `/tmp/forest_shot.gd` gained `--nolod`.
- [x] **Shadow caster audit** (sun shadows cost 3.6–4.1 ms; they double draw calls)
  - Count shadow-pass casters per group (forest Near, buildings, cars, props, labels). Turn shadows off for casters whose shadow is under ~1 px at the camera height (small trim, wheel hubs, signs flat against walls, roof clutter), following `docs/optimizations.md` §3.4.
  - Keep shadows for the forest Near tiles, buildings, cars, Mats, poles, and lamps.
  - Done (audit only, no casters turned off; `docs/optimizations.md` §5.10): shadow-pass draws at the bench camera are cars 448, buildings 122, props 76, forest 0 (Near tiles lie beyond the sun's 65 m shadow distance), and labels none (baked pck). The tiny-caster set (parts adding ≤ 2 cm to an enclosing box's shadow, or under 8 cm) is −52 draws unbaked and −3 baked, with no measurable GPU change. Even with every caster except Mats off, the saving is only 0.1–0.6 ms, against 2.6–2.8 ms for turning the sun's shadow off. The sun shadow cost is mostly fixed (atlas plus sampling), so trimming was skipped. Handoff for the bake items below: the baker merges shadow-off parts into shadow-casting meshes, so §3.4's per-part `cast_shadow` is lost in exports. Throwaway probes: `/tmp/shadow_audit.gd`, `/tmp/shadow_filter_shot.gd`.
  - [!] [HUMAN REVIEW NEEDED] Test `directional_shadow/soft_shadow_filter_quality` 2 → 1 with screenshot comparison. Shadow sampling is ~1.5 ms of the opaque pass. Set it in project settings, never at runtime (pipeline recompile hitch). - **Issue:** measured, not applied; needs human visual sign-off. GPU −0.9 ms (bench) / −1.2 ms (strip mall); diffs barely above the q2-vs-q2 noise floor (`docs/optimizations.md` §5.10). Compare `/tmp/sf_{bench,strip_mall,close}_{q2,q1}.png` (diff maps `/tmp/sf_*_diff.png`). If approved, set `lights_and_shadows/directional_shadow/soft_shadow_filter_quality=1` in `project.godot`.
- [!] [HUMAN REVIEW NEEDED] **Glow upscale linear** (`rendering/environment/glow/upscale_mode=0`) - **Issue:** measured, not applied; needs human visual sign-off. In night screenshots, linear vs bicubic is at the bicubic-vs-bicubic noise floor (> 8/255), with only faint halo changes at > 2/255 (`docs/optimizations.md` §5.11). Compare `/tmp/glow_{bench,strip_mall,close}_{bicubic,linear}.png` (diff maps ×8: `/tmp/glow_*_diff.png`). If approved, set `rendering/environment/glow/upscale_mode=0` in `project.godot`.
  - Saves 0.4 ms. Compare night screenshots (headlights, streetlamps, neon), where glow is most visible.
- [x] **Fix export bake culling granularity**
  - The baked export draws 30–40% more primitives than the unbaked scene (1.05M → 1.3–1.65M at the same waypoint). `MeshBaker.bake_static_scene` merges whole groups into one mesh, so per-part `visibility_range_end` and frustum culling are lost.
  - Group merges by `visibility_range_end` (and keep the range on the merged instance). Don't merge across more than ~30 m. Leave `Label3D` and anything with a visibility range unbaked.
  - Done (`docs/optimizations.md` §5.12): every `MeshBaker` merge now groups by render key (`cast_shadow` plus visibility range settings, kept on the merged instance). `bake_static_scene` also splits by 30 m cell (`BAKE_CELL_SIZE`). Merged meshes get generated LODs. Hidden subtrees and `Label3D` stay unbaked. Ranged parts are grouped rather than left unbaked (fewer draws); ranged cells shrink to `range / 4`. Bench camera, full scene: 1470 draws / 870k prims (old pack) → 1232 / 234k (unbaked editor: 1537 / 466k). Static screenshots match the unbaked scene apart from two issues the old pack also had. Also fixed: washed-out colors on color-collapsed surfaces (`vertex_color_is_srgb`) and flag poles vanishing at 35 m. `export_plugin.gd` customization hash is now 14; bump it on every baker change, or exports reuse cached scenes.
  - Handoff for desktop presets: **streetlights do not render in the exported pack** (old and new). `Props/Streetlights/BakedMultiMesh` loads with identity transforms, and the lamp instances draw nothing. Fix this before shipping desktop presets. Probes: `/tmp/sl_probe.gd`, `/tmp/bake_shot.gd`. Fixed in the next item.
- [x] **Desktop export presets with baking**
  - There is no macOS/Windows/Linux preset. `mesh_baker` is enabled only inside the `export-web` task.
  - Add desktop presets and enable the plugin in their export task. This saves 40–50% of render-thread CPU (cars are 25–100 meshes each unbaked) and lands after the culling fix above.
  - Done (`docs/optimizations.md` §5.13): `export_presets.cfg` has `macOS` (universal), `Windows Desktop`, and `Linux` (x86_64). `mise run export-desktop` exports them baked to `build/{macos,windows,linux}` through `scripts/prepare_export_copy.sh` (shared with `export-web`/`export-mac-pack`; the mac pack now uses the `macOS` preset). macOS universal needs `import_etc2_astc=true` (set in `project.godot`). Fixed the streetlight blocker: the headless exporter's dummy RenderingServer drops `set_instance_transform`, so `MeshBaker.set_multimesh_transforms` writes `MultiMesh.buffer` directly. Also fixed sub-scenes loading twice in the pack (122 duplicate nodes: every building drawn twice, 15 extra lamps with SpotLights, trees, flags, sedan/F150 spokes). The fixes are `MeshBaker.make_local`, `bake_scene_for_path` as the single export dispatch, and skipping inherited scenes over baked bases. Static-shot draws are 3–10% lower than the old pack, pixel diffs against the unbaked scene drop at most cameras, and night lamps match. The exported `.app` runs clean on M2. Customization hash is now 15. Render-thread CPU was not re-benched (`mise run bench --main-pack=/tmp/stroad_mac.pck`).
- [x] **Labels (low)**
  - Hiding all `Label3D` saved ~1 ms (noisy). Revisit only if the bench still shows them significant after the forest and shadow work.
  - Done (no code change, `docs/optimizations.md` §5.14): in the baked pck, hiding all 229–244 labels changes GPU by ±0.2 ms (noise) by day and at night, and render CPU by ≤ 0.1 ms. Not significant, so not revisited. Probe: `/tmp/label_probe.gd`.

---

## 4. P2: Resolution and Frame Pacing

- [!] [HUMAN REVIEW NEEDED] **Dynamic render scale fallback** - **Issue:** dropping below 1.0 softens/sharpens the image, so whether to ship an automatic fallback (and which upscaler) is a human visual decision. Not implemented. The measurement it waited on is done: on Metal, MetalFX spatial 0.75 is the cheapest (−2.9 ms GPU vs −2.1 for FSR1); see the sub-item.
  - Scale 0.75 saves ~4 ms but softens the image (FSR1 via mode 1 is sharper than bilinear). FSR2 costs +11 ms on M2 (Vulkan GPU timers). MetalFX was checked only by Metal frame pacing, which is capped at the display rate, so that test can show regressions but not savings.
  - [x] Evaluate MetalFX spatial/temporal on target hardware with a frame-time measure that isn't vsync-capped before ruling it in or out.
    - Done (`docs/optimizations.md` §5.15): GPU busy per frame came from Instruments Metal System Trace, which isn't vsync-capped. On M2 at the strip mall, native is 14.1 ms, FSR1 0.75 is 11.9, MetalFX spatial 0.75 is 11.2, and MetalFX temporal is 18.3 at 0.75 (≈ native at 0.5). Temporal is ruled out. Spatial is in for Metal, and FSR1 remains the option for Vulkan/D3D12. Compare `/tmp/mfx_shot_*.png`.
  - Proposal: keep 1.0 by default. When measured frame time stays above budget for ~2 s, step down to 0.85/0.75 with FSR1; step back up when there is headroom. The `G` toggle (`ui/hud.gd:cycle_render_scale`) stays as a manual override.
- [x] **Vsync cliff**
  - With vsync, a 17–18 ms frame displays at 33 ms. On machines just over budget, every GPU item above is worth a full halving of the frame rate, not 1–2 ms.
  - Evaluate `display/window/vsync/vsync_mode` adaptive where supported (Vulkan on Windows/Linux). Metal ignores it.
  - Done (`docs/optimizations.md` §5.16): `project.godot` sets `window/vsync/vsync_mode=2` and `vsync_mode.macos=1`. The macOS override exists because Metal maps Adaptive to Enabled and MoltenVK warns and falls back. Windows/Linux resolve to Vulkan, where Adaptive is `FIFO_RELAXED`. Tearing vs. judder there is untested (no hardware).
- [x] **Thermal**
  - Sustained load on fanless laptops (MacBook Air) slows the GPU over minutes (back-to-back runs drifted 16.6 → 18–20 ms). Reducing the work (P0, P1) is the fix. Don't add a frame cap below the display refresh rate.
  - Done (no code change): the work reduction landed in §2/§3, and no frame cap exists (`max_fps` isn't set in `project.godot` or any script). On Windows/Linux Vulkan, Adaptive V-Sync (above) should keep a throttled 18–20 ms frame from halving to 30 fps (untested).

---

## 5. P3: Hitches

- [x] After P0, re-run the tour and recheck the remaining spikes. The large spikes seen so far (93–103 ms) were TrafficManager multi-steps, not shader compiles.
  - Done (`docs/optimizations.md` §5.17): no multi-step spikes remain. Worst frame 34.1 ms; all 33 spikes (5 day, 28 night) are single missed vblanks with 1 physics step, `tm` ≤ 2.6 ms, and render CPU ≤ 2.2 ms. Night spikes cluster at the busiest views (start, booger_king, car_care), which is GPU budget, not hitches.
- [x] Not yet measured: the dusk transition (`docs/optimizations.md` recorded a 38 ms Forward+ max) and a night `--gpu-profile` waypoint sweep. Add both to `--bench-tour`.
  - Done (`docs/optimizations.md` §5.18): `--bench-tour` now runs `day,dusk,night` by default. `dusk` holds the first waypoint and sweeps 18.0 → 19.6 h in 10 s. The runner flag `--gpu-profile` switches to Vulkan and prints per-pass GPU means per waypoint (`scripts/run_tests.py:split_gpu_profile`). No dusk hitch: the worst frame is 33.9 ms and the lights-on frame is 25.2 ms. Spikes after lights-on are the `start` GPU budget. Night GPU (MoltenVK) ranges 15.9–21.9 ms; only Opaque (5.5–9.1 ms) varies by view.
- [x] If a graphics settings menu is added, apply shadow-filter, glow, and scale changes behind a one-frame warmup (`world/world_warmup.gd`), because they recompile pipelines (0.8–1.0 s).
  - Not triggered: no graphics settings menu exists. No script changes shadow-filter quality or glow at runtime. Only `ui/hud.gd:cycle_render_scale` (F2) and `ui/retro_filter.gd` change `scaling_3d_scale`. Only the shadow-filter recompile was measured (§ Notes above); glow and scale recompile costs are unmeasured. This item stays a constraint for any future settings menu.

---

## 6. Acceptance

- [!] Baked Metal build on M2, Retina native, `--bench-tour` day and night after a 120 s congestion warmup: - **Issue:** measured, fails (`docs/optimizations.md` §5.19, two runs). Frame p95 18.1–19.7 ms at day strip_mall/cramped_inn/car_care and 31–32 ms at night `start`/`cramped_inn` (GPU-bound vsync cliff, not traffic: `tm` ≤ 4.5 ms, render CPU ≤ 2 ms). Worst frame 33.2–34.0 ms (single missed vblanks). ≤ 2 physics steps passes. Every remaining GPU lever needs a human visual decision: soft shadow filter 2 → 1 (−0.9 to −1.2 ms), glow upscale linear (−0.4 ms), or the dynamic render scale fallback (MetalFX spatial 0.75, −2.9 ms).
  - Frame p95 ≤ 18 ms at every waypoint.
  - No frame > 33 ms after startup.
  - ≤ 2 physics steps per frame.
- [!] TrafficManager ≤ 2 ms/tick p95 under congestion (`--profile-traffic`). - **Issue:** measured, fails (`docs/optimizations.md` §5.19). `TM_PROFILE` `total` averages 1.74–2.84 ms/tick (over 2 ms in 18 of 21 windows, max 4.2–19.7), so p95 is above 2 ms; unprofiled per-frame `tm` p95 is 2.2–4.5 ms. Closing a ~30–40% gap needs the §2 `[HUMAN REVIEW NEEDED]` **Desktop physics at 30 Hz with interpolation** item (or its staggered 30 Hz blocker-evaluation alternative, which changes traffic timing). No other identified lever is that large: `lot_cars` is 0.8–2.0 ms and `lane_traffic` 0.7–0.9 ms, most of it `Car.advance_simulation`.
- [!] Vulkan GPU at strip mall ≤ 13 ms (≥ 4 ms headroom). - **Issue:** measured, fails (`docs/optimizations.md` §5.19). Day is 16.0 ms (pass total) and night 19.5 ms, so ≥ 3 ms is still missing. The remaining levers are all `[HUMAN REVIEW NEEDED]`: soft shadow filter 2 → 1 (−1.2 ms at strip mall), glow upscale linear (−0.4), and the dynamic render scale fallback (0.75: about −3 to −4). Even together they only just reach 13 ms by day, and not at night. Getting there by night also needs a visual decision on content: sun shadows (−3.6) or forest/opaque density.
- [x] Screenshot comparison at the bench camera and 3 tour waypoints (day and night) shows no visible difference for items not marked `[HUMAN REVIEW NEEDED]`.
  - Done (`docs/optimizations.md` §5.20): bench, strip_mall, taco_hell, and car_care, day and night, comparing unbaked `HEAD`, the current unbaked scene, and the current baked pack. Two bake regressions were found and fixed: street lamp heads cast shadows in the pack (`single_mesh` template bakes now split by `cast_shadow`, so there is one `BakedMultiMesh*` per setting), and merged normals were wrong under non-uniform scale (`SurfaceTool.append_from`; the Taco Hell bell shading). Remaining differences are ≤ 158 px of specks, plus far forest trees in day strip_mall/car_care that the old whole-side buckets drew mid-fade and now draw solid (§5.8, matches their visibility range).
- [!] [HUMAN REVIEW NEEDED] Minimum-spec target: pick a reference laptop (e.g. 1080p Intel Iris Xe) and its fps target. - **Issue:** product decision for a human: which reference hardware and fps target (e.g. 30 or 60 fps at 1080p) to commit to. No such hardware is available here to measure on. Once chosen, record it here and run `--bench-tour` on that machine.
