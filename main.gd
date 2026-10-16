extends Node3D

const BloodSplatScript = preload("res://blood_splat.gd")

@onready var mats: CharacterBody3D = $Mats
@onready var hud: CanvasLayer = $HUD
@onready var blood_splats: Node3D = $BloodSplats


func _ready() -> void:
	if mats:
		mats.died.connect(_on_player_died)


func _on_player_died(pos: Vector3) -> void:
	if hud and hud.has_method("increment_spd"):
		hud.increment_spd()
	if blood_splats and mats:
		BloodSplatScript.spawn(pos, blood_splats, [mats.get_rid()])
