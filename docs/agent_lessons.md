# Agent Lessons Learned

Lessons and anti-patterns identified during codebase exploration, scene graph audits, and Godot 4 headless testing.

---

## 1. Auditing Scene Graphs: Programmatic vs Text-Grepping

- **Anti-pattern**: Grepping across dozens of `.tscn` files or reading scenes line-by-line to manually trace hierarchies (e.g. checking whether a `MeshInstance3D` has an associated `StaticBody3D` and `CollisionShape3D`). This burns tool calls, yields truncated text output, and misses inherited scene hierarchies.
- **Pattern**: Write a 15-line throwaway audit script in `/tmp/audit.gd` that loads `main.tscn` (or specific sub-scenes) and recursively traverses nodes to report discrepancies. Run it once with `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s /tmp/audit.gd`.

---

## 2. Godot 4 Headless Scripting Quirks

When running throwaway scripts via `-s /tmp/script.gd`:

- **`SceneTree._process(delta) -> bool`**: In Godot 4, overriding `_process` in a `SceneTree` script requires an explicit `bool` return type. Returning `false` keeps running; returning `true` quits. Omitting the return or returning `null` causes a script parse error.
- **`--quit` terminates immediately**: Running `<godot> --headless --path . --quit -- <args>` kills the engine on frame 1 before physics or multi-frame tests can step. Multi-frame scripts should omit `--quit` and call `quit(code)` explicitly upon completion.
- **Physics Space Requirements**: Calling `move_and_slide()` or `test_move()` in `_init()` fails with `body->get_space() is null` because nodes must be attached to an active scene tree inside the physics server. Use `change_scene_to_file("res://main.tscn")` or attach to `root` and wait for physics frames.
- **Project Test Runner**: `main.gd` reads user arguments via `OS.get_cmdline_user_args()`. Pass test flags after `--` (e.g. `<godot> --headless --path . -- --test-mats-blocker`) to execute built-in scenario tests cleanly.

---

## 3. Pairing Collision Shapes to Visual Meshes

- **Extract exact dimensions from sibling mesh resources**: When matching a `BoxShape3D` or `CylinderShape3D` to a `BoxMesh` or `CylinderMesh`, never approximate from memory or perspective screenshots. Read the mesh sub-resource in the same `.tscn` file:
  - `BoxMesh.size` $\rightarrow$ `BoxShape3D.size`
  - `CylinderMesh.bottom_radius` / `height` $\rightarrow$ `CylinderShape3D.radius` / `height`
- **Inspect multi-column / multi-post structures**: For assets like roadside pylon signs with left and right uprights (`PoleL` / `PoleR`):
  - Do not place a single collider at the root center, which leaves the actual poles uncollided while placing an invisible barrier in the empty air between them.
  - Create separate collision shapes anchored to the specific column offsets.
- **Check enclosure and perimeter walls**: Compound assemblies (like dumpster corrals or drive-thru lanes) often place collision only on the concrete floor pad while leaving the enclosing side and back walls intangible. Check every boundary mesh.

---

## 4. File I/O and Formatting Rules

- **Scratch files go to `/tmp`**: Never create temporary `.gd`, `.tscn`, or test output files inside the repository; Godot scans and creates `.uid` import artifacts for any file under `res://`.
- **Run `mise run fmt`**: Automatically formats GDScript (`gdformat`) and documentation markdown (`oxfmt`).
