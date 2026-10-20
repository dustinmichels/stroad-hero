class_name ParkingSite
extends RefCounted

## Site classification / shape
enum Kind {
	PARKING_LOT,
	DRIVE_THRU,
}

var id: StringName = &""
var kind: Kind = Kind.PARKING_LOT
var served_destinations: Array[StringName] = []
var lane_id: int = 0  # 0 (westbound curb) or 3 (eastbound curb)
var turn_in: Vector3 = Vector3.ZERO
var wait: Vector3 = Vector3.ZERO
var merge_end: Vector3 = Vector3.ZERO
var entry_x: float = 0.0
var exit_x: float = 0.0
var entry_aisle: Vector2 = Vector2.ZERO  # Vector2(aisle_west, aisle_east) or Vector2(aisle_z, aisle_z)
var exit_aisle: Vector2 = Vector2.ZERO  # Vector2(aisle_west, aisle_east) or Vector2(aisle_z, aisle_z)
var reverse_run: float = 3.0

# Optional custom route overrides or params
var entry_route: Curve3D = null
var drive_thru_route: Curve3D = null
var merge_route: Curve3D = null
