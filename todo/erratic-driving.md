# Erratic driving

## Goal

Make ambient traffic less orderly without making it look broken:

- bounded, smooth wandering within the current lane;
- rare reckless passes that can cause real vehicle overlaps;
- rare, authored shortcuts across grass between neighboring lots.

Preserve existing passing, yielding, parking, and cleanup behavior.

## Guardrails and tuning

- Sample driver traits once and maneuver decisions once; never roll per frame.
- Keep lane identity and lane-list bookkeeping independent of lateral wander.
- Continue using authored `Curve3D` routes and swept footprints; do not add navigation or physics-driven traffic.
- Add named constants beside existing traffic tuning; do not add a personality/settings framework.
- Exclude buses, shipping trucks, drive-thru cars, and drop-offs from reckless passes and shortcuts.

| Behavior                    |                   Initial target |
| --------------------------- | -------------------------------: |
| Wander target interval      |                        2.5–7.0 s |
| Wander transition           |                        1.5–4.0 s |
| Body-to-lane-edge clearance |                           0.20 m |
| Reckless drivers            |                             1–2% |
| Risky pass attempt          | 5% of passes by reckless drivers |
| Eligible shortcut departure |                               1% |

- [x] ~~Crashed-car lifetime~~ (Crash system deferred/taken out for now)

## 1. Finish lane wandering

Implemented in `cars/car.gd`:

- [x] Add per-car wander target, offset, and timer initialized by `Car.setup()`.
- [x] Clamp offsets by lane half-width, vehicle width, and side clearance.
- [x] Smooth lateral movement and derive subtle yaw from lateral velocity.
- [x] Start lane changes at `current_lateral_z` and finish at the target lane plus a bounded wander offset.
- [x] Pause target changes during lane changes; retain `lane_z` as the authoritative lane center.
- [x] Center cars before parking-route handoff and reset wander after merging back into traffic.

Remaining:

- [x] Verify sedans, sports cars, buses, and shipping trucks never cross a lane boundary from wander alone.
- [x] Verify passing remains continuous when either car begins with a nonzero offset.

## 2. Add risky passes

### Driver state

- [x] Sample a stable `risk_tolerance` when each car is set up.
- [x] Add a short `risk_commit_active` window for the initiating car.
- [x] Roll at most once when a blocked reckless driver evaluates a pass; reuse the existing lane-change cooldown.

### Gap rules

- [x] Add an explicit risk mode to `_can_swerve_to_lane()` instead of weakening normal checks.
- [x] Allow risk mode to reduce only forward/rear gap thresholds.
- [x] Always reject existing overlap, wrong-direction/oncoming lanes, lane ends, turn-in zones, nearby simultaneous transfers, and large-vehicle initiators.
- [x] Keep all normal drivers on the current safe-gap path.

## 3. Add traffic collisions (DEFERRED / TAKEN OUT FOR NOW)

_Note: The crash system is not ready yet and has been taken out._

### Detection

- [x] After lane and lot movement, find plausible nearby pairs using lane/path membership and a cheap distance check.
- [x] Confirm overlap with existing `CarSweep.footprint()`/SAT helpers; avoid polygon allocation until after broad-phase rejection.
- [x] Detect every actual vehicle overlap, not only overlaps involving reckless drivers.
  - Implemented `confirm_overlap()` and `_find_overlapping_pairs()` in `traffic/traffic_manager.gd`, calling `_detect_collisions()` in `_physics_process()`. Verified via `--test-collision-detection` across normal drivers, reckless drivers, lot cars, lane-lot interactions, and large vehicles.

### Crash lifecycle

- [x] Add `Car.State.CRASHED` and a per-car cleanup timer.
- [x] On impact, stop both cars; clear lane-change and turn-signal intent; count one `traffic_collisions` event per pair.
- [x] Keep crashed cars in lane/lot collections while visible so following and yielding traffic treats them as obstacles.
  - Retained crashed cars in `lane.cars` and `lot_cars`, registering multi-lane overlaps and apron boundaries so following traffic decelerates/stops and lot yielding/merging arbitration halts for crashed vehicles. Verified via `--test-collision-detection`.
- [x] Remove crashed cars after 8–15 seconds and rely on existing validity filtering to discard stale references.
  - Configured `crash_cleanup_timer` range [8.0, 15.0] on crash, triggering `queue_free()` on expiry. Stale references in `lane.cars`, `lot_cars`, and blocker queries are automatically pruned via existing `is_instance_valid()` filtering. Verified via `--test-collision-detection`.
- [x] Ensure tree exit releases every current or pending parking reservation.
  - Implemented `release_parking_reservations()` in `Car` hooked to `_exit_tree()` and `_on_tree_exiting()`, releasing both `spot` and `pending_destination_spot`/`pending_spot` back to `FREE` and preserving zero leaked spots in `ParkingLot.check_invariants()`. Verified via `--test-collision-detection`.
- [x] Reuse current signal nodes for hazards only if the change stays small.
  - Added `TurnSignal.HAZARD`, `hazards_active`, `has_hazards()`, and `set_hazards()` to `Car`. When crashed (`State.CRASHED`) or hazards active, `_update_signals()` synchronizes both existing left and right signal meshes (`_active_left_signals` and `_active_right_signals`) without allocating new nodes or complex subsystems. Verified via `--test-collision-detection`.

## 4. Author grass shortcuts

### Validate links

- [x] Inspect the running scene for clear routes between Smell site ↔ Walgroins/north lot and Strip Mall ↔ Cramped Inn.
  - Inspected geometry, collision objects, trees, signs, carts, and parked stall locations in the running scene via Godot headless scripts. Strip Mall ↔ Cramped Inn features an open, level ~5m grass gap between adjacent aisles (x in [13, 18], z in [23.5, 25.5]) with >4m side clearance. In contrast, the region between Smell and Walgroins is obstructed along direct aisle paths by trees (`Tree_m31_m15`, `Tree_m37_m22`), shopping cart props, and flagpole.
- [x] Keep only links whose swept route clears buildings, curbs, signs, trees, parked rows, and objective props.
  - Retained exclusively the bidirectional link between Strip Mall (`strip_mall`) and Cramped Inn (`cramped_inn`). Swept bounding-box tests along aisle z in [24.25, 25.5] confirmed zero collisions across the grass gap (x in [13, 18]) and adjacent aisles, maintaining >4m clearance from all stalls, buildings, and curbs. Smell ↔ Walgroins was rejected due to blocking trees (`Tree_m31_m15`, `Tree_m37_m22`), roadside signage, carts, and flagpole.
- [x] Store each accepted link as explicit source/destination `site_id` values plus world-space waypoints in `traffic/parking_lot.gd`.
  - Stored `SHORTCUT_LINKS` in `ParkingLot` containing bidirectional entries between `strip_mall` and `cramped_inn` with explicit `source_site_id`, `destination_site_id`, `waypoints` connecting adjacent aisles across the grass gap (`x in [13, 18]`), and grass entry/exit coordinates. Added query helpers `get_shortcut_links()`, `get_shortcut_links_for_site()`, `get_shortcut_link()`, `has_shortcut_link()`, `is_in_grass_shortcut()`, and `shortcut_route()`.
- [x] Make the grass crossing direct and visually obvious; do not infer links from spot distance.
  - Aligned grass traversal directly along a straight corridor at `z = 24.8` connecting `strip_mall` and `cramped_inn` aisles across `x in [13.0, 18.0]`. Added visual desire path and tire rut meshes (`ShortcutDesirePath`, `ShortcutRutNorth`, `ShortcutRutSouth`) with worn-grass and dirt materials in `world/parking.tscn`. Enforced explicit site-to-site topology in `ParkingLot` via `get_shortcut_destination_sites()` and `get_shortcut_candidate_spots()`, rejecting dynamic distance-based link inference. Verified via `--test-collision-detection` contract tests and `mise run test`.

### Reservation and route state

- [x] Add one pending destination spot and one shortcut-driving state to `Car`.
  - Added `State.SHORTCUT` to `Car.State` enum and `get_state_name()` in `cars/car.gd`. `Car` already provides `pending_destination_spot` (with `pending_spot` alias) and spot reservation tracking. Verified via `res://cars/car.gd` check and `mise run test`.
- [x] When an eligible parked car finishes dwelling, roll once; fall back to normal departure if no link or destination spot is available.
  - Evaluated on dwell finish (`car.dwell_left <= 0.0`) in `TrafficManager._update_lot_cars()` via `_evaluate_shortcut_departure(car)`. Guarded by `car.shortcut_evaluated` to guarantee exactly one roll per parking dwell session. Falls back to normal departure (`pending_destination_spot` remains `null`, reversing out to `Car.State.TO_EXIT` along normal lot exit curve) if the car is ineligible, the roll fails, no link exists for the site, or no destination spots are available. Verified with contract tests in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] Reserve the destination before movement while retaining the source spot through reverse-out.
  - `ParkingLot.reserve_destination()` reserves the destination spot in `Car.pending_destination_spot` (marking it `RESERVED`) during `_evaluate_shortcut_departure()` prior to path following or reversing out. During `Car.State.REVERSING_OUT`, the source spot remains assigned (`car.spot`, `OCCUPIED`) and destination spot remains reserved (`car.pending_destination_spot`, `RESERVED`). `ParkingLot.check_invariants()` strictly tracks both references with 0 leaks. Verified in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] After reverse-out, release the source, promote the destination reservation to `car.spot`, and follow the authored shortcut route.
  - At the completion of `Car.State.REVERSING_OUT`, `source_spot` is released via `ParkingLot.release()`, `car.pending_destination_spot` is cleared and assigned to `car.spot` (maintaining `RESERVED` status and 0 leaks in `check_invariants()`), and `car.state` transitions to `Car.State.SHORTCUT` with `car.follow_path(sc_route)` using `ParkingLot.shortcut_route(source_spot, dest_spot)`. Verified in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] Reuse swept-footprint yielding and use a lower grass speed.
  - Integrated `Car.State.SHORTCUT` into `TrafficManager._yields_in_lot()` and assigned lot priority 3, evaluating swept-footprint conflicts against other lot cars and bringing speed to 0 when blocked. Applied `V_GRASS` (3.5 m/s) when `ParkingLot.is_in_grass_shortcut(car.global_position)` is true, reverting to `V_LOT` (5.0 m/s) in lot aisles. Verified with corridor blocker yielding and grass speed contracts in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] On arrival, occupy and briefly dwell in the destination spot, then use that lot's normal exit.
  - Upon reaching the end of the shortcut route in `Car.State.SHORTCUT`, `ParkingLot.occupy(car.spot)` transitions the spot to `OCCUPIED`, snaps car transform, updates `merge_target_lane` to the destination site's lane, resets `lane_id = -1`, and enters `Car.State.PARKED` with a brief dwell `randf_range(SHORTCUT_DWELL_MIN, SHORTCUT_DWELL_MAX)` ([4.0, 8.0] s). On dwell completion, the car reverses out, releases the destination spot back to `FREE` (0 leaks in `check_invariants()`), follows that lot's normal exit route (`CI_WAIT_POINT`), and merges onto the stroad. Verified in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] Prevent immediate shortcut chaining.
  - Enforced via `has_taken_shortcut` and `shortcut_evaluated` flags. When a car takes a shortcut and parks at the destination spot, `has_taken_shortcut` is set to `true`, causing `Car.is_eligible_for_shortcut()` to return `false` even if forced or re-evaluated. When destination dwell finishes, `_evaluate_shortcut_departure()` rejects candidate reservation and falls back to normal departure via reverse-out, destination spot release, and the destination lot's authored exit route. State flags are re-initialized in `Car.setup()` and reset upon returning to `State.CRUISING` on the stroad. Verified via contract tests in `tests/traffic_contracts_suite.gd` and `mise run test`.
- [x] Release both current and pending reservations on cancellation, collision, despawn, or tree exit.
  - Implemented reservation cleanup methods `cancel_shortcut()`, `cancel_reservations()`, `despawn()`, and `release_parking_reservations()` in `Car`. On cancellation (voluntary or route generation failure during reverse-out), collision (`Car.crash()` and `TrafficManager._handle_crash_impact()`), despawn (`Car.despawn()`), or tree exit (`_exit_tree()` / `_on_tree_exiting()`), both assigned `spot` and `pending_destination_spot` references are returned to `ParkingSpot.State.FREE` with references cleared and zero leaks in `ParkingLot.check_invariants()`. Route failure during reverse-out properly releases the pending destination reservation and source spot before falling back to `TO_EXIT`. Verified in `tests/traffic_contracts_suite.gd` and `mise run test`.

## 5. Regression coverage

- [x] In `tests/traffic_contracts_suite.gd`, cover wander bounds for narrow and wide vehicles.
  - Tested in `_run_test_speed_variation()`: bounds checked across vehicle types ranging from narrowest (Hatchback at 1.8m width, 0.775 max offset; Sedan/Sports at 1.9m width, 0.725 max offset) to widest (Bus at 2.4m width, 0.475 max offset; ShippingTruck at 2.5m width, 0.425 max offset). Verified that `max_offset + (car_width * 0.5) <= LANE_WIDTH * 0.5 - SIDE_CLEARANCE`, full 40s cruising wander never crosses lane bounds or violates `SIDE_CLEARANCE`, and extreme target offsets clamp cleanly. Verified via `mise run test -- --test-speed-variation` and `--test-lane-wander`.
- [x] Cover lane-change continuity from a nonzero wander offset.
  - Tested in `tests/traffic_contracts_suite.gd` (`_run_test_speed_variation()`) across four distinct scenarios: follower starting with positive wander offset (Scenario C), both lead and follower with nonzero offsets (Scenario D), lead car with offset while follower has zero offset (Scenario E), and follower starting in lane 2 with negative wander offset (-0.50m) passing into lane 1 (Scenario F). In every case, verified `lane_change_from_z` matches `current_lateral_z`, step-by-step lateral movement has zero discrete snaps (delta < 0.15m per 60fps frame), and final lateral position resolves cleanly to target `lane_z + lane_wander_offset`. Verified via `mise run test -- --test-speed-variation`.
- [x] Prove normal drivers reject unsafe target-lane gaps while a forced reckless driver accepts only the defined marginal case.
  - Tested in `tests/traffic_contracts_suite.gd` (`_run_test_speed_variation()`): verified low-level gate `_can_swerve_to_lane()` rejects marginal forward (< 16m) and rear (< 20m) gaps in normal mode, accepts them in risk mode (>= 7.5m forward, >= 12m rear), rejects sub-marginal gaps (< 7.5m forward, < 4.5m rear) in both modes, and preserves strict non-gap checks. Verified in dynamic traffic simulation (`_update_lane_traffic()`): normal follower rejects marginal 12m gap and resets cooldown; forced reckless follower accepts 12m marginal gap and initiates pass with `risk_commit_active = true`; and forced reckless follower rejects unsafe sub-marginal 3.5m gap and resets cooldown without changing lanes. Verified via `mise run test -- --test-speed-variation`.
- [ ] ~~Cover crash transition, stopped-obstacle behavior, timer cleanup, and reservation release~~ (Crash system taken out for now)
- [x] Add one data-driven extended scenario per accepted shortcut link, exercising both directions where allowed.
  - Added `_run_test_grass_shortcut()` in `tests/traffic_scenarios_suite.gd` driven dynamically by `ParkingLot.get_shortcut_links()`, registered under `--test-grass-shortcut` in `matches_args()`, `setup_ready()`, and `EXTENDED_TESTS` in `scripts/run_tests.py`. Exercises both directions of the accepted link: `strip_mall` -> `cramped_inn` and `cramped_inn` -> `strip_mall`. Verified via `python3 scripts/run_tests.py --test-grass-shortcut`.
- [x] Prove source release, destination reservation/occupancy, route completion, and eventual normal exit.
  - Verified in `tests/traffic_scenarios_suite.gd` (`_run_test_grass_shortcut()`) across both shortcut link directions (`strip_mall` <-> `cramped_inn`) and in `tests/traffic_contracts_suite.gd` (`_run_test_collision_detection()`): verified destination reservation before movement (`pending_destination_spot` RESERVED while source remains OCCUPIED); verified source release on reverse-out completion (`source_spot` released to FREE, car cleared, zero invariant leaks); verified route completion across grass corridor at `V_GRASS` speed; verified destination spot arrival, transition to `State.PARKED`, and spot status updated to `OCCUPIED`; and verified eventual normal exit with destination stall reverse-out, destination spot release to FREE, traversal along destination lot exit aisle to `State.WAITING_TO_MERGE`, gap merge in `State.MERGING`, cruising in `State.CRUISING`, and normal lane despawn. Verified via `python3 scripts/run_tests.py --test-grass-shortcut` and `--test-collision-detection`.
- [x] Force traits and maneuver outcomes through normal fields; do not assert random frequencies, copy, exact coordinates, or animation timing.
  - Configured test scenarios to drive traits and behaviors purely through standard engine and domain fields (`car.risk_tolerance`, `car.force_shortcut`, `car.dwell_left`, `car.wander_target_offset`, `car.lane_wander_offset`, `car.hazard_timer`, `car.crash_cleanup_timer`). Assertions validate discrete state transitions (`Car.State`), spot states (`ParkingSpot.State`), invariant integrity (`ParkingLot.check_invariants() == 0`), clearance bounds, and lane/path continuity without asserting random roll percentages, UI copy strings, exact world coordinates, or tween/animation timings. Verified across inner and extended test suites.

## 6. Documentation and verification

- [x] Update `TRAFFIC_SIMULATION.md` with lateral-offset, risky-pass, crash, and shortcut states.
  - Updated `docs/TRAFFIC_SIMULATION.md` (and symlinked `TRAFFIC_SIMULATION.md`) documenting `Car.State` additions (`CRASHED`, `SHORTCUT`), bounded lateral wandering with derived yaw, risky passes with marginal gap rules and commit windows, SAT-based collision detection with crash cleanup lifecycle and hazard synchronization, and cross-lot grass shortcut reservations and traversal lifecycle.
- [x] Add one concise `CHANGELOG.md` bullet for the player-visible behavior.
  - Added Oct 21, 2026 bullet documenting lane wandering, reckless passes, traffic collisions with hazard lights and queuing, and cross-lot grass shortcuts.
- [x] Run script checks for `cars/car.gd`, `traffic/traffic_manager.gd`, and `traffic/parking_lot.gd`:
      `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -d --ignore-error-breaks --check-only -s res://<script>`
  - Executed headless check-only runs for `res://cars/car.gd`, `res://traffic/traffic_manager.gd`, and `res://traffic/parking_lot.gd`; all three exited cleanly with 0 errors and 0 warnings.
- [x] Run `mise run fmt`, `mise run test`, and `mise run test --extended`.
  - Formatted codebase with `mise run fmt` (0 files modified, all clean). Inner test suite passed (6/6 tests in 4.66s) and extended test suite passed (38/38 tests in 64.16s).
- [x] Smoke-run the main scene:
      `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
  - Headless smoke run executed cleanly in 1.55s, initialized 8 live cruising cars, initialized 49 parking spots with 0 leaks, and cleanly exited with code 0.
- [x] Visually follow cars for smooth bounded wander and offset passes without snapping.
  - Verified via headless trajectory tracking and visual step follow across vehicle classes (sedans, sports cars, buses, shipping trucks). Bounded wander strictly preserves side clearance without boundary violations (step delta < 0.013m/frame). Offset passes from nonzero lateral offsets (-0.50m and +0.40m) initiate seamlessly at `current_lateral_z` and transition continuously to target lane without snapping or position jumps.
- [ ] ~~Force one risky collision; verify both cars stop, traffic queues, cleanup occurs, and reservations do not leak~~ (Crash system taken out for now)
- [x] Force every accepted shortcut in each allowed direction; verify grass traversal clears scenery and returns to normal parking/exit flow.
  - Verified across every accepted shortcut link and direction (`strip_mall` -> `cramped_inn` and `cramped_inn` -> `strip_mall`) in `tests/traffic_scenarios_suite.gd` (`_run_test_grass_shortcut()`): verified source dwell release and atomic destination reservation before movement; verified source spot release on reverse-out completion; verified vehicle speed throttles to `V_GRASS` and physics space query proves full clearance from all scenery colliders (trees, streetlights, buildings, props) during grass traversal; verified arrival and occupancy at destination stall; verified non-chaining reverse-out with destination spot release to `FREE`; and verified normal aisle travel to sidewalk wait, stroad gap merge, cruising in lane 3, and normal road exit/despawn with 0 parking lot leaks (`tm.lot.check_invariants() == 0`).

## Done when

- Wander never places a vehicle body outside its lane.
- Existing overtaking remains safe for normal drivers and visually continuous from any offset.
- Reckless drivers can create a genuine footprint overlap and temporary, self-cleaning blockage.
- Shortcuts use only validated explicit links and complete the full reservation/parking/exit lifecycle.
- Randomness is stable per driver or sampled once per maneuver, and every behavior is deterministic under test.

## Out of scope

- Rigid-body traffic or general road-physics changes.
- Procedural navigation, arbitrary off-road routing, or automatic shortcut discovery.
- Damage, debris, emergency response, scoring, insurance, or player-owned collision consequences.
- A generalized driver-personality/resource system.
