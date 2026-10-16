extends CharacterBody3D
## Mats: arrow keys walk, Space does a small hop.
## Movement is in world axes because the camera only pitches (up = -Z).
## The model's front is local +Z, so the facing yaw is atan2(dir.x, dir.z).

signal died(death_position: Vector3)

@export var walk_speed := 4.0
@export var acceleration := 30.0
@export var deceleration := 40.0
@export var jump_height := 0.5
@export var gravity := 20.0
@export var turn_speed := 14.0
## Tallest ledge (curb) Mats walks onto without jumping.
@export var step_height := 0.3

## Leg-swing radians per meter walked.
const STRIDE_RATE := 2.6
const LEG_SWING := 0.6
const ARM_SWING := 0.5
const BOB_HEIGHT := 0.08
const POSE_SHARPNESS := 15.0
const STEP_SMOOTHING := 18.0

@onready var _visual: Node3D = $Visual
@onready var _left_leg: Node3D = $Visual/LeftLegPivot
@onready var _right_leg: Node3D = $Visual/RightLegPivot
@onready var _left_arm: Node3D = $Visual/LeftArmPivot
@onready var _right_arm: Node3D = $Visual/RightArmPivot

var _stride_phase := 0.0
var _squash := 0.0
## Vertical offset that eases the model over instant height changes (curbs).
var _step_offset := 0.0

var _spawn_transform: Transform3D
var _is_dead := false


func _ready() -> void:
	floor_snap_length = step_height + 0.05
	_spawn_transform = global_transform
	add_to_group("player")

func _physics_process(delta: float) -> void:
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
	if was_on_floor and is_on_floor():
		_step_offset += y_before - global_position.y
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - exp(-STEP_SMOOTHING * delta))

	if not was_on_floor and is_on_floor():
		_squash = 1.0

	if direction != Vector3.ZERO:
		var target_yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	_animate(delta)


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector3.ZERO
	died.emit(global_position)
	
	_visual.visible = false
	
	await get_tree().create_timer(0.45).timeout
	
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_stride_phase = 0.0
	_squash = 0.0
	_step_offset = 0.0
	_visual.rotation.y = PI
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


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var walk_blend := clampf(speed / walk_speed, 0.0, 1.0)
	_stride_phase = fmod(_stride_phase + speed * STRIDE_RATE * delta, TAU)
	var swing := sin(_stride_phase)

	var leg_x := swing * LEG_SWING * walk_blend
	var arm_x := -swing * ARM_SWING * walk_blend
	var arm_z := 0.0
	var bob := absf(swing) * BOB_HEIGHT * walk_blend
	if not is_on_floor():
		# Mid-hop: legs split, arms flung out.
		leg_x = 0.45
		arm_x = 0.0
		arm_z = 0.7
		bob = 0.0

	var weight := 1.0 - exp(-POSE_SHARPNESS * delta)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, leg_x, weight)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -leg_x, weight)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, arm_x, weight)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, -arm_x, weight)
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, arm_z, weight)
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, -arm_z, weight)

	_squash = move_toward(_squash, 0.0, 6.0 * delta)
	_visual.scale = Vector3(1.0 + 0.15 * _squash, 1.0 - 0.2 * _squash, 1.0 + 0.15 * _squash)
	_visual.position.y = bob + _step_offset
