class_name HUD
extends CanvasLayer

@onready var spd_label: Label = %SpdLabel
@onready var desc_label: Label = %DescLabel
@onready var action_label: Label = %ActionLabel
@onready var margin_container: MarginContainer = $MarginContainer
@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer

var night_mode_button: Button = null
var spd_count: int = 0
var fade_overlay: ColorRect
var _action_prompt_sources := {}
var _default_margin_pos := Vector2(20.0, 20.0)
var _fade_tween: Tween
var _spd_tween: Tween


func _ready() -> void:
	_setup_fade_overlay()
	_setup_night_mode_button()
	if margin_container:
		_default_margin_pos = margin_container.position
		margin_container.pivot_offset = Vector2.ZERO
	_update_display()
	add_to_group("hud")


func _exit_tree() -> void:
	if GameState.instance:
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)


func _setup_fade_overlay() -> void:
	var existing := get_node_or_null("FadeOverlay") as ColorRect
	if existing:
		fade_overlay = existing
	else:
		fade_overlay = ColorRect.new()
		fade_overlay.name = "FadeOverlay"
		fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fade_overlay)
		move_child(fade_overlay, 0)


func _setup_night_mode_button() -> void:
	var existing := get_node_or_null("%NightModeButton") as Button
	if existing:
		night_mode_button = existing
	else:
		var container := MarginContainer.new()
		container.name = "NightModeContainer"
		container.anchors_preset = Control.PRESET_TOP_RIGHT
		container.anchor_left = 1.0
		container.anchor_right = 1.0
		container.offset_left = -254.0
		container.offset_top = 20.0
		container.offset_right = -20.0
		container.offset_bottom = 54.0
		container.grow_horizontal = Control.GROW_DIRECTION_BEGIN

		var btn = TimeOfDayToggle.new()
		btn.name = "NightModeButton"
		btn.unique_name_in_owner = true

		container.add_child(btn)
		add_child(container)
		night_mode_button = btn
	if not night_mode_button.has_method("set_mode"):
		night_mode_button.pressed.connect(_on_night_mode_button_pressed)
	if GameState.instance:
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
	_update_night_mode_button(GameState.time_of_day)


func _on_night_mode_button_pressed() -> void:
	GameState.cycle_time_of_day()


func _on_time_of_day_changed(mode: GameState.TimeOfDay) -> void:
	_update_night_mode_button(mode)


func _update_night_mode_button(mode: Variant) -> void:
	if not night_mode_button:
		return
	var tod: GameState.TimeOfDay = GameState.time_of_day
	if mode is GameState.TimeOfDay:
		tod = mode
	if night_mode_button.has_method("set_mode"):
		night_mode_button.set_mode(tod)
	else:
		match tod:
			GameState.TimeOfDay.DAY:
				night_mode_button.text = "TIME: DAY [N]"
				night_mode_button.tooltip_text = "Time of Day: Day (Click or press N for Sunset)"
			GameState.TimeOfDay.EVENING:
				night_mode_button.text = "TIME: SUNSET [N]"
				night_mode_button.tooltip_text = "Time of Day: Sunset (Click or press N for Night)"
			GameState.TimeOfDay.NIGHT:
				night_mode_button.text = "TIME: NIGHT [N]"
				night_mode_button.tooltip_text = "Time of Day: Night (Click or press N for Day)"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_N:
			GameState.cycle_time_of_day()
			get_viewport().set_input_as_handled()


func increment_spd() -> void:
	spd_count += 1
	_update_display()
	_animate_increment()


func fade_to_black(duration: float = 0.4) -> void:
	if action_label:
		action_label.visible = false
	_action_prompt_sources.clear()
	if not fade_overlay:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	(
		_fade_tween
		. tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	await _fade_tween.finished


func emphasize_death_spd(hold_duration: float = 0.8) -> void:
	spd_count += 1
	_update_display()

	if not margin_container or not spd_label:
		if is_inside_tree():
			await get_tree().create_timer(hold_duration).timeout
		return

	if _spd_tween and _spd_tween.is_valid():
		_spd_tween.kill()
	_spd_tween = create_tween()

	margin_container.pivot_offset = Vector2.ZERO
	(
		_spd_tween
		. tween_property(margin_container, "scale", Vector2(1.65, 1.65), 0.25)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_spd_tween
		. parallel()
		. tween_property(
			margin_container, "position", _default_margin_pos + Vector2(24.0, 24.0), 0.25
		)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	spd_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	if desc_label:
		desc_label.modulate = Color(1.0, 0.9, 0.9, 1.0)
	_spd_tween.parallel().tween_property(spd_label, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.25)

	var half_hold := hold_duration * 0.5
	(
		_spd_tween
		. tween_property(margin_container, "scale", Vector2(1.58, 1.58), half_hold)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_spd_tween
		. tween_property(margin_container, "scale", Vector2(1.65, 1.65), half_hold)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	await _spd_tween.finished


func fade_from_black(duration: float = 0.45) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if _spd_tween and _spd_tween.is_valid():
		_spd_tween.kill()

	_fade_tween = create_tween()
	_spd_tween = create_tween()

	if fade_overlay:
		(
			_fade_tween
			. tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)

	if margin_container:
		(
			_spd_tween
			. tween_property(margin_container, "scale", Vector2(1.0, 1.0), duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_spd_tween
			. parallel()
			. tween_property(margin_container, "position", _default_margin_pos, duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	if spd_label:
		_spd_tween.parallel().tween_property(spd_label, "modulate", Color.WHITE, duration)
	if desc_label:
		_spd_tween.parallel().tween_property(
			desc_label, "modulate", Color(0.85, 0.65, 0.65, 0.9), duration
		)

	if fade_overlay:
		await _fade_tween.finished
	elif is_inside_tree():
		await get_tree().create_timer(duration).timeout


func set_spd(value: int) -> void:
	spd_count = value
	_update_display()


func set_action_prompt(source: Node, active: bool) -> void:
	if active:
		_action_prompt_sources[source] = true
	else:
		_action_prompt_sources.erase(source)
	action_label.visible = not _action_prompt_sources.is_empty()


func _update_display() -> void:
	if spd_label:
		spd_label.text = "SPD: %d" % spd_count


func _animate_increment() -> void:
	if not spd_label:
		return
	var tween := create_tween()
	spd_label.pivot_offset = spd_label.size * 0.5
	spd_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	(
		tween
		. tween_property(spd_label, "scale", Vector2(1.35, 1.35), 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(spd_label, "scale", Vector2(1.0, 1.0), 0.15)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(spd_label, "modulate", Color.WHITE, 0.25)
