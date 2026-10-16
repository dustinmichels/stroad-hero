class_name TrafficManager
extends Node3D

const CarScript = preload("res://car.gd")
const CAR_SCENE = preload("res://car.tscn")
const TrafficDebugScript = preload("res://traffic_debug.gd")
const Errand = preload("res://errand.gd")


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
	var cars: Array = []

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

	func overlaps(car) -> bool:
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
var _physics_tick_count: int = 0

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
	_setup_lanes()
	_pre_populate_traffic()
	_seed_parked_cars()


func _setup_lanes() -> void:
	# 4 lanes matching the stroad markings; lanes run 10m past each road end (road spans x = ±60)
	# Lane 0: Westbound outer
	lanes.append(Lane.new(0, -5.6, -1.0, 70.0, 140.0, 11.0, 14.0, 3.0, 6.0))
	# Lane 1: Westbound inner (faster)
	lanes.append(Lane.new(1, -1.9, -1.0, 70.0, 140.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 2: Eastbound inner (faster)
	lanes.append(Lane.new(2, 1.9, 1.0, -70.0, 140.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 3: Eastbound outer
	lanes.append(Lane.new(3, 5.6, 1.0, -70.0, 140.0, 11.0, 14.0, 3.0, 6.0))


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
		var car: Car = CAR_SCENE.instantiate()
		var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
		car.car_type = chosen_type
		car.speed = 0.0
		car.desired_speed = 0.0
		add_child(car)
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
	var surviving_cars: Array[Car] = []
	for car in lot_cars:
		if not is_instance_valid(car):
			continue
		if car.state == CarScript.State.TO_SPOT:
			var target_speed := V_LOT
			if car.path != null:
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
			if arrived:
				car.speed = 0.0
				car.desired_speed = 0.0
				if car.spot != null:
					if lot != null:
						lot.occupy(car.spot)
					elif car.spot.lot != null:
						car.spot.lot.occupy(car.spot)
				car.state = CarScript.State.PARKED
				if car.errand != null:
					car.dwell_left = car.errand.dwell_time
				else:
					car.dwell_left = randf_range(5.0, 40.0)
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.PARKED:
			car.dwell_left -= delta
			if car.dwell_left <= 0.0:
				var rev_route: Curve3D = null
				if lot != null and car.spot != null:
					rev_route = lot.reverse_route(car.spot)
				elif car.spot != null and car.spot.lot != null:
					rev_route = car.spot.lot.reverse_route(car.spot)
				if rev_route != null:
					car.state = CarScript.State.REVERSING_OUT
					car.follow_path(rev_route, true)
					car.speed = -V_PARK
					car.desired_speed = -V_PARK
				else:
					push_error("TrafficManager: Missing reverse route for parked car %s" % car.name)
			surviving_cars.append(car)
		elif car.state == CarScript.State.REVERSING_OUT:
			var arrived := car.advance_path(delta)
			if arrived:
				car.speed = 0.0
				car.desired_speed = 0.0
				var exit_path: Curve3D = null
				if lot != null and car.spot != null:
					exit_path = lot.exit_route(car.spot)
				elif car.spot != null and car.spot.lot != null:
					exit_path = car.spot.lot.exit_route(car.spot)
				if car.spot != null:
					if lot != null:
						lot.release(car.spot)
					elif car.spot.lot != null:
						car.spot.lot.release(car.spot)
				car.state = CarScript.State.TO_EXIT
				if exit_path != null:
					car.follow_path(exit_path)
					car.desired_speed = V_LOT
				else:
					push_error("TrafficManager: Missing exit route for reversing car")
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.TO_EXIT:
			var target_speed := V_LOT
			if car.path != null:
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
				car.state = CarScript.State.WAITING_TO_MERGE
				car.update_presentation()
				car._update_blocker_layer()
			surviving_cars.append(car)
		elif car.state == CarScript.State.WAITING_TO_MERGE:
			if "--test-exit-route" in OS.get_cmdline_user_args():
				car.speed = 0.0
				car.desired_speed = 0.0
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
			elif not has_method("_can_merge") or call("_can_merge", car):
				car.state = CarScript.State.MERGING
				car.lane_id = 0
				var m_route: Curve3D = null
				if lot != null:
					m_route = lot.merge_route()
				else:
					m_route = ParkingLot.merge_route()
				car.follow_path(m_route)
				car.desired_speed = V_TURN
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
			else:
				car.speed = 0.0
				car.desired_speed = 0.0
				car.update_presentation()
				car._update_blocker_layer()
				surviving_cars.append(car)
		elif car.state == CarScript.State.MERGING:
			var target_speed := V_TURN
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
					and car.path_distance >= car.path.get_baked_length() - 0.05
				)
			):
				var lane0: Lane = lanes[0] if lanes.size() > 0 else null
				car.motion = CarScript.Motion.LANE
				car.lane_id = 0
				if lane0 != null:
					car.lane_z = lane0.z
					car.direction = lane0.direction
					car.start_x = lane0.start_x
					car.lane_length = lane0.length
					car.lane_distance = lane0.distance_at(car.global_position.x)
					car.desired_speed = randf_range(lane0.min_speed, lane0.max_speed)
					if not lane0.cars.has(car):
						lane0.cars.append(car)
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
				car.update_presentation()
				car._update_blocker_layer()
				# Removed from lot_cars by omitting from surviving_cars
			else:
				surviving_cars.append(car)
	lot_cars = surviving_cars


func spawn_debug_car() -> Car:
	if lot == null:
		return null
	var free_spots := lot.get_free_spots()
	if free_spots.is_empty():
		return null
	var chosen_spot: ParkingSpot = free_spots[randi() % free_spots.size()]
	var car: Car = CAR_SCENE.instantiate()
	var parkable_types := CarScript.PARKING_CAR_TYPES
	var chosen_type: CarScript.CarType = parkable_types[randi() % parkable_types.size()]
	car.car_type = chosen_type
	add_child(car)
	lot.reserve(chosen_spot, car)
	var route := lot.entry_route(chosen_spot)
	car.state = CarScript.State.TO_SPOT
	car.speed = V_LOT
	car.desired_speed = V_LOT
	car.follow_path(route)
	lot_cars.append(car)
	stats["cars_spawned"] += 1
	return car


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4 or event.physical_keycode == KEY_F4:
			spawn_debug_car()


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


func _spawn_car_at(lane: Lane, initial_distance: float) -> Node:
	var car = CAR_SCENE.instantiate()
	var spd := randf_range(lane.min_speed, lane.max_speed)
	var car_type: int = randi() % CarScript.CarType.size()
	if car_type == CarScript.CarType.BUS:
		spd *= 0.9

	add_child(car)
	car.setup(lane.id, lane.z, lane.direction, lane.start_x, lane.length, spd, car_type)
	car.lane_distance = initial_distance
	car.update_presentation()
	if lane.id == 0 and car.can_park() and initial_distance < DECISION_D and randf() < P_ERRAND:
		car.errand = Errand.random()
		car.had_errand = true
		stats["errands_assigned"] += 1
	lane.cars.append(car)
	stats["cars_spawned"] += 1
	return car


func _update_lane_traffic(lane: Lane, delta: float) -> void:
	# Register any overlapping PATH cars from lot_cars
	for car in lot_cars:
		if is_instance_valid(car) and car.motion == Car.Motion.PATH and car.lane_id == lane.id:
			if lane.overlaps(car) and not lane.cars.has(car):
				lane.cars.append(car)

	# Clean up despawned / invalid cars and PATH cars that no longer overlap
	var valid_cars: Array = []
	for car in lane.cars:
		if not is_instance_valid(car):
			continue
		if car.motion == Car.Motion.PATH:
			if not lane.overlaps(car):
				continue
			car.lane_distance = lane.distance_at(car.global_position.x)
			car.lane_speed = maxf(0.0, car.speed * car.get_heading().dot(lane.forward()))
		else:
			car.lane_speed = car.speed
		valid_cars.append(car)

	# Sort cars by distance descending (farthest ahead first)
	valid_cars.sort_custom(func(a, b) -> bool: return a.lane_distance > b.lane_distance)

	var surviving_cars: Array = []
	for i in range(valid_cars.size()):
		var car = valid_cars[i]
		if car.motion == Car.Motion.PATH:
			surviving_cars.append(car)
			continue
		# Decision point for errand cars
		if (
			car.state == Car.State.CRUISING
			and car.errand != null
			and car.lane_distance >= DECISION_D
		):
			if lot != null:
				var spot = lot.request_spot(car, car.errand)
				if spot != null:
					car.state = Car.State.APPROACHING
				else:
					car.errand = null
					car.had_errand = false
					stats["errands_dropped_lot_full"] += 1
		# Simple car-following (safe distance to lead car)
		var following_target: float = car.desired_speed
		if i > 0:
			var lead_car = valid_cars[i - 1]
			var gap: float = (
				lead_car.lane_distance
				- car.lane_distance
				- (0.5 * (lead_car.car_length + car.car_length))
			)
			if gap < SAFE_FOLLOWING_GAP:
				following_target = lead_car.lane_speed * clampf(gap / SAFE_FOLLOWING_GAP, 0.1, 1.0)
		var target_speed: float = maxf(0.0, minf(car.desired_speed, following_target))
		if car.state == Car.State.APPROACHING:
			var approach_dist: float = maxf(0.0, TURN_D - car.lane_distance)
			var approach_target: float = sqrt(V_TURN * V_TURN + 2.0 * A_COMFORT * approach_dist)
			target_speed = minf(target_speed, approach_target)

		var accel: float = BRAKE_ACCELERATION if car.speed > target_speed else MOTOR_ACCELERATION
		car.speed = move_toward(car.speed, target_speed, accel * delta)
		car.advance_simulation(delta)

		if car.state == Car.State.APPROACHING and car.lane_distance >= TURN_D:
			car.motion = Car.Motion.PATH
			if lot != null and car.spot != null:
				car.follow_path(lot.entry_route(car.spot))
			car.state = Car.State.TO_SPOT
			if not lot_cars.has(car):
				lot_cars.append(car)
			if lane.overlaps(car):
				car.lane_distance = lane.distance_at(car.global_position.x)
				car.lane_speed = maxf(0.0, car.speed * car.get_heading().dot(lane.forward()))
				surviving_cars.append(car)
			continue

		# Check if reached end of lane
		if car.lane_distance >= lane.length:
			if car.lane_id == 0 and car.had_errand:
				stats["errands_completed"] += 1
			car.queue_free()
		else:
			surviving_cars.append(car)

	lane.cars = surviving_cars


func _exit_tree() -> void:
	var counted := {}
	for lane in lanes:
		for car in lane.cars:
			if is_instance_valid(car):
				counted[car.get_instance_id()] = true
	for car in lot_cars:
		if is_instance_valid(car):
			counted[car.get_instance_id()] = true
	stats["live_cars"] = counted.size()
	if lot != null:
		stats["spots_total"] = lot.spots.size()
	print("TRAFFIC STATS: %s" % JSON.stringify(stats))
