class_name Car
extends Area3D

enum CarType {
	SEDAN,
	SUV,
	TAXI,
	TRUCK
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
	
	if is_node_ready():
		_apply_visual_type()
	
	update_presentation()


func _apply_visual_type() -> void:
	if not _sedan:
		return
	_sedan.visible = (car_type == CarType.SEDAN)
	_suv.visible = (car_type == CarType.SUV)
	_taxi.visible = (car_type == CarType.TAXI)
	_truck.visible = (car_type == CarType.TRUCK)


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
