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
var _test_frames: int = 0
var _test_car: Car = null
var _test_follower: Car = null
var _saw_waiting: bool = false
var _ghost_registered: bool = false
var _follower_braked: bool = false
var _handoff_verified: bool = false
var _passing_car: Car = null
var _gap_test_stage: int = 0
var _saw_hold_position: bool = false
var _saw_gap_merge: bool = false
var _saw_follower_yield: bool = false
var _mats_testing: bool = false
var _mats_start_frame: int = 0
var _mats_squash_frames: int = 0
var _mats_stage: int = 0
var _cart_test_stage: int = 0
var _cart_test_cart: ShoppingCart = null
var _cart_test_angles: Array[float] = [0.0, PI, PI / 2.0, -PI / 2.0]
var _cart_test_angle_idx: int = 0
var _cart_test_rolling: bool = false
var _cart_prev_rot_y: float = 0.0
var _col_test_stage: int = 0
var _col_test_lane: int = 0
var _col_test_initial_spd: int = 0
var _col_test_wait: int = 0
var _col_test_car: Car = null
const COL_LANE_CONFIGS: Array[Dictionary] = [
	{"lane_id": 0, "z": -5.6, "dir": -1.0, "car_x": 12.0, "mats_x": 0.0},
	{"lane_id": 1, "z": -1.9, "dir": -1.0, "car_x": 12.0, "mats_x": 0.0},
	{"lane_id": 2, "z": 1.9, "dir": 1.0, "car_x": -12.0, "mats_x": 0.0},
	{"lane_id": 3, "z": 5.6, "dir": 1.0, "car_x": -12.0, "mats_x": 0.0},
]

var _saw_lc_cruising: bool = false
var _saw_lc_decision: bool = false
var _saw_lc_braking: bool = false
var _saw_lc_turn: bool = false
var _saw_lc_park: bool = false
var _saw_lc_dwell: bool = false
var _saw_lc_reverse: bool = false
var _saw_lc_exit_aisle: bool = false
var _saw_lc_wait: bool = false
var _saw_lc_merge: bool = false
var _saw_lc_post_merge_cruise: bool = false
var _saw_lc_despawn: bool = false
var _rt_lead_car: Car = null
var _rt_follower_car: Car = null
var _rt_saw_lead_braking: bool = false
var _rt_saw_follower_braking: bool = false
var _rt_saw_lead_turning: bool = false
var _rt_saw_follower_resumed: bool = false
var _rt_min_distance: float = 999.0
var _user_args: PackedStringArray = []
var _ci_saw_cruise: bool = false
var _ci_saw_decision: bool = false
var _ci_saw_turn: bool = false
var _ci_saw_park: bool = false
var _ci_saw_reverse: bool = false
var _ci_saw_exit: bool = false
var _ci_saw_wait: bool = false
var _ci_saw_merge: bool = false
var _ci_saw_rejoin: bool = false
var _ci_site: StringName = &"cramped_inn"
var _smell_saw_cruise: bool = false
var _smell_saw_decision: bool = false
var _smell_saw_turn: bool = false
var _smell_saw_park: bool = false
var _smell_saw_reverse: bool = false
var _smell_saw_exit: bool = false
var _smell_saw_wait: bool = false
var _smell_saw_merge: bool = false
var _smell_saw_rejoin: bool = false
var _smell_dest: StringName = &"smell_gas"


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


func _ready() -> void:
	_user_args = OS.get_cmdline_user_args()
	if OS.is_debug_build() and ProjectSettings.get_setting("debug/bake_preview", false):
		MeshBaker.bake_main_scene(self)
	if mats:
		mats.died.connect(_on_player_died)
	_capture_day_settings()
	if GameState.instance:
		GameState.instance.time_of_day_changed.connect(_on_time_of_day_changed)
	_apply_time_of_day(GameState.time_of_day, true)
	if "--test-mats-blocker" in _user_args or "--test-mats-interaction" in _user_args:
		var car_scene = load("res://cars/passenger_car.tscn")
		_test_car = car_scene.instantiate()
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.state = Car.State.WAITING_TO_MERGE
		add_child(_test_car)
		_test_car.global_position = Vector3(9.0, 0.0, -9.6)
		_test_car.rotation.y = -PI / 2.0  # facing +Z
		_test_car._update_blocker_layer()
		mats.global_position = Vector3(9.0, 0.5, -13.0)
	if "--test-mats-walk" in _user_args:
		# Place Mats on flat sidewalk/road, clear velocity, ready for walk cycle test
		mats.global_position = Vector3(9.0, 0.0, -15.0)
		mats.velocity = Vector3(0.0, 0.0, mats.walk_speed)
	if "--test-mats-cart" in _user_args:
		_cart_test_cart = (
			get_node_or_null("Props/WalgroinsShoppingCarts/Cart_Abandoned_WestApron")
			as ShoppingCart
		)
		assert(_cart_test_cart != null, "ShoppingCart not found in scene")
		_cart_test_cart.global_position = Vector3(9.0, 0.0, -15.0)
		_cart_test_cart.global_basis = Basis()
		_cart_test_cart._current_speed = 0.0
		_cart_test_stage = 0
		_test_frames = 0
		_cart_test_setup()
	if "--test-mats-collision" in _user_args:
		mats.blood_linger_delay = 0.02
		mats.fade_duration = 0.02
		mats.spd_emphasis_duration = 0.02
		var hud_node: HUD = get_tree().get_first_node_in_group("hud") as HUD
		if hud_node:
			_col_test_initial_spd = hud_node.spd_count
		var tm = $TrafficManager
		if tm:
			for lane in tm.lanes:
				lane.spawn_timer = 999.0
				for c in lane.cars:
					if is_instance_valid(c):
						c.queue_free()
				lane.cars.clear()
		_col_test_stage = 0
		_test_frames = 0
		mats.global_position = Vector3(16.0, 0.10, 7.1)
		mats.velocity = Vector3(0.0, 0.0, 4.0)
	if "--test-merge-reentry" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(
			traffic_mgr != null and traffic_mgr.lot_cars.size() > 0,
			"TrafficManager must have seeded cars"
		)
		for c in traffic_mgr.lot_cars:
			if c.global_position.z < 0.0 and c.global_position.x > -30.0:
				_test_car = c
				break
		_test_car.dwell_left = 0.0
		_test_car.had_errand = true
	if "--test-merge-gap" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(
			traffic_mgr != null and traffic_mgr.lot_cars.size() > 0,
			"TrafficManager must have seeded cars"
		)
		for c in traffic_mgr.lot_cars:
			if c.global_position.z < 0.0 and c.global_position.x > -30.0:
				_test_car = c
				break
		if _test_car.spot != null:
			traffic_mgr.lot.release(_test_car.spot)
			_test_car.spot = null
		_test_car.motion = Car.Motion.PATH
		_test_car.path = null
		_test_car.lane_id = -1
		_test_car.state = Car.State.WAITING_TO_MERGE
		_test_car.global_position = Vector3(9.0, 0.0, -9.6)
		_test_car.rotation.y = -PI / 2.0
		_test_car.speed = 0.0
		_test_car.desired_speed = 0.0
		_test_car.had_errand = true
		_test_car.merge_wait_time = 0.0
		_test_car._update_blocker_layer()
	if "--test-exit-priority" in _user_args:
		var tm = $TrafficManager
		for lane in tm.lanes:
			for car in lane.cars:
				car.queue_free()
			lane.cars.clear()
		for car in tm.lot_cars:
			car.queue_free()
		tm.lot_cars.clear()
		for lane_id in [0, 3]:
			var lane = tm.lanes[lane_id]
			var exiting: Car = tm.PassengerCarScene.instantiate()
			tm.add_child(exiting)
			exiting.motion = Car.Motion.PATH
			exiting.state = Car.State.DRIVE_THRU
			exiting.lane_id = lane_id
			exiting.merge_target_lane = lane_id
			exiting.dt_order_done = true
			exiting.dt_pickup_done = true
			exiting.follow_path(
				tm.taco_hell_drive_thru_path if lane_id == 0 else tm.booger_king_drive_thru_path
			)
			exiting.path_distance = exiting.path.get_baked_length() - 0.01
			exiting.speed = 0.0
			exiting.update_presentation()
			tm.lot_cars.append(exiting)
			lane.cars.append(exiting)
			var merge_x: float = (
				ParkingLot.WAIT_POINT.x if lane_id == 0 else ParkingLot.BK_WAIT_POINT.x
			)
			var through: Car = tm._spawn_car_at(
				lane, lane.distance_at(merge_x) - 20.0, tm.PassengerCarScene
			)
			through.errand = null
			through.speed = 13.0
			through.desired_speed = 13.0
			var saw_wait := false
			for tick in range(360):
				tm._update_lane_traffic(lane, 1.0 / 60.0)
				tm._update_lot_cars(1.0 / 60.0)
				if exiting.state == Car.State.WAITING_TO_MERGE:
					saw_wait = true
					assert(
						is_equal_approx(through.speed, 13.0),
						"Main-road traffic must not brake for a waiting driveway car"
					)
					assert(exiting.speed == 0.0, "Exiting car must wait for main-road traffic")
				if exiting.state == Car.State.CRUISING:
					break
			assert(saw_wait, "Returning drive-thru car must yield before merging")
			assert(
				exiting.state == Car.State.CRUISING, "Exit must clear once main-road traffic passes"
			)
			for car in lane.cars:
				car.queue_free()
			lane.cars.clear()
		print("EXIT_PRIORITY: SUCCESS - both exits yield without stopping main-road traffic")
		get_tree().quit(0)
		return
	if "--test-lifecycle" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		_test_car = traffic_mgr._spawn_car_at(lane0, 0.0, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.random()
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0
	if "--test-cramped-inn" in _user_args or "--test-strip-mall" in _user_args:
		_ci_site = &"strip_mall" if "--test-strip-mall" in _user_args else &"cramped_inn"
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane3 = traffic_mgr.lanes[3]
		for c in lane3.cars:
			c.queue_free()
		lane3.cars.clear()
		lane3.spawn_timer = 9999.0
		var start_d: float = traffic_mgr._lane3_lot_decision_d(_ci_site) - 14.0
		_test_car = traffic_mgr._spawn_car_at(lane3, start_d, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(_ci_site, 1.0)
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0
	if "--test-smell-store" in _user_args or "--test-smell-gas" in _user_args:
		_smell_dest = &"smell_gas" if "--test-smell-gas" in _user_args else &"smell_store"
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		var start_d: float = traffic_mgr.DECISION_D_SMELL - 14.0
		_test_car = traffic_mgr._spawn_car_at(lane0, start_d, traffic_mgr.PassengerCarScene)
		_test_car.car_type = Car.CarType.SEDAN
		_test_car.errand = Errand.new(_smell_dest, 1.0)
		_test_car.had_errand = true
		_test_car.desired_speed = 12.0
		_test_car.speed = 12.0
	if "--test-right-turn-following" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(traffic_mgr != null, "TrafficManager must exist")
		var lane0 = traffic_mgr.lanes[0]
		for c in lane0.cars:
			c.queue_free()
		lane0.cars.clear()
		lane0.spawn_timer = 9999.0
		_rt_lead_car = traffic_mgr._spawn_car_at(lane0, 10.0, traffic_mgr.PassengerCarScene)
		_rt_lead_car.car_type = Car.CarType.SEDAN
		_rt_lead_car.errand = Errand.new(&"walgroins", 10.0)
		_rt_lead_car.had_errand = true
		_rt_lead_car.desired_speed = 13.0
		_rt_lead_car.speed = 13.0

		_rt_follower_car = traffic_mgr._spawn_car_at(lane0, 0.0, traffic_mgr.PassengerCarScene)
		_rt_follower_car.car_type = Car.CarType.SEDAN
		_rt_follower_car.desired_speed = 14.0
		_rt_follower_car.speed = 14.0
		_rt_follower_car.errand = null
		_rt_follower_car.had_errand = false
	if "--test-find-blocker" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		# Clear lot cars for isolated unit testing of find_blocker
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		var car_scene = load("res://cars/passenger_car.tscn")
		var car_a = car_scene.instantiate()
		car_a.car_type = Car.CarType.SEDAN
		car_a.car_width = 2.0
		car_a.speed = 0.0
		car_a.direction = 1.0
		tm.add_child(car_a)
		car_a.global_position = Vector3(0.0, 0.0, 0.0)
		car_a.rotation.y = 0.0  # forward is +X
		tm.lot_cars.append(car_a)

		var car_b = car_scene.instantiate()
		car_b.car_type = Car.CarType.SEDAN
		car_b.car_width = 2.0
		car_b.speed = 0.0
		car_b.direction = 1.0
		tm.add_child(car_b)
		car_b.global_position = Vector3(2.0, 0.0, 0.5)
		tm.lot_cars.append(car_b)

		# Test 1: centers 6.0m apart (gap = 6.0 - 4.2 = 1.8 < 4.0m lookahead), lateral 0.5 < 2.2m -> blocker found
		car_b.global_position = Vector3(6.0, 0.0, 0.5)
		var b = tm.find_blocker(car_a)
		assert(b == car_b, "car_b at 6.0m center distance must be detected as blocker")

		# Test 2: lateral too large (2.5 > 2.2m)
		car_b.global_position = Vector3(6.0, 0.0, 2.5)
		assert(tm.find_blocker(car_a) == null, "car_b with lateral 2.5m must NOT be blocker")

		# Test 3: behind car_a (forward < 0)
		car_b.global_position = Vector3(-6.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == null, "car_b behind car_a must NOT be blocker")

		# Test 4: centers 9.0m apart (gap = 9.0 - 4.2 = 4.8 >= 4.0m lookahead) -> NOT a blocker when stopped
		car_b.global_position = Vector3(9.0, 0.0, 0.0)
		assert(
			tm.find_blocker(car_a) == null,
			"car_b at 9.0m center distance must NOT be blocker when car_a is stopped"
		)

		# Test 5: dynamic lookahead with speed
		# speed = 10 m/s -> lookahead = max(4.0, 100 / (2 * 25) + 3.0) = 5.0m
		# gap = 4.8 < 5.0m -> blocker found!
		car_a.speed = 10.0
		assert(
			tm.find_blocker(car_a) == car_b,
			"car_b at 9.0m must be blocker when car_a speed is 10 m/s"
		)
		car_a.speed = 0.0

		# Test 6: closest blocker when multiple candidates exist
		var car_c = car_scene.instantiate()
		car_c.car_type = Car.CarType.SEDAN
		tm.add_child(car_c)
		car_c.global_position = Vector3(5.0, 0.0, 0.0)
		tm.lot_cars.append(car_c)
		car_b.global_position = Vector3(7.0, 0.0, 0.0)
		assert(
			tm.find_blocker(car_a) == car_c,
			"find_blocker must return closest blocker (car_c at 5.0m, not car_b at 7.0m)"
		)
		tm.lot_cars.erase(car_c)
		car_c.queue_free()

		# Test 7: Reversing car
		car_a.state = Car.State.REVERSING_OUT
		car_a.speed = -1.5
		# In reverse, forward direction is -X. car_b at (-6.0, 0, 0) is ahead in reverse direction!
		car_b.global_position = Vector3(-6.0, 0.0, 0.0)
		assert(
			tm.find_blocker(car_a) == car_b,
			"car_b at -6.0m must be blocker for car_a reversing along -X"
		)
		# car_b at (+6.0, 0, 0) is behind reversing car_a
		car_b.global_position = Vector3(6.0, 0.0, 0.0)
		assert(
			tm.find_blocker(car_a) == null,
			"car_b at +6.0m must NOT be blocker for car_a reversing along -X"
		)
		# Test 8: Ghost in lane 0
		car_a.state = Car.State.TO_SPOT
		car_a.speed = 4.5
		var ghost = car_scene.instantiate()
		ghost.car_type = Car.CarType.SEDAN
		ghost.car_width = 2.0
		ghost.motion = Car.Motion.PATH
		tm.add_child(ghost)
		ghost.global_position = Vector3(3.0, 0.0, 0.0)
		# ghost is NOT in lot_cars, but in lane 0 cars
		assert(tm.lanes.size() > 0, "lanes must not be empty")
		tm.lanes[0].cars.append(ghost)
		car_b.global_position = Vector3(50.0, 0.0, 0.0)
		assert(tm.find_blocker(car_a) == ghost, "ghost in lane 0 must be detected as blocker")
		tm.lanes[0].cars.erase(ghost)
		ghost.queue_free()

		print("FIND_BLOCKER_TEST: SUCCESS - all 8 blocker test cases passed!")
		get_tree().quit(0)
		return
	if "--test-reverse-safety" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		# Find a spot in the lot
		assert(tm.lot != null and tm.lot.spots.size() > 0, "ParkingLot must have spots")
		var spot = tm.lot.spots[0]
		var car_scene = load("res://cars/passenger_car.tscn")
		var parked_car = car_scene.instantiate()
		parked_car.car_type = Car.CarType.SEDAN
		parked_car.state = Car.State.PARKED
		parked_car.spot = spot
		parked_car.dwell_left = 0.0
		parked_car.speed = 0.0
		tm.add_child(parked_car)
		parked_car.global_position = spot.position
		tm.lot_cars.append(parked_car)

		var aisle_car = car_scene.instantiate()
		aisle_car.car_type = Car.CarType.SEDAN
		aisle_car.state = Car.State.TO_EXIT
		aisle_car.speed = 4.5
		tm.add_child(aisle_car)
		# Place aisle car within 8m of spot along X
		aisle_car.global_position = Vector3(spot.x + 5.0, 0.0, -20.0)
		tm.lot_cars.append(aisle_car)

		# Test 1: Moving car within 8m along aisle -> can_reverse_out returns false
		assert(
			tm.can_reverse_out(parked_car) == false,
			"can_reverse_out must be false when moving car is within 8m along aisle"
		)

		# Update lot cars for 1 tick -> parked_car must delay reversing and stay PARKED
		tm._update_lot_cars(0.016)
		assert(
			parked_car.state == Car.State.PARKED,
			"parked car must remain PARKED while aisle is busy"
		)

		# Test 2: Car within 8m but STOPPED -> does not block reverse
		aisle_car.speed = 0.0
		assert(
			tm.can_reverse_out(parked_car) == true,
			"can_reverse_out must be true when nearby car is stopped"
		)

		# Test 3: Moving car beyond 8m along aisle -> does not block reverse
		aisle_car.speed = 4.5
		aisle_car.global_position = Vector3(spot.x + 10.0, 0.0, -20.0)
		assert(
			tm.can_reverse_out(parked_car) == true,
			"can_reverse_out must be true when moving car is > 8m away"
		)

		# Update lot cars for 1 tick -> parked_car transitions to REVERSING_OUT
		tm._update_lot_cars(0.016)
		assert(
			parked_car.state == Car.State.REVERSING_OUT,
			"parked car must transition to REVERSING_OUT once aisle is clear"
		)
		assert(parked_car.speed < 0.0, "reversing car must have negative speed")

		print(
			"REVERSE_SAFETY_TEST: SUCCESS - parked car delays reversing while moving lot car is within 8m, and reverses once clear!"
		)
		get_tree().quit(0)
		return
	if "--test-priority-arbitration" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		var car_scene = load("res://cars/passenger_car.tscn")

		# Case 1: head-on, each car's body sits in the other's route -> both stop, whatever their priority
		var east = Curve3D.new()
		east.add_point(Vector3(0.0, 0.0, 0.0))
		east.add_point(Vector3(30.0, 0.0, 0.0))
		var west = Curve3D.new()
		west.add_point(Vector3(30.0, 0.0, 0.0))
		west.add_point(Vector3(0.0, 0.0, 0.0))

		var car1: Car = car_scene.instantiate()
		car1.car_type = Car.CarType.SEDAN
		tm.add_child(car1)
		car1.state = Car.State.TO_SPOT
		car1.follow_path(east)
		car1.path_distance = 10.0  # x = 10, facing +X
		car1.speed = 4.0
		car1.update_presentation()
		tm.lot_cars.append(car1)

		var car2: Car = car_scene.instantiate()
		car2.car_type = Car.CarType.SEDAN
		tm.add_child(car2)
		car2.state = Car.State.TO_EXIT
		car2.follow_path(west)
		car2.path_distance = 14.0  # x = 16, facing -X toward car1
		car2.speed = 4.0
		car2.update_presentation()
		tm.lot_cars.append(car2)

		assert(tm.find_blocker(car1) == car2, "Head-on: TO_SPOT must not drive into TO_EXIT")
		assert(tm.find_blocker(car2) == car1, "Head-on: TO_EXIT must not drive into TO_SPOT")

		# Crossing: car1 eastbound along z=0, car2 southbound along x=15; both 5m from the crossing
		var south = Curve3D.new()
		south.add_point(Vector3(15.0, 0.0, -15.0))
		south.add_point(Vector3(15.0, 0.0, 15.0))
		var north = Curve3D.new()
		north.add_point(Vector3(15.0, 0.0, 15.0))
		north.add_point(Vector3(15.0, 0.0, -15.0))
		var place_crossing := func(rev: bool) -> void:
			if rev:
				car2.follow_path(north, true)
				car2.path_distance = 20.0  # z = -5, reversing toward +Z
				car2.speed = -TrafficManager.V_PARK
				car2.desired_speed = -TrafficManager.V_PARK
			else:
				car2.follow_path(south)
				car2.path_distance = 10.0  # z = -5, facing +Z
				car2.speed = 4.0
				car2.desired_speed = 4.0
			car2.update_presentation()
			car1.path_distance = 10.0
			car1.speed = 4.0
			car1.update_presentation()

		# Case 2: equal distance to the crossing -> tie broken by priority TO_SPOT > TO_EXIT
		car1.state = Car.State.TO_SPOT
		car2.state = Car.State.TO_EXIT
		place_crossing.call(false)
		assert(tm.find_blocker(car1) == null, "Crossing tie: TO_SPOT proceeds")
		assert(tm.find_blocker(car2) == car1, "Crossing tie: TO_EXIT yields to TO_SPOT")

		# Case 3: a reversing car owns its whole back-out route -> crossing traffic waits for it
		car1.state = Car.State.TO_EXIT
		car2.state = Car.State.REVERSING_OUT
		place_crossing.call(true)
		assert(tm.find_blocker(car1) == car2, "TO_EXIT must stop for a reversing car's route")
		assert(tm.find_blocker(car2) == null, "REVERSING_OUT keeps backing out")

		# Case 4: the car nearer the crossing goes first, even with lower priority
		car1.state = Car.State.TO_SPOT
		car2.state = Car.State.TO_EXIT
		place_crossing.call(false)
		car2.path_distance = 12.0  # z = -3, nose almost in car1's route
		car2.update_presentation()
		assert(tm.find_blocker(car2) == null, "Nearer TO_EXIT proceeds through the crossing")
		assert(tm.find_blocker(car1) == car2, "Farther TO_SPOT yields to the nearer car")

		# Case 5: yielding car stops, then resumes once the crossing clears
		place_crossing.call(false)
		for i in range(20):
			tm._update_lot_cars(0.016)

		assert(car1.state == Car.State.TO_SPOT, "car1 must remain in TO_SPOT")
		assert(car2.state == Car.State.TO_EXIT, "car2 must remain in TO_EXIT")
		assert(car2.desired_speed == 0.0, "car2 must have desired_speed 0.0")
		assert(car2.speed < 0.1, "car2 must stop (speed ~ 0)")
		assert(car1.speed > 1.0, "car1 (higher priority) must continue moving")

		# car1 moves past the crossing
		car1.path_distance = 25.0
		car1.update_presentation()
		assert(tm.find_blocker(car2) == null, "car2 blocker should clear once car1 is past")

		for i in range(20):
			tm._update_lot_cars(0.016)
		assert(car2.desired_speed > 0.0, "car2 desired_speed must restore once blocker clears")
		assert(car2.speed > 0.5, "car2 must resume moving once blocker clears")

		# Case 6: REVERSING_OUT yielding on first tick does not prematurely finish or release spot
		assert(tm.lot != null and tm.lot.spots.size() > 0, "ParkingLot must have spots")
		var test_spot = tm.lot.spots[0]
		var rev_path = tm.lot.reverse_route(test_spot)
		var car3: Car = car_scene.instantiate()
		car3.car_type = Car.CarType.SEDAN
		car3.spot = test_spot
		tm.add_child(car3)
		car3.state = Car.State.REVERSING_OUT
		car3.follow_path(rev_path, true)  # reversed path
		car3.speed = -TrafficManager.V_PARK
		car3.desired_speed = -TrafficManager.V_PARK
		car3.update_presentation()
		tm.lot_cars.append(car3)

		# Place a TO_SPOT car directly blocking the reversing car
		var car4: Car = car_scene.instantiate()
		car4.car_type = Car.CarType.SEDAN
		car4.state = Car.State.TO_SPOT
		car4.speed = 0.0
		tm.add_child(car4)
		# Place car4 behind reversing car3 (along reverse direction)
		var rev_heading = car3.get_heading()
		car4.global_position = car3.global_position - rev_heading * 2.5
		tm.lot_cars.append(car4)

		assert(tm.find_blocker(car3) == car4, "car3 must find car4 as blocker")
		assert(
			tm._update_car_yielding(car3, 0.0) == true, "car3 (REVERSING_OUT) must yield to car4"
		)
		# Tick 1 update
		tm._update_lot_cars(0.016)
		assert(
			car3.state == Car.State.REVERSING_OUT,
			"car3 must remain in REVERSING_OUT while yielding"
		)
		assert(car3.spot == test_spot, "car3 must not release spot while yielding")
		assert(car3.desired_speed == 0.0, "car3 desired_speed must be 0.0 when yielding")

		print(
			"PRIORITY_ARBITRATION_TEST: SUCCESS - Priority arbitration TO_SPOT > TO_EXIT > REVERSING_OUT verified!"
		)
		get_tree().quit(0)
		return
	if "--test-drive-thru" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()
		for lane in tm.lanes:
			for c in lane.cars:
				c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = 999.0

		# 1. Live Taco Hell Drive-Thru Simulation
		var car1: Car = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
		assert(car1.state == Car.State.DRIVE_THRU, "car1 must start in DRIVE_THRU state")
		assert(car1.merge_target_lane == 0, "car1 target lane must be 0")
		assert(
			car1.path == tm.taco_hell_drive_thru_path, "car1 must follow taco_hell_drive_thru_path"
		)

		var car2: Car = null
		var saw_c1_order := false
		var saw_c1_pickup := false
		var saw_c2_queued := false
		var saw_c2_order := false
		var saw_c2_pickup := false
		var c1_prev_d := 0.0
		var c2_prev_d := 0.0
		var delta := 0.05
		var max_ticks := 2000
		var ticks := 0

		while ticks < max_ticks:
			ticks += 1
			# Spawn car2 once car1 has advanced 14 meters
			if car2 == null and car1.path_distance >= 14.0:
				car2 = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")

			# Tick traffic manager lot cars
			tm._update_lot_cars(delta)
			for lane in tm.lanes:
				tm._update_lane_traffic(lane, delta)

			# Monotonic progress check for car1
			if car1.state == Car.State.DRIVE_THRU:
				assert(car1.path_distance >= c1_prev_d - 0.001, "car1 progress must be monotonic")
				c1_prev_d = car1.path_distance
				if car1.dt_order_done and not saw_c1_order:
					saw_c1_order = true
				if car1.dt_pickup_done and not saw_c1_pickup:
					saw_c1_pickup = true

			# Monotonic progress check for car2
			if car2 != null and car2.state == Car.State.DRIVE_THRU:
				assert(car2.path_distance >= c2_prev_d - 0.001, "car2 progress must be monotonic")
				c2_prev_d = car2.path_distance
				if car2.dt_order_done and not saw_c2_order:
					saw_c2_order = true
				if car2.dt_pickup_done and not saw_c2_pickup:
					saw_c2_pickup = true

			# Euclidean no-overlap check
			if (
				car2 != null
				and car1.state == Car.State.DRIVE_THRU
				and car2.state == Car.State.DRIVE_THRU
			):
				var d_pos := car1.global_position.distance_to(car2.global_position)
				var min_allowed := (car1.car_length + car2.car_length) * 0.5 - 0.2
				assert(
					d_pos >= min_allowed,
					(
						"Euclidean overlap detected between car1 and car2: dist=%.2f < min=%.2f"
						% [d_pos, min_allowed]
					)
				)
				if tm.find_blocker(car2) == car1 and car2.speed < 0.1:
					saw_c2_queued = true

			# Check if both have completed merge and are cruising
			if (
				car1.state == Car.State.CRUISING
				and car2 != null
				and car2.state == Car.State.CRUISING
			):
				break

		assert(saw_c1_order, "car1 must dwell to order at menu board")
		assert(saw_c1_pickup, "car1 must dwell to pick up food at window")
		assert(saw_c2_queued, "car2 must queue and stop behind car1 in line")
		assert(saw_c2_order, "car2 must dwell to order at menu board")
		assert(saw_c2_pickup, "car2 must dwell to pick up food at window")
		assert(
			car1.state == Car.State.CRUISING and car1.lane_id == 0,
			"car1 must merge and cruise in lane 0"
		)
		assert(
			car2.state == Car.State.CRUISING and car2.lane_id == 0,
			"car2 must merge and cruise in lane 0"
		)

		# 2. Live Booger King Drive-Thru Simulation
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()
		for lane in tm.lanes:
			for c in lane.cars:
				c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = 999.0

		var bk1: Car = tm.spawn_drive_thru_car(&"booger_king")
		assert(bk1.state == Car.State.DRIVE_THRU, "bk1 must start in DRIVE_THRU state")
		assert(bk1.merge_target_lane == 3, "bk1 target lane must be 3 (Eastbound)")
		assert(
			bk1.path == tm.booger_king_drive_thru_path,
			"bk1 must follow booger_king_drive_thru_path"
		)

		var bk2: Car = null
		var saw_bk1_order := false
		var saw_bk1_pickup := false
		var saw_bk2_queued := false
		var saw_bk2_order := false
		var saw_bk2_pickup := false
		var bk1_prev_d := 0.0
		var bk2_prev_d := 0.0
		ticks = 0

		while ticks < max_ticks:
			ticks += 1
			# Spawn bk2 once bk1 has advanced 14 meters
			if bk2 == null and bk1.path_distance >= 14.0:
				bk2 = tm.spawn_drive_thru_car(&"booger_king")

			tm._update_lot_cars(delta)
			for lane in tm.lanes:
				tm._update_lane_traffic(lane, delta)

			# Monotonic progress check for bk1
			if bk1.state == Car.State.DRIVE_THRU:
				assert(bk1.path_distance >= bk1_prev_d - 0.001, "bk1 progress must be monotonic")
				bk1_prev_d = bk1.path_distance
				if bk1.dt_order_done and not saw_bk1_order:
					saw_bk1_order = true
				if bk1.dt_pickup_done and not saw_bk1_pickup:
					saw_bk1_pickup = true

			# Monotonic progress check for bk2
			if bk2 != null and bk2.state == Car.State.DRIVE_THRU:
				assert(bk2.path_distance >= bk2_prev_d - 0.001, "bk2 progress must be monotonic")
				bk2_prev_d = bk2.path_distance
				if bk2.dt_order_done and not saw_bk2_order:
					saw_bk2_order = true
				if bk2.dt_pickup_done and not saw_bk2_pickup:
					saw_bk2_pickup = true

			# Euclidean no-overlap check
			if (
				bk2 != null
				and bk1.state == Car.State.DRIVE_THRU
				and bk2.state == Car.State.DRIVE_THRU
			):
				var d_pos := bk1.global_position.distance_to(bk2.global_position)
				var min_allowed := (bk1.car_length + bk2.car_length) * 0.5 - 0.2
				assert(
					d_pos >= min_allowed,
					(
						"Euclidean overlap detected between bk1 and bk2: dist=%.2f < min=%.2f"
						% [d_pos, min_allowed]
					)
				)
				if tm.find_blocker(bk2) == bk1 and bk2.speed < 0.1:
					saw_bk2_queued = true

			# Check if both have completed merge and are cruising
			if bk1.state == Car.State.CRUISING and bk2 != null and bk2.state == Car.State.CRUISING:
				break

		assert(saw_bk1_order, "bk1 must dwell at menu/pickup window")
		assert(saw_bk1_pickup, "bk1 must dwell at menu/pickup window")
		assert(saw_bk2_queued, "bk2 must queue and stop behind bk1 in line")
		assert(saw_bk2_order, "bk2 must dwell at menu/pickup window")
		assert(saw_bk2_pickup, "bk2 must dwell at menu/pickup window")
		assert(
			bk1.state == Car.State.CRUISING and bk1.lane_id == 3,
			"bk1 must merge and cruise in lane 3"
		)
		assert(
			bk2.state == Car.State.CRUISING and bk2.lane_id == 3,
			"bk2 must merge and cruise in lane 3"
		)
		assert(tm.lanes[3].cars.has(bk1), "bk1 must be added to lane 3 traffic")
		# 3. Seeded Full-Traffic Phase
		seed(42)
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()
		if tm.lot != null:
			for s in tm.lot.spots:
				tm.lot.release(s)
		for lane in tm.lanes:
			for c in lane.cars:
				c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = randf_range(1.0, 2.5)

		tm._seed_parked_cars()

		var dt_cars: Array[Car] = []
		var p3_taco1: Car = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
		var p3_bk1: Car = tm.spawn_drive_thru_car(&"booger_king")
		dt_cars.append(p3_taco1)
		dt_cars.append(p3_bk1)
		var p3_taco2: Car = null
		var p3_bk2: Car = null

		var full_cap := 3000
		var finished_all := false

		for t in range(full_cap):
			# Stagger secondary drive-thru cars so one enters while another exits
			if t >= 220 and p3_taco2 == null and tm.can_spawn_drive_thru(&"taco_hell_drive_thru"):
				p3_taco2 = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
				dt_cars.append(p3_taco2)
			if t >= 220 and p3_bk2 == null and tm.can_spawn_drive_thru(&"booger_king"):
				p3_bk2 = tm.spawn_drive_thru_car(&"booger_king")
				dt_cars.append(p3_bk2)

			tm._physics_process(delta)

			# Collect all active cars for separation checks
			var all_cars: Array[Car] = []
			for c in tm.lot_cars:
				if is_instance_valid(c):
					all_cars.append(c)
			for lane in tm.lanes:
				for c in lane.cars:
					if is_instance_valid(c) and not all_cars.has(c):
						all_cars.append(c)

			# All-pairs Euclidean separation check for pairs involving drive-thru cars
			for i in range(all_cars.size()):
				var c_i := all_cars[i]
				for j in range(i + 1, all_cars.size()):
					var c_j := all_cars[j]
					if not dt_cars.has(c_i) and not dt_cars.has(c_j):
						continue
					var dpos := c_j.global_position - c_i.global_position
					var dpos_2d := Vector2(dpos.x, dpos.z)
					var h_i := c_i.get_heading()
					var f_i := Vector2(h_i.x, h_i.z).normalized()
					var l_i := Vector2(-f_i.y, f_i.x)
					var h_j := c_j.get_heading()
					var f_j := Vector2(h_j.x, h_j.z).normalized()
					var l_j := Vector2(-f_j.y, f_j.x)

					var hx_i := c_i.car_length * 0.5
					var hz_i := c_i.car_width * 0.5
					var hx_j := c_j.car_length * 0.5
					var hz_j := c_j.car_width * 0.5

					var separated := false
					var axes := [f_i, l_i, f_j, l_j]
					for axis in axes:
						var dist_axis := absf(dpos_2d.dot(axis))
						var r_i := absf(f_i.dot(axis)) * hx_i + absf(l_i.dot(axis)) * hz_i
						var r_j := absf(f_j.dot(axis)) * hx_j + absf(l_j.dot(axis)) * hz_j
						if dist_axis >= (r_i + r_j - 0.25):
							separated = true
							break

					assert(
						separated,
						(
							"Euclidean car penetration involving drive-thru car %s (%s) and %s (%s) at tick %d: pos_i=%s, pos_j=%s"
							% [
								c_i.name,
								c_i.get_state_name(),
								c_j.name,
								c_j.get_state_name(),
								t,
								c_i.global_position,
								c_j.global_position
							]
						)
					)

			# Check if all 4 drive-thru cars reached CRUISING in their destination lanes
			if p3_taco2 != null and p3_bk2 != null:
				var all_cruising := true
				for dt_c in dt_cars:
					if dt_c.state != Car.State.CRUISING:
						all_cruising = false
						break
				if all_cruising:
					finished_all = true
					break

		assert(
			finished_all,
			"All 4 drive-thru cars must complete their loops and reach CRUISING within frame cap"
		)
		assert(
			p3_taco1.lane_id == 0 and p3_taco2.lane_id == 0,
			"Taco Hell drive-thru cars must merge and cruise in lane 0"
		)
		assert(
			p3_bk1.lane_id == 3 and p3_bk2.lane_id == 3,
			"Booger King drive-thru cars must merge and cruise in lane 3"
		)

		print(
			"DRIVE_THRU_TEST: SUCCESS - Verified live simulation, dwell at stops, queueing without overlap, and clean seeded full-traffic phase with staggered cars completing loops without collisions or deadlocks!"
		)
		get_tree().quit(0)
		return
	if "--test-deadlock-watchdog" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()

		# Activate debug overlay to verify HUD reflects live counts throughout deadlock lifecycle
		var dbg: TrafficDebug = tm.debug_overlay
		assert(dbg != null, "debug_overlay must exist")
		dbg.visible = true
		assert(dbg.hud_layer.visible == true, "HUD layer must be visible when overlay is active")
		dbg.update_hud()
		var initial_hud: String = dbg.get_hud_text()
		assert(
			"watchdog_fires: 0" in initial_hud,
			"Initial HUD must show 0 watchdog fires: %s" % initial_hud
		)
		assert(
			"max_stuck_time: 0.0s" in initial_hud,
			"Initial HUD must show 0.0s max stuck: %s" % initial_hud
		)
		var path1 = Curve3D.new()
		path1.add_point(Vector3(0.0, 0.0, 0.0))
		path1.add_point(Vector3(30.0, 0.0, 0.0))

		var path2 = Curve3D.new()
		path2.add_point(Vector3(30.0, 0.0, 0.0))
		path2.add_point(Vector3(0.0, 0.0, 0.0))

		var car_scene = load("res://cars/passenger_car.tscn")
		var car1: Car = car_scene.instantiate()
		car1.car_type = Car.CarType.SEDAN
		car1.car_width = 2.0
		car1.car_length = 4.2
		tm.add_child(car1)
		car1.follow_path(path1)
		car1.path_distance = 10.0
		car1.speed = 4.0
		car1.state = Car.State.TO_SPOT
		car1.update_presentation()
		tm.lot_cars.append(car1)

		var car2: Car = car_scene.instantiate()
		car2.car_type = Car.CarType.SEDAN
		car2.car_width = 2.0
		car2.car_length = 4.2
		tm.add_child(car2)
		car2.follow_path(path2)
		car2.path_distance = 14.0  # x = 16.0, facing -X
		car2.speed = 4.0
		car2.state = Car.State.TO_SPOT
		car2.update_presentation()
		tm.lot_cars.append(car2)

		var higher_car := car1 if car1.get_instance_id() > car2.get_instance_id() else car2
		var lower_car := car2 if car1.get_instance_id() > car2.get_instance_id() else car1

		assert(tm.find_blocker(car1) == car2, "car1 must find car2 as blocker")
		assert(tm.find_blocker(car2) == car1, "car2 must find car1 as blocker")

		# Step for 3.8s (240 ticks of 0.016s) -> watchdog should NOT have fired yet (< 4.0s)
		for i in range(240):
			tm._update_lot_cars(0.016)
			dbg.update_hud()

		assert(tm.stats["watchdog_fires"] == 0, "Watchdog must not fire before 4.0s")
		assert(car1.speed < 0.1 and car2.speed < 0.1, "Both cars must be stopped")
		assert(
			car1.blocked_time >= 3.8 and car2.blocked_time >= 3.8,
			"Both cars must track blocked_time"
		)
		assert(tm.stats["max_stuck_time"] >= 3.8, "max_stuck_time must track blocked_time")
		var pre_fire_hud: String = dbg.get_hud_text()
		assert(
			"watchdog_fires: 0" in pre_fire_hud,
			"Pre-fire HUD must show 0 watchdog fires: %s" % pre_fire_hud
		)
		assert(
			"max_stuck_time: 3.8s" in pre_fire_hud,
			"Pre-fire HUD must show 3.8s max stuck: %s" % pre_fire_hud
		)

		# Step another 20 ticks (0.32s, reaching 4.12s > 4.0s) -> watchdog MUST fire!
		for i in range(20):
			tm._update_lot_cars(0.016)
			dbg.update_hud()

		assert(tm.stats["watchdog_fires"] == 1, "Watchdog must fire once mutual block exceeds 4.0s")
		assert(tm.stats["max_stuck_time"] >= 4.0, "max_stuck_time must be >= 4.0s")
		var post_fire_hud: String = dbg.get_hud_text()
		assert(
			"watchdog_fires: 1" in post_fire_hud,
			"Post-fire HUD must show 1 watchdog fire: %s" % post_fire_hud
		)
		assert(
			"max_stuck_time: 4.1s" in post_fire_hud or "max_stuck_time: 4.0s" in post_fire_hud,
			"Post-fire HUD must show >= 4.0s max stuck: %s" % post_fire_hud
		)
		assert(
			tm._is_ignoring(higher_car, lower_car) == true, "Higher ID car must ignore lower ID car"
		)
		assert(
			tm._is_ignoring(lower_car, higher_car) == false,
			"Lower ID car must NOT ignore higher ID car"
		)
		# Run another 20 ticks -> higher_car must accelerate and move while lower_car remains stopped
		for i in range(20):
			tm._update_lot_cars(0.016)

		assert(
			higher_car.speed > 0.5, "Higher ID car must accelerate and proceed (ignoring blocker)"
		)
		assert(lower_car.speed < 0.1, "Lower ID car must stay stopped and yield")
		assert(lower_car.desired_speed == 0.0, "Lower ID car desired speed must be 0.0")

		# Move higher_car well past lower_car to simulate clear conflict
		higher_car.path_distance = 28.0
		higher_car.update_presentation()
		for i in range(20):
			tm._update_lot_cars(0.016)

		assert(
			tm.find_blocker(lower_car) == null,
			"Lower car blocker must clear once higher car passes"
		)
		assert(lower_car.speed > 0.5, "Lower car must resume moving once conflict is cleared")
		# Verify HUD reflects live stall counts
		var spot = tm.lot.spots[0]
		spot.state = ParkingSpot.State.RESERVED
		tm.lot.spot_changed.emit(spot)
		var final_hud: String = dbg.get_hud_text()
		assert(
			"1 reserved" in final_hud, "HUD line must reflect live reserved count: %s" % final_hud
		)
		assert(
			"watchdog_fires: 1" in final_hud,
			"HUD line must preserve watchdog fire count: %s" % final_hud
		)

		print(
			"DEADLOCK_WATCHDOG_TEST: SUCCESS - Watchdog triggered at 4.0s, tiebreaker cleanly resolved deadlock!"
		)
		get_tree().quit(0)
		return
	if "--test-objective-manager" in _user_args:
		var obj_mgr: ObjectiveManager = $ObjectiveManager
		assert(obj_mgr != null, "ObjectiveManager must exist")
		assert(obj_mgr._is_test_mode() == true, "Must detect --test-* flag")
		obj_mgr._setup()
		assert(
			obj_mgr.current_state == ObjectiveManager.State.RINGING,
			"Must ring immediately in test mode"
		)
		assert(
			obj_mgr.current_errand != null and obj_mgr.current_errand.id == &"cough_syrup",
			"First errand must be cough_syrup"
		)
		# 2. First errand is always cough_syrup and targets Walgroins (north)
		assert(obj_mgr.completed_count == 0)
		assert(obj_mgr.current_errand.id == &"cough_syrup")
		assert(obj_mgr.current_errand.store_name == "Walgroins")
		var target_pos = obj_mgr.get_target_position(obj_mgr.current_errand)
		assert(target_pos.z < 0.0, "Walgroins target z must be North (negative z)")
		# 3. _pick_next() tests:
		# Case A: Mats at North (z = -30.0), last_completed = cough_syrup -> opposite side candidate is Booger King (hamburgers)
		mats.global_position = Vector3(0.0, 0.0, -30.0)
		obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		var next_errand = obj_mgr._pick_next()
		assert(
			next_errand.id == &"hamburgers",
			"Must pick hamburgers when Mats is North and last was cough_syrup"
		)

		# Case B: Mats at South (z = 30.0), last_completed = hamburgers -> opposite side candidates are cough_syrup & milk
		mats.global_position = Vector3(0.0, 0.0, 30.0)
		obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"hamburgers")
		for _i in range(20):
			var picked = obj_mgr._pick_next()
			assert(
				picked.id == &"cough_syrup" or picked.id == &"milk",
				"Must pick North errand (cough_syrup or milk)"
			)
			assert(picked.id != &"hamburgers", "Must exclude last completed errand")

		# Case C: Mats at South (z = 30.0), last_completed = cough_syrup -> opposite side candidate excluding cough_syrup is milk
		mats.global_position = Vector3(0.0, 0.0, 30.0)
		obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		next_errand = obj_mgr._pick_next()
		assert(
			next_errand.id == &"milk",
			"Must pick milk when cough_syrup is excluded on opposite side"
		)

		# Case D: Fallback when no candidates remain on opposite side:
		# Mats at North (z = -30.0), last_completed = hamburgers. Opposite candidate is hamburgers, which is excluded.
		mats.global_position = Vector3(0.0, 0.0, -30.0)
		obj_mgr.last_completed_errand = obj_mgr.get_errand_by_id(&"hamburgers")
		next_errand = obj_mgr._pick_next()
		assert(
			next_errand.id == &"cough_syrup" or next_errand.id == &"milk",
			"Must fall back to any errand except last one"
		)
		assert(next_errand.id != &"hamburgers", "Fallback must exclude last completed errand")
		# 4. Completion delay test:
		obj_mgr.current_state = ObjectiveManager.State.ACTIVE
		obj_mgr.current_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		var count_before = obj_mgr.completed_count
		obj_mgr.complete_objective()
		assert(obj_mgr.completed_count == count_before + 1, "completed_count must increment")
		assert(
			obj_mgr.current_state == ObjectiveManager.State.IDLE,
			"Must transition to IDLE after complete"
		)
		assert(is_equal_approx(obj_mgr.next_call_delay, 4.0), "next_call_delay must be 4.0s")
		assert(is_equal_approx(obj_mgr._call_timer, 4.0), "Must schedule next call with 4.0s delay")
		# Advance timer
		obj_mgr._process(4.1)
		assert(obj_mgr.current_state == ObjectiveManager.State.RINGING, "Must ring after 4s delay")
		assert(obj_mgr.current_errand != null, "Next errand must be picked")
		assert(obj_mgr._call_timer == -1.0, "Timer must be reset after starting call")

		# Start trigger with StartScreen simulation
		var dummy_mgr = ObjectiveManager.new()
		add_child(dummy_mgr)
		assert(dummy_mgr._started_once == false)
		dummy_mgr._on_start_screen_started()
		assert(dummy_mgr._started_once == true)
		assert(is_equal_approx(dummy_mgr._call_timer, dummy_mgr.initial_call_delay))
		# Second started signal (e.g. from H pause/resume) must NOT overwrite timer
		dummy_mgr._call_timer = 1.5
		dummy_mgr._on_start_screen_started()
		assert(
			is_equal_approx(dummy_mgr._call_timer, 1.5),
			"Subsequent started events must not overwrite timer"
		)
		dummy_mgr.queue_free()
		# 5. Arrival detection tests:
		obj_mgr.current_state = ObjectiveManager.State.ACTIVE
		obj_mgr.current_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		var walgroins_pos = obj_mgr.get_target_position(obj_mgr.current_errand)
		var count_at_arrival = obj_mgr.completed_count

		# Outside arrival radius: dist_xz = 5.0 > 2.5
		mats.global_position = walgroins_pos + Vector3(5.0, 0.0, 0.0)
		obj_mgr._physics_process(0.016)
		assert(
			obj_mgr.completed_count == count_at_arrival,
			"Must not complete when outside arrive_radius"
		)
		assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE)

		# Inside arrival radius, but Mats is dead
		mats.global_position = walgroins_pos + Vector3(1.0, 0.0, 0.0)
		obj_mgr._on_mats_died(mats.global_position)
		assert(obj_mgr._is_mats_dead == true)
		obj_mgr._physics_process(0.016)
		assert(
			obj_mgr.completed_count == count_at_arrival,
			"Must not complete arrival while Mats is dead"
		)

		# Mats respawns: arrival should complete
		obj_mgr._on_mats_respawned()
		assert(obj_mgr._is_mats_dead == false)
		mats.died.emit(mats.global_position)
		assert(obj_mgr._is_mats_dead == true, "mats.died signal must pause arrival checks")
		mats.respawned.emit()
		assert(obj_mgr._is_mats_dead == false, "mats.respawned signal must resume arrival checks")
		# Test horizontal XZ distance: large Y offset should still count as arrived if XZ is close
		mats.global_position = walgroins_pos + Vector3(1.0, 10.0, 1.0)  # XZ dist = sqrt(2) ≈ 1.414 < 2.5
		obj_mgr._physics_process(0.016)
		assert(
			obj_mgr.completed_count == count_at_arrival + 1,
			"Must complete arrival using horizontal XZ distance"
		)
		assert(obj_mgr.current_state == ObjectiveManager.State.IDLE)

		# Test: Mats already standing inside arrive radius when errand starts allows instant completion
		obj_mgr.current_state = ObjectiveManager.State.ACTIVE
		obj_mgr.current_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		mats.global_position = walgroins_pos + Vector3(0.5, 0.0, 0.5)
		var count_before_instant = obj_mgr.completed_count
		obj_mgr._physics_process(0.016)
		assert(
			obj_mgr.completed_count == count_before_instant + 1,
			"Mats already standing inside arrive_radius when errand starts must allow instant completion"
		)
		assert(obj_mgr.current_state == ObjectiveManager.State.IDLE)

		# 6. Phone call UI tests:
		var hud = $HUD
		assert(hud != null, "HUD must exist")
		var phone_call = hud.phone_call
		assert(phone_call != null, "PhoneCall must be instanced under HUD")
		assert(phone_call is PhoneCall, "phone_call must be of type PhoneCall")
		phone_call.set_objective_manager(obj_mgr)
		hud.set_objective_manager(obj_mgr)

		# 6a. HUD OBJ counter and objective line initial state:
		assert(hud.obj_label != null, "HUD must have obj_label")
		assert(hud.obj_label.text == "OBJ: 0", "HUD must show OBJ: 0 initially")
		assert(hud.obj_desc_label != null, "HUD must have obj_desc_label")
		assert(hud.obj_desc_label.text == "Errands Completed", "HUD must show Errands Completed")
		assert(hud.objective_line != null, "HUD must have objective_line")
		assert(
			hud.objective_line.visible == false,
			"Objective line must be hidden when no objective active"
		)
		var obj_style: StyleBoxFlat = hud.obj_panel_container.get_theme_stylebox("panel")
		assert(obj_style != null, "StyleBoxFlat must be set on OBJ panel")
		assert(
			obj_style.border_color.g > 0.7 and obj_style.border_color.r < 0.3,
			"OBJ panel border must be green"
		)
		var tri: Control = hud.objective_line.get_node_or_null("ObjectiveTriangle")
		assert(tri != null, "ObjectiveLine must contain ObjectiveTriangle")
		assert(tri.has_method("_draw"), "ObjectiveTriangle must have _draw()")
		tri.queue_redraw()
		hud.set_obj(3)
		assert(
			hud.obj_count == 3 and hud.obj_label.text == "OBJ: 3",
			"set_obj must update count and label"
		)
		hud.increment_obj()
		assert(
			hud.obj_count == 4 and hud.obj_label.text == "OBJ: 4",
			"increment_obj must update count and label"
		)
		hud.set_obj(0)
		# Verify HUD styling match
		var ring_style: StyleBoxFlat = phone_call.ringing_panel.get_theme_stylebox("panel")
		assert(ring_style != null, "StyleBoxFlat must be set on ringing panel")
		assert(
			ring_style.bg_color == Color(0.08, 0.1, 0.13, 0.85), "bg_color must match HUD dark bg"
		)
		assert(ring_style.corner_radius_top_left == 8, "corner radius must be 8")
		assert(
			ring_style.border_color.g > 0.7 and ring_style.border_color.r < 0.3,
			"border must be green"
		)
		var caller_font: Font = phone_call.caller_label.get_theme_font("font")
		assert(
			caller_font != null and "Overpass" in caller_font.resource_path,
			"Must use Overpass font"
		)
		var dialogue_font: Font = phone_call.dialogue_label.get_theme_font("font")
		assert(
			dialogue_font != null and "Overpass" in dialogue_font.resource_path,
			"Must use Overpass font"
		)

		# Test ringing UI state:
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		assert(phone_call.is_ringing == true, "PhoneCall must be ringing")
		assert(phone_call.visible == true, "PhoneCall must be visible")
		assert(phone_call.ringing_panel.visible == true, "RingingPanel must be visible")
		assert(
			phone_call.in_call_panel.visible == false, "InCallPanel must be hidden while ringing"
		)
		assert(phone_call.caller_label.text == "MOM", "Caller must be MOM")
		assert(phone_call.prompt_label.text == "[Enter] Answer", "Prompt must be [Enter] Answer")
		assert(mats.is_phone_ringing == true, "Mats must have phone ringing state")
		assert(
			phone_call._shake_tween != null and phone_call._shake_tween.is_valid(),
			"Shake tween must be active while ringing"
		)
		phone_call.phone_icon.queue_redraw()
		# Test answering call & in-call dialogue state:
		phone_call.answer()
		assert(obj_mgr.current_state == ObjectiveManager.State.IN_CALL, "Manager must be IN_CALL")
		assert(phone_call.is_in_call == true, "PhoneCall must be in_call")
		assert(phone_call.ringing_panel.visible == false, "RingingPanel must be hidden")
		assert(phone_call.in_call_panel.visible == true, "InCallPanel must be visible")
		assert(mats.is_on_phone == true, "Mats must be holding phone to ear during call")
		assert(phone_call.speaker_label.text == "Mom", "Speaker label must be Mom")
		assert(
			phone_call.dialogue_label.text == obj_mgr.current_errand.call_line,
			"Dialogue text must match errand call_line"
		)
		assert(
			phone_call._typewriter_tween != null and phone_call._typewriter_tween.is_valid(),
			"Typewriter tween must be active"
		)
		phone_call._finish_typewriter()
		assert(
			phone_call.dialogue_label.visible_ratio == 1.0, "visible_ratio must be 1.0 after finish"
		)

		# Test dismissal of dialogue:
		assert(phone_call.ok_prompt_label.text == "[Enter] OK", "Prompt must be [Enter] OK")
		var dismissed := [false]
		phone_call.call_dismissed.connect(func(): dismissed[0] = true)
		phone_call.dismiss()
		assert(dismissed[0] == true, "call_dismissed must be emitted on dismiss")
		assert(
			obj_mgr.current_state == ObjectiveManager.State.ACTIVE,
			"Manager must transition to ACTIVE"
		)
		assert(phone_call.visible == false, "PhoneCall must be hidden after dismiss")
		assert(phone_call.is_in_call == false, "is_in_call must be false")
		assert(mats.is_on_phone == false, "Mats must not be on phone after dismiss")
		assert(
			hud.objective_line.visible == true,
			"Objective line must be visible when objective is active"
		)
		assert(
			hud.current_objective_label.text == "Get cough syrup at Walgroins",
			"Objective line text must match current objective"
		)

		# Test completion hides objective line:
		obj_mgr.complete_objective()
		assert(
			hud.objective_line.visible == false, "Objective line must hide when objective completed"
		)

		# Test _unhandled_input handling:
		# 1. When hidden, input is ignored
		var a_test_ev := InputEventKey.new()
		a_test_ev.pressed = true
		a_test_ev.keycode = KEY_A
		a_test_ev.physical_keycode = KEY_A
		phone_call._unhandled_input(a_test_ev)
		assert(phone_call.visible == false, "Input while hidden must be ignored")

		var test_ev := InputEventKey.new()
		test_ev.pressed = true
		test_ev.keycode = KEY_ENTER
		test_ev.physical_keycode = KEY_ENTER
		# 2. Ringing: input answers call
		obj_mgr.current_state = ObjectiveManager.State.IDLE
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		assert(phone_call.is_ringing == true)
		# Key A must not answer
		phone_call._unhandled_input(a_test_ev)
		assert(phone_call.is_ringing == true, "Key A must not answer call")
		assert(phone_call.is_in_call == false)
		# Enter must answer
		phone_call._unhandled_input(test_ev)
		assert(phone_call.is_in_call == true, "_unhandled_input must answer ringing call")
		assert(obj_mgr.current_state == ObjectiveManager.State.IN_CALL)

		# 3. In-call: first input finishes typewriter if running
		phone_call.dialogue_label.visible_ratio = 0.2
		phone_call._unhandled_input(test_ev)
		assert(
			phone_call.dialogue_label.visible_ratio == 1.0,
			"Input must finish typewriter if animating"
		)
		assert(phone_call.is_in_call == true)

		# 4. In-call: second input dismisses call
		phone_call._unhandled_input(test_ev)
		assert(phone_call.visible == false, "Input must dismiss call when typewriter complete")
		assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE)

		# 5. answer_phone ActionMap test:
		assert(InputMap.has_action("answer_phone"), "InputMap must define answer_phone")
		var enter_ev := InputEventKey.new()
		enter_ev.pressed = true
		enter_ev.physical_keycode = KEY_ENTER
		assert(enter_ev.is_action_pressed("answer_phone"), "Enter must trigger answer_phone")
		var a_ev := InputEventKey.new()
		a_ev.pressed = true
		a_ev.physical_keycode = KEY_A
		assert(not a_ev.is_action_pressed("answer_phone"), "A must not trigger answer_phone")
		var joy_ev := InputEventJoypadButton.new()
		joy_ev.pressed = true
		joy_ev.button_index = JOY_BUTTON_A
		assert(joy_ev.is_action_pressed("answer_phone"), "Gamepad A must trigger answer_phone")
		obj_mgr.current_state = ObjectiveManager.State.IDLE
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		assert(phone_call.is_ringing == true)
		phone_call._unhandled_input(joy_ev)
		assert(phone_call.is_in_call == true, "Must answer via answer_phone action")
		phone_call.dismiss()

		# Test: Don't ring while StartScreen is open or tree is paused
		var start_screen_node = get_node_or_null("StartScreen")
		obj_mgr.current_state = ObjectiveManager.State.IDLE
		obj_mgr._call_timer = 1.0
		if start_screen_node:
			start_screen_node.visible = true
			obj_mgr._process(2.0)
			assert(
				obj_mgr.current_state == ObjectiveManager.State.IDLE,
				"Must not ring while StartScreen is visible"
			)
			assert(
				obj_mgr._call_timer == 1.0,
				"Call timer must not advance while StartScreen is visible"
			)
			start_screen_node.visible = false

		# Don't ring while tree is paused
		get_tree().paused = true
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		assert(
			obj_mgr.current_state == ObjectiveManager.State.IDLE,
			"Must not ring while tree is paused"
		)
		get_tree().paused = false

		# Opening start screen / pause mid-call does not break state machine
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		assert(obj_mgr.current_state == ObjectiveManager.State.RINGING)
		phone_call.answer()
		assert(obj_mgr.current_state == ObjectiveManager.State.IN_CALL)
		# Simulate pause mid-call
		get_tree().paused = true
		assert(
			obj_mgr.current_state == ObjectiveManager.State.IN_CALL,
			"State must remain IN_CALL while paused"
		)
		phone_call._unhandled_input(test_ev)
		assert(
			obj_mgr.current_state == ObjectiveManager.State.IN_CALL,
			"Input while paused must be ignored"
		)
		get_tree().paused = false
		phone_call.dismiss()
		assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE)
		obj_mgr.complete_objective()
		# 6. FollowCamera ignores camera_left during phone call:
		var cam := get_node_or_null("Camera3D") as FollowCamera
		if cam:
			obj_mgr.current_state = ObjectiveManager.State.RINGING
			assert(
				obj_mgr.is_call_showing() == true,
				"ObjectiveManager must report call showing when ringing"
			)
			assert(
				cam._is_phone_call_showing() == true, "Camera must detect ringing call via group"
			)
			obj_mgr.current_state = ObjectiveManager.State.IN_CALL
			assert(
				obj_mgr.is_call_showing() == true,
				"ObjectiveManager must report call showing when in call"
			)
			assert(
				cam._is_phone_call_showing() == true, "Camera must detect in-call state via group"
			)
			obj_mgr.current_state = ObjectiveManager.State.ACTIVE
			assert(
				obj_mgr.is_call_showing() == false,
				"ObjectiveManager must not report call showing when active"
			)
			assert(
				cam._is_phone_call_showing() == false,
				"Camera must not report call showing when active"
			)
			obj_mgr.current_state = ObjectiveManager.State.IDLE
			assert(
				cam._is_phone_call_showing() == false,
				"Camera must not report call showing when idle"
			)
		# 7. World marker (ObjectiveMarker) tests:
		obj_mgr.current_state = ObjectiveManager.State.IDLE
		obj_mgr.start_call(obj_mgr.get_errand_by_id(&"cough_syrup"))
		obj_mgr.answer_call()
		obj_mgr.dismiss_call()
		assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE)
		assert(
			obj_mgr.current_marker != null, "ObjectiveMarker must be spawned on active objective"
		)
		var marker: ObjectiveMarker = obj_mgr.current_marker
		assert(marker is ObjectiveMarker, "current_marker must be of type ObjectiveMarker")
		assert(marker.is_inside_tree(), "ObjectiveMarker must be added to scene tree")
		var expected_pos := obj_mgr.get_target_position(obj_mgr.current_errand)
		var dist_xz := (
			Vector2(
				marker.global_position.x - expected_pos.x, marker.global_position.z - expected_pos.z
			)
			. length()
		)
		assert(dist_xz < 0.1, "Marker XZ position must match errand target position")
		assert(
			is_zero_approx(marker.global_position.y),
			"Marker ground position Y must be at ground level (0.0)"
		)
		# Cone checks:
		assert(marker.cone_mesh != null and marker.cone_mesh.mesh is CylinderMesh)
		var cyl_mesh: CylinderMesh = marker.cone_mesh.mesh
		assert(is_zero_approx(cyl_mesh.top_radius), "Cone mesh top_radius must be 0")
		assert(is_equal_approx(marker.cone_mesh.rotation.x, PI), "Cone mesh must point downwards")
		assert(is_equal_approx(marker.base_cone_height, 6.0), "base_cone_height must be 6.0m")
		var init_y := marker.cone_pivot.position.y
		var init_rot := marker.cone_pivot.rotation.y
		marker._process(0.3)
		assert(
			not is_equal_approx(marker.cone_pivot.position.y, init_y),
			"Cone pivot must bob with sine wave"
		)
		assert(
			not is_equal_approx(marker.cone_pivot.rotation.y, init_rot),
			"Cone pivot must rotate over time"
		)
		assert(
			marker.cone_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"Cone material must be unshaded"
		)
		assert(marker.cone_material.albedo_color.g > 0.8, "Cone must be green")

		# Ground ring checks:
		assert(marker.ground_ring != null and marker.ground_ring.mesh is TorusMesh)
		var torus_mesh: TorusMesh = marker.ground_ring.mesh
		assert(
			is_equal_approx(torus_mesh.outer_radius, obj_mgr.arrive_radius),
			"TorusMesh outer_radius must match arrive_radius"
		)
		assert(
			marker.ring_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"Ring material must be translucent"
		)
		assert(marker.ring_material.albedo_color.a < 1.0, "Ring material alpha must be < 1.0")
		assert(marker.ring_material.albedo_color.g > 0.8, "Ring must be green")
		marker.arrive_radius = 3.5
		assert(is_equal_approx((marker.ground_ring.mesh as TorusMesh).outer_radius, 3.5))
		marker.arrive_radius = 2.5

		# Store label checks:
		assert(marker.label != null and marker.label is Label3D)
		assert(
			marker.label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"StoreLabel must be billboarded"
		)
		assert(marker.label.text == "Walgroins", "StoreLabel text must match store name")
		assert(marker.label.visible == true, "StoreLabel must be visible when store name is set")
		marker.store_name = "Booger King"
		assert(marker.label.text == "Booger King")
		marker.store_name = ""
		assert(marker.label.visible == false, "StoreLabel must hide when store name is empty")
		marker.store_name = "Walgroins"
		assert(marker.label.visible == true)

		# Emissive / night readability checks:
		assert(
			marker.cone_material.emission_enabled == true,
			"Cone material must have emission enabled"
		)
		assert(
			marker.cone_material.emission == marker.marker_color,
			"Cone emission must match marker_color"
		)
		assert(
			marker.cone_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"Cone material must be unshaded for night readability"
		)
		assert(
			marker.ring_material.emission_enabled == true,
			"Ring material must have emission enabled"
		)
		assert(
			marker.ring_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"Ring material must be unshaded for night readability"
		)
		var orig_tod: GameState.TimeOfDay = GameState.time_of_day
		GameState.set_time_of_day(GameState.TimeOfDay.NIGHT)
		assert(marker.cone_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
		GameState.set_time_of_day(orig_tod)

		# No collision and no shadow checks:
		assert(
			not ((marker as Variant) is CollisionObject3D), "Marker must not be CollisionObject3D"
		)
		for child in marker.find_children("*", "", true, false):
			assert(
				not (child is CollisionObject3D),
				"Marker child %s must not be CollisionObject3D" % child.name
			)
			assert(
				not (child is CollisionShape3D),
				"Marker child %s must not be CollisionShape3D" % child.name
			)
			if child is GeometryInstance3D:
				assert(
					child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					"Marker visual %s must not cast shadows" % child.name
				)

		# Completion scale-up and fade tween:
		var completing_marker := obj_mgr.current_marker
		assert(completing_marker != null)
		assert(completing_marker._is_completing == false)
		obj_mgr.complete_objective()
		assert(obj_mgr.current_marker == null, "obj_mgr must clear current_marker on completion")
		assert(
			completing_marker._is_completing == true, "complete_and_free must set _is_completing"
		)
		assert(
			completing_marker.pop_particles != null, "complete_and_free must spawn pop_particles"
		)
		assert(completing_marker.pop_particles is CPUParticles3D)
		assert(completing_marker.pop_particles.one_shot == true)
		assert(completing_marker.pop_particles.emitting == true)
		var pop_node: CPUParticles3D = completing_marker.pop_particles
		assert(is_instance_valid(completing_marker), "Marker should still be valid during tween")
		await get_tree().create_timer(0.5).timeout
		assert(
			not is_instance_valid(completing_marker), "Marker should be freed after tween completes"
		)
		await get_tree().create_timer(0.3).timeout
		assert(not is_instance_valid(pop_node), "Particle pop should be freed after lifetime")
		# 8. ObjectiveArrow tests:
		var arrow: ObjectiveArrow = hud.objective_arrow
		assert(arrow != null, "HUD must have objective_arrow")
		assert(arrow is ObjectiveArrow, "objective_arrow must be of type ObjectiveArrow")
		assert(arrow.edge_margin == 60.0, "edge_margin must default to 60px")
		arrow._resolve_dependencies()
		arrow.camera = cam
		arrow.objective_manager = obj_mgr

		# Check projection and behind calculation
		var cam_3d: Camera3D = cam
		var behind_pos := cam_3d.global_position + cam_3d.global_basis.z * 10.0
		var front_pos := cam_3d.global_position - cam_3d.global_basis.z * 10.0
		assert(cam_3d.is_position_behind(behind_pos) == true, "Must detect position behind camera")
		assert(
			cam_3d.is_position_behind(front_pos) == false, "Must detect position in front of camera"
		)
		var unproj_front := cam_3d.unproject_position(front_pos)
		assert(unproj_front is Vector2, "unproject_position must return Vector2")

		# Test on-screen hiding:
		obj_mgr.current_state = ObjectiveManager.State.ACTIVE
		obj_mgr.current_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		target_pos = obj_mgr.get_target_position(obj_mgr.current_errand)
		# Aim camera directly at target from 10m back
		cam_3d.global_position = target_pos + Vector3(0.0, 5.0, 15.0)
		cam_3d.look_at(target_pos)
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == false, "Arrow must be hidden when target is on screen")
		assert(
			arrow.distance_label.visible == false,
			"Distance label must be hidden when target is on screen"
		)

		# Test off-screen clamping & rotation (target to the right):
		var vp_rect := arrow.get_viewport_rect()
		# Camera at origin looking north (0, 0, -1), target far east (100, 0, -10)
		cam_3d.global_position = Vector3(0.0, 1.5, 0.0)
		cam_3d.look_at(Vector3(0.0, 1.5, -10.0))
		var east_pos := Vector3(100.0, 1.5, -10.0)
		# Temporarily override target position via dummy errand or moving node
		var orig_errand_id := obj_mgr.current_errand.id
		# We can test with target behind camera: target is at (0, 1.5, 50.0)
		cam_3d.global_position = Vector3(0.0, 1.5, 0.0)
		cam_3d.look_at(Vector3(0.0, 1.5, -10.0))
		# Target pos for cough syrup is at z ≈ -31.35. Camera looking south:
		cam_3d.look_at(Vector3(0.0, 1.5, 10.0))  # camera looks South, target is North (behind camera!)
		arrow.update_arrow()
		assert(
			arrow.is_arrow_visible == true,
			"Arrow must be visible when target is off-screen / behind"
		)
		assert(
			is_equal_approx(arrow.arrow_screen_pos.x, vp_rect.size.x - 60.0),
			"Behind camera looking south with target at x<0 must clamp to right margin"
		)
		assert(cam_3d.is_position_behind(target_pos) == true, "Target must be behind camera")
		assert(cos(arrow.arrow_rotation) > 0.9, "Arrow rotation must point right")

		# Camera looks east (10, 1.5, 0), target is north (-3, 1.3, -31.35) -> target is to the left in front of camera
		cam_3d.global_position = Vector3(-3.0, 1.3, -10.0)
		cam_3d.look_at(Vector3(20.0, 1.3, -10.0))  # looking east (+X)
		# target is at Z=-31.35, which is to the left (-Z relative to +X)
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == true, "Arrow must be visible when target is off-screen")
		assert(
			arrow.arrow_screen_pos.x <= vp_rect.size.x - 60.0 and arrow.arrow_screen_pos.x >= 60.0,
			"X clamped within margin"
		)
		assert(
			arrow.arrow_screen_pos.y <= vp_rect.size.y - 60.0 and arrow.arrow_screen_pos.y >= 60.0,
			"Y clamped within margin"
		)
		# At least one dimension must be clamped to the margin
		assert(
			is_equal_approx(arrow.arrow_screen_pos.x, 60.0),
			"Target to the left must clamp to left margin"
		)
		# Angle pointing left is PI (or -PI)
		assert(
			absf(absf(arrow.arrow_rotation) - PI) < 0.1,
			"Arrow rotation must point left (-X in screen)"
		)
		# Distance label verification
		assert(arrow.distance_label != null, "Distance label must exist")
		assert(
			arrow.distance_label.visible == true, "Distance label must be visible when off-screen"
		)
		assert(arrow.distance_label.text.ends_with(" m"), "Distance label must end with ' m'")
		# Explicit 42 m test:
		mats.global_position = Vector3(target_pos.x, 0.0, target_pos.z + 42.0)
		arrow.update_arrow()
		assert(arrow.distance_meters == 42, "distance_meters must be 42")
		assert(arrow.distance_label.text == "42 m", "Distance label must display '42 m'")
		# Arrow draw verification:
		assert(arrow.has_method("_draw"), "ObjectiveArrow must implement _draw()")
		assert(arrow.arrow_color.g > 0.8, "Arrow color must be objective green")
		arrow.queue_redraw()
		# Overlay hiding tests:
		assert(arrow.is_arrow_visible == true, "Arrow must start visible off-screen")

		# 1. StartScreen open hides arrow
		var start_screen: StartScreen = get_node_or_null("StartScreen")
		if start_screen:
			start_screen.visible = true
			arrow.update_arrow()
			assert(arrow.is_arrow_visible == false, "StartScreen open must hide arrow")
			assert(
				arrow.distance_label.visible == false, "StartScreen open must hide distance label"
			)
			start_screen.visible = false
			arrow.update_arrow()
			assert(arrow.is_arrow_visible == true, "Closing StartScreen must restore arrow")

		# 2. CharacterEditor open hides arrow
		var char_editor: CharacterEditor = get_node_or_null("CharacterEditor")
		if char_editor:
			char_editor.open_editor()
			assert(get_tree().paused == true, "CharacterEditor must pause the tree")
			assert(arrow.is_arrow_visible == false, "CharacterEditor open must hide arrow")
			assert(
				arrow.distance_label.visible == false,
				"CharacterEditor open must hide distance label"
			)
			char_editor.close_editor()
			assert(get_tree().paused == false, "Closing CharacterEditor must unpause the tree")
			assert(arrow.is_arrow_visible == true, "Closing CharacterEditor must restore arrow")

			# Test CharacterEditor hiding the phone call overlay:
			phone_call.show_ringing()
			assert(phone_call.visible == true, "Phone call starts visible")
			char_editor.open_editor()
			assert(phone_call.visible == false, "CharacterEditor open must hide phone call overlay")
			char_editor.close_editor()
			assert(
				phone_call.visible == true,
				"Closing CharacterEditor must restore phone call overlay"
			)
			phone_call.hide_all()

		# 3. Call overlay open hides arrow
		phone_call.show_ringing()
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == false, "Ringing call must hide arrow")
		phone_call.hide_all()
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == true, "Hiding call must restore arrow")

		phone_call.show_in_call()
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == false, "In-call dialogue must hide arrow")
		phone_call.hide_all()
		arrow.update_arrow()
		assert(arrow.is_arrow_visible == true, "Hiding in-call must restore arrow")

		# 9. Success feedback toast tests:
		var toast: ObjectiveToast = hud.objective_toast
		assert(toast != null, "HUD must have objective_toast")
		assert(toast is ObjectiveToast, "objective_toast must be of type ObjectiveToast")
		assert(toast.checkmark != null, "Toast must have checkmark child")
		assert(toast.checkmark is ObjectiveCheckmark, "Checkmark must be ObjectiveCheckmark")
		assert(toast.checkmark.has_method("_draw"), "Checkmark must implement _draw()")
		assert(toast.checkmark.color.g > 0.8, "Checkmark must be green")
		assert(
			toast.anchor_left == 0.5 and toast.anchor_right == 0.5, "Toast must be center-anchored"
		)
		assert(
			toast.anchor_top == 0.5 and toast.anchor_bottom == 0.5, "Toast must be center-anchored"
		)

		# Test show_toast() with scale-in, hold, and fade-out timing
		hud.show_toast("Got the cough syrup!", 2.0)
		assert(toast.is_showing() == true, "Toast must be showing immediately after show_toast")
		assert(toast.get_text() == "Got the cough syrup!", "Toast text must match")
		await get_tree().create_timer(0.4).timeout
		assert(toast.is_showing() == true, "Toast must be visible after scale-in")
		assert(toast.modulate.a > 0.9, "Toast modulate alpha must be ~1.0 after scale-in")
		assert(is_equal_approx(toast.scale.x, 1.0), "Toast scale must be 1.0 after scale-in")
		await get_tree().create_timer(0.8).timeout  # t = 1.2s total
		assert(toast.is_showing() == true, "Toast must still be held visible at ~1.2s")
		assert(toast.modulate.a > 0.9, "Toast modulate alpha must still be ~1.0 during hold")
		await get_tree().create_timer(1.0).timeout  # t = 2.2s total
		assert(toast.visible == false, "Toast must be hidden after 2.0s duration and fade-out")

		# Test complete_objective triggers toast with errand success_line
		obj_mgr.current_state = ObjectiveManager.State.ACTIVE
		obj_mgr.current_errand = obj_mgr.get_errand_by_id(&"cough_syrup")
		obj_mgr.complete_objective()
		assert(toast.is_showing() == true, "complete_objective must trigger toast")
		assert(
			toast.get_text() == "Got the cough syrup!",
			"complete_objective toast text must match errand success_line"
		)

		# Test CharacterEditor open hides toast
		if char_editor:
			char_editor.open_editor()
			assert(toast.visible == false, "Opening CharacterEditor must hide toast")
			char_editor.close_editor()
		# Test hud.increment_obj() and green flash on complete_objective
		assert(hud.obj_count == obj_mgr.completed_count, "HUD obj_count must match completed_count")
		assert(
			hud.obj_label.text == "OBJ: %d" % obj_mgr.completed_count,
			"HUD obj_label must display completed_count"
		)
		assert(hud.obj_label.modulate.g > 0.8, "HUD obj_label must flash green on complete")

		# Test calling hud.increment_obj() directly
		var obj_before: int = hud.obj_count
		hud.increment_obj()
		assert(hud.obj_count == obj_before + 1, "Direct increment_obj must increase obj_count by 1")
		assert(
			hud.obj_label.text == "OBJ: %d" % (obj_before + 1),
			"Direct increment_obj must update label"
		)
		assert(hud.obj_label.modulate.g > 0.8, "Direct increment_obj must flash green")

		print("OBJECTIVE_MANAGER_TEST: SUCCESS - All ObjectiveManager test cases passed!")
		get_tree().quit(0)
		return
	if "--test-objectives" in _user_args:
		# Allow deferred setup across ObjectiveManager, HUD, and PhoneCall to resolve naturally
		await get_tree().process_frame
		var obj_mgr: ObjectiveManager = $ObjectiveManager
		assert(obj_mgr != null, "ObjectiveManager must exist")
		var hud = $HUD
		assert(hud != null, "HUD must exist")

		# 1. The first call is cough_syrup, and its target is on the north side (z < 0).
		assert(
			obj_mgr.current_state == ObjectiveManager.State.RINGING, "First call must be ringing"
		)
		assert(obj_mgr.current_errand != null, "Current errand must be set")
		assert(obj_mgr.current_errand.id == &"cough_syrup", "First errand must be cough_syrup")
		var target_pos := obj_mgr.get_target_position(obj_mgr.current_errand)
		assert(target_pos.z < 0.0, "First errand target must be on the north side (z < 0)")

		# 2. Answer programmatically, teleport Mats to the target, and assert completed_count == 1 and the HUD shows "OBJ: 1".
		var phone_call = hud.phone_call
		if phone_call and phone_call.is_ringing:
			phone_call.answer()
			phone_call.dismiss()
		else:
			obj_mgr.answer_call()
			obj_mgr.dismiss_call()
		assert(obj_mgr.current_state == ObjectiveManager.State.ACTIVE, "Must be ACTIVE after call")

		mats.global_position = target_pos
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(obj_mgr.completed_count == 1, "completed_count must be 1 after reaching target")
		assert(hud.obj_label != null and hud.obj_label.text == "OBJ: 1", "HUD must show 'OBJ: 1'")

		# 3. The next errand's target z sign is opposite Mats's z sign.
		obj_mgr.start_call()
		assert(obj_mgr.current_errand != null, "Next errand must be set")
		var next_target_pos := obj_mgr.get_target_position(obj_mgr.current_errand)
		assert(
			signf(next_target_pos.z) != signf(mats.global_position.z),
			(
				"Next errand target z sign (%f) must be opposite Mats's z sign (%f)"
				% [next_target_pos.z, mats.global_position.z]
			)
		)

		# 4. Quit with exit code 0.
		print("OBJECTIVES_TEST: SUCCESS - --test-objectives passed cleanly!")
		get_tree().quit(0)
		return


func _physics_process(_delta: float) -> void:
	if "--test-mats-blocker" in _user_args or "--test-mats-interaction" in _user_args:
		_test_frames += 1
		if _mats_stage == 0:
			# Push Mats south along sidewalk into the car (from z=-13 toward z=-9.6)
			mats.velocity = Vector3(0.0, 0.0, 5.0)
			if _test_frames > 60:
				print(
					"MATS_TEST [1/2]: mats_pos=",
					mats.global_position,
					" mats_dead=",
					mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(not mats._is_dead, "Mats died on stopped car!")
				assert(
					mats.global_position.z < -11.0,
					"Mats walked through stopped car across sidewalk!"
				)
				assert(
					_test_car.blocker.collision_layer == 4,
					"Blocker must be on layer 3 when stopped!"
				)
				print(
					"MATS_TEST: Part 1 SUCCESS - Mats was blocked across the sidewalk without dying!"
				)
				_mats_stage = 1
				_mats_start_frame = _test_frames
				# Prepare Stage 2: place Mats on sidewalk apron in front of car in merge path
				mats.global_position = Vector3(9.0, 0.5, -7.0)
				mats.velocity = Vector3.ZERO
				# Initiate car merge
				_test_car.state = Car.State.MERGING
				_test_car.follow_path(ParkingLot.merge_route())
				_test_car.desired_speed = 5.0
				_test_car.speed = 1.0
				_test_car._update_blocker_layer()
		elif _mats_stage == 1:
			# Advance merging car along merge route toward Mats
			_test_car.speed = move_toward(_test_car.speed, _test_car.desired_speed, 8.0 * _delta)
			_test_car.advance_path(_delta)
			if mats._is_dead:
				print(
					"MATS_TEST [2/2]: car_pos=",
					_test_car.global_position,
					" car_speed=",
					_test_car.speed,
					" mats_dead=",
					mats._is_dead,
					" blocker_layer=",
					_test_car.blocker.collision_layer
				)
				assert(_test_car.speed > 0.1, "Car must be moving when Mats dies!")
				assert(
					_test_car.blocker.collision_layer == 0, "Blocker must be disabled while moving!"
				)
				print(
					"MATS_TEST: Part 2 SUCCESS - Mats dies when hit by car pulling out into merge!"
				)
				print(
					"MATS_TEST: ALL CHECKS PASSED - Mats is stopped by car waiting across sidewalk, and dies if hit by car pulling out into merge!"
				)
				get_tree().quit(0)
			elif _test_frames - _mats_start_frame > 120:
				assert(false, "Timeout: Mats did not die when hit by car pulling out into merge!")

	if "--test-mats-walk" in _user_args:
		_test_frames += 1
		if _test_frames <= 60 or _test_frames >= 105:
			mats.velocity = Vector3(0.0, 0.0, mats.walk_speed)
		elif _test_frames == 61:
			mats.velocity = Vector3(0.0, sqrt(2.0 * mats.gravity * mats.jump_height), 0.0)
		elif _test_frames > 61 and not mats.is_on_floor():
			mats.velocity.x = 0.0
			mats.velocity.z = 0.0
		elif mats.is_on_floor():
			mats.velocity = Vector3.ZERO
		var shoe_l: Node3D = mats.get_node("Visual/LeftLegPivot/Knee/Shoe")
		var shoe_r: Node3D = mats.get_node("Visual/RightLegPivot/Knee/Shoe")
		var shoe_bottom_local := Vector3(0.0, -0.07, 0.0)
		var l_y := (shoe_l.global_transform * shoe_bottom_local).y
		var r_y := (shoe_r.global_transform * shoe_bottom_local).y
		var lowest_shoe_y := minf(l_y, r_y)
		var l_z := (shoe_l.global_transform * shoe_bottom_local).z
		var r_z := (shoe_r.global_transform * shoe_bottom_local).z
		var stance_is_left := l_y <= r_y
		var stance_z := l_z if stance_is_left else r_z
		if _test_frames >= 40 and _test_frames <= 50:
			var l_hip: Node3D = mats.get_node("Visual/LeftLegPivot")
			var r_hip: Node3D = mats.get_node("Visual/RightLegPivot")
			var l_knee: Node3D = mats.get_node("Visual/LeftLegPivot/Knee")
			var r_knee: Node3D = mats.get_node("Visual/RightLegPivot/Knee")
			print(
				(
					"F%d ph=%.2f sw=%.2f st=%.2f | L: rot_x=%.2f kn=%.2f y=%.3f z=%.3f | R: rot_x=%.2f kn=%.2f y=%.3f z=%.3f"
					% [
						_test_frames,
						mats._stride_phase,
						sin(mats._stride_phase),
						cos(mats._stride_phase),
						l_hip.rotation.x,
						l_knee.rotation.x,
						l_y,
						l_z,
						r_hip.rotation.x,
						r_knee.rotation.x,
						r_y,
						r_z,
					]
				)
			)
		elif _test_frames % 10 == 0:
			print(
				(
					"WALK_TEST frame=%d z=%.2f mats_y=%.3f floor=%s rel_shoe_y=%.4f (l=%.4f, r=%.4f) stance=%s stance_z=%.3f"
					% [
						_test_frames,
						mats.global_position.z,
						mats.global_position.y,
						mats.is_on_floor(),
						lowest_shoe_y - mats.global_position.y,
						l_y - mats.global_position.y,
						r_y - mats.global_position.y,
						"L" if stance_is_left else "R",
						stance_z,
					]
				)
			)
		var rel_y := lowest_shoe_y - mats.global_position.y
		if _test_frames >= 10 and _test_frames <= 60:
			assert(
				absf(rel_y) <= 0.01,
				(
					"Lowest shoe point exceeded 1 cm from floor during walk at frame %d: %.4f"
					% [_test_frames, rel_y]
				)
			)
		if _test_frames >= 61 and _test_frames <= 115 and mats.is_on_floor():
			assert(
				absf(rel_y) <= 0.01,
				(
					"Lowest shoe point exceeded 1 cm from floor during landing/recovery at frame %d: %.4f"
					% [_test_frames, rel_y]
				)
			)
		if _test_frames > 65 and mats.is_on_floor() and mats._squash >= 0.3:
			_mats_squash_frames += 1
			var l_knee: Node3D = mats.get_node("Visual/LeftLegPivot/Knee")
			var r_knee: Node3D = mats.get_node("Visual/RightLegPivot/Knee")
			assert(
				l_knee.rotation.x >= 0.15 and r_knee.rotation.x >= 0.15,
				(
					"Knees must bend during landing squash (L: %.3f, R: %.3f, squash: %.3f)"
					% [l_knee.rotation.x, r_knee.rotation.x, mats._squash]
				)
			)
		if _test_frames >= 115:
			assert(
				absf(rel_y) <= 0.01,
				(
					"Lowest shoe point exceeded 1 cm from floor after resume walk at frame %d: %.4f"
					% [_test_frames, rel_y]
				)
			)
		if _test_frames >= 160:
			assert(
				_mats_squash_frames > 0,
				(
					"Landing squash assertion must run at least once (ran %d times)"
					% _mats_squash_frames
				)
			)
			print(
				(
					"WALK_TEST completed: walk stride, jump, and landing squash knee bend verified (squash frames=%d)!"
					% _mats_squash_frames
				)
			)
			get_tree().quit(0)
		elif _test_frames >= 200:
			assert(false, "Timeout in WALK_TEST")
	if "--test-mats-cart" in _user_args:
		_test_frames += 1
		var vis: Node3D = mats.get_node("Visual")
		var left_knee: Node3D = mats.get_node("Visual/LeftLegPivot/Knee")
		var left_leg: Node3D = mats.get_node("Visual/LeftLegPivot")
		var left_ankle: Node3D = mats.get_node("Visual/LeftLegPivot/Knee/Shoe")
		if _cart_test_stage == 0:
			var cur_rot_y := vis.rotation.y
			var d_rot := absf(wrapf(cur_rot_y - _cart_prev_rot_y, -PI, PI))
			assert(d_rot < 0.45, "Abrupt rotation jump during cart mount: %f" % d_rot)
			_cart_prev_rot_y = cur_rot_y
			if _test_frames >= 24:
				assert(
					absf(vis.rotation.y) < 0.01,
					"Visual rotation Y not 0 at sit: %f" % vis.rotation.y
				)
				assert(
					absf(vis.rotation.x) < 0.01,
					"Visual rotation X not 0 at sit: %f" % vis.rotation.x
				)
				assert(
					absf(vis.rotation.z) < 0.01,
					"Visual rotation Z not 0 at sit: %f" % vis.rotation.z
				)
				var target_y := Mats.KNEEL_HIP_HEIGHT - left_leg.position.y
				assert(
					absf(vis.position.y - target_y) < 0.01,
					"Visual position Y mismatch at sit: %f vs %f" % [vis.position.y, target_y]
				)
				assert(
					absf(left_knee.rotation.x - Mats.KNEEL_KNEE_ROTATION) < 0.01,
					"Knee rotation mismatch at sit"
				)
				assert(
					absf(left_ankle.rotation.x - Mats.KNEEL_ANKLE_ROTATION) < 0.01,
					"Ankle rotation mismatch at sit"
				)
				var left_arm: Node3D = mats.get_node("Visual/LeftArmPivot")
				var left_elbow: Node3D = mats.get_node("Visual/LeftArmPivot/Elbow")
				assert(
					absf(left_arm.rotation.x - Mats.KNEEL_SHOULDER_ROTATION) < 0.01,
					"Shoulder rotation mismatch at sit"
				)
				assert(
					absf(left_elbow.rotation.x - Mats.KNEEL_ELBOW_ROTATION) < 0.01,
					"Elbow rotation mismatch at sit"
				)
				assert(_cart_test_cart._rider == mats, "ShoppingCart rider must be set to mats")
				_cart_test_stage = 1
				_test_frames = 0
		elif _cart_test_stage == 1:
			if _test_frames >= 5:
				_cart_test_stage = 2
				_test_frames = 0
				mats.exit_cart(_cart_test_cart.get_node("ExitPosition"))
		elif _cart_test_stage == 2:
			if _test_frames >= 24:
				assert(
					mats.is_physics_processing(),
					"Physics processing must resume after exiting cart"
				)
				assert(
					left_knee.rotation.x < 0.35,
					"Knee rotation must return to idle stance after exit: %f" % left_knee.rotation.x
				)
				assert(
					absf(vis.position.y) < 0.05,
					"Visual pos Y must return to ground level: %f" % vis.position.y
				)
				_cart_test_angle_idx += 1
				if _cart_test_angle_idx >= _cart_test_angles.size():
					if not _cart_test_rolling:
						_cart_test_rolling = true
						_cart_test_angle_idx = 0
						print("Stationary angle tests passed! Now testing rolling cart...")
					else:
						print(
							"Mount, sit, and exit verified across all angles and while rolling! Now testing death while riding..."
						)
						_cart_test_stage = 3
						_test_frames = 0
						_cart_test_angle_idx = 0
						_cart_test_rolling = true
						_cart_test_setup()
						return
				_cart_test_stage = 0
				_test_frames = 0
				_cart_test_setup()
		elif _cart_test_stage == 3:
			if _test_frames >= 24:
				assert(_cart_test_cart._rider == mats, "ShoppingCart rider must be set")
				_cart_test_stage = 4
				_test_frames = 0
				_cart_test_cart.die()
		elif _cart_test_stage == 4:
			if not mats.is_dead and _test_frames > 20:
				assert(
					mats.is_physics_processing(),
					"Physics processing must resume after respawning from cart death"
				)
				assert(mats._mounted_cart == null, "_mounted_cart must be cleared after death")
				assert(
					(
						mats.get_parent() != _cart_test_cart
						and mats.get_parent() != _cart_test_cart.get_node("Seat")
					),
					"Mats must be reparented out of cart after death"
				)
				assert(_cart_test_cart._rider == null, "Cart rider must be null after rider died")
				assert(
					_cart_test_cart._nearby_mats == null,
					"Cart nearby mats must be null after rider died and respawned"
				)
				assert(
					absf(vis.position.x) < 0.01 and absf(vis.position.z) < 0.01,
					"Visual X/Z offset must be reset to 0: %s" % vis.position
				)
				assert(
					absf(vis.position.y) < 0.05,
					"Visual pos Y must return to ground level: %f" % vis.position.y
				)
				assert(
					left_knee.rotation.x < 0.1,
					"Knee rotation must reset after respawn: %f" % left_knee.rotation.x
				)
				assert(
					left_leg.rotation.x < 0.1,
					"Hip rotation must reset after respawn: %f" % left_leg.rotation.x
				)
				print("CART_TEST completed: mount, sit, exit, and die-while-riding verified!")
				get_tree().quit(0)
				return
			elif _test_frames >= 300:
				assert(false, "Timeout waiting for respawn after dying in cart")
		elif _test_frames >= 120:
			assert(false, "Timeout in CART_TEST")
	if "--test-mats-collision" in _user_args:
		_test_frames += 1
		if _col_test_stage == 0:
			mats.velocity = Vector3(0.0, 0.0, 4.0)
			if mats.global_position.z >= 7.3 and mats.global_position.z <= 7.8:
				print(
					(
						"  [Curb Step-Up Trace] f=%d y=%.4f z=%.4f on_floor=%s"
						% [
							_test_frames,
							mats.global_position.y,
							mats.global_position.z,
							mats.is_on_floor()
						]
					)
				)
			if _test_frames >= 40:
				assert(mats.global_position.z > 7.6, "Mats should walk onto sidewalk over curb")
				assert(
					absf(mats.global_position.y - 0.245) < 0.05,
					"Mats should be on sidewalk (y ~ 0.245), got %f" % mats.global_position.y
				)
				print(
					"COLLISION_TEST [1/5]: Curb step-up (0.195m height with step_height=0.3) verified!"
				)
				_col_test_stage = 1
				_test_frames = 0
		elif _col_test_stage == 1:
			mats.velocity = Vector3(0.0, 0.0, -4.0)
			if mats.global_position.z >= 7.3 and mats.global_position.z <= 7.8:
				print(
					(
						"  [Curb Step-Down Trace] f=%d y=%.4f z=%.4f on_floor=%s"
						% [
							_test_frames,
							mats.global_position.y,
							mats.global_position.z,
							mats.is_on_floor()
						]
					)
				)
			if _test_frames >= 50:
				assert(mats.global_position.z < 7.4, "Mats should step off sidewalk back onto road")
				assert(
					absf(mats.global_position.y - 0.10) < 0.05,
					"Mats should settle on road (y ~ 0.10), got %f" % mats.global_position.y
				)
				print("COLLISION_TEST [2/5]: Curb step-down and floor snap verified!")
				_col_test_stage = 2
				_test_frames = 0
				mats.global_position = Vector3(92.0, 0.245, 9.3)
				mats.velocity = Vector3(0.0, 0.0, -4.0)
		elif _col_test_stage == 2:
			mats.velocity = Vector3(0.0, 0.0, -4.0)
			if _test_frames >= 40:
				var post_pos := Vector3(92.0, 0.245, 8.2)
				var dist := mats.global_position.distance_to(post_pos)
				assert(dist >= 0.48, "Mats must not penetrate sign post cylinder: dist=%f" % dist)
				assert(mats.global_position.z > 8.5, "Mats must be stopped by sign post!")
				print(
					(
						"COLLISION_TEST [3/5]: Sign post cylinder collision verified (blocked at dist=%.2f)!"
						% dist
					)
				)
				_col_test_stage = 3
				_test_frames = 0
				var bk_site := get_node("Props/BoogerKingSite")
				var bk_doors := bk_site.get_node("Building/Building/Tower/Doors")
				mats.global_position = bk_doors.global_position + Vector3(0.0, 0.0, -2.5)
				mats.velocity = Vector3(0.0, 0.0, 3.0)
		elif _col_test_stage == 3:
			mats.velocity = Vector3(0.0, 0.0, 3.0)
			assert(not mats.is_on_ceiling(), "Mats 1.5m capsule must not hit canopy ceiling!")
			if _test_frames >= 40:
				var bk_site := get_node("Props/BoogerKingSite")
				var bk_doors := bk_site.get_node("Building/Building/Tower/Doors")
				var dist := mats.global_position.distance_to(bk_doors.global_position)
				assert(dist < 1.0, "Mats must reach BK door threshold unobstructed: dist=%f" % dist)
				_col_test_stage = 4
				_test_frames = 0
				var taco := get_node("Props/TacoHell")
				var taco_doors := taco.get_node("Building/MainArchPortico/Doors")
				mats.global_position = taco_doors.global_position + Vector3(0.0, 0.0, 2.5)
				mats.velocity = Vector3(0.0, 0.0, -3.0)
		elif _col_test_stage == 4:
			mats.velocity = Vector3(0.0, 0.0, -3.0)
			assert(not mats.is_on_ceiling(), "Mats 1.5m capsule must not hit arch header!")
			if _test_frames >= 40:
				var taco := get_node("Props/TacoHell")
				var taco_doors := taco.get_node("Building/MainArchPortico/Doors")
				var dist := mats.global_position.distance_to(taco_doors.global_position)
				assert(
					dist < 1.0,
					"Mats must reach Taco Hell door threshold unobstructed: dist=%f" % dist
				)
				print(
					"COLLISION_TEST [4/5]: Building doorways and overhead canopies clearance verified!"
				)
				_col_test_stage = 5
				_setup_col_near_miss_test()
		elif _col_test_stage == 5:
			if is_instance_valid(_col_test_car):
				_col_test_car.advance_simulation(_delta)
				assert(
					not mats.is_dead,
					"Near miss must not kill Mats! 0.25m capsule radius accurately avoids phantom hits."
				)
				if _col_test_car.global_position.x < -8.0:
					print(
						"  Near miss verified! Car brushed within 0.27m of Mats center without phantom hit."
					)
					_col_test_car.queue_free()
					_col_test_stage = 6
					_col_test_lane = 0
					_setup_col_lane_test(0)
			elif _test_frames > 120:
				assert(false, "Timeout waiting for near miss car")
		elif _col_test_stage == 6:
			if is_instance_valid(_col_test_car):
				_col_test_car.advance_simulation(_delta)
			if _col_test_wait == 0:
				if mats.is_dead:
					_col_test_wait = 1
				elif _test_frames > 120:
					assert(false, "Timeout waiting for car hit in lane %d" % _col_test_lane)
			elif _col_test_wait == 1:
				if not mats.is_dead:
					var hud_node: HUD = get_tree().get_first_node_in_group("hud") as HUD
					var expected_spd = _col_test_initial_spd + _col_test_lane + 1
					assert(
						hud_node != null and hud_node.spd_count == expected_spd,
						(
							"SPD counter must increment on car hit death! expected %d, got %d"
							% [expected_spd, hud_node.spd_count if hud_node else -1]
						)
					)
					print(
						(
							"  Lane %d hit verified! Mats died and SPD counter incremented to %d"
							% [_col_test_lane, hud_node.spd_count]
						)
					)
					if is_instance_valid(_col_test_car):
						_col_test_car.queue_free()
					_col_test_lane += 1
					if _col_test_lane >= COL_LANE_CONFIGS.size():
						print(
							(
								"COLLISION_TEST [5/5]: Near miss clearance and car hits in all 4 lanes verified (SPD = %d)!"
								% hud_node.spd_count
							)
						)
						print(
							"MATS_COLLISION_TEST: SUCCESS - All collision, curb, sign post, doorway, and car hit tests passed!"
						)
						get_tree().quit(0)
						return
					else:
						_setup_col_lane_test(_col_test_lane)
	if "--test-merge-reentry" in _user_args:
		_test_frames += 1
		if _test_car != null and is_instance_valid(_test_car):
			var tm = $TrafficManager
			if _test_car.state == Car.State.WAITING_TO_MERGE:
				var lane0 = tm.lanes[0]
				lane0.spawn_timer = 999.0
				var to_remove: Array[Car] = []
				for c in lane0.cars:
					if is_instance_valid(c) and c != _test_car and c != _test_follower:
						to_remove.append(c)
				for c in to_remove:
					lane0.cars.erase(c)
					c.queue_free()
			elif _test_car.state == Car.State.MERGING:
				_saw_waiting = true
				if _test_follower == null:
					_test_follower = tm._spawn_car_at(tm.lanes[0], 42.0, tm.PassengerCarScene)
					_test_follower.speed = 13.0
					_test_follower.desired_speed = 13.0
					_test_follower.errand = null
					_test_follower.had_errand = false
				_saw_waiting = true
				# Check if lane 0 registered _test_car as a ghost
				if tm.lanes[0].cars.has(_test_car):
					_ghost_registered = true
				if _test_follower != null and is_instance_valid(_test_follower):
					var gap: float = (
						_test_car.lane_distance
						- _test_follower.lane_distance
						- (0.5 * (_test_car.car_length + _test_follower.car_length))
					)
					if gap < 8.0:
						if _test_follower.speed < 11.0:
							_follower_braked = true
			elif _test_car.state == Car.State.CRUISING and _saw_waiting:
				if not _mats_testing:
					_mats_testing = true
					print("MERGE_TEST: Handoff occurred at frame ", _test_frames)
					print(
						"MERGE_TEST: pos=",
						_test_car.global_position,
						" rot_y=",
						_test_car.rotation.y
					)
					var expected_pos := Vector3(5.0, 0.05, -5.6)
					var pos_delta := _test_car.global_position.distance_to(expected_pos)
					var rot_delta_deg := absf(rad_to_deg(wrapf(_test_car.rotation.y - PI, -PI, PI)))
					print("MERGE_TEST: pos_delta=", pos_delta, " rot_delta_deg=", rot_delta_deg)
					assert(
						pos_delta < 0.05,
						"Position delta at handoff must be < 0.05 m (was %f)" % pos_delta
					)
					assert(
						rot_delta_deg < 1.0,
						"Rotation delta at handoff must be < 1.0 deg (was %f)" % rot_delta_deg
					)
					assert(_test_car.motion == Car.Motion.LANE, "Motion must be Motion.LANE")
					assert(_test_car.lane_id == 0, "Lane ID must be 0")
					assert(_test_car.errand == null, "Errand must be null")
					assert(
						_ghost_registered,
						"Car must have registered as a ghost in lane 0 during merge"
					)
					assert(_follower_braked, "Follower in lane 0 must brake behind ghost")
					assert(not tm.lot_cars.has(_test_car), "Car must be removed from lot_cars")
					assert(tm.lanes[0].cars.has(_test_car), "Car must be in lane 0 cars")
					_handoff_verified = true
		else:
			# Car despawned at lane end
			var tm = $TrafficManager
			print("MERGE_TEST: Car despawned! errands_completed=", tm.stats["errands_completed"])
			assert(_handoff_verified, "Handoff must have been verified before despawn")
			assert(tm.stats["errands_completed"] >= 1, "errands_completed must be incremented")
			print(
				"MERGE_TEST: SUCCESS - full lifecycle, handoff delta verified, despawned cleanly!"
			)
			get_tree().quit(0)
		# Budget covers waiting out another car's full back-out before exiting the lot.
		if _test_frames > 3000:
			assert(false, "Timeout waiting for merge re-entry and despawn!")

	if "--test-merge-gap" in _user_args:
		_test_frames += 1
		var tm = $TrafficManager
		var lane0 = tm.lanes[0]
		if _gap_test_stage == 0:
			lane0.spawn_timer = 999.0
			var to_remove: Array[Car] = []
			for c in lane0.cars:
				if is_instance_valid(c) and c != _test_car:
					to_remove.append(c)
			for c in to_remove:
				lane0.cars.erase(c)
				c.queue_free()

			assert(tm._can_merge(_test_car), "Must be able to merge when lane 0 is clear")

			var dummy1 = tm._spawn_car_at(lane0, 70.0, tm.PassengerCarScene)
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when car is at d=70.0 (inside window)"
			)
			lane0.cars.erase(dummy1)
			dummy1.queue_free()

			var dummy2 = tm._spawn_car_at(lane0, 58.0, tm.PassengerCarScene)
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when car is at d=58.0 (inside window)"
			)
			lane0.cars.erase(dummy2)
			dummy2.queue_free()

			var dummy3 = tm._spawn_car_at(lane0, 25.0, tm.PassengerCarScene)
			dummy3.lane_speed = 13.0
			dummy3.speed = 13.0
			dummy3.desired_speed = 13.0
			assert(
				not tm._can_merge(_test_car),
				"Must reject merge when upstream car gap is 2.77s <= 3.0s"
			)
			lane0.cars.erase(dummy3)
			dummy3.queue_free()

			var dummy4 = tm._spawn_car_at(lane0, 20.0, tm.PassengerCarScene)
			dummy4.lane_speed = 13.0
			dummy4.speed = 13.0
			dummy4.desired_speed = 13.0
			assert(
				tm._can_merge(_test_car), "Must accept merge when upstream car gap is 3.15s > 3.0s"
			)
			lane0.cars.erase(dummy4)
			dummy4.queue_free()

			_passing_car = tm._spawn_car_at(lane0, 45.0, tm.PassengerCarScene)
			_passing_car.speed = 13.0
			_passing_car.desired_speed = 13.0
			_passing_car.lane_speed = 13.0
			_passing_car.errand = null
			_passing_car.had_errand = false

			assert(not tm._can_merge(_test_car), "Must reject merge with passing car at d=45.0")
			_gap_test_stage = 1

		elif _gap_test_stage == 1:
			if _passing_car != null and is_instance_valid(_passing_car):
				if _passing_car.lane_distance <= 71.0:
					assert(
						_test_car.state == Car.State.WAITING_TO_MERGE,
						"Waiting car must hold state WAITING_TO_MERGE"
					)
					assert(_test_car.speed == 0.0, "Waiting car speed must remain 0.0")
					assert(
						_test_car.global_position.distance_to(Vector3(9.0, 0.0, -9.6)) < 0.05,
						"Waiting car must hold position"
					)
					assert(
						not tm._can_merge(_test_car),
						"Must not merge while car in window [54.5, 71]"
					)
					_saw_hold_position = true
				else:
					assert(
						_saw_hold_position,
						"Must have observed waiting car holding position while car passed"
					)
					assert(_test_car.merge_wait_time > 0.0, "Merge wait time must accumulate")
					assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be updated")
					assert(
						tm._can_merge(_test_car),
						"Merge must be accepted once passing car clears d=71.0"
					)
					print(
						(
							"GAP_TEST: Passing car cleared window (d=%.1f). Wait time: %.2fs"
							% [_passing_car.lane_distance, _test_car.merge_wait_time]
						)
					)
					_gap_test_stage = 2

		elif _gap_test_stage == 2:
			if _test_car.state == Car.State.MERGING:
				_saw_gap_merge = true
				print("GAP_TEST: Car successfully initiated merge when valid gap opened!")
				_test_follower = tm._spawn_car_at(lane0, 42.0, tm.PassengerCarScene)
				_test_follower.speed = 13.0
				_test_follower.desired_speed = 13.0
				_test_follower.errand = null
				_test_follower.lane_speed = 13.0
				_test_follower.had_errand = false
				_gap_test_stage = 3

		elif _gap_test_stage == 3:
			if lane0.cars.has(_test_car):
				_ghost_registered = true

			if _test_follower != null and is_instance_valid(_test_follower) and _ghost_registered:
				var gap: float = (
					_test_car.lane_distance
					- _test_follower.lane_distance
					- (0.5 * (_test_car.car_length + _test_follower.car_length))
				)
				if gap < 8.0:
					if _test_follower.speed < 11.0:
						_saw_follower_yield = true
						print(
							(
								"GAP_TEST: Upstream follower braked to %.2f m/s behind merging car (gap=%.2fm)"
								% [_test_follower.speed, gap]
							)
						)

			if _test_car.state == Car.State.CRUISING:
				print("GAP_TEST: Merged car transitioned to CRUISING!")
				assert(
					_saw_hold_position,
					"Waiting car must have held position while lane 0 car passed"
				)
				assert(_saw_gap_merge, "Car must have merged only when valid gap opened")
				assert(_ghost_registered, "Merging car must have registered as ghost in lane 0")
				assert(
					_saw_follower_yield, "Upstream traffic must yield appropriately to merging car"
				)
				assert(tm.stats["max_merge_wait"] > 0.0, "max_merge_wait must be tracked")
				print(
					"GAP_TEST: SUCCESS - waiting cars hold position while lane-0 cars pass, merge only when valid gap opens, and upstream traffic yields appropriately!"
				)
				get_tree().quit(0)

		if _test_frames > 600:
			assert(false, "Timeout waiting for gap test completion!")

	if "--test-lifecycle" in _user_args:
		_test_frames += 1
		if _saw_lc_despawn:
			return
		var tm = $TrafficManager
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and not _saw_lc_merge
			):
				if not _saw_lc_cruising:
					_saw_lc_cruising = true
					print(
						(
							"LIFECYCLE [1/12]: lane cruising (speed=%.1f, lane_dist=%.1f)"
							% [_test_car.speed, _test_car.lane_distance]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _saw_lc_decision:
					_saw_lc_decision = true
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT,
						"Car approaching right turn must activate turn signal"
					)
					print(
						(
							"LIFECYCLE [2/12]: decision (lane_dist=%.1f, spot=%s, signal=%s)"
							% [
								_test_car.lane_distance,
								str(_test_car.spot.id) if _test_car.spot else "null",
								str(_test_car.turn_signal)
							]
						)
					)
				if _test_car.speed < 11.0 and not _saw_lc_braking:
					_saw_lc_braking = true
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT,
						"Car braking for right turn must have turn signal ON"
					)
					print(
						(
							"LIFECYCLE [3/12]: approach braking (speed=%.1f, target_v_turn=%.1f, signal=%s)"
							% [_test_car.speed, TrafficManager.V_TURN, str(_test_car.turn_signal)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _saw_lc_turn:
					_saw_lc_turn = true
					print(
						(
							"LIFECYCLE [4/12]: driveway turn (pos=%s, motion=PATH, signal=%s)"
							% [str(_test_car.global_position), str(_test_car.turn_signal)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _saw_lc_park:
					_saw_lc_park = true
					print(
						(
							"LIFECYCLE [5/12]: stall park (pos=%s, spot=%s, dwell=%.1f)"
							% [
								str(_test_car.global_position),
								str(_test_car.spot.id) if _test_car.spot else "null",
								_test_car.dwell_left
							]
						)
					)
					_test_car.dwell_left = minf(_test_car.dwell_left, 1.0)
				if not _saw_lc_dwell:
					_saw_lc_dwell = true
					print("LIFECYCLE [6/12]: dwell (dwell_left=%.2f)" % _test_car.dwell_left)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _saw_lc_reverse:
					_saw_lc_reverse = true
					print(
						(
							"LIFECYCLE [7/12]: reverse out (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _saw_lc_exit_aisle:
					_saw_lc_exit_aisle = true
					print(
						(
							"LIFECYCLE [8/12]: exit aisle (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _saw_lc_wait:
					_saw_lc_wait = true
					print(
						(
							"LIFECYCLE [9/12]: sidewalk wait (pos=%s, speed=%.1f)"
							% [str(_test_car.global_position), _test_car.speed]
						)
					)
				var lane0 = tm.lanes[0]
				lane0.spawn_timer = 999.0
				var to_remove: Array[Car] = []
				for c in lane0.cars:
					if is_instance_valid(c) and c != _test_car:
						to_remove.append(c)
				for c in to_remove:
					lane0.cars.erase(c)
					c.queue_free()
			elif _test_car.state == Car.State.MERGING:
				if not _saw_lc_merge:
					_saw_lc_merge = true
					print(
						(
							"LIFECYCLE [10/12]: gap merge (speed=%.1f, pos=%s)"
							% [_test_car.speed, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.CRUISING and _test_car.lane_id == 0 and _saw_lc_merge:
				if not _saw_lc_post_merge_cruise:
					_saw_lc_post_merge_cruise = true
					print(
						(
							"LIFECYCLE [11/12]: lane cruising (speed=%.1f, lane_dist=%.1f)"
							% [_test_car.speed, _test_car.lane_distance]
						)
					)
		else:
			if _saw_lc_post_merge_cruise and not _saw_lc_despawn:
				_saw_lc_despawn = true
				print(
					(
						"LIFECYCLE [12/12]: despawn (errands_completed=%d)"
						% tm.stats["errands_completed"]
					)
				)
				assert(_saw_lc_cruising, "Must have observed lane cruising")
				assert(_saw_lc_decision, "Must have observed decision")
				assert(_saw_lc_braking, "Must have observed approach braking")
				assert(_saw_lc_turn, "Must have observed driveway turn")
				assert(_saw_lc_park, "Must have observed stall park")
				assert(_saw_lc_dwell, "Must have observed dwell")
				assert(_saw_lc_reverse, "Must have observed reverse out")
				assert(_saw_lc_exit_aisle, "Must have observed exit aisle")
				assert(_saw_lc_wait, "Must have observed sidewalk wait")
				assert(_saw_lc_merge, "Must have observed gap merge")
				assert(_saw_lc_post_merge_cruise, "Must have observed lane cruising")
				assert(_saw_lc_despawn, "Must have observed despawn")
				print(
					"LIFECYCLE: SUCCESS - observed complete vehicle lifecycle through all 12 stages!"
				)
				get_tree().quit(0)
				return
		if _test_frames > 4000:
			assert(false, "Timeout waiting for vehicle lifecycle completion!")
	if "--test-right-turn-following" in _user_args:
		_test_frames += 1
		if is_instance_valid(_rt_lead_car) and is_instance_valid(_rt_follower_car):
			var d_euc = _rt_lead_car.global_position.distance_to(_rt_follower_car.global_position)
			_rt_min_distance = minf(_rt_min_distance, d_euc)
			var min_allowed = (_rt_lead_car.car_length + _rt_follower_car.car_length) * 0.5 - 0.2
			assert(
				d_euc >= min_allowed,
				"Collision detected: distance %.2f < min allowed %.2f" % [d_euc, min_allowed]
			)

			if _rt_lead_car.state == Car.State.APPROACHING and _rt_lead_car.speed < 11.0:
				if not _rt_saw_lead_braking:
					_rt_saw_lead_braking = true
					print(
						(
							"RIGHT_TURN_TEST [1/4]: lead car braking for turn (spd=%.1f, signal=%s)"
							% [_rt_lead_car.speed, str(_rt_lead_car.turn_signal)]
						)
					)

			if _rt_saw_lead_braking and _rt_follower_car.speed < 10.0:
				if not _rt_saw_follower_braking:
					_rt_saw_follower_braking = true
					print(
						(
							"RIGHT_TURN_TEST [2/4]: follower car slowing down smoothly behind turning car (spd=%.1f, dist=%.1f)"
							% [_rt_follower_car.speed, d_euc]
						)
					)

			if _rt_lead_car.state == Car.State.TO_SPOT:
				if not _rt_saw_lead_turning:
					_rt_saw_lead_turning = true
					print(
						(
							"RIGHT_TURN_TEST [3/4]: lead car turning into driveway (pos=%s)"
							% str(_rt_lead_car.global_position)
						)
					)

			if (
				_rt_saw_lead_turning
				and _rt_follower_car.speed > 11.0
				and _rt_follower_car.lane_distance > 53.0
			):
				if not _rt_saw_follower_resumed:
					_rt_saw_follower_resumed = true
					print(
						(
							"RIGHT_TURN_TEST [4/4]: follower car safely cleared driveway and resumed cruise (spd=%.1f, min_dist=%.1f)"
							% [_rt_follower_car.speed, _rt_min_distance]
						)
					)
					assert(_rt_saw_lead_braking, "Lead car must have braked")
					assert(_rt_saw_follower_braking, "Follower car must have slowed down")
					assert(_rt_saw_lead_turning, "Lead car must have turned")
					print(
						"RIGHT_TURN_TEST: SUCCESS - Follower car slowed down smoothly behind right turning car without crashing!"
					)
					get_tree().quit(0)
					return
		if _test_frames > 1500:
			assert(false, "Timeout waiting for right turn following test completion!")
	if "--test-cramped-inn" in _user_args or "--test-strip-mall" in _user_args:
		var tag := String(_ci_site).to_upper()
		_test_frames += 1
		var tm = $TrafficManager
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 3
				and not _ci_saw_merge
			):
				if not _ci_saw_cruise:
					_ci_saw_cruise = true
					print(
						(
							"%s [1/8]: cruising east in lane 3 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _ci_saw_decision:
					_ci_saw_decision = true
					assert(_test_car.spot != null, "Must have reserved a spot")
					assert(_test_car.spot.serves.has(_ci_site), "Spot must serve %s" % _ci_site)
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT, "Turn signal must be RIGHT"
					)
					print(
						(
							"%s [2/8]: decision & approach turn (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _ci_saw_turn:
					_ci_saw_turn = true
					assert(_test_car.merge_target_lane == 3, "merge_target_lane must be 3")
					print(
						(
							"%s [3/8]: turned into driveway (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _ci_saw_park:
					_ci_saw_park = true
					_test_car.dwell_left = minf(_test_car.dwell_left, 0.5)
					assert(
						_test_car.spot.state == ParkingSpot.State.OCCUPIED, "Spot must be OCCUPIED"
					)
					print(
						(
							"%s [4/8]: parked in stall (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _ci_saw_reverse:
					_ci_saw_reverse = true
					print(
						"%s [5/8]: reversing out (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _ci_saw_exit:
					_ci_saw_exit = true
					print(
						"%s [6/8]: driving to exit (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _ci_saw_wait:
					_ci_saw_wait = true
					var wait_point: Vector3 = ParkingLot.SOUTH_LOTS[_ci_site]["wait"]
					assert(
						_test_car.global_position.distance_to(wait_point) < 1.0,
						"Must be at the %s wait point" % _ci_site
					)
					print(
						(
							"%s [7/8]: waiting at exit wait point (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
					var lane3 = tm.lanes[3]
					lane3.spawn_timer = 9999.0
					for c in lane3.cars:
						if is_instance_valid(c) and c != _test_car:
							c.queue_free()
					lane3.cars.clear()
			elif _test_car.state == Car.State.MERGING:
				if not _ci_saw_merge:
					_ci_saw_merge = true
					print(
						(
							"%s [8/8]: merging into lane 3 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.CRUISING and _test_car.lane_id == 3 and _ci_saw_merge:
				if not _ci_saw_rejoin:
					_ci_saw_rejoin = true
					assert(
						absf(_test_car.global_position.z - 5.6) < 0.5,
						"Car must be in Lane 3 (z=5.6)"
					)
					print("%s: SUCCESS - full errand cycle complete!" % tag)
					get_tree().quit(0)
					return
		if _test_frames > 2400:
			assert(false, "Timeout waiting for %s test completion!" % _ci_site)

	if "--test-smell-store" in _user_args or "--test-smell-gas" in _user_args:
		var tag := String(_smell_dest).to_upper()
		_test_frames += 1
		if _test_car != null and is_instance_valid(_test_car):
			if (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and not _smell_saw_merge
			):
				if not _smell_saw_cruise:
					_smell_saw_cruise = true
					print(
						(
							"%s [1/8]: cruising west in lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.APPROACHING:
				if not _smell_saw_decision:
					_smell_saw_decision = true
					assert(_test_car.spot != null, "Must have reserved a spot")
					assert(
						_test_car.spot.serves.has(_smell_dest), "Spot must serve %s" % _smell_dest
					)
					assert(
						_test_car.turn_signal == Car.TurnSignal.RIGHT, "Turn signal must be RIGHT"
					)
					print(
						(
							"%s [2/8]: decision & approach turn (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.TO_SPOT:
				if not _smell_saw_turn:
					_smell_saw_turn = true
					assert(_test_car.merge_target_lane == 0, "merge_target_lane must be 0")
					print(
						(
							"%s [3/8]: turned into driveway (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.PARKED:
				if not _smell_saw_park:
					_smell_saw_park = true
					_test_car.dwell_left = minf(_test_car.dwell_left, 0.5)
					assert(
						_test_car.spot.state == ParkingSpot.State.OCCUPIED, "Spot must be OCCUPIED"
					)
					print(
						(
							"%s [4/8]: parked at destination (spot=%d, pos=%s)"
							% [tag, _test_car.spot.id, str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.REVERSING_OUT:
				if not _smell_saw_reverse:
					_smell_saw_reverse = true
					print(
						"%s [5/8]: reversing out (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.TO_EXIT:
				if not _smell_saw_exit:
					_smell_saw_exit = true
					print(
						"%s [6/8]: driving to exit (pos=%s)" % [tag, str(_test_car.global_position)]
					)
			elif _test_car.state == Car.State.WAITING_TO_MERGE:
				if not _smell_saw_wait:
					_smell_saw_wait = true
					var wait_point: Vector3 = ParkingLot.SMELL_WAIT_POINT
					assert(
						_test_car.global_position.distance_to(wait_point) < 1.0,
						"Must be at the smell wait point"
					)
					print(
						(
							"%s [7/8]: waiting to merge (wait_point=%s, pos=%s)"
							% [tag, str(wait_point), str(_test_car.global_position)]
						)
					)
			elif _test_car.state == Car.State.MERGING:
				if not _smell_saw_merge:
					_smell_saw_merge = true
					print(
						(
							"%s [8/8]: merging into lane 0 (pos=%s)"
							% [tag, str(_test_car.global_position)]
						)
					)
			elif (
				_test_car.state == Car.State.CRUISING
				and _test_car.lane_id == 0
				and _smell_saw_merge
			):
				if not _smell_saw_rejoin:
					_smell_saw_rejoin = true
					assert(
						absf(_test_car.global_position.z - (-5.6)) < 0.5,
						"Car must be in Lane 0 (z=-5.6)"
					)
					print("%s: SUCCESS - full errand cycle complete!" % tag)
					get_tree().quit(0)
					return
		if _test_frames > 3600:
			assert(false, "Timeout waiting for %s test completion!" % _smell_dest)


func _on_player_died(pos: Vector3) -> void:
	if blood_splats and mats:
		BloodSplat.spawn(pos, blood_splats, [mats.get_rid()])


func _exit_tree() -> void:
	if (
		GameState.instance
		and GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed)
	):
		GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)


func _cart_test_setup() -> void:
	var facing: float = _cart_test_angles[_cart_test_angle_idx]
	_cart_test_cart.global_position = Vector3(9.0, 0.0, -15.0)
	_cart_test_cart.global_basis = Basis()
	if _cart_test_rolling:
		_cart_test_cart.roll_from(Vector3(0.0, 0.0, 1.0))
	else:
		_cart_test_cart._current_speed = 0.0
	mats.global_position = _cart_test_cart.global_position + Vector3(0.5, 0.0, 0.5)
	var vis: Node3D = mats.get_node("Visual")
	vis.rotation = Vector3(0.0, facing, 0.0)
	_cart_prev_rot_y = facing
	mats.get_node("Visual/LeftLegPivot").rotation.x = 0.4
	mats.get_node("Visual/RightLegPivot").rotation.x = -0.4
	mats.get_node("Visual/LeftLegPivot/Knee").rotation.x = 0.8
	mats.get_node("Visual/RightLegPivot/Knee").rotation.x = 0.2
	mats.enter_cart(_cart_test_cart, _cart_test_cart.get_node("Seat"))


func _setup_col_near_miss_test() -> void:
	_test_frames = 0
	_col_test_wait = 0
	var lane_id := 0
	var lane_z := -5.6
	var lane_dir := -1.0
	var car_x := 12.0
	# Car width for SEDAN is 1.9m -> half-width is 0.95m.
	# Lane center is -5.6, so south edge of car is at -5.6 + 0.95 = -4.65.
	# Place Mats center at -4.65 + 0.27 = -4.38 (clearance 0.27m to car edge).
	# With radius=0.25m, car passes cleanly without hit (capsule reaches -4.63 > -4.65).
	# With radius=0.30m, capsule reaches -4.68 < -4.65, so a phantom hit kills Mats.
	mats.global_position = Vector3(0.0, 0.10, -4.38)
	mats.velocity = Vector3.ZERO

	var car_scene = load("res://cars/passenger_car.tscn")
	_col_test_car = car_scene.instantiate()
	_col_test_car.car_type = Car.CarType.SEDAN
	add_child(_col_test_car)
	_col_test_car.setup(lane_id, lane_z, lane_dir, car_x, 60.0, 16.0, Car.CarType.SEDAN)
	_col_test_car.speed = 16.0
	_col_test_car.desired_speed = 16.0
	_col_test_car._update_blocker_layer()


func _setup_col_lane_test(idx: int) -> void:
	_test_frames = 0
	_col_test_wait = 0
	var cfg: Dictionary = COL_LANE_CONFIGS[idx]
	var lane_id: int = cfg["lane_id"]
	var lane_z: float = cfg["z"]
	var lane_dir: float = cfg["dir"]
	var car_x: float = cfg["car_x"]
	var mats_x: float = cfg["mats_x"]

	mats.global_position = Vector3(mats_x, 0.10, lane_z)
	mats.velocity = Vector3.ZERO

	var car_scene = load("res://cars/passenger_car.tscn")
	_col_test_car = car_scene.instantiate()
	_col_test_car.car_type = Car.CarType.SEDAN
	add_child(_col_test_car)
	_col_test_car.setup(lane_id, lane_z, lane_dir, car_x, 60.0, 16.0, Car.CarType.SEDAN)
	_col_test_car.speed = 16.0
	_col_test_car.desired_speed = 16.0
	_col_test_car._update_blocker_layer()
