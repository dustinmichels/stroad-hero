extends Node2D

var grid

func _ready():
	grid = $PanelContainer/MarginContainer/GridContainer

func update_deaths(num: int):
	grid.get_node("DeathsCountLabel").text = str(num)
	

