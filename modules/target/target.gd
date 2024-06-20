extends Area2D
class_name Target

signal collected(target: Target)

@onready var anim = $AnimatedSprite2D
@onready var shadow = $Shadow
@onready var rings = $Rings

var IS_GHOST = false


func _ready():
	anim.play("idle")
	shadow.play("idle")
	rings.play()


func _on_area_entered(area):
	if area.name == "Player":
		# emit signal
		collected.emit(self)
		$CollisionShape2D.set_deferred("disabled", true)

		# play audio
		$AudioStreamPlayer.play()

		# play animation
		anim.position.y += 20
		anim.position.x -= 10
		anim.play("collected")
		shadow.play("collected")
		$Circle.hide()
		rings.hide()

		# clear after animation
		await anim.animation_finished
		queue_free()
		
func make_ghost():
	modulate.a = 0.5
	modulate.r = 80
	IS_GHOST = true

func is_ghost():
	return IS_GHOST
