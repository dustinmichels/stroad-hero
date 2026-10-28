@tool
class_name Forest
extends Node3D
## Procedural forest that blankets the background behind the stroad,
## commercial buildings, parking lots, and highway tunnel portals with native
## woodland cover (slash pine, southern live oak, sabal palm, and mixed hardwoods).
## Each tree is an interactive collidable StreetTree with wind sway and collision rustle.

const FENCE_SCENE: PackedScene = preload("res://props/chainlink_fence.tscn")
const BLEND_TREE1: PackedScene = preload("res://props/tree1.blend")
const BLEND_TREE2: PackedScene = preload("res://props/tree2.blend")

static var _variant_parts_cache: Dictionary = {}
@export var fence_enabled: bool = true:
	set(value):
		fence_enabled = value
		if is_inside_tree():
			build_forest()

@export var fence_height: float = 2.2:
	set(value):
		fence_height = value
		if is_inside_tree():
			build_forest()

@export var forest_seed: int = 1984:
	set(value):
		forest_seed = value
		if is_inside_tree():
			build_forest()

@export var grid_spacing: float = 9.0:
	set(value):
		grid_spacing = value
		if is_inside_tree():
			build_forest()

@export var min_tree_distance: float = 4.4:
	set(value):
		min_tree_distance = value
		if is_inside_tree():
			build_forest()

@export var bounds_min: Vector2 = Vector2(-140.0, -112.0):
	set(value):
		bounds_min = value
		if is_inside_tree():
			build_forest()

@export var bounds_max: Vector2 = Vector2(230.0, 140.0):
	set(value):
		bounds_max = value
		if is_inside_tree():
			build_forest()

@export var forest_visibility_range_end: float = 160.0:
	set(value):
		forest_visibility_range_end = value
		if is_inside_tree():
			build_forest()

@export var forest_visibility_range_end_margin: float = 25.0:
	set(value):
		forest_visibility_range_end_margin = value
		if is_inside_tree():
			build_forest()

@export var shadow_tree_distance: float = 40.0:
	set(value):
		shadow_tree_distance = value
		if is_inside_tree():
			build_forest()

## Edge length of the square tiles the forest MultiMeshes are split into, so
## frustum culling and visibility_range work per tile instead of per map side.
@export var forest_tile_size: float = 40.0:
	set(value):
		forest_tile_size = value
		if is_inside_tree():
			build_forest()

## Exclusion bounding boxes [x_min, x_max, z_min, z_max] for all structures,
## roads, parking lots, driveways, signs, and tunnel corridors.
const EXCLUSION_ZONES = [
	# Stroad corridor (roadway, shoulders, sidewalk gaps, markings)
	[-135.0, 185.0, -14.5, 14.5],
	# Frontage road, connector road, median, frontage sidewalks & aprons
	[56.0, 180.0, 14.0, 36.0],
	# Smell Gas Station (store building, pump canopy, parking apron, driveways)
	[-75.0, -36.0, -48.0, -14.0],
	# Walgroins Pharmacy (building, parking lot, driveways, carts, rear dumpsters)
	[-28.0, 22.0, -58.0, -14.0],
	# Taco Hell (restaurant building, parking stalls, drive-thru lane, ordering speaker)
	[20.0, 52.0, -54.0, -14.0],
	# North Billboard
	[56.0, 68.0, -26.0, -15.0],
	# Dorf Car Dealership (showroom, paved lot, display rows, giant US flag)
	[70.0, 130.0, -58.0, -14.0],
	# Booger King Site (restaurant, drive-thru lane, parking lot, flags)
	[-65.0, -20.0, 14.0, 56.0],
	# Strip Mall (retail strip, parking lot, sidewalks, dumpster corral)
	[-24.0, 18.0, 14.0, 56.0],
	# Cramped Inn Motel (hotel building, swimming pool, courtyard, parking lot)
	[16.0, 68.0, 14.0, 56.0],
	# Frontage Retail (building, parking lot, driveway)
	[72.0, 104.0, 32.0, 60.0],
	# Consumer Car Care (shop building, parking bays, driveway)
	[104.0, 136.0, 32.0, 62.0],
	# Frontage Commercial (office/commercial building, parking lot, driveway)
	[136.0, 168.0, 32.0, 60.0],
	# Frontage Median Billboard
	[98.0, 110.0, 16.0, 23.0],
	# Highway Tunnels (enclosures and approaches)
	[-128.0, -78.0, -15.5, 15.5],
	[136.0, 185.0, -15.5, 15.5],
]


func _ready() -> void:
	if not Engine.is_editor_hint():
		StreetTree._ensure_wind_connected()
	build_forest()


func build_forest() -> void:
	# Clear any prior generated trees and fences
	for child in get_children():
		child.queue_free()

	_build_fence()

	var existing_trees := _get_existing_tree_positions()
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed

	var min_dist_sq := min_tree_distance * min_tree_distance
	var cell_size := min_tree_distance
	var grid: Dictionary = {}

	var nx := int(ceil((bounds_max.x - bounds_min.x) / grid_spacing))
	var nz := int(ceil((bounds_max.y - bounds_min.y) / grid_spacing))
	# Bucket key: Vector3i(tile_x, tile_z, near). Each bucket maps TreeType to transforms.
	var groups: Dictionary = {}

	for ix in range(nx):
		for iz in range(nz):
			var x := bounds_min.x + (float(ix) + rng.randf_range(0.15, 0.85)) * grid_spacing
			var z := bounds_min.y + (float(iz) + rng.randf_range(0.15, 0.85)) * grid_spacing

			if _is_position_blocked(x, z, existing_trees):
				continue

			# Spatial grid check for minimum distance between trunks
			var gx := int(floor(x / cell_size))
			var gz := int(floor(z / cell_size))
			var too_close := false

			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var key := Vector2i(gx + dx, gz + dz)
					if grid.has(key):
						var pts: Array = grid[key]
						for pt: Vector2 in pts:
							var d2 := (x - pt.x) * (x - pt.x) + (z - pt.y) * (z - pt.y)
							if d2 < min_dist_sq:
								too_close = true
								break
					if too_close:
						break
				if too_close:
					break

			if too_close:
				continue

			var cell_key := Vector2i(gx, gz)
			if not grid.has(cell_key):
				grid[cell_key] = []
			grid[cell_key].append(Vector2(x, z))

			# Select tree type weighted for Florida Nature Coast woods
			var roll := rng.randf()
			var tree_type: StreetTree.TreeType
			var base_scale: float
			var height_ratio: float

			if roll < 0.32:
				tree_type = StreetTree.TreeType.TALL
				base_scale = rng.randf_range(0.95, 1.35)
				height_ratio = rng.randf_range(1.0, 1.25)
			elif roll < 0.58:
				tree_type = StreetTree.TreeType.LIVE_OAK
				base_scale = rng.randf_range(0.85, 1.25)
				height_ratio = rng.randf_range(0.9, 1.1)
			elif roll < 0.74:
				tree_type = StreetTree.TreeType.PALM
				base_scale = rng.randf_range(0.85, 1.20)
				height_ratio = rng.randf_range(0.95, 1.15)
			elif roll < 0.85:
				tree_type = StreetTree.TreeType.BROAD
				base_scale = rng.randf_range(0.90, 1.25)
				height_ratio = rng.randf_range(0.92, 1.12)
			elif roll < 0.92:
				tree_type = StreetTree.TreeType.CLUSTERED
				base_scale = rng.randf_range(0.90, 1.20)
				height_ratio = rng.randf_range(0.95, 1.10)
			elif roll < 0.97:
				tree_type = StreetTree.TreeType.STANDARD
				base_scale = rng.randf_range(0.90, 1.20)
				height_ratio = rng.randf_range(0.95, 1.10)
			else:
				tree_type = StreetTree.TreeType.COMPACT
				base_scale = rng.randf_range(0.85, 1.15)
				height_ratio = rng.randf_range(0.95, 1.10)

			var rot_y := rng.randf_range(0.0, TAU)
			var scale_vec := Vector3(base_scale, base_scale * height_ratio, base_scale)
			var tree_xform := Transform3D(
				Basis(Vector3.UP, rot_y).scaled(scale_vec), Vector3(x, 0.0, z)
			)

			var dx_box := maxf(0.0, maxf(-100.0 - x, x - 168.0))
			var dz_box := maxf(0.0, maxf(-60.0 - z, z - 64.0))
			var dist := sqrt(dx_box * dx_box + dz_box * dz_box)
			var near := 1 if dist <= shadow_tree_distance else 0
			var tile_key := Vector3i(
				int(floor(x / forest_tile_size)), int(floor(z / forest_tile_size)), near
			)
			if not groups.has(tile_key):
				groups[tile_key] = {}
			var bucket: Dictionary = groups[tile_key]
			if not bucket.has(tree_type):
				bucket[tree_type] = [] as Array[Transform3D]
			bucket[tree_type].append(tree_xform)

	_build_multimeshes(groups)


func _build_multimeshes(groups: Dictionary) -> void:
	var parts := _get_variant_mesh_parts()
	var mm_container := Node3D.new()
	mm_container.name = "TreeMultiMeshes"
	add_child(mm_container)

	for key: Vector3i in groups:
		var is_near := key.z == 1
		var variant_transforms: Dictionary = groups[key]
		for tree_type in variant_transforms:
			var xforms: Array = variant_transforms[tree_type]
			var count: int = xforms.size()
			var v_parts: Array = parts[tree_type]
			for part_idx in range(v_parts.size()):
				var part: Dictionary = v_parts[part_idx]
				var mmi := MultiMeshInstance3D.new()
				mmi.name = (
					"TreeMultiMesh_%d_%d_%s_%s_%d"
					% [
						key.x,
						key.y,
						"Near" if is_near else "Far",
						StreetTree.TreeType.keys()[tree_type],
						part_idx
					]
				)
				if forest_visibility_range_end > 0.0:
					# Godot measures the range to the tile's AABB center. Pad by the tile
					# half-diagonal so tiling never hides a tree a per-tree range would keep.
					mmi.visibility_range_end = (
						forest_visibility_range_end + forest_tile_size * sqrt(0.5)
					)
					mmi.visibility_range_end_margin = forest_visibility_range_end_margin
					mmi.visibility_range_fade_mode = (GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
				mmi.cast_shadow = (
					GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					if is_near
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				)
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part.mesh
				mm.instance_count = count
				for i in range(count):
					var instance_xform: Transform3D = (
						(xforms[i] as Transform3D) * (part.xform as Transform3D)
					)
					mm.set_instance_transform(i, instance_xform)
				mmi.multimesh = mm
				mm_container.add_child(mmi)


static func _get_variant_mesh_parts() -> Dictionary:
	if not _variant_parts_cache.is_empty():
		return _variant_parts_cache

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.18, 1.0)
	trunk_mat.roughness = 0.95

	var leaves_std := StandardMaterial3D.new()
	leaves_std.albedo_color = Color(0.22, 0.42, 0.18, 1.0)
	leaves_std.roughness = 0.9

	var leaves_tall := StandardMaterial3D.new()
	leaves_tall.albedo_color = Color(0.18, 0.38, 0.16, 1.0)
	leaves_tall.roughness = 0.9

	var leaves_broad := StandardMaterial3D.new()
	leaves_broad.albedo_color = Color(0.25, 0.44, 0.19, 1.0)
	leaves_broad.roughness = 0.9

	var leaves_clustered := StandardMaterial3D.new()
	leaves_clustered.albedo_color = Color(0.2, 0.4, 0.17, 1.0)
	leaves_clustered.roughness = 0.9

	var leaves_compact := StandardMaterial3D.new()
	leaves_compact.albedo_color = Color(0.24, 0.45, 0.21, 1.0)
	leaves_compact.roughness = 0.9

	var m_trunk_std := CylinderMesh.new()
	m_trunk_std.material = trunk_mat
	m_trunk_std.radial_segments = 10
	m_trunk_std.rings = 1
	m_trunk_std.top_radius = 0.25
	m_trunk_std.bottom_radius = 0.3
	m_trunk_std.height = 2.0

	var m_foliage_std := SphereMesh.new()
	m_foliage_std.material = leaves_std
	m_foliage_std.radial_segments = 16
	m_foliage_std.rings = 8
	m_foliage_std.radius = 1.4
	m_foliage_std.height = 2.5

	var m_trunk_tall := CylinderMesh.new()
	m_trunk_tall.material = trunk_mat
	m_trunk_tall.radial_segments = 10
	m_trunk_tall.rings = 1
	m_trunk_tall.top_radius = 0.22
	m_trunk_tall.bottom_radius = 0.28
	m_trunk_tall.height = 2.6

	var m_foliage_tall := SphereMesh.new()
	m_foliage_tall.material = leaves_tall
	m_foliage_tall.radial_segments = 16
	m_foliage_tall.rings = 8
	m_foliage_tall.radius = 1.25
	m_foliage_tall.height = 3.2

	var m_trunk_broad := CylinderMesh.new()
	m_trunk_broad.material = trunk_mat
	m_trunk_broad.radial_segments = 10
	m_trunk_broad.rings = 1
	m_trunk_broad.top_radius = 0.28
	m_trunk_broad.bottom_radius = 0.35
	m_trunk_broad.height = 1.8

	var m_foliage_broad := SphereMesh.new()
	m_foliage_broad.material = leaves_broad
	m_foliage_broad.radial_segments = 16
	m_foliage_broad.rings = 8
	m_foliage_broad.radius = 1.8
	m_foliage_broad.height = 2.2

	var m_trunk_clustered := CylinderMesh.new()
	m_trunk_clustered.material = trunk_mat
	m_trunk_clustered.radial_segments = 10
	m_trunk_clustered.rings = 1
	m_trunk_clustered.top_radius = 0.25
	m_trunk_clustered.bottom_radius = 0.32
	m_trunk_clustered.height = 2.0

	var m_foliage_clustered_main := SphereMesh.new()
	m_foliage_clustered_main.material = leaves_clustered
	m_foliage_clustered_main.radial_segments = 16
	m_foliage_clustered_main.rings = 8
	m_foliage_clustered_main.radius = 1.3
	m_foliage_clustered_main.height = 2.3

	var m_foliage_clustered_side := SphereMesh.new()
	m_foliage_clustered_side.material = leaves_clustered
	m_foliage_clustered_side.radial_segments = 16
	m_foliage_clustered_side.rings = 8
	m_foliage_clustered_side.radius = 1.05
	m_foliage_clustered_side.height = 1.9
	var m_trunk_compact := CylinderMesh.new()
	m_trunk_compact.material = trunk_mat
	m_trunk_compact.radial_segments = 10
	m_trunk_compact.rings = 1
	m_trunk_compact.top_radius = 0.2
	m_trunk_compact.bottom_radius = 0.25
	m_trunk_compact.height = 1.6

	var m_foliage_compact := SphereMesh.new()
	m_foliage_compact.material = leaves_compact
	m_foliage_compact.radial_segments = 16
	m_foliage_compact.rings = 8
	m_foliage_compact.radius = 1.15
	m_foliage_compact.height = 2.0

	var t1: Node = BLEND_TREE1.instantiate()
	var t2: Node = BLEND_TREE2.instantiate()

	var oak_foliage_mesh := (t1.get_node("Foliage") as MeshInstance3D).mesh.duplicate() as ArrayMesh
	var oak_mats := StreetTree._get_or_create_live_oak_materials()
	for s in range(mini(oak_mats.size(), oak_foliage_mesh.get_surface_count())):
		oak_foliage_mesh.surface_set_material(s, oak_mats[s])

	_variant_parts_cache = {
		StreetTree.TreeType.STANDARD:
		[
			{"mesh": m_trunk_std, "xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))},
			{"mesh": m_foliage_std, "xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.8, 0.0))},
		],
		StreetTree.TreeType.TALL:
		[
			{"mesh": m_trunk_tall, "xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.3, 0.0))},
			{"mesh": m_foliage_tall, "xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 3.6, 0.0))},
		],
		StreetTree.TreeType.BROAD:
		[
			{
				"mesh": m_trunk_broad,
				"xform":
				Transform3D(
					Basis.from_scale(Vector3(1.0, 1.15, 1.0)), Vector3(0.0, 0.9 * 1.15, 0.0)
				)
			},
			{
				"mesh": m_foliage_broad,
				"xform":
				Transform3D(
					Basis.from_scale(Vector3(1.0, 1.15, 1.0)), Vector3(0.0, 2.6 * 1.15, 0.0)
				)
			},
		],
		StreetTree.TreeType.CLUSTERED:
		[
			{
				"mesh": m_trunk_clustered,
				"xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
			},
			{
				"mesh": m_foliage_clustered_main,
				"xform": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.8, -0.2))
			},
			{
				"mesh": m_foliage_clustered_side,
				"xform": Transform3D(Basis.IDENTITY, Vector3(0.5, 2.5, 0.3))
			},
		],
		StreetTree.TreeType.COMPACT:
		[
			{
				"mesh": m_trunk_compact,
				"xform":
				Transform3D(
					Basis.from_scale(Vector3(1.0, 1.25, 1.0)), Vector3(0.0, 0.8 * 1.25, 0.0)
				)
			},
			{
				"mesh": m_foliage_compact,
				"xform":
				Transform3D(
					Basis.from_scale(Vector3(1.0, 1.25, 1.0)), Vector3(0.0, 2.3 * 1.25, 0.0)
				)
			},
		],
		StreetTree.TreeType.PALM:
		[
			{"mesh": (t2.get_node("Trunk") as MeshInstance3D).mesh, "xform": Transform3D.IDENTITY},
			{
				"mesh": (t2.get_node("FoliageGreen") as MeshInstance3D).mesh,
				"xform": Transform3D.IDENTITY
			},
			{
				"mesh": (t2.get_node("FoliageDead") as MeshInstance3D).mesh,
				"xform": Transform3D.IDENTITY
			},
			{
				"mesh": (t2.get_node("Crown") as MeshInstance3D).mesh,
				"xform":
				Transform3D(Basis.from_scale(Vector3(1.0, 0.72, 1.0)), Vector3(0.05, 7.18, 0.02))
			},
		],
		StreetTree.TreeType.LIVE_OAK:
		[
			{"mesh": (t1.get_node("Trunk") as MeshInstance3D).mesh, "xform": Transform3D.IDENTITY},
			{"mesh": (t1.get_node("Mulch") as MeshInstance3D).mesh, "xform": Transform3D.IDENTITY},
			{"mesh": oak_foliage_mesh, "xform": Transform3D.IDENTITY},
		],
	}

	t1.free()
	t2.free()
	# Primitive meshes carry no LODs (the .blend trees import with them). Rebuild the
	# cylinders and spheres as ArrayMeshes so distant tiles draw simplified geometry.
	for v_parts: Array in _variant_parts_cache.values():
		for part: Dictionary in v_parts:
			if part.mesh is PrimitiveMesh:
				part.mesh = _with_lods(part.mesh)
	return _variant_parts_cache


static func _with_lods(mesh: PrimitiveMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays(), [], {}, mesh.material)
	# Same angles as the scene importer's defaults.
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()


func _build_fence() -> void:
	if not fence_enabled:
		return

	# 1. North Forest Fence - runs in front of the northern forest
	var north_fence := FENCE_SCENE.instantiate() as ChainlinkFence
	north_fence.name = "NorthForestFence"
	north_fence.mode = ChainlinkFence.Mode.POLYLINE
	north_fence.fence_height = fence_height
	north_fence.polyline_points = PackedVector3Array(
		[
			Vector3(-100.0, 0.0, -21.75),
			Vector3(-100.0, 0.0, -60.0),
			Vector3(150.0, 0.0, -60.0),
			Vector3(150.0, 0.0, -21.75),
		]
	)
	add_child(north_fence)
	north_fence.build_fence()

	# 2. South Forest Fence - runs in front of the southern forest
	var south_fence := FENCE_SCENE.instantiate() as ChainlinkFence
	south_fence.name = "SouthForestFence"
	south_fence.mode = ChainlinkFence.Mode.POLYLINE
	south_fence.fence_height = fence_height
	south_fence.polyline_points = PackedVector3Array(
		[
			Vector3(-100.0, 0.0, 21.75),
			Vector3(-100.0, 0.0, 64.0),
			Vector3(168.0, 0.0, 64.0),
			Vector3(168.0, 0.0, 24.0),
			Vector3(150.0, 0.0, 21.75),
		]
	)
	add_child(south_fence)
	south_fence.build_fence()


func _is_position_blocked(x: float, z: float, existing_trees: Array[Vector2]) -> bool:
	# Strictly forbid any trees inside the playable boundary (in front of the fence)
	# North playable area:
	if z < 0.0 and z > -62.5 and x > -102.5 and x < 152.5:
		return true

	# South playable area:
	if z >= 0.0 and z < 66.5 and x > -102.5 and x < 170.5:
		return true

	var clearance := 2.2
	for zone in EXCLUSION_ZONES:
		if (
			x + clearance >= zone[0]
			and x - clearance <= zone[1]
			and z + clearance >= zone[2]
			and z - clearance <= zone[3]
		):
			return true

	for pt in existing_trees:
		var d2 := (x - pt.x) * (x - pt.x) + (z - pt.y) * (z - pt.y)
		if d2 < 16.0:  # 4m distance from street trees
			return true

	return false


func _get_existing_tree_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var trees_node := get_node_or_null("../Trees")
	if trees_node:
		for child in trees_node.get_children():
			if child is Node3D:
				var n3d := child as Node3D
				var p := n3d.global_position if is_inside_tree() else n3d.position
				positions.append(Vector2(p.x, p.z))
	return positions
