class_name TrafficScenariosSuite
extends TestSuite

var _test_frames: int = 0
var _test_car: Car = null
var _test_follower: Car = null
var _passing_car: Car = null
var _ghost_registered: bool = false
var _gap_test_stage: int = 0
var _saw_hold_position: bool = false
var _saw_gap_merge: bool = false
var _saw_follower_yield: bool = false

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

var _rt_lead_car: Car = null
var _rt_follower_car: Car = null
var _rt_saw_lead_braking: bool = false
var _rt_saw_follower_braking: bool = false
var _rt_saw_lead_turning: bool = false
var _rt_saw_follower_resumed: bool = false
var _rt_min_distance: float = 999.0

var _ci_saw_cruise: bool = false
var _ci_saw_decision: bool = false
var _ci_saw_turn: bool = false
var _ci_saw_park: bool = false
var _ci_saw_reverse: bool = false
var _ci_saw_exit: bool = false
var _ci_saw_wait: bool = false
var _ci_saw_merge: bool = false
var _ci_saw_rejoin: bool = false
var _ci_site: StringName = &"cramped_inn"

var _side_lot_saw_cruise: bool = false
var _side_lot_saw_decision: bool = false
var _side_lot_saw_turn: bool = false
var _side_lot_saw_park: bool = false
var _side_lot_saw_reverse: bool = false
var _side_lot_saw_exit: bool = false
var _side_lot_saw_wait: bool = false
var _side_lot_saw_merge: bool = false
var _side_lot_saw_rejoin: bool = false
## Lane-0 destination with its own driveway (Smell store/gas, Dorf service).
var _side_lot_dest: StringName = &"smell_gas"
var _side_lot_held_spots: Array[ParkingSpot] = []


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--test-merge-gap",
				"--test-lifecycle",
				"--test-cramped-inn",
				"--test-strip-mall",
				"--test-smell-store",
				"--test-smell-gas",
				"--test-dorf-service",
				"--test-right-turn-following",
				"--test-drive-thru",
				"--test-cramped-inn-dropoff",
				"--test-frontage",
				"--test-grass-shortcut",
				"--test-sidewalk-shortcut",
				"--test-traffic-stop",
				"--test-bus-stop",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--test-merge-gap" in user_args:
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(
			traffic_mgr != null and traffic_mgr.lot_cars.size() > 0,
			"TrafficManager must have seeded cars"
		)
		for c in traffic_mgr.lot_cars:
			if c.global_position.z < 0.0 and c.global_position.x > -30.0:
				_test_car = c
				break
		if _test_car.spot != null:
			traffic_mgr.lot.release(_test_car.spot)
			_test_car.spot = null
		_test_car.motion = Car.Motion.PATH
		_test_car.path = null
		_test_car.lane_id = -1
		_test_car.state = Car.State.WAITING_TO_MERGE
		_test_car.global_position = Vector3(9.0, 0.0, -13.375)
		_test_car.rotation.y = -PI / 2.0
		_test_car.reset_physics_interpolation()
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.had_errand = true
		_test_car.merge_wait_time = 0.0
		_test_car._update_blocker_layer()

	if "--test-lifecycle" in user_args:
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		_test_car = traffic_mgr._spawn_car_at(lane0, 0.0, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(&"walgroins", 1.0)
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0
		if traffic_mgr.lot != null:
			for spot in traffic_mgr.lot.spots:
				if spot.serves.has(&"walgroins") and not spot.is_free():
					for c in traffic_mgr.lot_cars.duplicate():
						if is_instance_valid(c) and c.spot == spot:
							traffic_mgr.lot_cars.erase(c)
							c.queue_free()
					traffic_mgr.lot.release(spot)

	if (
		"--test-cramped-inn" in user_args
		or "--test-strip-mall" in user_args
		or "--test-frontage" in user_args
	):
		_ci_site = (
			&"strip_mall"
			if "--test-strip-mall" in user_args
			else (&"consumer_car_care" if "--test-frontage" in user_args else &"cramped_inn")
		)
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane3 = traffic_mgr.lanes[3]
		for c in lane3.cars:
			c.queue_free()
		lane3.cars.clear()
		lane3.spawn_timer = 9999.0
		if traffic_mgr.lot != null:
			for spot in traffic_mgr.lot.spots:
				if spot.serves.has(_ci_site) and not spot.is_free():
					for c in traffic_mgr.lot_cars.duplicate():
						if is_instance_valid(c) and c.spot == spot:
							traffic_mgr.lot_cars.erase(c)
							c.queue_free()
					traffic_mgr.lot.release(spot)
		var start_d: float = traffic_mgr._lane3_lot_decision_d(_ci_site) - 14.0
		_test_car = traffic_mgr._spawn_car_at(lane3, start_d, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(_ci_site, 1.0)
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0

	if _is_side_lot_test():
		_side_lot_dest = (
			&"smell_gas"
			if "--test-smell-gas" in user_args
			else (&"dorf_service" if "--test-dorf-service" in user_args else &"smell_store")
		)
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		if traffic_mgr.lot != null:
			for spot in traffic_mgr.lot.spots:
				if spot.serves.has(_side_lot_dest) and not spot.is_free():
					for c in traffic_mgr.lot_cars.duplicate():
						if is_instance_valid(c) and c.spot == spot:
							traffic_mgr.lot_cars.erase(c)
							c.queue_free()
					traffic_mgr.lot.release(spot)
			# Hold every Dorf bay but the farthest, so the run drives the longest entry and the
			# tightest back-out (past the canopy post and floodlight).
			if _side_lot_dest == &"dorf_service":
				var far_spot: ParkingSpot = null
				for spot in traffic_mgr.lot.spots:
					if spot.site_id == &"dorf" and (far_spot == null or spot.x > far_spot.x):
						far_spot = spot
				for spot in traffic_mgr.lot.spots:
					if spot.site_id == &"dorf" and spot != far_spot:
						spot.state = ParkingSpot.State.OCCUPIED
						_side_lot_held_spots.append(spot)
		# Start 14 m before the site's decision point (35 m before its turn-in). The Dorf
		# turn-in lies east of the test lane start, so this distance can be negative.
		var site_cfg := ParkingLot.get_site_cfg(ParkingLot.get_site_for_destination(_side_lot_dest))
		var start_d: float = lane0.distance_at(site_cfg["turn_in"].x) - 35.0 - 14.0
		_test_car = traffic_mgr._spawn_car_at(lane0, start_d, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(_side_lot_dest, 1.0)
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0

	if "--test-right-turn-following" in user_args:
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		_rt_lead_car = traffic_mgr._spawn_car_at(lane0, 10.0, traffic_mgr.PassengerCarScene)
		_rt_lead_car.car_type = Car.CarType.SEDAN
		_rt_lead_car.errand = Errand.new(&"walgroins", 10.0)
		_rt_lead_car.had_errand = true
		_rt_lead_car.desired_speed = 13.0
		_rt_lead_car.speed = 13.0

		_rt_follower_car = traffic_mgr._spawn_car_at(lane0, 0.0, traffic_mgr.PassengerCarScene)
		_rt_follower_car.car_type = Car.CarType.SEDAN
		_rt_follower_car.desired_speed = 14.0
		_rt_follower_car.speed = 14.0
		_rt_follower_car.errand = null
		_rt_follower_car.had_errand = false

	if "--test-drive-thru" in user_args:
		_run_test_drive_thru()

	if "--test-cramped-inn-dropoff" in user_args:
		_run_test_cramped_inn_dropoff()
	if "--test-grass-shortcut" in user_args:
		_run_test_grass_shortcut()
	if "--test-sidewalk-shortcut" in user_args:
		_run_test_sidewalk_shortcut()
	if "--test-traffic-stop" in user_args:
		_run_test_traffic_stop()
	if "--test-bus-stop" in user_args:
		_run_test_bus_stop()


func on_physics_process(_delta: float) -> void:
	if "--test-merge-gap" in user_args:
		_test_frames += 1
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
		var lane0 = tm.lanes[0]
		if _gap_test_stage == 0:
			for l in tm.lanes:
				l.spawn_timer = 999.0
			var to_remove: Array[Car] = []
			for c in lane0.cars:
				if is_instance_valid(c) and c != _test_car:
					to_remove.append(c)
			for c in to_remove:
				lane0.cars.erase(c)
				c.queue_free()

			assert(tm._can_merge(_test_car), "Must be able to merge when lane 0 is clear")

			var dummy1 = tm._spawn_car_at(lane0, 70.0, tm.PassengerCarScene)
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when car is at d=70.0 (inside window)"
			)
			lane0.cars.erase(dummy1)
			dummy1.queue_free()

			var dummy2 = tm._spawn_car_at(lane0, 58.0, tm.PassengerCarScene)
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when car is at d=58.0 (inside window)"
			)
			lane0.cars.erase(dummy2)
			dummy2.queue_free()

			var dummy3 = tm._spawn_car_at(lane0, 25.0, tm.PassengerCarScene)
			dummy3.lane_speed = 13.0
			dummy3.speed = 13.0
			dummy3.desired_speed = 13.0
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when upstream car gap is 2.77s <= 3.0s"
			)
			lane0.cars.erase(dummy3)
			dummy3.queue_free()

			var dummy4 = tm._spawn_car_at(lane0, 20.0, tm.PassengerCarScene)
			dummy4.lane_speed = 13.0
			dummy4.speed = 13.0
			dummy4.desired_speed = 13.0
			assert(
				tm._can_merge(_test_car), "Must accept merge when upstream car gap is 3.15s > 3.0s"
			)
			lane0.cars.erase(dummy4)
			dummy4.queue_free()

			_passing_car = tm._spawn_car_at(lane0, 45.0, tm.PassengerCarScene)
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
					assert(
						_test_car.state == Car.State.WAITING_TO_MERGE,
						"Waiting car must hold state WAITING_TO_MERGE"
					)
					assert(_test_car.speed == 0.0, "Waiting car speed must remain 0.0")
					assert(
						_test_car.global_position.distance_to(Vector3(9.0, 0.0, -13.375)) < 0.05,
						"Waiting car must hold position"
					)
					assert(
						not tm._can_merge(_test_car),
						"Must not merge while car in window [54.5, 71]"
					)
					_saw_hold_position = true
				else:
					assert(
						_saw_hold_position,
						"Must have observed waiting car holding position while car passed"
					)
					assert(_test_car.merge_wait_time > 0.0, "Merge wait time must accumulate")
					assert(
						tm._can_merge(_test_car),
						"Merge must be accepted once passing car clears d=71.0"
					)
					print(
						(
							"GAP_TEST: Passing car cleared window (d=%.1f). Wait time: %.2fs"
							% [_passing_car.lane_distance, _test_car.merge_wait_time]
						)
					)
					_gap_test_stage = 2

		elif _gap_test_stage == 2:
			if _test_car.state == Car.State.MERGING:
				_saw_gap_merge = true
				print("GAP_TEST: Car successfully initiated merge when valid gap opened!")
				_test_follower = tm._spawn_car_at(lane0, 42.0, tm.PassengerCarScene)
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
						print(
							(
								"GAP_TEST: Upstream follower braked to %.2f m/s behind merging car (gap=%.2fm)"
								% [_test_follower.speed, gap]
							)
						)

			if _test_car.state == Car.State.CRUISING:
				print("GAP_TEST: Merged car transitioned to CRUISING!")
				assert(
					_saw_hold_position,
					"Waiting car must have held position while lane 0 car passed"
				)
				assert(_saw_gap_merge, "Car must have merged only when valid gap opened")
				assert(_ghost_registered, "Merging car must have registered as ghost in lane 0")
				assert(
					_saw_follower_yield, "Upstream traffic must yield appropriately to merging car"
				)
				assert(_test_car.motion == Car.Motion.LANE, "Merged car must use lane motion")
				assert(_test_car.lane_id == 0, "Merged car must join lane 0")
				assert(_test_car.errand == null, "Merged car must clear its completed errand")
				assert(not tm.lot_cars.has(_test_car), "Merged car must leave lot traffic")
				assert(lane0.cars.has(_test_car), "Merged car must join lane traffic")
				print(
					"GAP_TEST: SUCCESS - waiting cars hold position while lane-0 cars pass, merge only when valid gap opens, and upstream traffic yields appropriately!"
				)
				main.get_tree().quit(0)

		if _test_frames > 600:
			assert(false, "Timeout waiting for gap test completion!")

	if "--test-lifecycle" in user_args:
		_test_frames += 1
		if _saw_lc_despawn:
			return
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and not _saw_lc_merge
			):
				if not _saw_lc_cruising:
					_saw_lc_cruising = true
					print(
						(
							"LIFECYCLE [1/12]: lane cruising (speed=%.1f, lane_dist=%.1f)"
							% [_test_car.speed, _test_car.lane_distance]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _saw_lc_decision:
					_saw_lc_decision = true
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT,
						"Car approaching right turn must activate turn signal"
					)
					print(
						(
							"LIFECYCLE [2/12]: decision (lane_dist=%.1f, spot=%s, signal=%s)"
							% [
								_test_car.lane_distance,
								str(_test_car.spot.id) if _test_car.spot else "null",
								str(_test_car.turn_signal)
							]
						)
					)
				if _test_car.speed < 11.0 and not _saw_lc_braking:
					_saw_lc_braking = true
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT,
						"Car braking for right turn must have turn signal ON"
					)
					print(
						(
							"LIFECYCLE [3/12]: approach braking (speed=%.1f, target_v_turn=%.1f, signal=%s)"
							% [_test_car.speed, TrafficManager.V_TURN, str(_test_car.turn_signal)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _saw_lc_turn:
					_saw_lc_turn = true
					print(
						(
							"LIFECYCLE [4/12]: driveway turn (pos=%s, motion=PATH, signal=%s)"
							% [str(_test_car.global_position), str(_test_car.turn_signal)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _saw_lc_park:
					_saw_lc_park = true
					print(
						(
							"LIFECYCLE [5/12]: stall park (pos=%s, spot=%s, dwell=%.1f)"
							% [
								str(_test_car.global_position),
								str(_test_car.spot.id) if _test_car.spot else "null",
								_test_car.dwell_left
							]
						)
					)
					_test_car.dwell_left = minf(_test_car.dwell_left, 1.0)
				if not _saw_lc_dwell:
					_saw_lc_dwell = true
					print("LIFECYCLE [6/12]: dwell (dwell_left=%.2f)" % _test_car.dwell_left)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _saw_lc_reverse:
					_saw_lc_reverse = true
					print(
						(
							"LIFECYCLE [7/12]: reverse out (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _saw_lc_exit_aisle:
					_saw_lc_exit_aisle = true
					print(
						(
							"LIFECYCLE [8/12]: exit aisle (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _saw_lc_wait:
					_saw_lc_wait = true
					print(
						(
							"LIFECYCLE [9/12]: sidewalk wait (pos=%s, speed=%.1f)"
							% [str(_test_car.global_position), _test_car.speed]
						)
					)
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
					print(
						(
							"LIFECYCLE [10/12]: gap merge (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.CRUISING and _test_car.lane_id == 0 and _saw_lc_merge:
				if not _saw_lc_post_merge_cruise:
					_saw_lc_post_merge_cruise = true
					print(
						(
							"LIFECYCLE [11/12]: lane cruising (speed=%.1f, lane_dist=%.1f)"
							% [_test_car.speed, _test_car.lane_distance]
						)
					)
		else:
			if _saw_lc_post_merge_cruise and not _saw_lc_despawn:
				_saw_lc_despawn = true
				print(
					(
						"LIFECYCLE [12/12]: despawn (errands_completed=%d)"
						% tm.stats["errands_completed"]
					)
				)
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
				print(
					"LIFECYCLE: SUCCESS - observed complete vehicle lifecycle through all 12 stages!"
				)
				main.get_tree().quit(0)
				return
		if _test_frames > 4000:
			assert(false, "Timeout waiting for vehicle lifecycle completion!")

	if "--test-right-turn-following" in user_args:
		_test_frames += 1
		if is_instance_valid(_rt_lead_car) and is_instance_valid(_rt_follower_car):
			var d_euc = _rt_lead_car.global_position.distance_to(_rt_follower_car.global_position)
			if d_euc < _rt_min_distance:
				_rt_min_distance = d_euc
			assert(
				d_euc > 3.0,
				"Cars got too close during right turn following! Minimum distance: %f" % d_euc
			)
			if _rt_lead_car.state == Car.State.APPROACHING and _rt_lead_car.speed < 11.0:
				_rt_saw_lead_braking = true
			if _rt_follower_car.desired_speed < 14.0 or _rt_follower_car.speed < 13.0:
				_rt_saw_follower_braking = true
			if _rt_lead_car.state == Car.State.TO_SPOT:
				_rt_saw_lead_turning = true
			if (
				_rt_saw_lead_turning
				and _rt_lead_car.state != Car.State.APPROACHING
				and _rt_follower_car.state == Car.State.CRUISING
				and _rt_follower_car.speed > 13.5
			):
				_rt_saw_follower_resumed = true
			if (
				_rt_saw_lead_braking
				and _rt_saw_follower_braking
				and _rt_saw_lead_turning
				and _rt_saw_follower_resumed
			):
				assert(
					_rt_min_distance >= 4.0,
					"Safe following distance breached! Min dist: %f" % _rt_min_distance
				)
				print(
					"RIGHT_TURN_TEST: SUCCESS - Follower car slowed down smoothly behind right turning car without crashing!"
				)
				main.get_tree().quit(0)
				return
		if _test_frames > 1500:
			assert(false, "Timeout waiting for right turn following test completion!")

	if (
		"--test-cramped-inn" in user_args
		or "--test-strip-mall" in user_args
		or "--test-frontage" in user_args
	):
		var tag := String(_ci_site).to_upper()
		_test_frames += 1
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 3
				and not _ci_saw_merge
			):
				if not _ci_saw_cruise:
					_ci_saw_cruise = true
					print(
						(
							"%s [1/8]: cruising east in lane 3 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _ci_saw_decision:
					_ci_saw_decision = true
					assert(_test_car.spot != null, "Must have reserved a spot")
					assert(_test_car.spot.serves.has(_ci_site), "Spot must serve %s" % _ci_site)
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT, "Turn signal must be RIGHT"
					)
					print(
						(
							"%s [2/8]: decision & approach turn (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _ci_saw_turn:
					_ci_saw_turn = true
					assert(_test_car.merge_target_lane == 3, "merge_target_lane must be 3")
					print(
						(
							"%s [3/8]: turned into driveway (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _ci_saw_park:
					_ci_saw_park = true
					_test_car.dwell_left = minf(_test_car.dwell_left, 0.5)
					assert(
						_test_car.spot.state == ParkingSpot.State.OCCUPIED, "Spot must be OCCUPIED"
					)
					print(
						(
							"%s [4/8]: parked in stall (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _ci_saw_reverse:
					_ci_saw_reverse = true
					print(
						"%s [5/8]: reversing out (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _ci_saw_exit:
					_ci_saw_exit = true
					print(
						"%s [6/8]: driving to exit (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _ci_saw_wait:
					_ci_saw_wait = true
					var site_id := ParkingLot.get_site_for_destination(_ci_site)
					var wait_point: Vector3 = (
						ParkingLot.get_site_cfg(site_id)["wait"]
						if site_id != &""
						else (
							ParkingLot.SOUTH_LOTS[_ci_site]["wait"]
							if ParkingLot.SOUTH_LOTS.has(_ci_site)
							else ParkingLot.FRONTAGE_WAIT_POINT
						)
					)
					assert(
						_test_car.global_position.distance_to(wait_point) < 1.0,
						"Must be at the %s wait point" % _ci_site
					)
					print(
						(
							"%s [7/8]: waiting at exit wait point (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
					var lane3 = tm.lanes[3]
					lane3.spawn_timer = 9999.0
					for c in lane3.cars:
						if is_instance_valid(c) and c != _test_car:
							c.queue_free()
					lane3.cars.clear()
			elif _test_car.state == Car.State.MERGING:
				if not _ci_saw_merge:
					_ci_saw_merge = true
					print(
						(
							"%s [8/8]: merging into lane 3 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.CRUISING and _test_car.lane_id == 3 and _ci_saw_merge:
				if not _ci_saw_rejoin:
					_ci_saw_rejoin = true
					assert(
						absf(_test_car.global_position.z - 9.375) < 0.5,
						"Car must be in Lane 3 (z=9.375)"
					)
					print("%s: SUCCESS - full errand cycle complete!" % tag)
					main.get_tree().quit(0)
					return
		if _test_frames > 4000:
			assert(false, "Timeout waiting for %s test completion!" % _ci_site)

	if _is_side_lot_test():
		var tag := String(_side_lot_dest).to_upper()
		_test_frames += 1
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and not _side_lot_saw_merge
			):
				if not _side_lot_saw_cruise:
					_side_lot_saw_cruise = true
					print(
						(
							"%s [1/8]: cruising west in lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _side_lot_saw_decision:
					_side_lot_saw_decision = true
					assert(_test_car.spot != null, "Must have reserved a spot")
					assert(
						_test_car.spot.serves.has(_side_lot_dest),
						"Spot must serve %s" % _side_lot_dest
					)
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT, "Turn signal must be RIGHT"
					)
					print(
						(
							"%s [2/8]: decision & approach turn (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _side_lot_saw_turn:
					_side_lot_saw_turn = true
					assert(_test_car.merge_target_lane == 0, "merge_target_lane must be 0")
					print(
						(
							"%s [3/8]: turned into driveway (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _side_lot_saw_park:
					_side_lot_saw_park = true
					_test_car.dwell_left = minf(_test_car.dwell_left, 0.5)
					var tm := main.get_node("TrafficManager") as TrafficManager
					for held in _side_lot_held_spots:
						tm.lot.release(held)
					_side_lot_held_spots.clear()
					assert(
						_test_car.spot.state == ParkingSpot.State.OCCUPIED, "Spot must be OCCUPIED"
					)
					print(
						(
							"%s [4/8]: parked at destination (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _side_lot_saw_reverse:
					_side_lot_saw_reverse = true
					print(
						"%s [5/8]: reversing out (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _side_lot_saw_exit:
					_side_lot_saw_exit = true
					print(
						"%s [6/8]: driving to exit (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _side_lot_saw_wait:
					_side_lot_saw_wait = true
					var site_id := ParkingLot.get_site_for_destination(_side_lot_dest)
					var wait_point: Vector3 = ParkingLot.get_site_cfg(site_id)["wait"]
					assert(
						_test_car.global_position.distance_to(wait_point) < 1.0,
						"Must be at the %s wait point" % site_id
					)
					print(
						(
							"%s [7/8]: waiting to merge (wait_point=%s, pos=%s)"
							% [tag, str(wait_point), str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.MERGING:
				if not _side_lot_saw_merge:
					_side_lot_saw_merge = true
					print(
						(
							"%s [8/8]: merging into lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and _side_lot_saw_merge
			):
				if not _side_lot_saw_rejoin:
					_side_lot_saw_rejoin = true
					assert(
						absf(_test_car.global_position.z - (-9.375)) < 0.5,
						"Car must be in Lane 0 (z=-9.375)"
					)
					print("%s: SUCCESS - full errand cycle complete!" % tag)
					main.get_tree().quit(0)
					return
		if _test_frames > 3600:
			assert(false, "Timeout waiting for %s test completion!" % _side_lot_dest)


func _is_side_lot_test() -> bool:
	return (
		"--test-smell-store" in user_args
		or "--test-smell-gas" in user_args
		or "--test-dorf-service" in user_args
	)


func _run_test_drive_thru() -> void:
	seed(42)
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	for lane in tm.lanes:
		for c in lane.cars:
			c.queue_free()
		lane.cars.clear()
		lane.spawn_timer = 999.0

	# 1. Live Taco Hell Drive-Thru Simulation
	var car1: Car = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")

	var car2: Car = null
	var saw_c1_order := false
	var saw_c1_pickup := false
	var saw_c2_queued := false
	var saw_c2_order := false
	var saw_c2_pickup := false
	var c1_prev_d := 0.0
	var c2_prev_d := 0.0
	var delta := 0.05
	var max_ticks := 2000
	var ticks := 0

	while ticks < max_ticks:
		ticks += 1
		if car2 == null and car1.path_distance >= 10.0:
			car2 = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")

		tm._update_lot_cars(delta)
		for lane in tm.lanes:
			tm._update_lane_traffic(lane, delta)

		if car1.state == Car.State.DRIVE_THRU:
			assert(car1.path_distance >= c1_prev_d - 0.001, "car1 progress must be monotonic")
			c1_prev_d = car1.path_distance
			if car1.dt_order_done and not saw_c1_order:
				saw_c1_order = true
			if car1.dt_pickup_done and not saw_c1_pickup:
				saw_c1_pickup = true

		if car2 != null and car2.state == Car.State.DRIVE_THRU:
			assert(car2.path_distance >= c2_prev_d - 0.001, "car2 progress must be monotonic")
			c2_prev_d = car2.path_distance
			if car2.dt_order_done and not saw_c2_order:
				saw_c2_order = true
			if car2.dt_pickup_done and not saw_c2_pickup:
				saw_c2_pickup = true

		if (
			car2 != null
			and car1.state == Car.State.DRIVE_THRU
			and car2.state == Car.State.DRIVE_THRU
		):
			var d_pos := car1.global_position.distance_to(car2.global_position)
			var min_allowed := (car1.car_length + car2.car_length) * 0.5 - 0.2
			assert(
				d_pos >= min_allowed,
				(
					"Euclidean overlap detected between car1 and car2: dist=%.2f < min=%.2f"
					% [d_pos, min_allowed]
				)
			)
			if tm.find_blocker(car2) == car1 and car2.speed < 0.1:
				saw_c2_queued = true

		if car1.state == Car.State.CRUISING and car2 != null and car2.state == Car.State.CRUISING:
			break

	assert(saw_c1_order, "car1 must dwell to order at menu board")
	assert(saw_c1_pickup, "car1 must dwell to pick up food at window")
	assert(saw_c2_queued, "car2 must queue and stop behind car1 in line")
	assert(saw_c2_order, "car2 must dwell to order at menu board")
	assert(saw_c2_pickup, "car2 must dwell to pick up food at window")
	assert(
		car1.state == Car.State.CRUISING and car1.lane_id == 0,
		"car1 must merge and cruise in lane 0"
	)
	assert(
		car2.state == Car.State.CRUISING and car2.lane_id == 0,
		"car2 must merge and cruise in lane 0"
	)

	# 2. Live Booger King Drive-Thru Simulation
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	for lane in tm.lanes:
		for c in lane.cars:
			c.queue_free()
		lane.cars.clear()
		lane.spawn_timer = 999.0

	var bk1: Car = tm.spawn_drive_thru_car(&"booger_king")

	var bk2: Car = null
	var saw_bk1_order := false
	var saw_bk1_pickup := false
	var saw_bk2_queued := false
	var saw_bk2_order := false
	var saw_bk2_pickup := false
	var bk1_prev_d := 0.0
	var bk2_prev_d := 0.0
	ticks = 0
	var bk1_merged_lane := false

	while ticks < max_ticks:
		ticks += 1
		if bk2 == null and bk1.path_distance >= 10.0:
			bk2 = tm.spawn_drive_thru_car(&"booger_king")

		tm._update_lot_cars(delta)
		for lane in tm.lanes:
			tm._update_lane_traffic(lane, delta)

		if bk1.state == Car.State.DRIVE_THRU:
			assert(bk1.path_distance >= bk1_prev_d - 0.001, "bk1 progress must be monotonic")
			bk1_prev_d = bk1.path_distance
			if bk1.dt_order_done and not saw_bk1_order:
				saw_bk1_order = true
			if bk1.dt_pickup_done and not saw_bk1_pickup:
				saw_bk1_pickup = true

		if bk2 != null and bk2.state == Car.State.DRIVE_THRU:
			assert(bk2.path_distance >= bk2_prev_d - 0.001, "bk2 progress must be monotonic")
			bk2_prev_d = bk2.path_distance
			if bk2.dt_order_done and not saw_bk2_order:
				saw_bk2_order = true
			if bk2.dt_pickup_done and not saw_bk2_pickup:
				saw_bk2_pickup = true

		if bk2 != null and bk1.state == Car.State.DRIVE_THRU and bk2.state == Car.State.DRIVE_THRU:
			var d_pos := bk1.global_position.distance_to(bk2.global_position)
			var min_allowed := (bk1.car_length + bk2.car_length) * 0.5 - 0.2
			assert(
				d_pos >= min_allowed,
				(
					"Euclidean overlap detected between bk1 and bk2: dist=%.2f < min=%.2f"
					% [d_pos, min_allowed]
				)
			)
			if tm.find_blocker(bk2) == bk1 and bk2.speed < 0.1:
				saw_bk2_queued = true
		if bk1.state == Car.State.CRUISING and (tm.lanes[3].cars.has(bk1) or bk1_merged_lane):
			bk1_merged_lane = true
		if bk1.state == Car.State.CRUISING and bk2 != null and bk2.state == Car.State.CRUISING:
			break

	assert(saw_bk1_order, "bk1 must dwell at menu/pickup window")
	assert(saw_bk1_pickup, "bk1 must dwell at menu/pickup window")
	assert(saw_bk2_queued, "bk2 must queue and stop behind bk1 in line")
	assert(saw_bk2_order, "bk2 must dwell at menu/pickup window")
	assert(saw_bk2_pickup, "bk2 must dwell at menu/pickup window")
	assert(
		bk1.state == Car.State.CRUISING and bk1.lane_id == 3, "bk1 must merge and cruise in lane 3"
	)
	assert(
		bk2.state == Car.State.CRUISING and bk2.lane_id == 3, "bk2 must merge and cruise in lane 3"
	)
	assert(bk1_merged_lane or tm.lanes[3].cars.has(bk1), "bk1 must be added to lane 3 traffic")

	# 3. Seeded Full-Traffic Phase
	seed(42)
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	if tm.lot != null:
		for s in tm.lot.spots:
			tm.lot.release(s)
	for lane in tm.lanes:
		for c in lane.cars:
			c.queue_free()
		lane.cars.clear()
		lane.spawn_timer = randf_range(1.0, 2.5)

	tm._seed_parked_cars()

	var dt_cars: Array[Car] = []
	var p3_taco1: Car = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
	var p3_bk1: Car = tm.spawn_drive_thru_car(&"booger_king")
	dt_cars.append(p3_taco1)
	dt_cars.append(p3_bk1)
	var p3_taco2: Car = null
	var p3_bk2: Car = null

	var full_cap := 4500
	var finished_all := false
	for t in range(full_cap):
		if t >= 220 and p3_taco2 == null and tm.can_spawn_drive_thru(&"taco_hell_drive_thru"):
			p3_taco2 = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
			dt_cars.append(p3_taco2)
		if t >= 220 and p3_bk2 == null and tm.can_spawn_drive_thru(&"booger_king"):
			p3_bk2 = tm.spawn_drive_thru_car(&"booger_king")
			dt_cars.append(p3_bk2)

		tm._physics_process(delta)

		var all_cars: Array[Car] = []
		for c in tm.lot_cars:
			if is_instance_valid(c):
				all_cars.append(c)
		for lane in tm.lanes:
			for c in lane.cars:
				if is_instance_valid(c) and not all_cars.has(c):
					all_cars.append(c)

		for i in range(all_cars.size()):
			var c_i := all_cars[i]
			for j in range(i + 1, all_cars.size()):
				var c_j := all_cars[j]
				if not dt_cars.has(c_i) and not dt_cars.has(c_j):
					continue
				var dpos := c_j.global_position - c_i.global_position
				var dpos_2d := Vector2(dpos.x, dpos.z)
				var h_i := c_i.get_heading()
				var f_i := Vector2(h_i.x, h_i.z).normalized()
				var l_i := Vector2(-f_i.y, f_i.x)
				var h_j := c_j.get_heading()
				var f_j := Vector2(h_j.x, h_j.z).normalized()
				var l_j := Vector2(-f_j.y, f_j.x)

				var hx_i := c_i.car_length * 0.5
				var hz_i := c_i.car_width * 0.5
				var hx_j := c_j.car_length * 0.5
				var hz_j := c_j.car_width * 0.5

				var separated := false
				var axes := [f_i, l_i, f_j, l_j]
				for axis in axes:
					var dist_axis := absf(dpos_2d.dot(axis))
					var r_i := absf(f_i.dot(axis)) * hx_i + absf(l_i.dot(axis)) * hz_i
					var r_j := absf(f_j.dot(axis)) * hx_j + absf(l_j.dot(axis)) * hz_j
					if dist_axis >= (r_i + r_j - 0.25):
						separated = true
						break

				assert(
					separated,
					(
						"Euclidean car penetration involving drive-thru car %s (%s) and %s (%s) at tick %d: pos_i=%s, pos_j=%s"
						% [
							c_i.name,
							c_i.get_state_name(),
							c_j.name,
							c_j.get_state_name(),
							t,
							c_i.global_position,
							c_j.global_position
						]
					)
				)

		if p3_taco2 != null and p3_bk2 != null:
			var all_cruising := true
			for dt_c in dt_cars:
				if dt_c.state != Car.State.CRUISING:
					all_cruising = false
					break
			if all_cruising:
				finished_all = true
				break

	assert(
		finished_all,
		"All 4 drive-thru cars must complete their loops and reach CRUISING within frame cap"
	)
	assert(
		p3_taco1.lane_id == 0 and p3_taco2.lane_id == 0,
		"Taco Hell drive-thru cars must merge and cruise in lane 0"
	)
	assert(
		p3_bk1.lane_id == 3 and p3_bk2.lane_id == 3,
		"Booger King drive-thru cars must merge and cruise in lane 3"
	)

	print(
		"DRIVE_THRU_TEST: SUCCESS - Verified live simulation, dwell at stops, queueing without overlap, and clean seeded full-traffic phase with staggered cars completing loops without collisions or deadlocks!"
	)
	main.get_tree().quit(0)


func _run_test_cramped_inn_dropoff() -> void:
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	for c in tm.lot_cars:
		c.queue_free()
	tm.lot_cars.clear()
	for lane in tm.lanes:
		for c in lane.cars:
			c.queue_free()
		lane.cars.clear()
		lane.spawn_timer = 999.0

	# 1. Spawn a Taxi doing Cramped Inn drop-off/pickup
	var taxi: Car = tm.spawn_cramped_inn_dropoff_car(true)
	assert(taxi.can_take_errands(), "taxi must be able to take drop-off errand")
	assert(not taxi.can_park(), "taxi must not be able to park in stalls")

	var car2: Car = null
	var saw_taxi_under_awning := false
	var saw_taxi_dwell := false
	var saw_car2_under_awning := false
	var saw_car2_dwell := false
	var _saw_car2_queued := false
	var taxi_prev_d := 0.0
	var car2_prev_d := 0.0
	var delta := 0.05
	var max_ticks := 2000
	var ticks := 0

	while ticks < max_ticks:
		ticks += 1
		if car2 == null and taxi.path_distance >= 12.0:
			car2 = tm.spawn_cramped_inn_dropoff_car(false)

		tm._update_lot_cars(delta)
		for lane in tm.lanes:
			tm._update_lane_traffic(lane, delta)

		if taxi.state == Car.State.DRIVE_THRU:
			assert(taxi.path_distance >= taxi_prev_d - 0.001, "taxi progress must be monotonic")
			taxi_prev_d = taxi.path_distance
			if (
				taxi.global_position.x >= 41.0
				and taxi.global_position.x <= 52.0
				and taxi.global_position.z >= 24.5
				and taxi.global_position.z <= 32.5
			):
				saw_taxi_under_awning = true
			if taxi.dt_pickup_done and taxi.dt_dwell_timer > 0.0:
				saw_taxi_dwell = true

		if car2 != null and car2.state == Car.State.DRIVE_THRU:
			assert(car2.path_distance >= car2_prev_d - 0.001, "car2 progress must be monotonic")
			car2_prev_d = car2.path_distance
			if (
				car2.global_position.x >= 41.0
				and car2.global_position.x <= 52.0
				and car2.global_position.z >= 24.5
				and car2.global_position.z <= 32.5
			):
				saw_car2_under_awning = true
			if car2.dt_pickup_done and car2.dt_dwell_timer > 0.0:
				saw_car2_dwell = true

		if (
			car2 != null
			and taxi.state == Car.State.DRIVE_THRU
			and car2.state == Car.State.DRIVE_THRU
		):
			var d_pos := taxi.global_position.distance_to(car2.global_position)
			var min_allowed := (taxi.car_length + car2.car_length) * 0.5 - 0.2
			assert(
				d_pos >= min_allowed,
				(
					"Euclidean overlap detected between taxi and car2: dist=%.2f < min=%.2f"
					% [d_pos, min_allowed]
				)
			)
			if tm.find_blocker(car2) == taxi and car2.speed < 0.1:
				_saw_car2_queued = true

		if taxi.state == Car.State.CRUISING and car2 != null and car2.state == Car.State.CRUISING:
			break

	assert(saw_taxi_under_awning, "taxi must go under roof / awning")
	assert(saw_taxi_dwell, "taxi must dwell under roof / awning")
	assert(saw_car2_under_awning, "passenger car must go under roof / awning")
	assert(saw_car2_dwell, "passenger car must dwell under roof / awning")
	assert(
		taxi.state == Car.State.CRUISING and taxi.lane_id == 3,
		"taxi must merge and cruise in lane 3"
	)
	assert(
		car2.state == Car.State.CRUISING and car2.lane_id == 3,
		"passenger car must merge and cruise in lane 3"
	)
	print(
		"CRAMPED_INN_DROPOFF_TEST: SUCCESS - Taxi and passenger car navigated under awning, dwelled, and merged into lane 3 without collisions"
	)
	main.get_tree().quit(0)


func _run_test_grass_shortcut() -> void:
	seed(42)
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	assert(tm.lot != null, "ParkingLot must exist")

	var links := ParkingLot.get_shortcut_links()
	assert(links.size() >= 2, "Must have accepted shortcut links in both directions")

	for link in links:
		var source_site: StringName = link.get("source_site_id", &"")
		var dest_site: StringName = link.get("destination_site_id", &"")
		assert(
			source_site != &"" and dest_site != &"",
			"Shortcut link must have valid source and dest sites"
		)
		print("GRASS_SHORTCUT_TEST: Running scenario for link %s -> %s" % [source_site, dest_site])
		var dest_lane: int = ParkingLot.get_site_cfg(dest_site).get("lane_id", 0)

		# 1. Clear lot cars, lane cars, and free spots
		for c in tm.lot_cars:
			if is_instance_valid(c):
				c.queue_free()
		tm.lot_cars.clear()

		for lane in tm.lanes:
			for c in lane.cars:
				if is_instance_valid(c):
					c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = 9999.0

		for s in tm.lot.spots:
			tm.lot.release(s)

		# 2. Find a source/destination stall pair joined by this link
		var source_spot: ParkingSpot = null
		var dest_spot: ParkingSpot = null
		for s in tm.lot.spots:
			for d in tm.lot.spots:
				if ParkingLot.get_shortcut_link_for_spots(s, d) == link:
					source_spot = s
					dest_spot = d
					break
			if source_spot != null:
				break
		assert(source_spot != null, "Source spot must exist for %s" % source_site)
		assert(dest_spot != null, "Destination spot must exist for %s" % dest_site)
		# Forced selection uses the first free candidate; exercise this link even when a
		# source business has several outgoing links.
		var dest_index: int = tm.lot.spots.find(dest_spot)
		var first_spot: ParkingSpot = tm.lot.spots[0]
		tm.lot.spots[0] = dest_spot
		tm.lot.spots[dest_index] = first_spot

		# 3. Spawn test car parked at source_spot
		var car: Car = tm.PassengerCarScene.instantiate()
		tm.add_child(car)
		car.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		car.state = Car.State.PARKED
		tm.lot.reserve(source_spot, car)
		tm.lot.occupy(source_spot)
		car.global_transform = source_spot.transform
		car.reset_physics_interpolation()
		tm.lot_cars.append(car)

		# Force traits and maneuver outcomes through normal fields
		car.force_shortcut = true
		car.shortcut_evaluated = false
		car.dwell_left = 0.1

		assert(tm.lot.check_invariants() == 0, "Initial invariant check must pass")

		# 4. Simulation loop
		var delta := 0.05
		var max_ticks := 3000
		var ticks := 0
		var saw_dest_reserved := false
		var saw_source_released := false
		var saw_shortcut_active := false
		var saw_grass_speed_drop := false
		var saw_dest_arrival := false
		var saw_dest_occupied := false
		var saw_dest_reverse := false
		var saw_dest_released := false
		var saw_to_exit := false
		var saw_waiting_to_merge := false
		var saw_merging := false
		var saw_cruising := false
		var saw_normal_exit := false
		var observed_dest_spot: ParkingSpot = null

		while ticks < max_ticks:
			ticks += 1
			tm._update_lot_cars(delta)
			if car.pending_destination_spot != null and not saw_dest_reserved:
				assert(car.pending_destination_spot == dest_spot, "Must exercise the selected link")
				tm.lot.spots[0] = first_spot
				tm.lot.spots[dest_index] = dest_spot
			for lane in tm.lanes:
				tm._update_lane_traffic(lane, delta)

			# Stage A: Dwell finishes and destination spot is reserved before movement while source remains occupied
			if (
				car.state == Car.State.REVERSING_OUT
				and not saw_dest_reserved
				and not saw_source_released
			):
				assert(
					car.pending_destination_spot != null,
					"Destination spot must be reserved during reverse-out"
				)
				assert(
					car.pending_destination_spot.state == ParkingSpot.State.RESERVED,
					"Destination spot must be RESERVED"
				)
				assert(
					car.spot == source_spot, "Source spot must remain assigned during reverse-out"
				)
				assert(
					source_spot.state == ParkingSpot.State.OCCUPIED,
					"Source spot must remain OCCUPIED"
				)
				assert(tm.lot.check_invariants() == 0, "No leaks during reverse-out")
				observed_dest_spot = car.pending_destination_spot
				saw_dest_reserved = true

			# Stage B: Reverse-out completes -> source spot released, destination promoted to car.spot, enter SHORTCUT
			if car.state == Car.State.SHORTCUT:
				if not saw_source_released:
					saw_source_released = true
					assert(
						source_spot.state == ParkingSpot.State.FREE,
						"Source spot must be released to FREE"
					)
					assert(source_spot.car == null, "Source spot car reference must be cleared")
					assert(
						car.pending_destination_spot == null,
						"pending_destination_spot must be cleared"
					)
					assert(car.spot == observed_dest_spot, "car.spot must hold destination spot")
					assert(
						car.spot.state == ParkingSpot.State.RESERVED,
						"Destination spot remains RESERVED until arrival"
					)
					assert(car.path != null, "Car must have shortcut path")
					assert(tm.lot.check_invariants() == 0, "No leaks after reverse-out completion")
				saw_shortcut_active = true

				if ParkingLot.is_in_grass_shortcut(car.global_position):
					if car.desired_speed <= TrafficManager.V_GRASS + 0.1:
						saw_grass_speed_drop = true
					# Verify car clears all scenery colliders (buildings, trees, props) during grass traversal
					var hit := _scenery_hit(car)
					assert(
						hit == "",
						(
							"Car in grass shortcut must clear scenery (intersected %s at pos %s)"
							% [hit, str(car.global_position)]
						)
					)
			# Stage C: Arrival at destination spot -> occupied, parked, dwell starts
			if car.state == Car.State.PARKED and saw_shortcut_active and not saw_dest_arrival:
				saw_dest_arrival = true
				assert(car.spot == observed_dest_spot, "Car must be assigned destination spot")
				assert(
					observed_dest_spot.state == ParkingSpot.State.OCCUPIED,
					"Destination spot must become OCCUPIED on arrival"
				)
				assert(observed_dest_spot.car == car, "Destination spot car must be car")
				assert(car.has_taken_shortcut, "has_taken_shortcut must be true")
				assert(tm.lot.check_invariants() == 0, "No leaks on destination arrival")
				saw_dest_occupied = true
				# Force destination dwell to finish promptly through normal field
				car.dwell_left = 0.1

			# Stage D: Destination dwell finishes -> reverse out from destination stall without chaining
			if saw_dest_arrival and car.state == Car.State.REVERSING_OUT and not saw_dest_reverse:
				saw_dest_reverse = true
				assert(car.has_taken_shortcut, "has_taken_shortcut must prevent chaining")
				assert(
					car.pending_destination_spot == null,
					"Must not reserve another shortcut destination"
				)
				assert(
					car.spot == observed_dest_spot, "Destination spot assigned during reverse-out"
				)
				assert(
					observed_dest_spot.state == ParkingSpot.State.OCCUPIED,
					"Destination spot OCCUPIED during reverse-out"
				)

			# Stage E: Reversing out of destination stall finishes -> destination released, enter TO_EXIT
			if car.state == Car.State.TO_EXIT and not saw_to_exit:
				saw_to_exit = true
				saw_dest_released = true
				assert(car.spot == null, "car.spot must be null after reverse-out")
				assert(
					observed_dest_spot.state == ParkingSpot.State.FREE,
					"Destination spot must be released to FREE"
				)
				assert(
					observed_dest_spot.car == null, "Destination spot car reference must be cleared"
				)
				for s in tm.lot.spots:
					assert(s.car != car, "Car must not be assigned to any stall in lot")
				assert(tm.lot.check_invariants() == 0, "No leaks after destination reverse-out")

			# Stage F: Driving to exit aisle -> reaches WAITING_TO_MERGE
			if car.state == Car.State.WAITING_TO_MERGE and not saw_waiting_to_merge:
				saw_waiting_to_merge = true
				assert(
					car.merge_target_lane == dest_lane, "merge_target_lane must be %d" % dest_lane
				)

			# Stage G: Gap merge onto stroad
			if car.state == Car.State.MERGING and not saw_merging:
				saw_merging = true

			# Stage H: Merged into the destination site's curb lane -> cruising
			if car.state == Car.State.CRUISING and saw_merging and not saw_cruising:
				saw_cruising = true
				assert(car.lane_id == dest_lane, "Car must be cruising in lane %d" % dest_lane)
				assert(tm.lanes[dest_lane].cars.has(car), "Destination lane must contain car")
				assert(not tm.lot_cars.has(car), "lot_cars must no longer contain car")

			# Stage I: Normal exit (reaches end of lane and despawns)
			if (
				saw_cruising
				and (
					not is_instance_valid(car)
					or car.is_queued_for_deletion()
					or not tm.lanes[dest_lane].cars.has(car)
					or car.lane_distance >= tm.lanes[dest_lane].length
				)
			):
				saw_normal_exit = true
				break

		assert(
			saw_dest_reserved,
			(
				"Must have observed destination reservation before movement for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_source_released,
			"Must have observed source spot release for link %s -> %s" % [source_site, dest_site]
		)
		assert(
			saw_shortcut_active,
			(
				"Must have observed shortcut route traversal for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_grass_speed_drop,
			(
				"Must have observed grass speed in grass corridor for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_dest_arrival and saw_dest_occupied,
			(
				"Must have observed destination arrival and occupancy for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_dest_reverse,
			(
				"Must have observed destination reverse-out for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_dest_released,
			(
				"Must have observed destination spot release for link %s -> %s"
				% [source_site, dest_site]
			)
		)
		assert(
			saw_to_exit,
			"Must have observed travel to exit for link %s -> %s" % [source_site, dest_site]
		)
		assert(
			saw_waiting_to_merge,
			"Must have observed sidewalk wait for link %s -> %s" % [source_site, dest_site]
		)
		assert(
			saw_merging, "Must have observed gap merge for link %s -> %s" % [source_site, dest_site]
		)
		assert(
			saw_cruising,
			"Must have observed curb lane cruising for link %s -> %s" % [source_site, dest_site]
		)
		assert(
			saw_normal_exit,
			(
				"Must have observed eventual normal exit / despawn for link %s -> %s"
				% [source_site, dest_site]
			)
		)

	print(
		"GRASS_SHORTCUT_TEST: SUCCESS - Verified every shortcut link: source release, destination reservation/occupancy, grass route traversal, and eventual normal exit!"
	)
	main.get_tree().quit(0)


## Name of a non-ground scenery collider (building, tree, pole, prop) overlapping `car`, or "".
func _scenery_hit(car: Car) -> String:
	var col_shape := car.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null or col_shape.shape == null:
		return ""
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = col_shape.shape
	query.transform = car.global_transform * col_shape.transform
	query.collision_mask = 1
	for hit in car.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider = hit.get("collider")
		if collider == null or not is_instance_valid(collider) or collider is CharacterBody3D:
			continue
		var col_name: String = str(collider.name)
		var parent_name: String = (
			str(collider.get_parent().name) if collider.get_parent() != null else ""
		)
		var p_lower := parent_name.to_lower()
		var is_ground := (
			col_name == "Forecourt"
			or (
				col_name == "StaticBody3D"
				and (
					p_lower.contains("ground")
					or p_lower.contains("parking")
					or p_lower.contains("asphalt")
					or p_lower.contains("driveway")
					or p_lower.contains("road")
					or p_lower.contains("sidewalk")
					or p_lower.contains("apron")
					or p_lower.contains("grassgap")
					or p_lower.contains("shoulder")
				)
			)
		)
		if not is_ground:
			return "%s in %s" % [col_name, parent_name]
	return ""


## For every stall with a sidewalk crossing: a parked car rolling the sidewalk shortcut backs
## out, drives over the sidewalk clear of scenery and of other stalls, waits at the curb of the
## crossing, and merges into its site's curb lane. Every authored crossing must be reachable.
func _run_test_sidewalk_shortcut() -> void:
	seed(42)
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null and tm.lot != null, "TrafficManager with a lot must exist")

	var used_crossings := {}
	for spot: ParkingSpot in tm.lot.spots.duplicate():
		var crossing_x := ParkingLot.sidewalk_crossing_x(spot)
		if is_nan(crossing_x):
			continue
		var site_id := ParkingLot.lot_group(spot)
		used_crossings["%s@%.1f" % [site_id, crossing_x]] = true
		var lane_id: int = ParkingLot.get_site_cfg(site_id).get("lane_id", 0)
		var label := "%s stall x=%.1f @ x=%.1f" % [site_id, spot.x, crossing_x]
		for c in tm.lot_cars:
			if is_instance_valid(c):
				c.queue_free()
		tm.lot_cars.clear()
		for lane in tm.lanes:
			for c in lane.cars:
				if is_instance_valid(c):
					c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = 9999.0
		for s in tm.lot.spots:
			tm.lot.release(s)
		await main.get_tree().physics_frame

		var car: Car = tm.PassengerCarScene.instantiate()
		tm.add_child(car)
		car.setup(0, 0.0, 1.0, 0.0, 100.0, 10.0, Car.CarType.SEDAN)
		car.state = Car.State.PARKED
		car.merge_target_lane = lane_id
		tm.lot.reserve(spot, car)
		tm.lot.occupy(spot)
		car.global_transform = spot.transform
		car.reset_physics_interpolation()
		tm.lot_cars.append(car)
		car.force_sidewalk_shortcut = true
		car.dwell_left = 0.1

		var wait_z := -ParkingLot.CURB_WAIT_Z if lane_id == 0 else ParkingLot.CURB_WAIT_Z
		var saw_waiting := false
		var saw_cruising := false
		for tick in 3000:
			tm._update_lot_cars(0.05)
			for lane in tm.lanes:
				tm._update_lane_traffic(lane, 0.05)
			if car.state == Car.State.TO_EXIT or car.state == Car.State.MERGING:
				var hit := _scenery_hit(car)
				if hit == "" and car.state == Car.State.TO_EXIT:
					hit = _stall_hit(car, spot, tm.lot.spots)
				assert(
					hit == "",
					"Crossing %s must stay clear (hit %s at %s)" % [label, hit, car.global_position]
				)
			if car.state == Car.State.WAITING_TO_MERGE and not saw_waiting:
				saw_waiting = true
				assert(
					(
						absf(car.global_position.x - crossing_x) < 0.1
						and absf(car.global_position.z - wait_z) < 0.1
					),
					(
						"Car must wait at the curb of crossing %s, was %s"
						% [label, car.global_position]
					)
				)
			if car.state == Car.State.CRUISING:
				saw_cruising = true
				assert(car.lane_id == lane_id, "Car must join lane %d at %s" % [lane_id, label])
				assert(is_nan(car.sidewalk_crossing_x), "Crossing must clear once merged")
				break
		assert(saw_waiting, "Car must wait at the curb of crossing %s" % label)
		assert(saw_cruising, "Car must merge into traffic from crossing %s" % label)
		assert(tm.lot.check_invariants() == 0, "No spot leaks after crossing %s" % label)
		print("SIDEWALK_SHORTCUT_TEST: %s verified" % label)

	for site_id in ParkingLot.SIDEWALK_CROSSINGS:
		for crossing_x: float in ParkingLot.SIDEWALK_CROSSINGS[site_id]["x"]:
			assert(
				used_crossings.has("%s@%.1f" % [site_id, crossing_x]),
				"Some stall must lead to crossing %s @ x=%.1f" % [site_id, crossing_x]
			)
	print("SIDEWALK_SHORTCUT_TEST: SUCCESS")
	main.get_tree().quit(0)


## Another stall whose parked-car footprint `car` overlaps, as "x,z", or "".
func _stall_hit(car: Car, own: ParkingSpot, spots: Array[ParkingSpot]) -> String:
	var half_w := car.car_width * 0.5
	var half_l := car.car_length * 0.5
	var corners := [
		Vector3(half_w, 0, half_l),
		Vector3(-half_w, 0, half_l),
		Vector3(half_w, 0, -half_l),
		Vector3(-half_w, 0, -half_l),
	]
	for s in spots:
		if s == own:
			continue
		var to_stall := s.transform.affine_inverse()
		for corner: Vector3 in corners:
			var local := to_stall * (car.global_transform * corner)
			if absf(local.x) < half_w and absf(local.z) < half_l:
				return "stall %.1f,%.1f" % [s.x, s.transform.origin.z]
	return ""


## Patrol police light up behind a car, both pull onto the shoulder clear of street furniture,
## traffic (an in-lane bus and a car free to move over) gets past without stopping or touching
## them, then the stopped car leaves before the police, who go dark.
func _run_test_traffic_stop() -> void:
	seed(7)
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	# Let static bodies register so shoulder clearance queries see poles and lamps.
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	for c in tm.lot_cars:
		if is_instance_valid(c):
			c.queue_free()
	tm.lot_cars.clear()
	for l in tm.lanes:
		for c in l.cars:
			if is_instance_valid(c):
				c.queue_free()
		l.cars.clear()
		l.spawn_timer = 9999.0

	var lane: TrafficManager.Lane = tm.lanes[3]
	var suspect := _spawn_stop_test_car(tm, tm.PassengerCarScene, lane, 45.0, Car.CarType.SEDAN)
	var police := _spawn_stop_test_car(tm, tm.PassengerCarScene, lane, 15.0, Car.CarType.POLICE_SUV)
	police.on_patrol = true
	assert(not police.is_siren_on(), "Patrol police must cruise dark before a traffic stop")

	var stop: TrafficStop = null
	var followers: Array[Car] = []
	var passed: Dictionary = {}
	var saw_pursuit_lights := false
	var saw_stopped := false
	var suspect_left_tick := -1
	var police_left_tick := -1
	var delta := 1.0 / 30.0
	for tick in range(6000):
		tm._update_traffic_stops(delta)
		for l in tm.lanes:
			tm._update_lane_traffic(l, delta)
		tm._apply_pending_lane_transfers()
		tm._physics_tick_count += 1
		if stop == null:
			stop = police.traffic_stop
			continue
		if stop.phase == TrafficStop.Phase.PURSUIT and police.is_siren_on():
			saw_pursuit_lights = true

		if stop.phase == TrafficStop.Phase.STOPPED and not saw_stopped:
			saw_stopped = true
			assert(saw_pursuit_lights, "Police must light up while closing in")
			var stop_gap := TrafficStop.bumper_gap(police, suspect)
			assert(
				stop_gap > 0.0 and stop_gap < TrafficStop.POLICE_GAP + 1.0,
				"Police must stop right behind the pulled-over car (gap %.2f)" % stop_gap
			)
			# Inner side on the asphalt shoulder (ends at |z| = 11.85, world/road.tscn), outer
			# side up on the sidewalk.
			for c in [suspect, police]:
				var inner: float = absf(c.current_lateral_z) - c.car_width * 0.5
				var outer: float = absf(c.current_lateral_z) + c.car_width * 0.5
				assert(
					inner < 11.85 and outer > Car.CURB_Z,
					(
						"Pulled-over car must straddle pavement and sidewalk (z %.2f..%.2f)"
						% [inner, outer]
					)
				)
				assert(
					_stop_footprint_clear(tm, c),
					"Pulled-over car at x=%.1f must not sit in a pole or lamp" % c.global_position.x
				)
			# Traffic arrives once both cars sit on the shoulder.
			followers.append(
				_spawn_stop_test_car(
					tm, tm.BusScene, lane, stop.police_stop_distance - 60.0, Car.CarType.BUS
				)
			)
			followers.append(
				_spawn_stop_test_car(
					tm,
					tm.PassengerCarScene,
					lane,
					stop.police_stop_distance - 95.0,
					Car.CarType.HATCHBACK
				)
			)

		for f in followers:
			if passed.has(f):
				continue
			if f.lane_distance > suspect.lane_distance + 0.5 * (f.car_length + suspect.car_length):
				passed[f] = true
				continue
			if f.lane_distance > stop.police_stop_distance - 40.0:
				assert(
					f.speed > 3.0,
					"Traffic must keep moving past a traffic stop, not queue behind it"
				)
			for c in [suspect, police]:
				assert(
					not CarSweep.footprints_overlap(
						_stop_test_footprint(f), _stop_test_footprint(c)
					),
					"Passing traffic must swerve clear of pulled-over cars"
				)

		if stop.phase == TrafficStop.Phase.STOPPED:
			# Hold the stop until traffic has passed, then send everyone on their way.
			stop.dwell_left = (
				1.0 if passed.size() < followers.size() else minf(stop.dwell_left, 0.5)
			)
		if saw_stopped:
			if suspect_left_tick < 0 and suspect.speed > 1.0:
				suspect_left_tick = tick
			if police_left_tick < 0 and police.speed > 1.0:
				police_left_tick = tick
		if stop.phase == TrafficStop.Phase.DONE:
			break

	assert(saw_stopped, "Traffic stop must reach the shoulder")
	assert(stop.phase == TrafficStop.Phase.DONE, "Traffic stop must finish")
	assert(passed.size() == 2, "Both following vehicles must get past the traffic stop")
	assert(
		suspect_left_tick >= 0 and police_left_tick > suspect_left_tick,
		"Stopped car must pull away before the police"
	)
	for c in [suspect, police]:
		assert(c.state == Car.State.CRUISING and c.traffic_stop == null, "Cars must rejoin traffic")
		assert(
			absf(c.current_lateral_z - lane.z) < 0.1,
			"Departing cars must return to the lane center"
		)
	assert(not police.is_siren_on(), "Police lights must go off after the stop")
	assert(not police.on_patrol, "A patrol car makes one traffic stop")
	print(
		"TRAFFIC_STOP_TEST: SUCCESS - pursuit, shoulder stop, swerving traffic, and departure order"
	)
	main.get_tree().quit(0)


## A curb-lane bus brakes to its stop with the door at the pole, tucks in beside the lane, and
## dwells while a car that must stay in its lane swerves past without queueing or touching it;
## then it pulls back out to its lane center and drives on.
## Police never pick a bus stop for a traffic stop.
func _run_test_bus_stop() -> void:
	seed(11)
	var tm = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	for c in tm.lot_cars:
		if is_instance_valid(c):
			c.queue_free()
	tm.lot_cars.clear()
	for l in tm.lanes:
		for c in l.cars:
			if is_instance_valid(c):
				c.queue_free()
		l.cars.clear()
		l.spawn_timer = 9999.0

	var lane: TrafficManager.Lane = tm.lanes[3]
	var pole_d := 200.0
	var bus := _spawn_stop_test_car(tm, tm.BusScene, lane, 110.0, Car.CarType.BUS) as BusCar
	var stop_d := bus.stop_distance_for(pole_d)

	var probe := _spawn_stop_test_car(tm, tm.PassengerCarScene, tm.lanes[0], 5.0, Car.CarType.SEDAN)
	var edge := TrafficStop.OUTER_EDGE_MAX
	lane.bus_stops = PackedFloat32Array()
	assert(
		TrafficStop.is_site_clear(tm, lane, stop_d, probe, probe, edge),
		"Test stop site must otherwise be clear for a traffic stop"
	)
	lane.bus_stops = PackedFloat32Array([pole_d])
	assert(
		not TrafficStop.is_site_clear(tm, lane, stop_d, probe, probe, edge),
		"Police must not pick a bus stop for a traffic stop"
	)
	probe.queue_free()
	tm.lanes[0].cars.clear()

	var followers: Array[Car] = []
	var passed: Dictionary = {}
	var saw_dwell := false
	var saw_pull_out := false
	var delta := 1.0 / 30.0
	for tick in range(3000):
		for l in tm.lanes:
			tm._update_lane_traffic(l, delta)
		tm._apply_pending_lane_transfers()
		tm._physics_tick_count += 1

		if bus.stop_phase == BusCar.StopPhase.DWELLING and not saw_dwell:
			saw_dwell = true
			assert(
				absf(bus.lane_distance - stop_d) < 1.0 and bus.speed == 0.0,
				(
					"Bus must stop with its door at the pole (off by %.2f m)"
					% (bus.lane_distance - stop_d)
				)
			)
			assert(bus.is_beside_lane(), "A dwelling bus must tuck in beside its lane")
			var outer: float = absf(bus.current_lateral_z) + bus.car_width * 0.5
			assert(outer < Car.CURB_Z, "Bus must stay off the sidewalk (outer z %.2f)" % outer)
			var stays_in_lane := _spawn_stop_test_car(
				tm, tm.PassengerCarScene, lane, stop_d - 80.0, Car.CarType.SUV
			)
			stays_in_lane.had_errand = true  # left a lot: never changes lanes
			followers.append(stays_in_lane)

		for f in followers:
			if passed.has(f):
				continue
			if f.lane_distance > bus.lane_distance + 0.5 * (f.car_length + bus.car_length):
				passed[f] = true
				continue
			if f.lane_distance > stop_d - 40.0:
				assert(f.speed > 3.0, "Traffic must keep moving past a stopped bus, not queue")
			assert(
				not CarSweep.footprints_overlap(_stop_test_footprint(f), _stop_test_footprint(bus)),
				"Passing traffic must swerve clear of a stopped bus"
			)

		if bus.stop_phase == BusCar.StopPhase.DWELLING:
			# Hold the bus until traffic has passed, then let it leave.
			bus.stop_timer = 1.0 if passed.size() < followers.size() else minf(bus.stop_timer, 0.5)
		if bus.stop_phase == BusCar.StopPhase.PULLING_OUT:
			saw_pull_out = true
		if saw_pull_out and bus.stop_phase == BusCar.StopPhase.NONE:
			break

	assert(saw_dwell, "Bus must stop at the bus stop")
	assert(passed.size() == 1, "In-lane traffic must get past the stopped bus")
	assert(saw_pull_out and bus.stop_phase == BusCar.StopPhase.NONE, "Bus must pull away")
	assert(bus.speed > 1.0 and bus.lane_distance > stop_d, "Bus must drive on after its stop")
	assert(absf(bus.current_lateral_z - lane.z) < 0.1, "Bus must return to its lane center")
	assert(bus.turn_signal == Car.TurnSignal.NONE, "Bus must cancel its signal after rejoining")
	print("BUS_STOP_TEST: SUCCESS - stop at pole, traffic swerves past, bus pulls back out")
	main.get_tree().quit(0)


func _spawn_stop_test_car(
	tm: TrafficManager,
	scene: PackedScene,
	lane: TrafficManager.Lane,
	distance: float,
	type: Car.CarType
) -> Car:
	var car: Car = scene.instantiate()
	tm.add_child(car)
	car.setup(lane.id, lane.z, lane.direction, lane.start_x, lane.length, 14.0, type)
	car.lane_distance = distance
	car.update_presentation()
	lane.cars.append(car)
	return car


func _stop_test_footprint(car: Car) -> PackedVector2Array:
	return CarSweep.footprint(
		car.global_position, car.get_heading(), car.car_length * 0.5, car.car_width * 0.5
	)


func _stop_footprint_clear(tm: TrafficManager, car: Car) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(car.car_length, 1.6, car.car_width)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = 1
	params.collide_with_areas = false
	params.transform = Transform3D(
		Basis(Vector3.UP, car.rotation.y), car.global_position + Vector3(0.0, 1.2, 0.0)
	)
	return tm.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()
