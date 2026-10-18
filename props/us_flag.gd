@tool
class_name USFlag
extends StaticBody3D

enum FlagSize {
	STANDARD,
	LARGE,
	GIANT,
}

const SIZE_CONFIG := {
	FlagSize.STANDARD:
	{
		"node_name": "Standard",
		"flag_half_width": 1.235,
		"flag_y": 7.7,
		"rope_offset": 0.075,
		"rope_y": 4.88,
	},
	FlagSize.LARGE:
	{
		"node_name": "Large",
		"flag_half_width": 1.805,
		"flag_y": 10.95,
		"rope_offset": 0.11,
		"rope_y": 6.7,
	},
	FlagSize.GIANT:
	{
		"node_name": "Giant",
		"flag_half_width": 2.85,
		"flag_y": 15.55,
		"rope_offset": 0.16,
		"rope_y": 9.6,
	},
}

@export var flag_size: FlagSize = FlagSize.STANDARD:
	set(value):
		flag_size = value
		_apply_flag_size()

## Responsiveness of the flag swivel to changes in wind direction.
@export var response_speed: float = 3.5

@onready var _visuals: Node3D = $Visuals
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _current_angle: float = 0.0
var _initialized_angle: bool = false
var _phase_offset: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_phase_offset = fmod(absf(global_position.x * 1.37 + global_position.z * 2.83), TAU)
	_apply_flag_size()
	_update_wind_orientation(0.0, true)
	if not Engine.is_editor_hint():
		var visuals := _visuals if _visuals else get_node_or_null("Visuals")
		if visuals:
			var config: Dictionary = SIZE_CONFIG.get(flag_size, SIZE_CONFIG[FlagSize.STANDARD])
			var active: Node = visuals.get_node_or_null(config["node_name"])
			if active != null:
				for child in visuals.get_children():
					if child != active:
						child.queue_free()


func _process(delta: float) -> void:
	_time += delta
	_update_wind_orientation(delta, false)


func set_flag_size(p_size: FlagSize) -> void:
	flag_size = p_size


func _apply_flag_size() -> void:
	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	for child in visuals.get_children():
		if child is Node3D:
			child.visible = false

	var active_node: Node3D = null
	match flag_size:
		FlagSize.STANDARD:
			active_node = visuals.get_node_or_null("Standard")
		FlagSize.LARGE:
			active_node = visuals.get_node_or_null("Large")
		FlagSize.GIANT:
			active_node = visuals.get_node_or_null("Giant")

	if active_node:
		active_node.visible = true

	_update_collision()
	_update_wind_orientation(0.0, true)


func _update_wind_orientation(delta: float, snap: bool = false) -> void:
	if not is_inside_tree():
		return
	var visuals := _visuals if _visuals else get_node_or_null("Visuals")
	if not visuals:
		return

	var config: Dictionary = SIZE_CONFIG.get(flag_size, SIZE_CONFIG[FlagSize.STANDARD])
	var active_node := visuals.get_node_or_null(config["node_name"]) as Node3D
	if not active_node:
		return

	var flag_mesh := active_node.get_node_or_null("Flag") as MeshInstance3D
	var rope_mesh := active_node.get_node_or_null("Rope") as MeshInstance3D

	# Query global wind direction from GameState
	var wind_dir: Vector3 = GameState.wind_direction
	var wind_spd: float = GameState.wind_speed

	# Convert world-space wind direction into flagpole local space
	var local_wind := global_basis.inverse() * wind_dir
	local_wind.y = 0.0
	if local_wind.is_zero_approx():
		local_wind = Vector3.RIGHT

	local_wind = local_wind.normalized()

	# In local space, flag mesh extends along +X when rotation = 0.
	# Positive Y rotation in Godot maps +X towards -Z.
	var target_angle := atan2(-local_wind.z, local_wind.x)

	# Add subtle unique micro-turbulence per flagpole position
	var local_flutter := sin(_time * 2.2 + _phase_offset) * 0.025
	target_angle += local_flutter

	if snap or not _initialized_angle:
		_current_angle = target_angle
		_initialized_angle = true
	else:
		_current_angle = lerp_angle(
			_current_angle, target_angle, clampf(delta * response_speed, 0.0, 1.0)
		)

	var rot_basis := Basis(Vector3.UP, _current_angle)

	# Flag swivel around pole (0, 0, 0)
	if flag_mesh:
		var half_w: float = config["flag_half_width"]
		var fy: float = config["flag_y"]
		flag_mesh.transform = Transform3D(rot_basis, rot_basis * Vector3(half_w, fy, 0.0))

		# Update shader uniforms with global wind
		var mat := flag_mesh.get_active_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("wind_direction", Vector2(wind_dir.x, wind_dir.z))
			mat.set_shader_parameter("wind_strength", wind_spd)

	# Rope halyard swivel with flag
	if rope_mesh:
		var roff: float = config["rope_offset"]
		var ry: float = config["rope_y"]
		rope_mesh.transform = Transform3D(rot_basis, rot_basis * Vector3(roff, ry, 0.0))


func _update_collision() -> void:
	var col := (
		_collision_shape
		if _collision_shape
		else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	)
	if not col:
		return

	var radius: float = 0.20
	var height: float = 8.0
	var pos_y: float = 4.0

	match flag_size:
		FlagSize.STANDARD:
			radius = 0.20
			height = 8.0
			pos_y = 4.0
		FlagSize.LARGE:
			radius = 0.26
			height = 11.5
			pos_y = 5.75
		FlagSize.GIANT:
			radius = 0.38
			height = 16.5
			pos_y = 8.25

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = Vector3(0.0, pos_y, 0.0)
