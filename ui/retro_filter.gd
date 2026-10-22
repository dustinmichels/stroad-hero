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
	NES = 8,
	ONE_BIT = 9,
	VIRTUAL_BOY = 10,
	ARCADE_CRT = 11,
	NIGHT_VISION = 12,
	THERMAL = 13,
	COMIC = 14,
}

# Shader `palette_mode` ids. Palettes are built once in _ready; entry 0 is the
# darkest color and doubles as the outline ink.
enum Palette {
	NONE = 0,
	GAMEBOY = 1,
	AMBER = 2,
	CGA = 3,
	PICO8 = 4,
	NES = 5,
	ONE_BIT = 6,
	VIRTUAL_BOY = 7,
	NIGHT_VISION = 8,
	THERMAL = 9,
	COMIC = 10,
}

const DEFAULT_OUTLINE_COLOR := Color(0.05, 0.06, 0.09)

# Every preset starts from these, so effects never leak between presets.
const BASE_PARAMS := {
	"pixel_size": 3.0,
	"color_depth": 16.0,
	"dither_strength": 0.5,
	"dither_pattern": 0,
	"enable_outlines": true,
	"outline_threshold": 0.22,
	"outline_opacity": 0.75,
	"palette_mode": Palette.NONE,
	"luma_ramp": false,
	"scanline_strength": 0.0,
	"mask_strength": 0.0,
	"curvature": 0.0,
	"vignette": 0.0,
	"grain": 0.0,
}

const PRESETS := {
	Preset.OFF: {"name": "Normal (3D Modern)"},
	Preset.SUBTLE_RETRO:
	{
		"name": "Subtle Retro (2x Crisp - Readable Text)",
		"pixel_size": 2.0,
		"color_depth": 32.0,
		"dither_strength": 0.10,
		"outline_threshold": 0.28,
		"outline_opacity": 0.45,
	},
	Preset.RETRO_16BIT:
	{
		"name": "16-Bit Retro (3x Widescreen)",
		"color_depth": 20.0,
		"dither_strength": 0.18,
		"outline_threshold": 0.24,
		"outline_opacity": 0.65,
	},
	Preset.RETRO_CHUNKY:
	{
		"name": "16-Bit Chunky (4x)",
		"pixel_size": 4.0,
		"dither_strength": 0.25,
		"outline_threshold": 0.20,
	},
	Preset.ARCADE_8BIT:
	{
		"name": "8-Bit Arcade (PICO-8 Palette)",
		"color_depth": 8.0,
		"dither_strength": 0.90,
		"outline_opacity": 0.80,
		"palette_mode": Palette.PICO8,
	},
	Preset.GAMEBOY:
	{
		"name": "Game Boy Classic (4-Color)",
		"color_depth": 4.0,
		"dither_strength": 0.85,
		"outline_threshold": 0.25,
		"palette_mode": Palette.GAMEBOY,
	},
	Preset.AMBER_CRT:
	{
		"name": "Amber CRT Terminal",
		"pixel_size": 2.0,
		"color_depth": 8.0,
		"dither_strength": 0.85,
		"outline_threshold": 0.24,
		"outline_opacity": 0.70,
		"palette_mode": Palette.AMBER,
	},
	Preset.CGA_CYBER:
	{
		"name": "CGA Cyberpunk (4-Color)",
		"color_depth": 4.0,
		"dither_strength": 0.80,
		"outline_opacity": 0.80,
		"palette_mode": Palette.CGA,
	},
	Preset.NES:
	{
		"name": "NES Console (2C02 Palette)",
		"pixel_size": 4.0,
		"color_depth": 6.0,
		"dither_strength": 0.55,
		"outline_opacity": 0.85,
		"palette_mode": Palette.NES,
	},
	Preset.ONE_BIT:
	{
		"name": "1-Bit Ink (Obra Dinn)",
		"pixel_size": 2.0,
		"color_depth": 1.0,
		"dither_strength": 1.0,
		"outline_threshold": 0.18,
		"outline_opacity": 1.0,
		"palette_mode": Palette.ONE_BIT,
		"luma_ramp": true,
	},
	Preset.VIRTUAL_BOY:
	{
		"name": "Virtual Boy (Red Mono)",
		"color_depth": 3.0,
		"dither_strength": 0.85,
		"outline_opacity": 0.90,
		"palette_mode": Palette.VIRTUAL_BOY,
		"luma_ramp": true,
		"vignette": 0.6,
	},
	Preset.ARCADE_CRT:
	{
		"name": "Arcade CRT (Scanlines + Curve)",
		"pixel_size": 3.0,
		"color_depth": 24.0,
		"dither_strength": 0.30,
		"outline_opacity": 0.60,
		"scanline_strength": 0.55,
		"mask_strength": 0.30,
		"curvature": 0.08,
		"vignette": 0.8,
	},
	Preset.NIGHT_VISION:
	{
		"name": "Night Vision Goggles",
		"pixel_size": 2.0,
		"color_depth": 7.0,
		"dither_strength": 0.6,
		"outline_opacity": 0.45,
		"palette_mode": Palette.NIGHT_VISION,
		"luma_ramp": true,
		"scanline_strength": 0.30,
		"vignette": 1.6,
		"grain": 0.12,
	},
	Preset.THERMAL:
	{
		"name": "Thermal Cam (Luma Heatmap)",
		"color_depth": 9.0,
		"dither_strength": 0.7,
		"outline_opacity": 0.5,
		"palette_mode": Palette.THERMAL,
		"luma_ramp": true,
		"grain": 0.04,
	},
	Preset.COMIC:
	{
		"name": "Comic Book Halftone (CMYK)",
		"pixel_size": 2.0,
		"color_depth": 2.0,
		"dither_strength": 1.0,
		"dither_pattern": 1,
		"outline_threshold": 0.16,
		"outline_opacity": 1.0,
		"palette_mode": Palette.COMIC,
	},
}

# NES 2C02 palette (common emulator approximation), duplicates removed.
const NES_RGB: Array[int] = [
	0x000000,
	0x545454,
	0x001E74,
	0x081090,
	0x300088,
	0x440064,
	0x5C0030,
	0x540400,
	0x3C1800,
	0x202A00,
	0x083A00,
	0x004000,
	0x003C00,
	0x00323C,
	0x989698,
	0x084CC4,
	0x3032EC,
	0x5C1EE4,
	0x8814B0,
	0xA01464,
	0x982220,
	0x783C00,
	0x545A00,
	0x287200,
	0x087C00,
	0x007628,
	0x006678,
	0xECEEEC,
	0x4C9AEC,
	0x787CEC,
	0xB062EC,
	0xE454EC,
	0xEC58B4,
	0xEC6A64,
	0xD48820,
	0xA0AA00,
	0x74C400,
	0x4CD020,
	0x38CC6C,
	0x38B4CC,
	0x3C3C3C,
	0xA8CCEC,
	0xBCBCEC,
	0xD4B2EC,
	0xECAEEC,
	0xECAED4,
	0xECB4B0,
	0xE4C490,
	0xCCD278,
	0xB4DE78,
	0xA8E290,
	0x98E2B4,
	0xA0D6E4,
	0xA0A2A0,
]

@export var current_preset: Preset = Preset.OFF:
	set(val):
		current_preset = val
		_apply_preset(current_preset)

@export var filter_hud: bool = false:
	set(val):
		filter_hud = val
		layer = 10 if filter_hud else 1

const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")

@onready var effect_rect: ColorRect = $EffectRect
var _shader_mat: ShaderMaterial = null

var _palette_textures: Dictionary = {}
var _palette_sizes: Dictionary = {}
var _palette_ink: Dictionary = {}

# Full-screen depth/normal outline pass (Forward+ only; see _uses_depth_outlines).
var _outline_quad: MeshInstance3D = null
var _outline_mat: ShaderMaterial = null

# Viewport 3D settings captured when a preset turns on, restored on OFF.
var _saved_3d_scale: float = -1.0
var _saved_msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED


func _ready() -> void:
	if effect_rect and effect_rect.material is ShaderMaterial:
		_shader_mat = effect_rect.material as ShaderMaterial
	layer = 10 if filter_hud else 1
	_build_palette_textures()
	_apply_preset(current_preset)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F1 or event.physical_keycode == KEY_F1:
			# Shift+F1 steps backwards.
			cycle_preset(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()


func cycle_preset(step: int = 1) -> Preset:
	var next_val := posmod(int(current_preset) + step, Preset.size())
	current_preset = next_val as Preset
	_notify_hud(PRESETS[current_preset]["name"])
	return current_preset


# ── Palette texture helpers ────────────────────────────────────────────────────


func _register_palette(mode: Palette, colors: Array) -> void:
	var img := Image.create(colors.size(), 1, false, Image.FORMAT_RGB8)
	for i in colors.size():
		img.set_pixel(i, 0, colors[i] as Color)
	_palette_textures[mode] = ImageTexture.create_from_image(img)
	_palette_sizes[mode] = colors.size()
	_palette_ink[mode] = colors[0] as Color


func _ramp(stops: Array, steps: int) -> Array:
	var out: Array = []
	for i in steps:
		var t := float(i) / float(steps - 1) * float(stops.size() - 1)
		var k := mini(int(t), stops.size() - 2)
		out.append((stops[k] as Color).lerp(stops[k + 1] as Color, t - float(k)))
	return out


func _build_palette_textures() -> void:
	_register_palette(
		Palette.GAMEBOY,
		[
			Color(0.06, 0.22, 0.06),
			Color(0.19, 0.38, 0.19),
			Color(0.55, 0.67, 0.06),
			Color(0.61, 0.73, 0.06),
		]
	)
	# 8-step ramp from dark brown to bright amber.
	_register_palette(Palette.AMBER, _ramp([Color(0.08, 0.04, 0.01), Color(1.0, 0.72, 0.15)], 8))
	_register_palette(
		Palette.CGA,
		[
			Color(0.02, 0.02, 0.04),
			Color(0.0, 0.85, 0.85),
			Color(0.95, 0.15, 0.65),
			Color(1.0, 1.0, 1.0),
		]
	)
	_register_palette(
		Palette.PICO8,
		[
			Color8(0, 0, 0),
			Color8(29, 43, 83),
			Color8(126, 37, 83),
			Color8(0, 135, 81),
			Color8(171, 82, 54),
			Color8(95, 87, 79),
			Color8(194, 195, 199),
			Color8(255, 241, 232),
			Color8(255, 0, 77),
			Color8(255, 163, 0),
			Color8(255, 236, 39),
			Color8(0, 228, 54),
			Color8(41, 173, 255),
			Color8(131, 118, 156),
			Color8(255, 119, 168),
			Color8(255, 204, 170),
		]
	)
	var nes: Array = []
	for rgb in NES_RGB:
		nes.append(Color.hex((rgb << 8) | 0xFF))
	_register_palette(Palette.NES, nes)
	# Luma ramps below must run dark → bright.
	_register_palette(Palette.ONE_BIT, [Color8(38, 36, 30), Color8(232, 228, 206)])
	_register_palette(Palette.VIRTUAL_BOY, _ramp([Color(0.0, 0.0, 0.0), Color(1.0, 0.02, 0.05)], 4))
	_register_palette(
		Palette.NIGHT_VISION,
		_ramp([Color(0.0, 0.03, 0.0), Color(0.2, 0.75, 0.15), Color(0.85, 1.0, 0.8)], 8)
	)
	_register_palette(
		Palette.THERMAL,
		_ramp(
			[
				Color(0.02, 0.0, 0.08),
				Color(0.3, 0.0, 0.55),
				Color(0.85, 0.05, 0.45),
				Color(1.0, 0.45, 0.0),
				Color(1.0, 0.9, 0.2),
				Color(1.0, 1.0, 1.0),
			],
			10
		)
	)
	_register_palette(
		Palette.COMIC,
		[
			Color(0.07, 0.06, 0.08),  # key (black ink)
			Color(0.0, 0.62, 0.89),  # cyan
			Color(0.9, 0.0, 0.5),  # magenta
			Color(1.0, 0.92, 0.0),  # yellow
			Color(0.93, 0.11, 0.14),  # red (M+Y)
			Color(0.12, 0.16, 0.62),  # blue (C+M)
			Color(0.0, 0.65, 0.31),  # green (C+Y)
			Color(0.5, 0.49, 0.46),  # grey (black halftone on paper)
			Color(0.97, 0.94, 0.84),  # newsprint
		]
	)


# ── Preset application ─────────────────────────────────────────────────────────


func _apply_preset(preset: Preset) -> void:
	if not effect_rect:
		return
	if not _shader_mat and effect_rect.material is ShaderMaterial:
		_shader_mat = effect_rect.material as ShaderMaterial

	if preset == Preset.OFF:
		effect_rect.visible = false
		if _shader_mat:
			_shader_mat.set_shader_parameter("enabled", false)
		if _outline_quad:
			_outline_quad.visible = false
		_restore_3d_render()
		return

	effect_rect.visible = true
	if not _shader_mat:
		return

	_shader_mat.set_shader_parameter("enabled", true)
	var params: Dictionary = BASE_PARAMS.merged(PRESETS[preset], true)
	for key: String in BASE_PARAMS:
		_shader_mat.set_shader_parameter(key, params[key])
	var mode: int = params["palette_mode"]
	if _palette_textures.has(mode):
		_shader_mat.set_shader_parameter("palette_texture", _palette_textures[mode])
		_shader_mat.set_shader_parameter("palette_size", _palette_sizes[mode])
	_shader_mat.set_shader_parameter("outline_color", _palette_ink.get(mode, DEFAULT_OUTLINE_COLOR))

	_apply_3d_render()


# ── 3D render settings ─────────────────────────────────────────────────────────


func _exit_tree() -> void:
	_restore_3d_render()


# Renders 3D at one sample per block (screen ÷ pixel_size) with MSAA, so each
# block is a real multisampled pixel and the 3D pass does ~pixel_size² less
# fragment work. The HUD and other 2D still render at full resolution.
func _apply_3d_render() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if _saved_3d_scale < 0.0:
		_saved_3d_scale = vp.scaling_3d_scale
		_saved_msaa_3d = vp.msaa_3d
	var pixel_size: float = _shader_mat.get_shader_parameter("pixel_size")
	vp.scaling_3d_scale = 1.0 / pixel_size
	vp.msaa_3d = maxi(_saved_msaa_3d, Viewport.MSAA_2X) as Viewport.MSAA

	var outlines: bool = _shader_mat.get_shader_parameter("enable_outlines")
	var depth_outlines := outlines and _uses_depth_outlines()
	# Depth outlines replace the color-based edge test rather than stacking on it.
	_shader_mat.set_shader_parameter("enable_outlines", outlines and not depth_outlines)
	if depth_outlines:
		_ensure_outline_quad()
		_outline_mat.set_shader_parameter(
			"ink_color", _shader_mat.get_shader_parameter("outline_color")
		)
		_outline_mat.set_shader_parameter(
			"opacity", _shader_mat.get_shader_parameter("outline_opacity")
		)
	if _outline_quad:
		_outline_quad.visible = depth_outlines


func _restore_3d_render() -> void:
	if _saved_3d_scale < 0.0 or not is_inside_tree():
		return
	var vp := get_viewport()
	vp.scaling_3d_scale = _saved_3d_scale
	vp.msaa_3d = _saved_msaa_3d
	_saved_3d_scale = -1.0


# Only Forward+ has the normal-roughness buffer. Mobile and Compatibility (web)
# keep the color-based edge test in pixel_art.gdshader.
func _uses_depth_outlines() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func _ensure_outline_quad() -> void:
	if _outline_quad:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE_SHADER
	# Draw before other transparent geometry so signs and glass stay on top.
	_outline_mat.render_priority = Material.RENDER_PRIORITY_MIN
	_outline_quad = MeshInstance3D.new()
	_outline_quad.name = "OutlineQuad"
	_outline_quad.mesh = quad
	_outline_quad.material_override = _outline_mat
	_outline_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The vertex shader places the quad in clip space; never frustum-cull it.
	_outline_quad.extra_cull_margin = 16384.0
	_outline_quad.ignore_occlusion_culling = true
	add_child(_outline_quad)


func _notify_hud(preset_label: String) -> void:
	var hud_node := get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.call("show_toast", "Visual Style: %s" % preset_label, 1.8)
	print("RetroFilter: Switched style to '%s'" % preset_label)
