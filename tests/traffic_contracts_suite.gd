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
				"--test-police-siren",
				"--test-frontage-contracts",
				"--test-speed-variation",
				"--test-lane-wander",
				"--test-shortcut-contracts",
				"--test-grass-shortcuts",
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
	if "--test-police-siren" in user_args:
		_run_test_police_siren()
		return
	if "--test-frontage-contracts" in user_args:
		_run_test_frontage_contracts()
		return
	if "--test-speed-variation" in user_args or "--test-lane-wander" in user_args:
		_run_test_speed_variation()
		return
	if "--test-shortcut-contracts" in user_args or "--test-grass-shortcuts" in user_args:
		_run_test_shortcut_contracts()
		return


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


func _run_test_police_siren() -> void:
	var body_scene := load("res://cars/bodies/police_suv.tscn") as PackedScene
	for bake_mode in range(3):
		var body := body_scene.instantiate() as Node3D
		if bake_mode != 0:
			if bake_mode == 1:
				PassengerCar.MeshBakerScript.bake_car_body(body)
			else:
				PassengerCar.MeshBakerScript.bake_vehicle_model(body)
			var packed := PackedScene.new()
			assert(packed.pack(body) == OK)
			body.free()
			body = packed.instantiate()
		body.set("siren_active", false)
		main.add_child(body)
		var audio := (
			body.find_children("*", "AudioStreamPlayer3D", true, false)[0] as AudioStreamPlayer3D
		)
		assert(not audio.playing, "Siren disabled before ready must remain silent")
		var other := body_scene.instantiate() as Node3D
		main.add_child(other)
		body.set("siren_active", true)
		await main.get_tree().process_frame
		assert(audio.playing, "Enabling siren must start positional audio")
		var red_seen := false
		var blue_seen := false
		var end_time := Time.get_ticks_msec() + 900
		while Time.get_ticks_msec() < end_time:
			red_seen = red_seen or _police_lenses_lit(body.get_node("SirenRed"))
			blue_seen = blue_seen or _police_lenses_lit(body.get_node("SirenBlue"))
			await main.get_tree().process_frame
		assert(
			red_seen and blue_seen,
			"Both emergency colors must flash, including after export baking"
		)
		other.set("siren_active", false)
		other.set("siren_active", true)
		var other_lit := (
			_police_lenses_lit(other.get_node("SirenRed"))
			or _police_lenses_lit(other.get_node("SirenBlue"))
		)
		body.set("siren_active", false)
		assert(not audio.playing, "Disabling siren must stop audio")
		assert(not _police_lenses_lit(body.get_node("SirenRed")))
		assert(not _police_lenses_lit(body.get_node("SirenBlue")))
		assert(
			(
				other_lit
				and (
					_police_lenses_lit(other.get_node("SirenRed"))
					or _police_lenses_lit(other.get_node("SirenBlue"))
				)
			),
			"Disabling one SUV must not darken another SUV's lenses"
		)
		var other_audio := (
			other.find_children("*", "AudioStreamPlayer3D", true, false)[0] as AudioStreamPlayer3D
		)
		assert(other_audio.playing, "Disabling one SUV must not silence another")
		body.set("siren_active", true)
		await main.get_tree().process_frame
		assert(audio.playing, "Siren must restart after being disabled")
		body.queue_free()
		other.queue_free()
		await main.get_tree().process_frame
	print("POLICE_SIREN_TEST: SUCCESS - live and baked sirens toggle independently")
	main.get_tree().quit(0)


func _police_lenses_lit(group: Node) -> bool:
	for lens in group.find_children("*", "MeshInstance3D", true, false):
		var material := (lens as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if material.emission_enabled and material.emission_energy_multiplier > 0.0:
			return true
	return false


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

	# 2. Night: moving cars turn headlights on (staggered switch-over)
	GameState.set_time_of_day(GameState.TimeOfDay.NIGHT)
	var waited := 0.0
	while waited < 1.5:
		if pcar.headlamp.visible and truck.headlamp.visible:
			break
		await main.get_tree().process_frame
		waited += main.get_process_delta_time()
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

	# 5. Headlamp LOD: when >12 cars exist at night, only the closest 12 keep SpotLight3D active,
	# while distant cars keep emissive lens material.
	GameState.set_time_of_day(GameState.TimeOfDay.NIGHT)
	var tm: TrafficManager = main.get_node_or_null("TrafficManager") as TrafficManager
	if tm:
		var cam := main.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.global_position = Vector3(0.0, 10.0, 0.0)
		for lane in tm.lanes:
			for c in lane.cars:
				c.queue_free()
			lane.cars.clear()
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		var test_cars: Array[Car] = []
		for i in range(16):
			var c: Car = pcar_scene.instantiate()
			c.car_type = Car.CarType.SEDAN
			c.state = Car.State.CRUISING
			main.add_child(c)
			c.global_position = Vector3(float((i + 1) * 10), 0.0, 0.0)
			tm.lot_cars.append(c)
			test_cars.append(c)
		for c in test_cars:
			c.stagger_headlamps = false
			c._update_headlamps(true)
		tm.update_headlamp_lod()

		var active_spots := 0
		var emissive_active := 0
		for c in test_cars:
			if c.headlamp != null and c.headlamp.visible:
				active_spots += 1
			for m in c._headlight_meshes:
				var mat := m.material_override as StandardMaterial3D
				if mat != null and mat.emission_enabled:
					emissive_active += 1
					break
		assert(
			active_spots == TrafficManager.MAX_ACTIVE_HEADLAMPS,
			"Exactly MAX_ACTIVE_HEADLAMPS spotlights should be active (got %d)" % active_spots
		)
		assert(
			emissive_active == 16,
			"All 16 cars must retain emissive lens material at night (got %d)" % emissive_active
		)
		for i in range(12):
			assert(
				test_cars[i].headlamp.visible == true,
				"Car %d (closest) should have active spotlight" % i
			)
		for i in range(12, 16):
			assert(
				test_cars[i].headlamp.visible == false,
				"Car %d (distant) should have inactive spotlight" % i
			)
		for c in test_cars:
			tm.lot_cars.erase(c)
			c.queue_free()
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

	# 7. Cybertruck EV zero emissions: never rolls exhaust or smokestacks
	var cybertruck: Car = pcar_scene.instantiate()
	cybertruck.car_type = Car.CarType.CYBERTRUCK
	main.add_child(cybertruck)
	await main.get_tree().process_frame

	assert(cybertruck.has_exhaust == false, "Cybertruck EV must never have exhaust")
	assert(cybertruck.exhaust_pipe == null, "Cybertruck EV must not have exhaust pipe")
	assert(cybertruck.exhaust_particles == null, "Cybertruck EV must not have exhaust particles")
	assert(cybertruck._exhaust_emitters.is_empty(), "Cybertruck EV must have 0 exhaust emitters")
	var cyber_model := cybertruck.get_active_model()
	assert(cyber_model != null, "Cybertruck active model must exist")
	assert(cyber_model.name == "Cybertruck", "Cybertruck model root must be named Cybertruck")
	var cyber_lightbar := cyber_model.get_node_or_null("FrontLightBar")
	assert(cyber_lightbar != null, "Cybertruck must have FrontLightBar")
	cybertruck.queue_free()
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
	var hatchback: Car = pcar_scene.instantiate()
	hatchback.car_type = Car.CarType.HATCHBACK

	main.add_child(shipping_truck)
	main.add_child(box_truck)
	main.add_child(bus)
	main.add_child(van)
	main.add_child(sedan)
	main.add_child(f150_coal)
	main.add_child(sports)
	main.add_child(hatchback)

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

	# Scenario C: Follower begins with nonzero wander offset -> pass initiates from current_lateral_z and remains continuous
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	lead_car.lane_distance = 45.0
	lead_car.speed = 14.0
	lead_car.desired_speed = 14.0
	lead_car.lane_speed = 14.0
	lead_car.is_changing_lanes = false
	lead_car.lane_wander_offset = 0.0
	lead_car.lane_wander_start_offset = 0.0
	lead_car.lane_wander_target = 0.0
	lead_car.current_lateral_z = lane.z
	lead_car.update_presentation()
	lane.cars.append(lead_car)

	fast_follower.lane_distance = 25.0
	fast_follower.lane_id = lane.id
	fast_follower.lane_z = lane.z
	fast_follower.speed = 26.0
	fast_follower.desired_speed = 26.0
	fast_follower.lane_speed = 26.0
	fast_follower.lane_change_cooldown = 0.0
	fast_follower.is_changing_lanes = false
	var follower_initial_offset := 0.55
	fast_follower.lane_wander_offset = follower_initial_offset
	fast_follower.lane_wander_start_offset = follower_initial_offset
	fast_follower.lane_wander_target = follower_initial_offset
	fast_follower.current_lateral_z = lane.z + follower_initial_offset
	fast_follower.update_presentation()
	lane.cars.append(fast_follower)

	tm._update_lane_traffic(lane, 0.016)

	assert(
		fast_follower.is_changing_lanes == true, "Follower with nonzero offset must initiate pass"
	)
	assert(
		absf(fast_follower.lane_change_from_z - (lane.z + follower_initial_offset)) < 0.001,
		(
			"Lane change must start from current_lateral_z (lane.z + offset), got %.3f vs %.3f"
			% [fast_follower.lane_change_from_z, lane.z + follower_initial_offset]
		)
	)
	tm._apply_pending_lane_transfers()

	var prev_follower_z := fast_follower.current_lateral_z
	var pass_completed := false
	for step in range(120):
		tm._update_lane_traffic(lane, 0.016)
		tm._update_lane_traffic(lane2, 0.016)
		tm._apply_pending_lane_transfers()
		var step_delta_z := absf(fast_follower.current_lateral_z - prev_follower_z)
		assert(
			step_delta_z < 0.15,
			"Step lateral discontinuity detected during pass: step delta = %.4f" % step_delta_z
		)
		prev_follower_z = fast_follower.current_lateral_z
		if not fast_follower.is_changing_lanes:
			pass_completed = true
			break

	assert(pass_completed, "Lane change must complete cleanly within reasonable frame count")
	assert(
		(
			absf(
				(
					fast_follower.current_lateral_z
					- (fast_follower.lane_z + fast_follower.lane_wander_offset)
				)
			)
			< 0.001
		),
		"Finished lateral z must match new lane_z plus bounded wander offset"
	)
	print("  Lane change continuity verified: follower with nonzero offset transitions smoothly")

	# Scenario D: Both cars begin with nonzero wander offsets -> passing remains continuous and lead car is overtaken
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	lead_car.lane_distance = 45.0
	lead_car.speed = 14.0
	lead_car.desired_speed = 14.0
	lead_car.lane_speed = 14.0
	lead_car.is_changing_lanes = false
	var lead_offset := -0.50
	lead_car.lane_wander_offset = lead_offset
	lead_car.lane_wander_start_offset = lead_offset
	lead_car.lane_wander_target = lead_offset
	lead_car.current_lateral_z = lane.z + lead_offset
	lead_car.update_presentation()
	lane.cars.append(lead_car)

	fast_follower.lane_distance = 25.0
	fast_follower.speed = 26.0
	fast_follower.desired_speed = 26.0
	fast_follower.lane_speed = 26.0
	fast_follower.lane_change_cooldown = 0.0
	fast_follower.is_changing_lanes = false
	fast_follower.lane_id = lane.id
	fast_follower.lane_z = lane.z
	var follower_offset := 0.40
	fast_follower.lane_wander_offset = follower_offset
	fast_follower.lane_wander_start_offset = follower_offset
	fast_follower.lane_wander_target = follower_offset
	fast_follower.current_lateral_z = lane.z + follower_offset
	fast_follower.update_presentation()
	lane.cars.append(fast_follower)

	tm._update_lane_traffic(lane, 0.016)
	assert(fast_follower.is_changing_lanes == true, "Follower must initiate pass")
	assert(
		absf(fast_follower.lane_change_from_z - (lane.z + follower_offset)) < 0.001,
		"Lane change must originate at follower's current_lateral_z"
	)
	tm._apply_pending_lane_transfers()

	var prev_lead_z := lead_car.current_lateral_z
	prev_follower_z = fast_follower.current_lateral_z
	var overtaken := false
	for step in range(250):
		tm._update_lane_traffic(lane, 0.016)
		tm._update_lane_traffic(lane2, 0.016)
		tm._apply_pending_lane_transfers()

		var follower_delta := absf(fast_follower.current_lateral_z - prev_follower_z)
		var lead_delta := absf(lead_car.current_lateral_z - prev_lead_z)
		assert(follower_delta < 0.15, "Follower lateral jump detected: %.4f" % follower_delta)
		assert(lead_delta < 0.15, "Lead car lateral jump detected: %.4f" % lead_delta)
		prev_follower_z = fast_follower.current_lateral_z
		prev_lead_z = lead_car.current_lateral_z

		if fast_follower.lane_distance > lead_car.lane_distance + 5.0:
			overtaken = true
			break

	assert(overtaken, "Faster follower must overtake lead car without interruption")
	assert(lead_car.lane_id == lane.id, "Lead car must remain in its lane")
	print(
		"  Lane change continuity verified: both cars with nonzero offsets remain continuous through pass"
	)

	# Scenario E: Lead car begins with nonzero wander offset, follower begins with zero offset -> passing remains continuous
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	lead_car.lane_id = lane.id
	lead_car.lane_z = lane.z
	lead_car.lane_distance = 45.0
	lead_car.speed = 14.0
	lead_car.desired_speed = 14.0
	lead_car.lane_speed = 14.0
	lead_car.is_changing_lanes = false
	var lead_offset_e := 0.60
	lead_car.lane_wander_offset = lead_offset_e
	lead_car.lane_wander_start_offset = lead_offset_e
	lead_car.lane_wander_target = lead_offset_e
	lead_car.current_lateral_z = lane.z + lead_offset_e
	lead_car.update_presentation()
	lane.cars.append(lead_car)

	fast_follower.lane_id = lane.id
	fast_follower.lane_z = lane.z
	fast_follower.lane_distance = 25.0
	fast_follower.speed = 26.0
	fast_follower.desired_speed = 26.0
	fast_follower.lane_speed = 26.0
	fast_follower.lane_change_cooldown = 0.0
	fast_follower.is_changing_lanes = false
	fast_follower.lane_wander_offset = 0.0
	fast_follower.lane_wander_start_offset = 0.0
	fast_follower.lane_wander_target = 0.0
	fast_follower.current_lateral_z = lane.z
	fast_follower.update_presentation()
	lane.cars.append(fast_follower)

	tm._update_lane_traffic(lane, 0.016)
	assert(
		fast_follower.is_changing_lanes == true,
		"Follower must initiate pass when lead car has offset"
	)
	assert(
		absf(fast_follower.lane_change_from_z - lane.z) < 0.001,
		"Lane change must originate at follower's current_lateral_z (lane center)"
	)
	tm._apply_pending_lane_transfers()

	prev_lead_z = lead_car.current_lateral_z
	prev_follower_z = fast_follower.current_lateral_z
	overtaken = false
	for step in range(250):
		tm._update_lane_traffic(lane, 0.016)
		tm._update_lane_traffic(lane2, 0.016)
		tm._apply_pending_lane_transfers()

		var follower_delta := absf(fast_follower.current_lateral_z - prev_follower_z)
		var lead_delta := absf(lead_car.current_lateral_z - prev_lead_z)
		assert(follower_delta < 0.15, "Follower lateral jump detected: %.4f" % follower_delta)
		assert(lead_delta < 0.15, "Lead car lateral jump detected: %.4f" % lead_delta)
		prev_follower_z = fast_follower.current_lateral_z
		prev_lead_z = lead_car.current_lateral_z

		if fast_follower.lane_distance > lead_car.lane_distance + 5.0:
			overtaken = true
			break

	assert(overtaken, "Faster follower must overtake offset lead car without interruption")
	assert(lead_car.lane_id == lane.id, "Lead car must remain in its lane")
	print(
		"  Lane change continuity verified: lead car with nonzero offset remains continuous through pass"
	)

	# Scenario F: Follower in lane 2 with negative wander offset passes slower lead car into lane 1
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	lead_car.lane_id = lane2.id
	lead_car.lane_z = lane2.z
	lead_car.lane_distance = 45.0
	lead_car.speed = 14.0
	lead_car.desired_speed = 14.0
	lead_car.lane_speed = 14.0
	lead_car.is_changing_lanes = false
	lead_car.lane_wander_offset = 0.0
	lead_car.lane_wander_start_offset = 0.0
	lead_car.lane_wander_target = 0.0
	lead_car.current_lateral_z = lane2.z
	lead_car.update_presentation()
	lane2.cars.append(lead_car)

	fast_follower.lane_id = lane2.id
	fast_follower.lane_z = lane2.z
	fast_follower.lane_distance = 25.0
	fast_follower.speed = 26.0
	fast_follower.desired_speed = 26.0
	fast_follower.lane_speed = 26.0
	fast_follower.lane_change_cooldown = 0.0
	fast_follower.is_changing_lanes = false
	var follower_offset_f := -0.50
	fast_follower.lane_wander_offset = follower_offset_f
	fast_follower.lane_wander_start_offset = follower_offset_f
	fast_follower.lane_wander_target = follower_offset_f
	fast_follower.current_lateral_z = lane2.z + follower_offset_f
	fast_follower.update_presentation()
	lane2.cars.append(fast_follower)

	tm._update_lane_traffic(lane2, 0.016)
	assert(
		fast_follower.is_changing_lanes == true,
		"Follower with negative offset in lane 2 must initiate pass"
	)
	assert(
		absf(fast_follower.lane_change_from_z - (lane2.z + follower_offset_f)) < 0.001,
		(
			"Lane change must start from follower's current_lateral_z (lane2.z + offset), got %.3f vs %.3f"
			% [fast_follower.lane_change_from_z, lane2.z + follower_offset_f]
		)
	)
	tm._apply_pending_lane_transfers()

	prev_follower_z = fast_follower.current_lateral_z
	pass_completed = false
	for step in range(120):
		tm._update_lane_traffic(lane, 0.016)
		tm._update_lane_traffic(lane2, 0.016)
		tm._apply_pending_lane_transfers()
		var step_delta_z := absf(fast_follower.current_lateral_z - prev_follower_z)
		assert(
			step_delta_z < 0.15,
			(
				"Step lateral discontinuity detected during pass from lane 2: delta = %.4f"
				% step_delta_z
			)
		)
		prev_follower_z = fast_follower.current_lateral_z
		if not fast_follower.is_changing_lanes:
			pass_completed = true
			break

	assert(pass_completed, "Lane change from lane 2 must complete cleanly")
	assert(fast_follower.lane_id == lane.id, "Follower must now be in lane 1")
	assert(
		(
			absf(
				(
					fast_follower.current_lateral_z
					- (fast_follower.lane_z + fast_follower.lane_wander_offset)
				)
			)
			< 0.001
		),
		"Finished lateral z must match new lane_z plus bounded wander offset"
	)
	print(
		"  Lane change continuity verified: follower with negative offset in lane 2 transitions smoothly to lane 1"
	)

	# 3. Lane wander bounds verification: sedans, sports cars, buses, and shipping trucks never cross a lane boundary from wander alone
	var test_vehicles: Array[Dictionary] = [
		{"name": "Sedan", "car": sedan, "expected_width": 1.9, "expected_max_offset": 0.725},
		{"name": "Sports", "car": sports, "expected_width": 1.9, "expected_max_offset": 0.725},
		{
			"name": "Hatchback",
			"car": hatchback,
			"expected_width": 1.8,
			"expected_max_offset": 0.775
		},
		{"name": "Bus", "car": bus, "expected_width": 2.4, "expected_max_offset": 0.475},
		{
			"name": "ShippingTruck",
			"car": shipping_truck,
			"expected_width": 2.5,
			"expected_max_offset": 0.425
		},
	]

	var lane_half_w := Car.LANE_WIDTH * 0.5  # 1.875
	for v in test_vehicles:
		var c: Car = v["car"]
		var v_name: String = v["name"]
		c.setup(lane.id, lane.z, lane.direction, lane.start_x, lane.length, 20.0, c.car_type)

		assert(
			absf(c.car_width - v["expected_width"]) < 0.01,
			(
				"%s car_width mismatch: expected %.2f got %.2f"
				% [v_name, v["expected_width"], c.car_width]
			)
		)
		var max_offset := c.get_max_lane_wander_offset()
		assert(
			absf(max_offset - v["expected_max_offset"]) < 0.01,
			(
				"%s max_offset mismatch: expected %.3f got %.3f"
				% [v_name, v["expected_max_offset"], max_offset]
			)
		)
		assert(
			max_offset + (c.car_width * 0.5) <= lane_half_w - Car.SIDE_CLEARANCE + 0.001,
			"%s max offset + half width must respect SIDE_CLEARANCE" % v_name
		)

		# Simulate 40 seconds of cruising wander across multiple wander cycles
		for step in range(400):
			c.advance_simulation(0.1)
			var half_w: float = c.car_width * 0.5
			var lateral_min: float = c.current_lateral_z - half_w
			var lateral_max: float = c.current_lateral_z + half_w
			var lane_min: float = c.lane_z - lane_half_w
			var lane_max: float = c.lane_z + lane_half_w

			assert(
				lateral_min >= lane_min + Car.SIDE_CLEARANCE - 0.001,
				(
					"%s left edge crossed lane boundary during wander: %.3f < %.3f"
					% [v_name, lateral_min, lane_min]
				)
			)
			assert(
				lateral_max <= lane_max - Car.SIDE_CLEARANCE + 0.001,
				(
					"%s right edge crossed lane boundary during wander: %.3f > %.3f"
					% [v_name, lateral_max, lane_max]
				)
			)

			var xf := c.global_transform
			var half_l: float = c.car_length * 0.5
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner_world := xf * Vector3(sx * half_l, 0.0, sz * half_w)
					assert(
						corner_world.z >= lane_min - 0.01 and corner_world.z <= lane_max + 0.01,
						(
							"%s oriented corner crossed lane boundary during wander: corner.z=%.3f, lane=[%.3f, %.3f]"
							% [v_name, corner_world.z, lane_min, lane_max]
						)
					)

		# Explicitly verify clamping with extreme target offsets
		c.lane_wander_start_offset = c.lane_wander_offset
		c.lane_wander_target = 999.0
		c.lane_wander_timer = 999.0
		c.lane_wander_duration = 1.0
		c.lane_wander_elapsed = 0.0
		for step in range(25):
			c.advance_simulation(0.05)
		assert(
			c.lane_wander_offset <= max_offset + 0.001,
			(
				"%s failed to clamp positive extreme wander offset: %.3f > %.3f"
				% [v_name, c.lane_wander_offset, max_offset]
			)
		)

		c.lane_wander_start_offset = c.lane_wander_offset
		c.lane_wander_target = -999.0
		c.lane_wander_timer = 999.0
		c.lane_wander_duration = 1.0
		c.lane_wander_elapsed = 0.0
		for step in range(25):
			c.advance_simulation(0.05)
		assert(
			c.lane_wander_offset >= -max_offset - 0.001,
			(
				"%s failed to clamp negative extreme wander offset: %.3f < %.3f"
				% [v_name, c.lane_wander_offset, -max_offset]
			)
		)

	print(
		"  Lane wander bounds verified: sedans, sports cars, buses, and shipping trucks never cross a lane boundary from wander alone"
	)

	# Verify stable risk_tolerance sampled at Car.setup()
	var test_sedan: Car = pcar_scene.instantiate()
	main.add_child(test_sedan)
	test_sedan.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 20.0, Car.CarType.SEDAN
	)
	assert(
		test_sedan.risk_tolerance >= 0.0 and test_sedan.risk_tolerance <= 1.0,
		"risk_tolerance must be sampled in [0, 1]"
	)
	var initial_risk := test_sedan.risk_tolerance
	for i in range(10):
		test_sedan.advance_simulation(0.1)
	assert(
		test_sedan.risk_tolerance == initial_risk,
		"risk_tolerance must remain stable across simulation steps"
	)

	var test_bus: Car = bus_scene.instantiate()
	main.add_child(test_bus)
	test_bus.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 14.0, Car.CarType.BUS
	)
	assert(test_bus.risk_tolerance == 0.0, "Buses must never have risk tolerance")
	assert(not test_bus.is_reckless(), "Buses must never be reckless")

	test_sedan.risk_tolerance = 1.0
	assert(test_sedan.is_reckless(), "Forced risk_tolerance=1.0 on sedan must be reckless")
	test_sedan.risk_tolerance = 0.0
	assert(not test_sedan.is_reckless(), "risk_tolerance=0.0 must not be reckless")

	# Verify risk_commit_active window
	assert(not test_sedan.risk_commit_active, "risk_commit_active must be false by default")
	test_sedan.start_risk_commit(0.5)
	assert(test_sedan.risk_commit_active, "start_risk_commit must activate window")
	test_sedan.advance_simulation(0.3)
	assert(
		test_sedan.risk_commit_active, "risk_commit_active must remain true before duration expires"
	)
	test_sedan.advance_simulation(0.3)
	assert(not test_sedan.risk_commit_active, "risk_commit_active must expire after duration")

	test_sedan.risk_commit_active = true
	assert(test_sedan.risk_commit_active, "Setter must activate risk_commit_active")
	test_sedan.risk_commit_active = false
	assert(not test_sedan.risk_commit_active, "Setter must clear risk_commit_active")

	test_sedan.start_lane_change(lane.id, lane.z + 3.75, true)
	assert(
		test_sedan.risk_commit_active,
		"start_lane_change with is_risky must activate risk_commit_active"
	)
	for i in range(30):
		test_sedan.advance_simulation(0.1)
	assert(not test_sedan.is_changing_lanes, "Lane change should be complete")
	assert(not test_sedan.risk_commit_active, "Completed lane change must clear risk_commit_active")

	# Verify blocked driver evaluating a pass resets lane_change_cooldown
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	var blocked_reckless: Car = pcar_scene.instantiate()
	main.add_child(blocked_reckless)
	blocked_reckless.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 26.0, Car.CarType.SEDAN
	)
	blocked_reckless.lane_distance = 25.0
	blocked_reckless.speed = 26.0
	blocked_reckless.desired_speed = 26.0
	blocked_reckless.lane_speed = 26.0
	blocked_reckless.risk_tolerance = 1.0
	blocked_reckless.lane_change_cooldown = 0.0
	lane.cars.append(blocked_reckless)

	var blocker_lead: Car = pcar_scene.instantiate()
	main.add_child(blocker_lead)
	blocker_lead.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 14.0, Car.CarType.SEDAN
	)
	blocker_lead.lane_distance = 32.0
	blocker_lead.speed = 14.0
	blocker_lead.desired_speed = 14.0
	blocker_lead.lane_speed = 14.0
	lane.cars.append(blocker_lead)

	var target_blocker: Car = pcar_scene.instantiate()
	main.add_child(target_blocker)
	target_blocker.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 26.0, Car.CarType.SEDAN
	)
	target_blocker.lane_distance = 25.0
	lane2.cars.append(target_blocker)

	tm._update_lane_traffic(lane, 0.016)

	assert(
		not blocked_reckless.is_changing_lanes,
		"Blocked car must not change lanes when target lane is blocked"
	)
	assert(
		blocked_reckless.lane_change_cooldown > 0.0,
		"Blocked driver must reset lane_change_cooldown after evaluating pass"
	)
	print(
		"  Reckless driver pass evaluation cooldown verified: blocked reckless driver reuses lane_change_cooldown"
	)

	# Verify explicit risk mode vs normal mode on _can_swerve_to_lane()
	var swerve_car: Car = pcar_scene.instantiate()
	main.add_child(swerve_car)
	swerve_car.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 25.0, Car.CarType.SEDAN
	)
	swerve_car.lane_distance = 40.0
	swerve_car.speed = 25.0

	var target_car: Car = pcar_scene.instantiate()
	main.add_child(target_car)
	target_car.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 25.0, Car.CarType.SEDAN
	)
	# Put target_car ahead by 12.0m net gap (less than normal 16m threshold, but >= risky 7.5m threshold)
	# gap_ahead = other.dist - car.dist - 0.5*(other.len + car.len)
	# 12.0 = other.dist - 40.0 - 4.5 => other.dist = 56.5
	target_car.lane_distance = 56.5
	target_car.speed = 25.0
	target_car.lane_speed = 25.0
	lane2.cars.clear()
	lane2.cars.append(target_car)

	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject marginal forward gap (< 16m)"
	)
	assert(
		tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must accept marginal forward gap (>= 7.5m)"
	)
	print(
		"  Explicit risk mode verified: normal checks remain strict, risk mode allows marginal gap"
	)

	# Verify rear gap threshold reduction in risk mode
	# swerve_car at 40.0, target_car behind at 20.0
	# gap_behind = 40.0 - 20.0 - 4.5 = 15.5m
	# At speed 20.0: normal safe_behind = max(9.0, 4.0 + 20*0.8) = 20.0m (> 15.5m -> reject)
	# Risky safe_behind = max(4.5, 4.0 + 20*0.4) = 12.0m (< 15.5m -> accept)
	target_car.lane_distance = 20.0
	target_car.speed = 20.0
	target_car.lane_speed = 20.0
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject marginal rear gap"
	)
	assert(
		tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must accept marginal rear gap"
	)

	# Verify gaps below risky thresholds are rejected by both modes
	target_car.lane_distance = 33.0  # gap_behind = 40 - 33 - 4.5 = 2.5m (< 4.5m)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject sub-marginal rear gap"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject sub-marginal rear gap"
	)

	# Verify non-gap constraints are NOT reduced: target car changing lanes nearby rejects both
	target_car.lane_distance = 56.5
	target_car.is_changing_lanes = true
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject when target car is changing lanes"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must also reject when target car is changing lanes"
	)
	target_car.is_changing_lanes = false

	# Verify unconditional rejection of existing overlap (lead gap <= 0 or longitudinal overlap)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 0.0, 20.0, false),
		"Normal mode must reject zero lead gap"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 0.0, 20.0, true),
		"Risk mode must reject zero lead gap"
	)
	target_car.lane_distance = 42.0  # Overlapping swerve_car (at 40.0, length 4.5m)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject existing target lane overlap"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject existing target lane overlap"
	)
	target_car.lane_distance = 56.5

	# Verify unconditional rejection of wrong-direction/oncoming lanes
	# swerve_car is westbound (direction -1.0), so direction +1.0 is oncoming
	lane2.direction = 1.0
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject oncoming lane"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject oncoming lane"
	)
	lane2.direction = -1.0
	# Verify unconditional rejection of lane ends
	swerve_car.lane_distance = 10.0
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject start of lane"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject start of lane"
	)
	swerve_car.lane_distance = lane2.length - 10.0
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject end of lane"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject end of lane"
	)
	swerve_car.lane_distance = 40.0

	# Verify unconditional rejection of turn-in zones
	swerve_car.state = Car.State.APPROACHING
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject initiator approaching turn-in"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject initiator approaching turn-in"
	)
	swerve_car.state = Car.State.CRUISING
	target_car.state = Car.State.APPROACHING
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject target approaching turn-in"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject target approaching turn-in"
	)
	target_car.state = Car.State.CRUISING

	# Verify unconditional rejection of nearby simultaneous transfers
	var transfer_dummy: Car = pcar_scene.instantiate()
	main.add_child(transfer_dummy)
	transfer_dummy.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 25.0, Car.CarType.SEDAN
	)
	transfer_dummy.lane_distance = 45.0
	tm._pending_transfers.append({"car": transfer_dummy, "target_lane": lane2})
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
		"Normal mode must reject simultaneous pending transfer"
	)
	assert(
		not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
		"Risk mode must reject simultaneous pending transfer"
	)
	tm._pending_transfers.clear()
	transfer_dummy.queue_free()

	# Verify unconditional rejection of large-vehicle initiators
	for large_type in [Car.CarType.BUS, Car.CarType.SHIPPING_TRUCK, Car.CarType.TRUCK]:
		swerve_car.car_type = large_type
		assert(
			not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, false),
			"Normal mode must reject large vehicle initiator %s" % str(large_type)
		)
		assert(
			not tm._can_swerve_to_lane(swerve_car, lane2, 5.0, 20.0, true),
			"Risk mode must reject large vehicle initiator %s" % str(large_type)
		)
	swerve_car.car_type = Car.CarType.SEDAN

	print("  Gap threshold rules verified: risk mode reduces only forward/rear gap thresholds")

	# Prove normal drivers reject marginal target-lane gaps while forced reckless driver accepts it
	lane.cars.clear()
	lane2.cars.clear()
	tm._pending_transfers.clear()

	var slow_lead_car: Car = pcar_scene.instantiate()
	main.add_child(slow_lead_car)
	slow_lead_car.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 12.0, Car.CarType.SEDAN
	)
	slow_lead_car.lane_distance = 50.0
	slow_lead_car.speed = 12.0
	slow_lead_car.desired_speed = 12.0
	slow_lead_car.lane_speed = 12.0
	lane2.cars.append(slow_lead_car)

	# Target car in lane 1 ahead with marginal gap (gap_ahead = 56.5 - 40.0 - 4.5 = 12.0m, between 7.5m and 16.0m)
	var test_target_lead: Car = pcar_scene.instantiate()
	main.add_child(test_target_lead)
	test_target_lead.setup(
		lane.id, lane.z, lane.direction, lane.start_x, lane.length, 25.0, Car.CarType.SEDAN
	)
	test_target_lead.lane_distance = 56.5
	test_target_lead.speed = 25.0
	test_target_lead.desired_speed = 25.0
	test_target_lead.lane_speed = 25.0
	lane.cars.append(test_target_lead)

	# 1. Normal driver behind slow lead (fast driver, blocked by 12 m/s lead, but normal safe-gap rejects 12m marginal gap in lane 1)
	var normal_follower: Car = pcar_scene.instantiate()
	main.add_child(normal_follower)
	normal_follower.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 25.0, Car.CarType.SEDAN
	)
	normal_follower.lane_distance = 40.0
	normal_follower.speed = 25.0
	normal_follower.desired_speed = 25.0
	normal_follower.risk_tolerance = 0.1
	normal_follower.lane_change_cooldown = 0.0
	lane2.cars.append(normal_follower)

	tm._update_lane_traffic(lane2, 0.016)
	assert(
		not normal_follower.is_changing_lanes,
		"Normal driver must reject marginal target lane gap and stay on safe-gap path"
	)
	assert(
		normal_follower.lane_change_cooldown > 0.0,
		"Normal driver must reset lane_change_cooldown after rejecting pass"
	)

	# Remove normal driver
	lane2.cars.erase(normal_follower)
	normal_follower.queue_free()
	tm._pending_transfers.clear()

	# 2. Forced reckless driver in identical situation accepts the marginal gap
	var reckless_follower: Car = pcar_scene.instantiate()
	main.add_child(reckless_follower)
	reckless_follower.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 25.0, Car.CarType.SEDAN
	)
	reckless_follower.lane_distance = 40.0
	reckless_follower.speed = 25.0
	reckless_follower.desired_speed = 25.0
	reckless_follower.risk_tolerance = 0.9
	reckless_follower.force_risky_pass = true
	reckless_follower.lane_change_cooldown = 0.0
	lane2.cars.append(reckless_follower)

	tm._update_lane_traffic(lane2, 0.016)
	assert(
		reckless_follower.is_changing_lanes,
		"Forced reckless driver must accept marginal gap and initiate lane change"
	)
	assert(
		reckless_follower.risk_commit_active,
		"Reckless driver initiating risky pass must activate risk commit window"
	)

	# Remove reckless follower
	lane2.cars.erase(reckless_follower)
	reckless_follower.queue_free()
	tm._pending_transfers.clear()

	# 3. Forced reckless driver rejects unsafe sub-marginal target gap (< 7.5m)
	test_target_lead.lane_distance = 48.0  # gap_ahead = 48.0 - 40.0 - 4.5 = 3.5m (< 7.5m)
	var reckless_unsafe: Car = pcar_scene.instantiate()
	main.add_child(reckless_unsafe)
	reckless_unsafe.setup(
		lane2.id, lane2.z, lane2.direction, lane2.start_x, lane2.length, 25.0, Car.CarType.SEDAN
	)
	reckless_unsafe.lane_distance = 40.0
	reckless_unsafe.speed = 25.0
	reckless_unsafe.desired_speed = 25.0
	reckless_unsafe.risk_tolerance = 1.0
	reckless_unsafe.force_risky_pass = true
	reckless_unsafe.lane_change_cooldown = 0.0
	lane2.cars.append(reckless_unsafe)

	tm._update_lane_traffic(lane2, 0.016)
	assert(
		not reckless_unsafe.is_changing_lanes,
		"Forced reckless driver must reject unsafe sub-marginal target gap"
	)
	assert(
		reckless_unsafe.lane_change_cooldown > 0.0,
		"Forced reckless driver must reset lane_change_cooldown after rejecting unsafe gap"
	)
	lane2.cars.erase(reckless_unsafe)
	reckless_unsafe.queue_free()
	tm._pending_transfers.clear()

	# Cleanup test cars
	lane2.cars.erase(slow_lead_car)
	slow_lead_car.queue_free()
	lane.cars.erase(test_target_lead)
	test_target_lead.queue_free()
	tm._pending_transfers.clear()
	print(
		"  Safe-gap path verified: normal drivers reject marginal gap, forced reckless driver accepts"
	)

	swerve_car.queue_free()
	target_car.queue_free()
	lane2.cars.clear()

	blocked_reckless.queue_free()
	blocker_lead.queue_free()
	target_blocker.queue_free()

	test_sedan.queue_free()
	test_bus.queue_free()
	print(
		"  Driver state verified: stable risk_tolerance sampled at setup, large vehicles excluded"
	)
	# Cleanup
	shipping_truck.queue_free()
	box_truck.queue_free()
	bus.queue_free()
	van.queue_free()
	sedan.queue_free()
	f150_coal.queue_free()
	sports.queue_free()
	hatchback.queue_free()
	lead_car.queue_free()
	fast_follower.queue_free()
	slow_follower.queue_free()

	print("SPEED_VARIATION_TEST: SUCCESS - --test-speed-variation passed cleanly!")
	main.get_tree().quit(0)


func _run_test_shortcut_contracts() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	await main.get_tree().process_frame

	# Clear existing cars from lanes and lot and stop ambient simulation
	tm.set_physics_process(false)
	for lane in tm.lanes:
		lane.spawn_timer = 999999.0
		for c in lane.cars:
			c.queue_free()
		lane.cars.clear()
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	await main.get_tree().process_frame

	var pcar_scene = load("res://cars/passenger_car.tscn")

	# Scenario 21: Ensure tree exit releases every current or pending parking reservation
	if tm.lot != null and tm.lot.spots.size() >= 2:
		var spot_a: ParkingSpot = tm.lot.spots[0]
		var spot_b: ParkingSpot = tm.lot.spots[1]
		tm.lot.release(spot_a)
		tm.lot.release(spot_b)

		# Test current reservation release on tree exit
		var res_car: Car = pcar_scene.instantiate()
		main.add_child(res_car)
		tm.lot.reserve(spot_a, res_car)
		assert(spot_a.state == ParkingSpot.State.RESERVED, "spot_a must be RESERVED")
		assert(spot_a.car == res_car, "spot_a car must be res_car")
		res_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		assert(not is_instance_valid(res_car), "res_car must be freed")
		assert(
			spot_a.state == ParkingSpot.State.FREE, "spot_a must be FREE after res_car tree exit"
		)
		assert(spot_a.car == null, "spot_a car must be null after res_car tree exit")
		print("  Tree exit: current parking reservation released")

		# Test both current and pending destination spot released on tree exit
		var dual_car: Car = pcar_scene.instantiate()
		main.add_child(dual_car)
		tm.lot.reserve(spot_a, dual_car)
		tm.lot.occupy(spot_a)
		tm.lot.reserve_destination(spot_b, dual_car)
		assert(spot_a.state == ParkingSpot.State.OCCUPIED, "spot_a must be OCCUPIED")
		assert(spot_b.state == ParkingSpot.State.RESERVED, "spot_b must be RESERVED")
		assert(dual_car.spot == spot_a, "dual_car current spot must be spot_a")
		assert(dual_car.pending_destination_spot == spot_b, "dual_car pending spot must be spot_b")
		assert(
			tm.lot.check_invariants() == 0,
			"Parking lot invariants must hold with pending destination"
		)

		dual_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		assert(not is_instance_valid(dual_car), "dual_car must be freed")
		assert(spot_a.state == ParkingSpot.State.FREE, "spot_a must be FREE after tree exit")
		assert(spot_a.car == null, "spot_a car must be null")
		assert(spot_b.state == ParkingSpot.State.FREE, "spot_b must be FREE after tree exit")
		assert(spot_b.car == null, "spot_b car must be null")
		assert(tm.lot.check_invariants() == 0, "No leaked spots after dual reservation tree exit")
		print("  Tree exit: both current and pending destination reservations released cleanly")

		# Test grass shortcut link contracts
		var links := ParkingLot.get_shortcut_links()
		assert(
			ParkingLot.has_shortcut_link(&"strip_mall", &"cramped_inn"),
			"Must have strip_mall -> cramped_inn link"
		)
		for link in links:
			assert(
				ParkingLot.has_shortcut_link(link["destination_site_id"], link["source_site_id"]),
				(
					"Shortcut %s -> %s must be drivable both ways"
					% [link["source_site_id"], link["destination_site_id"]]
				)
			)
		assert(
			not ParkingLot.has_shortcut_link(&"strip_mall", &"smell"),
			"Must not infer link between strip_mall and smell"
		)

		# Candidates come only from the authored businesses, never inferred by distance
		var walgroins_spot: ParkingSpot = null
		var taco_spot: ParkingSpot = null
		for s in tm.lot.spots:
			if walgroins_spot == null and s.serves.has(&"walgroins"):
				walgroins_spot = s
			elif taco_spot == null and s.serves.has(&"taco_hell"):
				taco_spot = s
		var walgroins_candidates := ParkingLot.get_shortcut_candidate_spots(
			walgroins_spot, tm.lot.spots
		)
		assert(not walgroins_candidates.is_empty(), "Walgroins must have shortcut candidates")
		for s in walgroins_candidates:
			assert(s.serves.has(&"smell_gas"), "Walgroins shortcut must lead to Smell gas stalls")
		assert(
			ParkingLot.get_shortcut_candidate_spots(taco_spot, tm.lot.spots).is_empty(),
			"Taco Hell stalls share the north site but have no authored shortcut"
		)
		print("  Grass shortcut: bidirectional explicit links and business filters verified")

		# Test dwelling completion, single roll, and fallback to normal departure
		var sm_spot: ParkingSpot = null
		var ci_spot: ParkingSpot = null
		for s in tm.lot.spots:
			var site := ParkingLot.lot_group(s)
			if site == &"strip_mall" and sm_spot == null and s.state == ParkingSpot.State.FREE:
				sm_spot = s
			elif site == &"cramped_inn" and ci_spot == null and s.state == ParkingSpot.State.FREE:
				ci_spot = s
		if sm_spot == null or ci_spot == null:
			for s in tm.lot.spots:
				var site := ParkingLot.lot_group(s)
				if site == &"strip_mall" and sm_spot == null:
					tm.lot.release(s)
					sm_spot = s
				elif site == &"cramped_inn" and ci_spot == null:
					tm.lot.release(s)
					ci_spot = s
		tm.lot.release(taco_spot)
		assert(sm_spot != null and ci_spot != null, "Required parking spots must exist")

		# 1. Car dwelling: does not roll until dwell_left <= 0.0
		var test_sc_car: Car = pcar_scene.instantiate()
		main.add_child(test_sc_car)
		tm.lot_cars.append(test_sc_car)
		test_sc_car.state = Car.State.PARKED
		tm.lot.reserve(sm_spot, test_sc_car)
		tm.lot.occupy(sm_spot)
		test_sc_car.dwell_left = 1.0
		test_sc_car.shortcut_evaluated = false
		test_sc_car.force_shortcut = true

		tm._update_lot_cars(0.4)
		assert(test_sc_car.dwell_left > 0.0, "dwell_left must decrease but remain positive")
		assert(not test_sc_car.shortcut_evaluated, "Shortcut must not be evaluated while dwelling")
		assert(
			test_sc_car.pending_destination_spot == null,
			"pending_destination_spot must be null while dwelling"
		)

		# 2. Dwell finishes -> rolls once. With force_shortcut, reserves destination spot.
		tm._update_lot_cars(0.7)
		assert(test_sc_car.dwell_left <= 0.0, "dwell_left must have completed")
		assert(test_sc_car.shortcut_evaluated, "Shortcut must be evaluated once dwelling finishes")
		assert(
			test_sc_car.pending_destination_spot != null,
			"Destination spot must be reserved when forced"
		)
		var reserved_dest := test_sc_car.pending_destination_spot
		assert(
			reserved_dest.state == ParkingSpot.State.RESERVED, "Destination spot must be RESERVED"
		)

		# Verify single roll: subsequent update does not re-roll or overwrite destination
		tm._update_lot_cars(0.1)
		assert(
			test_sc_car.pending_destination_spot == reserved_dest,
			"Single roll invariant: destination must not change"
		)

		# Clean up test_sc_car
		test_sc_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		tm.lot_cars.clear()

		# 3. Fallback to normal departure if no link is available (Taco Hell stall)
		var no_link_car: Car = pcar_scene.instantiate()
		main.add_child(no_link_car)
		tm.lot_cars.append(no_link_car)
		no_link_car.state = Car.State.PARKED
		tm.lot.reserve(taco_spot, no_link_car)
		tm.lot.occupy(taco_spot)
		no_link_car.dwell_left = 0.05
		no_link_car.force_shortcut = true
		tm._update_lot_cars(0.1)
		assert(no_link_car.shortcut_evaluated, "Shortcut must be evaluated")
		assert(
			no_link_car.pending_destination_spot == null,
			"Fallback: car at site with no link must not reserve a shortcut destination"
		)
		no_link_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		tm.lot_cars.clear()

		# 4. Fallback to normal departure if destination lot has no available spots
		# Temporarily occupy all cramped_inn spots
		var occupied_ci_spots: Array[ParkingSpot] = []
		for s in tm.lot.spots:
			if ParkingLot.lot_group(s) == &"cramped_inn" and s.state == ParkingSpot.State.FREE:
				s.state = ParkingSpot.State.OCCUPIED
				occupied_ci_spots.append(s)

		var full_dest_car: Car = pcar_scene.instantiate()
		main.add_child(full_dest_car)
		tm.lot_cars.append(full_dest_car)
		full_dest_car.state = Car.State.PARKED
		tm.lot.reserve(sm_spot, full_dest_car)
		tm.lot.occupy(sm_spot)
		full_dest_car.dwell_left = 0.05
		full_dest_car.force_shortcut = true
		tm._update_lot_cars(0.1)
		assert(full_dest_car.shortcut_evaluated, "Shortcut must be evaluated")
		assert(
			full_dest_car.pending_destination_spot == null,
			"Fallback: when destination spots are full, car must fall back to normal departure"
		)

		# Restore occupied cramped_inn spots
		for s in occupied_ci_spots:
			s.state = ParkingSpot.State.FREE
		full_dest_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		tm.lot_cars.clear()
		assert(
			tm.lot.check_invariants() == 0, "Parking lot invariants must hold after fallback tests"
		)
		print("  Shortcut departure: roll once on dwell finish and fallback contracts verified")

		# Test: Reserve destination before movement while retaining source spot through reverse-out
		var rev_test_car: Car = pcar_scene.instantiate()
		main.add_child(rev_test_car)
		tm.lot_cars.append(rev_test_car)
		tm.lot.release(sm_spot)
		rev_test_car.state = Car.State.PARKED
		tm.lot.reserve(sm_spot, rev_test_car)
		tm.lot.occupy(sm_spot)
		rev_test_car.dwell_left = 0.0
		rev_test_car.shortcut_evaluated = false
		rev_test_car.force_shortcut = true

		# Step 1: Destination must be reserved BEFORE movement occurs
		tm._update_lot_cars(0.016)
		assert(
			rev_test_car.pending_destination_spot != null,
			"Destination must be reserved before movement"
		)
		var dest_spot := rev_test_car.pending_destination_spot
		assert(
			dest_spot.state == ParkingSpot.State.RESERVED,
			"Destination must be RESERVED before movement"
		)
		assert(dest_spot.car == rev_test_car, "Destination spot car must be rev_test_car")
		assert(
			sm_spot.state == ParkingSpot.State.OCCUPIED,
			"Source spot must still be OCCUPIED before movement"
		)
		assert(sm_spot.car == rev_test_car, "Source spot car must still be rev_test_car")
		assert(
			tm.lot.check_invariants() == 0, "No leaked spots with dual reservation before movement"
		)

		# Step 2: Car starts reversing out; both spots must be retained throughout reverse-out
		assert(
			rev_test_car.state == Car.State.REVERSING_OUT, "Car must transition to REVERSING_OUT"
		)
		# Advance partially along reverse route
		tm._update_lot_cars(0.1)
		if rev_test_car.state == Car.State.REVERSING_OUT:
			assert(rev_test_car.spot == sm_spot, "Source spot must be retained mid-reverse")
			assert(sm_spot.car == rev_test_car, "Source spot car must be rev_test_car mid-reverse")
			assert(
				rev_test_car.pending_destination_spot == dest_spot,
				"Destination reservation must be retained mid-reverse"
			)
			assert(
				dest_spot.state == ParkingSpot.State.RESERVED,
				"Destination spot must stay RESERVED mid-reverse"
			)
			assert(
				dest_spot.car == rev_test_car,
				"Destination spot car must stay rev_test_car mid-reverse"
			)
			assert(tm.lot.check_invariants() == 0, "No leaked spots mid-reverse")

		# Step 3: Complete reverse-out -> release source, promote destination, follow shortcut route
		assert(rev_test_car.path != null, "Car must have a reverse-out path")
		# Reversing starts at path_distance = length and advances backward down to 0.0
		rev_test_car.path_distance = 0.01
		tm._update_lot_cars(0.1)
		assert(
			rev_test_car.state == Car.State.SHORTCUT,
			"Car must transition to SHORTCUT after reverse-out"
		)
		assert(
			sm_spot.state == ParkingSpot.State.FREE,
			"Source spot must be released after reverse-out"
		)
		assert(sm_spot.car == null, "Source spot car must be null after reverse-out")
		assert(
			rev_test_car.pending_destination_spot == null,
			"pending_destination_spot must be cleared"
		)
		assert(rev_test_car.spot == dest_spot, "Destination spot must be promoted to car.spot")
		assert(
			dest_spot.state == ParkingSpot.State.RESERVED,
			"Promoted destination spot must remain RESERVED"
		)
		assert(dest_spot.car == rev_test_car, "Promoted destination spot car must be rev_test_car")
		assert(rev_test_car.path != null, "Car must have shortcut route path")
		assert(tm.lot.check_invariants() == 0, "No leaked spots after promotion to shortcut")

		# Step 4: Verify lower grass speed vs lot speed in SHORTCUT state
		# Position car at start of route (aisle outside grass)
		rev_test_car.path_distance = 0.5
		rev_test_car.update_presentation()
		assert(
			not ParkingLot.is_in_grass_shortcut(rev_test_car.global_position),
			"Must be outside grass at route start"
		)
		tm._update_lot_cars(0.016)
		var speed_outside: float = rev_test_car.desired_speed

		# Position car inside grass shortcut corridor
		var grass_offset := -1.0
		var sample_step := 0.2
		var curr := 0.0
		while curr < rev_test_car.path.get_baked_length():
			var p := rev_test_car.path.sample_baked(curr)
			if ParkingLot.is_in_grass_shortcut(p):
				grass_offset = curr
				break
			curr += sample_step
		assert(grass_offset >= 0.0, "Must find grass shortcut offset along route")
		rev_test_car.path_distance = grass_offset
		rev_test_car.update_presentation()
		assert(
			ParkingLot.is_in_grass_shortcut(rev_test_car.global_position),
			"Must be in grass shortcut"
		)
		tm._update_lot_cars(0.016)
		var speed_inside: float = rev_test_car.desired_speed
		assert(
			speed_inside <= TrafficManager.V_GRASS + 0.01,
			"Grass speed must be <= V_GRASS (got %f)" % speed_inside
		)
		assert(
			speed_inside < speed_outside,
			"Grass speed (%f) must be lower than lot speed (%f)" % [speed_inside, speed_outside]
		)

		# Step 5: Verify swept-footprint yielding in SHORTCUT state
		var blocker_car: Car = pcar_scene.instantiate()
		main.add_child(blocker_car)
		tm.lot_cars.append(blocker_car)
		blocker_car.motion = Car.Motion.PATH
		blocker_car.state = Car.State.TO_EXIT
		blocker_car.path = rev_test_car.path
		blocker_car.path_distance = grass_offset + 3.0
		blocker_car.global_position = rev_test_car.path.sample_baked(grass_offset + 3.0)
		blocker_car.speed = 0.0
		blocker_car.desired_speed = 0.0
		blocker_car.update_presentation()
		tm._update_lot_cars(0.016)
		var found_blocker := tm.find_blocker(rev_test_car)
		assert(
			found_blocker == blocker_car,
			"Shortcut car must detect blocker ahead in shortcut corridor"
		)
		assert(
			rev_test_car.desired_speed == 0.0,
			"Shortcut car must yield (desired_speed == 0.0) when blocked"
		)

		# Remove blocker -> car must unblock and resume
		tm.lot_cars.erase(blocker_car)
		blocker_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		tm._update_lot_cars(0.016)
		assert(tm.find_blocker(rev_test_car) == null, "Blocker must be cleared")
		assert(
			rev_test_car.desired_speed > 0.0, "Shortcut car must resume speed once blocker clears"
		)
		# Step 6: Arrival at destination spot, brief dwell, and normal lot exit
		rev_test_car.speed = 1.0
		rev_test_car.path_distance = rev_test_car.path.get_baked_length()
		tm._update_lot_cars(0.016)
		assert(
			rev_test_car.state == Car.State.PARKED,
			"Car must transition to PARKED on shortcut arrival"
		)
		assert(
			dest_spot.state == ParkingSpot.State.OCCUPIED,
			"Destination spot must be OCCUPIED on shortcut arrival"
		)
		assert(dest_spot.car == rev_test_car, "Destination spot car must be rev_test_car")
		assert(
			(
				rev_test_car.dwell_left >= TrafficManager.SHORTCUT_DWELL_MIN - 0.1
				and rev_test_car.dwell_left <= TrafficManager.SHORTCUT_DWELL_MAX + 0.1
			),
			(
				"Car must have brief dwell time [%f, %f], got %f"
				% [
					TrafficManager.SHORTCUT_DWELL_MIN,
					TrafficManager.SHORTCUT_DWELL_MAX,
					rev_test_car.dwell_left
				]
			)
		)
		assert(rev_test_car.has_taken_shortcut, "has_taken_shortcut must be true on arrival")
		assert(rev_test_car.shortcut_evaluated, "shortcut_evaluated must be true on arrival")
		assert(rev_test_car.lane_id == -1, "Parked car lane_id must be -1")
		assert(tm.lot.check_invariants() == 0, "No leaked spots upon shortcut arrival")

		# Prevent immediate shortcut chaining: car cannot take another shortcut from destination lot
		assert(
			not rev_test_car.is_eligible_for_shortcut(),
			"Car that has taken shortcut must not be eligible for shortcut chaining"
		)
		rev_test_car.shortcut_evaluated = false
		rev_test_car.force_shortcut = true
		tm._evaluate_shortcut_departure(rev_test_car)
		assert(
			rev_test_car.pending_destination_spot == null,
			"Immediate shortcut chaining must be rejected even if evaluated/forced at destination"
		)

		# Elapse brief dwell in destination spot -> reverse out
		rev_test_car.dwell_left = 0.0
		tm._update_lot_cars(0.016)
		assert(
			rev_test_car.state == Car.State.REVERSING_OUT,
			"Car must start reversing out after destination spot dwell finishes"
		)
		assert(
			rev_test_car.pending_destination_spot == null,
			"Car must not have pending destination spot during destination exit"
		)

		# Complete reverse-out -> release destination spot, enter TO_EXIT along destination lot's normal exit
		rev_test_car.path_distance = 0.01
		tm._update_lot_cars(0.016)
		assert(
			rev_test_car.state == Car.State.TO_EXIT,
			"Car must transition to TO_EXIT after reversing out of destination spot"
		)
		assert(
			dest_spot.state == ParkingSpot.State.FREE, "Destination spot must be released to FREE"
		)
		assert(dest_spot.car == null, "Destination spot car must be cleared")
		assert(rev_test_car.spot == null, "Car spot reference must be cleared")
		assert(rev_test_car.path != null, "Car must have an exit path")
		var ci_wait: Vector3 = ParkingLot.CI_WAIT_POINT
		var path_end: Vector3 = rev_test_car.path.get_point_position(
			rev_test_car.path.point_count - 1
		)
		assert(
			path_end.distance_to(ci_wait) < 1.0,
			(
				"Exit path must lead to destination lot's normal exit wait point (expected ~%s, got %s)"
				% [ci_wait, path_end]
			)
		)
		assert(tm.lot.check_invariants() == 0, "No leaked spots after destination spot exit")

		# Complete TO_EXIT -> arrive at destination lot's merge wait point
		rev_test_car.speed = 1.0
		rev_test_car.path_distance = rev_test_car.path.get_baked_length()
		tm._update_lot_cars(0.016)
		assert(
			rev_test_car.state == Car.State.WAITING_TO_MERGE,
			"Car must transition to WAITING_TO_MERGE at destination lot exit"
		)
		assert(
			rev_test_car.merge_target_lane == 3,
			"Merge target lane must be destination lot's lane (3)"
		)

		rev_test_car.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		tm.lot_cars.clear()
		assert(tm.lot.check_invariants() == 0, "No leaked spots after test car cleanup")

		# Test reservation releases on cancellation, collision, despawn, and tree exit
		var s_source: ParkingSpot = null
		var s_dest: ParkingSpot = null
		for sp in tm.lot.spots:
			if (
				sp.site_id == &"strip_mall"
				and sp.state == ParkingSpot.State.FREE
				and s_source == null
			):
				s_source = sp
			elif (
				sp.site_id == &"cramped_inn"
				and sp.state == ParkingSpot.State.FREE
				and s_dest == null
			):
				s_dest = sp
		assert(s_source != null and s_dest != null, "Must find free source and dest spots")

		# 1. Cancellation via cancel_shortcut() and cancel_reservations()
		var c_cancel: Car = pcar_scene.instantiate()
		c_cancel.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		c_cancel.state = Car.State.PARKED
		main.add_child(c_cancel)
		tm.lot.reserve(s_source, c_cancel)
		tm.lot.occupy(s_source)
		s_source.car = c_cancel
		c_cancel.spot = s_source
		tm.lot.reserve_destination(s_dest, c_cancel)
		assert(
			(
				s_source.state == ParkingSpot.State.OCCUPIED
				and s_dest.state == ParkingSpot.State.RESERVED
			)
		)
		assert(tm.lot.check_invariants() == 0, "No leaks with both current and pending spots")

		c_cancel.cancel_shortcut()
		assert(
			c_cancel.pending_destination_spot == null, "pending_destination_spot must be cleared"
		)
		assert(
			s_dest.state == ParkingSpot.State.FREE and s_dest.car == null,
			"Destination spot must be FREE"
		)
		assert(
			s_source.state == ParkingSpot.State.OCCUPIED and s_source.car == c_cancel,
			"Source spot still OCCUPIED"
		)
		assert(tm.lot.check_invariants() == 0, "No leaks after cancel_shortcut()")

		tm.lot.reserve_destination(s_dest, c_cancel)
		c_cancel.cancel_reservations()
		assert(
			c_cancel.spot == null and c_cancel.pending_destination_spot == null,
			"Both spots cleared on car"
		)
		assert(
			s_source.state == ParkingSpot.State.FREE and s_source.car == null, "Source spot FREE"
		)
		assert(s_dest.state == ParkingSpot.State.FREE and s_dest.car == null, "Dest spot FREE")
		assert(tm.lot.check_invariants() == 0, "No leaks after cancel_reservations()")
		c_cancel.queue_free()
		await main.get_tree().process_frame

		# 3. Despawn release
		var c_despawn: Car = pcar_scene.instantiate()
		c_despawn.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		main.add_child(c_despawn)
		tm.lot.reserve(s_source, c_despawn)
		tm.lot.occupy(s_source)
		c_despawn.spot = s_source
		tm.lot.reserve_destination(s_dest, c_despawn)
		assert(tm.lot.check_invariants() == 0)
		c_despawn.despawn()
		assert(s_source.state == ParkingSpot.State.FREE and s_source.car == null)
		assert(s_dest.state == ParkingSpot.State.FREE and s_dest.car == null)
		assert(tm.lot.check_invariants() == 0, "No leaks after despawn()")
		await main.get_tree().process_frame

		# 4. Tree exit release
		var c_tree: Car = pcar_scene.instantiate()
		c_tree.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		main.add_child(c_tree)
		tm.lot.reserve(s_source, c_tree)
		tm.lot.occupy(s_source)
		c_tree.spot = s_source
		tm.lot.reserve_destination(s_dest, c_tree)
		c_tree.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		assert(s_source.state == ParkingSpot.State.FREE and s_source.car == null)
		assert(s_dest.state == ParkingSpot.State.FREE and s_dest.car == null)
		assert(tm.lot.check_invariants() == 0, "No leaks after tree exit")

		# 5. Route failure / route cancellation during reverse-out fallback
		var c_cancel_route: Car = pcar_scene.instantiate()
		c_cancel_route.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		main.add_child(c_cancel_route)
		tm.lot_cars.append(c_cancel_route)
		tm.lot.reserve(s_source, c_cancel_route)
		tm.lot.occupy(s_source)
		c_cancel_route.spot = s_source
		tm.lot.reserve_destination(s_dest, c_cancel_route)
		c_cancel_route.state = Car.State.REVERSING_OUT
		c_cancel_route.follow_path(ParkingLot.reverse_route(s_source), true)
		c_cancel_route.speed = -TrafficManager.V_PARK
		c_cancel_route.desired_speed = -TrafficManager.V_PARK
		var orig_site: StringName = s_dest.site_id
		s_dest.site_id = &"smell"
		c_cancel_route.path_distance = 0.01
		tm._update_lot_cars(0.1)
		s_dest.site_id = orig_site
		assert(
			c_cancel_route.state == Car.State.TO_EXIT,
			"Car must fallback to TO_EXIT on route cancellation"
		)
		assert(
			c_cancel_route.pending_destination_spot == null,
			"Pending destination spot must be cleared"
		)
		assert(
			s_dest.state == ParkingSpot.State.FREE and s_dest.car == null,
			"Destination spot released to FREE"
		)
		assert(
			s_source.state == ParkingSpot.State.FREE and s_source.car == null,
			"Source spot released to FREE"
		)
		assert(
			tm.lot.check_invariants() == 0,
			"No leaks after shortcut cancellation during reverse-out"
		)
		c_cancel_route.queue_free()
		tm.lot_cars.clear()
		await main.get_tree().process_frame
		print("  Spot release on cancellation, collision, despawn, and tree exit verified")
		print("  Destination arrival, brief dwell, and normal lot exit verified")
	print("SHORTCUT_CONTRACTS_TEST: SUCCESS - --test-shortcut-contracts passed cleanly!")
	main.get_tree().quit(0)
	return
