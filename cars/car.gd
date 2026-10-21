class_name Car
extends Area3D

enum CarType {
	SEDAN,
	SUV,
	TAXI,
	TRUCK,
	PICKUP,
	BUS,
	HATCHBACK,
	MINIVAN,
	SPORTS,
	VAN,
	SHIPPING_TRUCK,
	JEEP,
	F150,
	CYBERTRUCK,
	POLICE_SUV
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
	DRIVE_THRU,
	SHORTCUT
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
	CarType.F150,
	CarType.CYBERTRUCK,
	CarType.POLICE_SUV,
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
@export var state: State = State.CRUISING:
	set(value):
		if state != value:
			var prev_state := state
			state = value
			sweep_rev += 1
			_update_headlamps()
			_update_exhaust()
			if state == State.APPROACHING:
				_center_for_approach()
			elif state == State.CRUISING and prev_state != State.CRUISING:
				_init_lane_wander()


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
		State.SHORTCUT:
			return "SHORTCUT"
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
var lane_speed: float = 20.0
var speed: float = 20.0:
	set(value):
		if speed != value:
			speed = value
			sweep_rev += 1
var desired_speed: float = 20.0:
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
var lane_z: float = 0.0:
	set(value):
		lane_z = value
		if not is_changing_lanes:
			current_lateral_z = lane_z + lane_wander_offset
var lane_length: float = 140.0
var start_x: float = -70.0
var spot: ParkingSpot = null
var pending_destination_spot: ParkingSpot = null
var pending_spot: ParkingSpot:
	get:
		return pending_destination_spot
	set(value):
		pending_destination_spot = value
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
const LANE_WIDTH: float = 3.75
const SIDE_CLEARANCE: float = 0.20
const WANDER_INTERVAL_MIN: float = 2.5
const WANDER_INTERVAL_MAX: float = 7.0
const WANDER_TRANSITION_MIN: float = 1.5
const WANDER_TRANSITION_MAX: float = 4.0
const RECKLESS_DRIVER_PROBABILITY: float = 0.015
const RECKLESS_RISK_THRESHOLD: float = 0.8

var risk_tolerance: float = 0.0
var force_risky_pass: bool = false
var force_shortcut: bool = false
var has_taken_shortcut: bool = false
var shortcut_evaluated: bool = false
const RISK_COMMIT_DURATION: float = 1.0

var risk_commit_timer: float = 0.0
var _risk_commit_active: bool = false
var risk_commit_active: bool:
	get:
		return _risk_commit_active
	set(val):
		_risk_commit_active = val
		if val:
			risk_commit_timer = (
				RISK_COMMIT_DURATION if risk_commit_timer <= 0.0 else risk_commit_timer
			)
		else:
			risk_commit_timer = 0.0

var is_changing_lanes: bool = false
var lane_change_progress: float = 0.0
var lane_change_duration: float = 0.8
var lane_change_from_z: float = 0.0
var lane_change_to_z: float = 0.0
var current_lateral_z: float = 0.0
var lane_change_cooldown: float = 0.0
var lane_change_target_lane_z: float = 0.0

var lane_wander_target: float = 0.0
var lane_wander_offset: float = 0.0
var lane_wander_timer: float = 0.0
var lane_wander_start_offset: float = 0.0
var lane_wander_duration: float = 0.0
var lane_wander_elapsed: float = 0.0


func get_max_lane_wander_offset() -> float:
	var lane_half_width := LANE_WIDTH * 0.5
	return maxf(0.0, lane_half_width - (car_width * 0.5) - SIDE_CLEARANCE)


func is_reckless() -> bool:
	if car_type == CarType.BUS or car_type == CarType.SHIPPING_TRUCK or car_type == CarType.TRUCK:
		return false
	if errand != null and (errand.is_drive_thru() or errand.is_dropoff()):
		return false
	return risk_tolerance >= RECKLESS_RISK_THRESHOLD


func is_eligible_for_shortcut() -> bool:
	if car_type == CarType.BUS or car_type == CarType.SHIPPING_TRUCK or car_type == CarType.TRUCK:
		return false
	if errand != null and (errand.is_drive_thru() or errand.is_dropoff()):
		return false
	if has_taken_shortcut or pending_destination_spot != null:
		return false
	return true


func _init_risk_tolerance() -> void:
	if car_type == CarType.BUS or car_type == CarType.SHIPPING_TRUCK or car_type == CarType.TRUCK:
		risk_tolerance = 0.0
		return
	if TrafficManager._is_test_mode():
		risk_tolerance = 0.0
		return
	if randf() < RECKLESS_DRIVER_PROBABILITY:
		risk_tolerance = randf_range(RECKLESS_RISK_THRESHOLD, 1.0)
	else:
		risk_tolerance = randf_range(0.0, 0.3)


func _init_lane_wander() -> void:
	lane_wander_offset = 0.0
	lane_wander_start_offset = 0.0
	lane_wander_elapsed = 0.0
	if TrafficManager._is_test_mode():
		lane_wander_target = 0.0
		lane_wander_timer = 999.0
		lane_wander_duration = 1.0
		return
	var max_offset := get_max_lane_wander_offset()
	lane_wander_target = randf_range(-max_offset, max_offset) if max_offset > 0.0 else 0.0
	lane_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	lane_wander_duration = randf_range(WANDER_TRANSITION_MIN, WANDER_TRANSITION_MAX)


func _center_for_approach() -> void:
	lane_wander_target = 0.0
	lane_wander_start_offset = lane_wander_offset
	lane_wander_elapsed = 0.0
	lane_wander_duration = clampf(absf(lane_wander_offset) / 0.5, 0.4, 1.2)
	lane_wander_timer = 999.0


func _advance_lane_wander(delta: float) -> void:
	var max_offset := get_max_lane_wander_offset()
	if state != State.APPROACHING:
		lane_wander_timer -= delta
		if lane_wander_timer <= 0.0:
			lane_wander_target = randf_range(-max_offset, max_offset) if max_offset > 0.0 else 0.0
			lane_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
			lane_wander_duration = randf_range(WANDER_TRANSITION_MIN, WANDER_TRANSITION_MAX)
			lane_wander_start_offset = lane_wander_offset
			lane_wander_elapsed = 0.0

	lane_wander_elapsed += delta
	var t := clampf(lane_wander_elapsed / maxf(0.001, lane_wander_duration), 0.0, 1.0)
	var smooth_t := t * t * (3.0 - 2.0 * t)
	var eff_target := (
		0.0 if state == State.APPROACHING else clampf(lane_wander_target, -max_offset, max_offset)
	)
	lane_wander_offset = clampf(
		lerpf(lane_wander_start_offset, eff_target, smooth_t), -max_offset, max_offset
	)
	current_lateral_z = lane_z + lane_wander_offset


func start_risk_commit(duration: float = RISK_COMMIT_DURATION) -> void:
	risk_commit_timer = duration
	_risk_commit_active = duration > 0.0


func reset_lane_change_cooldown() -> void:
	if car_type == CarType.SPORTS or (car_type == CarType.F150 and has_smokestacks):
		lane_change_cooldown = randf_range(1.0, 2.0)
	else:
		lane_change_cooldown = randf_range(2.0, 3.5)


func start_lane_change(target_id: int, target_z: float, is_risky: bool = false) -> void:
	lane_id = target_id
	is_changing_lanes = true
	lane_change_progress = 0.0
	if is_risky:
		start_risk_commit()
	if car_type == CarType.SPORTS or car_type == CarType.CYBERTRUCK:
		lane_change_duration = randf_range(0.6, 0.8)
	elif car_type == CarType.SHIPPING_TRUCK or car_type == CarType.BUS:
		lane_change_duration = randf_range(1.2, 1.5)
	else:
		lane_change_duration = randf_range(0.8, 1.1)
	lane_change_from_z = current_lateral_z
	lane_change_target_lane_z = target_z
	var max_offset := get_max_lane_wander_offset()
	lane_wander_target = randf_range(-max_offset, max_offset) if max_offset > 0.0 else 0.0
	lane_change_to_z = target_z + lane_wander_target
	var is_right: bool = (
		(target_z > lane_change_from_z) if (direction > 0.0) else (target_z < lane_change_from_z)
	)
	set_turn_signal(TurnSignal.RIGHT if is_right else TurnSignal.LEFT)


var turn_signal: TurnSignal = TurnSignal.NONE
const SIGNAL_BLINK_INTERVAL := 0.35
var _signal_blink_timer: float = 0.0
var _signal_blink_is_on: int = -1
var _signals_initialized: bool = false
var _active_right_signals: Array[MeshInstance3D] = []
var _active_left_signals: Array[MeshInstance3D] = []

var headlamp: SpotLight3D = null
var _headlamps_initialized: bool = false
var _headlight_meshes: Array[MeshInstance3D] = []
var _headlamps_on: int = -1
var _headlamp_delay_active: bool = false
var headlamp_lod_active: bool = true
static var stagger_headlamps: bool = true

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

@export var has_exhaust: bool = false:
	set(value):
		has_exhaust = value
		_exhaust_explicitly_set = true
		if _exhaust_initialized:
			_apply_exhaust_visibility()
			_update_exhaust()

@export var has_smokestacks: bool = false:
	set(value):
		has_smokestacks = value
		_smokestacks_explicitly_set = true
		if _exhaust_initialized:
			_apply_smokestacks_visibility()
			_setup_exhaust()

var has_coal_stacks: bool:
	get:
		return has_smokestacks
	set(value):
		self.has_smokestacks = value

var _smokestacks_explicitly_set: bool = false
var _exhaust_explicitly_set: bool = false
var _exhaust_initialized: bool = false
var exhaust_pipe: Node3D = null
var exhaust_particles: CPUParticles3D = null
var _exhaust_emitters: Array[CPUParticles3D] = []
static var _exhaust_mesh: CylinderMesh = null
static var _exhaust_mat: StandardMaterial3D = null
static var _smog_quad_mesh: QuadMesh = null
static var _smog_material: StandardMaterial3D = null
static var _smog_material_alt: StandardMaterial3D = null
static var _smog_gradient: Gradient = null
static var _coal_gradient: Gradient = null
static var _smog_scale_curve: Curve = null
static var _coal_scale_curve: Curve = null
static var _smog_texture: ImageTexture = null
static var _smog_texture_alt: ImageTexture = null
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
	_risk_commit_active = false
	risk_commit_timer = 0.0
	lane_change_cooldown = randf_range(1.0, 3.0)
	direction = p_dir
	start_x = p_start_x
	lane_length = p_lane_len
	lane_distance = 0.0
	speed = p_speed
	desired_speed = p_speed
	lane_speed = p_speed
	car_type = p_type
	turn_signal = TurnSignal.NONE

	force_shortcut = false
	has_taken_shortcut = false
	shortcut_evaluated = false
	pending_destination_spot = null
	_apply_visual_type()
	_init_lane_wander()
	_init_risk_tolerance()
	update_presentation()
	_update_blocker_layer()
	reset_physics_interpolation()


func teleport(target_transform: Transform3D) -> void:
	global_transform = target_transform
	reset_physics_interpolation()


func follow_path(curve: Curve3D, from_end := false) -> void:
	motion = Motion.PATH
	path = curve
	lane_wander_offset = 0.0
	lane_wander_target = 0.0
	current_lateral_z = lane_z
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
	_setup_exhaust()
	_collect_active_parts()


func _collect_active_parts() -> void:
	_active_wheels.clear()
	_active_right_signals.clear()
	_active_left_signals.clear()
	_signal_blink_is_on = -1
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
		_signal_blink_is_on = -1
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


static func _init_headlight_resources() -> void:
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


static func get_headlight_mat_on() -> StandardMaterial3D:
	_init_headlight_resources()
	return _headlight_mat_on


static func get_headlight_mat_off() -> StandardMaterial3D:
	_init_headlight_resources()
	return _headlight_mat_off


func set_headlights_override(on: bool, include_spotlight: bool = true) -> void:
	_headlamp_delay_active = false
	_headlamps_on = 1 if on else 0
	_init_headlight_resources()
	if headlamp:
		headlamp.visible = on if include_spotlight else false
	var mat := _headlight_mat_on if on else _headlight_mat_off
	for mesh in _headlight_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = mat


func restore_headlamps() -> void:
	_headlamp_delay_active = false
	_headlamps_on = -1
	_update_headlamps(true)


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
	light.distance_fade_enabled = true
	light.distance_fade_begin = 35.0
	light.distance_fade_length = 10.0
	light.visible = _should_headlamp_be_on() and headlamp_lod_active
	parent.add_child(light)
	return light


func _should_headlamp_be_on() -> bool:
	return GameState.are_lights_on() and state != State.PARKED


func _update_headlamps(force: bool = false) -> void:
	if not force and _headlamp_delay_active and state != State.PARKED:
		return
	var on := _should_headlamp_be_on()
	var on_int := 1 if on else 0
	if not force and _headlamps_on == on_int:
		return
	_headlamp_delay_active = false
	_headlamps_on = on_int
	if not on:
		headlamp_lod_active = true
	if headlamp:
		headlamp.visible = on and headlamp_lod_active
	var mat := _headlight_mat_on if on else _headlight_mat_off
	for mesh in _headlight_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = mat


func set_headlamp_lod_active(active: bool) -> void:
	if headlamp_lod_active == active:
		return
	headlamp_lod_active = active
	if headlamp:
		headlamp.visible = (
			_should_headlamp_be_on() and not _headlamp_delay_active and headlamp_lod_active
		)


func _on_headlamp_delay_timeout() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_headlamp_delay_active = false
	_update_headlamps()


func _on_time_of_day_changed(_mode: GameState.TimeOfDay) -> void:
	var desired := _should_headlamp_be_on()
	var current := _headlamps_on == 1
	if desired == current:
		_headlamp_delay_active = false
		return
	if not desired or not is_inside_tree() or not stagger_headlamps:
		_headlamp_delay_active = false
		_update_headlamps()
		return
	_headlamp_delay_active = true
	var delay := randf_range(0.05, 1.2)
	get_tree().create_timer(delay).timeout.connect(_on_headlamp_delay_timeout)


func _update_signals(delta: float) -> void:
	if turn_signal == TurnSignal.NONE:
		_signal_blink_timer = 0.0
		_signal_blink_is_on = -1
		for s in _active_right_signals:
			s.visible = false
		for s in _active_left_signals:
			s.visible = false
		return

	_signal_blink_timer += delta
	var blink_cycle := fmod(_signal_blink_timer, SIGNAL_BLINK_INTERVAL * 2.0)
	var is_on := blink_cycle < SIGNAL_BLINK_INTERVAL
	var on_int := 1 if is_on else 0

	if on_int != _signal_blink_is_on:
		_signal_blink_is_on = on_int
		var target_mat := _signal_mat_on if is_on else _signal_mat_off
		for s in _active_right_signals:
			s.material_override = target_mat
		for s in _active_left_signals:
			s.material_override = target_mat
	if turn_signal == TurnSignal.RIGHT:
		for s in _active_right_signals:
			s.visible = true
		for s in _active_left_signals:
			s.visible = false
	elif turn_signal == TurnSignal.LEFT:
		for s in _active_left_signals:
			s.visible = true
		for s in _active_right_signals:
			s.visible = false


static func _generate_plume_image(size: int, variant: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var half := float(size) * 0.5

	var lobes: Array = []
	if variant == 0:
		# Puffy cumulus billow: broad central body with rounded outer lobes
		lobes = [
			[Vector2(0.0, 0.0), 0.62, 1.0],
			[Vector2(-0.28, 0.16), 0.46, 0.90],
			[Vector2(0.26, 0.22), 0.44, 0.90],
			[Vector2(-0.22, -0.24), 0.42, 0.88],
			[Vector2(0.28, -0.18), 0.45, 0.88],
			[Vector2(0.04, 0.34), 0.40, 0.82],
		]
	else:
		# Wispy swirling plume: asymmetric elongated lobes
		lobes = [
			[Vector2(0.04, -0.05), 0.58, 1.0],
			[Vector2(-0.32, -0.12), 0.44, 0.88],
			[Vector2(0.30, 0.16), 0.45, 0.90],
			[Vector2(-0.14, 0.28), 0.42, 0.84],
			[Vector2(0.18, -0.26), 0.38, 0.82],
			[Vector2(-0.16, -0.22), 0.40, 0.80],
		]

	for y in range(size):
		for x in range(size):
			var nx := (float(x) - center.x) / half
			var ny := (float(y) - center.y) / half
			var dist_c := sqrt(nx * nx + ny * ny)
			if dist_c >= 0.98:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue

			var ang := atan2(ny, nx)
			var wobble := (
				1.0
				+ 0.10 * sin(ang * 3.0 + (0.5 if variant == 0 else -0.7))
				+ 0.07 * cos(ang * 5.0 + float(variant) * 1.5)
			)

			var density := 0.0
			for lobe in lobes:
				var lpos: Vector2 = lobe[0]
				var lrad: float = lobe[1] * wobble
				var lweight: float = lobe[2]
				var d := (Vector2(nx, ny) - lpos).length() / lrad
				if d < 1.0:
					var t := 1.0 - d
					var la := t * t * (3.0 - 2.0 * t) * lweight
					density = 1.0 - (1.0 - density) * (1.0 - la)

			var edge_fade := clampf((0.96 - dist_c) / 0.16, 0.0, 1.0)
			var a := clampf(density * edge_fade, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

	return img


static func _init_exhaust_resources() -> void:
	if _exhaust_mesh != null:
		return

	_exhaust_mat = StandardMaterial3D.new()
	_exhaust_mat.resource_name = "CarExhaustMetal"
	_exhaust_mat.albedo_color = Color(0.72, 0.74, 0.76, 1.0)
	_exhaust_mat.metallic = 0.85
	_exhaust_mat.roughness = 0.3

	_exhaust_mesh = CylinderMesh.new()
	_exhaust_mesh.top_radius = 0.045
	_exhaust_mesh.bottom_radius = 0.045
	_exhaust_mesh.height = 0.16
	_exhaust_mesh.radial_segments = 16
	_exhaust_mesh.material = _exhaust_mat

	var size := 48
	var img_billow := _generate_plume_image(size, 0)
	_smog_texture = ImageTexture.create_from_image(img_billow)

	var img_wisp := _generate_plume_image(size, 1)
	_smog_texture_alt = ImageTexture.create_from_image(img_wisp)

	_smog_quad_mesh = QuadMesh.new()
	_smog_quad_mesh.size = Vector2(0.56, 0.56)

	_smog_material = StandardMaterial3D.new()
	_smog_material.resource_name = "CarSmogMaterial"
	_smog_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smog_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smog_material.vertex_color_use_as_albedo = true
	_smog_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_smog_material.billboard_keep_scale = true
	_smog_material.albedo_texture = _smog_texture

	_smog_material_alt = StandardMaterial3D.new()
	_smog_material_alt.resource_name = "CarSmogMaterialAlt"
	_smog_material_alt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smog_material_alt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smog_material_alt.vertex_color_use_as_albedo = true
	_smog_material_alt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_smog_material_alt.billboard_keep_scale = true
	_smog_material_alt.albedo_texture = _smog_texture_alt

	_smog_gradient = Gradient.new()
	_smog_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	_smog_gradient.add_point(0.08, Color(1.0, 1.0, 1.0, 0.28))
	_smog_gradient.add_point(0.32, Color(1.0, 1.0, 1.0, 0.19))
	_smog_gradient.add_point(0.65, Color(1.0, 1.0, 1.0, 0.09))
	_smog_gradient.add_point(0.86, Color(1.0, 1.0, 1.0, 0.02))
	_smog_gradient.set_color(_smog_gradient.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))

	_coal_gradient = Gradient.new()
	_coal_gradient.set_color(0, Color(0.14, 0.13, 0.12, 0.0))
	_coal_gradient.add_point(0.06, Color(0.12, 0.11, 0.10, 0.68))
	_coal_gradient.add_point(0.36, Color(0.16, 0.15, 0.14, 0.52))
	_coal_gradient.add_point(0.70, Color(0.22, 0.21, 0.20, 0.24))
	_coal_gradient.add_point(0.90, Color(0.26, 0.25, 0.24, 0.07))
	_coal_gradient.set_color(_coal_gradient.get_point_count() - 1, Color(0.28, 0.28, 0.28, 0.0))

	_smog_scale_curve = Curve.new()
	_smog_scale_curve.add_point(Vector2(0.0, 0.22))
	_smog_scale_curve.add_point(Vector2(0.16, 0.58))
	_smog_scale_curve.add_point(Vector2(0.42, 1.12))
	_smog_scale_curve.add_point(Vector2(0.72, 1.62))
	_smog_scale_curve.add_point(Vector2(1.0, 2.05))

	_coal_scale_curve = Curve.new()
	_coal_scale_curve.add_point(Vector2(0.0, 0.28))
	_coal_scale_curve.add_point(Vector2(0.14, 0.78))
	_coal_scale_curve.add_point(Vector2(0.40, 1.50))
	_coal_scale_curve.add_point(Vector2(0.70, 2.20))
	_coal_scale_curve.add_point(Vector2(1.0, 2.75))


func _roll_exhaust() -> bool:
	match car_type:
		CarType.CYBERTRUCK:
			return false
		CarType.PICKUP, CarType.F150, CarType.TRUCK, CarType.VAN, CarType.SHIPPING_TRUCK:
			return randf() < 0.50
		CarType.BUS:
			return randf() < 0.40
		CarType.SEDAN, CarType.HATCHBACK, CarType.SUV, CarType.MINIVAN, CarType.JEEP, CarType.TAXI:
			return randf() < 0.35
		CarType.SPORTS:
			return randf() < 0.15
		_:
			return randf() < 0.35


func _setup_exhaust() -> void:
	if not _smokestacks_explicitly_set:
		if car_type == CarType.F150:
			has_smokestacks = randf() < 0.30
		else:
			has_smokestacks = false

	if not _exhaust_explicitly_set:
		if car_type == CarType.F150 and has_smokestacks:
			has_exhaust = true
		elif car_type == CarType.CYBERTRUCK:
			has_exhaust = false
		else:
			has_exhaust = _roll_exhaust()
	_exhaust_initialized = true
	_init_exhaust_resources()
	_exhaust_emitters.clear()
	exhaust_pipe = null
	exhaust_particles = null

	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return
	var car_model := get_active_model()
	if not car_model:
		return

	# Remove any existing generated pipe or smog on this model
	var old_pipe := car_model.get_node_or_null("ExhaustPipe")
	if old_pipe:
		car_model.remove_child(old_pipe)
		old_pipe.free()
	for child in car_model.get_children():
		if child is CPUParticles3D and child.name.begins_with("ExhaustSmog"):
			car_model.remove_child(child)
			child.free()

	if car_type == CarType.CYBERTRUCK:
		has_exhaust = false
		return
	# Apply smokestack visibility (e.g. for F150 rolling coal stacks)
	_apply_smokestacks_visibility()

	# Check for pre-existing modeled exhausts (e.g. Taxi, Sports, or F150 with smokestacks enabled)
	var existing_exhausts: Array[Node3D] = []
	for child in car_model.get_children():
		if child is Node3D and (child.name == "Exhaust" or child.name.begins_with("Exhaust")):
			if child.name != "ExhaustPipe" and not child.name.begins_with("ExhaustSmog"):
				if child.name.begins_with("ExhaustStack"):
					if has_smokestacks:
						existing_exhausts.append(child)
				else:
					existing_exhausts.append(child)
	if not existing_exhausts.is_empty():
		exhaust_pipe = existing_exhausts[0]
		var count := existing_exhausts.size()
		for i in range(count):
			var exh := existing_exhausts[i]
			var tip_pos := exh.position + Vector3(-0.04, 0.0, 0.0)
			var emitter_name := "ExhaustSmog" if i == 0 else "ExhaustSmog%d" % i
			var emitter := _create_smog_emitter(car_model, emitter_name, tip_pos)
			if count > 1:
				emitter.amount = maxi(5, int(emitter.amount * 0.65))
			_exhaust_emitters.append(emitter)
		exhaust_particles = _exhaust_emitters[0]
	else:
		var tl_l := car_model.get_node_or_null("TaillightL") as Node3D
		var rear_x: float = -car_length * 0.5
		var rear_z: float = 0.55
		var rear_y: float = 0.28

		if tl_l:
			rear_x = tl_l.position.x - 0.02
			rear_z = tl_l.position.z * 0.78
			rear_y = 0.28

		var b_rear: Node3D = null
		for c in car_model.get_children():
			if "Bumper" in c.name and ("R" in c.name or "Rear" in c.name):
				b_rear = c
				break
		if b_rear:
			rear_x = b_rear.position.x - 0.02
			rear_y = maxf(0.26, b_rear.position.y - 0.18)

		if car_type == CarType.SHIPPING_TRUCK:
			rear_y = 0.42
			rear_z = 0.75
		elif car_type == CarType.BUS:
			rear_y = 0.34
			rear_z = 0.70
		elif car_type == CarType.PICKUP or car_type == CarType.F150:
			rear_y = 0.32
			rear_z = 0.65
		elif car_type == CarType.TRUCK:
			rear_y = 0.32
			rear_z = 0.55

		var pipe := MeshInstance3D.new()
		pipe.name = "ExhaustPipe"
		pipe.mesh = _exhaust_mesh
		pipe.material_override = _exhaust_mat
		pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pipe.visibility_range_end = 80.0
		pipe.transform = Transform3D(
			Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(rear_x, rear_y, rear_z)
		)
		car_model.add_child(pipe)
		exhaust_pipe = pipe

		var tip_pos := Vector3(rear_x - 0.08, rear_y, rear_z)
		var emitter := _create_smog_emitter(car_model, "ExhaustSmog", tip_pos)
		_exhaust_emitters.append(emitter)
		exhaust_particles = emitter

	_apply_exhaust_visibility()
	_update_exhaust()


func _create_smog_emitter(parent: Node3D, node_name: String, local_pos: Vector3) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = node_name
	emitter.mesh = _smog_quad_mesh
	emitter.local_coords = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_range_end = 100.0

	var base_amount := 20
	var base_lifetime := 1.2
	var vel_min := 0.8
	var vel_max := 1.8
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	var scale_min := 0.65
	var scale_max := 1.35
	var emitter_mat: StandardMaterial3D = _smog_material
	var use_coal_curve := false

	var is_coal := car_type == CarType.F150 and has_smokestacks

	if is_coal:
		base_amount = randi_range(34, 44)
		base_lifetime = randf_range(1.6, 2.1)
		vel_min = 1.3
		vel_max = 2.4
		scale_min = 0.95
		scale_max = 1.85
		tint = Color(0.12, 0.105, 0.09, randf_range(0.85, 0.95))
		emitter_mat = _smog_material
		use_coal_curve = true
	else:
		match car_type:
			CarType.TRUCK, CarType.SHIPPING_TRUCK, CarType.BUS:
				# Heavy commercial diesel
				base_amount = randi_range(20, 28)
				base_lifetime = randf_range(1.15, 1.45)
				vel_min = 0.8
				vel_max = 1.6
				scale_min = randf_range(0.75, 0.90)
				scale_max = randf_range(1.30, 1.60)
				var tone := randf_range(0.66, 0.78)
				tint = Color(tone, tone * 0.98, tone * 0.96, randf_range(0.85, 1.05))
				emitter_mat = _smog_material if randf() > 0.3 else _smog_material_alt
			CarType.PICKUP, CarType.VAN, CarType.F150:
				# Utility workhorses
				base_amount = randi_range(15, 22)
				base_lifetime = randf_range(1.00, 1.25)
				vel_min = 0.7
				vel_max = 1.5
				scale_min = randf_range(0.65, 0.78)
				scale_max = randf_range(1.15, 1.45)
				var tone := randf_range(0.80, 0.90)
				tint = Color(tone, tone * 0.99, tone * 0.97, randf_range(0.75, 0.95))
				emitter_mat = _smog_material if randf() > 0.4 else _smog_material_alt
			CarType.SPORTS:
				# Sports cars: rapid exhaust jets, wispy plume, brisk dissipation
				base_amount = randi_range(10, 15)
				base_lifetime = randf_range(0.75, 0.95)
				vel_min = 1.3
				vel_max = 2.2
				scale_min = randf_range(0.45, 0.58)
				scale_max = randf_range(0.85, 1.10)
				tint = Color(0.94, 0.96, 1.0, randf_range(0.48, 0.62))
				emitter_mat = _smog_material_alt
			_:
				# Passenger cars (Sedan, SUV, Taxi, Hatchback, Minivan, Jeep)
				# Rolled personality for rich visual diversity
				var tier := randf()
				if tier < 0.25:
					# Clean / modern vehicle: faint wispy vapor
					base_amount = randi_range(10, 14)
					base_lifetime = randf_range(0.85, 1.05)
					vel_min = 0.7
					vel_max = 1.4
					scale_min = randf_range(0.45, 0.58)
					scale_max = randf_range(0.80, 1.05)
					tint = Color(
						randf_range(0.92, 0.97),
						randf_range(0.93, 0.98),
						randf_range(0.96, 1.0),
						randf_range(0.35, 0.50)
					)
					emitter_mat = _smog_material_alt
				elif tier < 0.80:
					# Standard commuter: classic soft gray-white billowing plume
					base_amount = randi_range(14, 20)
					base_lifetime = randf_range(0.95, 1.20)
					vel_min = 0.7
					vel_max = 1.5
					scale_min = randf_range(0.58, 0.72)
					scale_max = randf_range(1.05, 1.30)
					var tone := randf_range(0.86, 0.94)
					tint = Color(tone, tone, tone * 1.02, randf_range(0.60, 0.80))
					emitter_mat = _smog_material if randf() > 0.4 else _smog_material_alt
				else:
					# High-mileage beater / smoker: puffier, heavier plume
					base_amount = randi_range(18, 25)
					base_lifetime = randf_range(1.15, 1.40)
					vel_min = 0.8
					vel_max = 1.6
					scale_min = randf_range(0.70, 0.85)
					scale_max = randf_range(1.30, 1.60)
					tint = Color(
						randf_range(0.74, 0.84),
						randf_range(0.72, 0.81),
						randf_range(0.68, 0.77),
						randf_range(0.85, 1.05)
					)
					emitter_mat = _smog_material
	emitter.material_override = emitter_mat
	emitter.color_ramp = _coal_gradient if is_coal else _smog_gradient
	emitter.scale_amount_curve = (
		_coal_scale_curve if (is_coal or use_coal_curve) else _smog_scale_curve
	)
	emitter.amount = base_amount
	emitter.lifetime = base_lifetime
	emitter.lifetime_randomness = randf_range(0.35, 0.50)
	emitter.color = tint

	if is_coal:
		emitter.direction = Vector3(-0.65, 1.0, 0.0).normalized()
		emitter.spread = randf_range(30.0, 38.0)
	elif car_type == CarType.SPORTS:
		emitter.direction = Vector3(-1.0, randf_range(0.15, 0.28), 0.0)
		emitter.spread = randf_range(14.0, 20.0)
	else:
		emitter.direction = Vector3(-1.0, randf_range(0.20, 0.38), randf_range(-0.12, 0.12))
		emitter.spread = randf_range(20.0, 28.0)

	emitter.initial_velocity_min = vel_min
	emitter.initial_velocity_max = vel_max
	emitter.scale_amount_min = scale_min
	emitter.scale_amount_max = scale_max

	emitter.angle_min = 0.0
	emitter.angle_max = 360.0
	emitter.angular_velocity_min = randf_range(-28.0, -14.0)
	emitter.angular_velocity_max = randf_range(14.0, 28.0)

	emitter.tangential_accel_min = randf_range(-0.45, -0.15)
	emitter.tangential_accel_max = randf_range(0.15, 0.45)

	if is_coal:
		emitter.gravity = Vector3(0.0, randf_range(0.85, 1.25), 0.0)
	else:
		emitter.gravity = Vector3(0.0, randf_range(0.38, 0.65), 0.0)

	emitter.damping_min = randf_range(0.8, 1.1)
	emitter.damping_max = randf_range(1.2, 1.6)

	emitter.position = local_pos
	emitter.emitting = false
	parent.add_child(emitter)
	return emitter


func _apply_smokestacks_visibility() -> void:
	var car_model := get_active_model()
	if not car_model:
		return
	for child in car_model.get_children():
		if child is Node3D and child.name.begins_with("ExhaustStack"):
			child.visible = has_smokestacks


func _apply_exhaust_visibility() -> void:
	if not _exhaust_initialized:
		return
	if is_instance_valid(exhaust_pipe) and exhaust_pipe.name == "ExhaustPipe":
		exhaust_pipe.visible = has_exhaust
	for emitter in _exhaust_emitters:
		if is_instance_valid(emitter):
			emitter.visible = has_exhaust


func _update_exhaust() -> void:
	var should_emit := has_exhaust and state != State.PARKED
	for emitter in _exhaust_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = should_emit


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
		CarType.POLICE_SUV:
			car_length = 5.0
			car_width = 2.1
			shape_size = Vector3(5.0, 2.0, 2.1)
			shape_y = 1.0
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
		CarType.F150:
			car_length = 5.4
			car_width = 2.2
			shape_size = Vector3(5.3, 1.85, 2.2)
			shape_y = 0.9
		CarType.CYBERTRUCK:
			car_length = 5.5
			car_width = 2.2
			shape_size = Vector3(5.4, 1.8, 2.2)
			shape_y = 0.9
		_:
			car_length = 4.5
			car_width = 2.0
			shape_size = Vector3(4.5, 1.6, 2.0)
			shape_y = 0.8
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
	if _risk_commit_active:
		risk_commit_timer = maxf(0.0, risk_commit_timer - delta)
		if risk_commit_timer <= 0.0:
			_risk_commit_active = false

	if is_changing_lanes:
		lane_change_progress += delta / maxf(0.001, lane_change_duration)
		var t := clampf(lane_change_progress, 0.0, 1.0)
		var smooth_t := t * t * (3.0 - 2.0 * t)
		current_lateral_z = lerpf(lane_change_from_z, lane_change_to_z, smooth_t)
		if t >= 1.0:
			is_changing_lanes = false
			_risk_commit_active = false
			risk_commit_timer = 0.0
			lane_wander_offset = lane_wander_target
			lane_z = lane_change_target_lane_z
			current_lateral_z = lane_change_to_z
			lane_wander_start_offset = lane_wander_offset
			lane_wander_elapsed = 0.0
			lane_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
			lane_wander_duration = randf_range(WANDER_TRANSITION_MIN, WANDER_TRANSITION_MAX)
			set_turn_signal(TurnSignal.NONE)
			reset_lane_change_cooldown()
	else:
		_advance_lane_wander(delta)

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
	var z_pos := current_lateral_z
	if is_inside_tree():
		global_position = Vector3(current_x, 0.05, z_pos)
	else:
		position = Vector3(current_x, 0.05, z_pos)

	var dz_dt := 0.0
	if is_changing_lanes:
		var t := clampf(lane_change_progress, 0.0, 1.0)
		dz_dt = (
			(lane_change_to_z - lane_change_from_z)
			* (6.0 * t * (1.0 - t))
			/ maxf(0.001, lane_change_duration)
		)
	elif lane_wander_elapsed < lane_wander_duration and lane_wander_duration > 0.001:
		var t := clampf(lane_wander_elapsed / lane_wander_duration, 0.0, 1.0)
		var max_offset := get_max_lane_wander_offset()
		var eff_target := (
			0.0
			if state == State.APPROACHING
			else clampf(lane_wander_target, -max_offset, max_offset)
		)
		dz_dt = (
			(eff_target - lane_wander_start_offset) * (6.0 * t * (1.0 - t)) / lane_wander_duration
		)

	var dx_dt := speed * direction
	if absf(dx_dt) > 0.01:
		rotation.y = atan2(-dz_dt, dx_dt)
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
	if global_position.distance_to(body.global_position) > maxf(4.5, car_length * 0.5 + 1.5):
		return
	if body.is_in_group("player") or body.has_method("die"):
		body.die()


func _release_spot_reference(s: ParkingSpot) -> void:
	if s == null:
		return
	if s.lot != null:
		s.lot.release(s)
	else:
		if s.car == self:
			s.car = null
		s.state = ParkingSpot.State.FREE


func release_parking_reservations() -> void:
	if spot != null:
		var s := spot
		spot = null
		_release_spot_reference(s)
	if pending_destination_spot != null:
		var s := pending_destination_spot
		pending_destination_spot = null
		_release_spot_reference(s)


func cancel_shortcut() -> void:
	if pending_destination_spot != null:
		var s := pending_destination_spot
		pending_destination_spot = null
		_release_spot_reference(s)
	if state == State.SHORTCUT:
		release_parking_reservations()


func cancel_reservations() -> void:
	release_parking_reservations()


func despawn() -> void:
	release_parking_reservations()
	queue_free()


func _exit_tree() -> void:
	release_parking_reservations()


func _on_tree_exiting() -> void:
	if GameState.instance:
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
	release_parking_reservations()
