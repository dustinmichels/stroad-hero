class_name FollowCamera
extends Camera3D
## Tracks `target`; A/D steps yaw, W/S tilts up/down, and R resets behind Mats.
## Death returns the camera to its starting view. A view override (set_view_override) locks yaw,
## pitch, and distance and ignores manual input until cleared.

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
## Current orbit distance; eases toward the override or default distance.
var _view_distance: float
var _has_view_override := false
var _override_yaw := 0.0
var _override_pitch := 0.0
var _override_distance := 0.0


func _ready() -> void:
	add_to_group("camera")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not InputMap.has_action("camera_reset"):
		InputMap.add_action("camera_reset")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		InputMap.action_add_event("camera_reset", event)

	if not target and is_inside_tree():
		target = get_tree().get_first_node_in_group("player") as Mats
	if target:
		set_target(target)


func set_target(new_target: Mats) -> void:
	if target and is_instance_valid(target) and target != new_target:
		if target.died.is_connected(_on_target_died):
			target.died.disconnect(_on_target_died)
		if target.respawned.is_connected(_on_target_respawned):
			target.respawned.disconnect(_on_target_respawned)
	target = new_target
	if not target:
		return
	var offset := global_position - target.global_position
	_distance = offset.length()
	var horizontal_dist := Vector2(offset.x, offset.z).length()
	_default_yaw = atan2(-offset.x, -offset.z)
	var scene_pitch := atan2(offset.y, horizontal_dist)
	_pitch_framing_offset = rotation.x - (-scene_pitch)
	_default_pitch = clampf(scene_pitch - PITCH_STEP, MIN_PITCH, MAX_PITCH)
	snap_to_target()
	if not target.died.is_connected(_on_target_died):
		target.died.connect(_on_target_died)
	if not target.respawned.is_connected(_on_target_respawned):
		target.respawned.connect(_on_target_respawned)


func _exit_tree() -> void:
	if target and is_instance_valid(target):
		if target.died.is_connected(_on_target_died):
			target.died.disconnect(_on_target_died)
		if target.respawned.is_connected(_on_target_respawned):
			target.respawned.disconnect(_on_target_respawned)


func _process(delta: float) -> void:
	if not target:
		return
	var target_position := target.get_global_transform_interpolated().origin
	var is_target_dead: bool = target.is_dead
	if not is_target_dead and not _has_view_override:
		var yaw_step := (
			int(Input.is_action_just_pressed("camera_left"))
			- int(Input.is_action_just_pressed("camera_right"))
		)
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
	var goal_distance := _override_distance if _has_view_override else _distance
	_view_distance = lerpf(_view_distance, goal_distance, 1.0 - exp(-swing_smoothing * delta))

	var cos_pitch := cos(_camera_pitch)
	var sin_pitch := sin(_camera_pitch)
	var goal := (
		target_position
		+ Vector3(
			-sin(_camera_yaw) * cos_pitch * _view_distance,
			sin_pitch * _view_distance,
			-cos(_camera_yaw) * cos_pitch * _view_distance
		)
	)
	global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))

	var target_direction := target_position - global_position
	var horizontal_distance := Vector2(target_direction.x, target_direction.z).length()
	global_rotation.y = atan2(-target_direction.x, -target_direction.z)
	global_rotation.x = atan2(target_direction.y, horizontal_distance) + _pitch_framing_offset


func reset_view() -> void:
	if not target:
		return
	var visual := target.get_node_or_null("Visual") as Node3D
	var target_facing := visual.global_rotation.y if visual else _default_yaw
	_target_yaw = _camera_yaw + angle_difference(_camera_yaw, target_facing)
	_target_pitch = _default_pitch
	_is_swinging = true


## Swings to `yaw`/`pitch` (radians, same convention as the default view) at `distance` meters and
## holds there, ignoring manual camera input, until clear_view_override().
func set_view_override(yaw: float, pitch: float, distance: float) -> void:
	_has_view_override = true
	_override_yaw = yaw
	_override_pitch = pitch
	_override_distance = distance
	_target_yaw = _camera_yaw + angle_difference(_camera_yaw, yaw)
	_target_pitch = pitch
	_is_swinging = true


## Releases a view override; keeps the current yaw and swings back to the default pitch/distance.
func clear_view_override() -> void:
	if not _has_view_override:
		return
	_has_view_override = false
	_target_pitch = _default_pitch
	_is_swinging = true


func snap_to_target() -> void:
	if not target:
		return
	_camera_yaw = _override_yaw if _has_view_override else _default_yaw
	_target_yaw = _camera_yaw
	_camera_pitch = _override_pitch if _has_view_override else _default_pitch
	_target_pitch = _camera_pitch
	_view_distance = _override_distance if _has_view_override else _distance
	_is_swinging = false
	var target_position := (
		target.get_global_transform_interpolated().origin
		if target.is_inside_tree()
		else target.global_position
	)
	var cos_pitch := cos(_camera_pitch)
	var sin_pitch := sin(_camera_pitch)
	global_position = (
		target_position
		+ Vector3(
			-sin(_camera_yaw) * cos_pitch * _view_distance,
			sin_pitch * _view_distance,
			-cos(_camera_yaw) * cos_pitch * _view_distance
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
