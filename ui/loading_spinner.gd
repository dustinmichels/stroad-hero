class_name LoadingSpinner
extends Control

@export var spinner_color: Color = Color(0.95, 0.74, 0.14, 1.0)
@export var radius: float = 10.0
@export var thickness: float = 2.5
@export var speed: float = 6.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_angle += speed * delta
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, radius, _angle, _angle + PI * 1.35, 24, spinner_color, thickness, true)
