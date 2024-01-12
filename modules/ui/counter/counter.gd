extends Node2D
	

func update_deaths(num: int):
	%DeathsCountLabel.text = str(num)


func update_errands(num: int):
	%ErrandsCountLabel.text = str(num)
