extends CanvasLayer

const BACKPACK_COLORS := [
	Color(0.2, 0.55, 0.3, 1.0),
	Color(0.12, 0.32, 0.82, 1.0),
	Color(0.78, 0.2, 0.16, 1.0),
	Color(0.95, 0.72, 0.12, 1.0),
]
const BACKPACK_NAMES := ["Pine", "Blue", "Red", "Yellow"]

@export var player_path: NodePath

@onready var _preview: CharacterBody3D = %PreviewMats
@onready var _camera: Camera3D = %PreviewCamera
@onready var _player: CharacterBody3D = get_node_or_null(player_path)

var _was_paused := false
var _selected_row := 0
var _headwear_index := 1
var _backpack_index := 0


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 1.0, 0.0))
	%HeadPrevious.pressed.connect(_on_headwear_step.bind(-1))
	%HeadNext.pressed.connect(_on_headwear_step.bind(1))
	%BackpackPrevious.pressed.connect(_on_backpack_step.bind(-1))
	%BackpackNext.pressed.connect(_on_backpack_step.bind(1))
	%CloseButton.pressed.connect(close_editor)
	visible = false


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
	_sync_from_player()
	visible = true


func close_editor() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _exit_tree() -> void:
	if visible:
		get_tree().paused = _was_paused


func _sync_from_player() -> void:
	if _player:
		_headwear_index = _player.headwear
		_backpack_index = _closest_backpack_color(_player.backpack_color)
	_set_headwear(_headwear_index)
	_set_backpack_color(_backpack_index)
	_refresh_selection()


func _select_row(direction: int) -> void:
	_selected_row = posmod(_selected_row + direction, 2)
	_refresh_selection()


func _cycle_selected(direction: int) -> void:
	if _selected_row == 0:
		_set_headwear(posmod(_headwear_index + direction, 2))
	else:
		_set_backpack_color(posmod(_backpack_index + direction, BACKPACK_COLORS.size()))


func _on_headwear_step(direction: int) -> void:
	_selected_row = 0
	_set_headwear(posmod(_headwear_index + direction, 2))


func _on_backpack_step(direction: int) -> void:
	_selected_row = 1
	_set_backpack_color(posmod(_backpack_index + direction, BACKPACK_COLORS.size()))


func _set_headwear(value: int) -> void:
	_headwear_index = value
	_preview.set_headwear(value)
	if _player:
		_player.set_headwear(value)
	_refresh_selection()


func _set_backpack_color(index: int) -> void:
	_backpack_index = index
	var color: Color = BACKPACK_COLORS[index]
	_preview.set_backpack_color(color)
	if _player:
		_player.set_backpack_color(color)
	_refresh_selection()


func _closest_backpack_color(color: Color) -> int:
	var closest := 0
	var closest_distance := INF
	for index in BACKPACK_COLORS.size():
		var option: Color = BACKPACK_COLORS[index]
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
	%HeadwearValue.text = "Hair" if _headwear_index == 0 else "Hat"
	%BackpackValue.text = BACKPACK_NAMES[_backpack_index]
	%BackpackSwatch.color = BACKPACK_COLORS[_backpack_index]
	var head_modulate := Color.WHITE if _selected_row == 0 else Color(0.55, 0.58, 0.6, 1.0)
	var backpack_modulate := Color.WHITE if _selected_row == 1 else Color(0.55, 0.58, 0.6, 1.0)
	%HeadPrevious.modulate = head_modulate
	%HeadNext.modulate = head_modulate
	%HeadwearValue.modulate = head_modulate
	%BackpackPrevious.modulate = backpack_modulate
	%BackpackNext.modulate = backpack_modulate
	%BackpackValue.modulate = backpack_modulate
	%BackpackSwatch.modulate = backpack_modulate
