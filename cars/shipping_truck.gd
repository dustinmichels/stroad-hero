class_name ShippingTruckCar
extends Car


func _init() -> void:
	car_type = CarType.SHIPPING_TRUCK
	wheel_radius = 0.5


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
	_p_type: CarType = CarType.SHIPPING_TRUCK
) -> void:
	super.setup(p_lane_id, p_lane_z, p_dir, p_start_x, p_lane_len, p_speed, CarType.SHIPPING_TRUCK)


func _apply_visual_type() -> void:
	car_type = CarType.SHIPPING_TRUCK
	var visuals := get_node_or_null("Visuals")
	if visuals:
		var truck_model := visuals.get_node_or_null("ShippingTruck")
		if truck_model:
			truck_model.visible = true
	super._apply_visual_type()
