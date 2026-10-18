class_name PassengerCar
extends Car

const MeshBakerScript = preload("res://addons/mesh_baker/mesh_baker.gd")

const PASSENGER_TYPES: Array[CarType] = [
	CarType.SEDAN,
	CarType.SUV,
	CarType.PICKUP,
	CarType.HATCHBACK,
	CarType.MINIVAN,
	CarType.SPORTS,
]

const BODY_SCENES: Dictionary = {
	CarType.SEDAN: preload("res://cars/bodies/sedan.tscn"),
	CarType.SUV: preload("res://cars/bodies/suv.tscn"),
	CarType.PICKUP: preload("res://cars/bodies/pickup.tscn"),
	CarType.HATCHBACK: preload("res://cars/bodies/hatchback.tscn"),
	CarType.MINIVAN: preload("res://cars/bodies/minivan.tscn"),
	CarType.SPORTS: preload("res://cars/bodies/sports.tscn"),
}

const BODY_NODE_PATHS: Dictionary = {
	CarType.SEDAN: ^"Sedan",
	CarType.SUV: ^"SUV",
	CarType.PICKUP: ^"Pickup",
	CarType.HATCHBACK: ^"Hatchback",
	CarType.MINIVAN: ^"Minivan",
	CarType.SPORTS: ^"Sports",
}

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
	if visuals and not _get_node_for_type(car_type):
		for model in visuals.get_children():
			visuals.remove_child(model)
			model.free()

		var body_scene: PackedScene = BODY_SCENES[car_type]
		var active_model := body_scene.instantiate() as Node3D
		assert(active_model != null)
		if OS.is_debug_build() and ProjectSettings.get_setting("debug/bake_preview", false):
			MeshBakerScript.bake_car_body(active_model)
		active_model.visible = true
		visuals.add_child(active_model)
		_wheels_initialized = false
		_signals_initialized = false

	super._apply_visual_type()
	_apply_paint_material()


func _get_node_for_type(type: CarType) -> Node3D:
	var visuals := get_node_or_null("Visuals")
	if not visuals or not BODY_NODE_PATHS.has(type):
		return null
	return visuals.get_node_or_null(BODY_NODE_PATHS[type]) as Node3D


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
