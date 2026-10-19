class_name PhoneIcon
extends Control

@export var icon_color: Color = Color(0.3, 0.9, 0.45, 1.0)

var _handle_style: StyleBoxFlat


func _ready() -> void:
	_init_style()


func _init_style() -> void:
	if _handle_style == null:
		_handle_style = StyleBoxFlat.new()
		_handle_style.bg_color = icon_color
		_handle_style.corner_radius_top_left = 3
		_handle_style.corner_radius_top_right = 3
		_handle_style.corner_radius_bottom_left = 3
		_handle_style.corner_radius_bottom_right = 3


func _draw() -> void:
	var s := size
	if s.x <= 0 or s.y <= 0:
		s = Vector2(28, 28)
	var center := s * 0.5

	_init_style()

	# Draw handset angled at -25 degrees
	draw_set_transform(center, deg_to_rad(-25.0), Vector2.ONE)

	# Central handle (rounded rect)
	var handle_w := 6.0
	var handle_h := 16.0
	var handle_rect := Rect2(-handle_w * 0.5, -handle_h * 0.5, handle_w, handle_h)
	draw_style_box(_handle_style, handle_rect)

	# Earpiece at top (small rect)
	var ear_w := 10.0
	var ear_h := 4.0
	var ear_rect := Rect2(-ear_w * 0.5, -handle_h * 0.5 - 2.0, ear_w, ear_h)
	draw_rect(ear_rect, icon_color, true)

	# Mouthpiece at bottom (small rect)
	var mouth_w := 10.0
	var mouth_h := 4.0
	var mouth_rect := Rect2(-mouth_w * 0.5, handle_h * 0.5 - 2.0, mouth_w, mouth_h)
	draw_rect(mouth_rect, icon_color, true)
