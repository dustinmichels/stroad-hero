extends Node3D

const BloodSplatScript = preload("res://blood_splat.gd")

@onready var mats: CharacterBody3D = $Mats
@onready var hud: CanvasLayer = $HUD
@onready var blood_splats: Node3D = $BloodSplats
var _test_frames: int = 0
var _test_car: Car = null
var _test_follower: Car = null
var _saw_reversing: bool = false
var _saw_to_exit: bool = false
var _saw_waiting: bool = false
var _ghost_registered: bool = false
var _follower_braked: bool = false
var _handoff_verified: bool = false
var _passing_car: Car = null
var _gap_test_stage: int = 0
var _saw_hold_position: bool = false
var _saw_gap_merge: bool = false
var _saw_follower_yield: bool = false
var _mats_testing: bool = false
var _mats_start_frame: int = 0
var _mats_stage: int = 0
var _saw_lc_cruising: bool = false
var _saw_lc_decision: bool = false
var _saw_lc_braking: bool = false
var _saw_lc_turn: bool = false
var _saw_lc_park: bool = false
var _saw_lc_dwell: bool = false
var _saw_lc_reverse: bool = false
var _saw_lc_exit_aisle: bool = false
var _saw_lc_wait: bool = false
var _saw_lc_merge: bool = false
var _saw_lc_post_merge_cruise: bool = false
var _saw_lc_despawn: bool = false
func _ready() -> void:
	if mats:
		mats.died.connect(_on_player_died)
	if "--test-mats-blocker" in OS.get_cmdline_user_args() or "--test-mats-interaction" in OS.get_cmdline_user_args():
		var car_scene = load("res://car.tscn")
		_test_car = car_scene.instantiate()
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.state = Car.State.WAITING_TO_MERGE
		add_child(_test_car)
		_test_car.global_position = Vector3(9.0, 0.0, -9.6)
		_test_car.rotation.y = -PI / 2.0  # facing +Z
		_test_car._update_blocker_layer()
		mats.global_position = Vector3(9.0, 0.5, -13.0)
	if "--test-exit-route" in OS.get_cmdline_user_args():
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null and traffic_mgr.lot_cars.size() > 0, "TrafficManager must have seeded cars")
		_test_car = traffic_mgr.lot_cars[0]
		_test_car.dwell_left = 0.0
	if "--test-merge-reentry" in OS.get_cmdline_user_args():
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null and traffic_mgr.lot_cars.size() > 0, "TrafficManager must have seeded cars")
		_test_car = traffic_mgr.lot_cars[0]
		_test_car.dwell_left = 0.0
		_test_car.had_errand = true
	if "--test-merge-gap" in OS.get_cmdline_user_args():
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null and traffic_mgr.lot_cars.size() > 0, "TrafficManager must have seeded cars")
		_test_car = traffic_mgr.lot_cars[0]
		if _test_car.spot != null:
			traffic_mgr.lot.release(_test_car.spot)
			_test_car.spot = null
		_test_car.motion = Car.Motion.PATH
		_test_car.path = null
		_test_car.lane_id = -1
		_test_car.state = Car.State.WAITING_TO_MERGE
		_test_car.global_position = Vector3(9.0, 0.0, -9.6)
		_test_car.rotation.y = -PI / 2.0
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.had_errand = true
		_test_car.merge_wait_time = 0.0
		_test_car._update_blocker_layer()
	if "--test-lifecycle" in OS.get_cmdline_user_args():
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		_test_car = traffic_mgr._spawn_car_at(lane0, 0.0)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.random()
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0
	if "--test-find-blocker" in OS.get_cmdline_user_args():
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		# Clear lot cars for isolated unit testing of find_blocker
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		var car_scene = load("res://car.tscn")
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
		assert(tm.find_blocker(car_a) == null, "car_b with lateral 2.5m must NOT be blocker")

		# Test 3: behind car_a (forward < 0)
		car_b.global_position = Vector3(-6.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == null, "car_b behind car_a must NOT be blocker")

		# Test 4: centers 9.0m apart (gap = 9.0 - 4.2 = 4.8 >= 4.0m lookahead) -> NOT a blocker when stopped
		car_b.global_position = Vector3(9.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == null, "car_b at 9.0m center distance must NOT be blocker when car_a is stopped")

		# Test 5: dynamic lookahead with speed
		# speed = 10 m/s -> lookahead = max(4.0, 100 / (2 * 25) + 3.0) = 5.0m
		# gap = 4.8 < 5.0m -> blocker found!
		car_a.speed = 10.0
		assert(tm.find_blocker(car_a) == car_b, "car_b at 9.0m must be blocker when car_a speed is 10 m/s")
		car_a.speed = 0.0

		# Test 6: closest blocker when multiple candidates exist
		var car_c = car_scene.instantiate()
		car_c.car_type = Car.CarType.SEDAN
		tm.add_child(car_c)
		car_c.global_position = Vector3(5.0, 0.0, 0.0)
		tm.lot_cars.append(car_c)
		car_b.global_position = Vector3(7.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == car_c, "find_blocker must return closest blocker (car_c at 5.0m, not car_b at 7.0m)")
		tm.lot_cars.erase(car_c)
		car_c.queue_free()

		# Test 7: Reversing car
		car_a.state = Car.State.REVERSING_OUT
		car_a.speed = -1.5
		# In reverse, forward direction is -X. car_b at (-6.0, 0, 0) is ahead in reverse direction!
		car_b.global_position = Vector3(-6.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == car_b, "car_b at -6.0m must be blocker for car_a reversing along -X")
		# car_b at (+6.0, 0, 0) is behind reversing car_a
		car_b.global_position = Vector3(6.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == null, "car_b at +6.0m must NOT be blocker for car_a reversing along -X")
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
		get_tree().quit(0)
		return
	if "--test-reverse-safety" in OS.get_cmdline_user_args():
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		# Find a spot in the lot
		assert(tm.lot != null and tm.lot.spots.size() > 0, "ParkingLot must have spots")
		var spot = tm.lot.spots[0]
		var car_scene = load("res://car.tscn")
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
		assert(tm.can_reverse_out(parked_car) == false, "can_reverse_out must be false when moving car is within 8m along aisle")

		# Update lot cars for 1 tick -> parked_car must delay reversing and stay PARKED
		tm._update_lot_cars(0.016)
		assert(parked_car.state == Car.State.PARKED, "parked car must remain PARKED while aisle is busy")

		# Test 2: Car within 8m but STOPPED -> does not block reverse
		aisle_car.speed = 0.0
		assert(tm.can_reverse_out(parked_car) == true, "can_reverse_out must be true when nearby car is stopped")

		# Test 3: Moving car beyond 8m along aisle -> does not block reverse
		aisle_car.speed = 4.5
		aisle_car.global_position = Vector3(spot.x + 10.0, 0.0, -20.0)
		assert(tm.can_reverse_out(parked_car) == true, "can_reverse_out must be true when moving car is > 8m away")

		# Update lot cars for 1 tick -> parked_car transitions to REVERSING_OUT
		tm._update_lot_cars(0.016)
		assert(parked_car.state == Car.State.REVERSING_OUT, "parked car must transition to REVERSING_OUT once aisle is clear")
		assert(parked_car.speed < 0.0, "reversing car must have negative speed")

		print("REVERSE_SAFETY_TEST: SUCCESS - parked car delays reversing while moving lot car is within 8m, and reverses once clear!")
		get_tree().quit(0)
		return
	if "--test-priority-arbitration" in OS.get_cmdline_user_args():
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		# Setup two paths moving along +X towards each other
		# path1: from x=0 to x=30 (forward is +X)
		var path1 = Curve3D.new()
		path1.add_point(Vector3(0.0, 0.0, 0.0))
		path1.add_point(Vector3(30.0, 0.0, 0.0))

		# path2: from x=30 to x=0 (forward is -X)
		var path2 = Curve3D.new()
		path2.add_point(Vector3(30.0, 0.0, 0.0))
		path2.add_point(Vector3(0.0, 0.0, 0.0))

		var car_scene = load("res://car.tscn")
		var car1: Car = car_scene.instantiate()
		car1.car_type = Car.CarType.SEDAN
		car1.car_width = 2.0
		car1.car_length = 4.2
		tm.add_child(car1)
		car1.follow_path(path1)
		car1.path_distance = 10.0
		car1.speed = 4.0
		car1.update_presentation()
		tm.lot_cars.append(car1)

		var car2: Car = car_scene.instantiate()
		car2.car_type = Car.CarType.SEDAN
		car2.car_width = 2.0
		car2.car_length = 4.2
		tm.add_child(car2)
		car2.follow_path(path2)
		car2.path_distance = 14.0 # x = 16.0, facing -X towards car1 at x = 10.0
		car2.speed = 4.0
		car2.update_presentation()
		tm.lot_cars.append(car2)

		# Center-to-center distance is 6.0m along X, lateral is 0.0
		# car1 forward (+X) sees car2 ahead: forward = 6.0, gap = 6.0 - 4.2 = 1.8 < lookahead
		# car2 forward (-X) sees car1 ahead: forward = 6.0, gap = 6.0 - 4.2 = 1.8 < lookahead
		assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
		assert(tm.find_blocker(car2) == car1, "car2 must find car1 as blocker")

		# Unit tests for priority arbitration: TO_SPOT > TO_EXIT > REVERSING_OUT
		# Case 1: TO_SPOT (car1) vs TO_EXIT (car2)
		car1.state = Car.State.TO_SPOT
		car2.state = Car.State.TO_EXIT
		assert(tm._should_yield(car1) == false, "TO_SPOT should not yield to TO_EXIT")
		assert(tm._should_yield(car2) == true, "TO_EXIT should yield to TO_SPOT")

		# Case 2: TO_EXIT (car1) vs REVERSING_OUT (car2)
		# For car2 to block car1 while REVERSING_OUT, car2 reverses in direction facing away from car1
		# so its reverse direction points toward car1 (+X)
		car2.follow_path(path1)
		car2.path_distance = 16.0
		car2.speed = -4.0
		car2.desired_speed = -4.0
		car2.state = Car.State.REVERSING_OUT
		car2.update_presentation()
		car1.state = Car.State.TO_EXIT
		assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
		assert(tm.find_blocker(car2) == car1, "car2 (reversing) must find car1 as blocker")
		assert(tm._should_yield(car1) == false, "TO_EXIT should not yield to REVERSING_OUT")
		assert(tm._should_yield(car2) == true, "REVERSING_OUT should yield to TO_EXIT")
		# Reset car2 to path2
		car2.follow_path(path2)
		car2.path_distance = 14.0
		car2.speed = 4.0
		car2.desired_speed = 4.0
		car2.update_presentation()
		# Case 3: TO_SPOT (car1) vs REVERSING_OUT (car2)
		car2.follow_path(path1)
		car2.path_distance = 16.0
		car2.speed = -4.0
		car2.desired_speed = -4.0
		car2.state = Car.State.REVERSING_OUT
		car2.update_presentation()
		car1.state = Car.State.TO_SPOT
		assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
		assert(tm.find_blocker(car2) == car1, "car2 (reversing) must find car1 as blocker")
		assert(tm._should_yield(car1) == false, "TO_SPOT should not yield to REVERSING_OUT")
		assert(tm._should_yield(car2) == true, "REVERSING_OUT should yield to TO_SPOT")
		# Reset car2 to path2
		car2.follow_path(path2)
		car2.path_distance = 14.0
		car2.speed = 4.0
		car2.desired_speed = 4.0
		car2.update_presentation()
		# Case 4: Equal priority (both TO_SPOT) -> both yield
		car1.state = Car.State.TO_SPOT
		car2.state = Car.State.TO_SPOT
		assert(tm._should_yield(car1) == true, "Equal priority mutual blocker must yield")
		assert(tm._should_yield(car2) == true, "Equal priority mutual blocker must yield")

		# Case 5: Dynamic yielding & resuming in aisle
		# car1 in TO_SPOT (priority), car2 in TO_EXIT (yields)
		car1.state = Car.State.TO_SPOT
		car2.state = Car.State.TO_EXIT
		car1.path_distance = 10.0
		car2.path_distance = 14.0 # x=16
		car1.speed = 4.0
		car2.speed = 4.0
		car1.update_presentation()
		car2.update_presentation()

		# Tick simulation
		for i in range(20):
			tm._update_lot_cars(0.016)

		assert(car1.state == Car.State.TO_SPOT, "car1 must remain in TO_SPOT")
		assert(car2.state == Car.State.TO_EXIT, "car2 must remain in TO_EXIT")
		assert(car2.desired_speed == 0.0, "car2 must have desired_speed 0.0")
		assert(car2.speed < 0.1, "car2 must stop (speed ~ 0)")
		assert(car1.speed > 1.0, "car1 (higher priority) must continue moving")

		# Now car1 moves past car2 (clear conflict)
		car1.path_distance = 25.0
		car1.update_presentation()
		assert(tm.find_blocker(car2) == null, "car2 blocker should clear once car1 is past")

		# Tick simulation -> car2 resumes moving
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
		car3.follow_path(rev_path, true) # reversed path
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
		assert(tm._should_yield(car3) == true, "car3 (REVERSING_OUT) must yield to car4")
		# Tick 1 update
		tm._update_lot_cars(0.016)
		assert(car3.state == Car.State.REVERSING_OUT, "car3 must remain in REVERSING_OUT while yielding")
		assert(car3.spot == test_spot, "car3 must not release spot while yielding")
		assert(car3.desired_speed == 0.0, "car3 desired_speed must be 0.0 when yielding")

		print("PRIORITY_ARBITRATION_TEST: SUCCESS - Priority arbitration TO_SPOT > TO_EXIT > REVERSING_OUT verified!")
		get_tree().quit(0)
		return
	if "--test-debug-hud" in OS.get_cmdline_user_args():
		var tm = $TrafficManager
		assert(tm != null and tm.debug_overlay != null, "TrafficManager and debug_overlay must exist")
		var dbg: TrafficDebug = tm.debug_overlay

		# Overlay is initially hidden
		assert(dbg.visible == false, "Debug overlay must be initially hidden")
		assert(dbg.hud_layer != null, "HUD layer must exist")
		assert(dbg.hud_layer.visible == false, "HUD layer must be initially hidden")

		# Toggle overlay active
		dbg.visible = true
		assert(dbg.hud_layer.visible == true, "HUD layer must become visible when overlay is active")

		# Initial counts based on live spots
		var init_free := 0
		var init_res := 0
		var init_occ := 0
		for s in tm.lot.spots:
			match s.state:
				ParkingSpot.State.FREE: init_free += 1
				ParkingSpot.State.RESERVED: init_res += 1
				ParkingSpot.State.OCCUPIED: init_occ += 1

		var hud_text := dbg.get_hud_text()
		assert("%d free" % init_free in hud_text, "HUD text must reflect free stalls: %s" % hud_text)
		assert("%d reserved" % init_res in hud_text, "HUD text must reflect reserved stalls: %s" % hud_text)
		assert("%d occupied" % init_occ in hud_text, "HUD text must reflect occupied stalls: %s" % hud_text)
		assert("errands_dropped_lot_full: 0" in hud_text, "HUD text must reflect 0 dropped: %s" % hud_text)
		assert("watchdog_fires: 0" in hud_text, "HUD text must reflect 0 watchdog fires: %s" % hud_text)
		assert("max_stuck_time: 0.0s" in hud_text, "HUD text must reflect 0.0s max stuck time: %s" % hud_text)

		# Dynamic update: reserve a free stall
		var free_spot: ParkingSpot = null
		for s in tm.lot.spots:
			if s.is_free():
				free_spot = s
				break
		assert(free_spot != null, "Must have a free spot")
		free_spot.state = ParkingSpot.State.RESERVED
		tm.lot.spot_changed.emit(free_spot)

		hud_text = dbg.get_hud_text()
		assert("%d free" % (init_free - 1) in hud_text, "HUD text must reflect %d free stalls: %s" % [init_free - 1, hud_text])
		assert("%d reserved" % (init_res + 1) in hud_text, "HUD text must reflect %d reserved stalls: %s" % [init_res + 1, hud_text])
		# Dynamic update: stats increment
		tm.stats["errands_dropped_lot_full"] = 4
		tm.stats["watchdog_fires"] = 2
		tm.stats["max_stuck_time"] = 4.8
		dbg.update_hud()
		hud_text = dbg.get_hud_text()
		assert("errands_dropped_lot_full: 4" in hud_text, "HUD text must show 4 dropped: %s" % hud_text)
		assert("watchdog_fires: 2" in hud_text, "HUD text must show 2 watchdog fires: %s" % hud_text)
		assert("max_stuck_time: 4.8s" in hud_text, "HUD text must show 4.8s max stuck: %s" % hud_text)

		# Toggle overlay inactive
		dbg.visible = false
		assert(dbg.hud_layer.visible == false, "HUD layer must hide when overlay is inactive")

		print("DEBUG_HUD_TEST: SUCCESS - HUD line shows stall counts, dropped, watchdog fires, and max stuck time")
		get_tree().quit(0)
		return
	if "--test-deadlock-watchdog" in OS.get_cmdline_user_args():
		var tm = $TrafficManager
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
		assert("watchdog_fires: 0" in initial_hud, "Initial HUD must show 0 watchdog fires: %s" % initial_hud)
		assert("max_stuck_time: 0.0s" in initial_hud, "Initial HUD must show 0.0s max stuck: %s" % initial_hud)
		var path1 = Curve3D.new()
		path1.add_point(Vector3(0.0, 0.0, 0.0))
		path1.add_point(Vector3(30.0, 0.0, 0.0))

		var path2 = Curve3D.new()
		path2.add_point(Vector3(30.0, 0.0, 0.0))
		path2.add_point(Vector3(0.0, 0.0, 0.0))

		var car_scene = load("res://car.tscn")
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
		car2.path_distance = 14.0 # x = 16.0, facing -X
		car2.speed = 4.0
		car2.state = Car.State.TO_SPOT
		car2.update_presentation()
		tm.lot_cars.append(car2)

		var higher_car := car1 if car1.get_instance_id() > car2.get_instance_id() else car2
		var lower_car := car2 if car1.get_instance_id() > car2.get_instance_id() else car1

		assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
		assert(tm.find_blocker(car2) == car1, "car2 must find car1 as blocker")
		assert(tm._should_yield(car1) == true, "Equal priority mutual blocker car1 must yield")
		assert(tm._should_yield(car2) == true, "Equal priority mutual blocker car2 must yield")

		# Step for 3.8s (240 ticks of 0.016s) -> watchdog should NOT have fired yet (< 4.0s)
		for i in range(240):
			tm._update_lot_cars(0.016)
			dbg.update_hud()

		assert(tm.stats["watchdog_fires"] == 0, "Watchdog must not fire before 4.0s")
		assert(car1.speed < 0.1 and car2.speed < 0.1, "Both cars must be stopped")
		assert(car1.blocked_time >= 3.8 and car2.blocked_time >= 3.8, "Both cars must track blocked_time")
		assert(tm.stats["max_stuck_time"] >= 3.8, "max_stuck_time must track blocked_time")
		var pre_fire_hud: String = dbg.get_hud_text()
		assert("watchdog_fires: 0" in pre_fire_hud, "Pre-fire HUD must show 0 watchdog fires: %s" % pre_fire_hud)
		assert("max_stuck_time: 3.8s" in pre_fire_hud, "Pre-fire HUD must show 3.8s max stuck: %s" % pre_fire_hud)

		# Step another 20 ticks (0.32s, reaching 4.12s > 4.0s) -> watchdog MUST fire!
		for i in range(20):
			tm._update_lot_cars(0.016)
			dbg.update_hud()

		assert(tm.stats["watchdog_fires"] == 1, "Watchdog must fire once mutual block exceeds 4.0s")
		assert(tm.stats["max_stuck_time"] >= 4.0, "max_stuck_time must be >= 4.0s")
		var post_fire_hud: String = dbg.get_hud_text()
		assert("watchdog_fires: 1" in post_fire_hud, "Post-fire HUD must show 1 watchdog fire: %s" % post_fire_hud)
		assert("max_stuck_time: 4.1s" in post_fire_hud or "max_stuck_time: 4.0s" in post_fire_hud, "Post-fire HUD must show >= 4.0s max stuck: %s" % post_fire_hud)
		assert(tm._is_ignoring(higher_car, lower_car) == true, "Higher ID car must ignore lower ID car")
		assert(tm._is_ignoring(lower_car, higher_car) == false, "Lower ID car must NOT ignore higher ID car")
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

		assert(tm.find_blocker(lower_car) == null, "Lower car blocker must clear once higher car passes")
		assert(lower_car.speed > 0.5, "Lower car must resume moving once conflict is cleared")
		# Verify HUD reflects live stall counts
		var spot = tm.lot.spots[0]
		spot.state = ParkingSpot.State.RESERVED
		tm.lot.spot_changed.emit(spot)
		var final_hud: String = dbg.get_hud_text()
		assert("1 reserved" in final_hud, "HUD line must reflect live reserved count: %s" % final_hud)
		assert("watchdog_fires: 1" in final_hud, "HUD line must preserve watchdog fire count: %s" % final_hud)

		print("DEADLOCK_WATCHDOG_TEST: SUCCESS - Watchdog triggered at 4.0s, tiebreaker cleanly resolved deadlock!")
		get_tree().quit(0)
		return
func _physics_process(_delta: float) -> void:
	if "--test-mats-blocker" in OS.get_cmdline_user_args() or "--test-mats-interaction" in OS.get_cmdline_user_args():
		_test_frames += 1
		if _mats_stage == 0:
			# Push Mats south along sidewalk into the car (from z=-13 toward z=-9.6)
			mats.velocity = Vector3(0.0, 0.0, 5.0)
			if _test_frames > 60:
				print(
					"MATS_TEST [1/2]: mats_pos=",
					mats.global_position,
					" mats_dead=",
					mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(not mats._is_dead, "Mats died on stopped car!")
				assert(
					mats.global_position.z < -11.0, "Mats walked through stopped car across sidewalk!"
				)
				assert(_test_car.blocker.collision_layer == 4, "Blocker must be on layer 3 when stopped!")
				print("MATS_TEST: Part 1 SUCCESS - Mats was blocked across the sidewalk without dying!")
				_mats_stage = 1
				_mats_start_frame = _test_frames
				# Prepare Stage 2: place Mats on sidewalk apron in front of car in merge path
				mats.global_position = Vector3(9.0, 0.5, -7.0)
				mats.velocity = Vector3.ZERO
				# Initiate car merge
				_test_car.state = Car.State.MERGING
				_test_car.follow_path(ParkingLot.merge_route())
				_test_car.desired_speed = 5.0
				_test_car.speed = 1.0
				_test_car._update_blocker_layer()
		elif _mats_stage == 1:
			# Advance merging car along merge route toward Mats
			_test_car.speed = move_toward(_test_car.speed, _test_car.desired_speed, 8.0 * _delta)
			_test_car.advance_path(_delta)
			if mats._is_dead:
				print(
					"MATS_TEST [2/2]: car_pos=",
					_test_car.global_position,
					" car_speed=",
					_test_car.speed,
					" mats_dead=",
					mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(_test_car.speed > 0.1, "Car must be moving when Mats dies!")
				assert(_test_car.blocker.collision_layer == 0, "Blocker must be disabled while moving!")
				print("MATS_TEST: Part 2 SUCCESS - Mats dies when hit by car pulling out into merge!")
				print("MATS_TEST: ALL CHECKS PASSED - Mats is stopped by car waiting across sidewalk, and dies if hit by car pulling out into merge!")
				get_tree().quit(0)
			elif _test_frames - _mats_start_frame > 120:
				assert(false, "Timeout: Mats did not die when hit by car pulling out into merge!")

	if "--test-exit-route" in OS.get_cmdline_user_args():
		_test_frames += 1
		if _test_car.state == Car.State.REVERSING_OUT:
			_saw_reversing = true
		elif _test_car.state == Car.State.TO_EXIT:
			_saw_to_exit = true
		elif _test_car.state == Car.State.WAITING_TO_MERGE:
			_saw_waiting = true
			if not _mats_testing:
				print("EXIT_TEST: Arrived at WAITING_TO_MERGE at frame ", _test_frames)
				print("EXIT_TEST: pos=", _test_car.global_position, " speed=", _test_car.speed)
				var expected_wait_pt := Vector3(9.0, 0.0, -9.6)
				assert(_saw_reversing, "Car must have reversed out")
				assert(_saw_to_exit, "Car must have driven exit route")
				assert(_test_car.global_position.distance_to(expected_wait_pt) < 0.05, "Car must stop cleanly at (9, 0, -9.6)")
				assert(_test_car.speed == 0.0, "Car speed must be 0.0")
				assert(is_instance_valid(_test_car), "Car must not despawn")
				assert(_test_car.blocker.collision_layer == 4, "Blocker must be on layer 3")
				_mats_testing = true
				_mats_start_frame = _test_frames
				mats.global_position = Vector3(9.0, 0.5, -13.0)
			else:
				mats.velocity = Vector3(0.0, 0.0, 5.0)
				if _test_frames - _mats_start_frame > 60:
					print("EXIT_TEST: mats_pos=", mats.global_position, " mats_dead=", mats._is_dead)
					assert(not mats._is_dead, "Mats died on stopped car!")
					assert(mats.global_position.z < -11.0, "Mats walked through stopped car across sidewalk!")
					print("EXIT_TEST: SUCCESS - car reversed out, drove to wait point, stopped without despawning, and blocked Mats!")
					get_tree().quit(0)
		if _test_frames > 1200:
			assert(false, "Timeout waiting for exit route completion!")

	if "--test-merge-reentry" in OS.get_cmdline_user_args():
		_test_frames += 1
		if _test_car != null and is_instance_valid(_test_car):
			var tm = $TrafficManager
			if _test_car.state == Car.State.WAITING_TO_MERGE:
				var lane0 = tm.lanes[0]
				lane0.spawn_timer = 999.0
				var to_remove: Array[Car] = []
				for c in lane0.cars:
					if is_instance_valid(c) and c != _test_car and c != _test_follower:
						to_remove.append(c)
				for c in to_remove:
					lane0.cars.erase(c)
					c.queue_free()
			elif _test_car.state == Car.State.MERGING:
				_saw_waiting = true
				if _test_follower == null:
					_test_follower = tm._spawn_car_at(tm.lanes[0], 42.0)
					_test_follower.speed = 13.0
					_test_follower.desired_speed = 13.0
					_test_follower.errand = null
					_test_follower.had_errand = false
				_saw_waiting = true
				# Check if lane 0 registered _test_car as a ghost
				if tm.lanes[0].cars.has(_test_car):
					_ghost_registered = true
				if _test_follower != null and is_instance_valid(_test_follower):
					var gap: float = (
						_test_car.lane_distance
						- _test_follower.lane_distance
						- (0.5 * (_test_car.car_length + _test_follower.car_length))
					)
					if gap < 8.0:
						if _test_follower.speed < 11.0:
							_follower_braked = true
			elif _test_car.state == Car.State.CRUISING and _saw_waiting:
				if not _mats_testing:
					_mats_testing = true
					print("MERGE_TEST: Handoff occurred at frame ", _test_frames)
					print("MERGE_TEST: pos=", _test_car.global_position, " rot_y=", _test_car.rotation.y)
					var expected_pos := Vector3(5.0, 0.05, -5.6)
					var pos_delta := _test_car.global_position.distance_to(expected_pos)
					var rot_delta_deg := absf(rad_to_deg(wrapf(_test_car.rotation.y - PI, -PI, PI)))
					print("MERGE_TEST: pos_delta=", pos_delta, " rot_delta_deg=", rot_delta_deg)
					assert(pos_delta < 0.05, "Position delta at handoff must be < 0.05 m (was %f)" % pos_delta)
					assert(rot_delta_deg < 1.0, "Rotation delta at handoff must be < 1.0 deg (was %f)" % rot_delta_deg)
					assert(_test_car.motion == Car.Motion.LANE, "Motion must be Motion.LANE")
					assert(_test_car.lane_id == 0, "Lane ID must be 0")
					assert(_test_car.errand == null, "Errand must be null")
					assert(_ghost_registered, "Car must have registered as a ghost in lane 0 during merge")
					assert(_follower_braked, "Follower in lane 0 must brake behind ghost")
					assert(not tm.lot_cars.has(_test_car), "Car must be removed from lot_cars")
					assert(tm.lanes[0].cars.has(_test_car), "Car must be in lane 0 cars")
					_handoff_verified = true
		else:
			# Car despawned at lane end
			var tm = $TrafficManager
			print("MERGE_TEST: Car despawned! errands_completed=", tm.stats["errands_completed"])
			assert(_handoff_verified, "Handoff must have been verified before despawn")
			assert(tm.stats["errands_completed"] >= 1, "errands_completed must be incremented")
			print("MERGE_TEST: SUCCESS - full lifecycle, handoff delta verified, despawned cleanly!")
			get_tree().quit(0)
		if _test_frames > 2000:
			assert(false, "Timeout waiting for merge re-entry and despawn!")

	if "--test-merge-gap" in OS.get_cmdline_user_args():
		_test_frames += 1
		var tm = $TrafficManager
		var lane0 = tm.lanes[0]
		if _gap_test_stage == 0:
			lane0.spawn_timer = 999.0
			var to_remove: Array[Car] = []
			for c in lane0.cars:
				if is_instance_valid(c) and c != _test_car:
					to_remove.append(c)
			for c in to_remove:
				lane0.cars.erase(c)
				c.queue_free()

			assert(tm._can_merge(_test_car), "Must be able to merge when lane 0 is clear")

			var dummy1 = tm._spawn_car_at(lane0, 70.0)
			assert(not tm._can_merge(_test_car), "Must reject merge when car is at d=70.0 (inside window)")
			lane0.cars.erase(dummy1)
			dummy1.queue_free()

			var dummy2 = tm._spawn_car_at(lane0, 58.0)
			assert(not tm._can_merge(_test_car), "Must reject merge when car is at d=58.0 (inside window)")
			lane0.cars.erase(dummy2)
			dummy2.queue_free()

			var dummy3 = tm._spawn_car_at(lane0, 25.0)
			dummy3.lane_speed = 13.0
			assert(not tm._can_merge(_test_car), "Must reject merge when upstream car gap is 2.77s <= 3.0s")
			lane0.cars.erase(dummy3)
			dummy3.queue_free()

			var dummy4 = tm._spawn_car_at(lane0, 20.0)
			dummy4.lane_speed = 13.0
			assert(tm._can_merge(_test_car), "Must accept merge when upstream car gap is 3.15s > 3.0s")
			lane0.cars.erase(dummy4)
			dummy4.queue_free()

			_passing_car = tm._spawn_car_at(lane0, 45.0)
			_passing_car.speed = 13.0
			_passing_car.desired_speed = 13.0
			_passing_car.lane_speed = 13.0
			_passing_car.errand = null
			_passing_car.had_errand = false

			assert(not tm._can_merge(_test_car), "Must reject merge with passing car at d=45.0")
			_gap_test_stage = 1

		elif _gap_test_stage == 1:
			if _passing_car != null and is_instance_valid(_passing_car):
				if _passing_car.lane_distance <= 71.0:
					assert(_test_car.state == Car.State.WAITING_TO_MERGE, "Waiting car must hold state WAITING_TO_MERGE")
					assert(_test_car.speed == 0.0, "Waiting car speed must remain 0.0")
					assert(_test_car.global_position.distance_to(Vector3(9.0, 0.0, -9.6)) < 0.05, "Waiting car must hold position")
					assert(not tm._can_merge(_test_car), "Must not merge while car in window [54.5, 71]")
					_saw_hold_position = true
				else:
					assert(_saw_hold_position, "Must have observed waiting car holding position while car passed")
					assert(_test_car.merge_wait_time > 0.0, "Merge wait time must accumulate")
					assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be updated")
					assert(tm._can_merge(_test_car), "Merge must be accepted once passing car clears d=71.0")
					print("GAP_TEST: Passing car cleared window (d=%.1f). Wait time: %.2fs" % [_passing_car.lane_distance, _test_car.merge_wait_time])
					_gap_test_stage = 2

		elif _gap_test_stage == 2:
			if _test_car.state == Car.State.MERGING:
				_saw_gap_merge = true
				print("GAP_TEST: Car successfully initiated merge when valid gap opened!")
				_test_follower = tm._spawn_car_at(lane0, 42.0)
				_test_follower.speed = 13.0
				_test_follower.desired_speed = 13.0
				_test_follower.errand = null
				_test_follower.lane_speed = 13.0
				_test_follower.had_errand = false
				_gap_test_stage = 3

		elif _gap_test_stage == 3:
			if lane0.cars.has(_test_car):
				_ghost_registered = true

			if _test_follower != null and is_instance_valid(_test_follower) and _ghost_registered:
				var gap: float = (
					_test_car.lane_distance
					- _test_follower.lane_distance
					- (0.5 * (_test_car.car_length + _test_follower.car_length))
				)
				if gap < 8.0:
					if _test_follower.speed < 11.0:
						_saw_follower_yield = true
						print("GAP_TEST: Upstream follower braked to %.2f m/s behind merging car (gap=%.2fm)" % [_test_follower.speed, gap])

			if _test_car.state == Car.State.CRUISING:
				print("GAP_TEST: Merged car transitioned to CRUISING!")
				assert(_saw_hold_position, "Waiting car must have held position while lane 0 car passed")
				assert(_saw_gap_merge, "Car must have merged only when valid gap opened")
				assert(_ghost_registered, "Merging car must have registered as ghost in lane 0")
				assert(_saw_follower_yield, "Upstream traffic must yield appropriately to merging car")
				assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be tracked")
				print("GAP_TEST: SUCCESS - waiting cars hold position while lane-0 cars pass, merge only when valid gap opens, and upstream traffic yields appropriately!")
				get_tree().quit(0)

		if _test_frames > 600:
			assert(false, "Timeout waiting for gap test completion!")

	if "--test-lifecycle" in OS.get_cmdline_user_args():
		_test_frames += 1
		if _saw_lc_despawn:
			return
		var tm = $TrafficManager
		if _test_car != null and is_instance_valid(_test_car):
			if _test_car.state == Car.State.CRUISING and _test_car.lane_id == 0 and not _saw_lc_merge:
				if not _saw_lc_cruising:
					_saw_lc_cruising = true
					print("LIFECYCLE [1/12]: lane cruising (speed=%.1f, lane_dist=%.1f)" % [_test_car.speed, _test_car.lane_distance])
			elif _test_car.state == Car.State.APPROACHING:
				if not _saw_lc_decision:
					_saw_lc_decision = true
					print("LIFECYCLE [2/12]: decision (lane_dist=%.1f, spot=%s)" % [_test_car.lane_distance, str(_test_car.spot.id) if _test_car.spot else "null"])
				if _test_car.speed < 11.0 and not _saw_lc_braking:
					_saw_lc_braking = true
					print("LIFECYCLE [3/12]: approach braking (speed=%.1f, target_v_turn=%.1f)" % [_test_car.speed, TrafficManager.V_TURN])
			elif _test_car.state == Car.State.TO_SPOT:
				if not _saw_lc_turn:
					_saw_lc_turn = true
					print("LIFECYCLE [4/12]: driveway turn (pos=%s, motion=PATH)" % str(_test_car.global_position))
			elif _test_car.state == Car.State.PARKED:
				if not _saw_lc_park:
					_saw_lc_park = true
					print("LIFECYCLE [5/12]: stall park (pos=%s, spot=%s, dwell=%.1f)" % [str(_test_car.global_position), str(_test_car.spot.id) if _test_car.spot else "null", _test_car.dwell_left])
					_test_car.dwell_left = minf(_test_car.dwell_left, 1.0)
				if not _saw_lc_dwell:
					_saw_lc_dwell = true
					print("LIFECYCLE [6/12]: dwell (dwell_left=%.2f)" % _test_car.dwell_left)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _saw_lc_reverse:
					_saw_lc_reverse = true
					print("LIFECYCLE [7/12]: reverse out (speed=%.1f, pos=%s)" % [_test_car.speed, str(_test_car.global_position)])
			elif _test_car.state == Car.State.TO_EXIT:
				if not _saw_lc_exit_aisle:
					_saw_lc_exit_aisle = true
					print("LIFECYCLE [8/12]: exit aisle (speed=%.1f, pos=%s)" % [_test_car.speed, str(_test_car.global_position)])
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _saw_lc_wait:
					_saw_lc_wait = true
					print("LIFECYCLE [9/12]: sidewalk wait (pos=%s, speed=%.1f)" % [str(_test_car.global_position), _test_car.speed])
				var lane0 = tm.lanes[0]
				lane0.spawn_timer = 999.0
				var to_remove: Array[Car] = []
				for c in lane0.cars:
					if is_instance_valid(c) and c != _test_car:
						to_remove.append(c)
				for c in to_remove:
					lane0.cars.erase(c)
					c.queue_free()
			elif _test_car.state == Car.State.MERGING:
				if not _saw_lc_merge:
					_saw_lc_merge = true
					print("LIFECYCLE [10/12]: gap merge (speed=%.1f, pos=%s)" % [_test_car.speed, str(_test_car.global_position)])
			elif _test_car.state == Car.State.CRUISING and _test_car.lane_id == 0 and _saw_lc_merge:
				if not _saw_lc_post_merge_cruise:
					_saw_lc_post_merge_cruise = true
					print("LIFECYCLE [11/12]: lane cruising (speed=%.1f, lane_dist=%.1f)" % [_test_car.speed, _test_car.lane_distance])
		else:
			if _saw_lc_post_merge_cruise and not _saw_lc_despawn:
				_saw_lc_despawn = true
				print("LIFECYCLE [12/12]: despawn (errands_completed=%d)" % tm.stats["errands_completed"])
				assert(_saw_lc_cruising, "Must have observed lane cruising")
				assert(_saw_lc_decision, "Must have observed decision")
				assert(_saw_lc_braking, "Must have observed approach braking")
				assert(_saw_lc_turn, "Must have observed driveway turn")
				assert(_saw_lc_park, "Must have observed stall park")
				assert(_saw_lc_dwell, "Must have observed dwell")
				assert(_saw_lc_reverse, "Must have observed reverse out")
				assert(_saw_lc_exit_aisle, "Must have observed exit aisle")
				assert(_saw_lc_wait, "Must have observed sidewalk wait")
				assert(_saw_lc_merge, "Must have observed gap merge")
				assert(_saw_lc_post_merge_cruise, "Must have observed lane cruising")
				assert(_saw_lc_despawn, "Must have observed despawn")
				print("LIFECYCLE: SUCCESS - observed complete vehicle lifecycle through all 12 stages!")
				get_tree().quit(0)
				return
		if _test_frames > 4000:
			assert(false, "Timeout waiting for vehicle lifecycle completion!")
func _on_player_died(pos: Vector3) -> void:
	if hud and hud.has_method("increment_spd"):
		hud.increment_spd()
	if blood_splats and mats:
		BloodSplatScript.spawn(pos, blood_splats, [mats.get_rid()])
