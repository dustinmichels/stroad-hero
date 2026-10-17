class_name PassengerCar
extends Car

const PASSENGER_TYPES: Array[CarType] = [
	CarType.SEDAN,
	CarType.SUV,
	CarType.PICKUP,
	CarType.HATCHBACK,
	CarType.MINIVAN,
	CarType.SPORTS,
]

const PAINT_PALETTE: Array[Color] = [
	Color(0.82, 0.16, 0.14),  # Classic Crimson Red
	Color(0.14, 0.38, 0.82),  # Cobalt Blue
	Color(0.18, 0.38, 0.24),  # Forest Green
	Color(0.92, 0.93, 0.94),  # Pearl White
	Color(0.75, 0.77, 0.80),  # Silver Metallic
	Color(0.20, 0.22, 0.25),  # Charcoal / Dark Slate
	Color(0.90, 0.36, 0.08),  # Vibrant Orange
	Color(0.48, 0.08, 0.16),  # Burgundy
	Color(0.48, 0.18, 0.70),  # Purple
	Color(0.94, 0.76, 0.08),  # Yellow
	Color(0.08, 0.15, 0.32),  # Midnight Navy
	Color(0.82, 0.76, 0.65),  # Desert Sand
]

const PAINTED_NODE_NAMES: Array[StringName] = [
	&"Body",
	&"Hood",
	&"FrontBumper",
	&"RearBumper",
	&"Trunk",
	&"Roof",
	&"RoofSpoiler",
	&"SlopingNose",
	&"BedWallL",
	&"BedWallR",
	&"Tailgate",
	&"FlareRL",
	&"FlareRR",
	&"SpoilerWing",
	&"FastbackL",
	&"FastbackR",
	&"APillarL",
	&"APillarR",
	&"CPillarL",
	&"CPillarR",
	&"DPillarL",
	&"DPillarR",
	&"MirrorHousingL",
	&"MirrorHousingR",
]

static var _rng: RandomNumberGenerator = null

@export var body_color: Color = Color(0, 0, 0, 0)
var _paint_material: StandardMaterial3D = null


static func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


func _ready() -> void:
	super._ready()
	_apply_paint_material()


func can_park() -> bool:
	return true


func can_take_errands() -> bool:
	return true


func can_use_drive_thru() -> bool:
	return true


func _apply_visual_type() -> void:
	if not PASSENGER_TYPES.has(car_type):
		var rng := _get_rng()
		car_type = PASSENGER_TYPES[rng.randi_range(0, PASSENGER_TYPES.size() - 1)]

	var visuals := get_node_or_null("Visuals")
	if visuals:
		for model in visuals.get_children():
			if model is Node3D:
				model.visible = false
		var active_model := _get_node_for_type(car_type)
		if active_model:
			active_model.visible = true

	super._apply_visual_type()
	_apply_paint_material()


func _get_node_for_type(type: CarType) -> Node3D:
	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return null
	match type:
		CarType.SEDAN:
			return visuals.get_node_or_null("Sedan")
		CarType.SUV:
			return visuals.get_node_or_null("SUV")
		CarType.PICKUP:
			return visuals.get_node_or_null("Pickup")
		CarType.HATCHBACK:
			return visuals.get_node_or_null("Hatchback")
		CarType.MINIVAN:
			return visuals.get_node_or_null("Minivan")
		CarType.SPORTS:
			return visuals.get_node_or_null("Sports")
	return null


func set_body_color(c: Color) -> void:
	body_color = c
	_apply_paint_material()


func _apply_paint_material() -> void:
	if body_color == Color(0, 0, 0, 0):
		var rng := _get_rng()
		body_color = PAINT_PALETTE[rng.randi_range(0, PAINT_PALETTE.size() - 1)]

	if _paint_material == null:
		_paint_material = StandardMaterial3D.new()
		_paint_material.roughness = 0.32
		_paint_material.metallic = 0.15
	_paint_material.albedo_color = body_color

	var active_model := _get_node_for_type(car_type)
	if not active_model:
		active_model = get_active_model()
	if active_model:
		for child in active_model.get_children():
			if child is MeshInstance3D and child.name in PAINTED_NODE_NAMES:
				child.material_override = _paint_material
