extends Node

@export var car_scene: PackedScene
@export var blood_scene: PackedScene
@export var flag_scene: PackedScene

@export var car_speed = 600.0

@onready var bloodLayer = $BloodLayer
@onready var yLayer = $ySort
@onready var player: Area2D = $ySort/Player
@onready var flag_layer = $FlagLayer

var curr_flags: Array

var DEATH_COUNT = 0
var ERRANDS_COUNT = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	#randomize()
	new_game()
	#$Counter.update_deaths(0)
	#$Counter.update_errands(0)


func _on_target_collected():
	ERRANDS_COUNT += 1
	$Counter.update_errands(ERRANDS_COUNT)
	spawn_flag()


func _on_player_hit():
	# add blood stain
	var blood = blood_scene.instantiate()
	blood.position = player.position
	bloodLayer.add_child(blood)  # Spawn the mob by adding it to the Main scene.
	blood.play_sound()

	# update deaths
	DEATH_COUNT += 1
	$Counter.update_deaths(DEATH_COUNT)

	# reset game, after pause
	await get_tree().create_timer(1.0).timeout
	reset()


func new_game():
	$MobTimer.start()
	player.start($Markers/StartPosition.position)
	spawn_flag()
	spawn_flag()
	#spawn_flag()
	#$Timers/StartTimer.start()


func reset():
	player.start($Markers/StartPosition.position)


func _on_mob_timer_timeout():
	_add_car_to_scene($Markers/CarStart_Left1.position, false)
	_add_car_to_scene($Markers/CarStart_Left2.position, false)
	_add_car_to_scene($Markers/CarStart_Right1.position, true)
	_add_car_to_scene($Markers/CarStart_Right2.position, true)


func _add_car_to_scene(pos: Vector2, flip: bool):
	var car = car_scene.instantiate()
	var speed = car_speed
	if flip:
		speed = -1 * car_speed
		car.flip()

	#car.position = Vector2(pos.x + randf_range(-100, 100), pos.y + randf_range(-5, 5))
	car.position = Vector2(pos.x + _get_variation(100), pos.y)
	car.linear_velocity = Vector2(speed + _get_variation(car_speed / 15), 0.0)
	yLayer.add_child(car)  # Spawn the mob by adding it to the Main scene.


func _get_variation(val: int):
	return randf_range(-val, val)


func spawn_flag():
	var pos = pick_flag_location()
	var flag = flag_scene.instantiate()
	flag.position = pos

	flag.collected.connect(_on_target_collected)
	yLayer.call_deferred("add_child", flag)

	curr_flags.append(flag)


func pick_flag_location():
	var r1: ReferenceRect = $SpawnRect1
	var r2: ReferenceRect = $SpawnRect2
	#var r3: ReferenceRect = $SpawnRect3

	#var rects = [r1, r2, r3]
	var rects = [r1, r2]
	var r = rects.pick_random()

	#var pos = curr_flags[0].position

	# TODO: make sure flag is not too close to existing flag

	var pos = r.position + Vector2(randf() * r.size.x, randf() * r.size.y)

	return pos
