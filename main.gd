extends Node

@export var car_scene: PackedScene
@export var blood_scene: PackedScene

@export var car_speed = 750.0

var score
var bloodLayer
var yLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	#randomize()
	new_game()
	bloodLayer = $BloodLayer
	yLayer = $ySort


func game_over():
	$Timers/ScoreTimer.stop()
	#$MobTimer.stop()

	# add blood stain
	var blood = blood_scene.instantiate()
	blood.position = $ySort/Player.position
	bloodLayer.add_child(blood)  # Spawn the mob by adding it to the Main scene.

	# start new game, after pause
	await get_tree().create_timer(1.0).timeout
	new_game()


func new_game():
	score = 0
	$ySort/Player.start($StartPosition.position)
	$Timers/StartTimer.start()


func _on_start_timer_timeout():
	$Timers/MobTimer.start()
	$Timers/MobTimer2.start()
	$Timers/MobTimer3.start()
	$Timers/MobTimer4.start()
	$Timers/ScoreTimer.start()


func _on_score_timer_timeout():
	score += 1


func _on_mob_timer_timeout():
	var startPos = $CarStart_Left1.position
	var car = car_scene.instantiate()
	car.position = Vector2(startPos.x + randf_range(-100, 100), startPos.y + randf_range(-5, 5))
	car.linear_velocity = Vector2(car_speed + randf_range(-60, 60), 0.0)
	yLayer.add_child(car)  # Spawn the mob by adding it to the Main scene.


func _on_mob_timer_2_timeout():
	var startPos = $CarStart_Left2.position
	var car = car_scene.instantiate()
	car.position = Vector2(startPos.x + randf_range(-100, 100), startPos.y + randf_range(-5, 5))
	car.linear_velocity = Vector2(car_speed + randf_range(-60, 60), 0.0)
	yLayer.add_child(car)  # Spawn the mob by adding it to the Main scene.


func _on_mob_timer_3_timeout():
	var startPos = $CarStart_Right1.position
	var car = car_scene.instantiate()
	car.flip()
	car.position = Vector2(startPos.x + randf_range(-100, 100), startPos.y + randf_range(-5, 5))
	car.linear_velocity = Vector2((-1 * car_speed) + randf_range(-60, 60), 0.0)
	yLayer.add_child(car)  # Spawn the mob by adding it to the Main scene.


func _on_mob_timer_4_timeout():
	var startPos = $CarStart_Right2.position
	var car = car_scene.instantiate()
	car.flip()
	car.position = Vector2(startPos.x + randf_range(-100, 100), startPos.y + randf_range(-5, 5))
	car.linear_velocity = Vector2((-1 * car_speed) + randf_range(-60, 60), 0.0)
	yLayer.add_child(car)  # Spawn the mob by adding it to the Main scene.
