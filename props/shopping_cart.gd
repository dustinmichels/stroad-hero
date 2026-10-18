class_name ShoppingCart
extends CharacterBody3D

@export var roll_speed := 4.0
@export var rolling_friction := 1.5

@onready var _interaction_area: Area3D = $InteractionArea
@onready var _hud := get_tree().get_first_node_in_group("hud") as HUD
@onready var _seat: Marker3D = $Seat
@onready var _exit_position: Marker3D = $ExitPosition

var _current_speed := 0.0
var _nearby_mats: CharacterBody3D = null
var _rider: CharacterBody3D = null


func _ready() -> void:
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	_update_prompt()


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.set_action_prompt(self, false)


func _physics_process(delta: float) -> void:
	if is_zero_approx(_current_speed):
		return
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if move_and_collide(forward * _current_speed * delta):
		_current_speed = 0.0
	else:
		_current_speed = move_toward(_current_speed, 0.0, rolling_friction * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("jump") or event.is_echo():
		return
	if _rider:
		_nearby_mats = _rider
		_rider.call("exit_cart", _exit_position)
		_rider = null
	elif _nearby_mats:
		_rider = _nearby_mats
		_nearby_mats = null
		_rider.call("enter_cart", self, _seat)
	else:
		return
	_update_prompt()
	get_viewport().set_input_as_handled()


func roll_from(impact_direction: Vector3) -> void:
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var forward_impact := impact_direction.normalized().dot(forward)
	if absf(forward_impact) < 0.1:
		return
	_current_speed = signf(forward_impact) * roll_speed


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_nearby_mats = body as CharacterBody3D
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_mats:
		_nearby_mats = null
		_update_prompt()


func _update_prompt() -> void:
	if _hud:
		_hud.set_action_prompt(self, _nearby_mats != null or _rider != null)
