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
	CarType.F150,
	CarType.CYBERTRUCK,
	CarType.POLICE_SUV,
]

const BODY_SCENE_PATHS: Dictionary = {
	CarType.SEDAN: "res://cars/bodies/sedan.tscn",
	CarType.SUV: "res://cars/bodies/suv.tscn",
	CarType.PICKUP: "res://cars/bodies/pickup.tscn",
	CarType.HATCHBACK: "res://cars/bodies/hatchback.tscn",
	CarType.MINIVAN: "res://cars/bodies/minivan.tscn",
	CarType.SPORTS: "res://cars/bodies/sports.tscn",
	CarType.JEEP: "res://cars/bodies/jeep.tscn",
	CarType.F150: "res://cars/bodies/f150.tscn",
	CarType.CYBERTRUCK: "res://cars/bodies/cybertruck.tscn",
	CarType.POLICE_SUV: "res://cars/bodies/police_suv.tscn",
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
		var scene_path: String = BODY_SCENE_PATHS.get(type, "")
		if scene_path != "":
			_body_scenes[type] = load(scene_path)
	return _body_scenes.get(type)


const BODY_NODE_PATHS: Dictionary = {
	CarType.SEDAN: ^"Sedan",
	CarType.SUV: ^"SUV",
	CarType.PICKUP: ^"Pickup",
	CarType.HATCHBACK: ^"Hatchback",
	CarType.MINIVAN: ^"Minivan",
	CarType.SPORTS: ^"Sports",
	CarType.JEEP: ^"Jeep",
	CarType.F150: ^"F150",
	CarType.CYBERTRUCK: ^"Cybertruck",
	CarType.POLICE_SUV: ^"PoliceSUV",
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
	CarType.F150,
	CarType.CYBERTRUCK,
	CarType.POLICE_SUV,
]

const DEFAULT_WHEEL_RADIUS := 0.35
const WHEEL_RADII: Dictionary = {
	CarType.JEEP: 0.4,
	CarType.F150: 0.38,
	CarType.CYBERTRUCK: 0.40,
}

const SPORTS_SPAWN_CHANCE: float = 0.08


static func pick_passenger_car_type(allow_sports: bool = true) -> CarType:
	var rng := _get_rng()
	if allow_sports and rng.randf() < SPORTS_SPAWN_CHANCE:
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

const GRITTY_TYPES: Array[CarType] = [
	CarType.PICKUP,
	CarType.F150,
	CarType.JEEP,
]

static var _grit_roughness_texture: NoiseTexture2D = null
static var _grit_normal_texture: NoiseTexture2D = null
static var _gritty_paint_materials: Dictionary = {}

static var _rng: RandomNumberGenerator = null
static var _paint_materials: Dictionary = {}
static var _sports_stripe_materials: Dictionary = {}

@export var body_color: Color = Color(0, 0, 0, 0)
@export var is_gritty: bool = false
var _grit_determined: bool = false
var _paint_material: StandardMaterial3D = null


static func _get_grit_roughness_texture() -> NoiseTexture2D:
	if _grit_roughness_texture == null:
		_grit_roughness_texture = load("res://cars/textures/grit_roughness.tres")
	return _grit_roughness_texture


static func _get_grit_normal_texture() -> NoiseTexture2D:
	if _grit_normal_texture == null:
		_grit_normal_texture = load("res://cars/textures/grit_normal.tres")
	return _grit_normal_texture


static func get_paint_material(color: Color, gritty: bool = false) -> StandardMaterial3D:
	var cache: Dictionary = _gritty_paint_materials if gritty else _paint_materials
	if not cache.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if gritty:
			mat.metallic = 0.10
			mat.roughness = 0.70
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
			mat.roughness_texture = _get_grit_roughness_texture()
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mat.normal_enabled = true
			mat.normal_scale = 0.45
			mat.normal_texture = _get_grit_normal_texture()
		else:
			mat.roughness = 0.32
			mat.metallic = 0.15
		cache[color] = mat
	return cache[color]


static func get_sports_stripe_color(car_body_color: Color) -> Color:
	if car_body_color.get_luminance() > 0.55:
		return Color(0.10, 0.10, 0.12)
	return Color(0.96, 0.96, 0.98)


static func get_sports_stripe_material(car_body_color: Color) -> StandardMaterial3D:
	var stripe_col := get_sports_stripe_color(car_body_color)
	if not _sports_stripe_materials.has(stripe_col):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = stripe_col
		mat.roughness = 0.20
		mat.metallic = 0.25
		_sports_stripe_materials[stripe_col] = mat
	return _sports_stripe_materials[stripe_col]


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
		_exhaust_initialized = false
		exhaust_pipe = null
		exhaust_particles = null
		_exhaust_emitters.clear()
		headlamp = null
		_headlight_meshes.clear()
		_headlamps_on = -1
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


func set_gritty(val: bool) -> void:
	is_gritty = val
	_grit_determined = true
	_apply_paint_material()


func _apply_paint_material() -> void:
	if car_type in [CarType.CYBERTRUCK, CarType.POLICE_SUV]:
		# Preserve stainless steel and police livery from their body scenes.
		return
	if car_type == CarType.SPORTS:
		if not SPORTS_PAINT_PALETTE.has(body_color):
			var rng := _get_rng()
			body_color = SPORTS_PAINT_PALETTE[rng.randi_range(0, SPORTS_PAINT_PALETTE.size() - 1)]
	elif body_color == Color(0, 0, 0, 0):
		var rng := _get_rng()
		body_color = PAINT_PALETTE[rng.randi_range(0, PAINT_PALETTE.size() - 1)]
	if not _grit_determined:
		if GRITTY_TYPES.has(car_type):
			is_gritty = true
		elif car_type == CarType.SPORTS:
			is_gritty = false
		elif _get_rng().randf() < 0.35:
			is_gritty = true
		_grit_determined = true

	_paint_material = get_paint_material(body_color, is_gritty)

	var active_model := _get_node_for_type(car_type)
	if not active_model:
		active_model = get_active_model()
	if active_model:
		for child in active_model.get_children():
			if child is MeshInstance3D and child.name in PAINTED_NODE_NAMES:
				child.material_override = _paint_material
		if car_type == CarType.SPORTS:
			var stripe_mat := get_sports_stripe_material(body_color)
			for child in active_model.get_children():
				if (
					child is MeshInstance3D
					and (child.name == &"Stripe" or child.name.begins_with("Stripe"))
				):
					child.material_override = stripe_mat
