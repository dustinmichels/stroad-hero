extends Node2D


func _ready():
	%DeathsCountLabel.text = "%3d" % 0
	%ErrandsCountLabel.text = "%3d" % 0
	

func update_deaths(num: int):
	%DeathsCountLabel.text = "%3d" % num


func update_errands(num: int):
	%ErrandsCountLabel.text = "%3d" % num
