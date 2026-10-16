class_name HUD
extends CanvasLayer

@onready var spd_label: Label = %SpdLabel
@onready var desc_label: Label = %DescLabel

var spd_count: int = 0


func _ready() -> void:
	_update_display()


func increment_spd() -> void:
	spd_count += 1
	_update_display()
	_animate_increment()


func set_spd(value: int) -> void:
	spd_count = value
	_update_display()


func _update_display() -> void:
	if spd_label:
		spd_label.text = "SPD: %d" % spd_count


func _animate_increment() -> void:
	if not spd_label:
		return
	var tween := create_tween()
	spd_label.pivot_offset = spd_label.size * 0.5
	spd_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	tween.tween_property(spd_label, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spd_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(spd_label, "modulate", Color.WHITE, 0.25)
