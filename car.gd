class_name Car
extends Area3D

enum CarType {
	SEDAN,
	SUV,
	TAXI,
	TRUCK,
	PICKUP,
	BUS
}

@export var car_type: CarType = CarType.SEDAN

# Authoritative simulation state (per TRAFFIC_SIMULATION.md)
var lane_id: int = 0
var lane_distance: float = 0.0
var speed: float = 14.0
var desired_speed: float = 14.0
var car_length: float = 4.5
var direction: float = 1.0 # +1.0 for Eastbound (+X), -1.0 for Westbound (-X)
var lane_z: float = 0.0
var lane_length: float = 140.0
var start_x: float = -70.0

@onready var _sedan: Node3D = $Visuals/Sedan
@onready var _suv: Node3D = $Visuals/SUV
@onready var _taxi: Node3D = $Visuals/Taxi
@onready var _truck: Node3D = $Visuals/Truck
@onready var _pickup: Node3D = $Visuals/Pickup
@onready var _bus: Node3D = $Visuals/Bus
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual_type()


func setup(p_lane_id: int, p_lane_z: float, p_dir: float, p_start_x: float, p_lane_len: float, p_speed: float, p_type: CarType) -> void:
	lane_id = p_lane_id
	lane_z = p_lane_z
	direction = p_dir
	start_x = p_start_x
	lane_length = p_lane_len
	lane_distance = 0.0
	speed = p_speed
	desired_speed = p_speed
	car_type = p_type
	
	_apply_visual_type()
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


func _update_dimensions() -> void:
	var shape_size: Vector3
	var shape_y: float
	match car_type:
		CarType.SEDAN:
			car_length = 4.2
			shape_size = Vector3(4.0, 1.4, 1.9)
			shape_y = 0.7
		CarType.SUV:
			car_length = 4.6
			shape_size = Vector3(4.5, 1.7, 2.0)
			shape_y = 0.85
		CarType.TAXI:
			car_length = 4.2
			shape_size = Vector3(4.0, 1.5, 1.9)
			shape_y = 0.75
		CarType.TRUCK:
			car_length = 5.2
			shape_size = Vector3(5.0, 2.2, 2.1)
			shape_y = 1.1
		CarType.PICKUP:
			car_length = 5.0
			shape_size = Vector3(5.0, 1.8, 2.1)
			shape_y = 0.9
		CarType.BUS:
			car_length = 9.0
			shape_size = Vector3(8.8, 2.7, 2.4)
			shape_y = 1.35
	var col = _collision_shape if _collision_shape else get_node_or_null("CollisionShape3D")
	if col:
		var box := BoxShape3D.new()
		box.size = shape_size
		col.shape = box
		col.position = Vector3(0.0, shape_y, 0.0)


## Advance vehicle along lane (kinematic state) and update 3D transform
func advance_simulation(delta: float) -> void:
	lane_distance += speed * delta
	update_presentation()
	_check_player_overlap()


func update_presentation() -> void:
	var current_x := start_x + (direction * lane_distance)
	global_position = Vector3(current_x, 0.05, lane_z)
	rotation.y = 0.0 if direction > 0.0 else PI


func _on_body_entered(body: Node3D) -> void:
	_check_hit(body)


func _check_player_overlap() -> void:
	for body in get_overlapping_bodies():
		_check_hit(body)


func _check_hit(body: Node3D) -> void:
	if body.is_in_group("player") or body.has_method("die"):
		body.die()
