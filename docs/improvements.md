# Build and Performance Improvements

Plan for shipping the Web export, making it run well, and keeping desktop builds in line. The numbers come from a profiling pass on Oct 17, 2026: Godot 4.7.2, Apple M2, Chromium with WebGL 2 through ANGLE Metal.

## Baseline

| Metric                                         | Value                                                    |
| ---------------------------------------------- | -------------------------------------------------------- |
| `index.wasm`                                   | 39.5 MB (about 10 MB gzipped, as served by Pages)        |
| `index.pck`                                    | 855 KB (`samples/` excluded from the export)             |
| Main-thread CPU per frame (rAF callback, idle) | avg 12–15 ms, p95 16–20 ms, spikes 38–96 ms              |
| Native headless physics step                   | about 3 ms                                               |
| Nodes / `MeshInstance3D`                       | 7,060 / 6,382                                            |
| Shadow-casting lights                          | 1 (sun), plus the character editor `KeyLight` while open |

The 60 fps budget is 16.7 ms per frame, and an M2 already uses most of it. GPU time hasn't been measured; rAF callback time only counts CPU-side submission. The test browser caps rAF at 30 Hz, so it can't show the real frame rate. The CPU and node rows were measured before the character editor preview was limited to when the editor is open and the street lamp lights were removed, so measure them again.

The web build always uses the Compatibility renderer, even though `project.godot` says Forward+. Check visuals in the browser, not the editor.

## 1. Deploy path

- [x] Add a GitHub remote. (`origin` set to `git@github.com:dustinmichels/stroad-hero.git`).
- [ ] In the repo settings, set Settings → Pages → Source to "GitHub Actions".
- [ ] Merge `dev` into `main`. `.github/workflows/deploy-web.yml` only runs on pushes to `main`, or by hand through `workflow_dispatch`.
- [x] Keep `variant/thread_support=false`. GitHub Pages can't send the COOP/COEP headers that a threaded build needs (set in `export_presets.cfg`).

Verify: the workflow run goes green, and the Pages URL loads to the street scene with no console errors.

## 2. Render cost

### 2a. Draw calls from small meshes

Each visible car is about 37–49 `MeshInstance3D`s, and props add hundreds more. In WebGL every draw call goes through JS→GL bindings on the main thread.

- [ ] Confirm the real count first. In the editor, Debugger → Monitors shows `Raster > Total Draw Calls` and `Total Objects In Frame`. Headless always reports 0. The F3 overlay now displays `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `TIME_PROCESS`, and `TIME_PHYSICS_PROCESS` so the real count can be read in the editor or web build.
- [x] Merge static scenery (buildings, lot striping, sidewalk pieces) into fewer meshes, or bake it into a single mesh per building. (`MeshBaker.bake_main_scene` bakes `Road` [stroad, 5 sidewalks, 2 aprons, 44 markings] into 1 mesh and `Parking` [lots, driveways, 29 stall stripes] into 1 mesh with collisions intact; `MeshBaker.bake_static_scene` bakes buildings and static props at export. Note: Taco Hell's scripted `DriveThru` subtree remains unbaked).
- [x] Move repeated props (trees, bollards, carts, flags) to `MultiMeshInstance3D` where they don't need per-instance logic. (`Props/Streetlights` converted to `MultiMeshInstance3D` with collisions intact; static props [bollards, shopping carts, fire hydrants, street lamps] baked to single-mesh scenes; inactive tree and flag variants freed at runtime `_ready()`, saving nodes and memory).
- [x] Merge each car body's parts into one mesh per variant, using a few material slots instead of many child nodes. Section 4 does this as a build step, so the source scenes stay editable.

### 2b. Resolution and fill rate

`display/window/dpi/allow_hidpi` defaults to on, so Retina screens render at 2× (2940×1672 in the tests).

- [ ] Try a web-only `rendering/scaling_3d/scale.web` of 0.75, or 0.5 with FSR off, and compare frame time on a weaker device.
- [ ] Recheck `glow_enabled` under Compatibility, and cut it for web if it costs more than it adds. Shadows are covered in 5c.

## 3. Scene and CPU cost

### 3a. Hidden car variants

`cars/passenger_car.tscn` now contains only the shared collision and script nodes. It loads exactly one of six body scenes from `cars/bodies/`; no hidden body trees are instantiated.

- [x] Split each body style into its own scene under `cars/bodies/`.
- [x] In `_apply_visual_type()`, instantiate only the chosen body under `Visuals`.
- [x] Keep `_get_node_for_type()` and `_apply_paint_material()` working against the single instanced body.
- [x] `_setup_wheels()` in `car.gd` now runs after the body is instantiated, so it adds `Spoke` and `Hub` only to the selected body's four wheels. Section 4 removes the runtime creation altogether.

Expected: total nodes go from about 7,000 to about 1,500.

### 3b. Find where the physics and logic time goes

The native physics step is about 3 ms. Turning individual scripts off gave noisy results, so it's still unknown whether the time goes to `traffic_manager.gd`, `car.gd`, or the physics server handling 21 car `Area3D`s.

- [ ] Run the main scene from the editor and use Debugger → Profiler (per-function script time) and Visual Profiler (CPU/GPU per render stage).
- [ ] Fix whatever tops the list. Likely candidates: per-tick `get_baked_length()` calls and per-car yielding checks in `_update_lot_cars`, or Area3D overlap monitoring that can be replaced with distance checks along the lane.

### 3c. Debug overlay

`traffic/traffic_debug.gd` creates `Label3D`s and does per-frame work only while it's visible (F3).

- [ ] Leave it as is, but consider stripping the node from release builds with `if not OS.is_debug_build(): queue_free()`.

## 4. Author granular, ship merged: bake meshes at export

Cars, buildings and props are built from many primitive `MeshInstance3D`s. `cars/passenger_car.tscn` alone has 112 `BoxMesh` and 2 `CylinderMesh` sub-resources and 16 `StandardMaterial3D`s. That's good for editing, since each part is a named node with an inspector-editable size, and bad for the renderer. Keep the granular scenes as the source of truth and have the build produce merged meshes.

Draw calls scale with surfaces (one per mesh × material pair), not with nodes. Merging a car's 37 parts into one mesh that still has 10 materials still costs 10 draw calls, multiplied again by every shadow pass. The bake has to collapse materials as well as nodes.

### 4a. What the bake does

- Group static `MeshInstance3D` descendants by material and combine each group into one `ArrayMesh` surface with `SurfaceTool.append_from(mesh, surface, transform)`, using each part's transform relative to the scene root.
- Collapse materials that differ only in color: write the albedo into vertex `COLOR` and share one material with `vertex_color_use_as_albedo = true`. Materials that differ in transparency, emission, or roughness/metallic stay as separate surfaces. A car should end up with about four surfaces: paint, opaque trim, glass and lights. That estimate hasn't been checked against the 16 actual materials.
- Keep the nodes that code addresses by name or changes at runtime:
  - `Wheel*`, which `car.gd:_update_wheels()` rotates. Bake tire, spoke and hub into one mesh per wheel instead of creating `Spoke` and `Hub` at runtime in `_setup_wheels()`.
  - The painted parts (`PAINTED_NODE_NAMES`). Bake them into a single `Paint` node so that `_apply_paint_material()` still sets `material_override` on one node.
  - Turn signals from `_create_signal_mesh()`, which blink by swapping `material_override`, and the `HeadlightL/R` and `TaillightL/R` nodes that `car.gd` looks up by name to place them. Keep those as `Marker3D`s, or bake their positions into metadata.
  - Anything with a script, a collision shape, an `Area3D` or an animation.
- Make merging opt-in, for example only children of a node in a `bake_merge` group. That's safer than guessing from node names.
- Turn off `cast_shadow` on parts too small or flat to matter (see 5c) before merging, because a merged surface casts all or nothing.

### 4b. Where the bake runs

|                  | Export plugin                                                                                                                                                                                        | Baked scenes committed to the repo                                                                                     |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| How              | `EditorExportPlugin._customize_scene(scene, path)` returns the merged tree at export time; enabled by returning `true` from `_begin_customize_scenes()`                                              | A `@tool` `EditorScript` (File → Run) writes `cars/baked/*.tscn` from `cars/src/*.tscn`                                |
| Source of truth  | One. Nothing generated lands in git                                                                                                                                                                  | Two. Baked files can go stale                                                                                          |
| Editor play (F5) | Runs the unmerged scenes, so the editor profiler doesn't show the gain                                                                                                                               | Runs the baked scenes, so the profiler shows the gain                                                                  |
| CI               | Nothing extra; `mise run export-web` already runs the editor's export path                                                                                                                           | Needs a staleness check: re-bake in a `/tmp` copy and diff                                                             |
| Pitfalls         | `_customize_scene()` only runs for scenes modified since the last export. Bump `_get_customization_configuration_hash()` whenever the bake logic changes. Bake bugs only show up in exported builds. | Baked scenes must be saved by Godot (`ResourceSaver.save`), never written by hand, so that UIDs are assigned correctly |

Recommended: the export plugin, with the merge logic in one static function (`MeshBaker.bake(root: Node3D) -> Node3D`). `_customize_scene()` calls it; return `null` for scenes it leaves alone. A debug-only project setting such as `debug/bake_preview` can also call it from `_ready()`, so editor runs and profiling match the build through the same code path.

- [x] Do 3a first, so each body scene is a single unit to bake.
- [x] Write `addons/mesh_baker/` with `plugin.cfg`, `plugin.gd` (`EditorPlugin` calling `add_export_plugin()`), `export_plugin.gd` and `mesh_baker.gd`.
- [x] Enable it in the export pipeline (`mise.toml` and `.github/workflows/deploy-web.yml` auto-enable it during export; can also be toggled in GUI editor under Project Settings → Plugins).
- [x] Check it headless against a `/tmp` copy: instance `passenger_car.tscn`, bake it, print the surface count before and after.
- [x] Extend it to buildings and props. They have no per-part logic, so they can usually go down to one mesh per building or prop. (Buildings, static props [bollard, shopping cart, fire hydrant, street lamp], and main scene road/parking scenery baked at export via `export_plugin.gd`).

Verify: cars paint, signal, and spin wheels (verified on exported `.scn` artifacts). Confirm WebGL draw calls drop in browser monitor (`Raster > Total Draw Calls` under WebGL).

Alternative: build models in Blender and import them as `.glb`, with an `EditorScenePostImport` script doing the merge. That brings automatic mesh LOD and a real modeling tool, but it means re-authoring every asset that is currently built by hand in `.tscn`. Not worth it at this scale.

### 4c. Other development vs. release splits

- Feature-tag overrides on project settings (`setting.web`, `setting.mobile`, `setting.pc`, `setting.debug`, `setting.release`) tune one value per target without code. Custom tags (e.g. `lowspec`) go in a preset's `custom_features`.
- Code paths: `OS.has_feature("web")`, `OS.is_debug_build()`, `OS.has_feature("editor")`. `assert()` calls are stripped from release builds, so expensive invariant checks can go there.
- Keep dev-only content out of the pck with `exclude_filter`, as is already done for `samples/*`. Add test scenes and tool scripts to it as they appear.

## 5. Other common optimizations

### 5a. Web: download and startup

- [ ] Custom export template. The 39.5 MB `index.wasm` is the stock engine. Project → Tools → Engine Compilation Configuration Editor detects the classes the project uses and saves a `.gdbuild` profile. Then build with `scons platform=web target=template_release build_profile=<file> optimize=size_extra module_text_server_adv_enabled=no module_text_server_fb_enabled=yes` and point `custom_template/release` in the preset at the result. The fallback text server is enough for Latin-only UI. Cost: an Emscripten build in CI, cached by Godot version plus profile hash. The detector can be too aggressive with classes created only from code, so smoke-test every scene afterwards.
- Compression: GitHub Pages gzips on the fly but doesn't serve precompressed Brotli. If the game moves to itch.io or GitLab Pages, which don't compress on the fly, precompress the files.
- VRAM compression for mobile browsers: the preset has `vram_texture_compression/for_mobile=false`. No exported texture is imported as VRAM Compressed, so this doesn't matter today. If one is added, also turn on `rendering/textures/vram_compression/import_etc2_astc` and `for_mobile=true`, because mobile GPUs don't support the desktop S3TC/BPTC formats.
- Loading: `main.tscn` loads in one go behind Godot's default progress bar. A small boot scene with its own loading UI is also the natural place for the shader warm-up in 5b. With `thread_support=false`, threaded resource loading can't run on a background thread, so load in steps rather than counting on it.

### 5b. Web: frame spikes and shader compilation

The 38–96 ms spikes in the baseline fit first-use shader compilation: ANGLE translates and links each new shader variant on its first draw. The trace hasn't confirmed this yet.

- [ ] Confirm it: in a DevTools trace, check whether the long tasks are inside GL program compile/link calls.
- [ ] Warm-up: behind a loading overlay, draw every mesh/material combination once (each car body with paint, both signal materials, blood splat, flag, character editor) for one frame, then hide them.
- [ ] Fewer distinct materials means fewer shader variants, and 4a already cuts them. Materials that differ only in parameters share a shader, while turning on a feature (emission, transparency, vertex color) creates a new variant.
- [ ] `passenger_car.gd` creates a new paint `StandardMaterial3D` for every car. Cache one per `PAINT_PALETTE` entry in a static dictionary, so 21 cars share a handful of materials.

### 5c. Shadows (web and desktop)

No scene sets `cast_shadow`, so every mesh, down to lot striping and wheel hubs, is drawn again into the sun's shadow map.

- [ ] Set `cast_shadow = SHADOW_CASTING_SETTING_OFF` on flat ground pieces (road markings, lot striping, sidewalk tops), small details (hubs, spokes, signals, logos) and anything inside a larger caster.
- [ ] The sun uses the default PSSM 4-split mode with `directional_shadow_max_distance = 80`, so a caster can be drawn up to four times. The camera follows from a fixed height (16.5 m, 54° FOV), so try 2 splits or orthogonal mode and a max distance that fits what the camera can actually see.
- [ ] Web overrides: `rendering/lights_and_shadows/directional_shadow/size.web` at 2048 (default 4096) and a lower `soft_shadow_filter_quality.web`.

### 5d. Culling and LOD

- Visibility ranges: set `visibility_range_end` on small details (signs, `Label3D`s, flags, wheel spokes). The fixed camera height limits how much this saves, so measure before rolling it out.
- Automatic mesh LOD only applies to imported meshes (glTF and similar), not to `BoxMesh` primitives. Low-poly boxes have nothing to simplify anyway.
- Occlusion culling: `OccluderInstance3D` works on the web, since the raycast module builds for `wasm32`. But it rasterizes occluders on the CPU, which costs main-thread time in a single-threaded build, and a high camera looking down sees most of the scene. Skip it unless profiling shows heavy overdraw behind buildings.

### 5e. CPU: physics and scripts

- [ ] Physics tick rate: set `physics/common/physics_ticks_per_second.web = 30` and turn on `physics/common/physics_interpolation`. That halves the physics and traffic-logic cost per second. It requires moving objects only in `_physics_process`, scaling everything by `delta` rather than assuming 60 Hz, and calling `reset_physics_interpolation()` after teleports and spawns. Two follow-ups:
  - `follow_camera.gd` moves the camera in `_physics_process`. With interpolation on, it will stutter against the smoothed cars, so move it to `_process` and follow the target's `get_global_transform_interpolated()`.
  - At 30 Hz a car moves twice as far per step, so car-vs-player `Area3D` hits can be skipped. Retest the hits, and enlarge the shapes or sweep along the lane if needed.
- [ ] Lower `physics/common/max_physics_steps_per_frame` (default 8) for web, to about 3. On a slow device a long frame otherwise triggers several catch-up physics steps, which makes the next frame longer too.
- [ ] Physics engine: a headless check prints `physics/3d/physics_engine` = `DEFAULT`, which is Godot Physics. Jolt is only written into new projects. Try `Jolt Physics`, which is usually faster with many bodies and areas, then retest car `Area3D` overlaps and player collisions.
- [ ] Areas: set `monitorable = false` on areas nothing queries, and narrow collision layers and masks so cars don't test against scenery.
- [ ] `us_flag.gd` runs `_process` for every flag. Move the wave into a vertex shader driven by `TIME`, or stop processing when the flag is off-screen (`VisibleOnScreenNotifier3D`). (Partially done: wave is in `shaders/us_flag.gdshader`, but `_process` still runs for wind orientation without off-screen culling).
- Hot loops (`traffic_manager.gd`, `car.gd`): cache node lookups and curve lengths, and avoid allocating Arrays or Dictionaries every tick.

### 5f. Desktop

- Desktop exports use Forward+, as `project.godot` says, while web uses Compatibility. That means two looks and two performance profiles to test. The environment only uses glow and ACES tonemapping (no SSAO, SSR, SDFGI or volumetric fog), so Forward+ adds little here. Switching the whole project to Compatibility would make the editor, desktop and web match. Keep Forward+ only if desktop-only effects are planned.
- On Forward+ (4.4+), ubershaders and the pipeline cache mostly remove desktop shader-compile stutter. The warm-up in 5b is still cheap insurance.
- Laptops: consider `application/run/max_fps = 60` (or V-Sync with a 60 Hz cap) so 120 Hz displays don't burn battery on a game designed for 60.

## Order of work

1. Deploy (1).
2. Add draw-call and frame-time readouts to the F3 overlay (see "How to measure"), so later steps can be measured in the browser.
3. Cheap settings: `cast_shadow` and sun splits (5c), web physics tick and step cap (5e), paint material cache (5b).
4. Profile in the editor (2a count, 3b), then do the car body split (3a).
5. Mesh bake export plugin (4), cars first, then buildings and props.
6. Shader warm-up (5b) if the trace confirms that the spikes are shader compiles.
7. Web-only resolution scale (2b) if weaker devices still drop below 30 fps.
8. Custom export template (5a) once the feature set has settled.
9. Decide whether to use one renderer for everything (5f).

## How to measure

- Export: `mise run export-web` (exports from a copy in `/tmp`; the open editor's `.godot/` is untouched).
- Serve: `python3 -m http.server -d build/web 8000`, then open `http://localhost:8000`.
- Frame time: in DevTools, record a Performance trace for 10 s while idle and again while walking. Compare the main-thread time per frame and the GPU track against the baseline table above.
- Test on at least one non-Apple-Silicon laptop and one phone. The M2 numbers are a best case.
- In exported builds: the editor monitors don't exist and headless reports 0, so print `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` in the F3 overlay (`traffic/traffic_debug.gd`). Check in the browser that the render monitors return real values before relying on them.
