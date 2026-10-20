class_name Mats
extends CharacterBody3D
## Mats: arrow keys walk relative to the current camera; Space hops.
## The model's front is local +Z, so the facing yaw is atan2(dir.x, dir.z).

signal died(death_position: Vector3)
signal respawned
signal stamina_changed(current: float, max_val: float)
signal sprint_started
signal sprint_stopped
signal stamina_depleted

@export var walk_speed := 5.5
@export var sprint_speed := 8.5
@export var max_stamina := 100.0
@export var stamina := 100.0
@export var sprint_drain_rate := 25.0
@export var stamina_recovery_rate := 30.0
@export var stamina_recovery_delay := 0.5
@export var acceleration := 30.0
@export var deceleration := 40.0
@export var jump_height := 0.5
@export var gravity := 20.0
@export var turn_speed := 14.0
## Tallest ledge (curb) Mats walks onto without jumping.
@export var step_height := 0.3
## Seconds to pause at death position showing the blood spot before screen goes dark.
@export var blood_linger_delay := 1.1
## Seconds for screen fade transitions.
@export var fade_duration := 0.4
## Seconds to emphasize the SPD counter while screen is dark.
@export var spd_emphasis_duration := 1.5
## Seconds to pause at death position before respawning (legacy/fallback without HUD).
@export var respawn_delay := 1.25

enum Headwear { HAIR, HAT, BEANIE }
enum PhoneMode { NONE, RINGING, TALKING }

@export_enum("Hair", "Red ball cap", "Beanie") var headwear: int = Headwear.HAIR:
	set(value):
		headwear = clampi(value, Headwear.HAIR, Headwear.BEANIE)
		if is_instance_valid(_visual):
			_visual.headwear = headwear
@export var jacket_color := Color(0.96, 0.48, 0.1, 1.0):
	set(value):
		jacket_color = value
		if is_instance_valid(_visual):
			_visual.jacket_color = jacket_color
@export var backpack_color := Color(0.2, 0.55, 0.3, 1.0):
	set(value):
		backpack_color = value
		if is_instance_valid(_visual):
			_visual.backpack_color = backpack_color
@export var shoe_color := Color(0.8, 0.14, 0.12, 1.0):
	set(value):
		shoe_color = value
		if is_instance_valid(_visual):
			_visual.shoe_color = shoe_color
@export var preview_mode := false

const STEP_SMOOTHING := 18.0

## Hip height above the cart's seat marker while kneeling in the basket.
const KNEEL_HIP_HEIGHT := 0.3
const KNEEL_HIP_ROTATION := 0.0
const KNEEL_KNEE_ROTATION := PI / 2.0
const KNEEL_ANKLE_ROTATION := PI / 2.0
const KNEEL_SHOULDER_ROTATION := -0.60
const KNEEL_ELBOW_ROTATION := -0.20

@onready var _visual: MatsRig = $Visual

var visual: MatsRig:
	get:
		return _visual
@onready var _camera := get_viewport().get_camera_3d()
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

## Vertical offset that eases the model over instant height changes (curbs).
var _step_offset := 0.0

## Lateral Z distance from road centerline (z=0) for roadside sidewalk respawning.
const ROADSIDE_Z: float = 13.85
## Min/max X bounds along the playable stroad corridor to keep respawns clear of tunnel abutments.
const MIN_RESPAWN_X: float = -95.0
const MAX_RESPAWN_X: float = 145.0

var _spawn_transform: Transform3D
var _last_death_position := Vector3.ZERO
var _has_death_position := false
var _is_dead := false
## True if Mats is currently dead and waiting to respawn.
var is_dead: bool:
	get:
		return _is_dead
var _control_forward := Vector3.FORWARD
var _control_right := Vector3.RIGHT
var _has_control_basis := false
var _mounted_cart: Node3D = null
var _pushing_cart: ShoppingCart = null
var _world_parent: Node = null
var _mount_tween: Tween = null

## True if Mats is currently pushing a shopping cart.
var is_pushing_cart: bool:
	get:
		return _pushing_cart != null
var is_sprinting := false
var is_exhausted := false
var _stamina_recovery_timer := 0.0

var _phone_mode: PhoneMode = PhoneMode.NONE
var phone_mode: PhoneMode:
	get:
		return _phone_mode

var phone_blend: float:
	get:
		return _visual.phone_blend if _visual else 0.0

var phone: Node3D:
	get:
		return _visual.phone if _visual else null

## True if Mats is currently holding his phone to his ear during a call.
var is_on_phone: bool:
	get:
		return _phone_mode == PhoneMode.TALKING

## True if Mats has his phone out for an incoming call.
var is_phone_ringing: bool:
	get:
		return _phone_mode == PhoneMode.RINGING


func _ready() -> void:
	_world_parent = get_parent()
	set_collision_mask_value(3, true)
	floor_snap_length = step_height + 0.05
	_spawn_transform = global_transform
	if not preview_mode:
		add_to_group("player")
	_visual.setup_materials(backpack_color, shoe_color, jacket_color)
	set_headwear(headwear)
	set_jacket_color(jacket_color)
	set_backpack_color(backpack_color)
	set_shoe_color(shoe_color)
	if _visual and _phone_mode != PhoneMode.NONE:
		_visual.set_phone_mode(_phone_mode as MatsRig.PhoneMode)


func _physics_process(delta: float) -> void:
	if preview_mode:
		velocity = Vector3.ZERO
		_animate(delta, true)
		return
	if _is_dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _movement_direction(input)
	var was_on_floor := is_on_floor()

	_update_sprint_and_stamina(delta, input, direction)

	var target_speed := sprint_speed if is_sprinting else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	horizontal = horizontal.move_toward(direction * target_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if was_on_floor:
		if Input.is_action_just_pressed("jump") and not is_pushing_cart:
			velocity.y = sqrt(2.0 * gravity * jump_height)
	else:
		velocity.y -= gravity * delta
	var y_before := global_position.y
	if was_on_floor:
		_try_step_up(horizontal * delta)
	move_and_slide()
	_handle_slide_collisions(horizontal)
	if was_on_floor and is_on_floor():
		_step_offset += y_before - global_position.y
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - exp(-STEP_SMOOTHING * delta))

	if not was_on_floor and is_on_floor():
		_visual.trigger_jump_squash()

	var target_yaw := atan2(direction.x, direction.z) if direction != Vector3.ZERO else NAN

	if is_pushing_cart:
		_update_pushing_cart(delta)

	_animate(delta, false, target_yaw)


func _update_sprint_and_stamina(delta: float, input: Vector2, direction: Vector3) -> void:
	var sprint_pressed := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
	var is_moving := not input.is_zero_approx() and direction != Vector3.ZERO
	var can_sprint := not is_pushing_cart and _mounted_cart == null

	if is_exhausted and stamina >= max_stamina * 0.25:
		is_exhausted = false

	var wants_sprint := sprint_pressed and is_moving and can_sprint

	if wants_sprint and not is_exhausted and stamina > 0.0:
		if not is_sprinting:
			is_sprinting = true
			sprint_started.emit()
		var old_stamina := stamina
		stamina = maxf(0.0, stamina - sprint_drain_rate * delta)
		_stamina_recovery_timer = stamina_recovery_delay
		if stamina != old_stamina:
			stamina_changed.emit(stamina, max_stamina)
		if stamina <= 0.0:
			stamina = 0.0
			is_exhausted = true
			is_sprinting = false
			sprint_stopped.emit()
			stamina_depleted.emit()
	else:
		if is_sprinting:
			is_sprinting = false
			sprint_stopped.emit()
		if _stamina_recovery_timer > 0.0:
			_stamina_recovery_timer = maxf(0.0, _stamina_recovery_timer - delta)
		elif stamina < max_stamina:
			var old_stamina := stamina
			stamina = minf(max_stamina, stamina + stamina_recovery_rate * delta)
			if stamina != old_stamina:
				stamina_changed.emit(stamina, max_stamina)
			if is_exhausted and stamina >= max_stamina * 0.25:
				is_exhausted = false


func _movement_direction(input: Vector2) -> Vector3:
	if input.is_zero_approx():
		_has_control_basis = false
		return Vector3.ZERO

	if not _has_control_basis:
		if _camera:
			_control_forward = -_camera.global_basis.z
			_control_forward.y = 0.0
			_control_forward = _control_forward.normalized()
			_control_right = _camera.global_basis.x
			_control_right.y = 0.0
			_control_right = _control_right.normalized()
		_has_control_basis = true

	return _control_right * input.x - _control_forward * input.y


func _handle_slide_collisions(impact_direction: Vector3) -> void:
	if impact_direction.is_zero_approx():
		return
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider()
		if collider is StreetTree:
			collider.rustle(impact_direction)
		elif collider and collider.has_method("roll_from"):
			if collider != _pushing_cart:
				collider.roll_from(impact_direction)


## Hair always shows; headwear sits over it with hair peeking out below.
func set_headwear(value: int) -> void:
	headwear = clampi(value, Headwear.HAIR, Headwear.BEANIE)
	if is_node_ready():
		_visual.set_headwear(headwear)


func set_jacket_color(color: Color) -> void:
	jacket_color = color
	if not is_node_ready():
		return
	_visual.set_jacket_color(color)


func set_backpack_color(color: Color) -> void:
	backpack_color = color
	if not is_node_ready():
		return
	_visual.set_backpack_color(color)


func set_shoe_color(color: Color) -> void:
	shoe_color = color
	if not is_node_ready():
		return
	_visual.set_shoe_color(color)


func get_pushed_cart() -> ShoppingCart:
	return _pushing_cart


func start_pushing_cart(cart: ShoppingCart) -> void:
	_pushing_cart = cart
	_visual.rotation.y = cart.global_rotation.y
	const PUSH_DISTANCE := 0.85
	var forward := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y)).normalized()
	global_position.x = cart.global_position.x - forward.x * PUSH_DISTANCE
	global_position.z = cart.global_position.z - forward.z * PUSH_DISTANCE


func stop_pushing_cart() -> void:
	if _pushing_cart:
		var cart := _pushing_cart
		_pushing_cart = null
		if cart.get_pusher() == self:
			cart.stop_pushing()


func _update_pushing_cart(_delta: float) -> void:
	if not _pushing_cart or not is_instance_valid(_pushing_cart):
		_pushing_cart = null
		return

	var forward := Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y)).normalized()
	_pushing_cart.global_rotation.y = _visual.rotation.y

	const PUSH_DISTANCE := 0.85
	var target_cart_pos := global_position + forward * PUSH_DISTANCE

	var space_state := get_world_3d().direct_space_state
	var ray_from := Vector3(target_cart_pos.x, global_position.y + 1.0, target_cart_pos.z)
	var ray_to := Vector3(target_cart_pos.x, global_position.y - 1.0, target_cart_pos.z)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = collision_mask
	query.exclude = [get_rid(), _pushing_cart.get_rid()]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		target_cart_pos.y = hit.position.y + 0.1
	else:
		target_cart_pos.y = global_position.y + 0.1

	_pushing_cart.global_position.y = target_cart_pos.y

	var horizontal_motion := Vector3(
		target_cart_pos.x - _pushing_cart.global_position.x,
		0.0,
		target_cart_pos.z - _pushing_cart.global_position.z
	)
	if not horizontal_motion.is_zero_approx():
		var col := _pushing_cart.move_and_collide(horizontal_motion)
		if col:
			var collider := col.get_collider()
			if collider and collider.has_method("roll_from"):
				collider.roll_from(forward * walk_speed)
			global_position.x = _pushing_cart.global_position.x - forward.x * PUSH_DISTANCE
			global_position.z = _pushing_cart.global_position.z - forward.z * PUSH_DISTANCE
			velocity = velocity.slide(col.get_normal())


func enter_cart(cart: Node3D, seat: Marker3D) -> void:
	if _mounted_cart:
		return
	if _pushing_cart:
		var pc := _pushing_cart
		_pushing_cart = null
		if pc.get_pusher() == self:
			pc.stop_pushing()
	_mounted_cart = cart
	if not _world_parent or not is_instance_valid(_world_parent):
		_world_parent = get_parent()
	if cart.has_method("set_rider"):
		cart.set_rider(self)
	velocity = Vector3.ZERO
	set_physics_process(false)
	_collision_shape.disabled = true
	reparent(seat, true)
	self.rotation.y = wrapf(self.rotation.y, -PI, PI)
	_visual.rotation.y = wrapf(_visual.rotation.y, -PI, PI)

	var starting_position := position
	var jump_peak := starting_position * 0.5 + Vector3.UP * 0.85
	var target_visual_pos := Vector3(0.0, KNEEL_HIP_HEIGHT - _visual.left_leg.position.y, 0.03)

	_mount_tween = create_tween().set_parallel(true)
	(
		_mount_tween
		. tween_property(self, "position", jump_peak, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_mount_tween
		. tween_property(self, "position", Vector3.ZERO, 0.16)
		. set_delay(0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_mount_tween
		. tween_property(self, "rotation", Vector3.ZERO, 0.32)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_mount_tween
		. tween_property(_visual, "rotation", Vector3.ZERO, 0.32)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_mount_tween
		. tween_property(_visual, "position", target_visual_pos, 0.32)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	for joint: Node3D in [_visual.left_leg, _visual.right_leg]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_HIP_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_visual.left_knee, _visual.right_knee]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_KNEE_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_visual.left_ankle, _visual.right_ankle]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_ANKLE_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_visual.left_arm, _visual.right_arm]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_SHOULDER_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			_mount_tween
			. tween_property(joint, "rotation:y", 0.0, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			_mount_tween
			. tween_property(joint, "rotation:z", 0.0, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_visual.left_elbow, _visual.right_elbow]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_ELBOW_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	if _visual.head:
		(
			_mount_tween
			. tween_property(_visual.head, "rotation", Vector3.ZERO, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	_mount_tween.chain().tween_callback(_sit_in_cart)


func exit_cart(exit_position: Marker3D) -> void:
	if not _mounted_cart:
		return
	if _mount_tween and _mount_tween.is_valid():
		_mount_tween.kill()
		_mount_tween = null
	if _mounted_cart and _mounted_cart.has_method("clear_rider"):
		_mounted_cart.clear_rider()
	var facing_yaw := _visual.global_rotation.y
	_mounted_cart = null
	reparent(_world_parent, true)
	global_basis = Basis()
	_visual.global_rotation = Vector3(0.0, facing_yaw, 0.0)
	_visual.position = Vector3.ZERO
	var destination := exit_position.global_position
	var jump_peak := (global_position + destination) * 0.5 + Vector3.UP * 0.85
	_mount_tween = create_tween().set_parallel(true)
	(
		_mount_tween
		. tween_property(self, "global_position", jump_peak, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_mount_tween
		. tween_property(self, "global_position", destination, 0.16)
		. set_delay(0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	for joint: Node3D in [
		_visual.left_leg,
		_visual.right_leg,
		_visual.left_knee,
		_visual.right_knee,
		_visual.left_ankle,
		_visual.right_ankle,
		_visual.left_arm,
		_visual.right_arm,
		_visual.left_elbow,
		_visual.right_elbow,
	]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", 0.0, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	_mount_tween.chain().tween_callback(_finish_exiting_cart)


func _sit_in_cart() -> void:
	_mount_tween = null
	# Kneel facing the cart's front: shins flat behind, soles up.
	_visual.rotation = Vector3.ZERO
	# Forward nudge keeps the upturned soles inside the basket's rear wall.
	_visual.position = Vector3(0.0, KNEEL_HIP_HEIGHT - _visual.left_leg.position.y, 0.03)
	_visual.set_limb_pose(
		KNEEL_HIP_ROTATION,
		KNEEL_KNEE_ROTATION,
		KNEEL_ANKLE_ROTATION,
		KNEEL_SHOULDER_ROTATION,
		KNEEL_ELBOW_ROTATION
	)
	_visual.left_arm.rotation.y = 0.0
	_visual.left_arm.rotation.z = 0.0
	_visual.right_arm.rotation.y = 0.0
	_visual.right_arm.rotation.z = 0.0
	if _visual.head:
		_visual.head.rotation = Vector3.ZERO


func _finish_exiting_cart() -> void:
	_mount_tween = null
	_visual.set_limb_pose(0.0, 0.0, 0.0, 0.0, 0.0)
	_collision_shape.disabled = false
	set_physics_process(true)


func _dismount_cart() -> void:
	if _mount_tween and _mount_tween.is_valid():
		_mount_tween.kill()
		_mount_tween = null
	if _mounted_cart:
		if _mounted_cart.has_method("clear_rider"):
			_mounted_cart.clear_rider()
		_mounted_cart = null
	if _world_parent and is_instance_valid(_world_parent) and get_parent() != _world_parent:
		reparent(_world_parent, true)


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_has_control_basis = false
	velocity = Vector3.ZERO
	if is_sprinting:
		is_sprinting = false
		sprint_stopped.emit()
	end_phone_call()
	if _visual:
		_visual.hide_phone()
	if _pushing_cart:
		var pc := _pushing_cart
		_pushing_cart = null
		if pc.get_pusher() == self:
			pc.stop_pushing()
	_dismount_cart()
	_last_death_position = global_position
	_has_death_position = true
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)
	died.emit(global_position)

	_visual.visible = false

	var tree := get_tree()
	if not tree:
		return

	# Linger for a moment showing the blood spot
	await tree.create_timer(blood_linger_delay).timeout
	if not is_inside_tree():
		return

	# Screen goes dark and emphasize SPD counter
	var hud: HUD = tree.get_first_node_in_group("hud") as HUD
	if hud and hud.has_method("fade_to_black"):
		await hud.fade_to_black(fade_duration)
		if not is_inside_tree():
			return
		await hud.emphasize_death_spd(spd_emphasis_duration)
		if not is_inside_tree():
			return
	else:
		await tree.create_timer(respawn_delay).timeout
		if not is_inside_tree():
			return

	respawn()

	if hud and hud.has_method("fade_from_black"):
		await hud.fade_from_black(fade_duration)
		if not is_inside_tree():
			return

	_is_dead = false


func respawn() -> void:
	if _pushing_cart:
		var pc := _pushing_cart
		_pushing_cart = null
		if pc.get_pusher() == self:
			pc.stop_pushing()
	_dismount_cart()
	velocity = Vector3.ZERO
	set_physics_process(true)
	var target_transform := _spawn_transform
	target_transform.origin = get_respawn_position()
	global_transform = target_transform
	reset_physics_interpolation()
	_step_offset = 0.0
	_visual.reset_pose()
	_visual.visible = true
	end_phone_call()
	if _visual:
		_visual.hide_phone()
	if _collision_shape:
		_collision_shape.disabled = false
	respawned.emit()
	stamina = max_stamina
	is_sprinting = false
	is_exhausted = false
	_stamina_recovery_timer = 0.0
	stamina_changed.emit(stamina, max_stamina)


## Calculates the respawn position at the nearest roadside sidewalk to where Mats died.
func get_respawn_position(death_pos: Vector3 = Vector3.INF) -> Vector3:
	var pos := death_pos
	if is_inf(pos.x):
		pos = _last_death_position if _has_death_position else _spawn_transform.origin
	var roadside_z := (
		absf(_spawn_transform.origin.z) if absf(_spawn_transform.origin.z) > 1.0 else ROADSIDE_Z
	)
	var side_z := -roadside_z if pos.z < 0.0 else roadside_z
	var side_x := clampf(pos.x, MIN_RESPAWN_X, MAX_RESPAWN_X)
	var side_y := _spawn_transform.origin.y
	return Vector3(side_x, side_y, side_z)


func set_phone_state(mode: PhoneMode) -> void:
	_phone_mode = mode
	if _visual:
		_visual.set_phone_mode(mode as MatsRig.PhoneMode)


func answer_phone() -> void:
	set_phone_state(PhoneMode.TALKING)


func end_phone_call() -> void:
	set_phone_state(PhoneMode.NONE)


func set_on_phone(on_phone: bool) -> void:
	if on_phone:
		answer_phone()
	else:
		end_phone_call()


## Lifts the body onto a low ledge blocking `motion`; floor snap settles it on top.
func _try_step_up(motion: Vector3) -> void:
	if motion.is_zero_approx():
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if hit.get_normal().angle_to(up_direction) <= floor_max_angle:
		return
	var lift := up_direction * step_height
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), motion):
		return
	global_position += lift


func _animate(delta: float, force_idle := false, target_yaw: float = NAN) -> void:
	var planar_vel := Vector2.ZERO if force_idle else Vector2(velocity.x, velocity.z)
	var on_floor := true if force_idle else is_on_floor()
	_visual.update_locomotion(
		delta,
		planar_vel,
		walk_speed,
		sprint_speed,
		on_floor,
		is_pushing_cart,
		_step_offset,
		target_yaw,
		turn_speed
	)
