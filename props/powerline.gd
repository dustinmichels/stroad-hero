@tool
class_name Powerline
extends StaticBody3D

@export var has_wires: bool = true:
	set(value):
		has_wires = value
		_update_wires()

@export var target_pole: NodePath:
	set(value):
		target_pole = value
		_update_wires()

@export var span_distance: float = 32.0:
	set(value):
		span_distance = value
		_update_wires()

@export var wire_sag: float = 0.55:
	set(value):
		wire_sag = value
		_update_wires()

@export var has_transformer: bool = false:
	set(value):
		has_transformer = value
		_update_transformer()

const WIRE_ATTACHMENTS: Array[Dictionary] = [
	{
		"offset": Vector3(0.0, 9.70, -1.05),
		"sag": 1.0,
		"radius": 0.016,
	},
	{
		"offset": Vector3(0.0, 10.27, 0.0),
		"sag": 0.95,
		"radius": 0.016,
	},
	{
		"offset": Vector3(0.0, 9.70, 1.05),
		"sag": 1.0,
		"radius": 0.016,
	},
	{
		"offset": Vector3(0.0, 8.33, -0.65),
		"sag": 1.05,
		"radius": 0.014,
	},
	{
		"offset": Vector3(0.0, 8.33, 0.65),
		"sag": 1.05,
		"radius": 0.014,
	},
	{
		"offset": Vector3(0.0, 6.0, 0.22),
		"sag": 1.35,
		"radius": 0.022,
	},
]

@onready var _transformer_node: Node3D = get_node_or_null("Visuals/Transformer")
@onready var _wire_mesh_instance: MeshInstance3D = get_node_or_null("WireMesh")


func _ready() -> void:
	_update_transformer()
	_update_wires()
	call_deferred(&"_update_wires")


func _update_transformer() -> void:
	var t_node := (
		_transformer_node
		if _transformer_node
		else (get_node_or_null("Visuals/Transformer") as Node3D)
	)
	if t_node:
		t_node.visible = has_transformer


func _resolve_target() -> Node3D:
	if not target_pole.is_empty():
		return get_node_or_null(target_pole) as Node3D

	var parent := get_parent()
	if parent != null:
		var my_idx := get_index()
		for i in range(my_idx + 1, parent.get_child_count()):
			var sibling := parent.get_child(i)
			if _is_pole_node(sibling):
				return sibling as Node3D

	return null


func _has_preceding_pole() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var my_idx := get_index()
	for i in range(my_idx):
		var sibling := parent.get_child(i)
		if _is_pole_node(sibling):
			return true
	return false


func _is_pole_node(node: Node) -> bool:
	if node == self:
		return false
	if node is Powerline:
		return true
	if (
		node is StaticBody3D
		and (node.name.begins_with("Powerline") or node.name.begins_with("Pole"))
	):
		return true
	return false


func _update_wires() -> void:
	var wire_mi := (
		_wire_mesh_instance
		if _wire_mesh_instance
		else (get_node_or_null("WireMesh") as MeshInstance3D)
	)
	if wire_mi == null:
		return

	if not has_wires:
		wire_mi.visible = false
		wire_mi.mesh = null
		return

	var target_node := _resolve_target()

	# If this is the terminal pole in a chain, do not span dangling wires forward
	if target_node == null and target_pole.is_empty() and _has_preceding_pole():
		wire_mi.visible = false
		wire_mi.mesh = null
		return

	wire_mi.visible = true
	wire_mi.mesh = build_wire_mesh(target_node)


func build_wire_mesh(target_node: Node3D = null) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
	mat.roughness = 0.8
	mat.metallic = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(mat)

	for entry in WIRE_ATTACHMENTS:
		var pt_a: Vector3 = entry["offset"]
		var radius: float = entry["radius"]
		var sag: float = wire_sag * entry["sag"]
		var pt_b: Vector3
		if target_node != null and is_instance_valid(target_node):
			var rel_transform: Transform3D
			if get_parent() != null and get_parent() == target_node.get_parent():
				rel_transform = transform.affine_inverse() * target_node.transform
			elif is_inside_tree() and target_node.is_inside_tree():
				rel_transform = global_transform.affine_inverse() * target_node.global_transform
			else:
				rel_transform = transform.affine_inverse() * target_node.transform
			pt_b = rel_transform * (entry["offset"] as Vector3)
		else:
			pt_b = pt_a + Vector3(span_distance, 0.0, 0.0)

		var wire_len := (pt_b - pt_a).length()
		if wire_len < 0.2:
			continue

		var seg_count := maxi(8, int(wire_len / 2.0))
		var pts: Array[Vector3] = []
		for i in range(seg_count + 1):
			var t := float(i) / float(seg_count)
			var p := pt_a.lerp(pt_b, t)
			p.y -= 4.0 * sag * t * (1.0 - t)
			pts.append(p)

		for i in range(seg_count):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var dir := (p1 - p0).normalized()

			var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
			var norm := dir.cross(up).normalized()
			var binorm := dir.cross(norm).normalized()

			var n0 := norm * radius
			var b0 := binorm * radius
			var n1 := norm * radius
			var b1 := binorm * radius

			var p0_left := p0 - n0
			var p0_right := p0 + n0
			var p1_left := p1 - n1
			var p1_right := p1 + n1

			var p0_up := p0 + b0
			var p0_down := p0 - b0
			var p1_up := p1 + b1
			var p1_down := p1 - b1

			# Ribbon 1 (normal)
			surface.set_normal(binorm)
			surface.add_vertex(p0_left)
			surface.add_vertex(p0_right)
			surface.add_vertex(p1_right)
			surface.add_vertex(p0_left)
			surface.add_vertex(p1_right)
			surface.add_vertex(p1_left)

			# Ribbon 2 (binormal)
			surface.set_normal(norm)
			surface.add_vertex(p0_up)
			surface.add_vertex(p0_down)
			surface.add_vertex(p1_down)
			surface.add_vertex(p0_up)
			surface.add_vertex(p1_down)
			surface.add_vertex(p1_up)

	var mesh := ArrayMesh.new()
	surface.commit(mesh)
	return mesh
