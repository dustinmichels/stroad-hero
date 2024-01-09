extends RigidBody2D


func _ready():
	var car_types = $AnimatedSprite2D.sprite_frames.get_animation_names()
	$AnimatedSprite2D.play(car_types[randi() % car_types.size()])
	#linear_velocity = Vector2(800.0, 0.0)


func flip():
	#scale.x = -1
	$AnimatedSprite2D.flip_h = true
	$CollisionShape2D.position.x *= -1
	$CollisionShape2D2.position.x *= -1
	$VisibleOnScreenNotifier2D.position.x *= -1
	#$CollisionShape2D.scale.x = -1


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
