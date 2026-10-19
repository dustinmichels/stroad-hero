# Mats Objectives (Errands from Mom)

Mom calls Mats and asks him to pick something up. Mats walks to the store, the errand completes, and the OBJ counter goes up. Then the next call comes.

## Goals

- A phone-call overlay rings. Press **A** to answer. Mom's line appears in a dialogue box.
- One errand is active at a time. A green marker hovers over the destination store, and an off-screen arrow on the HUD points toward it.
- When Mats reaches the store entrance, a success toast shows and the **OBJ** counter (next to SPD, top-left) increments.
- The next errand prefers the store on the opposite side of the stroad from Mats, so every errand means crossing traffic.

## Non-goals

- Inventory, carrying items, or delivering them home.
- Voice acting or audio (add later if wanted).
- Save/persistence across sessions.
- Using errands to change the traffic AI. The `traffic/errand.gd` class (`Errand`) is for car destinations. It stays separate from this system, and the new class must not be called `Errand`.

## Reference data (world coordinates)

The stroad runs along X. North is `-Z` and south is `+Z`. Sidewalks are at `z = ±9.1`, and Mats spawns at `(0, 0.3, 9)` on the south sidewalk.

| Errand        | Item        | Store           | Side  | Scene node                                               | Approx. entrance (x, z) |
| ------------- | ----------- | --------------- | ----- | -------------------------------------------------------- | ----------------------- |
| `cough_syrup` | Cough syrup | Walgroins       | North | `Props/Walgroins` (`Building/Doors`)                     | (-3, -31.35)            |
| `milk`        | Milk        | Smell Food Mart | North | `Props/SmellGasStation` (`Store/DoorGlass`)              | (-52.5, -31.3)          |
| `hamburgers`  | Hamburgers  | Booger King     | South | `Props/BoogerKingSite` (`Building/Building/Tower/Doors`) | (-47.3, 29.4)           |

Entrance positions are computed from the transform chains in `main.tscn` and the building scenes. At runtime, read them from the door nodes' `global_position`, not from these constants. That way, if a building moves, the target moves with it.

## Open decisions

- [ ] **Answer key conflict:** `A` is already bound to `camera_left` (`project.godot`). `follow_camera.gd:52` polls `Input.is_action_just_pressed("camera_left")`, so pressing A to answer would also rotate the camera, and `set_input_as_handled()` will not stop that. Options:
  - [ ] **(Recommended)** Add an `answer_phone` action bound to `A` (plus Enter, and the gamepad A button for later). While the ringing overlay is visible, `follow_camera` skips its yaw step. This keeps the "A to answer" UX.
  - [ ] Answer with Space or Enter instead. This needs no camera change, but the prompt no longer says "A".
- [ ] **Freeze during the call:** Pause Mats's movement while the dialogue box is open, or let him keep walking? Recommendation: keep the world running, freeze only Mats's input, and do not pause the tree, because traffic stopping would look odd.
- [ ] **Death mid-errand:** Recommendation: the errand stays active, and the marker and arrow resume after respawn.
- [ ] **After all three errands:** Loop with random picks (using the opposite-side rule), or end with a "That's everything, sweetie!" call? Recommendation: loop, so the counter keeps climbing.

## 1. Data model

- [ ] Create `objectives/mats_errand.gd` (`class_name MatsErrand`, `extends Resource` or `RefCounted`) with:
  - [ ] `id: StringName`, `item: String`, `store_name: String`
  - [ ] `target_path: NodePath` (the entrance node, relative to Main)
  - [ ] `call_line: String` (Mom's dialogue)
  - [ ] `success_line: String` (toast text, e.g. "Got the cough syrup!")
- [ ] Define the three errands as a `const`/static list in the manager. Don't create `.tres` files yet; three entries don't need them.
  - [ ] Cough syrup: "Hello Mats darling, while you're out exploring, could you please pick up some cough syrup from Walgroins?"
  - [ ] Milk: "Mats, sweetie, we're out of milk. Could you grab some from the Smell on your way?"
  - [ ] Hamburgers: "Mats, honey, I don't feel like cooking. Pick up some hamburgers from Booger King for dinner?"

## 2. Objective manager

- [ ] Create `objectives/objective_manager.gd` (`class_name ObjectiveManager`, `extends Node`) and add it as a child of `Main` in `main.tscn`.
  - [ ] Add it with a plain `[node]` entry, a `res://` script path, and no invented `uid://`.
- [ ] State machine: `IDLE -> RINGING -> IN_CALL -> ACTIVE -> COMPLETE -> IDLE`.
- [ ] Signals: `call_started(errand)`, `call_answered(errand)`, `objective_started(errand)`, `objective_completed(errand, total)`.
- [ ] Add `completed_count: int`.
- [ ] Start trigger: connect to `StartScreen.started`, wait about 3 s, then ring. If the game starts with `--test-*` args (StartScreen auto-skips), start immediately.
- [ ] First errand is always `cough_syrup`. Mats spawns south and Walgroins is north, so this already satisfies the opposite-side rule.
- [ ] Pick later errands with `_pick_next()`:
  - [ ] Mats's side is `sign(mats.global_position.z)`. Candidates are errands whose target `z` has the opposite sign.
  - [ ] Exclude the errand just completed. If no candidates remain, fall back to any errand except the last one.
  - [ ] Pick randomly among the candidates.
- [ ] After each completion, wait about 4 s before the next call (`@export var next_call_delay`).
- [ ] Arrival detection: in `_physics_process`, measure the horizontal (XZ) distance from Mats to the target. It completes when the distance is under `@export var arrive_radius := 2.5`.
  - [ ] Use a plain distance check, not an `Area3D`, so the scenes don't change.
  - [ ] Skip the check while Mats is dead (between `died` and `respawned`).

## 3. Phone call overlay (UI)

- [ ] Create `ui/phone_call.gd` plus a scene, or build the nodes in code the way `hud.gd` builds `FadeOverlay`. Prefer a small `ui/phone_call.tscn` instanced under `HUD`.
- [ ] Ringing state:
  - [ ] A panel at bottom-center or top-center with a phone icon drawn in `_draw()` (handset from a rounded rect and two small rects), the text "MOM", and the prompt "[A] Answer". Don't use emoji or symbol glyphs: Overpass doesn't have them, and the web export has no system font fallback, so they would show as missing-glyph boxes.
  - [ ] A pulsing/shaking tween on the panel while it rings.
- [ ] In-call state:
  - [ ] Show a dialogue box with the speaker label "Mom" and `call_line`, using a typewriter reveal with `visible_ratio` tweening.
  - [ ] "[A] OK" dismisses the box. On dismiss, emit and the manager moves to `ACTIVE`.
- [ ] Match the HUD styling: reuse the `StyleBoxFlat` look from `hud.tscn` (dark bg `Color(0.08, 0.1, 0.13, 0.85)`, rounded corners) with a green border for objectives.
- [ ] Use the Overpass fonts already in `fonts/`.
- [ ] Input: handle `answer_phone` in `_unhandled_input` only while visible.

## 4. Input action

- [ ] Add `answer_phone` to `[input]` in `project.godot` (A, Enter, and gamepad A). This is a text edit. While the editor is open, make sure the editor doesn't overwrite it: if `project.godot` is open in the editor, ask the user to reload or add it through Project Settings.
- [ ] In `follow_camera.gd`, ignore `camera_left` while a phone call is showing. Check the `ObjectiveManager` state through a group or signal, so the camera doesn't need a hard reference to it.

## 5. HUD: OBJ counter

- [ ] Add an `ObjLabel` to `hud.tscn`, inside a second panel next to the SPD panel or below it inside the same `VBoxContainer`.
  - [ ] Recommendation: use a separate green-bordered panel to the right of SPD. It reads as "good" next to the red "bad" counter.
  - [ ] Show "OBJ: 0" with the subtitle "Errands Completed".
- [ ] In `hud.gd`, add `increment_obj()` and `set_obj(value)`, mirroring `increment_spd()` and `set_spd()`. Use a green flash for the increment animation (copy `_animate_increment` with a parameterized color instead of duplicating it).
- [ ] Add a current-objective line under the OBJ panel, e.g. "Get cough syrup at Walgroins", with a small green triangle drawn in `_draw()` before it (no glyph). Hide it when no objective is active.

## 6. World marker (green indicator)

- [ ] Create `objectives/objective_marker.gd` (Node3D), built in code, and spawn one instance at the target:
  - [ ] A downward-pointing green chevron or cone (`CylinderMesh` with `top_radius = 0`, unshaded, emissive green) about 6 m above the entrance. Bob it with a sine wave and rotate it slowly.
  - [ ] A translucent green ground ring (`TorusMesh` or a flat `CylinderMesh`) at the entrance showing the arrive radius.
  - [ ] Optional: a `Label3D` with the store name, billboarded.
- [ ] Use an emissive material so it stays readable at night (`GameState.TimeOfDay.NIGHT`).
- [ ] Make sure the marker has no collision and doesn't cast shadows.
- [ ] Free the marker on completion with a short scale-up and fade tween.

## 7. Off-screen arrow (HUD)

- [ ] Create `ui/objective_arrow.gd` (Control under HUD):
  - [ ] Each frame, project the target with `camera.unproject_position()` and check `camera.is_position_behind()`.
  - [ ] If the target is on screen, hide the arrow (the world marker is enough).
  - [ ] If it is off screen, clamp the arrow to the viewport edge with a margin of about 60 px and rotate it toward the target. When the target is behind the camera, flip the direction.
  - [ ] Show the distance in meters next to the arrow ("42 m").
- [ ] Draw the arrow with `_draw()` (`draw_colored_polygon`) in objective green. No texture assets needed.
- [ ] Hide it while the start screen, character editor, or a call overlay is open.

## 8. Success feedback

- [ ] Show a center-screen toast with "Got the cough syrup!" and a green checkmark drawn with `draw_polyline` (no glyph) for about 2 s, with a scale-in and fade-out.
- [ ] Call `hud.increment_obj()` with the green flash.
- [ ] Optional: a small green particle pop at the marker.

## 9. Wiring and edge cases

- [ ] The manager finds Mats and the HUD with `get_node("../Mats")` and the `hud` group (already added in `hud.gd:28`).
- [ ] Connect `mats.died` and `mats.respawned` to pause and resume arrival checks.
- [ ] Don't ring while `StartScreen` is open or the tree is paused. Opening the start screen with H mid-call must not break the state machine (tweens use the default pause mode, so they freeze along with the tree).
- [ ] Character editor (C): hide the overlay and arrow while it is open.
- [ ] Mats already standing inside the arrive radius when an errand starts: unlikely given the opposite-side rule, but require one frame outside first, or just allow instant completion. Pick one and document it.

## 10. Verification

- [ ] `--check-only` each new script:
      `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only -s res://objectives/objective_manager.gd` (and the others).
- [ ] Smoke-run: `<godot> --headless --path . --quit`.
- [ ] Add a `--test-objectives` headless test, following the `--test-*` pattern in `main.gd`:
  - [ ] The first call is `cough_syrup`, and its target is on the north side (`z < 0`).
  - [ ] Answer programmatically, teleport Mats to the target, and assert `completed_count == 1` and the HUD shows "OBJ: 1".
  - [ ] The next errand's target `z` sign is opposite Mats's `z` sign.
  - [ ] Quit with exit code 0.
- [ ] Manual check in the editor (by the user): ring, answer, marker visible day and night, arrow behavior when the target is off screen or behind the camera, toast, counter.
- [ ] Run `mise run fmt`.

## 11. Docs

- [ ] Add a `CHANGELOG.md` entry under today's date in `### Added`.
- [ ] Mention the errand loop and the `answer_phone` control in `docs/mats.md` and in the controls page on the start screen (`ui/start_screen.tscn`).
