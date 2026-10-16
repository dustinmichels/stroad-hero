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
- [ ] Verify: seamless handoff into lane 0 with position delta < 0.05 m and rotation delta < 1°; ghost ensures lane-0 followers brake; car cruises to lane end and despawns cleanly

### 4.4 Merge gap acceptance and timing

[Plan section](PARKING_AND_ERRANDS.md#merge-gap-acceptance-waitingtomerge)

- [ ] Constant `T_MERGE_GAP := 3.0`
- [ ] Add `_can_merge(car: Car) -> bool` in `TrafficManager`:
  - Merge window check: no lane-0 car currently within `[61 - car_length - 2, 71]`
  - Upstream check: every upstream lane-0 car (`d < 61`) has `(61 - d) / max(lane_speed, 0.1) > T_MERGE_GAP`
- [ ] Gate the `WAITING_TO_MERGE → MERGING` transition on `_can_merge()`
- [ ] Track merge wait duration per car and update `stats["max_merge_wait"]`
- [ ] In `TrafficDebug`: draw the merge window on lane 0 while any car is in `WAITING_TO_MERGE`
- [ ] Verify: waiting cars hold position while lane-0 cars pass, merge only when a valid gap opens, and upstream traffic yields appropriately

### 4.5 Phase 4 verification and soak

- [ ] 10-minute soak run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --quit-after 36000 -- --seed=42`
  - `errands_completed ≈ errands_assigned - errands_dropped_lot_full - active_errands`
  - `leaked = 0` (zero reservation leaks)
  - `max_merge_wait` is tracked and finite
- [ ] In-game behavior: observe full vehicle lifecycle (lane cruising → decision → approach braking → driveway turn → stall park → dwell → reverse out → exit aisle → sidewalk wait → gap merge → lane cruising → despawn)
- [ ] Mats interaction: Mats is stopped by car waiting across sidewalk, and dies if hit by car pulling out into merge

## Phase 5: lot conflicts

[Plan section](PARKING_AND_ERRANDS.md#lot-traffic-conflicts)

### 5.1 Aisle conflict detection and priority yielding

- [ ] `find_blocker(car: Car) -> Car` in `TrafficManager`:
  - Scan other `lot_cars` and lane-0 ghosts
  - Transform positions into `car` frame (heading signed by speed direction to handle reversing)
  - `lookahead = max(4.0, (speed * speed) / (2.0 * BRAKE_ACCELERATION) + 3.0)`
  - Blocker condition: `0.0 < forward < lookahead` and `abs(lateral) < (width_A + width_B) / 2.0 + 0.3`
- [ ] Reverse-start safety check:
  - A `PARKED` car with dwell expired delays transitioning to `REVERSING_OUT` while any moving lot car is within 8.0 m along the aisle (`abs(car.global_position.x - spot.x) < 8.0`)
- [ ] Priority arbitration:
  - Priority order: `TO_SPOT > TO_EXIT > REVERSING_OUT`
  - When car A and car B mutually block each other, only the lower-priority car yields (sets target speed to 0.0)
- [ ] Verify: lower-priority car stops for higher-priority car in the aisle and resumes once cleared; parked car does not reverse into passing aisle traffic

### 5.2 Deadlock watchdog and debug HUD

[Plan section](PARKING_AND_ERRANDS.md#debug-overlay-build-in-phase-1-toggle-f3)

- [ ] Deadlock watchdog in `TrafficManager`:
  - Track `blocked_time` and current blocker for each waiting lot car
  - If mutual blocking occurs at equal priority for > 4.0 s: car with higher `get_instance_id()` ignores the other for 1.5 s
  - Print each firing with car IDs, states, and coordinates; track `stats["watchdog_fires"]` and `stats["max_stuck_time"]`
- [ ] Debug overlay HUD in `TrafficDebug`:
  - When F3 overlay is active, show HUD line with free/reserved/occupied stall counts, `errands_dropped_lot_full`, `watchdog_fires`, and `max_stuck_time`
- [ ] Verify: staged equal-priority conflict triggers watchdog at 4.0s, tiebreaker cleanly resolves deadlock, stats increment; HUD line reflects live counts

### 5.3 Phase 5 verification and high-load soak

- [ ] Run 10-minute stress soak with elevated errand volume (`P_ERRAND = 0.6`):
  - Test with seed 42, seed 101, and seed 999
  - `max_stuck_time < 30.0`
  - `watchdog_fires` stays low (rare and logged, no unhandled deadlocks)
  - `leaked = 0`
  - `errands_completed` steadily advances
- [ ] Reset `P_ERRAND` back to 0.3

## Wrap-up

### 6.1 Documentation and cleanup

- [ ] Remove any temporary `/tmp` test scripts
- [ ] Update `docs/PARKING_AND_ERRANDS.md` where implementation differs from original draft (blocker `sync_to_physics = false`, jump height/roof clearance notes, filleted corner radius clamping)
- [ ] Update `README.md`: document vehicle visits to Walgroins & Taco Hell, and list debug controls (F3 overlay, F4 debug car spawn)
- [ ] Smoke validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only` on all scripts
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit` exits cleanly

## Deferred (not in this checklist)

- [ ] Left turns in and out for eastbound traffic
- [ ] Lane changes into lane 0 for errand cars
- [ ] Drivers get out and walk to the store
- [ ] Multi-stop errands
- [ ] Second driveway or lot (waypoint graph)
- [ ] Stall size classes, drive-thru, loading zones
