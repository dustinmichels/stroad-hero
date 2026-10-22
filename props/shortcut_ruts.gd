@tool
class_name ShortcutRuts
extends Node3D

## Dirt tire ruts worn into the grass by cars taking shortcuts: along every grass shortcut
## between lots, and across the verge (and lawn) at every sidewalk crossing.

## Rut heights just above the open ground and above the raised verge strip by the road.
const LAWN_Y := 0.055
const VERGE_Y := 0.105
const RUT_WIDTH := 0.35
const TRACK_SPACING := 1.55
const RUT_COLOR := Color(0.4, 0.31, 0.2)
const LINK_RADIUS := 0.8
## |z| of the verge strip between road shoulder and sidewalk, and of the sidewalk's lot side.
const VERGE_NEAR_Z := 11.85
const VERGE_FAR_Z := 13.0
const SIDEWALK_FAR_Z := 14.7


func _ready() -> void:
	if (
		has_node("ShortcutRutMesh")
		or (get_parent() != null and get_parent().has_node("BakedStaticMesh"))
	):
		return
	build_mesh()


func build_mesh() -> MeshInstance3D:
	var existing := get_node_or_null("ShortcutRutMesh") as MeshInstance3D
	if existing != null:
		return existing

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_color = RUT_COLOR
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)

	for track in _tracks():
		for offset in [-TRACK_SPACING * 0.5, TRACK_SPACING * 0.5]:
			_add_strip(surface, track, offset)

	var rut_mesh := MeshInstance3D.new()
	rut_mesh.name = "ShortcutRutMesh"
	rut_mesh.mesh = surface.commit()
	rut_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rut_mesh)
	return rut_mesh


## Centerlines of the worn tracks; each link corridor is laid once for both directions.
func _tracks() -> Array[PackedVector3Array]:
	var tracks: Array[PackedVector3Array] = []
	var seen := {}
	for link in ParkingLot.SHORTCUT_LINKS:
		if not link.get("ruts", true):
			continue
		var entry: Vector3 = link["grass_entry"]
		var exit: Vector3 = link["grass_exit"]
		var key := [str(entry), str(exit)]
		key.sort()
		if seen.has(str(key)):
			continue
		seen[str(key)] = true
		var pts := PackedVector3Array()
		var on_grass := false
		for w: Vector3 in link["waypoints"]:
			if w.is_equal_approx(entry):
				on_grass = true
			if on_grass:
				pts.append(Vector3(w.x, LAWN_Y, w.z))
			if w.is_equal_approx(exit):
				break
		tracks.append(PathBuilder.build(pts, LINK_RADIUS).get_baked_points())

	for site_id in ParkingLot.SIDEWALK_CROSSINGS:
		var crossing: Dictionary = ParkingLot.SIDEWALK_CROSSINGS[site_id]
		var side := -1.0 if ParkingLot.SITES[site_id].get("lane_id", 0) == 0 else 1.0
		for x: float in crossing["x"]:
			tracks.append(_straight(x, side * VERGE_FAR_Z, side * VERGE_NEAR_Z, VERGE_Y))
			if crossing.has("lawn_edge_z"):
				tracks.append(
					_straight(x, side * crossing["lawn_edge_z"], side * SIDEWALK_FAR_Z, LAWN_Y)
				)
	return tracks


func _straight(x: float, from_z: float, to_z: float, y: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(x, y, from_z), Vector3(x, y, to_z)])


## A flat strip `RUT_WIDTH` wide running alongside `track` at a lateral `offset`.
func _add_strip(surface: SurfaceTool, track: PackedVector3Array, offset: float) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in track.size():
		var prev := track[maxi(i - 1, 0)]
		var next := track[mini(i + 1, track.size() - 1)]
		var dir := Vector3(next.x - prev.x, 0.0, next.z - prev.z).normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		var center := track[i] + side * offset
		left.append(center - side * RUT_WIDTH * 0.5)
		right.append(center + side * RUT_WIDTH * 0.5)
	for i in track.size() - 1:
		for vertex in [left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
