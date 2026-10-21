@tool
class_name ChainlinkFence
extends StaticBody3D

enum Mode { PERIMETER, SINGLE_SECTION, POLYLINE }

@export var mode: Mode = Mode.PERIMETER:
	set(value):
		mode = value
		if is_inside_tree():
			build_fence()

@export var fence_height := 2.2:
	set(value):
		fence_height = value
		if is_inside_tree():
			build_fence()

@export var post_spacing := 3.0:
	set(value):
		post_spacing = value
		if is_inside_tree():
			build_fence()

@export var post_radius := 0.038:
	set(value):
		post_radius = value
		if is_inside_tree():
			build_fence()

@export var corner_post_radius := 0.055:
	set(value):
		corner_post_radius = value
		if is_inside_tree():
			build_fence()

@export var rail_radius := 0.022:
	set(value):
		rail_radius = value
		if is_inside_tree():
			build_fence()

## Distance (meters) from camera beyond which fence geometry is culled.
@export var visibility_distance := 60.0:
	set(value):
		visibility_distance = value
		if is_inside_tree():
			build_fence()

## Margin (meters) over which fence geometry smoothly fades in/out.
@export var visibility_fade_margin := 15.0:
	set(value):
		visibility_fade_margin = value
		if is_inside_tree():
			build_fence()

## Chunk size (meters) for spatial culling of fence sections.
@export var chunk_length := 18.0:
	set(value):
		chunk_length = value
		if is_inside_tree():
			build_fence()

@export var bounds_min := Vector2(-135.0, -105.0):
	set(value):
		bounds_min = value
		if is_inside_tree():
			build_fence()

@export var bounds_max := Vector2(225.0, 135.0):
	set(value):
		bounds_max = value
		if is_inside_tree():
			build_fence()

@export var single_section_length := 4.0:
	set(value):
		single_section_length = value
		if is_inside_tree():
			build_fence()

@export var polyline_points: PackedVector3Array = PackedVector3Array():
	set(value):
		polyline_points = value
		if is_inside_tree():
			build_fence()

const SHADER_RES_PATH := "res://shaders/chainlink.gdshader"

var _is_built := false
var _steel_mat: StandardMaterial3D
var _chainlink_mat: ShaderMaterial


func _ready() -> void:
	_init_materials()
	build_fence()


func _init_materials() -> void:
	if _steel_mat == null:
		_steel_mat = StandardMaterial3D.new()
		_steel_mat.albedo_color = Color(0.70, 0.73, 0.76)
		_steel_mat.metallic = 0.88
		_steel_mat.roughness = 0.32

	if _chainlink_mat == null:
		_chainlink_mat = ShaderMaterial.new()
		var shader := load(SHADER_RES_PATH) as Shader
		if shader:
			_chainlink_mat.shader = shader

	if _chainlink_mat:
		_chainlink_mat.set_shader_parameter(
			"fade_distance_start", maxf(0.0, visibility_distance - visibility_fade_margin)
		)
		_chainlink_mat.set_shader_parameter("fade_distance_end", visibility_distance)


func _apply_visibility(geo: GeometryInstance3D) -> void:
	if visibility_distance > 0.0:
		geo.visibility_range_end = visibility_distance
		geo.visibility_range_end_margin = visibility_fade_margin
		geo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func build_fence() -> void:
	_init_materials()

	# Remove existing generated children
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if mode == Mode.PERIMETER:
		_build_perimeter()
	elif mode == Mode.SINGLE_SECTION:
		_build_single_section()
	elif mode == Mode.POLYLINE:
		_build_polyline()

	_is_built = true


func _build_perimeter() -> void:
	var x_min: float = bounds_min.x
	var z_min: float = bounds_min.y
	var x_max: float = bounds_max.x
	var z_max: float = bounds_max.y

	# Corners clockwise from Northwest:
	# NW: (x_min, z_min), NE: (x_max, z_min), SE: (x_max, z_max), SW: (x_min, z_max)
	var corners: Array[Vector3] = [
		Vector3(x_min, 0.0, z_min),
		Vector3(x_max, 0.0, z_min),
		Vector3(x_max, 0.0, z_max),
		Vector3(x_min, 0.0, z_max)
	]

	var corner_names := ["CornerPost_NW", "CornerPost_NE", "CornerPost_SE", "CornerPost_SW"]
	for i in range(4):
		_create_corner_post(corners[i], corner_names[i])

	# 4 Sides chunked into localized sections for efficient distance visibility culling
	var side_names := ["North", "East", "South", "West"]
	for i in range(4):
		var p1 := corners[i]
		var p2 := corners[(i + 1) % 4]
		_build_side(p1, p2, side_names[i])

	# Build solid collision boundaries along all 4 perimeter sides
	_build_perimeter_collisions(x_min, x_max, z_min, z_max)


func _build_side(p1: Vector3, p2: Vector3, side_name: String) -> void:
	var diff := p2 - p1
	var total_len := diff.length()
	if total_len < 0.01:
		return

	var dir := diff.normalized()
	var normal := Vector3.UP.cross(dir)
	var num_chunks := int(ceil(total_len / chunk_length))
	var chunk_step := total_len / float(num_chunks)

	var side_node := Node3D.new()
	side_node.name = "Side_" + side_name
	add_child(side_node)

	var top_rail_y := fence_height + 0.02
	var bottom_wire_y := 0.07

	for c in range(num_chunks):
		var cp1 := p1 + dir * (float(c) * chunk_step)
		var cp2 := p1 + dir * (float(c + 1) * chunk_step)
		var this_chunk_len := (cp2 - cp1).length()

		var chunk_node := Node3D.new()
		chunk_node.name = "Chunk_%d" % c
		side_node.add_child(chunk_node)

		# 1. Top Rail
		var top_rail := _create_pipe(
			cp1 + Vector3(0, top_rail_y, 0), cp2 + Vector3(0, top_rail_y, 0), rail_radius
		)
		top_rail.name = "TopRail"
		chunk_node.add_child(top_rail)

		# 2. Bottom Tension Wire
		var bottom_wire := _create_pipe(
			cp1 + Vector3(0, bottom_wire_y, 0),
			cp2 + Vector3(0, bottom_wire_y, 0),
			rail_radius * 0.35
		)
		bottom_wire.name = "BottomWire"
		chunk_node.add_child(bottom_wire)

		# 3. Chainlink Fabric Quad
		var fabric_mesh := _create_fabric_quad(
			cp1, cp2, bottom_wire_y, top_rail_y, this_chunk_len, normal
		)
		var fabric_instance := MeshInstance3D.new()
		fabric_instance.name = "Fabric"
		fabric_instance.mesh = fabric_mesh
		fabric_instance.material_override = _chainlink_mat
		fabric_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_visibility(fabric_instance)
		chunk_node.add_child(fabric_instance)

		# 4. Line posts for this chunk
		var post_transforms: Array[Transform3D] = []
		var post_height := fence_height + 0.12
		var chunk_start_dist := float(c) * chunk_step
		var chunk_end_dist := float(c + 1) * chunk_step

		var first_post_idx := int(floor(chunk_start_dist / post_spacing)) + 1
		var last_post_idx := int(floor((chunk_end_dist - 0.01) / post_spacing))

		for idx in range(first_post_idx, last_post_idx + 1):
			var dist_along := float(idx) * post_spacing
			if dist_along >= total_len - 0.01:
				break
			var post_pos := p1 + dir * dist_along
			var t := Transform3D()
			t.origin = post_pos + Vector3(0.0, post_height * 0.5, 0.0)
			post_transforms.append(t)

		if not post_transforms.is_empty():
			_create_chunk_multimesh_posts(chunk_node, post_transforms)


func _build_single_section() -> void:
	var half_len := single_section_length * 0.5
	var p1 := Vector3(-half_len, 0.0, 0.0)
	var p2 := Vector3(half_len, 0.0, 0.0)

	_create_corner_post(p1, "CornerPost_Left")
	_create_corner_post(p2, "CornerPost_Right")

	var top_rail_y := fence_height + 0.02
	var bottom_wire_y := 0.07

	var top_rail := _create_pipe(
		p1 + Vector3(0, top_rail_y, 0), p2 + Vector3(0, top_rail_y, 0), rail_radius
	)
	top_rail.name = "TopRail"
	add_child(top_rail)

	var bottom_wire := _create_pipe(
		p1 + Vector3(0, bottom_wire_y, 0), p2 + Vector3(0, bottom_wire_y, 0), rail_radius * 0.35
	)
	bottom_wire.name = "BottomWire"
	add_child(bottom_wire)

	var fabric_mesh := _create_fabric_quad(
		p1, p2, bottom_wire_y, top_rail_y, single_section_length, Vector3.FORWARD
	)
	var fabric_instance := MeshInstance3D.new()
	fabric_instance.name = "Fabric"
	fabric_instance.mesh = fabric_mesh
	fabric_instance.material_override = _chainlink_mat
	fabric_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_visibility(fabric_instance)
	add_child(fabric_instance)

	# Single section collision
	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionSection"
	var box := BoxShape3D.new()
	box.size = Vector3(single_section_length, fence_height + 0.8, 0.3)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, (fence_height + 0.8) * 0.5, 0.0)
	add_child(col_shape)


func _build_polyline() -> void:
	if polyline_points.size() < 2:
		return

	for i in range(polyline_points.size()):
		_create_corner_post(polyline_points[i], "CornerPost_%d" % i)

	for i in range(polyline_points.size() - 1):
		var p1 := polyline_points[i]
		var p2 := polyline_points[i + 1]
		_build_side(p1, p2, "Seg_%d" % i)
		_build_segment_collision(p1, p2, "Collision_%d" % i)


func _build_segment_collision(p1: Vector3, p2: Vector3, col_name: String) -> void:
	var diff := p2 - p1
	var length := diff.length()
	if length < 0.01:
		return

	var wall_h := fence_height + 0.8
	var thickness := 0.4
	var mid := (p1 + p2) * 0.5 + Vector3(0.0, wall_h * 0.5, 0.0)

	var col_shape := CollisionShape3D.new()
	col_shape.name = col_name
	var box := BoxShape3D.new()
	box.size = Vector3(length, wall_h, thickness)
	col_shape.shape = box
	col_shape.position = mid
	col_shape.rotation.y = -atan2(diff.z, diff.x)
	add_child(col_shape)


func _create_corner_post(pos: Vector3, node_name: String = "CornerPost") -> void:
	var post_h := fence_height + 0.22
	var post_node := Node3D.new()
	post_node.name = node_name
	post_node.position = pos

	# Vertical pipe
	var post_mesh := CylinderMesh.new()
	post_mesh.material = _steel_mat
	post_mesh.top_radius = corner_post_radius
	post_mesh.bottom_radius = corner_post_radius
	post_mesh.height = post_h
	post_mesh.radial_segments = 12

	var mi := MeshInstance3D.new()
	mi.name = "Post"
	mi.mesh = post_mesh
	mi.position = Vector3(0.0, post_h * 0.5, 0.0)
	_apply_visibility(mi)
	post_node.add_child(mi)

	# Acorn/Dome Cap
	var cap_mesh := SphereMesh.new()
	cap_mesh.material = _steel_mat
	cap_mesh.radius = corner_post_radius * 1.15
	cap_mesh.height = corner_post_radius * 1.5
	cap_mesh.radial_segments = 12
	cap_mesh.rings = 6

	var cap_mi := MeshInstance3D.new()
	cap_mi.name = "Cap"
	cap_mi.mesh = cap_mesh
	cap_mi.position = Vector3(0.0, post_h, 0.0)
	_apply_visibility(cap_mi)
	post_node.add_child(cap_mi)

	# Tension bands around corner post
	for band_y in [0.25, fence_height * 0.5, fence_height * 0.85, fence_height + 0.02]:
		var band := CylinderMesh.new()
		band.material = _steel_mat
		band.top_radius = corner_post_radius * 1.12
		band.bottom_radius = corner_post_radius * 1.12
		band.height = 0.04
		band.radial_segments = 12

		var band_mi := MeshInstance3D.new()
		band_mi.mesh = band
		band_mi.position = Vector3(0.0, band_y, 0.0)
		_apply_visibility(band_mi)
		post_node.add_child(band_mi)

	add_child(post_node)


func _create_chunk_multimesh_posts(parent: Node3D, transforms: Array[Transform3D]) -> void:
	var post_h := fence_height + 0.12

	# 1. Post Cylinders
	var post_mesh := CylinderMesh.new()
	post_mesh.material = _steel_mat
	post_mesh.top_radius = post_radius
	post_mesh.bottom_radius = post_radius
	post_mesh.height = post_h
	post_mesh.radial_segments = 10

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = post_mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LinePosts"
	mmi.multimesh = multimesh
	_apply_visibility(mmi)
	parent.add_child(mmi)

	# 2. Post Caps
	var cap_mesh := SphereMesh.new()
	cap_mesh.material = _steel_mat
	cap_mesh.radius = post_radius * 1.15
	cap_mesh.height = post_radius * 1.3
	cap_mesh.radial_segments = 10
	cap_mesh.rings = 5

	var cap_multimesh := MultiMesh.new()
	cap_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cap_multimesh.mesh = cap_mesh
	cap_multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		var cap_transform := transforms[i]
		cap_transform.origin.y += post_h * 0.5
		cap_multimesh.set_instance_transform(i, cap_transform)

	var cap_mmi := MultiMeshInstance3D.new()
	cap_mmi.name = "PostCaps"
	cap_mmi.multimesh = cap_multimesh
	_apply_visibility(cap_mmi)
	parent.add_child(cap_mmi)


func _create_pipe(from_pos: Vector3, to_pos: Vector3, radius: float) -> MeshInstance3D:
	var diff := to_pos - from_pos
	var length := diff.length()
	var center := (from_pos + to_pos) * 0.5

	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.material = _steel_mat
	pipe_mesh.top_radius = radius
	pipe_mesh.bottom_radius = radius
	pipe_mesh.height = length
	pipe_mesh.radial_segments = 10

	var mi := MeshInstance3D.new()
	mi.mesh = pipe_mesh
	mi.position = center
	_apply_visibility(mi)

	var dir := diff.normalized()
	if not dir.is_equal_approx(Vector3.UP) and not dir.is_equal_approx(Vector3.DOWN):
		var axis := Vector3.UP.cross(dir).normalized()
		var angle := Vector3.UP.angle_to(dir)
		mi.basis = Basis(axis, angle)

	return mi


func _create_fabric_quad(
	p1: Vector3, p2: Vector3, y_bottom: float, y_top: float, length: float, normal: Vector3
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var v0 := Vector3(p1.x, y_bottom, p1.z)
	var v1 := Vector3(p2.x, y_bottom, p2.z)
	var v2 := Vector3(p2.x, y_top, p2.z)
	var v3 := Vector3(p1.x, y_top, p1.z)

	var tangent_dir := (p2 - p1).normalized()
	var tangent := Plane(tangent_dir.x, tangent_dir.y, tangent_dir.z, 1.0)

	# Tri 1: v0 -> v1 -> v2
	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(0.0, y_bottom))
	st.add_vertex(v0)

	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(length, y_bottom))
	st.add_vertex(v1)

	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(length, y_top))
	st.add_vertex(v2)

	# Tri 2: v0 -> v2 -> v3
	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(0.0, y_bottom))
	st.add_vertex(v0)

	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(length, y_top))
	st.add_vertex(v2)

	st.set_normal(normal)
	st.set_tangent(tangent)
	st.set_uv(Vector2(0.0, y_top))
	st.add_vertex(v3)

	return st.commit()


func _build_perimeter_collisions(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var wall_h := fence_height + 0.8
	var thickness := 0.4
	var y_pos := wall_h * 0.5

	var x_len := x_max - x_min
	var z_len := z_max - z_min
	var x_mid := (x_min + x_max) * 0.5
	var z_mid := (z_min + z_max) * 0.5

	# North wall (at z_min)
	_add_collision_box(
		"CollisionNorth",
		Vector3(x_mid, y_pos, z_min),
		Vector3(x_len + thickness, wall_h, thickness)
	)

	# South wall (at z_max)
	_add_collision_box(
		"CollisionSouth",
		Vector3(x_mid, y_pos, z_max),
		Vector3(x_len + thickness, wall_h, thickness)
	)

	# West wall (at x_min)
	_add_collision_box(
		"CollisionWest", Vector3(x_min, y_pos, z_mid), Vector3(thickness, wall_h, z_len + thickness)
	)

	# East wall (at x_max)
	_add_collision_box(
		"CollisionEast", Vector3(x_max, y_pos, z_mid), Vector3(thickness, wall_h, z_len + thickness)
	)


func _add_collision_box(node_name: String, center: Vector3, size: Vector3) -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = node_name
	var box := BoxShape3D.new()
	box.size = size
	col_shape.shape = box
	col_shape.position = center
	add_child(col_shape)
