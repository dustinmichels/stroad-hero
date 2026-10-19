class_name Mats
extends CharacterBody3D
## Mats: arrow keys walk relative to the current camera; Space hops.
## The model's front is local +Z, so the facing yaw is atan2(dir.x, dir.z).

signal died(death_position: Vector3)
signal respawned

@export var walk_speed := 5.5
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
@export var spd_emphasis_duration := 0.8
## Seconds to pause at death position before respawning (legacy/fallback without HUD).
@export var respawn_delay := 1.25

enum Headwear { HAIR, HAT, BEANIE }
enum PhoneMode { NONE, RINGING, TALKING }

@export_enum("Hair", "Red ball cap", "Beanie") var headwear: int = Headwear.HAIR
@export var jacket_color := Color(0.96, 0.48, 0.1, 1.0)
@export var backpack_color := Color(0.2, 0.55, 0.3, 1.0)
@export var shoe_color := Color(0.8, 0.14, 0.12, 1.0)
@export var preview_mode := false

const THIGH_LENGTH := 0.28
const SHIN_LENGTH := 0.25
const SHOE_HEIGHT := 0.07
const LEG_LENGTH := THIGH_LENGTH + SHIN_LENGTH + SHOE_HEIGHT
const LEG_SWING := 0.6
## Leg-swing radians per meter walked, derived from leg length and swing.
const STRIDE_RATE := PI / (2.0 * LEG_LENGTH * sin(LEG_SWING))
const ARM_SWING := 0.5
const POSE_SHARPNESS := 50.0
const STEP_SMOOTHING := 18.0
## Knee flex while a leg swings forward, plus a slight bend while it carries weight.
const KNEE_SWING := 0.9
const KNEE_STANCE := 0.12
const ELBOW_REST := 0.25
const ELBOW_SWING := 0.5
## Fraction of hip + knee rotation the ankle cancels, keeping shoes near level.
const ANKLE_LEVELING := 0.7

## Run blend tuning (blends in between RUN_SPEED_THRESHOLD and walk_speed).
const RUN_SPEED_THRESHOLD := 2.5
const RUN_KNEE_SWING := 1.25
const RUN_LEAN := 0.10
const RUN_ARM_SWING := 0.65
const RUN_ELBOW_BEND := 0.35

## Landing squash tuning.
const SQUASH_KNEE_BEND := 0.40
const SQUASH_HIP_BEND := 0.20
const SQUASH_SCALE_Y := 0.10
const SQUASH_SCALE_XZ := 0.08

## Hip height above the cart's seat marker while kneeling in the basket.
const KNEEL_HIP_HEIGHT := 0.3
const KNEEL_HIP_ROTATION := 0.0
const KNEEL_KNEE_ROTATION := PI / 2.0
const KNEEL_ANKLE_ROTATION := PI / 2.0
const KNEEL_SHOULDER_ROTATION := -0.60
const KNEEL_ELBOW_ROTATION := -0.20

## Idle animation tuning.
const IDLE_BREATH_RATE := 2.4
const IDLE_SCALE_BREATH := 0.015
const IDLE_ARM_REST_Z := 0.06
const IDLE_ARM_BREATH_Z := 0.02
const IDLE_ARM_BREATH_X := 0.025
const IDLE_SWAY_RATE := 0.8
const IDLE_SWAY_ANGLE := 0.02

@onready var _visual: Node3D = $Visual
@onready var _left_leg: Node3D = $Visual/LeftLegPivot
@onready var _right_leg: Node3D = $Visual/RightLegPivot
@onready var _left_arm: Node3D = $Visual/LeftArmPivot
@onready var _right_arm: Node3D = $Visual/RightArmPivot
@onready var _left_knee: Node3D = $Visual/LeftLegPivot/Knee
@onready var _right_knee: Node3D = $Visual/RightLegPivot/Knee
@onready var _left_ankle: Node3D = $Visual/LeftLegPivot/Knee/Shoe
@onready var _right_ankle: Node3D = $Visual/RightLegPivot/Knee/Shoe
@onready var _left_elbow: Node3D = $Visual/LeftArmPivot/Elbow
@onready var _right_elbow: Node3D = $Visual/RightArmPivot/Elbow
@onready var _head: Node3D = $Visual/Head
@onready var _hat: Node3D = $Visual/Head/Hat
@onready var _cap: MeshInstance3D = $Visual/Head/Hat/Cap
@onready var _beanie: MeshInstance3D = $Visual/Head/Hat/Beanie
@onready var _backpack: MeshInstance3D = $Visual/Backpack
@onready var _left_shoe_upper: MeshInstance3D = $Visual/LeftLegPivot/Knee/Shoe/Upper
@onready var _right_shoe_upper: MeshInstance3D = $Visual/RightLegPivot/Knee/Shoe/Upper
@onready var _torso: MeshInstance3D = $Visual/Torso
@onready var _left_upper_arm: MeshInstance3D = $Visual/LeftArmPivot/UpperArm
@onready var _right_upper_arm: MeshInstance3D = $Visual/RightArmPivot/UpperArm
@onready var _left_forearm: MeshInstance3D = $Visual/LeftArmPivot/Elbow/Forearm
@onready var _right_forearm: MeshInstance3D = $Visual/RightArmPivot/Elbow/Forearm
@onready var _camera := get_viewport().get_camera_3d()
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _stride_phase := 0.0
var _squash := 0.0
## Vertical offset that eases the model over instant height changes (curbs).
var _step_offset := 0.0
var _idle_time := 0.0

var _spawn_transform: Transform3D
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
var _jacket_material: StandardMaterial3D = null
var _jacket_trim_material: StandardMaterial3D = null

var _phone_mode: PhoneMode = PhoneMode.NONE
var _phone_blend := 0.0
var _phone_arm_pose := Vector3.ZERO
var _phone_elbow_pose := Vector3.ZERO
var _phone_head_pose := Vector3.ZERO
var _phone: Node3D = null

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
	var material := StandardMaterial3D.new()
	material.roughness = 0.8
	_backpack.material_override = material
	var shoe_material := StandardMaterial3D.new()
	shoe_material.roughness = 0.75
	_left_shoe_upper.material_override = shoe_material
	_right_shoe_upper.material_override = shoe_material
	_jacket_material = StandardMaterial3D.new()
	_jacket_material.roughness = 0.7
	_jacket_trim_material = StandardMaterial3D.new()
	_jacket_trim_material.roughness = 0.75
	_torso.set_surface_override_material(0, _jacket_material)
	_torso.set_surface_override_material(1, _jacket_trim_material)
	_left_upper_arm.set_surface_override_material(0, _jacket_material)
	_right_upper_arm.set_surface_override_material(0, _jacket_material)
	_left_forearm.set_surface_override_material(0, _jacket_material)
	_left_forearm.set_surface_override_material(1, _jacket_trim_material)
	_right_forearm.set_surface_override_material(0, _jacket_material)
	_right_forearm.set_surface_override_material(1, _jacket_trim_material)
	set_headwear(headwear)
	set_jacket_color(jacket_color)
	set_backpack_color(backpack_color)
	set_shoe_color(shoe_color)
	_build_phone()


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

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	horizontal = horizontal.move_toward(direction * walk_speed, rate * delta)
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
		_squash = 1.0

	if direction != Vector3.ZERO:
		var target_yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(
			_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
		)

	if is_pushing_cart:
		_update_pushing_cart(delta)

	_animate(delta)


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
		_hat.visible = headwear != Headwear.HAIR
		if _cap:
			_cap.visible = headwear == Headwear.HAT
		if _beanie:
			_beanie.visible = headwear == Headwear.BEANIE


func set_jacket_color(color: Color) -> void:
	jacket_color = color
	if not is_node_ready():
		return
	if _jacket_material:
		_jacket_material.albedo_color = jacket_color
	if _jacket_trim_material:
		_jacket_trim_material.albedo_color = jacket_color.darkened(0.2)


func set_backpack_color(color: Color) -> void:
	backpack_color = color
	if not is_node_ready():
		return
	var material := _backpack.material_override as StandardMaterial3D
	if material:
		material.albedo_color = backpack_color


func set_shoe_color(color: Color) -> void:
	shoe_color = color
	if not is_node_ready():
		return
	var material := _left_shoe_upper.material_override as StandardMaterial3D
	if material:
		material.albedo_color = shoe_color


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
	var target_visual_pos := Vector3(0.0, KNEEL_HIP_HEIGHT - _left_leg.position.y, 0.03)

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
	for joint: Node3D in [_left_leg, _right_leg]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_HIP_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_left_knee, _right_knee]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_KNEE_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_left_ankle, _right_ankle]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_ANKLE_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_left_arm, _right_arm]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_SHOULDER_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			_mount_tween
			. tween_property(joint, "rotation:z", 0.0, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [_left_elbow, _right_elbow]:
		(
			_mount_tween
			. tween_property(joint, "rotation:x", KNEEL_ELBOW_ROTATION, 0.32)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	if _head:
		(
			_mount_tween
			. tween_property(_head, "rotation", Vector3.ZERO, 0.32)
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
		_left_leg,
		_right_leg,
		_left_knee,
		_right_knee,
		_left_ankle,
		_right_ankle,
		_left_arm,
		_right_arm,
		_left_elbow,
		_right_elbow,
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
	_visual.position = Vector3(0.0, KNEEL_HIP_HEIGHT - _left_leg.position.y, 0.03)
	_set_limb_pose(
		KNEEL_HIP_ROTATION,
		KNEEL_KNEE_ROTATION,
		KNEEL_ANKLE_ROTATION,
		KNEEL_SHOULDER_ROTATION,
		KNEEL_ELBOW_ROTATION
	)
	_left_arm.rotation.z = 0.0
	_right_arm.rotation.z = 0.0
	if _head:
		_head.rotation = Vector3.ZERO


func _finish_exiting_cart() -> void:
	_mount_tween = null
	_set_limb_pose(0.0, 0.0, 0.0, 0.0, 0.0)
	_collision_shape.disabled = false
	set_physics_process(true)


func _set_limb_pose(hip: float, knee: float, ankle: float, shoulder: float, elbow: float) -> void:
	for joint: Node3D in [_left_leg, _right_leg]:
		joint.rotation.x = hip
	for joint: Node3D in [_left_knee, _right_knee]:
		joint.rotation.x = knee
	for joint: Node3D in [_left_ankle, _right_ankle]:
		joint.rotation.x = ankle
	for joint: Node3D in [_left_arm, _right_arm]:
		joint.rotation.x = shoulder
	for joint: Node3D in [_left_elbow, _right_elbow]:
		joint.rotation.x = elbow


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
	end_phone_call()
	_phone_blend = 0.0
	if _phone:
		_phone.visible = false
	if _pushing_cart:
		var pc := _pushing_cart
		_pushing_cart = null
		if pc.get_pusher() == self:
			pc.stop_pushing()
	_dismount_cart()
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
	set_physics_process(true)
	global_transform = _spawn_transform
	reset_physics_interpolation()
	_stride_phase = 0.0
	_squash = 0.0
	_step_offset = 0.0
	_idle_time = 0.0
	_visual.position = Vector3.ZERO
	_visual.rotation.x = 0.0
	_visual.rotation.y = PI
	_visual.rotation.z = 0.0
	_visual.scale = Vector3.ONE
	_visual.visible = true
	_set_limb_pose(0.0, 0.0, 0.0, 0.0, 0.0)
	_left_arm.rotation.z = 0.0
	_right_arm.rotation.z = 0.0
	if _head:
		_head.rotation = Vector3.ZERO
	end_phone_call()
	_phone_blend = 0.0
	if _phone:
		_phone.visible = false
	if _collision_shape:
		_collision_shape.disabled = false
	respawned.emit()


func set_phone_state(mode: PhoneMode) -> void:
	_phone_mode = mode
	if _phone and mode != PhoneMode.NONE:
		_phone.visible = true


func answer_phone() -> void:
	set_phone_state(PhoneMode.TALKING)


func end_phone_call() -> void:
	set_phone_state(PhoneMode.NONE)


func set_on_phone(on_phone: bool) -> void:
	if on_phone:
		answer_phone()
	else:
		end_phone_call()


func _build_phone() -> void:
	if _phone or not _right_elbow:
		return
	_phone = Node3D.new()
	_phone.name = "Phone"
	_phone.visible = false
	_phone.position = Vector3(0.0, -0.23, 0.02)
	_phone.rotation = Vector3(0.0, 0.0, PI)

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.056, 0.11, 0.012)
	var body_inst := MeshInstance3D.new()
	body_inst.name = "Body"
	body_inst.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.14, 0.15, 0.18, 1.0)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.35
	body_inst.material_override = body_mat
	_phone.add_child(body_inst)

	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.048, 0.098, 0.002)
	var screen_inst := MeshInstance3D.new()
	screen_inst.name = "Screen"
	screen_inst.mesh = screen_mesh
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.08, 0.12, 1.0)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.18, 0.65, 0.85, 1.0)
	screen_mat.emission_energy_multiplier = 0.8
	screen_inst.material_override = screen_mat
	screen_inst.position = Vector3(0.0, 0.0, -0.006)
	_phone.add_child(screen_inst)

	_right_elbow.add_child(_phone)


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


func _animate(delta: float, force_idle := false) -> void:
	var speed := 0.0 if force_idle else Vector2(velocity.x, velocity.z).length()
	var walk_blend := clampf(speed / walk_speed, 0.0, 1.0)
	var on_floor := true if force_idle else is_on_floor()
	var idle_blend := (1.0 - walk_blend) if on_floor else 0.0
	var run_blend := (
		clampf((speed - RUN_SPEED_THRESHOLD) / (walk_speed - RUN_SPEED_THRESHOLD), 0.0, 1.0)
		if on_floor
		else 0.0
	)

	_idle_time += delta
	_stride_phase = fmod(_stride_phase + speed * STRIDE_RATE * delta, TAU)
	var swing := sin(_stride_phase)
	var breath := sin(_idle_time * IDLE_BREATH_RATE)
	var sway := sin(_idle_time * IDLE_SWAY_RATE)

	# Leg targets
	var leg_x := swing * LEG_SWING * walk_blend
	var idle_leg_l := maxf(0.0, sway) * 0.04 * idle_blend
	var idle_leg_r := maxf(0.0, -sway) * 0.04 * idle_blend
	var squash_hip := -SQUASH_HIP_BEND * _squash
	var target_left_leg_x := leg_x + idle_leg_l + squash_hip
	var target_right_leg_x := -leg_x + idle_leg_r + squash_hip

	# Arm targets
	var arm_swing := lerpf(ARM_SWING, RUN_ARM_SWING, run_blend)
	var walk_arm_x := -swing * arm_swing * walk_blend
	var idle_arm_x := (0.02 + cos(_idle_time * IDLE_BREATH_RATE) * IDLE_ARM_BREATH_X) * idle_blend
	var idle_arm_z := (IDLE_ARM_REST_Z + breath * IDLE_ARM_BREATH_Z) * idle_blend
	var target_left_arm_x := walk_arm_x + idle_arm_x
	var target_right_arm_x := -walk_arm_x + idle_arm_x
	var target_left_arm_z := idle_arm_z
	var target_right_arm_z := -idle_arm_z

	# Joint targets: a knee flexes while its leg swings forward (left: cos < 0), and an
	# elbow bends further while its arm leads (left: swing > 0).
	var stride := cos(_stride_phase)
	var knee_swing := lerpf(KNEE_SWING, RUN_KNEE_SWING, run_blend)
	var squash_knee := SQUASH_KNEE_BEND * _squash
	var target_left_knee := (
		(KNEE_STANCE + knee_swing * maxf(0.0, -stride)) * walk_blend + squash_knee
	)
	var target_right_knee := (
		(KNEE_STANCE + knee_swing * maxf(0.0, stride)) * walk_blend + squash_knee
	)
	var elbow_rest := lerpf(ELBOW_REST, ELBOW_REST + RUN_ELBOW_BEND, run_blend)
	var target_left_elbow := -(elbow_rest + ELBOW_SWING * maxf(0.0, swing) * walk_blend)
	var target_right_elbow := -(elbow_rest + ELBOW_SWING * maxf(0.0, -swing) * walk_blend)
	var target_lean_x := RUN_LEAN * run_blend
	if not on_floor:
		# Mid-hop: legs split with knees tucked, arms flung out.
		target_left_leg_x = 0.45
		target_right_leg_x = -0.45
		target_left_knee = 0.9
		target_right_knee = 0.4
		target_left_arm_x = 0.0
		target_right_arm_x = 0.0
		target_left_arm_z = 0.7
		target_right_arm_z = -0.7
		target_left_elbow = -0.3
		target_right_elbow = -0.3
		target_lean_x = 0.0
	elif is_pushing_cart:
		target_left_arm_x = -0.75
		target_right_arm_x = -0.75
		target_left_arm_z = 0.06
		target_right_arm_z = -0.06
		target_left_elbow = -0.25
		target_right_elbow = -0.25
		target_lean_x = 0.08 * walk_blend
	var weight := 1.0 - exp(-POSE_SHARPNESS * delta)

	var target_blend := 1.0 if _phone_mode != PhoneMode.NONE else 0.0
	_phone_blend = move_toward(_phone_blend, target_blend, 4.0 * delta)
	if _phone:
		_phone.visible = _phone_blend > 0.0

	var target_phone_arm := Vector3.ZERO
	var target_phone_elbow := Vector3.ZERO
	var target_phone_head := Vector3.ZERO

	if _phone_mode == PhoneMode.TALKING:
		target_phone_arm = Vector3(deg_to_rad(-108.0), deg_to_rad(40.0), deg_to_rad(24.0))
		target_phone_elbow = Vector3(deg_to_rad(-112.0), deg_to_rad(-10.0), 0.0)
		target_phone_head = Vector3(deg_to_rad(4.0), deg_to_rad(-10.0), deg_to_rad(-8.0))
	elif _phone_mode == PhoneMode.RINGING:
		target_phone_arm = Vector3(deg_to_rad(-45.0), deg_to_rad(20.0), deg_to_rad(15.0))
		target_phone_elbow = Vector3(deg_to_rad(-85.0), 0.0, 0.0)
		target_phone_head = Vector3(deg_to_rad(10.0), deg_to_rad(-8.0), 0.0)

	var phone_trans_weight := 1.0 - exp(-12.0 * delta)
	_phone_arm_pose = _phone_arm_pose.lerp(target_phone_arm, phone_trans_weight)
	_phone_elbow_pose = _phone_elbow_pose.lerp(target_phone_elbow, phone_trans_weight)
	_phone_head_pose = _phone_head_pose.lerp(target_phone_head, phone_trans_weight)

	var final_right_arm_x := lerpf(target_right_arm_x, _phone_arm_pose.x, _phone_blend)
	var final_right_arm_y := lerpf(0.0, _phone_arm_pose.y, _phone_blend)
	var final_right_arm_z := lerpf(target_right_arm_z, _phone_arm_pose.z, _phone_blend)

	var final_right_elbow_x := lerpf(target_right_elbow, _phone_elbow_pose.x, _phone_blend)
	var final_right_elbow_y := lerpf(0.0, _phone_elbow_pose.y, _phone_blend)
	var final_right_elbow_z := lerpf(0.0, _phone_elbow_pose.z, _phone_blend)

	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, target_left_leg_x, weight)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, target_right_leg_x, weight)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, target_left_arm_x, weight)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, final_right_arm_x, weight)
	_right_arm.rotation.y = lerpf(_right_arm.rotation.y, final_right_arm_y, weight)
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, target_left_arm_z, weight)
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, final_right_arm_z, weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, target_left_knee, weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, target_right_knee, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, target_left_elbow, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, final_right_elbow_x, weight)
	_right_elbow.rotation.y = lerpf(_right_elbow.rotation.y, final_right_elbow_y, weight)
	_right_elbow.rotation.z = lerpf(_right_elbow.rotation.z, final_right_elbow_z, weight)
	_left_ankle.rotation.x = -ANKLE_LEVELING * (_left_leg.rotation.x + _left_knee.rotation.x)
	_right_ankle.rotation.x = -ANKLE_LEVELING * (_right_leg.rotation.x + _right_knee.rotation.x)

	# Body posture: forward lean when running, subtle sway when idle
	_visual.rotation.x = lerpf(_visual.rotation.x, target_lean_x, weight)
	var target_sway_z := sway * IDLE_SWAY_ANGLE * idle_blend
	_visual.rotation.z = lerpf(_visual.rotation.z, target_sway_z, weight)

	# Drop the visual by the shortening of the stance leg so the planted foot stays on the floor.
	var hip_y := LEG_LENGTH * cos(_visual.rotation.x)
	var reach_l := _leg_reach(
		_left_leg.rotation.x, _left_knee.rotation.x, _left_ankle.rotation.x, _visual.rotation.x
	)
	var reach_r := _leg_reach(
		_right_leg.rotation.x, _right_knee.rotation.x, _right_ankle.rotation.x, _visual.rotation.x
	)
	var stance_reach := maxf(reach_l, reach_r)
	var leg_bob := stance_reach - hip_y
	var total_bob := leg_bob if on_floor else 0.0

	# Head glance and breathing nod
	if _head:
		var look_cycle := fmod(_idle_time, 9.0)
		var head_yaw := 0.0
		if look_cycle > 2.5 and look_cycle < 4.5:
			var p := (look_cycle - 2.5) / 2.0
			head_yaw = sin(p * PI) * 0.35
		elif look_cycle > 6.0 and look_cycle < 8.0:
			var p := (look_cycle - 6.0) / 2.0
			head_yaw = -sin(p * PI) * 0.35
		head_yaw *= idle_blend

		var head_pitch := (breath * 0.02) * idle_blend
		var head_roll := head_yaw * 0.15

		var phone_nod := sin(_idle_time * IDLE_BREATH_RATE) * 0.02 * _phone_blend
		var final_head_x := lerpf(head_pitch, _phone_head_pose.x + phone_nod, _phone_blend)
		var final_head_y := lerpf(head_yaw, _phone_head_pose.y, _phone_blend)
		var final_head_z := lerpf(head_roll, _phone_head_pose.z, _phone_blend)

		_head.rotation.y = lerpf(_head.rotation.y, final_head_y, weight)
		_head.rotation.x = lerpf(_head.rotation.x, final_head_x, weight)
		_head.rotation.z = lerpf(_head.rotation.z, final_head_z, weight)

	# Breathing scale + landing squash
	_squash = move_toward(_squash, 0.0, 6.0 * delta)
	var breath_scale_y := 1.0 + IDLE_SCALE_BREATH * breath * idle_blend
	var breath_scale_xz := 1.0 - (IDLE_SCALE_BREATH * 0.5) * breath * idle_blend
	var sx := (1.0 + SQUASH_SCALE_XZ * _squash) * breath_scale_xz
	var sy := (1.0 - SQUASH_SCALE_Y * _squash) * breath_scale_y
	var sz := (1.0 + SQUASH_SCALE_XZ * _squash) * breath_scale_xz
	_visual.scale = Vector3(sx, sy, sz)
	_visual.position.y = total_bob * sy + _step_offset


static func _leg_reach(hip: float, knee: float, ankle: float, lean: float = 0.0) -> float:
	var thigh_angle := hip + lean
	var shin_angle := hip + knee + lean
	var shoe_angle := hip + knee + ankle + lean
	return (
		THIGH_LENGTH * cos(thigh_angle)
		+ SHIN_LENGTH * cos(shin_angle)
		+ SHOE_HEIGHT * cos(shoe_angle)
	)
