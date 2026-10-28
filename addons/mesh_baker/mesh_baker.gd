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

## Merged static meshes never span grid cells of this size (m), so frustum and
## visibility-range culling still work per neighbourhood instead of per scene.
const BAKE_CELL_SIZE := 30.0

## Render key of a GeometryInstance3D with default settings.
const DEFAULT_RENDER_KEY: Array = [
	GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
	0.0,
	0.0,
	0.0,
	0.0,
	GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
]

## Render key of the wheel spokes/hubs `Car` adds to unbaked wheels.
const WHEEL_DETAIL_RENDER_KEY: Array = [
	GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	0.0,
	0.0,
	35.0,
	0.0,
	GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
]

## Vehicle scenes baked whole by `bake_vehicle_scene` (car bodies bake by folder).
const BAKED_VEHICLE_SCENES: Array[String] = [
	"res://cars/bus.tscn",
	"res://cars/truck.tscn",
	"res://cars/van.tscn",
	"res://cars/shipping_truck.tscn",
	"res://cars/taxi.tscn",
]

## Props baked by `bake_static_scene` (buildings bake by folder).
const BAKED_PROP_SCENES: Array[String] = [
	"res://props/shopping_cart.tscn",
	"res://props/bollard.tscn",
	"res://props/street_lamp.tscn",
	"res://props/fire_hydrant.tscn",
	"res://props/overhead_road_sign.tscn",
	"res://props/ice_machine.tscn",
]


## Export entry point: bakes the packed scene at `path`, or returns null when it
## ships unbaked. Every scene listed here is baked in its own exported file, so
## scenes that instance it must not bake into it again.
static func bake_scene_for_path(scene: Node3D, path: String) -> Node3D:
	if path == "res://main.tscn":
		return bake_main_scene(scene, false)
	# An inherited scene (sedan.tscn over sedan.blend) loads its base already baked;
	# baking it again stacks a second set of merged meshes on top.
	if _bakes_on_its_own(_inherited_base_path(path)):
		return null
	if path.begins_with("res://cars/bodies/"):
		return bake_car_body(scene)
	if path in BAKED_VEHICLE_SCENES:
		return bake_vehicle_scene(scene)
	if path.begins_with("res://buildings/"):
		bake_static_scene(scene)
		bake_bollards(scene, scene)
		return scene
	if path == "res://props/dumpster.tscn":
		return bake_dumpster(scene)
	if path in BAKED_PROP_SCENES:
		return bake_static_scene(scene)
	return null


## Saves the instanced sub-scene `node` inline under `scene_root` (nested instances
## stay references). A packed scene cannot delete an instance's children, so without
## this every node a bake removes from the instance would load again next to its
## baked copy.
static func make_local(node: Node, scene_root: Node) -> void:
	if node.scene_file_path == "":
		return
	var inner_owner := node
	node.scene_file_path = ""
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		for child in curr.get_children():
			if child.owner == inner_owner:
				child.owner = scene_root
				stack.append(child)


## Fills `mm` through its buffer: the headless exporter's dummy RenderingServer
## drops `set_instance_transform`, which saved every instance as identity.
static func set_multimesh_transforms(mm: MultiMesh, xforms: Array[Transform3D]) -> void:
	mm.instance_count = xforms.size()
	var buf := PackedFloat32Array()
	buf.resize(xforms.size() * 12)
	for i in range(xforms.size()):
		var t := xforms[i]
		var o := i * 12
		for row in range(3):
			buf[o + row * 4] = t.basis.x[row]
			buf[o + row * 4 + 1] = t.basis.y[row]
			buf[o + row * 4 + 2] = t.basis.z[row]
			buf[o + row * 4 + 3] = t.origin[row]
	mm.buffer = buf


## Godot measures a MultiMesh's visibility range to its AABB center, so pad a
## per-instance range by the spread of the instances or the outer ones vanish early.
static func _padded_range(range_end: float, xforms: Array[Transform3D]) -> float:
	var bounds := AABB(xforms[0].origin, Vector3.ZERO)
	for t in xforms:
		bounds = bounds.expand(t.origin)
	return range_end + bounds.size.length() * 0.5


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


## Appends one surface of `mesh`, transformed by `xform`. SurfaceTool.append_from
## transforms normals by the basis itself, which tilts them under non-uniform scale
## (the flattened Taco Hell bells shaded brighter), so the arrays are transformed here.
static func _append_mesh_surface(
	st: SurfaceTool, mesh: Mesh, surface_idx: int, xform: Transform3D
) -> void:
	if mesh == null or surface_idx < 0 or surface_idx >= mesh.get_surface_count():
		return
	_append_arrays(st, mesh.surface_get_arrays(surface_idx), xform)


static func _append_arrays(st: SurfaceTool, arrays: Array, xform: Transform3D) -> void:
	if arrays.is_empty():
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	for i in range(verts.size()):
		verts[i] = xform * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		var normal_basis := xform.basis.inverse().transposed()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(normals.size()):
			normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size() - 3, 4):
			var t := (
				(xform.basis * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])).normalized()
			)
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tangents
	var temp_mesh := ArrayMesh.new()
	temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.append_from(temp_mesh, 0, Transform3D.IDENTITY)


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
	_append_arrays(st, arrays, xform)


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
				_append_mesh_surface(st, item["mesh"], item["surface"], item["transform"])
			st.commit(merged_mesh)
		else:
			var base_mat: StandardMaterial3D = grp["base_material"] as StandardMaterial3D
			var collapsed_mat: StandardMaterial3D = base_mat.duplicate()
			collapsed_mat.vertex_color_use_as_albedo = true
			# Vertex colors carry the sRGB albedo_color values they replace.
			collapsed_mat.vertex_color_is_srgb = true
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


## Per-instance settings every part of a merged mesh must share, so baking never
## changes which parts cast shadows or when they are culled by distance.
static func render_key(gi: GeometryInstance3D) -> Array:
	return [
		gi.cast_shadow,
		gi.visibility_range_begin,
		gi.visibility_range_begin_margin,
		gi.visibility_range_end,
		gi.visibility_range_end_margin,
		gi.visibility_range_fade_mode,
	]


static func apply_render_key(gi: GeometryInstance3D, key: Array) -> void:
	gi.cast_shadow = key[0]
	gi.visibility_range_begin = key[1]
	gi.visibility_range_begin_margin = key[2]
	gi.visibility_range_end = key[3]
	gi.visibility_range_end_margin = key[4]
	gi.visibility_range_fade_mode = key[5]


## Appends one item per surface of `mi` (transform relative to `root`) to `items`.
static func append_mesh_items(items: Array[Dictionary], mi: MeshInstance3D, root: Node3D) -> void:
	var xform := get_relative_transform(mi, root)
	var key := render_key(mi)
	for s in range(mi.mesh.get_surface_count()):
		(
			items
			. append(
				{
					"mesh": mi.mesh,
					"surface": s,
					"transform": xform,
					"material": get_surface_material(mi, s),
					"key": key,
					"name": mi.name,
				}
			)
		)


## Merges `items` ({mesh, surface, transform, material, key}) into one mesh per
## render key and, when `cell_size` > 0, per horizontal grid cell of the part's
## AABB center (grid anchored at the parts' minimum corner, so anything smaller
## than a cell stays whole). Returns [{mesh, key, first}] in first-seen order
## (`first` is the group's first item).
static func merge_by_render_key(items: Array[Dictionary], cell_size: float) -> Array[Dictionary]:
	var centers: Array[Vector3] = []
	var grid_origin := Vector3.INF
	if cell_size > 0.0:
		for item in items:
			var xform: Transform3D = item["transform"]
			var center := (xform * (item["mesh"] as Mesh).get_aabb()).get_center()
			centers.append(center)
			grid_origin = grid_origin.min(center)
	var groups: Dictionary = {}
	var order: Array[String] = []
	var canonical_materials: Array[Material] = []
	for i in range(items.size()):
		var item := items[i]
		var key: Array = item["key"]
		var group_id := str(key)
		if cell_size > 0.0:
			var size := cell_size
			if key[3] > 0.0:
				# Godot measures the range to the merged AABB center: keep it near each part.
				size = minf(size, key[3] * 0.25)
			var local := centers[i] - grid_origin
			group_id += "|%d,%d" % [floori(local.x / size), floori(local.z / size)]
		if not groups.has(group_id):
			var mat_order: Array[Material] = []
			groups[group_id] = {"by_mat": {}, "mat_order": mat_order, "first": item}
			order.append(group_id)
		var group: Dictionary = groups[group_id]
		var mat := get_canonical_material(item["material"], canonical_materials)
		if not group["by_mat"].has(mat):
			group["by_mat"][mat] = []
			group["mat_order"].append(mat)
		group["by_mat"][mat].append(item)
	var out: Array[Dictionary] = []
	for group_id in order:
		var group: Dictionary = groups[group_id]
		var mesh := ArrayMesh.new()
		commit_surfaces_with_color_collapsing(mesh, group["by_mat"], group["mat_order"])
		out.append({"mesh": with_lods(mesh), "key": group["first"]["key"], "first": group["first"]})
	return out


## Rebuilds `mesh` with generated LODs: SurfaceTool merges drop the source meshes'
## LODs.
static func with_lods(mesh: ArrayMesh) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var importer := ImporterMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX] == null:
			# LOD generation skips surfaces without an index array.
			var st := SurfaceTool.new()
			st.create_from(mesh, s)
			st.index()
			arrays = st.commit_to_arrays()
		importer.add_surface(
			mesh.surface_get_primitive_type(s), arrays, [], {}, mesh.surface_get_material(s)
		)
	# Same angles as the scene importer's defaults.
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()


## Adds one MeshInstance3D per `merge_by_render_key` result under `parent`. The first is
## named `base_name`, the rest `base_name` + index, or their first part's name when
## `keep_part_names` (so name-based lookups such as car paint still match).
static func add_merged_instances(
	parent: Node3D,
	merged: Array[Dictionary],
	base_name: String,
	actual_owner: Node,
	keep_part_names := false
) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for i in range(merged.size()):
		var mi := MeshInstance3D.new()
		if i == 0:
			mi.name = base_name
		elif keep_part_names:
			mi.name = merged[i]["first"]["name"]
		else:
			mi.name = "%s%d" % [base_name, i + 1]
		mi.mesh = merged[i]["mesh"]
		apply_render_key(mi, merged[i]["key"])
		parent.add_child(mi)
		mi.owner = actual_owner
		out.append(mi)
	return out


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
	var wheel_key: Array = (
		render_key(wheel_node as MeshInstance3D)
		if wheel_node is MeshInstance3D
		else DEFAULT_RENDER_KEY
	)

	if wheel_node is MeshInstance3D and wheel_node.mesh != null:
		for s in range(wheel_node.mesh.get_surface_count()):
			(
				wheel_items
				. append(
					{
						"mesh": wheel_node.mesh,
						"surface": s,
						"transform": Transform3D.IDENTITY,
						"material": get_surface_material(wheel_node, s),
						"key": wheel_key,
					}
				)
			)

	for child in wheel_node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mi := child as MeshInstance3D
			append_mesh_items(wheel_items, mi, wheel_node)
			to_remove_children.append(mi)

	for detail_mesh: Mesh in [spoke_mesh, hub_mesh]:
		(
			wheel_items
			. append(
				{
					"mesh": detail_mesh,
					"surface": 0,
					"transform": Transform3D.IDENTITY,
					"material": chrome_mat,
					"key": WHEEL_DETAIL_RENDER_KEY,
				}
			)
		)

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

	# Parts sharing the wheel's render key merge into the wheel mesh; the rest
	# (shadowless, distance-culled rims and caps) become child meshes, the first
	# named "Spoke" so `Car` sees the wheel as already detailed.
	var detail_groups: Array[Dictionary] = []
	wheel_mi.mesh = null
	for group in merge_by_render_key(wheel_items, 0.0):
		if group["key"] == wheel_key:
			wheel_mi.mesh = group["mesh"]
			wheel_mi.mesh.set_meta("baked_wheel", true)
		else:
			detail_groups.append(group)
	add_merged_instances(wheel_mi, detail_groups, "Spoke", actual_owner)
	wheel_mi.set_meta("baked_wheel", true)

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
	var trim_items: Array[Dictionary] = []
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
			if child_name in PassengerCar.PAINTED_NODE_NAMES:
				append_mesh_items(painted_items, child, root)
			elif child_name == &"Stripe" or child_name.begins_with("Stripe"):
				append_mesh_items(stripe_items, child, root)
			else:
				append_mesh_items(trim_items, child, root)
		to_remove.append(child)

	for node in to_remove:
		root.remove_child(node)
		node.free()

	for wheel in wheels_to_bake:
		bake_wheel(wheel, actual_owner)

	# Painted parts and stripes take one shared material each (the runtime overrides
	# it by node name), so each render key bakes to a single surface. Extra keys keep
	# their first part's name so the paint and stripe lookups still match them.
	for items in [painted_items, stripe_items]:
		for item in items:
			item["material"] = items[0]["material"]
	add_merged_instances(root, merge_by_render_key(painted_items, 0.0), "Body", actual_owner, true)
	add_merged_instances(root, merge_by_render_key(stripe_items, 0.0), "Stripe", actual_owner, true)
	add_merged_instances(root, merge_by_render_key(trim_items, 0.0), "Trim", actual_owner)

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


static func _collect_vehicle_meshes(node: Node3D, root: Node3D, items: Array[Dictionary]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		append_mesh_items(items, node, root)
	for child in node.get_children():
		if child is Node3D and not child.name.begins_with("Wheel"):
			_collect_vehicle_meshes(child, root, items)


static func _process_vehicle_container(
	container: Node3D, model: Node3D, actual_owner: Node, items: Array[Dictionary]
) -> void:
	container.owner = actual_owner
	var sub_to_remove: Array[Node] = []
	for subchild in container.get_children():
		if subchild is MeshInstance3D:
			_collect_vehicle_meshes(subchild, model, items)
			sub_to_remove.append(subchild)
		elif subchild is Label3D:
			subchild.owner = actual_owner
		elif subchild is Node3D:
			_process_vehicle_container(subchild, model, actual_owner, items)
			if subchild.get_child_count() == 0:
				sub_to_remove.append(subchild)
	for sm in sub_to_remove:
		container.remove_child(sm)
		sm.free()


static func bake_vehicle_model(model: Node3D, scene_root: Node = null) -> Node3D:
	if not model is Node3D:
		return model
	var actual_owner: Node = scene_root if scene_root != null else model
	var items: Array[Dictionary] = []
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
			_collect_vehicle_meshes(child, model, items)
			to_remove.append(child)
		elif child is Node3D:
			_process_vehicle_container(child, model, actual_owner, items)
			if child.get_child_count() == 0:
				to_remove.append(child)
	for node in to_remove:
		model.remove_child(node)
		node.free()

	for wheel in wheels_to_bake:
		bake_wheel(wheel, actual_owner)

	add_merged_instances(model, merge_by_render_key(items, 0.0), "Body", actual_owner)

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
			_append_mesh_surface(body_st, item["mesh"], item["surface"], item["transform"])
		body_st.commit(merged_mesh)

	# 2. Surfaces 1+: Static trim parts grouped by material
	commit_surfaces_with_color_collapsing(merged_mesh, trim_by_mat, trim_mat_order)

	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = merged_mesh
	root.add_child(body_mi)
	body_mi.owner = actual_owner

	return root


## Merges the static meshes under `root` into "BakedStaticMesh" instances, one per
## render key and BAKE_CELL_SIZE cell. Hidden subtrees stay unbaked (scripts may
## toggle them). `single_mesh` bakes MultiMesh templates instead: one mesh per
## `cast_shadow` setting (shadow-off parts must stay shadow-off), all keeping the
## longest visibility range.
static func bake_static_scene(
	root: Node3D, scene_root: Node = null, single_mesh := false
) -> Node3D:
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
			if child is Node3D and not (child as Node3D).visible:
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

	var items: Array[Dictionary] = []
	for mi in mesh_instances:
		append_mesh_items(items, mi, root)
	if single_mesh:
		var key := DEFAULT_RENDER_KEY.duplicate()
		for mi in mesh_instances:
			if mi.visibility_range_end <= 0.0:
				key[3] = 0.0
				break
			key[3] = maxf(key[3], mi.visibility_range_end)
		for item in items:
			var item_key := key.duplicate()
			item_key[0] = item["key"][0]
			item["key"] = item_key
	var merged := merge_by_render_key(items, 0.0 if single_mesh else BAKE_CELL_SIZE)

	# Nullify original meshes so they don't render or take draw calls
	for i in range(mesh_instances.size() - 1, -1, -1):
		var mi := mesh_instances[i]
		mi.mesh = null
		if mi.get_child_count() == 0:
			var parent := mi.get_parent()
			if parent != null:
				parent.remove_child(mi)
				mi.free()
	add_merged_instances(root, merged, "BakedStaticMesh", actual_owner)
	return root


## Replaces the meshes of every instance under `container` with one MultiMesh per
## baked template ("BakedMultiMesh", then "BakedMultiMesh2", ...), each keeping its
## template's `cast_shadow` and visibility range.
static func create_multimesh_from_instances(
	container: Node3D, templates: Array[MeshInstance3D], scene_root: Node = null
) -> Array[MultiMeshInstance3D]:
	var actual_owner: Node = scene_root if scene_root != null else container
	var out: Array[MultiMeshInstance3D] = []
	var instances: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D and not (child is MultiMeshInstance3D):
			instances.append(child as Node3D)
	if instances.is_empty() or templates.is_empty():
		return out

	var xforms: Array[Transform3D] = []
	for inst in instances:
		xforms.append(inst.transform)
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

	for i in range(templates.size()):
		var template := templates[i]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = template.mesh
		set_multimesh_transforms(mm, xforms)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BakedMultiMesh" if i == 0 else "BakedMultiMesh%d" % (i + 1)
		mmi.multimesh = mm
		mmi.cast_shadow = template.cast_shadow
		if template.visibility_range_end > 0.0:
			mmi.visibility_range_end = _padded_range(template.visibility_range_end, xforms)
		container.add_child(mmi)
		mmi.owner = actual_owner
		out.append(mmi)
	return out


static func bake_trees(container: Node3D, actual_owner: Node) -> void:
	for tree in container.get_children():
		if not (tree is Node3D):
			continue
		make_local(tree, actual_owner)
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
		# Palm/LiveOak variants instance a model; the merge below edits its children.
		make_local(active_node, actual_owner)
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
			var items: Array[Dictionary] = []
			for mi in static_meshes:
				append_mesh_items(items, mi, active_node)
				active_node.remove_child(mi)
				mi.free()
			add_merged_instances(
				active_node, merge_by_render_key(items, 0.0), "Trunk", actual_owner
			)
		# `_apply_tree_type` builds variants without an owner; own them so they save.
		var stack: Array[Node] = [tree]
		while not stack.is_empty():
			for c in stack.pop_back().get_children():
				if c.owner == null:
					c.owner = actual_owner
				if c.scene_file_path == "":
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
		var pole_items: Array[Dictionary] = []
		var pole_nodes_to_remove: Array[Node] = []
		for child in active_node.get_children():
			if child.name in STATIC_POLE_NAMES and child is MeshInstance3D and child.mesh != null:
				append_mesh_items(pole_items, child, active_node)
				pole_nodes_to_remove.append(child)

		if not pole_items.is_empty():
			for node in pole_nodes_to_remove:
				active_node.remove_child(node)
				node.free()
			add_merged_instances(
				active_node, merge_by_render_key(pole_items, 0.0), "Pole", actual_owner
			)

		flag.scene_file_path = ""
		var stack: Array[Node] = [flag]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			n.owner = actual_owner
			for c in n.get_children():
				stack.append(c)


## Merges the bollards `actual_owner` owns (nested sub-scenes bake their own) into
## one MultiMesh per direct child of `container`.
static func bake_bollards(container: Node3D, actual_owner: Node) -> void:
	var bollards_by_site: Dictionary = {}
	var stack: Array[Node] = [container]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if (
			n.owner == actual_owner
			and (
				n.scene_file_path == "res://props/bollard.tscn"
				or (n.name.begins_with("Bollard") and n is StaticBody3D)
			)
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
	bake_static_scene(bollard_template, null, true)
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
		var xforms: Array[Transform3D] = []

		for bollard: Node3D in bollard_list:
			xforms.append(get_relative_transform(bollard, site))
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
		set_multimesh_transforms(mm, xforms)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BakedBollardsMultiMesh"
		mmi.multimesh = mm
		if template_vis_range > 0.0:
			mmi.visibility_range_end = _padded_range(template_vis_range, xforms)
		site.add_child(mmi)
		mmi.owner = actual_owner

	bollard_template.free()


## Bakes the main scene. `bake_instanced` also bakes the instanced sub-scenes that
## export bakes in their own files (`bake_scene_for_path`); runtime previews load
## them unbaked, while the export must leave them alone or they load twice.
static func bake_main_scene(root: Node3D, bake_instanced := true) -> Node3D:
	var road := root.get_node_or_null("Road") as Node3D
	if road != null:
		make_local(road, root)
		var pavement := road.get_node_or_null("PavementDetails")
		if pavement != null and pavement.has_method("build_mesh"):
			pavement.build_mesh()
		bake_static_scene(road, root)
		_disable_baked_shadows(road)
	var parking := root.get_node_or_null("Parking") as Node3D
	if parking != null:
		make_local(parking, root)
		var ruts := parking.get_node_or_null("ShortcutRuts")
		if ruts != null and ruts.has_method("build_mesh"):
			ruts.build_mesh()
		bake_static_scene(parking, root)
		_disable_baked_shadows(parking)

	var streetlights := root.get_node_or_null("Props/Streetlights") as Node3D
	if streetlights != null and streetlights.get_child_count() > 0:
		make_local(streetlights, root)
		var lamp_template := load("res://props/street_lamp.tscn").instantiate() as Node3D
		if lamp_template != null:
			bake_static_scene(lamp_template, null, true)
			var baked_parts: Array[MeshInstance3D] = []
			for child in lamp_template.get_children():
				if child is MeshInstance3D and child.name.begins_with("BakedStaticMesh"):
					baked_parts.append(child)
			create_multimesh_from_instances(streetlights, baked_parts, root)
			lamp_template.free()

	var trees := root.get_node_or_null("Props/Trees") as Node3D
	if trees != null:
		make_local(trees, root)
		bake_trees(trees, root)

	var flags := root.get_node_or_null("Props/Flags") as Node3D
	if flags != null:
		make_local(flags, root)
		bake_flags(flags, root)

	var props := root.get_node_or_null("Props") as Node3D
	if props == null:
		return root
	if bake_instanced:
		var instanced: Array[Node3D] = []
		var stack: Array[Node] = [props]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			var path := n.scene_file_path
			# Cars stay unbaked here: their scripts hold references to the body parts.
			if n is Node3D and _bakes_on_its_own(path) and not path.begins_with("res://cars/"):
				instanced.append(n as Node3D)
		for n in instanced:
			bake_scene_for_path(n, n.scene_file_path)
	for child in props.get_children():
		if child.name in [&"Streetlights", &"Trees", &"Flags", &"Powerlines"]:
			continue
		# Scripted props (billboards, tunnels, forest) build their meshes in `_ready`.
		if not (child is Node3D) or child.get_script() != null:
			continue
		if _bakes_on_its_own(child.scene_file_path):
			continue
		make_local(child, root)
		bake_static_scene(child, root)

	return root


static func _bakes_on_its_own(path: String) -> bool:
	return (
		path.begins_with("res://buildings/")
		or path.begins_with("res://cars/bodies/")
		or path in BAKED_VEHICLE_SCENES
		or path in BAKED_PROP_SCENES
		or path == "res://props/dumpster.tscn"
	)


## Base scene of the inherited scene at `path` ("" when it is not inherited).
static func _inherited_base_path(path: String) -> String:
	if not path.ends_with(".tscn"):
		return ""
	var state := (load(path) as PackedScene).get_state()
	if state.get_node_count() == 0 or state.get_node_instance(0) == null:
		return ""
	return state.get_node_instance(0).resource_path


static func _disable_baked_shadows(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and child.name.begins_with("BakedStaticMesh"):
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
