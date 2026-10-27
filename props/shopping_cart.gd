class_name ShoppingCart
extends CharacterBody3D

@export var roll_speed := 4.0
@export var rolling_friction := 1.5
@export var hud: HUD = null

@onready var _interaction_area: Area3D = $InteractionArea
@onready var _hud: HUD = (
	hud if hud else (get_tree().get_first_node_in_group("hud") as HUD if is_inside_tree() else null)
)
@onready var _seat: Marker3D = $Seat
@onready var _exit_position: Marker3D = $ExitPosition

var _current_speed := 0.0
var _nearby_mats: Mats = null
var _rider: Mats = null
var _pusher: Mats = null
var _last_was_behind := false
var _spawn_transform: Transform3D


func _ready() -> void:
	add_to_group(&"shopping_carts")
	_spawn_transform = global_transform
	if _hud == null:
		if hud != null:
			_hud = hud
		elif is_inside_tree():
			_hud = get_tree().get_first_node_in_group("hud") as HUD
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	_update_prompt()


func set_hud(h: HUD) -> void:
	hud = h
	_hud = h


func _exit_tree() -> void:
	if _pusher:
		stop_pushing()
	if _rider and _rider.has_signal("died") and _rider.died.is_connected(_on_rider_died):
		_rider.died.disconnect(_on_rider_died)
	if is_instance_valid(_hud):
		_hud.set_action_prompt(self, false)


## Rolls the cart back to its scene position, as at the start of a day. Riders and pushers must
## already be released (Mats.reset_to_start does this).
func reset_to_start() -> void:
	_current_speed = 0.0
	global_transform = _spawn_transform
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _rider and _rider.has_method("update_stroad_side"):
		_rider.update_stroad_side()
	if _pusher != null:
		return
	if _nearby_mats != null and _rider == null:
		var behind := is_mats_behind(_nearby_mats)
		if behind != _last_was_behind:
			_last_was_behind = behind
			_update_prompt()
	if is_zero_approx(_current_speed):
		return
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if move_and_collide(forward * _current_speed * delta):
		_current_speed = 0.0
	else:
		_current_speed = move_toward(_current_speed, 0.0, rolling_friction * delta)


func _is_push_action(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("push_cart"):
		return true
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P or event.physical_keycode == KEY_P:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _is_push_action(event):
		if _pusher:
			stop_pushing()
			get_viewport().set_input_as_handled()
		elif _nearby_mats and is_mats_behind(_nearby_mats):
			start_pushing(_nearby_mats)
			get_viewport().set_input_as_handled()
		_update_prompt()
		return

	if not event.is_action_pressed("jump") or event.is_echo():
		return
	if _rider:
		var exiting_rider := _rider
		clear_rider()
		_nearby_mats = exiting_rider
		exiting_rider.call("exit_cart", _exit_position)
	elif _pusher:
		var new_rider := _pusher
		stop_pushing()
		set_rider(new_rider)
		new_rider.call("enter_cart", self, _seat)
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


func get_pusher() -> Mats:
	return _pusher


func is_being_pushed() -> bool:
	return _pusher != null


func is_mats_behind(mats: Mats) -> bool:
	if not mats or not is_instance_valid(mats) or mats.is_dead:
		return false
	if mats == _rider:
		return false
	var local_pos := to_local(mats.global_position)
	return local_pos.z < -0.2 and absf(local_pos.x) < 0.85 and local_pos.length() < 2.0


func start_pushing(mats: Mats) -> void:
	if _pusher == mats or _rider != null:
		return
	if mats.is_pushing_cart and mats.get_pushed_cart() != self:
		return
	_pusher = mats
	_nearby_mats = null
	_current_speed = 0.0
	add_collision_exception_with(mats)
	mats.add_collision_exception_with(self)
	if mats.has_signal("died") and not mats.died.is_connected(_on_pusher_died):
		mats.died.connect(_on_pusher_died)
	mats.start_pushing_cart(self)
	_update_prompt()


func stop_pushing() -> void:
	if not _pusher:
		return
	var former_pusher := _pusher
	_pusher = null
	remove_collision_exception_with(former_pusher)
	former_pusher.remove_collision_exception_with(self)
	if former_pusher.has_signal("died") and former_pusher.died.is_connected(_on_pusher_died):
		former_pusher.died.disconnect(_on_pusher_died)
	if former_pusher.is_pushing_cart and former_pusher.get_pushed_cart() == self:
		former_pusher.stop_pushing_cart()

	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var forward_vel := former_pusher.velocity.dot(forward)
	if forward_vel > 0.5:
		_current_speed = minf(forward_vel, roll_speed)

	if is_instance_valid(former_pusher) and not former_pusher.is_dead:
		var dist := global_position.distance_to(former_pusher.global_position)
		if dist < 2.0:
			_nearby_mats = former_pusher
			_last_was_behind = is_mats_behind(_nearby_mats)
	_update_prompt()


func _on_pusher_died(_death_position: Vector3) -> void:
	stop_pushing()


func die() -> void:
	if _rider and _rider.has_method("die"):
		_rider.die()
	elif _pusher and _pusher.has_method("die"):
		_pusher.die()


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
	if body.is_in_group("player") and body != _rider and body != _pusher:
		var m := body as Mats
		if m and m.is_pushing_cart and m.get_pushed_cart() != self:
			return
		_nearby_mats = m
		_last_was_behind = is_mats_behind(_nearby_mats)
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_mats:
		_nearby_mats = null
		_last_was_behind = false
		_update_prompt()


func _update_prompt() -> void:
	if not _hud:
		return
	if _rider != null:
		_hud.set_action_prompt(self, true, "space to exit")
	elif _pusher != null:
		_hud.set_action_prompt(self, true, "p to stop pushing\nspace to jump in")
	elif _nearby_mats != null:
		if is_mats_behind(_nearby_mats):
			_hud.set_action_prompt(self, true, "p to push\nspace to jump in")
		else:
			_hud.set_action_prompt(self, true, "space to jump in")
	else:
		_hud.set_action_prompt(self, false)
