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

static var _blend_tree1: PackedScene = null
static var _blend_tree2: PackedScene = null
static var _procedural_cache: Dictionary = {}
static var _live_oak_materials: Array[ShaderMaterial] = []
static var _wind_connected: bool = false

@onready var _visuals: Node3D = $Visuals
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var _rustle_tween: Tween


func _enter_tree() -> void:
	_apply_tree_type()


func _ready() -> void:
	_apply_tree_type()
	if not Engine.is_editor_hint():
		_ensure_wind_connected()


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

	var expected_name := _get_variant_name(tree_type)
	var active_node: Node3D = null

	for child in visuals.get_children():
		if child is Node3D:
			if child.name == expected_name:
				active_node = child
			else:
				if Engine.is_editor_hint():
					child.free()
				else:
					if not child.is_queued_for_deletion():
						visuals.remove_child(child)
						child.queue_free()
	if not active_node:
		active_node = _build_variant_node(tree_type)
		if active_node:
			visuals.add_child(active_node)

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


static func _get_variant_name(p_type: TreeType) -> String:
	match p_type:
		TreeType.STANDARD:
			return "Standard"
		TreeType.TALL:
			return "Tall"
		TreeType.BROAD:
			return "Broad"
		TreeType.CLUSTERED:
			return "Clustered"
		TreeType.COMPACT:
			return "Compact"
		TreeType.PALM:
			return "Palm"
		TreeType.LIVE_OAK:
			return "LiveOak"
	return "Standard"


static func _build_variant_node(p_type: TreeType) -> Node3D:
	match p_type:
		TreeType.PALM:
			if not _blend_tree2:
				_blend_tree2 = load("res://props/tree2.blend") as PackedScene
			var node := _blend_tree2.instantiate() as Node3D
			node.name = "Palm"
			_set_visibility_range_recursive(node, 260.0)
			return node

		TreeType.LIVE_OAK:
			if not _blend_tree1:
				_blend_tree1 = load("res://props/tree1.blend") as PackedScene
			var node := _blend_tree1.instantiate() as Node3D
			node.name = "LiveOak"
			_set_visibility_range_recursive(node, 260.0)
			return node

		_:
			return _build_procedural_variant_node(p_type)


static func _set_visibility_range_recursive(node: Node, dist: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = dist
	for child in node.get_children():
		_set_visibility_range_recursive(child, dist)


static func _ensure_procedural_cache() -> void:
	if not _procedural_cache.is_empty():
		return

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.18, 1.0)
	trunk_mat.roughness = 0.95

	var mat_std := StandardMaterial3D.new()
	mat_std.albedo_color = Color(0.22, 0.42, 0.18, 1.0)
	mat_std.roughness = 0.9

	var mat_tall := StandardMaterial3D.new()
	mat_tall.albedo_color = Color(0.18, 0.38, 0.16, 1.0)
	mat_tall.roughness = 0.9

	var mat_broad := StandardMaterial3D.new()
	mat_broad.albedo_color = Color(0.25, 0.44, 0.19, 1.0)
	mat_broad.roughness = 0.9

	var mat_clustered := StandardMaterial3D.new()
	mat_clustered.albedo_color = Color(0.2, 0.4, 0.17, 1.0)
	mat_clustered.roughness = 0.9

	var mat_compact := StandardMaterial3D.new()
	mat_compact.albedo_color = Color(0.24, 0.45, 0.21, 1.0)
	mat_compact.roughness = 0.9

	var m_trunk_std := CylinderMesh.new()
	m_trunk_std.material = trunk_mat
	m_trunk_std.radial_segments = 10
	m_trunk_std.rings = 1
	m_trunk_std.top_radius = 0.25
	m_trunk_std.bottom_radius = 0.3
	m_trunk_std.height = 2.0

	var m_foliage_std := SphereMesh.new()
	m_foliage_std.material = mat_std
	m_foliage_std.radial_segments = 16
	m_foliage_std.rings = 8
	m_foliage_std.radius = 1.4
	m_foliage_std.height = 2.5

	var m_trunk_tall := CylinderMesh.new()
	m_trunk_tall.material = trunk_mat
	m_trunk_tall.radial_segments = 10
	m_trunk_tall.rings = 1
	m_trunk_tall.top_radius = 0.22
	m_trunk_tall.bottom_radius = 0.28
	m_trunk_tall.height = 2.6

	var m_foliage_tall := SphereMesh.new()
	m_foliage_tall.material = mat_tall
	m_foliage_tall.radial_segments = 16
	m_foliage_tall.rings = 8
	m_foliage_tall.radius = 1.25
	m_foliage_tall.height = 3.2

	var m_trunk_broad := CylinderMesh.new()
	m_trunk_broad.material = trunk_mat
	m_trunk_broad.radial_segments = 10
	m_trunk_broad.rings = 1
	m_trunk_broad.top_radius = 0.28
	m_trunk_broad.bottom_radius = 0.35
	m_trunk_broad.height = 1.8

	var m_foliage_broad := SphereMesh.new()
	m_foliage_broad.material = mat_broad
	m_foliage_broad.radial_segments = 16
	m_foliage_broad.rings = 8
	m_foliage_broad.radius = 1.8
	m_foliage_broad.height = 2.2

	var m_trunk_clustered := CylinderMesh.new()
	m_trunk_clustered.material = trunk_mat
	m_trunk_clustered.radial_segments = 10
	m_trunk_clustered.rings = 1
	m_trunk_clustered.top_radius = 0.25
	m_trunk_clustered.bottom_radius = 0.32
	m_trunk_clustered.height = 2.0

	var m_foliage_clustered_main := SphereMesh.new()
	m_foliage_clustered_main.material = mat_clustered
	m_foliage_clustered_main.radial_segments = 16
	m_foliage_clustered_main.rings = 8
	m_foliage_clustered_main.radius = 1.3
	m_foliage_clustered_main.height = 2.3

	var m_foliage_clustered_side := SphereMesh.new()
	m_foliage_clustered_side.material = mat_clustered
	m_foliage_clustered_side.radial_segments = 16
	m_foliage_clustered_side.rings = 8
	m_foliage_clustered_side.radius = 1.05
	m_foliage_clustered_side.height = 1.9
	var m_trunk_compact := CylinderMesh.new()
	m_trunk_compact.material = trunk_mat
	m_trunk_compact.radial_segments = 10
	m_trunk_compact.rings = 1
	m_trunk_compact.top_radius = 0.2
	m_trunk_compact.bottom_radius = 0.25
	m_trunk_compact.height = 1.6

	var m_foliage_compact := SphereMesh.new()
	m_foliage_compact.material = mat_compact
	m_foliage_compact.radial_segments = 16
	m_foliage_compact.rings = 8
	m_foliage_compact.radius = 1.15
	m_foliage_compact.height = 2.0
	_procedural_cache = {
		"trunk_std": m_trunk_std,
		"foliage_std": m_foliage_std,
		"trunk_tall": m_trunk_tall,
		"foliage_tall": m_foliage_tall,
		"trunk_broad": m_trunk_broad,
		"foliage_broad": m_foliage_broad,
		"trunk_clustered": m_trunk_clustered,
		"foliage_clustered_main": m_foliage_clustered_main,
		"foliage_clustered_side": m_foliage_clustered_side,
		"trunk_compact": m_trunk_compact,
		"foliage_compact": m_foliage_compact,
	}


static func _create_mesh_instance(mesh: Mesh, node_name: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.visibility_range_end = 260.0
	return mi


static func _build_procedural_variant_node(p_type: TreeType) -> Node3D:
	_ensure_procedural_cache()
	var root := Node3D.new()
	match p_type:
		TreeType.STANDARD:
			root.name = "Standard"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_std"], "Trunk", Vector3(0.0, 1.0, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_std"], "Foliage", Vector3(0.0, 2.8, 0.0)
				)
			)
		TreeType.TALL:
			root.name = "Tall"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_tall"], "Trunk", Vector3(0.0, 1.3, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_tall"], "Foliage", Vector3(0.0, 3.6, 0.0)
				)
			)
		TreeType.BROAD:
			root.name = "Broad"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_broad"], "Trunk", Vector3(0.0, 0.9, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_broad"], "Foliage", Vector3(0.0, 2.6, 0.0)
				)
			)
		TreeType.CLUSTERED:
			root.name = "Clustered"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_clustered"], "Trunk", Vector3(0.0, 1.0, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_clustered_main"],
					"MainFoliage",
					Vector3(0.0, 2.8, -0.2)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_clustered_side"],
					"SideFoliage",
					Vector3(0.5, 2.5, 0.3)
				)
			)
		TreeType.COMPACT:
			root.name = "Compact"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_compact"], "Trunk", Vector3(0.0, 0.8, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_compact"], "Foliage", Vector3(0.0, 2.3, 0.0)
				)
			)
		_:
			root.name = "Standard"
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["trunk_std"], "Trunk", Vector3(0.0, 1.0, 0.0)
				)
			)
			root.add_child(
				_create_mesh_instance(
					_procedural_cache["foliage_std"], "Foliage", Vector3(0.0, 2.8, 0.0)
				)
			)
	return root


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
