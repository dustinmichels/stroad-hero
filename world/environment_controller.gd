class_name EnvironmentController
extends Node

@export var world_env: WorldEnvironment = null
@export var sun_light: DirectionalLight3D = null
@export var streetlights: Node3D = null

## Baked streetlight MultiMesh -> [unlit mesh, lit mesh (bulb surfaces swapped)].
var _baked_streetlight_meshes: Dictionary = {}
var _streetlights_active_target: int = -1
var _streetlight_seq: int = 0
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
var _last_applied_time_hours: float = -1.0

const TIME_THROTTLE_HOURS: float = 0.005

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

const WEB_DIRECTIONAL_SHADOW_MODE := DirectionalLight3D.SHADOW_ORTHOGONAL
const WEB_DIRECTIONAL_SHADOW_MAX_DISTANCE := 45.0

static var _lamp_bulb_on_mat: StandardMaterial3D = null


static func _get_lamp_bulb_on_mat() -> StandardMaterial3D:
	if _lamp_bulb_on_mat == null:
		_lamp_bulb_on_mat = StandardMaterial3D.new()
		_lamp_bulb_on_mat.albedo_color = Color(1.0, 0.98, 0.85, 1.0)
		_lamp_bulb_on_mat.emission_enabled = true
		_lamp_bulb_on_mat.emission = Color(1.0, 0.96, 0.85, 1.0)
		_lamp_bulb_on_mat.emission_energy_multiplier = 4.0
	return _lamp_bulb_on_mat


static func get_lamp_bulb_on_mat() -> StandardMaterial3D:
	return _get_lamp_bulb_on_mat()


func setup(
	p_world_env: WorldEnvironment = null,
	p_sun_light: DirectionalLight3D = null,
	p_streetlights: Node3D = null
) -> void:
	if p_world_env:
		world_env = p_world_env
	if p_sun_light:
		sun_light = p_sun_light
	if p_streetlights:
		streetlights = p_streetlights
	_capture_day_settings()
	apply_web_shadow_overrides()
	apply_time_hours(GameState.current_time_hours, true)


func _resolve_targets() -> void:
	if not world_env and is_inside_tree():
		world_env = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
		if not world_env and get_parent():
			world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not sun_light and is_inside_tree():
		sun_light = get_tree().get_first_node_in_group("directional_light") as DirectionalLight3D
		if not sun_light and get_parent():
			sun_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not streetlights and is_inside_tree():
		streetlights = get_tree().get_first_node_in_group("streetlights") as Node3D
		if not streetlights and get_parent():
			streetlights = get_parent().get_node_or_null("Props/Streetlights") as Node3D


static func _has_cmdline_arg(arg: String) -> bool:
	return arg in OS.get_cmdline_user_args() or arg in OS.get_cmdline_args()


func apply_web_shadow_overrides(force: bool = false) -> void:
	if not force and not OS.has_feature("web") and not _has_cmdline_arg("--force-web-shadows"):
		return
	_resolve_targets()
	if sun_light:
		sun_light.directional_shadow_mode = WEB_DIRECTIONAL_SHADOW_MODE
		sun_light.directional_shadow_max_distance = WEB_DIRECTIONAL_SHADOW_MAX_DISTANCE


func _ready() -> void:
	_resolve_targets()
	apply_web_shadow_overrides()
	_capture_day_settings()
	if GameState.instance:
		if not GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
		if not GameState.instance.time_changed.is_connected(_on_time_changed):
			GameState.instance.time_changed.connect(_on_time_changed)
	apply_time_hours(GameState.current_time_hours, true)


func _exit_tree() -> void:
	if GameState.instance:
		if GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed):
			GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
		if GameState.instance.time_changed.is_connected(_on_time_changed):
			GameState.instance.time_changed.disconnect(_on_time_changed)


func _on_time_of_day_changed(_mode: GameState.TimeOfDay) -> void:
	update_streetlights(GameState.are_lights_on(), true)
	apply_time_hours(GameState.current_time_hours, true)


func _on_time_changed(hours: float, _time_str: String) -> void:
	if (
		_last_applied_time_hours >= 0.0
		and absf(hours - _last_applied_time_hours) < TIME_THROTTLE_HOURS
	):
		return
	apply_time_hours(hours, true)


func update_streetlights(enabled: bool, staggered: bool = false) -> void:
	_resolve_targets()
	var sl := streetlights
	if not sl:
		return
	var target_int := 1 if enabled else 0
	if _streetlights_active_target == target_int and not staggered:
		return
	_streetlights_active_target = target_int
	_streetlight_seq += 1
	var seq := _streetlight_seq

	var bulb_mat := _get_lamp_bulb_on_mat()
	_update_baked_streetlights(sl, enabled, bulb_mat)

	if not staggered or not is_inside_tree():
		_set_all_streetlights(sl, enabled, bulb_mat)
		return

	_stagger_streetlights(sl, enabled, bulb_mat, seq)


func _update_baked_streetlights(sl: Node3D, enabled: bool, bulb_mat: StandardMaterial3D) -> void:
	for child in sl.get_children():
		var baked_mmi := child as MultiMeshInstance3D
		if baked_mmi == null or baked_mmi.multimesh == null or baked_mmi.multimesh.mesh == null:
			continue
		var mm := baked_mmi.multimesh
		if not _baked_streetlight_meshes.has(mm):
			var unlit_mesh := mm.mesh
			var lit_mesh := unlit_mesh.duplicate() as Mesh
			for s in range(lit_mesh.get_surface_count()):
				var orig_mat := unlit_mesh.surface_get_material(s)
				if (
					orig_mat is StandardMaterial3D
					and orig_mat.albedo_color.r > 0.85
					and orig_mat.metallic < 0.2
				):
					lit_mesh.surface_set_material(s, bulb_mat)
			_baked_streetlight_meshes[mm] = [unlit_mesh, lit_mesh]
		mm.mesh = _baked_streetlight_meshes[mm][1 if enabled else 0]


func _set_all_streetlights(sl: Node3D, enabled: bool, bulb_mat: StandardMaterial3D) -> void:
	for lamp in sl.get_children():
		if lamp is MultiMeshInstance3D:
			continue
		var light: SpotLight3D = lamp.get_node_or_null("Light")
		if light:
			light.visible = enabled
		var lamp_mesh: MeshInstance3D = lamp.get_node_or_null("Lamp")
		if lamp_mesh:
			lamp_mesh.material_override = bulb_mat if enabled else null


func _stagger_streetlights(
	sl: Node3D, enabled: bool, bulb_mat: StandardMaterial3D, seq: int
) -> void:
	var lamps: Array[Node] = []
	for lamp in sl.get_children():
		if not (lamp is MultiMeshInstance3D):
			lamps.append(lamp)
	var count := lamps.size()
	if count == 0:
		return
	var per_frame := maxi(1, int(ceil(float(count) / 6.0)))
	var idx := 0
	while idx < count:
		if seq != _streetlight_seq or not is_inside_tree():
			return
		var batch_end := mini(idx + per_frame, count)
		for i in range(idx, batch_end):
			var lamp = lamps[i]
			if not is_instance_valid(lamp):
				continue
			var light: SpotLight3D = lamp.get_node_or_null("Light")
			if light:
				light.visible = enabled
			var lamp_mesh: MeshInstance3D = lamp.get_node_or_null("Lamp")
			if lamp_mesh:
				lamp_mesh.material_override = bulb_mat if enabled else null
		idx = batch_end
		if idx < count:
			await get_tree().process_frame


func warmup_streetlights(enable_lit: bool, single_light: bool = true) -> void:
	_streetlights_active_target = -1
	_resolve_targets()
	var sl := streetlights
	if not sl:
		return
	var bulb_mat := _get_lamp_bulb_on_mat()
	_update_baked_streetlights(sl, enable_lit, bulb_mat)
	var first_light_handled := false
	for lamp in sl.get_children():
		if lamp is MultiMeshInstance3D:
			continue
		var light: SpotLight3D = lamp.get_node_or_null("Light")
		if light:
			if single_light:
				if not first_light_handled:
					light.visible = enable_lit
					first_light_handled = true
				else:
					light.visible = false
			else:
				light.visible = enable_lit
		var lamp_mesh: MeshInstance3D = lamp.get_node_or_null("Lamp")
		if lamp_mesh:
			lamp_mesh.material_override = bulb_mat if enable_lit else null


func _capture_day_settings() -> void:
	if _day_captured:
		return
	_resolve_targets()
	var we := world_env
	var dl := sun_light
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
	_day_captured = true


func apply_time_hours(hours: float, _immediate: bool = true) -> void:
	_last_applied_time_hours = hours
	_resolve_targets()
	var lights_on := GameState.are_lights_on()
	var target_int := 1 if lights_on else 0
	if _streetlights_active_target != target_int:
		update_streetlights(lights_on, not _immediate)
	var we := world_env
	var dl := sun_light
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

	var t := clampf(hours, GameState.START_HOUR, GameState.NIGHT_HOUR)
	if t < GameState.SUNSET_HOUR:
		# Afternoon daylight
		var p := clampf(
			(t - GameState.START_HOUR) / (GameState.SUNSET_HOUR - GameState.START_HOUR), 0.0, 1.0
		)
		target_sky_top = _day_sky_top.lerp(DAY_SKY_TOP, p)
		target_sky_horizon = _day_sky_horizon.lerp(DAY_SKY_HORIZON, p)
		target_ground_bottom = _day_ground_bottom
		target_ground_horizon = _day_ground_horizon
		target_ambient_color = _day_ambient_color
		target_ambient_energy = _day_ambient_energy
		target_ambient_contrib = _day_ambient_sky_contrib
		target_sun_color = _day_sun_color
		target_sun_energy = _day_sun_energy
		target_sun_rot = _day_sun_rotation
	elif t < GameState.TWILIGHT_HOUR:
		# Sunset
		var p := clampf(
			(t - GameState.SUNSET_HOUR) / (GameState.TWILIGHT_HOUR - GameState.SUNSET_HOUR),
			0.0,
			1.0
		)
		var s := p * p * (3.0 - 2.0 * p)
		target_sky_top = DAY_SKY_TOP.lerp(EVENING_SKY_TOP, s)
		target_sky_horizon = DAY_SKY_HORIZON.lerp(EVENING_SKY_HORIZON, s)
		target_ground_bottom = DAY_GROUND_BOTTOM.lerp(EVENING_GROUND_BOTTOM, s)
		target_ground_horizon = DAY_GROUND_HORIZON.lerp(EVENING_GROUND_HORIZON, s)
		target_ambient_color = DAY_AMBIENT_COLOR.lerp(EVENING_AMBIENT_COLOR, s)
		target_ambient_energy = lerpf(DAY_AMBIENT_ENERGY, EVENING_AMBIENT_ENERGY, s)
		target_ambient_contrib = lerpf(DAY_AMBIENT_SKY_CONTRIB, EVENING_AMBIENT_SKY_CONTRIB, s)
		target_sun_color = DAY_SUN_COLOR.lerp(EVENING_SUN_COLOR, s)
		target_sun_energy = lerpf(DAY_SUN_ENERGY, EVENING_SUN_ENERGY, s)
		target_sun_rot = _day_sun_rotation.lerp(EVENING_SUN_ROTATION, s)
	elif t < GameState.NIGHT_HOUR:
		# Twilight to night (the day ends early in this ramp, as it starts getting dark)
		var p := clampf(
			(t - GameState.TWILIGHT_HOUR) / (GameState.NIGHT_HOUR - GameState.TWILIGHT_HOUR),
			0.0,
			1.0
		)
		var s := p * p * (3.0 - 2.0 * p)
		target_sky_top = EVENING_SKY_TOP.lerp(NIGHT_SKY_TOP, s)
		target_sky_horizon = EVENING_SKY_HORIZON.lerp(NIGHT_SKY_HORIZON, s)
		target_ground_bottom = EVENING_GROUND_BOTTOM.lerp(NIGHT_GROUND_BOTTOM, s)
		target_ground_horizon = EVENING_GROUND_HORIZON.lerp(NIGHT_GROUND_HORIZON, s)
		target_ambient_color = EVENING_AMBIENT_COLOR.lerp(NIGHT_AMBIENT_COLOR, s)
		target_ambient_energy = lerpf(EVENING_AMBIENT_ENERGY, NIGHT_AMBIENT_ENERGY, s)
		target_ambient_contrib = lerpf(EVENING_AMBIENT_SKY_CONTRIB, NIGHT_AMBIENT_SKY_CONTRIB, s)
		target_sun_color = EVENING_SUN_COLOR.lerp(NIGHT_SUN_COLOR, s)
		target_sun_energy = lerpf(EVENING_SUN_ENERGY, NIGHT_SUN_ENERGY, s)
		target_sun_rot = EVENING_SUN_ROTATION.lerp(_day_sun_rotation, s)
	else:
		# Night
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
