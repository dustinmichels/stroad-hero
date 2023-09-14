extends Control

@onready var retry_button = %RetryButton as Button
@onready var quit_button = %QuitButton as Button
@onready var main_game = preload("res://main.tscn") as PackedScene


# Called when the node enters the scene tree for the first time.
func _ready():
	retry_button.button_down.connect(on_retry_button_pressed)
	quit_button.button_down.connect(on_quit_button_pressed)


func on_retry_button_pressed():
	get_tree().change_scene_to_packed(main_game)


func on_quit_button_pressed():
	get_tree().quit()
