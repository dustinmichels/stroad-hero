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
				"--test-character-editor",
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
	if "--test-character-editor" in user_args:
		_run_test_character_editor()
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
	var streetlights: Node3D = main.get_node_or_null("Props/Streetlights")
	assert(streetlights != null, "Props/Streetlights must exist")
	var lamp0: Node3D = streetlights.get_child(0) as Node3D
	var spot0: SpotLight3D = lamp0.get_node_or_null("Light") as SpotLight3D
	var lamp_mesh0: MeshInstance3D = lamp0.get_node_or_null("Lamp") as MeshInstance3D
	assert(spot0 != null and not spot0.visible, "Streetlight SpotLight3D must be off at 3:30 PM")
	if lamp_mesh0:
		assert(
			lamp_mesh0.material_override == null,
			"Streetlight luminaire material override must be null at 3:30 PM"
		)
	# 3. Evening / Dusk progression
	GameState.set_time_hours(18.5)
	assert(GameState.get_time_string() == "6:30 PM", "18.5 should format as 6:30 PM")
	assert(GameState.are_lights_on() == true, "Lights should be on at 6:30 PM")
	assert(GameState.time_of_day == GameState.TimeOfDay.EVENING, "18.5 should be EVENING")
	assert(spot0 != null and spot0.visible, "Streetlight SpotLight3D must be on at 6:30 PM")
	if lamp_mesh0:
		assert(
			lamp_mesh0.material_override != null,
			"Streetlight luminaire material override must be active at 6:30 PM"
		)
		var mat: StandardMaterial3D = lamp_mesh0.material_override as StandardMaterial3D
		assert(
			mat != null and mat.emission_enabled,
			"Streetlight luminaire material must be emissive at 6:30 PM"
		)
	# 4. Night progression
	GameState.set_time_hours(20.5)
	assert(GameState.get_time_string() == "8:30 PM", "20.5 should format as 8:30 PM")
	assert(GameState.are_lights_on() == true, "Lights should be on at night")
	assert(GameState.time_of_day == GameState.TimeOfDay.NIGHT, "20.5 should be NIGHT")
	assert(spot0 != null and spot0.visible, "Streetlight SpotLight3D must be on at night")
	# 5. Day rollover / loop
	GameState.current_day = 1
	GameState.set_time_hours(20.9)
	GameState.advance_time(0.2)
	assert(GameState.current_day == 2, "Reaching 9:00 PM should increment current_day to 2")
	assert(
		GameState.current_time_hours >= 15.5 and GameState.current_time_hours < 16.0,
		"Time should wrap back to 3:30 PM"
	)
	assert(
		spot0 != null and not spot0.visible,
		"Streetlight SpotLight3D must turn off when looping back to day"
	)
	if lamp_mesh0:
		assert(
			lamp_mesh0.material_override == null,
			"Streetlight luminaire material override must clear when looping back to day"
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
		assert(
			absf(pole.global_position.z - (-13.85)) < 0.05,
			(
				"Powerline pole %s must be centered in sidewalk (z=-13.85), got z=%.3f"
				% [pole.name, pole.global_position.z]
			)
		)

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

	# Physics collision: verify pole obstructs pedestrian Mats walking down the middle of the sidewalk
	main.mats.global_position = Vector3(4.0, 0.245, -13.85)
	main.mats.velocity = Vector3(10.0, 0.0, 0.0)
	for _step in range(30):
		main.mats.velocity = Vector3(10.0, 0.0, 0.0)
		main.mats._physics_process(1.0 / 60.0)
	assert(
		main.mats.global_position.x < 5.8,
		(
			"Electricity pole in middle of sidewalk must physically block Mats (got x=%.2f)"
			% main.mats.global_position.x
		)
	)

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

	# 3d. Contextual dialogue and excuse scoping tests
	assert(
		ObjectiveManager.is_dinner_errand("tacos", "Taco Hell", &"taco_hell"),
		"Tacos at Taco Hell must be a dinner errand"
	)
	assert(
		ObjectiveManager.is_dinner_errand("hamburgers", "Booger King", &"booger_king"),
		"Hamburgers at Booger King must be a dinner errand"
	)
	assert(
		not ObjectiveManager.is_dinner_errand("cough syrup", "Walgroins", &"walgroins"),
		"Cough syrup at Walgroins must not be a dinner errand"
	)
	assert(
		not ObjectiveManager.is_dinner_errand("batteries", "Walgroins", &"walgroins"),
		"Batteries at Walgroins must not be a dinner errand"
	)
	assert(
		not ObjectiveManager.is_dinner_errand("milk", "Smell", &"smell"),
		"Milk at Smell must not be a dinner errand"
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

	# Verify legacy flat-array excuses compatibility and filtering
	var legacy_parts = {
		"openings": ["Mats schat..."],
		"excuses":
		[
			"I don't feel like cooking dinner tonight.",
			"I just remembered another thing!",
		],
		"requests": ["Could you pick up some {item} at {location}?"],
	}
	var leg_pharma = ObjectiveManager.get_excuses_for_errand(
		legacy_parts, "cough syrup", "Walgroins", &"walgroins"
	)
	assert(
		leg_pharma == ["I just remembered another thing!"],
		"Legacy flat excuses must filter out dinner excuse for pharmacy items"
	)
	var leg_dinner = ObjectiveManager.get_excuses_for_errand(
		legacy_parts, "hamburgers", "Booger King", &"booger_king"
	)
	assert(
		leg_dinner.size() == 2, "Legacy flat excuses must preserve dinner excuses for dinner items"
	)

	# Verify Dutch openings include italicized English translations in brackets
	var openings: Array = d_parts.get("openings", [])
	var dutch_checks = {
		"schat": "darling",
		"jongen": "my boy",
		"lieverd": "sweetheart",
		"Lieve Mats": "Dear Mats",
		"Hoi": "Hi",
	}
	for dutch_word in dutch_checks:
		var found := false
		var trans: String = dutch_checks[dutch_word]
		for op in openings:
			var op_str := str(op)
			if op_str.contains(dutch_word):
				found = true
				var has_italic := (
					op_str.contains("[[i]%s[/i]]" % trans) or op_str.contains("[i][%s][/i]" % trans)
				)
				assert(
					has_italic,
					(
						"Dutch opening with '%s' must include italicized translation in brackets: '%s'"
						% [dutch_word, op_str]
					)
				)
		assert(found, "Expected Dutch word '%s' in openings catalog" % dutch_word)

	# Verify PhoneCall DialogueLabel supports BBCode italics
	var phone_call_scene = load("res://ui/phone_call.tscn")
	assert(phone_call_scene != null, "phone_call.tscn must load")
	var phone_call_inst = phone_call_scene.instantiate()
	var dl = phone_call_inst.get_node("%DialogueLabel") as RichTextLabel
	assert(dl != null, "DialogueLabel must be a RichTextLabel")
	assert(dl.bbcode_enabled, "DialogueLabel must have bbcode_enabled = true")
	dl.text = "Mats schat [[i]darling[/i]]..."
	assert(
		dl.get_parsed_text() == "Mats schat [darling]...",
		"BBCode parsed text must strip tags and display bracketed translation"
	)
	phone_call_inst.queue_free()

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

	# 4. Verify phone visibility hides cleanly on death and restores on respawn
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
	assert(
		absf(main.mats.global_position.z - (-13.85)) < 0.15,
		(
			"Mats must respawn on the north side of the road when dying at north destination (got z=%.2f)"
			% main.mats.global_position.z
		)
	)
	assert(
		absf(main.mats.global_position.x - target_pos.x) < 0.5,
		(
			"Mats must respawn at the x coordinate of death (expected x=%.2f, got %.2f)"
			% [target_pos.x, main.mats.global_position.x]
		)
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
	assert(main.mats.crossings_achieved == 1, "crossings_achieved alias must be 1")

	# Wait until Mats is completely out of death sequence
	while main.mats.is_dead:
		await main.get_tree().process_frame

	# Answer and dismiss to ensure phone lowers and hides cleanly
	if phone_call and phone_call.is_ringing:
		phone_call.answer()
		assert(main.mats.is_on_phone, "Mats must be on phone after answering")
		assert(main.mats.phone.visible, "Phone must remain visible while talking")
		phone_call.dismiss()
	else:
		obj_mgr.answer_call()
		obj_mgr.dismiss_call()

	# Simulate animation frames for phone lowering blend
	for _i in range(15):
		main.mats.visual.update_phone_pose(0.1)
	assert(main.mats.phone_blend == 0.0, "Phone blend must return to 0 after call dismissal")
	assert(not main.mats.phone.visible, "Phone mesh must hide cleanly after lowering")

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


func _run_test_character_editor() -> void:
	await main.get_tree().process_frame

	# 1. Test standalone instantiation of MatsRig
	var rig_scene: PackedScene = load("res://player/mats_rig.tscn")
	assert(rig_scene != null, "mats_rig.tscn must exist and load")
	var standalone_rig1: MatsRig = rig_scene.instantiate() as MatsRig
	assert(standalone_rig1 != null, "mats_rig must instantiate as MatsRig")
	assert(
		not ((standalone_rig1 as Object) is CharacterBody3D),
		"mats_rig must not be a CharacterBody3D"
	)
	assert(
		not ((standalone_rig1 as Object) is CollisionObject3D),
		"mats_rig must have no physics overhead"
	)

	main.add_child(standalone_rig1)
	await main.get_tree().process_frame

	# Test isolated material customization
	var standalone_rig2: MatsRig = rig_scene.instantiate() as MatsRig
	main.add_child(standalone_rig2)
	await main.get_tree().process_frame

	standalone_rig1.set_jacket_color(Color.RED)
	standalone_rig1.set_backpack_color(Color.BLUE)
	standalone_rig1.set_shoe_color(Color.GREEN)
	standalone_rig1.set_headwear(MatsRig.Headwear.BEANIE)

	standalone_rig2.set_jacket_color(Color.YELLOW)
	standalone_rig2.set_backpack_color(Color(0.8, 0.2, 0.8, 1.0))
	standalone_rig2.set_shoe_color(Color.BLACK)
	standalone_rig2.set_headwear(MatsRig.Headwear.HAT)

	# Verify material isolation
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

	# Test update_idle on standalone rig
	var prev_idle_rot: Vector3 = standalone_rig1.right_arm.rotation
	standalone_rig1.update_idle(0.5)
	assert(
		standalone_rig1.right_arm.rotation != prev_idle_rot, "update_idle must animate limb posture"
	)

	standalone_rig1.queue_free()
	standalone_rig2.queue_free()

	# 2. Test CharacterEditor integration
	var editor: CharacterEditor = main.character_editor
	if editor == null:
		editor = main.get_node_or_null("CharacterEditor") as CharacterEditor
	assert(editor != null, "CharacterEditor must exist in main scene")

	# Target rig resolution
	assert(editor.target_rig_resolved != null, "CharacterEditor must resolve target rig")
	assert(editor.target_rig_resolved is MatsRig, "Target rig must be MatsRig")

	# Open editor
	editor.open_editor()
	assert(editor.visible, "Editor must be visible when opened")
	assert(editor.preview_rig != null, "Preview rig must be instantiated on open")
	assert(editor.preview_rig is MatsRig, "Preview must be an instance of MatsRig")
	assert(
		not ((editor.preview_rig as Object) is CharacterBody3D),
		"Preview must not have physics overhead"
	)

	# Verify preview sync from player rig
	var player_rig: MatsRig = main.mats.visual
	assert(
		editor._headwear_index == player_rig.headwear, "Editor headwear must sync with player rig"
	)

	# Test customization steps
	var orig_jacket := editor._jacket_index
	editor._on_jacket_step(1)
	assert(editor._jacket_index != orig_jacket, "Stepping jacket must update index")
	var new_color: Color = CharacterEditor.JACKET_COLORS[editor._jacket_index]
	assert(player_rig.jacket_color == new_color, "Player rig jacket color must update")
	assert(editor.preview_rig.jacket_color == new_color, "Preview rig jacket color must update")

	# Test rotation over time
	var orig_preview_yaw: float = editor.preview_rig.rotation.y
	editor._process(1.0)
	assert(editor.preview_rig.rotation.y != orig_preview_yaw, "Preview rig must rotate over time")

	# Close editor
	editor.close_editor()
	assert(not editor.visible, "Editor must be hidden when closed")

	print("CHARACTER_EDITOR_TEST: SUCCESS - --test-character-editor passed cleanly!")
	main.get_tree().quit(0)
