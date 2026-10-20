class_name PhoneCall
extends Control

signal call_answered
signal call_dismissed

@export var objective_manager_path: NodePath

@onready var ringing_panel: PanelContainer = %RingingPanel
@onready var in_call_panel: PanelContainer = %InCallPanel
@onready var caller_label: Label = %CallerLabel
@onready var prompt_label: Label = %PromptLabel
@onready var phone_icon: Control = %PhoneIcon
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var ok_prompt_label: Label = %OkPromptLabel
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var portrait_container: PanelContainer = %PortraitContainer

var objective_manager: ObjectiveManager = null
var current_errand: MatsErrand = null
var is_ringing: bool = false
var is_in_call: bool = false

var _shake_tween: Tween = null
var _typewriter_tween: Tween = null
var _character_editor: CharacterEditor = null


func _ready() -> void:
	hide_all()
	_find_objective_manager.call_deferred()
	_find_character_editor.call_deferred()


func _exit_tree() -> void:
	if objective_manager:
		if objective_manager.call_started.is_connected(_on_call_started):
			objective_manager.call_started.disconnect(_on_call_started)
		if objective_manager.call_answered.is_connected(_on_call_answered):
			objective_manager.call_answered.disconnect(_on_call_answered)
		if objective_manager.state_changed.is_connected(_on_state_changed):
			objective_manager.state_changed.disconnect(_on_state_changed)
	if _character_editor and is_instance_valid(_character_editor):
		if _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		):
			_character_editor.visibility_changed.disconnect(_on_character_editor_visibility_changed)


func _find_objective_manager() -> void:
	if objective_manager:
		return
	if has_node(objective_manager_path):
		set_objective_manager(get_node(objective_manager_path) as ObjectiveManager)
		return
	var mgr := get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager
	if mgr:
		set_objective_manager(mgr)


func set_character_editor(c: CharacterEditor) -> void:
	if _character_editor and is_instance_valid(_character_editor):
		if _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		):
			_character_editor.visibility_changed.disconnect(_on_character_editor_visibility_changed)
	_character_editor = c
	if (
		_character_editor
		and not _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		)
	):
		_character_editor.visibility_changed.connect(_on_character_editor_visibility_changed)


func _find_character_editor() -> CharacterEditor:
	if _character_editor and is_instance_valid(_character_editor):
		return _character_editor
	if is_inside_tree():
		var hud := get_parent() as HUD
		if hud and hud.character_editor:
			set_character_editor(hud.character_editor)
			return _character_editor
		var editor := get_tree().get_first_node_in_group("character_editor") as CharacterEditor
		if editor:
			set_character_editor(editor)
			return _character_editor
	return null


func _is_character_editor_open() -> bool:
	var editor := _find_character_editor()
	return editor != null and editor.visible


func _on_character_editor_visibility_changed() -> void:
	if _is_character_editor_open():
		if ringing_panel:
			ringing_panel.visible = false
		if in_call_panel:
			in_call_panel.visible = false
		visible = false
	else:
		if is_ringing:
			show_ringing(current_errand)
		elif is_in_call:
			visible = true
			if ringing_panel:
				ringing_panel.visible = false
			if in_call_panel:
				in_call_panel.visible = true


func set_objective_manager(mgr: ObjectiveManager) -> void:
	if objective_manager == mgr:
		return
	if objective_manager:
		if objective_manager.call_started.is_connected(_on_call_started):
			objective_manager.call_started.disconnect(_on_call_started)
		if objective_manager.call_answered.is_connected(_on_call_answered):
			objective_manager.call_answered.disconnect(_on_call_answered)
		if objective_manager.state_changed.is_connected(_on_state_changed):
			objective_manager.state_changed.disconnect(_on_state_changed)
	objective_manager = mgr
	if objective_manager:
		objective_manager.call_started.connect(_on_call_started)
		objective_manager.call_answered.connect(_on_call_answered)
		objective_manager.state_changed.connect(_on_state_changed)
		_sync_with_manager()


func _sync_with_manager() -> void:
	if not objective_manager:
		return
	match objective_manager.current_state:
		ObjectiveManager.State.RINGING:
			show_ringing(objective_manager.current_errand)
		ObjectiveManager.State.IN_CALL:
			show_in_call(objective_manager.current_errand)
		_:
			hide_all()


func _on_call_started(errand: MatsErrand) -> void:
	show_ringing(errand)


func _on_call_answered(errand: MatsErrand) -> void:
	show_in_call(errand)


func _on_state_changed(
	_old_state: ObjectiveManager.State, new_state: ObjectiveManager.State
) -> void:
	if (
		new_state == ObjectiveManager.State.IDLE
		or new_state == ObjectiveManager.State.ACTIVE
		or new_state == ObjectiveManager.State.COMPLETE
	):
		hide_all()


func show_ringing(errand: MatsErrand = null) -> void:
	if errand:
		current_errand = errand
	is_ringing = true
	is_in_call = false
	if _is_character_editor_open():
		visible = false
		if ringing_panel:
			ringing_panel.visible = false
		if in_call_panel:
			in_call_panel.visible = false
		return
	visible = true
	in_call_panel.visible = false
	ringing_panel.visible = true
	caller_label.text = "MOM"
	prompt_label.text = "[Enter] Answer"
	_start_ringing_animation()


func show_in_call(errand: MatsErrand = null) -> void:
	if errand:
		current_errand = errand
	is_ringing = false
	is_in_call = true
	if _is_character_editor_open():
		visible = false
		if ringing_panel:
			ringing_panel.visible = false
		if in_call_panel:
			in_call_panel.visible = false
		return
	visible = true
	_stop_ringing_animation()
	ringing_panel.visible = false
	in_call_panel.visible = true
	speaker_label.text = "Mom"
	var text := ""
	if current_errand and not current_errand.call_line.is_empty():
		text = current_errand.call_line
	else:
		text = "Mats, could you pick something up for me?"
	_start_typewriter(text)
	if portrait_container:
		var p_size: Vector2 = (
			portrait_container.size if portrait_container.size.x > 0 else Vector2(104, 104)
		)
		portrait_container.pivot_offset = p_size * 0.5
		portrait_container.scale = Vector2(0.88, 0.88)
		var pop_tween := create_tween()
		(
			pop_tween
			. tween_property(portrait_container, "scale", Vector2.ONE, 0.22)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)


func answer() -> void:
	if not is_ringing:
		return
	is_ringing = false
	_stop_ringing_animation()
	call_answered.emit()
	if objective_manager and objective_manager.current_state == ObjectiveManager.State.RINGING:
		objective_manager.answer_call()


func dismiss() -> void:
	if not is_in_call:
		return
	is_in_call = false
	hide_all()
	call_dismissed.emit()
	if objective_manager and objective_manager.current_state == ObjectiveManager.State.IN_CALL:
		objective_manager.dismiss_call()


func hide_all() -> void:
	is_ringing = false
	is_in_call = false
	_stop_ringing_animation()
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
		_typewriter_tween = null
	if ringing_panel:
		ringing_panel.visible = false
	if in_call_panel:
		in_call_panel.visible = false
	visible = false


func _start_ringing_animation() -> void:
	_stop_ringing_animation()
	ringing_panel.pivot_offset = ringing_panel.size * 0.5
	_shake_tween = create_tween().set_loops()
	_shake_tween.tween_property(ringing_panel, "scale", Vector2(1.06, 1.06), 0.25).set_trans(
		Tween.TRANS_SINE
	)
	_shake_tween.parallel().tween_property(ringing_panel, "rotation_degrees", 2.0, 0.12).set_trans(
		Tween.TRANS_SINE
	)
	_shake_tween.tween_property(ringing_panel, "rotation_degrees", -2.0, 0.13).set_trans(
		Tween.TRANS_SINE
	)
	_shake_tween.tween_property(ringing_panel, "scale", Vector2.ONE, 0.25).set_trans(
		Tween.TRANS_SINE
	)
	_shake_tween.parallel().tween_property(ringing_panel, "rotation_degrees", 0.0, 0.13).set_trans(
		Tween.TRANS_SINE
	)
	_shake_tween.tween_interval(0.3)


func _stop_ringing_animation() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		_shake_tween = null
	if ringing_panel:
		ringing_panel.scale = Vector2.ONE
		ringing_panel.rotation_degrees = 0.0


func _start_typewriter(line: String) -> void:
	dialogue_label.text = line
	dialogue_label.visible_ratio = 0.0
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	var duration := clampf(float(line.length()) * 0.025, 0.8, 2.5)
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration).set_trans(
		Tween.TRANS_LINEAR
	)


func _finish_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
		_typewriter_tween = null
	dialogue_label.visible_ratio = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (not is_ringing and not is_in_call):
		return
	if is_inside_tree() and get_tree().paused:
		return

	if not _is_answer_action(event):
		return

	get_viewport().set_input_as_handled()

	if is_ringing:
		answer()
	elif is_in_call:
		if (
			_typewriter_tween
			and _typewriter_tween.is_valid()
			and dialogue_label.visible_ratio < 1.0
		):
			_finish_typewriter()
		else:
			dismiss()


func _is_answer_action(event: InputEvent) -> bool:
	if InputMap.has_action("answer_phone") and event.is_action_pressed("answer_phone"):
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (
			event.keycode == KEY_ENTER
			or event.physical_keycode == KEY_ENTER
			or event.keycode == KEY_KP_ENTER
			or event.physical_keycode == KEY_KP_ENTER
		):
			return true
	return false
