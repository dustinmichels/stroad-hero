@tool
class_name USFlag
extends StaticBody3D

enum FlagSize {
	STANDARD,
	LARGE,
	GIANT,
}

@export var flag_size: FlagSize = FlagSize.STANDARD:
	set(value):
		flag_size = value
		_apply_flag_size()

@onready var _visuals: Node3D = $Visuals
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_apply_flag_size()


func set_flag_size(p_size: FlagSize) -> void:
	flag_size = p_size


func _apply_flag_size() -> void:
	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	for child in visuals.get_children():
		if child is Node3D:
			child.visible = false

	var active_node: Node3D = null
	match flag_size:
		FlagSize.STANDARD:
			active_node = visuals.get_node_or_null("Standard")
		FlagSize.LARGE:
			active_node = visuals.get_node_or_null("Large")
		FlagSize.GIANT:
			active_node = visuals.get_node_or_null("Giant")

	if active_node:
		active_node.visible = true

	_update_collision()


func _update_collision() -> void:
	var col := (
		_collision_shape
		if _collision_shape
		else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	)
	if not col:
		return

	var radius: float = 0.20
	var height: float = 8.0
	var pos_y: float = 4.0

	match flag_size:
		FlagSize.STANDARD:
			radius = 0.20
			height = 8.0
			pos_y = 4.0
		FlagSize.LARGE:
			radius = 0.26
			height = 11.5
			pos_y = 5.75
		FlagSize.GIANT:
			radius = 0.38
			height = 16.5
			pos_y = 8.25

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = Vector3(0.0, pos_y, 0.0)
