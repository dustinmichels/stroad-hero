class_name FroggerGrid
extends MultiMeshInstance3D
## Frogger-mode hop grid: one translucent tile per cell, draped on the ground below it (road, curb,
## sidewalk). Cells are `cell_size` squares aligned to the world origin.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 line_color : source_color = vec4(1.0, 0.92, 0.35, 0.45);
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 0.06);
uniform float line_width = 0.025;
uniform float fade = 0.0;

varying float checker;

void vertex() {
	checker = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 edge_distance = min(UV, 1.0 - UV);
	float line = 1.0 - step(line_width, min(edge_distance.x, edge_distance.y));
	vec4 fill = vec4(fill_color.rgb, fill_color.a * (0.4 + 0.6 * checker));
	vec4 color = mix(fill, line_color, line);
	ALBEDO = color.rgb;
	ALPHA = color.a * fade;
}
"""
## Raise tiles off the ground to avoid z-fighting.
const SURFACE_LIFT := 0.03
## Probe from below awnings and bus-stop roofs down through the ground.
const RAY_TOP := 1.5
const RAY_BOTTOM := -2.0
## Static world geometry; cars are areas on layer 2 and are ignored.
const GROUND_LAYER := 1
const FADE_SECONDS := 0.25

var _material := ShaderMaterial.new()
var _fade_tween: Tween


static func cell_of(world_position: Vector3, cell_size: float) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))


static func cell_center(cell: Vector2i, cell_size: float) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _init() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter(&"fade", 0.0)
	material_override = _material
	var tile := PlaneMesh.new()
	tile.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = tile


## Places one tile per cell on the ground found beneath it. Cells without ground, or whose ground is
## above `max_ground_height` (benches, planters), get no tile. Call during physics frames.
func build(
	cells: Array[Vector2i], cell_size: float, max_ground_height: float, exclude: Array[RID]
) -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = GROUND_LAYER
	query.exclude = exclude
	var tile_basis := Basis.from_scale(Vector3(cell_size, 1.0, cell_size))
	var transforms: Array[Transform3D] = []
	var checkers := PackedFloat32Array()
	for cell in cells:
		var center := cell_center(cell, cell_size)
		query.from = Vector3(center.x, RAY_TOP, center.y)
		query.to = Vector3(center.x, RAY_BOTTOM, center.y)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var ground_y: float = hit.position.y
		if ground_y > max_ground_height:
			continue
		transforms.append(
			Transform3D(tile_basis, Vector3(center.x, ground_y + SURFACE_LIFT, center.y))
		)
		checkers.append(float((cell.x + cell.y) & 1))
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, Color(checkers[i], 0.0, 0.0, 0.0))


func fade_in() -> void:
	visible = true
	_fade_to(1.0)


func fade_out() -> void:
	_fade_to(0.0).tween_callback(hide)


func _fade_to(value: float) -> Tween:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_material, "shader_parameter/fade", value, FADE_SECONDS)
	return _fade_tween
