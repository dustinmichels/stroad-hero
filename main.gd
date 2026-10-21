class_name Main
extends Node3D
const LABEL_FADE_MARGIN_METERS := 12.0

@export var mats_node: Mats = null
@export var hud_node: HUD = null
@export var objective_manager_node: ObjectiveManager = null
@export var traffic_manager_node: TrafficManager = null
@export var start_screen_node: StartScreen = null
@export var character_editor_node: CharacterEditor = null
@export var drive_thru_node: TacoHellDriveThru = null
@export var camera_node: Camera3D = null
@export var props_container: Node3D = null
@export var environment_controller_node: EnvironmentController = null
@onready var mats: Mats = mats_node if mats_node else get_node_or_null("Mats") as Mats
@onready var hud: HUD = hud_node if hud_node else get_node_or_null("HUD") as HUD
@onready var objective_manager: ObjectiveManager = (
	objective_manager_node if objective_manager_node else get_node_or_null("ObjectiveManager")
	as ObjectiveManager
)
@onready var traffic_manager: TrafficManager = (
	traffic_manager_node if traffic_manager_node else get_node_or_null("TrafficManager")
	as TrafficManager
)
@onready var start_screen: StartScreen = (
	start_screen_node if start_screen_node else get_node_or_null("StartScreen") as StartScreen
)
@onready var character_editor: CharacterEditor = (
	character_editor_node if character_editor_node else get_node_or_null("CharacterEditor")
	as CharacterEditor
)
@onready var drive_thru: TacoHellDriveThru = (
	drive_thru_node if drive_thru_node else get_node_or_null("Props/TacoHell/DriveThru")
	as TacoHellDriveThru
)
@onready
var camera_3d: Camera3D = camera_node if camera_node else get_node_or_null("Camera3D") as Camera3D
@onready
var props: Node3D = props_container if props_container else get_node_or_null("Props") as Node3D
@onready var blood_splats: Node3D = $BloodSplats
@onready var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("DirectionalLight3D")
@onready var environment_controller: EnvironmentController = (
	(
		environment_controller_node
		if environment_controller_node
		else get_node_or_null("EnvironmentController")
	)
	as EnvironmentController
)
@onready var streetlights_node: Node3D = get_node_or_null("Props/Streetlights")
var world_warmup: WorldWarmup = null
var _user_args: PackedStringArray = []
var _js_callbacks: Array = []


func _init() -> void:
	_user_args = OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_args():
		if not _user_args.has(arg):
			_user_args.append(arg)


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
	get_tree().node_added.connect(_configure_label_fade)
	_configure_label_fades(self)
	_wire_composition()
	_init_world_warmup()
	if not environment_controller:
		environment_controller = EnvironmentController.new()
		environment_controller.name = "EnvironmentController"
		add_child(environment_controller)
		environment_controller.setup(world_env, sun_light, streetlights_node)
	if mats:
		mats.died.connect(_on_player_died)
	if OS.has_feature("web"):
		_setup_web_bridge()


func _configure_label_fades(node: Node) -> void:
	_configure_label_fade(node)
	for child in node.get_children():
		_configure_label_fades(child)


func _configure_label_fade(node: Node) -> void:
	if node is not Label3D:
		return
	var label := node as Label3D
	if label.visibility_range_end <= 0.0:
		return
	label.visibility_range_end_margin = minf(
		LABEL_FADE_MARGIN_METERS, label.visibility_range_end * 0.3
	)
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _on_player_died(pos: Vector3) -> void:
	if blood_splats and mats:
		BloodSplat.spawn(pos, blood_splats, [mats.get_rid()])


func _wire_composition() -> void:
	if mats:
		if hud:
			hud.set_player(mats)
		if character_editor:
			character_editor.set_target_rig(mats.visual)
		if camera_3d and camera_3d is FollowCamera:
			(camera_3d as FollowCamera).set_target(mats)
	if camera_3d and hud:
		hud.set_camera(camera_3d)
	if start_screen:
		if hud:
			hud.set_start_screen(start_screen)
	if character_editor and hud:
		hud.set_character_editor(character_editor)
	if objective_manager:
		objective_manager._setup()
		if mats:
			objective_manager.mats = mats
		if hud:
			objective_manager.hud = hud
			hud.set_objective_manager(objective_manager)
		if start_screen:
			if not start_screen.started.is_connected(objective_manager.start_objective_flow):
				start_screen.started.connect(objective_manager.start_objective_flow)
		else:
			objective_manager.start_objective_flow()
	if drive_thru:
		if traffic_manager:
			drive_thru.set_traffic_manager(traffic_manager)
		if mats:
			drive_thru.set_player(mats)

	if environment_controller:
		environment_controller.setup(world_env, sun_light, streetlights_node)


func _init_world_warmup() -> void:
	if world_warmup == null:
		world_warmup = WorldWarmup.new()
	if start_screen:
		start_screen.set_warmup(world_warmup)
	world_warmup.start_warmup(get_tree(), props, traffic_manager, environment_controller)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_configure_label_fade):
		get_tree().node_added.disconnect(_configure_label_fade)
	if mats and is_instance_valid(mats):
		if mats.died.is_connected(_on_player_died):
			mats.died.disconnect(_on_player_died)
	if start_screen and objective_manager:
		if start_screen.started.is_connected(objective_manager.start_objective_flow):
			start_screen.started.disconnect(objective_manager.start_objective_flow)


func _setup_web_bridge() -> void:
	var window = JavaScriptBridge.get_interface("window")
	if not window:
		return
	var start_cb = JavaScriptBridge.create_callback(_on_js_start_game)
	var set_time_cb = JavaScriptBridge.create_callback(_on_js_set_time_hours)
	var get_time_cb = JavaScriptBridge.create_callback(_on_js_get_time_hours)
	_js_callbacks.append(start_cb)
	_js_callbacks.append(set_time_cb)
	_js_callbacks.append(get_time_cb)
	window.godotStartGame = start_cb
	window.godotSetTimeHours = set_time_cb
	window.godotGetTimeHours = get_time_cb


func _on_js_start_game(_args: Array) -> void:
	if start_screen and is_instance_valid(start_screen) and start_screen.visible:
		start_screen.dismiss_immediately()


func _on_js_set_time_hours(args: Array) -> void:
	if args.size() > 0:
		var hours: float = float(args[0])
		GameState.set_time_hours(hours)


func _on_js_get_time_hours(_args: Array) -> float:
	return GameState.current_time_hours
