extends Area2D


func _on_area_entered(area):
	modulate.a = 0.5


func _on_area_exited(area):
	if area.name == "Player":
		modulate.a = 1
