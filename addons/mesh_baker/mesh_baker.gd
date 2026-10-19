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
	&"GrilleFace",
]

const LIGHT_MARKER_NAMES: Array[StringName] = [
	&"HeadlightL",
	&"HeadlightR",
	&"TaillightL",
	&"TaillightR",
]

const PRESERVED_STATIC_MESH_NAMES: Array[StringName] = [
	&"StatusLed",
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


static func bake_wheel(wheel_node: Node3D, scene_root: Node = null) -> Node3D:
	if wheel_node == null or wheel_node.get_meta("baked_wheel", false):
		return wheel_node

	var actual_owner: Node = (
		scene_root
		if scene_root != null
		else (wheel_node.owner if wheel_node.owner != null else wheel_node)
	)

	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.albedo_color = Color(0.85, 0.86, 0.88, 1.0)
	chrome_mat.metallic = 0.85
	chrome_mat.roughness = 0.25

	var spoke_mesh := BoxMesh.new()
	spoke_mesh.size = Vector3(0.50, 0.32, 0.08)

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.12
	hub_mesh.bottom_radius = 0.12
	hub_mesh.height = 0.33

	var wheel_items: Array[Dictionary] = []
	var to_remove_children: Array[Node] = []

	if wheel_node is MeshInstance3D and wheel_node.mesh != null:
		for s in range(wheel_node.mesh.get_surface_count()):
			var mat := get_surface_material(wheel_node, s)
			(
				wheel_items
				. append(
					{
						"mesh": wheel_node.mesh,
						"surface": s,
						"transform": Transform3D.IDENTITY,
						"material": mat,
					}
				)
			)

	for child in wheel_node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mi := child as MeshInstance3D
			var xform: Transform3D = mi.transform
			for s in range(mi.mesh.get_surface_count()):
				var mat := get_surface_material(mi, s)
				(
					wheel_items
					. append(
						{
							"mesh": mi.mesh,
							"surface": s,
							"transform": xform,
							"material": mat,
						}
					)
				)
			to_remove_children.append(mi)

	(
		wheel_items
		. append(
			{
				"mesh": spoke_mesh,
				"surface": 0,
				"transform": Transform3D.IDENTITY,
				"material": chrome_mat,
			}
		)
	)
	(
		wheel_items
		. append(
			{
				"mesh": hub_mesh,
				"surface": 0,
				"transform": Transform3D.IDENTITY,
				"material": chrome_mat,
			}
		)
	)

	var surfaces_by_material: Dictionary = {}
	var material_order: Array[Material] = []

	for item in wheel_items:
		var mat: Material = item["material"]
		if not surfaces_by_material.has(mat):
			surfaces_by_material[mat] = []
			material_order.append(mat)
		surfaces_by_material[mat].append(item)

	var new_wheel_mesh := ArrayMesh.new()
	for mat in material_order:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if mat != null:
			st.set_material(mat)
		for item in surfaces_by_material[mat]:
			st.append_from(item["mesh"], item["surface"], item["transform"])
		st.commit(new_wheel_mesh)

	var wheel_mi: MeshInstance3D
	if wheel_node is MeshInstance3D:
		wheel_mi = wheel_node
		for c in to_remove_children:
			wheel_mi.remove_child(c)
			c.free()
	else:
		wheel_mi = MeshInstance3D.new()
		wheel_mi.name = wheel_node.name
		wheel_mi.transform = wheel_node.transform
		var parent := wheel_node.get_parent()
		if parent != null:
			parent.remove_child(wheel_node)
			parent.add_child(wheel_mi)
			wheel_mi.owner = actual_owner
			wheel_node.free()

	wheel_mi.mesh = new_wheel_mesh
	wheel_mi.set_meta("baked_wheel", true)
	new_wheel_mesh.set_meta("baked_wheel", true)

	if not wheel_mi.has_node("Spoke"):
		var spoke_tag := Node.new()
		spoke_tag.name = "Spoke"
		wheel_mi.add_child(spoke_tag)
		spoke_tag.owner = actual_owner

	return wheel_mi


static func bake_car_body(root: Node3D, scene_root: Node = null) -> Node3D:
	var actual_owner: Node = scene_root if scene_root != null else root
	var painted_items: Array[Dictionary] = []
	var trim_by_material: Dictionary = {}
	var light_markers_data: Array[Dictionary] = []
	var wheels_to_bake: Array[Node3D] = []
	var to_remove: Array[Node] = []

	for child in root.get_children():
		var child_name: StringName = child.name
		if child_name.begins_with("Wheel") and child is Node3D:
			wheels_to_bake.append(child)
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

	for wheel in wheels_to_bake:
		bake_wheel(wheel, actual_owner)

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
		body_mi.owner = actual_owner

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
		trim_mi.owner = actual_owner

	# 3. Light markers (preserves positions for turn signal spawns)
	for data in light_markers_data:
		var marker := Marker3D.new()
		marker.name = data["name"]
		marker.transform = data["transform"]
		root.add_child(marker)
		marker.owner = actual_owner

	return root


static func bake_vehicle_scene(scene: Node3D, scene_root: Node = null) -> Node3D:
	if not scene is Node3D:
		return scene
	var actual_owner: Node = scene_root if scene_root != null else scene
	var visuals := scene.get_node_or_null("Visuals") as Node3D
	if visuals == null:
		return scene

	for model in visuals.get_children():
		if model is Node3D:
			bake_vehicle_model(model, actual_owner)

	return scene


static func _collect_vehicle_meshes(
	node: Node3D, root: Node3D, surfaces_by_material: Dictionary, material_order: Array[Material]
) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var xform := get_relative_transform(node, root)
		for s in range(node.mesh.get_surface_count()):
			var mat := get_surface_material(node, s)
			if not surfaces_by_material.has(mat):
				surfaces_by_material[mat] = []
				material_order.append(mat)
			(
				surfaces_by_material[mat]
				. append(
					{
						"mesh": node.mesh,
						"surface": s,
						"transform": xform,
						"material": mat,
					}
				)
			)
	for child in node.get_children():
		if child is Node3D and not child.name.begins_with("Wheel"):
			_collect_vehicle_meshes(child, root, surfaces_by_material, material_order)


static func _process_vehicle_container(
	container: Node3D,
	model: Node3D,
	actual_owner: Node,
	surfaces_by_material: Dictionary,
	material_order: Array[Material]
) -> void:
	container.owner = actual_owner
	var sub_to_remove: Array[Node] = []
	for subchild in container.get_children():
		if subchild is MeshInstance3D:
			_collect_vehicle_meshes(subchild, model, surfaces_by_material, material_order)
			sub_to_remove.append(subchild)
		elif subchild is Label3D:
			subchild.owner = actual_owner
		elif subchild is Node3D:
			_process_vehicle_container(
				subchild, model, actual_owner, surfaces_by_material, material_order
			)
			if subchild.get_child_count() == 0:
				sub_to_remove.append(subchild)
	for sm in sub_to_remove:
		container.remove_child(sm)
		sm.free()


static func bake_vehicle_model(model: Node3D, scene_root: Node = null) -> Node3D:
	if not model is Node3D:
		return model
	var actual_owner: Node = scene_root if scene_root != null else model
	var surfaces_by_material: Dictionary = {}
	var material_order: Array[Material] = []
	var light_markers_data: Array[Dictionary] = []
	var wheels_to_bake: Array[Node3D] = []
	var to_remove: Array[Node] = []

	for child in model.get_children():
		var child_name: StringName = child.name
		if child_name.begins_with("Wheel") and child is Node3D:
			wheels_to_bake.append(child)
			continue

		if child_name in LIGHT_MARKER_NAMES:
			light_markers_data.append({"name": child_name, "transform": child.transform})

		if child is Label3D:
			child.owner = actual_owner
			continue

		if child is MeshInstance3D:
			_collect_vehicle_meshes(child, model, surfaces_by_material, material_order)
			to_remove.append(child)
		elif child is Node3D:
			_process_vehicle_container(
				child, model, actual_owner, surfaces_by_material, material_order
			)
			if child.get_child_count() == 0:
				to_remove.append(child)

	for node in to_remove:
		model.remove_child(node)
		node.free()

	for wheel in wheels_to_bake:
		bake_wheel(wheel, actual_owner)

	if not surfaces_by_material.is_empty():
		var baked_mesh := ArrayMesh.new()
		for mat in material_order:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if mat != null:
				st.set_material(mat)
			for item in surfaces_by_material[mat]:
				st.append_from(item["mesh"], item["surface"], item["transform"])
			st.commit(baked_mesh)

		var body_mi := MeshInstance3D.new()
		body_mi.name = "Body"
		body_mi.mesh = baked_mesh
		model.add_child(body_mi)
		body_mi.owner = actual_owner

	for data in light_markers_data:
		var marker := Marker3D.new()
		marker.name = data["name"]
		marker.transform = data["transform"]
		model.add_child(marker)
		marker.owner = actual_owner

	return model


static func bake_dumpster(root: Node3D, scene_root: Node = null) -> Node3D:
	if not root is Node3D:
		return root
	var actual_owner: Node = scene_root if scene_root != null else root

	var warning_sticker := root.get_node_or_null("WarningSticker")
	if warning_sticker != null:
		var warning_label := warning_sticker.get_node_or_null("WarningLabel") as Label3D
		if warning_label != null:
			var label_xform := get_relative_transform(warning_label, root)
			warning_label.owner = null
			warning_sticker.remove_child(warning_label)
			root.add_child(warning_label)
			warning_label.transform = label_xform
			warning_label.owner = actual_owner

	const COLORED_PART_NAMES: Array[StringName] = [
		&"Body",
		&"TopRim",
		&"RibL",
		&"RibM",
		&"RibR",
	]
	const STATIC_TRIM_NAMES: Array[StringName] = [
		&"PocketL",
		&"PocketR",
		&"SkidL",
		&"SkidR",
		&"LeftLid",
		&"WarningSticker",
	]

	var colored_items: Array[Dictionary] = []
	var trim_by_mat: Dictionary = {}
	var to_remove: Array[Node] = []

	for child in root.get_children():
		var child_name: StringName = child.name
		if child_name in COLORED_PART_NAMES:
			if child is MeshInstance3D and child.mesh != null:
				var xform := get_relative_transform(child, root)
				for s in range(child.mesh.get_surface_count()):
					var mat := get_surface_material(child, s)
					(
						colored_items
						. append(
							{
								"mesh": child.mesh,
								"surface": s,
								"transform": xform,
								"material": mat,
							}
						)
					)
			to_remove.append(child)
		elif child_name in STATIC_TRIM_NAMES:
			if child is MeshInstance3D and child.mesh != null:
				var xform := get_relative_transform(child, root)
				for s in range(child.mesh.get_surface_count()):
					var mat := get_surface_material(child, s)
					if not trim_by_mat.has(mat):
						trim_by_mat[mat] = []
					(
						trim_by_mat[mat]
						. append(
							{
								"mesh": child.mesh,
								"surface": s,
								"transform": xform,
							}
						)
					)
			to_remove.append(child)

	for node in to_remove:
		root.remove_child(node)
		node.free()

	var merged_mesh := ArrayMesh.new()

	# 1. Surface 0: Dumpster colored body + ribs
	if not colored_items.is_empty():
		var body_st := SurfaceTool.new()
		body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var body_mat: Material = colored_items[0]["material"]
		if body_mat != null:
			body_st.set_material(body_mat)
		for item in colored_items:
			body_st.append_from(item["mesh"], item["surface"], item["transform"])
		body_st.commit(merged_mesh)

	# 2. Surfaces 1+: Static trim parts grouped by material
	for mat in trim_by_mat.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if mat != null:
			st.set_material(mat)
		for item in trim_by_mat[mat]:
			st.append_from(item["mesh"], item["surface"], item["transform"])
		st.commit(merged_mesh)

	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = merged_mesh
	root.add_child(body_mi)
	body_mi.owner = actual_owner

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
				stack.append(child)
				continue
			if child is CollisionShape3D or child is CollisionPolygon3D:
				continue
			if child is MeshInstance3D and child.mesh != null:
				if not (child.name in PRESERVED_STATIC_MESH_NAMES):
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
	for i in range(mesh_instances.size() - 1, -1, -1):
		var mi := mesh_instances[i]
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


static func bake_trees(container: Node3D, actual_owner: Node) -> void:
	for tree in container.get_children():
		if not (tree is Node3D):
			continue
		var tree_type: int = tree.get("tree_type")
		var visuals := tree.get_node_or_null("Visuals") as Node3D
		if visuals == null:
			continue
		var active_name: String = ""
		var height_scale: float = 1.0
		match tree_type:
			0:
				active_name = "Standard"
			1:
				active_name = "Tall"
			2:
				active_name = "Broad"
				height_scale = 1.15
			3:
				active_name = "Clustered"
			4:
				active_name = "Compact"
				height_scale = 1.25

		var active_node := visuals.get_node_or_null(active_name) as Node3D
		if active_node == null:
			continue
		active_node.scale.y = height_scale
		active_node.visible = true

		var to_remove: Array[Node] = []
		for child in visuals.get_children():
			if child != active_node:
				to_remove.append(child)
		for child in to_remove:
			visuals.remove_child(child)
			child.free()

		# Merge static meshes inside active_node if more than 1
		var static_meshes: Array[MeshInstance3D] = []
		for child in active_node.get_children():
			if child is MeshInstance3D and child.mesh != null and not ("Foliage" in child.name):
				static_meshes.append(child)
		if static_meshes.size() > 1:
			var by_mat: Dictionary = {}
			for mi in static_meshes:
				var xform := get_relative_transform(mi, active_node)
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
				active_node.remove_child(mi)
				mi.free()
			var merged_mesh := ArrayMesh.new()
			for mat in by_mat.keys():
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				if mat != null:
					st.set_material(mat)
				for item in by_mat[mat]:
					st.append_from(item["mesh"], item["surface"], item["transform"])
				st.commit(merged_mesh)
			var merged_mi := MeshInstance3D.new()
			merged_mi.name = "Trunk"
			merged_mi.mesh = merged_mesh
			active_node.add_child(merged_mi)

		tree.scene_file_path = ""
		var stack: Array[Node] = [tree]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			n.owner = actual_owner
			for c in n.get_children():
				stack.append(c)


static func bake_flags(container: Node3D, actual_owner: Node) -> void:
	const STATIC_POLE_NAMES: Array[StringName] = [
		&"Footing",
		&"BasePlate",
		&"Pole",
		&"Truck",
		&"Ball",
		&"Cleat",
	]
	for flag in container.get_children():
		if not (flag is Node3D):
			continue
		var flag_size: int = flag.get("flag_size")
		var visuals := flag.get_node_or_null("Visuals") as Node3D
		if visuals == null:
			continue
		var active_name: String = ""
		match flag_size:
			0:
				active_name = "Standard"
			1:
				active_name = "Large"
			2:
				active_name = "Giant"
		var active_node := visuals.get_node_or_null(active_name) as Node3D
		if active_node == null:
			continue
		active_node.visible = true

		var to_remove_variants: Array[Node] = []
		for child in visuals.get_children():
			if child != active_node:
				to_remove_variants.append(child)
		for child in to_remove_variants:
			visuals.remove_child(child)
			child.free()

		# Merge static meshes of pole (Footing, BasePlate, Pole, Truck, Ball, Cleat)
		var pole_items_by_mat: Dictionary = {}
		var pole_nodes_to_remove: Array[Node] = []
		for child in active_node.get_children():
			if child.name in STATIC_POLE_NAMES and child is MeshInstance3D and child.mesh != null:
				var xform := get_relative_transform(child, active_node)
				for s in range(child.mesh.get_surface_count()):
					var mat := get_surface_material(child, s)
					if not pole_items_by_mat.has(mat):
						pole_items_by_mat[mat] = []
					(
						pole_items_by_mat[mat]
						. append(
							{
								"mesh": child.mesh,
								"surface": s,
								"transform": xform,
							}
						)
					)
				pole_nodes_to_remove.append(child)

		if not pole_items_by_mat.is_empty():
			for node in pole_nodes_to_remove:
				active_node.remove_child(node)
				node.free()
			var merged_pole_mesh := ArrayMesh.new()
			for mat in pole_items_by_mat.keys():
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				if mat != null:
					st.set_material(mat)
				for item in pole_items_by_mat[mat]:
					st.append_from(item["mesh"], item["surface"], item["transform"])
				st.commit(merged_pole_mesh)
			var pole_mi := MeshInstance3D.new()
			pole_mi.name = "Pole"
			pole_mi.mesh = merged_pole_mesh
			active_node.add_child(pole_mi)

		flag.scene_file_path = ""
		var stack: Array[Node] = [flag]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			n.owner = actual_owner
			for c in n.get_children():
				stack.append(c)


static func bake_main_scene(root: Node3D) -> Node3D:
	var road := root.get_node_or_null("Road") as Node3D
	if road != null:
		var pavement := road.get_node_or_null("PavementDetails")
		if pavement != null and pavement.has_method("build_mesh"):
			pavement.build_mesh()
		bake_static_scene(road, root)
		var baked_road := road.get_node_or_null("BakedStaticMesh") as MeshInstance3D
		if baked_road != null:
			baked_road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parking := root.get_node_or_null("Parking") as Node3D
	if parking != null:
		bake_static_scene(parking, root)
		var baked_parking := parking.get_node_or_null("BakedStaticMesh") as MeshInstance3D
		if baked_parking != null:
			baked_parking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var streetlights := root.get_node_or_null("Props/Streetlights") as Node3D
	if streetlights != null and streetlights.get_child_count() > 0:
		var lamp_template := load("res://props/street_lamp.tscn").instantiate() as Node3D
		if lamp_template != null:
			bake_static_scene(lamp_template)
			var baked_lamp := lamp_template.get_node_or_null("BakedStaticMesh") as MeshInstance3D
			if baked_lamp != null and baked_lamp.mesh != null:
				create_multimesh_from_instances(streetlights, baked_lamp.mesh, root)
			lamp_template.free()

	var trees := root.get_node_or_null("Props/Trees") as Node3D
	if trees != null:
		bake_trees(trees, root)

	var flags := root.get_node_or_null("Props/Flags") as Node3D
	if flags != null:
		bake_flags(flags, root)

	return root
