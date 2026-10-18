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


static func bake_static_scene(root: Node3D, scene_root: Node = null) -> Node3D:
	var actual_owner: Node = scene_root if scene_root != null else root
	var mesh_instances: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		for child in curr.get_children():
			# Do not traverse into instanced sub-scenes (they are baked on their own)
			if child.scene_file_path != "":
				continue
			if child.owner != null and child.owner != root and root.is_ancestor_of(child.owner):
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
	merged_mi.owner = actual_owner
	return root


static func create_multimesh_from_instances(
	container: Node3D, template_mesh: Mesh, scene_root: Node = null
) -> MultiMeshInstance3D:
	var actual_owner: Node = scene_root if scene_root != null else container
	var instances: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D and not (child is MultiMeshInstance3D):
			instances.append(child as Node3D)
	if instances.is_empty() or template_mesh == null:
		return null

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = template_mesh
	mm.instance_count = instances.size()

	for i in range(instances.size()):
		var inst := instances[i]
		mm.set_instance_transform(i, inst.transform)
		var to_remove: Array[Node] = []
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var curr: Node = stack.pop_back()
			for child in curr.get_children():
				if child is MeshInstance3D:
					to_remove.append(child)
				else:
					stack.append(child)
		for mi in to_remove:
			var p := mi.get_parent()
			if p != null:
				p.remove_child(mi)
			mi.free()
		inst.scene_file_path = ""
		inst.owner = actual_owner
		var remaining_stack: Array[Node] = [inst]
		while not remaining_stack.is_empty():
			var n: Node = remaining_stack.pop_back()
			n.owner = actual_owner
			for c: Node in n.get_children():
				remaining_stack.append(c)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BakedMultiMesh"
	mmi.multimesh = mm
	container.add_child(mmi)
	mmi.owner = actual_owner
	return mmi


static func bake_main_scene(root: Node3D) -> Node3D:
	var road := root.get_node_or_null("Road") as Node3D
	if road != null:
		bake_static_scene(road, root)

	var parking := root.get_node_or_null("Parking") as Node3D
	if parking != null:
		bake_static_scene(parking, root)

	var streetlights := root.get_node_or_null("Props/Streetlights") as Node3D
	if streetlights != null and streetlights.get_child_count() > 0:
		var lamp_template := load("res://props/street_lamp.tscn").instantiate() as Node3D
		if lamp_template != null:
			bake_static_scene(lamp_template)
			var baked_lamp := lamp_template.get_node_or_null("BakedStaticMesh") as MeshInstance3D
			if baked_lamp != null and baked_lamp.mesh != null:
				create_multimesh_from_instances(streetlights, baked_lamp.mesh, root)
			lamp_template.free()

	return root
