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
var _mats_testing: bool = false
var _mats_start_frame: int = 0
func _ready() -> void:
	if mats:
		mats.died.connect(_on_player_died)
	if "--test-mats-blocker" in OS.get_cmdline_user_args():
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
func _physics_process(_delta: float) -> void:
	if "--test-mats-blocker" in OS.get_cmdline_user_args():
		_test_frames += 1
		# Push Mats south along sidewalk into the car (from z=-13 toward z=-9.6)
		mats.velocity = Vector3(0.0, 0.0, 5.0)
		if _test_frames > 60:
			print(
				"MATS_TEST: mats_pos=",
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
			print("MATS_TEST: SUCCESS - Mats was blocked across the sidewalk!")
			get_tree().quit(0)

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
				if _test_follower == null:
					var lane0 = tm.lanes[0]
					var to_remove: Array[Car] = []
					for c in lane0.cars:
						if is_instance_valid(c) and c != _test_car and c.lane_distance > 25.0 and c.lane_distance < 65.0:
							to_remove.append(c)
					for c in to_remove:
						lane0.cars.erase(c)
						c.queue_free()
					_test_follower = tm._spawn_car_at(lane0, 48.0)
					_test_follower.speed = 13.0
					_test_follower.desired_speed = 13.0
					_test_follower.errand = null
					_test_follower.had_errand = false
			elif _test_car.state == Car.State.MERGING:
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

func _on_player_died(pos: Vector3) -> void:
	if hud and hud.has_method("increment_spd"):
		hud.increment_spd()
	if blood_splats and mats:
		BloodSplatScript.spawn(pos, blood_splats, [mats.get_rid()])
