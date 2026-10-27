class_name ObjectivesUiSuite
extends TestSuite


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--test-day-weather",
				"--test-world-bounds",
				"--test-objective-manager",
				"--test-objectives",
				"--test-start-screen",
				"--test-startup",
				"--test-character-editor",
				"--test-retro-filter",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--test-day-weather" in user_args:
		_run_test_day_weather()
		return
	if "--test-world-bounds" in user_args:
		_run_test_world_bounds()
		return
	if "--test-objective-manager" in user_args:
		_run_test_objective_manager()
		return
	if "--test-objectives" in user_args:
		_run_test_objectives()
		return
	if "--test-start-screen" in user_args:
		_run_test_start_screen()
		return
	if "--test-startup" in user_args:
		_run_test_startup()
		return
	if "--test-character-editor" in user_args:
		_run_test_character_editor()
		return
	if "--test-retro-filter" in user_args:
		_run_test_retro_filter()
		return


func _run_test_day_weather() -> void:
	await main.get_tree().process_frame
	GameState.set_time_hours(15.5)
	assert(GameState.are_lights_on() == false, "Lights should be off at 3:30 PM")
	var streetlights: Node3D = main.get_node_or_null("Props/Streetlights")
	var lamp0: Node3D = streetlights.get_child(0) as Node3D
	var spot0: SpotLight3D = lamp0.get_node_or_null("Light") as SpotLight3D
	var lamp_mesh0: MeshInstance3D = lamp0.get_node_or_null("Lamp") as MeshInstance3D
	assert(spot0 != null and not spot0.visible, "Streetlight SpotLight3D must be off at 3:30 PM")
	if lamp_mesh0:
		assert(
			lamp_mesh0.material_override == null,
			"Streetlight luminaire material override must be null at 3:30 PM"
		)
	GameState.set_time_hours(GameState.DUSK_HOUR - 0.05)
	assert(not GameState.are_lights_on(), "Lights should stay off until dusk")
	GameState.set_time_hours(GameState.DUSK_HOUR)
	assert(GameState.are_lights_on() == true, "Lights should be on at dusk")
	assert(spot0 != null and spot0.visible, "Streetlight SpotLight3D must be on at dusk")
	if lamp_mesh0:
		var mat: StandardMaterial3D = lamp_mesh0.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled,
			"Streetlight luminaire material must be emissive at dusk"
		)
	# Day end: clock stops at 8:00 PM, summary pauses, button starts the next day
	var tm: TrafficManager = main.traffic_manager
	if not tm.is_initial_traffic_ready:
		await tm.initial_traffic_ready
	var day1_cars: Array[Car] = tm.lot_cars.duplicate()
	for lane in tm.lanes:
		day1_cars.append_array(lane.cars)
	assert(not day1_cars.is_empty(), "Day 1 must have traffic")
	var spawn_pos: Vector3 = main.mats._spawn_transform.origin
	main.mats.global_position = spawn_pos + Vector3(20.0, 0.0, -25.0)
	var cart := main.get_tree().get_first_node_in_group(&"shopping_carts") as ShoppingCart
	var cart_spawn: Vector3 = cart.global_position
	cart.global_position = cart_spawn + Vector3(5.0, 0.0, 0.0)
	# Die just before the day ends so the new day resets Mats while the screen is fading to black.
	main.mats.die()
	await main.get_tree().create_timer(main.mats.blood_linger_delay + 0.2).timeout
	GameState.current_day = 1
	GameState.set_time_hours(19.9)
	GameState.advance_time(0.2)
	assert(GameState.day_over, "Reaching 8:00 PM should end the day")
	assert(is_equal_approx(GameState.current_time_hours, 20.0), "Clock must stop at 8:00 PM")
	GameState.advance_time(0.5)
	assert(is_equal_approx(GameState.current_time_hours, 20.0), "Ended day must not advance")
	var summary: DaySummary = main.hud.day_summary
	assert(summary.visible, "Day summary must show when the day ends")
	assert(main.get_tree().paused, "Day summary must pause the game")
	summary.next_day_button.pressed.emit()
	assert(not summary.visible, "Day summary must hide after starting the next day")
	assert(not main.get_tree().paused, "Starting the next day must unpause")
	assert(GameState.current_day == 2, "Next day button should advance to day 2")
	assert(not GameState.day_over, "New day must not be over")
	assert(
		is_equal_approx(GameState.current_time_hours, GameState.START_HOUR),
		"New day should start at the day start hour"
	)
	assert(
		spot0 != null and not spot0.visible,
		"Streetlight SpotLight3D must turn off when the next day starts"
	)
	if lamp_mesh0:
		assert(
			lamp_mesh0.material_override == null,
			"Streetlight luminaire material override must clear when the next day starts"
		)
	assert(
		main.mats.global_position.is_equal_approx(spawn_pos),
		"New day must put Mats back at his spawn point"
	)
	assert(not main.mats.is_dead, "New day must revive Mats")
	assert(
		cart.global_position.is_equal_approx(cart_spawn),
		"New day must put shopping carts back at their spawn points"
	)
	await main.get_tree().physics_frame
	assert(main.blood_splats.get_child_count() == 0, "New day must clear blood splats")
	for car in day1_cars:
		assert(
			not is_instance_valid(car) or not car.is_inside_tree(),
			"New day must remove the previous day's cars"
		)
	var lane_cars := 0
	for lane in tm.lanes:
		lane_cars += lane.cars.size()
	assert(lane_cars > 0, "New day must repopulate the stroad")
	assert(not tm.lot_cars.is_empty(), "New day must reseed parked cars")
	assert(tm.lot.check_invariants() == 0, "New day must leave no leaked lot reservations")
	# Let the interrupted death sequence finish: it must not move Mats or leave the screen black.
	await main.get_tree().create_timer(4.0).timeout
	assert(
		main.mats.global_position.distance_to(spawn_pos) < 0.5,
		"A stale death sequence must not respawn Mats after the new day reset"
	)
	assert(not main.mats.is_dead, "Mats must stay alive after the stale death sequence ends")
	assert(is_zero_approx(main.hud.fade_overlay.color.a), "Screen must fade back in on the new day")
	print("DAY_WEATHER_TEST: SUCCESS - --test-day-weather passed cleanly!")
	main.get_tree().quit(0)


func _assert_mats_blocked(start: Vector3, vel: Vector3, passes: Callable, msg: String) -> void:
	main.mats.global_position = start
	for _step in range(30):
		main.mats.velocity = vel
		main.mats._physics_process(1.0 / 60.0)
	assert(passes.call(main.mats.global_position), msg)


func _run_test_world_bounds() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	_assert_mats_blocked(
		Vector3(25.0, 0.3, -59.0),
		Vector3(0.0, 0.0, -10.0),
		func(p: Vector3) -> bool: return p.z > -60.0,
		"North forest fence must block Mats from entering forest"
	)
	_assert_mats_blocked(
		Vector3(25.0, 0.3, 63.0),
		Vector3(0.0, 0.0, 10.0),
		func(p: Vector3) -> bool: return p.z < 64.0,
		"South forest fence must block Mats from entering forest"
	)
	_assert_mats_blocked(
		Vector3(-98.0, 0.3, 0.0),
		Vector3(-10.0, 0.0, 0.0),
		func(p: Vector3) -> bool: return p.x > -100.5,
		"Tunnel blocker must prevent Mats from entering West tunnel on roadway"
	)
	_assert_mats_blocked(
		Vector3(-98.0, 0.3, 14.0),
		Vector3(-10.0, 0.0, 0.0),
		func(p: Vector3) -> bool: return p.x > -100.5,
		"Chain link fence must block Mats on West tunnel South sidewalk"
	)
	_assert_mats_blocked(
		Vector3(148.0, 0.3, 0.0),
		Vector3(10.0, 0.0, 0.0),
		func(p: Vector3) -> bool: return p.x < 150.5,
		"Tunnel blocker must prevent Mats from entering East tunnel on roadway"
	)
	_assert_mats_blocked(
		Vector3(148.0, 0.3, -14.0),
		Vector3(10.0, 0.0, 0.0),
		func(p: Vector3) -> bool: return p.x < 150.5,
		"Chain link fence must block Mats on East tunnel North sidewalk"
	)
	_assert_mats_blocked(
		Vector3(4.0, 0.245, -13.85),
		Vector3(10.0, 0.0, 0.0),
		func(p: Vector3) -> bool: return p.x < 5.8,
		"Power pole in the middle of the sidewalk must block Mats"
	)
	print("WORLD_BOUNDS_TEST: SUCCESS - --test-world-bounds passed cleanly!")
	main.get_tree().quit(0)


func _run_test_objective_manager() -> void:
	var obj_mgr: ObjectiveManager = main.get_node_or_null("ObjectiveManager") as ObjectiveManager
	assert(obj_mgr != null, "ObjectiveManager must exist")
	obj_mgr._setup()
	obj_mgr.start_call()
	assert(
		obj_mgr.current_state == ObjectiveManager.State.RINGING,
		"Must ring immediately in test mode"
	)
	assert(obj_mgr.current_errand != null, "First errand must be set")
	# 2. First errand is picked with randomness and targets opposite side (North)
	assert(obj_mgr.completed_count == 0)
	var target_pos = obj_mgr.get_target_position(obj_mgr.current_errand)
	assert(target_pos.z < 0.0, "First errand target z must be North (negative z)")
	assert(obj_mgr.current_errand.location_id in [&"walgroins", &"smell", &"taco_hell"])
	# 3. _pick_next() tests:
	# Case A: Mats at North (z = -30.0), last_completed = cough_syrup -> opposite side candidate is Booger King (hamburgers)
	main.mats.global_position = Vector3(0.0, 0.0, -30.0)
	obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
	var next_errand = obj_mgr._pick_next()
	assert(
		next_errand.id == &"hamburgers",
		"Must pick hamburgers when Mats is North and last was cough_syrup"
	)

	# Case B: Mats at South (z = 30.0), last_completed = hamburgers -> opposite side candidates are North errands (Walgroins, Smell, Taco Hell)
	main.mats.global_position = Vector3(0.0, 0.0, 30.0)
	obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"hamburgers")
	var north_locs_seen: Dictionary = {}
	for _i in range(30):
		var picked = obj_mgr._pick_next()
		var picked_target = obj_mgr.get_target_position(picked)
		assert(picked_target.z < 0.0, "Must pick North errand when Mats is at South")
		assert(picked.id != &"hamburgers", "Must exclude last completed errand")
		assert(picked.location_id in [&"walgroins", &"smell", &"taco_hell"])
		north_locs_seen[picked.location_id] = true
	assert(north_locs_seen.size() >= 2, "Should pick from multiple North locations across trials")

	# Case C: Mats at South (z = 30.0), last_completed = cough_syrup -> opposite side candidates prefer other locations
	main.mats.global_position = Vector3(0.0, 0.0, 30.0)
	obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
	next_errand = obj_mgr._pick_next()
	assert(next_errand.id != &"cough_syrup", "Must exclude last completed errand")
	assert(
		obj_mgr.get_target_position(next_errand).z < 0.0,
		"Must pick North errand when Mats is at South"
	)
	assert(
		next_errand.location_id in [&"smell", &"taco_hell"],
		"Must prefer different North location when cough_syrup was last completed"
	)

	# Case D: Fallback when no candidates remain on opposite side:
	# Mats at North (z = -30.0), last_completed = hamburgers. Opposite candidate is hamburgers, which is excluded.
	main.mats.global_position = Vector3(0.0, 0.0, -30.0)
	obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"hamburgers")
	next_errand = obj_mgr._pick_next()
	assert(next_errand.id != &"hamburgers", "Fallback must exclude last completed errand")
	assert(
		obj_mgr.get_target_position(next_errand).z < 0.0,
		"Fallback must pick errand from available side"
	)

	# Verify non-dinner errands never receive cooking/dinner excuses
	var non_dinner_items = [
		{"item": "cough syrup", "store": "Walgroins", "loc_id": &"walgroins"},
		{"item": "band-aids", "store": "Walgroins", "loc_id": &"walgroins"},
		{"item": "toothpaste", "store": "Walgroins", "loc_id": &"walgroins"},
		{"item": "batteries", "store": "Walgroins", "loc_id": &"walgroins"},
		{"item": "potato chips", "store": "Walgroins", "loc_id": &"walgroins"},
		{"item": "milk", "store": "Smell", "loc_id": &"smell"},
		{"item": "cereal", "store": "Smell", "loc_id": &"smell"},
		{"item": "chewing gum", "store": "Smell", "loc_id": &"smell"},
		{"item": "beef jerky", "store": "Smell", "loc_id": &"smell"},
	]
	var d_parts: Dictionary = obj_mgr.objectives_data.get("dialogue_parts", {})
	for entry in non_dinner_items:
		var cand_excuses = ObjectiveManager.get_excuses_for_errand(
			d_parts, entry["item"], entry["store"], entry["loc_id"]
		)
		for exc in cand_excuses:
			assert(
				not ObjectiveManager.is_dinner_excuse(exc),
				"Non-dinner errand '%s' must not have dinner excuse: '%s'" % [entry["item"], exc]
			)
		# Sample multiple generated lines to ensure randomized selections never leak cooking excuses
		for _iter in range(25):
			var res = ObjectiveManager.generate_dialogue(
				entry["item"], entry["store"], entry["store"], d_parts, false, entry["loc_id"]
			)
			assert(
				not ObjectiveManager.is_dinner_excuse(res["excuse"]),
				"Generated excuse for '%s' must not be a dinner excuse" % entry["item"]
			)
			assert(
				not res["call_line"].to_lower().contains("cooking dinner"),
				"Call line for '%s' must not contain 'cooking dinner'" % entry["item"]
			)

	# Verify dinner errands include cooking excuses
	var bk_excuses = ObjectiveManager.get_excuses_for_errand(
		d_parts, "hamburgers", "Booger King", &"booger_king"
	)
	assert(
		bk_excuses.has("I don't feel like cooking dinner tonight."),
		"Booger King excuses must include 'I don't feel like cooking dinner tonight.'"
	)

	print("OBJECTIVE_MANAGER_TEST: SUCCESS - All ObjectiveManager test cases passed!")
	main.get_tree().quit(0)


func _run_test_objectives() -> void:
	await main.get_tree().process_frame
	var obj_mgr: ObjectiveManager = main.get_node_or_null("ObjectiveManager") as ObjectiveManager
	assert(obj_mgr != null, "ObjectiveManager must exist")
	assert(main.hud != null, "HUD must exist")

	if obj_mgr.current_state != ObjectiveManager.State.RINGING:
		obj_mgr.start_call()
	# 1. The first call is cough_syrup, and its target is on the north side (z < 0).
	assert(obj_mgr.current_state == ObjectiveManager.State.RINGING, "First call must be ringing")
	assert(obj_mgr.current_errand != null, "Current errand must be set")
	assert(
		obj_mgr.current_errand.location_id in [&"walgroins", &"smell", &"taco_hell"],
		"First errand must target North"
	)
	var target_pos := obj_mgr.get_target_position(obj_mgr.current_errand)
	assert(target_pos.z < 0.0, "First errand target must be on the north side (z < 0)")

	# 2. Answer programmatically, teleport Mats to the target, and assert completed_count == 1 and the HUD objective count is 1.
	var phone_call = main.hud.phone_call
	if phone_call and phone_call.is_ringing:
		phone_call.answer()
		phone_call.dismiss()
	else:
		obj_mgr.answer_call()
		obj_mgr.dismiss_call()
	assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE, "Must be ACTIVE after call")

	main.mats.global_position = target_pos
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	assert(obj_mgr.completed_count == 1, "completed_count must be 1 after reaching target")

	# 3. Verify phone visibility hides cleanly on death and restores on respawn
	obj_mgr.start_call()
	assert(main.mats.is_phone_ringing, "Mats must be in ringing phone mode")
	assert(
		main.mats.phone != null and main.mats.phone.visible, "Phone must be visible while ringing"
	)

	# Fast-forward death delays for testing
	main.mats.blood_linger_delay = 0.01
	main.mats.fade_duration = 0.01
	main.mats.spd_emphasis_duration = 0.01
	main.mats.respawn_delay = 0.01

	main.mats.die()
	assert(main.mats.is_dead, "Mats must be dead")
	assert(
		not main.mats.is_on_phone and not main.mats.is_phone_ringing,
		"Phone mode must clear on death"
	)
	assert(
		main.mats.phone != null and not main.mats.phone.visible,
		"Phone mesh must hide cleanly on death"
	)
	assert(not main.mats.get_node("Visual").visible, "Visual rig must hide on death")

	# Wait for respawn
	await main.mats.respawned
	assert(main.mats.get_node("Visual").visible, "Visual rig must be visible after respawn")
	assert(main.mats.is_phone_ringing, "Ringing phone state must restore on respawn")
	assert(
		main.mats.phone != null and main.mats.phone.visible,
		"Phone visibility must restore on respawn"
	)

	# Verify stroad side tracking, starting-side respawn on stroad death, and offroad respawn
	assert(
		main.mats.current_side == Mats.StroadSide.NORTH,
		"Mats must be on North side after respawning on north roadside"
	)

	# Crossing death: if trying to cross from South, dying on North half of road (z = -8.0) respawns on starting side (South)
	var south_start_death := main.mats.get_respawn_position(
		Vector3(30.0, 0.0, -8.0), Mats.StroadSide.SOUTH
	)
	assert(
		absf(south_start_death.z - 13.85) < 0.01 and absf(south_start_death.x - 30.0) < 0.01,
		"Death on stroad when crossing from South must respawn on South roadside"
	)

	# Crossing death: if trying to cross from North, dying on South half of road (z = 5.0) respawns on starting side (North)
	var north_start_death := main.mats.get_respawn_position(
		Vector3(-10.0, 0.0, 5.0), Mats.StroadSide.NORTH
	)
	assert(
		absf(north_start_death.z - (-13.85)) < 0.01 and absf(north_start_death.x - (-10.0)) < 0.01,
		"Death on stroad when crossing from North must respawn on North roadside"
	)

	# Offroad roadside deaths (not on the stroad):
	var south_offroad := main.mats.get_respawn_position(Vector3(30.0, 0.0, 20.0))
	assert(
		absf(south_offroad.z - 13.85) < 0.01, "South roadside death must respawn on South roadside"
	)
	var north_offroad := main.mats.get_respawn_position(Vector3(-10.0, 0.0, -20.0))
	assert(
		absf(north_offroad.z - (-13.85)) < 0.01,
		"North roadside death must respawn on North roadside"
	)

	var clamped_west := main.mats.get_respawn_position(Vector3(-120.0, 0.0, 20.0))
	assert(
		absf(clamped_west.x - Mats.MIN_RESPAWN_X) < 0.01,
		"Extreme west x must clamp to MIN_RESPAWN_X"
	)
	var clamped_east := main.mats.get_respawn_position(Vector3(160.0, 0.0, -20.0))
	assert(
		absf(clamped_east.x - Mats.MAX_RESPAWN_X) < 0.01,
		"Extreme east x must clamp to MAX_RESPAWN_X"
	)

	# Verify crossing detection and crossing count increment
	assert(main.mats.crossings_count == 0, "Initial crossings count must be 0")
	# Enter stroad from North side
	main.mats.global_position = Vector3(0.0, 0.3, -5.0)
	main.mats.update_stroad_side()
	assert(main.mats.is_crossing, "Mats must be in crossing state while on stroad")
	assert(
		main.mats.crossing_start_side == Mats.StroadSide.NORTH, "Crossing start side must be NORTH"
	)
	assert(
		main.mats.current_side == Mats.StroadSide.NORTH,
		"Current side must remain NORTH while crossing"
	)

	# Dying on stroad during crossing attempt must return to starting side (North)
	var mid_cross_respawn := main.mats.get_respawn_position()
	assert(
		absf(mid_cross_respawn.z - (-13.85)) < 0.01,
		"Mid-crossing death must respawn on starting side (North)"
	)

	# Successfully reach South side
	main.mats.global_position = Vector3(0.0, 0.3, 13.85)
	main.mats.update_stroad_side()
	assert(not main.mats.is_crossing, "Crossing must complete upon reaching South roadside")
	assert(main.mats.current_side == Mats.StroadSide.SOUTH, "Current side must now be SOUTH")
	assert(main.mats.crossings_count == 1, "Crossings count must increment to 1")
	assert(main.hud.crossings_count == 1, "HUD crossings count must follow Mats crossings")

	print("OBJECTIVES_TEST: SUCCESS - --test-objectives passed cleanly!")
	main.get_tree().quit(0)


func _run_test_start_screen() -> void:
	await main.get_tree().process_frame
	var start_screen: StartScreen = main.start_screen
	if start_screen == null:
		start_screen = main.get_node_or_null("StartScreen") as StartScreen
	assert(start_screen != null, "StartScreen must exist")

	var start_btn: Button = start_screen.get_node("%StartButton")
	var quit_btn: Button = start_screen.get_node("%QuitButton")
	var see_more_btn: Button = start_screen.get_node("%SeeMoreButton")
	start_screen.open_screen(StartScreen.Page.MAIN)
	start_screen._is_loaded = true
	start_screen.set_loading(false)
	start_screen._setup_focus_navigation()
	await main.get_tree().process_frame

	start_btn.grab_focus()
	assert(main.get_viewport().gui_get_focus_owner() == start_btn, "Start button must be focused")

	# Arrow Right from Start -> Quit
	start_screen._handle_arrow_navigation(KEY_RIGHT)
	assert(
		main.get_viewport().gui_get_focus_owner() == quit_btn,
		"Arrow Right must move focus to Quit button"
	)

	# Arrow Left from Quit -> Start
	start_screen._handle_arrow_navigation(KEY_LEFT)
	assert(
		main.get_viewport().gui_get_focus_owner() == start_btn,
		"Arrow Left must move focus to Start button"
	)

	# Arrow Up from Start -> See More
	start_screen._handle_arrow_navigation(KEY_UP)
	assert(
		main.get_viewport().gui_get_focus_owner() == see_more_btn,
		"Arrow Up must move focus to See More button"
	)

	# Arrow Down from See More -> Start
	start_screen._handle_arrow_navigation(KEY_DOWN)
	assert(
		main.get_viewport().gui_get_focus_owner() == start_btn,
		"Arrow Down must move focus to Start button"
	)

	# Arrow Up from Quit -> See More
	quit_btn.grab_focus()
	start_screen._handle_arrow_navigation(KEY_UP)
	assert(
		main.get_viewport().gui_get_focus_owner() == see_more_btn,
		"Arrow Up from Quit must move focus to See More button"
	)

	# Arrow Right from See More -> Quit
	start_screen._handle_arrow_navigation(KEY_RIGHT)
	assert(
		main.get_viewport().gui_get_focus_owner() == quit_btn,
		"Arrow Right from See More must move focus to Quit button"
	)

	# Test page switch to controls
	start_screen.show_page(StartScreen.Page.CONTROLS)
	await main.get_tree().process_frame
	var back_btn: Button = start_screen.get_node("%ControlsBackButton")
	var resume_btn: Button = start_screen.get_node("%ControlsResumeButton")
	assert(
		main.get_viewport().gui_get_focus_owner() == back_btn,
		"Controls page must focus Back button"
	)

	# Arrow navigation between Back and Resume
	start_screen._handle_arrow_navigation(KEY_RIGHT)
	assert(
		main.get_viewport().gui_get_focus_owner() == resume_btn,
		"Arrow Right must move focus to Resume button"
	)
	start_screen._handle_arrow_navigation(KEY_LEFT)
	assert(
		main.get_viewport().gui_get_focus_owner() == back_btn,
		"Arrow Left must move focus to Back button"
	)

	print("START_SCREEN_TEST: SUCCESS - --test-start-screen passed cleanly!")
	main.get_tree().quit(0)


func _run_test_startup() -> void:
	var start_screen: StartScreen = main.start_screen
	if start_screen == null:
		start_screen = main.get_node_or_null("StartScreen") as StartScreen
	assert(start_screen != null, "StartScreen must exist")
	var tm: TrafficManager = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm != null, "TrafficManager must exist")
	var obj_mgr: ObjectiveManager = main.get_node_or_null("ObjectiveManager") as ObjectiveManager
	assert(obj_mgr != null, "ObjectiveManager must exist")

	# Initial state: start screen is visible, tree is paused, warmup is underway.
	assert(start_screen.visible, "StartScreen must be visible at boot")
	assert(main.get_tree().paused, "Game tree must start paused for menu gating")
	assert(not start_screen._is_loaded, "StartScreen must not be loaded before warmup finishes")
	assert(not tm.is_initial_traffic_ready, "Initial traffic must still be staging")

	# 1. Warmup: wait for staged traffic spawn and shader warmup to complete
	if not tm.is_initial_traffic_ready:
		await tm.initial_traffic_ready
	assert(tm.is_initial_traffic_ready, "TrafficManager must finish staged spawn")

	while not start_screen._is_loaded:
		await main.get_tree().process_frame
	assert(start_screen._is_loaded, "StartScreen must be loaded after warmup")
	var props: Node3D = main.get_node_or_null("Props")
	if props:
		for building_name in [
			"Walgroins", "TacoHell", "BoogerKingSite", "StripMall", "CrampedInn", "SmellGasStation"
		]:
			var b := props.get_node_or_null(building_name) as Node3D
			assert(
				b != null and b.visible, "Building %s must be visible after warmup" % building_name
			)

	# Verify night lighting warmup completed and restored to daytime
	assert(not GameState.are_lights_on(), "Lights must not be active during daytime")
	var sl := props.get_node_or_null("Streetlights") as Node3D if props else null
	if sl:
		for lamp in sl.get_children():
			if lamp is MultiMeshInstance3D:
				continue
			var light: SpotLight3D = lamp.get_node_or_null("Light")
			if light:
				assert(
					not light.visible,
					"Streetlight SpotLight3D must be restored to off after warmup"
				)
	# 2. Menu gating: verify tree remains paused and objectives are gated
	assert(main.get_tree().paused, "Tree must remain paused while StartScreen is gating")
	assert(
		obj_mgr.current_state == ObjectiveManager.State.IDLE,
		"ObjectiveManager must be IDLE in menu"
	)
	assert(not obj_mgr._started_once, "Objective flow must not start while menu is open")
	assert(obj_mgr._call_timer < 0.0, "First-call timer must not tick while menu is open")

	for _i in range(5):
		await main.get_tree().process_frame
	assert(main.get_tree().paused, "Tree must stay paused across frames while in menu")
	assert(obj_mgr.current_state == ObjectiveManager.State.IDLE, "ObjectiveManager must stay IDLE")

	# 3. First-call timing: start game, unpause, and verify first-call delay
	start_screen.start_game()
	await start_screen.started
	assert(not main.get_tree().paused, "Tree must be unpaused after start_game()")
	assert(obj_mgr._started_once, "ObjectiveManager flow must start on game start")
	assert(obj_mgr._call_timer > 0.0, "First-call timer must be running")
	assert(
		obj_mgr.current_state == ObjectiveManager.State.IDLE,
		"Phone must remain IDLE before timer elapses"
	)

	# Wait for the initial call timer to expire and the phone to ring
	await obj_mgr.call_started
	assert(
		obj_mgr.current_state == ObjectiveManager.State.RINGING,
		"Phone must ring when delay elapses"
	)
	assert(obj_mgr.current_errand != null, "First errand must be assigned")

	print("STARTUP_TEST: SUCCESS - --test-startup passed cleanly!")
	main.get_tree().quit(0)


func _run_test_character_editor() -> void:
	await main.get_tree().process_frame

	# Material isolation across standalone rigs
	var rig_scene: PackedScene = load("res://player/mats_rig.tscn")
	var standalone_rig1: MatsRig = rig_scene.instantiate() as MatsRig
	var standalone_rig2: MatsRig = rig_scene.instantiate() as MatsRig
	main.add_child(standalone_rig1)
	main.add_child(standalone_rig2)
	await main.get_tree().process_frame
	standalone_rig1.set_jacket_color(Color.RED)
	standalone_rig2.set_jacket_color(Color.YELLOW)
	var rig1_jacket_mat := (
		standalone_rig1.torso.get_surface_override_material(0) as StandardMaterial3D
	)
	var rig2_jacket_mat := (
		standalone_rig2.torso.get_surface_override_material(0) as StandardMaterial3D
	)
	assert(rig1_jacket_mat != null and rig2_jacket_mat != null, "Jacket materials must exist")
	assert(rig1_jacket_mat != rig2_jacket_mat, "Material instances must be isolated across rigs")
	assert(rig1_jacket_mat.albedo_color == Color.RED, "Rig 1 jacket color must match")
	assert(rig2_jacket_mat.albedo_color == Color.YELLOW, "Rig 2 jacket color must match")
	standalone_rig1.queue_free()
	standalone_rig2.queue_free()

	# Editor customization drives player and preview rigs
	var editor: CharacterEditor = main.character_editor
	if editor == null:
		editor = main.get_node_or_null("CharacterEditor") as CharacterEditor
	editor.open_editor()
	assert(editor.visible, "Editor must be visible when opened")
	var player_rig: MatsRig = main.mats.visual
	var orig_jacket := editor._jacket_index
	editor._on_jacket_step(1)
	assert(editor._jacket_index != orig_jacket, "Stepping jacket must update index")
	var new_color: Color = CharacterEditor.JACKET_COLORS[editor._jacket_index]
	assert(player_rig.jacket_color == new_color, "Player rig jacket color must update")
	assert(editor.preview_rig.jacket_color == new_color, "Preview rig jacket color must update")
	editor.close_editor()
	assert(not editor.visible, "Editor must be hidden when closed")

	print("CHARACTER_EDITOR_TEST: SUCCESS - --test-character-editor passed cleanly!")
	main.get_tree().quit(0)


func _run_test_retro_filter() -> void:
	await main.get_tree().process_frame
	var retro_filter: CanvasLayer = main.retro_filter
	if retro_filter == null:
		retro_filter = main.get_node_or_null("RetroFilter") as CanvasLayer
	assert(retro_filter != null, "RetroFilter must exist in main scene")

	var effect_rect: ColorRect = retro_filter.get_node_or_null("EffectRect") as ColorRect
	assert(effect_rect != null, "EffectRect must exist in RetroFilter")
	assert(not effect_rect.visible, "EffectRect must start disabled (Preset.OFF)")
	var vp := main.get_viewport()
	var orig_scale: float = vp.scaling_3d_scale

	# Cycle preset to subtle retro (2x crisp)
	var p = retro_filter.call("cycle_preset")
	assert(p == 1, "First cycle must switch to Subtle Retro (1)")
	assert(effect_rect.visible, "EffectRect must be visible when preset is active")
	var mat: ShaderMaterial = effect_rect.material as ShaderMaterial
	assert(mat != null, "EffectRect must have a ShaderMaterial")
	assert(mat.get_shader_parameter("enabled") == true, "Shader must be enabled")
	assert(
		is_equal_approx(vp.scaling_3d_scale, 0.5),
		"Active preset must render 3D at one sample per block (1 / pixel_size)"
	)

	# Walk every remaining preset; each must drive the low-res 3D render and
	# reset effects set by the previous one (e.g. CRT curvature).
	var preset_count: int = RetroFilter.Preset.size()
	for i in range(2, preset_count):
		p = retro_filter.call("cycle_preset")
		assert(p == i, "Cycle must advance one preset at a time")
		assert(
			is_equal_approx(vp.scaling_3d_scale, 1.0 / mat.get_shader_parameter("pixel_size")),
			"Preset %d must render 3D at 1 / pixel_size" % i
		)
		if p != RetroFilter.Preset.ARCADE_CRT:
			assert(
				is_zero_approx(mat.get_shader_parameter("curvature")),
				"Preset %d must not inherit CRT curvature" % i
			)
	p = retro_filter.call("cycle_preset")
	assert(p == 0, "Must wrap back to Preset.OFF")
	assert(
		retro_filter.call("cycle_preset", -1) == preset_count - 1,
		"Stepping back from OFF must wrap to the last preset"
	)
	p = retro_filter.call("cycle_preset")
	assert(p == 0, "Stepping forward from the last preset must return to OFF")
	assert(not effect_rect.visible, "EffectRect must be hidden when OFF")
	assert(
		is_equal_approx(vp.scaling_3d_scale, orig_scale),
		"Turning the filter OFF must restore the previous 3D render scale"
	)
	print("RETRO_FILTER_TEST: SUCCESS - --test-retro-filter passed cleanly!")
	main.get_tree().quit(0)
