@tool
class_name Dumpster
extends StaticBody3D

@export_enum("green", "blue", "brown") var dumpster_color: String = "green":
	set(value):
		dumpster_color = value
		_update_appearance()

@export var lid_open: bool = false:
	set(value):
		lid_open = value
		_update_appearance()

@onready var _body_mesh: MeshInstance3D = get_node_or_null("Body")
@onready var _right_lid_pivot: Node3D = get_node_or_null("RightLidPivot")
@onready var _trash_bag: MeshInstance3D = get_node_or_null("TrashBag")

const COLORS := {
	"green": Color(0.18, 0.36, 0.22, 1.0),
	"blue": Color(0.16, 0.32, 0.52, 1.0),
	"brown": Color(0.38, 0.26, 0.18, 1.0),
}


func _ready() -> void:
	_update_appearance()


func _update_appearance() -> void:
	var body: MeshInstance3D = _body_mesh if _body_mesh else get_node_or_null("Body")
	if body and COLORS.has(dumpster_color):
		var base_mat: StandardMaterial3D = body.material_override as StandardMaterial3D
		var mat: StandardMaterial3D = base_mat.duplicate() if base_mat else StandardMaterial3D.new()
		mat.albedo_color = COLORS[dumpster_color]
		body.material_override = mat
		for child_name in ["TopRim", "RibL", "RibM", "RibR"]:
			var part: MeshInstance3D = get_node_or_null(child_name)
			if part:
				part.material_override = mat
	var pivot: Node3D = _right_lid_pivot if _right_lid_pivot else get_node_or_null("RightLidPivot")
	if pivot:
		pivot.rotation.x = deg_to_rad(-42.0) if lid_open else 0.0

	var bag: MeshInstance3D = _trash_bag if _trash_bag else get_node_or_null("TrashBag")
	if bag:
		bag.visible = lid_open
