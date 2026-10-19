class_name Errand
extends RefCounted

var destination: StringName
var dwell_time: float


func _init(p_destination: StringName = &"", p_dwell_time: float = 0.0) -> void:
	destination = p_destination
	dwell_time = p_dwell_time


func is_drive_thru() -> bool:
	return destination == &"booger_king" or destination == &"taco_hell_drive_thru"


func is_smell() -> bool:
	return destination == &"smell_store" or destination == &"smell_gas"


static func random() -> Errand:
	var roll := randf()
	if roll < 0.35:
		return new(&"walgroins", randf_range(20.0, 45.0))
	elif roll < 0.6:
		return new(&"taco_hell", randf_range(15.0, 30.0))
	elif roll < 0.8:
		return new(&"smell_store", randf_range(15.0, 35.0))
	else:
		return new(&"smell_gas", randf_range(12.0, 25.0))
