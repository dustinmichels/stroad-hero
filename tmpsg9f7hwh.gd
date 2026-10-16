extends SceneTree

func _init():
	var scene = load('res://main.tscn')
	if scene == null:
		print('FAILED to load main.tscn')
		quit(1)
	var instance = scene.instantiate()
	print('Successfully loaded main.tscn: ', instance.name)
	quit(0)
