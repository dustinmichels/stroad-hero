class_name ParkingSpot
extends RefCounted

enum State {
	FREE,
	RESERVED,
	OCCUPIED,
}

var id: int = 0
var transform: Transform3D = Transform3D.IDENTITY
var serves: Array[StringName] = []
var state := State.FREE
var car: Car = null
var lot: ParkingLot = null

var x: float:
	get:
		return transform.origin.x

var position: Vector3:
	get:
		return transform.origin


func is_free() -> bool:
	return state == State.FREE
