@tool
class_name StreetTree
extends StaticBody3D

enum TreeType {
	STANDARD,
	TALL,
	BROAD,
	CLUSTERED,
	COMPACT,
}

@export var tree_type: TreeType = TreeType.STANDARD:
	set(value):
		tree_type = value
		_apply_tree_type()

@onready var _visuals: Node3D = $Visuals
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var _rustle_tween: Tween


func _ready() -> void:
	_apply_tree_type()
	if not Engine.is_editor_hint():
		var visuals := _visuals if _visuals else get_node_or_null("Visuals")
		if visuals:
			var active: Node3D = null
			for child in visuals.get_children():
				if child is Node3D and child.visible:
					active = child
					break
			if active != null:
				for child in visuals.get_children():
					if child != active:
						child.queue_free()


func set_tree_type(p_type: TreeType) -> void:
	tree_type = p_type


func rustle(impact_direction: Vector3) -> void:
	if impact_direction.is_zero_approx():
		return
	if _rustle_tween and _rustle_tween.is_running():
		return

	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	var foliage: Array[Node3D] = []
	for variant in visuals.get_children():
		if not (variant is Node3D) or not variant.visible:
			continue
		for child in variant.get_children():
			if child is Node3D and "Foliage" in child.name:
				foliage.append(child)
	if foliage.is_empty():
		return

	var local_direction := global_basis.inverse() * impact_direction.normalized()
	var tilt := Vector3(local_direction.z, 0.0, -local_direction.x) * deg_to_rad(6.0)
	var resting_rotations: Array[Vector3] = []
	for leaves in foliage:
		resting_rotations.append(leaves.rotation)

	_rustle_tween = create_tween()
	(
		_rustle_tween
		. tween_property(foliage[0], "rotation", resting_rotations[0] + tilt, 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	for index in range(1, foliage.size()):
		(
			_rustle_tween
			. parallel()
			. tween_property(foliage[index], "rotation", resting_rotations[index] + tilt, 0.08)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	(
		_rustle_tween
		. chain()
		. tween_property(foliage[0], "rotation", resting_rotations[0], 0.35)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	for index in range(1, foliage.size()):
		(
			_rustle_tween
			. parallel()
			. tween_property(foliage[index], "rotation", resting_rotations[index], 0.35)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)


func _apply_tree_type() -> void:
	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	for child in visuals.get_children():
		if child is Node3D:
			child.visible = false

	var active_node: Node3D = null
	match tree_type:
		TreeType.STANDARD:
			active_node = visuals.get_node_or_null("Standard")
		TreeType.TALL:
			active_node = visuals.get_node_or_null("Tall")
		TreeType.BROAD:
			active_node = visuals.get_node_or_null("Broad")
		TreeType.CLUSTERED:
			active_node = visuals.get_node_or_null("Clustered")
		TreeType.COMPACT:
			active_node = visuals.get_node_or_null("Compact")

	var height_scale := 1.0
	if tree_type == TreeType.BROAD:
		height_scale = 1.15
	elif tree_type == TreeType.COMPACT:
		height_scale = 1.25

	if active_node:
		active_node.scale.y = height_scale
		active_node.visible = true
	_update_dimensions()


func _update_dimensions() -> void:
	var col := (
		_collision_shape
		if _collision_shape
		else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	)
	if not col:
		return

	var radius: float = 0.35
	var height: float = 2.0
	var pos_y: float = 1.0

	match tree_type:
		TreeType.STANDARD:
			radius = 0.35
			height = 2.0
			pos_y = 1.0
		TreeType.TALL:
			radius = 0.32
			height = 2.6
			pos_y = 1.3
		TreeType.BROAD:
			radius = 0.38
			height = 2.07
			pos_y = 1.035
		TreeType.CLUSTERED:
			radius = 0.35
			height = 2.0
			pos_y = 1.0
		TreeType.COMPACT:
			radius = 0.30
			height = 2.0
			pos_y = 1.0

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = Vector3(0.0, pos_y, 0.0)
