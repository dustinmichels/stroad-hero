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


static var _wheel_chrome_mat: StandardMaterial3D = null


static func get_wheel_chrome_material() -> StandardMaterial3D:
	if _wheel_chrome_mat == null:
		_wheel_chrome_mat = StandardMaterial3D.new()
		_wheel_chrome_mat.albedo_color = Color(0.85, 0.86, 0.88, 1.0)
		_wheel_chrome_mat.metallic = 0.85
		_wheel_chrome_mat.roughness = 0.25
	return _wheel_chrome_mat


static func _standard_materials_equal(a: StandardMaterial3D, b: StandardMaterial3D) -> bool:
	if a == b:
		return true
	if a == null or b == null:
		return false
	if not a.albedo_color.is_equal_approx(b.albedo_color):
		return false
	if a.albedo_texture != b.albedo_texture:
		return false
	if not is_equal_approx(a.roughness, b.roughness):
		return false
	if a.roughness_texture != b.roughness_texture:
		return false
	if not is_equal_approx(a.metallic, b.metallic):
		return false
	if not is_equal_approx(a.metallic_specular, b.metallic_specular):
		return false
	if a.metallic_texture != b.metallic_texture:
		return false
	if a.emission_enabled != b.emission_enabled:
		return false
	if a.emission_enabled:
		if not a.emission.is_equal_approx(b.emission):
			return false
		if not is_equal_approx(a.emission_energy_multiplier, b.emission_energy_multiplier):
			return false
		if a.emission_texture != b.emission_texture:
			return false
	if a.transparency != b.transparency:
		return false
	if a.shading_mode != b.shading_mode:
		return false
	if a.cull_mode != b.cull_mode:
		return false
	if a.depth_draw_mode != b.depth_draw_mode:
		return false
	if a.no_depth_test != b.no_depth_test:
		return false
	if a.render_priority != b.render_priority:
		return false
	if a.vertex_color_use_as_albedo != b.vertex_color_use_as_albedo:
		return false
	if a.blend_mode != b.blend_mode:
		return false
	if a.texture_filter != b.texture_filter:
		return false
	if a.billboard_mode != b.billboard_mode:
		return false
	if a.grow != b.grow:
		return false
	if a.grow and not is_equal_approx(a.grow_amount, b.grow_amount):
		return false
	if not a.uv1_scale.is_equal_approx(b.uv1_scale):
		return false
	if not a.uv1_offset.is_equal_approx(b.uv1_offset):
		return false
	if not a.uv2_scale.is_equal_approx(b.uv2_scale):
		return false
	if not a.uv2_offset.is_equal_approx(b.uv2_offset):
		return false
	if a.disable_ambient_light != b.disable_ambient_light:
		return false
	return true


static func _shader_materials_equal(a: ShaderMaterial, b: ShaderMaterial) -> bool:
	if a == b:
		return true
	if a == null or b == null:
		return false
	if a.shader != b.shader or a.render_priority != b.render_priority:
		return false
	for prop in a.get_property_list():
		var pname: String = prop.name
		if pname.begins_with("shader_parameter/"):
			var val_a = a.get(pname)
			var val_b = b.get(pname)
			if val_a != val_b:
				if val_a is Color and val_b is Color:
					if not val_a.is_equal_approx(val_b):
						return false
				elif val_a is float and val_b is float:
					if not is_equal_approx(val_a, val_b):
						return false
				elif val_a is Vector2 and val_b is Vector2:
					if not val_a.is_equal_approx(val_b):
						return false
				elif val_a is Vector3 and val_b is Vector3:
					if not val_a.is_equal_approx(val_b):
						return false
				else:
					return false
	return true


static func materials_are_equivalent(a: Material, b: Material) -> bool:
	if a == b:
		return true
	if a == null or b == null:
		return false
	if a.get_class() != b.get_class():
		return false
	if a is StandardMaterial3D:
		return _standard_materials_equal(a as StandardMaterial3D, b as StandardMaterial3D)
	if a is ShaderMaterial:
		return _shader_materials_equal(a as ShaderMaterial, b as ShaderMaterial)
	return false


static func get_canonical_material(mat: Material, canonical_materials: Array[Material]) -> Material:
	if mat == null:
		return null
	for existing in canonical_materials:
		if materials_are_equivalent(mat, existing):
			return existing
	canonical_materials.append(mat)
	return mat


static func materials_can_collapse_by_color(a: Material, b: Material) -> bool:
	if a == b:
		return true
	if a == null or b == null:
		return false
	if not (a is StandardMaterial3D and b is StandardMaterial3D):
		return false
	var sa := a as StandardMaterial3D
	var sb := b as StandardMaterial3D
	if sa.albedo_texture != null or sb.albedo_texture != null:
		return false
	if sa.roughness_texture != null or sb.roughness_texture != null:
		return false
	if sa.metallic_texture != null or sb.metallic_texture != null:
		return false
	if sa.normal_texture != null or sb.normal_texture != null:
		return false
	if sa.emission_enabled or sb.emission_enabled:
		return false
	if (
		sa.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or sb.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	):
		return false
	if sa.shading_mode != sb.shading_mode:
		return false
	if sa.cull_mode != sb.cull_mode:
		return false
	if sa.depth_draw_mode != sb.depth_draw_mode:
		return false
	if sa.no_depth_test != sb.no_depth_test:
		return false
	if sa.render_priority != sb.render_priority:
		return false
	if sa.blend_mode != sb.blend_mode:
		return false
	if sa.billboard_mode != sb.billboard_mode:
		return false
	if sa.texture_filter != sb.texture_filter:
		return false
	if sa.specular_mode != sb.specular_mode:
		return false
	if sa.diffuse_mode != sb.diffuse_mode:
		return false
	if sa.disable_ambient_light != sb.disable_ambient_light:
		return false
	if sa.grow != sb.grow:
		return false
	if sa.grow and not is_equal_approx(sa.grow_amount, sb.grow_amount):
		return false
	if not is_equal_approx(sa.roughness, sb.roughness):
		return false
	if not is_equal_approx(sa.metallic, sb.metallic):
		return false
	if not is_equal_approx(sa.metallic_specular, sb.metallic_specular):
		return false
	if (
		not sa.uv1_scale.is_equal_approx(sb.uv1_scale)
		or not sa.uv1_offset.is_equal_approx(sb.uv1_offset)
	):
		return false
	if (
		not sa.uv2_scale.is_equal_approx(sb.uv2_scale)
		or not sa.uv2_offset.is_equal_approx(sb.uv2_offset)
	):
		return false
	return true


static func _append_mesh_surface_with_color(
	st: SurfaceTool, mesh: Mesh, surface_idx: int, xform: Transform3D, color: Color
) -> void:
	if mesh == null or surface_idx < 0 or surface_idx >= mesh.get_surface_count():
		return
	var arrays := mesh.surface_get_arrays(surface_idx)
	if arrays.is_empty():
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vert_count := verts.size()
	if vert_count == 0:
		return
	var colors := PackedColorArray()
	colors.resize(vert_count)
	var existing_colors = arrays[Mesh.ARRAY_COLOR]
	if existing_colors is PackedColorArray and existing_colors.size() == vert_count:
		for i in range(vert_count):
			colors[i] = existing_colors[i] * color
	else:
		colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var temp_mesh := ArrayMesh.new()
	temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.append_from(temp_mesh, 0, xform)


static func commit_surfaces_with_color_collapsing(
	merged_mesh: ArrayMesh, surfaces_by_material: Dictionary, material_order: Array[Material]
) -> void:
	var groups: Array[Dictionary] = []
	for mat in material_order:
		var found_group := false
		for grp in groups:
			if materials_can_collapse_by_color(mat, grp["base_material"]):
				grp["materials"].append(mat)
				found_group = true
				break
		if not found_group:
			groups.append({"base_material": mat, "materials": [mat]})

	for grp in groups:
		var mats: Array = grp["materials"]
		if mats.size() == 1:
			var mat: Material = mats[0]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if mat != null:
				st.set_material(mat)
			for item in surfaces_by_material[mat]:
				st.append_from(item["mesh"], item["surface"], item["transform"])
			st.commit(merged_mesh)
		else:
			var base_mat: StandardMaterial3D = grp["base_material"] as StandardMaterial3D
			var collapsed_mat: StandardMaterial3D = base_mat.duplicate()
			collapsed_mat.vertex_color_use_as_albedo = true
			collapsed_mat.albedo_color = Color.WHITE
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(collapsed_mat)
			for mat in mats:
				var col: Color = (mat as StandardMaterial3D).albedo_color
				for item in surfaces_by_material[mat]:
					_append_mesh_surface_with_color(
						st, item["mesh"], item["surface"], item["transform"], col
					)
			st.commit(merged_mesh)


static func bake_wheel(wheel_node: Node3D, scene_root: Node = null) -> Node3D:
	if wheel_node == null or wheel_node.get_meta("baked_wheel", false):
		return wheel_node

	var actual_owner: Node = (
		scene_root
		if scene_root != null
		else (wheel_node.owner if wheel_node.owner != null else wheel_node)
	)

	var chrome_mat := get_wheel_chrome_material()

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
	var canonical_materials: Array[Material] = []

	for item in wheel_items:
		var orig_mat: Material = item["material"]
		var mat: Material = get_canonical_material(orig_mat, canonical_materials)
		item["material"] = mat
		if not surfaces_by_material.has(mat):
			surfaces_by_material[mat] = []
			material_order.append(mat)
		surfaces_by_material[mat].append(item)
	var new_wheel_mesh := ArrayMesh.new()
	commit_surfaces_with_color_collapsing(new_wheel_mesh, surfaces_by_material, material_order)

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
	var stripe_items: Array[Dictionary] = []
	var trim_by_material: Dictionary = {}
	var trim_mat_order: Array[Material] = []
	var canonical_materials: Array[Material] = []
	var light_markers_data: Array[Dictionary] = []
	var wheels_to_bake: Array[Node3D] = []
	var to_remove: Array[Node] = []

	for child in root.get_children():
		var child_name: StringName = child.name
		if child_name.begins_with("Wheel") and child is Node3D:
			wheels_to_bake.append(child)
			continue
		if child_name in [&"SirenRed", &"SirenBlue"]:
			child.owner = actual_owner
			for lens in child.find_children("*", "", true, false):
				lens.owner = actual_owner
			continue

		if child_name in [&"HeadlightL", &"HeadlightR"]:
			child.owner = actual_owner
			continue

		if child_name.begins_with("ExhaustStack"):
			child.owner = actual_owner
			for subchild in child.get_children():
				subchild.owner = actual_owner
			continue

		if child_name in LIGHT_MARKER_NAMES:
			light_markers_data.append({"name": child_name, "transform": child.transform})
		if child is MeshInstance3D and child.mesh:
			var xform := get_relative_transform(child, root)
			var is_painted := child_name in PassengerCar.PAINTED_NODE_NAMES
			var is_stripe := child_name == &"Stripe" or child_name.begins_with("Stripe")
			for s in range(child.mesh.get_surface_count()):
				var orig_mat := get_surface_material(child, s)
				var mat := get_canonical_material(orig_mat, canonical_materials)
				var entry := {
					"mesh": child.mesh,
					"surface": s,
					"transform": xform,
					"material": mat,
				}
				if is_painted:
					painted_items.append(entry)
				elif is_stripe:
					stripe_items.append(entry)
				else:
					if not trim_by_material.has(mat):
						trim_by_material[mat] = []
						trim_mat_order.append(mat)
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

	# 2. Baked Stripe (stripe parts merged into 1 mesh, 1 surface)
	if not stripe_items.is_empty():
		var stripe_st := SurfaceTool.new()
		stripe_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var stripe_mat: Material = stripe_items[0]["material"]
		if stripe_mat:
			stripe_st.set_material(stripe_mat)
		for item in stripe_items:
			stripe_st.append_from(item["mesh"], item["surface"], item["transform"])
		var stripe_mesh := stripe_st.commit()

		var stripe_mi := MeshInstance3D.new()
		stripe_mi.name = "Stripe"
		stripe_mi.mesh = stripe_mesh
		root.add_child(stripe_mi)
		stripe_mi.owner = actual_owner

	# 2. Baked Trim (all other static body parts grouped by material)
	if not trim_by_material.is_empty():
		var trim_mesh := ArrayMesh.new()
		commit_surfaces_with_color_collapsing(trim_mesh, trim_by_material, trim_mat_order)
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
	node: Node3D,
	root: Node3D,
	surfaces_by_material: Dictionary,
	material_order: Array[Material],
	canonical_materials: Array[Material]
) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var xform := get_relative_transform(node, root)
		for s in range(node.mesh.get_surface_count()):
			var orig_mat := get_surface_material(node, s)
			var mat := get_canonical_material(orig_mat, canonical_materials)
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
			_collect_vehicle_meshes(
				child, root, surfaces_by_material, material_order, canonical_materials
			)


static func _process_vehicle_container(
	container: Node3D,
	model: Node3D,
	actual_owner: Node,
	surfaces_by_material: Dictionary,
	material_order: Array[Material],
	canonical_materials: Array[Material]
) -> void:
	container.owner = actual_owner
	var sub_to_remove: Array[Node] = []
	for subchild in container.get_children():
		if subchild is MeshInstance3D:
			_collect_vehicle_meshes(
				subchild, model, surfaces_by_material, material_order, canonical_materials
			)
			sub_to_remove.append(subchild)
		elif subchild is Label3D:
			subchild.owner = actual_owner
		elif subchild is Node3D:
			_process_vehicle_container(
				subchild,
				model,
				actual_owner,
				surfaces_by_material,
				material_order,
				canonical_materials
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
	var canonical_materials: Array[Material] = []
	var light_markers_data: Array[Dictionary] = []
	var wheels_to_bake: Array[Node3D] = []
	var to_remove: Array[Node] = []

	for child in model.get_children():
		var child_name: StringName = child.name
		if child_name.begins_with("Wheel") and child is Node3D:
			wheels_to_bake.append(child)
			continue
		if child_name in [&"SirenRed", &"SirenBlue"]:
			child.owner = actual_owner
			for lens in child.find_children("*", "", true, false):
				lens.owner = actual_owner
			continue

		if child_name in [&"HeadlightL", &"HeadlightR"]:
			child.owner = actual_owner
			continue

		if child_name in LIGHT_MARKER_NAMES:
			light_markers_data.append({"name": child_name, "transform": child.transform})
		if child is Label3D:
			child.owner = actual_owner
			continue

		if child is MeshInstance3D:
			_collect_vehicle_meshes(
				child, model, surfaces_by_material, material_order, canonical_materials
			)
			to_remove.append(child)
		elif child is Node3D:
			_process_vehicle_container(
				child,
				model,
				actual_owner,
				surfaces_by_material,
				material_order,
				canonical_materials
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
		commit_surfaces_with_color_collapsing(baked_mesh, surfaces_by_material, material_order)

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
	var trim_mat_order: Array[Material] = []
	var canonical_materials: Array[Material] = []
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
					var orig_mat := get_surface_material(child, s)
					var mat := get_canonical_material(orig_mat, canonical_materials)
					if not trim_by_mat.has(mat):
						trim_by_mat[mat] = []
						trim_mat_order.append(mat)
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
	commit_surfaces_with_color_collapsing(merged_mesh, trim_by_mat, trim_mat_order)

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
	var mat_order: Array[Material] = []
	var canonical_materials: Array[Material] = []
	var max_vis_range: float = 0.0
	for mi in mesh_instances:
		if mi.visibility_range_end > max_vis_range:
			max_vis_range = mi.visibility_range_end
		var xform := get_relative_transform(mi, root)
		for s in range(mi.mesh.get_surface_count()):
			var orig_mat := get_surface_material(mi, s)
			var mat := get_canonical_material(orig_mat, canonical_materials)
			if not by_mat.has(mat):
				by_mat[mat] = []
				mat_order.append(mat)
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
	commit_surfaces_with_color_collapsing(merged_mesh, by_mat, mat_order)

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
	if max_vis_range > 0.0:
		merged_mi.visibility_range_end = max_vis_range
	root.add_child(merged_mi)
	merged_mi.owner = actual_owner
	return root


static func create_multimesh_from_instances(
	container: Node3D,
	template_mesh: Mesh,
	scene_root: Node = null,
	visibility_range_end: float = 0.0
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
	if visibility_range_end > 0.0:
		mmi.visibility_range_end = visibility_range_end
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
			5:
				active_name = "Palm"
			6:
				active_name = "LiveOak"
		var active_node := visuals.get_node_or_null(active_name) as Node3D
		if active_node == null and tree.has_method("_apply_tree_type"):
			tree._apply_tree_type()
			active_node = visuals.get_node_or_null(active_name) as Node3D
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
			var mat_order: Array[Material] = []
			var canonical_materials: Array[Material] = []
			var max_trunk_vis_range: float = 0.0
			for mi in static_meshes:
				if mi.visibility_range_end > max_trunk_vis_range:
					max_trunk_vis_range = mi.visibility_range_end
				var xform := get_relative_transform(mi, active_node)
				for s in range(mi.mesh.get_surface_count()):
					var orig_mat := get_surface_material(mi, s)
					var mat := get_canonical_material(orig_mat, canonical_materials)
					if not by_mat.has(mat):
						by_mat[mat] = []
						mat_order.append(mat)
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
			commit_surfaces_with_color_collapsing(merged_mesh, by_mat, mat_order)
			var merged_mi := MeshInstance3D.new()
			merged_mi.name = "Trunk"
			merged_mi.mesh = merged_mesh
			if max_trunk_vis_range > 0.0:
				merged_mi.visibility_range_end = max_trunk_vis_range
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
		&"Bracket",
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
			3:
				active_name = "Mounted"
			4:
				active_name = "Colossal"
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
		var pole_mat_order: Array[Material] = []
		var canonical_materials: Array[Material] = []
		var pole_nodes_to_remove: Array[Node] = []
		var max_pole_vis_range: float = 0.0
		for child in active_node.get_children():
			if child.name in STATIC_POLE_NAMES and child is MeshInstance3D and child.mesh != null:
				if child.visibility_range_end > max_pole_vis_range:
					max_pole_vis_range = child.visibility_range_end
				var xform := get_relative_transform(child, active_node)
				for s in range(child.mesh.get_surface_count()):
					var orig_mat := get_surface_material(child, s)
					var mat := get_canonical_material(orig_mat, canonical_materials)
					if not pole_items_by_mat.has(mat):
						pole_items_by_mat[mat] = []
						pole_mat_order.append(mat)
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
			commit_surfaces_with_color_collapsing(
				merged_pole_mesh, pole_items_by_mat, pole_mat_order
			)
			var pole_mi := MeshInstance3D.new()
			pole_mi.name = "Pole"
			pole_mi.mesh = merged_pole_mesh
			if max_pole_vis_range > 0.0:
				pole_mi.visibility_range_end = max_pole_vis_range
			active_node.add_child(pole_mi)

		flag.scene_file_path = ""
		var stack: Array[Node] = [flag]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			n.owner = actual_owner
			for c in n.get_children():
				stack.append(c)


static func bake_bollards(container: Node3D, actual_owner: Node) -> void:
	var bollards_by_site: Dictionary = {}
	var stack: Array[Node] = [container]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if (
			n.scene_file_path == "res://props/bollard.tscn"
			or (n.name.begins_with("Bollard") and n is StaticBody3D)
		):
			var site := n
			while site != null and site.get_parent() != container and site != container:
				site = site.get_parent()
			if site == null:
				site = container
			if not bollards_by_site.has(site):
				bollards_by_site[site] = []
			bollards_by_site[site].append(n)
		for c in n.get_children():
			stack.append(c)

	if bollards_by_site.is_empty():
		return

	var bollard_template := load("res://props/bollard.tscn").instantiate() as Node3D
	if bollard_template == null:
		return
	bake_static_scene(bollard_template)
	var baked_mi := bollard_template.get_node_or_null("BakedStaticMesh") as MeshInstance3D
	if baked_mi == null or baked_mi.mesh == null:
		bollard_template.free()
		return
	var template_mesh := baked_mi.mesh
	var template_vis_range := baked_mi.visibility_range_end

	for site: Node3D in bollards_by_site:
		if site.get_node_or_null("BakedBollardsMultiMesh") != null:
			continue
		var bollard_list: Array = bollards_by_site[site]
		if bollard_list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = template_mesh
		mm.instance_count = bollard_list.size()

		for i in range(bollard_list.size()):
			var bollard := bollard_list[i] as Node3D
			var xf := get_relative_transform(bollard, site)
			mm.set_instance_transform(i, xf)
			var to_remove: Array[Node] = []
			for c in bollard.get_children():
				if c is MeshInstance3D:
					to_remove.append(c)
			for mi in to_remove:
				bollard.remove_child(mi)
				mi.free()
			bollard.scene_file_path = ""
			bollard.owner = actual_owner
			var b_stack: Array[Node] = [bollard]
			while not b_stack.is_empty():
				var curr: Node = b_stack.pop_back()
				curr.owner = actual_owner
				for c in curr.get_children():
					b_stack.append(c)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BakedBollardsMultiMesh"
		mmi.multimesh = mm
		if template_vis_range > 0.0:
			mmi.visibility_range_end = template_vis_range
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		site.add_child(mmi)
		mmi.owner = actual_owner

	bollard_template.free()


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
				create_multimesh_from_instances(
					streetlights, baked_lamp.mesh, root, baked_lamp.visibility_range_end
				)
			lamp_template.free()

	var trees := root.get_node_or_null("Props/Trees") as Node3D
	if trees != null:
		bake_trees(trees, root)

	var flags := root.get_node_or_null("Props/Flags") as Node3D
	if flags != null:
		bake_flags(flags, root)

	var props := root.get_node_or_null("Props") as Node3D
	if props != null:
		bake_bollards(props, root)
		for child in props.get_children():
			if child.name in [&"Streetlights", &"Trees", &"Flags", &"Powerlines", &"Forest"]:
				continue
			if child.name == &"WalgroinsShoppingCarts":
				for cart in child.get_children():
					if cart is Node3D and cart.get_node_or_null("BakedStaticMesh") == null:
						bake_static_scene(cart, root)
			elif child is Node3D and child.get_node_or_null("BakedStaticMesh") == null:
				bake_static_scene(child, root)

	return root
