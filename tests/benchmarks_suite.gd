class_name BenchmarksSuite
extends TestSuite

var _perf_target_frames: int = 0
var _perf_frames: int = 0
var _perf_is_walk: bool = false
var _perf_walk_dir: float = 1.0
var _perf_phys_samples: Array[float] = []
var _perf_phys_script_samples: Array[float] = []
var _perf_phys_server_samples: Array[float] = []
var _perf_proc_samples: Array[float] = []
var _perf_physics_tick_start_usec: int = 0
var _perf_physics_probe_usec: int = 0
var _perf_process_frame_start_usec: int = 0
var _perf_last_tick_usec: int = 0
var _perf_wall_samples: Array[float] = []


class PhysicsBenchmarkProbe:
	extends Node
	var suite: BenchmarksSuite

	func _physics_process(_delta: float) -> void:
		suite._on_probe_physics_process()

	func _process(_delta: float) -> void:
		suite._on_probe_process()


var _render_bench_active: bool = false
var _render_bench_target_frames: int = 240
var _render_bench_frames: int = 0
var _render_bench_draw_calls: Array[int] = []
var _render_bench_objects: Array[int] = []
var _render_bench_frame_intervals: Array[float] = []
var _render_bench_last_frame_usec: int = 0
var _render_bench_f3_texts: Array[String] = []

var _gameplay_bench_active: bool = false
var _gameplay_phase_target_sec: float = 20.0
var _gameplay_current_phase: int = 0
var _gameplay_phase_start_usec: int = 0
var _gameplay_last_frame_usec: int = 0
var _gameplay_frame_physics_script_ms: float = 0.0
var _gameplay_prev_cars_spawned: int = 0
var _gameplay_phase_data: Dictionary = {}


func matches_args() -> bool:
	for arg in user_args:
		if (
			arg
			in [
				"--bench-physics",
				"--bench-physics-walk",
				"--bench-render",
				"--bench-gameplay",
				"--bench-gameplay-compat",
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

		var probe := PhysicsBenchmarkProbe.new()
		probe.name = "PhysicsBenchmarkProbe"
		probe.suite = self
		probe.process_physics_priority = 1 << 30
		probe.process_priority = 1 << 30
		main.add_child(probe)
		main.get_tree().physics_frame.connect(_on_physics_frame_stamp)
		main.get_tree().process_frame.connect(_on_process_frame_stamp)
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

	if "--bench-gameplay" in user_args or "--bench-gameplay-compat" in user_args:
		_gameplay_bench_active = true
		main.set_physics_process(true)
		main.get_tree().paused = false
		for arg in user_args:
			if arg.begins_with("--duration="):
				_gameplay_phase_target_sec = float(arg.substr(11))
		_gameplay_phase_data = {
			"day":
			{
				"frame_count": 0,
				"frame_intervals": [] as Array[float],
				"draw_calls": [] as Array[int],
				"objects": [] as Array[int],
				"spikes": [],
			},
			"night":
			{
				"frame_count": 0,
				"frame_intervals": [] as Array[float],
				"draw_calls": [] as Array[int],
				"objects": [] as Array[int],
				"spikes": [],
			},
		}
		var probe := PhysicsBenchmarkProbe.new()
		probe.name = "PhysicsBenchmarkProbe"
		probe.suite = self
		probe.process_physics_priority = 1 << 30
		probe.process_priority = 1 << 30
		main.add_child(probe)
		main.get_tree().physics_frame.connect(_on_physics_frame_stamp)
		main.get_tree().process_frame.connect(_on_process_frame_stamp)
		if "--bake" in user_args or "--bench-gameplay-compat" in user_args:
			var mb = load("res://addons/mesh_baker/mesh_baker.gd")
			if mb:
				mb.bake_main_scene(main)
		RenderingServer.frame_post_draw.connect(_on_gameplay_frame_post_draw)

	if "--test-verify-render" in user_args:
		_run_verify_render_test()


func _record_physics_server_step(now_usec: int) -> void:
	if _perf_physics_probe_usec > 0:
		var server_ms := float(now_usec - _perf_physics_probe_usec) / 1000.0
		if _perf_frames > 60:
			_perf_phys_server_samples.append(server_ms)
			var script_ms := 0.0
			if _perf_phys_script_samples.size() > 0:
				script_ms = _perf_phys_script_samples[_perf_phys_script_samples.size() - 1]
			_perf_phys_samples.append(script_ms + server_ms)
		_perf_physics_probe_usec = 0
		if _perf_target_frames > 0 and _perf_frames >= _perf_target_frames:
			_report_perf_benchmark()
			main.get_tree().quit(0)


func _on_physics_frame_stamp() -> void:
	var now_usec := Time.get_ticks_usec()
	_record_physics_server_step(now_usec)
	_perf_physics_tick_start_usec = now_usec
	if _perf_last_tick_usec > 0 and _perf_frames >= 60:
		_perf_wall_samples.append(float(now_usec - _perf_last_tick_usec) / 1000.0)
	_perf_last_tick_usec = now_usec


func _on_process_frame_stamp() -> void:
	var now_usec := Time.get_ticks_usec()
	_record_physics_server_step(now_usec)
	_perf_process_frame_start_usec = now_usec


func _on_probe_physics_process() -> void:
	var now_usec := Time.get_ticks_usec()
	_perf_physics_probe_usec = now_usec
	var script_ms := float(now_usec - _perf_physics_tick_start_usec) / 1000.0
	if _perf_frames > 60:
		_perf_phys_script_samples.append(script_ms)
	if _gameplay_bench_active:
		_gameplay_frame_physics_script_ms += script_ms


func _on_probe_process() -> void:
	if _perf_frames > 60:
		var proc_ms := float(Time.get_ticks_usec() - _perf_process_frame_start_usec) / 1000.0
		_perf_proc_samples.append(proc_ms)


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


static func _compute_stats(samples_sorted: Array[float]) -> Dictionary:
	var count := samples_sorted.size()
	if count == 0:
		return {"min": 0.0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sum := 0.0
	for v in samples_sorted:
		sum += v
	return {
		"min": samples_sorted[0],
		"avg": sum / float(count),
		"p50": samples_sorted[int(count * 0.50)],
		"p95": samples_sorted[mini(count - 1, int(count * 0.95))],
		"p99": samples_sorted[mini(count - 1, int(count * 0.99))],
		"max": samples_sorted[count - 1],
	}


func _report_perf_benchmark() -> void:
	var phys_sorted := _perf_phys_samples.duplicate()
	phys_sorted.sort()
	var script_sorted := _perf_phys_script_samples.duplicate()
	script_sorted.sort()
	var server_sorted := _perf_phys_server_samples.duplicate()
	server_sorted.sort()
	var proc_sorted := _perf_proc_samples.duplicate()
	proc_sorted.sort()
	var wall_sorted := _perf_wall_samples.duplicate()
	wall_sorted.sort()

	var n: int = phys_sorted.size()
	if n == 0:
		print("PERF_BENCHMARK: No samples collected")
		return

	var phys_stats := _compute_stats(phys_sorted)
	var script_stats := _compute_stats(script_sorted)
	var server_stats := _compute_stats(server_sorted)
	var proc_stats := _compute_stats(proc_sorted)
	var wall_stats := _compute_stats(wall_sorted)

	print(
		(
			"  Wall Tick (ms): avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, max=%.3f"
			% [wall_stats.avg, wall_stats.p50, wall_stats.p95, wall_stats.p99, wall_stats.max]
		)
	)

	var ticks_per_sec: int = Engine.physics_ticks_per_second
	var phys_cpu_ms_per_sec: float = phys_stats.avg * float(ticks_per_sec)

	var mode_str := "WALK" if _perf_is_walk else "IDLE"
	print("==================================================")
	print("PERF_BENCHMARK: mode=%s, ticks_per_sec=%d, samples=%d" % [mode_str, ticks_per_sec, n])
	print(
		(
			"  Physics Step (ms):   avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [
				phys_stats.avg,
				phys_stats.p50,
				phys_stats.p95,
				phys_stats.p99,
				phys_stats.min,
				phys_stats.max
			]
		)
	)
	print(
		(
			"    Physics Script:    avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [
				script_stats.avg,
				script_stats.p50,
				script_stats.p95,
				script_stats.p99,
				script_stats.min,
				script_stats.max
			]
		)
	)
	print(
		(
			"    Physics Server:    avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [
				server_stats.avg,
				server_stats.p50,
				server_stats.p95,
				server_stats.p99,
				server_stats.min,
				server_stats.max
			]
		)
	)
	print(
		(
			"  Total Physics CPU:   %.2f ms / simulated second (%.1f%% of 1 core)"
			% [phys_cpu_ms_per_sec, phys_cpu_ms_per_sec / 10.0]
		)
	)
	print(
		(
			"  Process Frame (ms):  avg=%.3f, p50=%.3f, p95=%.3f, p99=%.3f, min=%.3f, max=%.3f"
			% [
				proc_stats.avg,
				proc_stats.p50,
				proc_stats.p95,
				proc_stats.p99,
				proc_stats.min,
				proc_stats.max
			]
		)
	)
	print("==================================================")
	var result_dict := {
		"mode": mode_str,
		"physics_ticks_per_second": ticks_per_sec,
		"samples": n,
		"physics_step_ms": phys_stats,
		"physics_script_ms": script_stats,
		"physics_server_ms": server_stats,
		"physics_cpu_ms_per_sec": phys_cpu_ms_per_sec,
		"process_frame_ms": proc_stats,
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


func _on_gameplay_frame_post_draw() -> void:
	if not _gameplay_bench_active:
		return
	var now_usec := Time.get_ticks_usec()
	if _gameplay_last_frame_usec == 0:
		_gameplay_last_frame_usec = now_usec
		_gameplay_phase_start_usec = now_usec
		if main.traffic_manager and "cars_spawned" in main.traffic_manager.stats:
			_gameplay_prev_cars_spawned = int(main.traffic_manager.stats["cars_spawned"])
		return

	var fi_ms := float(now_usec - _gameplay_last_frame_usec) / 1000.0
	_gameplay_last_frame_usec = now_usec

	var current_cars_spawned: int = 0
	if main.traffic_manager and "cars_spawned" in main.traffic_manager.stats:
		current_cars_spawned = int(main.traffic_manager.stats["cars_spawned"])
	var cars_spawned := current_cars_spawned - _gameplay_prev_cars_spawned
	_gameplay_prev_cars_spawned = current_cars_spawned

	var script_ms := _gameplay_frame_physics_script_ms
	_gameplay_frame_physics_script_ms = 0.0

	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var obj := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var phase_name := "day" if _gameplay_current_phase == 0 else "night"
	var phase_dict: Dictionary = _gameplay_phase_data[phase_name]
	phase_dict["frame_count"] += 1
	var frame_idx: int = phase_dict["frame_count"]

	(phase_dict["frame_intervals"] as Array[float]).append(fi_ms)
	(phase_dict["draw_calls"] as Array[int]).append(dc)
	(phase_dict["objects"] as Array[int]).append(obj)

	if fi_ms > 25.0:
		var spike_info := {
			"phase": phase_name,
			"frame": frame_idx,
			"interval_ms": fi_ms,
			"physics_script_ms": script_ms,
			"cars_spawned": cars_spawned,
		}
		(phase_dict["spikes"] as Array).append(spike_info)
		print(
			(
				"[SPIKE] phase=%s frame=%d: %.2f ms (> 25 ms), physics_script=%.2f ms, cars_spawned=%d"
				% [phase_name, frame_idx, fi_ms, script_ms, cars_spawned]
			)
		)

	var phase_elapsed_sec := float(now_usec - _gameplay_phase_start_usec) / 1_000_000.0
	if phase_elapsed_sec >= _gameplay_phase_target_sec:
		if _gameplay_current_phase == 0:
			print(
				(
					"GAMEPLAY_BENCHMARK: Completed Day phase (%d frames, %.2f s). Transitioning to Night..."
					% [phase_dict["frame_count"], phase_elapsed_sec]
				)
			)
			# Hold the clock at night so the day-end summary can't pause the benchmark.
			GameState.set_time_hours(GameState.NIGHT_HOUR)
			GameState.time_paused = true
			_gameplay_current_phase = 1
			_gameplay_phase_start_usec = Time.get_ticks_usec()
			_gameplay_frame_physics_script_ms = 0.0
		else:
			print(
				(
					"GAMEPLAY_BENCHMARK: Completed Night phase (%d frames, %.2f s)."
					% [phase_dict["frame_count"], phase_elapsed_sec]
				)
			)
			_gameplay_bench_active = false
			_report_gameplay_benchmark()
			main.get_tree().quit(0)


func _report_gameplay_benchmark() -> void:
	print("==================================================")
	print("GAMEPLAY BENCHMARK REPORT (target %.1f s per phase)" % _gameplay_phase_target_sec)
	var summary_results := {}

	for phase_name in ["day", "night"]:
		var pdata: Dictionary = _gameplay_phase_data[phase_name]
		var fi_list: Array[float] = pdata["frame_intervals"]
		var dc_list: Array[int] = pdata["draw_calls"]
		var obj_list: Array[int] = pdata["objects"]
		var n: int = fi_list.size()

		if n == 0:
			print("  Phase %s: No frames recorded" % phase_name.to_upper())
			continue

		var fi_sorted := fi_list.duplicate()
		fi_sorted.sort()
		var dc_sorted := dc_list.duplicate()
		dc_sorted.sort()
		var obj_sorted := obj_list.duplicate()
		obj_sorted.sort()

		var fi_min: float = fi_sorted[0]
		var fi_max: float = fi_sorted[n - 1]
		var fi_p50: float = fi_sorted[int(n * 0.50)]
		var fi_p95: float = fi_sorted[mini(n - 1, int(n * 0.95))]
		var fi_p99: float = fi_sorted[mini(n - 1, int(n * 0.99))]
		var fi_sum: float = 0.0
		var count_gt_20: int = 0
		var count_gt_33: int = 0
		for v in fi_sorted:
			fi_sum += v
			if v > 20.0:
				count_gt_20 += 1
			if v > 33.0:
				count_gt_33 += 1
		var fi_avg: float = fi_sum / float(n)
		var pct_gt_20: float = (float(count_gt_20) / float(n)) * 100.0
		var pct_gt_33: float = (float(count_gt_33) / float(n)) * 100.0
		var effective_fps: float = (1000.0 / fi_avg) if fi_avg > 0.0 else 0.0

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
		var obj_p95: int = obj_sorted[mini(n - 1, int(n * 0.95))]
		var obj_p99: int = obj_sorted[mini(n - 1, int(n * 0.99))]
		var obj_sum: int = 0
		for v in obj_sorted:
			obj_sum += v
		var obj_avg: float = float(obj_sum) / float(n)
		var spikes: Array = pdata["spikes"]

		print("--------------------------------------------------")
		print("PHASE: %s (frames=%d)" % [phase_name.to_upper(), n])
		print(
			(
				"  Frame Interval (ms): avg=%.2f (%.1f fps), min=%.2f, p50=%.2f, p95=%.2f, p99=%.2f, max=%.2f"
				% [fi_avg, effective_fps, fi_min, fi_p50, fi_p95, fi_p99, fi_max]
			)
		)
		print("  Frames > 20 ms:      %d (%.2f%%)" % [count_gt_20, pct_gt_20])
		print("  Frames > 33 ms:      %d (%.2f%%)" % [count_gt_33, pct_gt_33])
		print(
			(
				"  Draw Calls:          avg=%.1f, min=%d, p50=%d, p95=%d, p99=%d, max=%d"
				% [dc_avg, dc_min, dc_p50, dc_p95, dc_p99, dc_max]
			)
		)
		print(
			(
				"  Render Objects:      avg=%.1f, min=%d, p50=%d, p95=%d, p99=%d, max=%d"
				% [obj_avg, obj_min, obj_p50, obj_p95, obj_p99, obj_max]
			)
		)
		print("  Spikes (> 25 ms):    %d" % spikes.size())
		for s in spikes:
			print(
				(
					"    frame %d: %.2f ms, physics_script=%.2f ms, cars_spawned=%d"
					% [s["frame"], s["interval_ms"], s["physics_script_ms"], s["cars_spawned"]]
				)
			)

		summary_results[phase_name] = {
			"frames": n,
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
			"pct_gt_20ms": pct_gt_20,
			"pct_gt_33ms": pct_gt_33,
			"count_gt_20ms": count_gt_20,
			"count_gt_33ms": count_gt_33,
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
				"p95": obj_p95,
				"p99": obj_p99,
				"max": obj_max,
			},
			"spikes": spikes,
		}

	print("==================================================")
	print("GAMEPLAY_BENCHMARK_RESULT: " + JSON.stringify(summary_results))


func _run_verify_render_test() -> void:
	await main.get_tree().process_frame
	var streetlights := main.get_node_or_null("Props/Streetlights")
	if not streetlights.has_node("BakedMultiMesh"):
		load("res://addons/mesh_baker/mesh_baker.gd").bake_main_scene(main)
	var baked_streetlights := streetlights.get_node_or_null("BakedMultiMesh") as MultiMeshInstance3D
	assert(
		baked_streetlights != null and baked_streetlights.multimesh != null,
		"Props/Streetlights/BakedMultiMesh must exist with MultiMesh"
	)
	for child in streetlights.get_children():
		if child is MultiMeshInstance3D:
			continue
		assert(
			child.get_node_or_null("CollisionShape3D") != null,
			"Streetlight pole collision shape must remain intact after baking"
		)
		assert(
			child.get_node_or_null("Light") != null,
			"Streetlight SpotLight3D must remain intact after baking"
		)
	for building in [
		"Walgroins",
		"BoogerKingSite",
		"TacoHell",
		"StripMall",
		"CrampedInn",
		"SmellGasStation",
		"Dorf"
	]:
		var b_node := main.get_node("Props/" + building)
		assert(
			not b_node.find_children("*", "CollisionShape3D", true, false).is_empty(),
			"Building %s must keep its collision after baking" % building
		)

	if main.environment_controller:
		main.environment_controller.update_streetlights(true)
		assert(
			baked_streetlights.multimesh.mesh != null,
			"Baked streetlights mesh must not be null when lights on"
		)
		var has_lit_surface := false
		for s in range(baked_streetlights.multimesh.mesh.get_surface_count()):
			var mat = baked_streetlights.multimesh.mesh.surface_get_material(s)
			if mat is StandardMaterial3D and mat.emission_enabled:
				has_lit_surface = true
				break
		assert(
			has_lit_surface, "Baked streetlights mesh must have an emissive surface when lights on"
		)
		for child in streetlights.get_children():
			if child is MultiMeshInstance3D:
				continue
			var light := child.get_node_or_null("Light") as SpotLight3D
			assert(
				light != null and light.visible,
				"Streetlight SpotLight3D must be visible when lights on"
			)

		main.environment_controller.update_streetlights(false)
		var has_lit_surface_off := false
		for s in range(baked_streetlights.multimesh.mesh.get_surface_count()):
			var mat = baked_streetlights.multimesh.mesh.surface_get_material(s)
			if mat is StandardMaterial3D and mat.emission_enabled:
				has_lit_surface_off = true
				break
		assert(
			not has_lit_surface_off,
			"Baked streetlights mesh must not have an emissive surface when lights off"
		)
		for child in streetlights.get_children():
			if child is MultiMeshInstance3D:
				continue
			var light := child.get_node_or_null("Light") as SpotLight3D
			assert(
				light != null and not light.visible,
				"Streetlight SpotLight3D must be off when lights off"
			)
	print("VERIFY_RENDER: SUCCESS - baked streetlights keep collision and toggle with time of day")
	main.get_tree().quit(0)
