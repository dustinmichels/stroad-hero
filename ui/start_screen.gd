class_name StartScreen
extends CanvasLayer

signal started

enum Page { MAIN, CONTROLS }

const SCRIM_COLOR_START := Color(0.03, 0.04, 0.055, 1.0)
const SCRIM_COLOR_PAUSED := Color(0.03, 0.04, 0.055, 0.85)

@onready var root_control: Control = $RootControl
@onready var scrim: ColorRect = $RootControl/Scrim
@onready var pane: PanelContainer = $RootControl/Pane

# Pages
@onready var main_page: VBoxContainer = %MainPage
@onready var controls_page: VBoxContainer = %ControlsPage

# Main page controls
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var see_more_button: Button = %SeeMoreButton
@onready var prompt_label: Label = %PromptLabel
@onready var loading_status: HBoxContainer = %LoadingStatus
@onready var loading_label: Label = %LoadingLabel
@onready var quote_label: Label = %QuoteLabel
@onready var welcome_label: Label = %WelcomeLabel

# Controls page controls
@onready var controls_back_button: Button = %ControlsBackButton
@onready var controls_resume_button: Button = %ControlsResumeButton
@onready var controls_prompt_label: Label = %ControlsPromptLabel

var _active: bool = false
var _fade_tween: Tween
var _has_started_once: bool = false
var _is_loaded: bool = false
var _current_page: Page = Page.MAIN
var _opened_via_h: bool = false


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
	if see_more_button:
		see_more_button.pressed.connect(_on_see_more_pressed)
	if controls_back_button:
		controls_back_button.pressed.connect(_on_back_pressed)
	if controls_resume_button:
		controls_resume_button.pressed.connect(start_game)

	open_screen(Page.MAIN)

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
		if not loading and _current_page == Page.MAIN:
			start_button.grab_focus()
	if controls_resume_button:
		controls_resume_button.disabled = loading


func _mark_loaded() -> void:
	_is_loaded = true
	set_loading(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.godotReady) { window.godotReady(); }")


func show_page(page: Page) -> void:
	_current_page = page
	if page == Page.MAIN:
		if main_page:
			main_page.visible = true
		if controls_page:
			controls_page.visible = false
		if _is_loaded and start_button:
			start_button.grab_focus()
	else:
		if main_page:
			main_page.visible = false
		if controls_page:
			controls_page.visible = true
		if controls_back_button:
			controls_back_button.grab_focus()


func open_screen(page: Page = Page.MAIN) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	visible = true
	_active = true
	get_tree().paused = true

	if root_control:
		root_control.modulate.a = 1.0
	if scrim:
		scrim.color = SCRIM_COLOR_PAUSED if _has_started_once else SCRIM_COLOR_START

	_update_action_labels()
	show_page(page)


func _update_action_labels() -> void:
	var action_text := "RESUME" if _has_started_once else "START GAME"
	var prompt_text := (
		"[ Press Space, Enter, or Esc to Resume ]"
		if _has_started_once
		else "[ Press Space, Enter, or Esc to Play ]"
	)
	var controls_prompt_text := (
		"[ Press H or Esc to Close ]" if _has_started_once else "[ Press H or Esc to Return ]"
	)

	if start_button:
		start_button.text = action_text
		start_button.disabled = not _is_loaded
	if controls_resume_button:
		controls_resume_button.text = action_text
		controls_resume_button.disabled = not _is_loaded
	if prompt_label:
		prompt_label.text = prompt_text
	if controls_prompt_label:
		controls_prompt_label.text = controls_prompt_text


func start_game() -> void:
	if not _active or not _is_loaded:
		return
	_active = false
	_has_started_once = true
	_opened_via_h = false

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


func _on_see_more_pressed() -> void:
	show_page(Page.CONTROLS)


func _on_back_pressed() -> void:
	if _opened_via_h and _has_started_once:
		start_game()
	else:
		show_page(Page.MAIN)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _active:
		if not _is_loaded:
			get_viewport().set_input_as_handled()
			return

		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_H:
				if _current_page == Page.MAIN:
					show_page(Page.CONTROLS)
				else:
					if _has_started_once:
						start_game()
					else:
						show_page(Page.MAIN)
				get_viewport().set_input_as_handled()
				return

			if event.keycode == KEY_ESCAPE:
				if _current_page == Page.CONTROLS:
					if _opened_via_h and _has_started_once:
						start_game()
					else:
						show_page(Page.MAIN)
				else:
					start_game()
				get_viewport().set_input_as_handled()
				return

			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				var focused := get_viewport().gui_get_focus_owner()
				if focused in [see_more_button, controls_back_button]:
					# Let normal button GUI handle this
					return
				start_game()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
			if event.is_action_pressed("ui_cancel") and _current_page == Page.CONTROLS:
				if _opened_via_h and _has_started_once:
					start_game()
				else:
					show_page(Page.MAIN)
				get_viewport().set_input_as_handled()
				return
			start_game()
			get_viewport().set_input_as_handled()
			return

		# Consume any other game action keys while the start screen is up
		get_viewport().set_input_as_handled()
	elif not visible:
		if get_tree().paused:
			return
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_H:
				_opened_via_h = true
				open_screen(Page.CONTROLS)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE:
				_opened_via_h = false
				open_screen(Page.MAIN)
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("ui_cancel"):
			_opened_via_h = false
			open_screen(Page.MAIN)
			get_viewport().set_input_as_handled()
			return
