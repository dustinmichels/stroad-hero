class_name TestSuite
extends RefCounted

var main: Main
var user_args: Array[String] = []


func _init(p_main: Main, p_user_args: Array[String]) -> void:
	main = p_main
	user_args = p_user_args


func matches_args() -> bool:
	return false


func setup_ready() -> void:
	pass


func on_physics_process(_delta: float) -> void:
	pass
