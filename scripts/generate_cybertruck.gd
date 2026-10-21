extends SceneTree
## Generates the faceted Cybertruck body meshes used by res://cars/bodies/cybertruck.tscn.
## Run: <godot> --headless --path . -s res://scripts/generate_cybertruck.gd
##
## Coordinates: +X forward, +Y up, +Z left. The body is a side profile extruded across the
## width; the greenhouse above the shoulder crease leans inward toward the roof ridge.

const OUT_BODY := "res://cars/bodies/cybertruck_body.tres"
const OUT_GLASS := "res://cars/bodies/cybertruck_glass.tres"
const OUT_TRIM := "res://cars/bodies/cybertruck_trim.tres"

const HALF_W := 1.0
const RIDGE_HALF_W := 0.80
const NOSE := Vector2(2.70, 1.00)
const APEX := Vector2(-0.35, 1.79)
const TAIL := Vector2(-2.70, 1.18)
const FRONT_AXLE_X := 1.75
const REAR_AXLE_X := -1.85
const BODY_BOTTOM := 0.50
const ARCH_TOP := 0.86
const ARCH_HALF_BOTTOM := 0.62
const ARCH_HALF_TOP := 0.36
const GLASS_OFFSET := 0.006
const PILLAR := 0.065
## Windshield base / front edge of the side glass.
const COWL_X := 1.58


func _init() -> void:
	_save(_build_body(), OUT_BODY)
	_save(_build_glass(), OUT_GLASS)
	_save(_build_trim(), OUT_TRIM)
	quit()


func _save(mesh: ArrayMesh, path: String) -> void:
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("Failed to save %s: %d" % [path, err])
	else:
		print("Saved ", path)


# --- Profile helpers -------------------------------------------------------


func _crease_y(x: float) -> float:
	return lerpf(NOSE.y, TAIL.y, (NOSE.x - x) / (NOSE.x - TAIL.x))


func _front_y(x: float) -> float:
	return lerpf(NOSE.y, APEX.y, (NOSE.x - x) / (NOSE.x - APEX.x))


func _rear_y(x: float) -> float:
	return lerpf(APEX.y, TAIL.y, (APEX.x - x) / (APEX.x - TAIL.x))


func _side_normal(side: float) -> Vector3:
	var n := Vector3(TAIL.x, TAIL.y, HALF_W) - Vector3(NOSE.x, NOSE.y, HALF_W)
	n = n.cross(Vector3(APEX.x, APEX.y, RIDGE_HALF_W) - Vector3(NOSE.x, NOSE.y, HALF_W))
	if n.z < 0.0:
		n = -n
	n = n.normalized()
	return Vector3(n.x, n.y, n.z * side)


## Point on the inward-leaning greenhouse side plane for profile coordinate p.
func _on_side(p: Vector2, side: float, offset: float = 0.0) -> Vector3:
	var n := _side_normal(1.0)
	var z := HALF_W - (n.x * (p.x - NOSE.x) + n.y * (p.y - NOSE.y)) / n.z
	return Vector3(p.x, p.y, z * side) + _side_normal(side) * offset


## Point on a sloped roof face: u runs from `from` to `to` in profile, v in [-1, 1] across.
func _on_slope(
	from: Vector2, from_w: float, to: Vector2, to_w: float, u: float, v: float, inset: float
) -> Vector3:
	var p := from.lerp(to, u)
	return Vector3(p.x, p.y, v * (lerpf(from_w, to_w, u) - inset))


# --- Geometry primitives ---------------------------------------------------


## Adds a convex planar polygon, flat shaded, facing `hint`.
func _face(st: SurfaceTool, pts: Array[Vector3], hint: Vector3) -> void:
	var n := Vector3.ZERO
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		n += Vector3(
			(a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)
		)
	if n.dot(hint) < 0.0:
		n = -n
	n = n.normalized()
	for i in range(1, pts.size() - 1):
		_tri(st, pts[0], pts[i], pts[i + 1], n)


## Godot front faces wind clockwise as seen from the front.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## Extrudes a simple (possibly concave) XY profile between z0 and z1.
## Edges listed in `skip_edges` (edge i runs from poly[i] to poly[i + 1]) get no wall.
func _extrude(
	st: SurfaceTool, poly: PackedVector2Array, z0: float, z1: float, skip_edges: Array = []
) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	assert(not idx.is_empty(), "Profile failed to triangulate")
	for i in range(0, idx.size(), 3):
		for z_n in [[z1, Vector3.BACK], [z0, Vector3.FORWARD]]:
			var z: float = z_n[0]
			var a := poly[idx[i]]
			var b := poly[idx[i + 1]]
			var c := poly[idx[i + 2]]
			_tri(st, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), z_n[1])
	var ccw := _signed_area(poly) > 0.0
	for i in poly.size():
		if i in skip_edges:
			continue
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var d := (b - a).normalized()
		var out := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		var n := Vector3(out.x, out.y, 0.0)
		var p0 := Vector3(a.x, a.y, z0)
		var p1 := Vector3(b.x, b.y, z0)
		var p2 := Vector3(b.x, b.y, z1)
		var p3 := Vector3(a.x, a.y, z1)
		_tri(st, p0, p1, p2, n)
		_tri(st, p0, p2, p3, n)


func _signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


func _box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var poly := PackedVector2Array(
		[
			Vector2(center.x - h.x, center.y - h.y),
			Vector2(center.x + h.x, center.y - h.y),
			Vector2(center.x + h.x, center.y + h.y),
			Vector2(center.x - h.x, center.y + h.y),
		]
	)
	_extrude(st, poly, center.z - h.z, center.z + h.z)


func _arch(
	cx: float, half_bottom: float, half_top: float, top: float, bottom: float
) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(cx + half_bottom, bottom),
			Vector2(cx + half_top, top),
			Vector2(cx - half_top, top),
			Vector2(cx - half_bottom, bottom),
		]
	)


# --- Parts -----------------------------------------------------------------


func _build_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Lower body: vertical sides with trapezoidal wheel arches cut out of the profile.
	var lower := PackedVector2Array([NOSE, TAIL, Vector2(TAIL.x, 0.58), Vector2(-2.66, 0.52)])
	lower.append_array(_arch(REAR_AXLE_X, ARCH_HALF_BOTTOM, ARCH_HALF_TOP, ARCH_TOP, BODY_BOTTOM))
	lower.append_array(_arch(FRONT_AXLE_X, ARCH_HALF_BOTTOM, ARCH_HALF_TOP, ARCH_TOP, BODY_BOTTOM))
	lower.append_array([Vector2(2.60, 0.52), Vector2(2.68, 0.62)])
	# Edge 0 (nose -> tail crease) is covered by the greenhouse.
	_extrude(st, lower, -HALF_W, HALF_W, [0])

	# Greenhouse: a single triangle in profile (nose, roof ridge, tail) with leaning sides.
	for side: float in [1.0, -1.0]:
		var n := Vector3(NOSE.x, NOSE.y, HALF_W * side)
		var a := Vector3(APEX.x, APEX.y, RIDGE_HALF_W * side)
		var t := Vector3(TAIL.x, TAIL.y, HALF_W * side)
		_face(st, [n, a, t], _side_normal(side))
	_face(
		st,
		[
			Vector3(NOSE.x, NOSE.y, HALF_W),
			Vector3(NOSE.x, NOSE.y, -HALF_W),
			Vector3(APEX.x, APEX.y, -RIDGE_HALF_W),
			Vector3(APEX.x, APEX.y, RIDGE_HALF_W),
		],
		Vector3(1, 3, 0)
	)
	_face(
		st,
		[
			Vector3(APEX.x, APEX.y, RIDGE_HALF_W),
			Vector3(APEX.x, APEX.y, -RIDGE_HALF_W),
			Vector3(TAIL.x, TAIL.y, -HALF_W),
			Vector3(TAIL.x, TAIL.y, HALF_W),
		],
		Vector3(-1, 3, 0)
	)
	return st.commit()


func _side_window_profile() -> Array[Vector2]:
	return [
		Vector2(COWL_X, _crease_y(COWL_X) + 0.05),
		Vector2(COWL_X, _front_y(COWL_X) - PILLAR),
		Vector2(-0.28, _front_y(-0.28) - PILLAR),
		Vector2(-0.45, _rear_y(-0.45) - PILLAR),
		Vector2(-1.05, _rear_y(-1.05) - PILLAR),
		Vector2(-1.18, _crease_y(-1.18) + 0.05),
	]


func _build_glass() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Windshield: runs up the front slope from the cowl almost to the roof ridge.
	var u0 := (NOSE.x - COWL_X) / (NOSE.x - APEX.x)
	var u1 := 0.97
	var front_n := Vector3(APEX.y - NOSE.y, NOSE.x - APEX.x, 0.0).normalized()
	var ws: Array[Vector3] = [
		_on_slope(NOSE, HALF_W, APEX, RIDGE_HALF_W, u0, 1.0, PILLAR),
		_on_slope(NOSE, HALF_W, APEX, RIDGE_HALF_W, u1, 1.0, PILLAR),
		_on_slope(NOSE, HALF_W, APEX, RIDGE_HALF_W, u1, -1.0, PILLAR),
		_on_slope(NOSE, HALF_W, APEX, RIDGE_HALF_W, u0, -1.0, PILLAR),
	]
	for i in ws.size():
		ws[i] += front_n * GLASS_OFFSET
	_face(st, ws, front_n)

	# Side windows lie flush on the leaning greenhouse sides.
	for side: float in [1.0, -1.0]:
		var pts: Array[Vector3] = []
		for p in _side_window_profile():
			pts.append(_on_side(p, side, GLASS_OFFSET))
		_face(st, pts, _side_normal(side))
	return st.commit()


func _build_trim() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Underbody / wheel-well liner fills the arch cutouts between the tires.
	_box(st, Vector3(0.0, 0.58, 0.0), Vector3(5.0, 0.56, 1.40))

	# Front and rear bumpers with chamfered lower edges.
	var front_bumper := PackedVector2Array(
		[
			Vector2(2.38, 0.30),
			Vector2(2.60, 0.30),
			Vector2(2.73, 0.40),
			Vector2(2.74, 0.62),
			Vector2(2.38, 0.62),
		]
	)
	_extrude(st, front_bumper, -0.97, 0.97)
	var rear_bumper := PackedVector2Array(
		[
			Vector2(-2.48, 0.30),
			Vector2(-2.48, 0.60),
			Vector2(-2.73, 0.60),
			Vector2(-2.73, 0.40),
			Vector2(-2.62, 0.30),
		]
	)
	_extrude(st, rear_bumper, -0.97, 0.97)

	# Tonneau (vault) cover over the bed, framed by the steel sail rails.
	var rear_n := Vector3(TAIL.y - APEX.y, APEX.x - TAIL.x, 0.0).normalized()
	var tonneau: Array[Vector3] = [
		_on_slope(APEX, RIDGE_HALF_W, TAIL, HALF_W, 0.14, 1.0, 0.09),
		_on_slope(APEX, RIDGE_HALF_W, TAIL, HALF_W, 0.98, 1.0, 0.09),
		_on_slope(APEX, RIDGE_HALF_W, TAIL, HALF_W, 0.98, -1.0, 0.09),
		_on_slope(APEX, RIDGE_HALF_W, TAIL, HALF_W, 0.14, -1.0, 0.09),
	]
	for i in tonneau.size():
		tonneau[i] += rear_n * GLASS_OFFSET
	_face(st, tonneau, rear_n)

	for side: float in [1.0, -1.0]:
		var z_in := (HALF_W - 0.05) * side
		var z_out := (HALF_W + 0.025) * side

		# Rocker cladding between the arches.
		var rocker := PackedVector2Array(
			[
				Vector2(FRONT_AXLE_X - 0.66, 0.36),
				Vector2(FRONT_AXLE_X - 0.62, 0.56),
				Vector2(REAR_AXLE_X + 0.62, 0.56),
				Vector2(REAR_AXLE_X + 0.66, 0.36),
			]
		)
		_extrude(st, rocker, minf(z_in, z_out), maxf(z_in, z_out))

		# Polygonal wheel-arch flares: outer band minus the arch opening.
		for cx: float in [FRONT_AXLE_X, REAR_AXLE_X]:
			var flare := _arch(cx, 0.76, 0.41, 0.94, 0.44)
			var inner := _arch(cx, 0.66, ARCH_HALF_TOP, ARCH_TOP, 0.44)
			inner.reverse()
			flare.append_array(inner)
			_extrude(st, flare, minf(z_in, z_out), maxf(z_in, z_out))

		# B-pillar strip over the side glass.
		var bx0 := 0.16
		var bx1 := 0.24
		var b_pillar: Array[Vector3] = [
			_on_side(Vector2(bx0, _crease_y(bx0) + 0.05), side, GLASS_OFFSET * 2.0),
			_on_side(Vector2(bx1, _crease_y(bx1) + 0.05), side, GLASS_OFFSET * 2.0),
			_on_side(Vector2(bx1, _front_y(bx1) - PILLAR), side, GLASS_OFFSET * 2.0),
			_on_side(Vector2(bx0, _front_y(bx0) - PILLAR), side, GLASS_OFFSET * 2.0),
		]
		_face(st, b_pillar, _side_normal(side))

		# Side mirror: stalk plus a wedge housing at the front corner of the side glass.
		_box(st, Vector3(COWL_X - 0.06, 1.15, (HALF_W + 0.02) * side), Vector3(0.08, 0.04, 0.10))
		_box(st, Vector3(COWL_X - 0.08, 1.17, (HALF_W + 0.11) * side), Vector3(0.12, 0.11, 0.14))
	return st.commit()
