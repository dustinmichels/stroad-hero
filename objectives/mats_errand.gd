class_name MatsErrand
extends Resource

@export var id: StringName = &""
@export var item: String = ""
@export var store_name: String = ""
@export var target_path: NodePath = NodePath()
@export var call_line: String = ""
@export var success_line: String = ""


func _init(
	p_id: StringName = &"",
	p_item: String = "",
	p_store_name: String = "",
	p_target_path: NodePath = NodePath(),
	p_call_line: String = "",
	p_success_line: String = ""
) -> void:
	id = p_id
	item = p_item
	store_name = p_store_name
	target_path = p_target_path
	call_line = p_call_line
	success_line = p_success_line
