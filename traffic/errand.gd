class_name Errand
extends RefCounted

var destination: StringName
var dwell_time: float


func _init(p_destination: StringName = &"", p_dwell_time: float = 0.0) -> void:
	destination = p_destination
	dwell_time = p_dwell_time


func is_drive_thru() -> bool:
	return destination == &"booger_king" or destination == &"taco_hell_drive_thru"


static func random() -> Errand:
	var dest: StringName
	var dwell: float
	if randf() < 0.6:
		dest = &"walgroins"
		dwell = randf_range(20.0, 45.0)
	else:
		dest = &"taco_hell"
		dwell = randf_range(15.0, 30.0)
	return new(dest, dwell)
