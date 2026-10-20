@tool
class_name StreetTree
extends StaticBody3D

enum TreeType {
	STANDARD,
	TALL,
	BROAD,
	CLUSTERED,
	COMPACT,
	PALM,
	LIVE_OAK,
}

@export var tree_type: TreeType = TreeType.STANDARD:
	set(value):
		tree_type = value
		_apply_tree_type()

const FOLIAGE_SHADER: Shader = preload("res://shaders/foliage_wind.gdshader")

static var _live_oak_materials: Array[ShaderMaterial] = []
static var _wind_connected: bool = false

@onready var _visuals: Node3D = $Visuals
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var _rustle_tween: Tween


func _ready() -> void:
	_apply_tree_type()
	if not Engine.is_editor_hint():
		_ensure_wind_connected()
		var visuals := _visuals if _visuals else get_node_or_null("Visuals")
		if visuals:
			var active: Node3D = null
			for child in visuals.get_children():
				if child is Node3D and child.visible:
					active = child
					break
			if active != null:
				for child in visuals.get_children():
					if child != active:
						child.queue_free()


func set_tree_type(p_type: TreeType) -> void:
	tree_type = p_type


func rustle(impact_direction: Vector3) -> void:
	if impact_direction.is_zero_approx():
		return
	if _rustle_tween and _rustle_tween.is_running():
		return

	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	var foliage: Array[Node3D] = []
	for variant in visuals.get_children():
		if not (variant is Node3D) or not variant.visible:
			continue
		for child in variant.get_children():
			if child is Node3D and "Foliage" in child.name:
				foliage.append(child)
	if foliage.is_empty():
		return

	var local_direction := global_basis.inverse() * impact_direction.normalized()
	var tilt := Vector3(local_direction.z, 0.0, -local_direction.x) * deg_to_rad(6.0)
	var resting_rotations: Array[Vector3] = []
	for leaves in foliage:
		resting_rotations.append(leaves.rotation)

	_rustle_tween = create_tween()
	(
		_rustle_tween
		. tween_property(foliage[0], "rotation", resting_rotations[0] + tilt, 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	for index in range(1, foliage.size()):
		(
			_rustle_tween
			. parallel()
			. tween_property(foliage[index], "rotation", resting_rotations[index] + tilt, 0.08)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	(
		_rustle_tween
		. chain()
		. tween_property(foliage[0], "rotation", resting_rotations[0], 0.35)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	for index in range(1, foliage.size()):
		(
			_rustle_tween
			. parallel()
			. tween_property(foliage[index], "rotation", resting_rotations[index], 0.35)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)


func _apply_tree_type() -> void:
	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	for child in visuals.get_children():
		if child is Node3D:
			child.visible = false

	var active_node: Node3D = null
	match tree_type:
		TreeType.STANDARD:
			active_node = visuals.get_node_or_null("Standard")
		TreeType.TALL:
			active_node = visuals.get_node_or_null("Tall")
		TreeType.BROAD:
			active_node = visuals.get_node_or_null("Broad")
		TreeType.CLUSTERED:
			active_node = visuals.get_node_or_null("Clustered")
		TreeType.COMPACT:
			active_node = visuals.get_node_or_null("Compact")
		TreeType.PALM:
			active_node = visuals.get_node_or_null("Palm")
		TreeType.LIVE_OAK:
			active_node = visuals.get_node_or_null("LiveOak")
	var height_scale := 1.0
	if tree_type == TreeType.BROAD:
		height_scale = 1.15
	elif tree_type == TreeType.COMPACT:
		height_scale = 1.25

	if active_node:
		active_node.scale.y = height_scale
		active_node.visible = true
		if tree_type == TreeType.LIVE_OAK:
			_apply_live_oak_foliage(active_node)
	_update_dimensions()


static func _get_or_create_live_oak_materials() -> Array[ShaderMaterial]:
	if not _live_oak_materials.is_empty():
		return _live_oak_materials

	var colors: Array[Color] = [
		Color(0.2601, 0.41, 0.2478, 1.0),
		Color(0.3656, 0.542, 0.3035, 1.0),
		Color(0.5169, 0.6652, 0.3575, 1.0),
	]
	var wind_dir := GameState.wind_direction_2d if GameState else Vector2(0.978, 0.208)
	var wind_spd := GameState.wind_speed if GameState else 1.0
	for col in colors:
		var mat := ShaderMaterial.new()
		mat.shader = FOLIAGE_SHADER
		mat.set_shader_parameter("albedo_color", col)
		mat.set_shader_parameter("roughness", 0.85)
		mat.set_shader_parameter("specular", 0.2)
		mat.set_shader_parameter("wind_direction", wind_dir)
		mat.set_shader_parameter("wind_strength", wind_spd)
		_live_oak_materials.append(mat)
	return _live_oak_materials


static func _ensure_wind_connected() -> void:
	if GameState and GameState.instance:
		if (
			not _wind_connected
			or not GameState.instance.wind_changed.is_connected(_on_global_wind_changed)
		):
			GameState.instance.wind_changed.connect(_on_global_wind_changed)
			_wind_connected = true
		_on_global_wind_changed(GameState.wind_direction, GameState.wind_speed)


static func _on_global_wind_changed(direction: Vector3, speed: float) -> void:
	if _live_oak_materials.is_empty():
		return
	var dir_2d := Vector2(direction.x, direction.z)
	for mat in _live_oak_materials:
		mat.set_shader_parameter("wind_direction", dir_2d)
		mat.set_shader_parameter("wind_strength", speed)


func _apply_live_oak_foliage(active_node: Node3D) -> void:
	var foliage := active_node.get_node_or_null("Foliage") as MeshInstance3D
	if not foliage or not foliage.mesh:
		return
	var mats := _get_or_create_live_oak_materials()
	for i in range(mini(mats.size(), foliage.mesh.get_surface_count())):
		if foliage.get_surface_override_material(i) != mats[i]:
			foliage.set_surface_override_material(i, mats[i])


func _update_dimensions() -> void:
	var col := (
		_collision_shape
		if _collision_shape
		else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	)
	if not col:
		return

	var radius: float = 0.35
	var height: float = 2.0
	var pos_y: float = 1.0

	match tree_type:
		TreeType.STANDARD:
			radius = 0.35
			height = 2.0
			pos_y = 1.0
		TreeType.TALL:
			radius = 0.32
			height = 2.6
			pos_y = 1.3
		TreeType.BROAD:
			radius = 0.38
			height = 2.07
			pos_y = 1.035
		TreeType.CLUSTERED:
			radius = 0.35
			height = 2.0
			pos_y = 1.0
		TreeType.COMPACT:
			radius = 0.30
			height = 2.0
			pos_y = 1.0
		TreeType.PALM:
			radius = 0.28
			height = 7.15
			pos_y = 3.575
		TreeType.LIVE_OAK:
			radius = 0.50
			height = 2.2
			pos_y = 1.1

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = Vector3(0.0, pos_y, 0.0)
