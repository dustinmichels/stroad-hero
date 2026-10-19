class_name PavementDetails
extends Node3D

const SURFACE_Y := 0.103
const CRACK_WIDTH := 0.025
const TIRE_WIDTH := 0.12
const TIRE_SPACING := 1.55

const CRACKS := [
	[Vector2(-67.2, -4.6), Vector2(-66.8, -4.3), Vector2(-66.9, -3.9), Vector2(-66.5, -3.6)],
	[Vector2(-51.4, 5.1), Vector2(-51.0, 4.8), Vector2(-50.7, 5.0), Vector2(-50.3, 4.6)],
	[Vector2(-31.6, -2.7), Vector2(-31.2, -2.4), Vector2(-31.3, -2.0), Vector2(-30.9, -1.7)],
	[Vector2(-14.8, 4.8), Vector2(-14.4, 4.5), Vector2(-14.1, 4.7), Vector2(-13.8, 4.3)],
	[Vector2(7.0, -5.4), Vector2(7.4, -5.1), Vector2(7.2, -4.7), Vector2(7.7, -4.4)],
	[Vector2(24.5, 2.8), Vector2(24.9, 2.5), Vector2(25.2, 2.7), Vector2(25.6, 2.3)],
	[Vector2(45.1, -3.6), Vector2(45.4, -3.2), Vector2(45.8, -3.3), Vector2(46.1, -2.9)],
	[Vector2(63.0, 5.8), Vector2(63.4, 5.5), Vector2(63.2, 5.1), Vector2(63.7, 4.8)],
	[Vector2(-18.8, -20.8), Vector2(-18.4, -20.5), Vector2(-18.1, -20.7), Vector2(-17.7, -20.3)],
	[Vector2(5.1, -17.8), Vector2(5.5, -17.5), Vector2(5.3, -17.1), Vector2(5.8, -16.9)],
	[Vector2(30.8, 20.1), Vector2(31.2, 20.4), Vector2(31.6, 20.2), Vector2(32.0, 20.6)],
	[Vector2(51.0, 26.5), Vector2(51.4, 26.2), Vector2(51.8, 26.4), Vector2(52.1, 26.0)],
]

const TIRE_MARKS := [
	[Vector2(-39.0, 5.6), Vector2(-36.0, 5.5)],
	[Vector2(-10.0, -5.6), Vector2(-6.8, -5.7)],
	[Vector2(34.0, 1.9), Vector2(37.2, 2.0)],
	[Vector2(59.0, -1.9), Vector2(62.0, -2.1)],
]


func _ready() -> void:
	if (
		has_node("PavementDetailMesh")
		or (get_parent() != null and get_parent().has_node("BakedStaticMesh"))
	):
		return
	build_mesh()


func build_mesh() -> MeshInstance3D:
	var existing := get_node_or_null("PavementDetailMesh") as MeshInstance3D
	if existing != null:
		return existing

	var mesh := ArrayMesh.new()
	_build_cracks(mesh)
	_build_tire_marks(mesh)

	var pavement_mesh := MeshInstance3D.new()
	pavement_mesh.name = "PavementDetailMesh"
	pavement_mesh.mesh = mesh
	pavement_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pavement_mesh)
	return pavement_mesh


func _build_cracks(mesh: ArrayMesh) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_detail_material(Color(0.025, 0.025, 0.03, 0.72), 0.92))
	for path in CRACKS:
		for index in range(path.size() - 1):
			_add_segment(surface, path[index], path[index + 1], CRACK_WIDTH)
	surface.commit(mesh)


func _build_tire_marks(mesh: ArrayMesh) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_detail_material(Color(0.045, 0.045, 0.05, 0.28), 0.58))
	for mark in TIRE_MARKS:
		var start: Vector2 = mark[0]
		var end: Vector2 = mark[1]
		var direction := (end - start).normalized()
		var side := Vector2(-direction.y, direction.x) * TIRE_SPACING * 0.5
		_add_segment(surface, start - side, end - side, TIRE_WIDTH)
		_add_segment(surface, start + side, end + side, TIRE_WIDTH)
	surface.commit(mesh)


func _detail_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


func _add_segment(surface: SurfaceTool, start: Vector2, end: Vector2, width: float) -> void:
	var direction := (end - start).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var a := Vector3(start.x - side.x, SURFACE_Y, start.y - side.y)
	var b := Vector3(start.x + side.x, SURFACE_Y, start.y + side.y)
	var c := Vector3(end.x + side.x, SURFACE_Y, end.y + side.y)
	var d := Vector3(end.x - side.x, SURFACE_Y, end.y - side.y)

	for vertex in [a, b, c, a, c, d]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
