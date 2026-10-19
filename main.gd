extends Node3D

const BloodSplatScript = preload("res://player/blood_splat.gd")

@onready var mats: CharacterBody3D = $Mats
@onready var hud: CanvasLayer = $HUD
@onready var blood_splats: Node3D = $BloodSplats
@onready var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("DirectionalLight3D")
@onready var streetlights_node: Node3D = get_node_or_null("Props/Streetlights")
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
var _saw_reversing: bool = false
var _saw_to_exit: bool = false
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
var _mats_stage: int = 0
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
var _dt_saw_order: bool = false
var _dt_saw_pickup: bool = false
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
		var m: Mesh = baked_mmi.multimesh.mesh
		for s in range(m.get_surface_count()):
			var orig_mat := m.surface_get_material(s)
			if (
				orig_mat is StandardMaterial3D
				and orig_mat.albedo_color.r > 0.85
				and orig_mat.metallic < 0.2
			):
				baked_mmi.set_surface_override_material(s, bulb_mat if enabled else null)

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
	if "--test-night-mode" in _user_args:
		var initial_state := GameState.night_mode
		assert(initial_state == false, "Initial night_mode should be false")
		var sl := get_node_or_null("Props/Streetlights") as Node3D
		assert(sl != null and sl.get_child_count() > 0, "Props/Streetlights must exist")
		var day_lights_checked := 0
		for lamp in sl.get_children():
			if lamp is MultiMeshInstance3D:
				continue
			var light: SpotLight3D = lamp.get_node_or_null("Light")
			assert(light != null, "Each street lamp must have a Light node")
			assert(light.visible == false, "Streetlight must be off in day mode")
			day_lights_checked += 1
		assert(day_lights_checked >= 10, "Must check at least 10 streetlights in day mode")

		var tm := $TrafficManager
		assert(tm != null and tm.lot_cars.size() > 0, "TrafficManager must have cars")
		var sample_car: Car = null
		for lane in tm.lanes:
			if lane.cars.size() > 0:
				sample_car = lane.cars[0]
				break
		assert(sample_car != null, "Must find an active cruising car")
		assert(sample_car.headlamp != null, "Active car must have a headlamp node")
		assert(
			sample_car.headlamp.visible == false, "Cruising car headlamp must be off in day mode"
		)

		# Test 3-way toggle cycle: DAY -> EVENING -> NIGHT -> DAY
		GameState.cycle_time_of_day()
		_apply_time_of_day(GameState.time_of_day, true)
		assert(
			GameState.time_of_day == GameState.TimeOfDay.EVENING,
			"First cycle must switch to EVENING"
		)
		assert(GameState.are_lights_on() == true, "Evening mode must have lights on")
		assert(
			sun_light.light_color == EVENING_SUN_COLOR,
			"Evening mode must have orange sun: %s" % sun_light.light_color
		)
		assert(sample_car.headlamp.visible == true, "Evening mode must have car headlamps on")
		if hud and hud.night_mode_button:
			assert("SUNSET" in hud.night_mode_button.text, "HUD button must show SUNSET")

		# Cycle to NIGHT
		GameState.cycle_time_of_day()
		_apply_time_of_day(GameState.time_of_day, true)
		assert(
			GameState.time_of_day == GameState.TimeOfDay.NIGHT, "Second cycle must switch to NIGHT"
		)
		assert(GameState.night_mode == true, "Night mode must be active")
		assert(
			sun_light.light_color == NIGHT_SUN_COLOR,
			"Night mode must have moon light: %s" % sun_light.light_color
		)
		if hud and hud.night_mode_button:
			assert("NIGHT" in hud.night_mode_button.text, "HUD button must show NIGHT")
		var lights_found := 0
		for lamp in sl.get_children():
			if lamp is MultiMeshInstance3D:
				continue
			var light: SpotLight3D = lamp.get_node_or_null("Light")
			assert(light != null and light.visible == true, "Streetlight must be on in night mode")
			lights_found += 1
		assert(lights_found >= 10, "Must have checked at least 10 streetlights on in night mode")

		assert(
			sample_car.headlamp.visible == true, "Cruising car headlamp must turn on in night mode"
		)

		assert(
			sample_car.headlamp.visible == true, "Cruising car headlamp must turn on in night mode"
		)

		# Check car spawned AFTER night mode is toggled on has headlamps visible
		var lane_east = tm.lanes[0]
		var spawned_car: Car = tm._spawn_car_at(lane_east, 35.0, tm.PassengerCarScene)
		assert(spawned_car != null, "Car spawned after night mode enabled must succeed")
		assert(spawned_car.headlamp != null, "Spawned car must have headlamp node")
		assert(
			spawned_car.headlamp.visible == true, "Car spawned in night mode must have headlamp on"
		)

		# Test beam aim for both eastbound (direction > 0) and westbound (direction < 0) cars
		var eastbound_car: Car = null
		var westbound_car: Car = null
		for lane in tm.lanes:
			for c in lane.cars:
				if c.direction > 0.0 and eastbound_car == null:
					eastbound_car = c
				elif c.direction < 0.0 and westbound_car == null:
					westbound_car = c
		assert(eastbound_car != null, "Must find eastbound car")
		assert(westbound_car != null, "Must find westbound car")
		var east_dot := (-eastbound_car.headlamp.global_transform.basis.z).dot(
			eastbound_car.get_heading()
		)
		assert(
			east_dot > 0.9, "Eastbound headlamp must point forward with heading (dot=%f)" % east_dot
		)
		var west_dot := (-westbound_car.headlamp.global_transform.basis.z).dot(
			westbound_car.get_heading()
		)
		assert(
			west_dot > 0.9, "Westbound headlamp must point forward with heading (dot=%f)" % west_dot
		)

		# Test baked car body compatibility
		var baked_car: PassengerCar = tm.PassengerCarScene.instantiate()
		var body_model := baked_car.get_active_model()
		if body_model:
			MeshBaker.bake_car_body(body_model)
		tm.add_child(baked_car)
		baked_car.setup(0, 0.0, 1.0, 0.0, 140.0, 14.0, Car.CarType.SEDAN)
		assert(
			baked_car.headlamp != null,
			"Baked car must successfully instantiate headlamp from Marker3D"
		)
		assert(
			baked_car.headlamp.visible == true, "Baked car in night mode must have headlamp visible"
		)
		baked_car.queue_free()

		if hud and hud.night_mode_button:
			assert("NIGHT" in hud.night_mode_button.text, "HUD button must show NIGHT")

		# Cycle back to DAY
		GameState.cycle_time_of_day()
		_apply_time_of_day(GameState.time_of_day, true)
		assert(GameState.time_of_day == GameState.TimeOfDay.DAY, "Third cycle must return to DAY")
		assert(GameState.night_mode == false, "GameState.night_mode should be false")
		assert(sun_light.light_color == DAY_SUN_COLOR, "Day mode must restore daylight sun color")

		for lamp in sl.get_children():
			if lamp is MultiMeshInstance3D:
				continue
			var light: SpotLight3D = lamp.get_node_or_null("Light")
			assert(
				light != null and light.visible == false,
				"Streetlight must turn off when day mode restored"
			)

		assert(sample_car.headlamp.visible == false, "Car headlamps must turn off in day mode")
		assert(
			spawned_car.headlamp.visible == false, "Spawned car headlamp must turn off in day mode"
		)

		if hud and hud.night_mode_button:
			assert("DAY" in hud.night_mode_button.text, "HUD button must show DAY")

		print(
			"NIGHT_MODE_TEST: SUCCESS - toggling night mode updates GameState, streetlights, car headlamps, beam directions, and HUD"
		)
		get_tree().quit(0)
		return
	if "--test-start-screen" in _user_args:
		var start_screen: StartScreen = get_node_or_null("StartScreen")
		assert(start_screen != null, "StartScreen must exist in main scene")
		assert(start_screen.visible == true, "StartScreen must be visible initially")
		assert(get_tree().paused == true, "Tree must be paused when StartScreen is open")
		assert(
			start_screen.scrim != null and is_equal_approx(start_screen.scrim.color.a, 1.0),
			"StartScreen scrim must be fully opaque when game starts"
		)

		# Verify exact title
		var title_label: Label = start_screen.get_node(
			"RootControl/Pane/Margin/Content/HeaderBox/TitleLabel"
		)
		assert(
			title_label != null and title_label.text == "STROAD HERO", "Title must be STROAD HERO"
		)

		# Verify welcome message
		var welcome_label: Label = start_screen.get_node(
			"RootControl/Pane/Margin/Content/MessageSection/WelcomeLabel"
		)
		assert(welcome_label != null, "WelcomeLabel must exist")
		var expected_welcome := "Hello, pedestrian. Welcome to Anywhere, USA.\nDo you have what it takes to be the Stroad Hero?"
		assert(
			welcome_label.text == expected_welcome,
			"Welcome text must match: %s" % welcome_label.text
		)

		# Verify good luck text
		var good_luck_label: Label = start_screen.get_node(
			"RootControl/Pane/Margin/Content/MessageSection/GoodLuckLabel"
		)
		assert(
			good_luck_label != null and good_luck_label.text == "Good Luck",
			"Good luck label must be 'Good Luck'"
		)

		# Verify controls grid content
		var grid = start_screen.get_node(
			"RootControl/Pane/Margin/Content/ControlsPanel/ControlsContent/Grid"
		)
		assert(grid != null, "Controls grid must exist")
		var keycaps: Array[String] = []
		var desc_texts: Array[String] = []
		for child in grid.get_children():
			for sub in child.get_children():
				if sub is PanelContainer:
					for sub2 in sub.get_children():
						if sub2 is Label:
							keycaps.append(sub2.text)
				elif sub is Label:
					desc_texts.append(sub.text)
		assert("Arrow Keys" in keycaps, "Must have Arrow Keys keycap: %s" % str(keycaps))
		assert("Space" in keycaps, "Must have Space keycap: %s" % str(keycaps))
		assert("A / D" in keycaps, "Must have A / D keycap: %s" % str(keycaps))
		assert("W / S" in keycaps, "Must have W / S keycap: %s" % str(keycaps))
		assert("C" in keycaps, "Must have C keycap: %s" % str(keycaps))
		assert("R" in keycaps, "Must have R keycap: %s" % str(keycaps))
		assert("Esc" in keycaps, "Must have Esc keycap: %s" % str(keycaps))
		assert("H" in keycaps, "Must have H keycap: %s" % str(keycaps))

		# Verify start and quit buttons exist and work
		var start_btn: Button = start_screen.start_button
		assert(
			start_btn != null and start_btn.text == "START GAME", "Start button must say START GAME"
		)
		var quit_btn: Button = start_screen.quit_button
		assert(quit_btn != null and quit_btn.text == "QUIT", "Quit button must say QUIT")
		assert(
			quit_btn.pressed.is_connected(start_screen.quit_game),
			"Quit button must be connected to quit_game"
		)
		assert(quit_btn.focus_mode == Control.FOCUS_NONE, "QuitButton must have FOCUS_NONE")

		# Test that pressing Right arrow does not focus QuitButton or cause Space to quit
		var right_event := InputEventKey.new()
		right_event.pressed = true
		right_event.keycode = KEY_RIGHT
		right_event.echo = false
		Input.parse_input_event(right_event)
		await get_tree().process_frame
		assert(!quit_btn.has_focus(), "QuitButton must not gain focus from keyboard navigation")
		start_screen.start_game()
		await start_screen.started
		assert(start_screen.visible == false, "StartScreen must hide after start_game()")
		assert(get_tree().paused == false, "Game tree must unpause after start_game()")

		# Test CharacterEditor handles Esc without StartScreen intercepting it
		var char_editor = get_node_or_null("CharacterEditor")
		assert(char_editor != null, "CharacterEditor must exist in main scene")
		char_editor.open_editor()
		assert(char_editor.visible == true, "CharacterEditor must be visible when opened")
		assert(get_tree().paused == true, "Game tree must pause when CharacterEditor is open")
		assert(
			start_screen.visible == false,
			"StartScreen must remain hidden when CharacterEditor is open"
		)

		var esc_event := InputEventKey.new()
		esc_event.pressed = true
		esc_event.keycode = KEY_ESCAPE
		esc_event.echo = false
		Input.parse_input_event(esc_event)
		await get_tree().process_frame

		assert(char_editor.visible == false, "CharacterEditor must close on Esc")
		assert(
			start_screen.visible == false,
			"StartScreen must remain hidden when Esc closes CharacterEditor"
		)
		assert(get_tree().paused == false, "Game tree must unpause after CharacterEditor closes")

		# Test Esc during gameplay pauses and shows StartScreen with RESUME
		Input.parse_input_event(esc_event)
		await get_tree().process_frame
		assert(start_screen.visible == true, "Pressing Esc during gameplay must show StartScreen")
		assert(get_tree().paused == true, "Pressing Esc during gameplay must pause game tree")
		assert(start_btn.text == "RESUME", "Start button must say RESUME on pause")
		assert(
			is_equal_approx(start_screen.scrim.color.a, 0.85),
			"StartScreen scrim should be translucent when paused during gameplay"
		)

		# Test Esc again resumes the game
		Input.parse_input_event(esc_event)
		await start_screen.started
		assert(start_screen.visible == false, "Pressing Esc again must resume and hide StartScreen")
		assert(get_tree().paused == false, "Pressing Esc again must unpause game tree")

		# Test reopening via open_screen()
		start_screen.open_screen()
		assert(start_screen.visible == true, "StartScreen must show on open_screen()")
		assert(get_tree().paused == true, "Game tree must pause on open_screen()")
		assert(start_btn.text == "RESUME", "Start button must say RESUME on reopen")
		assert(
			is_equal_approx(start_screen.scrim.color.a, 0.85),
			"StartScreen scrim should be translucent when reopened during gameplay"
		)

		print(
			"START_SCREEN_TEST: SUCCESS - title, message, controls, scrim opacity, CharacterEditor Esc isolation, and pause/resume flow verified"
		)
		get_tree().quit(0)
		return
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
	if "--test-exit-route" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(
			traffic_mgr != null and traffic_mgr.lot_cars.size() > 0,
			"TrafficManager must have seeded cars"
		)
		for c in traffic_mgr.lot_cars:
			if c.global_position.z < 0.0:
				_test_car = c
				break
		_test_car.dwell_left = 0.0
	if "--test-merge-reentry" in _user_args:
		var traffic_mgr = $TrafficManager
		assert(
			traffic_mgr != null and traffic_mgr.lot_cars.size() > 0,
			"TrafficManager must have seeded cars"
		)
		for c in traffic_mgr.lot_cars:
			if c.global_position.z < 0.0:
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
			if c.global_position.z < 0.0:
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
	if "--test-taco-dt-zones" in _user_args:
		var tm = $TrafficManager
		assert(tm != null, "TrafficManager must exist")
		for c in tm.lot_cars:
			c.queue_free()
		tm.lot_cars.clear()
		for lane in tm.lanes:
			for c in lane.cars:
				c.queue_free()
			lane.cars.clear()
			lane.spawn_timer = 9999.0
		_test_car = tm.spawn_drive_thru_car(&"taco_hell_drive_thru")
	if "--test-wind-flags" in _user_args:
		# Test 1: GameState initial properties
		assert(GameState.wind_direction.is_normalized(), "Wind direction must be normalized")
		assert(absf(GameState.wind_direction.y) < 0.0001, "Wind direction Y must be 0 (horizontal)")
		assert(GameState.wind_speed > 0.0, "Wind speed must be positive")
		assert(
			absf(GameState.wind_direction.length() - 1.0) < 0.001,
			"Wind direction must have length 1"
		)

		# Test 2: Wind subtle variation over time
		var initial_angle = GameState.wind_angle
		var max_step_change: float = 0.0
		for i in range(120):
			var prev_angle = GameState.wind_angle
			GameState.advance(1.0 / 60.0)
			var d_angle = absf(GameState.wind_angle - prev_angle)
			if d_angle > max_step_change:
				max_step_change = d_angle

		assert(GameState.wind_angle != initial_angle, "Wind angle must change over time")
		assert(
			max_step_change < 0.005,
			"Per-frame wind angle change must be subtle (was %f)" % max_step_change
		)

		# Test 3: All flags in main scene respect wind direction
		var flags_node = get_node_or_null("Props/Flags")
		assert(flags_node != null, "Props/Flags node must exist in main scene")

		var flags: Array[USFlag] = []
		for child in flags_node.get_children():
			if child is USFlag:
				flags.append(child)

		assert(
			flags.size() >= 7, "Must have at least 7 flags in Props/Flags, found %d" % flags.size()
		)

		# Snap all flags to initial wind
		for flag in flags:
			flag._update_wind_orientation(0.0, true)

		var cur_wind = GameState.wind_direction
		for flag in flags:
			var config: Dictionary = USFlag.SIZE_CONFIG[flag.flag_size]
			var node_name: String = config["node_name"]
			var flag_mesh: MeshInstance3D = flag.get_node("Visuals/" + node_name + "/Flag")
			var half_w: float = config["flag_half_width"]
			var fy: float = config["flag_y"]

			var hoist_world = flag_mesh.global_transform * Vector3(-half_w, 0.0, 0.0)
			var fly_world = flag_mesh.global_transform * Vector3(half_w, 0.0, 0.0)
			var pole_top = flag.global_position + Vector3(0.0, fy, 0.0)

			var dist_to_pole = hoist_world.distance_to(pole_top)
			assert(
				dist_to_pole < 0.01,
				"Flag hoist must stay attached to pole, dist = %f" % dist_to_pole
			)

			var flag_dir = fly_world - hoist_world
			flag_dir.y = 0.0
			flag_dir = flag_dir.normalized()
			var dot = flag_dir.dot(cur_wind)
			assert(
				dot > 0.95,
				"Flag '%s' must respect wind direction! Dot product: %f" % [flag.name, dot]
			)

		# Test 4: Dynamic wind change - all flags swivel to new direction
		var test_wind_targets = [
			Vector3(0.0, 0.0, 1.0),
			Vector3(-1.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -1.0),
			Vector3(0.707, 0.0, -0.707).normalized(),
		]

		for target_wind in test_wind_targets:
			GameState.set_wind_direction(target_wind, true)
			for step in range(90):
				for flag in flags:
					flag._update_wind_orientation(1.0 / 60.0, false)

			for flag in flags:
				var config: Dictionary = USFlag.SIZE_CONFIG[flag.flag_size]
				var node_name: String = config["node_name"]
				var flag_mesh: MeshInstance3D = flag.get_node("Visuals/" + node_name + "/Flag")
				var half_w: float = config["flag_half_width"]

				var hoist_world = flag_mesh.global_transform * Vector3(-half_w, 0.0, 0.0)
				var fly_world = flag_mesh.global_transform * Vector3(half_w, 0.0, 0.0)
				var flag_dir = fly_world - hoist_world
				flag_dir.y = 0.0
				flag_dir = flag_dir.normalized()

				var dot = flag_dir.dot(target_wind)
				assert(
					dot > 0.98,
					(
						"Flag '%s' must swivel to target wind %s! Dot: %f"
						% [flag.name, target_wind, dot]
					)
				)

		GameState.resume_wind_simulation()
		print("WIND_FLAGS_TEST: SUCCESS - all test cases passed!")
		get_tree().quit(0)
		return
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
	if "--test-debug-hud" in _user_args:
		var tm = $TrafficManager
		assert(
			tm != null and tm.debug_overlay != null, "TrafficManager and debug_overlay must exist"
		)
		var dbg: TrafficDebug = tm.debug_overlay

		# Overlay is initially hidden
		assert(dbg.visible == false, "Debug overlay must be initially hidden")
		assert(dbg.hud_layer != null, "HUD layer must exist")
		assert(dbg.hud_layer.visible == false, "HUD layer must be initially hidden")

		# Toggle overlay active
		dbg.visible = true
		assert(
			dbg.hud_layer.visible == true, "HUD layer must become visible when overlay is active"
		)

		# Initial counts based on live spots
		var init_free := 0
		var init_res := 0
		var init_occ := 0
		for s in tm.lot.spots:
			match s.state:
				ParkingSpot.State.FREE:
					init_free += 1
				ParkingSpot.State.RESERVED:
					init_res += 1
				ParkingSpot.State.OCCUPIED:
					init_occ += 1

		var hud_text := dbg.get_hud_text()
		assert(
			"%d free" % init_free in hud_text, "HUD text must reflect free stalls: %s" % hud_text
		)
		assert(
			"%d reserved" % init_res in hud_text,
			"HUD text must reflect reserved stalls: %s" % hud_text
		)
		assert(
			"%d occupied" % init_occ in hud_text,
			"HUD text must reflect occupied stalls: %s" % hud_text
		)
		assert(
			"errands_dropped_lot_full: 0" in hud_text,
			"HUD text must reflect 0 dropped: %s" % hud_text
		)
		assert(
			"watchdog_fires: 0" in hud_text, "HUD text must reflect 0 watchdog fires: %s" % hud_text
		)
		assert(
			"max_stuck_time: 0.0s" in hud_text,
			"HUD text must reflect 0.0s max stuck time: %s" % hud_text
		)

		# Dynamic update: reserve a free stall
		var free_spot: ParkingSpot = null
		for s in tm.lot.spots:
			if s.is_free():
				free_spot = s
				break
		assert(free_spot != null, "Must have a free spot")
		free_spot.state = ParkingSpot.State.RESERVED
		tm.lot.spot_changed.emit(free_spot)

		hud_text = dbg.get_hud_text()
		assert(
			"%d free" % (init_free - 1) in hud_text,
			"HUD text must reflect %d free stalls: %s" % [init_free - 1, hud_text]
		)
		assert(
			"%d reserved" % (init_res + 1) in hud_text,
			"HUD text must reflect %d reserved stalls: %s" % [init_res + 1, hud_text]
		)
		# Dynamic update: stats increment
		tm.stats["errands_dropped_lot_full"] = 4
		tm.stats["watchdog_fires"] = 2
		tm.stats["max_stuck_time"] = 4.8
		dbg.update_hud()
		hud_text = dbg.get_hud_text()
		assert(
			"errands_dropped_lot_full: 4" in hud_text, "HUD text must show 4 dropped: %s" % hud_text
		)
		assert(
			"watchdog_fires: 2" in hud_text, "HUD text must show 2 watchdog fires: %s" % hud_text
		)
		assert(
			"max_stuck_time: 4.8s" in hud_text, "HUD text must show 4.8s max stuck: %s" % hud_text
		)

		# Toggle overlay inactive
		dbg.visible = false
		assert(dbg.hud_layer.visible == false, "HUD layer must hide when overlay is inactive")

		print(
			"DEBUG_HUD_TEST: SUCCESS - HUD line shows stall counts, dropped, watchdog fires, and max stuck time"
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

	if "--test-exit-route" in _user_args:
		_test_frames += 1
		if _test_car.state == Car.State.REVERSING_OUT:
			_saw_reversing = true
		elif _test_car.state == Car.State.TO_EXIT:
			_saw_to_exit = true
		elif _test_car.state == Car.State.WAITING_TO_MERGE:
			_saw_waiting = true
			if not _mats_testing:
				print("EXIT_TEST: Arrived at WAITING_TO_MERGE at frame ", _test_frames)
				print("EXIT_TEST: pos=", _test_car.global_position, " speed=", _test_car.speed)
				var expected_wait_pt := Vector3(9.0, 0.0, -9.6)
				assert(_saw_reversing, "Car must have reversed out")
				assert(_saw_to_exit, "Car must have driven exit route")
				assert(
					_test_car.global_position.distance_to(expected_wait_pt) < 0.05,
					"Car must stop cleanly at (9, 0, -9.6)"
				)
				assert(_test_car.speed == 0.0, "Car speed must be 0.0")
				assert(is_instance_valid(_test_car), "Car must not despawn")
				assert(_test_car.blocker.collision_layer == 4, "Blocker must be on layer 3")
				_mats_testing = true
				_mats_start_frame = _test_frames
				mats.global_position = Vector3(9.0, 0.5, -13.0)
			else:
				mats.velocity = Vector3(0.0, 0.0, 5.0)
				if _test_frames - _mats_start_frame > 60:
					print(
						"EXIT_TEST: mats_pos=", mats.global_position, " mats_dead=", mats._is_dead
					)
					assert(not mats._is_dead, "Mats died on stopped car!")
					assert(
						mats.global_position.z < -11.0,
						"Mats walked through stopped car across sidewalk!"
					)
					print(
						"EXIT_TEST: SUCCESS - car reversed out, drove to wait point, stopped without despawning, and blocked Mats!"
					)
					get_tree().quit(0)
		if _test_frames > 1500:
			assert(false, "Timeout waiting for exit route completion!")

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
	if "--test-taco-dt-zones" in _user_args:
		_test_frames += 1
		var taco_hell = $Props/TacoHell
		var dt = taco_hell.get_node("DriveThru")
		var lcd = dt.get_node("MenuBoard/LcdLabel")
		var pickup = dt.get_node("PickupLabel")
		if "CONFIRMED" in lcd.text or "IN PROGRESS" in lcd.text:
			_dt_saw_order = true
		if "SERVING" in pickup.text:
			_dt_saw_pickup = true
		if _test_car != null and is_instance_valid(_test_car):
			if _test_car.state == Car.State.CRUISING:
				assert(_dt_saw_order, "Taco Hell drive-thru LCD must show active order")
				assert(_dt_saw_pickup, "Taco Hell drive-thru pickup sign must show serving")
				print(
					"TACO_DT_ZONES_TEST: SUCCESS - Verified live reactive LCD order screen and pickup window sign during real traffic simulation loop!"
				)
				get_tree().quit(0)
				return
		if _test_frames > 3600:
			assert(false, "Timeout waiting for taco dt zones test completion!")
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


func _on_player_died(pos: Vector3) -> void:
	if blood_splats and mats:
		BloodSplatScript.spawn(pos, blood_splats, [mats.get_rid()])


func _exit_tree() -> void:
	if (
		GameState.instance
		and GameState.instance.time_of_day_changed.is_connected(_on_time_of_day_changed)
	):
		GameState.instance.time_of_day_changed.disconnect(_on_time_of_day_changed)
