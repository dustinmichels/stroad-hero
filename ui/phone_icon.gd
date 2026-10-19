class_name PhoneIcon
extends Control

@export var icon_color: Color = Color(0.3, 0.9, 0.45, 1.0)
@export var screen_color: Color = Color(0.08, 0.1, 0.13, 1.0)

var _body_style: StyleBoxFlat
var _screen_style: StyleBoxFlat


func _ready() -> void:
	_init_styles()


func _init_styles() -> void:
	if _body_style == null:
		_body_style = StyleBoxFlat.new()
		_body_style.bg_color = icon_color
		_body_style.corner_radius_top_left = 3
		_body_style.corner_radius_top_right = 3
		_body_style.corner_radius_bottom_left = 3
		_body_style.corner_radius_bottom_right = 3
	else:
		_body_style.bg_color = icon_color

	if _screen_style == null:
		_screen_style = StyleBoxFlat.new()
		_screen_style.bg_color = screen_color
		_screen_style.corner_radius_top_left = 1
		_screen_style.corner_radius_top_right = 1
		_screen_style.corner_radius_bottom_left = 1
		_screen_style.corner_radius_bottom_right = 1
	else:
		_screen_style.bg_color = screen_color


func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(28.0, 28.0)
	var cx := s.x * 0.5
	var cy := s.y * 0.5

	_init_styles()

	# Upright smartphone body
	var pw := 14.0
	var ph := 24.0
	var px := cx - pw * 0.5
	var py := cy - ph * 0.5
	draw_style_box(_body_style, Rect2(px, py, pw, ph))

	# Screen cutout
	var sw := 10.0
	var sh := 15.0
	var sx := cx - sw * 0.5
	var sy := py + 3.8
	draw_style_box(_screen_style, Rect2(sx, sy, sw, sh))

	# Speaker slot at top
	draw_line(Vector2(cx - 2.5, py + 2.0), Vector2(cx + 2.5, py + 2.0), screen_color, 1.2)

	# Home bar at bottom
	draw_line(Vector2(cx - 3.0, py + ph - 2.4), Vector2(cx + 3.0, py + ph - 2.4), screen_color, 1.2)

	# Ringing vibration arcs on sides
	draw_arc(
		Vector2(px - 1.5, cy), 4.5, deg_to_rad(125.0), deg_to_rad(235.0), 8, icon_color, 1.4, true
	)
	draw_arc(
		Vector2(px + pw + 1.5, cy),
		4.5,
		deg_to_rad(-55.0),
		deg_to_rad(55.0),
		8,
		icon_color,
		1.4,
		true
	)
