class_name DaySummary
extends CanvasLayer

## End-of-day overlay: pauses the game, shows the day's counts, and starts the next day.

const FONT_BOLD_PATH := "res://fonts/Overpass-Bold.ttf"
const FONT_BLACK_PATH := "res://fonts/Overpass-Black.ttf"

var title_label: Label
var spd_label: Label
var obj_label: Label
var crossings_label: Label
var next_day_button: Button


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func show_summary(spd: int, objectives: int, crossings: int) -> void:
	spd_label.text = "SPD: %d" % spd
	obj_label.text = "Objectives: %d" % objectives
	crossings_label.text = "Crossings: %d" % crossings
	next_day_button.text = "Start Day %d" % (GameState.current_day + 1)
	visible = true
	get_tree().paused = true
	next_day_button.grab_focus()


func start_next_day() -> void:
	if not visible:
		return
	visible = false
	# Clear the press that confirmed the button so Mats doesn't jump on unpause.
	Input.action_release("jump")
	get_tree().paused = false
	GameState.start_next_day()


func _build_ui() -> void:
	var font_bold: Font = load(FONT_BOLD_PATH) as Font
	var font_black: Font = load(FONT_BLACK_PATH) as Font

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.0, 0.0, 0.0, 0.6)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.95)
	style.border_color = Color(0.45, 0.65, 0.85, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	title_label = _make_label("Day over!", font_black, 40, Color(1.0, 0.85, 0.35))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	vbox.add_child(_make_spacer(6))
	spd_label = _make_label("", font_bold, 24, Color(1.0, 0.95, 0.95))
	vbox.add_child(spd_label)
	obj_label = _make_label("", font_bold, 24, Color(0.95, 1.0, 0.95))
	vbox.add_child(obj_label)
	crossings_label = _make_label("", font_bold, 24, Color(1.0, 0.98, 0.9))
	vbox.add_child(crossings_label)
	vbox.add_child(_make_spacer(10))

	next_day_button = Button.new()
	next_day_button.name = "NextDayButton"
	next_day_button.custom_minimum_size = Vector2(220, 48)
	if font_bold:
		next_day_button.add_theme_font_override("font", font_bold)
	next_day_button.add_theme_font_size_override("font_size", 22)
	next_day_button.pressed.connect(start_next_day)
	vbox.add_child(next_day_button)


func _make_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
