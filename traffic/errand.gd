class_name Errand
extends RefCounted

var destination: StringName
## Stop time at drive-thru windows and hotel drop-off; parked stays are set by TrafficManager.
var dwell_time: float


func _init(p_destination: StringName = &"", p_dwell_time: float = 0.0) -> void:
	destination = p_destination
	dwell_time = p_dwell_time


func is_drive_thru() -> bool:
	return destination == &"booger_king" or destination == &"taco_hell_drive_thru"


func is_smell() -> bool:
	return destination == &"smell_store" or destination == &"smell_gas"


func is_hotel_dropoff() -> bool:
	return (
		destination == &"cramped_inn_dropoff"
		or destination == &"cramped_inn_pickup"
		or destination == &"cramped_inn_dropoff_pickup"
	)


func is_dropoff() -> bool:
	return is_hotel_dropoff()


func is_frontage() -> bool:
	return (
		destination == &"frontage_retail"
		or destination == &"consumer_car_care"
		or destination == &"frontage_commercial"
		or destination == &"leaders_furniture"
		or destination == &"leaders_outdoor"
		or destination == &"car_care"
		or destination == &"checkers"
	)


static func random() -> Errand:
	var roll := randf()
	if roll < 0.50:
		return new(&"walgroins")
	elif roll < 0.70:
		return new(&"taco_hell")
	elif roll < 0.85:
		return new(&"smell_store")
	else:
		return new(&"smell_gas")
