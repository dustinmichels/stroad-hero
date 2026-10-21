class_name ParkingLot
extends Node3D

const STALL_SPACING := 4.0
const ROWS := [
	{"z": -32.5, "x0": -18.0, "count": 9, "nose": -1.0, "serves": &"walgroins", "site": &"north"},  # N row, nose -Z
	{"z": -18.5, "x0": -18.0, "count": 6, "nose": 1.0, "serves": &"walgroins", "site": &"north"},  # S row, nose +Z
	{"z": -18.5, "x0": 28.0, "count": 4, "nose": 1.0, "serves": &"taco_hell", "site": &"north"},  # Taco row, nose +Z
	{
		"z": 28.0,
		"x0": 22.0,
		"count": 3,
		"nose": 1.0,
		"serves": &"cramped_inn",
		"site": &"cramped_inn"
	},  # CI West row, nose +Z
	{
		"z": 28.0,
		"x0": 54.0,
		"count": 2,
		"nose": 1.0,
		"serves": &"cramped_inn",
		"site": &"cramped_inn"
	},  # CI East row, nose +Z
	{
		"z": 30.0,
		"x0": -19.0,
		"count": 8,
		"nose": 1.0,
		"serves": &"strip_mall",
		"site": &"strip_mall"
	},  # Mall row, nose +Z
	{"z": -31.0, "x0": -50.0, "count": 2, "nose": -1.0, "serves": &"smell_store", "site": &"smell"},  # Smell store row, nose -Z
	{
		"z": -25.2,
		"x0": -61.75,
		"count": 2,
		"spacing": 5.5,
		"nose": -1.0,
		"serves": &"smell_gas",
		"site": &"smell"
	},  # Smell gas row, nose -Z
	{
		"z": 38.0,
		"x0": 79.25,
		"count": 6,
		"spacing": 3.5,
		"nose": 1.0,
		"serves": &"frontage_retail",
		"site": &"frontage",
	},  # Frontage Retail (Leaders), nose +Z
	{
		"z": 41.0,
		"x0": 107.75,
		"count": 5,
		"spacing": 3.5,
		"nose": 1.0,
		"serves": &"consumer_car_care",
		"site": &"frontage",
	},  # Consumer Car Care, nose +Z
	{
		"z": 38.0,
		"x0": 142.0,
		"count": 2,
		"spacing": 3.0,
		"nose": 1.0,
		"serves": &"frontage_commercial",
		"site": &"frontage",
	},  # Frontage Commercial (Checkers), nose +Z
]
const ENTRANCES: Dictionary[StringName, Vector3] = {
	&"walgroins": Vector3(-3, 0, -36),
	&"taco_hell": Vector3(31.5, 0, -31.8),
	&"cramped_inn": Vector3(45.7, 0, 31.75),
	&"strip_mall": Vector3(-5, 0, 33.7),
	&"smell_store": Vector3(-48.0, 0, -34.0),
	&"smell_gas": Vector3(-59.0, 0, -25.2),
	&"frontage_retail": Vector3(88.0, 0.0, 43.0),
	&"leaders_furniture": Vector3(88.0, 0.0, 43.0),
	&"leaders_outdoor": Vector3(88.0, 0.0, 43.0),
	&"consumer_car_care": Vector3(123.2, 0.0, 45.0),
	&"car_care": Vector3(123.2, 0.0, 45.0),
	&"frontage_commercial": Vector3(147.5, 0.0, 43.5),
	&"checkers": Vector3(147.5, 0.0, 43.5),
}
const TURN_IN_START := Vector3(17.0, 0.0, -9.375)
const ENTRY_X := 13.0
const EXIT_X := 9.0
const WAIT_POINT := Vector3(9.0, 0.0, -13.375)
const MERGE_END := Vector3(5.0, 0.0, -9.375)
const AISLE_Z_WB := -27.0
const AISLE_Z_EB := -24.0
const AISLE_WB_Z := AISLE_Z_WB
const AISLE_EB_Z := AISLE_Z_EB
const POACH_PENALTY := 1000.0
const JITTER := 5.0
const V_LOT := 7.0
const V_PARK := 2.6

const BK_TURN_IN_START := Vector3(-45.0, 0.0, 9.375)
const BK_WAIT_POINT := Vector3(-40.5, 0.0, 13.375)
const BK_MERGE_END := Vector3(-36.5, 0.0, 9.375)
const TACO_DT_ORDER_DIST := 38.5
const TACO_DT_PICKUP_DIST := 75.1
const BK_DT_ORDER_DIST := 75.5
const BK_DT_PICKUP_DIST := 77.0
const CI_TURN_IN_START := Vector3(34.0, 0.0, 9.375)
const CI_ENTRY_X := 38.0
const CI_EXIT_X := 42.0
const CI_WAIT_POINT := Vector3(42.0, 0.0, 13.375)
const CI_MERGE_END := Vector3(46.0, 0.0, 9.375)
const CI_DROPOFF_STOP_DIST := 27.0
const FRONTAGE_TURN_IN_START := Vector3(61.75, 0.0, 9.375)
const FRONTAGE_ENTRY_X := 65.75
const FRONTAGE_EXIT_X := 70.25
const FRONTAGE_WAIT_POINT := Vector3(70.25, 0.0, 13.375)
const FRONTAGE_MERGE_END := Vector3(74.25, 0.0, 9.375)
const FRONTAGE_AISLE_EB := 29.75
const FRONTAGE_AISLE_WB := 26.25
const SM_TURN_IN_START := Vector3(-11.0, 0.0, 9.375)
const SM_ENTRY_X := -7.0
const SM_EXIT_X := -3.0
const SM_WAIT_POINT := Vector3(-3.0, 0.0, 13.375)
const SM_MERGE_END := Vector3(1.0, 0.0, 9.375)
const SMELL_TURN_IN_START := Vector3(-44.0, 0.0, -9.375)
const SMELL_ENTRY_X := -48.0
const SMELL_EXIT_X := -61.0
const SMELL_WAIT_POINT := Vector3(-61.0, 0.0, -13.375)
const SMELL_MERGE_END := Vector3(-65.0, 0.0, -9.375)
const SMELL_AISLE_Z := -19.0
## Lots south of the road, entered from and exited to eastbound Lane 3 through a
## two-way driveway: enter at entry_x, leave at exit_x. Aisle z values are
## Vector2(west of the driveway column, east of it); entry and exit aisles differ so
## arriving and departing cars do not share a line.
const SOUTH_LOTS: Dictionary[StringName, Dictionary] = {
	&"cramped_inn":
	{
		"turn_in": CI_TURN_IN_START,
		"entry_x": CI_ENTRY_X,
		"exit_x": CI_EXIT_X,
		"wait": CI_WAIT_POINT,
		"merge_end": CI_MERGE_END,
		"entry_aisle": Vector2(21.5, 20.5),
		"exit_aisle": Vector2(24.25, 23.5),
	},
	&"strip_mall":
	{
		"turn_in": SM_TURN_IN_START,
		"entry_x": SM_ENTRY_X,
		"exit_x": SM_EXIT_X,
		"wait": SM_WAIT_POINT,
		"merge_end": SM_MERGE_END,
		"entry_aisle": Vector2(23.5, 22.5),
		"exit_aisle": Vector2(26.25, 25.5),
	},
}
## Unified authoritative site registry
const SITES: Dictionary[StringName, Dictionary] = {
	&"north":
	{
		"kind": ParkingSite.Kind.PARKING_LOT,
		"served_destinations": [&"walgroins", &"taco_hell"],
		"lane_id": 0,
		"turn_in": TURN_IN_START,
		"entry_x": ENTRY_X,
		"exit_x": EXIT_X,
		"wait": WAIT_POINT,
		"merge_end": MERGE_END,
		"entry_aisle": Vector2(AISLE_Z_WB, AISLE_Z_EB),
		"exit_aisle": Vector2(AISLE_Z_EB, AISLE_Z_WB),
		"reverse_run": 6.0,
	},
	&"smell":
	{
		"kind": ParkingSite.Kind.PARKING_LOT,
		"served_destinations": [&"smell_store", &"smell_gas"],
		"lane_id": 0,
		"turn_in": SMELL_TURN_IN_START,
		"entry_x": SMELL_ENTRY_X,
		"exit_x": SMELL_EXIT_X,
		"wait": SMELL_WAIT_POINT,
		"merge_end": SMELL_MERGE_END,
		"entry_aisle": Vector2(SMELL_AISLE_Z, SMELL_AISLE_Z),
		"exit_aisle": Vector2(SMELL_AISLE_Z, SMELL_AISLE_Z),
		"reverse_run": -3.0,
	},
	&"cramped_inn":
	{
		"kind": ParkingSite.Kind.PARKING_LOT,
		"served_destinations": [&"cramped_inn"],
		"lane_id": 3,
		"turn_in": CI_TURN_IN_START,
		"entry_x": CI_ENTRY_X,
		"exit_x": CI_EXIT_X,
		"wait": CI_WAIT_POINT,
		"merge_end": CI_MERGE_END,
		"entry_aisle": Vector2(21.5, 20.5),
		"exit_aisle": Vector2(24.25, 23.5),
		"reverse_run": SOUTH_REVERSE_RUN,
	},
	&"strip_mall":
	{
		"kind": ParkingSite.Kind.PARKING_LOT,
		"served_destinations": [&"strip_mall"],
		"lane_id": 3,
		"turn_in": SM_TURN_IN_START,
		"entry_x": SM_ENTRY_X,
		"exit_x": SM_EXIT_X,
		"wait": SM_WAIT_POINT,
		"merge_end": SM_MERGE_END,
		"entry_aisle": Vector2(23.5, 22.5),
		"exit_aisle": Vector2(26.25, 25.5),
		"reverse_run": SOUTH_REVERSE_RUN,
	},
	&"taco_hell_drive_thru":
	{
		"kind": ParkingSite.Kind.DRIVE_THRU,
		"served_destinations": [&"taco_hell_drive_thru"],
		"lane_id": 0,
		"turn_in": TURN_IN_START,
		"entry_x": ENTRY_X,
		"exit_x": EXIT_X,
		"wait": WAIT_POINT,
		"merge_end": MERGE_END,
		"order_dist": TACO_DT_ORDER_DIST,
		"pickup_dist": TACO_DT_PICKUP_DIST,
	},
	&"booger_king":
	{
		"kind": ParkingSite.Kind.DRIVE_THRU,
		"served_destinations": [&"booger_king"],
		"lane_id": 3,
		"turn_in": BK_TURN_IN_START,
		"wait": BK_WAIT_POINT,
		"merge_end": BK_MERGE_END,
		"order_dist": BK_DT_ORDER_DIST,
		"pickup_dist": BK_DT_PICKUP_DIST,
	},
	&"cramped_inn_dropoff":
	{
		"kind": ParkingSite.Kind.DRIVE_THRU,
		"served_destinations":
		[&"cramped_inn_dropoff", &"cramped_inn_pickup", &"cramped_inn_dropoff_pickup"],
		"lane_id": 3,
		"turn_in": CI_TURN_IN_START,
		"entry_x": CI_ENTRY_X,
		"exit_x": CI_EXIT_X,
		"wait": CI_WAIT_POINT,
		"merge_end": CI_MERGE_END,
		"order_dist": -1.0,
		"pickup_dist": CI_DROPOFF_STOP_DIST,
	},
	&"frontage":
	{
		"kind": ParkingSite.Kind.PARKING_LOT,
		"served_destinations":
		[
			&"frontage_retail",
			&"leaders_furniture",
			&"leaders_outdoor",
			&"consumer_car_care",
			&"car_care",
			&"frontage_commercial",
			&"checkers",
		],
		"lane_id": 3,
		"turn_in": FRONTAGE_TURN_IN_START,
		"entry_x": FRONTAGE_ENTRY_X,
		"exit_x": FRONTAGE_EXIT_X,
		"wait": FRONTAGE_WAIT_POINT,
		"merge_end": FRONTAGE_MERGE_END,
		"reverse_run": SOUTH_REVERSE_RUN,
	},
}


static func get_site_for_destination(dest: StringName) -> StringName:
	for site_id in SITES:
		var site_cfg: Dictionary = SITES[site_id]
		var served: Array = site_cfg.get("served_destinations", [])
		if served.has(dest):
			return site_id
	return &""


static func get_site_cfg(site_id: StringName) -> Dictionary:
	return SITES.get(site_id, {})


static func get_drive_thru_order_dist(dest_or_site: StringName) -> float:
	var site_id := (
		dest_or_site if SITES.has(dest_or_site) else get_site_for_destination(dest_or_site)
	)
	return SITES.get(site_id, {}).get("order_dist", TACO_DT_ORDER_DIST)


static func get_drive_thru_pickup_dist(dest_or_site: StringName) -> float:
	var site_id := (
		dest_or_site if SITES.has(dest_or_site) else get_site_for_destination(dest_or_site)
	)
	return SITES.get(site_id, {}).get("pickup_dist", TACO_DT_PICKUP_DIST)


static func site_merge_route(site_id: StringName, radius: float = 4.0) -> Curve3D:
	var cfg := get_site_cfg(site_id)
	if cfg.is_empty():
		return merge_route(radius)
	var wait_pos: Vector3 = cfg["wait"]
	var lane_id: int = cfg.get("lane_id", 0)
	var curb_lane_z := -9.375 if lane_id == 0 else 9.375
	var exit_x: float = cfg.get("exit_x", wait_pos.x)
	var end_pos: Vector3 = cfg["merge_end"]
	var pts := PackedVector3Array(
		[
			wait_pos,
			Vector3(exit_x, 0.0, curb_lane_z),
			end_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func get_site_for_wait_point(lane_id: int, x: float) -> StringName:
	var best_site: StringName = &""
	var best_d := INF
	for site_id in SITES:
		var cfg: Dictionary = SITES[site_id]
		if cfg.get("lane_id", -1) != lane_id:
			continue
		var wait_pos: Vector3 = cfg.get("wait", Vector3.ZERO)
		var d := absf(wait_pos.x - x)
		if d < best_d:
			best_d = d
			best_site = site_id
	return best_site


static func merge_path(lane_id: int, x: float, radius: float = 4.0) -> Curve3D:
	var site_id := get_site_for_wait_point(lane_id, x)
	if site_id != &"":
		return site_merge_route(site_id, radius)
	return merge_route(radius)


static func merge_x(lane_id: int, x: float) -> float:
	var site_id := get_site_for_wait_point(lane_id, x)
	if site_id != &"":
		var cfg: Dictionary = SITES[site_id]
		return cfg.get("wait", Vector3.ZERO).x
	return 9.0 if lane_id == 0 else -40.5


static func drive_thru_route(dest: StringName, radius: float = 4.0) -> Curve3D:
	if dest == &"booger_king":
		return booger_king_drive_thru_route(radius)
	elif (
		dest == &"cramped_inn_dropoff"
		or dest == &"cramped_inn_pickup"
		or dest == &"cramped_inn_dropoff_pickup"
	):
		return cramped_inn_dropoff_route(2.5)
	return taco_hell_drive_thru_route(radius)


const SOUTH_REVERSE_RUN := 3.0


## Which south lot a spot belongs to, or &"" for other lots.
static func south_lot(spot) -> StringName:
	if spot is ParkingSpot:
		if spot.site_id == &"strip_mall" or spot.site_id == &"cramped_inn":
			return spot.site_id
		for site in SOUTH_LOTS:
			if spot.serves.has(site):
				return site
	return &""


static func is_smell(spot) -> bool:
	if spot is ParkingSpot:
		if spot.site_id == &"smell":
			return true
		for s in spot.serves:
			if s == &"smell_store" or s == &"smell_gas":
				return true
	return false


static func is_frontage(spot) -> bool:
	if spot is ParkingSpot:
		if spot.site_id == &"frontage":
			return true
		for s in spot.serves:
			if (
				s == &"frontage_retail"
				or s == &"consumer_car_care"
				or s == &"frontage_commercial"
				or s == &"leaders_furniture"
				or s == &"leaders_outdoor"
				or s == &"car_care"
				or s == &"checkers"
			):
				return true
	return false


static func _frontage_business_params(spot) -> Dictionary:
	if spot is ParkingSpot:
		for s in spot.serves:
			if s == &"frontage_retail" or s == &"leaders_furniture" or s == &"leaders_outdoor":
				return {"driveway_x": 88.0, "aisle_z": 33.5}
			elif s == &"consumer_car_care" or s == &"car_care":
				return {"driveway_x": 120.0, "aisle_z": 36.5}
			elif s == &"frontage_commercial" or s == &"checkers":
				return {"driveway_x": 150.0, "aisle_z": 33.5}
	var sx := _spot_position(spot).x
	if sx < 102.0:
		return {"driveway_x": 88.0, "aisle_z": 33.5}
	elif sx < 137.0:
		return {"driveway_x": 120.0, "aisle_z": 36.5}
	else:
		return {"driveway_x": 150.0, "aisle_z": 33.5}


static func lot_group(spot) -> StringName:
	if spot is ParkingSpot:
		if spot.site_id != &"":
			return spot.site_id
		var s_lot := south_lot(spot)
		if s_lot != &"":
			return s_lot
		if is_frontage(spot):
			return &"frontage"
		if is_smell(spot):
			return &"smell"
	return &"north"


static func dest_group(dest: StringName) -> StringName:
	var site_id := get_site_for_destination(dest)
	if site_id != &"":
		return site_id
	return &"north"


## Rule: Dorf parking lot does not allow Jeeps, sports cars, or taxis.
const DISALLOWED_DORF_LOT_CAR_TYPES: Array[Car.CarType] = [
	Car.CarType.JEEP,
	Car.CarType.SPORTS,
	Car.CarType.TAXI,
]


static func is_car_type_allowed_in_dorf_lot(type: Car.CarType) -> bool:
	return not (type in DISALLOWED_DORF_LOT_CAR_TYPES)


static func is_car_allowed_in_dorf_lot(car: Car) -> bool:
	if car == null:
		return false
	return is_car_type_allowed_in_dorf_lot(car.car_type)


static func _spot_position(spot) -> Vector3:
	if spot is ParkingSpot:
		return spot.transform.origin
	elif spot is Transform3D:
		return spot.origin
	elif spot is Vector3:
		return spot
	elif spot is Vector2:
		return Vector3(spot.x, 0.05, spot.y)
	elif "x" in spot:
		var sy: float = spot.get("y") if "y" in spot else 0.05
		var sz: float = spot.get("z") if "z" in spot else 0.0
		return Vector3(spot.x, sy, sz)
	push_error("ParkingLot: unsupported spot argument %s" % str(spot))
	return Vector3.ZERO


static func south_entry_aisle_z(site: StringName, sx: float) -> float:
	var lot_cfg: Dictionary = SOUTH_LOTS[site]
	var aisle: Vector2 = lot_cfg["entry_aisle"]
	return aisle.x if sx <= lot_cfg["entry_x"] else aisle.y


static func south_exit_aisle_z(site: StringName, sx: float) -> float:
	var lot_cfg: Dictionary = SOUTH_LOTS[site]
	var aisle: Vector2 = lot_cfg["exit_aisle"]
	return aisle.x if sx <= lot_cfg["exit_x"] else aisle.y


static func _south_exit_sign(site: StringName, sx: float) -> float:
	return 1.0 if sx < SOUTH_LOTS[site]["exit_x"] else -1.0


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
	if spot is ParkingSpot and spot.entry_route != null:
		return spot.entry_route
	if is_frontage(spot):
		return frontage_entry_route(spot, 1.5)
	var site := south_lot(spot)
	if site != &"":
		return south_entry_route(site, spot, radius)
	if is_smell(spot):
		return smell_entry_route(spot, radius)
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
			Vector3(ENTRY_X, 0.0, -9.375 - radius),
			Vector3(ENTRY_X, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func south_entry_route(site: StringName, spot, radius := 4.0) -> Curve3D:
	var lot_cfg: Dictionary = SOUTH_LOTS[site]
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var entry_x: float = lot_cfg["entry_x"]
	var aisle_z := south_entry_aisle_z(site, sx)
	var pts := PackedVector3Array(
		[
			lot_cfg["turn_in"],
			Vector3(entry_x, 0.0, 9.375 + radius),
			Vector3(entry_x, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func smell_entry_route(spot, radius := 4.0) -> Curve3D:
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var pts := PackedVector3Array(
		[
			SMELL_TURN_IN_START,
			Vector3(SMELL_ENTRY_X, 0.0, -9.375 - radius),
			Vector3(SMELL_ENTRY_X, 0.0, SMELL_AISLE_Z),
			Vector3(sx, 0.0, SMELL_AISLE_Z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func reverse_route(spot, radius := 4.0) -> Curve3D:
	if spot is ParkingSpot and spot.reverse_route != null:
		return spot.reverse_route
	if is_frontage(spot):
		return frontage_reverse_route(spot, 1.5)
	var site := south_lot(spot)
	if site != &"":
		return south_reverse_route(site, spot, radius)
	if is_smell(spot):
		return smell_reverse_route(spot, radius)
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


static func south_reverse_route(site: StringName, spot, radius := 4.0) -> Curve3D:
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var aisle_z := south_exit_aisle_z(site, sx)
	var sign_val := _south_exit_sign(site, sx)
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * SOUTH_REVERSE_RUN, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func smell_reverse_route(spot, radius := 4.0) -> Curve3D:
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var pts := PackedVector3Array(
		[
			Vector3(sx + 3.0, 0.0, SMELL_AISLE_Z),
			Vector3(sx, 0.0, SMELL_AISLE_Z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func exit_route(spot, radius := 4.0) -> Curve3D:
	if spot is ParkingSpot and spot.exit_route != null:
		return spot.exit_route
	if is_frontage(spot):
		return frontage_exit_route(spot, 1.5)
	var site := south_lot(spot)
	if site != &"":
		return south_exit_route(site, spot, radius)
	if is_smell(spot):
		return smell_exit_route(spot, radius)
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


static func south_exit_route(site: StringName, spot, radius := 4.0) -> Curve3D:
	var lot_cfg: Dictionary = SOUTH_LOTS[site]
	var sx := _spot_position(spot).x
	var aisle_z := south_exit_aisle_z(site, sx)
	var sign_val := _south_exit_sign(site, sx)
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * SOUTH_REVERSE_RUN, 0.0, aisle_z),
			Vector3(lot_cfg["exit_x"], 0.0, aisle_z),
			lot_cfg["wait"],
		]
	)
	return PathBuilder.build(pts, radius)


static func smell_exit_route(spot, radius := 4.0) -> Curve3D:
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var pts := PackedVector3Array(
		[
			Vector3(sx + 3.0, 0.0, SMELL_AISLE_Z),
			Vector3(SMELL_EXIT_X, 0.0, SMELL_AISLE_Z),
			SMELL_WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func smell_merge_route(radius := 4.0) -> Curve3D:
	return site_merge_route(&"smell", radius)


static func south_merge_route(site: StringName, radius := 4.0) -> Curve3D:
	return site_merge_route(site, radius)


static func frontage_merge_route(radius := 4.0) -> Curve3D:
	return site_merge_route(&"frontage", radius)


static func merge_route(radius := 4.0) -> Curve3D:
	return site_merge_route(&"north", radius)


static func taco_hell_drive_thru_route(radius := 4.0) -> Curve3D:
	var pts := PackedVector3Array(
		[
			TURN_IN_START,
			Vector3(ENTRY_X, 0.0, -9.375 - radius),
			Vector3(ENTRY_X, 0.0, AISLE_Z_EB),
			Vector3(23.0, 0.0, AISLE_Z_EB),
			Vector3(23.0, 0.0, -47.0),
			Vector3(47.0, 0.0, -47.0),
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
			Vector3(-43.5, 0.0, 13.375),
			Vector3(-43.5, 0.0, 26.0),
			Vector3(-54.25, 0.0, 26.0),
			Vector3(-54.25, 0.0, 49.0),
			Vector3(-29.75, 0.0, 49.0),
			Vector3(-29.75, 0.0, 26.0),
			Vector3(-40.5, 0.0, 26.0),
			BK_WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func booger_king_merge_route(radius := 4.0) -> Curve3D:
	return site_merge_route(&"booger_king", radius)


static func cramped_inn_dropoff_route(radius := 2.5) -> Curve3D:
	var pts := PackedVector3Array(
		[
			CI_TURN_IN_START,
			Vector3(CI_ENTRY_X, 0.0, 13.375),
			Vector3(CI_ENTRY_X, 0.0, 28.5),
			Vector3(48.0, 0.0, 28.5),
			Vector3(48.0, 0.0, 22.5),
			Vector3(CI_EXIT_X, 0.0, 22.5),
			CI_WAIT_POINT,
		]
	)
	return PathBuilder.build(pts, radius)


static func frontage_entry_route(spot, radius := 1.5) -> Curve3D:
	if spot is ParkingSpot and spot.entry_route != null:
		return spot.entry_route
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var params := _frontage_business_params(spot)
	var dw_x: float = params["driveway_x"]
	var aisle_z: float = params["aisle_z"]
	var pts := PackedVector3Array(
		[
			FRONTAGE_TURN_IN_START,
			Vector3(FRONTAGE_ENTRY_X, 0.0, 13.375),
			Vector3(FRONTAGE_ENTRY_X, 0.0, 22.0),
			Vector3(FRONTAGE_ENTRY_X, 0.0, FRONTAGE_AISLE_EB),
			Vector3(dw_x, 0.0, FRONTAGE_AISLE_EB),
			Vector3(dw_x, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func frontage_reverse_route(spot, radius := 1.5) -> Curve3D:
	if spot is ParkingSpot and spot.reverse_route != null:
		return spot.reverse_route
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var params := _frontage_business_params(spot)
	var dw_x: float = params["driveway_x"]
	var aisle_z: float = params["aisle_z"]
	var sign_val := 1.0 if sx < dw_x else -1.0
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * 3.0, 0.0, aisle_z),
			Vector3(sx, 0.0, aisle_z),
			spot_pos,
		]
	)
	return PathBuilder.build(pts, radius)


static func frontage_exit_route(spot, radius := 1.5) -> Curve3D:
	if spot is ParkingSpot and spot.exit_route != null:
		return spot.exit_route
	var spot_pos := _spot_position(spot)
	var sx := spot_pos.x
	var params := _frontage_business_params(spot)
	var dw_x: float = params["driveway_x"]
	var aisle_z: float = params["aisle_z"]
	var sign_val := 1.0 if sx < dw_x else -1.0
	var pts := PackedVector3Array(
		[
			Vector3(sx - sign_val * 3.0, 0.0, aisle_z),
			Vector3(dw_x, 0.0, aisle_z),
			Vector3(dw_x, 0.0, FRONTAGE_AISLE_WB),
			Vector3(74.0, 0.0, FRONTAGE_AISLE_WB),
			Vector3(FRONTAGE_EXIT_X, 0.0, FRONTAGE_AISLE_WB),
			Vector3(FRONTAGE_EXIT_X, 0.0, 22.0),
			FRONTAGE_WAIT_POINT,
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
		var site_name: StringName = row.get("site", &"north")
		var rot_y: float = PI / 2.0 if nose < 0.0 else -PI / 2.0
		var spot_basis := Basis(Vector3.UP, rot_y)

		var spacing: float = row.get("spacing", STALL_SPACING)
		for i in range(count):
			var x: float = x0 + i * spacing
			var spot := ParkingSpot.new()
			spot.id = next_id
			next_id += 1
			spot.transform = Transform3D(spot_basis, Vector3(x, 0.05, z))
			var serves_arr: Array[StringName] = []
			if row["serves"] is Array:
				for s in row["serves"]:
					serves_arr.append(StringName(s))
			else:
				var s_name: StringName = row["serves"]
				serves_arr.append(s_name)
				if s_name == &"frontage_retail":
					serves_arr.append(&"leaders_furniture")
					serves_arr.append(&"leaders_outdoor")
				elif s_name == &"consumer_car_care":
					serves_arr.append(&"car_care")
				elif s_name == &"frontage_commercial":
					serves_arr.append(&"checkers")
			spot.serves = serves_arr
			spot.site_id = site_name
			spot.lot = self
			spot.entry_route = ParkingLot.entry_route(spot)
			spot.reverse_route = ParkingLot.reverse_route(spot)
			spot.exit_route = ParkingLot.exit_route(spot)
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

	# Cars can only poach spots reachable through the same driveway as their errand.
	var target_group := dest_group(dest)
	for spot in spots:
		if not spot.is_free() or lot_group(spot) != target_group:
			continue
		if target_group == &"smell" and not (dest in spot.serves):
			continue
		if &"dorf" in spot.serves and not is_car_allowed_in_dorf_lot(car):
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
