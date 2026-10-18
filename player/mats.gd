extends CharacterBody3D
## Mats: arrow keys walk relative to the current camera; Space hops.
## The model's front is local +Z, so the facing yaw is atan2(dir.x, dir.z).

signal died(death_position: Vector3)

@export var walk_speed := 5.5
@export var acceleration := 30.0
@export var deceleration := 40.0
@export var jump_height := 0.5
@export var gravity := 20.0
@export var turn_speed := 14.0
## Tallest ledge (curb) Mats walks onto without jumping.
@export var step_height := 0.3
## Seconds to pause at death position before respawning and flying camera back.
@export var respawn_delay := 1.25

enum Headwear { HAIR, HAT }

@export_enum("Hair", "Red ball cap") var headwear: int = Headwear.HAIR
@export var backpack_color := Color(0.2, 0.55, 0.3, 1.0)
@export var shoe_color := Color(0.8, 0.14, 0.12, 1.0)
@export var preview_mode := false

## Leg-swing radians per meter walked.
const STRIDE_RATE := 2.6
const LEG_SWING := 0.6
const ARM_SWING := 0.5
const BOB_HEIGHT := 0.08
const POSE_SHARPNESS := 15.0
const STEP_SMOOTHING := 18.0

## Idle animation tuning.
const IDLE_BREATH_RATE := 2.4
const IDLE_BOB_HEIGHT := 0.018
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
@onready var _head: Node3D = $Visual/Head
@onready var _hat: Node3D = $Visual/Head/Hat
@onready var _backpack: MeshInstance3D = $Visual/Backpack
@onready var _left_shoe_upper: MeshInstance3D = $Visual/LeftLegPivot/Shoe/Upper
@onready var _right_shoe_upper: MeshInstance3D = $Visual/RightLegPivot/Shoe/Upper
@onready var _camera := get_viewport().get_camera_3d()
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _stride_phase := 0.0
var _squash := 0.0
## Vertical offset that eases the model over instant height changes (curbs).
var _step_offset := 0.0
var _idle_time := 0.0

var _spawn_transform: Transform3D
var _is_dead := false
var _control_forward := Vector3.FORWARD
var _control_right := Vector3.RIGHT
var _has_control_basis := false
var _mounted_cart: Node3D = null
var _world_parent: Node = null
var _mount_tween: Tween = null


func _ready() -> void:
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
	set_headwear(headwear)
	set_backpack_color(backpack_color)
	set_shoe_color(shoe_color)


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
		if Input.is_action_just_pressed("jump"):
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
			collider.roll_from(impact_direction)


## Hair always shows; the cap sits over it with a tuft peeking out below.
func set_headwear(value: int) -> void:
	headwear = clampi(value, Headwear.HAIR, Headwear.HAT)
	if is_node_ready():
		_hat.visible = headwear == Headwear.HAT


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


func enter_cart(cart: Node3D, seat: Marker3D) -> void:
	if _mounted_cart:
		return
	_mounted_cart = cart
	_world_parent = get_parent()
	velocity = Vector3.ZERO
	set_physics_process(false)
	_collision_shape.disabled = true
	reparent(seat, true)

	var starting_position := position
	var jump_peak := starting_position * 0.5 + Vector3.UP * 0.85
	_mount_tween = create_tween()
	(
		_mount_tween
		. tween_property(self, "position", jump_peak, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_mount_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.32)
	(
		_mount_tween
		. tween_property(self, "position", Vector3.ZERO, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_mount_tween.tween_callback(_sit_in_cart)


func exit_cart(exit_position: Marker3D) -> void:
	if not _mounted_cart:
		return
	if _mount_tween and _mount_tween.is_valid():
		_mount_tween.kill()
	var facing_yaw := _visual.global_rotation.y
	_mounted_cart = null
	reparent(_world_parent, true)
	global_basis = Basis()
	_visual.global_rotation = Vector3(0.0, facing_yaw, 0.0)
	var destination := exit_position.global_position
	var jump_peak := (global_position + destination) * 0.5 + Vector3.UP * 0.85
	_mount_tween = create_tween()
	(
		_mount_tween
		. tween_property(self, "global_position", jump_peak, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_mount_tween
		. tween_property(self, "global_position", destination, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_mount_tween.tween_callback(_finish_exiting_cart)


func _sit_in_cart() -> void:
	_mount_tween = null
	_left_leg.rotation.x = -1.35
	_right_leg.rotation.x = -1.35
	_left_arm.rotation.x = -0.45
	_right_arm.rotation.x = -0.45


func _finish_exiting_cart() -> void:
	_mount_tween = null
	_left_leg.rotation.x = 0.0
	_right_leg.rotation.x = 0.0
	_left_arm.rotation.x = 0.0
	_right_arm.rotation.x = 0.0
	_collision_shape.disabled = false
	set_physics_process(true)


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_has_control_basis = false
	velocity = Vector3.ZERO
	died.emit(global_position)

	_visual.visible = false

	await get_tree().create_timer(respawn_delay).timeout

	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_stride_phase = 0.0
	_squash = 0.0
	_step_offset = 0.0
	_idle_time = 0.0
	_visual.rotation.y = PI
	_visual.rotation.z = 0.0
	_head.rotation = Vector3.ZERO
	_visual.visible = true
	_is_dead = false


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

	_idle_time += delta
	_stride_phase = fmod(_stride_phase + speed * STRIDE_RATE * delta, TAU)
	var swing := sin(_stride_phase)
	var breath := sin(_idle_time * IDLE_BREATH_RATE)
	var sway := sin(_idle_time * IDLE_SWAY_RATE)

	# Leg targets
	var leg_x := swing * LEG_SWING * walk_blend
	var idle_leg_l := maxf(0.0, sway) * 0.04 * idle_blend
	var idle_leg_r := maxf(0.0, -sway) * 0.04 * idle_blend
	var target_left_leg_x := leg_x + idle_leg_l
	var target_right_leg_x := -leg_x + idle_leg_r

	# Arm targets
	var walk_arm_x := -swing * ARM_SWING * walk_blend
	var idle_arm_x := (0.02 + cos(_idle_time * IDLE_BREATH_RATE) * IDLE_ARM_BREATH_X) * idle_blend
	var idle_arm_z := (IDLE_ARM_REST_Z + breath * IDLE_ARM_BREATH_Z) * idle_blend
	var target_left_arm_x := walk_arm_x + idle_arm_x
	var target_right_arm_x := -walk_arm_x + idle_arm_x
	var target_left_arm_z := idle_arm_z
	var target_right_arm_z := -idle_arm_z

	# Vertical bob
	var walk_bob := absf(swing) * BOB_HEIGHT * walk_blend
	var idle_bob := breath * IDLE_BOB_HEIGHT * idle_blend
	var total_bob := walk_bob + idle_bob

	if not on_floor:
		# Mid-hop: legs split, arms flung out.
		target_left_leg_x = 0.45
		target_right_leg_x = -0.45
		target_left_arm_x = 0.0
		target_right_arm_x = 0.0
		target_left_arm_z = 0.7
		target_right_arm_z = -0.7
		total_bob = 0.0

	var weight := 1.0 - exp(-POSE_SHARPNESS * delta)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, target_left_leg_x, weight)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, target_right_leg_x, weight)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, target_left_arm_x, weight)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, target_right_arm_x, weight)
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, target_left_arm_z, weight)
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, target_right_arm_z, weight)

	# Body lateral sway (subtle weight shift)
	var target_sway_z := sway * IDLE_SWAY_ANGLE * idle_blend
	_visual.rotation.z = lerpf(_visual.rotation.z, target_sway_z, weight)

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

		_head.rotation.y = lerpf(_head.rotation.y, head_yaw, weight)
		_head.rotation.x = lerpf(_head.rotation.x, head_pitch, weight)
		_head.rotation.z = lerpf(_head.rotation.z, head_roll, weight)

	# Breathing scale + landing squash
	_squash = move_toward(_squash, 0.0, 6.0 * delta)
	var breath_scale_y := 1.0 + IDLE_SCALE_BREATH * breath * idle_blend
	var breath_scale_xz := 1.0 - (IDLE_SCALE_BREATH * 0.5) * breath * idle_blend
	var sx := (1.0 + 0.15 * _squash) * breath_scale_xz
	var sy := (1.0 - 0.2 * _squash) * breath_scale_y
	var sz := (1.0 + 0.15 * _squash) * breath_scale_xz
	_visual.scale = Vector3(sx, sy, sz)
	_visual.position.y = total_bob + _step_offset
