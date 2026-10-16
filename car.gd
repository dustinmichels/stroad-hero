class_name Car
extends Area3D
const Errand = preload("res://errand.gd")

enum CarType { SEDAN, SUV, TAXI, TRUCK, PICKUP, BUS }

enum Motion { LANE, PATH }

enum State {
	CRUISING, APPROACHING, TO_SPOT, PARKED, REVERSING_OUT, TO_EXIT, WAITING_TO_MERGE, MERGING
}

const PARKING_CAR_TYPES: Array[CarType] = [
	CarType.SEDAN,
	CarType.SUV,
	CarType.TAXI,
	CarType.PICKUP,
]


static func is_type_parkable(type: CarType) -> bool:
	match type:
		CarType.SEDAN, CarType.SUV, CarType.TAXI, CarType.PICKUP:
			return true
		CarType.BUS, CarType.TRUCK:
			return false
	return false


func can_park() -> bool:
	return is_type_parkable(car_type)


@export var car_type: CarType = CarType.SEDAN

# Authoritative simulation state (per TRAFFIC_SIMULATION.md)
var lane_id: int = 0
var motion := Motion.LANE
var state := State.CRUISING


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
	return "UNKNOWN"


var path: Curve3D = null
var path_distance: float = 0.0
var lane_distance: float = 0.0
var lane_speed: float = 14.0
var speed: float = 14.0
var desired_speed: float = 14.0
var car_length: float = 4.5
var car_width: float = 2.0
var direction: float = 1.0  # +1.0 for Eastbound (+X), -1.0 for Westbound (-X)
var lane_z: float = 0.0
var lane_length: float = 140.0
var start_x: float = -70.0
var spot: ParkingSpot = null
var dwell_left: float = 0.0
var errand: Errand = null

const WHEEL_RADIUS := 0.35
const BASE_WHEEL_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const STOP_SPEED := 0.1
const BLOCKER_LAYER := 4  # Layer 3 (1 << 2)

static var _spoke_mesh: BoxMesh
static var _hub_mesh: CylinderMesh
static var _chrome_mat: StandardMaterial3D

var wheel_rotation: float = 0.0
var _wheels_initialized: bool = false
var _active_wheels: Array[Node3D] = []

@onready var _sedan: Node3D = $Visuals/Sedan
@onready var _suv: Node3D = $Visuals/SUV
@onready var _taxi: Node3D = $Visuals/Taxi
@onready var _truck: Node3D = $Visuals/Truck
@onready var _pickup: Node3D = $Visuals/Pickup
@onready var _bus: Node3D = $Visuals/Bus
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var blocker: AnimatableBody3D = null
var _blocker_shape: CollisionShape3D = null
var _blocking: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	tree_exiting.connect(_on_tree_exiting)
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
	_setup_wheels()
	_apply_visual_type()


func _physics_process(_delta: float) -> void:
	_update_blocker_layer()


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
				var spoke := MeshInstance3D.new()
				spoke.mesh = _spoke_mesh
				spoke.name = "Spoke"
				child.add_child(spoke)

				var hub := MeshInstance3D.new()
				hub.mesh = _hub_mesh
				hub.name = "Hub"
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


func follow_path(curve: Curve3D, from_end := false) -> void:
	motion = Motion.PATH
	path = curve
	if from_end and curve != null:
		path_distance = curve.get_baked_length()
	else:
		path_distance = 0.0
	update_presentation()


func _apply_visual_type() -> void:
	var sedan = _sedan if _sedan else get_node_or_null("Visuals/Sedan")
	var suv = _suv if _suv else get_node_or_null("Visuals/SUV")
	var taxi = _taxi if _taxi else get_node_or_null("Visuals/Taxi")
	var truck = _truck if _truck else get_node_or_null("Visuals/Truck")
	var pickup = _pickup if _pickup else get_node_or_null("Visuals/Pickup")
	var bus = _bus if _bus else get_node_or_null("Visuals/Bus")

	if sedan:
		sedan.visible = (car_type == CarType.SEDAN)
	if suv:
		suv.visible = (car_type == CarType.SUV)
	if taxi:
		taxi.visible = (car_type == CarType.TAXI)
	if truck:
		truck.visible = (car_type == CarType.TRUCK)
	if pickup:
		pickup.visible = (car_type == CarType.PICKUP)
	if bus:
		bus.visible = (car_type == CarType.BUS)

	_update_dimensions()

	_setup_wheels()
	_active_wheels.clear()
	var active_node: Node3D = null
	match car_type:
		CarType.SEDAN:
			active_node = sedan
		CarType.SUV:
			active_node = suv
		CarType.TAXI:
			active_node = taxi
		CarType.TRUCK:
			active_node = truck
		CarType.PICKUP:
			active_node = pickup
		CarType.BUS:
			active_node = bus
	if active_node:
		for child in active_node.get_children():
			if child is Node3D and child.name.begins_with("Wheel"):
				_active_wheels.append(child)


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
	lane_distance += speed * delta
	update_presentation()
	_check_player_overlap()
	_update_blocker_layer()


func advance_path(delta: float) -> bool:
	if path == null:
		return true
	var length := path.get_baked_length()
	if length <= 0.0:
		path_distance = 0.0
		update_presentation()
		_check_player_overlap()
		_update_blocker_layer()
		return true

	path_distance += speed * delta
	var arrived := false
	if speed < 0.0:
		if path_distance <= 0.0:
			path_distance = 0.0
			arrived = true
	else:
		if path_distance >= length:
			path_distance = length
			arrived = true

	path_distance = clampf(path_distance, 0.0, length)
	update_presentation()
	_check_player_overlap()
	_update_blocker_layer()
	return arrived


func update_presentation() -> void:
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
			wheel_rotation = fmod(-path_distance / WHEEL_RADIUS, TAU)
			_update_wheels()
		return
	if spot != null:
		global_transform = spot.transform
		return
	var current_x := start_x + (direction * lane_distance)
	global_position = Vector3(current_x, 0.05, lane_z)
	rotation.y = 0.0 if direction > 0.0 else PI

	wheel_rotation = fmod(-lane_distance / WHEEL_RADIUS, TAU)
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


func _check_player_overlap() -> void:
	for body in get_overlapping_bodies():
		_check_hit(body)


func _check_hit(body: Node3D) -> void:
	if not is_moving():
		return
	if body.is_in_group("player") or body.has_method("die"):
		body.die()


func _on_tree_exiting() -> void:
	if spot != null:
		if spot.lot != null:
			spot.lot.release(spot)
		else:
			if spot.car == self:
				spot.car = null
			spot.state = ParkingSpot.State.FREE
			spot = null
