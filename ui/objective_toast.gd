class_name ObjectiveToast
extends PanelContainer

const FONT_PATH := "res://fonts/Overpass-SemiBold.ttf"

@export var duration: float = 2.0

var checkmark: ObjectiveCheckmark = null
var label: Label = null
var hbox: HBoxContainer = null

var _built: bool = false
var _tween: Tween = null
var _character_editor: CharacterEditor = null


func _ready() -> void:
	if not _built:
		_build()
	resized.connect(_on_resized)
	visible = false
	_find_character_editor.call_deferred()


func _exit_tree() -> void:
	if _character_editor and is_instance_valid(_character_editor):
		if _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		):
			_character_editor.visibility_changed.disconnect(_on_character_editor_visibility_changed)


func _find_character_editor() -> CharacterEditor:
	if _character_editor and is_instance_valid(_character_editor):
		return _character_editor
	if (
		get_parent()
		and get_parent().get_parent()
		and get_parent().get_parent().has_node("CharacterEditor")
	):
		_character_editor = (
			get_parent().get_parent().get_node("CharacterEditor") as CharacterEditor
		)
	elif is_inside_tree() and get_tree().root:
		_character_editor = (
			get_tree().root.find_child("CharacterEditor", true, false) as CharacterEditor
		)
	if (
		_character_editor
		and not _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		)
	):
		_character_editor.visibility_changed.connect(_on_character_editor_visibility_changed)
	return _character_editor


func _on_character_editor_visibility_changed() -> void:
	if _character_editor and _character_editor.visible:
		visible = false


func _build() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Centered on screen
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.85, 0.35, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 24.0
	style.content_margin_top = 14.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", style)

	hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	checkmark = ObjectiveCheckmark.new()
	checkmark.name = "Checkmark"
	checkmark.custom_minimum_size = Vector2(32, 32)
	checkmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(checkmark)

	label = Label.new()
	label.name = "MessageLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 22)
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		if font:
			label.add_theme_font_override("font", font)
	hbox.add_child(label)


func _on_resized() -> void:
	pivot_offset = size * 0.5


func show_toast(text: String = "Got the cough syrup!", toast_duration: float = -1.0) -> void:
	if not _built:
		_build()
	var d := toast_duration if toast_duration > 0.0 else duration
	if label:
		label.text = text
	visible = true
	modulate.a = 0.0
	reset_size()
	pivot_offset = size * 0.5
	scale = Vector2(0.65, 0.65)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()

	# Scale in + fade in
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	# Hold
	var hold_time := maxf(0.1, d - 0.6)
	_tween.chain().tween_interval(hold_time)

	# Fade out (chained after hold_time, scale and fade in parallel)
	(
		_tween
		. chain()
		. tween_property(self, "modulate:a", 0.0, 0.35)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. parallel()
		. tween_property(self, "scale", Vector2(1.05, 1.05), 0.35)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_tween.chain().tween_callback(func(): visible = false)


func is_showing() -> bool:
	return visible


func get_text() -> String:
	return label.text if label else ""
