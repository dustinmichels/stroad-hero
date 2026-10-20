class_name Car
extends Area3D

enum CarType {
	SEDAN, SUV, TAXI, TRUCK, PICKUP, BUS, HATCHBACK, MINIVAN, SPORTS, VAN, SHIPPING_TRUCK, JEEP
}

enum Motion { LANE, PATH }

enum State {
	CRUISING,
	APPROACHING,
	TO_SPOT,
	PARKED,
	REVERSING_OUT,
	TO_EXIT,
	WAITING_TO_MERGE,
	MERGING,
	DRIVE_THRU
}

enum TurnSignal { NONE, LEFT, RIGHT }

const PARKING_CAR_TYPES: Array[CarType] = [
	CarType.SEDAN,
	CarType.SUV,
	CarType.PICKUP,
	CarType.HATCHBACK,
	CarType.MINIVAN,
	CarType.SPORTS,
	CarType.JEEP,
]


static func is_type_parkable(type: CarType) -> bool:
	return type in PARKING_CAR_TYPES


func can_park() -> bool:
	return is_type_parkable(car_type)


func can_take_errands() -> bool:
	return can_park()


func can_use_drive_thru() -> bool:
	return can_park()


@export var car_type: CarType = CarType.SEDAN

# Authoritative simulation state (per TRAFFIC_SIMULATION.md)
var lane_id: int = 0
var motion := Motion.LANE:
	set(value):
		if motion != value:
			motion = value
			sweep_rev += 1
var _last_transform: Transform3D = Transform3D()
var sweep_rev: int = 0:
	get:
		var current_xf := global_transform if is_inside_tree() else transform
		if current_xf != _last_transform:
			_last_transform = current_xf
			sweep_rev += 1
		return sweep_rev
var state := State.CRUISING:
	set(value):
		if state != value:
			state = value
			sweep_rev += 1
			_update_headlamps()


func get_state_name() -> String:
	match state:
		State.CRUISING:
			return "CRUISING"
		State.APPROACHING:
			return "APPROACHING"
		State.TO_SPOT:
			return "TO_SPOT"
		State.PARKED:
			return "PARKED"
		State.REVERSING_OUT:
			return "REVERSING_OUT"
		State.TO_EXIT:
			return "TO_EXIT"
		State.WAITING_TO_MERGE:
			return "WAITING_TO_MERGE"
		State.MERGING:
			return "MERGING"
		State.DRIVE_THRU:
			return "DRIVE_THRU"
	return "UNKNOWN"


var path: Curve3D = null:
	set(value):
		if path != value:
			path = value
			sweep_rev += 1
var path_distance: float = 0.0:
	set(value):
		if path_distance != value:
			path_distance = value
			sweep_rev += 1
var lane_distance: float = 0.0
var lane_speed: float = 14.0
var speed: float = 14.0:
	set(value):
		if speed != value:
			speed = value
			sweep_rev += 1
var desired_speed: float = 14.0:
	set(value):
		if desired_speed != value:
			desired_speed = value
			sweep_rev += 1
var car_length: float = 4.5:
	set(value):
		if car_length != value:
			car_length = value
			sweep_rev += 1
var car_width: float = 2.0:
	set(value):
		if car_width != value:
			car_width = value
			sweep_rev += 1
var direction: float = 1.0  # +1.0 for Eastbound (+X), -1.0 for Westbound (-X)
var lane_z: float = 0.0
var lane_length: float = 140.0
var start_x: float = -70.0
var spot: ParkingSpot = null
var dwell_left: float = 0.0
var merge_wait_time: float = 0.0
var errand: Errand = null
var had_errand: bool = false
var blocked_time: float = 0.0
var current_blocker: Car = null
var merge_target_lane: int = 0
var dt_order_done: bool = false
var dt_pickup_done: bool = false
var dt_dwell_timer: float = 0.0
var is_changing_lanes: bool = false
var lane_change_progress: float = 0.0
var lane_change_duration: float = 0.8
var lane_change_from_z: float = 0.0
var lane_change_to_z: float = 0.0
var current_lateral_z: float = 0.0
var lane_change_cooldown: float = 0.0


func start_lane_change(target_id: int, target_z: float) -> void:
	lane_id = target_id
	is_changing_lanes = true
	lane_change_progress = 0.0
	lane_change_duration = randf_range(0.75, 1.0)
	lane_change_from_z = current_lateral_z if absf(current_lateral_z) > 0.001 else lane_z
	lane_change_to_z = target_z
	var is_right: bool = (
		(target_z > lane_change_from_z) if (direction > 0.0) else (target_z < lane_change_from_z)
	)
	set_turn_signal(TurnSignal.RIGHT if is_right else TurnSignal.LEFT)


var turn_signal: TurnSignal = TurnSignal.NONE
const SIGNAL_BLINK_INTERVAL := 0.35
var _signal_blink_timer: float = 0.0
var _signals_initialized: bool = false
var _active_right_signals: Array[MeshInstance3D] = []
var _active_left_signals: Array[MeshInstance3D] = []

var headlamp: SpotLight3D = null
var _headlamps_initialized: bool = false
var _headlight_meshes: Array[MeshInstance3D] = []
var _headlamps_on: int = -1

static var _headlight_mat_on: StandardMaterial3D = null
static var _headlight_mat_off: StandardMaterial3D = null
static var _signal_mesh: BoxMesh
static var _signal_mat_on: StandardMaterial3D
static var _signal_mat_off: StandardMaterial3D
var wheel_radius := 0.35
const BASE_WHEEL_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const STOP_SPEED := 0.1
const BLOCKER_LAYER := 4  # Layer 3 (1 << 2)

static var _spoke_mesh: BoxMesh
static var _hub_mesh: CylinderMesh
static var _chrome_mat: StandardMaterial3D

var wheel_rotation: float = 0.0
var _wheels_initialized: bool = false
var _active_wheels: Array[Node3D] = []

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
var blocker: AnimatableBody3D = null
var _blocker_shape: CollisionShape3D = null
var _blocking: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_notify_transform(true)
	tree_exiting.connect(_on_tree_exiting)
	if GameState.instance:
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
	blocker = AnimatableBody3D.new()
	blocker.name = "Blocker"
	blocker.sync_to_physics = false
	blocker.collision_mask = 0
	_blocking = not is_moving()
	blocker.collision_layer = BLOCKER_LAYER if _blocking else 0
	_blocker_shape = CollisionShape3D.new()
	_blocker_shape.name = "CollisionShape3D"
	blocker.add_child(_blocker_shape)
	add_child(blocker)
	_apply_visual_type()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		var current_xf := global_transform if is_inside_tree() else transform
		if current_xf != _last_transform:
			_last_transform = current_xf
			sweep_rev += 1


func _physics_process(delta: float) -> void:
	_update_blocker_layer()
	_update_signals(delta)


func _update_blocker_layer() -> void:
	if not blocker:
		return
	var should_block := not is_moving()
	if should_block != _blocking:
		_blocking = should_block
		blocker.set_deferred("collision_layer", BLOCKER_LAYER if _blocking else 0)


static func _init_wheel_resources() -> void:
	if _spoke_mesh != null:
		return

	_chrome_mat = StandardMaterial3D.new()
	_chrome_mat.albedo_color = Color(0.85, 0.86, 0.88, 1.0)
	_chrome_mat.metallic = 0.85
	_chrome_mat.roughness = 0.25

	_spoke_mesh = BoxMesh.new()
	_spoke_mesh.size = Vector3(0.50, 0.32, 0.08)
	_spoke_mesh.material = _chrome_mat

	_hub_mesh = CylinderMesh.new()
	_hub_mesh.top_radius = 0.12
	_hub_mesh.bottom_radius = 0.12
	_hub_mesh.height = 0.33
	_hub_mesh.material = _chrome_mat


func _setup_wheels() -> void:
	if _wheels_initialized:
		return
	_wheels_initialized = true
	_init_wheel_resources()

	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return
	for car_model in visuals.get_children():
		for child in car_model.get_children():
			if child is Node3D and child.name.begins_with("Wheel"):
				if (
					child.has_node("Spoke")
					or child.get_meta("baked_wheel", false)
					or (
						child is MeshInstance3D
						and child.mesh
						and child.mesh.get_meta("baked_wheel", false)
					)
				):
					continue
				var spoke := MeshInstance3D.new()
				spoke.mesh = _spoke_mesh
				spoke.name = "Spoke"
				spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				spoke.visibility_range_end = 35.0
				child.add_child(spoke)

				var hub := MeshInstance3D.new()
				hub.mesh = _hub_mesh
				hub.name = "Hub"
				hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				hub.visibility_range_end = 35.0
				child.add_child(hub)


func setup(
	p_lane_id: int,
	p_lane_z: float,
	p_dir: float,
	p_start_x: float,
	p_lane_len: float,
	p_speed: float,
	p_type: CarType
) -> void:
	lane_id = p_lane_id
	motion = Motion.LANE
	lane_z = p_lane_z
	current_lateral_z = p_lane_z
	is_changing_lanes = false
	lane_change_progress = 0.0
	lane_change_cooldown = randf_range(1.0, 3.0)
	direction = p_dir
	start_x = p_start_x
	lane_length = p_lane_len
	lane_distance = 0.0
	speed = p_speed
	desired_speed = p_speed
	lane_speed = p_speed
	car_type = p_type

	_apply_visual_type()
	update_presentation()
	_update_blocker_layer()
	reset_physics_interpolation()


func teleport(target_transform: Transform3D) -> void:
	global_transform = target_transform
	reset_physics_interpolation()


func follow_path(curve: Curve3D, from_end := false) -> void:
	motion = Motion.PATH
	path = curve
	if from_end and curve != null:
		path_distance = curve.get_baked_length()
	else:
		path_distance = 0.0
	update_presentation()
	reset_physics_interpolation()


func get_active_model() -> Node3D:
	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return null
	for child in visuals.get_children():
		if child is Node3D and child.visible:
			return child
	if visuals.get_child_count() == 1 and visuals.get_child(0) is Node3D:
		return visuals.get_child(0)
	return null


func _apply_visual_type() -> void:
	_update_dimensions()
	_setup_wheels()
	_setup_signals()
	_setup_headlamps()
	_collect_active_parts()


func _collect_active_parts() -> void:
	_active_wheels.clear()
	_active_right_signals.clear()
	_active_left_signals.clear()
	var active_node := get_active_model()
	if active_node:
		for child in active_node.get_children():
			if child is Node3D and child.name.begins_with("Wheel"):
				_active_wheels.append(child)
			elif child is MeshInstance3D:
				if child.name == "SignalFrontR" or child.name == "SignalRearR":
					_active_right_signals.append(child)
				elif child.name == "SignalFrontL" or child.name == "SignalRearL":
					_active_left_signals.append(child)


func set_turn_signal(sig: TurnSignal) -> void:
	if turn_signal != sig:
		turn_signal = sig
		_signal_blink_timer = 0.0
		_update_signals(0.0)


func has_turn_signal_right() -> bool:
	return turn_signal == TurnSignal.RIGHT


static func _init_signal_resources() -> void:
	if _signal_mesh != null:
		return
	_signal_mesh = BoxMesh.new()
	_signal_mesh.size = Vector3(0.16, 0.18, 0.16)

	_signal_mat_on = StandardMaterial3D.new()
	_signal_mat_on.albedo_color = Color(1.0, 0.62, 0.02, 1.0)
	_signal_mat_on.emission_enabled = true
	_signal_mat_on.emission = Color(1.0, 0.62, 0.02, 1.0)
	_signal_mat_on.emission_energy_multiplier = 4.0
	_signal_mat_on.roughness = 0.3

	_signal_mat_off = StandardMaterial3D.new()
	_signal_mat_off.albedo_color = Color(0.38, 0.22, 0.04, 1.0)
	_signal_mat_off.emission_enabled = false
	_signal_mat_off.emission_energy_multiplier = 0.0
	_signal_mat_off.roughness = 0.5


func _setup_signals() -> void:
	if _signals_initialized:
		return
	_signals_initialized = true
	_init_signal_resources()

	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return
	for car_model in visuals.get_children():
		var hl_l: Node3D = car_model.get_node_or_null("HeadlightL")
		var hl_r: Node3D = car_model.get_node_or_null("HeadlightR")
		var tl_l: Node3D = car_model.get_node_or_null("TaillightL")
		var tl_r: Node3D = car_model.get_node_or_null("TaillightR")

		if hl_l:
			_create_signal_mesh(car_model, "SignalFrontR", hl_l.position, 1.0, 1.0)
		if tl_l:
			_create_signal_mesh(car_model, "SignalRearR", tl_l.position, -1.0, 1.0)
		if hl_r:
			_create_signal_mesh(car_model, "SignalFrontL", hl_r.position, 1.0, -1.0)
		if tl_r:
			_create_signal_mesh(car_model, "SignalRearL", tl_r.position, -1.0, -1.0)


func _create_signal_mesh(
	parent: Node, node_name: String, base_pos: Vector3, sign_x: float, sign_z: float
) -> MeshInstance3D:
	var sig := MeshInstance3D.new()
	sig.name = node_name
	sig.mesh = _signal_mesh
	sig.position = base_pos + Vector3(sign_x * 0.02, 0.0, sign_z * 0.16)
	sig.material_override = _signal_mat_off
	sig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sig.visibility_range_end = 50.0
	sig.visible = false
	parent.add_child(sig)
	return sig


func _init_headlight_resources() -> void:
	if _headlight_mat_off != null:
		return

	_headlight_mat_off = StandardMaterial3D.new()
	_headlight_mat_off.resource_name = "CarHeadlightOff"
	_headlight_mat_off.albedo_color = Color(1.0, 0.98, 0.85, 1.0)
	_headlight_mat_off.roughness = 0.2
	_headlight_mat_off.emission_enabled = false

	_headlight_mat_on = StandardMaterial3D.new()
	_headlight_mat_on.resource_name = "CarHeadlightOn"
	_headlight_mat_on.albedo_color = Color(1.0, 0.98, 0.85, 1.0)
	_headlight_mat_on.roughness = 0.2
	_headlight_mat_on.emission_enabled = true
	_headlight_mat_on.emission = Color(1.0, 0.98, 0.85, 1.0)
	_headlight_mat_on.emission_energy_multiplier = 2.5


func _setup_headlamps() -> void:
	if _headlamps_initialized:
		_update_headlamps()
		return
	_headlamps_initialized = true
	_init_headlight_resources()
	_headlight_meshes.clear()
	_headlamps_on = -1

	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return
	for car_model in visuals.get_children():
		var hl_l := car_model.get_node_or_null("HeadlightL") as MeshInstance3D
		var hl_r := car_model.get_node_or_null("HeadlightR") as MeshInstance3D

		if hl_l:
			_headlight_meshes.append(hl_l)
			var front_x: float = hl_l.position.x
			var height_y: float = hl_l.position.y
			if hl_r:
				_headlight_meshes.append(hl_r)
				front_x = maxf(hl_l.position.x, hl_r.position.x)
				height_y = (hl_l.position.y + hl_r.position.y) * 0.5
			headlamp = _create_headlamp(car_model, "HeadlampLight", Vector3(front_x, height_y, 0.0))
			var fl_l := car_model.get_node_or_null("FogLightL") as MeshInstance3D
			var fl_r := car_model.get_node_or_null("FogLightR") as MeshInstance3D
			if fl_l:
				_headlight_meshes.append(fl_l)
			if fl_r:
				_headlight_meshes.append(fl_r)
			break
	_update_headlamps(true)


func _create_headlamp(parent: Node, node_name: String, base_pos: Vector3) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = node_name
	var aim_dir := Vector3(1.0, -0.06, 0.0).normalized()
	light.transform = Transform3D(
		Basis.looking_at(aim_dir, Vector3.UP), base_pos + Vector3(0.06, 0.0, 0.0)
	)
	light.light_color = Color(1.0, 0.97, 0.88, 1.0)
	light.light_energy = 3.2
	light.spot_range = 18.0
	light.spot_angle = 38.0
	light.spot_angle_attenuation = 1.1
	light.spot_attenuation = 1.0
	light.shadow_enabled = false
	light.visible = _should_headlamp_be_on()
	parent.add_child(light)
	return light


func _should_headlamp_be_on() -> bool:
	return GameState.are_lights_on() and state != State.PARKED


func _update_headlamps(force: bool = false) -> void:
	var on := _should_headlamp_be_on()
	var on_int := 1 if on else 0
	if not force and _headlamps_on == on_int:
		return
	_headlamps_on = on_int
	if headlamp:
		headlamp.visible = on
	var mat := _headlight_mat_on if on else _headlight_mat_off
	for mesh in _headlight_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = mat


func _on_time_of_day_changed(_mode: GameState.TimeOfDay) -> void:
	_update_headlamps()


func _update_signals(delta: float) -> void:
	if turn_signal == TurnSignal.NONE:
		_signal_blink_timer = 0.0
		for s in _active_right_signals:
			s.visible = false
		for s in _active_left_signals:
			s.visible = false
		return

	_signal_blink_timer += delta
	var blink_cycle := fmod(_signal_blink_timer, SIGNAL_BLINK_INTERVAL * 2.0)
	var is_on := blink_cycle < SIGNAL_BLINK_INTERVAL
	var target_mat := _signal_mat_on if is_on else _signal_mat_off

	if turn_signal == TurnSignal.RIGHT:
		for s in _active_right_signals:
			s.visible = true
			s.material_override = target_mat
		for s in _active_left_signals:
			s.visible = false
	elif turn_signal == TurnSignal.LEFT:
		for s in _active_left_signals:
			s.visible = true
			s.material_override = target_mat
		for s in _active_right_signals:
			s.visible = false


func _update_dimensions() -> void:
	var shape_size: Vector3
	var shape_y: float
	match car_type:
		CarType.SEDAN:
			car_length = 4.2
			car_width = 1.9
			shape_size = Vector3(4.0, 1.4, 1.9)
			shape_y = 0.7
		CarType.SUV:
			car_length = 4.6
			car_width = 2.0
			shape_size = Vector3(4.5, 1.7, 2.0)
			shape_y = 0.85
		CarType.TAXI:
			car_length = 4.2
			car_width = 1.9
			shape_size = Vector3(4.0, 1.5, 1.9)
			shape_y = 0.75
		CarType.TRUCK:
			car_length = 5.2
			car_width = 2.1
			shape_size = Vector3(5.0, 2.2, 2.1)
			shape_y = 1.1
		CarType.PICKUP:
			car_length = 5.0
			car_width = 2.1
			shape_size = Vector3(5.0, 1.8, 2.1)
			shape_y = 0.9
		CarType.BUS:
			car_length = 9.0
			car_width = 2.4
			shape_size = Vector3(8.8, 2.7, 2.4)
			shape_y = 1.35
		CarType.HATCHBACK:
			car_length = 3.8
			car_width = 1.8
			shape_size = Vector3(3.7, 1.5, 1.8)
			shape_y = 0.75
		CarType.MINIVAN:
			car_length = 4.9
			car_width = 2.0
			shape_size = Vector3(4.8, 1.9, 2.0)
			shape_y = 0.95
		CarType.SPORTS:
			car_length = 4.3
			car_width = 1.9
			shape_size = Vector3(4.2, 1.2, 1.9)
			shape_y = 0.6
		CarType.VAN:
			car_length = 5.4
			car_width = 2.1
			shape_size = Vector3(5.3, 2.3, 2.1)
			shape_y = 1.15
		CarType.SHIPPING_TRUCK:
			car_length = 13.7
			car_width = 2.5
			shape_size = Vector3(13.7, 3.6, 2.5)
			shape_y = 1.85
		CarType.JEEP:
			car_length = 4.4
			car_width = 1.95
			shape_size = Vector3(4.3, 1.86, 1.95)
			shape_y = 0.93
	var col = _collision_shape if _collision_shape else get_node_or_null("CollisionShape3D")
	if col:
		var box := BoxShape3D.new()
		box.size = shape_size
		col.shape = box
		col.position = Vector3(0.0, shape_y, 0.0)

	var b_col = (
		_blocker_shape
		if _blocker_shape
		else (blocker.get_node_or_null("CollisionShape3D") if blocker else null)
	)
	if b_col:
		var blocker_box := BoxShape3D.new()
		blocker_box.size = shape_size + Vector3(0.2, 0.2, 0.2)
		b_col.shape = blocker_box
		b_col.position = Vector3(0.0, shape_y, 0.0)


func get_heading() -> Vector3:
	var h := global_transform.basis.x
	var h_2d := Vector3(h.x, 0.0, h.z)
	if h_2d.length_squared() < 0.0001:
		return Vector3(direction, 0.0, 0.0)
	return h_2d.normalized()


## Advance vehicle along lane (kinematic state) and update 3D transform
func advance_simulation(delta: float) -> void:
	if lane_change_cooldown > 0.0:
		lane_change_cooldown = maxf(0.0, lane_change_cooldown - delta)

	if is_changing_lanes:
		lane_change_progress += delta / maxf(0.001, lane_change_duration)
		var t := clampf(lane_change_progress, 0.0, 1.0)
		var smooth_t := t * t * (3.0 - 2.0 * t)
		current_lateral_z = lerpf(lane_change_from_z, lane_change_to_z, smooth_t)
		if t >= 1.0:
			is_changing_lanes = false
			current_lateral_z = lane_change_to_z
			lane_z = lane_change_to_z
			set_turn_signal(TurnSignal.NONE)
			lane_change_cooldown = randf_range(1.5, 3.0)
	else:
		current_lateral_z = lane_z

	lane_distance += speed * delta
	update_presentation()
	_update_blocker_layer()


func advance_path(delta: float) -> bool:
	if path == null:
		return true
	var length := path.get_baked_length()
	if length <= 0.0:
		path_distance = 0.0
		update_presentation()
		_update_blocker_layer()
		return true

	path_distance += speed * delta
	var arrived := false
	if state == State.REVERSING_OUT or speed < 0.0 or desired_speed < 0.0:
		if path_distance <= 0.0:
			path_distance = 0.0
			arrived = true
		elif path_distance >= length:
			path_distance = length
			arrived = true
	else:
		if path_distance >= length:
			path_distance = length
			arrived = true
	path_distance = clampf(path_distance, 0.0, length)
	update_presentation()
	_update_blocker_layer()
	return arrived


func update_presentation() -> void:
	_update_headlamps()
	if motion == Motion.PATH:
		if path != null:
			var length := path.get_baked_length()
			var d := clampf(path_distance, 0.0, length)
			global_position = path.sample_baked(d)
			var d_prev := clampf(d - 0.05, 0.0, length)
			var d_next := clampf(d + 0.05, 0.0, length)
			var h := (path.sample_baked(d_next) - path.sample_baked(d_prev)).normalized()
			if h.length_squared() > 0.0001:
				rotation.y = atan2(-h.z, h.x)
			wheel_rotation = fmod(-path_distance / wheel_radius, TAU)
			_update_wheels()
		return
	if state == State.PARKED and spot != null:
		if global_transform != spot.transform:
			global_transform = spot.transform
			reset_physics_interpolation()
		return
	var current_x := start_x + (direction * lane_distance)
	var z_pos := current_lateral_z if is_changing_lanes else lane_z
	if is_inside_tree():
		global_position = Vector3(current_x, 0.05, z_pos)
	else:
		position = Vector3(current_x, 0.05, z_pos)

	if is_changing_lanes:
		var t := clampf(lane_change_progress, 0.0, 1.0)
		var dz_dt := (
			(lane_change_to_z - lane_change_from_z)
			* (6.0 * t * (1.0 - t))
			/ maxf(0.001, lane_change_duration)
		)
		var dx_dt := speed * direction
		if absf(dx_dt) > 0.01:
			rotation.y = atan2(-dz_dt, dx_dt)
		else:
			rotation.y = 0.0 if direction > 0.0 else PI
	else:
		rotation.y = 0.0 if direction > 0.0 else PI

	wheel_rotation = fmod(-lane_distance / wheel_radius, TAU)
	_update_wheels()


func _update_wheels() -> void:
	var wheel_rot := Basis(Vector3.UP, wheel_rotation)
	var wheel_basis := BASE_WHEEL_BASIS * wheel_rot
	for wheel in _active_wheels:
		wheel.transform.basis = wheel_basis


func is_moving() -> bool:
	return absf(speed) > STOP_SPEED


func _on_body_entered(body: Node3D) -> void:
	_check_hit(body)


func _check_hit(body: Node3D) -> void:
	if not is_moving():
		return
	if global_position.distance_to(body.global_position) > 4.5:
		return
	if body.is_in_group("player") or body.has_method("die"):
		body.die()


func _on_tree_exiting() -> void:
	if GameState.instance:
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)

	if spot != null:
		if spot.lot != null:
			spot.lot.release(spot)
		else:
			if spot.car == self:
				spot.car = null
			spot.state = ParkingSpot.State.FREE
			spot = null
