extends CharacterBody3D
## Mats: arrow keys walk, Space does a small hop.
## Movement is in world axes because the camera only pitches (up = -Z).
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

var _stride_phase := 0.0
var _squash := 0.0
## Vertical offset that eases the model over instant height changes (curbs).
var _step_offset := 0.0
var _idle_time := 0.0

var _spawn_transform: Transform3D
var _is_dead := false


func _ready() -> void:
	set_collision_mask_value(3, true)
	floor_snap_length = step_height + 0.05
	_spawn_transform = global_transform
	if not preview_mode:
		add_to_group("player")
	var material := StandardMaterial3D.new()
	material.roughness = 0.8
	_backpack.material_override = material
	set_headwear(headwear)
	set_backpack_color(backpack_color)


func _physics_process(delta: float) -> void:
	if preview_mode:
		velocity = Vector3.ZERO
		_animate(delta, true)
		return
	if _is_dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0.0, input.y)
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
	_rustle_collided_trees(horizontal)
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


func _rustle_collided_trees(impact_direction: Vector3) -> void:
	if impact_direction.is_zero_approx():
		return
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider()
		if collider is StreetTree:
			collider.rustle(impact_direction)


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


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
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
