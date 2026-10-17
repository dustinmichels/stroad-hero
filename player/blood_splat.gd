class_name BloodSplat
extends Node3D

@export var base_radius: float = 0.85
@export var perimeter_points: int = 36


static func spawn(
	at_world_pos: Vector3, parent_node: Node, exclude_rids: Array[RID] = []
) -> Node3D:
	var splat_script: GDScript = load("res://player/blood_splat.gd")
	var splat: Node3D = splat_script.new()
	parent_node.add_child(splat)

	# Raycast to find the ground height and normal
	var space_state := splat.get_world_3d().direct_space_state
	var ray_from := at_world_pos + Vector3.UP * 1.5
	var ray_to := at_world_pos + Vector3.DOWN * 4.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	if not exclude_rids.is_empty():
		query.exclude = exclude_rids
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		splat.global_position = result.position + result.normal * 0.006
		# If normal is roughly UP, keep flat on XZ plane
		if result.normal.dot(Vector3.UP) < 0.99 and result.normal.length_squared() > 0.1:
			var axis := Vector3.UP.cross(result.normal).normalized()
			var angle := Vector3.UP.angle_to(result.normal)
			splat.basis = Basis(axis, angle)
	else:
		splat.global_position = Vector3(at_world_pos.x, 0.11, at_world_pos.z)

	splat.rotation.y = randf() * TAU
	splat._generate_mesh()
	return splat


func _generate_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55 + randf_range(-0.06, 0.04), 0.02, 0.03, 0.95)
	mat.roughness = 0.15  # wet gloss
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 1
	st.set_material(mat)

	var radius := base_radius * randf_range(0.85, 1.25)
	var angles: Array[float] = []
	var radii: Array[float] = []

	var p1 := randf() * TAU
	var p2 := randf() * TAU
	var p3 := randf() * TAU

	# Pick 2-4 angles for splatter streaks
	var streak_angles: Array[float] = []
	for s in range(randi_range(2, 4)):
		streak_angles.append(randf() * TAU)

	for i in range(perimeter_points):
		var theta := (float(i) / float(perimeter_points)) * TAU
		angles.append(theta)

		# Base circular shape with smooth low-frequency wobble
		var r := (
			radius
			* (
				1.0
				+ 0.14 * sin(2.0 * theta + p1)
				+ 0.10 * sin(3.0 * theta + p2)
				+ 0.06 * cos(5.0 * theta + p3)
			)
		)
		# Subtle noise
		r += randf_range(-0.05, 0.05) * radius

		# Splatter streak protrusions
		for sa in streak_angles:
			var diff := absf(fposmod(theta - sa + PI, TAU) - PI)
			if diff < 0.28:
				var factor := 1.0 - (diff / 0.28)
				r += factor * randf_range(0.2, 0.45) * radius

		radii.append(r)

	# Build the circular fan
	var center := Vector3.ZERO
	for i in range(perimeter_points):
		var next := (i + 1) % perimeter_points
		var p_curr := Vector3(cos(angles[i]) * radii[i], 0.0, sin(angles[i]) * radii[i])
		var p_next := Vector3(cos(angles[next]) * radii[next], 0.0, sin(angles[next]) * radii[next])

		st.set_normal(Vector3.UP)
		st.add_vertex(center)
		st.set_normal(Vector3.UP)
		st.add_vertex(p_curr)
		st.set_normal(Vector3.UP)
		st.add_vertex(p_next)

	# Add satellite splatter droplets
	var num_droplets := randi_range(4, 7)
	for d in range(num_droplets):
		var da := randf() * TAU
		var dd := radius * randf_range(1.2, 2.1)
		var dc := Vector3(cos(da) * dd, 0.0, sin(da) * dd)
		var dr := randf_range(0.04, 0.12)
		var drop_pts := 10
		for j in range(drop_pts):
			var a1 := (float(j) / float(drop_pts)) * TAU
			var a2 := (float(j + 1) / float(drop_pts)) * TAU
			var pt1 := dc + Vector3(cos(a1) * dr, 0.0, sin(a1) * dr)
			var pt2 := dc + Vector3(cos(a2) * dr, 0.0, sin(a2) * dr)
			st.set_normal(Vector3.UP)
			st.add_vertex(dc)
			st.set_normal(Vector3.UP)
			st.add_vertex(pt1)
			st.set_normal(Vector3.UP)
			st.add_vertex(pt2)

	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)
