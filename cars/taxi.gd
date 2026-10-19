class_name TaxiCar
extends Car
const TAXI_YELLOW: Color = Color(0.98, 0.70, 0.02, 1.0)

@export var body_color: Color = TAXI_YELLOW


func _init() -> void:
	car_type = CarType.TAXI


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
	_p_type: CarType = CarType.TAXI
) -> void:
	super.setup(p_lane_id, p_lane_z, p_dir, p_start_x, p_lane_len, p_speed, CarType.TAXI)


func _apply_visual_type() -> void:
	car_type = CarType.TAXI
	var visuals := get_node_or_null("Visuals")
	if visuals:
		var taxi_model := visuals.get_node_or_null("Taxi")
		if taxi_model:
			taxi_model.visible = true
	super._apply_visual_type()
