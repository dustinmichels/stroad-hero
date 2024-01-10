extends CharacterBody2D

signal hit

@export var speed = 300  # How fast the player will move (pixels/sec).
var screen_size  # Size of the game window.

var curr_direction = "down"
var is_idle = true


func _ready():
	screen_size = get_viewport_rect().size
	#position = screen_size/2


func _process(delta):
	player_movement()
	player_animation()


func player_movement():
	if Input.is_action_pressed("move_right"):
		curr_direction = "right"
		is_idle = false
		velocity.x = speed
		velocity.y = 0
	elif Input.is_action_pressed("move_left"):
		curr_direction = "left"
		is_idle = false
		velocity.x = -speed
		velocity.y = 0
	elif Input.is_action_pressed("move_down"):
		curr_direction = "down"
		is_idle = false
		velocity.y = speed
		velocity.x = 0
	elif Input.is_action_pressed("move_up"):
		curr_direction = "up"
		is_idle = false
		velocity.y = -speed
		velocity.x = 0
	else:
		is_idle = true
		velocity.x = 0
		velocity.y = 0

	move_and_slide()
	position = position.clamp(Vector2.ZERO, screen_size * 2)


func player_animation():
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if is_idle:
		if curr_direction == "up":
			anim.play("idle_up")
		elif curr_direction == "down":
			anim.play("idle_down")
		elif curr_direction == "left":
			anim.flip_h = true
			anim.play("idle_side")
		elif curr_direction == "right":
			anim.flip_h = false
			anim.play("idle_side")
	else:
		if curr_direction == "up":
			anim.play("walk_up")
		elif curr_direction == "down":
			anim.play("walk_down")
		elif curr_direction == "left":
			anim.flip_h = true
			anim.play("walk_side")
		elif curr_direction == "right":
			anim.flip_h = false
			anim.play("walk_side")


func _on_body_entered(body):
	hide()  # Player disappears after being hit.
	hit.emit()
	$CollisionShape2D.set_deferred("disabled", true)


func start(pos):
	position = pos
	$AnimatedSprite2D.animation = "down"
	show()
	$CollisionShape2D.disabled = false
