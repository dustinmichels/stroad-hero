class_name FroggerTraffic
extends Node
## Frogger-mode traffic beat. TrafficManager keeps simulating every physics tick (slowed by
## `time_scale`), but cars are only *shown* moving on the beat: every `tick_seconds` each car slides
## from its last shown pose to its current simulated pose over `slide_seconds`, then holds.
##
## The shown pose is the car's real transform between ticks, so the hit Area kills Mats where the
## car is drawn, and sliding through in-between poses keeps overlap hits from skipping over him.
## Before each simulation tick the simulated pose is restored, so traffic logic never sees the
## shown pose.

## Real seconds between traffic moves.
@export var tick_seconds := 0.25
## Simulated seconds per real second (0.5: cars move ~1-2 hop cells per tick).
@export var time_scale := 0.5
## How long each move takes; must be shorter than tick_seconds.
@export var slide_seconds := 0.1

var traffic: TrafficManager = null
var is_running := false

## Car -> simulated Transform3D as of the last tick. Keys stay untyped: cars can be freed any time.
var _simulated := {}
## Car -> [from Transform3D, to Transform3D] of its current beat slide.
var _slides := {}
var _beat_elapsed := 0.0


func start(p_traffic: TrafficManager) -> void:
	if is_running or not p_traffic:
		return
	traffic = p_traffic
	is_running = true
	# First tick starts a beat, so every car is captured right away.
	_beat_elapsed = tick_seconds
	traffic.sim_time_scale = time_scale
	traffic.sim_step_started.connect(_restore_simulated_poses)
	traffic.sim_step_finished.connect(_show_beat_poses)


func stop() -> void:
	if not is_running:
		return
	is_running = false
	_restore_simulated_poses()
	_simulated.clear()
	_slides.clear()
	if is_instance_valid(traffic):
		traffic.sim_time_scale = 1.0
		traffic.sim_step_started.disconnect(_restore_simulated_poses)
		traffic.sim_step_finished.disconnect(_show_beat_poses)
	traffic = null


func _exit_tree() -> void:
	stop()


func _restore_simulated_poses() -> void:
	for car in _simulated:
		if not is_instance_valid(car):
			continue
		var pose: Transform3D = _simulated[car]
		if (car as Car).global_transform != pose:
			(car as Car).global_transform = pose


func _show_beat_poses() -> void:
	_beat_elapsed += get_physics_process_delta_time()
	var is_beat := _beat_elapsed >= tick_seconds
	if is_beat:
		_beat_elapsed = 0.0
	var t := minf(_beat_elapsed / slide_seconds, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var simulated := {}
	var slides := {}
	for child in traffic.get_children():
		if child is not Car:
			continue
		var car := child as Car
		var pose := car.global_transform
		simulated[car] = pose
		# Cars spawned since the last beat hold where they appeared.
		var slide: Array = _slides.get(car, [pose, pose])
		if is_beat:
			slide = [slide[1], pose]
		slides[car] = slide
		var shown := (slide[0] as Transform3D).interpolate_with(slide[1], eased)
		if shown != pose:
			car.global_transform = shown
	_simulated = simulated
	_slides = slides
