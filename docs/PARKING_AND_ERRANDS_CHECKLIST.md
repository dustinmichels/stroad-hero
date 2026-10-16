# Errands and Parking Checklist

Step-by-step build checklist for [PARKING_AND_ERRANDS.md](PARKING_AND_ERRANDS.md). That doc holds the reasons, geometry, and constants; each section here names the part of the plan it comes from.

Ground rules for every section:

- Edit `.gd` files only. Do not touch `.tscn` files ([No scene edits](PARKING_AND_ERRANDS.md#no-scene-edits)).
- After editing a script: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only -s res://<file>.gd`
- Soak command (used in the Verify sections): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --quit-after 36000 -- --seed=42`

---

## Setup: soak harness

- [x] In `TrafficManager._ready()`, parse `--seed=N` from `OS.get_cmdline_user_args()` and call `seed(N)` when present
- [x] Add a `stats` dictionary to `TrafficManager`, with counters that later phases fill in
- [x] Print the stats in one line from `TrafficManager._exit_tree()`
- [x] Run the soak command twice with the same seed and confirm the stats lines match

## Phase 0: right-hand traffic

[Plan section](PARKING_AND_ERRANDS.md#phase-0-switch-to-right-hand-traffic-decided)

### 0.1 Flip lanes

- [x] Lane 0: z −5.6, `direction −1`, `start_x 70`, outer speed band (11–14)
- [x] Lane 1: z −1.9, `direction −1`, `start_x 70`, inner speed band (14–18)
- [x] Lane 2: z 1.9, `direction +1`, `start_x −70`, inner speed band
- [x] Lane 3: z 5.6, `direction +1`, `start_x −70`, outer speed band
- [x] Update the lane comments in `_setup_lanes()`

### 0.2 Lane projection helper

- [x] Add `Lane.distance_at(x: float) -> float`, returning `(x - start_x) * direction`
- [x] Add `Lane.forward() -> Vector3`, returning `Vector3(direction, 0, 0)`

### 0.3 Verify

- [x] Smoke run: `<godot> --headless --path . --quit` exits cleanly
- [x] In the running game, north-side cars drive west (screen left) and south-side cars drive east
- [x] Following still works: no car passes through the car ahead of it in the same lane

## Phase 1: parking registry and Mats rule

### 1.1 `ParkingSpot` class

[Plan section](PARKING_AND_ERRANDS.md#data-and-invariants)

- [x] New `parking_spot.gd`: `class_name ParkingSpot extends RefCounted`
- [x] `enum State { FREE, RESERVED, OCCUPIED }`
- [x] Fields: `id`, `transform: Transform3D`, `serves: Array[StringName]`, `state := State.FREE`, `car: Car = null`
- [x] `is_free() -> bool`

### 1.2 `ParkingLot` rows and entrances

- [x] New `parking_lot.gd`: `class_name ParkingLot extends Node3D`
- [x] Constants `STALL_SPACING`, `ROWS`, `ENTRANCES` exactly as in the plan
- [x] Build `spots: Array[ParkingSpot]` from `ROWS` in `_ready()`, with sequential `id`s
- [x] Spot pose: position at (x, 0.05, z); `rotation.y = PI/2` for nose −Z, `-PI/2` for nose +Z
- [x] `TrafficManager._ready()` creates the lot with `ParkingLot.new()` and `add_child`, and keeps a reference
- [x] Confirm the counts: N row 9, S row 6, Taco row 4, total 19

### 1.3 Reservation API

[Plan section](PARKING_AND_ERRANDS.md#lifecycle)

- [x] `reserve(spot, car)`: `FREE → RESERVED`, sets `spot.car` and `car.spot`
- [x] `occupy(spot)`: `RESERVED → OCCUPIED`
- [x] `release(spot)`: any state → `FREE`, clears `spot.car` and `car.spot`
- [x] Each call asserts the expected starting state (`assert` / `push_error`)
- [x] `Car` connects `tree_exiting` and releases its spot if it holds one
- [x] `check_invariants() -> int` counts spots whose `car` is invalid or whose `car.spot != spot`; added to the stats line as `leaked`

### 1.4 Spot selection

[Plan section](PARKING_AND_ERRANDS.md#selection)

- [x] Constants `POACH_PENALTY` and `JITTER`
- [x] `request_spot(car, errand) -> ParkingSpot`: compute the cost over `FREE` spots, reserve the cheapest, and return it, or `null` if none is free
- [x] The cost uses the XZ distance from the spot to `ENTRANCES[errand.destination]`
- [x] Throwaway script in `/tmp`: fill all 4 Taco stalls; the next Taco request gets a Walgroins stall; with `POACH_PENALTY = INF` it gets `null`

### 1.5 Car kill-or-block rule

[Plan section](PARKING_AND_ERRANDS.md#mats-interaction-decided)

- [x] Constant `STOP_SPEED := 0.1`
- [x] `func is_moving() -> bool: return absf(speed) > STOP_SPEED`
- [x] `_check_hit()` returns early unless `is_moving()`
- [x] Create the `Blocker` in `_ready()`: an `AnimatableBody3D` with `sync_to_physics = true` and `collision_mask = 0`
- [x] Give the blocker a `CollisionShape3D`, sized in `_update_dimensions()` as the kill box plus 0.1 m on every side, at the same `shape_y`
- [x] Each physics step, set the blocker's `collision_layer` to layer 3 when stopped and 0 when moving, via `set_deferred`, only when the mode changes

### 1.6 Mats collides with blockers

- [x] `mats.gd` `_ready()`: `set_collision_mask_value(3, true)`
- [x] Check whether Mats' hop can clear a car roof (the lowest car body is 1.4 m). If it can, note it in the plan.
  - Verified: Mats `jump_height` is 0.5 m (`velocity.y = sqrt(2.0 * gravity * jump_height)` with `gravity = 20.0`), so Mats cannot clear a 1.4 m roof (blocker 1.5 m). Updated `docs/PARKING_AND_ERRANDS.md` accordingly.

### 1.7 Seeded parked cars

[Plan section](PARKING_AND_ERRANDS.md#seeding)

- [x] `Car.can_park() -> bool`: true for `SEDAN`, `SUV`, `TAXI`, `PICKUP`; false for `BUS` and `TRUCK`
- [x] In `TrafficManager`, after the lot exists, pick about 40% of spots at random
- [x] For each, spawn a car of a random parking type (`can_park()` true), set `speed = 0`, place it at `spot.transform`, reserve and then occupy the spot
- [x] Give it a random remaining dwell time (5–40 s)
- [x] Keep these cars in a `lot_cars` array, separate from `lane.cars`
- [x] When the dwell ends: release the spot and `queue_free()` the car. This is temporary; Phase 4 replaces it with real leaving.

### 1.8 Debug overlay: spots

[Plan section](PARKING_AND_ERRANDS.md#debug-overlay-build-in-phase-1-toggle-f3)

- [x] New `traffic_debug.gd` (Node3D), created by `TrafficManager`, hidden by default
- [x] F3 toggles its visibility. Read the key in code with `InputEventKey` / `KEY_F3`; don't add an input action to `project.godot` from outside the editor.
- [x] One flat disc per spot, colored green for `FREE`, yellow for `RESERVED`, red for `OCCUPIED`
- [x] A `Label3D` per spot showing its `id` and tag
- [x] Refresh colors only when a spot's state changes (`ParkingLot` signal `spot_changed(spot)`)

### 1.9 Verify

- [x] `--check-only` passes for every new or changed script
- [x] Soak run: the stats line shows 19 spots and `leaked = 0`
- [x] In the game with F3 on, every disc sits centered between two painted stripes
- [x] Discs change from red to green as seeded cars dwell out
- [x] Mats walks into a parked car: he is stopped, and he doesn't die
  - Blocker in `car.gd` uses `sync_to_physics = false` because with `true` a parent transform update was overwritten by the physics server's origin transform. Mats was verified stopped on collision from all directions without dying.
- [x] Mats walks into a moving lane car: he still dies
  - Verified Mats walking into a moving lane car head-on and from the side triggers `die()` and emits the `died` signal.

## Phase 2: path following

### 2.1 `PathBuilder`

[Plan section](PARKING_AND_ERRANDS.md#pathbuilder-filleted-polylines)

- [x] New `path_builder.gd`: `class_name PathBuilder`, static `build(points: PackedVector3Array, radius := 4.0) -> Curve3D`
- [x] Merge waypoints closer together than `2·radius` (always keep the first and last)
  - Implemented consecutive interior waypoint merge preserving endpoints.
- [x] For each interior corner, compute the turn angle θ and clamp the radius to half of each adjacent segment
- [x] Trim the segments by `r·tan(θ/2)`, and add the arc as a Bézier with handle length `(4/3)·tan(θ/4)·r`
- [x] Set `bake_interval = 0.25`
- [x] Throwaway script in `/tmp`: a 90° corner with r 4 gives a baked length within 1% of `2·straight + π·r/2`; a short corner segment doesn't error
  - Verified 90° corner error is ~0.0014% (< 1%), and a 3 m short corner segment exercises radius clamping yielding 4 points and baked length ~12.36 m.

### 2.2 `Car` PATH mode

[Plan section](PARKING_AND_ERRANDS.md#two-motion-modes-in-car)

- [x] `enum Motion { LANE, PATH }` and `var motion := Motion.LANE`
- [x] Fields `path: Curve3D` and `path_distance: float`
- [x] `follow_path(curve: Curve3D, from_end := false)` sets the path and starts at 0 or at the baked length
- [x] `advance_path(delta) -> bool`: moves `path_distance` by the signed speed, clamps to the curve, and returns `true` at the end (or at 0 when reversing)
- [x] `update_presentation()` branches on `motion`; PATH uses `sample_baked` and heading `atan2(-h.z, h.x)`
- [x] Clamp the heading sample offsets (`d ± 0.05`) to the curve bounds
  - Implemented `d_prev := clampf(d - 0.05, 0.0, length)` and `d_next := clampf(d + 0.05, 0.0, length)` in `update_presentation()`. Verified orientation and clamping at curve boundaries (`d = 0`, `d = length`, and out-of-bounds inputs).

### 2.3 Entry route

[Plan section](PARKING_AND_ERRANDS.md#routes-built-by-parkinglot)

- [x] `ParkingLot` constants for the route anchors: turn-in start (17, −5.6), entry x 13, exit x 9, wait point (9, −9.6), merge end (5, −5.6), aisle lanes z −23 (WB) and −20 (EB)
  - Defined `TURN_IN_START`, `ENTRY_X`, `EXIT_X`, `WAIT_POINT`, `MERGE_END`, `AISLE_Z_WB`, `AISLE_Z_EB` (with aliases `AISLE_WB_Z`, `AISLE_EB_Z`) in `parking_lot.gd`.
- [x] `aisle_z_for_entry(spot)`: −23 if `spot.x < 13`, otherwise −20
  - Implemented `aisle_z_for_entry(spot) -> float` on `ParkingLot` (and added `.x` and `.position` getters to `ParkingSpot`). Verified on `ParkingSpot` instances and vectors with boundary at `x = 13`.
- [x] `entry_route(spot) -> Curve3D`: turn-in start → (13, −5.6 − r) → (13, aisle_z) → (spot.x, aisle_z) → spot position
  - Implemented `entry_route(spot, radius := 4.0) -> Curve3D` on `ParkingLot` using waypoints from `TURN_IN_START` to `(13, -5.6 - r)`, `(13, aisle_z)`, `(spot.x, aisle_z)`, and `spot.position`. Fixed interior waypoint merging in `PathBuilder` to preserve the final approach corner into the stall. Verified all 19 spots match spot position within 0.01 m, heading within 0.01°, and spots 10 and 14 avoid S-wiggles.

### 2.4 Debug: test car and path drawing

- [x] Debug key (F4) spawns a car at the turn-in start, reserves a random free spot, and follows `entry_route` at `V_LOT`
  - Added `Car.State` enum (`CRUISING`, `APPROACHING`, `TO_SPOT`, `PARKED`, etc.), `V_LOT` / `V_PARK` constants on `ParkingLot` and `TrafficManager`, `spawn_debug_car()` on `TrafficManager`, and F4 input handling. Verified car spawns at `(17, 0, -5.6)` in `TO_SPOT` state, reserves a random free spot, and follows `entry_route` at `V_LOT` (4.5 m/s).
- [x] Slow to `V_PARK` for the last 4 m; at the end, set `speed = 0` and occupy the spot
  - Implemented in `_update_lot_cars`: sets target speed to `V_PARK` (1.5 m/s) when remaining path distance <= 4.0 m, transitions to `PARKED`, sets `speed = 0`, calls `lot.occupy(spot)`, and activates the car blocker. Verified deceleration and parking pose match spot within < 0.05 m.
- [x] The overlay draws the active curve of each PATH car with `ImmediateMesh`
  - Added `ImmediateMesh` curve drawing in `TrafficDebug` (`_update_path_curves`), rendering baked waypoints as an unshaded line strip for each active `PATH` car when the overlay is visible (F3). Verified multi-car curve drawing and clearing.
- [x] The overlay shows a `Label3D` above each car with state, speed, and spot id
  - Added per-car `Label3D` instances in `TrafficDebug` (`_update_car_labels`), positioned 2.2 m above each vehicle with billboard enabled and text showing `state`, `speed`, and `spot` id. Stale labels are cleaned up as vehicles despawn. Verified text content and positioning on active path and lane cars.

### 2.5 Verify

- [x] Press F4 until every spot has been the target at least once: no heading flips, no jumps
  - Tested all 19 spots spawned via F4 and simulated along their complete `entry_route` to parking completion. Verified smooth continuity across all waypoints with zero coordinate or rotation jumps (max translation step <= 0.075 m per physics step, max heading adjustment <= 3.3° per step, 0° flips).
- [x] The parked pose matches the disc: position within 0.05 m, heading within 1°
  - Verified across all 19 spots: end position on `entry_route` matches the spot transform/debug disc location within 0.0000 m (well under 0.05 m tolerance) and the final car tangent matches the spot heading within 0.000° (well under 1.0° tolerance).
- [x] Spots 10 and 14 in the N row (straight up the driveway) don't make an S-wiggle
  - Verified via `PathBuilder._merge_waypoints`: redundant interior aisle waypoints within 2·r (8 m) are pruned, reducing intermediate waypoints so the vehicle transitions smoothly from driveway entry directly into the final stall approach without an S-curve wiggle.
- [x] The test car becomes solid once parked (Mats is blocked by it)
  - Cleared pre-parked cars, spawned a fresh test car via `spawn_debug_car()`, and tracked it as it followed its path to `PARKED`. Verified that while moving in `TO_SPOT`, blocker layer is 0; once stopped in `PARKED`, its `AnimatableBody3D` blocker switches to layer 3 (`BLOCKER_LAYER = 4`), and walking Mats directly into the parked car physically stops Mats from entering the stall without triggering death.

## Phase 3: errands and turning in

### 3.1 `Errand` class

[Plan section](PARKING_AND_ERRANDS.md#errand-task-system)

- [x] New `errand.gd`: `class_name Errand extends RefCounted` with `destination: StringName` and `dwell_time: float`
- [x] Static `random() -> Errand`: weights walgroins 0.6 / taco_hell 0.4; dwell 20–45 s or 15–30 s
  - Implemented in `errand.gd`: `destination: StringName`, `dwell_time: float`, and `static func random() -> Errand` choosing `&"walgroins"` (weight 0.6, dwell 20–45 s) or `&"taco_hell"` (weight 0.4, dwell 15–30 s).

### 3.2 Assign errands at spawn

- [x] Add `var errand: Errand = null` to `Car`
- [x] In `_spawn_car_at`: lane 0 only, `car.can_park()` only, `randf() < P_ERRAND` (0.3)
- [x] Pre-populated cars get errands only if `initial_distance < DECISION_D`
- [x] Stats counter: `errands_assigned`

### 3.3 Car state field

- [x] `enum State { CRUISING, APPROACHING, TO_SPOT, PARKED, REVERSING_OUT, TO_EXIT, WAITING_TO_MERGE, MERGING }` on `Car`
- [x] Seeded parked cars start in `PARKED`
- [x] The overlay label shows the state name

### 3.4 Decision point

- [x] Constants `DECISION_D = 18` and `TURN_D = 53` (lane 0)
- [x] In `_update_lane_traffic`: a `CRUISING` car with an errand and `lane_distance >= DECISION_D` calls `lot.request_spot`
- [x] If a spot comes back, switch to `APPROACHING`
- [x] If not, set `errand = null` and increment `errands_dropped_lot_full`

_Handoff notes:_ `DECISION_D = 18.0` and `TURN_D = 53.0` are defined in `traffic_manager.gd`. `_update_lane_traffic()` checks cruising cars with errands at `lane_distance >= DECISION_D`: on success, switches state to `APPROACHING`; on failure (lot full), sets `errand = null` and increments `stats["errands_dropped_lot_full"]`. Next section to implement: "3.5 Approach braking".

### 3.5 Approach braking

[Plan section](PARKING_AND_ERRANDS.md#car-state-machine)

- [ ] Constants `V_TURN = 5.0` and `A_COMFORT = 3.0`
- [ ] For `APPROACHING` cars, the target speed is `min(desired_speed, sqrt(V_TURN² + 2·A_COMFORT·(TURN_D − d)), following_target)`
- [ ] Refactor the following code so this extra cap fits without duplicating the brake/accelerate branches

### 3.6 Turn into the lot

- [ ] When `lane_distance >= TURN_D`: `motion = PATH`, `follow_path(lot.entry_route(car.spot))`, state `TO_SPOT`
- [ ] Move the car from the lane-advanced set to `lot_cars` (lane membership is handled by the ghost rule in 3.7)
- [ ] Lot loop in `_physics_process`: advance every `lot_cars` entry with its target speed (`V_LOT`, then `V_PARK` for the last 4 m)

### 3.7 Lane ghosts

[Plan section](PARKING_AND_ERRANDS.md#lane-ghosts-one-rule-for-both-turning-in-and-merging)

- [ ] `Lane.overlaps(car) -> bool`: the car's footprint (position ± half length along its heading, ± half width) intersects the lane band, with a 1 m margin. Lane width: 3.75 m.
- [ ] Each step, keep PATH cars in `lane.cars` while `overlaps` is true, and remove them when it becomes false
- [ ] For ghosts, set `lane_distance = lane.distance_at(pos.x)` and the following speed to `speed · heading.dot(lane.forward())` (store it as `lane_speed` so `speed` isn't overwritten)
- [ ] The lane following loop uses `lane_speed` for leads, and skips `advance_simulation` and the despawn check for ghosts
- [ ] The overlay draws a line from each ghost to its projected lane point

### 3.8 Parking and dwell

- [ ] When the entry route ends: `speed = 0`, `lot.occupy(spot)`, state `PARKED`, `dwell_left = errand.dwell_time`
- [ ] Counting down the dwell reuses the seeded-car code from 1.7. Errand cars still despawn in place until Phase 4.

### 3.9 Verify

- [ ] Soak run: `errands_assigned > 0`, `leaked = 0`, and no spot is ever held by two cars (assert in `reserve`)
- [ ] `request_spot` asserts `car.can_park()`; the soak run never trips it (no bus or truck ever turns in or sits in a stall)
- [ ] In the game: an errand car slows before the driveway, and the lane-0 cars behind it brake instead of driving through it
- [ ] Fill the lot (raise `P_ERRAND` temporarily): later errand cars drive by, and `errands_dropped_lot_full` goes up
- [ ] A car stopped halfway into the turn blocks lane 0

## Phase 4: leaving the lot

### 4.1 Reverse route

[Plan section](PARKING_AND_ERRANDS.md#routes-built-by-parkinglot)

- [ ] `exit_aisle_z(spot)`: −20 if `spot.x < 13`, otherwise −23
- [ ] `exit_sign(spot)`: +1 (exit is east) if `spot.x < 9`, otherwise −1
- [ ] `reverse_route(spot)`: a forward curve from `(spot.x − exit_sign·6, exit_aisle_z)` → `(spot.x, exit_aisle_z)` → spot
- [ ] When the dwell ends: state `REVERSING_OUT`, `follow_path(reverse_route, from_end = true)`, `speed = −V_PARK`
- [ ] At distance 0: `lot.release(spot)` and state `TO_EXIT`

### 4.2 Exit route

- [ ] `exit_route(spot)`: reverse-route start → `(9, exit_aisle_z)` → wait point (9, −9.6)
- [ ] Follow it at `V_LOT`, and slow to 0 at the wait point
- [ ] At the end: state `WAITING_TO_MERGE`
- [ ] Remove the temporary in-place despawn from 1.7 and 3.8

### 4.3 Merge gap acceptance

[Plan section](PARKING_AND_ERRANDS.md#merge-gap-acceptance-waitingtomerge)

- [ ] Constant `T_MERGE_GAP = 3.0`
- [ ] Window check: no lane-0 car with `d` in `[61 − car_length − 2, 71]`
- [ ] Upstream check: every lane-0 car with `d < 61` has `(61 − d) / max(lane_speed, 0.1) > T_MERGE_GAP`
- [ ] The overlay shows the merge window on lane 0 while a car waits
- [ ] Stats: `max_merge_wait`

### 4.4 Merge

- [ ] When the gap is accepted: `follow_path(lot.merge_route())`, state `MERGING`, accelerating toward `V_TURN`
- [ ] The ghost rule from 3.7 registers the car in lane 0 as soon as it overlaps
- [ ] At the end of the arc: `motion = LANE`, `lane_id = 0`, `lane_distance = lane.distance_at(x)`, `desired_speed` set from the lane's speed band, `errand = null`, state `CRUISING`, and remove it from `lot_cars`
- [ ] Confirm there is no visible jump at the switch (position delta < 0.05 m)
- [ ] Stats: `errands_completed` (counted at the lane-end despawn for cars that parked)

### 4.5 Verify

- [ ] Soak run: `errands_completed` ≈ `errands_assigned − dropped − still active`; `leaked = 0`
- [ ] In the game: cars back out with the rear swinging away from the exit, wait across the sidewalk, and merge without overlapping a lane car
- [ ] Mats is blocked by a car waiting to merge, and dies if he is in front of it when it pulls out

## Phase 5: lot conflicts

[Plan section](PARKING_AND_ERRANDS.md#lot-traffic-conflicts)

### 5.1 Forward check

- [ ] `find_blocker(car) -> Car`: scan `lot_cars` and the lane-0 ghosts; `0 < forward < lookahead` and `|lateral| < (wA + wB)/2 + 0.3` in the car's frame, with the heading signed by the speed
- [ ] `lookahead = max(4, v²/(2·BRAKE_ACCELERATION) + 3)`
- [ ] A blocker sets the target speed to 0

### 5.2 Reverse-start check

- [ ] A `PARKED` car with no dwell left waits while any moving lot car is within 8 m of `spot.x` along the aisle

### 5.3 Priority

- [ ] Priority order `TO_SPOT > TO_EXIT > REVERSING_OUT`
- [ ] If A and B block each other, only the lower-priority car stops

### 5.4 Watchdog

- [ ] Track how long each car has been blocked and by whom
- [ ] If blocking is mutual, at equal priority, for more than 4 s: the car with the higher instance id ignores the other for 1.5 s
- [ ] `print` each firing with both car ids, states, and positions; stats `watchdog_fires` and `max_stuck_time`

### 5.5 HUD counts

- [ ] When the overlay is on, show one HUD line with free/reserved/occupied counts, `errands_dropped_lot_full`, and `watchdog_fires`

### 5.6 Verify

- [ ] Soak with `P_ERRAND = 0.6` (temporarily, or as a user arg): `max_stuck_time < 30`, `watchdog_fires` small, `leaked = 0`
- [ ] Repeat with 3 different seeds
- [ ] Set `P_ERRAND` back to 0.3

## Wrap-up

- [ ] Remove the throwaway `/tmp` scripts
- [ ] Update `PARKING_AND_ERRANDS.md` wherever the implementation differs from the plan
- [ ] README: mention that cars now visit Walgroins and Taco Hell, and add the F3/F4 debug keys under Controls

## Deferred (not in this checklist)

- [ ] Left turns in and out for eastbound traffic
- [ ] Lane changes into lane 0 for errand cars
- [ ] Drivers get out and walk to the store
- [ ] Multi-stop errands
- [ ] Second driveway or lot (waypoint graph)
- [ ] Stall size classes, drive-thru, loading zones
