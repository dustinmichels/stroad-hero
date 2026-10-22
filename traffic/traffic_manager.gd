class_name TrafficManager
extends Node3D

const PASSENGER_CAR_SCENE_PATH := "res://cars/passenger_car.tscn"
const BUS_SCENE_PATH := "res://cars/bus.tscn"
const TAXI_SCENE_PATH := "res://cars/taxi.tscn"
const TRUCK_SCENE_PATH := "res://cars/truck.tscn"
const VAN_SCENE_PATH := "res://cars/van.tscn"
const SHIPPING_TRUCK_SCENE_PATH := "res://cars/shipping_truck.tscn"
const PoliceSirenScript := preload("res://cars/police_siren.gd")

static var _passenger_car_scene: PackedScene
static var _bus_scene: PackedScene
static var _taxi_scene: PackedScene
static var _truck_scene: PackedScene
static var _van_scene: PackedScene
static var _shipping_truck_scene: PackedScene

static var PassengerCarScene: PackedScene:
	get:
		if _passenger_car_scene == null:
			_passenger_car_scene = load(PASSENGER_CAR_SCENE_PATH)
		return _passenger_car_scene

static var BusScene: PackedScene:
	get:
		if _bus_scene == null:
			_bus_scene = load(BUS_SCENE_PATH)
		return _bus_scene

static var TaxiScene: PackedScene:
	get:
		if _taxi_scene == null:
			_taxi_scene = load(TAXI_SCENE_PATH)
		return _taxi_scene

static var TruckScene: PackedScene:
	get:
		if _truck_scene == null:
			_truck_scene = load(TRUCK_SCENE_PATH)
		return _truck_scene

static var VanScene: PackedScene:
	get:
		if _van_scene == null:
			_van_scene = load(VAN_SCENE_PATH)
		return _van_scene

static var ShippingTruckScene: PackedScene:
	get:
		if _shipping_truck_scene == null:
			_shipping_truck_scene = load(SHIPPING_TRUCK_SCENE_PATH)
		return _shipping_truck_scene


## Loads every car scene and passenger body, and synthesizes the siren wail. Run behind the loading
## screen: the first mid-game spawn of a rare type otherwise stalls a physics tick for 4–13 ms.
static func _load_car_scenes() -> void:
	for scene: PackedScene in [
		PassengerCarScene, BusScene, TaxiScene, TruckScene, VanScene, ShippingTruckScene
	]:
		assert(scene != null)
	PassengerCar.load_body_scenes()
	PoliceSirenScript.get_wail_stream()


class Lane:
	var id: int
	var z: float
	var direction: float  # +1.0 for Eastbound, -1.0 for Westbound
	var start_x: float
	var length: float
	var min_speed: float
	var max_speed: float
	var spawn_interval_min: float
	var spawn_interval_max: float
	var spawn_timer: float = 0.0
	var cars: Array[Car] = []
	## This tick's PATH lot cars on or merging into this lane (see _bucket_lot_cars_by_lane).
	var lot_path_cars: Array[Car] = []
	# Scratch arrays reused by _update_lane_traffic; spare_cars and cars swap every tick.
	var valid_cars: Array[Car] = []
	var shouldered_cars: Array[Car] = []
	var spare_cars: Array[Car] = []
	## Lane distances of the bus stop poles along this lane, ascending.
	var bus_stops: PackedFloat32Array = []

	func _init(
		p_id: int,
		p_z: float,
		p_dir: float,
		p_start_x: float,
		p_len: float,
		p_min_spd: float,
		p_max_spd: float,
		p_int_min: float,
		p_int_max: float
	) -> void:
		id = p_id
		z = p_z
		direction = p_dir
		start_x = p_start_x
		length = p_len
		min_speed = p_min_spd
		max_speed = p_max_spd
		spawn_interval_min = p_int_min
		spawn_interval_max = p_int_max
		spawn_timer = randf_range(0.2, 1.0)

	func distance_at(x: float) -> float:
		return (x - start_x) * direction

	## Whether lane-distance span [back_d, front_d] reaches into a bus stop's curb zone.
	func overlaps_bus_stop(back_d: float, front_d: float) -> bool:
		for pole_d in bus_stops:
			if front_d >= pole_d - BUS_STOP_ZONE_BEHIND and back_d <= pole_d + BUS_STOP_ZONE_AHEAD:
				return true
		return false

	func forward() -> Vector3:
		return Vector3(direction, 0, 0)

	const LANE_WIDTH := 3.75
	const MARGIN := 1.0

	func overlaps(car: Car) -> bool:
		if car == null or not is_instance_valid(car):
			return false
		var pos: Vector3 = car.global_position
		var half_l: float = car.car_length * 0.5
		var half_w: float = car.car_width * 0.5
		var h: Vector3 = (
			car.get_heading() if car.has_method("get_heading") else Vector3(car.direction, 0, 0)
		)
		var w := Vector3(-h.z, 0.0, h.x)

		var c1 := pos + h * half_l + w * half_w
		var c2 := pos + h * half_l - w * half_w
		var c3 := pos - h * half_l + w * half_w
		var c4 := pos - h * half_l - w * half_w

		var min_cz := minf(minf(c1.z, c2.z), minf(c3.z, c4.z))
		var max_cz := maxf(maxf(c1.z, c2.z), maxf(c3.z, c4.z))

		var lane_half_w := LANE_WIDTH * 0.5 + MARGIN
		if max_cz < (z - lane_half_w) or min_cz > (z + lane_half_w):
			return false

		var min_cx := minf(minf(c1.x, c2.x), minf(c3.x, c4.x))
		var max_cx := maxf(maxf(c1.x, c2.x), maxf(c3.x, c4.x))

		var x_end := start_x + direction * length
		var lane_min_x := minf(start_x, x_end) - MARGIN
		var lane_max_x := maxf(start_x, x_end) + MARGIN

		if max_cx < lane_min_x or min_cx > lane_max_x:
			return false

		return true


signal initial_traffic_ready

var is_initial_traffic_ready: bool = false
var lanes: Array[Lane] = []
var lot: ParkingLot = null
var lot_cars: Array[Car] = []
var debug_overlay: Node3D = null
var taco_hell_drive_thru_path: Curve3D = null
var booger_king_drive_thru_path: Curve3D = null
var cramped_inn_dropoff_path: Curve3D = null
## Lane 3 merge paths (Booger King drive-thru, strip mall, Cramped Inn), one per wait point.
var lane3_merge_paths: Array[Curve3D] = []
var _physics_tick_count: int = 0
var _watchdog_ignores: Dictionary[int, Dictionary] = {}  # int (car_instance_id) -> Dictionary { "target_id": int, "timer": float }
var _sweep_cache: Dictionary[int, Dictionary] = {}  # car instance id -> _car_sweep() result
## car id -> { other id -> [mine sweep rev, theirs sweep rev, candidate_conflict_distance] }.
## A sweep rev covers every input of the candidate, so a hit is exact; cleared every 60 ticks.
var _pair_cache: Dictionary[int, Dictionary] = {}
var _reach_cache: Dictionary[int, float] = {}  # car instance id -> max reach
## Per-tick x-sorted index over the blocker candidates (see _index_blocker_candidates).
var _indexed_candidates: Array[Car] = []
var _cand_x := PackedFloat32Array()  # tick-start x of each candidate, ascending
var _cand_order := PackedInt32Array()  # original candidate index for each _cand_x entry
var _cand_max_reach := 0.0
var _pending_transfers: Array[Dictionary] = []
## True only inside the _physics_process lane loop, while Lane.lot_path_cars is current.
var _lane_buckets_valid := false
var traffic_stops: Array[TrafficStop] = []
const MAX_ACTIVE_HEADLAMPS: int = 12
var profile_find_blocker: bool = false
## --profile-traffic section timers: summed/max usec per PROFILE_SECTIONS entry over the window.
const PROFILE_WINDOW_TICKS := 600
const PROFILE_SECTIONS: PackedStringArray = [
	"stops",
	"lane_traffic",
	"lane_spawning",
	"transfers",
	"lot_cars",
	"despawn",
	"bookkeeping",
	"total"
]
var _profile_sum := PackedInt64Array()
var _profile_max := PackedInt64Array()
var _profile_ticks := 0
var _profile_fb_calls := 0
var _profile_fb_usec := 0
var _profile_conflicts := 0
var _profile_pair_hits := 0
var _profile_cands := 0
var _profile_reach := 0
var _was_lights_on: bool = false

var stats: Dictionary = {
	"cars_spawned": 0,
	"live_cars": 0,
	"spots_total": 0,
	"spots_free": 0,
	"spots_reserved": 0,
	"spots_occupied": 0,
	"errands_assigned": 0,
	"errands_completed": 0,
	"errands_dropped_lot_full": 0,
	"active_errands": 0,
	"max_stuck_time": 0.0,
	"max_merge_wait": 0.0,
	"watchdog_fires": 0,
	"stuck_despawns": 0,
	"leaked": 0,
	"find_blocker_calls": 0,
	"find_blocker_usec_total": 0,
	"find_blocker_usec_max": 0,
	"candidates_checked": 0,
	"reach_passed": 0,
	"conflicts_evaluated": 0,
	"pair_cache_hits": 0,
}
const P_ERRAND := 0.90
const P_FRONTAGE_ERRAND := 0.3  # extra frontage-shop roll for lane-3 cars without an errand
const DECISION_D := 18.0
const TURN_D := 53.0
const V_TURN := 6.5
const A_COMFORT := 4.0
const MIN_SPAWN_HEADWAY := 14.0  # meters needed before spawning another car in lane
const SAFE_FOLLOWING_GAP := 6.0  # meters
const RISKY_PASS_PROBABILITY := 0.05
const SHORTCUT_DEPARTURE_PROBABILITY := 0.25
const SIDEWALK_SHORTCUT_PROBABILITY := 0.15
const SHORTCUT_DWELL_MIN := 4.0
const SHORTCUT_DWELL_MAX := 8.0
const SWERVE_MIN_GAP_AHEAD := 16.0
const SWERVE_RISKY_MIN_GAP_AHEAD := 7.5
const SWERVE_LEAD_MARGIN := 6.0
const SWERVE_RISKY_LEAD_MARGIN := 2.0
const SWERVE_MIN_GAP_BEHIND_BASE := 9.0
const SWERVE_RISKY_MIN_GAP_BEHIND_BASE := 4.5
const SWERVE_MIN_GAP_BEHIND_SPEED_FACTOR := 0.8
const SWERVE_RISKY_MIN_GAP_BEHIND_SPEED_FACTOR := 0.4
const SWERVE_CLOSING_SPEED_FACTOR := 2.5
const SWERVE_RISKY_CLOSING_SPEED_FACTOR := 1.2
const SWERVE_CLOSING_SPEED_BASE := 8.0
const SWERVE_RISKY_CLOSING_SPEED_BASE := 4.0
const BRAKE_ACCELERATION := 25.0
const MOTOR_ACCELERATION := 18.0
const V_LOT := 7.0
const V_PARK := 2.6
const V_GRASS := 4.0
const T_MERGE_GAP := 3.0
const V_DRIVE_THRU := 4.0
const DECISION_D_BK := 15.0
const TURN_D_BK := 50.0
const DECISION_D_SM := 49.0
const TURN_D_SM := 84.0
const DECISION_D_CI := 94.0
const TURN_D_CI := 129.0
const DECISION_D_SMELL := 79.0
const TURN_D_SMELL := 114.0
const DECISION_D_FRONTAGE := 121.75
const TURN_D_FRONTAGE := 156.75
const MAX_DRIVE_THRU_CAPACITY := 5
const TACO_DT_ORDER_DIST := 38.5
const TACO_DT_PICKUP_DIST := 75.1
const BK_DT_ORDER_DIST := 75.5
const BK_DT_PICKUP_DIST := 77.0
const SWEEP_STEP := 0.5  # meters between sampled footprints along a car's route
const SWEEP_SIDE_MARGIN := 0.15  # lateral clearance added to a car's projected footprints
const SWEEP_TIE_EPS := 0.25  # route-conflict distances closer than this count as a tie
const SWEEP_INTENT_EXTRA := 4.0  # meters past the lookahead used to settle who crosses first
const CANDIDATE_X_SLACK := 2.0  # meters; > one tick of lot-car travel, pads the candidate x-window
const REVERSE_CLEAR_TRAVEL := 1.0  # meters of another car's route a back-out route must avoid
const PATROL_PROBABILITY := 0.75  # police spawned on the stroad patrol instead of running errands
const MAX_TRAFFIC_STOPS := 2  # at most one per curb lane
const STOP_SWERVE_BIAS := 1.0  # in-lane swerve away from a pulled-over car
const STOP_SWERVE_LOOKAHEAD := 35.0
const STOP_SLOW_LOOKAHEAD := 80.0
const STOP_MOVE_OVER_LOOKAHEAD := 60.0
const V_PASS_STOP := 9.0  # speed when passing a traffic stop in its lane
const BUS_STOP_GROUP := &"bus_stops"
const BUS_STOP_ZONE_BEHIND := 30.0  # curb kept clear behind a stop pole for a bus pulling in
const BUS_STOP_ZONE_AHEAD := 6.0
## Parked cars leave only while their site stays at least this full (incoming reservations count).
const PARKING_TARGET_FILL := 0.5
const SEED_FILL_MIN := 0.6
const SEED_FILL_MAX := 0.85
## Minimum stay after parking before a car considers leaving.
const PARK_DWELL_MIN := 3.0
const PARK_DWELL_MAX := 8.0
## A parked car leaves only while at most 0..this many cars are already leaving its site.
const MAX_LEAVE_TOLERANCE := 3
## A car standing still this long with no reason to (parked, dwelling, traffic stop) is
## removed so a conflict the yielding rules cannot resolve doesn't back up the stroad.
const STUCK_DESPAWN_TIME := 30.0
## Stroad spawning pauses while this many cars (all states, parked included) are alive.
const MAX_LIVE_CARS := 110

var staged_initial_spawn: bool = true
## Occupancy floor for parked departures; test fixtures zero it so lone cars can leave.
var parking_fill_floor: float = PARKING_TARGET_FILL
## Per-site counts refreshed each lot tick: spots, cars staying parked, cars leaving.
var _site_spots: Dictionary = {}
var _site_staying: Dictionary = {}
var _site_leaving: Dictionary = {}
var stuck_despawn_time: float = STUCK_DESPAWN_TIME
var live_car_count: int = 0


func set_random_seed(seed_val: int) -> void:
	seed(seed_val)


func populate_immediately() -> void:
	_pre_populate_traffic()
	_seed_parked_cars()
	is_initial_traffic_ready = true
	initial_traffic_ready.emit()


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	lot = ParkingLot.new()
	add_child(lot)
	debug_overlay = TrafficDebug.new(self)
	add_child(debug_overlay)
	taco_hell_drive_thru_path = ParkingLot.taco_hell_drive_thru_route()
	booger_king_drive_thru_path = ParkingLot.booger_king_drive_thru_route()
	cramped_inn_dropoff_path = ParkingLot.cramped_inn_dropoff_route()
	lane3_merge_paths = [
		ParkingLot.booger_king_merge_route(),
		ParkingLot.south_merge_route(&"strip_mall"),
		ParkingLot.south_merge_route(&"cramped_inn"),
		ParkingLot.frontage_merge_route(),
	]
	_setup_lanes()
	_collect_bus_stops()
	if staged_initial_spawn:
		_spawn_initial_traffic_staged()
	else:
		populate_immediately()
	if GameState.instance:
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
	for arg in OS.get_cmdline_user_args():
		if arg == "--profile-traffic" or arg == "--profile-blocker":
			profile_find_blocker = true
	for arg in OS.get_cmdline_args():
		if arg == "--profile-traffic" or arg == "--profile-blocker":
			profile_find_blocker = true


static func _is_test_mode() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-") or arg.begins_with("--bench-"):
			return true
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-") or arg.begins_with("--bench-"):
			return true
	return false


func _setup_lanes() -> void:
	var test_mode: bool = _is_test_mode()
	var wb_start_x: float = 70.0 if test_mode else 170.0
	var wb_len: float = 195.0 if test_mode else 295.0
	var eb_start_x: float = -95.0 if test_mode else -120.0
	var eb_len: float = 270.0 if test_mode else 295.0
	# 6 lanes matching the stroad markings; lanes run into tunnels at each edge
	# Lane 0: Westbound outer (driveway turns & merges)
	lanes.append(Lane.new(0, -9.375, -1.0, wb_start_x, wb_len, 16.0, 21.0, 1.8, 3.4))
	# Lane 1: Westbound middle (fast through-traffic)
	lanes.append(Lane.new(1, -5.625, -1.0, wb_start_x, wb_len, 21.0, 27.0, 1.4, 2.6))
	# Lane 2: Westbound inner (express speedway)
	lanes.append(Lane.new(2, -1.875, -1.0, wb_start_x, wb_len, 25.0, 32.0, 1.0, 2.0))
	# Lane 3: Eastbound outer (driveway turns & merges)
	lanes.append(Lane.new(3, 9.375, 1.0, eb_start_x, eb_len, 16.0, 21.0, 1.8, 3.4))
	# Lane 4: Eastbound middle (fast through-traffic)
	lanes.append(Lane.new(4, 5.625, 1.0, eb_start_x, eb_len, 21.0, 27.0, 1.4, 2.6))
	# Lane 5: Eastbound inner (express speedway)
	lanes.append(Lane.new(5, 1.875, 1.0, eb_start_x, eb_len, 25.0, 32.0, 1.0, 2.0))


## Each bus stop pole (BUS_STOP_GROUP) serves the curb lane on its side of the stroad.
func _collect_bus_stops() -> void:
	for lane in lanes:
		lane.bus_stops.clear()
	for node in get_tree().get_nodes_in_group(BUS_STOP_GROUP):
		var pole: Vector3 = (node as Node3D).global_position
		var lane: Lane = lanes[0] if pole.z < 0.0 else lanes[3]
		var d := lane.distance_at(pole.x)
		if d > 0.0 and d < lane.length:
			lane.bus_stops.append(d)
	for lane in lanes:
		lane.bus_stops.sort()


func _pre_populate_traffic() -> void:
	# Seed 3-4 cars per lane across the full road length
	for lane in lanes:
		var d := randf_range(16.0, 28.0)
		while d < lane.length - 15.0:
			_spawn_car_at(lane, d)
			d += randf_range(28.0, 42.0)


func _get_spots_by_lot() -> Dictionary:
	var groups: Dictionary = {}
	if lot == null:
		return groups
	for spot in lot.spots:
		var key: StringName = spot.serves[0] if not spot.serves.is_empty() else spot.site_id
		if not groups.has(key):
			var arr: Array[ParkingSpot] = []
			groups[key] = arr
		groups[key].append(spot)
	return groups


func _pick_seeded_spots() -> Array[ParkingSpot]:
	var result: Array[ParkingSpot] = []
	var groups := _get_spots_by_lot()
	for lot_key in groups:
		var spots_in_lot: Array = groups[lot_key]
		if spots_in_lot.is_empty():
			continue
		var n: int = spots_in_lot.size()
		var count := clampi(
			roundi(n * randf_range(SEED_FILL_MIN, SEED_FILL_MAX)), 1, maxi(1, n - 1)
		)
		var candidates: Array = spots_in_lot.duplicate()
		candidates.shuffle()
		for spot in candidates.slice(0, count):
			result.append(spot)
	return result


func _seed_parked_cars() -> void:
	for spot in _pick_seeded_spots():
		_seed_parked_car_at(spot)


## Starts a parked car's stay: a short minimum dwell, then it leaves when its site allows.
func _begin_parked_stay(car: Car, dwell: float) -> void:
	car.state = Car.State.PARKED
	car.dwell_left = dwell
	car.leave_tolerance = randi_range(0, MAX_LEAVE_TOLERANCE)


func _is_leaving_lot(car: Car) -> bool:
	return (
		car.state == Car.State.REVERSING_OUT
		or car.state == Car.State.TO_EXIT
		or car.state == Car.State.WAITING_TO_MERGE
		or car.state == Car.State.MERGING
	)


## Tallies each site's spots, cars staying (parked or inbound), and cars on their way out.
func _refresh_site_occupancy() -> void:
	_site_spots.clear()
	_site_staying.clear()
	_site_leaving.clear()
	if lot == null:
		return
	for spot in lot.spots:
		var site := ParkingLot.lot_group(spot)
		_site_spots[site] = _site_spots.get(site, 0) + 1
		var holder: Car = spot.car if is_instance_valid(spot.car) else null
		var leaving := holder != null and holder.spot == spot and _is_leaving_lot(holder)
		if not spot.is_free() and not leaving:
			_site_staying[site] = _site_staying.get(site, 0) + 1
	for car in lot_cars:
		if is_instance_valid(car) and _is_leaving_lot(car):
			_site_leaving[car.departing_site] = _site_leaving.get(car.departing_site, 0) + 1


## A parked car leaves only if few cars are already leaving its site and the site stays full enough.
func _may_leave(car: Car) -> bool:
	if car.spot == null:
		return true
	var site := ParkingLot.lot_group(car.spot)
	if _site_leaving.get(site, 0) > car.leave_tolerance:
		return false
	var floor_count := floori(_site_spots.get(site, 0) * parking_fill_floor)
	return _site_staying.get(site, 0) - 1 >= floor_count


func _count_departure(car: Car) -> void:
	var site := ParkingLot.lot_group(car.spot) if car.spot != null else &""
	car.departing_site = site
	_site_leaving[site] = _site_leaving.get(site, 0) + 1
	_site_staying[site] = _site_staying.get(site, 0) - 1


func _seed_parked_car_at(spot: ParkingSpot) -> void:
	var site_id := ParkingLot.lot_group(spot)
	var allow_sports: bool = site_id != &"dorf"
	var car: Car = PassengerCarScene.instantiate()
	var chosen_type: Car.CarType = PassengerCar.pick_passenger_car_type(allow_sports)
	car.car_type = chosen_type
	car.speed = 0.0
	car.desired_speed = 0.0
	add_child(car)
	car.lane_id = -1
	car.motion = Car.Motion.PATH
	var site_cfg := ParkingLot.get_site_cfg(site_id)
	car.merge_target_lane = site_cfg.get("lane_id", 0)
	_begin_parked_stay(car, randf_range(0.0, PARK_DWELL_MAX))
	car.global_transform = spot.transform
	car.reset_physics_interpolation()
	lot.reserve(spot, car)
	lot.occupy(spot)
	var dest: StringName = spot.serves[0] if not spot.serves.is_empty() else site_id
	car.errand = Errand.new(dest)
	car.had_errand = true
	lot_cars.append(car)
	stats["cars_spawned"] += 1


const DISALLOWED_DORF_LOT_CAR_TYPES: Array[Car.CarType] = ParkingLot.DISALLOWED_DORF_LOT_CAR_TYPES


static func is_car_type_allowed_in_dorf_lot(type: Car.CarType) -> bool:
	return ParkingLot.is_car_type_allowed_in_dorf_lot(type)


static func is_car_allowed_in_dorf_lot(car: Car) -> bool:
	return ParkingLot.is_car_allowed_in_dorf_lot(car)


func _spawn_initial_traffic_staged() -> void:
	const BATCH_SIZE: int = 4
	var count := 0
	_load_car_scenes()

	for lane in lanes:
		var d := randf_range(16.0, 28.0)
		while d < lane.length - 15.0:
			_spawn_car_at(lane, d)
			count += 1
			if count >= BATCH_SIZE:
				count = 0
				await get_tree().process_frame
				if not is_inside_tree():
					return
			d += randf_range(28.0, 42.0)

	for spot in _pick_seeded_spots():
		_seed_parked_car_at(spot)
		count += 1
		if count >= BATCH_SIZE:
			count = 0
			await get_tree().process_frame
			if not is_inside_tree():
				return

	is_initial_traffic_ready = true
	initial_traffic_ready.emit()


func _physics_process(delta: float) -> void:
	if profile_find_blocker:
		_physics_process_profiled(delta)
		return
	_update_traffic_stops(delta)
	_bucket_lot_cars_by_lane()
	for lane in lanes:
		_update_lane_traffic(lane, delta)
		_update_lane_spawning(lane, delta)
	_lane_buckets_valid = false
	_apply_pending_lane_transfers()
	_update_lot_cars(delta)
	_despawn_stalled_car(delta)
	_end_physics_tick()


## Same tick as _physics_process, with per-section timings. Only runs under --profile-traffic,
## so production ticks never pay for the clock reads.
func _physics_process_profiled(delta: float) -> void:
	var t := PackedInt64Array()
	t.resize(PROFILE_SECTIONS.size())
	var t0 := Time.get_ticks_usec()
	var mark := t0
	_update_traffic_stops(delta)
	t[0] = Time.get_ticks_usec() - mark
	mark = Time.get_ticks_usec()
	_bucket_lot_cars_by_lane()
	t[1] = Time.get_ticks_usec() - mark
	for lane in lanes:
		mark = Time.get_ticks_usec()
		_update_lane_traffic(lane, delta)
		var mid := Time.get_ticks_usec()
		_update_lane_spawning(lane, delta)
		var done := Time.get_ticks_usec()
		t[1] += mid - mark
		t[2] += done - mid
	_lane_buckets_valid = false
	mark = Time.get_ticks_usec()
	_apply_pending_lane_transfers()
	var after_transfers := Time.get_ticks_usec()
	_update_lot_cars(delta)
	var after_lot := Time.get_ticks_usec()
	_despawn_stalled_car(delta)
	var after_despawn := Time.get_ticks_usec()
	_end_physics_tick()
	var end := Time.get_ticks_usec()
	t[3] = after_transfers - mark
	t[4] = after_lot - after_transfers
	t[5] = after_despawn - after_lot
	t[6] = end - after_despawn
	t[7] = end - t0
	_record_profile_tick(t)


func _record_profile_tick(t: PackedInt64Array) -> void:
	if _profile_sum.is_empty():
		_profile_sum.resize(PROFILE_SECTIONS.size())
		_profile_max.resize(PROFILE_SECTIONS.size())
		_profile_fb_calls = stats["find_blocker_calls"]
		_profile_fb_usec = stats["find_blocker_usec_total"]
		_profile_conflicts = stats["conflicts_evaluated"]
		_profile_pair_hits = stats["pair_cache_hits"]
		_profile_cands = stats["candidates_checked"]
		_profile_reach = stats["reach_passed"]
	for i in t.size():
		_profile_sum[i] += t[i]
		_profile_max[i] = maxi(_profile_max[i], t[i])
	_profile_ticks += 1
	if _profile_ticks < PROFILE_WINDOW_TICKS:
		return
	var parts := PackedStringArray()
	for i in PROFILE_SECTIONS.size():
		(
			parts
			. append(
				(
					"%s=%.3f/%.3f"
					% [
						PROFILE_SECTIONS[i],
						_profile_sum[i] / 1000.0 / _profile_ticks,
						_profile_max[i] / 1000.0,
					]
				)
			)
		)
	var fb_calls: int = stats["find_blocker_calls"] - _profile_fb_calls
	var fb_usec: int = stats["find_blocker_usec_total"] - _profile_fb_usec
	var conflicts: int = stats["conflicts_evaluated"] - _profile_conflicts
	var pair_hits: int = stats["pair_cache_hits"] - _profile_pair_hits
	var cands: int = stats["candidates_checked"] - _profile_cands
	var reach_passed: int = stats["reach_passed"] - _profile_reach
	var lane_cars := 0
	for lane in lanes:
		lane_cars += lane.cars.size()
	print(
		(
			"TM_PROFILE: ticks=%d lane_cars=%d lot_cars=%d ms avg/max %s find_blocker=%.1f calls/tick %.3f ms/tick cand=%.1f reach=%.1f /call pair_cache=%d/%d hits"
			% [
				_profile_ticks,
				lane_cars,
				lot_cars.size(),
				" ".join(parts),
				float(fb_calls) / _profile_ticks,
				fb_usec / 1000.0 / _profile_ticks,
				float(cands) / maxi(fb_calls, 1),
				float(reach_passed) / maxi(fb_calls, 1),
				pair_hits,
				conflicts,
			]
		)
	)
	_profile_sum.clear()
	_profile_max.clear()
	_profile_ticks = 0


func _end_physics_tick() -> void:
	_physics_tick_count += 1
	if _physics_tick_count % 6 == 0:
		_update_headlamp_lod()
	if _physics_tick_count % 60 == 0 and lot != null:
		var free_count := 0
		var reserved_count := 0
		var occupied_count := 0
		for spot in lot.spots:
			match spot.state:
				ParkingSpot.State.FREE:
					free_count += 1
				ParkingSpot.State.RESERVED:
					reserved_count += 1
				ParkingSpot.State.OCCUPIED:
					occupied_count += 1
		stats["spots_free"] = free_count
		stats["spots_reserved"] = max(stats["spots_reserved"], reserved_count)
		stats["spots_occupied"] = max(stats["spots_occupied"], occupied_count)
		stats["leaked"] = max(stats["leaked"], lot.check_invariants())


func _evaluate_shortcut_departure(car: Car) -> void:
	if car.shortcut_evaluated:
		return
	car.shortcut_evaluated = true
	if car.spot == null:
		return
	if not _try_grass_shortcut(car):
		_try_sidewalk_shortcut(car)


func _try_grass_shortcut(car: Car) -> bool:
	if not car.is_eligible_for_shortcut():
		return false
	var roll: bool = (
		car.force_shortcut or (not _is_test_mode() and randf() < SHORTCUT_DEPARTURE_PROBABILITY)
	)
	if not roll:
		return false
	var parking_lot: ParkingLot = lot if lot != null else car.spot.lot
	if parking_lot == null:
		return false
	var candidates := ParkingLot.get_shortcut_candidate_spots(car.spot, parking_lot.spots)
	if candidates.is_empty():
		return false
	var target_spot: ParkingSpot = (
		candidates[0] if car.force_shortcut else candidates[randi() % candidates.size()]
	)
	parking_lot.reserve_destination(target_spot, car)
	car.has_taken_shortcut = true
	return true


func _try_sidewalk_shortcut(car: Car) -> void:
	if (
		car.car_type == Car.CarType.BUS
		or car.car_type == Car.CarType.SHIPPING_TRUCK
		or car.car_type == Car.CarType.TRUCK
	):
		return
	var roll: bool = (
		car.force_sidewalk_shortcut
		or (not _is_test_mode() and randf() < SIDEWALK_SHORTCUT_PROBABILITY)
	)
	if roll:
		car.sidewalk_crossing_x = ParkingLot.sidewalk_crossing_x(car.spot)


func _update_lot_cars(delta: float) -> void:
	_reach_cache.clear()
	if _physics_tick_count % 60 == 0:
		_pair_cache.clear()
		var dead_cids: Array[int] = []
		for cid in _sweep_cache:
			if instance_from_id(cid) == null:
				dead_cids.append(cid)
		for cid in dead_cids:
			_sweep_cache.erase(cid)
	var candidates := _build_blocker_candidates()
	_index_blocker_candidates(candidates)
	var expired_ignores: Array[int] = []
	for cid in _watchdog_ignores.keys():
		_watchdog_ignores[cid]["timer"] -= delta
		if _watchdog_ignores[cid]["timer"] <= 0.0 or instance_from_id(cid) == null:
			expired_ignores.append(cid)
	for cid in expired_ignores:
		_watchdog_ignores.erase(cid)

	_refresh_site_occupancy()
	var surviving_cars: Array[Car] = []
	for car in lot_cars:
		if not is_instance_valid(car):
			continue
		if car.state == Car.State.TO_SPOT:
			if car.turn_signal != Car.TurnSignal.NONE:
				if (
					(car.lane_id == 0 or car.merge_target_lane == 0)
					and car.global_position.z <= -12.5
				):
					car.set_turn_signal(Car.TurnSignal.NONE)
				elif (
					(car.lane_id == 3 or car.merge_target_lane == 3)
					and car.global_position.z >= 12.5
				):
					car.set_turn_signal(Car.TurnSignal.NONE)
			var yielding := _update_car_yielding(car, delta, candidates)
			var target_speed := 0.0 if yielding else V_LOT
			if not yielding and car.path != null:
				var length := car.path.get_baked_length()
				var remaining := length - car.path_distance
				if remaining <= 5.0:
					target_speed = V_PARK
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := car.advance_path(delta)
			if (
				arrived
				or (car.path != null and car.path.get_baked_length() - car.path_distance <= 0.02)
			):
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				if car.spot != null:
					if lot != null:
						lot.occupy(car.spot)
					elif car.spot.lot != null:
						car.spot.lot.occupy(car.spot)
				_begin_parked_stay(car, randf_range(PARK_DWELL_MIN, PARK_DWELL_MAX))
				car.lane_id = -1
				car.update_presentation()
				car.reset_physics_interpolation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == Car.State.DRIVE_THRU:
			if car.turn_signal != Car.TurnSignal.NONE:
				if (
					(car.merge_target_lane == 0 and car.global_position.z <= -12.5)
					or (car.merge_target_lane == 3 and car.global_position.z >= 12.5)
				):
					car.set_turn_signal(Car.TurnSignal.NONE)
			var yielding := _update_car_yielding(car, delta, candidates)
			var dest: StringName = car.errand.destination if car.errand != null else &""
			var site_id := (
				ParkingLot.get_site_for_destination(dest)
				if dest != &""
				else (&"booger_king" if car.merge_target_lane == 3 else &"taco_hell_drive_thru")
			)
			var order_dist := ParkingLot.get_drive_thru_order_dist(site_id)
			var pickup_dist := ParkingLot.get_drive_thru_pickup_dist(site_id)
			if (
				order_dist > 0.0
				and not car.dt_order_done
				and car.path_distance >= order_dist - 1.5
				and car.path_distance <= order_dist + 3.0
			):
				car.dt_order_done = true
				car.dt_dwell_timer = randf_range(1.2, 2.5)
			elif (
				not car.dt_pickup_done
				and car.path_distance >= pickup_dist - 1.5
				and car.path_distance <= pickup_dist + 3.0
			):
				car.dt_pickup_done = true
				if car.errand != null and car.errand.is_dropoff():
					car.dt_order_done = true
					car.dt_dwell_timer = (
						car.errand.dwell_time
						if car.errand.dwell_time > 0.0
						else randf_range(4.0, 8.0)
					)
				else:
					car.dt_dwell_timer = randf_range(1.2, 2.5)

			var target_speed := 0.0
			if car.dt_dwell_timer > 0.0:
				car.dt_dwell_timer -= delta
				target_speed = 0.0
			elif yielding:
				var b := car.current_blocker
				if b != null and b.speed > 0.5:
					var gap := (
						(
							b.path_distance
							- car.path_distance
							- (car.car_length + b.car_length) * 0.5
						)
						if (car.path != null and b.path == car.path)
						else 0.0
					)
					# Creep behind a leader on the same path; the loop also crosses itself,
					# so a blocker far ahead along the path is a crossing car, not a leader.
					if gap > 2.5 and gap <= _lookahead(car) + SWEEP_STEP:
						target_speed = minf(b.speed, V_DRIVE_THRU)
					else:
						target_speed = 0.0
				else:
					target_speed = 0.0
			else:
				target_speed = V_DRIVE_THRU
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := car.advance_path(delta)
			if (
				arrived
				or (car.path != null and car.path.get_baked_length() - car.path_distance <= 0.05)
			):
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				car.state = Car.State.WAITING_TO_MERGE
				car.merge_wait_time = 0.0
				car.update_presentation()
				car.reset_physics_interpolation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == Car.State.PARKED:
			car.current_blocker = null
			car.blocked_time = 0.0
			car.dwell_left -= delta
			if car.dwell_left <= 0.0 and _may_leave(car):
				_evaluate_shortcut_departure(car)
				if can_reverse_out(car):
					var rev_route := _reverse_out_route(car)
					if rev_route != null:
						_count_departure(car)
						car.state = Car.State.REVERSING_OUT
						car.follow_path(rev_route, true)
						car.speed = -V_PARK
						car.desired_speed = -V_PARK
					else:
						push_error(
							"TrafficManager: Missing reverse route for parked car %s" % car.name
						)
			surviving_cars.append(car)
		elif car.state == Car.State.REVERSING_OUT:
			var yielding := _update_car_yielding(car, delta, candidates)
			var target_speed := 0.0 if yielding else -V_PARK
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if absf(car.speed) > absf(target_speed) else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := false
			if not yielding or absf(car.speed) > 0.0:
				arrived = car.advance_path(delta)
			else:
				car.update_presentation()
				car._update_blocker_layer()
			if arrived:
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				if car.pending_destination_spot != null:
					var source_spot: ParkingSpot = car.spot
					var dest_spot: ParkingSpot = car.pending_destination_spot
					var sc_route: Curve3D = (
						ParkingLot.shortcut_route(source_spot, dest_spot)
						if source_spot != null
						else null
					)
					if sc_route != null and sc_route.point_count >= 2:
						car.pending_destination_spot = null
						var parking_lot: ParkingLot = (
							lot
							if lot != null
							else (source_spot.lot if source_spot != null else null)
						)
						if source_spot != null:
							if parking_lot != null:
								parking_lot.release(source_spot)
							elif source_spot.lot != null:
								source_spot.lot.release(source_spot)
							car.spot = null
						car.spot = dest_spot
						car.state = Car.State.SHORTCUT
						car.follow_path(sc_route)
						car.desired_speed = V_LOT
					else:
						# Shortcut cancelled or route unavailable: release pending destination reservation
						var dest_lot: ParkingLot = (
							dest_spot.lot if dest_spot != null and dest_spot.lot != null else lot
						)
						if dest_spot != null:
							if dest_lot != null:
								dest_lot.release(dest_spot)
							else:
								dest_spot.state = ParkingSpot.State.FREE
								dest_spot.car = null
						car.pending_destination_spot = null
						var exit_path: Curve3D = null
						if lot != null and source_spot != null:
							exit_path = ParkingLot.exit_route(source_spot)
						elif source_spot != null and source_spot.lot != null:
							exit_path = ParkingLot.exit_route(source_spot)
						if source_spot != null:
							if lot != null:
								lot.release(source_spot)
							elif source_spot.lot != null:
								source_spot.lot.release(source_spot)
							car.spot = null
						if exit_path != null:
							car.state = Car.State.TO_EXIT
							car.follow_path(exit_path)
							car.desired_speed = V_LOT
						else:
							push_error("TrafficManager: Missing exit route on cancelled shortcut")
				else:
					var exit_path: Curve3D = null
					if car.spot != null and not is_nan(car.sidewalk_crossing_x):
						exit_path = ParkingLot.sidewalk_exit_route(
							car.spot, car.sidewalk_crossing_x
						)
					elif car.spot != null and (lot != null or car.spot.lot != null):
						exit_path = ParkingLot.exit_route(car.spot)
					if car.spot != null:
						if lot != null:
							lot.release(car.spot)
						elif car.spot.lot != null:
							car.spot.lot.release(car.spot)
						car.spot = null
					if exit_path != null:
						car.state = Car.State.TO_EXIT
						car.follow_path(exit_path)
						car.desired_speed = V_LOT
					else:
						push_error("TrafficManager: Missing exit route for reversing car")
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == Car.State.SHORTCUT:
			var yielding := _update_car_yielding(car, delta, candidates)
			var base_speed := (
				V_GRASS if ParkingLot.is_in_grass_shortcut(car.global_position) else V_LOT
			)
			var target_speed := 0.0 if yielding else base_speed
			if not yielding and car.path != null:
				var length := car.path.get_baked_length()
				var remaining := maxf(0.0, length - car.path_distance)
				var smooth_target := sqrt(2.0 * A_COMFORT * remaining)
				target_speed = minf(target_speed, smooth_target)
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := car.advance_path(delta)
			if (
				arrived
				or (
					car.path != null
					and car.path.get_baked_length() - car.path_distance <= 0.02
					and car.speed <= Car.STOP_SPEED
				)
			):
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				if car.spot != null:
					var parking_lot: ParkingLot = (
						lot if lot != null else (car.spot.lot if car.spot != null else null)
					)
					if parking_lot != null:
						parking_lot.occupy(car.spot)
					elif car.spot.lot != null:
						car.spot.lot.occupy(car.spot)
					car.global_transform = car.spot.transform
					var dest_site := ParkingLot.lot_group(car.spot)
					var site_cfg := ParkingLot.get_site_cfg(dest_site)
					car.merge_target_lane = site_cfg.get("lane_id", 0)
				_begin_parked_stay(car, randf_range(SHORTCUT_DWELL_MIN, SHORTCUT_DWELL_MAX))
				car.lane_id = -1
				car.has_taken_shortcut = true
				car.shortcut_evaluated = true
				car.update_presentation()
				car.reset_physics_interpolation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == Car.State.TO_EXIT:
			var yielding := _update_car_yielding(car, delta, candidates)
			var target_speed := 0.0 if yielding else V_LOT
			if not yielding and car.path != null:
				var length := car.path.get_baked_length()
				var remaining := maxf(0.0, length - car.path_distance)
				var smooth_target := sqrt(2.0 * A_COMFORT * remaining)
				target_speed = minf(target_speed, smooth_target)
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := car.advance_path(delta)
			if (
				arrived
				or (
					car.path != null
					and car.path.get_baked_length() - car.path_distance <= 0.02
					and car.speed <= Car.STOP_SPEED
				)
			):
				if car.path != null:
					car.path_distance = car.path.get_baked_length()
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				car.state = Car.State.WAITING_TO_MERGE
				car.merge_wait_time = 0.0
				car.update_presentation()
				car.reset_physics_interpolation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == Car.State.WAITING_TO_MERGE:
			car.current_blocker = null
			car.blocked_time = 0.0
			if _can_merge(car):
				stats["max_merge_wait"] = maxf(stats["max_merge_wait"], car.merge_wait_time)
				car.state = Car.State.MERGING
				car.lane_id = car.merge_target_lane
				var m_route := ParkingLot.merge_path(car.merge_target_lane, car.global_position.x)
				car.follow_path(m_route)
				car.desired_speed = V_TURN
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
			else:
				car.merge_wait_time += delta
				stats["max_merge_wait"] = maxf(stats["max_merge_wait"], car.merge_wait_time)
				car.speed = 0.0
				car.desired_speed = 0.0
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
		elif car.state == Car.State.MERGING:
			car.current_blocker = null
			car.blocked_time = 0.0
			var target_speed := V_TURN
			car.desired_speed = target_speed
			var accel: float = (
				BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
			)
			car.speed = move_toward(car.speed, target_speed, accel * delta)
			var arrived := car.advance_path(delta)
			if (
				arrived
				or (car.path != null and car.path_distance >= car.path.get_baked_length() - 0.05)
			):
				var target_lane_id := car.merge_target_lane
				var target_lane: Lane = (
					lanes[target_lane_id] if lanes.size() > target_lane_id else null
				)
				car.motion = Car.Motion.LANE
				car.lane_id = target_lane_id
				if target_lane != null:
					car.lane_z = target_lane.z
					car.direction = target_lane.direction
					car.start_x = target_lane.start_x
					car.lane_length = target_lane.length
					car.lane_distance = target_lane.distance_at(car.global_position.x)
					car.desired_speed = calculate_car_desired_speed(target_lane, car)
					if not target_lane.cars.has(car):
						target_lane.cars.append(car)
				else:
					car.lane_z = -5.6
					car.direction = -1.0
					car.start_x = 70.0
					car.lane_length = 140.0
					car.lane_distance = (70.0 - car.global_position.x)
					car.desired_speed = 20.0
				car.errand = null
				car.lane_change_cooldown = 4.0
				car.state = Car.State.CRUISING
				car.has_taken_shortcut = false
				car.shortcut_evaluated = false
				car.sidewalk_crossing_x = NAN
				car.path = null
				car.current_blocker = null
				car.blocked_time = 0.0
				car.update_presentation()
				car.reset_physics_interpolation()
				car._update_blocker_layer()
				# Removed from lot_cars by omitting from surviving_cars
			else:
				surviving_cars.append(car)
	lot_cars = surviving_cars
	_check_deadlock_watchdog()


func _is_ignoring(car: Car, other: Car) -> bool:
	if car == null or other == null:
		return false
	var cid := car.get_instance_id()
	if _watchdog_ignores.has(cid):
		var entry: Dictionary = _watchdog_ignores[cid]
		if entry.get("timer", 0.0) > 0.0:
			var oid := other.get_instance_id()
			if entry.get("target_id", 0) == oid:
				return true
			if entry.has("targets") and entry["targets"].has(oid):
				return true
	return false


func find_blocker(car: Car, candidates: Array[Car] = []) -> Car:
	if not profile_find_blocker:
		return _find_blocker_impl(car, candidates)

	var t0 := Time.get_ticks_usec()
	var result := _find_blocker_impl(car, candidates)
	var elapsed := Time.get_ticks_usec() - t0
	stats["find_blocker_calls"] += 1
	stats["find_blocker_usec_total"] += elapsed
	if elapsed > stats["find_blocker_usec_max"]:
		stats["find_blocker_usec_max"] = elapsed
	return result


func _build_blocker_candidates() -> Array[Car]:
	var candidates: Array[Car] = []
	var seen: Dictionary = {}
	for other in lot_cars:
		if is_instance_valid(other) and other.state != Car.State.PARKED:
			seen[other.get_instance_id()] = true
			candidates.append(other)
	for lane in lanes:
		if lane != null:
			for ghost in lane.cars:
				if is_instance_valid(ghost) and ghost.motion == Car.Motion.PATH:
					var id := ghost.get_instance_id()
					if not seen.has(id):
						seen[id] = true
						candidates.append(ghost)
	return candidates


## Sorts this tick's candidates by tick-start x so _find_blocker_impl scans only an
## x-window. Reaches are cached here, so the window bound matches the reach test.
func _index_blocker_candidates(candidates: Array[Car]) -> void:
	_indexed_candidates = candidates
	_cand_max_reach = 0.0
	var n := candidates.size()
	var keys: Array[Vector2] = []
	keys.resize(n)
	for i in n:
		var c := candidates[i]
		keys[i] = Vector2(c.global_position.x, i)
		_cand_max_reach = maxf(_cand_max_reach, _get_car_reach(c))
	keys.sort()
	_cand_x.resize(n)
	_cand_order.resize(n)
	for k in n:
		_cand_x[k] = keys[k].x
		_cand_order[k] = int(keys[k].y)


func _get_car_reach(c: Car) -> float:
	var cid := c.get_instance_id()
	if _reach_cache.has(cid):
		return _reach_cache[cid]
	var look := CarSweep.lookahead(c)
	var horizon := look + SWEEP_INTENT_EXTRA
	if c.state == Car.State.REVERSING_OUT and c.path != null:
		horizon = maxf(horizon, c.path_distance)
	var r := horizon + c.car_length
	_reach_cache[cid] = r
	return r


func _find_blocker_impl(car: Car, candidates: Array[Car] = []) -> Car:
	if car == null or not is_instance_valid(car):
		return null

	var candidate_list := candidates
	if candidate_list.is_empty():
		candidate_list = _build_blocker_candidates()
	var my_pos := car.global_position
	var my_reach := _get_car_reach(car)
	var mine: Dictionary = {}
	var closest_blocker: Car = null
	var min_dist: float = INF
	var lo := 0
	var hi := candidate_list.size()
	var indexed := is_same(candidate_list, _indexed_candidates)
	if indexed:
		# Superset of the pairwise reach test; the slack covers cars that moved
		# earlier in this tick's loop since the index was built.
		var w := my_reach + _cand_max_reach + CANDIDATE_X_SLACK
		lo = _cand_x.bsearch(my_pos.x - w)
		hi = _cand_x.bsearch(my_pos.x + w, false)
	var best_i := -1
	for k in range(lo, hi):
		var i: int = _cand_order[k] if indexed else k
		var other := candidate_list[i]
		if other == car or not is_instance_valid(other):
			continue
		if other.state == Car.State.PARKED:
			continue
		# Fast spatial partition / rejection: opposite sides of stroad
		var other_pos := other.global_position
		if (my_pos.z * other_pos.z < 0.0) and (absf(my_pos.z) > 4.0 or absf(other_pos.z) > 4.0):
			continue
		if profile_find_blocker:
			stats["candidates_checked"] += 1
		if _is_ignoring(car, other):
			continue
		var reach := my_reach + _get_car_reach(other)
		if my_pos.distance_squared_to(other_pos) > reach * reach:
			continue
		if profile_find_blocker:
			stats["reach_passed"] += 1
		if mine.is_empty():
			mine = _car_sweep(car)
		var theirs := _car_sweep(other)
		if profile_find_blocker:
			stats["conflicts_evaluated"] += 1
		var dist := _conflict_distance(car, mine, other, theirs)
		# Ties go to the earliest candidate in list order (stable blocker choice).
		if dist < min_dist or (dist == min_dist and i < best_i):
			min_dist = dist
			best_i = i
			closest_blocker = other
	return closest_blocker


func _lookahead(car: Car) -> float:
	return CarSweep.lookahead(car)


static func lookahead(car: Car) -> float:
	return CarSweep.lookahead(car)


## Footprints a car covers: index 0 is its body now, the rest are its body at
## SWEEP_STEP intervals along its upcoming route (curved path or straight heading),
## widened by SWEEP_SIDE_MARGIN. A reversing car claims its whole remaining back-out
func _car_sweep(car: Car) -> Dictionary:
	return CarSweep.car_sweep(car, _sweep_cache)


## Appends footprints at SWEEP_STEP intervals from path distance `from` over `travel`
## meters (negative = backward), stopping at the path end; dists gets travel so far.
static func _append_path_footprints(
	rects: Array[PackedVector2Array],
	dists: Array[float],
	path: Curve3D,
	from: float,
	travel: float,
	half_l: float,
	half_w: float
) -> void:
	CarSweep.append_path_footprints(rects, dists, path, from, travel, half_l, half_w)


static func _footprint(
	pos: Vector3, heading: Vector3, half_l: float, half_w: float
) -> PackedVector2Array:
	return CarSweep.footprint(pos, heading, half_l, half_w)


## Separating-axis test for two rectangles from _footprint.
static func _footprints_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return CarSweep.footprints_overlap(a, b)


## Cars that run the lot yielding logic; others (merging, waiting, lane cars) never stop for us.
func _yields_in_lot(car: Car) -> bool:
	return (
		car.state == Car.State.TO_SPOT
		or car.state == Car.State.TO_EXIT
		or car.state == Car.State.REVERSING_OUT
		or car.state == Car.State.DRIVE_THRU
		or car.state == Car.State.SHORTCUT
	)


## Tie-break rank when two cars reach a shared area at the same distance.
func _lot_priority(s: Car.State) -> int:
	match s:
		Car.State.TO_SPOT:
			return 3
		Car.State.SHORTCUT:
			return 3
		Car.State.TO_EXIT:
			return 2
		Car.State.DRIVE_THRU:
			return 3
		_:
			return 0


## Right-of-way arbitration when two cars have a soft conflict at (first_mine, first_theirs).
func _has_lot_priority(car: Car, other: Car, first_mine: float, first_theirs: float) -> bool:
	if not _yields_in_lot(other):
		return false
	if first_theirs < first_mine - SWEEP_TIE_EPS:
		return false
	if first_mine < first_theirs - SWEEP_TIE_EPS:
		return true
	var p_car := _lot_priority(car.state)
	var p_other := _lot_priority(other.state)
	if p_car != p_other:
		return p_car > p_other
	return car.get_instance_id() < other.get_instance_id()


## Travel distance at which `car` must stop for `other`, or INF if it may proceed.
## Hard conflict (within car's braking lookahead): car's route runs into other's
## current body, or into the whole remaining route of a car backing out
## (can_reverse_out cleared that route, so the reversing car owns it until done).
## Soft conflict: the routes overlap within their intent horizons and other reaches
## the shared area first (ties: _lot_priority, then instance id); car then stops
## once that area is within its lookahead. The soft rule is symmetric, so exactly
## one car of a pair proceeds, and the one that waits does so before its body is
## in the other's way.
func _conflict_distance(car: Car, mine: Dictionary, other: Car, theirs: Dictionary) -> float:
	var c := _candidate_conflict(car, mine, other, theirs)
	if c.x == INF:
		return INF
	if c.y < 0.0:
		return c.x
	return INF if _has_lot_priority(car, other, c.x, c.y) else c.x


## CarSweep.candidate_conflict_distance, reused while neither car's sweep changed
## (stopped cars in a jam hit this every tick). Not shared with the reverse query:
## the candidate is asymmetric (hard check, lookahead, and index ranges are per-side).
func _candidate_conflict(car: Car, mine: Dictionary, other: Car, theirs: Dictionary) -> Vector2:
	var mine_rev: int = mine["rev"]
	var theirs_rev: int = theirs["rev"]
	var cid := car.get_instance_id()
	var row: Variant = _pair_cache.get(cid)
	if row == null:
		row = {}
		_pair_cache[cid] = row
	var oid := other.get_instance_id()
	var entry: Variant = row.get(oid)
	if entry != null and entry[0] == mine_rev and entry[1] == theirs_rev:
		if profile_find_blocker:
			stats["pair_cache_hits"] += 1
		return entry[2]
	var c := CarSweep.candidate_conflict_distance(
		mine, theirs, car.state == Car.State.REVERSING_OUT, other.state == Car.State.REVERSING_OUT
	)
	if entry == null:
		row[oid] = [mine_rev, theirs_rev, c]
	else:
		entry[0] = mine_rev
		entry[1] = theirs_rev
		entry[2] = c
	return c


func _update_car_yielding(car: Car, delta: float, candidates: Array[Car] = []) -> bool:
	var b := find_blocker(car, candidates)
	if b != null:
		if car.current_blocker == b:
			car.blocked_time += delta
		else:
			car.current_blocker = b
			car.blocked_time = delta
		stats["max_stuck_time"] = maxf(stats["max_stuck_time"], car.blocked_time)
	else:
		car.current_blocker = null
		car.blocked_time = 0.0
	return b != null


func _check_deadlock_watchdog() -> void:
	var handled := {}
	for start_car in lot_cars:
		if not is_instance_valid(start_car) or start_car.current_blocker == null:
			continue
		if handled.has(start_car.get_instance_id()):
			continue

		var visited: Array[Car] = []
		var curr: Car = start_car
		var cycle: Array[Car] = []
		while curr != null and is_instance_valid(curr):
			var idx := visited.find(curr)
			if idx != -1:
				cycle = visited.slice(idx)
				break
			visited.append(curr)
			curr = curr.current_blocker

		if not cycle.is_empty():
			var any_stuck := false
			var highest_car: Car = null
			for c in cycle:
				handled[c.get_instance_id()] = true
				if c.blocked_time > 4.0:
					any_stuck = true
				if highest_car == null or c.get_instance_id() > highest_car.get_instance_id():
					highest_car = c
			if any_stuck and highest_car != null:
				var hid := highest_car.get_instance_id()
				if _watchdog_ignores.has(hid) and _watchdog_ignores[hid].get("timer", 0.0) > 0.0:
					continue
				var lower_cars: Array[Car] = []
				for c in cycle:
					if c != highest_car and is_instance_valid(c):
						lower_cars.append(c)
				_fire_watchdog(highest_car, lower_cars)


func _fire_watchdog(higher_car: Car, lower_cars: Array[Car]) -> void:
	stats["watchdog_fires"] += 1
	var first_lower := lower_cars[0] if not lower_cars.is_empty() else null
	var lower_id := first_lower.get_instance_id() if first_lower else 0
	print(
		(
			"WATCHDOG: Deadlock mutual blocking at equal priority (%s vs %s) > 4.0s! Car %d at %s ignoring Car %d at %s for 1.5s"
			% [
				higher_car.get_state_name(),
				first_lower.get_state_name() if first_lower else "none",
				higher_car.get_instance_id(),
				higher_car.global_position,
				lower_id,
				first_lower.global_position if first_lower else Vector3.ZERO,
			]
		)
	)
	var targets := {}
	for lc in lower_cars:
		if is_instance_valid(lc):
			targets[lc.get_instance_id()] = true
			lc.blocked_time = 0.0
			lc.current_blocker = null
	_watchdog_ignores[higher_car.get_instance_id()] = {
		"target_id": lower_id,
		"targets": targets,
		"timer": 1.5,
	}
	higher_car.blocked_time = 0.0
	higher_car.current_blocker = null


## A parked car may back out only when no lot car is moving nearby, and its back-out
## route is clear of other cars' bodies, the stretch of their route they need to
## stop (at least REVERSE_CLEAR_TRAVEL), and other cars' back-out routes.
func can_reverse_out(car: Car) -> bool:
	if car == null or not is_instance_valid(car):
		return false
	var spot_x: float = car.spot.x if car.spot != null else car.global_position.x
	for other in lot_cars:
		if is_instance_valid(other) and other != car:
			if (
				other.is_moving()
				and absf(other.global_position.x - spot_x) < 8.0
				and (car.global_position.z * other.global_position.z > 0.0)
			):
				return false
	if car.spot == null:
		return true
	return _reverse_route_clear(car, _reverse_out_route(car))


## Back-out route for a parked car; shortcut takers back out facing their shortcut.
func _reverse_out_route(car: Car) -> Curve3D:
	if car.spot == null:
		return null
	if car.pending_destination_spot != null:
		return ParkingLot.shortcut_reverse_route(car.spot, car.pending_destination_spot)
	return ParkingLot.reverse_route(car.spot)


## Checks whether a car's reverse route is clear of conflicting lot car footprints.
func _reverse_route_clear(car: Car, route: Curve3D) -> bool:
	var length := route.get_baked_length()
	var rects := CarSweep.reverse_path_footprints(route, car.car_length, car.car_width)
	for other in lot_cars:
		if not is_instance_valid(other) or other == car or other.state == Car.State.PARKED:
			continue
		var theirs := _car_sweep(other)
		if other.global_position.distance_to(car.global_position) > length + theirs["reach"]:
			continue
		if not CarSweep.reverse_route_clear(
			rects, theirs, other.speed, other.state == Car.State.REVERSING_OUT, REVERSE_CLEAR_TRAVEL
		):
			return false
	return true


## Lane 3 merge path whose wait point is closest to x (a waiting car sits on its wait point).
func get_drive_thru_path(dest: StringName) -> Curve3D:
	if dest == &"booger_king":
		return booger_king_drive_thru_path
	elif (
		dest == &"cramped_inn_dropoff"
		or dest == &"cramped_inn_pickup"
		or dest == &"cramped_inn_dropoff_pickup"
	):
		return cramped_inn_dropoff_path
	return taco_hell_drive_thru_path


## Lane 3 merge path whose wait point is closest to x (a waiting car sits on its wait point).
func lane3_merge_path(x: float) -> Curve3D:
	return ParkingLot.merge_path(3, x)


## x where a Lane 3 car waiting near x joins the lane.
func lane3_merge_x(x: float) -> float:
	return ParkingLot.merge_x(3, x)


func _can_merge(car: Car) -> bool:
	if car == null or lanes.is_empty():
		return false
	var target_lane_id := car.merge_target_lane
	if target_lane_id >= lanes.size() or lanes[target_lane_id] == null:
		return false
	var target_lane: Lane = lanes[target_lane_id]

	for other in lot_cars:
		if (
			is_instance_valid(other)
			and other != car
			and other.state == Car.State.MERGING
			and other.merge_target_lane == target_lane_id
		):
			var other_d: float = target_lane.distance_at(other.global_position.x)
			var my_d: float = target_lane.distance_at(
				ParkingLot.merge_x(target_lane_id, car.global_position.x)
			)
			if absf(other_d - my_d) < 25.0:
				return false

	var merge_dist: float = target_lane.distance_at(
		ParkingLot.merge_x(target_lane_id, car.global_position.x)
	)
	var window_start: float = merge_dist - car.car_length - 2.0
	var window_end: float = merge_dist + 10.0

	for other in target_lane.cars:
		if not is_instance_valid(other) or other == car:
			continue
		# Cars turning into the lot/drive-thru leave before the merge point
		if other.state == Car.State.TO_SPOT or other.state == Car.State.DRIVE_THRU:
			continue
		if other.state == Car.State.APPROACHING and _turn_d(target_lane_id, other) <= merge_dist:
			continue
		var d: float = other.lane_distance
		if other.motion == Car.Motion.PATH:
			d = target_lane.distance_at(other.global_position.x)
		if d >= window_start and d <= window_end:
			return false
		if d < merge_dist:
			var spd: float = maxf(maxf(other.lane_speed, other.speed), 0.1)
			if (merge_dist - d) / spd <= T_MERGE_GAP:
				return false
	return true


## A drive-thru car spawns at its path start, which sits on the curb lane, so the start
## must be clear of other drive-thru cars and of lane traffic passing the turn-in.
func can_spawn_drive_thru(dest: StringName) -> bool:
	var target_path := get_drive_thru_path(dest)
	for car in lot_cars:
		if is_instance_valid(car) and car.path == target_path:
			if car.path_distance < 12.0:
				return false
	var start := target_path.get_point_position(0)
	var site_id := ParkingLot.get_site_for_destination(dest)
	var site_cfg := ParkingLot.get_site_cfg(site_id)
	var check_lane_id: int = site_cfg.get("lane_id", 0)
	if check_lane_id < lanes.size() and lanes[check_lane_id] != null:
		for car in lanes[check_lane_id].cars:
			if not is_instance_valid(car):
				continue
			var safe_dist := car.car_length + maxf(10.0, car.speed * 1.5)
			if car.global_position.distance_to(start) < safe_dist:
				return false
	return true


func _count_drive_thru_cars(dest: StringName) -> int:
	var count := 0
	for car in lot_cars:
		if is_instance_valid(car) and car.state == Car.State.DRIVE_THRU:
			if (
				car.errand != null
				and (
					car.errand.destination == dest
					or (
						car.errand.is_dropoff()
						and (dest == &"cramped_inn_dropoff" or dest == &"cramped_inn_pickup")
					)
				)
			):
				count += 1
			elif (
				dest == &"booger_king"
				and (
					car.path == booger_king_drive_thru_path
					or (
						car.merge_target_lane == 3
						and (car.errand == null or car.errand.destination != &"cramped_inn")
					)
				)
			):
				count += 1
			elif (
				dest == &"taco_hell_drive_thru"
				and (
					car.path == taco_hell_drive_thru_path
					or (
						car.merge_target_lane == 0
						and (
							car.errand == null
							or (
								car.errand.destination != &"walgroins"
								and car.errand.destination != &"taco_hell"
							)
						)
					)
				)
			):
				count += 1
			elif (
				(dest == &"cramped_inn_dropoff" or dest == &"cramped_inn_pickup")
				and car.merge_target_lane == 3
				and car.path == cramped_inn_dropoff_path
			):
				count += 1
	var check_lane_id := 0 if dest == &"taco_hell_drive_thru" else 3
	if lanes.size() > check_lane_id:
		for car in lanes[check_lane_id].cars:
			if (
				is_instance_valid(car)
				and car.errand != null
				and (
					car.errand.destination == dest
					or (
						car.errand.is_dropoff()
						and (dest == &"cramped_inn_dropoff" or dest == &"cramped_inn_pickup")
					)
				)
			):
				count += 1
	return count


func spawn_drive_thru_car(dest: StringName = &"taco_hell_drive_thru", is_taxi: bool = false) -> Car:
	var car: Car
	if is_taxi:
		car = TaxiScene.instantiate()
		car.car_type = Car.CarType.TAXI
	else:
		car = PassengerCarScene.instantiate()
		var chosen_type: Car.CarType = PassengerCar.pick_passenger_car_type(true)
		car.car_type = chosen_type
	add_child(car)
	car.errand = Errand.new(dest, 15.0)
	car.had_errand = true
	car.state = Car.State.DRIVE_THRU
	car.speed = V_DRIVE_THRU
	car.desired_speed = V_DRIVE_THRU
	var site_id := ParkingLot.get_site_for_destination(dest)
	var site_cfg := ParkingLot.get_site_cfg(site_id)
	car.merge_target_lane = site_cfg.get("lane_id", 0)
	car.follow_path(get_drive_thru_path(dest))
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	stats["errands_assigned"] += 1
	return car


func spawn_cramped_inn_dropoff_car(is_taxi: bool = false) -> Car:
	var dest := &"cramped_inn_dropoff" if randf() < 0.5 else &"cramped_inn_pickup"
	return spawn_drive_thru_car(dest, is_taxi)


func spawn_debug_car() -> Car:
	if lot == null:
		return null
	var free_spots := lot.get_free_spots()
	if free_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = free_spots[randi() % free_spots.size()]
	var car: Car = PassengerCarScene.instantiate()
	var chosen_type: Car.CarType = PassengerCar.pick_passenger_car_type(true)
	car.car_type = chosen_type
	var spot_site := ParkingLot.lot_group(chosen_spot)
	var site_cfg := ParkingLot.get_site_cfg(spot_site)
	car.merge_target_lane = site_cfg.get("lane_id", 0)
	if spot_site == &"strip_mall" or spot_site == &"cramped_inn":
		car.errand = Errand.new(spot_site)
	elif spot_site == &"smell":
		var dest := chosen_spot.serves[0] if not chosen_spot.serves.is_empty() else &"smell_store"
		car.errand = Errand.new(dest)
	elif spot_site == &"frontage":
		var dest := (
			chosen_spot.serves[0] if not chosen_spot.serves.is_empty() else &"consumer_car_care"
		)
		car.errand = Errand.new(dest)
	else:
		car.errand = Errand.random()
	car.had_errand = true
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := ParkingLot.entry_route(chosen_spot)
	car.state = Car.State.TO_SPOT
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.follow_path(route)
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	return car


## Spawns an errand car already on its way into a free spot of a south lot.
func spawn_south_lot_car(site: StringName) -> Car:
	if lot == null:
		return null
	var free_spots: Array[ParkingSpot] = []
	for s in lot.spots:
		if s.is_free() and (s.serves.has(site) or s.site_id == site):
			free_spots.append(s)
	if free_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = free_spots[randi() % free_spots.size()]
	var car: Car = PassengerCarScene.instantiate()
	var chosen_type: Car.CarType = PassengerCar.pick_passenger_car_type(true)
	car.car_type = chosen_type
	var errand_dest := (
		site
		if site != &"frontage"
		else (chosen_spot.serves[0] if not chosen_spot.serves.is_empty() else &"consumer_car_care")
	)
	car.errand = Errand.new(errand_dest)
	car.had_errand = true
	car.merge_target_lane = 3
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := ParkingLot.entry_route(chosen_spot)
	car.state = Car.State.TO_SPOT
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.follow_path(route)
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	stats["errands_assigned"] += 1
	return car


func spawn_frontage_car(dest: StringName = &"consumer_car_care") -> Car:
	return spawn_south_lot_car(dest)


func spawn_smell_car(dest: StringName = &"smell_gas") -> Car:
	if lot == null:
		return null
	var candidate_spots: Array[ParkingSpot] = []
	for s in lot.get_free_spots():
		if dest in s.serves:
			candidate_spots.append(s)
	if candidate_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = candidate_spots[randi() % candidate_spots.size()]
	var car: Car = PassengerCarScene.instantiate()
	var chosen_type: Car.CarType = PassengerCar.pick_passenger_car_type(true)
	car.car_type = chosen_type
	car.errand = Errand.new(dest)
	car.had_errand = true
	car.merge_target_lane = 0
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := ParkingLot.entry_route(chosen_spot)
	car.follow_path(route)
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.state = Car.State.TO_SPOT
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	stats["errands_assigned"] += 1
	return car


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4 or event.physical_keycode == KEY_F4:
			spawn_debug_car()
		elif event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			spawn_drive_thru_car(&"taco_hell_drive_thru")
		elif event.keycode == KEY_F6 or event.physical_keycode == KEY_F6:
			spawn_drive_thru_car(&"booger_king")
		elif event.keycode == KEY_F7 or event.physical_keycode == KEY_F7:
			if event.shift_pressed:
				spawn_cramped_inn_dropoff_car(true)
			else:
				spawn_south_lot_car(&"cramped_inn")
		elif event.keycode == KEY_F8 or event.physical_keycode == KEY_F8:
			spawn_south_lot_car(&"strip_mall")
		elif event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
			spawn_smell_car(&"smell_gas")
		elif event.keycode == KEY_F10 or event.physical_keycode == KEY_F10:
			spawn_smell_car(&"smell_store")


func _on_child_entered_tree(node: Node) -> void:
	if node is Car:
		live_car_count += 1


func _on_child_exiting_tree(node: Node) -> void:
	if node is Car:
		live_car_count -= 1


## Updates every live car's stall timer and removes the longest-stalled car once it
## exceeds stuck_despawn_time (at most one per tick, so a jam clears from its root).
func _despawn_stalled_car(delta: float) -> void:
	var worst: Car = null
	for car in lot_cars:
		worst = _track_stall(car, delta, worst)
	for lane in lanes:
		for car in lane.cars:
			worst = _track_stall(car, delta, worst)
	if worst != null:
		_despawn_stuck_car(worst)


func _track_stall(car: Car, delta: float, worst: Car) -> Car:
	# Lot cars in a lane apron appear in both lists; count each car once per tick.
	if not is_instance_valid(car) or car.stall_tick == _physics_tick_count:
		return worst
	car.stall_tick = _physics_tick_count
	if (
		car.is_moving()
		or car.state == Car.State.PARKED
		or car.traffic_stop != null
		or car.dt_dwell_timer > 0.0
	):
		car.stalled_time = 0.0
		return worst
	car.stalled_time += delta
	if car.stalled_time < stuck_despawn_time:
		return worst
	if worst == null or car.stalled_time > worst.stalled_time:
		return car
	return worst


func _despawn_stuck_car(car: Car) -> void:
	stats["stuck_despawns"] += 1
	var b := car.current_blocker if is_instance_valid(car.current_blocker) else null
	print(
		(
			"STUCK: removing car %d (%s) at %s after %.1fs stalled; blocker %s"
			% [
				car.get_instance_id(),
				car.get_state_name(),
				car.global_position,
				car.stalled_time,
				(
					"%d (%s) at %s" % [b.get_instance_id(), b.get_state_name(), b.global_position]
					if b != null
					else "none"
				),
			]
		)
	)
	lot_cars.erase(car)
	# Cars queued behind the removed one stalled nearly as long; restart every timer so
	# they get a full window to pull away instead of being removed one after another.
	for lane in lanes:
		lane.cars.erase(car)
		for other in lane.cars:
			_clear_stall_after_despawn(other, car)
	for other in lot_cars:
		_clear_stall_after_despawn(other, car)
	_watchdog_ignores.erase(car.get_instance_id())
	car.despawn()


func _clear_stall_after_despawn(other: Car, removed: Car) -> void:
	if not is_instance_valid(other):
		return
	other.stalled_time = 0.0
	if other.current_blocker == removed:
		other.current_blocker = null


func _update_lane_spawning(lane: Lane, delta: float) -> void:
	lane.spawn_timer -= delta
	if lane.spawn_timer > 0.0:
		return
	if live_car_count >= MAX_LIVE_CARS:
		lane.spawn_timer = 0.5
		return
	# Check headway: ensure no car is too close to spawn point
	var can_spawn := true
	for car in lane.cars:
		if is_instance_valid(car) and car.lane_distance < MIN_SPAWN_HEADWAY:
			can_spawn = false
			break

	if can_spawn:
		_spawn_car_at(lane, 0.0)
		lane.spawn_timer = randf_range(lane.spawn_interval_min, lane.spawn_interval_max)
	else:
		lane.spawn_timer = 0.5


func _spawn_car_at(lane: Lane, initial_distance: float, scene: PackedScene = null) -> Node:
	var car: Car
	var chosen_type: Car.CarType
	if scene != null:
		car = scene.instantiate()
		if car is PassengerCar:
			chosen_type = PassengerCar.pick_passenger_car_type(true)
		else:
			chosen_type = car.car_type
	else:
		var roll := randf()
		if roll < 0.67:
			car = PassengerCarScene.instantiate()
			chosen_type = PassengerCar.pick_passenger_car_type(true)
		elif roll < 0.75:
			car = VanScene.instantiate()
			chosen_type = Car.CarType.VAN
		elif roll < 0.85:
			car = TaxiScene.instantiate()
			chosen_type = Car.CarType.TAXI
		elif roll < 0.92:
			car = TruckScene.instantiate()
			chosen_type = Car.CarType.TRUCK
		elif roll < 0.96:
			car = ShippingTruckScene.instantiate()
			chosen_type = Car.CarType.SHIPPING_TRUCK
		else:
			car = BusScene.instantiate()
			chosen_type = Car.CarType.BUS
	# Pick the body before _ready builds one, or passenger cars build a sedan and then swap it.
	car.car_type = chosen_type
	add_child(car)
	car.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, lane.min_speed, chosen_type
	)
	var spd := calculate_car_desired_speed(lane, car)
	car.speed = spd
	car.desired_speed = spd
	car.lane_speed = spd
	car.lane_distance = initial_distance
	car.update_presentation()
	car.reset_physics_interpolation()
	# Patrol duty replaces the errand roll: patrolling police look for a car to pull over.
	car.on_patrol = (
		car.car_type == Car.CarType.POLICE_SUV
		and not _is_test_mode()
		and randf() < PATROL_PROBABILITY
	)
	var takes_errands := car.can_take_errands() and not car.on_patrol
	if lane.id == 0 and takes_errands:
		if randf() < P_ERRAND:
			if (
				initial_distance < DECISION_D
				and car.can_use_drive_thru()
				and _count_drive_thru_cars(&"taco_hell_drive_thru") < 3
				and randf() < 0.22
			):
				car.errand = Errand.new(&"taco_hell_drive_thru", randf_range(8.0, 16.0))
				car.had_errand = true
				stats["errands_assigned"] += 1
			elif car.can_park():
				if initial_distance < DECISION_D:
					car.errand = Errand.random()
					car.had_errand = true
					stats["errands_assigned"] += 1
				elif initial_distance < DECISION_D_SMELL:
					var roll := randf()
					if roll < 0.45:
						car.errand = Errand.new(&"smell_store")
					else:
						car.errand = Errand.new(&"smell_gas")
					car.had_errand = true
					stats["errands_assigned"] += 1
	elif lane.id == 3 and takes_errands:
		if randf() < P_ERRAND:
			var roll := randf()
			if car.car_type == Car.CarType.TAXI:
				if (
					initial_distance < DECISION_D_CI
					and _count_drive_thru_cars(&"cramped_inn_dropoff") < 2
				):
					var dest := &"cramped_inn_dropoff" if randf() < 0.5 else &"cramped_inn_pickup"
					car.errand = Errand.new(dest, randf_range(3.0, 8.0))
			else:
				if (
					initial_distance < DECISION_D_BK
					and car.can_use_drive_thru()
					and _count_drive_thru_cars(&"booger_king") < 3
					and randf() < 0.22
				):
					car.errand = Errand.new(&"booger_king", randf_range(8.0, 16.0))
				elif car.can_park():
					if initial_distance < DECISION_D_SM:
						if roll < 0.30:
							car.errand = Errand.new(&"strip_mall")
						elif roll < 0.55:
							car.errand = Errand.new(&"cramped_inn")
						elif roll < 0.70:
							var dest := (
								&"cramped_inn_dropoff" if randf() < 0.5 else &"cramped_inn_pickup"
							)
							car.errand = Errand.new(dest, randf_range(3.0, 8.0))
						else:
							car.errand = Errand.new(_random_frontage_destination())
					elif initial_distance < DECISION_D_CI:
						if roll < 0.45:
							car.errand = Errand.new(&"cramped_inn")
						elif roll < 0.65:
							var dest := (
								&"cramped_inn_dropoff" if randf() < 0.5 else &"cramped_inn_pickup"
							)
							car.errand = Errand.new(dest, randf_range(3.0, 8.0))
						else:
							car.errand = Errand.new(_random_frontage_destination())
					elif initial_distance < DECISION_D_FRONTAGE:
						car.errand = Errand.new(_random_frontage_destination())
		# Extra pull toward the frontage shops for lane-3 cars that rolled no errand.
		if (
			car.errand == null
			and car.car_type != Car.CarType.TAXI
			and car.can_park()
			and initial_distance < DECISION_D_FRONTAGE
			and randf() < P_FRONTAGE_ERRAND
		):
			car.errand = Errand.new(_random_frontage_destination())
		if car.errand != null:
			car.had_errand = true
			stats["errands_assigned"] += 1
	lane.cars.append(car)
	stats["cars_spawned"] += 1
	return car


func _random_frontage_destination() -> StringName:
	var roll := randf()
	if roll < 0.4:
		return &"consumer_car_care"
	return &"frontage_retail" if roll < 0.8 else &"frontage_commercial"


func _is_lane_obstacle(car: Car) -> bool:
	return (
		car.state == Car.State.TO_SPOT
		or car.state == Car.State.MERGING
		or (car.state == Car.State.DRIVE_THRU and not car.dt_pickup_done)
	)


func _is_turning_in_apron(car: Car, lane: Lane) -> bool:
	if car.state != Car.State.TO_SPOT and car.state != Car.State.DRIVE_THRU:
		return false
	if lane.id == 0 and car.global_position.z > -13.2:
		return true
	if lane.id == 3 and car.global_position.z < 13.2:
		return true
	return false


## Buckets this tick's PATH lot cars by lane once, instead of every lane scanning all lot cars.
## Valid for the whole lane loop: lane updates never move a lot car to another lane (a car that
## turns in mid-loop joins lot_cars for its own lane, which is already done).
func _bucket_lot_cars_by_lane() -> void:
	for lane in lanes:
		lane.lot_path_cars.clear()
	var lane_count := lanes.size()
	for car in lot_cars:
		if not is_instance_valid(car) or car.motion != Car.Motion.PATH:
			continue
		if car.lane_id >= 0 and car.lane_id < lane_count:
			lanes[car.lane_id].lot_path_cars.append(car)
		var target := car.merge_target_lane
		if target != car.lane_id and target >= 0 and target < lane_count:
			lanes[target].lot_path_cars.append(car)
	_lane_buckets_valid = true


## Stable insertion sort, farthest ahead first. Lane order barely changes between ticks, so this
## is near-linear; ties keep their previous order.
static func _sort_by_lane_distance_desc(cars: Array[Car]) -> void:
	for i in range(1, cars.size()):
		var car := cars[i]
		var d := car.lane_distance
		var j := i - 1
		while j >= 0 and d > cars[j].lane_distance:
			cars[j + 1] = cars[j]
			j -= 1
		cars[j + 1] = car


func _update_lane_traffic(lane: Lane, delta: float) -> void:
	# Register any overlapping PATH cars from lot_cars
	for car in lane.lot_path_cars if _lane_buckets_valid else lot_cars:
		if (
			is_instance_valid(car)
			and car.motion == Car.Motion.PATH
			and (car.lane_id == lane.id or car.merge_target_lane == lane.id)
		):
			if _is_lane_obstacle(car):
				var in_apron: bool = lane.overlaps(car) or _is_turning_in_apron(car, lane)
				if in_apron and not lane.cars.has(car):
					lane.cars.append(car)
	# Clean up despawned / invalid cars and PATH cars that no longer overlap
	var valid_cars := lane.valid_cars
	valid_cars.clear()
	for car in lane.cars:
		if not is_instance_valid(car) or car.state == Car.State.PARKED:
			continue
		if car.motion == Car.Motion.PATH:
			# Exiting cars yield off-road; retaining them here deadlocks the merge.
			var in_apron: bool = lane.overlaps(car) or _is_turning_in_apron(car, lane)
			if not _is_lane_obstacle(car) or not in_apron:
				continue
			car.lane_distance = lane.distance_at(car.global_position.x)
			if car.state == Car.State.TO_SPOT or car.state == Car.State.DRIVE_THRU:
				car.lane_speed = car.speed if car.speed > 0.5 else 0.0
			else:
				car.lane_speed = maxf(0.0, car.speed * car.get_heading().dot(lane.forward()))
		else:
			if car.lane_id != lane.id:
				continue
			car.lane_speed = car.speed
		valid_cars.append(car)

	# Sort cars by distance descending (farthest ahead first)
	_sort_by_lane_distance_desc(valid_cars)
	var shouldered_cars := lane.shouldered_cars
	shouldered_cars.clear()
	for car in valid_cars:
		if car.is_beside_lane():
			shouldered_cars.append(car)

	var surviving_cars := lane.spare_cars
	surviving_cars.clear()
	for i in range(valid_cars.size()):
		var car = valid_cars[i]
		if car.motion == Car.Motion.PATH:
			surviving_cars.append(car)
			continue
		# Decision point for errand cars
		if car.state == Car.State.CRUISING and car.errand != null:
			var site_id := ParkingLot.get_site_for_destination(car.errand.destination)
			var site_cfg := ParkingLot.get_site_cfg(site_id)
			var site_lane_id: int = site_cfg.get("lane_id", -1)
			if site_lane_id == lane.id:
				var dec_d := _decision_d(lane.id, car)
				if car.lane_distance >= dec_d:
					if car.errand.is_drive_thru() or car.errand.is_dropoff():
						if _count_drive_thru_cars(car.errand.destination) < MAX_DRIVE_THRU_CAPACITY:
							car.state = Car.State.APPROACHING
							car.set_turn_signal(Car.TurnSignal.RIGHT)
						else:
							car.errand = null
							car.had_errand = false
							stats["errands_dropped_lot_full"] += 1
					elif lot != null:
						var spot = lot.request_spot(car, car.errand)
						if spot != null:
							car.state = Car.State.APPROACHING
							car.set_turn_signal(Car.TurnSignal.RIGHT)
						else:
							car.errand = null
							car.had_errand = false
							stats["errands_dropped_lot_full"] += 1
		# Smooth car-following with velocity-dependent safe gap and comfortable deceleration
		var stop: TrafficStop = car.traffic_stop
		var following_target: float = car.desired_speed
		var brake_accel: float = BRAKE_ACCELERATION
		var lead_car: Car = _lane_lead(valid_cars, i)
		var lead_gap: float = 999.0
		var safe_gap: float = maxf(SAFE_FOLLOWING_GAP, 3.5 + car.speed * 0.75)
		if lead_car != null:
			var is_lead_turning: bool = (
				lead_car.state == Car.State.APPROACHING or lead_car.state == Car.State.TO_SPOT
			)
			if is_lead_turning:
				safe_gap = maxf(SAFE_FOLLOWING_GAP + 2.0, 5.0 + car.speed * 0.85)
			lead_gap = (
				lead_car.lane_distance
				- car.lane_distance
				- (0.5 * (lead_car.car_length + car.car_length))
			)
			var lead_speed: float = lead_car.lane_speed
			var min_stop_gap: float = 6.0 if is_lead_turning else 5.0
			if lead_gap < safe_gap:
				var t: float = clampf(
					maxf(0.0, lead_gap - min_stop_gap) / maxf(0.1, safe_gap - min_stop_gap),
					0.0,
					1.0
				)
				following_target = lerpf(lead_speed, car.desired_speed, t)
				if lead_gap < min_stop_gap:
					following_target = lead_speed * clampf(lead_gap / min_stop_gap, 0.0, 1.0)
					brake_accel = BRAKE_ACCELERATION
				else:
					brake_accel = A_COMFORT * 2.5

		# Cars beside the lane at the curb: slow down, swerve past, or move over a lane.
		var curb_stopping := stop != null or car.is_curb_stopping()
		var stop_gap: float = INF
		if not curb_stopping and not shouldered_cars.is_empty():
			stop_gap = _shouldered_gap(car, shouldered_cars)
		if not curb_stopping and not car.is_changing_lanes:
			car.lateral_bias_target = (
				-signf(lane.z) * STOP_SWERVE_BIAS if stop_gap < STOP_SWERVE_LOOKAHEAD else 0.0
			)
		var move_over: bool = stop_gap > 0.0 and stop_gap < STOP_MOVE_OVER_LOOKAHEAD

		var swerved := false
		if (
			car.state == Car.State.CRUISING
			and car.errand == null
			and not car.had_errand
			and stop == null
			and not car.on_patrol
			and not car.is_changing_lanes
			and car.lane_change_cooldown <= 0.0
			and (lead_car != null or move_over)
		):
			var pass_gap := lead_gap
			var pass_lead_speed: float = lead_car.lane_speed if lead_car != null else 0.0
			if move_over and stop_gap < pass_gap:
				pass_gap = stop_gap
				pass_lead_speed = 0.0
			var wants_pass: bool = (
				move_over
				or (
					lead_car != null
					and (
						(
							lead_gap < safe_gap * 2.2
							and lead_car.lane_speed < car.desired_speed - 0.8
						)
						or (car.car_type == Car.CarType.SPORTS and lead_gap < safe_gap)
					)
				)
			)
			if wants_pass:
				var candidate_lane_ids := _get_passing_lane_candidates(lane.id)
				for target_lane_id in candidate_lane_ids:
					if target_lane_id >= 0 and target_lane_id < lanes.size():
						var target_lane := lanes[target_lane_id]
						if _can_swerve_to_lane(car, target_lane, pass_gap, pass_lead_speed):
							swerved = true
							car.start_lane_change(target_lane_id, target_lane.z)
							var target_lane_spd := calculate_car_desired_speed(target_lane, car)
							car.desired_speed = maxf(car.desired_speed, target_lane_spd)
							_pending_transfers.append({"car": car, "target_lane": target_lane})
							following_target = car.desired_speed
							break

				# If blocked, roll at most once for a reckless driver and attempt a risky pass
				if not swerved and car.is_reckless():
					var attempts_risky: bool = (
						car.force_risky_pass or (randf() < RISKY_PASS_PROBABILITY)
					)
					if attempts_risky:
						for target_lane_id in candidate_lane_ids:
							if target_lane_id >= 0 and target_lane_id < lanes.size():
								var target_lane := lanes[target_lane_id]
								if _can_swerve_to_lane(
									car, target_lane, pass_gap, pass_lead_speed, true
								):
									swerved = true
									car.start_lane_change(target_lane_id, target_lane.z, true)
									var target_lane_spd := calculate_car_desired_speed(
										target_lane, car
									)
									car.desired_speed = maxf(car.desired_speed, target_lane_spd)
									_pending_transfers.append(
										{"car": car, "target_lane": target_lane}
									)
									following_target = car.desired_speed
									break

				if not swerved:
					car.reset_lane_change_cooldown()

		if not swerved and car.on_patrol and stop == null:
			swerved = _try_patrol_keep_right(car, lane, lead_gap)

		var target_speed: float = maxf(0.0, minf(car.desired_speed, following_target))
		if stop_gap < STOP_SLOW_LOOKAHEAD:
			var pass_target := sqrt(
				V_PASS_STOP * V_PASS_STOP + 2.0 * A_COMFORT * maxf(0.0, stop_gap)
			)
			target_speed = minf(target_speed, pass_target)
		if car.state == Car.State.APPROACHING:
			if car.turn_signal != Car.TurnSignal.RIGHT:
				car.set_turn_signal(Car.TurnSignal.RIGHT)
			var turn_d := _turn_d(lane.id, car)
			var approach_dist: float = maxf(0.0, turn_d - car.lane_distance)
			var approach_target: float = sqrt(V_TURN * V_TURN + 2.0 * A_COMFORT * approach_dist)
			target_speed = minf(target_speed, approach_target)
		if stop != null:
			target_speed = stop.limit_speed(car, target_speed)
		elif car is BusCar:
			target_speed = _update_bus_stop(lane, car, target_speed, delta)

		var motor_accel := MOTOR_ACCELERATION
		if car.car_type == Car.CarType.SPORTS:
			motor_accel = 28.0
		elif car.car_type == Car.CarType.CYBERTRUCK:
			motor_accel = 26.0
		elif car.car_type == Car.CarType.F150 and car.has_smokestacks:
			motor_accel = 22.0
		elif (
			car.car_type == Car.CarType.SHIPPING_TRUCK
			or car.car_type == Car.CarType.TRUCK
			or car.car_type == Car.CarType.BUS
		):
			motor_accel = 12.0
		elif car.car_type == Car.CarType.VAN:
			motor_accel = 15.0
		var accel: float = brake_accel if car.speed > target_speed else motor_accel
		car.speed = move_toward(car.speed, target_speed, accel * delta)
		car.advance_simulation(delta)

		if car.state == Car.State.APPROACHING:
			var turn_d := _turn_d(lane.id, car)
			if car.lane_distance >= turn_d:
				car.motion = Car.Motion.PATH
				car.merge_target_lane = lane.id
				if car.errand != null and (car.errand.is_drive_thru() or car.errand.is_dropoff()):
					car.state = Car.State.DRIVE_THRU
					car.follow_path(get_drive_thru_path(car.errand.destination))
				else:
					car.state = Car.State.TO_SPOT
					if lot != null and car.spot != null:
						car.follow_path(ParkingLot.entry_route(car.spot))
				if not lot_cars.has(car):
					lot_cars.append(car)
				if lane.overlaps(car):
					car.lane_distance = lane.distance_at(car.global_position.x)
					if car.state == Car.State.TO_SPOT or car.state == Car.State.DRIVE_THRU:
						car.lane_speed = car.speed if car.speed > 0.5 else 0.0
					else:
						car.lane_speed = maxf(
							0.0, car.speed * car.get_heading().dot(lane.forward())
						)
					surviving_cars.append(car)
				continue
		# Check if reached end of lane inside tunnel
		if car.lane_distance >= lane.length:
			if (car.lane_id == 0 or car.lane_id == 3) and car.had_errand:
				stats["errands_completed"] += 1
			car.queue_free()
		elif not swerved:
			var remaining: float = lane.length - car.lane_distance
			if remaining < 8.0:
				var t := clampf(remaining / 8.0, 0.0, 1.0)
				car.scale = Vector3(t, t, t)
			surviving_cars.append(car)
	lane.spare_cars = lane.cars
	lane.cars = surviving_cars


## Lane distance at which a Lane 3 car commits to a lot errand (35 m before its turn).
func _lane3_lot_decision_d(dest: StringName) -> float:
	if dest == &"strip_mall":
		return DECISION_D_SM
	elif (
		dest == &"frontage"
		or dest == &"consumer_car_care"
		or dest == &"frontage_retail"
		or dest == &"frontage_commercial"
		or dest == &"leaders_furniture"
		or dest == &"leaders_outdoor"
		or dest == &"car_care"
		or dest == &"checkers"
	):
		return DECISION_D_FRONTAGE
	return DECISION_D_CI


## Lane distance at which an approaching car leaves its lane for the turn-in path.
func _turn_d(lane_id: int, car: Car) -> float:
	var dest: StringName = car.errand.destination if car.errand != null else &""
	var site_id := ParkingLot.get_site_for_destination(dest)
	var site_cfg := ParkingLot.get_site_cfg(site_id)
	if site_cfg.has("turn_in") and lane_id < lanes.size() and lanes[lane_id] != null:
		return lanes[lane_id].distance_at(site_cfg["turn_in"].x)
	if lane_id == 0:
		return TURN_D
	return TURN_D_BK


func _decision_d(lane_id: int, car: Car) -> float:
	return _turn_d(lane_id, car) - 35.0


func _get_passing_lane_candidates(current_lane_id: int) -> Array[int]:
	match current_lane_id:
		0:
			return [1]
		1:
			return [2, 0]
		2:
			return [1]
		3:
			return [4]
		4:
			return [5, 3]
		5:
			return [4]
	return []


func _get_adjacent_lane_id(current_lane_id: int) -> int:
	var candidates := _get_passing_lane_candidates(current_lane_id)
	return candidates[0] if not candidates.is_empty() else -1


func calculate_car_desired_speed(lane: Lane, car: Car) -> float:
	var ctype := car.car_type
	# 1. Delivery trucks tend to drive slower
	if (
		ctype == Car.CarType.SHIPPING_TRUCK
		or ctype == Car.CarType.TRUCK
		or ctype == Car.CarType.BUS
	):
		return randf_range(lane.min_speed * 0.78, lane.min_speed * 0.88)
	# 2. Amazon Prime / Crime trucks go a little faster than other delivery trucks
	elif ctype == Car.CarType.VAN:
		return randf_range(lane.min_speed * 0.90, lane.min_speed * 0.98)
	# 3. Race cars faster
	elif ctype == Car.CarType.SPORTS:
		return maxf(randf_range(28.0, 34.0), lane.max_speed * randf_range(1.25, 1.45))
	# 4. Rolling-coal trucks go a little faster than other cars (but not as fast as race cars)
	elif ctype == Car.CarType.F150 and car.has_smokestacks:
		return lane.max_speed * randf_range(1.08, 1.18)
	# 5. Other cars normal
	else:
		return randf_range(lerpf(lane.min_speed, lane.max_speed, 0.15), lane.max_speed)


func _is_in_turn_in_zone(check_lane: Lane, distance: float) -> bool:
	if check_lane == null or (check_lane.id != 0 and check_lane.id != 3):
		return false
	for site in ParkingLot.SITES.values():
		if site.get("lane_id", -1) == check_lane.id and site.has("turn_in"):
			var turn_pos: Vector3 = site["turn_in"]
			var turn_dist := check_lane.distance_at(turn_pos.x)
			if distance >= turn_dist - 25.0 and distance <= turn_dist + 10.0:
				return true
	return false


## Evaluates whether car can swerve to target_lane.
## When risk_mode is true, tighter gap thresholds are permitted for reckless drivers
## while keeping normal drivers on the safe-gap path.
func _can_swerve_to_lane(
	car: Car,
	target_lane: Lane,
	current_lead_gap: float,
	lead_car_speed: float = 0.0,
	risk_mode: bool = false
) -> bool:
	if car == null or target_lane == null:
		return false

	# 1. Large-vehicle initiators are never allowed to swerve
	if (
		car.car_type == Car.CarType.BUS
		or car.car_type == Car.CarType.SHIPPING_TRUCK
		or car.car_type == Car.CarType.TRUCK
	):
		return false

	# 2. Reject wrong-direction/oncoming lanes
	if target_lane.direction * car.direction <= 0.0:
		return false
	if car.lane_id >= 0 and car.lane_id < lanes.size() and lanes[car.lane_id] != null:
		if target_lane.direction * lanes[car.lane_id].direction <= 0.0:
			return false

	# 3. Reject lane ends
	if car.lane_distance < 15.0 or car.lane_distance > target_lane.length - 25.0:
		return false
	if car.lane_id >= 0 and car.lane_id < lanes.size() and lanes[car.lane_id] != null:
		if car.lane_distance > lanes[car.lane_id].length - 25.0:
			return false

	# 4. Reject turn-in zones
	if car.state == Car.State.APPROACHING:
		return false
	if _is_in_turn_in_zone(target_lane, car.lane_distance):
		return false
	if car.lane_id >= 0 and car.lane_id < lanes.size() and lanes[car.lane_id] != null:
		if _is_in_turn_in_zone(lanes[car.lane_id], car.lane_distance):
			return false

	# 5. Reject existing overlap
	if current_lead_gap <= 0.0 or car.is_changing_lanes:
		return false
	if car.lane_id >= 0 and car.lane_id < lanes.size() and lanes[car.lane_id] != null:
		var current_lane: Lane = lanes[car.lane_id]
		for cur_car in current_lane.cars:
			if cur_car == null or not is_instance_valid(cur_car) or cur_car == car:
				continue
			if (
				absf(cur_car.lane_distance - car.lane_distance)
				< 0.5 * (cur_car.car_length + car.car_length)
			):
				return false
			if cur_car.is_changing_lanes and absf(cur_car.lane_distance - car.lane_distance) < 25.0:
				return false
	# 6. Reject nearby simultaneous transfers
	for transfer in _pending_transfers:
		if transfer.get("target_lane") == target_lane:
			var other: Car = transfer.get("car")
			if other == null or not is_instance_valid(other) or other == car:
				continue
			if absf(other.lane_distance - car.lane_distance) < 25.0:
				return false
		var other_target = transfer.get("target_lane")
		if car.lane_id >= 0 and car.lane_id < lanes.size() and other_target == lanes[car.lane_id]:
			var other: Car = transfer.get("car")
			if other != null and is_instance_valid(other) and other != car:
				if absf(other.lane_distance - car.lane_distance) < 25.0:
					return false

	var car_fp: PackedVector2Array = []
	var car_fp_computed := false

	for other in target_lane.cars:
		if other == null or not is_instance_valid(other) or other == car:
			continue
		# Never change into a lane right before (or beside) a car stopping at the curb.
		if other.is_curb_stopping():
			var stop_ahead := other.lane_distance - car.lane_distance
			if stop_ahead > -15.0 and stop_ahead < STOP_MOVE_OVER_LOOKAHEAD:
				return false

		# Existing physical/bounding overlap rejection
		var center_dist := car.global_position.distance_to(other.global_position)
		if center_dist < (car.car_length + other.car_length) * 0.5:
			if not car_fp_computed:
				car_fp = CarSweep.footprint(
					car.global_position,
					car.get_heading(),
					car.car_length * 0.5,
					car.car_width * 0.5
				)
				car_fp_computed = true
			var other_fp := CarSweep.footprint(
				other.global_position,
				other.get_heading(),
				other.car_length * 0.5,
				other.car_width * 0.5
			)
			if CarSweep.footprints_overlap(car_fp, other_fp):
				return false

		# Existing longitudinal overlap rejection in target lane
		if (
			absf(other.lane_distance - car.lane_distance)
			< 0.5 * (other.car_length + car.car_length)
		):
			return false

		if other.motion == Car.Motion.PATH:
			if center_dist < 18.0:
				return false
			continue

		# Reject approaching cars in turn-in zones in target lane
		if (
			(
				other.state == Car.State.APPROACHING
				or _is_in_turn_in_zone(target_lane, other.lane_distance)
			)
			and absf(other.lane_distance - car.lane_distance) < 25.0
		):
			return false
		if other.is_changing_lanes and absf(other.lane_distance - car.lane_distance) < 25.0:
			return false

		var min_gap_ahead := SWERVE_RISKY_MIN_GAP_AHEAD if risk_mode else SWERVE_MIN_GAP_AHEAD
		var lead_margin := SWERVE_RISKY_LEAD_MARGIN if risk_mode else SWERVE_LEAD_MARGIN
		var min_gap_behind_base := (
			SWERVE_RISKY_MIN_GAP_BEHIND_BASE if risk_mode else SWERVE_MIN_GAP_BEHIND_BASE
		)
		var speed_behind_factor := (
			SWERVE_RISKY_MIN_GAP_BEHIND_SPEED_FACTOR
			if risk_mode
			else SWERVE_MIN_GAP_BEHIND_SPEED_FACTOR
		)
		var closing_factor := (
			SWERVE_RISKY_CLOSING_SPEED_FACTOR if risk_mode else SWERVE_CLOSING_SPEED_FACTOR
		)
		var closing_base := (
			SWERVE_RISKY_CLOSING_SPEED_BASE if risk_mode else SWERVE_CLOSING_SPEED_BASE
		)

		if other.lane_distance >= car.lane_distance:
			var gap_ahead := (
				other.lane_distance
				- car.lane_distance
				- (0.5 * (other.car_length + car.car_length))
			)
			if gap_ahead < min_gap_ahead:
				return false
			if (
				other.lane_speed <= lead_car_speed + 1.0
				and gap_ahead < current_lead_gap + lead_margin
			):
				return false
		else:
			var gap_behind := (
				car.lane_distance
				- other.lane_distance
				- (0.5 * (car.car_length + other.car_length))
			)
			var safe_behind := maxf(min_gap_behind_base, 4.0 + other.speed * speed_behind_factor)
			if gap_behind < safe_behind:
				return false
			if (
				other.speed > car.speed + 1.0
				and gap_behind < (other.speed - car.speed) * closing_factor + closing_base
			):
				return false
	return true


func _apply_pending_lane_transfers() -> void:
	for transfer in _pending_transfers:
		var c: Car = transfer["car"]
		var target_lane: Lane = transfer["target_lane"]
		if is_instance_valid(c) and not target_lane.cars.has(c):
			target_lane.cars.append(c)
	_pending_transfers.clear()


## Starts, advances, and ends a bus's stops; returns its lane target speed capped for the phase.
func _update_bus_stop(lane: Lane, bus: BusCar, target_speed: float, delta: float) -> float:
	if bus.stop_phase == BusCar.StopPhase.NONE:
		_try_start_bus_stop(lane, bus)
		if bus.stop_phase == BusCar.StopPhase.NONE:
			return target_speed
	var lane_clear := (
		bus.stop_phase == BusCar.StopPhase.PULLING_OUT
		and TrafficStop.lane_clear_to_reenter(lane, bus, bus.stop_timer, null, null)
	)
	bus.advance_stop(delta, lane_clear)
	return bus.limit_stop_speed(target_speed)


## Begins the bus's approach to the next stop once it is within comfortable braking distance.
## A stop it can no longer brake for, or one already taken by another curb stop, is skipped.
func _try_start_bus_stop(lane: Lane, bus: BusCar) -> void:
	if bus.is_changing_lanes or bus.motion != Car.Motion.LANE or bus.state != Car.State.CRUISING:
		return
	for pole_d in lane.bus_stops:
		if pole_d <= bus.last_pole_distance:
			continue
		var remaining := bus.stop_distance_for(pole_d) - bus.lane_distance
		if remaining > bus.speed * bus.speed / (2.0 * BusCar.COMFORT_DECEL) + 2.0:
			return
		bus.last_pole_distance = pole_d
		if (
			remaining > BusCar.ARRIVAL_TOLERANCE
			and bus.speed * bus.speed / (2.0 * remaining) <= BusCar.MAX_STOP_DECEL
			and not _bus_stop_occupied(lane, bus, pole_d)
		):
			bus.begin_pull_in(pole_d)
		return


func _bus_stop_occupied(lane: Lane, bus: BusCar, pole_d: float) -> bool:
	for other in lane.cars:
		if not is_instance_valid(other) or other == bus or not other.is_curb_stopping():
			continue
		var ahead := other.lane_distance - pole_d
		if ahead > -BUS_STOP_ZONE_BEHIND and ahead < BUS_STOP_ZONE_AHEAD + bus.car_length:
			return true
	return false


func _update_traffic_stops(delta: float) -> void:
	for k in range(traffic_stops.size() - 1, -1, -1):
		if not traffic_stops[k].update(self, delta):
			traffic_stops.remove_at(k)
	if _physics_tick_count % 30 == 0 and traffic_stops.size() < MAX_TRAFFIC_STOPS:
		for lane_id in [0, 3]:
			if lane_id < lanes.size():
				_try_start_patrol_stop(lanes[lane_id])


func _try_start_patrol_stop(lane: Lane) -> void:
	for stop in traffic_stops:
		if stop.lane == lane:
			return
	for police in lane.cars:
		if not is_instance_valid(police) or not police.on_patrol:
			continue
		var suspect := _car_ahead(lane, police)
		if (
			suspect != null
			and TrafficStop.bumper_gap(police, suspect) <= TrafficStop.MAX_START_GAP
			and start_traffic_stop(police, suspect) != null
		):
			return


## Lights up police behind suspect if it can pull it over before the road ends; null otherwise.
func start_traffic_stop(police: Car, suspect: Car) -> TrafficStop:
	if not TrafficStop.can_patrol(police) or not TrafficStop.can_be_stopped(suspect, police):
		return null
	var lane := lanes[police.lane_id]
	for stop in traffic_stops:
		if stop.lane == lane:
			return null
	var site := TrafficStop.find_site(
		self,
		lane,
		TrafficStop.earliest_stop_distance(police, suspect),
		suspect,
		police,
		TrafficStop.OUTER_EDGE_MAX
	)
	if site < 0.0:
		return null
	var stop := TrafficStop.new(police, suspect, lane)
	traffic_stops.append(stop)
	return stop


## Nearest car ahead of car in lane, or null.
func _car_ahead(lane: Lane, car: Car) -> Car:
	var nearest: Car = null
	for other in lane.cars:
		if not is_instance_valid(other) or other == car:
			continue
		if (
			other.lane_distance > car.lane_distance
			and (nearest == null or other.lane_distance < nearest.lane_distance)
		):
			nearest = other
	return nearest


## Nearest car ahead that valid_cars[i] must follow. Cars beside the lane at the curb are
## passed, not followed, unless they are pulling out and this car can still yield to them.
## A car on the shoulder follows nobody (its traffic stop sets where it stops); a stop
## participant still in its lane keeps following its partner.
func _lane_lead(valid_cars: Array[Car], i: int) -> Car:
	var car := valid_cars[i]
	if TrafficStop.is_car_shouldered(car):
		return null
	var partner: Car = car.traffic_stop.partner_of(car) if car.traffic_stop != null else null
	for j in range(i - 1, -1, -1):
		var other := valid_cars[j]
		if other == partner or not other.is_beside_lane() or TrafficStop.is_yielded_to(other, car):
			return other
	return null


## Bumper gap to the nearest pulled-over car not yet passed (negative alongside), or INF.
func _shouldered_gap(car: Car, shouldered_cars: Array[Car]) -> float:
	var nearest := INF
	for other in shouldered_cars:
		var half_lengths := 0.5 * (car.car_length + other.car_length)
		var gap := other.lane_distance - car.lane_distance - half_lengths
		if gap > -(2.0 * half_lengths + 1.5):
			nearest = minf(nearest, gap)
	return nearest


## Patrolling police drift toward the curb lane, where traffic stops happen.
func _try_patrol_keep_right(car: Car, lane: Lane, lead_gap: float) -> bool:
	if car.state != Car.State.CRUISING or car.is_changing_lanes or car.lane_change_cooldown > 0.0:
		return false
	var curb_id := _curbward_lane_id(lane.id)
	if curb_id < 0:
		return false
	var curb_lane := lanes[curb_id]
	# -INF lead speed: no "stuck behind a slower car" veto when merely keeping right.
	if not _can_swerve_to_lane(car, curb_lane, lead_gap, -INF):
		car.reset_lane_change_cooldown()
		return false
	car.start_lane_change(curb_id, curb_lane.z)
	car.desired_speed = calculate_car_desired_speed(curb_lane, car)
	_pending_transfers.append({"car": car, "target_lane": curb_lane})
	return true


func _curbward_lane_id(lane_id: int) -> int:
	match lane_id:
		1:
			return 0
		2:
			return 1
		4:
			return 3
		5:
			return 4
	return -1


func _exit_tree() -> void:
	if (
		GameState.instance
		and GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed)
	):
		GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
	var counted := {}
	var active_errands := 0
	var state_counts := {}
	for lane in lanes:
		for car in lane.cars:
			if is_instance_valid(car) and not counted.has(car.get_instance_id()):
				counted[car.get_instance_id()] = true
				var s_name: String = (
					Car.State.keys()[car.state] if car.state < Car.State.size() else str(car.state)
				)
				state_counts[s_name] = state_counts.get(s_name, 0) + 1
				if car.had_errand:
					active_errands += 1
	for car in lot_cars:
		if is_instance_valid(car) and not counted.has(car.get_instance_id()):
			counted[car.get_instance_id()] = true
			var s_name: String = (
				Car.State.keys()[car.state] if car.state < Car.State.size() else str(car.state)
			)
			state_counts[s_name] = state_counts.get(s_name, 0) + 1
			if car.had_errand:
				active_errands += 1
	stats["live_cars"] = counted.size()
	stats["active_errands"] = active_errands
	if lot != null:
		stats["leaked"] = max(stats["leaked"], lot.check_invariants())
		stats["spots_total"] = lot.spots.size()
	stats["sweep_hits"] = CarSweep.sweep_hits
	stats["sweep_reused"] = CarSweep.sweep_reused
	stats["sweep_allocs"] = CarSweep.sweep_allocs
	print("TRAFFIC STATS: %s" % JSON.stringify(stats))
	print("STATE COUNTS: %s" % JSON.stringify(state_counts))


func _on_time_of_day_changed(_mode: GameState.TimeOfDay) -> void:
	_update_headlamp_lod()


func update_headlamp_lod() -> void:
	_update_headlamp_lod()


func _reset_all_headlamp_lod() -> void:
	for lane in lanes:
		if lane == null:
			continue
		for car in lane.cars:
			if is_instance_valid(car):
				car.set_headlamp_lod_active(true)
	for car in lot_cars:
		if is_instance_valid(car):
			car.set_headlamp_lod_active(true)


func _update_headlamp_lod() -> void:
	var lights_on := GameState.are_lights_on()
	if not lights_on:
		if _was_lights_on:
			_was_lights_on = false
			_reset_all_headlamp_lod()
		return
	_was_lights_on = true

	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null and get_parent() != null:
		cam = get_parent().get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return

	var cam_pos := cam.global_position

	var candidates: Array[Car] = []
	var seen: Dictionary = {}
	for lane in lanes:
		if lane == null:
			continue
		for car in lane.cars:
			if is_instance_valid(car) and not seen.has(car):
				seen[car] = true
				if car.headlamp != null and car.state != Car.State.PARKED:
					candidates.append(car)
	for car in lot_cars:
		if is_instance_valid(car) and not seen.has(car):
			seen[car] = true
			if car.headlamp != null and car.state != Car.State.PARKED:
				candidates.append(car)

	if candidates.size() <= MAX_ACTIVE_HEADLAMPS:
		for car in candidates:
			car.set_headlamp_lod_active(true)
		return

	var car_dists: Array = []
	car_dists.resize(candidates.size())
	for i in range(candidates.size()):
		var car: Car = candidates[i]
		car_dists[i] = [car.global_position.distance_squared_to(cam_pos), car]

	car_dists.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	for i in range(car_dists.size()):
		var active: bool = i < MAX_ACTIVE_HEADLAMPS
		var car: Car = car_dists[i][1]
		car.set_headlamp_lod_active(active)
