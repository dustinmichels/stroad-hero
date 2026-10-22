# Web Optimization Plan

Goal: make the Web export load without Firefox's "This page is slowing down Firefox" warning and play without heavy lag. If that fails, ship a cut-down web demo (see §7).

Prior work and measurements: `docs/optimizations.md`. This plan covers what remains.

Items marked **`[HUMAN REVIEW NEEDED]`** need a design decision.

---

## 0. Current State (Oct 21, 2026)

| Fact                                   | Value                                                          | Source                                                   |
| -------------------------------------- | -------------------------------------------------------------- | -------------------------------------------------------- |
| Download size                          | `index.wasm` 18.6 MB + `index.pck` 26.1 MB                     | `build/web/`                                             |
| Threading                              | Single-threaded (`threads=no`, `variant/thread_support=false`) | `scripts/build_custom_template.sh`, `export_presets.cfg` |
| Main scene, authored                   | 4,484 nodes, 3,076 `MeshInstance3D`, 236 `Label3D`, 33 lights  | headless count of `main.tscn`                            |
| Main scene, after export bake          | 2,618 nodes, 1,228 `MeshInstance3D`                            | `MeshBaker.bake_main_scene` headless count               |
| Native load + instantiate (desktop)    | ~0.5 s                                                         | headless count script                                    |
| Web "Engine started" → "Godot ready"   | 12.5 s → 28.4 s (~16 s)                                        | `mise run smoke-web` (SwiftShader, inflated)             |
| Compatibility frame time (desktop, M2) | Day 22.4 ms, Night 32.3 ms                                     | `docs/optimizations.md` §1                               |

Largest remaining baked groups:

| `Props/` group    | Meshes after bake | Notes                                  |
| ----------------- | ----------------- | -------------------------------------- |
| `Dorf`            | 356               | Not covered by `MeshBakerExportPlugin` |
| `SmellGasStation` | 248               | Not covered                            |
| `Powerlines`      | 176               | Not baked at all (same count pre/post) |
| `BoogerKingSite`  | 91                | Partially baked                        |
| `StripMall`       | 77                |                                        |
| `CrampedInn`      | 73                |                                        |

Why Firefox warns: the build is single-threaded, so resource loading, scene instantiation, `_ready()` setup (forest, traffic spawn), and WebGL shader compilation all run on the browser main thread with no yield.

---

## 1. Fix Broken Web Features (blocking)

- [ ] **Police siren and text fail on web**
  - `cars/police_siren.gd` fails to parse on web: `AudioStreamPlayer3D` and `AudioStreamWAV` are stripped by `web.gdbuild`.
  - `cars/bodies/police_suv.tscn` uses `TextMesh`, also stripped.
  - [ ] [HUMAN REVIEW NEEDED] Fix choice:
    - Option A: Re-enable the classes in `web.gdbuild` and rebuild `templates/web_release.zip` (larger wasm, siren works).
    - Option B: Skip siren audio on web and have `MeshBaker` convert `TextMesh` to `ArrayMesh` at export (no template rebuild).
- [ ] **Guard against future class stripping**
  - Add a check (test or export step) that fails when project scripts or scenes reference a class in `web.gdbuild` `disabled_classes`.
- [ ] **`!is_inside_tree()` `get_global_transform` errors on web**
  - At least 15 at startup in the web console; not reproducible on desktop with `--bake --force-web-shadows`.
  - Likely an export-only path (car body / vehicle bake in `addons/mesh_baker/export_plugin.gd`) — unconfirmed.
  - [ ] Export a debug web build (official debug template has all classes and GDScript backtraces) to find the caller.

---

## 2. Measurement That Can Be Trusted

- [ ] **Smoke check must fail on script errors**
  - `scripts/smoke_check_web.js` `checkTextForErrors` only matches resource-load and 404 errors. Add `SCRIPT ERROR` and `Failed to load script`.
- [ ] **Real-GPU smoke mode**
  - The smoke check forces `--use-angle=swiftshader` (software WebGL). Its fps numbers are not usable. Add a flag to drop the SwiftShader args when a GPU is available.
- [ ] **Baseline before each change**
  - Desktop proxy: `mise run bench -- --bench-gameplay-compat` (day/dusk/night frame time, draw calls).
  - Real target: `mise run web`, open in Firefox, record load time to playable and fps day/night.
  - Record results in `docs/optimizations.md`.

---

## 3. Render Cost

Ordered by expected payoff per effort.

- [ ] **Web shadows**
  - The directional shadow pass re-submits every caster. `EnvironmentController.apply_web_shadow_overrides()` already uses 1 split at 45 m.
  - [ ] [HUMAN REVIEW NEEDED] Option A: disable sun shadows on web entirely. Option B: keep shadows only on Mats and moving cars (set `cast_shadow = OFF` on static world at export).
- [ ] **Extend export baking**
  - Add `Dorf`, `SmellGasStation`, `Powerlines`, `BoogerKingSite` to `MeshBakerExportPlugin._customize_scene` (or bake all static `Props/` children in `bake_main_scene`).
  - Target: 1,228 → ~600 baked meshes.
  - Keep collision bodies and anything scripts move or look up by path (dumpster lids, shopping carts, flags, signs with dynamic text).
- [ ] **Night lights**
  - 33 scene lights plus up to 12 headlamp `SpotLight3D` (`MAX_ACTIVE_HEADLAMPS`). Compatibility shades every light per object up to `max_lights_per_object = 8`.
  - On web: replace streetlight and billboard lights with emissive/unshaded fake light pools; lower `MAX_ACTIVE_HEADLAMPS`.
- [ ] **Label3D (low priority)**
  - All 236 labels already cull at 35–120 m with self-fade (`docs/optimizations.md` §3.6), so only nearby ones draw.
  - Only act if the compat bench shows labels are a significant share of draw calls; then bake static sign text into textured quads at export.

---

## 4. Load Time and the Firefox Hang Warning

- [ ] **Profile the startup in Firefox**
  - Use the Firefox profiler on `mise run web` to split time between wasm compile, pck load, scene instantiate, `_ready()` work, and shader compile.
- [ ] **Yield during startup**
  - Load a lightweight core scene first, then instantiate heavy `Props/` groups one per frame behind the loading screen (extends the staggering already in `world/world_warmup.gd`).
- [ ] **Shrink the pck**
  - Switch the Web preset from `export_filter="all_resources"` to `"scenes"` with only the main scene selected, so only its dependency closure ships.
  - Catch: paths loaded by string at runtime (`load("res://…")`, paths in `objectives/mats_objectives.json`, car bodies) are not tracked. Grep for `load(` and list them in `include_filter`.
- [ ] [HUMAN REVIEW NEEDED] **Threaded web build**
  - Moves resource loading off the main thread. Requires COOP/COEP headers; GitHub Pages needs a service-worker workaround (e.g. coi-serviceworker). Consider only if §4 yielding is not enough.

---

## 5. CPU Cost

- [ ] Re-run `--profile-traffic` under the compat bench and check `TrafficManager` script time per frame at web physics rate (30 ticks).
- [ ] **Spawn/despawn hitches**
  - `TrafficManager` calls `instantiate()` on every spawn and `Car.despawn()` calls `queue_free()`; each car brings a body scene with many meshes.
  - Check the Firefox profile for frame spikes at spawn. If present, pool cars per scene type and reset them in `setup()` instead of freeing.
- [ ] [HUMAN REVIEW NEEDED] Lower web traffic density if CPU-bound.

---

## 6. Acceptance

- [ ] No `SCRIPT ERROR` or engine errors in the web console during startup and 5 minutes of play.
- [ ] Firefox shows no "slowing down" warning on load.
- [ ] Firefox on the target machine: [HUMAN REVIEW NEEDED] set fps target (e.g. ≥30 fps night) and load-to-playable target.

---

## 7. Fallback: Web Demo

If §1–§5 do not reach §6, ship a reduced web demo that ends with a download prompt.

- [ ] **Split the world**
  - `main.tscn` keeps the road, Mats, HUD, traffic, and 1–2 stores (e.g. Walgroins + Taco Hell).
  - Move remaining businesses into `world_extras.tscn`, added by `main.gd` unless the `demo` feature is active.
  - Godot cannot delete nodes from inherited scenes, so a split is preferred over an inherited `demo.tscn`; a duplicated scene drifts.
  - `TrafficManager` errands and `ObjectiveManager` objectives must skip destinations that are not present.
- [ ] **Demo feature tag**
  - Web preset `custom_features="demo"`; `OS.has_feature("demo")` plus a `--demo` CLI flag for desktop testing.
- [ ] **Single evening**
  - Start at 18.5 (evening) or 19.5 (night); slow `time_scale` (18.5→20.0 is 90 s at 1.0).
  - Hide `ui/time_of_day_toggle.gd`; disable `godotSetTimeHours`.
  - Note: night is the most expensive web scenario (Compatibility night 32.3 ms vs day 22.4 ms).
- [ ] **End of demo**
  - `GameState.day_ended` already fires at `END_HOUR` and the HUD's `DaySummary` pauses the tree; hook the demo end there.
  - Pause the tree and call `window.godotDemoEnded()`; show a real `<a href>` download link in `web/custom_web_template.html` (avoids popup blocking of `OS.shell_open`).
- [ ] [HUMAN REVIEW NEEDED] Stores kept, demo length, download URL.
