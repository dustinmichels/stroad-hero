# Mats Character: Next Steps

Follow-up work for the Blender-modeled Mats (Oct 18, 2026). He is a low-poly kid, about 1.40 m tall and roughly 4.7 heads tall, with bending knees, elbows, and ankles. So far he has only been checked in Blender renders and headless Godot runs. Nobody has looked at him in the editor or in a running game.

## How the model is built

| Piece                 | Role                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------ |
| `player/mats.blend`   | Source of truth for Mats model and geometry. Directly scanned and imported by Godot. |
| `player/mats_meshes/` | Extracted mesh `.res` files (`mats_<name>.res`) used by `player/mats.tscn`.          |

Each Blender object's origin sits at the Godot node it belongs to: hip, knee, ankle (`Shoe`), shoulder, elbow, or chin (`Head`). The script looks up these nodes: `Visual/{Left,Right}LegPivot/Knee/Shoe/Upper`, `Visual/{Left,Right}ArmPivot/Elbow`, `Visual/Head/Hat`, and `Visual/Backpack`. Colors are set in Blender. Only the backpack and the shoe uppers are recolored at runtime, through `material_override`.

## 1. Visual review

- [ ] Look at Mats in the open editor and in a running game with the real sun and environment. The Blender previews used EEVEE with a different light setup.
- [ ] Check the Web build. It always uses the Compatibility renderer (see `improvements.md`), and smooth-shaded skin and eye highlights may look different there.
- [ ] Check the character editor framing. The preview camera now aims at y = 0.75, but its position (`character_editor.tscn`, `PreviewCamera`) was sized for the old 1.95 m Mats.
- [ ] Check that he reads at gameplay distance. He is shorter than before, so make sure the cap, backpack, and jacket still stand out from the sidewalk.

Verify: a screenshot of the gameplay view and one of the character editor, compared with `screenshots/asset_character_mats.png`.

## 2. Walk cycle

- [ ] Fix foot sliding. With `STRIDE_RATE = 3.6` and `LEG_SWING = 0.6`, each step covers about 0.87 m. A 0.6 m leg swung ±0.6 rad only travels about 0.68 m. Either tune the two constants until the feet stop sliding at `walk_speed`, or derive the stride rate from leg length and swing.
- [ ] Lower the body while a knee is bent. Bending the knee shortens the leg, but the body doesn't drop, so the planted foot can float above the ground. (A headless test measured the lowest shoe point at 1–9 cm above the floor.) One fix is to drop the visual by the shortening of the more-bent stance leg.
- [ ] Try a separate run blend at full `walk_speed` (5.5 m/s is fast for a kid), with a bigger knee swing and forward lean.
- [ ] Bend the knees in the landing squash so the impact shows in the legs, not only in the body scale.

Verify: walk past a curb edge in game and watch for sliding or floating feet. Optionally, add a `--test-mats-walk` flag following the `main.gd` test-flag pattern that asserts the lowest shoe point stays within ±1 cm of the floor across a stride.

## 3. Shopping cart

- [ ] Ease into the kneeling pose. `_sit_in_cart` currently snaps the visual's facing, height, and limb rotations when he lands.
- [ ] Rest the hands on the front rim. Shoulders at −0.45 and elbows at −0.4 reach toward it but don't touch it.
- [ ] Check what happens when he dies while riding. `respawn()` doesn't reset the visual offset or limb pose, and `_animate` only blends them back once physics resumes.

Verify: get in and out of a cart while it's rolling, and while facing each direction.

## 4. Collision and gameplay

- [ ] Re-test the shorter capsule (1.5 m, was 1.95 m) against car hits, curbs (`step_height = 0.3`), sign posts, and building doorways.
- [ ] The capsule radius is still 0.30 m, but his body is only about ±0.25 m wide. Decide whether near misses with cars should count.

Verify: let cars hit Mats in each lane and confirm the SPD counter goes up.

## 5. Customization

More character editor options for accesories.

- [ ] Jacket color.
- [ ] Extra headwear (beanie)
- [ ] Rename "pine" to green

## 6. Performance

- [ ] Measure Mats on the web. He is about 8,500 triangles across 12 meshes and about 25 surfaces, which means around 25 draw calls for one character. If that matters, bake colors into vertex colors with a single shared material and merge the static parts (torso, backpack).
- [ ] Make a low-detail version for the gameplay camera distance, if profiling calls for it.

## 7. Pipeline

- [x] Complete Godot editor import for `player/mats.blend`: set Blender path in Editor Settings, run Advanced Import Settings -> Set Mesh Save Paths to `res://player/mats_meshes/`.
- [ ] Add a preview render task. A task that renders front, side, back, walk, and kneel views to `/tmp` would make reviews repeatable.

### Maintenance rules for `mats.blend`

- **Adding new meshes in Blender**: A newly created mesh object won't have a save path automatically. After saving the `.blend`, open Advanced Import Settings in Godot and run **Actions → Set Mesh Save Paths** (or toggle "Save to File" for that mesh) so its `.res` is generated.
- **Renaming or removing meshes**: Godot does not delete old `.res` files when meshes are removed or renamed in Blender. Delete orphaned `player/mats_meshes/mats_<old>.res` files by hand.
