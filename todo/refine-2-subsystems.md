# Refinement plan: traffic, player rig, and layout subsystems

## Assessment

Stroad Hero's vehicle simulation and character interaction are rich but concentrated in large multi-responsibility controllers (`TrafficManager` and `Mats`). Additionally, world layout elements (Road, Parking, Props) are defined inline within `main.tscn`.

This document addresses subsystem-level extractions for traffic data/geometry, the player visual rig, and world layout scenes. These tasks build on the composition and dependency contracts defined in `todo/refine-1-composition.md`.

### What is already working

- `ParkingSpot`, `Errand`, and `PathBuilder` already separate small data records and route construction from the traffic simulation. Keep the lane/path traffic model; replacing it with a general-purpose navigation framework is not justified.
- Vehicle body variants are cleanly separated under `cars/bodies/`.
- Footprint/sweep operations already make use of caching (`Car.sweep_rev`).
- The mesh-baking pipeline (`MeshBaker`) successfully builds optimized collision and rendering meshes from authored scenes.

---

## Action items

### 1. Consolidate traffic site data before extracting traffic algorithms

**Evidence:** `traffic/parking_lot.gd:4–85` mixes world-space stall rows, destination entrances, individual site constants, and a `SOUTH_LOTS` table. Site classification includes coordinate-based fallbacks (`91–126`). `TrafficManager` owns spawning, lot lifecycle, blocker geometry, arbitration, merge logic, and debug input (`traffic/traffic_manager.gd:518–1230,1261–1507,1528–1826`).

**Problem:** Adding or moving a destination touches both map data and multiple branches in the simulation. The existing south-lot table is a useful start, but other sites use separate conventions. Separating the whole controller into forwarding managers would distribute this coupling rather than remove it.

**Plan:**

- [ ] Extend the existing site-data approach into one authoritative description of each site's identity, served destinations, lane connection, stalls, turn-in, wait, and merge positions.
- [ ] Give stalls explicit site identity; remove position-based identity inference after migrating callers and fixtures.
- [ ] Keep different route shapes explicit. Share common site lookup and lifecycle rules without forcing parking lots and drive-thrus through a universal route DSL.
- [ ] Once site branching is reduced, extract cohesive footprint/sweep geometry operations (`914–1023`) into one traffic-local helper. Keep update order, right-of-way decisions, watchdog state, and car ownership in the manager initially.
- [ ] Migrate debug displays and tests that inspect the moved implementation. Preserve current cache invalidation and allocation behavior (`Car.sweep_rev`).

**Acceptance:** Site configuration has one authoritative owner. Adding another ordinary parking site does not require copying north/south lifecycle branches. Blocker detection, priority, reverse safety, exit yielding, merge gaps, and destination lifecycles retain their current outcomes.

**If skipped:** Each destination increases the number of world-specific cases in traffic code.

---

### 2. Extract the player's visual rig as one cohesive component

**Evidence:** `player/mats.gd:88–110` owns detailed visual-node references; `269–304` owns customization; `561–572` owns joint poses; `698–734` builds the phone; `_animate()` starts at `753`. The same script owns movement, cart mounting/pushing, and death/respawn (`192–266,307–560,586–675`).

**Problem:** Changing joint hierarchy or character presentation requires editing the gameplay controller. The customization preview also shares a script that carries physical interaction and lifecycle responsibilities.

**Plan:**

- [ ] Attach one visual-rig controller to the existing `Visual` subtree; give it ownership of joints, materials, phone mesh, and pose transitions.
- [ ] Pass the small set of motion/pose inputs it actually needs. Keep authoritative movement, collisions, cart occupancy, and life state on `Mats`.
- [ ] Move customization callers in the character editor and preview tooling to the new owner. Do not leave obsolete forwarding aliases just to preserve an internal API.
- [ ] Keep cart lifecycle together during this extraction. Do not simultaneously create separate movement, inventory, phone, death, and cart frameworks.

**Acceptance:** Walking, hopping, phone poses, pushing, mounting/dismounting, and death during a cart interaction retain their behavior. Character-editor changes still affect the intended character without modifying another instance's materials. Visual preview can exercise the rig without running world interactions.

**If skipped:** Visual changes and physics changes continue sharing a large implementation surface.

---

### 3. Extract world layout scenes selectively (after dependency work)

**Evidence:** `main.tscn` already instances buildings, but authors `Road` and its descendants inline from line `510`, `Parking` from `1403`, and the placement hierarchy under `Props` from `1642`. `MeshBaker.bake_main_scene()` explicitly looks for `Road`, `Parking`, and `Props/...` (`addons/mesh_baker/mesh_baker.gd:1193–1233`).

**Problem:** Road and layout editing shares the main assembly file with game composition. A naive move into a new `World` node would break baker and gameplay paths.

**Plan:**

- [ ] After composition dependency work is complete, extract the road and parking visual/layout subtrees into dedicated scenes while preserving their root names and transforms at the main boundary.
- [ ] Keep the whole-world assembly responsible for placements. Do not move every building into a new wrapper or duplicate traffic coordinates into independent scene exports.
- [ ] If site-local anchors become the source of traffic layout, derive runtime positions from them once; otherwise keep traffic data authoritative and document the visual-layout relationship.
- [ ] Update baker targets, warmup inputs, objective bindings, and debug overlays in the same cutover whenever hierarchy changes.

**Acceptance:** `main.tscn` is primarily composition, and road/layout changes are localized. Collisions, objective anchors, traffic alignment, and baked export behavior match the unbaked world. No source scene is overwritten with baked output.

**If skipped:** `main.tscn` remains a larger layout file, which is tolerable for a single map, but keeps layout edits coupled to root composition.

---

## Suggested implementation order

1. **Traffic site data and sweep extraction (Item 1):** consolidate site conventions, then extract geometry operations without changing arbitration rules.
2. **Player visual rig extraction (Item 2):** separate visual presentation and customization from `Mats` movement/cart logic.
3. **Optional world layout scene extraction (Item 3):** perform only after consumers no longer depend on incidental root node hierarchy.

---

## Verification

- Check modified GDScript: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`
- Run core traffic contract tests: `mise run test`
- Run extended scenario suites: `mise run test --extended` (reverse safety, merge gap, parking lifecycle, drive-thru, cart/collision).
- Check simulation performance: run `mise run bench` to confirm no regressions in hot paths.
- For player rig changes, test character customization preview, cart pushing/riding, and ragdoll/death transitions.
- For layout changes, verify both unbaked play and baked web exports (`MeshBaker`).
