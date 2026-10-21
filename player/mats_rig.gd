class_name MatsRig
extends Node3D

enum Headwear { HAIR, HAT, BEANIE }
enum PhoneMode { NONE, RINGING, TALKING }

@export_enum("Hair", "Red ball cap", "Beanie") var headwear: int = Headwear.HAIR:
	set(value):
		headwear = clampi(value, Headwear.HAIR, Headwear.BEANIE)
		_update_headwear()
@export var jacket_color := Color(0.96, 0.48, 0.1, 1.0):
	set(value):
		if jacket_color == value and _jacket_material:
			return
		jacket_color = value
		_update_jacket_materials()
@export var backpack_color := Color(0.2, 0.55, 0.3, 1.0):
	set(value):
		if backpack_color == value and backpack and backpack.material_override:
			return
		backpack_color = value
		_update_backpack_material()
@export var shoe_color := Color(0.8, 0.14, 0.12, 1.0):
	set(value):
		if shoe_color == value and left_shoe_upper and left_shoe_upper.material_override:
			return
		shoe_color = value
		_update_shoe_material()
@export var auto_idle := false
@onready var left_leg: Node3D = $LeftLegPivot
@onready var right_leg: Node3D = $RightLegPivot
@onready var left_arm: Node3D = $LeftArmPivot
@onready var right_arm: Node3D = $RightArmPivot
@onready var left_knee: Node3D = $LeftLegPivot/Knee
@onready var right_knee: Node3D = $RightLegPivot/Knee
@onready var left_ankle: Node3D = $LeftLegPivot/Knee/Shoe
@onready var right_ankle: Node3D = $RightLegPivot/Knee/Shoe
@onready var left_elbow: Node3D = $LeftArmPivot/Elbow
@onready var right_elbow: Node3D = $RightArmPivot/Elbow
@onready var head: Node3D = $Head
@onready var face: MeshInstance3D = $Head/Face
@onready var hair: MeshInstance3D = $Head/Hair
@onready var hat: Node3D = $Head/Hat
@onready var cap: MeshInstance3D = $Head/Hat/Cap
@onready var beanie: MeshInstance3D = $Head/Hat/Beanie
@onready var backpack: MeshInstance3D = $Backpack
@onready var left_shoe_upper: MeshInstance3D = $LeftLegPivot/Knee/Shoe/Upper
@onready var right_shoe_upper: MeshInstance3D = $RightLegPivot/Knee/Shoe/Upper
@onready var torso: MeshInstance3D = $Torso
@onready var left_upper_arm: MeshInstance3D = $LeftArmPivot/UpperArm
@onready var right_upper_arm: MeshInstance3D = $RightArmPivot/UpperArm
@onready var left_forearm: MeshInstance3D = $LeftArmPivot/Elbow/Forearm
@onready var right_forearm: MeshInstance3D = $RightArmPivot/Elbow/Forearm

const THIGH_LENGTH := 0.28
const SHIN_LENGTH := 0.25
const SHOE_HEIGHT := 0.07
const LEG_LENGTH := THIGH_LENGTH + SHIN_LENGTH + SHOE_HEIGHT
const LEG_SWING := 0.6
const RUN_LEG_SWING := 0.66
const STRIDE_RATE_WALK := 3.2
const STRIDE_RATE_RUN := 2.7
const ARM_SWING := 0.5
const POSE_SHARPNESS := 32.0
const KNEE_SWING := 0.75
const KNEE_STANCE := 0.12
const ELBOW_REST := 0.25
const ELBOW_SWING := 0.5
const ANKLE_LEVELING := 0.7

const RUN_SPEED_THRESHOLD := 2.5
const RUN_KNEE_SWING := 1.0
const RUN_LEAN := 0.10
const RUN_ARM_SWING := 0.65
const RUN_ELBOW_BEND := 0.35
const RUN_ARM_OUTWARD_Z := 0.20
const RUN_ARM_FLAIL_Z := 0.10

const SQUASH_KNEE_BEND := 0.40
const SQUASH_HIP_BEND := 0.20
const SQUASH_SCALE_Y := 0.10
const SQUASH_SCALE_XZ := 0.08

const IDLE_BREATH_RATE := 2.4
const IDLE_SCALE_BREATH := 0.015
const IDLE_ARM_REST_Z := 0.06
const IDLE_ARM_BREATH_Z := 0.02
const IDLE_ARM_BREATH_X := 0.025
const IDLE_SWAY_RATE := 0.8
const IDLE_SWAY_ANGLE := 0.02
const KNEEL_HIP_HEIGHT := 0.3
const KNEEL_HIP_ROTATION := 0.0
const KNEEL_KNEE_ROTATION := PI / 2.0
const KNEEL_ANKLE_ROTATION := PI / 2.0
const KNEEL_SHOULDER_ROTATION := -0.60
const KNEEL_ELBOW_ROTATION := -0.20

const PHONE_BLEND_RATE := 4.0
const PHONE_TRANS_RATE := 12.0
const PHONE_TALKING_ARM := Vector3(deg_to_rad(-108.0), deg_to_rad(40.0), deg_to_rad(24.0))
const PHONE_TALKING_ELBOW := Vector3(deg_to_rad(-112.0), deg_to_rad(-10.0), 0.0)
const PHONE_TALKING_HEAD := Vector3(deg_to_rad(4.0), deg_to_rad(-10.0), deg_to_rad(-8.0))
const PHONE_RINGING_ARM := Vector3(deg_to_rad(-45.0), deg_to_rad(20.0), deg_to_rad(15.0))
const PHONE_RINGING_ELBOW := Vector3(deg_to_rad(-85.0), 0.0, 0.0)
const PHONE_RINGING_HEAD := Vector3(deg_to_rad(10.0), deg_to_rad(-8.0), 0.0)
var _stride_phase := 0.0
var _squash := 0.0
var _idle_time := 0.0
var _pose_tween: Tween = null
var _jacket_material: StandardMaterial3D = null
var _jacket_trim_material: StandardMaterial3D = null

var phone: Node3D:
	get:
		return _phone

var phone_mode: PhoneMode:
	get:
		return _phone_mode

var phone_blend: float:
	get:
		return _phone_blend

var _phone: Node3D = null
var _phone_mode: PhoneMode = PhoneMode.NONE
var _phone_blend := 0.0
var _phone_arm_pose := Vector3.ZERO
var _phone_elbow_pose := Vector3.ZERO
var _phone_head_pose := Vector3.ZERO


func _ready() -> void:
	_build_phone()
	setup_materials(backpack_color, shoe_color, jacket_color)
	set_headwear(headwear)


func _process(delta: float) -> void:
	if auto_idle:
		update_idle(delta)


## Updates idle posture, breathing, and subtle sway for standalone UI previews without physics inputs.
func update_idle(delta: float) -> void:
	update_locomotion(delta, Vector2.ZERO, 1.0, 1.0, true, false, 0.0)


var hip_y: float:
	get:
		return left_leg.position.y if left_leg else 0.6


func setup_materials(
	p_backpack_color: Color = backpack_color,
	p_shoe_color: Color = shoe_color,
	p_jacket_color: Color = jacket_color
) -> void:
	if not is_node_ready() or not backpack:
		return

	var bp_mat := StandardMaterial3D.new()
	bp_mat.albedo_color = p_backpack_color
	bp_mat.roughness = 0.8
	backpack.material_override = bp_mat

	var shoe_mat := StandardMaterial3D.new()
	shoe_mat.albedo_color = p_shoe_color
	shoe_mat.roughness = 0.75
	left_shoe_upper.material_override = shoe_mat
	right_shoe_upper.material_override = shoe_mat

	_jacket_material = StandardMaterial3D.new()
	_jacket_material.albedo_color = p_jacket_color
	_jacket_material.roughness = 0.7
	_jacket_trim_material = StandardMaterial3D.new()
	_jacket_trim_material.albedo_color = p_jacket_color.darkened(0.25)
	_jacket_trim_material.roughness = 0.75

	torso.set_surface_override_material(0, _jacket_material)
	torso.set_surface_override_material(1, _jacket_trim_material)
	left_upper_arm.set_surface_override_material(0, _jacket_material)
	right_upper_arm.set_surface_override_material(0, _jacket_material)
	left_forearm.set_surface_override_material(0, _jacket_material)
	left_forearm.set_surface_override_material(1, _jacket_trim_material)
	right_forearm.set_surface_override_material(0, _jacket_material)
	right_forearm.set_surface_override_material(1, _jacket_trim_material)


func set_headwear(value: int) -> void:
	headwear = value


func _update_headwear() -> void:
	if not is_node_ready():
		return
	if hat:
		hat.visible = headwear != Headwear.HAIR
	if cap:
		cap.visible = headwear == Headwear.HAT
	if beanie:
		beanie.visible = headwear == Headwear.BEANIE


func set_jacket_color(color: Color) -> void:
	jacket_color = color


func _update_jacket_materials() -> void:
	if not is_node_ready():
		return
	if _jacket_material:
		_jacket_material.albedo_color = jacket_color
	else:
		setup_materials(backpack_color, shoe_color, jacket_color)
	if _jacket_trim_material:
		_jacket_trim_material.albedo_color = jacket_color.darkened(0.25)


func set_backpack_color(color: Color) -> void:
	backpack_color = color


func _update_backpack_material() -> void:
	if not is_node_ready() or not backpack:
		return
	var material := backpack.material_override as StandardMaterial3D
	if material:
		material.albedo_color = backpack_color
	else:
		setup_materials(backpack_color, shoe_color, jacket_color)


func set_shoe_color(color: Color) -> void:
	shoe_color = color


func _update_shoe_material() -> void:
	if not is_node_ready() or not left_shoe_upper:
		return
	var material := left_shoe_upper.material_override as StandardMaterial3D
	if material:
		material.albedo_color = shoe_color
	else:
		setup_materials(backpack_color, shoe_color, jacket_color)


func set_shirt_color(color: Color) -> void:
	set_jacket_color(color)


func set_pants_color(_color: Color) -> void:
	# Provided for API parity; Mats models pants in mesh/texture
	pass


func attach_to_right_elbow(child: Node) -> void:
	if right_elbow:
		right_elbow.add_child(child)


func _build_phone() -> void:
	if _phone or not right_elbow:
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

	right_elbow.add_child(_phone)


func set_limb_pose(hip: float, knee: float, ankle: float, shoulder: float, elbow: float) -> void:
	for joint: Node3D in [left_leg, right_leg]:
		if joint:
			joint.rotation = Vector3(hip, 0.0, 0.0)
	for joint: Node3D in [left_knee, right_knee]:
		if joint:
			joint.rotation = Vector3(knee, 0.0, 0.0)
	for joint: Node3D in [left_ankle, right_ankle]:
		if joint:
			joint.rotation = Vector3(ankle, 0.0, 0.0)
	for joint: Node3D in [left_arm, right_arm]:
		if joint:
			joint.rotation = Vector3(shoulder, 0.0, 0.0)
	for joint: Node3D in [left_elbow, right_elbow]:
		if joint:
			joint.rotation = Vector3(elbow, 0.0, 0.0)


func stop_pose_animation() -> void:
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null


func get_cart_kneel_position() -> Vector3:
	var hip_offset := left_leg.position.y if left_leg else hip_y
	return Vector3(0.0, KNEEL_HIP_HEIGHT - hip_offset, 0.03)


func apply_cart_kneel_pose() -> void:
	stop_pose_animation()
	rotation = Vector3.ZERO
	position = get_cart_kneel_position()
	set_limb_pose(
		KNEEL_HIP_ROTATION,
		KNEEL_KNEE_ROTATION,
		KNEEL_ANKLE_ROTATION,
		KNEEL_SHOULDER_ROTATION,
		KNEEL_ELBOW_ROTATION
	)
	left_arm.rotation.y = 0.0
	left_arm.rotation.z = 0.0
	right_arm.rotation.y = 0.0
	right_arm.rotation.z = 0.0
	if head:
		head.rotation = Vector3.ZERO


func play_cart_mount_animation(duration: float = 0.32) -> Tween:
	stop_pose_animation()
	rotation.y = wrapf(rotation.y, -PI, PI)
	var target_pos := get_cart_kneel_position()
	var tween := create_tween().set_parallel(true)
	_pose_tween = tween
	(
		tween
		. tween_property(self, "rotation", Vector3.ZERO, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		tween
		. tween_property(self, "position", target_pos, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	for joint: Node3D in [left_leg, right_leg]:
		(
			tween
			. tween_property(joint, "rotation:x", KNEEL_HIP_ROTATION, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [left_knee, right_knee]:
		(
			tween
			. tween_property(joint, "rotation:x", KNEEL_KNEE_ROTATION, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [left_ankle, right_ankle]:
		(
			tween
			. tween_property(joint, "rotation:x", KNEEL_ANKLE_ROTATION, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [left_arm, right_arm]:
		(
			tween
			. tween_property(joint, "rotation:x", KNEEL_SHOULDER_ROTATION, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			tween
			. tween_property(joint, "rotation:y", 0.0, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			tween
			. tween_property(joint, "rotation:z", 0.0, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	for joint: Node3D in [left_elbow, right_elbow]:
		(
			tween
			. tween_property(joint, "rotation:x", KNEEL_ELBOW_ROTATION, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	if head:
		(
			tween
			. tween_property(head, "rotation", Vector3.ZERO, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	tween.chain().tween_callback(apply_cart_kneel_pose)
	return tween


func play_cart_dismount_animation(duration: float = 0.32) -> Tween:
	stop_pose_animation()
	var tween := create_tween().set_parallel(true)
	_pose_tween = tween
	(
		tween
		. tween_property(self, "position", Vector3.ZERO, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	for joint: Node3D in [
		left_leg,
		right_leg,
		left_knee,
		right_knee,
		left_ankle,
		right_ankle,
		left_arm,
		right_arm,
		left_elbow,
		right_elbow,
	]:
		(
			tween
			. tween_property(joint, "rotation:x", 0.0, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)
	tween.chain().tween_callback(
		func() -> void:
			_pose_tween = null
			position = Vector3.ZERO
			set_limb_pose(0.0, 0.0, 0.0, 0.0, 0.0)
	)
	return tween


func reset_pose() -> void:
	stop_pose_animation()
	position = Vector3.ZERO
	rotation = Vector3(0.0, PI, 0.0)
	scale = Vector3.ONE
	set_limb_pose(0.0, 0.0, 0.0, 0.0, 0.0)
	if left_arm:
		left_arm.rotation = Vector3.ZERO
	if right_arm:
		right_arm.rotation = Vector3.ZERO
	if left_elbow:
		left_elbow.rotation = Vector3.ZERO
	if right_elbow:
		right_elbow.rotation = Vector3.ZERO
	if head:
		head.rotation = Vector3.ZERO
	_stride_phase = 0.0
	_squash = 0.0
	_idle_time = 0.0
	hide_phone()


func set_rig_visible(value: bool) -> void:
	visible = value


func trigger_jump_squash() -> void:
	_squash = 1.0


func set_phone_mode(mode: PhoneMode) -> void:
	_phone_mode = mode
	if _phone:
		_phone.visible = (_phone_mode != PhoneMode.NONE) or (_phone_blend > 0.0)


func hide_phone() -> void:
	_phone_mode = PhoneMode.NONE
	_phone_blend = 0.0
	_phone_arm_pose = Vector3.ZERO
	_phone_elbow_pose = Vector3.ZERO
	_phone_head_pose = Vector3.ZERO
	if _phone:
		_phone.visible = false


func update_phone_pose(delta: float) -> void:
	var target_blend := 1.0 if _phone_mode != PhoneMode.NONE else 0.0
	_phone_blend = move_toward(_phone_blend, target_blend, PHONE_BLEND_RATE * delta)
	if _phone:
		_phone.visible = (_phone_mode != PhoneMode.NONE) or (_phone_blend > 0.0)

	var target_phone_arm := Vector3.ZERO
	var target_phone_elbow := Vector3.ZERO
	var target_phone_head := Vector3.ZERO

	if _phone_mode == PhoneMode.TALKING:
		target_phone_arm = PHONE_TALKING_ARM
		target_phone_elbow = PHONE_TALKING_ELBOW
		target_phone_head = PHONE_TALKING_HEAD
	elif _phone_mode == PhoneMode.RINGING:
		target_phone_arm = PHONE_RINGING_ARM
		target_phone_elbow = PHONE_RINGING_ELBOW
		target_phone_head = PHONE_RINGING_HEAD

	var phone_trans_weight := 1.0 - exp(-PHONE_TRANS_RATE * delta)
	_phone_arm_pose = _phone_arm_pose.lerp(target_phone_arm, phone_trans_weight)
	_phone_elbow_pose = _phone_elbow_pose.lerp(target_phone_elbow, phone_trans_weight)
	_phone_head_pose = _phone_head_pose.lerp(target_phone_head, phone_trans_weight)


func static_leg_reach(hip: float, knee: float, ankle: float, lean: float = 0.0) -> float:
	var thigh_angle := hip + lean
	var shin_angle := hip + knee + lean
	var shoe_angle := hip + knee + ankle + lean
	return (
		THIGH_LENGTH * cos(thigh_angle)
		+ SHIN_LENGTH * cos(shin_angle)
		+ SHOE_HEIGHT * cos(shoe_angle)
	)


func update_locomotion(
	delta: float,
	planar_velocity: Vector2,
	walk_speed: float,
	sprint_speed: float,
	on_floor: bool,
	is_pushing_cart: bool,
	step_offset: float,
	target_yaw: float = NAN,
	turn_speed: float = 0.0
) -> void:
	update_phone_pose(delta)
	var planar_speed := planar_velocity.length()
	if not is_nan(target_yaw) and turn_speed > 0.0:
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	var walk_blend := clampf(planar_speed / walk_speed, 0.0, 1.0) if walk_speed > 0.0 else 0.0
	var idle_blend := (1.0 - walk_blend) if on_floor else 0.0
	var run_blend := (
		clampf((planar_speed - RUN_SPEED_THRESHOLD) / (walk_speed - RUN_SPEED_THRESHOLD), 0.0, 1.0)
		if on_floor and walk_speed > RUN_SPEED_THRESHOLD
		else 0.0
	)
	var sprint_blend := (
		clampf((planar_speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0)
		if on_floor and sprint_speed > walk_speed
		else 0.0
	)

	_idle_time += delta
	var stride_rate := lerpf(STRIDE_RATE_WALK, STRIDE_RATE_RUN, run_blend)
	_stride_phase = fmod(_stride_phase + planar_speed * stride_rate * delta, TAU)
	var swing := sin(_stride_phase)
	var breath := sin(_idle_time * IDLE_BREATH_RATE)
	var sway := sin(_idle_time * IDLE_SWAY_RATE)

	# Leg targets
	var leg_swing := lerpf(LEG_SWING, RUN_LEG_SWING + 0.05 * sprint_blend, run_blend)
	var leg_x := swing * leg_swing * walk_blend
	var idle_leg_l := maxf(0.0, sway) * 0.04 * idle_blend
	var idle_leg_r := maxf(0.0, -sway) * 0.04 * idle_blend
	var squash_hip := -SQUASH_HIP_BEND * _squash
	var target_left_leg_x := leg_x + idle_leg_l + squash_hip
	var target_right_leg_x := -leg_x + idle_leg_r + squash_hip

	# Arm targets
	var arm_swing := lerpf(ARM_SWING, RUN_ARM_SWING + 0.08 * sprint_blend, run_blend)
	var walk_arm_x := -swing * arm_swing * walk_blend
	var idle_arm_x := (0.02 + cos(_idle_time * IDLE_BREATH_RATE) * IDLE_ARM_BREATH_X) * idle_blend
	var base_arm_z := IDLE_ARM_REST_Z + breath * IDLE_ARM_BREATH_Z * idle_blend
	# Multi-harmonic, asynchronous flail and subtle wobble for an organic, less rigid run
	var run_flail_l := (
		RUN_ARM_OUTWARD_Z
		+ (0.5 + 0.5 * sin(_stride_phase + 0.3)) * RUN_ARM_FLAIL_Z
		+ sin(_stride_phase * 1.37 + 1.2) * 0.04
		+ cos(_idle_time * 8.5) * 0.03
	)
	var run_flail_r := (
		RUN_ARM_OUTWARD_Z
		+ (0.5 + 0.5 * sin(_stride_phase + PI + 0.1)) * RUN_ARM_FLAIL_Z
		+ sin(_stride_phase * 1.29 + 2.7) * 0.04
		+ sin(_idle_time * 7.8) * 0.03
	)
	var run_wobble_x_l := sin(_stride_phase * 1.8 + 0.8) * 0.04 * run_blend
	var run_wobble_x_r := sin(_stride_phase * 1.7 + 2.4) * 0.04 * run_blend
	var target_left_arm_x := walk_arm_x + idle_arm_x + run_wobble_x_l
	var target_right_arm_x := -walk_arm_x + idle_arm_x + run_wobble_x_r
	var target_left_arm_y := sin(_stride_phase * 1.1 + 0.5) * 0.05 * run_blend
	var target_right_arm_y := -sin(_stride_phase * 0.9 + 2.1) * 0.05 * run_blend
	var target_left_arm_z := lerpf(base_arm_z, run_flail_l, run_blend)
	var target_right_arm_z := -lerpf(base_arm_z, run_flail_r, run_blend)

	# Joint targets: a knee flexes smoothly while its leg swings forward, and an
	# elbow bends further while its arm leads.
	var stride := cos(_stride_phase)
	var knee_swing := lerpf(KNEE_SWING, RUN_KNEE_SWING, run_blend)
	var squash_knee := SQUASH_KNEE_BEND * _squash
	var flex_l := pow(maxf(0.0, -stride), 1.25)
	var flex_r := pow(maxf(0.0, stride), 1.25)
	var target_left_knee := (KNEE_STANCE + knee_swing * flex_l) * walk_blend + squash_knee
	var target_right_knee := (KNEE_STANCE + knee_swing * flex_r) * walk_blend + squash_knee
	var elbow_rest := lerpf(ELBOW_REST, ELBOW_REST + RUN_ELBOW_BEND, run_blend)
	var elbow_wobble_l := sin(_stride_phase * 1.5 + 0.3) * 0.04 * run_blend
	var elbow_wobble_r := sin(_stride_phase * 1.4 + 2.8) * 0.04 * run_blend
	var target_left_elbow := -(
		elbow_rest + ELBOW_SWING * maxf(0.0, swing) * walk_blend + elbow_wobble_l
	)
	var target_right_elbow := -(
		elbow_rest + ELBOW_SWING * maxf(0.0, -swing) * walk_blend + elbow_wobble_r
	)
	var target_lean_x := (RUN_LEAN + 0.05 * sprint_blend) * run_blend
	if not on_floor:
		# Mid-hop: legs split with knees tucked, arms flung out.
		target_left_leg_x = 0.45
		target_right_leg_x = -0.45
		target_left_knee = 0.9
		target_right_knee = 0.4
		target_left_arm_x = 0.0
		target_right_arm_x = 0.0
		target_left_arm_y = 0.0
		target_right_arm_y = 0.0
		target_left_arm_z = 0.7
		target_right_arm_z = -0.7
		target_left_elbow = -0.3
		target_right_elbow = -0.3
		target_lean_x = 0.0
	elif is_pushing_cart:
		target_left_arm_x = -0.75
		target_right_arm_x = -0.75
		target_left_arm_y = 0.0
		target_right_arm_y = 0.0
		target_left_arm_z = 0.06
		target_right_arm_z = -0.06
		target_left_elbow = -0.25
		target_right_elbow = -0.25
		target_lean_x = 0.08 * walk_blend
	var weight := 1.0 - exp(-POSE_SHARPNESS * delta)

	var final_right_arm_x := lerpf(target_right_arm_x, _phone_arm_pose.x, _phone_blend)
	var final_right_arm_y := lerpf(target_right_arm_y, _phone_arm_pose.y, _phone_blend)
	var final_right_arm_z := lerpf(target_right_arm_z, _phone_arm_pose.z, _phone_blend)

	var final_right_elbow_x := lerpf(target_right_elbow, _phone_elbow_pose.x, _phone_blend)
	var final_right_elbow_y := lerpf(0.0, _phone_elbow_pose.y, _phone_blend)
	var final_right_elbow_z := lerpf(0.0, _phone_elbow_pose.z, _phone_blend)

	left_leg.rotation.x = lerpf(left_leg.rotation.x, target_left_leg_x, weight)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, target_right_leg_x, weight)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, target_left_arm_x, weight)
	left_arm.rotation.y = lerpf(left_arm.rotation.y, target_left_arm_y, weight)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, final_right_arm_x, weight)
	right_arm.rotation.y = lerpf(right_arm.rotation.y, final_right_arm_y, weight)
	left_arm.rotation.z = lerpf(left_arm.rotation.z, target_left_arm_z, weight)
	right_arm.rotation.z = lerpf(right_arm.rotation.z, final_right_arm_z, weight)
	left_knee.rotation.x = lerpf(left_knee.rotation.x, target_left_knee, weight)
	right_knee.rotation.x = lerpf(right_knee.rotation.x, target_right_knee, weight)
	left_elbow.rotation.x = lerpf(left_elbow.rotation.x, target_left_elbow, weight)
	right_elbow.rotation.x = lerpf(right_elbow.rotation.x, final_right_elbow_x, weight)
	right_elbow.rotation.y = lerpf(right_elbow.rotation.y, final_right_elbow_y, weight)
	right_elbow.rotation.z = lerpf(right_elbow.rotation.z, final_right_elbow_z, weight)
	left_ankle.rotation.x = -ANKLE_LEVELING * (left_leg.rotation.x + left_knee.rotation.x)
	right_ankle.rotation.x = -ANKLE_LEVELING * (right_leg.rotation.x + right_knee.rotation.x)

	# Body posture: forward lean when running, subtle sway when idle
	rotation.x = lerpf(rotation.x, target_lean_x, weight)
	var target_sway_z := sway * IDLE_SWAY_ANGLE * idle_blend
	rotation.z = lerpf(rotation.z, target_sway_z, weight)

	# Drop the visual by the shortening of the stance leg so the planted foot stays on the floor.
	var current_hip_y := LEG_LENGTH * cos(rotation.x)
	var reach_l := static_leg_reach(
		left_leg.rotation.x, left_knee.rotation.x, left_ankle.rotation.x, rotation.x
	)
	var reach_r := static_leg_reach(
		right_leg.rotation.x, right_knee.rotation.x, right_ankle.rotation.x, rotation.x
	)
	var stance_reach := maxf(reach_l, reach_r)
	var leg_bob := stance_reach - current_hip_y
	var total_bob := leg_bob if on_floor else 0.0

	# Head glance and breathing nod
	if head:
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

		head.rotation.y = lerpf(head.rotation.y, final_head_y, weight)
		head.rotation.x = lerpf(head.rotation.x, final_head_x, weight)
		head.rotation.z = lerpf(head.rotation.z, final_head_z, weight)

	# Breathing scale + landing squash
	_squash = move_toward(_squash, 0.0, 6.0 * delta)
	var breath_scale_y := 1.0 + IDLE_SCALE_BREATH * breath * idle_blend
	var breath_scale_xz := 1.0 - (IDLE_SCALE_BREATH * 0.5) * breath * idle_blend
	var sx := (1.0 + SQUASH_SCALE_XZ * _squash) * breath_scale_xz
	var sy := (1.0 - SQUASH_SCALE_Y * _squash) * breath_scale_y
	var sz := (1.0 + SQUASH_SCALE_XZ * _squash) * breath_scale_xz
	scale = Vector3(sx, sy, sz)
	position.y = total_bob * sy + step_offset
