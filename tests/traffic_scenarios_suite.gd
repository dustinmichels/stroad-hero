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

var _smell_saw_cruise: bool = false
var _smell_saw_decision: bool = false
var _smell_saw_turn: bool = false
var _smell_saw_park: bool = false
var _smell_saw_reverse: bool = false
var _smell_saw_exit: bool = false
var _smell_saw_wait: bool = false
var _smell_saw_merge: bool = false
var _smell_saw_rejoin: bool = false
var _smell_dest: StringName = &"smell_gas"


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
				"--test-right-turn-following",
				"--test-drive-thru",
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

	if "--test-cramped-inn" in user_args or "--test-strip-mall" in user_args:
		_ci_site = &"strip_mall" if "--test-strip-mall" in user_args else &"cramped_inn"
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

	if "--test-smell-store" in user_args or "--test-smell-gas" in user_args:
		_smell_dest = &"smell_gas" if "--test-smell-gas" in user_args else &"smell_store"
		var traffic_mgr = main.get_node_or_null("TrafficManager") as TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		if traffic_mgr.lot != null:
			for spot in traffic_mgr.lot.spots:
				if spot.serves.has(_smell_dest) and not spot.is_free():
					for c in traffic_mgr.lot_cars.duplicate():
						if is_instance_valid(c) and c.spot == spot:
							traffic_mgr.lot_cars.erase(c)
							c.queue_free()
					traffic_mgr.lot.release(spot)
		var start_d: float = traffic_mgr.DECISION_D_SMELL - 14.0
		_test_car = traffic_mgr._spawn_car_at(lane0, start_d, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(_smell_dest, 1.0)
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


func on_physics_process(_delta: float) -> void:
	if "--test-merge-gap" in user_args:
		_test_frames += 1
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
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
					assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be updated")
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
				assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be tracked")
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

	if "--test-cramped-inn" in user_args or "--test-strip-mall" in user_args:
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
					var wait_point: Vector3 = ParkingLot.SOUTH_LOTS[_ci_site]["wait"]
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
		if _test_frames > 2400:
			assert(false, "Timeout waiting for %s test completion!" % _ci_site)

	if "--test-smell-store" in user_args or "--test-smell-gas" in user_args:
		var tag := String(_smell_dest).to_upper()
		_test_frames += 1
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and not _smell_saw_merge
			):
				if not _smell_saw_cruise:
					_smell_saw_cruise = true
					print(
						(
							"%s [1/8]: cruising west in lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _smell_saw_decision:
					_smell_saw_decision = true
					assert(_test_car.spot != null, "Must have reserved a spot")
					assert(
						_test_car.spot.serves.has(_smell_dest), "Spot must serve %s" % _smell_dest
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
				if not _smell_saw_turn:
					_smell_saw_turn = true
					assert(_test_car.merge_target_lane == 0, "merge_target_lane must be 0")
					print(
						(
							"%s [3/8]: turned into driveway (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _smell_saw_park:
					_smell_saw_park = true
					_test_car.dwell_left = minf(_test_car.dwell_left, 0.5)
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
				if not _smell_saw_reverse:
					_smell_saw_reverse = true
					print(
						"%s [5/8]: reversing out (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _smell_saw_exit:
					_smell_saw_exit = true
					print(
						"%s [6/8]: driving to exit (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _smell_saw_wait:
					_smell_saw_wait = true
					var wait_point: Vector3 = ParkingLot.SMELL_WAIT_POINT
					assert(
						_test_car.global_position.distance_to(wait_point) < 1.0,
						"Must be at the smell wait point"
					)
					print(
						(
							"%s [7/8]: waiting to merge (wait_point=%s, pos=%s)"
							% [tag, str(wait_point), str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.MERGING:
				if not _smell_saw_merge:
					_smell_saw_merge = true
					print(
						(
							"%s [8/8]: merging into lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and _smell_saw_merge
			):
				if not _smell_saw_rejoin:
					_smell_saw_rejoin = true
					assert(
						absf(_test_car.global_position.z - (-9.375)) < 0.5,
						"Car must be in Lane 0 (z=-9.375)"
					)
					print("%s: SUCCESS - full errand cycle complete!" % tag)
					main.get_tree().quit(0)
					return
		if _test_frames > 3600:
			assert(false, "Timeout waiting for %s test completion!" % _smell_dest)


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
	assert(car1.state == Car.State.DRIVE_THRU, "car1 must start in DRIVE_THRU state")
	assert(car1.merge_target_lane == 0, "car1 target lane must be 0")
	assert(car1.path == tm.taco_hell_drive_thru_path, "car1 must follow taco_hell_drive_thru_path")

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
	assert(bk1.state == Car.State.DRIVE_THRU, "bk1 must start in DRIVE_THRU state")
	assert(bk1.merge_target_lane == 3, "bk1 target lane must be 3 (Eastbound)")
	assert(
		bk1.path == tm.booger_king_drive_thru_path, "bk1 must follow booger_king_drive_thru_path"
	)

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

	var full_cap := 3000
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
