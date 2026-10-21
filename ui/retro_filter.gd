class_name RetroFilter
extends CanvasLayer

enum Preset {
	OFF = 0,
	SUBTLE_RETRO = 1,
	RETRO_16BIT = 2,
	RETRO_CHUNKY = 3,
	ARCADE_8BIT = 4,
	GAMEBOY = 5,
	AMBER_CRT = 6,
	CGA_CYBER = 7,
}

const PRESET_NAMES := {
	Preset.OFF: "Normal (3D Modern)",
	Preset.SUBTLE_RETRO: "Subtle Retro (2x Crisp - Readable Text)",
	Preset.RETRO_16BIT: "16-Bit Retro (3x Widescreen)",
	Preset.RETRO_CHUNKY: "16-Bit Chunky (4x)",
	Preset.ARCADE_8BIT: "8-Bit Arcade (Dithered)",
	Preset.GAMEBOY: "Game Boy Classic (4-Color)",
	Preset.AMBER_CRT: "Amber CRT Terminal",
	Preset.CGA_CYBER: "CGA Cyberpunk (4-Color)",
}
@export var current_preset: Preset = Preset.OFF:
	set(val):
		current_preset = val
		_apply_preset(current_preset)

@export var filter_hud: bool = false:
	set(val):
		filter_hud = val
		layer = 10 if filter_hud else 1

@onready var effect_rect: ColorRect = $EffectRect
var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	if effect_rect and effect_rect.material is ShaderMaterial:
		_shader_mat = effect_rect.material as ShaderMaterial
	layer = 10 if filter_hud else 1
	_apply_preset(current_preset)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F1 or event.physical_keycode == KEY_F1:
			cycle_preset()
			get_viewport().set_input_as_handled()


func cycle_preset() -> Preset:
	var next_val := (int(current_preset) + 1) % (Preset.size())
	current_preset = next_val as Preset
	_notify_hud(PRESET_NAMES[current_preset])
	return current_preset


func _apply_preset(preset: Preset) -> void:
	if not effect_rect:
		return
	if not _shader_mat and effect_rect.material is ShaderMaterial:
		_shader_mat = effect_rect.material as ShaderMaterial

	if preset == Preset.OFF:
		effect_rect.visible = false
		if _shader_mat:
			_shader_mat.set_shader_parameter("enabled", false)
		return

	effect_rect.visible = true
	if not _shader_mat:
		return

	_shader_mat.set_shader_parameter("enabled", true)

	match preset:
		Preset.SUBTLE_RETRO:
			_shader_mat.set_shader_parameter("pixel_size", 2.0)
			_shader_mat.set_shader_parameter("color_depth", 32.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.10)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.28)
			_shader_mat.set_shader_parameter("outline_opacity", 0.45)
			_shader_mat.set_shader_parameter("palette_mode", 0)

		Preset.RETRO_16BIT:
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 20.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.18)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.24)
			_shader_mat.set_shader_parameter("outline_opacity", 0.65)
			_shader_mat.set_shader_parameter("palette_mode", 0)

		Preset.RETRO_CHUNKY:
			_shader_mat.set_shader_parameter("pixel_size", 4.0)
			_shader_mat.set_shader_parameter("color_depth", 16.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.25)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.20)
			_shader_mat.set_shader_parameter("outline_opacity", 0.75)
			_shader_mat.set_shader_parameter("palette_mode", 0)

		Preset.ARCADE_8BIT:
			_shader_mat.set_shader_parameter("pixel_size", 2.5)
			_shader_mat.set_shader_parameter("color_depth", 8.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.28)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.22)
			_shader_mat.set_shader_parameter("outline_opacity", 0.80)
			_shader_mat.set_shader_parameter("palette_mode", 0)

		Preset.GAMEBOY:
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 4.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.30)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.25)
			_shader_mat.set_shader_parameter("outline_opacity", 0.75)
			_shader_mat.set_shader_parameter("palette_mode", 1)

		Preset.AMBER_CRT:
			_shader_mat.set_shader_parameter("pixel_size", 2.5)
			_shader_mat.set_shader_parameter("color_depth", 12.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.20)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.24)
			_shader_mat.set_shader_parameter("outline_opacity", 0.70)
			_shader_mat.set_shader_parameter("palette_mode", 2)

		Preset.CGA_CYBER:
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 4.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.25)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.22)
			_shader_mat.set_shader_parameter("outline_opacity", 0.80)
			_shader_mat.set_shader_parameter("palette_mode", 3)


func _notify_hud(preset_label: String) -> void:
	var hud_node := get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.call("show_toast", "Visual Style: %s" % preset_label, 1.8)
	print("RetroFilter: Switched style to '%s'" % preset_label)
