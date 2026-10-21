class_name CarSweep
extends RefCounted

## 2D swept-footprint collision helper.
## Generates and caches oriented bounding boxes along a car's route (path or straight heading)
## and tests Separating Axis Theorem (SAT) polygon overlap.

const SWEEP_STEP := 0.5  # meters between sampled footprints along a car's route
const SWEEP_SIDE_MARGIN := 0.15  # lateral clearance added to a car's projected footprints
const SWEEP_INTENT_EXTRA := 4.0  # meters past the lookahead used to settle who crosses first
const BRAKE_ACCELERATION := 25.0
const REVERSE_CLEAR_TRAVEL := 1.0  # meters of another car's route a back-out route must avoid


## Braking lookahead (meters of travel) a car scans along its route.
static func lookahead(car: Car) -> float:
	var spd := absf(car.speed)
	return maxf(4.0, (spd * spd) / (2.0 * BRAKE_ACCELERATION) + 3.0)


static var sweep_hits: int = 0
static var sweep_reused: int = 0
static var sweep_allocs: int = 0


## Evaluates and caches oriented bounding boxes along the car's path or forward heading.
## Preserves car.sweep_rev to guarantee zero heap allocation on cache hits.
static func car_sweep(car: Car, cache: Dictionary) -> Dictionary:
	var rev: int = car.sweep_rev
	var car_id := car.get_instance_id()
	var cached: Dictionary = cache.get(car_id, {})
	if not cached.is_empty() and cached.get("rev", -1) == rev:
		sweep_hits += 1
		return cached
	if not cached.is_empty():
		sweep_reused += 1
	else:
		sweep_allocs += 1

	var backward := (
		car.speed < 0.0 or car.desired_speed < 0.0 or car.state == Car.State.REVERSING_OUT
	)
	var half_l := car.car_length * 0.5
	var half_w := car.car_width * 0.5
	var side := half_w + SWEEP_SIDE_MARGIN
	var heading := car.get_heading()
	var rects: Array[PackedVector2Array] = []
	var dists: Array[float] = []
	if not cached.is_empty():
		rects = cached.get("rects", [])
		rects.clear()
		dists = cached.get("dists", [])
		dists.clear()
	rects.append(footprint(car.global_position, heading, half_l, half_w))
	dists.append(0.0)
	var look := lookahead(car)
	var horizon := look + SWEEP_INTENT_EXTRA
	if car.state == Car.State.REVERSING_OUT and car.path != null:
		horizon = maxf(horizon, car.path_distance)
	var sign_dir := -1.0 if backward else 1.0
	if car.motion == Car.Motion.PATH and car.path != null:
		append_path_footprints(
			rects, dists, car.path, car.path_distance, sign_dir * horizon, half_l, side
		)
	else:
		var steps := int(ceil(horizon / SWEEP_STEP))
		var move := heading * sign_dir
		for k in range(1, steps + 1):
			var t := minf(k * SWEEP_STEP, horizon)
			rects.append(footprint(car.global_position + move * t, heading, half_l, side))
			dists.append(t)

	if cached.is_empty():
		var sweep := {
			"rev": rev,
			"rects": rects,
			"dists": dists,
			"look": look,
			"reach": horizon + car.car_length,
		}
		cache[car_id] = sweep
		return sweep
	else:
		cached["rev"] = rev
		cached["look"] = look
		cached["reach"] = horizon + car.car_length
		return cached


## Appends footprints at SWEEP_STEP intervals from path distance `from` over `travel`
## meters (negative = backward), stopping at the path end; dists gets travel so far.
static func append_path_footprints(
	rects: Array[PackedVector2Array],
	dists: Array[float],
	path: Curve3D,
	from: float,
	travel: float,
	half_l: float,
	half_w: float
) -> void:
	var length := path.get_baked_length()
	var look := absf(travel)
	var sign_dir := signf(travel)
	for k in range(1, int(ceil(look / SWEEP_STEP)) + 1):
		var t := minf(k * SWEEP_STEP, look)
		var d := from + sign_dir * t
		var dc := clampf(d, 0.0, length)
		var h := (
			path.sample_baked(clampf(dc + 0.05, 0.0, length))
			- path.sample_baked(clampf(dc - 0.05, 0.0, length))
		)
		if h.length_squared() < 0.000001:
			break
		rects.append(footprint(path.sample_baked(dc), h, half_l, half_w))
		dists.append(t)
		if dc != d:
			break


## Oriented 2D bounding box (4 vertices) in XZ space.
static func footprint(
	pos: Vector3, heading: Vector3, half_l: float, half_w: float
) -> PackedVector2Array:
	var f := Vector2(heading.x, heading.z).normalized()
	var s := Vector2(-f.y, f.x) * half_w
	f *= half_l
	var c := Vector2(pos.x, pos.z)
	return PackedVector2Array([c + f + s, c + f - s, c - f - s, c - f + s])


## Separating-axis test for two rectangles from footprint.
static func footprints_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var ra := a[0].distance_to(a[2]) * 0.5
	var rb := b[0].distance_to(b[2]) * 0.5
	if ((a[0] + a[2]) * 0.5).distance_to((b[0] + b[2]) * 0.5) > ra + rb:
		return false
	for poly in [a, b]:
		for i in 2:
			var e: Vector2 = poly[i + 1] - poly[i]
			var axis := Vector2(-e.y, e.x)
			var a_min := INF
			var a_max := -INF
			for p in a:
				var d := p.dot(axis)
				a_min = minf(a_min, d)
				a_max = maxf(a_max, d)
			var b_min := INF
			var b_max := -INF
			for p in b:
				var d := p.dot(axis)
				b_min = minf(b_min, d)
				b_max = maxf(b_max, d)
			if a_max < b_min or b_max < a_min:
				return false
	return true


## Computes candidate conflict points along mine's route against theirs.
## Returns Vector2(first_mine, first_theirs):
## - (INF, INF) if no conflict within mine's braking lookahead or already in their way.
## - (dist, -1.0) if hard conflict (mine intersects other's body b[0], or other is reversing and mine intersects b[j]).
## - (first_mine, first_theirs) if soft route intersection.
static func candidate_conflict_distance(
	mine: Dictionary, theirs: Dictionary, reversing_mine: bool, reversing_theirs: bool
) -> Vector2:
	var a: Array[PackedVector2Array] = mine["rects"]
	var da: Array[float] = mine["dists"]
	var look: float = mine["look"]
	var b: Array[PackedVector2Array] = theirs["rects"]
	for i in range(1, a.size()):
		if da[i] > look:
			break
		if footprints_overlap(a[i], b[0]):
			return Vector2(da[i], -1.0)

	if reversing_mine != reversing_theirs:
		if reversing_mine:
			return Vector2(INF, INF)
		for i in range(1, a.size()):
			if da[i] > look:
				break
			for j in range(1, b.size()):
				if footprints_overlap(a[i], b[j]):
					return Vector2(da[i], -1.0)
		return Vector2(INF, INF)

	var first_mine := INF
	var first_theirs := INF
	var db: Array[float] = theirs["dists"]
	for i in a.size():
		for j in range(1, b.size()):
			if da[i] >= first_mine and db[j] >= first_theirs:
				continue
			if footprints_overlap(a[i], b[j]):
				first_mine = minf(first_mine, da[i])
				first_theirs = minf(first_theirs, db[j])
	# Already in their way (nothing to gain by stopping) or conflict still beyond braking range.
	if first_mine == 0.0 or first_mine > look:
		return Vector2(INF, INF)
	return Vector2(first_mine, first_theirs)


## Distance along mine's route to stop for theirs, given arbitration result has_priority.
static func conflict_distance(
	mine: Dictionary,
	theirs: Dictionary,
	reversing_mine: bool,
	reversing_theirs: bool,
	has_priority: bool = false
) -> float:
	var c := candidate_conflict_distance(mine, theirs, reversing_mine, reversing_theirs)
	if c.x == INF:
		return INF
	if c.y < 0.0:
		return c.x
	return INF if has_priority else c.x


## Generates oriented 2D bounding boxes along a reverse path Curve3D from end to start.
static func reverse_path_footprints(
	route: Curve3D, car_length: float, car_width: float
) -> Array[PackedVector2Array]:
	var length := route.get_baked_length()
	var rects: Array[PackedVector2Array] = []
	var dists: Array[float] = []
	append_path_footprints(
		rects, dists, route, length, -length, car_length * 0.5, car_width * 0.5 + SWEEP_SIDE_MARGIN
	)
	return rects


## Tests whether a reverse path's footprints are clear of an obstacle car's swept footprints.
## Non-reversing cars are checked up to their stopping distance (or min_clear_travel).
## Reversing cars are checked along their entire back-out route.
static func reverse_route_clear(
	reverse_rects: Array[PackedVector2Array],
	other_sweep: Dictionary,
	other_speed: float,
	other_reversing: bool,
	min_clear_travel: float = REVERSE_CLEAR_TRAVEL
) -> bool:
	var other_rects: Array[PackedVector2Array] = other_sweep["rects"]
	var other_dists: Array[float] = other_sweep["dists"]
	var stop_dist := other_speed * other_speed / (2.0 * BRAKE_ACCELERATION) + SWEEP_STEP
	var clear_travel := maxf(min_clear_travel, stop_dist)
	for j in other_rects.size():
		if not other_reversing and other_dists[j] > clear_travel:
			break
		for r in reverse_rects:
			if footprints_overlap(r, other_rects[j]):
				return false
	return true
