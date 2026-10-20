class_name ObjectiveArrow
extends Control

@export var edge_margin: float = 60.0
@export var arrow_color: Color = Color(0.2, 0.85, 0.35, 0.65)
@export var outline_color: Color = Color(0.05, 0.18, 0.08, 0.65)
@export var arrow_scale: float = 2.0
@export var outline_width: float = 3.0

var objective_manager: ObjectiveManager = null
var camera: Camera3D = null
var mats: Mats = null

var is_arrow_visible: bool = false
var arrow_screen_pos: Vector2 = Vector2.ZERO
var arrow_rotation: float = 0.0
var distance_meters: int = 0

var distance_label: Label = null

var _start_screen: StartScreen = null
var _character_editor: CharacterEditor = null
var _phone_call: PhoneCall = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_distance_label()
	_resolve_dependencies.call_deferred()


func _exit_tree() -> void:
	if _character_editor and is_instance_valid(_character_editor):
		if _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		):
			_character_editor.visibility_changed.disconnect(_on_character_editor_visibility_changed)
	if _start_screen and is_instance_valid(_start_screen):
		if _start_screen.visibility_changed.is_connected(_on_start_screen_visibility_changed):
			_start_screen.visibility_changed.disconnect(_on_start_screen_visibility_changed)


func _setup_distance_label() -> void:
	if distance_label != null:
		return
	var existing := get_node_or_null("DistanceLabel") as Label
	if existing:
		distance_label = existing
		return
	distance_label = Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := load("res://fonts/Overpass-SemiBold.ttf") as Font
	if font:
		distance_label.add_theme_font_override("font", font)
	distance_label.add_theme_font_size_override("font_size", 16)
	distance_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95, 1.0))
	distance_label.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.08, 1.0))
	distance_label.add_theme_constant_override("outline_size", 3)
	distance_label.visible = false
	add_child(distance_label)


func _resolve_dependencies() -> void:
	if not objective_manager:
		objective_manager = (
			get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager
		)
		if not objective_manager and get_parent():
			var hud := get_parent() as HUD
			if hud and hud.objective_manager:
				objective_manager = hud.objective_manager
	if not mats:
		if objective_manager and objective_manager.mats:
			mats = objective_manager.mats
		else:
			mats = get_tree().get_first_node_in_group("player") as Mats
			if not mats and is_inside_tree() and get_tree().root:
				mats = get_tree().root.find_child("Mats", true, false) as Mats
	if not _phone_call and get_parent():
		_phone_call = get_parent().get_node_or_null("PhoneCall") as PhoneCall
	_find_start_screen()
	_find_character_editor()


func _find_start_screen() -> StartScreen:
	if _start_screen and is_instance_valid(_start_screen):
		return _start_screen
	if (
		get_parent()
		and get_parent().get_parent()
		and get_parent().get_parent().has_node("StartScreen")
	):
		_start_screen = get_parent().get_parent().get_node("StartScreen") as StartScreen
	elif is_inside_tree() and get_tree().root:
		_start_screen = get_tree().root.find_child("StartScreen", true, false) as StartScreen
	if (
		_start_screen
		and not _start_screen.visibility_changed.is_connected(_on_start_screen_visibility_changed)
	):
		_start_screen.visibility_changed.connect(_on_start_screen_visibility_changed)
	return _start_screen


func _find_character_editor() -> CharacterEditor:
	if _character_editor and is_instance_valid(_character_editor):
		return _character_editor
	if (
		get_parent()
		and get_parent().get_parent()
		and get_parent().get_parent().has_node("CharacterEditor")
	):
		_character_editor = (
			get_parent().get_parent().get_node("CharacterEditor") as CharacterEditor
		)
	elif is_inside_tree() and get_tree().root:
		_character_editor = (
			get_tree().root.find_child("CharacterEditor", true, false) as CharacterEditor
		)
	if (
		_character_editor
		and not _character_editor.visibility_changed.is_connected(
			_on_character_editor_visibility_changed
		)
	):
		_character_editor.visibility_changed.connect(_on_character_editor_visibility_changed)
	return _character_editor


func _on_start_screen_visibility_changed() -> void:
	update_arrow()


func _on_character_editor_visibility_changed() -> void:
	update_arrow()


func _get_active_camera() -> Camera3D:
	if camera and is_instance_valid(camera) and camera.is_inside_tree():
		return camera
	var vp := get_viewport()
	if vp:
		var cam := vp.get_camera_3d()
		if cam:
			camera = cam
			return cam
	if is_inside_tree() and get_tree().root:
		var cam_node := get_tree().root.find_child("Camera3D", true, false) as Camera3D
		if cam_node:
			camera = cam_node
			return cam_node
	return null


func _is_hidden_by_overlay() -> bool:
	var start_screen := _find_start_screen()
	if start_screen and is_instance_valid(start_screen) and start_screen.visible:
		return true

	var char_editor := _find_character_editor()
	if char_editor and is_instance_valid(char_editor) and char_editor.visible:
		return true

	if not _phone_call and get_parent():
		_phone_call = get_parent().get_node_or_null("PhoneCall") as PhoneCall
	if (
		_phone_call
		and is_instance_valid(_phone_call)
		and _phone_call.visible
		and (_phone_call.is_ringing or _phone_call.is_in_call)
	):
		return true

	if objective_manager and objective_manager.is_call_showing():
		return true

	return false


func _process(_delta: float) -> void:
	update_arrow()


func update_arrow() -> void:
	if _is_hidden_by_overlay():
		_set_arrow_visible(false)
		return

	if (
		not objective_manager
		or objective_manager.current_state != ObjectiveManager.State.ACTIVE
		or not objective_manager.current_errand
	):
		_set_arrow_visible(false)
		return

	var cam := _get_active_camera()
	if not cam:
		_set_arrow_visible(false)
		return

	var target_pos := objective_manager.get_target_position(objective_manager.current_errand)
	var is_behind := cam.is_position_behind(target_pos)
	var screen_pos := cam.unproject_position(target_pos)
	var vp_rect := get_viewport_rect()

	# If the target is on screen, hide the arrow (the world marker is enough)
	if not is_behind and vp_rect.has_point(screen_pos):
		_set_arrow_visible(false)
		return

	# Target is off screen
	_set_arrow_visible(true)

	var screen_center := vp_rect.size * 0.5
	var dir := screen_pos - screen_center

	# When the target is behind the camera, flip the direction
	if is_behind:
		dir = -dir

	if dir.length_squared() < 0.0001:
		dir = Vector2.DOWN
	else:
		dir = dir.normalized()

	# Clamp the arrow to the viewport edge with a margin of about 60 px
	var margin := edge_margin
	var hw := maxf(1.0, screen_center.x - margin)
	var hh := maxf(1.0, screen_center.y - margin)
	var tx := hw / absf(dir.x) if absf(dir.x) > 0.0001 else INF
	var ty := hh / absf(dir.y) if absf(dir.y) > 0.0001 else INF
	var t := minf(tx, ty)
	var clamped_pos := screen_center + dir * t
	clamped_pos.x = clampf(clamped_pos.x, margin, vp_rect.size.x - margin)
	clamped_pos.y = clampf(clamped_pos.y, margin, vp_rect.size.y - margin)

	arrow_screen_pos = clamped_pos
	arrow_rotation = dir.angle()

	# Distance in meters
	var mats_node := mats if mats else (objective_manager.mats if objective_manager else null)
	var ref_pos := mats_node.global_position if mats_node else cam.global_position
	var dist := Vector2(ref_pos.x - target_pos.x, ref_pos.z - target_pos.z).length()
	distance_meters = maxi(0, roundi(dist))

	if distance_label:
		distance_label.text = "%d m" % distance_meters
		distance_label.reset_size()
		var inward := -dir
		var label_offset := 24.0 + 12.0 * arrow_scale
		var label_pos := clamped_pos + inward * label_offset - distance_label.size * 0.5
		label_pos.x = clampf(label_pos.x, 10.0, vp_rect.size.x - distance_label.size.x - 10.0)
		label_pos.y = clampf(label_pos.y, 10.0, vp_rect.size.y - distance_label.size.y - 10.0)
		distance_label.position = label_pos

	queue_redraw()


func _set_arrow_visible(val: bool) -> void:
	if is_arrow_visible != val:
		is_arrow_visible = val
		queue_redraw()
	if distance_label:
		distance_label.visible = val


func _draw() -> void:
	if not is_arrow_visible:
		return

	var base_pts := [
		Vector2(16.0, 0.0),
		Vector2(-12.0, -11.0),
		Vector2(-6.0, 0.0),
		Vector2(-12.0, 11.0),
	]
	var cos_r := cos(arrow_rotation)
	var sin_r := sin(arrow_rotation)
	var transformed_pts := PackedVector2Array()
	for p in base_pts:
		var sp: Vector2 = p * arrow_scale
		var rx := sp.x * cos_r - sp.y * sin_r
		var ry := sp.x * sin_r + sp.y * cos_r
		transformed_pts.append(arrow_screen_pos + Vector2(rx, ry))

	draw_colored_polygon(transformed_pts, arrow_color)
	var outline_pts := PackedVector2Array(
		[
			transformed_pts[0],
			transformed_pts[1],
			transformed_pts[2],
			transformed_pts[3],
			transformed_pts[0],
		]
	)
	draw_polyline(outline_pts, outline_color, outline_width, true)
