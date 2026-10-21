# Traffic Simulation Design

## Recommendation

Model traffic as a **logical lane network** that is mostly independent of the 3D world. Keep its topology 2D-like, but embed every lane in 3D.

The core vehicle location should be:

```text
lane ID + longitudinal distance along the lane
```

The simulation uses lane IDs, distances, connections, signals, and right-of-way. The renderer converts a vehicle's lane and distance into a 3D position and rotation by sampling a spline.

This is simpler and more reliable than asking physics-driven cars to discover roads, intersections, and traffic laws from 3D geometry.

```mermaid
flowchart LR
    Stops[Ordered stops] --> Route[Strategic route planner]
    Route --> Maneuver[Upcoming lane and turn choices]
    Network[Lane network] --> Route
    Signals[Signals and right-of-way] --> Driver
    Maneuver --> Driver[Tactical driver]
    Nearby[Nearby vehicles] --> Driver
    Driver --> Motion[Longitudinal and lane-change motion]
    Motion --> State["lane ID, distance, speed, lateral offset"]
    State --> Sample[Sample 3D lane spline + lateral offset]
    Sample --> Visual[3D vehicle transform]
```

## System Layers

### 1. Road and lane data

Represent individual lanes rather than only road centerlines.

A lane needs roughly:

```text
Lane
  id
  road_id
  direction
  length
  speed_limit
  vehicle_classes
  centerline_3d
  left_neighbor
  right_neighbor
  outgoing_connections[]
  stop_line_distance
```

A connection describes a legal movement between lanes:

```text
LaneConnection
  from_lane
  to_lane
  movement: straight | left | right | merge | u_turn
  path_3d
  priority_rule
  controlling_signal
  conflict_zones[]
```

Intersections use explicit connections instead of open areas where cars improvise. This supports:

- Turn restrictions
- Dedicated turn lanes
- One-way streets
- Merges and lane drops
- Traffic signals
- Stop and yield signs
- Bridges and tunnels
- Vehicle-class restrictions

### 2. Strategic route planning

Each driver receives an ordered itinerary:

```text
Depot -> Store -> School -> Home
```

For each current destination:

1. Snap the destination to a lane or designated stopping area.
2. Find a route through the lane graph.
3. Convert the route into an ordered sequence of lanes and connections.
4. Advance to the next stop after arrival.
5. Replan only when necessary.

A* is sufficient initially. Edge cost can begin as travel time:

$$
\text{cost} = \frac{\text{lane length}}{\text{speed limit}} + \text{turn penalty}
$$

Possible later additions:

- Estimated congestion
- Left-turn penalties
- Toll or road-class preferences
- Vehicle restrictions
- Temporary closures
- Driver-specific preferences

Do not run pathfinding every simulation frame. Cache routes and replan when the destination, road availability, or route deviation changes.

### 3. Tactical driving and states

The route says where a driver intends to go. A separate tactical controller decides what the driver can safely do now.

Vehicle states (`Car.State`):

```text
CRUISING          - Stroad lane following with car-following and bounded lateral wander
APPROACHING       - Centering and preparing to enter parking lot entrance path
TO_SPOT           - Navigating lot aisles to reserved parking stall
PARKED            - Dwelling in stall with engine off / hazard idle
REVERSING_OUT     - Backing out of stall into aisle before forward departure
TO_EXIT           - Following aisle path to lot apron / merge point
WAITING_TO_MERGE  - Yielding at stroad entry apron for a gap in mainline traffic
MERGING           - Blending from lot exit path into target stroad lane
DRIVE_THRU        - Following queued drive-thru lane and order/pickup windows
SHORTCUT          - Traversing authored cross-lot grass corridor to adjacent site
```

Each update examines only local information:

- Lead vehicle and gap
- Target-lane availability
- Distance to the stop line
- Current traffic-signal phase
- Required intersection movement
- Conflicting vehicles or reserved intersection space
- Desired lane for the upcoming turn

Keep route planning and tactical driving separate. A route may instruct a left turn, while the tactical controller decides to wait, change lanes early, or replan if the turn becomes unavailable.

### 4. Vehicle motion and 3D presentation

Kinematic movement drives standard traffic rather than full rigid-body vehicle physics.

Authoritative simulation state:

```text
lane_id                  - Current lane index (or -1 if path-following)
lane_distance            - Distance along current lane centerline
speed                    - Longitudinal speed (m/s)
acceleration             - Longitudinal acceleration rate
current_lateral_z        - Current lateral world coordinate across lane
lane_wander_offset       - Bounded lateral displacement from lane center
is_changing_lanes        - True while executing lane-change transition
lane_change_progress     - Normalized [0, 1] interpolation progress
lane_change_from_z       - Starting lateral coordinate for lane change
lane_change_to_z         - Target lateral coordinate for lane change
current_connection       - Active lane connection or intersection path
state                    - Discrete Car.State
```

Derived presentation state:

```text
position = lane_spline.position_at(lane_distance) + lateral_offset_vector
forward  = lane_spline.tangent_at(lane_distance) + derived_yaw_from_lateral_rate
up       = road_surface_normal
rotation = orientation(forward, up)
```

During a lane change, blend smoothly from `lane_change_from_z` (preserving current lateral position without snapping) to target `lane_change_to_z`. During a turn or lot movement, follow the authored spline path.

## Lateral Offset and Lane Wandering

Vehicles naturally wander laterally within their lane to appear organic and non-robotic without violating lane boundaries:

- **Offset Bounds:** Each vehicle calculates its maximum lateral wander:
  $$ \text{max\_offset} = \max\left(0, \frac{\text{LANE\_WIDTH}}{2} - \frac{\text{car\_width}}{2} - \text{SIDE\_CLEARANCE}\right) $$
  where `LANE_WIDTH = 3.75 m` and `SIDE_CLEARANCE = 0.20 m`.
- **Vehicle Variation:** Narrower vehicles (hatchbacks, sedans) have wider allowable wander ranges (e.g. ±0.725–0.775 m), while wider vehicles (buses, shipping trucks at 2.4–2.5 m width) have tightly restricted wander (±0.425–0.475 m).
- **Target Selection:** Wander targets are sampled on an interval of 2.5–7.0 seconds, transitioning smoothly over 1.5–4.0 seconds using smoothstep interpolation.
- **Visual Yaw:** Lateral velocity applies a subtle yaw adjustment so the car body tilts slightly into the drift.
- **Lane Change Continuity:** Lane changes begin at `current_lateral_z` rather than snapping to the lane centerline, ensuring continuous visual trajectories regardless of initial wander. Wandering is paused during lane changes and resumes once settled in the destination lane.
- **Transitions:** Cars center (`lane_wander_offset = 0`) before entering parking routes (`APPROACHING`) and re-initialize wandering when returning to `CRUISING` on the stroad.

## Risky Passes and Reckless Driving

To create organic traffic friction, a small fraction of drivers exhibit aggressive behavior:

- **Driver Trait:** A stable `risk_tolerance` is sampled once per vehicle during setup. Drivers with `risk_tolerance >= 0.8` (~1.5% of passenger vehicles) are reckless. Buses, shipping trucks, and delivery vehicles are never reckless.
- **Pass Evaluation:** When blocked behind a slower vehicle, reckless drivers evaluate lane-change opportunities using an explicit risk mode in `_can_swerve_to_lane()`:
  - Normal drivers require safe longitudinal margins: $\ge 16\text{ m}$ forward gap, $\ge 20\text{ m}$ rear gap.
  - Risk mode permits marginal gaps: $\ge 7.5\text{ m}$ forward gap, $\ge 12\text{ m}$ rear gap.
  - Sub-marginal gaps ($< 7.5\text{ m}$ forward or $< 4.5\text{ m}$ rear) are rejected unconditionally.
- **Invariants:** Risk mode never relaxes core safety invariants: wrong-direction lanes, lane ends, turn-in zones, existing overlaps, and simultaneous adjacent maneuvers remain strictly prohibited.
- **Commit Window:** Once initiated, the reckless driver enters a brief `risk_commit_active` window (1.0 s) with normal lane-change cooldowns, preventing rapid oscillating swerves.

## Grass Shortcuts Between Lots

Eligible vehicles may bypass road traffic by taking authored shortcuts across grass between neighboring commercial lots:

- **Authored Links:** Shortcuts exist only as explicit, authored site-to-site topology (`SHORTCUT_LINKS` in `traffic/parking_lot.gd`), connecting adjacent parking aisles across validated grass corridors (e.g. Strip Mall `strip_mall` $\leftrightarrow$ Cramped Inn `cramped_inn` at $z = 24.8\text{ m}$, $x \in [13, 18]\text{ m}$).
- **Corridor Clearance:** Corridors must maintain $>4\text{ m}$ lateral clearance from buildings, curbs, signs, trees, and props, complemented by visual desire paths and tire ruts.
- **Eligibility & Evaluation:** Upon completing parking dwell (`dwell_left <= 0.0`), an eligible car rolls once (1% chance). Ineligible vehicles (buses, trucks, drive-thru patrons, or cars that already took a shortcut) and failed rolls proceed to normal road exits.
- **Reservation Lifecycle:**
  1. _Pre-reservation:_ The candidate destination stall is reserved (`ParkingSpot.State.RESERVED`) in `car.pending_destination_spot`.
  2. _Reverse-out:_ The vehicle reverses out of its stall (`State.REVERSING_OUT`). The source spot remains `OCCUPIED` and the destination remains `RESERVED`.
  3. _Transition to Shortcut:_ On reverse-out completion, the source spot is released to `FREE`, the destination spot is promoted to `car.spot`, and the vehicle enters `State.SHORTCUT`.
  4. _Grass Traversal:_ Follows the authored spline at reduced grass speed $V_{\text{GRASS}} = 3.5\text{ m/s}$ (compared to $V_{\text{LOT}} = 5.0\text{ m/s}$), yielding to conflicting lot traffic using swept-footprint checks.
  5. _Arrival & Dwell:_ Reaching the destination stall transitions the vehicle to `State.PARKED` with a brief dwell (4.0–8.0 s), setting `has_taken_shortcut = true` to prohibit shortcut chaining.
  6. _Normal Exit:_ After dwell, the car reverses out and departs via the destination lot's standard apron exit onto the stroad.
- **Cancellation Safety:** If aborted, cancelled, or despawned, both `spot` and `pending_destination_spot` are released immediately to prevent allocation leaks.

## 2D Logic and 3D Geometry

Use a **2D logical topology with 3D geometry**.

A purely 2D simulation works when all roads are flat and never overlap. It becomes ambiguous with:

- Bridges
- Tunnels
- Multilevel interchanges
- Parking structures
- Steep roads
- Ramps passing over other lanes

The lane graph avoids this ambiguity because connectivity is explicit. Two splines can cross visually without being connected.

| Concern                     | Representation                          |
| --------------------------- | --------------------------------------- |
| Route connectivity          | Directed lane graph                     |
| Route cost and traffic laws | Graph metadata                          |
| Vehicle progress            | Lane ID plus scalar distance            |
| Lateral displacement        | Scalar wander offset within lane bounds |
| Collision ordering          | One-dimensional order within each lane  |
| Intersections               | Connections and conflict zones          |
| Elevation and banking       | 3D lane spline                          |
| Vehicle visuals             | Sampled 3D transform + lateral offset   |

## Following and Stopping

Use a car-following model that produces desired acceleration based on:

- Current speed
- Desired speed
- Gap to the lead vehicle
- Relative speed
- Distance to a virtual obstacle

Represent stop lines, red lights, occupied intersections, and route destinations as **virtual lead vehicles with zero speed**. The same braking logic can then handle most stopping behavior.

```text
desired_speed = min(
    speed_limit,
    curve_safe_speed,
    lead_vehicle_safe_speed,
    stop_line_safe_speed
)

acceleration = clamp(
    response_gain * (desired_speed - current_speed),
    max_braking,
    max_acceleration
)
```

## Ordered Stops and Errands

Model trips as explicit tasks:

```text
Trip
  stops[]
  current_stop_index

Stop
  target_zone
  acceptable_approach_lanes[]
  dwell_duration
  arrival_radius
  activity_type
```

A stop is complete when the vehicle:

1. Reaches an acceptable stopping lane or parking space.
2. Enters the arrival zone.
3. Slows below the arrival threshold.
4. Remains for the required dwell duration.

The itinerary then advances to the next stop or lot exit.
