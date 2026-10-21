@tool
class_name Forest
extends Node3D
## Procedural forest that blankets the background behind the stroad,
## commercial buildings, parking lots, and highway tunnel portals with native
## woodland cover (slash pine, southern live oak, sabal palm, and mixed hardwoods).
## Each tree is an interactive collidable StreetTree with wind sway and collision rustle.

const TREE_SCENE: PackedScene = preload("res://props/tree.tscn")
const FENCE_SCENE: PackedScene = preload("res://props/chainlink_fence.tscn")

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
	var tree_index := 0

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

			var tree := TREE_SCENE.instantiate() as StreetTree
			tree.name = "ForestTree_%d" % tree_index
			tree_index += 1
			tree.tree_type = tree_type
			tree.position = Vector3(x, 0.0, z)
			tree.rotation.y = rng.randf_range(0.0, TAU)
			tree.scale = Vector3(base_scale, base_scale * height_ratio, base_scale)
			add_child(tree)


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
