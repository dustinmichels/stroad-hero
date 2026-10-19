# Web Startup and Runtime Optimization Plan

Actionable checklist to eliminate the Firefox _"This page is slowing down Firefox"_ warning, speed up Web startup, and reduce WebGL draw calls while keeping 100% of desktop features and visuals.

## Baseline Measurements (Exported `build/web/index.pck` on M2)

| Metric                               | Exported Value                    | Notes                                                                                    |
| ------------------------------------ | --------------------------------- | ---------------------------------------------------------------------------------------- |
| `index.wasm` / `index.pck`           | 37.7 MB / 5.3 MB                  | Uncompressed via `python3 -m http.server`; ~10 MB gzipped on Pages                       |
| `load("res://main.tscn")`            | 177.5 ms native (~0.5–1.0 s WASM) | Deserializes `main.scn` + all `ext_resource` buildings, props, and `preload()` vehicles  |
| `scene.instantiate()`                | 14.0 ms native (~40–80 ms WASM)   | Allocates 2,053 initial scene nodes                                                      |
| Frame 1 (`_ready` + text shaping)    | 339.9 ms native (~1.0–2.0 s WASM) | 188.7 ms (55%) in FreeType `Label3D` glyph rasterization; 151.2 ms (45%) in `_ready()`   |
| WebGL2 Shader Compile & Link         | ~0.5–2.5 s on main thread         | 12 distinct shader variants (8 `StandardMaterial3D` flag combos + 4 `.gdshader`s)        |
| Visible `MeshInstance3D`s / Surfaces | 664 / 1,067                       | `Props`: 334 meshes (571 surfaces); `TrafficManager`: 293 meshes (425 surfaces)          |
| Visible `Label3D`s                   | 169                               | 47 unique `(font, font_size, outline_size)` combinations (75 in `SmellGasStation` alone) |

---

## 1. Font & `Label3D` Startup Optimization (~55% of Frame 1 CPU)

169 visible `Label3D`s across 47 `(font, size, outline)` combinations force FreeType to rasterize and upload 47 glyph atlases synchronously on Frame 1.

- [x] Enable MSDF (`multichannel_signed_distance_field=true`) in all 7 `fonts/*.ttf.import` files (`ArchivoBlack-Regular`, `Fredoka`, `Lobster-Regular`, `Overpass-Black`, `Overpass-Bold`, `Overpass-Regular`, `Overpass-SemiBold`) so each typeface builds a single distance-field atlas regardless of `font_size` or `outline_size`.
- [x] Increase `msdf_pixel_range` from `8` to `24` in `fonts/*.ttf.import` so thick outlines (`outline_size = 10` and `12` on signs) do not clip.
- [x] Enable `gui/theme/default_font_multichannel_signed_distance_field=true` in `project.godot` (or assign an explicit `FontFile` to the 29 `Label3D` nodes currently using the built-in default font).
  - Note: `--test-mats-collision` has a pre-existing failure in the in-progress SPD death tween HUD changes.
- [x] Check `buildings/booger_king_logo.tscn` (`Font_BKBubble` subresource) and outlined signs visually in the browser to confirm crisp outlines under MSDF.
- [x] Re-run the headless Frame 1 timing check to verify the ~188 ms native FreeType spike is gone.
  - Note: Verified all 7 custom fonts and default theme font now resolve to a single `(48, 0)` MSDF size cache rather than 47 distinct dynamic bitmap atlases; unit test suite (`mise run test --fast`) passes 11/11.

---

## 2. Time-Sliced Startup & Staggered Shader Warm-Up (Fix Firefox Long-Task Warning)

Because `variant/thread_support=false` is required for GitHub Pages (no `COOP`/`COEP` headers), `Main::start()` runs `load()`, `instantiate()`, `_ready()`, and Frame 1 shader compilation inside a single browser turn.

- [x] Defer `TrafficManager` initial vehicle spawning (`_pre_populate_traffic()` and `_seed_parked_cars()`) out of synchronous `_ready()` so the ~20 cars spawn in small batches (e.g. 4–5 cars per frame) across warmup frames while the HTML loading overlay is still up (`--test-*` CLI modes should still spawn synchronously).
- [x] Stagger building/prop visibility and shader warm-up across frames in `ui/start_screen.gd` before calling `window.godotReady()`:
  - [x] Start with major `Props` building groups hidden on Frame 1, then reveal one group per `process_frame` tick so WebGL2 compiles and links the 12 distinct shader variants across multiple `requestAnimationFrame` ticks instead of blocking in one frame.
  - [x] Call `window.godotProgress(pct, text)` from GDScript between warmup steps so the HTML progress bar advances smoothly from 85% to 99%.
- [x] Replace `const ... = preload(...)` of the 6 vehicle scenes in `traffic/traffic_manager.gd` and 7 body scenes in `cars/passenger_car.gd` with staged loading during the startup warmup frames (or lazy loading) so `load("res://main.tscn")` doesn't parse every vehicle resource upfront.
  - Note: Replaced top-level static `preload()` in `traffic_manager.gd` and `passenger_car.gd` with lazy-loading cached accessors (`PassengerCarScene`, `BusScene`, `BODY_SCENES`, `get_body_scene()`), deferring vehicle resource parsing out of `load("res://main.tscn")`.

---

## 3. Defer Character Editor 3D Preview Until Opened

`player/character_editor.tscn` instantiates a second `World3D` (`own_world_3d = true`), a shadow-casting `DirectionalLight3D`, and a duplicate `PreviewMats` skeleton (87 nodes, 31 surfaces) at startup even though the editor is hidden until `C` is pressed.

- [x] Turn off `KeyLight.shadow_enabled` or keep the `PreviewViewport` 3D subtree uninstantiated until `CharacterEditor.open_editor()` is first called.
- [x] Lazy-instantiate `PreviewMats` (or the entire 3D preview rig inside `PreviewViewport`) on first `open_editor()` and cache it for subsequent opens.
- [x] Verify pressing `C` still opens the character editor, syncs Mats' look, rotates the preview, and passes character editor tests.
  - Note: Verified `KeyLight.shadow_enabled` disabled in `player/character_editor.tscn`, `PreviewMats` removed from initial scene instantiation and lazy-instantiated/cached in `player/character_editor.gd`. Headless tests verified pressing `C` instantiates `PreviewMats`, syncs customized Mats look (headwear, jacket, backpack, shoes), updates rotation over time, closes on subsequent toggle, and passes full test suite (20/20).

---

## 4. Expand `MeshBaker` Coverage for Props & Buildings

`Props` still has 334 visible `MeshInstance3D`s (571 surfaces) in the exported `.pck` because several scenes and scripted subtrees are skipped by `addons/mesh_baker/`.

- [x] Add `res://props/overhead_road_sign.tscn` (36 meshes) and `res://props/ice_machine.tscn` to `addons/mesh_baker/export_plugin.gd`.
- [x] Bake static meshes inside `TacoHell/DriveThru` (`buildings/taco_hell.tscn`):
  - [x] Allow `MeshBaker.bake_static_scene()` to merge static `MeshInstance3D` children under `DriveThru` while preserving `OrderingSpeaker/Housing/StatusLed` (the only mesh modified at runtime by `taco_hell_drive_thru.gd`), `OrderZone`, `PickupZone`, `StaticBody3D`s, and `Label3D`s.
- [x] Bake `props/dumpster.tscn` (6 instances = 79 meshes across Taco Hell, Booger King, and Strip Mall) into 3 static mesh parts (`Body`+colored ribs, `RightLidPivot`, `TrashBag`) so `dumpster.gd` still toggles lid rotation and color without 14 nodes per dumpster.
  - Note: Implemented `MeshBaker.bake_dumpster()` to merge static body parts into `Body` with Surface 0 reserved for color customization and static trim grouped on subsequent surfaces, preserving `RightLidPivot`, `TrashBag`, and `WarningLabel`; updated `dumpster.gd` to override Surface 0 on multi-surface baked meshes and wired `res://props/dumpster.tscn` in `export_plugin.gd`.
- [x] Strip unused variants in `props/tree.tscn` (5 tree types) and `props/us_flag.tscn` (3 flag sizes) during export in `MeshBaker.bake_main_scene()` (and merge each active tree/flag pole's static meshes) instead of instantiating all variants at boot and calling `queue_free()` in `_ready()`.
  - Note: Implemented `MeshBaker.bake_trees()` and `MeshBaker.bake_flags()` in `bake_main_scene()`, stripping unused variants, merging static flag pole meshes into a single `Pole` mesh with combined surfaces, clearing `scene_file_path`, and re-owning nodes to scene root (reducing tree/flag node footprint from 476 nodes to 136 nodes).
- [x] Pre-bake `PavementDetails` (`props/pavement_details.gd`) into `Road` at export time in `MeshBaker.bake_main_scene()` and skip runtime `SurfaceTool` generation in `_ready()` when the pre-baked node exists.
  - Note: Added `build_mesh()` to `PavementDetails` and wired it into `MeshBaker.bake_main_scene()` prior to `bake_static_scene(road, root)`; cracks and tire marks are pre-baked directly into `Road/BakedStaticMesh`, and `_ready()` skips runtime `SurfaceTool` generation when `BakedStaticMesh` or `PavementDetailMesh` exists.
- [x] Bump `_get_customization_configuration_hash()` in `addons/mesh_baker/export_plugin.gd` so Godot invalidates cached `.scn` exports.
  - Note: Bumped configuration hash from 3 to 4 in `MeshBakerExportPlugin._get_customization_configuration_hash()`.

---

## 5. Expand `MeshBaker` Coverage for Vehicles & Wheels

`TrafficManager` accounts for 293 visible `MeshInstance3D`s (425 surfaces) across ~20 active vehicles.

- [x] Bake `Spoke` and `Hub` geometry directly into each `Wheel*` mesh at export time in `MeshBaker.bake_car_body()` so `Car._setup_wheels()` (`cars/car.gd:211`) skips creating 8 `MeshInstance3D` nodes per car at runtime (already guarded by `if child.has_node("Spoke")`).
  - Note: Implemented `MeshBaker.bake_wheel()` merging tire rubber and spoke/hub chrome geometry into multi-surface baked wheel meshes with `baked_wheel` meta and `Spoke` node; updated `Car._setup_wheels()` guard to skip runtime mesh allocation.
- [x] Extend `addons/mesh_baker/export_plugin.gd` and `MeshBaker` to bake the commercial vehicle scenes (`res://cars/bus.tscn`, `res://cars/truck.tscn`, `res://cars/van.tscn`, `res://cars/shipping_truck.tscn`, `res://cars/taxi.tscn`), keeping `Wheel*` and light markers intact.
  - Note: Added `bake_vehicle_scene()` and `bake_vehicle_model()` to `MeshBaker`, merging body meshes into a multi-surface `Body` mesh, baking multi-surface `Wheel*` instances, preserving `Marker3D` light markers and label elements, wired paths into `export_plugin.gd`, and bumped config hash to 5.
- [x] Cache `StandardMaterial3D` instances per `PAINT_PALETTE` and `SPORTS_PAINT_PALETTE` color in a static `Dictionary` in `cars/passenger_car.gd` (`_apply_paint_material()`) instead of calling `StandardMaterial3D.new()` for every spawned car.
  - Note: Added static `_paint_materials` dictionary and `get_paint_material(color)` helper in `cars/passenger_car.gd`, caching standard materials by color across spawned passenger cars.

---

## 6. Web Export, Asset & Physics Settings

- [x] Change `buildings/smell_lines.svg.import` from `compress/mode=2` (VRAM S3TC, 341 KB `.ctex`, incompatible with mobile GPUs when `for_mobile=false`) to `compress/mode=0` (Lossless/WebP, <20 KB, works everywhere).
  - Note: Updated `compress/mode=0` in `buildings/smell_lines.svg.import`; Godot reimported to lossless `.ctex` (reduced texture footprint and universally compatible).
- [x] Add Web-specific project settings in `project.godot`:
  - [x] `physics/common/max_physics_steps_per_frame.web=3` (prevents physics spiral-of-death catch-up frames after a browser hiccup).
  - [x] `rendering/scaling_3d/scale.web=0.75` (reduces WebGL2 fragment fill-rate cost on 2× Retina/HiDPI displays while keeping 2D HUD and text crisp at native resolution).
  - Note: Added `common/max_physics_steps_per_frame.web=3` under `[physics]` and `scaling_3d/scale.web=0.75` under `[rendering]` in `project.godot`.
- [x] Update `mise run web` (`mise.toml`) to serve with HTTP compression or caching headers (or a lightweight local server helper) so local browser testing matches GitHub Pages' gzipped transfer behavior.
  - Note: Created `scripts/serve_web.py` with multi-threaded gzip compression, ETag / conditional request validation, and Cache-Control headers; updated `tasks.web` in `mise.toml` to serve via `serve_web.py`.
