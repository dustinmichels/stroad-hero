class_name TrafficManager
extends Node3D

const CarScript = preload("res://cars/car.gd")
const PassengerCarScene = preload("res://cars/passenger_car.tscn")
const BusScene = preload("res://cars/bus.tscn")
const TaxiScene = preload("res://cars/taxi.tscn")
const TruckScene = preload("res://cars/truck.tscn")
const VanScene = preload("res://cars/van.tscn")
const ShippingTruckScene = preload("res://cars/shipping_truck.tscn")
const TrafficDebugScript = preload("res://traffic/traffic_debug.gd")


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
		spawn_timer = randf_range(0.5, 2.0)

	func distance_at(x: float) -> float:
		return (x - start_x) * direction

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


var lanes: Array[Lane] = []
var lot: ParkingLot = null
var lot_cars: Array[Car] = []
var debug_overlay: Node3D = null
var taco_hell_drive_thru_path: Curve3D = null
var booger_king_drive_thru_path: Curve3D = null
## Lane 3 merge paths (Booger King drive-thru, strip mall, Cramped Inn), one per wait point.
var lane3_merge_paths: Array[Curve3D] = []
var _physics_tick_count: int = 0
var _watchdog_ignores: Dictionary[int, Dictionary] = {}  # int (car_instance_id) -> Dictionary { "target_id": int, "timer": float }
var _sweep_cache: Dictionary[int, Dictionary] = {}  # car instance id -> _car_sweep() result

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
	"leaked": 0,
}
const P_ERRAND := 0.3
const DECISION_D := 18.0
const TURN_D := 53.0
const V_TURN := 5.0
const A_COMFORT := 3.0
const MIN_SPAWN_HEADWAY := 18.0  # meters needed before spawning another car in lane
const SAFE_FOLLOWING_GAP := 8.0  # meters
const BRAKE_ACCELERATION := 25.0
const MOTOR_ACCELERATION := 15.0
const V_LOT := 4.5
const V_PARK := 1.5
const T_MERGE_GAP := 3.0
const V_DRIVE_THRU := 3.2
const DECISION_D_BK := 15.0
const TURN_D_BK := 50.0
const DECISION_D_SM := 49.0
const TURN_D_SM := 84.0
const DECISION_D_CI := 94.0
const TURN_D_CI := 129.0
const DECISION_D_SMELL := 79.0
const TURN_D_SMELL := 114.0
const MAX_DRIVE_THRU_CAPACITY := 5
const TACO_DT_ORDER_DIST := 38.5
const TACO_DT_PICKUP_DIST := 75.1
const BK_DT_ORDER_DIST := 75.5
const BK_DT_PICKUP_DIST := 77.0
const SWEEP_STEP := 0.5  # meters between sampled footprints along a car's route
const SWEEP_SIDE_MARGIN := 0.15  # lateral clearance added to a car's projected footprints
const SWEEP_TIE_EPS := 0.25  # route-conflict distances closer than this count as a tie
const SWEEP_INTENT_EXTRA := 4.0  # meters past the lookahead used to settle who crosses first
const REVERSE_CLEAR_TRAVEL := 1.0  # meters of another car's route a back-out route must avoid


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var seed_val: int = int(arg.substr(7))
			seed(seed_val)
			break
	lot = ParkingLot.new()
	add_child(lot)
	debug_overlay = TrafficDebugScript.new(self)
	add_child(debug_overlay)
	taco_hell_drive_thru_path = ParkingLot.taco_hell_drive_thru_route()
	booger_king_drive_thru_path = ParkingLot.booger_king_drive_thru_route()
	lane3_merge_paths = [
		ParkingLot.booger_king_merge_route(),
		ParkingLot.south_merge_route(&"strip_mall"),
		ParkingLot.south_merge_route(&"cramped_inn"),
	]
	_setup_lanes()
	_pre_populate_traffic()
	_seed_parked_cars()


func _setup_lanes() -> void:
	# 4 lanes matching the stroad markings; lanes run past each road end (road spans x = ±90)
	# Lane 0: Westbound outer
	lanes.append(Lane.new(0, -5.6, -1.0, 70.0, 165.0, 11.0, 14.0, 3.0, 6.0))
	# Lane 1: Westbound inner (faster)
	lanes.append(Lane.new(1, -1.9, -1.0, 70.0, 165.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 2: Eastbound inner (faster)
	lanes.append(Lane.new(2, 1.9, 1.0, -95.0, 190.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 3: Eastbound outer
	lanes.append(Lane.new(3, 5.6, 1.0, -95.0, 190.0, 11.0, 14.0, 3.0, 6.0))


func _pre_populate_traffic() -> void:
	# Seed 1-2 cars per lane at start
	for lane in lanes:
		var dist1 := randf_range(43.0, 60.0)
		_spawn_car_at(lane, dist1)
		if randf() > 0.3:
			var dist2 := dist1 + randf_range(20.0, 35.0)
			if dist2 < lane.length - 10.0:
				_spawn_car_at(lane, dist2)


func _pick_seeded_spots() -> Array[ParkingSpot]:
	if lot == null or lot.spots.is_empty():
		return []
	var count: int = int(round(lot.spots.size() * 0.4))
	var candidates: Array[ParkingSpot] = lot.spots.duplicate()
	candidates.shuffle()
	return candidates.slice(0, count)


func _seed_parked_cars() -> void:
	var chosen_spots := _pick_seeded_spots()
	var parkable_types := CarScript.PARKING_CAR_TYPES
	for spot in chosen_spots:
		var car: Car = PassengerCarScene.instantiate()
		var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
		car.car_type = chosen_type
		car.speed = 0.0
		car.desired_speed = 0.0
		add_child(car)
		car.lane_id = -1
		if spot.serves.has(&"cramped_inn") or spot.transform.origin.z > 0.0:
			car.merge_target_lane = 3
		else:
			car.merge_target_lane = 0
		car.state = CarScript.State.PARKED
		car.transform = spot.transform
		car.global_transform = spot.transform
		lot.reserve(spot, car)
		lot.occupy(spot)
		car.dwell_left = randf_range(5.0, 40.0)
		lot_cars.append(car)
		stats["cars_spawned"] += 1


func _physics_process(delta: float) -> void:
	for lane in lanes:
		_update_lane_traffic(lane, delta)
		_update_lane_spawning(lane, delta)
	_update_lot_cars(delta)

	_physics_tick_count += 1
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


func _update_lot_cars(delta: float) -> void:
	_sweep_cache.clear()
	var expired_ignores: Array[int] = []
	for cid in _watchdog_ignores.keys():
		_watchdog_ignores[cid]["timer"] -= delta
		if _watchdog_ignores[cid]["timer"] <= 0.0 or instance_from_id(cid) == null:
			expired_ignores.append(cid)
	for cid in expired_ignores:
		_watchdog_ignores.erase(cid)

	var surviving_cars: Array[Car] = []
	for car in lot_cars:
		if not is_instance_valid(car):
			continue
		if car.state == CarScript.State.TO_SPOT:
			if car.turn_signal != CarScript.TurnSignal.NONE:
				if (
					(car.lane_id == 0 or car.merge_target_lane == 0)
					and car.global_position.z <= -9.0
				):
					car.set_turn_signal(CarScript.TurnSignal.NONE)
				elif (
					(car.lane_id == 3 or car.merge_target_lane == 3)
					and car.global_position.z >= 9.0
				):
					car.set_turn_signal(CarScript.TurnSignal.NONE)
			var yielding := _update_car_yielding(car, delta)
			var target_speed := 0.0 if yielding else V_LOT
			if not yielding and car.path != null:
				var length := car.path.get_baked_length()
				var remaining := length - car.path_distance
				if remaining <= 4.0:
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
				car.state = CarScript.State.PARKED
				car.lane_id = -1
				if car.errand != null:
					car.dwell_left = car.errand.dwell_time
				else:
					car.dwell_left = randf_range(5.0, 40.0)
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.DRIVE_THRU:
			if car.turn_signal != CarScript.TurnSignal.NONE:
				if car.merge_target_lane == 0 and car.global_position.z <= -9.0:
					car.set_turn_signal(CarScript.TurnSignal.NONE)
				elif car.merge_target_lane == 3 and car.global_position.z >= 9.0:
					car.set_turn_signal(CarScript.TurnSignal.NONE)
			var yielding := _update_car_yielding(car, delta)
			var order_dist := TACO_DT_ORDER_DIST if car.merge_target_lane == 0 else BK_DT_ORDER_DIST
			var pickup_dist := (
				TACO_DT_PICKUP_DIST if car.merge_target_lane == 0 else BK_DT_PICKUP_DIST
			)
			if (
				not car.dt_order_done
				and car.path_distance >= order_dist - 1.5
				and car.path_distance <= order_dist + 3.0
			):
				car.dt_order_done = true
				car.dt_dwell_timer = randf_range(1.5, 3.0)
			elif (
				not car.dt_pickup_done
				and car.path_distance >= pickup_dist - 1.5
				and car.path_distance <= pickup_dist + 3.0
			):
				car.dt_pickup_done = true
				car.dt_dwell_timer = randf_range(1.5, 3.0)

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
				car.state = CarScript.State.WAITING_TO_MERGE
				car.merge_wait_time = 0.0
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.PARKED:
			car.current_blocker = null
			car.blocked_time = 0.0
			car.dwell_left -= delta
			if car.dwell_left <= 0.0:
				if can_reverse_out(car):
					var rev_route: Curve3D = null
					if lot != null and car.spot != null:
						rev_route = ParkingLot.reverse_route(car.spot)
					elif car.spot != null and car.spot.lot != null:
						rev_route = ParkingLot.reverse_route(car.spot)
					if rev_route != null:
						car.state = CarScript.State.REVERSING_OUT
						car.follow_path(rev_route, true)
						car.speed = -V_PARK
						car.desired_speed = -V_PARK
					else:
						push_error(
							"TrafficManager: Missing reverse route for parked car %s" % car.name
						)
			surviving_cars.append(car)
		elif car.state == CarScript.State.REVERSING_OUT:
			var yielding := _update_car_yielding(car, delta)
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
				var exit_path: Curve3D = null
				if lot != null and car.spot != null:
					exit_path = ParkingLot.exit_route(car.spot)
				elif car.spot != null and car.spot.lot != null:
					exit_path = ParkingLot.exit_route(car.spot)
				if car.spot != null:
					if lot != null:
						lot.release(car.spot)
					elif car.spot.lot != null:
						car.spot.lot.release(car.spot)
					car.spot = null
				if exit_path != null:
					car.state = CarScript.State.TO_EXIT
					car.follow_path(exit_path)
					car.desired_speed = V_LOT
				else:
					push_error("TrafficManager: Missing exit route for reversing car")
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.TO_EXIT:
			var yielding := _update_car_yielding(car, delta)
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
					and car.speed <= CarScript.STOP_SPEED
				)
			):
				if car.path != null:
					car.path_distance = car.path.get_baked_length()
				car.speed = 0.0
				car.desired_speed = 0.0
				car.current_blocker = null
				car.blocked_time = 0.0
				car.state = CarScript.State.WAITING_TO_MERGE
				car.merge_wait_time = 0.0
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.WAITING_TO_MERGE:
			car.current_blocker = null
			car.blocked_time = 0.0
			if "--test-exit-route" in OS.get_cmdline_user_args():
				car.merge_wait_time += delta
				stats["max_merge_wait"] = maxf(stats["max_merge_wait"], car.merge_wait_time)
				car.speed = 0.0
				car.desired_speed = 0.0
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
			elif _can_merge(car):
				stats["max_merge_wait"] = maxf(stats["max_merge_wait"], car.merge_wait_time)
				car.state = CarScript.State.MERGING
				car.lane_id = car.merge_target_lane
				var m_route: Curve3D = null
				if car.merge_target_lane == 3:
					m_route = lane3_merge_path(car.global_position.x)
				elif car.global_position.x < -30.0:
					m_route = ParkingLot.smell_merge_route()
				elif lot != null:
					m_route = ParkingLot.merge_route()
				else:
					m_route = ParkingLot.merge_route()
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
		elif car.state == CarScript.State.MERGING:
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
				car.motion = CarScript.Motion.LANE
				car.lane_id = target_lane_id
				if target_lane != null:
					car.lane_z = target_lane.z
					car.direction = target_lane.direction
					car.start_x = target_lane.start_x
					car.lane_length = target_lane.length
					car.lane_distance = target_lane.distance_at(car.global_position.x)
					car.desired_speed = randf_range(target_lane.min_speed, target_lane.max_speed)
					if not target_lane.cars.has(car):
						target_lane.cars.append(car)
				else:
					car.lane_z = -5.6
					car.direction = -1.0
					car.start_x = 70.0
					car.lane_length = 140.0
					car.lane_distance = (70.0 - car.global_position.x)
					car.desired_speed = 12.0
				car.errand = null
				car.state = CarScript.State.CRUISING
				car.path = null
				car.current_blocker = null
				car.blocked_time = 0.0
				car.update_presentation()
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


func find_blocker(car: Car) -> Car:
	if car == null or not is_instance_valid(car):
		return null

	var candidates: Array[Car] = []
	for other in lot_cars:
		if is_instance_valid(other) and other != car:
			if other.state == CarScript.State.PARKED:
				continue
			candidates.append(other)
	for lane in lanes:
		if lane != null:
			for ghost in lane.cars:
				if (
					is_instance_valid(ghost)
					and ghost != car
					and ghost.motion == CarScript.Motion.PATH
				):
					if not candidates.has(ghost):
						candidates.append(ghost)

	var mine := _car_sweep(car)
	var my_reach: float = mine["reach"]
	var closest_blocker: Car = null
	var min_dist: float = INF

	for other in candidates:
		if _is_ignoring(car, other):
			continue
		var theirs := _car_sweep(other)
		var reach: float = my_reach + theirs["reach"]
		if car.global_position.distance_to(other.global_position) > reach:
			continue
		var dist := _conflict_distance(car, mine, other, theirs)
		if dist < min_dist:
			min_dist = dist
			closest_blocker = other
	return closest_blocker


## Braking lookahead (meters of travel) a car scans along its route.
func _lookahead(car: Car) -> float:
	var spd := absf(car.speed)
	return maxf(4.0, (spd * spd) / (2.0 * BRAKE_ACCELERATION) + 3.0)


## Footprints a car covers: index 0 is its body now, the rest are its body at
## SWEEP_STEP intervals along its upcoming route (curved path or straight heading),
## widened by SWEEP_SIDE_MARGIN. A reversing car claims its whole remaining back-out
## route, so oncoming aisle traffic stops clear of it instead of meeting it head-on.
## Cached per tick; the key catches mid-tick moves.
func _car_sweep(car: Car) -> Dictionary:
	var backward := (
		car.speed < 0.0 or car.desired_speed < 0.0 or car.state == CarScript.State.REVERSING_OUT
	)
	var key := [
		car.global_transform,
		car.path,
		car.path_distance,
		car.speed,
		backward,
		car.state,
		car.car_length,
		car.car_width,
	]
	var cached: Dictionary = _sweep_cache.get(car.get_instance_id(), {})
	if not cached.is_empty() and cached["key"] == key:
		return cached

	var half_l := car.car_length * 0.5
	var half_w := car.car_width * 0.5
	var side := half_w + SWEEP_SIDE_MARGIN
	var heading := car.get_heading()
	var rects: Array[PackedVector2Array] = [
		_footprint(car.global_position, heading, half_l, half_w)
	]
	var dists: Array[float] = [0.0]
	var look := _lookahead(car)
	var horizon := look + SWEEP_INTENT_EXTRA
	if car.state == CarScript.State.REVERSING_OUT and car.path != null:
		horizon = maxf(horizon, car.path_distance)
	var sign_dir := -1.0 if backward else 1.0
	if car.motion == CarScript.Motion.PATH and car.path != null:
		_append_path_footprints(
			rects, dists, car.path, car.path_distance, sign_dir * horizon, half_l, side
		)
	else:
		var steps := int(ceil(horizon / SWEEP_STEP))
		var move := heading * sign_dir
		for k in range(1, steps + 1):
			var t := minf(k * SWEEP_STEP, horizon)
			rects.append(_footprint(car.global_position + move * t, heading, half_l, side))
			dists.append(t)

	var sweep := {
		"key": key,
		"rects": rects,
		"dists": dists,
		"look": look,
		"reach": horizon + car.car_length,
	}
	_sweep_cache[car.get_instance_id()] = sweep
	return sweep


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
	var length := path.get_baked_length()
	var look := absf(travel)
	var sign_dir := signf(travel)
	for k in range(1, int(ceil(look / SWEEP_STEP)) + 1):
		var t := minf(k * SWEEP_STEP, look)
		var d := from + sign_dir * t
		var dc := clampf(d, 0.0, length)
		var h := (
			path.sample_baked(clampf(dc + 0.05, 0.0, length))
			- path.sample_baked(clampf(dc - 0.05, 0.0, length))
		)
		if h.length_squared() < 0.000001:
			break
		rects.append(_footprint(path.sample_baked(dc), h, half_l, half_w))
		dists.append(t)
		if dc != d:
			break


static func _footprint(
	pos: Vector3, heading: Vector3, half_l: float, half_w: float
) -> PackedVector2Array:
	var f := Vector2(heading.x, heading.z).normalized()
	var s := Vector2(-f.y, f.x) * half_w
	f *= half_l
	var c := Vector2(pos.x, pos.z)
	return PackedVector2Array([c + f + s, c + f - s, c - f - s, c - f + s])


## Separating-axis test for two rectangles from _footprint.
static func _footprints_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var ra := a[0].distance_to(a[2]) * 0.5
	var rb := b[0].distance_to(b[2]) * 0.5
	if ((a[0] + a[2]) * 0.5).distance_to((b[0] + b[2]) * 0.5) > ra + rb:
		return false
	for poly in [a, b]:
		for i in 2:
			var e: Vector2 = poly[i + 1] - poly[i]
			var axis := Vector2(-e.y, e.x)
			var a_min := INF
			var a_max := -INF
			for p in a:
				var d := p.dot(axis)
				a_min = minf(a_min, d)
				a_max = maxf(a_max, d)
			var b_min := INF
			var b_max := -INF
			for p in b:
				var d := p.dot(axis)
				b_min = minf(b_min, d)
				b_max = maxf(b_max, d)
			if a_max < b_min or b_max < a_min:
				return false
	return true


## Cars that run the lot yielding logic; others (merging, waiting, lane cars) never stop for us.
func _yields_in_lot(car: Car) -> bool:
	return (
		car.state == CarScript.State.TO_SPOT
		or car.state == CarScript.State.TO_EXIT
		or car.state == CarScript.State.REVERSING_OUT
		or car.state == CarScript.State.DRIVE_THRU
	)


## Tie-break rank when two cars reach a shared area at the same distance.
func _lot_priority(s: CarScript.State) -> int:
	match s:
		CarScript.State.TO_SPOT:
			return 3
		CarScript.State.TO_EXIT:
			return 2
		CarScript.State.DRIVE_THRU:
			return 3
		_:
			return 0


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
	var a: Array[PackedVector2Array] = mine["rects"]
	var da: Array[float] = mine["dists"]
	var look: float = mine["look"]
	var b: Array[PackedVector2Array] = theirs["rects"]
	var db: Array[float] = theirs["dists"]
	for i in range(1, a.size()):
		if da[i] > look:
			break
		if _footprints_overlap(a[i], b[0]):
			return da[i]

	var reversing_mine := car.state == CarScript.State.REVERSING_OUT
	var reversing_theirs := other.state == CarScript.State.REVERSING_OUT
	if reversing_mine != reversing_theirs:
		if reversing_mine:
			return INF
		for i in range(1, a.size()):
			if da[i] > look:
				break
			for j in range(1, b.size()):
				if _footprints_overlap(a[i], b[j]):
					return da[i]
		return INF

	var first_mine := INF
	var first_theirs := INF
	for i in a.size():
		for j in range(1, b.size()):
			if da[i] >= first_mine and db[j] >= first_theirs:
				continue
			if _footprints_overlap(a[i], b[j]):
				first_mine = minf(first_mine, da[i])
				first_theirs = minf(first_theirs, db[j])
	# Already in their way (nothing to gain by stopping) or conflict still beyond braking range.
	if first_mine == 0.0 or first_mine > look:
		return INF
	if not _yields_in_lot(other):
		return first_mine
	if first_theirs < first_mine - SWEEP_TIE_EPS:
		return first_mine
	if first_mine < first_theirs - SWEEP_TIE_EPS:
		return INF
	var p_car := _lot_priority(car.state)
	var p_other := _lot_priority(other.state)
	if p_car != p_other:
		return first_mine if p_other > p_car else INF
	return first_mine if other.get_instance_id() < car.get_instance_id() else INF


func _update_car_yielding(car: Car, delta: float) -> bool:
	var b := find_blocker(car)
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
	var route := ParkingLot.reverse_route(car.spot)
	var length := route.get_baked_length()
	var rects: Array[PackedVector2Array] = []
	var dists: Array[float] = []
	_append_path_footprints(
		rects,
		dists,
		route,
		length,
		-length,
		car.car_length * 0.5,
		car.car_width * 0.5 + SWEEP_SIDE_MARGIN
	)
	for other in lot_cars:
		if not is_instance_valid(other) or other == car or other.state == CarScript.State.PARKED:
			continue
		var theirs := _car_sweep(other)
		if other.global_position.distance_to(car.global_position) > length + theirs["reach"]:
			continue
		var other_reversing := other.state == CarScript.State.REVERSING_OUT
		var other_rects: Array[PackedVector2Array] = theirs["rects"]
		var other_dists: Array[float] = theirs["dists"]
		var stop_dist := other.speed * other.speed / (2.0 * BRAKE_ACCELERATION) + SWEEP_STEP
		var clear_travel := maxf(REVERSE_CLEAR_TRAVEL, stop_dist)
		for j in other_rects.size():
			if not other_reversing and other_dists[j] > clear_travel:
				break
			for r in rects:
				if _footprints_overlap(r, other_rects[j]):
					return false
	return true


## Lane 3 merge path whose wait point is closest to x (a waiting car sits on its wait point).
func lane3_merge_path(x: float) -> Curve3D:
	var best: Curve3D = null
	var best_d := INF
	for p in lane3_merge_paths:
		var d := absf(p.get_point_position(0).x - x)
		if d < best_d:
			best_d = d
			best = p
	return best


## x where a Lane 3 car waiting near x joins the lane.
func lane3_merge_x(x: float) -> float:
	return lane3_merge_path(x).get_point_position(0).x


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
			and other.state == CarScript.State.MERGING
			and other.merge_target_lane == target_lane_id
		):
			var other_d: float = target_lane.distance_at(other.global_position.x)
			var my_d: float
			if target_lane_id == 3:
				my_d = target_lane.distance_at(lane3_merge_x(car.global_position.x))
			elif car.global_position.x < -30.0:
				my_d = target_lane.distance_at(ParkingLot.SMELL_WAIT_POINT.x)
			else:
				my_d = 61.0
			if absf(other_d - my_d) < 25.0:
				return false

	var merge_dist: float
	if target_lane_id == 3:
		merge_dist = target_lane.distance_at(lane3_merge_x(car.global_position.x))
	elif car.global_position.x < -30.0:
		merge_dist = target_lane.distance_at(ParkingLot.SMELL_WAIT_POINT.x)
	else:
		merge_dist = 61.0

	var window_start: float = merge_dist - car.car_length - 2.0
	var window_end: float = merge_dist + 10.0

	for other in target_lane.cars:
		if not is_instance_valid(other) or other == car:
			continue
		# Cars turning into the lot/drive-thru leave before the merge point
		if other.state == CarScript.State.TO_SPOT or other.state == CarScript.State.DRIVE_THRU:
			continue
		var d: float = other.lane_distance
		if other.motion == CarScript.Motion.PATH:
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
	var target_path := (
		booger_king_drive_thru_path if dest == &"booger_king" else taco_hell_drive_thru_path
	)
	for car in lot_cars:
		if is_instance_valid(car) and car.path == target_path:
			if car.path_distance < 12.0:
				return false
	var start := target_path.get_point_position(0)
	for lane in lanes:
		for car in lane.cars:
			if (
				is_instance_valid(car)
				and car.global_position.distance_to(start) < car.car_length * 0.5 + 6.0
			):
				return false
	return true


func _count_drive_thru_cars(dest: StringName) -> int:
	var count := 0
	for car in lot_cars:
		if is_instance_valid(car) and car.state == CarScript.State.DRIVE_THRU:
			if car.errand != null and car.errand.destination == dest:
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
	return count


func spawn_drive_thru_car(dest: StringName = &"taco_hell_drive_thru") -> Car:
	var car: Car = PassengerCarScene.instantiate()
	var parkable_types := CarScript.PARKING_CAR_TYPES
	var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
	car.car_type = chosen_type
	add_child(car)
	car.errand = Errand.new(dest, 15.0)
	car.had_errand = true
	car.state = CarScript.State.DRIVE_THRU
	car.speed = V_DRIVE_THRU
	car.desired_speed = V_DRIVE_THRU
	if dest == &"booger_king":
		car.merge_target_lane = 3
		car.follow_path(booger_king_drive_thru_path)
	else:
		car.merge_target_lane = 0
		car.follow_path(taco_hell_drive_thru_path)
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	stats["errands_assigned"] += 1
	return car


func spawn_debug_car() -> Car:
	if lot == null:
		return null
	var free_spots := lot.get_free_spots()
	if free_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = free_spots[randi() % free_spots.size()]
	var car: Car = PassengerCarScene.instantiate()
	var parkable_types := CarScript.PARKING_CAR_TYPES
	var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
	car.car_type = chosen_type
	if ParkingLot.south_lot(chosen_spot) != &"":
		car.merge_target_lane = 3
		car.errand = Errand.new(ParkingLot.south_lot(chosen_spot), randf_range(15.0, 35.0))
	else:
		car.merge_target_lane = 0
		car.errand = Errand.random()
	car.had_errand = true
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := ParkingLot.entry_route(chosen_spot)
	car.state = CarScript.State.TO_SPOT
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
		if s.is_free() and s.serves.has(site):
			free_spots.append(s)
	if free_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = free_spots[randi() % free_spots.size()]
	var car: Car = PassengerCarScene.instantiate()
	var parkable_types := CarScript.PARKING_CAR_TYPES
	var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
	car.car_type = chosen_type
	car.errand = Errand.new(site, randf_range(15.0, 35.0))
	car.had_errand = true
	car.merge_target_lane = 3
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := ParkingLot.entry_route(chosen_spot)
	car.state = CarScript.State.TO_SPOT
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.follow_path(route)
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	stats["errands_assigned"] += 1
	return car


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
	var parkable_types := CarScript.PARKING_CAR_TYPES
	var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
	car.car_type = chosen_type
	var dwell := randf_range(12.0, 25.0) if dest == &"smell_gas" else randf_range(15.0, 35.0)
	car.errand = Errand.new(dest, dwell)
	car.had_errand = true
	car.merge_target_lane = 0
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := lot.entry_route(chosen_spot)
	car.follow_path(route)
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.state = CarScript.State.TO_SPOT
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
			spawn_south_lot_car(&"cramped_inn")
		elif event.keycode == KEY_F8 or event.physical_keycode == KEY_F8:
			spawn_south_lot_car(&"strip_mall")
		elif event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
			spawn_smell_car(&"smell_gas")
		elif event.keycode == KEY_F10 or event.physical_keycode == KEY_F10:
			spawn_smell_car(&"smell_store")


func _update_lane_spawning(lane: Lane, delta: float) -> void:
	lane.spawn_timer -= delta
	if lane.spawn_timer > 0.0:
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
	var chosen_type: CarScript.CarType
	if scene != null:
		car = scene.instantiate()
		var parkable_types := CarScript.PARKING_CAR_TYPES
		chosen_type = parkable_types[randi() % parkable_types.size()]
	else:
		var roll := randf()
		if roll < 0.67:
			car = PassengerCarScene.instantiate()
			var parkable_types := CarScript.PARKING_CAR_TYPES
			chosen_type = parkable_types[randi() % parkable_types.size()]
		elif roll < 0.75:
			car = VanScene.instantiate()
			chosen_type = CarScript.CarType.VAN
		elif roll < 0.85:
			car = TaxiScene.instantiate()
			chosen_type = CarScript.CarType.TAXI
		elif roll < 0.92:
			car = TruckScene.instantiate()
			chosen_type = CarScript.CarType.TRUCK
		elif roll < 0.96:
			car = ShippingTruckScene.instantiate()
			chosen_type = CarScript.CarType.SHIPPING_TRUCK
		else:
			car = BusScene.instantiate()
			chosen_type = CarScript.CarType.BUS
	var spd := randf_range(lane.min_speed, lane.max_speed)
	if chosen_type == CarScript.CarType.BUS or chosen_type == CarScript.CarType.SHIPPING_TRUCK:
		spd *= 0.9

	add_child(car)
	car.setup(lane.id, lane.z, lane.direction, lane.start_x, lane.length, spd, chosen_type)
	car.lane_distance = initial_distance
	car.update_presentation()
	if lane.id == 0 and car.can_park() and randf() < P_ERRAND:
		if initial_distance < DECISION_D:
			if randf() < 0.35:
				car.errand = Errand.new(&"taco_hell_drive_thru", randf_range(10.0, 25.0))
			else:
				car.errand = Errand.random()
			car.had_errand = true
			stats["errands_assigned"] += 1
		elif initial_distance < DECISION_D_SMELL:
			var roll := randf()
			if roll < 0.5:
				car.errand = Errand.new(&"smell_store", randf_range(15.0, 35.0))
			else:
				car.errand = Errand.new(&"smell_gas", randf_range(12.0, 25.0))
			car.had_errand = true
			stats["errands_assigned"] += 1
	elif lane.id == 3 and car.can_park() and randf() < P_ERRAND:
		var roll := randf()
		if initial_distance < DECISION_D_BK:
			if roll < 0.4:
				car.errand = Errand.new(&"booger_king", randf_range(10.0, 25.0))
			elif roll < 0.7:
				car.errand = Errand.new(&"strip_mall", randf_range(20.0, 45.0))
			else:
				car.errand = Errand.new(&"cramped_inn", randf_range(20.0, 45.0))
		elif initial_distance < DECISION_D_SM:
			if roll < 0.5:
				car.errand = Errand.new(&"strip_mall", randf_range(20.0, 45.0))
			else:
				car.errand = Errand.new(&"cramped_inn", randf_range(20.0, 45.0))
		elif initial_distance < DECISION_D_CI:
			car.errand = Errand.new(&"cramped_inn", randf_range(20.0, 45.0))
		if car.errand != null:
			car.had_errand = true
			stats["errands_assigned"] += 1
	lane.cars.append(car)
	stats["cars_spawned"] += 1
	return car


func _is_lane_obstacle(car: Car) -> bool:
	return (
		car.state == CarScript.State.TO_SPOT
		or car.state == CarScript.State.MERGING
		or (car.state == CarScript.State.DRIVE_THRU and not car.dt_pickup_done)
	)


func _update_lane_traffic(lane: Lane, delta: float) -> void:
	# Register any overlapping PATH cars from lot_cars
	for car in lot_cars:
		if is_instance_valid(car) and car.motion == Car.Motion.PATH and car.lane_id == lane.id:
			if _is_lane_obstacle(car):
				if lane.overlaps(car) and not lane.cars.has(car):
					lane.cars.append(car)

	# Clean up despawned / invalid cars and PATH cars that no longer overlap
	var valid_cars: Array[Car] = []
	for car in lane.cars:
		if not is_instance_valid(car):
			continue
		if car.motion == Car.Motion.PATH:
			# Exiting cars yield off-road; retaining them here deadlocks the merge.
			if not _is_lane_obstacle(car) or not lane.overlaps(car):
				continue
			car.lane_distance = lane.distance_at(car.global_position.x)
			if car.state == CarScript.State.TO_SPOT or car.state == CarScript.State.DRIVE_THRU:
				car.lane_speed = car.speed if car.speed > 0.5 else 0.0
			else:
				car.lane_speed = maxf(0.0, car.speed * car.get_heading().dot(lane.forward()))
		else:
			car.lane_speed = car.speed
		valid_cars.append(car)

	# Sort cars by distance descending (farthest ahead first)
	valid_cars.sort_custom(func(a: Car, b: Car) -> bool: return a.lane_distance > b.lane_distance)

	var surviving_cars: Array[Car] = []
	for i in range(valid_cars.size()):
		var car = valid_cars[i]
		if car.motion == Car.Motion.PATH:
			surviving_cars.append(car)
			continue
		# Decision point for errand cars
		if car.state == Car.State.CRUISING and car.errand != null:
			if lane.id == 0:
				var is_smell_dest: bool = car.errand.is_smell()
				var dec_d := DECISION_D_SMELL if is_smell_dest else DECISION_D
				if car.lane_distance >= dec_d:
					if car.errand.destination == &"taco_hell_drive_thru":
						if (
							_count_drive_thru_cars(&"taco_hell_drive_thru")
							< MAX_DRIVE_THRU_CAPACITY
						):
							car.state = Car.State.APPROACHING
							car.set_turn_signal(CarScript.TurnSignal.RIGHT)
						else:
							car.errand = null
							car.had_errand = false
							stats["errands_dropped_lot_full"] += 1
					elif lot != null:
						var spot = lot.request_spot(car, car.errand)
						if spot != null:
							car.state = Car.State.APPROACHING
							car.set_turn_signal(CarScript.TurnSignal.RIGHT)
						else:
							car.errand = null
							car.had_errand = false
							stats["errands_dropped_lot_full"] += 1
			elif lane.id == 3:
				if car.errand.destination == &"booger_king" and car.lane_distance >= DECISION_D_BK:
					if _count_drive_thru_cars(&"booger_king") < MAX_DRIVE_THRU_CAPACITY:
						car.state = Car.State.APPROACHING
						car.set_turn_signal(CarScript.TurnSignal.RIGHT)
					else:
						car.errand = null
						car.had_errand = false
						stats["errands_dropped_lot_full"] += 1
				elif (
					not car.errand.is_drive_thru()
					and car.lane_distance >= _lane3_lot_decision_d(car.errand.destination)
				):
					if lot != null:
						var spot = lot.request_spot(car, car.errand)
						if spot != null:
							car.state = Car.State.APPROACHING
							car.set_turn_signal(CarScript.TurnSignal.RIGHT)
						else:
							car.errand = null
							car.had_errand = false
							stats["errands_dropped_lot_full"] += 1
		# Smooth car-following with velocity-dependent safe gap and comfortable deceleration
		var following_target: float = car.desired_speed
		var brake_accel: float = BRAKE_ACCELERATION
		if i > 0:
			var lead_car = valid_cars[i - 1]
			var gap: float = (
				lead_car.lane_distance
				- car.lane_distance
				- (0.5 * (lead_car.car_length + car.car_length))
			)
			var safe_gap: float = maxf(SAFE_FOLLOWING_GAP, 4.0 + car.speed * 1.2)
			var lead_speed: float = lead_car.lane_speed
			if gap < safe_gap:
				var t: float = clampf(maxf(0.0, gap - 4.0) / maxf(0.1, safe_gap - 4.0), 0.0, 1.0)
				following_target = lerpf(lead_speed, car.desired_speed, t)
				if gap < 4.0:
					following_target = lead_speed * clampf(gap / 4.0, 0.0, 1.0)
					brake_accel = BRAKE_ACCELERATION
				else:
					brake_accel = A_COMFORT * 2.0
		var target_speed: float = maxf(0.0, minf(car.desired_speed, following_target))
		if car.state == Car.State.APPROACHING:
			if car.turn_signal != CarScript.TurnSignal.RIGHT:
				car.set_turn_signal(CarScript.TurnSignal.RIGHT)
			var turn_d := _turn_d(lane.id, car)
			var approach_dist: float = maxf(0.0, turn_d - car.lane_distance)
			var approach_target: float = sqrt(V_TURN * V_TURN + 2.0 * A_COMFORT * approach_dist)
			target_speed = minf(target_speed, approach_target)

		var accel: float = brake_accel if car.speed > target_speed else MOTOR_ACCELERATION
		car.speed = move_toward(car.speed, target_speed, accel * delta)
		car.advance_simulation(delta)

		if car.state == Car.State.APPROACHING:
			var turn_d := _turn_d(lane.id, car)
			if car.lane_distance >= turn_d:
				car.motion = Car.Motion.PATH
				if lane.id == 0:
					car.merge_target_lane = 0
					if car.errand != null and car.errand.destination == &"taco_hell_drive_thru":
						car.state = Car.State.DRIVE_THRU
						car.follow_path(taco_hell_drive_thru_path)
					else:
						car.state = Car.State.TO_SPOT
						if lot != null and car.spot != null:
							car.follow_path(ParkingLot.entry_route(car.spot))
				elif lane.id == 3:
					car.merge_target_lane = 3
					if car.errand != null and not car.errand.is_drive_thru():
						car.state = Car.State.TO_SPOT
						if lot != null and car.spot != null:
							car.follow_path(ParkingLot.entry_route(car.spot))
					else:
						car.state = Car.State.DRIVE_THRU
						car.follow_path(booger_king_drive_thru_path)
				if not lot_cars.has(car):
					lot_cars.append(car)
				if lane.overlaps(car):
					car.lane_distance = lane.distance_at(car.global_position.x)
					if (
						car.state == CarScript.State.TO_SPOT
						or car.state == CarScript.State.DRIVE_THRU
					):
						car.lane_speed = car.speed if car.speed > 0.5 else 0.0
					else:
						car.lane_speed = maxf(
							0.0, car.speed * car.get_heading().dot(lane.forward())
						)
					surviving_cars.append(car)
				continue
		# Check if reached end of lane
		if car.lane_distance >= lane.length:
			if (car.lane_id == 0 or car.lane_id == 3) and car.had_errand:
				stats["errands_completed"] += 1
			car.queue_free()
		else:
			surviving_cars.append(car)

	lane.cars = surviving_cars


## Lane distance at which a Lane 3 car commits to a lot errand (35 m before its turn).
func _lane3_lot_decision_d(dest: StringName) -> float:
	return DECISION_D_SM if dest == &"strip_mall" else DECISION_D_CI


## Lane distance at which an approaching car leaves its lane for the turn-in path.
func _turn_d(lane_id: int, car: Car) -> float:
	if lane_id == 0:
		var dest: StringName = car.errand.destination if car.errand != null else &""
		if dest == &"smell_store" or dest == &"smell_gas":
			return TURN_D_SMELL
		return TURN_D
	var dest: StringName = car.errand.destination if car.errand != null else &""
	match dest:
		&"cramped_inn":
			return TURN_D_CI
		&"strip_mall":
			return TURN_D_SM
	return TURN_D_BK


func _exit_tree() -> void:
	var counted := {}
	var active_errands := 0
	var state_counts := {}
	for lane in lanes:
		for car in lane.cars:
			if is_instance_valid(car) and not counted.has(car.get_instance_id()):
				counted[car.get_instance_id()] = true
				var s_name: String = (
					CarScript.State.keys()[car.state]
					if car.state < CarScript.State.size()
					else str(car.state)
				)
				state_counts[s_name] = state_counts.get(s_name, 0) + 1
				if car.had_errand:
					active_errands += 1
	for car in lot_cars:
		if is_instance_valid(car) and not counted.has(car.get_instance_id()):
			counted[car.get_instance_id()] = true
			var s_name: String = (
				CarScript.State.keys()[car.state]
				if car.state < CarScript.State.size()
				else str(car.state)
			)
			state_counts[s_name] = state_counts.get(s_name, 0) + 1
			if car.had_errand:
				active_errands += 1
	stats["live_cars"] = counted.size()
	stats["active_errands"] = active_errands
	if lot != null:
		stats["leaked"] = max(stats["leaked"], lot.check_invariants())
		stats["spots_total"] = lot.spots.size()
	print("TRAFFIC STATS: %s" % JSON.stringify(stats))
	print("STATE COUNTS: %s" % JSON.stringify(state_counts))
