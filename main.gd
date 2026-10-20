class_name Main
extends Node3D

@onready var mats: Mats = $Mats
@onready var hud: HUD = $HUD
@onready var blood_splats: Node3D = $BloodSplats
@onready var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("DirectionalLight3D")
@onready var streetlights_node: Node3D = get_node_or_null("Props/Streetlights")
var _baked_streetlights_unlit_mesh: Mesh = null
var _baked_streetlights_lit_mesh: Mesh = null
var _day_captured: bool = false
var _day_sky_top: Color = Color(0.35, 0.55, 0.85, 1.0)
var _day_sky_horizon: Color = Color(0.68, 0.75, 0.82, 1.0)
var _day_ground_bottom: Color = Color(0.2, 0.25, 0.22, 1.0)
var _day_ground_horizon: Color = Color(0.68, 0.75, 0.82, 1.0)
var _day_ambient_color: Color = Color(0.62, 0.7, 0.84, 1.0)
var _day_ambient_energy: float = 1.0
var _day_ambient_sky_contrib: float = 0.6
var _day_sun_color: Color = Color(1.0, 0.96, 0.88, 1.0)
var _day_sun_energy: float = 1.0
var _day_sun_rotation: Vector3 = Vector3.ZERO

const EVENING_SUN_ROTATION := Vector3(-0.16, 1.30, 0.0)

const DAY_SKY_TOP := Color(0.35, 0.55, 0.85, 1.0)
const DAY_SKY_HORIZON := Color(0.68, 0.75, 0.82, 1.0)
const DAY_GROUND_BOTTOM := Color(0.2, 0.25, 0.22, 1.0)
const DAY_GROUND_HORIZON := Color(0.68, 0.75, 0.82, 1.0)
const DAY_AMBIENT_COLOR := Color(0.62, 0.7, 0.84, 1.0)
const DAY_AMBIENT_ENERGY := 1.0
const DAY_AMBIENT_SKY_CONTRIB := 0.6
const DAY_SUN_COLOR := Color(1.0, 0.96, 0.88, 1.0)
const DAY_SUN_ENERGY := 1.0
const EVENING_SKY_TOP := Color(0.18, 0.22, 0.45, 1.0)
const EVENING_SKY_HORIZON := Color(0.96, 0.52, 0.22, 1.0)
const EVENING_GROUND_BOTTOM := Color(0.10, 0.11, 0.12, 1.0)
const EVENING_GROUND_HORIZON := Color(0.48, 0.30, 0.20, 1.0)
const EVENING_AMBIENT_COLOR := Color(0.68, 0.45, 0.35, 1.0)
const EVENING_AMBIENT_ENERGY := 0.7
const EVENING_AMBIENT_SKY_CONTRIB := 0.5
const EVENING_SUN_COLOR := Color(1.0, 0.58, 0.28, 1.0)
const EVENING_SUN_ENERGY := 0.75

const NIGHT_SKY_TOP := Color(0.02, 0.035, 0.075, 1.0)
const NIGHT_SKY_HORIZON := Color(0.07, 0.09, 0.15, 1.0)
const NIGHT_GROUND_BOTTOM := Color(0.015, 0.02, 0.03, 1.0)
const NIGHT_GROUND_HORIZON := Color(0.05, 0.07, 0.11, 1.0)
const NIGHT_AMBIENT_COLOR := Color(0.18, 0.22, 0.32, 1.0)
const NIGHT_AMBIENT_ENERGY := 0.45
const NIGHT_AMBIENT_SKY_CONTRIB := 0.25
const NIGHT_SUN_COLOR := Color(0.45, 0.55, 0.78, 1.0)
const NIGHT_SUN_ENERGY := 0.15

var _night_tween: Tween = null
static var _lamp_bulb_on_mat: StandardMaterial3D = null
var _user_args: PackedStringArray = []


static func _get_lamp_bulb_on_mat() -> StandardMaterial3D:
	if _lamp_bulb_on_mat == null:
		_lamp_bulb_on_mat = StandardMaterial3D.new()
		_lamp_bulb_on_mat.albedo_color = Color(1.0, 0.98, 0.85, 1.0)
		_lamp_bulb_on_mat.emission_enabled = true
		_lamp_bulb_on_mat.emission = Color(1.0, 0.96, 0.85, 1.0)
		_lamp_bulb_on_mat.emission_energy_multiplier = 4.0
	return _lamp_bulb_on_mat


func _on_time_of_day_changed(mode: GameState.TimeOfDay) -> void:
	_apply_time_of_day(mode, false)


func _update_streetlights(enabled: bool) -> void:
	var sl := (
		streetlights_node if streetlights_node else get_node_or_null("Props/Streetlights") as Node3D
	)
	if not sl:
		return
	var bulb_mat := _get_lamp_bulb_on_mat()
	var baked_mmi := sl.get_node_or_null("BakedMultiMesh") as MultiMeshInstance3D
	if baked_mmi and baked_mmi.multimesh and baked_mmi.multimesh.mesh:
		if _baked_streetlights_unlit_mesh == null:
			_baked_streetlights_unlit_mesh = baked_mmi.multimesh.mesh
			var lit_mesh := _baked_streetlights_unlit_mesh.duplicate() as Mesh
			for s in range(lit_mesh.get_surface_count()):
				var orig_mat := _baked_streetlights_unlit_mesh.surface_get_material(s)
				if (
					orig_mat is StandardMaterial3D
					and orig_mat.albedo_color.r > 0.85
					and orig_mat.metallic < 0.2
				):
					lit_mesh.surface_set_material(s, bulb_mat)
			_baked_streetlights_lit_mesh = lit_mesh
		baked_mmi.multimesh.mesh = (
			_baked_streetlights_lit_mesh if enabled else _baked_streetlights_unlit_mesh
		)
	for lamp in sl.get_children():
		if lamp is MultiMeshInstance3D:
			continue
		var light: SpotLight3D = lamp.get_node_or_null("Light")
		if light:
			light.visible = enabled
		var lamp_mesh: MeshInstance3D = lamp.get_node_or_null("Lamp")
		if lamp_mesh:
			lamp_mesh.material_override = bulb_mat if enabled else null


func _capture_day_settings() -> void:
	if _day_captured:
		return
	_day_captured = true
	var we := world_env if world_env else get_node_or_null("WorldEnvironment") as WorldEnvironment
	var dl := (
		sun_light if sun_light else get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	)
	if we and we.environment:
		var env: Environment = we.environment
		_day_ambient_color = env.ambient_light_color
		_day_ambient_energy = env.ambient_light_energy
		_day_ambient_sky_contrib = env.ambient_light_sky_contribution
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
		if sky_mat:
			_day_sky_top = sky_mat.sky_top_color
			_day_sky_horizon = sky_mat.sky_horizon_color
			_day_ground_bottom = sky_mat.ground_bottom_color
			_day_ground_horizon = sky_mat.ground_horizon_color
	if dl:
		_day_sun_color = dl.light_color
		_day_sun_energy = dl.light_energy
		_day_sun_rotation = dl.rotation


func _apply_time_of_day(mode: GameState.TimeOfDay, immediate: bool = false) -> void:
	var lights_on := mode != GameState.TimeOfDay.DAY
	_update_streetlights(lights_on)

	var we := world_env if world_env else get_node_or_null("WorldEnvironment") as WorldEnvironment
	var dl := (
		sun_light if sun_light else get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	)
	if not we or not we.environment:
		return

	var env: Environment = we.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null

	var target_sky_top: Color
	var target_sky_horizon: Color
	var target_ground_bottom: Color
	var target_ground_horizon: Color
	var target_ambient_color: Color
	var target_ambient_energy: float
	var target_ambient_contrib: float
	var target_sun_color: Color
	var target_sun_energy: float
	var target_sun_rot: Vector3

	match mode:
		GameState.TimeOfDay.DAY:
			target_sky_top = _day_sky_top
			target_sky_horizon = _day_sky_horizon
			target_ground_bottom = _day_ground_bottom
			target_ground_horizon = _day_ground_horizon
			target_ambient_color = _day_ambient_color
			target_ambient_energy = _day_ambient_energy
			target_ambient_contrib = _day_ambient_sky_contrib
			target_sun_color = _day_sun_color
			target_sun_energy = _day_sun_energy
			target_sun_rot = _day_sun_rotation
		GameState.TimeOfDay.EVENING:
			target_sky_top = EVENING_SKY_TOP
			target_sky_horizon = EVENING_SKY_HORIZON
			target_ground_bottom = EVENING_GROUND_BOTTOM
			target_ground_horizon = EVENING_GROUND_HORIZON
			target_ambient_color = EVENING_AMBIENT_COLOR
			target_ambient_energy = EVENING_AMBIENT_ENERGY
			target_ambient_contrib = EVENING_AMBIENT_SKY_CONTRIB
			target_sun_color = EVENING_SUN_COLOR
			target_sun_energy = EVENING_SUN_ENERGY
			target_sun_rot = EVENING_SUN_ROTATION
		GameState.TimeOfDay.NIGHT:
			target_sky_top = NIGHT_SKY_TOP
			target_sky_horizon = NIGHT_SKY_HORIZON
			target_ground_bottom = NIGHT_GROUND_BOTTOM
			target_ground_horizon = NIGHT_GROUND_HORIZON
			target_ambient_color = NIGHT_AMBIENT_COLOR
			target_ambient_energy = NIGHT_AMBIENT_ENERGY
			target_ambient_contrib = NIGHT_AMBIENT_SKY_CONTRIB
			target_sun_color = NIGHT_SUN_COLOR
			target_sun_energy = NIGHT_SUN_ENERGY
			target_sun_rot = _day_sun_rotation

	if immediate:
		if _night_tween and _night_tween.is_valid():
			_night_tween.kill()
		if sky_mat:
			sky_mat.sky_top_color = target_sky_top
			sky_mat.sky_horizon_color = target_sky_horizon
			sky_mat.ground_bottom_color = target_ground_bottom
			sky_mat.ground_horizon_color = target_ground_horizon
		env.ambient_light_color = target_ambient_color
		env.ambient_light_energy = target_ambient_energy
		env.ambient_light_sky_contribution = target_ambient_contrib
		if dl:
			dl.light_color = target_sun_color
			dl.light_energy = target_sun_energy
			dl.rotation = target_sun_rot
	else:
		if _night_tween and _night_tween.is_valid():
			_night_tween.kill()
		_night_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
		if sky_mat:
			_night_tween.tween_property(sky_mat, "sky_top_color", target_sky_top, 0.5)
			_night_tween.tween_property(sky_mat, "sky_horizon_color", target_sky_horizon, 0.5)
			_night_tween.tween_property(sky_mat, "ground_bottom_color", target_ground_bottom, 0.5)
			_night_tween.tween_property(sky_mat, "ground_horizon_color", target_ground_horizon, 0.5)
		_night_tween.tween_property(env, "ambient_light_color", target_ambient_color, 0.5)
		_night_tween.tween_property(env, "ambient_light_energy", target_ambient_energy, 0.5)
		_night_tween.tween_property(
			env, "ambient_light_sky_contribution", target_ambient_contrib, 0.5
		)
		if dl:
			_night_tween.tween_property(dl, "light_color", target_sun_color, 0.5)
			_night_tween.tween_property(dl, "light_energy", target_sun_energy, 0.5)
			_night_tween.tween_property(dl, "rotation", target_sun_rot, 0.5)


func _init() -> void:
	_user_args = OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_args():
		if not _user_args.has(arg):
			_user_args.append(arg)


func _enter_tree() -> void:
	for arg in _user_args:
		if arg.begins_with("--test-") or arg.begins_with("--bench-"):
			var test_script: Script = load("res://tests/main_tests.gd")
			if test_script:
				set_script(test_script)
				return


func _ready() -> void:
	for arg in _user_args:
		if arg.begins_with("--physics-ticks="):
			Engine.physics_ticks_per_second = int(arg.substr(16))
			print("Overriding physics_ticks_per_second = %d" % Engine.physics_ticks_per_second)
		if arg.begins_with("--scaling-3d-scale="):
			get_viewport().scaling_3d_scale = float(arg.substr(19))
			print("Overriding scaling_3d_scale = %f" % get_viewport().scaling_3d_scale)
	if (
		(OS.is_debug_build() and ProjectSettings.get_setting("debug/bake_preview", false))
		or "--bake" in _user_args
	):
		MeshBaker.bake_main_scene(self)
	if mats:
		mats.died.connect(_on_player_died)
	_capture_day_settings()
	if GameState.instance:
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
	_apply_time_of_day(GameState.time_of_day, true)


func _on_player_died(pos: Vector3) -> void:
	if blood_splats and mats:
		BloodSplat.spawn(pos, blood_splats, [mats.get_rid()])


func _exit_tree() -> void:
	if (
		GameState.instance
		and GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed)
	):
		GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
