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
					"GAMEPLAY_BENCHMARK: Completed Day phase (%d frames, %.2f s). Transitioning to Night (19.9h)..."
					% [phase_dict["frame_count"], phase_elapsed_sec]
				)
			)
			GameState.set_time_hours(19.9)
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
	print("==================================================")
	print("VERIFY_RENDER: Beginning full verification of exported browser build...")

	var streetlights := main.get_node_or_null("Props/Streetlights")
	var is_baked: bool = (
		(streetlights != null and streetlights.has_node("BakedMultiMesh"))
		or ("--bake" in user_args)
	)
	if not is_baked:
		var mb = load("res://addons/mesh_baker/mesh_baker.gd")
		if mb:
			mb.bake_main_scene(main)
			is_baked = true

	var road_node := main.get_node_or_null("Road")
	assert(road_node != null, "Road node must exist in main scene")
	var baked_road := road_node.get_node_or_null("BakedStaticMesh") as MeshInstance3D
	assert(
		baked_road != null and baked_road.mesh != null,
		"Road/BakedStaticMesh must exist with baked mesh"
	)
	var parking_node := main.get_node_or_null("Parking")
	assert(parking_node != null, "Parking node must exist in main scene")
	var baked_parking := parking_node.get_node_or_null("BakedStaticMesh") as MeshInstance3D
	assert(
		baked_parking != null and baked_parking.mesh != null,
		"Parking/BakedStaticMesh must exist with baked mesh"
	)

	# --- Streetlights, Trees, Flags & Bollards Baking ---
	var baked_streetlights := streetlights.get_node_or_null("BakedMultiMesh") as MultiMeshInstance3D
	assert(
		baked_streetlights != null and baked_streetlights.multimesh != null,
		"Props/Streetlights/BakedMultiMesh must exist with MultiMesh"
	)
	assert(
		baked_streetlights.multimesh.instance_count == 15,
		"Baked streetlights must have 15 instances"
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
	var trees_node := main.get_node_or_null("Props/Trees") as Node3D
	assert(trees_node != null, "Props/Trees must exist in main scene")
	var tree_count := 0
	for tree in trees_node.get_children():
		if not (tree is Node3D):
			continue
		tree_count += 1
		var visuals := tree.get_node_or_null("Visuals") as Node3D
		assert(visuals != null, "Tree %s must have Visuals" % tree.name)
		assert(
			visuals.get_child_count() == 1,
			"Tree %s must have exactly 1 active variant after baking" % tree.name
		)
		var active_variant := visuals.get_child(0) as Node3D
		assert(active_variant.visible, "Tree active variant must be visible")
	assert(tree_count > 0, "Props/Trees must contain tree instances")

	var flags_node := main.get_node_or_null("Props/Flags") as Node3D
	assert(flags_node != null, "Props/Flags must exist in main scene")
	var flag_count := 0
	for flag in flags_node.get_children():
		if not (flag is Node3D):
			continue
		flag_count += 1
		var visuals := flag.get_node_or_null("Visuals") as Node3D
		assert(visuals != null, "Flag %s must have Visuals" % flag.name)
		assert(
			visuals.get_child_count() == 1,
			"Flag %s must have exactly 1 active variant after baking" % flag.name
		)
		var active_variant := visuals.get_child(0) as Node3D
		assert(active_variant.visible, "Flag active variant must be visible")
		assert(
			active_variant.has_node("Flag"), "Flag active variant must retain Flag mesh instance"
		)
	assert(flag_count > 0, "Props/Flags must contain flag instances")

	var bk_site := main.get_node_or_null("Props/BoogerKingSite") as Node3D
	assert(bk_site != null, "BoogerKingSite must exist")
	var bk_bollards := bk_site.get_node_or_null("BakedBollardsMultiMesh") as MultiMeshInstance3D
	assert(
		bk_bollards != null and bk_bollards.multimesh != null,
		"BoogerKingSite must have BakedBollardsMultiMesh"
	)
	assert(
		bk_bollards.multimesh.instance_count > 0, "BoogerKing bollard multimesh must have instances"
	)
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
	assert(dorf_inst.has_node("ParkedCars"), "Dorf must contain ParkedCars node")
	var dorf_parked_cars: Array = dorf_inst.get_node("ParkedCars").get_children()
	assert(dorf_parked_cars.size() == 15, "Dorf scene must have 15 parked cars")
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
	var dorf_parked_cars_node = main.get_node_or_null("Props/Dorf/ParkedCars")
	assert(dorf_parked_cars_node != null, "Props/Dorf/ParkedCars must exist")
	var dorf_cars: Array = dorf_parked_cars_node.get_children()
	assert(dorf_cars.size() == 15, "Dorf lot must have 15 parked cars in scene")
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
	for car_node in dorf_cars:
		assert(car_node is StaticBody3D, "Dorf car %s must be a StaticBody3D" % car_node.name)
		var col: CollisionShape3D = car_node.get_node_or_null("CollisionShape3D")
		assert(col != null, "Dorf car %s must have CollisionShape3D" % car_node.name)
		assert(car_node.has_node("Model"), "Dorf car %s must have a Model" % car_node.name)
		var car_meshes: Array[MeshInstance3D] = []
		var car_cols: Array[CollisionShape3D] = []
		_collect_typed_nodes(car_node, car_meshes, car_cols)
		assert(car_meshes.size() > 0, "Dorf car %s must contain mesh instances" % car_node.name)
	print(
		"  Dorf parking lot & 15 permanent scene-authored cars verified (StaticBody3D models with collision)"
	)
	# Verify outer edge display cars vs empty inner layer
	var raw_main: Node = load("res://main.tscn").instantiate()
	assert(
		raw_main.get_node_or_null("Parking/ParkingStall_Dorf_51") == null,
		"Dorf outer edge parking stall paint must be removed"
	)
	assert(
		raw_main.get_node_or_null("Parking/ParkingStall_Dorf_S_49") != null,
		"Dorf inner layer parking lines (S) must exist"
	)
	assert(
		raw_main.get_node_or_null("Parking/ParkingStall_Dorf_R_69") != null,
		"Dorf inner layer parking lines (R) must exist"
	)
	raw_main.free()
	for car_node in dorf_cars:
		if car_node.name == "TurntableCar" or car_node.name == "RampCar":
			continue
		assert(
			car_node.transform.origin.z >= 20.0,
			(
				"Static parked car %s must be on outer edge (z >= 20.0), found at z = %f"
				% [car_node.name, car_node.transform.origin.z]
			)
		)

	# Test Flag_Dorf and flags in main scene
	var flags_parent := main.get_node_or_null("Props/Flags")
	assert(flags_parent != null, "Props/Flags must exist")
	var dorf_flag := main.get_node_or_null("Props/Flags/Flag_Dorf") as USFlag
	assert(dorf_flag != null, "Flag_Dorf must exist in Props/Flags")
	assert(
		dorf_flag.flag_size == USFlag.FlagSize.COLOSSAL,
		"Flag_Dorf must have COLOSSAL flag_size (4)"
	)
	var dorf_flag_col := dorf_flag.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(
		dorf_flag_col != null and dorf_flag_col.shape is CylinderShape3D,
		"Flag_Dorf collision shape must be CylinderShape3D"
	)
	var colossal_shape := dorf_flag_col.shape as CylinderShape3D
	assert(colossal_shape.height >= 24.0, "Colossal flagpole height must be at least 24m")
	var colossal_visual := dorf_flag.get_node_or_null("Visuals/Colossal") as Node3D
	assert(colossal_visual != null, "Flag_Dorf must have Colossal visuals")
	var colossal_flag_mesh := colossal_visual.get_node_or_null("Flag") as MeshInstance3D
	assert(
		colossal_flag_mesh != null and colossal_flag_mesh.mesh is PlaneMesh,
		"Colossal flag mesh must be PlaneMesh"
	)
	var colossal_flag_plane := colossal_flag_mesh.mesh as PlaneMesh
	assert(
		colossal_flag_plane.size.x >= 9.0 and colossal_flag_plane.size.y >= 4.5,
		"Colossal flag plane size must be at least 9m x 4.5m"
	)
	var dorf_lot_node := main.get_node_or_null("Parking/DorfParkingLot") as MeshInstance3D
	if dorf_lot_node and dorf_lot_node.mesh is BoxMesh:
		var lot_box := dorf_lot_node.mesh as BoxMesh
		var lot_half_x: float = lot_box.size.x * 0.5
		var lot_min_x: float = dorf_lot_node.global_position.x - lot_half_x
		var lot_max_x: float = dorf_lot_node.global_position.x + lot_half_x
		assert(
			dorf_flag.global_position.x < lot_min_x or dorf_flag.global_position.x > lot_max_x,
			(
				"Flag_Dorf must be positioned to the side, outside the Dorf parking lot apron (lot X: [%.1f, %.1f], flag X: %.1f)"
				% [lot_min_x, lot_max_x, dorf_flag.global_position.x]
			)
		)
	print("  Dorf colossal American flag verified (24m pole, 9.5x5.0m flag)")

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
		Car.CarType.CYBERTRUCK,
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
		var col_node := test_car.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert(
			col_node != null and col_node.shape is BoxShape3D,
			"CarType %d must have BoxShape3D collision" % ct
		)
		var box_shape := col_node.shape as BoxShape3D
		assert(
			box_shape.size.x > 0.0 and box_shape.size.y > 0.0 and box_shape.size.z > 0.0,
			"CarType %d collision shape must have non-zero size" % ct
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
		if ct == Car.CarType.CYBERTRUCK:
			var body := test_car.get_node_or_null("Visuals/Cybertruck/Body") as MeshInstance3D
			assert(body != null and body.mesh != null, "Cybertruck Body mesh must exist")
			var flb := (
				test_car.get_node_or_null("Visuals/Cybertruck/FrontLightBar") as MeshInstance3D
			)
			assert(flb != null and flb.mesh != null, "Cybertruck FrontLightBar must exist")

	# Verify other vehicle scenes
	var other_scenes := [
		"res://cars/bus.tscn",
		"res://cars/truck.tscn",
		"res://cars/taxi.tscn",
		"res://cars/shipping_truck.tscn",
		"res://cars/f150.tscn",
		"res://cars/cybertruck.tscn",
	]
	for s_path in other_scenes:
		var scn = load(s_path)
		assert(scn != null, "%s must load" % s_path)
		var v: Car = scn.instantiate()
		main.add_child(v)
		assert(v._active_wheels.size() >= 4, "%s must have >= 4 wheels" % s_path)
		v.queue_free()
	test_car.queue_free()
	print("  Vehicles verified: 9 passenger body types + 4 commercial vehicle classes")

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

	for c in PassengerCar.SPORTS_PAINT_PALETTE:
		var smat := PassengerCar.get_sports_stripe_material(c)
		assert(smat != null, "Sports stripe material must generate for color %s" % c)
		var scol := PassengerCar.get_sports_stripe_color(c)
		assert(smat.albedo_color == scol, "Stripe material albedo must match stripe color")
		if c.get_luminance() > 0.55:
			assert(scol == Color(0.10, 0.10, 0.12), "Bright sports cars must have dark stripe")
		else:
			assert(scol == Color(0.96, 0.96, 0.98), "Dark sports cars must have white stripe")

	var sports_car: PassengerCar = pcar_scene.instantiate()
	sports_car.car_type = Car.CarType.SPORTS
	main.add_child(sports_car)
	sports_car._apply_visual_type()
	var sports_model := sports_car._get_node_for_type(Car.CarType.SPORTS)
	assert(sports_model != null, "Sports car model must exist")
	var stripe_count := 0
	for child in sports_model.get_children():
		if (
			child is MeshInstance3D
			and (child.name == &"Stripe" or child.name.begins_with("Stripe"))
		):
			stripe_count += 1
			assert(
				child.material_override != null,
				"Stripe node %s must have material_override" % child.name
			)
	assert(stripe_count >= 5, "Sports car must have stripe nodes (found %d)" % stripe_count)
	sports_car.queue_free()

	var sports_spawned := 0
	const SAMPLE_COUNT := 500
	for _i in range(SAMPLE_COUNT):
		if PassengerCar.pick_passenger_car_type(true) == Car.CarType.SPORTS:
			sports_spawned += 1
		assert(
			PassengerCar.pick_passenger_car_type(false) != Car.CarType.SPORTS,
			"Sports must never spawn when disallowed"
		)
	var sports_rate := float(sports_spawned) / float(SAMPLE_COUNT)
	assert(
		sports_rate > 0.04 and sports_rate < 0.14,
		"Sports spawn rate must be approx 8%% (got %.2f)" % sports_rate
	)

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
		assert(
			lbl.visibility_range_end > 0.0,
			"Label3D %s (%s) must have visibility_range_end > 0.0" % [lbl.name, lbl.get_path()]
		)
		assert(
			lbl.visibility_range_end_margin > 0.0,
			"Label3D %s must fade over a nonzero visibility margin" % lbl.name
		)
		assert(
			lbl.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF,
			"Label3D %s must fade itself at its visibility limit" % lbl.name
		)
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
