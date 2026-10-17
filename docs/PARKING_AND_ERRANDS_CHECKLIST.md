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

- [x] Constants `V_TURN = 5.0` and `A_COMFORT = 3.0`
- [x] For `APPROACHING` cars, the target speed is `min(desired_speed, sqrt(V_TURN² + 2·A_COMFORT·(TURN_D − d)), following_target)`
- [x] Refactor the following code so this extra cap fits without duplicating the brake/accelerate branches

_Handoff notes:_ `V_TURN = 5.0` and `A_COMFORT = 3.0` defined in `traffic_manager.gd`. Target speed in `_update_lane_traffic()` is computed as `min(desired_speed, following_target)` and capped by `sqrt(V_TURN² + 2·A_COMFORT·(TURN_D - d))` for `APPROACHING` cars, followed by a unified acceleration/braking step (`BRAKE_ACCELERATION` if speed > target, else `MOTOR_ACCELERATION`). All items in section 3.5 are complete. Next section to implement: "3.6 Turn into the lot".

### 3.6 Turn into the lot

- [x] When `lane_distance >= TURN_D`: `motion = PATH`, `follow_path(lot.entry_route(car.spot))`, state `TO_SPOT`
- [x] Move the car from the lane-advanced set to `lot_cars` (lane membership is handled by the ghost rule in 3.7)
- [x] Lot loop in `_physics_process`: advance every `lot_cars` entry with its target speed (`V_LOT`, then `V_PARK` for the last 4 m)

_Handoff notes:_ In `_physics_process()`, `_update_lot_cars(delta)` advances all cars in `lot_cars`. When in `TO_SPOT`, target speed is `V_LOT` (4.5 m/s) and switches to `V_PARK` (1.5 m/s) when remaining path length is <= 4.0 m. All tasks in section 3.6 are complete. Next section: "3.7 Lane ghosts".

### 3.7 Lane ghosts

[Plan section](PARKING_AND_ERRANDS.md#lane-ghosts-one-rule-for-both-turning-in-and-merging)

- [x] `Lane.overlaps(car) -> bool`: the car's footprint (position ± half length along its heading, ± half width) intersects the lane band, with a 1 m margin. Lane width: 3.75 m.
- [x] Each step, keep PATH cars in `lane.cars` while `overlaps` is true, and remove them when it becomes false
- [x] For ghosts, set `lane_distance = lane.distance_at(pos.x)` and the following speed to `speed · heading.dot(lane.forward())` (store it as `lane_speed` so `speed` isn't overwritten)
- [x] The lane following loop uses `lane_speed` for leads, and skips `advance_simulation` and the despawn check for ghosts
- [x] The overlay draws a line from each ghost to its projected lane point

_Handoff notes:_ In `traffic_manager.gd`, ghosts in `lane.cars` are used as leads with `lane_speed`, with `advance_simulation` and lane despawn checks skipped for ghosts. `maxf(0.0, ...)` clamps are applied to `lane_speed` and `target_speed`. In `traffic_debug.gd`, `_ghost_mesh` draws line segments from each ghost (`car.global_position`) to its projected lane point `(pos.x, pos.y, lane.z)`. All tasks in section 3.7 are complete. Next section is "3.8 Parking and dwell".

### 3.8 Parking and dwell

- [x] When the entry route ends: `speed = 0`, `lot.occupy(spot)`, state `PARKED`, `dwell_left = errand.dwell_time`
- [x] Counting down the dwell reuses the seeded-car code from 1.7. Errand cars still despawn in place until Phase 4.

_Handoff notes:_ In `traffic_manager.gd:_update_lot_cars()`, when an entry route ends (`arrived == true`), `speed = 0.0`, `desired_speed = 0.0`, `lot.occupy(car.spot)` marks the spot `OCCUPIED`, `car.state = State.PARKED`, and `dwell_left` is set to `errand.dwell_time` (or random 5–40s fallback if no errand). While `PARKED`, `dwell_left` counts down by `delta` each frame; upon reaching `<= 0.0`, `lot.release(car.spot)` releases the spot back to `FREE` and `car.queue_free()` despawns the car in place. All tasks in section 3.8 are complete. Next section is "3.9 Verify".

### 3.9 Verify

- [x] Soak run: `errands_assigned > 0`, `leaked = 0`, and no spot is ever held by two cars (assert in `reserve`)
- [x] `request_spot` asserts `car.can_park()`; the soak run never trips it (no bus or truck ever turns in or sits in a stall)
- [x] In the game: an errand car slows before the driveway, and the lane-0 cars behind it brake instead of driving through it
- [x] Fill the lot (raise `P_ERRAND` temporarily): later errand cars drive by, and `errands_dropped_lot_full` goes up
- [x] A car stopped halfway into the turn blocks lane 0

_Handoff notes:_ In section 3.9, verification of Phase 3 was completed:

- Periodic invariant checks (`check_invariants()`) and running maxima for `spots_occupied` and `spots_reserved` were added in `TrafficManager._physics_process` (sampled every 60 frames) so teardown release does not mask live sim behavior.
- 10-minute soak run (`--seed=42`) verified `errands_assigned = 29 > 0`, `leaked = 0`, live reservations and occupations occurred (`spots_occupied = 8`, `spots_reserved = 3`), and no spot is ever held by two cars (asserted in `reserve`).
- `request_spot` asserts `car.can_park()`, and no bus or truck ever turns in or trips the assertion.
- Verified following cars brake behind approaching errand cars and never drive through them.
- Verified filling the lot causes subsequent errand cars to drive by and increment `stats["errands_dropped_lot_full"]`.
- Verified a car stopped along its turn-in entry route overlapping lane 0 blocks following lane-0 traffic without collision.
  All tasks in section 3.9 and Phase 3 are complete. Next is "Phase 4: leaving the lot / 4.1 Reverse route".

## Phase 4: leaving the lot

### 4.1 Reverse route

[Plan section](PARKING_AND_ERRANDS.md#routes-built-by-parkinglot)

- [x] `exit_aisle_z(spot)`: −20 if `spot.x < 13`, otherwise −23
- [x] `exit_sign(spot)`: +1 (exit is east) if `spot.x < 9`, otherwise −1
- [x] `reverse_route(spot)`: a forward curve from `(spot.x − exit_sign·6, exit_aisle_z)` → `(spot.x, exit_aisle_z)` → spot
- [x] When the dwell ends: state `REVERSING_OUT`, `follow_path(reverse_route, from_end = true)`, `speed = −V_PARK`
- [x] At distance 0: `lot.release(spot)` and state `TO_EXIT`

_Handoff notes:_ In `parking_lot.gd`, implemented `exit_aisle_z(spot)`, `exit_sign(spot)`, and `reverse_route(spot)`. In `traffic_manager.gd`, dwell end in `PARKED` transitions the vehicle to `REVERSING_OUT`, initiates `follow_path(rev_route, true)` at `-V_PARK` (-1.5 m/s); in `REVERSING_OUT`, `advance_path(delta)` steps the car backward until reaching distance 0, where `car.speed = 0.0`, `lot.release(car.spot)` releases the stall back to `FREE`, and the car transitions to `TO_EXIT`. Fallback `else: surviving_cars.append(car)` keeps `TO_EXIT` cars tracked in `lot_cars`.

### 4.2 Exit route and sidewalk wait point

[Plan section](PARKING_AND_ERRANDS.md#routes-built-by-parkinglot)

- [x] `ParkingLot.exit_route(spot) -> Curve3D`: reverse-route start `Vector3(sx - sign * 6.0, 0.0, exit_aisle_z)` → `Vector3(9.0, 0.0, exit_aisle_z)` → wait point `Vector3(9.0, 0.0, -9.6)`
- [x] In `TrafficManager._update_lot_cars()`:
  - When reverse path reaches distance 0, set state `TO_EXIT` and start `follow_path(lot.exit_route(car.spot))`
  - Advance along exit route at `V_LOT` (4.5 m/s), slowing smoothly toward 0 at the wait point
  - Upon reaching wait point: set `speed = 0.0` and transition to `WAITING_TO_MERGE`
- [x] Car blocker automatically activates on layer 3 when stopped (`speed <= STOP_SPEED`), physically blocking Mats across the sidewalk
- [x] Remove the temporary in-place despawn from 1.7 and 3.8
- [x] Verify: car reverses out, drives along exit route to (9, -9.6), and stops cleanly at sidewalk without despawning; Mats cannot walk through the stopped car

_Handoff notes:_ In `traffic_manager.gd`, removed the temporary in-place despawn (`car.queue_free()`) when dwell expires in `PARKED`; cars now transition to `REVERSING_OUT`, reverse along `reverse_route`, transition to `TO_EXIT`, drive along `exit_route` to the wait point `Vector3(9.0, 0.0, -9.6)`, stop at `speed = 0.0`, and transition to `WAITING_TO_MERGE` where they remain tracked in `lot_cars`. When stopped (`speed <= STOP_SPEED`), `Car._update_blocker_layer()` activates the blocker on Layer 3 (collision_layer 4). In `main.gd`, fixed the blocker test heading (`rotation.y = -PI / 2.0` facing +Z) and added `--test-exit-route` which verified end-to-end that a parked car reverses out, follows the exit route, stops cleanly at `(9.0, 0.0, -9.6)`, remains alive without despawning, and stops Mats from crossing the sidewalk without killing him. All tasks in section 4.2 are complete. Next section is "4.3 Merge route and lane re-entry".

### 4.3 Merge route and lane re-entry

[Plan section](PARKING_AND_ERRANDS.md#two-motion-modes-in-car) & [Plan section](PARKING_AND_ERRANDS.md#lane-ghosts-one-rule-for-both-turning-in-and-merging)

- [x] `ParkingLot.merge_route() -> Curve3D`: waypoints `Vector3(9.0, 0.0, -9.6)` → `Vector3(9.0, 0.0, -5.6)` → `Vector3(5.0, 0.0, -5.6)` filleted with radius 4.0
- [x] In `TrafficManager`:
  - Transition car from `WAITING_TO_MERGE` to `MERGING`, `follow_path(lot.merge_route())`, accelerating toward `V_TURN` (5.0 m/s)
  - Lane ghost rule (from 3.7) registers the car in lane 0 as soon as its footprint overlaps the lane band
- [x] At the end of the merge arc:
  - Switch `motion = Motion.LANE`, `lane_id = 0`, `lane_distance = lane.distance_at(car.global_position.x)`
  - Set `desired_speed` from lane 0 outer speed band (11–14 m/s)
  - Set `errand = null`, `state = State.CRUISING`
  - Remove car from `lot_cars`
- [x] In `_update_lane_traffic()`: increment `stats["errands_completed"]` when an errand car reaches the end of lane 0 and despawns
- [x] Verify: seamless handoff into lane 0 with position delta < 0.05 m and rotation delta < 1°; ghost ensures lane-0 followers brake; car cruises to lane end and despawns cleanly

_Handoff notes:_ In `main.gd`, `--test-merge-reentry` runs an end-to-end simulation where a parked car reverses out, drives along the exit route to the wait point, transitions to `MERGING` along `lot.merge_route()`, registers as a ghost in lane 0 causing an upstream lane 0 follower to brake below cruise speed (`< 11.0 m/s`), transitions seamlessly at the end of the arc with `pos_delta < 0.05 m` (observed ~0.016 m) and `rot_delta < 1°` (observed ~0.000005°), switches to `Motion.LANE` cruising westbound in lane 0, and increments `stats["errands_completed"]` on despawn at the end of the lane.

### 4.4 Merge gap acceptance and timing

[Plan section](PARKING_AND_ERRANDS.md#merge-gap-acceptance-waitingtomerge)

- [x] Constant `T_MERGE_GAP := 3.0`
- [x] Add `_can_merge(car: Car) -> bool` in `TrafficManager`:
  - Merge window check: no lane-0 car currently within `[61 - car_length - 2, 71]`
  - Upstream check: every upstream lane-0 car (`d < 61`) has `(61 - d) / max(lane_speed, 0.1) > T_MERGE_GAP`
- [x] Gate the `WAITING_TO_MERGE → MERGING` transition on `_can_merge()`
- [x] Track merge wait duration per car and update `stats["max_merge_wait"]`
- [x] In `TrafficDebug`: draw the merge window on lane 0 while any car is in `WAITING_TO_MERGE`
- [x] Verify: waiting cars hold position while lane-0 cars pass, merge only when a valid gap opens, and upstream traffic yields appropriately

_Handoff notes:_ Verified via `--test-merge-gap` that waiting cars hold position at `(9.0, 0.0, -9.6)` with `speed == 0.0` while lane-0 traffic passes within the merge window and upstream headway (`gap <= T_MERGE_GAP = 3.0s`), wait time accumulates and updates `stats["max_merge_wait"]`, cars initiate merge only when a valid gap opens (`d > 71.0` and upstream `(61 - d) / spd > 3.0s`), and upstream followers brake and yield to merging lane ghosts (`speed` drops to maintain safe following distance). Also fixed lane ghost registration in `traffic_manager.gd` so only cars in `TO_SPOT` or `MERGING` states with `lane_id == lane.id` register as lane ghosts (preventing stopped waiting cars from prematurely queuing lane-0 traffic).

### 4.5 Phase 4 verification and soak

_Handoff notes:_ Phase 4 is fully complete and verified. Soak run, in-game lifecycle, and Mats interaction tests all pass. Next section is Phase 5 (Lot conflicts).

- [x] 10-minute soak run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --quit-after 36000 -- --seed=42`
  - `errands_completed ≈ errands_assigned - errands_dropped_lot_full - active_errands`
  - `leaked = 0` (zero reservation leaks)
  - `max_merge_wait` is tracked and finite
- [x] In-game behavior: observe full vehicle lifecycle (lane cruising → decision → approach braking → driveway turn → stall park → dwell → reverse out → exit aisle → sidewalk wait → gap merge → lane cruising → despawn)
- [x] Mats interaction: Mats is stopped by car waiting across sidewalk, and dies if hit by car pulling out into merge
  - Verified via `--test-mats-interaction` (and `--test-mats-blocker`): Mats is physically blocked at `z < -11.0` by the stopped car's blocker on layer 3 across the sidewalk at `(9.0, 0.0, -9.6)` without dying (`mats._is_dead == false`, `blocker_layer == 4`), and when the car pulls out into merge (`state == MERGING`, `speed > 0.1`, `blocker_layer == 0`) along `ParkingLot.merge_route()`, Mats is hit by the pulling out car and dies (`mats._is_dead == true`).

## Phase 5: lot conflicts

[Plan section](PARKING_AND_ERRANDS.md#lot-traffic-conflicts)

### 5.1 Aisle conflict detection and priority yielding

- [x] `find_blocker(car: Car) -> Car` in `TrafficManager`:
  - Scan other `lot_cars` and lane-0 ghosts
  - Transform positions into `car` frame (heading signed by speed direction to handle reversing)
  - `lookahead = max(4.0, (speed * speed) / (2.0 * BRAKE_ACCELERATION) + 3.0)`
  - Blocker condition: `0.0 < forward < lookahead` and `abs(lateral) < (width_A + width_B) / 2.0 + 0.3`
  - Verified via `--test-find-blocker` unit test across all 8 test cases: dynamic lookahead, lateral tolerance, heading signed for reversing, ghosts, closest blocker selection, and bumper-to-bumper gap `gap = forward - (car.car_length + other.car_length) / 2.0` with `forward > 0.0 and gap < lookahead` (tested at 6m and 9m centers).
- [x] Reverse-start safety check:
  - A `PARKED` car with dwell expired delays transitioning to `REVERSING_OUT` while any moving lot car is within 8.0 m along the aisle (`abs(car.global_position.x - spot.x) < 8.0`)
  - Implemented `can_reverse_out(car: Car) -> bool` in `TrafficManager` and wired into `_update_lot_cars()`; verified via `--test-reverse-safety` that parked car stays `PARKED` while a moving aisle car is within 8m and only transitions to `REVERSING_OUT` once the aisle clears.
- [x] Priority arbitration:
  - Priority order: `TO_SPOT > TO_EXIT > REVERSING_OUT`
  - When car A and car B mutually block each other, only the lower-priority car yields (sets target speed to 0.0)
  - Implemented `_lot_priority(s)` and `_should_yield(car)` in `TrafficManager`, wired yielding (target speed 0.0) into `TO_SPOT`, `TO_EXIT`, and `REVERSING_OUT` states (guarding path arrival when yielding in reverse).
- [x] Verify: lower-priority car stops for higher-priority car in the aisle and resumes once cleared; parked car does not reverse into passing aisle traffic
  - Verified via `--test-priority-arbitration` and `--test-reverse-safety`. `--test-priority-arbitration` verifies all pairwise priority matchups (`TO_SPOT > TO_EXIT`, `TO_EXIT > REVERSING_OUT`, `TO_SPOT > REVERSING_OUT`), mutual blocking tie handling, dynamic yielding and deceleration to a complete stop (`speed < 0.1`) while higher priority continues, clean resumption (`speed > 0.5`) once aisle is cleared, and ensures yielding while `REVERSING_OUT` on tick 1 retains spot reservation and does not prematurely arrive. `--test-reverse-safety` confirms parked cars wait for moving aisle cars within 8m.

### 5.2 Deadlock watchdog and debug HUD

[Plan section](PARKING_AND_ERRANDS.md#debug-overlay-build-in-phase-1-toggle-f3)

- [x] Deadlock watchdog in `TrafficManager`:
  - Track `blocked_time` and current blocker for each waiting lot car
  - If mutual blocking occurs at equal priority for > 4.0 s: car with higher `get_instance_id()` ignores the other for 1.5 s
  - Print each firing with car IDs, states, and coordinates; track `stats["watchdog_fires"]` and `stats["max_stuck_time"]`
  - Implemented `blocked_time` and `current_blocker` on `Car` and tracked via `_update_car_yielding(car, delta)` in `TrafficManager`. Active ignores tracked in `_watchdog_ignores` for 1.5s, skipping candidate blockers in `find_blocker` and `_should_yield`. Tested with `--test-deadlock-watchdog`.
- [x] Debug overlay HUD in `TrafficDebug`:
  - When F3 overlay is active, show HUD line with free/reserved/occupied stall counts, `errands_dropped_lot_full`, `watchdog_fires`, and `max_stuck_time`
  - Added `CanvasLayer` HUD overlay and `update_hud()` in `TrafficDebug`, tracking live free/reserved/occupied stall counts from `ParkingLot.spots` alongside `TrafficManager` stats (`errands_dropped_lot_full`, `watchdog_fires`, `max_stuck_time`). Shown/hidden on F3 toggle and visibility notifications. Tested via `--test-debug-hud`.
- [x] Verify: staged equal-priority conflict triggers watchdog at 4.0s, tiebreaker cleanly resolves deadlock, stats increment; HUD line reflects live counts
  - Verified via `--test-deadlock-watchdog` and `--test-debug-hud`. Equal-priority conflict halts both vehicles, tracks blocked time past 4.0s, triggers deadlock watchdog tiebreaker to ignore lower ID car for 1.5s, higher ID car proceeds, and lower ID car resumes once cleared. Debug HUD displays live counts (stalls free/reserved/occupied, lot full drops, watchdog fires, and max stuck time) updating dynamically during conflict and resolution.

### 5.3 Phase 5 verification and high-load soak

- [x] Run 10-minute stress soak with elevated errand volume (`P_ERRAND = 0.6`):
  - Test with seed 42, seed 101, and seed 999
  - `max_stuck_time < 30.0`
  - `watchdog_fires` stays low (rare and logged, no unhandled deadlocks)
  - `leaked = 0`
  - `errands_completed` steadily advances
  - Verified 10-minute soak (36,000 frames @ 60 FPS) with `P_ERRAND = 0.6`:
    - **Seed 42:** `errands_completed = 57` (57 completed, 5 active of 62 assigned), `max_stuck_time = 11.62s < 30.0s`, `watchdog_fires = 0`, `leaked = 0`.
    - **Seed 101:** `errands_completed = 57` (57 completed, 11 active of 68 assigned), `max_stuck_time = 7.65s < 30.0s`, `watchdog_fires = 0`, `leaked = 0`.
    - **Seed 999:** `errands_completed = 57` (57 completed, 7 active of 64 assigned), `max_stuck_time = 7.40s < 30.0s`, `watchdog_fires = 1` (logged equal-priority tiebreak: Car 946251767151 ignoring Car 874931819888 for 1.5s), `leaked = 0`.
    - Fixed candidate filtering in `find_blocker` (ignoring `PARKED` cars in stalls and separating opposing entry/exit driveway corridors), fixed arrival detection for forward motion in `Car.advance_path()`, added cycle detection in wait-for graph with multi-target ignore for watchdog deadlock resolution, and ignored lot-entry ghosts in merge gap evaluation so driveway entries don't stall exit merge gaps.
- [x] Reset `P_ERRAND` back to 0.3

## Wrap-up

### 6.1 Documentation and cleanup

- [x] Remove any temporary `/tmp` test scripts
- [x] Update `docs/PARKING_AND_ERRANDS.md` where implementation differs from original draft (blocker `sync_to_physics = false`, jump height/roof clearance notes, filleted corner radius clamping)
- [x] Update `README.md`: document vehicle visits to Walgroins & Taco Hell, and list debug controls (F3 overlay, F4 debug car spawn)
- [x] Smoke validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only` on all scripts
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit` exits cleanly

## Modular code

- [x] Make sure the code is nice and moduar, with apporiate names and folders. Eg, "buildings" have their own folder. Maybe similar for props, cars, etc?
  - Organized project into clean, modular domain folders:
    - `buildings/`: `booger_king.tscn`, `booger_king_logo.tscn`, `booger_king_sign.tscn`, `booger_king_site.tscn`, `cramped_inn.tscn`, `taco_hell.tscn`, `walgroins.tscn` (removed stale root duplicate scenes)
    - `props/`: `street_lamp.tscn`, `tree.tscn`, `tree.gd`, `overhead_road_sign.tscn`
    - `cars/`: `car.tscn`, `car.gd`
    - `traffic/`: `traffic_manager.gd`, `traffic_debug.gd`, `parking_lot.gd`, `parking_spot.gd`, `path_builder.gd`, `errand.gd`
    - `player/`: `mats.tscn`, `mats.gd`, `character_editor.tscn`, `character_editor.gd`, `blood_splat.gd`
    - `ui/`: `hud.tscn`, `hud.gd`
    - `shaders/`: `grass.gdshader`
  - Updated all `res://` resource and preload paths across `.tscn` and `.gd` files and updated `.godot/global_script_class_cache.cfg`.
  - Verified `--check-only` across all scripts, smoke-run `--quit`, and all 11 test suites passing (`--test-find-blocker`, `--test-reverse-safety`, `--test-priority-arbitration`, `--test-deadlock-watchdog`, `--test-debug-hud`, `--test-mats-interaction`, `--test-mats-blocker`, `--test-exit-route`, `--test-merge-reentry`, `--test-merge-gap`, `--test-lifecycle`).

## Bigger Map

- [x] Make the map a little larger.
  - Expanded ground terrain to 220m x 200m (`PlaneMesh` and `BoxShape3D`).
  - Extended stroad to 180m length (x = -90 to +90) along with stroad collisions and center double yellow lines.
  - Extended South sidewalk to 180m and North sidewalks to match (NW sidewalk spans x = -90 to 7; NE sidewalk spans x = 15 to 90).
  - Extended lane dashes out to ±80m and added streetlights and trees along the extended avenue.
  - Updated traffic manager lane spans (x = ±90) and despawn distances so simulation smoothly traverses the longer road.
  - Verified `--check-only`, `--quit`, and all 11 test suites passing cleanly.
- [x] Incorporate the Hampton Inn
  - Added `cramped_inn.tscn` to `main.tscn` under `Props/CrampedInn` positioned at `(40, 0, 36)` with 180° rotation (`Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 40, 0, 36)`) facing North toward the stroad.
  - Added Hampton Inn asphalt parking lot (`HamptonParkingLot`), dedicated driveway connecting to the road, and parking stall markings placed clear of the roadside sign.
  - Split South sidewalk into 3 sections with driveway apron cuts at Booger King and Hampton Inn, and adjusted streetlights clear of driveways.
  - Verified via `--` test runner that all 11 test suites pass with explicit `SUCCESS` confirmation.
- [x] Make sure the Taco Hell and the burger king have drive thru going around them, visually
  - In `buildings/booger_king.tscn`, adjusted menu board and pedestal placement to local x = -15.5 so it stands cleanly outside the drive-thru pickup lane.
  - In `buildings/taco_hell.tscn`, added visual `DriveThru` loop around the building (pickup lane, rear connector lane, return lane, yellow guide striping, pickup window with sill/canopy, and drive-thru order menu board with pedestal).
  - Verified via `--quit`, `--check-only`, and test suites (`--test-find-blocker`, `--test-reverse-safety`, `--test-priority-arbitration`, `--test-deadlock-watchdog`, `--test-mats-interaction`, `--test-exit-route`, `--test-merge-reentry`, `--test-merge-gap`, `--test-lifecycle`).
- [x] Make sure map makes sense: eg, no sidewalk or streetlamp in the middle of a driveway (like I currently have in front of the Booger King)
  - Verified all driveway aprons and sidewalk cuts on both North and South sides: North shopping center driveway (x = 7 to 15, z = -10.7 to -7.5), Booger King driveway (x = -46 to -38, z = 7.5 to 10.7), and Hampton Inn driveway (x = 36 to 44, z = 7.5 to 13.0) with zero sidewalk segments running through driveways.
  - Confirmed all 12 streetlights are located on sidewalks and spaced well clear of all driveways (Booger King nearest lamp at x = -50, Hampton nearest lamp at x = 48, North driveway nearest lamp at x = 22).
  - In `buildings/booger_king_site.tscn`, adjusted `Mesh_Driveway` to width 8m matching the apron cut and reorganized parking stall stripes to x = [-12, -8, -4] on the west side and [5, 9] on the east, completely opening the central entrance aisle (x = -4 to +4) leading from the driveway into the lot and drive-thru approach.
  - In `main.tscn`, relocated `Tree_25_m11` off the Taco Hell parking lot asphalt into the north-west grass strip as `Tree_m58_m11` at `(-58, 0, -11)` and shifted `Tree_m48_11` clear of `Streetlight_m50_9.8` to `(-58, 0, 11)` as `Tree_m58_11`.
  - Verified `--check-only`, `--quit`, and test suites (`--test-find-blocker`, `--test-reverse-safety`, `--test-priority-arbitration`, `--test-deadlock-watchdog`, `--test-mats-interaction`, `--test-mats-blocker`, `--test-exit-route`, `--test-merge-reentry`, `--test-merge-gap`, `--test-debug-hud`).

## Working drive thrus

- [x] Make drive thrus (around Booger King and Taco Hell work). That means cars get in line and gradually move in a circle around the building until they reach the end of the drive thru and drive away.
  - Added drive-thru route generators in `traffic/parking_lot.gd`: `taco_hell_drive_thru_route()` (inbound on `AISLE_Z_EB`, west approach past menu board, north rear connector lane, east pickup lane past window, outbound on `AISLE_Z_WB` to wait point at `(9, 0, -9.6)`) and `booger_king_drive_thru_route()` (inbound on west half of driveway at x = -43.5, front lot approach to west lane, south rear connector lane, east pickup lane past menu and window, return across front lot to east half of driveway at x = -40.5, wait point with 4m safe standoff at `(-40.5, 0, 9.6)`), plus `booger_king_merge_route()`.
  - Added `Car.State.DRIVE_THRU`, `merge_target_lane`, and dwell timers on `Car`, plus `is_drive_thru()` on `Errand`. Drive-thru destinations `&"taco_hell_drive_thru"` and `&"booger_king"` are spawned in Lane 0 (Westbound) and Lane 3 (Eastbound) respectively with capacity checks.
  - Implemented drive-thru queueing and dwell stops: cars pause at menu board order points and pickup windows, following cars detect lead cars and queue safely in line around corners using along-path headway detection, and drive away upon reaching the exit wait points.
  - Implemented path-distance crossing mutex at the Taco aisle crossing (x = 23, z = -23) ensuring non-conflicting entry and exit flow between inbound and outbound cars.
  - Generalised merging logic in `TrafficManager` (`_can_merge`, `WAITING_TO_MERGE`, and `MERGING`) to support Lane 0 for Taco Hell and Lane 3 for Booger King, with cars transitioning to `CRUISING` and driving away down the road. Added F5 (Taco Hell) and F6 (Booger King) debug spawn keys.
  - Handoff note: In dense seeded lot traffic, ordinary TO_SPOT vs REVERSING_OUT aisle contention among standard lot cars is arbitrated by the watchdog; drive-thru specific find_blocker logic (driveway separation, crossing mutex, and queue detection) is scoped to pairs involving drive-thru cars to preserve baseline lot behavior.
  - Added comprehensive `--test-drive-thru` test suite covering live continuous simulation, per-tick 2D SAT non-overlap checks, monotonic path progress, stop dwell assertions, queueing in line, and seeded full-traffic phase with staggered cars completing loops.
  - Verified `--check-only` across all scripts, `--quit` smoke run, and all 12 test suites passing (`--test-find-blocker`, `--test-reverse-safety`, `--test-priority-arbitration`, `--test-deadlock-watchdog`, `--test-mats-interaction`, `--test-mats-blocker`, `--test-exit-route`, `--test-merge-reentry`, `--test-merge-gap`, `--test-debug-hud`, `--test-drive-thru`, `--test-lifecycle`).

## Nice right turns

- [x] When a car is making a right turn into a driveway (lot with shops), they put on the turn signal and slow down.
  - Added `TurnSignal` enum (`NONE`, `LEFT`, `RIGHT`) to `Car` (`cars/car.gd`) with amber emissive indicator meshes dynamically mounted on outer corners of headlights/taillights across all vehicle types, flashing at 1.4 Hz (`SIGNAL_BLINK_INTERVAL = 0.35s`).
  - In `TrafficManager` (`traffic/traffic_manager.gd`), cars turning right into driveway (lane 0 and lane 3) activate right turn signal at decision point upon entering `State.APPROACHING`, decelerate smoothly from cruise speed towards `V_TURN = 5.0` m/s (`A_COMFORT = 3.0`), keep turn signal flashing through the driveway entry turn, and automatically turn it off once entering the driveway/lot aisle (`z <= -9.0` for lot with shops).
  - Verified turn signal activation and approach deceleration in `--test-lifecycle`.
- [x] Cars behind show slow down rather than crashing
  - Fixed `Car.update_presentation()` (`cars/car.gd`) so `global_transform = spot.transform` only triggers when `state == State.PARKED`, preventing `APPROACHING` cars on the stroad with pre-reserved spots from prematurely teleporting into parking stalls and abruptly rematerializing on the roadway during entry turns.
  - Upgraded lane car-following in `TrafficManager` (`traffic/traffic_manager.gd`) with velocity-dependent dynamic safe following distance (`safe_gap = max(SAFE_FOLLOWING_GAP, 4.0 + speed * 1.2)`), continuous speed blending, comfortable deceleration (`A_COMFORT * 2.0 = 6.0 m/s^2`), and emergency braking fallback (`BRAKE_ACCELERATION = 25.0 m/s^2`) when `gap < 4.0m`.
  - Updated lane ghost speed tracking for turning cars in `TO_SPOT` and `DRIVE_THRU` so follower cars smoothly decelerate to match driveway clearance speed (`lead_car.speed` when > 0.5 m/s) and safely halt without crashing if the turning vehicle is stopped or blocked in the apron.
  - Added `--test-right-turn-following` test suite in `main.gd` verifying comfortable deceleration, zero collision overlap, and clean resumption of cruising speed once the turn is clear.
