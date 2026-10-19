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
	CarType.JEEP,
]

const BODY_SCENE_PATHS: Dictionary = {
	CarType.SEDAN: "res://cars/bodies/sedan.tscn",
	CarType.SUV: "res://cars/bodies/suv.tscn",
	CarType.PICKUP: "res://cars/bodies/pickup.tscn",
	CarType.HATCHBACK: "res://cars/bodies/hatchback.tscn",
	CarType.MINIVAN: "res://cars/bodies/minivan.tscn",
	CarType.SPORTS: "res://cars/bodies/sports.tscn",
	CarType.JEEP: "res://cars/bodies/jeep.tscn",
}

static var _body_scenes: Dictionary = {}

static var BODY_SCENES: Dictionary:
	get:
		for type in BODY_SCENE_PATHS:
			if not _body_scenes.has(type):
				_body_scenes[type] = load(BODY_SCENE_PATHS[type])
		return _body_scenes


static func get_body_scene(type: CarType) -> PackedScene:
	if not _body_scenes.has(type):
		var path: String = BODY_SCENE_PATHS.get(type, "")
		if path != "":
			_body_scenes[type] = load(path)
	return _body_scenes.get(type)


const BODY_NODE_PATHS: Dictionary = {
	CarType.SEDAN: ^"Sedan",
	CarType.SUV: ^"SUV",
	CarType.PICKUP: ^"Pickup",
	CarType.HATCHBACK: ^"Hatchback",
	CarType.MINIVAN: ^"Minivan",
	CarType.SPORTS: ^"Sports",
	CarType.JEEP: ^"Jeep",
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
	Color(0.92, 0.84, 0.22),  # Canary Yellow
	Color(0.08, 0.15, 0.32),  # Midnight Navy
	Color(0.82, 0.76, 0.65),  # Desert Sand
]
const SPORTS_PAINT_PALETTE: Array[Color] = [
	Color(0.88, 0.12, 0.12),  # Bright Red
	Color(0.98, 0.88, 0.05),  # Vibrant Yellow
	Color(0.95, 0.35, 0.60),  # Hot Pink
]

const REGULAR_PASSENGER_TYPES: Array[CarType] = [
	CarType.SEDAN,
	CarType.SUV,
	CarType.PICKUP,
	CarType.HATCHBACK,
	CarType.MINIVAN,
	CarType.JEEP,
]

const DEFAULT_WHEEL_RADIUS := 0.35
const WHEEL_RADII: Dictionary = {
	CarType.JEEP: 0.4,
}


static func pick_passenger_car_type(allow_sports: bool = true) -> CarType:
	var rng := _get_rng()
	if allow_sports and rng.randf() < 0.05:
		return CarType.SPORTS
	return REGULAR_PASSENGER_TYPES[rng.randi_range(0, REGULAR_PASSENGER_TYPES.size() - 1)]


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
	&"CenterPillarL",
	&"CenterPillarR",
	&"CPillarL",
	&"CPillarR",
	&"DPillarL",
	&"DPillarR",
	&"MirrorHousingL",
	&"MirrorHousingR",
	&"GrilleFace",
	&"FenderFL",
	&"FenderFR",
]

static var _rng: RandomNumberGenerator = null
static var _paint_materials: Dictionary = {}

@export var body_color: Color = Color(0, 0, 0, 0)
var _paint_material: StandardMaterial3D = null


static func get_paint_material(color: Color) -> StandardMaterial3D:
	if not _paint_materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.32
		mat.metallic = 0.15
		mat.albedo_color = color
		_paint_materials[color] = mat
	return _paint_materials[color]


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
		car_type = pick_passenger_car_type()

	var visuals := get_node_or_null("Visuals")
	if visuals and not _get_node_for_type(car_type):
		for model in visuals.get_children():
			visuals.remove_child(model)
			model.free()

		var body_scene: PackedScene = get_body_scene(car_type)
		var active_model := body_scene.instantiate() as Node3D
		assert(active_model != null)
		if OS.is_debug_build() and ProjectSettings.get_setting("debug/bake_preview", false):
			MeshBakerScript.bake_car_body(active_model)
		active_model.visible = true
		visuals.add_child(active_model)
		_wheels_initialized = false
		_signals_initialized = false
		_headlamps_initialized = false
		headlamp = null

	wheel_radius = WHEEL_RADII.get(car_type, DEFAULT_WHEEL_RADIUS)
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
	if car_type == CarType.SPORTS:
		if not SPORTS_PAINT_PALETTE.has(body_color):
			var rng := _get_rng()
			body_color = SPORTS_PAINT_PALETTE[rng.randi_range(0, SPORTS_PAINT_PALETTE.size() - 1)]
	elif body_color == Color(0, 0, 0, 0):
		var rng := _get_rng()
		body_color = PAINT_PALETTE[rng.randi_range(0, PAINT_PALETTE.size() - 1)]
	_paint_material = get_paint_material(body_color)

	var active_model := _get_node_for_type(car_type)
	if not active_model:
		active_model = get_active_model()
	if active_model:
		for child in active_model.get_children():
			if child is MeshInstance3D and child.name in PAINTED_NODE_NAMES:
				child.material_override = _paint_material
