@tool
class_name ObjectivesEditorPlugin
extends EditorPlugin

const ObjectivesEditorDock = preload("res://addons/objectives_editor/objectives_editor_dock.gd")

var _dock: Control = null
var _bottom_panel_button: Button = null


func _enter_tree() -> void:
	_dock = ObjectivesEditorDock.new()
	_dock.name = "ObjectivesEditor"
	_bottom_panel_button = add_control_to_bottom_panel(_dock, "Objectives & Dialogue")
	add_tool_menu_item("Objectives & Dialogue Editor", _open_editor)


func _exit_tree() -> void:
	remove_tool_menu_item("Objectives & Dialogue Editor")
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.free()
		_dock = null
		_bottom_panel_button = null


func _open_editor() -> void:
	if _dock != null:
		make_bottom_panel_item_visible(_dock)
