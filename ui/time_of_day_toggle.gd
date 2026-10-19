class_name TimeOfDayToggle
extends Button

## A tactile 3-way toggle switch for Day, Sunset, and Night.
## Renders a unified pill track with a sliding thumb selector instead of multiple buttons.

const FONT_PATH := "res://fonts/ArchivoBlack-Regular.ttf"

var mode: GameState.TimeOfDay = GameState.TimeOfDay.DAY
var slider_pos: float = 0.0:
	set(val):
		slider_pos = val
		queue_redraw()

var _tween: Tween = null
var _font: Font = null
var _hovered: bool = false
var _is_pressed: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(234, 34)
	size = Vector2(234, 34)
	focus_mode = FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font

	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	set_mode(GameState.time_of_day, true)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func set_mode(new_mode: GameState.TimeOfDay, immediate: bool = false) -> void:
	mode = new_mode
	var target_pos := float(mode)

	match mode:
		GameState.TimeOfDay.DAY:
			text = "TIME: DAY [N]"
			tooltip_text = "Time of Day: Day (Click or press N for Sunset)"
		GameState.TimeOfDay.EVENING:
			text = "TIME: SUNSET [N]"
			tooltip_text = "Time of Day: Sunset (Click or press N for Night)"
		GameState.TimeOfDay.NIGHT:
			text = "TIME: NIGHT [N]"
			tooltip_text = "Time of Day: Night (Click or press N for Day)"

	if immediate:
		if _tween and _tween.is_valid():
			_tween.kill()
		slider_pos = target_pos
	else:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "slider_pos", target_pos, 0.22)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_pressed = true
			accept_event()
		else:
			if _is_pressed:
				_is_pressed = false
				var local_rect := Rect2(Vector2.ZERO, size)
				if local_rect.has_point(event.position):
					var slot_w := size.x / 3.0
					var clicked_slot: int = clampi(int(event.position.x / slot_w), 0, 2)
					var target_mode: GameState.TimeOfDay = clicked_slot as GameState.TimeOfDay

					if target_mode == mode:
						GameState.cycle_time_of_day()
					else:
						GameState.set_time_of_day(target_mode)
				accept_event()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var track_radius := h * 0.5
	var slot_w := w / 3.0

	# 1. Track chassis
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	bg_style.border_color = (
		Color(0.40, 0.48, 0.60, 0.95) if _hovered else Color(0.22, 0.26, 0.33, 0.85)
	)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.set_corner_radius_all(int(track_radius))
	bg_style.draw(get_canvas_item(), Rect2(0, 0, w, h))

	# 2. Slot divider notches (only visible between adjacent inactive slots)
	var div1_alpha: float = clampf((slider_pos - 1.2) / 0.6, 0.0, 1.0)
	if div1_alpha > 0.01:
		var div1_col := Color(0.22, 0.26, 0.33, 0.5 * div1_alpha)
		draw_line(Vector2(slot_w, 7), Vector2(slot_w, h - 7), div1_col, 1.0)

	var div2_alpha: float = clampf((0.8 - slider_pos) / 0.6, 0.0, 1.0)
	if div2_alpha > 0.01:
		var div2_col := Color(0.22, 0.26, 0.33, 0.5 * div2_alpha)
		draw_line(Vector2(slot_w * 2.0, 7), Vector2(slot_w * 2.0, h - 7), div2_col, 1.0)
	# 3. Inactive slot icons & labels (only rendered when not covered by thumb)
	for i in range(3):
		var dist: float = absf(slider_pos - float(i))
		if dist > 0.15:
			var slot_center := Vector2(slot_w * (float(i) + 0.5), h * 0.5)
			var alpha: float = clampf((dist - 0.15) / 0.5, 0.0, 1.0)
			_draw_slot_content(i, slot_center, false, alpha)

	# 4. Sliding Thumb (tactile toggle knob)
	var m := 3.0
	var tw := slot_w - 2.0 * m
	var th := h - 2.0 * m
	var tx := m + slider_pos * slot_w


	# Symmetric thumb shadow
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	shadow_style.set_corner_radius_all(int(th * 0.5))
	shadow_style.draw(get_canvas_item(), Rect2(tx, m, tw, th))

	# Thumb colors interpolated across modes
	var thumb_bg: Color
	var thumb_border: Color
	if slider_pos <= 1.0:
		thumb_bg = Color(0.96, 0.74, 0.16).lerp(Color(0.92, 0.42, 0.14), slider_pos)
		thumb_border = Color(1.0, 0.90, 0.45).lerp(Color(1.0, 0.65, 0.38), slider_pos)
	else:
		var t := slider_pos - 1.0
		thumb_bg = Color(0.92, 0.42, 0.14).lerp(Color(0.24, 0.38, 0.72), t)
		thumb_border = Color(1.0, 0.65, 0.38).lerp(Color(0.55, 0.72, 1.0), t)

	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = thumb_bg
	thumb_style.border_color = thumb_border
	thumb_style.border_width_left = 1
	thumb_style.border_width_top = 1
	thumb_style.border_width_right = 1
	thumb_style.border_width_bottom = 1
	thumb_style.set_corner_radius_all(int(th * 0.5))
	thumb_style.draw(get_canvas_item(), Rect2(tx, m, tw, th))

	# Active slot content inside the knob
	var active_slot := clampi(int(roundf(slider_pos)), 0, 2)
	_draw_slot_content(active_slot, Vector2(tx + tw * 0.5, m + th * 0.5), true)


func _draw_slot_content(
	slot_idx: int, center: Vector2, is_active: bool, alpha: float = 1.0
) -> void:
	var label_text := ""
	var fg_color: Color
	var icon_w := 11.0
	var font_size := 10 if slot_idx == 1 else 11

	match slot_idx:
		0:
			label_text = "DAY"
			icon_w = 12.0
			if is_active:
				fg_color = Color(0.14, 0.08, 0.01, 1.0)
			else:
				fg_color = Color(0.70, 0.65, 0.45, 0.65 * alpha)
		1:
			label_text = "SUNSET"
			icon_w = 13.0
			if is_active:
				fg_color = Color(1.0, 0.96, 0.92, 1.0)
			else:
				fg_color = Color(0.75, 0.52, 0.38, 0.65 * alpha)
		2:
			label_text = "NIGHT"
			icon_w = 11.0
			if is_active:
				fg_color = Color(0.92, 0.96, 1.0, 1.0)
			else:
				fg_color = Color(0.48, 0.58, 0.78, 0.65 * alpha)

	var text_w := 0.0
	if _font:
		text_w = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var gap := 5.0
	var total_w := icon_w + gap + text_w
	var start_x := center.x - total_w * 0.5
	var icon_c := Vector2(start_x + icon_w * 0.5, center.y)

	match slot_idx:
		0:
			_draw_sun(icon_c, fg_color, 4.0 if is_active else 3.5)
		1:
			_draw_sunset(icon_c, fg_color, 4.5 if is_active else 4.0)
		2:
			_draw_moon(icon_c, fg_color, 4.5 if is_active else 4.0)

	if _font:
		var text_pos := Vector2(start_x + icon_w + gap, center.y + 4.0)
		draw_string(_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg_color)


func _draw_sun(c: Vector2, col: Color, radius: float) -> void:
	draw_circle(c, radius, col)
	for i in range(8):
		var a := float(i) * PI * 0.25
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (radius + 1.5), c + dir * (radius + 3.5), col, 1.2)


func _draw_sunset(c: Vector2, col: Color, radius: float) -> void:
	draw_line(c + Vector2(-radius - 2.5, 1.5), c + Vector2(radius + 2.5, 1.5), col, 1.2)
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-radius, 1.0))
	for i in range(9):
		var a := PI + float(i) / 8.0 * PI
		pts.append(c + Vector2(cos(a) * radius, sin(a) * radius + 1.0))
	pts.append(c + Vector2(radius, 1.0))
	draw_colored_polygon(pts, col)


func _draw_moon(c: Vector2, col: Color, radius: float) -> void:
	draw_arc(c, radius, -PI * 0.52, PI * 0.52, 14, col, 2.0, true)
	draw_arc(c + Vector2(2.0, 0.0), radius * 0.72, -PI * 0.45, PI * 0.45, 12, col, 1.2, true)
