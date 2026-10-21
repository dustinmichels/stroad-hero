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
	Preset.ARCADE_8BIT: "8-Bit Arcade (PICO-8 Palette)",
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

const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")

@onready var effect_rect: ColorRect = $EffectRect
var _shader_mat: ShaderMaterial = null

# Palette textures for modes 1–4 (built once in _ready). Entry 0 is the
# darkest color and doubles as the outline ink.
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
			cycle_preset()
			get_viewport().set_input_as_handled()


func cycle_preset() -> Preset:
	var next_val := (int(current_preset) + 1) % (Preset.size())
	current_preset = next_val as Preset
	_notify_hud(PRESET_NAMES[current_preset])
	return current_preset


# ── Palette texture helpers ────────────────────────────────────────────────────


func _register_palette(mode: int, colors: Array) -> void:
	var img := Image.create(colors.size(), 1, false, Image.FORMAT_RGB8)
	for i in colors.size():
		img.set_pixel(i, 0, colors[i] as Color)
	_palette_textures[mode] = ImageTexture.create_from_image(img)
	_palette_sizes[mode] = colors.size()
	_palette_ink[mode] = colors[0] as Color


func _build_palette_textures() -> void:
	# Mode 1 – Game Boy Classic (4 green shades, dark→bright)
	var gb: Array = [
		Color(0.06, 0.22, 0.06),
		Color(0.19, 0.38, 0.19),
		Color(0.55, 0.67, 0.06),
		Color(0.61, 0.73, 0.06),
	]
	# Mode 2 – Amber CRT (8-step ramp from dark brown to bright amber)
	# Matches the former rgb_to_amber() linear mix across 8 evenly-spaced steps.
	var dark_amber := Color(0.08, 0.04, 0.01)
	var bright_amber := Color(1.0, 0.72, 0.15)
	var amber: Array = []
	for i in 8:
		amber.append(dark_amber.lerp(bright_amber, float(i) / 7.0))
	# Mode 3 – CGA Cyberpunk (4 colors: black, cyan, magenta, white)
	var cga: Array = [
		Color(0.02, 0.02, 0.04),
		Color(0.0, 0.85, 0.85),
		Color(0.95, 0.15, 0.65),
		Color(1.0, 1.0, 1.0),
	]
	_register_palette(1, gb)
	_register_palette(2, amber)
	_register_palette(3, cga)
	# Mode 4 – PICO-8 (16-color fantasy-console palette)
	var pico8: Array = [
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
	_register_palette(4, pico8)


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
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 8.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.90)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.22)
			_shader_mat.set_shader_parameter("outline_opacity", 0.80)
			_shader_mat.set_shader_parameter("palette_mode", 4)
			_apply_palette_texture(4)

		Preset.GAMEBOY:
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 4.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.85)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.25)
			_shader_mat.set_shader_parameter("outline_opacity", 0.75)
			_shader_mat.set_shader_parameter("palette_mode", 1)
			_apply_palette_texture(1)

		Preset.AMBER_CRT:
			_shader_mat.set_shader_parameter("pixel_size", 2.0)
			_shader_mat.set_shader_parameter("color_depth", 8.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.85)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.24)
			_shader_mat.set_shader_parameter("outline_opacity", 0.70)
			_shader_mat.set_shader_parameter("palette_mode", 2)
			_apply_palette_texture(2)

		Preset.CGA_CYBER:
			_shader_mat.set_shader_parameter("pixel_size", 3.0)
			_shader_mat.set_shader_parameter("color_depth", 4.0)
			_shader_mat.set_shader_parameter("dither_strength", 0.80)
			_shader_mat.set_shader_parameter("enable_outlines", true)
			_shader_mat.set_shader_parameter("outline_threshold", 0.22)
			_shader_mat.set_shader_parameter("outline_opacity", 0.80)
			_shader_mat.set_shader_parameter("palette_mode", 3)
			_apply_palette_texture(3)

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
		var mode: int = _shader_mat.get_shader_parameter("palette_mode")
		var outline_color: Color = _shader_mat.get_shader_parameter("outline_color")
		_outline_mat.set_shader_parameter("ink_color", _palette_ink.get(mode, outline_color))
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


func _apply_palette_texture(mode: int) -> void:
	if _palette_textures.has(mode):
		_shader_mat.set_shader_parameter("palette_texture", _palette_textures[mode])
		_shader_mat.set_shader_parameter("palette_size", _palette_sizes[mode])


func _notify_hud(preset_label: String) -> void:
	var hud_node := get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.call("show_toast", "Visual Style: %s" % preset_label, 1.8)
	print("RetroFilter: Switched style to '%s'" % preset_label)
