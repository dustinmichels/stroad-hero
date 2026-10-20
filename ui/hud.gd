class_name HUD
extends CanvasLayer

@onready var spd_label: Label = %SpdLabel
@onready var desc_label: Label = %DescLabel
@onready var action_label: Label = %ActionLabel
@onready var margin_container: MarginContainer = $MarginContainer
@onready var panel_container: PanelContainer = %PanelContainer
@onready var obj_label: Label = %ObjLabel
@onready var obj_desc_label: Label = %ObjDescLabel
@onready var obj_panel_container: PanelContainer = %ObjPanelContainer
@onready var phone_call: PhoneCall = $PhoneCall
@onready var objective_line: Control = %ObjectiveLine
@onready var current_objective_label: Label = %CurrentObjectiveLabel

const ObjectiveToast = preload("res://ui/objective_toast.gd")
@onready var objective_arrow: ObjectiveArrow = %ObjectiveArrow
@onready var objective_toast: ObjectiveToast = %ObjectiveToast
var objective_manager: ObjectiveManager = null
var current_objective_text: String = ""

var night_mode_button: Button = null
var spd_count: int = 0
var obj_count: int = 0
var fade_overlay: ColorRect
var _action_prompt_sources := {}
var _default_margin_pos := Vector2(20.0, 20.0)
var _fade_tween: Tween
var _spd_tween: Tween
var _spd_placeholder: Control = null
var _camera: Camera3D = null


func _ready() -> void:
	_setup_fade_overlay()
	_setup_night_mode_button()
	_setup_objective_toast()
	if margin_container:
		_default_margin_pos = margin_container.position
		margin_container.pivot_offset = Vector2.ZERO
	_update_display()
	add_to_group("hud")
	_resolve_objective_manager.call_deferred()


func _process(_delta: float) -> void:
	if action_label and action_label.visible:
		_update_action_label_position()


func _exit_tree() -> void:
	if GameState.instance:
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
	if objective_manager:
		if objective_manager.objective_started.is_connected(_on_objective_started):
			objective_manager.objective_started.disconnect(_on_objective_started)
		if objective_manager.objective_completed.is_connected(_on_objective_completed):
			objective_manager.objective_completed.disconnect(_on_objective_completed)
		if objective_manager.state_changed.is_connected(_on_objective_state_changed):
			objective_manager.state_changed.disconnect(_on_objective_state_changed)


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


func _setup_objective_toast() -> void:
	var existing := get_node_or_null("%ObjectiveToast") as ObjectiveToast
	if existing:
		objective_toast = existing
	elif not objective_toast:
		objective_toast = ObjectiveToast.new()
		objective_toast.name = "ObjectiveToast"
		objective_toast.unique_name_in_owner = true
		add_child(objective_toast)


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
	_animate_increment(spd_label, Color(1.0, 0.2, 0.2, 1.0))


func increment_obj() -> void:
	obj_count += 1
	_update_display()
	_animate_increment(obj_label, Color(0.2, 0.95, 0.4, 1.0))


func fade_to_black(duration: float = 0.4) -> void:
	if action_label:
		action_label.visible = false
		action_label.modulate.a = 1.0
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


func _reset_spd_panel() -> void:
	if _spd_tween and _spd_tween.is_valid():
		_spd_tween.kill()
	if _spd_placeholder and is_instance_valid(_spd_placeholder):
		var p_parent := _spd_placeholder.get_parent()
		if p_parent:
			p_parent.remove_child(_spd_placeholder)
		_spd_placeholder.queue_free()
		_spd_placeholder = null
	if panel_container:
		panel_container.top_level = false
		panel_container.z_index = 0
		panel_container.scale = Vector2.ONE
		panel_container.pivot_offset = Vector2.ZERO
		panel_container.position = Vector2.ZERO
	if spd_label:
		spd_label.modulate = Color.WHITE
		spd_label.scale = Vector2.ONE
	if desc_label:
		desc_label.modulate = Color(0.85, 0.65, 0.65, 0.9)


func emphasize_death_spd(hold_duration: float = 1.5) -> void:
	if not panel_container or not spd_label:
		spd_count += 1
		_update_display()
		if is_inside_tree():
			await get_tree().create_timer(hold_duration).timeout
		return

	_reset_spd_panel()

	var parent := panel_container.get_parent()
	if not parent:
		spd_count += 1
		_update_display()
		if is_inside_tree():
			await get_tree().create_timer(hold_duration).timeout
		return

	# Show current count before incrementing
	_update_display()

	# Create placeholder in HBoxContainer to hold OBJ panel in place
	_spd_placeholder = Control.new()
	_spd_placeholder.name = "SpdPlaceholder"
	_spd_placeholder.custom_minimum_size = panel_container.size
	parent.add_child(_spd_placeholder)
	parent.move_child(_spd_placeholder, panel_container.get_index())

	var start_pos := panel_container.global_position
	var panel_size := panel_container.size

	panel_container.top_level = true
	panel_container.z_index = 10
	panel_container.global_position = start_pos
	panel_container.pivot_offset = panel_size * 0.5
	panel_container.scale = Vector2.ONE

	var vp_size := get_viewport().get_visible_rect().size
	var target_center_pos := (vp_size - panel_size) * 0.5
	var target_scale := Vector2(2.5, 2.5)

	var move_in_time: float
	var pause_before: float
	var count_punch_time: float
	var pause_after: float
	var shrink_time: float
	if hold_duration <= 0.1:
		move_in_time = 0.35
		pause_before = 0.0
		count_punch_time = 0.12
		pause_after = 0.0
		shrink_time = 0.35
	else:
		move_in_time = 0.45
		pause_before = 0.08
		count_punch_time = 0.28
		pause_after = 0.18
		shrink_time = 0.45

	_spd_tween = create_tween()

	# 1. Make it big, in middle of the screen
	(
		_spd_tween
		. tween_property(panel_container, "global_position", target_center_pos, move_in_time)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_spd_tween
		. parallel()
		. tween_property(panel_container, "scale", target_scale, move_in_time)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	if desc_label:
		_spd_tween.parallel().tween_property(
			desc_label, "modulate", Color(1.0, 0.9, 0.9, 1.0), move_in_time
		)

	# 2. Count up
	var punch_scale := target_scale * 1.15
	var half_punch := count_punch_time * 0.5
	if pause_before > 0.0:
		_spd_tween.tween_interval(pause_before)
	_spd_tween.tween_callback(
		func():
			spd_count += 1
			_update_display()
			_animate_increment(
				spd_label,
				Color(1.0, 0.2, 0.2, 1.0),
				half_punch,
				half_punch,
				count_punch_time + pause_after
			)
	)
	(
		_spd_tween
		. tween_property(panel_container, "scale", punch_scale, half_punch)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_spd_tween
		. tween_property(panel_container, "scale", target_scale, half_punch)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	if pause_after > 0.0:
		_spd_tween.tween_interval(pause_after)

	# 3. Shrink back into its spot
	(
		_spd_tween
		. tween_property(panel_container, "scale", Vector2.ONE, shrink_time)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_spd_tween
		. parallel()
		. tween_property(panel_container, "global_position", start_pos, shrink_time)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	if desc_label:
		_spd_tween.parallel().tween_property(
			desc_label, "modulate", Color(0.85, 0.65, 0.65, 0.9), shrink_time
		)

	await _spd_tween.finished
	_reset_spd_panel()


func fade_from_black(duration: float = 0.45) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()

	if fade_overlay:
		(
			_fade_tween
			. tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN_OUT)
		)

	_reset_spd_panel()

	if fade_overlay:
		await _fade_tween.finished
	elif is_inside_tree():
		await get_tree().create_timer(duration).timeout


func set_spd(value: int) -> void:
	spd_count = value
	_update_display()


func set_obj(value: int) -> void:
	obj_count = value
	_update_display()


func set_action_prompt(source: Node, active: bool, text: String = "") -> void:
	if active:
		_action_prompt_sources[source] = text
	else:
		_action_prompt_sources.erase(source)
	action_label.visible = not _action_prompt_sources.is_empty()
	if action_label.visible:
		var prompt_text := ""
		for src in _action_prompt_sources:
			var t: String = _action_prompt_sources[src]
			if not t.is_empty():
				prompt_text = t
				break
		if prompt_text.is_empty():
			prompt_text = "space to jump in"
		action_label.text = prompt_text
		_update_action_label_position()


func _get_active_camera() -> Camera3D:
	if _camera and is_instance_valid(_camera) and _camera.is_inside_tree():
		return _camera
	var vp := get_viewport()
	if vp:
		var vp_cam := vp.get_camera_3d()
		if vp_cam:
			_camera = vp_cam
			return _camera
	if is_inside_tree() and get_tree().root:
		var cam_node := get_tree().root.find_child("Camera3D", true, false) as Camera3D
		if cam_node:
			_camera = cam_node
			return cam_node
	return null


func _update_action_label_position() -> void:
	if not action_label or not action_label.visible:
		return
	var active_source: Node = null
	var stale_sources: Array = []
	for src in _action_prompt_sources:
		if is_instance_valid(src):
			if active_source == null:
				active_source = src
		else:
			stale_sources.append(src)
	for src in stale_sources:
		_action_prompt_sources.erase(src)

	if _action_prompt_sources.is_empty():
		action_label.visible = false
		return

	var target_pos: Vector3
	if active_source is Node3D:
		target_pos = (active_source as Node3D).global_position
		var mats := get_tree().get_first_node_in_group("player") as Node3D
		if mats and is_instance_valid(mats) and not mats.is_dead:
			var dist := target_pos.distance_to(mats.global_position)
			if dist < 3.0:
				target_pos = (target_pos + mats.global_position) * 0.5
		target_pos.y += 1.25
	else:
		var mats := get_tree().get_first_node_in_group("player") as Node3D
		if mats and is_instance_valid(mats):
			target_pos = mats.global_position + Vector3(0.0, 1.4, 0.0)
		else:
			return

	var cam := _get_active_camera()
	if not cam:
		return
	if cam.is_position_behind(target_pos):
		action_label.modulate.a = 0.0
		return
	action_label.modulate.a = 1.0

	var screen_pos := cam.unproject_position(target_pos)
	action_label.reset_size()
	var label_size := action_label.get_combined_minimum_size()
	var target_x := screen_pos.x - label_size.x * 0.5
	var target_y := screen_pos.y - label_size.y - 12.0

	var vp_rect := get_viewport().get_visible_rect()
	target_x = clampf(target_x, 10.0, maxf(10.0, vp_rect.size.x - label_size.x - 10.0))
	target_y = clampf(target_y, 10.0, maxf(10.0, vp_rect.size.y - label_size.y - 10.0))

	action_label.position = Vector2(target_x, target_y)


func _resolve_objective_manager() -> void:
	if objective_manager:
		return
	var mgr := get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager
	if not mgr and get_parent():
		mgr = get_parent().get_node_or_null("ObjectiveManager") as ObjectiveManager
	if mgr:
		set_objective_manager(mgr)


func set_objective_manager(mgr: ObjectiveManager) -> void:
	if objective_manager == mgr:
		return
	if objective_manager:
		if objective_manager.objective_started.is_connected(_on_objective_started):
			objective_manager.objective_started.disconnect(_on_objective_started)
		if objective_manager.objective_completed.is_connected(_on_objective_completed):
			objective_manager.objective_completed.disconnect(_on_objective_completed)
		if objective_manager.state_changed.is_connected(_on_objective_state_changed):
			objective_manager.state_changed.disconnect(_on_objective_state_changed)
	objective_manager = mgr
	if objective_manager:
		objective_manager.objective_started.connect(_on_objective_started)
		objective_manager.objective_completed.connect(_on_objective_completed)
		objective_manager.state_changed.connect(_on_objective_state_changed)
		_sync_objective_manager_state()
	if objective_arrow:
		objective_arrow.objective_manager = mgr


func _sync_objective_manager_state() -> void:
	if not objective_manager:
		clear_objective()
		return
	if (
		objective_manager.current_state == ObjectiveManager.State.ACTIVE
		and objective_manager.current_errand
	):
		_show_errand_objective(objective_manager.current_errand)
	else:
		clear_objective()


func _on_objective_started(errand: MatsErrand) -> void:
	_show_errand_objective(errand)


func _on_objective_completed(errand: MatsErrand, total: int) -> void:
	clear_objective()
	var text := (
		errand.success_line
		if (errand and not errand.success_line.is_empty())
		else "Got the cough syrup!"
	)
	show_toast(text)
	if total > 0:
		obj_count = total - 1
	increment_obj()


func _on_objective_state_changed(_old_state: int, new_state: int) -> void:
	if new_state != ObjectiveManager.State.ACTIVE:
		clear_objective()


func _show_errand_objective(errand: MatsErrand) -> void:
	if errand:
		var item_str := errand.item.to_lower()
		var store_str := errand.store_name
		set_current_objective("Get %s at %s" % [item_str, store_str])
	else:
		clear_objective()


func set_current_objective(text: String) -> void:
	current_objective_text = text
	if not objective_line:
		return
	if text.strip_edges().is_empty():
		objective_line.visible = false
	else:
		if current_objective_label:
			current_objective_label.text = text
		objective_line.visible = true


func set_objective(text: String) -> void:
	set_current_objective(text)


func clear_objective() -> void:
	set_current_objective("")


func get_current_objective() -> String:
	return current_objective_text


func show_toast(text: String, duration: float = 2.0) -> void:
	if not objective_toast:
		_setup_objective_toast()
	if objective_toast:
		objective_toast.show_toast(text, duration)


func _update_display() -> void:
	if spd_label:
		spd_label.text = "SPD: %d" % spd_count
	if obj_label:
		obj_label.text = "OBJ: %d" % obj_count


func _animate_increment(
	target_label: Label = null,
	flash_color: Color = Color(1.0, 0.2, 0.2, 1.0),
	pop_in_time: float = 0.08,
	pop_out_time: float = 0.15,
	color_fade_time: float = 0.25
) -> void:
	var lbl: Label = target_label if target_label else spd_label
	if not lbl:
		return
	var tween := create_tween()
	lbl.pivot_offset = lbl.size * 0.5
	lbl.modulate = flash_color
	(
		tween
		. tween_property(lbl, "scale", Vector2(1.35, 1.35), pop_in_time)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(lbl, "scale", Vector2(1.0, 1.0), pop_out_time)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(lbl, "modulate", Color.WHITE, color_fade_time)
