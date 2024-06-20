extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$Target.make_ghost()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_target_collected(target):
	print(target.is_ghost())
