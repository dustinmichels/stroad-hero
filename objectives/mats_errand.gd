class_name MatsErrand
extends Resource

@export var id: StringName = &""
@export var item: String = ""
@export var store_name: String = ""
@export var target_path: NodePath = NodePath()
@export var call_line: String = ""
@export var success_line: String = ""
@export var location_id: StringName = &""
@export var proper_store_name: String = ""
@export var generic_store_name: String = ""
@export var used_location_name: String = ""
@export var category: String = ""


func _init(
	p_id: StringName = &"",
	p_item: String = "",
	p_store_name: String = "",
	p_target_path: NodePath = NodePath(),
	p_call_line: String = "",
	p_success_line: String = "",
	p_location_id: StringName = &"",
	p_proper_store_name: String = "",
	p_generic_store_name: String = "",
	p_used_location_name: String = "",
	p_category: String = ""
) -> void:
	id = p_id
	item = p_item
	store_name = p_store_name
	target_path = p_target_path
	call_line = p_call_line
	success_line = p_success_line
	location_id = p_location_id
	proper_store_name = p_proper_store_name if not p_proper_store_name.is_empty() else p_store_name
	generic_store_name = p_generic_store_name
	used_location_name = (
		p_used_location_name if not p_used_location_name.is_empty() else p_store_name
	)
	category = p_category
