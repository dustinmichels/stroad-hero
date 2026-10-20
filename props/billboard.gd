@tool
class_name Billboard
extends StaticBody3D

enum BillboardVariant {
	LAWYER_CENTERED,
	JEWELRY_OFFSET,
	CUSTOM,
}

@export_group("Variant & Structure")
@export var variant: BillboardVariant = BillboardVariant.LAWYER_CENTERED:
	set(value):
		variant = value
		_on_variant_changed()

@export_group("Front Content")
@export_multiline var headline_text: String = "INJURED ON THE STROAD?":
	set(value):
		headline_text = value
		_update_billboard()

@export_multiline var tagline_text: String = "Call Me!":
	set(value):
		tagline_text = value
		_update_billboard()

@export var contact_text: String = "444-STROAD":
	set(value):
		contact_text = value
		_update_billboard()

@export var disclaimer_text: String = "ACCIDENT & INJURY LAW • FREE CONSULTATION":
	set(value):
		disclaimer_text = value
		_update_billboard()

@export var show_banner: bool = true:
	set(value):
		show_banner = value
		_update_billboard()
@export var portrait_texture: Texture2D = preload("res://props/lawyer_portrait.png"):
	set(value):
		portrait_texture = value
		_update_billboard()

@export var show_portrait: bool = true:
	set(value):
		show_portrait = value
		_update_billboard()
@export var portrait_on_left: bool = false:
	set(value):
		portrait_on_left = value
		_update_billboard()

@export var custom_texture: Texture2D = null:
	set(value):
		custom_texture = value
		_update_billboard()

@export var hide_text_when_texture_set: bool = true:
	set(value):
		hide_text_when_texture_set = value
		_update_billboard()

@export_group("Front Styling")
@export var background_color: Color = Color(0.08, 0.14, 0.34, 1.0):
	set(value):
		background_color = value
		_update_billboard()

@export var headline_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		headline_color = value
		_update_billboard()

@export var tagline_color: Color = Color(1.0, 0.88, 0.15, 1.0):
	set(value):
		tagline_color = value
		_update_billboard()

@export var contact_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		contact_color = value
		_update_billboard()

@export var disclaimer_color: Color = Color(0.9, 0.92, 0.95, 1.0):
	set(value):
		disclaimer_color = value
		_update_billboard()

@export var banner_color: Color = Color(0.82, 0.12, 0.12, 1.0):
	set(value):
		banner_color = value
		_update_billboard()

@export_group("Structure & Lighting")
@export var two_sided: bool = true:
	set(value):
		two_sided = value
		_update_billboard()

@export var lights_enabled: bool = true:
	set(value):
		lights_enabled = value
		_update_billboard()

@export_group("Back Content")
@export var back_matches_front: bool = true:
	set(value):
		back_matches_front = value
		_update_billboard()

@export_multiline var back_headline_text: String = "INJURED ON THE STROAD?":
	set(value):
		back_headline_text = value
		_update_billboard()

@export_multiline var back_tagline_text: String = "Call Me!":
	set(value):
		back_tagline_text = value
		_update_billboard()

@export var back_contact_text: String = "444-STROAD":
	set(value):
		back_contact_text = value
		_update_billboard()

@export var back_disclaimer_text: String = "ACCIDENT & INJURY LAW • FREE CONSULTATION":
	set(value):
		back_disclaimer_text = value
		_update_billboard()

@export var back_show_banner: bool = true:
	set(value):
		back_show_banner = value
		_update_billboard()

@export var back_portrait_texture: Texture2D = null:
	set(value):
		back_portrait_texture = value
		_update_billboard()

@export var back_show_portrait: bool = true:
	set(value):
		back_show_portrait = value
		_update_billboard()
@export var back_portrait_on_left: bool = false:
	set(value):
		back_portrait_on_left = value
		_update_billboard()

@export var back_custom_texture: Texture2D = null:
	set(value):
		back_custom_texture = value
		_update_billboard()
@export var back_background_color: Color = Color(0.08, 0.14, 0.34, 1.0):
	set(value):
		back_background_color = value
		_update_billboard()

@export var back_headline_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		back_headline_color = value
		_update_billboard()

@export var back_tagline_color: Color = Color(1.0, 0.88, 0.15, 1.0):
	set(value):
		back_tagline_color = value
		_update_billboard()

@export var back_contact_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		back_contact_color = value
		_update_billboard()

@export var back_disclaimer_color: Color = Color(0.9, 0.92, 0.95, 1.0):
	set(value):
		back_disclaimer_color = value
		_update_billboard()

@export var back_banner_color: Color = Color(0.82, 0.12, 0.12, 1.0):
	set(value):
		back_banner_color = value
		_update_billboard()


func _ready() -> void:
	_apply_structure_variant()
	_update_billboard()


func set_variant(p_variant: BillboardVariant) -> void:
	variant = p_variant


func _on_variant_changed() -> void:
	if variant == BillboardVariant.JEWELRY_OFFSET:
		custom_texture = preload("res://props/billboard_jewelry_face.png")
		headline_text = "Simon G."
		tagline_text = "Nature Coast 🌲 Jewelers"
		contact_text = "Turn Right Now • 352-686-4515 ➔"
		disclaimer_text = "NATURE COAST JEWELERS • SPRING HILL, FL"
		show_banner = false
		portrait_texture = preload("res://props/jewelry_ring.png")
		show_portrait = true
		portrait_on_left = true
		background_color = Color(0.96, 0.97, 0.98, 1.0)
		headline_color = Color(0.18, 0.22, 0.24, 1.0)
		tagline_color = Color(0.12, 0.28, 0.18, 1.0)
		contact_color = Color(0.15, 0.18, 0.2, 1.0)
		disclaimer_color = Color(0.4, 0.45, 0.5, 1.0)
	elif variant == BillboardVariant.LAWYER_CENTERED:
		custom_texture = null
		headline_text = "INJURED ON THE STROAD?"
		tagline_text = "Call Me!"
		contact_text = "444-STROAD"
		disclaimer_text = "ACCIDENT & INJURY LAW • FREE CONSULTATION"
		show_banner = true
		portrait_texture = preload("res://props/lawyer_portrait.png")
		show_portrait = true
		portrait_on_left = false
		background_color = Color(0.08, 0.14, 0.34, 1.0)
		headline_color = Color(1.0, 1.0, 1.0, 1.0)
		tagline_color = Color(1.0, 0.88, 0.15, 1.0)
		contact_color = Color(1.0, 1.0, 1.0, 1.0)
		disclaimer_color = Color(0.9, 0.92, 0.95, 1.0)
		banner_color = Color(0.82, 0.12, 0.12, 1.0)
	_apply_structure_variant()
	_update_billboard()


func _apply_structure_variant() -> void:
	var structure: Node3D = get_node_or_null("Structure")
	var col_pole: CollisionShape3D = get_node_or_null("CollisionPole")
	var is_offset: bool = variant == BillboardVariant.JEWELRY_OFFSET

	if col_pole:
		col_pole.position.x = 2.1 if is_offset else 0.0

	if not structure:
		return

	var centered_group: Node3D = structure.get_node_or_null("CenteredGroup")
	var offset_group: Node3D = structure.get_node_or_null("OffsetGroup")

	if centered_group:
		centered_group.visible = not is_offset
	if offset_group:
		offset_group.visible = is_offset

	var rusted_mat: StandardMaterial3D = null
	if is_offset:
		rusted_mat = StandardMaterial3D.new()
		rusted_mat.albedo_color = Color(0.44, 0.27, 0.18, 1.0)
		rusted_mat.metallic = 0.35
		rusted_mat.roughness = 0.82

	for i in range(5):
		var upright: MeshInstance3D = structure.get_node_or_null("Upright%d" % i)
		if upright:
			upright.material_override = rusted_mat

	for trim_name in ["TrimTop", "TrimBottom", "TrimLeft", "TrimRight"]:
		var trim: MeshInstance3D = structure.get_node_or_null(trim_name)
		if trim:
			trim.material_override = rusted_mat

	for side_name in ["FrontSide", "BackSide"]:
		var side: Node3D = get_node_or_null(side_name)
		if side:
			var catwalk: Node3D = side.get_node_or_null("Catwalk")
			if catwalk:
				var walkway: MeshInstance3D = catwalk.get_node_or_null("Walkway")
				if walkway:
					walkway.material_override = rusted_mat
				for part in [
					"HandrailTop", "HandrailMid", "Post0", "Post1", "Post2", "Post3", "Post4"
				]:
					var mesh_part: MeshInstance3D = catwalk.get_node_or_null(part)
					if mesh_part:
						mesh_part.material_override = rusted_mat

	# Fallback if monolithic structure without groups
	if not centered_group and not offset_group:
		var monopole: MeshInstance3D = structure.get_node_or_null("Monopole")
		if monopole:
			monopole.position.x = 2.1 if is_offset else 0.0
			monopole.material_override = rusted_mat
		var foundation: MeshInstance3D = structure.get_node_or_null("Foundation")
		if foundation:
			foundation.position.x = 2.1 if is_offset else 0.0
		var ladder: Node3D = structure.get_node_or_null("Ladder")
		if ladder:
			ladder.position.x = 2.54 if is_offset else 0.44


func set_front_content(
	p_headline: String, p_tagline: String, p_contact: String, p_disclaimer: String = ""
) -> void:
	headline_text = p_headline
	tagline_text = p_tagline
	contact_text = p_contact
	disclaimer_text = p_disclaimer
	_update_billboard()


func set_back_content(
	p_headline: String, p_tagline: String, p_contact: String, p_disclaimer: String = ""
) -> void:
	back_matches_front = false
	back_headline_text = p_headline
	back_tagline_text = p_tagline
	back_contact_text = p_contact
	back_disclaimer_text = p_disclaimer
	_update_billboard()


func set_portrait(p_texture: Texture2D, p_back_texture: Texture2D = null) -> void:
	portrait_texture = p_texture
	if p_back_texture != null:
		back_matches_front = false
		back_portrait_texture = p_back_texture
	_update_billboard()


func set_custom_texture(p_texture: Texture2D, p_back_texture: Texture2D = null) -> void:
	custom_texture = p_texture
	if p_back_texture != null:
		back_matches_front = false
		back_custom_texture = p_back_texture
	_update_billboard()


func set_colors(
	p_bg: Color,
	p_headline: Color,
	p_tagline: Color,
	p_contact: Color,
	p_banner: Color = Color(0.82, 0.12, 0.12, 1.0)
) -> void:
	background_color = p_bg
	headline_color = p_headline
	tagline_color = p_tagline
	contact_color = p_contact
	banner_color = p_banner
	_update_billboard()


func _update_billboard() -> void:
	if get_node_or_null("FrontSide") == null:
		return

	_update_side(
		"FrontSide",
		custom_texture,
		portrait_texture,
		show_portrait,
		portrait_on_left,
		background_color,
		show_banner,
		banner_color,
		headline_text,
		headline_color,
		tagline_text,
		tagline_color,
		contact_text,
		contact_color,
		disclaimer_text,
		disclaimer_color
	)
	var back_side: Node3D = get_node_or_null("BackSide")
	var back_cover: MeshInstance3D = get_node_or_null("Structure/BackCover")

	if back_side:
		back_side.visible = two_sided
	if back_cover:
		back_cover.visible = not two_sided

	if two_sided and back_side:
		var tex: Texture2D = custom_texture if back_matches_front else back_custom_texture
		var port: Texture2D = portrait_texture if back_matches_front else back_portrait_texture
		var s_port: bool = show_portrait if back_matches_front else back_show_portrait
		var bg_col: Color = background_color if back_matches_front else back_background_color
		var sb: bool = show_banner if back_matches_front else back_show_banner
		var b_col: Color = banner_color if back_matches_front else back_banner_color
		var hl_txt: String = headline_text if back_matches_front else back_headline_text
		var hl_col: Color = headline_color if back_matches_front else back_headline_color
		var tag_txt: String = tagline_text if back_matches_front else back_tagline_text
		var tag_col: Color = tagline_color if back_matches_front else back_tagline_color
		var cnt_txt: String = contact_text if back_matches_front else back_contact_text
		var cnt_col: Color = contact_color if back_matches_front else back_contact_color
		var disc_txt: String = disclaimer_text if back_matches_front else back_disclaimer_text
		var disc_col: Color = disclaimer_color if back_matches_front else back_disclaimer_color
		var p_left: bool = portrait_on_left if back_matches_front else back_portrait_on_left
		_update_side(
			"BackSide",
			tex,
			port,
			s_port,
			p_left,
			bg_col,
			sb,
			b_col,
			hl_txt,
			hl_col,
			tag_txt,
			tag_col,
			cnt_txt,
			cnt_col,
			disc_txt,
			disc_col
		)
	_update_lights()


func _update_side(
	side_node_name: String,
	p_texture: Texture2D,
	p_portrait: Texture2D,
	p_show_portrait: bool,
	p_portrait_on_left: bool,
	p_bg_color: Color,
	p_show_banner: bool,
	p_banner_color: Color,
	p_headline_text: String,
	p_headline_color: Color,
	p_tagline_text: String,
	p_tagline_color: Color,
	p_contact_text: String,
	p_contact_color: Color,
	p_disclaimer_text: String,
	p_disclaimer_color: Color
) -> void:
	var side_node: Node3D = get_node_or_null(side_node_name)
	if not side_node:
		return

	# Board Face Material
	var board_mesh: MeshInstance3D = side_node.get_node_or_null("Board")
	if board_mesh:
		var board_mat := StandardMaterial3D.new()
		board_mat.roughness = 0.55
		board_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if p_texture != null:
			board_mat.albedo_texture = p_texture
			board_mat.albedo_color = Color.WHITE
		else:
			board_mat.albedo_color = p_bg_color
		board_mesh.material_override = board_mat

	# Banner
	var has_texture: bool = p_texture != null
	var hide_text: bool = has_texture and hide_text_when_texture_set
	var active_portrait: bool = p_portrait != null and p_show_portrait and not hide_text

	var port_x: float = -2.35 if p_portrait_on_left else 2.35
	var content_x: float = (
		1.35 if (active_portrait and p_portrait_on_left) else (-1.55 if active_portrait else 0.0)
	)
	var banner_scale_x: float = (4.4 / 5.6) if active_portrait else 1.0

	# Portrait Mesh & Frame
	var portrait_mesh: MeshInstance3D = side_node.get_node_or_null("Portrait")
	var portrait_frame: MeshInstance3D = side_node.get_node_or_null("PortraitFrame")
	if portrait_mesh:
		portrait_mesh.visible = active_portrait
		portrait_mesh.position = Vector3(port_x, 7.8, 0.035)
		if active_portrait:
			var pmat := StandardMaterial3D.new()
			pmat.roughness = 0.5
			pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			pmat.albedo_texture = p_portrait
			pmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			portrait_mesh.material_override = pmat
	if portrait_frame:
		portrait_frame.visible = active_portrait and not p_portrait_on_left
		portrait_frame.position = Vector3(port_x, 7.8, 0.021)
	# Banner
	var banner_mesh: MeshInstance3D = side_node.get_node_or_null("Banner")
	if banner_mesh:
		banner_mesh.visible = p_show_banner and not hide_text
		banner_mesh.position.x = content_x
		banner_mesh.scale.x = banner_scale_x
		if banner_mesh.visible:
			var bmat := StandardMaterial3D.new()
			bmat.roughness = 0.4
			bmat.albedo_color = p_banner_color
			banner_mesh.material_override = bmat

	# Labels
	var labels_node: Node3D = side_node.get_node_or_null("Labels")
	if labels_node:
		labels_node.visible = not hide_text

	var hl: Label3D = side_node.get_node_or_null("Labels/Headline")
	if hl:
		hl.text = p_headline_text
		hl.modulate = p_headline_color
		hl.position.x = content_x
		if p_portrait_on_left:
			hl.font_size = 64
			hl.pixel_size = 0.008
		else:
			hl.font_size = 40 if active_portrait else 54
			hl.pixel_size = 0.0065 if active_portrait else 0.007

	var tag: Label3D = side_node.get_node_or_null("Labels/Tagline")
	if tag:
		tag.text = p_tagline_text
		tag.modulate = p_tagline_color
		tag.position.x = content_x
		if p_portrait_on_left:
			tag.font_size = 38
			tag.pixel_size = 0.0065
	var cnt: Label3D = side_node.get_node_or_null("Labels/Contact")

	if cnt:
		cnt.text = p_contact_text
		cnt.modulate = p_contact_color
		cnt.position.x = content_x
		if p_portrait_on_left:
			cnt.font_size = 44
			cnt.pixel_size = 0.0055
		else:
			cnt.font_size = 66 if active_portrait else 72
			cnt.pixel_size = 0.0065 if active_portrait else 0.007

	var disc: Label3D = side_node.get_node_or_null("Labels/Disclaimer")
	if disc:
		disc.text = p_disclaimer_text
		disc.modulate = p_disclaimer_color
		disc.position.x = content_x
		disc.font_size = 24 if active_portrait else 26
		disc.pixel_size = 0.0058 if active_portrait else 0.0065


func _update_lights() -> void:
	var lamp_mat := StandardMaterial3D.new()
	if lights_enabled:
		lamp_mat.albedo_color = Color(1.0, 0.98, 0.9)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color(1.0, 0.96, 0.85)
		lamp_mat.emission_energy_multiplier = 2.5
	else:
		lamp_mat.albedo_color = Color(0.25, 0.25, 0.25)
		lamp_mat.emission_enabled = false

	for side_name in ["FrontSide", "BackSide"]:
		var side: Node3D = get_node_or_null(side_name)
		if not side:
			continue
		var lights_parent: Node3D = side.get_node_or_null("Catwalk/Lights")
		if not lights_parent:
			continue
		for lamp in lights_parent.get_children():
			var bulb: MeshInstance3D = lamp.get_node_or_null("Bulb")
			if bulb:
				bulb.material_override = lamp_mat
			var spot: SpotLight3D = lamp.get_node_or_null("SpotLight3D")
			if spot:
				spot.visible = lights_enabled
