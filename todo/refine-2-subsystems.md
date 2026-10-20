# Refinement plan: traffic, player rig, and layout subsystems

## Assessment

Stroad Hero's vehicle simulation, character interaction, and world layout were previously concentrated in large multi-responsibility controllers (`TrafficManager` and `Mats`) and an extensive inline hierarchy inside `main.tscn`.

This document breaks down the subsystem-level extractions for traffic data/geometry, the player visual rig, and world layout scenes into smaller, related work units. These tasks build on the composition and dependency contracts established in `todo/refine-1-composition.md`.

### What is already working

- `ParkingSpot`, `Errand`, and `PathBuilder` separate small data records and route construction from traffic simulation.
- Vehicle body variants are cleanly separated under `cars/bodies/`.
- Footprint/sweep operations make use of scalar revision caching (`Car.sweep_rev`).
- The mesh-baking pipeline (`MeshBaker`) successfully builds optimized collision and rendering meshes from authored scenes.

---

## Action Items

### Section 1: Traffic Subsystem Refinement

#### 1.1 Consolidate traffic site data

**Evidence:** `traffic/parking_lot.gd:4–85` previously mixed world-space stall rows, destination entrances, individual site constants, and a `SOUTH_LOTS` table. Site classification included coordinate-based fallbacks (`91–126`).

**Plan:**

- [x] Extend the existing site-data approach into one authoritative description of each site's identity, served destinations, lane connection, stalls, turn-in, wait, and merge positions (`LotSite` definitions in `traffic/parking_lot.gd`).
- [x] Give stalls explicit site identity; remove position-based identity inference after migrating callers and fixtures.
- [x] Keep different route shapes explicit. Share common site lookup and lifecycle rules without forcing parking lots and drive-thrus through a universal route DSL.

**Handoff:** Site definitions unified in `traffic/parking_lot.gd`; stall site identity and destination associations verified across all traffic test suites.

#### 1.2 Extract 2D swept-footprint collision helper (`traffic/car_sweep.gd`)

**Evidence:** `traffic/traffic_manager.gd:909–1030` defines `_lookahead()`, `_car_sweep()`, `_append_path_footprints()`, `_footprint()`, and `_footprints_overlap()`.

**Problem:** Pure 2D polygon projection and separating-axis theorem (SAT) intersection algorithms live inside the 1,900-line traffic orchestration node.

**Plan:**

- [x] Create a dedicated helper script (`traffic/car_sweep.gd` or `traffic/traffic_geometry.gd`).
- [x] Move `_footprint(pos, heading, half_l, half_w) -> PackedVector2Array` and `_footprints_overlap(a, b) -> bool` to static methods on the helper.
- [x] Move `_append_path_footprints(rects, dists, path, from, travel, half_l, half_w) -> void` and `_lookahead(car) -> float` to the helper.
- [x] Extract `car_sweep(car: Car, cache: Dictionary)` to evaluate and cache oriented bounding boxes along the car's path or forward heading.
- [x] Preserve the existing `sweep_rev` revision counter check on `Car` (`car.sweep_rev`) to guarantee zero heap allocation on cache hits.

**Acceptance:** `car_sweep.gd` handles all 2D footprint generation and SAT overlap checks with no dependencies on `TrafficManager` internal state beyond the passed cars and cache.

#### 1.3 Extract conflict distance and route clearance calculations

**Evidence:** `traffic_manager.gd:1060–1120` (`_conflict_distance`) and `1215–1250` (`_reverse_route_clear`) calculate distances to conflicting footprints and check whether a back-out path is unobstructed.

**Problem:** Collision query logic is interleaved with simulation update loops and arbitration states.

**Plan:**

- [x] Move candidate conflict distance calculation (`_conflict_distance`) into the geometry helper.
- [x] Move reverse path obstacle clearance testing (`_reverse_route_clear`) into the geometry helper.
- [x] Keep fast spatial partitioning (rejecting pairs separated across north/south stroad halves $|z| > 4.0$, and bounding box reach pruning) intact.
- [x] Keep right-of-way arbitration (`_has_lot_priority`), deadlock watchdog timer state (`_watchdog_ignores`), and car state mutation in `TrafficManager`.

**Acceptance:** `TrafficManager` delegates geometric conflict queries to the helper. Simulation decision order and car state transitions remain identical.

#### 1.4 Migrate traffic callers, debug displays, and tests

**Evidence:** Callers in `TrafficManager` (`find_blocker`, `can_reverse_out`, `_reverse_route_clear`) and tests in `tests/traffic_contracts_suite.gd` / `tests/traffic_scenarios_suite.gd`.

**Plan:**

- [ ] Update all internal callsites in `TrafficManager` to use the extracted helper.
- [ ] Ensure `_sweep_cache` clearing at the start of `_update_lot_cars` continues to properly manage cache lifetime.
- [ ] Verify any traffic debug visualizers (e.g., debug footprint overlays) reference the new helper.
- [ ] Run benchmark suite to confirm that cache hit rates and sweep timing have no regressions.

**Acceptance:** All traffic contracts and scenarios pass with zero regressions in benchmark run times.

---

### Section 2: Player Visual Rig Refinement

#### 2.1 Extract visual rig controller and joint hierarchy (`player/mats_rig.gd`)

**Evidence:** `player/mats.gd:88–138` caches `@onready` references to `$Visual`, pivots (`LeftLegPivot`, `RightLegPivot`, `LeftArmPivot`, `RightArmPivot`, `HeadPivot`), joint child nodes (`Knee`, `Shoe`, `Elbow`), and body meshes. `player/mats.tscn` authors this hierarchy under `$Visual`.

**Problem:** Changing a bone pivot, adding a joint, or previewing character art requires loading the full character controller script with all its gameplay and physics dependencies.

**Plan:**

- [ ] Create `player/mats_rig.gd` extending `Node3D` and attach it to `$Visual` in `player/mats.tscn`.
- [ ] Move pivot and joint node resolution (`$LeftLegPivot`, `$RightLegPivot`, etc.) into `mats_rig.gd`.
- [ ] Move `_set_limb_pose(hip, knee, ankle, shoulder, elbow)` and base limb rest orientations to `mats_rig.gd`.
- [ ] Expose clean reset/hide/show methods (`reset_pose()`, `set_visible(bool)`) for death, respawn, and menu presentation.

**Acceptance:** `mats.gd` no longer holds direct node paths into the joint hierarchy under `$Visual`.

#### 2.2 Move procedural locomotion animation, gait, and squash to the rig

**Evidence:** `player/mats.gd:753–953` (`_animate()`, `_leg_reach()`) computes walk/run stride, leg reaching, foot planting offset, torso lean, idle sway, breath scaling, and jump squash/stretch.

**Problem:** Over 200 lines of procedural kinematics and trigonometry run directly inside the gameplay controller.

**Plan:**

- [ ] Move `_animate()` logic and helper kinematics (`_leg_reach`) into `mats_rig.gd`.
- [ ] Define a clean input contract for the rig: pass delta, planar velocity, grounded state, turning angle/yaw, step cadence, and squash factor from `mats.gd` each frame.
- [ ] Keep authoritative movement, gravity, jumping, ledge-step assists, and collision detection inside `mats.gd`.
- [ ] Preserve exact visual feel: lean angles, foot planting ground-drop, breath rates, and squash timing.

**Acceptance:** Mats' walking, running, jumping, and idle animations are visually identical. `mats.gd` supplies locomotion inputs; `mats_rig.gd` evaluates joint transforms.

#### 2.3 Extract phone mesh construction and upper-body pose blending

**Evidence:** `player/mats.gd:141–157,677–734,853–883,933–936` constructs a procedural phone model (`_build_phone()`), manages phone modes (`PhoneMode.TALKING`, `PhoneMode.RINGING`), and blends arm/elbow/head poses to the phone position.

**Problem:** Accessory mesh construction and procedural arm IK/blending clutter character movement and lifecycle code.

**Plan:**

- [ ] Move phone mesh generation (`_build_phone`) and phone node attachment to `mats_rig.gd`.
- [ ] Move phone pose targets (talking arm/elbow/head rotations, ringing arm/elbow/head rotations) and pose lerping into `mats_rig.gd`.
- [ ] Maintain gameplay phone state (`PhoneMode`, `answer_phone()`, `end_phone_call()`, `is_on_phone`, `is_phone_ringing`) on `mats.gd`, passing state updates to the rig.
- [ ] Ensure phone visibility hides cleanly on death and restores on respawn.

**Acceptance:** Mats answers, holds, and lowers the phone with identical procedural transitions. Phone accessory setup lives entirely within the visual rig.

#### 2.4 Decouple customization materials and character preview

**Evidence:** `player/mats.gd:269–304` exports and sets color properties (`cap_color`, `hair_color`, `skin_color`, `shirt_color`, `pants_color`, `shoe_color`) and duplicates materials to avoid cross-instance bleeding. `ui/character_editor.gd` manipulates these properties.

**Problem:** Character preview in UI or editor tools requires instantiating the full `CharacterBody3D` player node.

**Plan:**

- [ ] Move mesh instance references (`Torso`, `Backpack`, `Face`, `Cap`, etc.) and material duplication/override logic to `mats_rig.gd`.
- [ ] Expose customization setters (`set_shirt_color`, `set_pants_color`, etc.) directly on `mats_rig.gd`.
- [ ] Update `mats.gd` to forward initial configuration to its rig, and update `ui/character_editor.gd` to target the rig directly.
- [ ] Enable standalone instantiation of `mats_rig` (or `$Visual` scene) for isolated UI previews without physics overhead.

**Acceptance:** Palette customization functions properly in-game and in the character editor. Material overrides are isolated to each character instance without cross-contamination.

#### 2.5 Decouple cart interaction poses and death/ragdoll transitions

**Evidence:** `player/mats.gd:386–485,535–560` tweens limb joints into a kneeling pose during cart mounting and dismounting. Lines `591–606,655–670` toggle visual visibility and reset poses on death and respawn.

**Problem:** Cart mount/dismount tweens directly manipulate joints (`_left_leg`, `_left_knee`, `_left_arm`, etc.) from within the cart interaction state machine.

**Plan:**

- [ ] Add pose methods to `mats_rig.gd` for kneeling poses and mount/dismount joint tweens (e.g. `play_cart_mount_animation(duration)`, `play_cart_dismount_animation(duration)`).
- [ ] Let `mats.gd` orchestrate physical cart attachment, positioning, and timing, while delegating joint transformations to the rig.
- [ ] Ensure death and respawn events cleanly reset rig pose without leaving dangling tweens or residual joint offsets.

**Acceptance:** Cart mounting, pushing, riding, dismounting, and dying while pushing/riding behave smoothly without joint snapping or broken state.

---

### Section 3: World Layout Scenes & MeshBaker Refinement

#### 3.1 Extract Road layout subtree (`world/road.tscn`)

**Evidence:** `main.tscn:502–1496` contains nearly 1,000 lines of road geometry, pavement detail nodes, collision shapes, and lane markings.

**Problem:** Adjusting a lane marking or curb mesh requires modifying `main.tscn`.

**Plan:**

- [ ] Create `world/road.tscn` containing the `Road` subtree exactly as authored in `main.tscn`.
- [ ] Ensure `Road` retains its root node name (`Road`) and transform at the `main.tscn` boundary.
- [ ] Instance `world/road.tscn` in `main.tscn` as node `Road`.
- [ ] Verify `MeshBaker.bake_main_scene()` detects `Road/PavementDetails` and builds `BakedRoadMesh` without changes to baker paths.

**Acceptance:** Road geometry, collisions, markings, and baked road output in `main.tscn` are visually and mechanically identical to the inline version.

#### 3.2 Extract Parking layout subtree (`world/parking.tscn`)

**Evidence:** `main.tscn:1498–1735` defines parking lot meshes, curb perimeters, and stall markers.

**Problem:** Parking layout changes risk merge conflicts in `main.tscn` and could disrupt traffic stall coordinate alignment.

**Plan:**

- [ ] Create `world/parking.tscn` containing the `Parking` subtree from `main.tscn`.
- [ ] Preserve exact stall positions and coordinates used by `traffic/parking_lot.gd` and `TrafficManager`.
- [ ] Instance `world/parking.tscn` in `main.tscn` as node `Parking`.
- [ ] Verify `MeshBaker.bake_main_scene()` finds `Parking` and successfully executes `bake_static_scene(parking, root)`.

**Acceptance:** Parking stall detection, car parking maneuvers, and static parking mesh baking continue working seamlessly.

#### 3.3 Modularize repetitive props and validate objective anchors

**Evidence:** `main.tscn:1737+` mixes repetitive decorative props (`Props/Streetlights`, `Props/Trees`, `Props/Flags`, `Props/Bollards`) with destination site containers (`Props/BoogerKingSite`, `Props/WalgroinsSite`, `Props/SmellGasSite`).

**Problem:** Site instances contain critical gameplay destination anchors (`Anchor`) registered by `ObjectiveManager`. Moving props must not break anchor resolution.

**Plan:**

- [ ] Extract repetitive visual prop groups (e.g., `Props/Streetlights`, `Props/Trees`, `Props/Flags`) into dedicated scene instances if layout isolation is beneficial.
- [ ] Keep destination site containers and their `Anchor` nodes discoverable under `Props/` for `ObjectiveManager` anchor registration.
- [ ] Verify `MeshBaker` streetlight instancing, tree baking, flag baking, and bollard baking routines run cleanly against the extracted structure.
- [ ] Retain environment presentation controller hooks for streetlight day/night toggles.

**Acceptance:** Objectives resolve all target anchors cleanly. MeshBaker correctly bakes props, trees, and flags. Day/night transitions still toggle streetlight luminaires.

---

## Suggested Implementation Order

1. **Traffic Geometry Extraction (Section 1):**
   Execute first. Traffic simulation is completely independent of player and world scene hierarchies. Isolates algorithmic math from simulation orchestration.
2. **Player Visual Rig Extraction (Section 2):**
   Execute second. Separates presentation and character editor previews from `Mats` movement physics and cart state machines.
3. **World Layout Scene Extraction (Section 3):**
   Execute last. With gameplay and traffic dependencies stabilized, layout scenes can be safely externalized without breaking node paths or mesh baking.

---

## Verification

- Check modified GDScript syntax:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`
- Run core contract tests (<3s): `mise run test`
- Run extended scenario suites: `mise run test --extended` (reverse safety, merge gap, parking lifecycle, drive-thru, cart/collision, objectives)
- Check simulation performance: run `mise run bench` to confirm no regressions in hot paths.
- Smoke-run main scene: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
- Visual checks:
  - Character customization preview in character editor.
  - Cart pushing, mounting, riding, and dismounting.
  - Phone ringing and talking pose transitions.
  - Baked vs unbaked scene parity (`MeshBaker`).
