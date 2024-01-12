extends Node2D


func _ready():
	%DeathsCountLabel.text = "%3d" % 0
	%ErrandsCountLabel.text = "%3d" % 0


func update_deaths(num: int):
	update_text(%DeathsCountLabel, num, Color.DARK_RED)


func update_errands(num: int):
	update_text(%ErrandsCountLabel, num, Color.FOREST_GREEN)


func update_text(label: Label, num: int, color: Color):
	label.add_theme_color_override("font_color", color)
	label.text = "%3d" % num
	await get_tree().create_timer(1.0).timeout
	label.add_theme_color_override("font_color", Color.WHITE)
