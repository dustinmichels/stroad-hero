class_name CharacterEditor
extends CanvasLayer

const BACKPACK_COLORS: Array[Color] = [
	Color(0.2, 0.55, 0.3, 1.0),
	Color(0.12, 0.32, 0.82, 1.0),
	Color(0.78, 0.2, 0.16, 1.0),
	Color(0.95, 0.72, 0.12, 1.0),
]
const BACKPACK_NAMES: Array[String] = ["Green", "Blue", "Red", "Yellow"]
const JACKET_COLORS: Array[Color] = [
	Color(0.96, 0.48, 0.1, 1.0),
	Color(0.15, 0.42, 0.85, 1.0),
	Color(0.82, 0.18, 0.15, 1.0),
	Color(0.18, 0.58, 0.28, 1.0),
	Color(0.95, 0.74, 0.12, 1.0),
]
const JACKET_NAMES: Array[String] = ["Orange", "Blue", "Red", "Green", "Yellow"]
const SHOE_COLORS: Array[Color] = [
	Color(0.8, 0.14, 0.12, 1.0),
	Color(0.95, 0.72, 0.12, 1.0),
	Color(0.14, 0.22, 0.42, 1.0),
	Color(0.14, 0.14, 0.16, 1.0),
	Color(0.2, 0.55, 0.3, 1.0),
]
const SHOE_NAMES: Array[String] = ["Red", "Yellow", "Navy", "Black", "Green"]
const HEADWEAR_NAMES: Array[String] = ["Natural", "Red ball cap", "Beanie"]

const PREVIEW_TURN_PERIOD := 8.0
const UNSELECTED_MODULATE := Color(0.7, 0.72, 0.74, 1.0)

@export var player_path: NodePath
@export var row_style: StyleBox
@export var row_selected_style: StyleBox

@onready var _camera: Camera3D = %PreviewCamera
@onready var _viewport: SubViewport = %PreviewViewport
@onready var _player: Mats = get_node_or_null(player_path)

var _preview: Mats = null
var _was_paused := false
var _selected_row := 0
var _headwear_index := 0
var _backpack_index := 0
var _jacket_index := 0
var _shoe_index := 0
var _preview_turn_time := 0.0


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 0.72, 0.0))
	%HeadPrevious.pressed.connect(_on_headwear_step.bind(-1))
	%HeadNext.pressed.connect(_on_headwear_step.bind(1))
	%JacketPrevious.pressed.connect(_on_jacket_step.bind(-1))
	%JacketNext.pressed.connect(_on_jacket_step.bind(1))
	%BackpackPrevious.pressed.connect(_on_backpack_step.bind(-1))
	%BackpackNext.pressed.connect(_on_backpack_step.bind(1))
	%ShoePrevious.pressed.connect(_on_shoe_step.bind(-1))
	%ShoeNext.pressed.connect(_on_shoe_step.bind(1))
	%CloseButton.pressed.connect(close_editor)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_preview_turn_time = fmod(_preview_turn_time + delta, PREVIEW_TURN_PERIOD)
	var turn_progress := 0.5 - 0.5 * cos(_preview_turn_time * TAU / PREVIEW_TURN_PERIOD)
	if _preview:
		_preview.rotation.y = turn_progress * PI


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_editor"):
		if visible:
			close_editor()
		else:
			open_editor()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_editor()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_up"):
		_select_row(-1)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_down"):
		_select_row(1)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_left"):
		_cycle_selected(-1)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_right"):
		_cycle_selected(1)
		get_viewport().set_input_as_handled()


func open_editor() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_selected_row = 0
	_ensure_preview_instantiated()
	_sync_from_player()
	_preview_turn_time = 0.0
	if _preview:
		_preview.rotation.y = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true


func close_editor() -> void:
	if not visible:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	visible = false
	get_tree().paused = _was_paused


func _exit_tree() -> void:
	if visible:
		get_tree().paused = _was_paused


func _sync_from_player() -> void:
	if _player:
		_headwear_index = _player.headwear
		_jacket_index = _closest_color(_player.jacket_color, JACKET_COLORS)
		_backpack_index = _closest_color(_player.backpack_color, BACKPACK_COLORS)
		_shoe_index = _closest_color(_player.shoe_color, SHOE_COLORS)
	_set_headwear(_headwear_index)
	_set_jacket_color(_jacket_index)
	_set_backpack_color(_backpack_index)
	_set_shoe_color(_shoe_index)
	_refresh_selection()


func _select_row(direction: int) -> void:
	_selected_row = posmod(_selected_row + direction, 4)
	_refresh_selection()


func _cycle_selected(direction: int) -> void:
	if _selected_row == 0:
		_set_headwear(posmod(_headwear_index + direction, HEADWEAR_NAMES.size()))
	elif _selected_row == 1:
		_set_jacket_color(posmod(_jacket_index + direction, JACKET_COLORS.size()))
	elif _selected_row == 2:
		_set_backpack_color(posmod(_backpack_index + direction, BACKPACK_COLORS.size()))
	else:
		_set_shoe_color(posmod(_shoe_index + direction, SHOE_COLORS.size()))


func _on_headwear_step(direction: int) -> void:
	_selected_row = 0
	_set_headwear(posmod(_headwear_index + direction, HEADWEAR_NAMES.size()))


func _on_jacket_step(direction: int) -> void:
	_selected_row = 1
	_set_jacket_color(posmod(_jacket_index + direction, JACKET_COLORS.size()))


func _on_backpack_step(direction: int) -> void:
	_selected_row = 2
	_set_backpack_color(posmod(_backpack_index + direction, BACKPACK_COLORS.size()))


func _on_shoe_step(direction: int) -> void:
	_selected_row = 3
	_set_shoe_color(posmod(_shoe_index + direction, SHOE_COLORS.size()))


func _set_headwear(value: int) -> void:
	_headwear_index = value
	if _preview:
		_preview.set_headwear(value)
	if _player:
		_player.set_headwear(value)
	_refresh_selection()


func _set_jacket_color(index: int) -> void:
	_jacket_index = index
	var color: Color = JACKET_COLORS[index]
	if _preview:
		_preview.set_jacket_color(color)
	if _player:
		_player.set_jacket_color(color)
	_refresh_selection()


func _set_backpack_color(index: int) -> void:
	_backpack_index = index
	var color: Color = BACKPACK_COLORS[index]
	if _preview:
		_preview.set_backpack_color(color)
	if _player:
		_player.set_backpack_color(color)
	_refresh_selection()


func _set_shoe_color(index: int) -> void:
	_shoe_index = index
	var color: Color = SHOE_COLORS[index]
	if _preview:
		_preview.set_shoe_color(color)
	if _player:
		_player.set_shoe_color(color)
	_refresh_selection()


func _closest_color(color: Color, palette: Array[Color]) -> int:
	var closest := 0
	var closest_distance := INF
	for index in palette.size():
		var option: Color = palette[index]
		var distance := Vector3(color.r, color.g, color.b).distance_squared_to(
			Vector3(option.r, option.g, option.b)
		)
		if distance < closest_distance:
			closest = index
			closest_distance = distance
	return closest


func _refresh_selection() -> void:
	if not is_node_ready():
		return
	%HeadwearValue.text = HEADWEAR_NAMES[_headwear_index]
	%JacketValue.text = JACKET_NAMES[_jacket_index]
	%JacketSwatch.color = JACKET_COLORS[_jacket_index]
	%BackpackValue.text = BACKPACK_NAMES[_backpack_index]
	%BackpackSwatch.color = BACKPACK_COLORS[_backpack_index]
	%ShoeValue.text = SHOE_NAMES[_shoe_index]
	%ShoeSwatch.color = SHOE_COLORS[_shoe_index]
	_style_row(%HairRow, _selected_row == 0)
	_style_row(%JacketRow, _selected_row == 1)
	_style_row(%BackpackRow, _selected_row == 2)
	_style_row(%ShoeRow, _selected_row == 3)


func _style_row(row: PanelContainer, selected: bool) -> void:
	row.add_theme_stylebox_override("panel", row_selected_style if selected else row_style)
	row.modulate = Color.WHITE if selected else UNSELECTED_MODULATE


func _ensure_preview_instantiated() -> void:
	if _preview != null and is_instance_valid(_preview):
		return
	if %PreviewViewport.has_node("PreviewMats"):
		_preview = %PreviewViewport.get_node("PreviewMats") as Mats
		return
	var mats_scene: PackedScene = load("res://player/mats.tscn")
	if mats_scene:
		var instance: Mats = mats_scene.instantiate() as Mats
		instance.name = "PreviewMats"
		instance.preview_mode = true
		%PreviewViewport.add_child(instance)
		_preview = instance
