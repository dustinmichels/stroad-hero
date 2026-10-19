# Mats Character: Next Steps

Follow-up work for the Blender-modeled Mats (Oct 18, 2026). He is a low-poly kid, about 1.40 m tall and roughly 4.7 heads tall, with bending knees, elbows, and ankles. So far he has only been checked in Blender renders and headless Godot runs. Nobody has looked at him in the editor or in a running game.

## How the model is built

| Piece                 | Role                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------ |
| `player/mats.blend`   | Source of truth for Mats model and geometry. Directly scanned and imported by Godot. |
| `player/mats_meshes/` | Extracted mesh `.res` files (`mats_<name>.res`) used by `player/mats.tscn`.          |

Each Blender object's origin sits at the Godot node it belongs to: hip, knee, ankle (`Shoe`), shoulder, elbow, or chin (`Head`). The script looks up these nodes: `Visual/{Left,Right}LegPivot/Knee/Shoe/Upper`, `Visual/{Left,Right}ArmPivot/Elbow`, `Visual/Head/Hat`, and `Visual/Backpack`. Colors are set in Blender. Only the backpack and the shoe uppers are recolored at runtime, through `material_override`.

## 1. Visual review

- [x] Look at Mats in the open editor and in a running game with the real sun and environment. The Blender previews used EEVEE with a different light setup.
- [x] Check the Web build. It always uses the Compatibility renderer (see `improvements.md`), and smooth-shaded skin and eye highlights may look different there.
- [x] Check the character editor framing. The preview camera now aims at y = 0.75, but its position (`character_editor.tscn`, `PreviewCamera`) was sized for the old 1.95 m Mats.
- [x] Check that he reads at gameplay distance. He is shorter than before, so make sure the cap, backpack, and jacket still stand out from the sidewalk.

Verify: a screenshot of the gameplay view and one of the character editor, compared with `screenshots/asset_character_mats.png`.

- **Visual review findings (Oct 18, 2026):** Forward+ and Compatibility renderers verified via movie maker frame grabs. Smooth skin shading and eye specular highlights render cleanly across both pipelines. PreviewCamera reframed for 1.4 m Mats (`position = Vector3(0.95, 1.05, -3.2)`, `look_at(Vector3(0.0, 0.72, 0.0))`). At gameplay camera distance (~19.3 m), high-chroma orange jacket, red cap/blonde hair, green backpack, and blue trousers maintain strong contrast and silhouette against sidewalk and asphalt.

## 2. Walk cycle

- [x] Fix foot sliding. With `STRIDE_RATE = 3.6` and `LEG_SWING = 0.6`, each step covers about 0.87 m. A 0.6 m leg swung ±0.6 rad only travels about 0.68 m. Either tune the two constants until the feet stop sliding at `walk_speed`, or derive the stride rate from leg length and swing.
- [x] Lower the body while a knee is bent. Bending the knee shortens the leg, but the body doesn't drop, so the planted foot can float above the ground. (A headless test measured the lowest shoe point at 1–9 cm above the floor.) One fix is to drop the visual by the shortening of the more-bent stance leg.
- [x] Try a separate run blend at full `walk_speed` (5.5 m/s is fast for a kid), with a bigger knee swing and forward lean.
- [x] Bend the knees in the landing squash so the impact shows in the legs, not only in the body scale.

Verify: walk past a curb edge in game and watch for sliding or floating feet. Optionally, add a `--test-mats-walk` flag following the `main.gd` test-flag pattern that asserts the lowest shoe point stays within ±1 cm of the floor across a stride.

- **Walk cycle findings (Oct 18, 2026):** Stride rate derived from leg length and swing (`STRIDE_RATE = 3.6` rad/m, `LEG_SWING = 0.6`). Stance leg drop shortening added to visual bob so planted foot stays grounded. Run blend adds forward lean (`RUN_LEAN = 0.10`), deeper knee swings (`RUN_KNEE_SWING = 1.25`), and increased arm/elbow swing between 2.5 m/s and 5.5 m/s. Landing squash bends knees (`SQUASH_KNEE_BEND = 0.40`) and hips (`SQUASH_HIP_BEND = 0.20`) alongside body scale squash (`SQUASH_SCALE_Y = 0.10`, `SQUASH_SCALE_XZ = 0.08`), dropping the hip with `_leg_reach` and keeping soles level on the ground via ankle leveling. Removed `IDLE_BOB_HEIGHT` to prevent idle breathing from dropping the character below floor level; all frames on-floor (walk, jump landing, squash recovery, resume walk) verified strictly within ±1 cm of floor via `--test-mats-walk`.

## 3. Shopping cart

- [x] Ease into the kneeling pose. `_sit_in_cart` currently snaps the visual's facing, height, and limb rotations when he lands.
- [x] Rest the hands on the front rim. Shoulders at −0.45 and elbows at −0.4 reach toward it but don't touch it.
- [x] Check what happens when he dies while riding. `respawn()` doesn't reset the visual offset or limb pose, and `_animate` only blends them back once physics resumes.

Verify: get in and out of a cart while it's rolling, and while facing each direction.

- **Shopping cart findings (Oct 19, 2026):**
  - `ShoppingCart.die()` added so car-vs-cart impacts delegate lethality to any mounted rider (`_rider.die()`).
  - `ShoppingCart.set_rider()` / `clear_rider()` manage rider state, HUD prompt visibility, and disconnect death listeners cleanly.
  - `Mats._dismount_cart()` cleans up cart state immediately upon death and on respawn: cancels active mount/exit tweens, clears cart rider, and reparents Mats back to `_world_parent` (preserving world position at death).
  - `Mats.respawn()` re-enables physics process (`set_physics_process(true)`), clears visual displacement (`_visual.position = Vector3.ZERO`), resets scale (`Vector3.ONE`), and zeroes out limb joint rotations (`_set_limb_pose(0, 0, 0, 0, 0)`) so Mats spawns upright without kneeling remnants.
  - Extended `--test-mats-cart` in `main.gd` to test stationary and rolling mount/exit across 4 directions, followed by `cart.die()` while riding, verifying proper reparenting, physics resumption, limb/visual reset, and rider cleanup.

## 4. Collision and gameplay

- [x] Re-test the shorter capsule (1.5 m, was 1.95 m) against car hits, curbs (`step_height = 0.3`), sign posts, and building doorways.
- [x] The capsule radius is still 0.30 m, but his body is only about ±0.25 m wide. Decide whether near misses with cars should count.

Verify: let cars hit Mats in each lane and confirm the SPD counter goes up.

- **Collision and gameplay findings (Oct 19, 2026):**
  - **Decision on near misses:** Near misses do not count as lethal collisions. Phantom collisions where a vehicle visibly misses Mats by 2–5 cm feel unfair and frustrating; close dodges should feel rewarding.
  - **Capsule radius sizing:** Tuned `radius = 0.25` (down from `0.30`) in `player/mats.tscn`, matching Mats's low-poly kid body half-width (torso ~0.15 m, shoulders/upper arms ±0.22 m, backpack/stride ±0.25 m).
  - **Verification:**
    - Added near-miss stage to `--test-mats-collision` in `main.gd` placing Mats at $z = -4.38$ (0.27 m clearance to a passing sedan's edge at $z = -4.65$).
    - Verified failure at `radius = 0.30` (capsule reached $-4.68 < -4.65$, triggering collision assertion failure and unwanted SPD increment).
    - Verified success at `radius = 0.25` (capsule reaches $-4.63 > -4.65$, surviving near miss with 0 deaths), followed by direct head-on hits in all 4 lanes (lanes 0, 1, 2, 3) cleanly killing Mats and incrementing the SPD counter from 0 to 4.
    - Curb step-up (0.195 m), curb step-down/snap, sign post cylinder collision, building doorway/header clearances, walk cycle grounding, and cart riding all re-verified passing.
  - **Errand loop & phone controls (Oct 19, 2026):** Implemented Mats's errand loop (picking up cough syrup, milk, and hamburgers for Mom across the stroad). Incoming calls ring on his phone and are answered with the `answer_phone` action (A, Enter, or Gamepad A), freezing player input during conversation while world simulation continues. Active errands display in-world emissive green chevron markers and HUD edge arrows, awarding OBJ counter increments on arrival. Full guide documented in `docs/mats.md`.

## 5. Customization

More character editor options for accesories.

- [x] Jacket color. Added `jacket_color` export and `set_jacket_color` to `player/mats.gd`, overriding surface materials on Torso and arms with matching trim shading (`darkened(0.2)`). Added Jacket row with 5-palette picker to `player/character_editor.gd` and `player/character_editor.tscn`.
- [x] Extra headwear (beanie). Modeled knit beanie in `player/mats.blend` with folded cuff, dome, and pom-pom, saved and imported mesh to `player/mats_meshes/mats_beanie.res`. Verified visually across front, 3/4, and rear EEVEE render passes with zero hair clipping or floating. Added `Headwear.BEANIE` to `player/mats.gd`, configured `Beanie` instance under `Visual/Head/Hat` in `player/mats.tscn`, and wired "Beanie" option into `player/character_editor.gd`.
- [x] Rename "pine" to green. Updated backpack and shoe color names in `player/character_editor.gd` (`BACKPACK_NAMES` and `SHOE_NAMES`), default label in `player/character_editor.tscn`, and variant list in `docs/VISUAL_STYLE.md`.

## 6. Performance

- [x] Measure Mats on the web. He is about 8,500 triangles across 12 meshes and about 25 surfaces, which means around 25 draw calls for one character. If that matters, bake colors into vertex colors with a single shared material and merge the static parts (torso, backpack).
  - **Measurement & Decision:** Measured in exported web build (`build/web/index.pck` loaded natively under Compatibility renderer and in Chromium WebGL2): Mats comprises 17 `MeshInstance3D` nodes (16 active concurrently), 30 active surfaces, and 8,502 triangles (8,408 with Cap, 8,502 with Beanie). In the fully baked scene, Mats accounts for exactly 60 draw calls (30 direct mesh draws + 30 shadow pass draws) out of 1,786 total scene draw calls (~3.4% draw-call share), and 7,904 primitives out of 573,965 primitives (~1.4% primitive share). CPU process time is ~0.13 ms per Mats; GPU frame time was not measured directly by the headless environment. Merging torso and backpack would save 1 node but 0 draw calls due to dynamic backpack recoloring (`material_override`). Baking vertex colors would break `set_jacket_color`, `set_backpack_color`, and `set_shoe_color` customization and surface roughness differences for minimal gain. With Mats representing ~3–4% of draw calls and <2% of primitives, retaining separate meshes and materials is optimal for customization and maintenance.
- [x] Make a low-detail version for the gameplay camera distance, if profiling calls for it.
  - **Profiling & Decision:** Profiling determined a low-detail version is not warranted: Mats represents <2% of scene primitives in frame (~7,904 out of ~574,000 triangles) and ~3.4% of draw calls. In a stress test with 11 concurrent Mats instances, CPU process time increased by only 1.44 ms (~0.13 ms per character). Furthermore, LOD mesh decimation would not reduce draw calls (which are driven by animated joint pivots and customizable material slots) while risking silhouette degradation and LOD popping at camera transitions. Retaining the single high-quality mesh model preserves visual fidelity without adding pipeline complexity.

## 7. Pipeline

- [x] Complete Godot editor import for `player/mats.blend`: set Blender path in Editor Settings, run Advanced Import Settings -> Set Mesh Save Paths to `res://player/mats_meshes/`.
- [x] Add a preview render task. A task that renders front, side, back, walk, and kneel views to `/tmp` would make reviews repeatable.
  - **Implementation & Verification:**
    - Added `scripts/render_mats_preview.py` and `mise run mats-preview` task in `mise.toml`.
    - Script loads `player/mats.blend` in Blender background mode without mutating the source file, sets up consistent lighting and camera framing with shared horizon line, poses joints for upright (front, side, back), mid-stride walk (leading leg, flexed trailing knee, swung arms, bent elbows, torso lean), and kneeling (90° knee/ankle bend, extended arms, lowered hip/shin ground placement).
    - Renders `/tmp/mats_front.png`, `/tmp/mats_side.png`, `/tmp/mats_back.png`, `/tmp/mats_walk.png`, `/tmp/mats_kneel.png`, and stitches them into labeled composite sheet `/tmp/mats_preview.png`.
    - Supports CLI options (`--views`, `--headwear {cap,beanie,hair}`, `--out-dir`, `--width`, `--height`, `--no-sheet`).
    - Verified end-to-end via `mise run mats-preview` (~8s total runtime) and visually inspected all 5 output images and composite sheet.

### Maintenance rules for `mats.blend`

- **Adding new meshes in Blender**: A newly created mesh object won't have a save path automatically. After saving the `.blend`, open Advanced Import Settings in Godot and run **Actions → Set Mesh Save Paths** (or toggle "Save to File" for that mesh) so its `.res` is generated.
- **Renaming or removing meshes**: Godot does not delete old `.res` files when meshes are removed or renamed in Blender. Delete orphaned `player/mats_meshes/mats_<old>.res` files by hand.
