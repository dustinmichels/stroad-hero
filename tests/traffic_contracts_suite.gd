class_name TrafficContractsSuite
extends TestSuite


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--test-exit-priority",
				"--test-find-blocker",
				"--test-reverse-safety",
				"--test-priority-arbitration",
				"--test-deadlock-watchdog",
				"--test-car-headlights",
				"--test-car-exhaust",
				"--test-frontage-contracts",
				"--test-speed-variation",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--test-exit-priority" in user_args:
		_run_test_exit_priority()
		return
	if "--test-find-blocker" in user_args:
		_run_test_find_blocker()
		return
	if "--test-reverse-safety" in user_args:
		_run_test_reverse_safety()
		return
	if "--test-priority-arbitration" in user_args:
		_run_test_priority_arbitration()
		return
	if "--test-deadlock-watchdog" in user_args:
		_run_test_deadlock_watchdog()
		return
	if "--test-car-headlights" in user_args:
		_run_test_car_headlights()
		return
	if "--test-car-exhaust" in user_args:
		_run_test_car_exhaust()
		return
	if "--test-frontage-contracts" in user_args:
		_run_test_frontage_contracts()
		return
	if "--test-speed-variation" in user_args:
		_run_test_speed_variation()


func _run_test_frontage_contracts() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	assert(tm.lot != null, "ParkingLot must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	for s in tm.lot.spots:
		tm.lot.release(s)

	# Verify frontage spots
	var frontage_spots: Array[ParkingSpot] = []
	for spot in tm.lot.spots:
		if ParkingLot.is_frontage(spot):
			frontage_spots.append(spot)
	assert(
		frontage_spots.size() == 13,
		"Must have exactly 13 frontage spots (found %d)" % frontage_spots.size()
	)

	# Verify spot properties and routes
	var retail_count := 0
	var car_care_count := 0
	var commercial_count := 0
	for spot in frontage_spots:
		assert(spot.site_id == &"frontage", 'Frontage spot site_id must be &"frontage"')
		assert(ParkingLot.lot_group(spot) == &"frontage", 'lot_group must be &"frontage"')
		assert(
			spot.entry_route != null and spot.entry_route.get_baked_length() > 30.0,
			"Entry route must be valid"
		)
		assert(
			spot.reverse_route != null and spot.reverse_route.get_baked_length() > 4.0,
			"Reverse route must be valid"
		)
		assert(
			spot.exit_route != null and spot.exit_route.get_baked_length() > 20.0,
			"Exit route must be valid"
		)
		if spot.serves.has(&"frontage_retail"):
			retail_count += 1
			assert(
				spot.serves.has(&"leaders_furniture"),
				'Retail spot must also serve &"leaders_furniture"'
			)
		elif spot.serves.has(&"consumer_car_care"):
			car_care_count += 1
			assert(spot.serves.has(&"car_care"), 'Car care spot must also serve &"car_care"')
		elif spot.serves.has(&"frontage_commercial"):
			commercial_count += 1
			assert(spot.serves.has(&"checkers"), 'Commercial spot must also serve &"checkers"')

	assert(retail_count == 6, "Must have 6 Retail spots (found %d)" % retail_count)
	assert(car_care_count == 5, "Must have 5 Consumer Car Care spots (found %d)" % car_care_count)
	assert(
		commercial_count == 2, "Must have 2 Frontage Commercial spots (found %d)" % commercial_count
	)

	# Verify SITES registry
	var site_cfg := ParkingLot.get_site_cfg(&"frontage")
	assert(not site_cfg.is_empty(), 'Site config for &"frontage" must exist')
	assert(site_cfg.get("lane_id") == 3, "Frontage lane_id must be 3")
	assert(
		site_cfg.get("wait") == ParkingLot.FRONTAGE_WAIT_POINT,
		"Wait point must match FRONTAGE_WAIT_POINT"
	)
	assert(
		site_cfg.get("merge_end") == ParkingLot.FRONTAGE_MERGE_END,
		"Merge end must match FRONTAGE_MERGE_END"
	)

	# Verify request_spot and state transitions
	var car_scene = load("res://cars/passenger_car.tscn")
	var test_car: Car = car_scene.instantiate()
	test_car.car_type = Car.CarType.SEDAN
	tm.add_child(test_car)

	var errand_cc = Errand.new(&"consumer_car_care", 10.0)
	var spot_cc = tm.lot.request_spot(test_car, errand_cc)
	assert(spot_cc != null, "Must successfully allocate spot for consumer_car_care")
	assert(spot_cc.serves.has(&"consumer_car_care"), "Spot must serve consumer_car_care")
	assert(spot_cc.state == ParkingSpot.State.RESERVED, "Spot must be RESERVED")
	tm.lot.occupy(spot_cc)
	assert(spot_cc.state == ParkingSpot.State.OCCUPIED, "Spot must be OCCUPIED")
	tm.lot.release(spot_cc)
	assert(spot_cc.state == ParkingSpot.State.FREE, "Spot must be FREE")

	var errand_ret = Errand.new(&"leaders_furniture", 10.0)
	var spot_ret = tm.lot.request_spot(test_car, errand_ret)
	assert(spot_ret != null, "Must successfully allocate spot for leaders_furniture")
	assert(spot_ret.serves.has(&"frontage_retail"), "Spot must serve frontage_retail")
	tm.lot.release(spot_ret)

	var errand_com = Errand.new(&"checkers", 10.0)
	var spot_com = tm.lot.request_spot(test_car, errand_com)
	assert(spot_com != null, "Must successfully allocate spot for checkers")
	assert(spot_com.serves.has(&"frontage_commercial"), "Spot must serve frontage_commercial")
	tm.lot.release(spot_com)

	test_car.queue_free()

	# Verify merge path and coordinates
	assert(ParkingLot.merge_x(3, 70.25) == 70.25, "Merge x for frontage must be 70.25")
	var m_route = ParkingLot.merge_path(3, 70.25)
	assert(m_route != null and m_route.get_baked_length() > 5.0, "Merge route must be valid")

	print("TRAFFIC CONTRACTS: Frontage road parking spots and routes verified successfully!")
	main.get_tree().quit(0)


func _run_test_exit_priority() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	for lane in tm.lanes:
		for car in lane.cars:
			car.queue_free()
		lane.cars.clear()
	for car in tm.lot_cars:
		car.queue_free()
	tm.lot_cars.clear()
	for lane_id in [0, 3]:
		var lane = tm.lanes[lane_id]
		var exiting: Car = tm.PassengerCarScene.instantiate()
		tm.add_child(exiting)
		exiting.motion = Car.Motion.PATH
		exiting.state = Car.State.DRIVE_THRU
		exiting.lane_id = lane_id
		exiting.merge_target_lane = lane_id
		exiting.dt_order_done = true
		exiting.dt_pickup_done = true
		exiting.follow_path(
			tm.taco_hell_drive_thru_path if lane_id == 0 else tm.booger_king_drive_thru_path
		)
		exiting.path_distance = exiting.path.get_baked_length() - 0.01
		exiting.speed = 0.0
		exiting.update_presentation()
		exiting.reset_physics_interpolation()
		tm.lot_cars.append(exiting)
		lane.cars.append(exiting)
		var merge_x: float = ParkingLot.WAIT_POINT.x if lane_id == 0 else ParkingLot.BK_WAIT_POINT.x
		var through: Car = tm._spawn_car_at(
			lane, lane.distance_at(merge_x) - 20.0, tm.PassengerCarScene
		)
		through.errand = null
		through.speed = 13.0
		through.desired_speed = 13.0
		var saw_wait := false
		for tick in range(360):
			tm._update_lane_traffic(lane, 1.0 / 60.0)
			tm._update_lot_cars(1.0 / 60.0)
			if exiting.state == Car.State.WAITING_TO_MERGE:
				saw_wait = true
				assert(
					is_equal_approx(through.speed, 13.0),
					"Main-road traffic must not brake for a waiting driveway car"
				)
				assert(exiting.speed == 0.0, "Exiting car must wait for main-road traffic")
			if exiting.state == Car.State.CRUISING:
				break
		assert(saw_wait, "Returning drive-thru car must yield before merging")
		assert(exiting.state == Car.State.CRUISING, "Exit must clear once main-road traffic passes")
		for car in lane.cars:
			car.queue_free()
		lane.cars.clear()
		# Regression test: Approaching car turning in before merge point must not block driveway exit merge
		var waiting_car: Car = tm.PassengerCarScene.instantiate()
		tm.add_child(waiting_car)
		waiting_car.state = Car.State.WAITING_TO_MERGE
		waiting_car.merge_target_lane = lane_id
		waiting_car.global_position = Vector3(merge_x, 0.0, -13.375 if lane_id == 0 else 13.375)
		var approaching_car: Car = tm._spawn_car_at(
			lane, lane.distance_at(merge_x) - 15.0, tm.PassengerCarScene
		)
		approaching_car.state = Car.State.APPROACHING
		approaching_car.errand = Errand.new(&"taco_hell" if lane_id == 0 else &"booger_king", 10.0)
		assert(
			tm._can_merge(waiting_car),
			"Approaching car turning in before merge point must not block driveway exit"
		)
		approaching_car.queue_free()
		waiting_car.queue_free()

		# Regression test: Parked cars must not be retained in lane.cars
		var parked: Car = tm.PassengerCarScene.instantiate()
		tm.add_child(parked)
		parked.state = Car.State.PARKED
		lane.cars.append(parked)
		tm._update_lane_traffic(lane, 1.0 / 60.0)
		assert(not lane.cars.has(parked), "Parked car must not remain in lane.cars")
		parked.queue_free()
		for car in lane.cars:
			car.queue_free()
		lane.cars.clear()
	print("EXIT_PRIORITY: SUCCESS - both exits yield without stopping main-road traffic")
	main.get_tree().quit(0)


func _run_test_find_blocker() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	# Clear lot cars for isolated unit testing of find_blocker
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()

	var car_scene = load("res://cars/passenger_car.tscn")
	var car_a = car_scene.instantiate()
	car_a.car_type = Car.CarType.SEDAN
	car_a.car_width = 2.0
	car_a.speed = 0.0
	car_a.direction = 1.0
	tm.add_child(car_a)
	car_a.global_position = Vector3(0.0, 0.0, 0.0)
	car_a.rotation.y = 0.0  # forward is +X
	tm.lot_cars.append(car_a)

	var car_b = car_scene.instantiate()
	car_b.car_type = Car.CarType.SEDAN
	car_b.car_width = 2.0
	car_b.speed = 0.0
	car_b.direction = 1.0
	tm.add_child(car_b)
	car_b.global_position = Vector3(2.0, 0.0, 0.5)
	tm.lot_cars.append(car_b)

	# Test 1: centers 6.0m apart (gap = 6.0 - 4.2 = 1.8 < 4.0m lookahead), lateral 0.5 < 2.2m -> blocker found
	car_b.global_position = Vector3(6.0, 0.0, 0.5)
	var b = tm.find_blocker(car_a)
	assert(b == car_b, "car_b at 6.0m center distance must be detected as blocker")

	# Test 2: lateral too large (2.5 > 2.2m)
	car_b.global_position = Vector3(6.0, 0.0, 2.5)
	var b2 = tm.find_blocker(car_a)
	assert(b2 == null, "car_b with lateral 2.5m must NOT be blocker")

	# Test 3: behind car_a (forward < 0)
	car_b.global_position = Vector3(-6.0, 0.0, 0.0)
	assert(tm.find_blocker(car_a) == null, "car_b behind car_a must NOT be blocker")

	# Test 4: centers 9.0m apart (gap = 9.0 - 4.2 = 4.8 >= 4.0m lookahead) -> NOT a blocker when stopped
	car_b.global_position = Vector3(9.0, 0.0, 0.0)
	assert(
		tm.find_blocker(car_a) == null,
		"car_b at 9.0m center distance must NOT be blocker when car_a is stopped"
	)

	# Test 5: dynamic lookahead with speed
	# speed = 10 m/s -> lookahead = max(4.0, 100 / (2 * 25) + 3.0) = 5.0m
	# gap = 4.8 < 5.0m -> blocker found!
	car_a.speed = 10.0
	assert(
		tm.find_blocker(car_a) == car_b, "car_b at 9.0m must be blocker when car_a speed is 10 m/s"
	)
	car_a.speed = 0.0

	# Test 6: closest blocker when multiple candidates exist
	var car_c = car_scene.instantiate()
	car_c.car_type = Car.CarType.SEDAN
	tm.add_child(car_c)
	car_c.global_position = Vector3(5.0, 0.0, 0.0)
	tm.lot_cars.append(car_c)
	car_b.global_position = Vector3(7.0, 0.0, 0.0)
	assert(
		tm.find_blocker(car_a) == car_c,
		"find_blocker must return closest blocker (car_c at 5.0m, not car_b at 7.0m)"
	)
	tm.lot_cars.erase(car_c)
	car_c.queue_free()

	# Test 7: Reversing car
	car_a.state = Car.State.REVERSING_OUT
	car_a.speed = -1.5
	# In reverse, forward direction is -X. car_b at (-6.0, 0, 0) is ahead in reverse direction!
	car_b.global_position = Vector3(-6.0, 0.0, 0.0)
	assert(
		tm.find_blocker(car_a) == car_b,
		"car_b at -6.0m must be blocker for car_a reversing along -X"
	)
	# car_b at (+6.0, 0, 0) is behind reversing car_a
	car_b.global_position = Vector3(6.0, 0.0, 0.0)
	assert(
		tm.find_blocker(car_a) == null,
		"car_b at +6.0m must NOT be blocker for car_a reversing along -X"
	)
	# Test 8: Ghost in lane 0
	car_a.state = Car.State.TO_SPOT
	car_a.speed = 4.5
	var ghost = car_scene.instantiate()
	ghost.car_type = Car.CarType.SEDAN
	ghost.car_width = 2.0
	ghost.motion = Car.Motion.PATH
	tm.add_child(ghost)
	ghost.global_position = Vector3(3.0, 0.0, 0.0)
	# ghost is NOT in lot_cars, but in lane 0 cars
	assert(tm.lanes.size() > 0, "lanes must not be empty")
	tm.lanes[0].cars.append(ghost)
	car_b.global_position = Vector3(50.0, 0.0, 0.0)
	assert(tm.find_blocker(car_a) == ghost, "ghost in lane 0 must be detected as blocker")
	tm.lanes[0].cars.erase(ghost)
	ghost.queue_free()

	print("FIND_BLOCKER_TEST: SUCCESS - all 8 blocker test cases passed!")
	main.get_tree().quit(0)


func _run_test_reverse_safety() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()

	# Find a spot in the lot
	assert(tm.lot != null and tm.lot.spots.size() > 0, "ParkingLot must have spots")
	var spot = tm.lot.spots[0]
	var car_scene = load("res://cars/passenger_car.tscn")
	var parked_car = car_scene.instantiate()
	parked_car.car_type = Car.CarType.SEDAN
	parked_car.state = Car.State.PARKED
	parked_car.spot = spot
	parked_car.dwell_left = 0.0
	parked_car.speed = 0.0
	tm.add_child(parked_car)
	parked_car.global_position = spot.position
	tm.lot_cars.append(parked_car)

	var aisle_car = car_scene.instantiate()
	aisle_car.car_type = Car.CarType.SEDAN
	aisle_car.state = Car.State.TO_EXIT
	aisle_car.speed = 4.5
	tm.add_child(aisle_car)
	# Place aisle car within 8m of spot along X
	aisle_car.global_position = Vector3(spot.x + 5.0, 0.0, -20.0)
	tm.lot_cars.append(aisle_car)

	# Test 1: Moving car within 8m along aisle -> can_reverse_out returns false
	assert(
		tm.can_reverse_out(parked_car) == false,
		"can_reverse_out must be false when moving car is within 8m along aisle"
	)

	# Update lot cars for 1 tick -> parked_car must delay reversing and stay PARKED
	tm._update_lot_cars(0.016)
	assert(
		parked_car.state == Car.State.PARKED, "parked car must remain PARKED while aisle is busy"
	)

	# Test 2: Car within 8m but STOPPED -> does not block reverse
	aisle_car.speed = 0.0
	assert(
		tm.can_reverse_out(parked_car) == true,
		"can_reverse_out must be true when nearby car is stopped"
	)

	# Test 3: Moving car beyond 8m along aisle -> does not block reverse
	aisle_car.speed = 4.5
	aisle_car.global_position = Vector3(spot.x + 10.0, 0.0, -20.0)
	assert(
		tm.can_reverse_out(parked_car) == true,
		"can_reverse_out must be true when moving car is > 8m away"
	)

	# Update lot cars for 1 tick -> parked_car transitions to REVERSING_OUT
	tm._update_lot_cars(0.016)
	assert(
		parked_car.state == Car.State.REVERSING_OUT,
		"parked car must transition to REVERSING_OUT once aisle is clear"
	)
	assert(parked_car.speed < 0.0, "reversing car must have negative speed")

	print(
		"REVERSE_SAFETY_TEST: SUCCESS - parked car delays reversing while moving lot car is within 8m, and reverses once clear!"
	)
	main.get_tree().quit(0)


func _run_test_priority_arbitration() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()

	var car_scene = load("res://cars/passenger_car.tscn")

	# Case 1: head-on, each car's body sits in the other's route -> both stop, whatever their priority
	var east = Curve3D.new()
	east.add_point(Vector3(0.0, 0.0, 0.0))
	east.add_point(Vector3(30.0, 0.0, 0.0))
	var west = Curve3D.new()
	west.add_point(Vector3(30.0, 0.0, 0.0))
	west.add_point(Vector3(0.0, 0.0, 0.0))

	var car1: Car = car_scene.instantiate()
	car1.car_type = Car.CarType.SEDAN
	tm.add_child(car1)
	car1.state = Car.State.TO_SPOT
	car1.follow_path(east)
	car1.path_distance = 10.0  # x = 10, facing +X
	car1.speed = 4.0
	car1.update_presentation()
	tm.lot_cars.append(car1)

	var car2: Car = car_scene.instantiate()
	car2.car_type = Car.CarType.SEDAN
	tm.add_child(car2)
	car2.state = Car.State.TO_EXIT
	car2.follow_path(west)
	car2.path_distance = 14.0  # x = 16, facing -X toward car1
	car2.speed = 4.0
	car2.update_presentation()
	tm.lot_cars.append(car2)

	assert(tm.find_blocker(car1) == car2, "Head-on: TO_SPOT must not drive into TO_EXIT")
	assert(tm.find_blocker(car2) == car1, "Head-on: TO_EXIT must not drive into TO_SPOT")

	# Crossing: car1 eastbound along z=0, car2 southbound along x=15; both 5m from the crossing
	var south = Curve3D.new()
	south.add_point(Vector3(15.0, 0.0, -15.0))
	south.add_point(Vector3(15.0, 0.0, 15.0))
	var north = Curve3D.new()
	north.add_point(Vector3(15.0, 0.0, 15.0))
	north.add_point(Vector3(15.0, 0.0, -15.0))
	var place_crossing := func(rev: bool) -> void:
		if rev:
			car2.follow_path(north, true)
			car2.path_distance = 20.0  # z = -5, reversing toward +Z
			car2.speed = -TrafficManager.V_PARK
			car2.desired_speed = -TrafficManager.V_PARK
		else:
			car2.follow_path(south)
			car2.path_distance = 10.0  # z = -5, facing +Z
			car2.speed = 4.0
			car2.desired_speed = 4.0
		car2.update_presentation()
		car1.path_distance = 10.0
		car1.speed = 4.0
		car1.update_presentation()

	# Case 2: equal distance to the crossing -> tie broken by priority TO_SPOT > TO_EXIT
	car1.state = Car.State.TO_SPOT
	car2.state = Car.State.TO_EXIT
	place_crossing.call(false)
	assert(tm.find_blocker(car1) == null, "Crossing tie: TO_SPOT proceeds")
	assert(tm.find_blocker(car2) == car1, "Crossing tie: TO_EXIT yields to TO_SPOT")

	# Case 3: a reversing car owns its whole back-out route -> crossing traffic waits for it
	car1.state = Car.State.TO_EXIT
	car2.state = Car.State.REVERSING_OUT
	place_crossing.call(true)
	assert(tm.find_blocker(car1) == car2, "TO_EXIT must stop for a reversing car's route")
	assert(tm.find_blocker(car2) == null, "REVERSING_OUT keeps backing out")

	# Case 4: the car nearer the crossing goes first, even with lower priority
	car1.state = Car.State.TO_SPOT
	car2.state = Car.State.TO_EXIT
	place_crossing.call(false)
	car2.path_distance = 12.0  # z = -3, nose almost in car1's route
	car2.update_presentation()
	assert(tm.find_blocker(car2) == null, "Nearer TO_EXIT proceeds through the crossing")
	assert(tm.find_blocker(car1) == car2, "Farther TO_SPOT yields to the nearer car")

	# Case 5: yielding car stops, then resumes once the crossing clears
	place_crossing.call(false)
	for i in range(20):
		tm._update_lot_cars(0.016)

	assert(car1.state == Car.State.TO_SPOT, "car1 must remain in TO_SPOT")
	assert(car2.state == Car.State.TO_EXIT, "car2 must remain in TO_EXIT")
	assert(car2.desired_speed == 0.0, "car2 must have desired_speed 0.0")
	assert(car2.speed < 0.1, "car2 must stop (speed ~ 0)")
	assert(car1.speed > 1.0, "car1 (higher priority) must continue moving")

	# car1 moves past the crossing
	car1.path_distance = 25.0
	car1.update_presentation()
	assert(tm.find_blocker(car2) == null, "car2 blocker should clear once car1 is past")

	for i in range(20):
		tm._update_lot_cars(0.016)
	assert(car2.desired_speed > 0.0, "car2 desired_speed must restore once blocker clears")
	assert(car2.speed > 0.5, "car2 must resume moving once blocker clears")

	# Case 6: REVERSING_OUT yielding on first tick does not prematurely finish or release spot
	assert(tm.lot != null and tm.lot.spots.size() > 0, "ParkingLot must have spots")
	var test_spot = tm.lot.spots[0]
	var rev_path = tm.lot.reverse_route(test_spot)
	var car3: Car = car_scene.instantiate()
	car3.car_type = Car.CarType.SEDAN
	car3.spot = test_spot
	tm.add_child(car3)
	car3.state = Car.State.REVERSING_OUT
	car3.follow_path(rev_path, true)  # reversed path
	car3.speed = -TrafficManager.V_PARK
	car3.desired_speed = -TrafficManager.V_PARK
	car3.update_presentation()
	tm.lot_cars.append(car3)

	# Place a TO_SPOT car directly blocking the reversing car
	var car4: Car = car_scene.instantiate()
	car4.car_type = Car.CarType.SEDAN
	car4.state = Car.State.TO_SPOT
	car4.speed = 0.0
	tm.add_child(car4)
	# Place car4 behind reversing car3 (along reverse direction)
	var rev_heading = car3.get_heading()
	car4.global_position = car3.global_position - rev_heading * 2.5
	tm.lot_cars.append(car4)

	assert(tm.find_blocker(car3) == car4, "car3 must find car4 as blocker")
	assert(tm._update_car_yielding(car3, 0.0) == true, "car3 (REVERSING_OUT) must yield to car4")
	# Tick 1 update
	tm._update_lot_cars(0.016)
	assert(
		car3.state == Car.State.REVERSING_OUT, "car3 must remain in REVERSING_OUT while yielding"
	)
	assert(car3.spot == test_spot, "car3 must not release spot while yielding")
	assert(car3.desired_speed == 0.0, "car3 desired_speed must be 0.0 when yielding")

	print(
		"PRIORITY_ARBITRATION_TEST: SUCCESS - Priority arbitration TO_SPOT > TO_EXIT > REVERSING_OUT verified!"
	)
	main.get_tree().quit(0)


func _run_test_deadlock_watchdog() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()

	# Activate debug overlay to verify HUD reflects live counts throughout deadlock lifecycle
	var dbg: TrafficDebug = tm.debug_overlay
	assert(dbg != null, "debug_overlay must exist")
	dbg.visible = true
	assert(dbg.hud_layer.visible == true, "HUD layer must be visible when overlay is active")
	dbg.update_hud()
	var initial_hud: String = dbg.get_hud_text()
	assert(
		"watchdog_fires: 0" in initial_hud,
		"Initial HUD must show 0 watchdog fires: %s" % initial_hud
	)
	assert(
		"max_stuck_time: 0.0s" in initial_hud,
		"Initial HUD must show 0.0s max stuck: %s" % initial_hud
	)
	var path1 = Curve3D.new()
	path1.add_point(Vector3(0.0, 0.0, 0.0))
	path1.add_point(Vector3(30.0, 0.0, 0.0))

	var path2 = Curve3D.new()
	path2.add_point(Vector3(30.0, 0.0, 0.0))
	path2.add_point(Vector3(0.0, 0.0, 0.0))

	var car_scene = load("res://cars/passenger_car.tscn")
	var car1: Car = car_scene.instantiate()
	car1.car_type = Car.CarType.SEDAN
	car1.car_width = 2.0
	car1.car_length = 4.2
	tm.add_child(car1)
	car1.follow_path(path1)
	car1.path_distance = 10.0
	car1.speed = 4.0
	car1.state = Car.State.TO_SPOT
	car1.update_presentation()
	tm.lot_cars.append(car1)

	var car2: Car = car_scene.instantiate()
	car2.car_type = Car.CarType.SEDAN
	car2.car_width = 2.0
	car2.car_length = 4.2
	tm.add_child(car2)
	car2.follow_path(path2)
	car2.path_distance = 14.0  # x = 16.0, facing -X
	car2.speed = 4.0
	car2.state = Car.State.TO_SPOT
	car2.update_presentation()
	tm.lot_cars.append(car2)

	var higher_car := car1 if car1.get_instance_id() > car2.get_instance_id() else car2
	var lower_car := car2 if car1.get_instance_id() > car2.get_instance_id() else car1

	assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
	assert(tm.find_blocker(car2) == car1, "car2 must find car1 as blocker")

	# Step for 3.8s (240 ticks of 0.016s) -> watchdog should NOT have fired yet (< 4.0s)
	for i in range(240):
		tm._update_lot_cars(0.016)
		dbg.update_hud()

	assert(tm.stats["watchdog_fires"] == 0, "Watchdog must not fire before 4.0s")
	assert(car1.speed < 0.1 and car2.speed < 0.1, "Both cars must be stopped")
	assert(
		car1.blocked_time >= 3.8 and car2.blocked_time >= 3.8, "Both cars must track blocked_time"
	)
	assert(tm.stats["max_stuck_time"] >= 3.8, "max_stuck_time must track blocked_time")
	var pre_fire_hud: String = dbg.get_hud_text()
	assert(
		"watchdog_fires: 0" in pre_fire_hud,
		"Pre-fire HUD must show 0 watchdog fires: %s" % pre_fire_hud
	)
	assert(
		"max_stuck_time: 3.8s" in pre_fire_hud,
		"Pre-fire HUD must show 3.8s max stuck: %s" % pre_fire_hud
	)

	# Step another 20 ticks (0.32s, reaching 4.12s > 4.0s) -> watchdog MUST fire!
	for i in range(20):
		tm._update_lot_cars(0.016)
		dbg.update_hud()

	assert(tm.stats["watchdog_fires"] == 1, "Watchdog must fire once mutual block exceeds 4.0s")
	assert(tm.stats["max_stuck_time"] >= 4.0, "max_stuck_time must be >= 4.0s")
	var post_fire_hud: String = dbg.get_hud_text()
	assert(
		"watchdog_fires: 1" in post_fire_hud,
		"Post-fire HUD must show 1 watchdog fire: %s" % post_fire_hud
	)
	assert(
		"max_stuck_time: 4.1s" in post_fire_hud or "max_stuck_time: 4.0s" in post_fire_hud,
		"Post-fire HUD must show >= 4.0s max stuck: %s" % post_fire_hud
	)
	assert(tm._is_ignoring(higher_car, lower_car) == true, "Higher ID car must ignore lower ID car")
	assert(
		tm._is_ignoring(lower_car, higher_car) == false,
		"Lower ID car must NOT ignore higher ID car"
	)
	# Run another 20 ticks -> higher_car must accelerate and move while lower_car remains stopped
	for i in range(20):
		tm._update_lot_cars(0.016)

	assert(higher_car.speed > 0.5, "Higher ID car must accelerate and proceed (ignoring blocker)")
	assert(lower_car.speed < 0.1, "Lower ID car must stay stopped and yield")
	assert(lower_car.desired_speed == 0.0, "Lower ID car desired speed must be 0.0")

	# Move higher_car well past lower_car to simulate clear conflict
	higher_car.path_distance = 28.0
	higher_car.update_presentation()
	for i in range(20):
		tm._update_lot_cars(0.016)

	assert(
		tm.find_blocker(lower_car) == null, "Lower car blocker must clear once higher car passes"
	)
	assert(lower_car.speed > 0.5, "Lower car must resume moving once conflict is cleared")
	# Verify HUD reflects live stall counts
	var spot = tm.lot.spots[0]
	spot.state = ParkingSpot.State.RESERVED
	tm.lot.spot_changed.emit(spot)
	var final_hud: String = dbg.get_hud_text()
	assert("1 reserved" in final_hud, "HUD line must reflect live reserved count: %s" % final_hud)
	assert(
		"watchdog_fires: 1" in final_hud,
		"HUD line must preserve watchdog fire count: %s" % final_hud
	)

	print(
		"DEADLOCK_WATCHDOG_TEST: SUCCESS - Watchdog triggered at 4.0s, tiebreaker cleanly resolved deadlock!"
	)
	main.get_tree().quit(0)


func _run_test_car_headlights() -> void:
	var orig_tod := GameState.time_of_day
	GameState.set_time_of_day(GameState.TimeOfDay.DAY)
	await main.get_tree().process_frame

	var pcar_scene = load("res://cars/passenger_car.tscn")
	var pcar: Car = pcar_scene.instantiate()
	pcar.car_type = Car.CarType.SEDAN
	main.add_child(pcar)

	var truck_scene = load("res://cars/truck.tscn")
	var truck: Car = truck_scene.instantiate()
	main.add_child(truck)
	await main.get_tree().process_frame

	# 1. Day: headlights must be off
	assert(
		pcar.headlamp != null and pcar.headlamp.visible == false,
		"Passenger car headlamp should be off during the day"
	)
	assert(
		truck.headlamp != null and truck.headlamp.visible == false,
		"Truck headlamp should be off during the day"
	)
	for m in pcar._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == false,
			"Passenger car headlight mesh should be off during the day"
		)
	for m in truck._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == false,
			"Truck headlight mesh should be off during the day"
		)

	# 2. Night: moving cars turn headlights on
	GameState.set_time_of_day(GameState.TimeOfDay.NIGHT)
	assert(pcar.headlamp.visible == true, "Passenger car headlamp should be on at night")
	assert(truck.headlamp.visible == true, "Truck headlamp should be on at night")
	for m in pcar._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == true,
			"Passenger car headlight mesh should be illuminated at night"
		)
	for m in truck._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == true,
			"Truck headlight mesh should be illuminated at night"
		)

	# 3. Parked: headlights turn off even at night
	pcar.state = Car.State.PARKED
	assert(pcar.headlamp.visible == false, "Parked car headlamp should be off at night")
	for m in pcar._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == false,
			"Parked car headlight mesh should be off at night"
		)

	# 4. Back to Day: headlights remain off
	pcar.state = Car.State.CRUISING
	GameState.set_time_of_day(GameState.TimeOfDay.DAY)
	assert(
		pcar.headlamp.visible == false, "Passenger car headlamp should be off when returning to day"
	)
	assert(truck.headlamp.visible == false, "Truck headlamp should be off when returning to day")
	for m in pcar._headlight_meshes:
		var mat := m.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled == false,
			"Passenger car headlight mesh should be off when returning to day"
		)

	# Restore state
	GameState.set_time_of_day(orig_tod)
	pcar.queue_free()
	truck.queue_free()

	print("CAR_HEADLIGHTS_TEST: SUCCESS - --test-car-headlights passed cleanly!")
	main.get_tree().quit(0)
	return


func _run_test_car_exhaust() -> void:
	await main.get_tree().process_frame

	# 1. Car with has_exhaust = false
	var pcar_scene = load("res://cars/passenger_car.tscn")
	var car_clean: Car = pcar_scene.instantiate()
	car_clean.car_type = Car.CarType.SEDAN
	car_clean.has_exhaust = false
	main.add_child(car_clean)
	await main.get_tree().process_frame

	assert(car_clean.has_exhaust == false, "Car should have has_exhaust = false")
	for em in car_clean._exhaust_emitters:
		assert(em.emitting == false, "Clean car should not have emitting exhaust particles")

	# 2. Car with has_exhaust = true (Sedan)
	var car_smog: Car = pcar_scene.instantiate()
	car_smog.car_type = Car.CarType.SEDAN
	car_smog.has_exhaust = true
	main.add_child(car_smog)
	await main.get_tree().process_frame

	assert(car_smog.has_exhaust == true, "Car should have has_exhaust = true")
	assert(car_smog.exhaust_pipe != null, "Car should have an exhaust pipe")
	assert(car_smog.exhaust_pipe.visible == true, "Exhaust pipe should be visible")
	assert(
		car_smog.exhaust_pipe.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"Exhaust pipe should have cast_shadow off"
	)
	assert(car_smog.exhaust_pipe.position.x < -1.5, "Exhaust pipe should be at the rear (-X)")
	assert(car_smog.exhaust_particles != null, "Car should have exhaust smog particles")
	assert(
		car_smog.exhaust_particles.local_coords == false,
		"Exhaust smog should use world coordinates (local_coords = false) for realistic trail"
	)
	assert(car_smog.exhaust_particles.amount > 0, "Exhaust smog should have > 0 amount")
	assert(
		car_smog.exhaust_particles.color_ramp != null,
		"Exhaust smog should have a color/alpha fade ramp"
	)
	assert(
		car_smog.exhaust_particles.scale_amount_curve != null,
		"Exhaust smog should have an expansion curve"
	)

	# Cruising -> emitting
	car_smog.state = Car.State.CRUISING
	assert(car_smog.exhaust_particles.emitting == true, "Cruising car should spew exhaust smog")

	# Parked -> stop emitting (engine off)
	car_smog.state = Car.State.PARKED
	assert(car_smog.exhaust_particles.emitting == false, "Parked car should turn off exhaust smog")

	# Back to cruising -> resume emitting
	car_smog.state = Car.State.CRUISING
	assert(car_smog.exhaust_particles.emitting == true, "Cruising car should resume exhaust smog")

	# 3. Commercial truck with has_exhaust = true
	var truck_scene = load("res://cars/truck.tscn")
	var truck: Car = truck_scene.instantiate()
	truck.has_exhaust = true
	main.add_child(truck)
	await main.get_tree().process_frame
	assert(truck.exhaust_pipe != null, "Truck should have exhaust pipe")
	assert(truck.exhaust_particles != null, "Truck should have exhaust particles")
	assert(truck.exhaust_particles.emitting == true, "Truck should emit smog when cruising")

	# 4. Taxi with existing modeled exhaust node
	var taxi_scene = load("res://cars/taxi.tscn")
	var taxi: Car = taxi_scene.instantiate()
	taxi.has_exhaust = true
	main.add_child(taxi)
	await main.get_tree().process_frame
	assert(taxi.exhaust_pipe != null, "Taxi should find existing exhaust pipe")
	assert(taxi.exhaust_particles != null, "Taxi should have exhaust particles")
	assert(taxi.exhaust_particles.emitting == true, "Taxi should emit smog when cruising")

	# 5. Ford F-150 rolling coal smokestacks vs stock exhaust
	var f150_coal: Car = pcar_scene.instantiate()
	f150_coal.car_type = Car.CarType.F150
	f150_coal.has_smokestacks = true
	main.add_child(f150_coal)

	var f150_stock: Car = pcar_scene.instantiate()
	f150_stock.car_type = Car.CarType.F150
	f150_stock.has_smokestacks = false
	f150_stock.has_exhaust = true
	main.add_child(f150_stock)
	await main.get_tree().process_frame

	var f150_coal_model := f150_coal.get_active_model()
	var stack_l := f150_coal_model.get_node_or_null("ExhaustStackL") as Node3D
	var stack_r := f150_coal_model.get_node_or_null("ExhaustStackR") as Node3D
	assert(
		stack_l != null and stack_l.visible == true,
		"F-150 with smokestacks must show ExhaustStackL"
	)
	assert(
		stack_r != null and stack_r.visible == true,
		"F-150 with smokestacks must show ExhaustStackR"
	)
	assert(
		f150_coal._exhaust_emitters.size() == 2,
		"F-150 with smokestacks must have 2 exhaust emitters"
	)
	assert(
		f150_coal.exhaust_particles.color_ramp == Car._coal_gradient,
		"F-150 smokestacks should use coal color gradient"
	)
	assert(
		f150_coal.exhaust_particles.scale_amount_curve == Car._coal_scale_curve,
		"F-150 smokestacks should use coal expansion curve"
	)
	assert(
		f150_coal_model.get_node_or_null("ExhaustPipe") == null,
		"F-150 with smokestacks should not have under-bumper ExhaustPipe"
	)

	var f150_stock_model := f150_stock.get_active_model()
	var stock_stack_l := f150_stock_model.get_node_or_null("ExhaustStackL") as Node3D
	var stock_stack_r := f150_stock_model.get_node_or_null("ExhaustStackR") as Node3D
	assert(
		stock_stack_l == null or stock_stack_l.visible == false,
		"Stock F-150 must hide ExhaustStackL"
	)
	assert(
		stock_stack_r == null or stock_stack_r.visible == false,
		"Stock F-150 must hide ExhaustStackR"
	)
	assert(
		f150_stock.exhaust_pipe != null,
		"Stock F-150 with exhaust must have under-bumper exhaust pipe"
	)
	assert(f150_stock.exhaust_pipe.name == "ExhaustPipe", "Stock F-150 pipe must be ExhaustPipe")
	assert(f150_stock._exhaust_emitters.size() == 1, "Stock F-150 should have 1 exhaust emitter")
	assert(
		f150_stock.exhaust_particles.color_ramp == Car._smog_gradient,
		"Stock F-150 should use normal smog color gradient"
	)

	# Dynamic toggle check
	f150_stock.has_smokestacks = true
	assert(stock_stack_l.visible == true, "Toggling has_smokestacks=true must show smokestacks")
	assert(
		f150_stock._exhaust_emitters.size() == 2,
		"Toggling has_smokestacks=true must create 2 coal emitters"
	)

	# 6. F-150 natural smokestack distribution: some have them, but not all
	var f150_samples: Array[Car] = []
	var f150_stack_count := 0
	for i in range(40):
		var fc: Car = pcar_scene.instantiate()
		fc.car_type = Car.CarType.F150
		main.add_child(fc)
		f150_samples.append(fc)
	await main.get_tree().process_frame

	for fc in f150_samples:
		if fc.has_smokestacks:
			f150_stack_count += 1
	assert(
		f150_stack_count > 0 and f150_stack_count < 40,
		"Some F-150s should roll smokestacks, but not all (got %d / 40)" % f150_stack_count
	)
	print(
		(
			"  F-150 smokestack distribution verified: %d of 40 F-150s rolled smokestacks"
			% f150_stack_count
		)
	)

	# 7. Distribution test: some of the cars get exhaust automatically
	var sample_cars: Array[Car] = []
	var exhaust_count := 0
	for i in range(30):
		var c: Car = pcar_scene.instantiate()
		main.add_child(c)
		sample_cars.append(c)
	await main.get_tree().process_frame

	for c in sample_cars:
		if c.has_exhaust:
			exhaust_count += 1
	assert(
		exhaust_count > 0 and exhaust_count < 30,
		"Only some cars should have exhaust enabled by default (got %d / 30)" % exhaust_count
	)
	print("  Exhaust distribution verified: %d of 30 cars rolled exhaust" % exhaust_count)

	# Cleanup
	car_clean.queue_free()
	car_smog.queue_free()
	truck.queue_free()
	taxi.queue_free()
	for c in sample_cars:
		c.queue_free()
	f150_coal.queue_free()
	f150_stock.queue_free()
	for fc in f150_samples:
		fc.queue_free()

	print("CAR_EXHAUST_TEST: SUCCESS - --test-car-exhaust passed cleanly!")
	main.get_tree().quit(0)
	return


func _run_test_speed_variation() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	await main.get_tree().process_frame

	var pcar_scene = load("res://cars/passenger_car.tscn")
	var van_scene = load("res://cars/van.tscn")
	var truck_scene = load("res://cars/truck.tscn")
	var ship_scene = load("res://cars/shipping_truck.tscn")
	var bus_scene = load("res://cars/bus.tscn")

	var lane = tm.lanes[1]  # Westbound middle: 21.0 - 27.0 m/s

	# 1. Verify speed calculation hierarchy
	var shipping_truck: Car = ship_scene.instantiate()
	var box_truck: Car = truck_scene.instantiate()
	var bus: Car = bus_scene.instantiate()
	var van: Car = van_scene.instantiate()
	var sedan: Car = pcar_scene.instantiate()
	sedan.car_type = Car.CarType.SEDAN
	var f150_coal: Car = pcar_scene.instantiate()
	f150_coal.car_type = Car.CarType.F150
	f150_coal.has_smokestacks = true
	var sports: Car = pcar_scene.instantiate()
	sports.car_type = Car.CarType.SPORTS

	main.add_child(shipping_truck)
	main.add_child(box_truck)
	main.add_child(bus)
	main.add_child(van)
	main.add_child(sedan)
	main.add_child(f150_coal)
	main.add_child(sports)

	var dt_speeds: Array[float] = []
	var van_speeds: Array[float] = []
	var car_speeds: Array[float] = []
	var coal_speeds: Array[float] = []
	var sports_speeds: Array[float] = []

	for k in range(25):
		dt_speeds.append(tm.calculate_car_desired_speed(lane, shipping_truck))
		dt_speeds.append(tm.calculate_car_desired_speed(lane, box_truck))
		dt_speeds.append(tm.calculate_car_desired_speed(lane, bus))
		van_speeds.append(tm.calculate_car_desired_speed(lane, van))
		car_speeds.append(tm.calculate_car_desired_speed(lane, sedan))
		coal_speeds.append(tm.calculate_car_desired_speed(lane, f150_coal))
		sports_speeds.append(tm.calculate_car_desired_speed(lane, sports))

	for spd in dt_speeds:
		assert(
			spd >= lane.min_speed * 0.77 and spd <= lane.min_speed * 0.89,
			"Delivery trucks must drive slower (0.78-0.88 min_speed): got %.2f" % spd
		)
	for spd in van_speeds:
		assert(
			spd >= lane.min_speed * 0.89 and spd <= lane.min_speed * 0.99,
			(
				"Prime/Crime van must drive slightly faster than delivery trucks (0.90-0.98 min_speed): got %.2f"
				% spd
			)
		)
	for spd in car_speeds:
		assert(
			spd >= lane.min_speed and spd <= lane.max_speed,
			"Regular cars must drive at normal lane speeds (min-max): got %.2f" % spd
		)
	for spd in coal_speeds:
		assert(
			spd >= lane.max_speed * 1.07 and spd <= lane.max_speed * 1.19,
			(
				"Rolling-coal trucks must drive faster than normal cars (1.08-1.18 max_speed): got %.2f"
				% spd
			)
		)
	for spd in sports_speeds:
		assert(
			spd >= 28.0 and spd >= lane.max_speed * 1.24,
			"Race cars must drive fastest: got %.2f" % spd
		)

	# Strict relative hierarchy: DT max < Van min < Car min < Coal min < Sports min
	var max_dt := -999.0
	for s in dt_speeds:
		max_dt = maxf(max_dt, s)
	var min_van := 999.0
	var max_van := -999.0
	for s in van_speeds:
		min_van = minf(min_van, s)
		max_van = maxf(max_van, s)
	var min_car := 999.0
	var max_car := -999.0
	for s in car_speeds:
		min_car = minf(min_car, s)
		max_car = maxf(max_car, s)
	var min_coal := 999.0
	var max_coal := -999.0
	for s in coal_speeds:
		min_coal = minf(min_coal, s)
		max_coal = maxf(max_coal, s)
	var min_sports := 999.0
	for s in sports_speeds:
		min_sports = minf(min_sports, s)

	assert(
		max_dt < min_van,
		"Delivery trucks must be slower than Prime/Crime van: %.2f vs %.2f" % [max_dt, min_van]
	)
	assert(
		max_van < min_car,
		"Prime/Crime van must be slower than normal cars: %.2f vs %.2f" % [max_van, min_car]
	)
	assert(
		max_car < min_coal,
		"Rolling coal must be faster than normal cars: %.2f vs %.2f" % [max_car, min_coal]
	)
	assert(
		max_coal < min_sports,
		"Race cars must be faster than rolling coal: %.2f vs %.2f" % [max_coal, min_sports]
	)
	print(
		(
			"  Speed hierarchy verified: Delivery Trucks (%.1f) < Crime Van (%.1f) < Normal Cars (%.1f) < Rolling Coal (%.1f) < Race Cars (%.1f)"
			% [max_dt, min_van, min_car, min_coal, min_sports]
		)
	)

	# 2. Passing / Lane Changing Verification
	# Clear cars from lane 1 and lane 2
	for c in lane.cars:
		if is_instance_valid(c):
			c.queue_free()
	lane.cars.clear()
	var lane2 = tm.lanes[2]
	for c in lane2.cars:
		if is_instance_valid(c):
			c.queue_free()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	# Scenario A: Follower is faster than lead car -> must initiate lane switch to pass
	var lead_car: Car = pcar_scene.instantiate()
	main.add_child(lead_car)
	lead_car.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 14.0, Car.CarType.SEDAN
	)
	lead_car.lane_distance = 40.0
	lead_car.speed = 14.0
	lead_car.desired_speed = 14.0
	lead_car.lane_speed = 14.0
	lane.cars.append(lead_car)

	var fast_follower: Car = pcar_scene.instantiate()
	main.add_child(fast_follower)
	fast_follower.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 26.0, Car.CarType.SEDAN
	)
	fast_follower.lane_distance = 25.0
	fast_follower.speed = 26.0
	fast_follower.desired_speed = 26.0
	fast_follower.lane_speed = 26.0
	fast_follower.lane_change_cooldown = 0.0
	lane.cars.append(fast_follower)

	tm._update_lane_traffic(lane, 0.016)

	assert(
		fast_follower.is_changing_lanes == true,
		"Faster car behind slower lead car must switch lanes to pass"
	)
	assert(
		fast_follower.turn_signal != Car.TurnSignal.NONE, "Passing car must activate turn signal"
	)
	print(
		"  Lane change pass verified: faster follower initiated lane change to pass slower lead car"
	)

	# Scenario B: Follower is slower than lead car -> must NOT initiate lane switch
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	lead_car.lane_distance = 40.0
	lead_car.speed = 26.0
	lead_car.desired_speed = 26.0
	lead_car.lane_speed = 26.0
	lane.cars.append(lead_car)

	var slow_follower: Car = pcar_scene.instantiate()
	main.add_child(slow_follower)
	slow_follower.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 20.0, Car.CarType.SEDAN
	)
	slow_follower.lane_distance = 25.0
	slow_follower.speed = 20.0
	slow_follower.desired_speed = 20.0
	slow_follower.lane_speed = 20.0
	slow_follower.lane_change_cooldown = 0.0
	lane.cars.append(slow_follower)

	tm._update_lane_traffic(lane, 0.016)

	assert(
		slow_follower.is_changing_lanes == false,
		"Follower not going faster than lead car must NOT switch lanes"
	)
	print("  No lane switch verified: slower follower stays in lane behind faster lead car")

	# Cleanup
	shipping_truck.queue_free()
	box_truck.queue_free()
	bus.queue_free()
	van.queue_free()
	sedan.queue_free()
	f150_coal.queue_free()
	sports.queue_free()
	lead_car.queue_free()
	fast_follower.queue_free()
	slow_follower.queue_free()

	print("SPEED_VARIATION_TEST: SUCCESS - --test-speed-variation passed cleanly!")
	main.get_tree().quit(0)
	return
