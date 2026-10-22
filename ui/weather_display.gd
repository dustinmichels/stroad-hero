class_name WeatherDisplay
extends PanelContainer

## Top-right HUD component displaying current time of day, period, wind speed/direction,
## and an interactive compass rose with N, E, S, W orientation aligned with the world and camera.

const FONT_BOLD_PATH := "res://fonts/Overpass-Bold.ttf"
const FONT_SEMIBOLD_PATH := "res://fonts/Overpass-SemiBold.ttf"


class CompassDial:
	extends Control
	var font: Font = null
	var is_hovered: bool = false
	var _smoothed_wind_dir := Vector2(1.0, 0.0)

	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)
		size = Vector2(54, 54)
		mouse_filter = MOUSE_FILTER_PASS

	func _process(delta: float) -> void:
		# Smoothly track wind direction for visual fluidness
		var target_wind := _get_screen_direction(GameState.wind_direction)
		_smoothed_wind_dir = _smoothed_wind_dir.slerp(target_wind, clampf(delta * 8.0, 0.0, 1.0))
		queue_redraw()

	func _get_screen_direction(world_dir: Vector3) -> Vector2:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cam_forward := Vector2(-cam.global_basis.z.x, -cam.global_basis.z.z).normalized()
			var cam_right := Vector2(cam.global_basis.x.x, cam.global_basis.x.z).normalized()
			var w := Vector2(world_dir.x, world_dir.z)
			if not w.is_zero_approx():
				w = w.normalized()
			return Vector2(w.dot(cam_right), -w.dot(cam_forward)).normalized()
		else:
			var w := Vector2(world_dir.x, world_dir.z)
			return Vector2(w.x, w.y).normalized() if not w.is_zero_approx() else Vector2(0, -1)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0

		# 1. Dark circular dial disc
		var disc_color := Color(0.06, 0.08, 0.11, 0.92)
		draw_circle(center, radius, disc_color)

		# 2. Outer rim border
		var rim_color := (
			Color(0.45, 0.65, 0.85, 0.95) if is_hovered else Color(0.24, 0.32, 0.42, 0.8)
		)
		draw_arc(center, radius, 0.0, TAU, 36, rim_color, 1.5, true)

		# 3. Inner decorative ring & cross ticks
		var inner_rad := radius * 0.68
		draw_arc(center, inner_rad, 0.0, TAU, 28, Color(0.18, 0.24, 0.32, 0.5), 1.0, true)

		# 4. Cardinal directions (N, E, S, W)
		var directions: Array[Dictionary] = [
			{
				"label": "N",
				"world": Vector3(0, 0, -1),
				"color": Color(1.0, 0.38, 0.32, 1.0),
				"bold": true
			},
			{
				"label": "E",
				"world": Vector3(1, 0, 0),
				"color": Color(0.85, 0.90, 0.96, 0.95),
				"bold": false
			},
			{
				"label": "S",
				"world": Vector3(0, 0, 1),
				"color": Color(0.85, 0.90, 0.96, 0.95),
				"bold": false
			},
			{
				"label": "W",
				"world": Vector3(-1, 0, 0),
				"color": Color(0.85, 0.90, 0.96, 0.95),
				"bold": false
			},
		]

		var font_size := 11
		for d: Dictionary in directions:
			var s_dir := _get_screen_direction(d["world"])
			var label_pos := center + s_dir * (radius - 8.0)
			if font:
				var str_w := (
					font.get_string_size(d["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				)
				draw_string(
					font,
					label_pos + Vector2(-str_w * 0.5, 4.0),
					d["label"],
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					d["color"]
				)
			# Small tick mark
			var tick_start := center + s_dir * (radius - 2.5)
			var tick_end := center + s_dir * radius
			draw_line(tick_start, tick_end, rim_color, 1.0, true)

		# Subtle diagonal ticks (NE, SE, SW, NW)
		var diagonals: Array[Vector3] = [
			Vector3(1, 0, -1).normalized(),
			Vector3(1, 0, 1).normalized(),
			Vector3(-1, 0, 1).normalized(),
			Vector3(-1, 0, -1).normalized(),
		]
		for diag: Vector3 in diagonals:
			var s_dir := _get_screen_direction(diag)
			var tick_start := center + s_dir * (radius - 3.5)
			var tick_end := center + s_dir * (radius - 1.0)
			draw_line(tick_start, tick_end, Color(0.35, 0.45, 0.55, 0.5), 1.0, true)

		# 5. Dynamic Wind Direction Arrow
		var wind_dir := _smoothed_wind_dir
		if not wind_dir.is_zero_approx():
			var arrow_len := radius * 0.72
			var tip := center + wind_dir * arrow_len
			var base := center - wind_dir * 5.0
			var wind_color := Color(0.25, 0.92, 1.0, 0.95)

			# Arrow shaft
			draw_line(base, tip, wind_color, 2.0, true)

			# Arrow head
			var perp := Vector2(-wind_dir.y, wind_dir.x)
			var head_len := 7.0
			var head_width := 4.5
			var head_left := tip - wind_dir * head_len + perp * head_width
			var head_right := tip - wind_dir * head_len - perp * head_width
			var poly: PackedVector2Array = [
				tip, head_left, tip - wind_dir * (head_len * 0.6), head_right
			]
			draw_colored_polygon(poly, wind_color)

		# 6. Center hub dot
		draw_circle(center, 2.5, Color(0.9, 0.95, 1.0, 1.0))


var day_label: Label
var time_label: Label
var period_label: Label
var wind_label: Label
var compass_dial: CompassDial
var _hovered: bool = false
var _font_bold: Font = null
var _font_semibold: Font = null


func _ready() -> void:
	if ResourceLoader.exists(FONT_BOLD_PATH):
		_font_bold = load(FONT_BOLD_PATH) as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_font_semibold = load(FONT_SEMIBOLD_PATH) as Font

	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Time of Day & Wind\nClick or press [N] to cycle time"

	_build_ui()
	_update_style()
	_update_display()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if GameState.instance:
		GameState.instance.time_changed.connect(_on_time_changed)
		GameState.instance.wind_changed.connect(_on_wind_changed)
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
		GameState.instance.day_advanced.connect(_on_day_advanced)


func _exit_tree() -> void:
	if GameState.instance:
		if GameState.instance.time_changed.is_connected(_on_time_changed):
			GameState.instance.time_changed.disconnect(_on_time_changed)
		if GameState.instance.wind_changed.is_connected(_on_wind_changed):
			GameState.instance.wind_changed.disconnect(_on_wind_changed)
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
		if GameState.instance.day_advanced.is_connected(_on_day_advanced):
			GameState.instance.day_advanced.disconnect(_on_day_advanced)


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	var text_vbox := VBoxContainer.new()
	text_vbox.name = "TextVBox"
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(text_vbox)

	day_label = Label.new()
	day_label.name = "DayLabel"
	if _font_bold:
		day_label.add_theme_font_override("font", _font_bold)
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	day_label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14))
	day_label.add_theme_constant_override("outline_size", 3)
	day_label.text = "Day 1"
	text_vbox.add_child(day_label)

	time_label = Label.new()
	time_label.name = "TimeLabel"
	if _font_bold:
		time_label.add_theme_font_override("font", _font_bold)
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	time_label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14))
	time_label.add_theme_constant_override("outline_size", 4)
	time_label.text = "3:30 PM"
	text_vbox.add_child(time_label)

	period_label = Label.new()
	period_label.name = "PeriodLabel"
	if _font_semibold:
		period_label.add_theme_font_override("font", _font_semibold)
	period_label.add_theme_font_size_override("font_size", 11)
	period_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	period_label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14))
	period_label.add_theme_constant_override("outline_size", 2)
	period_label.text = "AFTERNOON"
	text_vbox.add_child(period_label)

	wind_label = Label.new()
	wind_label.name = "WindLabel"
	if _font_semibold:
		wind_label.add_theme_font_override("font", _font_semibold)
	wind_label.add_theme_font_size_override("font_size", 11)
	wind_label.add_theme_color_override("font_color", Color(0.68, 0.88, 0.95))
	wind_label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14))
	wind_label.add_theme_constant_override("outline_size", 2)
	wind_label.text = "WIND: 12 MPH ENE"
	text_vbox.add_child(wind_label)

	compass_dial = CompassDial.new()
	compass_dial.name = "CompassDial"
	compass_dial.font = _font_semibold
	hbox.add_child(compass_dial)


func _update_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.88)
	style.border_color = (
		Color(0.45, 0.65, 0.85, 0.95) if _hovered else Color(0.28, 0.38, 0.50, 0.80)
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	_hovered = true
	if compass_dial:
		compass_dial.is_hovered = true
	_update_style()


func _on_mouse_exited() -> void:
	_hovered = false
	if compass_dial:
		compass_dial.is_hovered = false
	_update_style()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		GameState.cycle_time_of_day()
		accept_event()


func _on_time_changed(_hours: float, _time_str: String) -> void:
	_update_display()


func _on_wind_changed(_dir: Vector3, _speed: float) -> void:
	_update_display()


func _on_time_of_day_changed(_mode: GameState.TimeOfDay) -> void:
	_update_display()


func _on_day_advanced(_day_number: int) -> void:
	_update_display()


func _update_display() -> void:
	if not time_label:
		return
	day_label.text = "Day %d" % GameState.current_day
	time_label.text = GameState.get_time_string()
	var period := GameState.get_period_name()
	period_label.text = period

	# Period color modulation
	match period:
		"AFTERNOON":
			period_label.add_theme_color_override("font_color", Color(0.70, 0.85, 0.98))
			time_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
		"GOLDEN HOUR":
			period_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40))
			time_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
		"SUNSET":
			period_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.32))
			time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.65))
		"TWILIGHT":
			period_label.add_theme_color_override("font_color", Color(0.80, 0.62, 0.95))
			time_label.add_theme_color_override("font_color", Color(0.90, 0.88, 1.0))
		"NIGHT":
			period_label.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
			time_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))

	var cardinal := GameState.get_cardinal_direction_name(GameState.wind_direction)
	var mph := int(round(GameState.wind_speed * 12.0))
	wind_label.text = "WIND: %d MPH %s" % [mph, cardinal]
	if compass_dial:
		compass_dial.queue_redraw()
