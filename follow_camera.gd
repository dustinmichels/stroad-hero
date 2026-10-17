extends Camera3D
## Tracks `target`; each WASD press steps the view 45 degrees around it.
## Death returns the camera to its starting view.

@export var target: CharacterBody3D
@export var smoothing := 5.0
@export var swing_smoothing := 8.0

const SWING_FINISH_ANGLE := deg_to_rad(1.0)
const YAW_STEP := PI / 4.0
var _horizontal_distance: float
var _default_yaw: float
var _camera_yaw: float
var _target_yaw: float
var _is_swinging := false


func _ready() -> void:
	var offset := global_position - target.global_position
	_horizontal_distance = Vector2(offset.x, offset.z).length()
	_default_yaw = atan2(-offset.x, -offset.z)
	_camera_yaw = _default_yaw
	_target_yaw = _default_yaw
	if target.has_signal("died"):
		target.died.connect(_on_target_died)


func _physics_process(delta: float) -> void:
	var step := (
		int(Input.is_action_just_pressed("camera_left"))
		+ int(Input.is_action_just_pressed("camera_forward"))
		- int(Input.is_action_just_pressed("camera_right"))
		- int(Input.is_action_just_pressed("camera_back"))
	)
	if step != 0:
		_target_yaw += step * YAW_STEP
		_is_swinging = true
	if _is_swinging:
		_camera_yaw = lerpf(_camera_yaw, _target_yaw, 1.0 - exp(-swing_smoothing * delta))
		if absf(_target_yaw - _camera_yaw) <= SWING_FINISH_ANGLE:
			_camera_yaw = _target_yaw
			_is_swinging = false

	var goal := (
		target.global_position
		+ Vector3(
			-sin(_camera_yaw) * _horizontal_distance, 0.0, -cos(_camera_yaw) * _horizontal_distance
		)
	)
	goal.y = global_position.y
	global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))

	var target_direction := target.global_position - global_position
	global_rotation.y = atan2(-target_direction.x, -target_direction.z)


func _on_target_died(_death_position: Vector3) -> void:
	_target_yaw = _camera_yaw + angle_difference(_camera_yaw, _default_yaw)
	_is_swinging = true
