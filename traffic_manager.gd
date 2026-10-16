class_name TrafficManager
extends Node3D

const CarScript = preload("res://car.gd")
const CAR_SCENE = preload("res://car.tscn")

class Lane:
	var id: int
	var z: float
	var direction: float # +1.0 for Eastbound, -1.0 for Westbound
	var start_x: float
	var length: float
	var min_speed: float
	var max_speed: float
	var spawn_interval_min: float
	var spawn_interval_max: float
	var spawn_timer: float = 0.0
	var cars: Array = []

	func _init(p_id: int, p_z: float, p_dir: float, p_start_x: float, p_len: float, p_min_spd: float, p_max_spd: float, p_int_min: float, p_int_max: float) -> void:
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

var lanes: Array[Lane] = []

const MIN_SPAWN_HEADWAY := 18.0 # meters needed before spawning another car in lane
const SAFE_FOLLOWING_GAP := 8.0 # meters
const BRAKE_ACCELERATION := 25.0
const MOTOR_ACCELERATION := 15.0


func _ready() -> void:
	_setup_lanes()
	_pre_populate_traffic()


func _setup_lanes() -> void:
	# 4 lanes matching the stroad markings; lanes run 10m past each road end (road spans x = ±60)
	# Lane 0: Eastbound outer
	lanes.append(Lane.new(0, -5.6, 1.0, -70.0, 140.0, 11.0, 14.0, 3.0, 6.0))
	# Lane 1: Eastbound inner (faster)
	lanes.append(Lane.new(1, -1.9, 1.0, -70.0, 140.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 2: Westbound inner (faster)
	lanes.append(Lane.new(2, 1.9, -1.0, 70.0, 140.0, 14.0, 18.0, 2.5, 5.0))
	# Lane 3: Westbound outer
	lanes.append(Lane.new(3, 5.6, -1.0, 70.0, 140.0, 11.0, 14.0, 3.0, 6.0))


func _pre_populate_traffic() -> void:
	# Seed 1-2 cars per lane at start
	for lane in lanes:
		var dist1 := randf_range(43.0, 60.0)
		_spawn_car_at(lane, dist1)
		if randf() > 0.3:
			var dist2 := dist1 + randf_range(20.0, 35.0)
			if dist2 < lane.length - 10.0:
				_spawn_car_at(lane, dist2)


func _physics_process(delta: float) -> void:
	for lane in lanes:
		_update_lane_traffic(lane, delta)
		_update_lane_spawning(lane, delta)


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
	
	lane.cars.append(car)
	return car


func _update_lane_traffic(lane: Lane, delta: float) -> void:
	# Clean up despawned / invalid cars
	var valid_cars: Array = []
	for car in lane.cars:
		if is_instance_valid(car):
			valid_cars.append(car)
	
	# Sort cars by distance descending (farthest ahead first)
	valid_cars.sort_custom(func(a, b) -> bool:
		return a.lane_distance > b.lane_distance
	)
	
	var surviving_cars: Array = []
	for i in range(valid_cars.size()):
		var car = valid_cars[i]
		
		# Simple car-following (safe distance to lead car)
		if i > 0:
			var lead_car = valid_cars[i - 1]
			var gap: float = lead_car.lane_distance - car.lane_distance - (0.5 * (lead_car.car_length + car.car_length))
			if gap < SAFE_FOLLOWING_GAP:
				var target_speed := minf(car.desired_speed, lead_car.speed * clampf(gap / SAFE_FOLLOWING_GAP, 0.1, 1.0))
				car.speed = move_toward(car.speed, target_speed, BRAKE_ACCELERATION * delta)
			else:
				car.speed = move_toward(car.speed, car.desired_speed, MOTOR_ACCELERATION * delta)
		else:
			car.speed = move_toward(car.speed, car.desired_speed, MOTOR_ACCELERATION * delta)
		
		car.advance_simulation(delta)
		
		# Check if reached end of lane
		if car.lane_distance >= lane.length:
			car.queue_free()
		else:
			surviving_cars.append(car)
	
	lane.cars = surviving_cars
