extends Node2D

#@export var reshape_max = 3.5
var stain: AnimatedSprite2D
var COUNT_DOWN = 0.9

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


# Called when the node enters the scene tree for the first time.
func _ready():
	stain = $AnimatedSprite2D
	stain.scale.x = randf_range(2.5, 3.5)
	stain.scale.y = randf_range(1, 2)
	stain.modulate = Color(0.9, 0.9, 0.9, COUNT_DOWN)


func _on_vanish_timeout():
	COUNT_DOWN -= 0.03
	if COUNT_DOWN < 0:
		queue_free()
	stain.modulate = Color(0.9, 0.9, 0.9, COUNT_DOWN)


func play_sound():
	audio_player.play()
