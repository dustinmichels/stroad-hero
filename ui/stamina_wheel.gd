class_name StaminaWheel
extends Control
## Small circular stamina meter that appears when sprinting or recovering.

@export var mats: Mats = null
@export var camera: Camera3D = null

@export var radius: float = 14.0
@export var thickness: float = 4.0
@export var screen_offset: Vector2 = Vector2(28.0, -16.0)

@export var color_normal: Color = Color(0.24, 0.88, 0.42, 1.0)
@export var color_warning: Color = Color(0.96, 0.74, 0.16, 1.0)
@export var color_exhausted: Color = Color(0.92, 0.24, 0.20, 1.0)
@export var color_bg_track: Color = Color(0.12, 0.15, 0.20, 0.65)
@export var color_bg_disc: Color = Color(0.06, 0.08, 0.11, 0.60)
@export var color_border: Color = Color(0.04, 0.05, 0.07, 0.75)

const FADE_IN_SPEED: float = 10.0
const FADE_OUT_SPEED: float = 4.0
const FULL_LINGER_TIME: float = 0.45

var _current_ratio: float = 1.0
var _target_alpha: float = 0.0
var _fade_timer: float = 0.0
var _pulse_timer: float = 0.0

var _start_screen: StartScreen = null
var _character_editor: CharacterEditor = null
var _phone_call: PhoneCall = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	var diameter := (radius + thickness + 4.0) * 2.0
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	_resolve_dependencies.call_deferred()


func _resolve_dependencies() -> void:
	var hud := get_parent() as HUD
	if not mats and is_inside_tree():
		if hud and hud.player is Mats:
			mats = hud.player as Mats
		else:
			mats = get_tree().get_first_node_in_group("player") as Mats
	if not _phone_call and hud:
		_phone_call = hud.get_node_or_null("PhoneCall") as PhoneCall
	if not _start_screen and is_inside_tree():
		_find_start_screen()
	if not _character_editor and is_inside_tree():
		_find_character_editor()
	_resolve_camera()


func _find_start_screen() -> void:
	if is_inside_tree():
		var hud := get_parent() as HUD
		if hud and hud.start_screen:
			_start_screen = hud.start_screen
		else:
			_start_screen = get_tree().get_first_node_in_group("start_screen") as StartScreen


func _find_character_editor() -> void:
	if is_inside_tree():
		var hud := get_parent() as HUD
		if hud and hud.character_editor:
			_character_editor = hud.character_editor
		else:
			_character_editor = (
				get_tree().get_first_node_in_group("character_editor") as CharacterEditor
			)


func _resolve_camera() -> void:
	if camera and is_instance_valid(camera):
		return
	var hud := get_parent() as HUD
	if hud and hud.camera:
		camera = hud.camera
	elif is_inside_tree():
		var vp := get_viewport()
		if vp:
			camera = vp.get_camera_3d()


func _get_active_camera() -> Camera3D:
	if camera and is_instance_valid(camera) and camera.current:
		return camera
	var vp := get_viewport()
	if vp:
		var cam := vp.get_camera_3d()
		if cam:
			camera = cam
			return cam
	return null


func _is_hidden_by_overlay() -> bool:
	if _start_screen and is_instance_valid(_start_screen) and _start_screen.visible:
		return true
	if _character_editor and is_instance_valid(_character_editor) and _character_editor.visible:
		return true
	if _phone_call and is_instance_valid(_phone_call) and _phone_call.visible:
		return true
	return false


func _process(delta: float) -> void:
	if not mats or not is_instance_valid(mats):
		_resolve_dependencies()
		if not mats or not is_instance_valid(mats):
			_set_wheel_visible(false, delta)
			return

	if mats.preview_mode or mats.get("is_dead") or _is_hidden_by_overlay():
		_fade_timer = 0.0
		_target_alpha = 0.0
		_set_wheel_visible(false, delta)
		return

	var max_st: float = mats.max_stamina if mats.max_stamina > 0.0 else 100.0
	_current_ratio = clampf(mats.stamina / max_st, 0.0, 1.0)

	var is_sprinting: bool = mats.is_sprinting
	var is_exhausted: bool = mats.is_exhausted
	var is_depleted: bool = _current_ratio < 0.999

	if is_sprinting or is_exhausted:
		_target_alpha = 1.0
		_fade_timer = FULL_LINGER_TIME
	elif is_depleted:
		_target_alpha = 1.0
		_fade_timer = FULL_LINGER_TIME
	else:
		if _fade_timer > 0.0:
			_fade_timer -= delta
			_target_alpha = 1.0
		else:
			_target_alpha = 0.0

	if is_exhausted:
		_pulse_timer += delta * 14.0
	else:
		_pulse_timer = 0.0

	_update_position_and_alpha(delta)


func _update_position_and_alpha(delta: float) -> void:
	var fade_rate: float = FADE_IN_SPEED if _target_alpha > modulate.a else FADE_OUT_SPEED
	modulate.a = move_toward(modulate.a, _target_alpha, fade_rate * delta)

	if modulate.a <= 0.005:
		if visible:
			visible = false
		return

	var cam := _get_active_camera()
	if not cam:
		visible = false
		return

	var target_world_pos := mats.global_position + Vector3(0.0, 1.15, 0.0)
	if cam.is_position_behind(target_world_pos):
		visible = false
		return

	visible = true
	var screen_pos := cam.unproject_position(target_world_pos)
	var half_sz := size * 0.5
	var target_pos := screen_pos + screen_offset - half_sz
	var vp_rect := get_viewport_rect()
	target_pos.x = clampf(target_pos.x, 8.0, maxf(8.0, vp_rect.size.x - size.x - 8.0))
	target_pos.y = clampf(target_pos.y, 8.0, maxf(8.0, vp_rect.size.y - size.y - 8.0))
	position = target_pos
	queue_redraw()


func _set_wheel_visible(val: bool, delta: float) -> void:
	if not val:
		modulate.a = move_toward(modulate.a, 0.0, FADE_OUT_SPEED * delta)
		if modulate.a <= 0.005:
			visible = false


func _draw() -> void:
	if modulate.a <= 0.005 or not is_visible_in_tree():
		return

	var center := size * 0.5
	var track_radius := radius

	# 1. Background disc
	draw_circle(center, track_radius + thickness * 0.5 + 2.0, color_bg_disc)

	# 2. Dark track ring
	draw_arc(center, track_radius, 0.0, TAU, 36, color_bg_track, thickness, true)

	# 3. Subtle inner and outer borders
	draw_arc(center, track_radius + thickness * 0.5 + 1.0, 0.0, TAU, 36, color_border, 1.0, true)
	draw_arc(center, track_radius - thickness * 0.5 - 1.0, 0.0, TAU, 36, color_border, 1.0, true)

	# 4. Fill arc
	if _current_ratio > 0.005:
		var fill_color := color_normal
		if mats and mats.is_exhausted:
			var t := (sin(_pulse_timer) + 1.0) * 0.5
			fill_color = color_exhausted.lerp(Color(1.0, 0.6, 0.6, 1.0), t * 0.7)
		elif _current_ratio < 0.25:
			fill_color = color_warning.lerp(color_exhausted, (0.25 - _current_ratio) / 0.25)
		elif _current_ratio < 0.5:
			fill_color = color_normal.lerp(color_warning, (0.5 - _current_ratio) / 0.25)

		var start_angle := -PI * 0.5
		var sweep := _current_ratio * TAU
		draw_arc(
			center, track_radius, start_angle, start_angle + sweep, 36, fill_color, thickness, true
		)
	elif mats and mats.is_exhausted:
		var t := (sin(_pulse_timer) + 1.0) * 0.5
		var pulse_col := color_exhausted
		pulse_col.a = 0.4 + 0.5 * t
		draw_arc(center, track_radius, 0.0, TAU, 36, pulse_col, thickness, true)
