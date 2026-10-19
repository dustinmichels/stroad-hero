class_name ShoppingCart
extends CharacterBody3D

@export var roll_speed := 4.0
@export var rolling_friction := 1.5

@onready var _interaction_area: Area3D = $InteractionArea
@onready var _hud := get_tree().get_first_node_in_group("hud") as HUD
@onready var _seat: Marker3D = $Seat
@onready var _exit_position: Marker3D = $ExitPosition

var _current_speed := 0.0
var _nearby_mats: Mats = null
var _rider: Mats = null


func _ready() -> void:
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	_update_prompt()


func _exit_tree() -> void:
	if _rider and _rider.has_signal("died") and _rider.died.is_connected(_on_rider_died):
		_rider.died.disconnect(_on_rider_died)
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
		var exiting_rider := _rider
		clear_rider()
		_nearby_mats = exiting_rider
		exiting_rider.call("exit_cart", _exit_position)
	elif _nearby_mats:
		var new_rider := _nearby_mats
		set_rider(new_rider)
		new_rider.call("enter_cart", self, _seat)
	else:
		return
	_update_prompt()
	get_viewport().set_input_as_handled()


func set_rider(rider: Mats) -> void:
	if _rider == rider:
		return
	if _rider and _rider.has_signal("died") and _rider.died.is_connected(_on_rider_died):
		_rider.died.disconnect(_on_rider_died)
	_rider = rider
	if _rider:
		_nearby_mats = null
		if _rider.has_signal("died") and not _rider.died.is_connected(_on_rider_died):
			_rider.died.connect(_on_rider_died)
	_update_prompt()


func clear_rider() -> void:
	set_rider(null)


func die() -> void:
	if _rider and _rider.has_method("die"):
		_rider.die()


func _on_rider_died(_death_position: Vector3) -> void:
	clear_rider()


func roll_from(impact_direction: Vector3) -> void:
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var forward_impact := impact_direction.normalized().dot(forward)
	if absf(forward_impact) < 0.1:
		return
	_current_speed = signf(forward_impact) * roll_speed


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body != _rider:
		_nearby_mats = body as Mats
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_mats:
		_nearby_mats = null
		_update_prompt()


func _update_prompt() -> void:
	if _hud:
		_hud.set_action_prompt(self, _nearby_mats != null or _rider != null)
