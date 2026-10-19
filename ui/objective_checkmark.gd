class_name ObjectiveCheckmark
extends Control

@export var color: Color = Color(0.2, 0.95, 0.4, 1.0)
@export var outline_color: Color = Color(0.05, 0.18, 0.08, 0.9)
@export var line_width: float = 4.0
@export var antialiased: bool = true


func _draw() -> void:
	var s := size
	if s.x <= 0.0:
		s.x = 32.0
	if s.y <= 0.0:
		s.y = 32.0

	var p1 := Vector2(s.x * 0.16, s.y * 0.52)
	var p2 := Vector2(s.x * 0.40, s.y * 0.78)
	var p3 := Vector2(s.x * 0.86, s.y * 0.22)
	var pts := PackedVector2Array([p1, p2, p3])

	draw_polyline(pts, outline_color, line_width + 2.5, antialiased)
	draw_polyline(pts, color, line_width, antialiased)
