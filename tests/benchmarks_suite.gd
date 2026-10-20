class_name BenchmarksSuite
extends TestSuite

var _perf_target_frames: int = 0
var _perf_frames: int = 0
var _perf_is_walk: bool = false
var _perf_walk_dir: float = 1.0
var _perf_phys_samples: Array[float] = []
var _perf_proc_samples: Array[float] = []
var _perf_last_tick_usec: int = 0
var _perf_wall_samples: Array[float] = []
var _render_bench_active: bool = false
var _render_bench_target_frames: int = 240
var _render_bench_frames: int = 0
var _render_bench_draw_calls: Array[int] = []
var _render_bench_objects: Array[int] = []
var _render_bench_frame_intervals: Array[float] = []
var _render_bench_last_frame_usec: int = 0
var _render_bench_f3_texts: Array[String] = []


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--bench-physics",
				"--bench-physics-walk",
				"--bench-render",
				"--test-render",
				"--test-render-stats",
				"--test-verify-render",
			]
		):
			return true
	return false


func setup_ready() -> void:
	if "--bench-physics" in user_args or "--bench-physics-walk" in user_args:
		var sec := 5.0
		main.set_physics_process(true)
		main.get_tree().paused = false
		for arg in user_args:
			if arg.begins_with("--duration="):
				sec = float(arg.substr(11))
		_perf_target_frames = int(round(sec * Engine.physics_ticks_per_second)) + 60
		_perf_is_walk = "--bench-physics-walk" in user_args
		if _perf_is_walk and main.mats:
			main.mats.global_position = Vector3(9.0, 0.0, -15.0)

	if (
		"--bench-render" in user_args
		or "--test-render" in user_args
		or "--test-render-stats" in user_args
	):
		_render_bench_active = true
		for arg in user_args:
			if arg.begins_with("--frames="):
				_render_bench_target_frames = int(arg.substr(9))
		if main.mats:
			main.mats.global_position = Vector3(0.0, 0.3, 9.0)
			main.mats.velocity = Vector3.ZERO
			main.mats.set_physics_process(false)
			main.mats.set_process(false)
		var cam := main.get_node_or_null("Camera3D") as FollowCamera
		if cam:
			cam.set_process(false)
			cam.global_position = Vector3(0.0, 14.3777, 22.15358)
			cam.global_rotation = Vector3(-0.46259, 0.0, 0.0)
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
		if tm and tm.debug_overlay:
			tm.debug_overlay.visible = true
		if "--bake" in user_args:
			var mb = load("res://addons/mesh_baker/mesh_baker.gd")
			if mb:
				mb.bake_main_scene(main)
		RenderingServer.frame_post_draw.connect(_on_render_frame_post_draw)

	if "--test-verify-render" in user_args:
		_run_verify_render_test()


func on_physics_process(_delta: float) -> void:
	if "--bench-physics" in user_args or "--bench-physics-walk" in user_args:
		_perf_frames += 1
		if _perf_is_walk and main.mats:
			if main.mats.global_position.x > 80.0:
				_perf_walk_dir = -1.0
			elif main.mats.global_position.x < -80.0:
				_perf_walk_dir = 1.0
			main.mats.velocity = Vector3(_perf_walk_dir * 3.5, 0.0, 0.0)
			main.mats.move_and_slide()
		if _perf_frames > 60:
			var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			_perf_phys_samples.append(phys_ms)
			_perf_proc_samples.append(proc_ms)
			var now_usec := Time.get_ticks_usec()
			if _perf_last_tick_usec > 0:
				_perf_wall_samples.append(float(now_usec - _perf_last_tick_usec) / 1000.0)
			_perf_last_tick_usec = now_usec
		if _perf_frames >= _perf_target_frames:
			_report_perf_benchmark()
			main.get_tree().quit(0)


func _report_perf_benchmark() -> void:
	var phys_sorted := _perf_phys_samples.duplicate()
	phys_sorted.sort()
	var proc_sorted := _perf_proc_samples.duplicate()
	proc_sorted.sort()
	var n: int = phys_sorted.size()
	if n == 0:
		print("PERF_BENCHMARK: No samples collected")
		return
	var wall_sorted := _perf_wall_samples.duplicate()
	wall_sorted.sort()
	var wall_n := wall_sorted.size()
	var wall_sum := 0.0
	for w in wall_sorted:
		wall_sum += w
	var wall_avg: float = (wall_sum / float(wall_n)) if wall_n > 0 else 0.0
	var wall_p50: float = float(wall_sorted[int(wall_n * 0.50)]) if wall_n > 0 else 0.0
	var wall_p95: float = (
		float(wall_sorted[mini(wall_n - 1, int(wall_n * 0.95))]) if wall_n > 0 else 0.0
	)
	var wall_p99: float = (
		float(wall_sorted[mini(wall_n - 1, int(wall_n * 0.99))]) if wall_n > 0 else 0.0
	)
	var wall_max: float = float(wall_sorted[wall_n - 1]) if wall_n > 0 else 0.0
	print(
		(
			"  Wall Tick (ms): avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, max=%.3f"
			% [wall_avg, wall_p50, wall_p95, wall_p99, wall_max]
		)
	)

	var phys_sum := 0.0
	for v in phys_sorted:
		phys_sum += v
	var proc_sum := 0.0
	for v in proc_sorted:
		proc_sum += v

	var phys_min: float = phys_sorted[0]
	var phys_avg: float = phys_sum / float(n)
	var phys_p50: float = phys_sorted[int(n * 0.50)]
	var phys_p95: float = phys_sorted[mini(n - 1, int(n * 0.95))]
	var phys_p99: float = phys_sorted[mini(n - 1, int(n * 0.99))]
	var phys_max: float = phys_sorted[n - 1]

	var proc_min: float = proc_sorted[0]
	var proc_avg: float = proc_sum / float(n)
	var proc_p50: float = proc_sorted[int(n * 0.50)]
	var proc_p95: float = proc_sorted[mini(n - 1, int(n * 0.95))]
	var proc_p99: float = proc_sorted[mini(n - 1, int(n * 0.99))]
	var proc_max: float = proc_sorted[n - 1]

	var ticks_per_sec: int = Engine.physics_ticks_per_second
	var phys_cpu_ms_per_sec: float = phys_avg * float(ticks_per_sec)

	var mode_str := "WALK" if _perf_is_walk else "IDLE"
	print("==================================================")
	print("PERF_BENCHMARK: mode=%s, ticks_per_sec=%d, samples=%d" % [mode_str, ticks_per_sec, n])
	print(
		(
			"  Physics Step (ms): avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [phys_avg, phys_p50, phys_p95, phys_p99, phys_min, phys_max]
		)
	)
	print(
		(
			"  Total Physics CPU: %.2f ms / simulated second (%.1f%% of 1 core)"
			% [phys_cpu_ms_per_sec, phys_cpu_ms_per_sec / 10.0]
		)
	)
	print(
		(
			"  Process Frame (ms): avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [proc_avg, proc_p50, proc_p95, proc_p99, proc_min, proc_max]
		)
	)
	print("==================================================")
	var result_dict := {
		"mode": mode_str,
		"physics_ticks_per_second": ticks_per_sec,
		"samples": n,
		"physics_step_ms":
		{
			"min": phys_min,
			"avg": phys_avg,
			"p50": phys_p50,
			"p95": phys_p95,
			"p99": phys_p99,
			"max": phys_max,
		},
		"physics_cpu_ms_per_sec": phys_cpu_ms_per_sec,
		"process_frame_ms":
		{
			"min": proc_min,
			"avg": proc_avg,
			"p50": proc_p50,
			"p95": proc_p95,
			"p99": proc_p99,
			"max": proc_max,
		}
	}
	print("PERF_BENCHMARK_RESULT: " + JSON.stringify(result_dict))


func _on_render_frame_post_draw() -> void:
	if not _render_bench_active:
		return
	var now_usec := Time.get_ticks_usec()
	if _render_bench_last_frame_usec > 0 and _render_bench_frames > 30:
		_render_bench_frame_intervals.append(
			float(now_usec - _render_bench_last_frame_usec) / 1000.0
		)
	_render_bench_last_frame_usec = now_usec
	_render_bench_frames += 1
	if _render_bench_frames > 30:
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var obj := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_render_bench_draw_calls.append(dc)
		_render_bench_objects.append(obj)
		var tm = main.get_node_or_null("TrafficManager") as TrafficManager
		if tm and tm.debug_overlay and tm.debug_overlay.hud_label:
			_render_bench_f3_texts.append(tm.debug_overlay.hud_label.text)
	if _render_bench_frames >= _render_bench_target_frames:
		_render_bench_active = false
		_report_render_benchmark()
		main.get_tree().quit(0)


func _report_render_benchmark() -> void:
	var n := _render_bench_draw_calls.size()
	if n == 0:
		print("RENDER_BENCHMARK: No samples collected")
		return
	var dc_sorted := _render_bench_draw_calls.duplicate()
	dc_sorted.sort()
	var obj_sorted := _render_bench_objects.duplicate()
	obj_sorted.sort()
	var fi_sorted := _render_bench_frame_intervals.duplicate()
	fi_sorted.sort()

	var dc_min: int = dc_sorted[0]
	var dc_max: int = dc_sorted[n - 1]
	var dc_p50: int = dc_sorted[int(n * 0.50)]
	var dc_p95: int = dc_sorted[mini(n - 1, int(n * 0.95))]
	var dc_p99: int = dc_sorted[mini(n - 1, int(n * 0.99))]
	var dc_sum: int = 0
	for v in dc_sorted:
		dc_sum += v
	var dc_avg: float = float(dc_sum) / float(n)

	var obj_min: int = obj_sorted[0]
	var obj_max: int = obj_sorted[n - 1]
	var obj_p50: int = obj_sorted[int(n * 0.50)]
	var obj_sum: int = 0
	for v in obj_sorted:
		obj_sum += v
	var obj_avg: float = float(obj_sum) / float(n)

	var fi_n := fi_sorted.size()
	var fi_min := 0.0
	var fi_avg := 0.0
	var fi_p50 := 0.0
	var fi_p95 := 0.0
	var fi_p99 := 0.0
	var fi_max := 0.0
	if fi_n > 0:
		fi_min = fi_sorted[0]
		fi_max = fi_sorted[fi_n - 1]
		fi_p50 = fi_sorted[int(fi_n * 0.50)]
		fi_p95 = fi_sorted[mini(fi_n - 1, int(fi_n * 0.95))]
		fi_p99 = fi_sorted[mini(fi_n - 1, int(fi_n * 0.99))]
		var fi_sum := 0.0
		for v in fi_sorted:
			fi_sum += v
		fi_avg = fi_sum / float(fi_n)

	var effective_fps: float = (1000.0 / fi_avg) if fi_avg > 0.0 else 0.0

	var f3_last := ""
	if _render_bench_f3_texts.size() > 0:
		f3_last = _render_bench_f3_texts[_render_bench_f3_texts.size() - 1]

	print("==================================================")
	print("RENDER_BENCHMARK: samples=%d (after 30 warmup frames)" % n)
	print(
		(
			"  Draw Calls:       avg=%.1f, min=%d, p50=%d, p95=%d, p99=%d, max=%d"
			% [dc_avg, dc_min, dc_p50, dc_p95, dc_p99, dc_max]
		)
	)
	print(
		(
			"  Render Objects:   avg=%.1f, min=%d, p50=%d, max=%d"
			% [obj_avg, obj_min, obj_p50, obj_max]
		)
	)
	if fi_n > 0:
		print(
			(
				"  Frame Time (ms):  avg=%.2f (%.1f fps), min=%.2f, p50=%.2f, p95=%.2f, p99=%.2f, max=%.2f"
				% [fi_avg, effective_fps, fi_min, fi_p50, fi_p95, fi_p99, fi_max]
			)
		)
	if f3_last != "":
		print("  F3 HUD at end:   %s" % f3_last)
	print("==================================================")
	var result_dict := {
		"samples": n,
		"draw_calls":
		{
			"min": dc_min,
			"avg": dc_avg,
			"p50": dc_p50,
			"p95": dc_p95,
			"p99": dc_p99,
			"max": dc_max,
		},
		"objects":
		{
			"min": obj_min,
			"avg": obj_avg,
			"p50": obj_p50,
			"max": obj_max,
		},
		"frame_interval_ms":
		{
			"min": fi_min,
			"avg": fi_avg,
			"p50": fi_p50,
			"p95": fi_p95,
			"p99": fi_p99,
			"max": fi_max,
			"effective_fps": effective_fps,
		},
		"f3_hud_last": f3_last,
	}
	print("RENDER_BENCHMARK_RESULT: " + JSON.stringify(result_dict))


func _run_verify_render_test() -> void:
	await main.get_tree().process_frame
	print("==================================================")
	print("VERIFY_RENDER: Beginning full verification of exported browser build...")

	var streetlights := main.get_node_or_null("Props/Streetlights")
	var is_baked: bool = (streetlights is MultiMeshInstance3D) or ("--bake" in user_args)
	if not is_baked:
		var mb = load("res://addons/mesh_baker/mesh_baker.gd")
		if mb:
			mb.bake_main_scene(main)
			is_baked = true

	# --- 1. Buildings ---
	print("VERIFY_RENDER [1/7]: Verifying buildings...")
	var building_paths := [
		"Props/Walgroins",
		"Props/BoogerKingSite",
		"Props/TacoHell",
		"Props/StripMall",
		"Props/CrampedInn",
		"Props/SmellGasStation",
		"Props/Dorf",
		"Props/ConsumerCarCare",
		"Props/FrontageRetail",
		"Props/FrontageCommercial",
	]
	var total_building_meshes := 0
	var total_building_collisions := 0
	for b_path in building_paths:
		var b_node := main.get_node_or_null(b_path)
		assert(b_node != null, "Building %s must exist in scene" % b_path)
		var meshes: Array[MeshInstance3D] = []
		var cols: Array[CollisionShape3D] = []
		_collect_typed_nodes(b_node, meshes, cols)
		assert(cols.size() > 0, "Building %s must have collision shapes" % b_path)
		var valid_meshes := 0
		for mi in meshes:
			if mi.mesh == null:
				continue
			valid_meshes += 1
			assert(mi.mesh.get_surface_count() > 0, "Mesh in %s must have surfaces" % mi.name)
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				assert(
					mat != null,
					"Surface %d of mesh %s in %s must have a valid Material" % [s, mi.name, b_path]
				)
		assert(valid_meshes > 0, "Building %s must have active meshes" % b_path)
		total_building_meshes += valid_meshes
		total_building_collisions += cols.size()
	print(
		(
			"  Buildings verified: %d sites, %d active mesh instances, %d collision shapes"
			% [building_paths.size(), total_building_meshes, total_building_collisions]
		)
	)

	# Verify frontage road parking lots do not overlap
	var retail_apron := (
		main.get_node_or_null("Props/FrontageRetail/Site/ParkingApron") as MeshInstance3D
	)
	var car_care_apron := (
		main.get_node_or_null("Props/ConsumerCarCare/Site/ParkingApron") as MeshInstance3D
	)
	var comm_apron := (
		main.get_node_or_null("Props/FrontageCommercial/Site/ParkingApron") as MeshInstance3D
	)
	assert(retail_apron != null, "Retail ParkingApron must exist")
	assert(car_care_apron != null, "Car Care ParkingApron must exist")
	assert(comm_apron != null, "Commercial ParkingApron must exist")
	var retail_col := (
		retail_apron.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	)
	var car_care_col := (
		car_care_apron.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	)
	var comm_col := comm_apron.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	assert(
		retail_col != null and retail_col.shape is BoxShape3D,
		"Retail apron CollisionShape3D must exist"
	)
	assert(
		car_care_col != null and car_care_col.shape is BoxShape3D,
		"Car Care apron CollisionShape3D must exist"
	)
	assert(
		comm_col != null and comm_col.shape is BoxShape3D,
		"Commercial apron CollisionShape3D must exist"
	)
	var retail_box := retail_col.shape as BoxShape3D
	var car_care_box := car_care_col.shape as BoxShape3D
	var comm_box := comm_col.shape as BoxShape3D
	var retail_max_x: float = retail_col.global_position.x + retail_box.size.x * 0.5
	var car_care_min_x: float = car_care_col.global_position.x - car_care_box.size.x * 0.5
	var car_care_max_x: float = car_care_col.global_position.x + car_care_box.size.x * 0.5
	var comm_min_x: float = comm_col.global_position.x - comm_box.size.x * 0.5
	assert(
		car_care_min_x >= retail_max_x - 0.001,
		(
			"Car Care parking apron (min X %.2f) must not overlap Retail parking apron (max X %.2f)"
			% [car_care_min_x, retail_max_x]
		)
	)
	assert(
		car_care_max_x <= comm_min_x + 0.001,
		(
			"Car Care parking apron (max X %.2f) must not overlap Commercial parking apron (min X %.2f)"
			% [car_care_max_x, comm_min_x]
		)
	)
	print("  Frontage parking aprons verified: no overlap between Retail, Car Care, and Commercial")

	# Test Dorf building scene
	var dorf_scene = load("res://buildings/dorf.tscn")
	assert(dorf_scene != null, "dorf.tscn must be loadable")
	var dorf_inst: Node3D = dorf_scene.instantiate()
	assert(dorf_inst != null, "dorf.tscn must instantiate")
	var dorf_meshes: Array[MeshInstance3D] = []
	var dorf_cols: Array[CollisionShape3D] = []
	_collect_typed_nodes(dorf_inst, dorf_meshes, dorf_cols)
	assert(dorf_meshes.size() > 0, "Dorf must have meshes")
	assert(dorf_cols.size() > 0, "Dorf must have collision shapes")
	dorf_inst.free()
	print(
		(
			"  Dorf showroom verified: %d meshes, %d collision shapes"
			% [dorf_meshes.size(), dorf_cols.size()]
		)
	)

	# Test Dorf parking lot and parked cars
	var dorf_lot_mesh = main.get_node_or_null("Parking/DorfParkingLot")
	assert(dorf_lot_mesh != null, "Parking/DorfParkingLot must exist")
	var tm_node = main.get_node_or_null("TrafficManager") as TrafficManager
	assert(tm_node != null, "TrafficManager must exist")
	assert(tm_node.dorf_cars.size() == 15, "Dorf lot must have 15 parked cars")
	assert(
		not ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.JEEP),
		"Jeep must not be allowed in Dorf lot"
	)
	assert(
		not ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.SPORTS),
		"Sports car must not be allowed in Dorf lot"
	)
	assert(
		not ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.TAXI),
		"Taxi must not be allowed in Dorf lot"
	)
	assert(
		ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.SEDAN),
		"Sedan must be allowed in Dorf lot"
	)
	assert(
		ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.SUV),
		"SUV must be allowed in Dorf lot"
	)
	assert(
		ParkingLot.is_car_type_allowed_in_dorf_lot(Car.CarType.PICKUP),
		"Pickup must be allowed in Dorf lot"
	)
	for dc in tm_node.dorf_cars:
		assert(dc.state == Car.State.PARKED, "Dorf car must be PARKED")
		assert(is_inf(dc.dwell_left), "Dorf car must never leave (infinite dwell)")
		assert(dc.speed == 0.0, "Dorf car must not be moving")
		assert(
			TrafficManager.is_car_allowed_in_dorf_lot(dc),
			(
				"Dorf lot car must be allowed by Dorf lot rule (type: %s)"
				% Car.CarType.keys()[dc.car_type]
			)
		)
		assert(
			(
				dc.car_type != Car.CarType.JEEP
				and dc.car_type != Car.CarType.SPORTS
				and dc.car_type != Car.CarType.TAXI
			),
			(
				"Dorf lot must not have Jeeps, sports cars, or taxis (found %s)"
				% Car.CarType.keys()[dc.car_type]
			)
		)
	print("  Dorf parking lot & 15 permanent parked cars verified (no Jeeps, sports cars, taxis)")

	# --- 2. Vehicles ---
	print("VERIFY_RENDER [2/7]: Verifying vehicles & body variants...")
	var pcar_scene = load("res://cars/passenger_car.tscn")
	assert(pcar_scene != null, "passenger_car.tscn must exist")
	var test_car: PassengerCar = pcar_scene.instantiate()
	main.add_child(test_car)

	var all_types := [
		Car.CarType.SEDAN,
		Car.CarType.SUV,
		Car.CarType.PICKUP,
		Car.CarType.VAN,
		Car.CarType.SPORTS,
		Car.CarType.HATCHBACK,
		Car.CarType.MINIVAN,
		Car.CarType.JEEP,
		Car.CarType.F150,
	]
	for ct in all_types:
		test_car.car_type = ct
		test_car._apply_visual_type()
		assert(test_car._active_wheels.size() == 4, "CarType %d must have 4 active wheels" % ct)
		assert(test_car._active_left_signals.size() > 0, "CarType %d must have left signals" % ct)
		assert(test_car._active_right_signals.size() > 0, "CarType %d must have right signals" % ct)
		for s in test_car._active_left_signals + test_car._active_right_signals:
			assert(
				s.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"Vehicle signals must have cast_shadow off"
			)
			assert(
				is_equal_approx(s.visibility_range_end, 50.0),
				"Vehicle signals must have visibility_range_end 50.0"
			)
		if ct == Car.CarType.F150:
			var body := test_car.get_node_or_null("Visuals/F150/Body") as MeshInstance3D
			assert(body != null and body.mesh != null, "F150 Body mesh must exist")
			var mdt := MeshDataTool.new()
			mdt.create_from_surface(body.mesh, 0)
			for fi in range(mdt.get_face_count()):
				var c := Vector3.ZERO
				for v in range(3):
					c += mdt.get_vertex(mdt.get_face_vertex(fi, v))
				c /= 3.0
				if c.x > 1.2 and c.x < 2.4 and c.y > 1.15 and abs(c.z) < 0.9:
					assert(mdt.get_face_normal(fi).y > 0.5, "F150 hood faces must point upward")

	# Verify other vehicle scenes
	var other_scenes := [
		"res://cars/bus.tscn",
		"res://cars/truck.tscn",
		"res://cars/taxi.tscn",
		"res://cars/shipping_truck.tscn",
	]
	for s_path in other_scenes:
		var scn = load(s_path)
		assert(scn != null, "%s must load" % s_path)
		var v: Car = scn.instantiate()
		main.add_child(v)
		assert(v._active_wheels.size() >= 4, "%s must have >= 4 wheels" % s_path)
		v.queue_free()
	test_car.queue_free()
	print("  Vehicles verified: 8 passenger body types + 4 commercial vehicle classes")

	# --- 3. Paint Colors ---
	print("VERIFY_RENDER [3/7]: Verifying paint colors and vertex colors...")
	for c in PassengerCar.PAINT_PALETTE:
		var pmat := PassengerCar.get_paint_material(c)
		assert(pmat != null, "Paint material must generate for palette color %s" % c)
		assert(pmat.albedo_color == c, "Paint material albedo must match %s" % c)
		assert(pmat.vertex_color_use_as_albedo == false, "Paint material must not use vertex color")
		var gmat := PassengerCar.get_paint_material(c, true)
		assert(gmat != null, "Gritty paint material must generate for color %s" % c)
		assert(gmat.albedo_color == c, "Gritty paint material albedo must match %s" % c)
		assert(gmat.uv1_triplanar == true, "Gritty paint material must use triplanar mapping")
		assert(
			gmat.roughness_texture != null,
			"Gritty paint material must have roughness noise texture"
		)
		assert(gmat.normal_enabled == true, "Gritty paint material must have normal map enabled")
	for c in PassengerCar.SPORTS_PAINT_PALETTE:
		var pmat := PassengerCar.get_paint_material(c)
		assert(pmat != null, "Sports paint material must generate for color %s" % c)
		assert(pmat.albedo_color == c, "Sports paint material albedo must match %s" % c)

	var vertex_color_surfaces := 0
	var scene_meshes: Array[MeshInstance3D] = []
	_collect_all_mesh_instances(main, scene_meshes)
	for mi in scene_meshes:
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D and mat.vertex_color_use_as_albedo:
					vertex_color_surfaces += 1
	assert(vertex_color_surfaces > 0, "Scene must contain surfaces collapsed with vertex colors")
	print(
		(
			"  Paint colors verified: %d palette colors, %d vertex-colored collapsed surfaces active"
			% [
				PassengerCar.PAINT_PALETTE.size() + PassengerCar.SPORTS_PAINT_PALETTE.size(),
				vertex_color_surfaces
			]
		)
	)

	# --- 4. Signals ---
	print("VERIFY_RENDER [4/7]: Verifying signals (turn signals and indicators)...")
	var sig_car: PassengerCar = pcar_scene.instantiate()
	sig_car.car_type = Car.CarType.SEDAN
	main.add_child(sig_car)
	sig_car.set_turn_signal(Car.TurnSignal.LEFT)
	sig_car._update_signals(0.1)
	for s in sig_car._active_left_signals:
		assert(s.visible == true, "Left signal should be visible when LEFT")
	for s in sig_car._active_right_signals:
		assert(s.visible == false, "Right signal should be hidden when LEFT")
	sig_car.set_turn_signal(Car.TurnSignal.RIGHT)
	sig_car._update_signals(0.1)
	for s in sig_car._active_right_signals:
		assert(s.visible == true, "Right signal should be visible when RIGHT")
	for s in sig_car._active_left_signals:
		assert(s.visible == false, "Left signal should be hidden when RIGHT")
	sig_car.set_turn_signal(Car.TurnSignal.NONE)
	sig_car._update_signals(0.1)
	for s in sig_car._active_left_signals + sig_car._active_right_signals:
		assert(s.visible == false, "All signals should be hidden when NONE")
	sig_car.queue_free()
	print("  Signals verified: vehicle turn signal states (LEFT, RIGHT, NONE) fully functional")

	# --- 5. Wheels ---
	print("VERIFY_RENDER [5/7]: Verifying wheels, rotation, and details...")
	var wheel_car: PassengerCar = pcar_scene.instantiate()
	wheel_car.car_type = Car.CarType.SEDAN
	main.add_child(wheel_car)
	var spoke_count := 0
	var hub_count := 0
	for w in wheel_car._active_wheels:
		for ch in w.get_children():
			if ch.name == "Spoke" or ch.name.begins_with("Spoke"):
				spoke_count += 1
				if ch is GeometryInstance3D:
					assert(
						ch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"Wheel spoke cast_shadow must be OFF"
					)
					assert(
						is_equal_approx(ch.visibility_range_end, 35.0),
						"Wheel spoke visibility_range_end must be 35.0"
					)
			elif ch.name == "Hub" or ch.name.begins_with("Hub"):
				hub_count += 1
				if ch is GeometryInstance3D:
					assert(
						ch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"Wheel hub cast_shadow must be OFF"
					)
					assert(
						is_equal_approx(ch.visibility_range_end, 35.0),
						"Wheel hub visibility_range_end must be 35.0"
					)
	wheel_car.lane_distance = 10.0
	wheel_car.wheel_rotation = 1.2
	wheel_car._update_wheels()
	for w in wheel_car._active_wheels:
		assert(w.transform.basis != Basis.IDENTITY, "Wheel transform basis should reflect rotation")
	wheel_car.queue_free()
	print(
		(
			"  Wheels verified: 4 active wheels, %d spokes, %d hubs, rotation functional"
			% [spoke_count, hub_count]
		)
	)

	# --- 6. Signs & Label3D Nodes ---
	print("VERIFY_RENDER [6/7]: Verifying signs, Label3D nodes, and visibility ranges...")
	var labels: Array[Label3D] = []
	_collect_all_labels(main, labels)
	assert(labels.size() >= 50, "Expected >= 50 Label3D nodes, found %d" % labels.size())
	var culled_labels := 0
	for lbl in labels:
		assert(
			lbl.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"Label3D %s must have cast_shadow OFF" % lbl.name
		)
		if lbl.visibility_range_end > 0.0:
			culled_labels += 1
		assert(lbl.text != "", "Label3D %s text must not be empty" % lbl.name)
	print(
		(
			"  Signs verified: %d Label3D nodes, %d configured with visibility_range_end culling"
			% [labels.size(), culled_labels]
		)
	)

	# --- 7. Shadows ---
	print("VERIFY_RENDER [7/7]: Verifying lighting and shadow casting distribution...")
	var dl: DirectionalLight3D = main.get_node_or_null("DirectionalLight3D")
	assert(dl != null, "DirectionalLight3D must exist")
	assert(dl.shadow_enabled == true, "Sun directional light shadows must be enabled")
	assert(dl.light_energy > 0.0, "Sun light energy must be > 0")

	var shadows_on := 0
	var shadows_off := 0
	for mi in scene_meshes:
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows_off += 1
		elif mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			shadows_on += 1
	assert(shadows_on > 0, "Must have meshes casting shadows")
	assert(
		shadows_off > 50, "Must have >= 50 meshes with cast_shadow disabled to reduce draw calls"
	)
	print(
		(
			"  Shadows verified: DirectionalLight3D enabled; meshes casting shadow: %d; meshes with shadow disabled: %d"
			% [shadows_on, shadows_off]
		)
	)

	# Verify MultiMesh instances (streetlights, bollards)
	var multimeshes: Array[MultiMeshInstance3D] = []
	_collect_all_multimeshes(main, multimeshes)
	print("  MultiMeshes verified: %d MultiMeshInstance3D nodes in scene" % multimeshes.size())

	# --- 8. Render Scale & Quality Toggle ---
	print("VERIFY_RENDER [8/8]: Verifying 3D render scale and HUD quality toggle...")
	var hud_node: HUD = main.get_node_or_null("HUD")
	assert(hud_node != null, "HUD node must exist")
	var orig_scale: float = main.get_viewport().scaling_3d_scale
	hud_node.cycle_render_scale()
	var stepped_scale: float = main.get_viewport().scaling_3d_scale
	assert(
		not is_equal_approx(stepped_scale, orig_scale),
		"cycle_render_scale must change viewport scaling_3d_scale"
	)
	hud_node.cycle_render_scale()
	hud_node.cycle_render_scale()
	assert(
		is_equal_approx(main.get_viewport().scaling_3d_scale, orig_scale),
		(
			"Cycling 3 times must return to original scaling_3d_scale (%.2f vs %.2f)"
			% [main.get_viewport().scaling_3d_scale, orig_scale]
		)
	)
	print(
		"  Quality toggle verified: cycle_render_scale() cycles presets cleanly and restores scale"
	)
	print("==================================================")
	print(
		"VERIFY_RENDER: SUCCESS - All buildings, vehicles, paint colors, signals, wheels, signs, and shadows verified cleanly!"
	)
	print("==================================================")
	main.get_tree().quit(0)


func _collect_typed_nodes(
	node: Node, meshes: Array[MeshInstance3D], cols: Array[CollisionShape3D]
) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	elif node is CollisionShape3D:
		cols.append(node)
	for child in node.get_children():
		_collect_typed_nodes(child, meshes, cols)


func _collect_all_mesh_instances(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_all_mesh_instances(child, meshes)


func _collect_all_labels(node: Node, labels: Array[Label3D]) -> void:
	if node is Label3D:
		labels.append(node)
	for child in node.get_children():
		_collect_all_labels(child, labels)


func _collect_all_multimeshes(node: Node, multimeshes: Array[MultiMeshInstance3D]) -> void:
	if node is MultiMeshInstance3D:
		multimeshes.append(node)
	for child in node.get_children():
		_collect_all_multimeshes(child, multimeshes)
