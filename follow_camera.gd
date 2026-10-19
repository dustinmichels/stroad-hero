class_name FollowCamera
extends Camera3D
## Tracks `target`; A/D steps yaw, W/S tilts up/down, and R resets behind Mats.
## Death returns the camera to its starting view.

@export var target: Mats
@export var smoothing := 5.0
@export var swing_smoothing := 8.0

const SWING_FINISH_ANGLE := deg_to_rad(1.0)
const YAW_STEP := PI / 4.0
const PITCH_STEP := deg_to_rad(10.0)
const MIN_PITCH := deg_to_rad(15.0)
const MAX_PITCH := deg_to_rad(80.0)

var _distance: float
var _default_yaw: float
var _default_pitch: float
var _camera_yaw: float
var _target_yaw: float
var _camera_pitch: float
var _target_pitch: float
var _pitch_framing_offset: float
var _is_swinging := false


func _ready() -> void:
	if not InputMap.has_action("camera_reset"):
		InputMap.add_action("camera_reset")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		InputMap.action_add_event("camera_reset", event)

	var offset := global_position - target.global_position
	_distance = offset.length()
	var horizontal_dist := Vector2(offset.x, offset.z).length()
	_default_yaw = atan2(-offset.x, -offset.z)
	var scene_pitch := atan2(offset.y, horizontal_dist)
	_pitch_framing_offset = rotation.x - (-scene_pitch)
	_default_pitch = clampf(scene_pitch - PITCH_STEP, MIN_PITCH, MAX_PITCH)
	snap_to_target()
	if target:
		target.died.connect(_on_target_died)
		target.respawned.connect(_on_target_respawned)


func _process(delta: float) -> void:
	var target_position := target.get_global_transform_interpolated().origin
	var is_target_dead: bool = target.is_dead if target != null else false
	if not is_target_dead:
		var camera_left_pressed := (
			Input.is_action_just_pressed("camera_left") and not _is_phone_call_showing()
		)
		var yaw_step := int(camera_left_pressed) - int(Input.is_action_just_pressed("camera_right"))
		var pitch_step := (
			int(Input.is_action_just_pressed("camera_forward"))
			- int(Input.is_action_just_pressed("camera_back"))
		)
		if yaw_step != 0:
			_target_yaw += yaw_step * YAW_STEP
			_is_swinging = true
		if pitch_step != 0:
			_target_pitch = clampf(_target_pitch + pitch_step * PITCH_STEP, MIN_PITCH, MAX_PITCH)
			_is_swinging = true
		if Input.is_action_just_pressed("camera_reset"):
			reset_view()
	if _is_swinging:
		var weight := 1.0 - exp(-swing_smoothing * delta)
		_camera_yaw = lerpf(_camera_yaw, _target_yaw, weight)
		_camera_pitch = lerpf(_camera_pitch, _target_pitch, weight)
		if (
			absf(_target_yaw - _camera_yaw) <= SWING_FINISH_ANGLE
			and absf(_target_pitch - _camera_pitch) <= SWING_FINISH_ANGLE
		):
			_camera_yaw = _target_yaw
			_camera_pitch = _target_pitch
			_is_swinging = false

	var cos_pitch := cos(_camera_pitch)
	var sin_pitch := sin(_camera_pitch)
	var goal := (
		target_position
		+ Vector3(
			-sin(_camera_yaw) * cos_pitch * _distance,
			sin_pitch * _distance,
			-cos(_camera_yaw) * cos_pitch * _distance
		)
	)
	global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))

	var target_direction := target_position - global_position
	var horizontal_distance := Vector2(target_direction.x, target_direction.z).length()
	global_rotation.y = atan2(-target_direction.x, -target_direction.z)
	global_rotation.x = atan2(target_direction.y, horizontal_distance) + _pitch_framing_offset


func reset_view() -> void:
	var visual := target.get_node_or_null("Visual") as Node3D
	var target_facing := visual.global_rotation.y if visual else _default_yaw
	_target_yaw = _camera_yaw + angle_difference(_camera_yaw, target_facing)
	_target_pitch = _default_pitch
	_is_swinging = true


func snap_to_target() -> void:
	_camera_yaw = _default_yaw
	_target_yaw = _default_yaw
	_camera_pitch = _default_pitch
	_target_pitch = _default_pitch
	_is_swinging = false
	var target_position := target.global_position
	var cos_pitch := cos(_camera_pitch)
	var sin_pitch := sin(_camera_pitch)
	global_position = (
		target_position
		+ Vector3(
			-sin(_camera_yaw) * cos_pitch * _distance,
			sin_pitch * _distance,
			-cos(_camera_yaw) * cos_pitch * _distance
		)
	)
	var target_direction := target_position - global_position
	var horizontal_distance := Vector2(target_direction.x, target_direction.z).length()
	global_rotation.y = atan2(-target_direction.x, -target_direction.z)
	global_rotation.x = atan2(target_direction.y, horizontal_distance) + _pitch_framing_offset


func _on_target_died(_death_position: Vector3) -> void:
	_is_swinging = false


func _on_target_respawned() -> void:
	snap_to_target()


func _is_phone_call_showing() -> bool:
	var tree := get_tree()
	if not tree:
		return false
	var mgr := tree.get_first_node_in_group("objective_manager")
	if mgr and mgr.has_method("is_call_showing"):
		return mgr.is_call_showing()
	return false
