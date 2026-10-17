class_name ParkingLot
extends Node3D

const STALL_SPACING := 4.0
const ROWS := [
	{"z": -28.5, "x0": -18.0, "count": 9, "nose": -1.0, "serves": &"walgroins"},  # N row, nose -Z
	{"z": -14.5, "x0": -18.0, "count": 6, "nose": 1.0, "serves": &"walgroins"},  # S row, nose +Z
	{"z": -14.5, "x0": 28.0, "count": 4, "nose": 1.0, "serves": &"taco_hell"},  # Taco row, nose +Z
]
const ENTRANCES: Dictionary[StringName, Vector3] = {
	&"walgroins": Vector3(-3, 0, -32), &"taco_hell": Vector3(31.5, 0, -27.8)
}
const TURN_IN_START := Vector3(17.0, 0.0, -5.6)
const ENTRY_X := 13.0
const EXIT_X := 9.0
const WAIT_POINT := Vector3(9.0, 0.0, -9.6)
const MERGE_END := Vector3(5.0, 0.0, -5.6)
const AISLE_Z_WB := -23.0
const AISLE_Z_EB := -20.0
const AISLE_WB_Z := AISLE_Z_WB
const AISLE_EB_Z := AISLE_Z_EB
const POACH_PENALTY := 1000.0
const JITTER := 5.0
const V_LOT := 4.5
const V_PARK := 1.5

const BK_TURN_IN_START := Vector3(-45.0, 0.0, 5.6)
const BK_WAIT_POINT := Vector3(-40.5, 0.0, 9.6)
const BK_MERGE_END := Vector3(-36.5, 0.0, 5.6)
const TACO_DT_ORDER_DIST := 38.5
const TACO_DT_PICKUP_DIST := 75.1
const BK_DT_ORDER_DIST := 75.5
const BK_DT_PICKUP_DIST := 77.0
var poach_penalty: float = POACH_PENALTY
var jitter: float = JITTER

var spots: Array[ParkingSpot] = []
signal spot_changed(spot: ParkingSpot)


static func aisle_z_for_entry(spot) -> float:
	var sx: float = 0.0
	if spot is ParkingSpot:
		sx = spot.transform.origin.x
	elif spot is Transform3D:
		sx = spot.origin.x
	elif spot is Vector3 or spot is Vector2:
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
	else:
		push_error("ParkingLot.aisle_z_for_entry: unsupported spot argument %s" % str(spot))
		return AISLE_Z_WB
	return AISLE_Z_WB if sx < ENTRY_X else AISLE_Z_EB


static func exit_aisle_z(spot) -> float:
	var sx: float = 0.0
	if spot is ParkingSpot:
		sx = spot.transform.origin.x
	elif spot is Transform3D:
		sx = spot.origin.x
	elif spot is Vector3 or spot is Vector2:
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
	else:
		push_error("ParkingLot.exit_aisle_z: unsupported spot argument %s" % str(spot))
		return AISLE_Z_EB
	return AISLE_Z_EB if sx < ENTRY_X else AISLE_Z_WB


static func exit_sign(spot) -> float:
	var sx: float = 0.0
	if spot is ParkingSpot:
		sx = spot.transform.origin.x
	elif spot is Transform3D:
		sx = spot.origin.x
	elif spot is Vector3 or spot is Vector2:
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
	else:
		push_error("ParkingLot.exit_sign: unsupported spot argument %s" % str(spot))
		return 1.0
	return 1.0 if sx < EXIT_X else -1.0


static func entry_route(spot, radius := 4.0) -> Curve3D:
	var sx: float = 0.0
	var spot_pos := Vector3.ZERO
	if spot is ParkingSpot:
		spot_pos = spot.transform.origin
		sx = spot_pos.x
	elif spot is Transform3D:
		spot_pos = spot.origin
		sx = spot_pos.x
	elif spot is Vector3:
		spot_pos = spot
		sx = spot.x
	elif spot is Vector2:
		spot_pos = Vector3(spot.x, 0.05, spot.y)
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
		var sy: float = spot.get("y") if "y" in spot else 0.05
		var sz: float = spot.get("z") if "z" in spot else 0.0
		spot_pos = Vector3(sx, sy, sz)
	else:
		push_error("ParkingLot.entry_route: unsupported spot argument %s" % str(spot))
		return Curve3D.new()

	var aisle_z := aisle_z_for_entry(spot)
	var pts := PackedVector3Array(
		[
			TURN_IN_START,
			Vector3(ENTRY_X, 0.0, -5.6 - radius),
			Vector3(ENTRY_X, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func reverse_route(spot, radius := 4.0) -> Curve3D:
	var sx: float = 0.0
	var spot_pos := Vector3.ZERO
	if spot is ParkingSpot:
		spot_pos = spot.transform.origin
		sx = spot_pos.x
	elif spot is Transform3D:
		spot_pos = spot.origin
		sx = spot_pos.x
	elif spot is Vector3:
		spot_pos = spot
		sx = spot.x
	elif spot is Vector2:
		spot_pos = Vector3(spot.x, 0.05, spot.y)
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
		var sy: float = spot.get("y") if "y" in spot else 0.05
		var sz: float = spot.get("z") if "z" in spot else 0.0
		spot_pos = Vector3(sx, sy, sz)
	else:
		push_error("ParkingLot.reverse_route: unsupported spot argument %s" % str(spot))
		return Curve3D.new()

	var aisle_z := exit_aisle_z(spot)
	var sign_val := exit_sign(spot)
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * 6.0, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func exit_route(spot, radius := 4.0) -> Curve3D:
	var sx: float = 0.0
	if spot is ParkingSpot:
		sx = spot.transform.origin.x
	elif spot is Transform3D:
		sx = spot.origin.x
	elif spot is Vector3 or spot is Vector2:
		sx = spot.x
	elif "x" in spot:
		sx = spot.x
	else:
		push_error("ParkingLot.exit_route: unsupported spot argument %s" % str(spot))
		return Curve3D.new()

	var aisle_z := exit_aisle_z(spot)
	var sign_val := exit_sign(spot)
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * 6.0, 0.0, aisle_z),
			Vector3(EXIT_X, 0.0, aisle_z),
			WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func merge_route(radius := 4.0) -> Curve3D:
	var pts := PackedVector3Array(
		[
			WAIT_POINT,
			Vector3(EXIT_X, 0.0, -5.6),
			MERGE_END,
		]
	)
	return PathBuilder.build(pts, radius)


static func taco_hell_drive_thru_route(radius := 4.0) -> Curve3D:
	var pts := PackedVector3Array(
		[
			TURN_IN_START,
			Vector3(ENTRY_X, 0.0, -5.6 - radius),
			Vector3(ENTRY_X, 0.0, AISLE_Z_EB),
			Vector3(23.0, 0.0, AISLE_Z_EB),
			Vector3(23.0, 0.0, -43.0),
			Vector3(47.0, 0.0, -43.0),
			Vector3(47.0, 0.0, AISLE_Z_WB),
			Vector3(EXIT_X, 0.0, AISLE_Z_WB),
			WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func booger_king_drive_thru_route(radius := 4.0) -> Curve3D:
	var pts := PackedVector3Array(
		[
			BK_TURN_IN_START,
			Vector3(-43.5, 0.0, 9.6),
			Vector3(-43.5, 0.0, 22.0),
			Vector3(-54.25, 0.0, 22.0),
			Vector3(-54.25, 0.0, 45.0),
			Vector3(-29.75, 0.0, 45.0),
			Vector3(-29.75, 0.0, 22.0),
			Vector3(-40.5, 0.0, 22.0),
			BK_WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func booger_king_merge_route(radius := 4.0) -> Curve3D:
	var pts := PackedVector3Array(
		[
			BK_WAIT_POINT,
			Vector3(-40.5, 0.0, 5.6),
			BK_MERGE_END,
		]
	)
	return PathBuilder.build(pts, radius)


func _init() -> void:
	_build_spots()


func _ready() -> void:
	if spots.is_empty():
		_build_spots()


func _build_spots() -> void:
	spots.clear()
	var next_id := 0
	for row in ROWS:
		var z: float = row["z"]
		var x0: float = row["x0"]
		var count: int = row["count"]
		var nose: float = row["nose"]
		var serves_name: StringName = row["serves"]
		var rot_y: float = PI / 2.0 if nose < 0.0 else -PI / 2.0
		var spot_basis := Basis(Vector3.UP, rot_y)

		for i in range(count):
			var x: float = x0 + i * STALL_SPACING
			var spot := ParkingSpot.new()
			spot.id = next_id
			next_id += 1
			spot.transform = Transform3D(spot_basis, Vector3(x, 0.05, z))
			var serves_arr: Array[StringName] = [serves_name]
			spot.serves = serves_arr
			spot.lot = self
			spots.append(spot)


func get_free_spots() -> Array[ParkingSpot]:
	var free_spots: Array[ParkingSpot] = []
	for s in spots:
		if s.is_free():
			free_spots.append(s)
	return free_spots


func request_spot(car: Car, errand) -> ParkingSpot:
	if car == null or errand == null:
		push_error("ParkingLot.request_spot: car and errand must not be null")
		return null
	if car.spot != null:
		push_error("ParkingLot.request_spot: car already has a spot")
		return null
	if car.has_method("can_park") and not car.can_park():
		push_error("ParkingLot.request_spot: car cannot park")
		assert(car.can_park(), "car must be able to park")
		return null

	var dest: StringName = errand.destination
	if not ENTRANCES.has(dest):
		push_error("ParkingLot.request_spot: unknown destination %s" % dest)
		return null
	var entrance_3d: Vector3 = ENTRANCES[dest]
	var entrance_2d := Vector2(entrance_3d.x, entrance_3d.z)

	var best_spot: ParkingSpot = null
	var best_cost := INF

	for spot in spots:
		if not spot.is_free():
			continue
		var spot_2d := Vector2(spot.transform.origin.x, spot.transform.origin.z)
		var dist := spot_2d.distance_to(entrance_2d)
		var penalty := 0.0 if (dest in spot.serves) else poach_penalty
		var cost := dist + penalty + randf() * jitter
		if cost < best_cost:
			best_cost = cost
			best_spot = spot

	if best_spot == null:
		return null

	reserve(best_spot, car)
	return best_spot


func reserve(spot: ParkingSpot, car: Car) -> void:
	if spot == null or car == null:
		push_error("ParkingLot.reserve: spot and car must not be null")
		assert(spot != null and car != null, "spot and car must not be null")
		return
	if spot.state != ParkingSpot.State.FREE:
		push_error("ParkingLot.reserve: spot %d expected FREE, was %s" % [spot.id, spot.state])
		assert(spot.state == ParkingSpot.State.FREE, "spot must be FREE to reserve")
		return
	if spot.car != null:
		push_error("ParkingLot.reserve: spot %d already has car" % spot.id)
		assert(spot.car == null, "spot must have no car to reserve")
		return
	if car.spot != null:
		push_error("ParkingLot.reserve: car already has spot %d" % car.spot.id)
		assert(car.spot == null, "car must not already have a spot")
		return
	spot.state = ParkingSpot.State.RESERVED
	spot.car = car
	car.spot = spot
	spot_changed.emit(spot)


func occupy(spot: ParkingSpot) -> void:
	if spot == null:
		push_error("ParkingLot.occupy: spot must not be null")
		assert(spot != null, "spot must not be null")
		return
	if spot.state != ParkingSpot.State.RESERVED:
		push_error("ParkingLot.occupy: spot %d expected RESERVED, was %s" % [spot.id, spot.state])
		assert(spot.state == ParkingSpot.State.RESERVED, "spot must be RESERVED to occupy")
		return
	if spot.car == null:
		push_error("ParkingLot.occupy: spot %d has no car" % spot.id)
		assert(spot.car != null, "spot must have a car to occupy")
		return
	spot.state = ParkingSpot.State.OCCUPIED
	spot_changed.emit(spot)


func release(spot: ParkingSpot) -> void:
	if spot == null:
		push_error("ParkingLot.release: spot must not be null")
		assert(spot != null, "spot must not be null")
		return
	if spot.car != null:
		if is_instance_valid(spot.car):
			spot.car.spot = null
		spot.car = null
	spot.state = ParkingSpot.State.FREE
	spot_changed.emit(spot)


func check_invariants() -> int:
	var leaked := 0
	for spot in spots:
		if spot.state == ParkingSpot.State.FREE:
			if spot.car != null:
				leaked += 1
		else:
			if spot.car == null or not is_instance_valid(spot.car) or spot.car.spot != spot:
				leaked += 1
	return leaked
