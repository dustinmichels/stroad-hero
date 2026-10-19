class_name StartScreen
extends CanvasLayer

signal started

@onready var root_control: Control = $RootControl
@onready var scrim: ColorRect = $RootControl/Scrim
@onready var pane: PanelContainer = $RootControl/Pane
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var prompt_label: Label = %PromptLabel
@onready var loading_status: HBoxContainer = %LoadingStatus
@onready var loading_label: Label = %LoadingLabel

const SCRIM_COLOR_START := Color(0.03, 0.04, 0.055, 1.0)
const SCRIM_COLOR_PAUSED := Color(0.03, 0.04, 0.055, 0.85)

var _active: bool = false
var _fade_tween: Tween
var _has_started_once: bool = false
var _is_loaded: bool = false


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	for arg in user_args:
		if arg.begins_with("--test-") and arg != "--test-start-screen":
			visible = false
			return
	if quit_button and OS.has_feature("web"):
		quit_button.visible = false

	if start_button:
		start_button.pressed.connect(start_game)
	if quit_button:
		quit_button.pressed.connect(quit_game)
	open_screen()

	# In CLI tests, mark ready immediately to avoid async race in asserts
	for arg in user_args:
		if arg.begins_with("--test-"):
			_mark_loaded()
			return

	# In normal gameplay, gate start behind warmup frames
	set_loading(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_mark_loaded()


func set_loading(loading: bool) -> void:
	if loading_status:
		loading_status.visible = loading
	if prompt_label:
		prompt_label.visible = not loading
	if start_button:
		start_button.disabled = loading
		if not loading:
			start_button.grab_focus()


func _mark_loaded() -> void:
	_is_loaded = true
	set_loading(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.godotReady) { window.godotReady(); }")


func open_screen() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	visible = true
	_active = true
	get_tree().paused = true

	if root_control:
		root_control.modulate.a = 1.0
	if scrim:
		scrim.color = SCRIM_COLOR_PAUSED if _has_started_once else SCRIM_COLOR_START

	if start_button:
		if _has_started_once:
			start_button.text = "RESUME"
			if prompt_label:
				prompt_label.text = "[ Press Space, Enter, or Esc to Resume ]"
		else:
			start_button.text = "START GAME"
			if prompt_label:
				prompt_label.text = "[ Press Space, Enter, or Esc to Play ]"
		if _is_loaded:
			start_button.disabled = false
			start_button.grab_focus()
		else:
			start_button.disabled = true


func start_game() -> void:
	if not _active or not _is_loaded:
		return
	_active = false
	_has_started_once = true

	# Clear any queued jump input so Mats doesn't hop on unpause
	Input.action_release("jump")

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if root_control:
		_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		(
			_fade_tween
			. tween_property(root_control, "modulate:a", 0.0, 0.2)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		await _fade_tween.finished

	visible = false
	get_tree().paused = false
	await get_tree().process_frame
	started.emit()


func quit_game() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _active:
		if not _is_loaded:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_H]:
				start_game()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
			start_game()
			get_viewport().set_input_as_handled()
			return

		# Consume any other game action keys while the start screen is up
		get_viewport().set_input_as_handled()
	elif not visible:
		if get_tree().paused:
			return
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode in [KEY_ESCAPE, KEY_H]:
				open_screen()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("ui_cancel"):
			open_screen()
			get_viewport().set_input_as_handled()
			return
