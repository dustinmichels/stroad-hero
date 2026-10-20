class_name ObjectivesUiSuite
extends TestSuite


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--test-day-weather",
				"--test-foliage-wind",
				"--test-powerlines",
				"--test-chainlink-fence",
				"--test-stroad-tunnels",
				"--test-objective-manager",
				"--test-objectives",
				"--test-start-screen",
				"--test-startup",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--test-day-weather" in user_args:
		_run_test_day_weather()
		return
	if "--test-foliage-wind" in user_args:
		_run_test_foliage_wind()
		return
	if "--test-powerlines" in user_args:
		_run_test_powerlines()
		return
	if "--test-chainlink-fence" in user_args:
		_run_test_chainlink_fence()
	if "--test-stroad-tunnels" in user_args:
		_run_test_stroad_tunnels()
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


func _run_test_day_weather() -> void:
	await main.get_tree().process_frame
	# 1. Verify day span constants
	var start_h := GameState.START_HOUR
	var end_h := GameState.END_HOUR
	assert(is_equal_approx(start_h, 15.5), "Day must start at 3:30 PM (15.5)")
	assert(is_equal_approx(end_h, 21.0), "Day must end at 9:00 PM (21.0)")
	# 2. Time string formatting and period
	GameState.set_time_hours(15.5)
	assert(GameState.get_time_string() == "3:30 PM", "15.5 should format as 3:30 PM")
	assert(GameState.get_period_name() == "AFTERNOON", "15.5 should be AFTERNOON")
	assert(GameState.are_lights_on() == false, "Lights should be off at 3:30 PM")

	# 3. Evening / Dusk progression
	GameState.set_time_hours(18.5)
	assert(GameState.get_time_string() == "6:30 PM", "18.5 should format as 6:30 PM")
	assert(GameState.are_lights_on() == true, "Lights should be on at 6:30 PM")
	assert(GameState.time_of_day == GameState.TimeOfDay.EVENING, "18.5 should be EVENING")

	# 4. Night progression
	GameState.set_time_hours(20.5)
	assert(GameState.get_time_string() == "8:30 PM", "20.5 should format as 8:30 PM")
	assert(GameState.are_lights_on() == true, "Lights should be on at night")
	assert(GameState.time_of_day == GameState.TimeOfDay.NIGHT, "20.5 should be NIGHT")

	# 5. Day rollover / loop
	GameState.current_day = 1
	GameState.set_time_hours(20.9)
	GameState.advance_time(0.2)
	assert(GameState.current_day == 2, "Reaching 9:00 PM should increment current_day to 2")
	assert(
		GameState.current_time_hours >= 15.5 and GameState.current_time_hours < 16.0,
		"Time should wrap back to 3:30 PM"
	)

	# 6. Cardinal direction calculation
	assert(
		GameState.get_cardinal_direction_name(Vector3(0, 0, -1)) == "N", "World -Z must be North"
	)
	assert(GameState.get_cardinal_direction_name(Vector3(1, 0, 0)) == "E", "World +X must be East")
	assert(GameState.get_cardinal_direction_name(Vector3(0, 0, 1)) == "S", "World +Z must be South")
	assert(GameState.get_cardinal_direction_name(Vector3(-1, 0, 0)) == "W", "World -X must be West")
	assert(
		GameState.get_cardinal_direction_name(Vector3(1, 0, -1).normalized()) == "NE",
		"World +X, -Z must be NE"
	)

	# 7. WeatherDisplay component exists and updates
	assert(main.hud != null, "HUD must exist")
	assert(main.hud.weather_display != null, "WeatherDisplay must be mounted in HUD")
	assert(
		main.hud.weather_display.compass_dial != null, "Compass dial must exist in WeatherDisplay"
	)
	assert(main.hud.weather_display.time_label.text.length() > 0, "Time label must have text")

	print("DAY_WEATHER_TEST: SUCCESS - --test-day-weather passed cleanly!")
	main.get_tree().quit(0)


func _run_test_foliage_wind() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

	var trees_node := main.get_node_or_null("Props/Trees") as Node3D
	assert(trees_node != null, "Props/Trees must exist in main scene")

	var live_oaks: Array[StreetTree] = []
	for child in trees_node.get_children():
		if child is StreetTree and child.tree_type == StreetTree.TreeType.LIVE_OAK:
			live_oaks.append(child)
	assert(live_oaks.size() > 0, "Main scene must contain at least one LiveOak tree")

	for oak in live_oaks:
		var foliage := oak.get_node_or_null("Visuals/LiveOak/Foliage") as MeshInstance3D
		assert(foliage != null, "LiveOak must have Foliage MeshInstance3D")
		for s in range(3):
			var mat := foliage.get_surface_override_material(s) as ShaderMaterial
			assert(mat != null, "Surface %d override on LiveOak foliage must be ShaderMaterial" % s)
			assert(mat.shader != null, "ShaderMaterial must have valid shader resource")
			var albedo = mat.get_shader_parameter("albedo_color")
			assert(albedo is Color or albedo is Vector3, "Albedo color uniform must be present")

	# Test dynamic wind updates propagate to shader parameters
	var test_dir := Vector3(0.0, 0.0, 1.0)
	var test_speed := 2.2
	GameState.set_wind_direction(test_dir, true)
	GameState.set_wind_speed(test_speed)
	await main.get_tree().process_frame

	var sample_oak := live_oaks[0]
	var sample_foliage := sample_oak.get_node_or_null("Visuals/LiveOak/Foliage") as MeshInstance3D
	var sample_mat := sample_foliage.get_surface_override_material(0) as ShaderMaterial
	var current_dir: Vector2 = sample_mat.get_shader_parameter("wind_direction")
	var current_spd: float = sample_mat.get_shader_parameter("wind_strength")
	assert(current_dir.is_equal_approx(Vector2(0.0, 1.0)), "Wind direction uniform must update")
	assert(is_equal_approx(current_spd, 2.2), "Wind strength uniform must update")

	GameState.resume_wind_simulation()
	print("FOLIAGE_WIND_TEST: SUCCESS - --test-foliage-wind passed cleanly!")
	main.get_tree().quit(0)


func _run_test_powerlines() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

	var powerlines := main.get_node_or_null("Props/Powerlines") as Node3D
	assert(powerlines != null, "Props/Powerlines must exist in main scene")
	assert(powerlines.get_child_count() >= 2, "Props/Powerlines must contain multiple poles")

	var child_count := powerlines.get_child_count()
	for i in range(child_count):
		var pole := powerlines.get_child(i) as Powerline
		assert(pole != null, "Child %d of Powerlines must be a Powerline" % i)

		var col := pole.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert(col != null, "Powerline %d must have a CollisionShape3D" % i)

		var wire_mi := pole.get_node_or_null("WireMesh") as MeshInstance3D
		assert(wire_mi != null, "Powerline %d must have a WireMesh" % i)

		if i < child_count - 1:
			assert(wire_mi.visible == true, "Powerline %d must have visible wires" % i)
			assert(wire_mi.mesh != null, "Powerline %d must have a generated wire mesh" % i)
			assert(
				wire_mi.mesh.get_surface_count() > 0,
				"Powerline %d wire mesh must have surfaces" % i
			)
			var verts: int = wire_mi.mesh.surface_get_array_len(0)
			assert(verts > 0, "Powerline %d wire mesh must contain vertices" % i)
		else:
			assert(wire_mi.visible == false, "Terminal powerline must not dangle wires forward")

	# Test standalone re-usable scene instantiation
	var pl_scene := load("res://props/powerline.tscn") as PackedScene
	assert(pl_scene != null, "props/powerline.tscn must load as a PackedScene")
	var standalone := pl_scene.instantiate() as Powerline
	assert(standalone != null, "Must instantiate Powerline")
	standalone.has_transformer = true
	main.add_child(standalone)
	await main.get_tree().process_frame
	assert(standalone.has_transformer == true, "Standalone pole must support transformer")
	var st_transformer := standalone.get_node_or_null("Visuals/Transformer") as Node3D
	assert(
		st_transformer != null and st_transformer.visible == true,
		"Transformer must be visible when enabled"
	)
	standalone.queue_free()

	print("POWERLINES_TEST: SUCCESS - --test-powerlines passed cleanly!")
	main.get_tree().quit(0)


func _run_test_chainlink_fence() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

	const FenceScript = preload("res://props/chainlink_fence.gd")
	var fence = main.get_node_or_null("BoundaryFence")
	assert(
		fence != null and fence is FenceScript,
		"BoundaryFence must exist in main scene and be ChainlinkFence"
	)

	# 1. Verify collision boundaries along all 4 edges of the earth
	var col_north := fence.get_node_or_null("CollisionNorth") as CollisionShape3D
	var col_south := fence.get_node_or_null("CollisionSouth") as CollisionShape3D
	var col_east := fence.get_node_or_null("CollisionEast") as CollisionShape3D
	var col_west := fence.get_node_or_null("CollisionWest") as CollisionShape3D
	assert(col_north != null, "North collision shape must exist")
	assert(col_south != null, "South collision shape must exist")
	assert(col_east != null, "East collision shape must exist")
	assert(col_west != null, "West collision shape must exist")

	assert(col_north.shape is BoxShape3D, "North collision must be BoxShape3D")
	assert(col_south.shape is BoxShape3D, "South collision must be BoxShape3D")
	assert(col_east.shape is BoxShape3D, "East collision must be BoxShape3D")
	assert(col_west.shape is BoxShape3D, "West collision must be BoxShape3D")

	# 2. Verify visual components and distance visibility settings
	assert(fence.visibility_distance == 60.0, "Visibility distance must be 60m")
	assert(fence.visibility_fade_margin == 15.0, "Fade margin must be 15m")

	# Corner posts count and visibility range
	var corner_count := 0
	for child in fence.get_children():
		if child.name.begins_with("CornerPost"):
			corner_count += 1
			var post_mi := child.get_node_or_null("Post") as MeshInstance3D
			assert(post_mi != null, "Corner post must have Post mesh")
			assert(
				post_mi.visibility_range_end == 60.0,
				"Corner post must have visibility_range_end 60m"
			)
	assert(corner_count == 4, "Must have 4 corner posts for the perimeter rectangle")

	# Side chunks: line posts, fabric meshes, and rails
	var total_line_posts := 0
	var fabric_count := 0
	for side_name in ["Side_North", "Side_East", "Side_South", "Side_West"]:
		var side_node := fence.get_node_or_null(side_name) as Node3D
		assert(side_node != null, "Side node %s must exist" % side_name)
		for chunk in side_node.get_children():
			var fabric := chunk.get_node_or_null("Fabric") as MeshInstance3D
			assert(fabric != null, "Chunk must have Fabric mesh")
			assert(fabric.visibility_range_end == 60.0, "Fabric must have visibility_range_end 60m")
			assert(fabric.material_override is ShaderMaterial, "Fabric must have ShaderMaterial")
			fabric_count += 1

			var top_rail := chunk.get_node_or_null("TopRail") as MeshInstance3D
			assert(top_rail != null, "Chunk must have TopRail")
			assert(
				top_rail.visibility_range_end == 60.0, "TopRail must have visibility_range_end 60m"
			)

			var posts_mmi := chunk.get_node_or_null("LinePosts") as MultiMeshInstance3D
			if posts_mmi and posts_mmi.multimesh:
				assert(
					posts_mmi.visibility_range_end == 60.0,
					"LinePosts must have visibility_range_end 60m"
				)
				total_line_posts += posts_mmi.multimesh.instance_count

	assert(
		total_line_posts >= 300,
		"Total line posts across chunks must be >= 300 (got %d)" % total_line_posts
	)
	assert(
		fabric_count >= 50,
		"Perimeter must be chunked into localized sections (got %d chunks)" % fabric_count
	)

	# 3. Verify ground terrain extension past fence
	var ground_mi := main.get_node_or_null("GroundTerrain") as MeshInstance3D
	assert(
		ground_mi != null and ground_mi.mesh is PlaneMesh, "GroundTerrain must exist with PlaneMesh"
	)
	var ground_plane := ground_mi.mesh as PlaneMesh
	assert(ground_plane.size.x >= 380.0, "Ground must extend past fence in X (at least 380m)")
	assert(ground_plane.size.y >= 260.0, "Ground must extend past fence in Z (at least 260m)")

	# Test physics collision: prove Mats cannot walk off the edge of the earth
	main.mats.global_position = Vector3(45.0, 0.3, 134.0)
	main.mats.velocity = Vector3(0.0, 0.0, 10.0)
	for _step in range(30):
		main.mats.velocity = Vector3(0.0, 0.0, 10.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(main.mats.global_position.z < 134.8, "Fence must block Mats from falling off South edge")

	main.mats.global_position = Vector3(45.0, 0.3, -104.0)
	main.mats.velocity = Vector3(0.0, 0.0, -10.0)
	for _step in range(30):
		main.mats.velocity = Vector3(0.0, 0.0, -10.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.z > -104.8, "Fence must block Mats from falling off North edge"
	)

	main.mats.global_position = Vector3(-134.0, 0.3, 15.0)
	main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(main.mats.global_position.x > -134.8, "Fence must block Mats from falling off West edge")

	main.mats.global_position = Vector3(224.0, 0.3, 15.0)
	main.mats.velocity = Vector3(10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(main.mats.global_position.x < 224.8, "Fence must block Mats from falling off East edge")

	# 4. Test standalone reusable section scene
	var sec_scene := load("res://props/chainlink_fence_section.tscn") as PackedScene
	assert(sec_scene != null, "props/chainlink_fence_section.tscn must load as PackedScene")
	var sec_inst = sec_scene.instantiate()
	assert(sec_inst != null and sec_inst is FenceScript, "Must instantiate ChainlinkFenceSection")
	main.add_child(sec_inst)
	await main.get_tree().process_frame
	assert(
		sec_inst.get_node_or_null("CollisionSection") != null, "Section must have CollisionSection"
	)
	sec_inst.queue_free()

	print("CHAINLINK_FENCE_TEST: SUCCESS - --test-chainlink-fence passed cleanly!")
	main.get_tree().quit(0)


func _run_test_stroad_tunnels() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

	# 1. Verify stroad extension
	var road_node := main.get_node_or_null("Road")
	assert(road_node != null, "Road node must exist in main scene")
	var stroad := road_node.get_node_or_null("Stroad") as MeshInstance3D
	assert(stroad != null, "Stroad mesh instance must exist")
	assert(stroad.mesh is BoxMesh, "Stroad mesh must be BoxMesh")
	var stroad_mesh := stroad.mesh as BoxMesh
	assert(
		stroad_mesh.size.x >= 300.0,
		"Stroad must be extended to at least 300m in length (got %.1f)" % stroad_mesh.size.x
	)

	# 2. Verify road markings extension
	var markings := road_node.get_node_or_null("Markings")
	assert(markings != null, "Markings node must exist")
	for line_name in ["CenterLine1", "CenterLine2", "EdgeLineSouth", "EdgeLineNorth"]:
		var line_mi := markings.get_node_or_null(line_name) as MeshInstance3D
		assert(line_mi != null, "Line marking %s must exist" % line_name)
		assert(
			(line_mi.mesh as BoxMesh).size.x >= 300.0, "%s must extend to at least 300m" % line_name
		)

	# 3. Verify tunnel nodes exist under Props
	var props_node := main.get_node_or_null("Props")
	assert(props_node != null, "Props node must exist")
	var tunnel_west := props_node.get_node_or_null("TunnelWest") as Tunnel
	var tunnel_east := props_node.get_node_or_null("TunnelEast") as Tunnel
	assert(tunnel_west != null, "TunnelWest must exist under Props and be Tunnel instance")
	assert(tunnel_east != null, "TunnelEast must exist under Props and be Tunnel instance")

	assert(
		tunnel_west.global_position.x <= -100.0,
		"TunnelWest must be at west edge of stroad (x <= -100)"
	)
	assert(
		tunnel_east.global_position.x >= 150.0,
		"TunnelEast must be at east edge of stroad (x >= 150)"
	)

	# 4. Verify tunnel components and chain-link fences
	for t in [tunnel_west, tunnel_east]:
		var portal = t.get_node_or_null("PortalStructure")
		assert(portal != null, "Tunnel %s must have PortalStructure" % t.name)
		var tube = t.get_node_or_null("TunnelTube")
		assert(tube != null, "Tunnel %s must have TunnelTube" % t.name)

		var fences = t.get_node_or_null("ChainlinkFences")
		assert(fences != null, "Tunnel %s must have ChainlinkFences" % t.name)
		var f_south = fences.get_node_or_null("Fence_SouthAcross")
		var f_north = fences.get_node_or_null("Fence_NorthAcross")
		var f_side_s = fences.get_node_or_null("Fence_SouthSide")
		var f_side_n = fences.get_node_or_null("Fence_NorthSide")
		assert(
			f_south != null and f_north != null,
			"Tunnel %s must have fences across sidewalks" % t.name
		)
		assert(
			f_side_s != null and f_side_n != null, "Tunnel %s must have fences on sides" % t.name
		)

		# Verify portal player blocker
		var blocker = t.get_node_or_null("Col_PortalPlayerBlocker") as CollisionShape3D
		assert(blocker != null, "Tunnel %s must have Col_PortalPlayerBlocker" % t.name)

	# 5. Physics test: prove Mats is blocked from entering West tunnel on roadway
	main.mats.global_position = Vector3(-98.0, 0.3, 0.0)
	main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.x > -100.5,
		"Tunnel blocker must prevent Mats from entering West tunnel on roadway"
	)

	# 6. Physics test: prove Mats is blocked from passing West tunnel on sidewalk by chain link fence
	main.mats.global_position = Vector3(-98.0, 0.3, 14.0)
	main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(-10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.x > -100.5,
		"Chain link fence must block Mats on West tunnel South sidewalk"
	)

	# 7. Physics test: prove Mats is blocked from entering East tunnel on roadway
	main.mats.global_position = Vector3(148.0, 0.3, 0.0)
	main.mats.velocity = Vector3(10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.x < 150.5,
		"Tunnel blocker must prevent Mats from entering East tunnel on roadway"
	)

	# 8. Physics test: prove Mats is blocked from passing East tunnel on sidewalk by chain link fence
	main.mats.global_position = Vector3(148.0, 0.3, -14.0)
	main.mats.velocity = Vector3(10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.x < 150.5,
		"Chain link fence must block Mats on East tunnel North sidewalk"
	)

	print("STROAD_TUNNELS_TEST: SUCCESS - --test-stroad-tunnels passed cleanly!")
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

	# 3b. Verify expanded location catalog and items
	assert(obj_mgr.get_errand_by_id(&"tacos") != null, "Taco Hell tacos errand must exist")
	assert(obj_mgr.get_errand_by_id(&"burritos") != null, "Taco Hell burritos errand must exist")
	assert(
		obj_mgr.get_errand_by_id(&"quesadillas") != null, "Taco Hell quesadillas errand must exist"
	)
	assert(obj_mgr.get_errand_by_id(&"band_aids") != null, "Walgroins band-aids errand must exist")
	assert(obj_mgr.get_errand_by_id(&"beef_jerky") != null, "Smell beef jerky errand must exist")
	var taco_errand = obj_mgr.get_errand_by_id(&"tacos")
	assert(taco_errand.proper_store_name == "Taco Hell")
	assert(taco_errand.generic_store_name == "the taco stand")
	var walgroins_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
	assert(walgroins_errand.proper_store_name == "Walgroins")
	assert(walgroins_errand.generic_store_name == "the pharmacy")
	var smell_errand = obj_mgr.get_errand_by_id(&"milk")
	assert(smell_errand.proper_store_name == "Smell")
	assert(smell_errand.generic_store_name == "the convenience store")
	var bk_errand = obj_mgr.get_errand_by_id(&"hamburgers")
	assert(bk_errand.proper_store_name == "Booger King")
	assert(bk_errand.generic_store_name == "the burger joint")

	# 3c. Dialogue generation tests
	var d_proper = ObjectiveManager.generate_dialogue(
		"tacos",
		"Taco Hell",
		"the taco stand",
		obj_mgr.objectives_data.get("dialogue_parts", {}),
		false
	)
	assert(
		d_proper["used_location_name"] == "Taco Hell",
		"Must use proper name when use_generic is false"
	)
	assert(d_proper["call_line"].contains("Taco Hell"), "Call line must contain proper name")
	assert(d_proper["call_line"].contains("tacos"), "Call line must contain item")

	var d_generic = ObjectiveManager.generate_dialogue(
		"tacos",
		"Taco Hell",
		"the taco stand",
		obj_mgr.objectives_data.get("dialogue_parts", {}),
		true
	)
	assert(
		d_generic["used_location_name"] == "the taco stand",
		"Must use generic name when use_generic is true"
	)

	# 7. Destination Anchor Resolution Test
	# Verify that registered destination anchors match exact site locations
	print("OBJECTIVE_MANAGER_TEST: Verifying destination anchors and coordinate registration...")
	var walgroins_dest = obj_mgr.get_destination_anchor(&"walgroins")
	var bk_dest = obj_mgr.get_destination_anchor(&"booger_king")
	var smell_dest = obj_mgr.get_destination_anchor(&"smell")
	var taco_dest = obj_mgr.get_destination_anchor(&"taco_hell")

	assert(walgroins_dest != null, "Walgroins destination anchor must be registered")
	assert(bk_dest != null, "Booger King destination anchor must be registered")
	assert(smell_dest != null, "Smell destination anchor must be registered")
	assert(taco_dest != null, "Taco Hell destination anchor must be registered")

	# Verify destination coordinate bounds match reference architectural sites
	assert(walgroins_dest.global_position.z < 0.0, "Walgroins anchor must be on North side (z < 0)")
	assert(bk_dest.global_position.z > 0.0, "Booger King anchor must be on South side (z > 0)")
	assert(smell_dest.global_position.z < 0.0, "Smell anchor must be on North side (z < 0)")
	assert(taco_dest.global_position.z < 0.0, "Taco Hell anchor must be on North side (z < 0)")
	# 8. Composition Injection & Registration Test
	# Verify that a fresh Main composition explicitly wires and registers dependencies
	print("OBJECTIVE_MANAGER_TEST: Verifying root composition dependency injection...")
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "main.tscn must be loadable")
	var container = Node.new()
	main.add_child(container)
	var nested_main: Main = main_scene.instantiate()
	container.add_child(nested_main)

	# Ensure setup has executed
	assert(nested_main.objective_manager != null, "Main must expose objective_manager reference")
	assert(nested_main.traffic_manager != null, "Main must expose traffic_manager reference")
	assert(nested_main.hud != null, "Main must expose hud reference")
	assert(nested_main.mats != null, "Main must expose mats reference")

	# Verify all 4 required destination anchors were registered in nested Main
	var nested_om = nested_main.objective_manager
	assert(
		nested_om.has_destination(&"walgroins"), "Nested Main must register Walgroins destination"
	)
	assert(
		nested_om.has_destination(&"booger_king"),
		"Nested Main must register Booger King destination"
	)
	assert(
		nested_om.has_destination(&"smell"),
		"Nested Main must register Smell Gas Station destination"
	)
	assert(
		nested_om.has_destination(&"taco_hell"), "Nested Main must register Taco Hell destination"
	)

	# Verify HUD received explicit references
	assert(nested_main.hud.player == nested_main.mats, "HUD must receive explicit player reference")
	assert(
		nested_main.hud.objective_manager == nested_main.objective_manager,
		"HUD must receive explicit objective manager reference"
	)

	nested_main.queue_free()
	container.queue_free()

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

	# 2. Answer programmatically, teleport Mats to the target, and assert completed_count == 1 and the HUD shows "OBJ: 1".
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
	assert(
		main.hud.obj_label != null and main.hud.obj_label.text == "OBJ: 1", "HUD must show 'OBJ: 1'"
	)

	# 3. The next errand's target z sign is opposite Mats's z sign.
	obj_mgr.start_call()
	assert(obj_mgr.current_errand != null, "Next errand must be set")
	var next_target_pos := obj_mgr.get_target_position(obj_mgr.current_errand)
	assert(
		signf(next_target_pos.z) != signf(main.mats.global_position.z),
		(
			"Next errand target z sign (%f) must be opposite Mats's z sign (%f)"
			% [next_target_pos.z, main.mats.global_position.z]
		)
	)

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
