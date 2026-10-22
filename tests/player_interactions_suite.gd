class_name PlayerInteractionsSuite
extends TestSuite

var _test_frames: int = 0
var _test_car: Car = null
var _mats_start_frame: int = 0
var _mats_stage: int = 0
var _cart_test_stage: int = 0
var _cart_test_cart: ShoppingCart = null
var _cart_test_angles: Array[float] = [0.0, PI, PI / 2.0, -PI / 2.0]
var _cart_test_angle_idx: int = 0
var _cart_test_rolling: bool = false
var _col_test_stage: int = 0
var _col_test_lane: int = 0
var _col_test_initial_spd: int = 0
var _col_test_wait: int = 0
var _col_test_car: Car = null
var _col_test_start_side: Mats.StroadSide = Mats.StroadSide.SOUTH

const COL_LANE_CONFIGS: Array[Dictionary] = [
	{
		"lane_id": 0,
		"z": -9.375,
		"dir": -1.0,
		"car_x": 12.0,
		"mats_x": 0.0,
		"car_type": Car.CarType.SEDAN,
		"speed": 16.0,
		"mats_vz": 0.0
	},
	{
		"lane_id": 1,
		"z": -5.625,
		"dir": -1.0,
		"car_x": 20.0,
		"mats_x": 0.0,
		"car_type": Car.CarType.SPORTS,
		"speed": 26.5,
		"mats_vz": 0.0
	},
	{
		"lane_id": 5,
		"z": 1.875,
		"dir": 1.0,
		"car_x": -20.0,
		"mats_x": 0.0,
		"car_type": Car.CarType.SPORTS,
		"speed": 28.0,
		"mats_vz": 3.0
	},
	{
		"lane_id": 3,
		"z": 9.375,
		"dir": 1.0,
		"car_x": -12.0,
		"mats_x": 0.0,
		"car_type": Car.CarType.F150,
		"speed": 16.0,
		"mats_vz": 0.0
	},
]


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--test-mats-blocker",
				"--test-mats-cart",
				"--test-mats-collision",
				"--test-mats-sprint",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--test-mats-sprint" in user_args:
		_test_frames = 0
		_mats_stage = 0
		main.mats.global_position = Vector3(9.0, 0.5, -15.0)
		main.mats.velocity = Vector3.ZERO
	if "--test-mats-blocker" in user_args:
		var car_scene = load("res://cars/passenger_car.tscn")
		_test_car = car_scene.instantiate()
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.state = Car.State.WAITING_TO_MERGE
		main.add_child(_test_car)
		_test_car.global_position = Vector3(9.0, 0.0, -13.375)
		_test_car.rotation.y = -PI / 2.0  # facing +Z
		_test_car.reset_physics_interpolation()
		_test_car._update_blocker_layer()
		main.mats.global_position = Vector3(9.0, 0.5, -17.0)

	if "--test-mats-cart" in user_args:
		_cart_test_cart = (
			main.get_node_or_null("Props/WalgroinsShoppingCarts/Cart_Abandoned_WestApron")
			as ShoppingCart
		)
		assert(_cart_test_cart != null, "ShoppingCart not found in scene")
		# The cart sits on the Walgroins apron; keep lot and road traffic from hitting it.
		_clear_traffic()
		_cart_test_cart.global_position = Vector3(9.0, 0.0, -15.0)
		_cart_test_cart.global_basis = Basis()
		_cart_test_cart._current_speed = 0.0
		main.mats.blood_linger_delay = 0.02
		main.mats.fade_duration = 0.02
		main.mats.spd_emphasis_duration = 0.02
		main.mats.respawn_delay = 0.02
		_cart_test_stage = 0
		_test_frames = 0
		_cart_test_setup()

	if "--test-mats-collision" in user_args:
		main.mats.blood_linger_delay = 0.02
		main.mats.fade_duration = 0.02
		main.mats.spd_emphasis_duration = 0.02
		var hud_node: HUD = main.get_tree().get_first_node_in_group("hud") as HUD
		if hud_node:
			_col_test_initial_spd = hud_node.spd_count
		_clear_traffic()
		_col_test_stage = 0
		_test_frames = 0
		main.mats.global_position = Vector3(16.0, 0.10, 12.6)
		main.mats.velocity = Vector3(0.0, 0.0, 4.0)


func _clear_traffic() -> void:
	var tm := main.get_node_or_null("TrafficManager") as TrafficManager
	if tm == null:
		return
	for lane in tm.lanes:
		lane.spawn_timer = 999.0
		for c in lane.cars:
			if is_instance_valid(c):
				c.queue_free()
		lane.cars.clear()
	for c in tm.lot_cars:
		if is_instance_valid(c):
			if c.spot != null:
				tm.lot.release(c.spot)
			c.queue_free()
	tm.lot_cars.clear()


func on_physics_process(_delta: float) -> void:
	if "--test-mats-blocker" in user_args:
		_test_frames += 1
		if _mats_stage == 0:
			# Push Mats south along sidewalk into the car (from z=-17 toward z=-13.375)
			main.mats.velocity = Vector3(0.0, 0.0, 5.0)
			if _test_frames > 60:
				print(
					"MATS_TEST [1/2]: mats_pos=",
					main.mats.global_position,
					" mats_dead=",
					main.mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(not main.mats._is_dead, "Mats died on stopped car!")
				assert(
					main.mats.global_position.z < -14.5,
					"Mats walked through stopped car across sidewalk!"
				)
				assert(
					_test_car.blocker.collision_layer == 4,
					"Blocker must be on layer 3 when stopped!"
				)
				print(
					"MATS_TEST: Part 1 SUCCESS - Mats was blocked across the sidewalk without dying!"
				)
				_mats_stage = 1
				_mats_start_frame = _test_frames
				# Prepare Stage 2: place Mats on sidewalk apron in front of car in merge path
				main.mats.global_position = Vector3(9.0, 0.5, -11.0)
				main.mats.velocity = Vector3.ZERO
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
			if main.mats._is_dead:
				print(
					"MATS_TEST [2/2]: car_pos=",
					_test_car.global_position,
					" car_speed=",
					_test_car.speed,
					" mats_dead=",
					main.mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(_test_car.speed > 0.1, "Car must be moving when Mats dies!")
				assert(
					_test_car.blocker.collision_layer == 0, "Blocker must be disabled while moving!"
				)
				print(
					"MATS_TEST: Part 2 SUCCESS - Mats dies when hit by car pulling out into merge!"
				)
				print(
					"MATS_TEST: ALL CHECKS PASSED - Mats is stopped by car waiting across sidewalk, and dies if hit by car pulling out into merge!"
				)
				main.get_tree().quit(0)
			elif _test_frames - _mats_start_frame > 120:
				assert(false, "Timeout: Mats did not die when hit by car pulling out into merge!")

	if "--test-mats-cart" in user_args:
		_test_frames += 1
		var vis: Node3D = main.mats.get_node("Visual")
		if _cart_test_stage == 0 and _test_frames >= 24:
			assert(_cart_test_cart._rider == main.mats, "ShoppingCart rider must be set to mats")
			_cart_test_stage = 1
			_test_frames = 0
		elif _cart_test_stage == 1:
			if _test_frames >= 5:
				_cart_test_stage = 2
				_test_frames = 0
				main.mats.exit_cart(_cart_test_cart.get_node("ExitPosition"))
		elif _cart_test_stage == 2:
			if _test_frames >= 24:
				assert(
					main.mats.is_physics_processing(),
					"Physics processing must resume after exiting cart"
				)
				_cart_test_angle_idx += 1
				if _cart_test_angle_idx >= _cart_test_angles.size():
					if not _cart_test_rolling:
						_cart_test_rolling = true
						_cart_test_angle_idx = 0
						print("Stationary angle tests passed! Now testing rolling cart...")
					else:
						print(
							"Mount, sit, and exit verified across all angles and while rolling! Now testing death while riding..."
						)
						_cart_test_stage = 3
						_test_frames = 0
						_cart_test_angle_idx = 0
						_cart_test_rolling = true
						_cart_test_setup()
						return
				_cart_test_stage = 0
				_test_frames = 0
				_cart_test_setup()
		elif _cart_test_stage == 3:
			if _test_frames >= 24:
				assert(_cart_test_cart._rider == main.mats, "ShoppingCart rider must be set")
				_cart_test_stage = 4
				_test_frames = 0
				_cart_test_cart.die()
		elif _cart_test_stage == 4:
			if not main.mats.is_dead and _test_frames > 20:
				assert(
					main.mats.is_physics_processing(),
					"Physics processing must resume after respawning from cart death"
				)
				assert(main.mats._mounted_cart == null, "_mounted_cart must be cleared after death")
				assert(
					(
						main.mats.get_parent() != _cart_test_cart
						and main.mats.get_parent() != _cart_test_cart.get_node("Seat")
					),
					"Mats must be reparented out of cart after death"
				)
				assert(_cart_test_cart._rider == null, "Cart rider must be null after rider died")
				print("Stage 4 passed! Now testing pushing shopping cart (stages 5-8)...")
				_cart_test_stage = 5
				_test_frames = 0
				_cart_test_cart.global_position = Vector3(9.0, 0.1, -15.0)
				_cart_test_cart.global_basis = Basis()
				_cart_test_cart._current_speed = 0.0
				# Place Mats alongside cart (in interaction area, but not behind)
				main.mats.global_position = Vector3(10.0, 0.0, -15.0)
				main.mats.velocity = Vector3.ZERO
				vis.rotation = Vector3.ZERO
			elif _test_frames >= 300:
				assert(false, "Timeout waiting for respawn after dying in cart")
		elif _cart_test_stage == 5:
			if _test_frames == 2:
				assert(
					not _cart_test_cart.is_mats_behind(main.mats),
					"Mats must not be behind cart when at side"
				)
				_cart_test_cart._update_prompt()
				# Move Mats behind cart
				main.mats.global_position = Vector3(9.0, 0.0, -15.85)
				main.mats.velocity = Vector3.ZERO
				_cart_test_cart._update_prompt()
			elif _test_frames >= 5:
				assert(
					_cart_test_cart.is_mats_behind(main.mats), "Mats must be detected behind cart"
				)
				assert(main.hud.action_label.visible, "HUD action label must be visible")
				print("  Behind-cart detection and 'p to push' message verified!")
				# Press 'p' to start pushing
				var ev := InputEventKey.new()
				ev.keycode = KEY_P
				ev.pressed = true
				_cart_test_cart._unhandled_input(ev)
				assert(
					main.mats.is_pushing_cart, "Mats.is_pushing_cart must be true after pressing P"
				)
				assert(_cart_test_cart.is_being_pushed(), "Cart must be pushed after pressing P")
				assert(_cart_test_cart.get_pusher() == main.mats, "Cart pusher must be mats")
				print("  Start pushing verified!")
				_cart_test_stage = 6
				_test_frames = 0
		elif _cart_test_stage == 6:
			# Walk forward while pushing
			main.mats.velocity = Vector3(0.0, 0.0, 3.0)
			vis.rotation.y = 0.0
			if _test_frames >= 20:
				main.mats.velocity = Vector3.ZERO
				var expected_cart_z := main.mats.global_position.z + 0.85
				var actual_cart_z := _cart_test_cart.global_position.z
				assert(
					absf(actual_cart_z - expected_cart_z) < 0.1,
					(
						"Cart must follow Mats in front while walking: actual=%.3f expected=%.3f"
						% [actual_cart_z, expected_cart_z]
					)
				)
				print("  Cart following Mats while walking verified!")
				# Stage 7: Press Space to jump into cart while pushing
				var jump_ev := InputEventAction.new()
				jump_ev.action = "jump"
				jump_ev.pressed = true
				_cart_test_cart._unhandled_input(jump_ev)
				assert(not main.mats.is_pushing_cart, "Mats must stop pushing when jumping in")
				assert(
					_cart_test_cart.get_pusher() == null,
					"Cart pusher must be cleared when jumping in"
				)
				assert(_cart_test_cart._rider == main.mats, "Cart rider must be set to mats")
				_cart_test_stage = 7
				_test_frames = 0
		elif _cart_test_stage == 7:
			if _test_frames >= 25:
				assert(_cart_test_cart._rider == main.mats, "Mats must be riding in cart")
				print("  Jumping into cart while pushing verified!")
				# Exit cart
				main.mats.exit_cart(_cart_test_cart.get_node("ExitPosition"))
				_cart_test_stage = 8
				_test_frames = 0
		elif _cart_test_stage == 8:
			if _test_frames >= 25:
				assert(main.mats.is_physics_processing(), "Mats physics must resume after exit")
				# Position Mats behind cart again to test stop pushing with 'p'
				main.mats.global_position = (
					_cart_test_cart.global_position - Vector3(0.0, 0.0, 0.85)
				)
				_cart_test_cart._update_prompt()
				var p_ev := InputEventKey.new()
				p_ev.keycode = KEY_P
				p_ev.pressed = true
				_cart_test_cart._unhandled_input(p_ev)
				assert(main.mats.is_pushing_cart, "Must start pushing after pressing P")
				# Press P again to stop pushing
				_cart_test_cart._unhandled_input(p_ev)
				assert(not main.mats.is_pushing_cart, "Must stop pushing after pressing P again")
				assert(_cart_test_cart.get_pusher() == null, "Pusher must be null")
				print("  P to stop pushing toggle verified!")
				# Start pushing again to test death while pushing
				_cart_test_cart._unhandled_input(p_ev)
				assert(main.mats.is_pushing_cart, "Must start pushing before death test")
				_cart_test_stage = 9
				_test_frames = 0
		elif _cart_test_stage == 9:
			if _test_frames >= 5:
				assert(main.mats.is_pushing_cart, "Must be pushing cart")
				assert(_cart_test_cart.get_pusher() == main.mats, "Cart pusher must be mats")
				main.mats.die()
				assert(main.mats.is_dead, "Mats must be dead")
				assert(not main.mats.is_pushing_cart, "is_pushing_cart must be false after death")
				assert(_cart_test_cart.get_pusher() == null, "Cart pusher must be cleared on death")
				assert(not vis.visible, "Visual rig must be hidden on death")
				_cart_test_stage = 10
				_test_frames = 0
		elif _cart_test_stage == 10:
			if not main.mats.is_dead and _test_frames > 20:
				assert(
					main.mats.is_physics_processing(),
					"Physics processing must resume after respawn"
				)
				assert(not main.mats.is_pushing_cart, "is_pushing_cart must stay false on respawn")
				assert(
					_cart_test_cart.get_pusher() == null, "Cart pusher must stay null on respawn"
				)
				assert(vis.visible, "Visual rig must be visible after respawn")
				print("  Death and respawn while pushing verified!")
				print(
					"CART_TEST completed: mount, sit, exit, death, behind-detection, p-to-push, walk-pushing, space-jump-in, stop-pushing, and death-while-pushing verified!"
				)
				main.get_tree().quit(0)
				return
		elif _test_frames >= 120:
			assert(false, "Timeout in CART_TEST")

	if "--test-mats-sprint" in user_args:
		_test_frames += 1
		if _mats_stage == 0:
			assert(
				main.mats.stamina == main.mats.max_stamina, "Initial stamina must equal max_stamina"
			)
			assert(not main.mats.is_sprinting, "Must not be sprinting initially")
			assert(not main.mats.is_exhausted, "Must not be exhausted initially")
			Input.action_press("move_right")
			_mats_stage = 1
			_test_frames = 0
		elif _mats_stage == 1:
			if _test_frames >= 20:
				assert(not main.mats.is_sprinting, "Must not sprint without sprint input")
				assert(
					main.mats.stamina == main.mats.max_stamina,
					"Stamina must remain full while walking"
				)
				var h_speed := Vector2(main.mats.velocity.x, main.mats.velocity.z).length()
				assert(
					h_speed > 4.5 and h_speed <= main.mats.walk_speed + 0.1,
					"Speed should reach walk_speed"
				)
				Input.action_press("sprint")
				_mats_stage = 2
				_test_frames = 0
		elif _mats_stage == 2:
			if _test_frames >= 20:
				assert(main.mats.is_sprinting, "Must be sprinting when holding sprint")
				var sprint_spd := Vector2(main.mats.velocity.x, main.mats.velocity.z).length()
				assert(
					sprint_spd > main.mats.walk_speed + 1.0, "Sprint speed must exceed walk speed"
				)
				assert(
					main.mats.stamina < main.mats.max_stamina, "Stamina must drain while sprinting"
				)
				# Set stamina near empty to test depletion
				main.mats.stamina = 0.1
				_mats_stage = 3
				_test_frames = 0
		elif _mats_stage == 3:
			if _test_frames >= 10:
				assert(main.mats.stamina == 0.0, "Stamina must reach 0")
				assert(main.mats.is_exhausted, "Must enter exhausted state")
				assert(not main.mats.is_sprinting, "Must stop sprinting when stamina runs out")
				_mats_stage = 4
				_test_frames = 0
		elif _mats_stage == 4:
			if _test_frames >= 20:
				var exhausted_spd := Vector2(main.mats.velocity.x, main.mats.velocity.z).length()
				assert(
					exhausted_spd <= main.mats.walk_speed + 0.2,
					"Speed must drop to walk speed when exhausted"
				)
				assert(not main.mats.is_sprinting, "Must not sprint while exhausted")
				Input.action_release("sprint")
				_mats_stage = 5
				_test_frames = 0
		elif _mats_stage == 5:
			if _test_frames >= 45:
				assert(main.mats.stamina > 0.0, "Stamina must begin recovering after delay")
				main.mats.stamina = 50.0
				main.mats._physics_process(0.016)
				assert(
					not main.mats.is_exhausted,
					"Exhaustion must clear once recovered above threshold"
				)
				Input.action_release("move_right")
				Input.action_release("sprint")
				print(
					"SPRINT_TEST: ALL CHECKS PASSED - sprint, stamina drain, exhaustion, and recovery verified!"
				)
				main.get_tree().quit(0)
				return
	if "--test-mats-collision" in user_args:
		_test_frames += 1
		var tick_scale: float = Engine.physics_ticks_per_second / 60.0
		var f_40: int = maxi(1, int(round(40.0 * tick_scale)))
		var f_50: int = maxi(1, int(round(50.0 * tick_scale)))
		var f_120: int = maxi(1, int(round(120.0 * tick_scale)))
		if _col_test_stage == 0:
			main.mats.velocity = Vector3(0.0, 0.0, 4.0)
			if _test_frames >= f_40:
				assert(
					absf(main.mats.global_position.y - 0.245) < 0.05,
					"Mats should be on sidewalk (y ~ 0.245), got %f" % main.mats.global_position.y
				)
				print(
					"COLLISION_TEST [1/5]: Curb step-up (0.195m height with step_height=0.3) verified!"
				)
				_col_test_stage = 1
				_test_frames = 0
		elif _col_test_stage == 1:
			main.mats.velocity = Vector3(0.0, 0.0, -4.0)
			if _test_frames >= f_50:
				assert(
					main.mats.global_position.z < 12.9,
					"Mats should step off sidewalk back onto road"
				)
				assert(
					absf(main.mats.global_position.y - 0.10) < 0.05,
					"Mats should settle on road (y ~ 0.10), got %f" % main.mats.global_position.y
				)
				print("COLLISION_TEST [2/5]: Curb step-down and floor snap verified!")
				_col_test_stage = 2
				_test_frames = 0
				main.mats.global_position = Vector3(136.0, 0.245, 13.5)
				main.mats.velocity = Vector3(0.0, 0.0, -4.0)
		elif _col_test_stage == 2:
			main.mats.velocity = Vector3(0.0, 0.0, -4.0)
			if _test_frames >= f_40:
				var post_pos := Vector3(136.0, 0.245, 12.125)
				var dist := main.mats.global_position.distance_to(post_pos)
				assert(dist >= 0.45, "Mats must not penetrate sign post cylinder: dist=%f" % dist)
				assert(main.mats.global_position.z > 12.4, "Mats must be stopped by sign post!")
				print(
					(
						"COLLISION_TEST [3/5]: Sign post cylinder collision verified (blocked at dist=%.2f)!"
						% dist
					)
				)
				_col_test_stage = 3
				_test_frames = 0
				var bk_site := main.get_node("Props/BoogerKingSite")
				var bk_doors := bk_site.get_node("Building/Building/Tower/Doors")
				main.mats.global_position = bk_doors.global_position + Vector3(0.0, 0.0, -1.2)
				main.mats.velocity = Vector3(0.0, 0.0, 3.0)
		elif _col_test_stage == 3:
			main.mats.velocity = Vector3(0.0, 0.0, 3.0)
			assert(not main.mats.is_on_ceiling(), "Mats 1.5m capsule must not hit canopy ceiling!")
			var bk_site := main.get_node("Props/BoogerKingSite")
			var bk_doors := bk_site.get_node("Building/Building/Tower/Doors")
			var dist := main.mats.global_position.distance_to(bk_doors.global_position)
			if dist < 0.6:
				_col_test_stage = 4
				_test_frames = 0
				var taco := main.get_node("Props/TacoHell")
				var taco_doors := taco.get_node("Building/MainArchPortico/Doors")
				main.mats.global_position = taco_doors.global_position + Vector3(0.0, 0.0, 1.2)
				main.mats.velocity = Vector3(0.0, 0.0, -3.0)
			elif _test_frames > f_120:
				assert(
					false, "Timeout: Mats must reach BK door threshold unobstructed: dist=%f" % dist
				)
		elif _col_test_stage == 4:
			main.mats.velocity = Vector3(0.0, 0.0, -3.0)
			assert(not main.mats.is_on_ceiling(), "Mats 1.5m capsule must not hit arch header!")
			var taco := main.get_node("Props/TacoHell")
			var taco_doors := taco.get_node("Building/MainArchPortico/Doors")
			var dist := main.mats.global_position.distance_to(taco_doors.global_position)
			if dist < 0.6:
				print(
					"COLLISION_TEST [4/5]: Building doorways and overhead canopies clearance verified!"
				)
				_col_test_stage = 5
				_setup_col_near_miss_test()
			elif _test_frames > f_120:
				assert(
					false,
					"Timeout: Mats must reach Taco Hell door threshold unobstructed: dist=%f" % dist
				)
		elif _col_test_stage == 5:
			if is_instance_valid(_col_test_car):
				_col_test_car.advance_simulation(_delta)
				assert(
					not main.mats.is_dead,
					"Near miss must not kill Mats! 0.25m capsule radius accurately avoids phantom hits."
				)
				if _col_test_car.global_position.x < -8.0:
					print(
						"  Near miss verified! Car brushed within 0.27m of Mats center without phantom hit."
					)
					_col_test_car.queue_free()
					_col_test_stage = 6
					_col_test_lane = 0
					_setup_col_lane_test(0)
			elif _test_frames > f_120:
				assert(false, "Timeout waiting for near miss car")
		elif _col_test_stage == 6:
			if is_instance_valid(_col_test_car):
				_col_test_car.advance_simulation(_delta)
			var cfg: Dictionary = COL_LANE_CONFIGS[_col_test_lane]
			var mats_vz: float = cfg.get("mats_vz", 0.0)
			if mats_vz != 0.0 and not main.mats.is_dead:
				main.mats.velocity = Vector3(0.0, 0.0, mats_vz)
			if _col_test_wait == 0:
				if main.mats.is_dead:
					_col_test_wait = 1
				elif _test_frames > f_120:
					assert(false, "Timeout waiting for car hit in lane %d" % _col_test_lane)
			elif _col_test_wait == 1:
				if not main.mats.is_dead:
					var hud_node: HUD = main.get_tree().get_first_node_in_group("hud") as HUD
					var expected_spd = _col_test_initial_spd + _col_test_lane + 1
					assert(
						hud_node != null and hud_node.spd_count == expected_spd,
						(
							"SPD counter must increment on car hit death! expected %d, got %d"
							% [expected_spd, hud_node.spd_count if hud_node else -1]
						)
					)
					var expected_side_z := (
						-13.85 if _col_test_start_side == Mats.StroadSide.NORTH else 13.85
					)
					assert(
						absf(main.mats.global_position.z - expected_side_z) < 0.15,
						(
							"Mats must respawn on starting side of road: expected z=%.2f, got %.2f"
							% [expected_side_z, main.mats.global_position.z]
						)
					)
					assert(
						absf(main.mats.global_position.x - cfg["mats_x"]) < 0.5,
						(
							"Mats must respawn at death x coordinate: expected x=%.2f, got %.2f"
							% [cfg["mats_x"], main.mats.global_position.x]
						)
					)
					print(
						(
							"  Lane %d hit verified! Mats died and SPD counter incremented to %d (respawned at side z=%.2f)"
							% [_col_test_lane, hud_node.spd_count, main.mats.global_position.z]
						)
					)
					if is_instance_valid(_col_test_car):
						_col_test_car.queue_free()
					_col_test_lane += 1
					if _col_test_lane >= COL_LANE_CONFIGS.size():
						print(
							(
								"COLLISION_TEST [5/5]: Near miss clearance and car hits in all 4 lanes verified (SPD = %d)!"
								% hud_node.spd_count
							)
						)
						print(
							"MATS_COLLISION_TEST: SUCCESS - All collision, curb, sign post, doorway, and car hit tests passed!"
						)
						main.get_tree().quit(0)
						return
					else:
						_setup_col_lane_test(_col_test_lane)


func _cart_test_setup() -> void:
	var facing: float = _cart_test_angles[_cart_test_angle_idx]
	_cart_test_cart.global_position = Vector3(9.0, 0.0, -15.0)
	_cart_test_cart.global_basis = Basis()
	if _cart_test_rolling:
		_cart_test_cart.roll_from(Vector3(0.0, 0.0, 1.0))
	else:
		_cart_test_cart._current_speed = 0.0
	main.mats.global_position = _cart_test_cart.global_position + Vector3(0.5, 0.0, 0.5)
	var vis: Node3D = main.mats.get_node("Visual")
	vis.rotation = Vector3(0.0, facing, 0.0)
	main.mats.enter_cart(_cart_test_cart, _cart_test_cart.get_node("Seat"))


func _setup_col_near_miss_test() -> void:
	_test_frames = 0
	_col_test_wait = 0
	var lane_id := 0
	var lane_z := -9.375
	var lane_dir := -1.0
	var car_x := 12.0
	main.mats.global_position = Vector3(0.0, 0.10, -8.155)
	main.mats.velocity = Vector3.ZERO

	var car_scene = load("res://cars/passenger_car.tscn")
	_col_test_car = car_scene.instantiate()
	_col_test_car.car_type = Car.CarType.SEDAN
	main.add_child(_col_test_car)
	_col_test_car.setup(lane_id, lane_z, lane_dir, car_x, 60.0, 16.0, Car.CarType.SEDAN)
	_col_test_car.speed = 16.0
	_col_test_car.desired_speed = 16.0
	_col_test_car._update_blocker_layer()


func _setup_col_lane_test(idx: int) -> void:
	_test_frames = 0
	_col_test_wait = 0
	_col_test_start_side = main.mats.current_side
	var cfg: Dictionary = COL_LANE_CONFIGS[idx]
	var lane_id: int = cfg["lane_id"]
	var lane_z: float = cfg["z"]
	var lane_dir: float = cfg["dir"]
	var car_x: float = cfg["car_x"]
	var mats_x: float = cfg["mats_x"]
	var car_type: Car.CarType = cfg.get("car_type", Car.CarType.SEDAN)
	var speed: float = cfg.get("speed", 16.0)
	var mats_vz: float = cfg.get("mats_vz", 0.0)

	main.mats.global_position = Vector3(mats_x, 0.10, lane_z - (0.5 if mats_vz != 0.0 else 0.0))
	main.mats.velocity = Vector3(0.0, 0.0, mats_vz)

	var car_scene = load("res://cars/passenger_car.tscn")
	_col_test_car = car_scene.instantiate()
	_col_test_car.car_type = car_type
	main.add_child(_col_test_car)
	_col_test_car.setup(lane_id, lane_z, lane_dir, car_x, 60.0, speed, car_type)
	_col_test_car.speed = speed
	_col_test_car.desired_speed = speed
	_col_test_car._update_blocker_layer()
