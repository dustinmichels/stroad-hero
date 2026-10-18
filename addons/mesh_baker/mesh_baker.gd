class_name MeshBaker
extends RefCounted

const PAINTED_NODE_NAMES: Array[StringName] = [
	&"Body",
	&"Hood",
	&"FrontBumper",
	&"RearBumper",
	&"Trunk",
	&"Roof",
	&"RoofSpoiler",
	&"SlopingNose",
	&"BedWallL",
	&"BedWallR",
	&"Tailgate",
	&"FlareRL",
	&"FlareRR",
	&"SpoilerWing",
	&"FastbackL",
	&"FastbackR",
	&"APillarL",
	&"APillarR",
	&"CPillarL",
	&"CPillarR",
	&"DPillarL",
	&"DPillarR",
	&"MirrorHousingL",
	&"MirrorHousingR",
]

const LIGHT_MARKER_NAMES: Array[StringName] = [
	&"HeadlightL",
	&"HeadlightR",
	&"TaillightL",
	&"TaillightR",
]


static func get_relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr := node
	while curr != null and curr != root:
		xform = curr.transform * xform
		curr = curr.get_parent() as Node3D
	return xform


static func get_surface_material(mi: MeshInstance3D, surf_idx: int) -> Material:
	var active_mat := mi.get_active_material(surf_idx)
	if active_mat != null:
		return active_mat
	if mi.material_override != null:
		return mi.material_override
	var surf_mat := mi.get_surface_override_material(surf_idx)
	if surf_mat != null:
		return surf_mat
	if mi.mesh != null:
		return mi.mesh.surface_get_material(surf_idx)
	return null


static func bake_car_body(root: Node3D) -> Node3D:
	var painted_items: Array[Dictionary] = []
	var trim_by_material: Dictionary = {}
	var light_markers_data: Array[Dictionary] = []
	var to_remove: Array[Node] = []

	for child in root.get_children():
		var child_name: StringName = child.name
		# Keep wheels completely untouched so rotation and wheel scripts work unmodified
		if child_name.begins_with("Wheel"):
			continue

		if child_name in LIGHT_MARKER_NAMES:
			light_markers_data.append({"name": child_name, "transform": child.transform})

		if child is MeshInstance3D and child.mesh:
			var xform := get_relative_transform(child, root)
			var is_painted := child_name in PassengerCar.PAINTED_NODE_NAMES

			for s in range(child.mesh.get_surface_count()):
				var mat := get_surface_material(child, s)
				var entry := {
					"mesh": child.mesh,
					"surface": s,
					"transform": xform,
					"material": mat,
				}
				if is_painted:
					painted_items.append(entry)
				else:
					if not trim_by_material.has(mat):
						trim_by_material[mat] = []
					trim_by_material[mat].append(entry)

		to_remove.append(child)

	for node in to_remove:
		root.remove_child(node)
		node.free()

	# 1. Baked Body (painted parts merged into 1 mesh, 1 surface)
	if not painted_items.is_empty():
		var body_st := SurfaceTool.new()
		body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var body_mat: Material = painted_items[0]["material"]
		if body_mat:
			body_st.set_material(body_mat)
		for item in painted_items:
			body_st.append_from(item["mesh"], item["surface"], item["transform"])
		var body_mesh := body_st.commit()

		var body_mi := MeshInstance3D.new()
		body_mi.name = "Body"
		body_mi.mesh = body_mesh
		root.add_child(body_mi)
		body_mi.owner = root

	# 2. Baked Trim (all other static body parts grouped by material)
	if not trim_by_material.is_empty():
		var trim_mesh := ArrayMesh.new()
		for mat in trim_by_material.keys():
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if mat:
				st.set_material(mat)
			for item in trim_by_material[mat]:
				st.append_from(item["mesh"], item["surface"], item["transform"])
			st.commit(trim_mesh)

		var trim_mi := MeshInstance3D.new()
		trim_mi.name = "Trim"
		trim_mi.mesh = trim_mesh
		root.add_child(trim_mi)
		trim_mi.owner = root

	# 3. Light markers (preserves positions for turn signal spawns)
	for data in light_markers_data:
		var marker := Marker3D.new()
		marker.name = data["name"]
		marker.transform = data["transform"]
		root.add_child(marker)
		marker.owner = root

	return root


static func bake_static_scene(root: Node3D) -> Node3D:
	var mesh_instances: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		for child in curr.get_children():
			# Do not traverse into instanced sub-scenes (they are baked on their own)
			if child.scene_file_path != "":
				continue
			if child.owner != root and child.owner != null:
				continue
			# Do not merge nodes that have attached scripts or are collision shapes
			if child.get_script() != null:
				continue
			if child is CollisionShape3D or child is CollisionPolygon3D:
				continue
			if child is MeshInstance3D and child.mesh != null:
				mesh_instances.append(child)
			stack.append(child)
	if mesh_instances.is_empty():
		return root

	var by_mat: Dictionary = {}
	for mi in mesh_instances:
		var xform := get_relative_transform(mi, root)
		for s in range(mi.mesh.get_surface_count()):
			var mat := get_surface_material(mi, s)
			if not by_mat.has(mat):
				by_mat[mat] = []
			(
				by_mat[mat]
				. append(
					{
						"mesh": mi.mesh,
						"surface": s,
						"transform": xform,
					}
				)
			)

	var merged_mesh := ArrayMesh.new()
	for mat in by_mat.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if mat:
			st.set_material(mat)
		for item in by_mat[mat]:
			st.append_from(item["mesh"], item["surface"], item["transform"])
		st.commit(merged_mesh)

	# Nullify original meshes so they don't render or take draw calls
	for mi in mesh_instances:
		mi.mesh = null
		if mi.get_child_count() == 0:
			var parent := mi.get_parent()
			if parent != null:
				parent.remove_child(mi)
				mi.free()
	var merged_mi := MeshInstance3D.new()
	merged_mi.name = "BakedStaticMesh"
	merged_mi.mesh = merged_mesh
	root.add_child(merged_mi)
	merged_mi.owner = root

	return root
