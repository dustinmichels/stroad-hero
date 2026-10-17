# Web Build Improvements

Plan for shipping the Web export and making it run well. The numbers come from a profiling pass on Oct 17, 2026: Godot 4.7.2, Apple M2, Chromium with WebGL 2 through ANGLE Metal.

## Baseline

| Metric                                         | Value                                                     |
| ---------------------------------------------- | --------------------------------------------------------- |
| `index.wasm`                                   | 39.5 MB (about 10 MB gzipped, as served by Pages)         |
| `index.pck`                                    | 31 MB, of which 28.8 MB is `samples/` textures (22 files) |
| Main-thread CPU per frame (rAF callback, idle) | avg 12–15 ms, p95 16–20 ms, spikes 38–96 ms               |
| Native headless physics step                   | about 3 ms                                                |
| Nodes / `MeshInstance3D`                       | 7,060 / 6,382                                             |
| Shadow-casting lights                          | 14 (sun, 12 street lamps, character editor `KeyLight`)    |

The 60 fps budget is 16.7 ms per frame, and an M2 already uses most of it. GPU time hasn't been measured; rAF callback time only counts CPU-side submission. The test browser caps rAF at 30 Hz, so it can't show the real frame rate.

The web build always uses the Compatibility renderer, even though `project.godot` says Forward+. Check visuals in the browser, not the editor.

## 1. Deploy path

- [ ] Add a GitHub remote. `git remote -v` is currently empty.
- [ ] In the repo settings, set Settings → Pages → Source to "GitHub Actions".
- [ ] Merge `dev` into `main`. `.github/workflows/deploy-web.yml` only runs on pushes to `main`, or by hand through `workflow_dispatch`.
- [ ] Keep `variant/thread_support=false`. GitHub Pages can't send the COOP/COEP headers that a threaded build needs.

Verify: the workflow run goes green, and the Pages URL loads to the street scene with no console errors.

## 2. Download size: stop shipping `samples/`

`export_filter="all_resources"` packs every imported resource. `samples/` holds reference photos that no scene or script uses, and it makes up 28.8 MB of the 31 MB pck. (`screenshots/` already has a `.gdignore` and is not packed.)

- [ ] In `export_presets.cfg`, set `exclude_filter="samples/*"` on the Web preset. Prefer this over adding a `.gdignore`, so the images still show in the editor's FileSystem dock.

Expected: `index.pck` drops from 31 MB to about 2–3 MB. CI picks this up too, because it uses the same preset.

Verify: `mise run export-web`, then `ls -la build/web/index.pck`, then `strings build/web/index.pck | grep -c 'samples/'` should print `0`.

## 3. Render cost

### 3a. Character editor preview renders every frame

`player/character_editor.tscn` sets the preview `SubViewport` to `render_target_update_mode = 4` (`UPDATE_ALWAYS`). That renders a second 3D scene, with its own shadowed `KeyLight`, on every frame, even while the editor is closed.

- [ ] Set it to `UPDATE_WHEN_VISIBLE` (2) in the scene, or switch it between `UPDATE_DISABLED` and `UPDATE_ALWAYS` from `character_editor.gd` when the editor opens and closes.

### 3b. Shadowed street lamps

`props/street_lamp.tscn` has `shadow_enabled = true` on 12 `SpotLight3D`s. In Compatibility, every shadowed positional light needs its own shadow-map pass. This is GPU work that hasn't been measured, and it's the most likely cost on weaker laptops and mobile GPUs.

Options, cheapest first:

- [ ] Set `shadow_enabled = false` in `street_lamp.tscn`. Lamp shadows hardly show in daylight.
- [ ] Or keep them on desktop and turn them off only for web: add a small script on the lamp that sets `shadow_enabled = not OS.has_feature("web")`. Another option is a web override such as `rendering/lights_and_shadows/positional_shadow/atlas_size.web`; check that the override actually disables spot shadows before relying on it.
- [ ] Consider dropping the lamp lights entirely on web (`visible = false` on the `Light` node) if the scene stays daytime.

### 3c. Draw calls from small meshes

Each visible car is about 37–49 `MeshInstance3D`s, and props add hundreds more. In WebGL every draw call goes through JS→GL bindings on the main thread.

- [ ] Confirm the real count first. In the editor, Debugger → Monitors shows `Raster > Total Draw Calls` and `Total Objects In Frame`. Headless always reports 0.
- [ ] Merge static scenery (buildings, lot striping, sidewalk pieces) into fewer meshes, or bake it into a single mesh per building.
- [ ] Move repeated props (trees, bollards, carts, flags) to `MultiMeshInstance3D` where they don't need per-instance logic.
- [ ] Merge each car body's parts into one mesh per variant, using a few material slots instead of many child nodes.

### 3d. Resolution and fill rate

`display/window/dpi/allow_hidpi` defaults to on, so Retina screens render at 2× (2940×1672 in the tests).

- [ ] Try a web-only `rendering/scaling_3d/scale.web` of 0.75, or 0.5 with FSR off, and compare frame time on a weaker device.
- [ ] Recheck `glow_enabled` and shadow distance and size under Compatibility; cut them for web if they cost more than they add.

## 4. Scene and CPU cost

### 4a. Hidden car variants

`cars/passenger_car.tscn` contains all six body styles (Sedan, SUV, Pickup, Hatchback, Minivan, Sports). `_apply_visual_type()` in `passenger_car.gd` hides five of them. Each car therefore carries 266 meshes, of which 37 are visible: about 5,600 dead nodes across 21 cars. Hidden meshes aren't drawn, but they cost memory, spawn time and scene-tree traversal.

- [ ] Split each body style into its own scene, for example `cars/bodies/sedan.tscn`.
- [ ] In `_apply_visual_type()`, instantiate only the chosen body under `Visuals`, instead of toggling visibility.
- [ ] Keep `_get_node_for_type()` and `_apply_paint_material()` working against the single instanced body.

Expected: total nodes go from about 7,000 to about 1,500.

### 4b. Find where the physics and logic time goes

The native physics step is about 3 ms. Turning individual scripts off gave noisy results, so it's still unknown whether the time goes to `traffic_manager.gd`, `car.gd`, or the physics server handling 21 car `Area3D`s.

- [ ] Run the main scene from the editor and use Debugger → Profiler (per-function script time) and Visual Profiler (CPU/GPU per render stage).
- [ ] Fix whatever tops the list. Likely candidates: per-tick `get_baked_length()` calls and per-car yielding checks in `_update_lot_cars`, or Area3D overlap monitoring that can be replaced with distance checks along the lane.

### 4c. Debug overlay

`traffic/traffic_debug.gd` creates `Label3D`s and does per-frame work only while it's visible (F3).

- [ ] Leave it as is, but consider stripping the node from release builds with `if not OS.is_debug_build(): queue_free()`.

## Order of work

1. Exclude `samples/` (2): one line, removes most of the download.
2. Character editor viewport (3a) and lamp shadows (3b): one-line scene edits.
3. Deploy (1).
4. Profile in the editor (3c count, 4b), then do the car body split (4a) and mesh merging (3c) based on what the profiler shows.
5. Web-only resolution scale (3d) if weaker devices still drop below 30 fps.

## How to measure

- Export: `mise run export-web` (exports from a copy in `/tmp`; the open editor's `.godot/` is untouched).
- Serve: `python3 -m http.server -d build/web 8000`, then open `http://localhost:8000`.
- Frame time: in DevTools, record a Performance trace for 10 s while idle and again while walking. Compare the main-thread time per frame and the GPU track against the baseline table above.
- Test on at least one non-Apple-Silicon laptop and one phone. The M2 numbers are a best case.
