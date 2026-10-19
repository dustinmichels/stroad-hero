class_name VanCar
extends Car


func _init() -> void:
	car_type = CarType.VAN


func can_park() -> bool:
	return false


func can_take_errands() -> bool:
	return false


func can_use_drive_thru() -> bool:
	return false


func setup(
	p_lane_id: int,
	p_lane_z: float,
	p_dir: float,
	p_start_x: float,
	p_lane_len: float,
	p_speed: float,
	_p_type: CarType = CarType.VAN
) -> void:
	super.setup(p_lane_id, p_lane_z, p_dir, p_start_x, p_lane_len, p_speed, CarType.VAN)


func _apply_visual_type() -> void:
	car_type = CarType.VAN
	var visuals := get_node_or_null("Visuals")
	if visuals:
		var van_model := visuals.get_node_or_null("Van")
		if van_model:
			van_model.visible = true
	super._apply_visual_type()
