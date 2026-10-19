class_name PavementDetails
extends Node3D

const SURFACE_Y := 0.103
const SIDEWALK_Y := 0.248
const CRACK_WIDTH := 0.025
const TIRE_WIDTH := 0.12
const TIRE_SPACING := 1.55

const WATER_VALVES: Array[Vector2] = [
	Vector2(3.0, 9.8),
	Vector2(-28.0, 9.8),
	Vector2(58.0, 9.8),
	Vector2(-15.0, -9.8),
	Vector2(32.0, -9.8),
	Vector2(72.0, -9.8),
]

const UTILITY_BOXES: Array[Vector2] = [
	Vector2(-22.0, 9.7),
	Vector2(12.0, 9.7),
	Vector2(-34.0, -9.7),
	Vector2(26.0, -9.7),
	Vector2(58.0, -9.7),
]

const STORM_DRAINS: Array[Vector3] = [
	Vector3(-32.0, SURFACE_Y, 7.28),
	Vector3(26.0, SURFACE_Y, 7.28),
	Vector3(-22.0, SURFACE_Y, -7.28),
	Vector3(36.0, SURFACE_Y, -7.28),
]
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
	var mesh := ArrayMesh.new()
	_build_cracks(mesh)
	_build_tire_marks(mesh)
	_build_water_valves(mesh)
	_build_utility_boxes(mesh)
	_build_storm_drains(mesh)

	var pavement_mesh := MeshInstance3D.new()
	pavement_mesh.name = "PavementDetailMesh"
	pavement_mesh.mesh = mesh
	pavement_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pavement_mesh)


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


func _build_water_valves(mesh: ArrayMesh) -> void:
	var surface_rim := SurfaceTool.new()
	surface_rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_rim.set_material(_cast_iron_material(Color(0.18, 0.19, 0.21), 0.65, 0.6))

	var surface_disc := SurfaceTool.new()
	surface_disc.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_disc.set_material(_cast_iron_material(Color(0.25, 0.26, 0.28), 0.50, 0.7))

	const SEGMENTS := 10
	const OUTER_R := 0.11
	const INNER_R := 0.085
	const NUT_R := 0.03

	for pos in WATER_VALVES:
		var center := Vector3(pos.x, SIDEWALK_Y, pos.y)
		for i in range(SEGMENTS):
			var a1 := float(i) * TAU / float(SEGMENTS)
			var a2 := float(i + 1) * TAU / float(SEGMENTS)
			var dir1 := Vector3(cos(a1), 0.0, sin(a1))
			var dir2 := Vector3(cos(a2), 0.0, sin(a2))

			# Outer rim ring
			var o1 := center + dir1 * OUTER_R
			var o2 := center + dir2 * OUTER_R
			var in1 := center + dir1 * INNER_R
			var in2 := center + dir2 * INNER_R
			surface_rim.set_normal(Vector3.UP)
			for v in [in1, o1, o2, in1, o2, in2]:
				surface_rim.add_vertex(v)

			# Inner lid disc
			surface_disc.set_normal(Vector3.UP)
			surface_disc.add_vertex(center)
			surface_disc.add_vertex(in2)
			surface_disc.add_vertex(in1)

		# Raised center bolt / operating nut (3 mm above disc to eliminate z-fighting)
		_add_rect_y(surface_rim, center, Vector2(NUT_R * 2.0, NUT_R * 2.0), SIDEWALK_Y + 0.003)
	surface_rim.commit(mesh)
	surface_disc.commit(mesh)


func _build_utility_boxes(mesh: ArrayMesh) -> void:
	var surface_frame := SurfaceTool.new()
	surface_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_frame.set_material(_cast_iron_material(Color(0.16, 0.17, 0.19), 0.65, 0.6))

	var surface_lid := SurfaceTool.new()
	surface_lid.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_lid.set_material(_cast_iron_material(Color(0.24, 0.25, 0.27), 0.50, 0.7))

	const SIZE := Vector2(0.42, 0.60)
	const BORDER := 0.035
	var inner_size := SIZE - Vector2(BORDER * 2.0, BORDER * 2.0)

	for pos in UTILITY_BOXES:
		var center := Vector3(pos.x, SIDEWALK_Y, pos.y)
		var hx := SIZE.x * 0.5
		var hz := SIZE.y * 0.5

		# 4 non-overlapping border strips around the lid (eliminates coplanar z-fighting)
		# Left & right frame borders
		_add_rect(
			surface_frame, center + Vector3(-hx + BORDER * 0.5, 0.0, 0.0), Vector2(BORDER, SIZE.y)
		)
		_add_rect(
			surface_frame, center + Vector3(hx - BORDER * 0.5, 0.0, 0.0), Vector2(BORDER, SIZE.y)
		)
		# Top & bottom frame borders (between left and right)
		var inner_w := SIZE.x - BORDER * 2.0
		_add_rect(
			surface_frame, center + Vector3(0.0, 0.0, -hz + BORDER * 0.5), Vector2(inner_w, BORDER)
		)
		_add_rect(
			surface_frame, center + Vector3(0.0, 0.0, hz - BORDER * 0.5), Vector2(inner_w, BORDER)
		)

		# Inner lid sits inside the frame without overlap
		_add_rect(surface_lid, center, inner_size)

		# Anti-skid grip ribs raised 3 mm above lid
		var rib_w := inner_size.x * 0.75
		var rib_y := SIDEWALK_Y + 0.003
		_add_segment_y(
			surface_frame,
			Vector2(pos.x - rib_w * 0.5, pos.y - 0.12),
			Vector2(pos.x + rib_w * 0.5, pos.y - 0.12),
			0.018,
			rib_y
		)
		_add_segment_y(
			surface_frame,
			Vector2(pos.x - rib_w * 0.5, pos.y),
			Vector2(pos.x + rib_w * 0.5, pos.y),
			0.018,
			rib_y
		)
		_add_segment_y(
			surface_frame,
			Vector2(pos.x - rib_w * 0.5, pos.y + 0.12),
			Vector2(pos.x + rib_w * 0.5, pos.y + 0.12),
			0.018,
			rib_y
		)
	surface_frame.commit(mesh)
	surface_lid.commit(mesh)


func _build_storm_drains(mesh: ArrayMesh) -> void:
	var surface_cavity := SurfaceTool.new()
	surface_cavity.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_cavity.set_material(_cavity_material())

	var surface_grate := SurfaceTool.new()
	surface_grate.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_grate.set_material(_cast_iron_material(Color(0.20, 0.21, 0.23), 0.55, 0.7))

	const GRATE_SIZE := Vector2(0.68, 0.42)
	const BAR_COUNT := 5

	const GRATE_LIFT := 0.004

	for drain in STORM_DRAINS:
		var center := Vector3(drain.x, drain.y, drain.z)
		# Dark recessed cavity beneath the grate
		_add_rect(surface_cavity, center, GRATE_SIZE)

		# Outer border rim raised 4 mm above cavity bottom
		var half_x := GRATE_SIZE.x * 0.5
		var half_z := GRATE_SIZE.y * 0.5
		const RIM := 0.03
		# Left & right frame borders
		_add_rect(
			surface_grate,
			center + Vector3(-half_x + RIM * 0.5, GRATE_LIFT, 0.0),
			Vector2(RIM, GRATE_SIZE.y)
		)
		_add_rect(
			surface_grate,
			center + Vector3(half_x - RIM * 0.5, GRATE_LIFT, 0.0),
			Vector2(RIM, GRATE_SIZE.y)
		)
		# Top & bottom frame borders
		var inner_drain_w := GRATE_SIZE.x - RIM * 2.0
		_add_rect(
			surface_grate,
			center + Vector3(0.0, GRATE_LIFT, -half_z + RIM * 0.5),
			Vector2(inner_drain_w, RIM)
		)
		_add_rect(
			surface_grate,
			center + Vector3(0.0, GRATE_LIFT, half_z - RIM * 0.5),
			Vector2(inner_drain_w, RIM)
		)

		# Slotted grate bars across gutter raised above cavity
		var bar_spacing := (GRATE_SIZE.x - RIM * 2.0) / float(BAR_COUNT + 1)
		for b in range(1, BAR_COUNT + 1):
			var bar_x := -half_x + RIM + float(b) * bar_spacing
			_add_rect(
				surface_grate,
				center + Vector3(bar_x, GRATE_LIFT, 0.0),
				Vector2(0.024, GRATE_SIZE.y - RIM * 2.0)
			)
	surface_cavity.commit(mesh)
	surface_grate.commit(mesh)


func _cast_iron_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 2
	return material


func _cavity_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.03, 0.04, 1.0)
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


func _add_rect(surface: SurfaceTool, center: Vector3, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var a := center + Vector3(-hx, 0.0, -hz)
	var b := center + Vector3(hx, 0.0, -hz)
	var c := center + Vector3(hx, 0.0, hz)
	var d := center + Vector3(-hx, 0.0, hz)

	surface.set_normal(Vector3.UP)
	for vertex in [a, c, b, a, d, c]:
		surface.add_vertex(vertex)


func _add_segment_y(
	surface: SurfaceTool, start: Vector2, end: Vector2, width: float, y_pos: float
) -> void:
	var direction := (end - start).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var a := Vector3(start.x - side.x, y_pos, start.y - side.y)
	var b := Vector3(start.x + side.x, y_pos, start.y + side.y)
	var c := Vector3(end.x + side.x, y_pos, end.y + side.y)
	var d := Vector3(end.x - side.x, y_pos, end.y - side.y)

	surface.set_normal(Vector3.UP)
	for vertex in [a, c, b, a, d, c]:
		surface.add_vertex(vertex)


func _add_rect_y(surface: SurfaceTool, center: Vector3, size: Vector2, y_pos: float) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var a := Vector3(center.x - hx, y_pos, center.z - hz)
	var b := Vector3(center.x + hx, y_pos, center.z - hz)
	var c := Vector3(center.x + hx, y_pos, center.z + hz)
	var d := Vector3(center.x - hx, y_pos, center.z + hz)

	surface.set_normal(Vector3.UP)
	for vertex in [a, c, b, a, d, c]:
		surface.add_vertex(vertex)
