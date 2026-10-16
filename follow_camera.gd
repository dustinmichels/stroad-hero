extends Camera3D
## Follows `target` across the ground plane, keeping the framing it starts with.
## Height stays fixed so hops don't shake the view.

@export var target: Node3D
@export var smoothing := 5.0

var _offset: Vector3


func _ready() -> void:
	_offset = global_position - target.global_position


func _physics_process(delta: float) -> void:
	var goal := target.global_position + _offset
	goal.y = global_position.y
	global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))
