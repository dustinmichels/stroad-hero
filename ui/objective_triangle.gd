class_name ObjectiveTriangle
extends Control

@export var color: Color = Color(0.2, 0.85, 0.35, 1.0)
@export var outline_color: Color = Color(0.05, 0.18, 0.08, 0.9)


func _draw() -> void:
	var s := size
	if s.x <= 0:
		s.x = 10.0
	if s.y <= 0:
		s.y = 14.0
	var tri_w := 7.0
	var tri_h := 9.0
	var offset_x := (s.x - tri_w) * 0.5
	var offset_y := (s.y - tri_h) * 0.5
	var pts := PackedVector2Array(
		[
			Vector2(offset_x, offset_y),
			Vector2(offset_x + tri_w, offset_y + tri_h * 0.5),
			Vector2(offset_x, offset_y + tri_h),
		]
	)
	draw_colored_polygon(pts, color)
	var outline_pts := PackedVector2Array([pts[0], pts[1], pts[2], pts[0]])
	draw_polyline(outline_pts, outline_color, 1.0, true)
