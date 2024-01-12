extends Area2D

signal hit

@export var speed = 400  # How fast the player will move (pixels/sec).
var screen_size  # Size of the game window.

var curr_direction = "down"
var is_idle = true

@onready var footstep_audio = $AudioStreamPlayer2D


func _ready():
	screen_size = get_viewport_rect().size
	#position = screen_size/2


func lay():
	$AnimatedSprite2D.rotation = 270


func _process(delta):
	move_player(delta)
	animate_player()


func move_player(delta):
	var velocity = Vector2.ZERO  # The player's movement vector.
	if Input.is_action_pressed("move_right"):
		curr_direction = "right"
		velocity.y = 0
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		curr_direction = "left"
		velocity.y = 0
		velocity.x -= 1
	if Input.is_action_pressed("move_down"):
		curr_direction = "down"
		velocity.x = 0
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		curr_direction = "up"
		velocity.x = 0
		velocity.y -= 1

	if velocity.length() > 0:
		play_audio()
		is_idle = false
		velocity = velocity.normalized() * speed
	else:
		$AudioStreamPlayer2D.stop()
		is_idle = true

	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)


func play_audio():
		# if the footstep audio isn't playing, play the audio
	if !footstep_audio.playing:
		footstep_audio.pitch_scale = randf_range(.8, 1.2)
		footstep_audio.play()

func animate_player():
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
	show()
	$CollisionShape2D.disabled = false
