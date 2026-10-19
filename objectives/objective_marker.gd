class_name ObjectiveMarker
extends Node3D

@export var arrive_radius: float = 2.5:
	set(value):
		arrive_radius = value
		_update_ground_ring_radius()

@export var store_name: String = "":
	set(value):
		store_name = value
		if label:
			label.text = value
			label.visible = not value.is_empty()

@export var marker_color: Color = Color(0.2, 0.95, 0.4, 1.0)
@export var base_cone_height: float = 6.0
@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 3.0
@export var rotation_speed: float = 1.8

var cone_pivot: Node3D = null
var cone_mesh: MeshInstance3D = null
var ground_ring: MeshInstance3D = null
var label: Label3D = null

var cone_material: StandardMaterial3D = null
var ring_material: StandardMaterial3D = null
var pop_particles: CPUParticles3D = null

var _time: float = 0.0
var _is_completing: bool = false
var _built: bool = false


func _ready() -> void:
	if not _built:
		_build()


func _build() -> void:
	_built = true

	# 1. Downward-pointing cone (apex pointing down, 6m above entrance)
	cone_pivot = Node3D.new()
	cone_pivot.name = "ConePivot"
	cone_pivot.position = Vector3(0.0, base_cone_height, 0.0)
	add_child(cone_pivot)

	cone_mesh = MeshInstance3D.new()
	cone_mesh.name = "ConeMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.55
	cyl.height = 1.2
	cone_mesh.mesh = cyl
	cone_mesh.rotation.x = PI
	cone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	cone_material = StandardMaterial3D.new()
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.albedo_color = marker_color
	cone_material.emission_enabled = true
	cone_material.emission = marker_color
	cone_mesh.material_override = cone_material
	cone_pivot.add_child(cone_mesh)

	# 2. Translucent ground ring at entrance indicating arrival radius
	ground_ring = MeshInstance3D.new()
	ground_ring.name = "GroundRing"
	var torus := TorusMesh.new()
	torus.outer_radius = arrive_radius
	torus.inner_radius = maxf(0.1, arrive_radius - 0.12)
	ground_ring.mesh = torus
	ground_ring.position = Vector3(0.0, 0.05, 0.0)
	ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.55)
	ring_material.emission_enabled = true
	ring_material.emission = marker_color
	ground_ring.material_override = ring_material
	add_child(ground_ring)

	# 3. Billboarded store name label
	label = Label3D.new()
	label.name = "StoreLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = store_name
	label.visible = not store_name.is_empty()
	label.position = Vector3(0.0, base_cone_height + 1.1, 0.0)
	label.font_size = 40
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.modulate = Color(0.9, 1.0, 0.9, 1.0)
	label.no_depth_test = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _update_ground_ring_radius() -> void:
	if ground_ring and ground_ring.mesh is TorusMesh:
		var torus := ground_ring.mesh as TorusMesh
		torus.outer_radius = arrive_radius
		torus.inner_radius = maxf(0.1, arrive_radius - 0.12)


func _process(delta: float) -> void:
	if _is_completing:
		return
	_time += delta
	if cone_pivot:
		cone_pivot.position.y = base_cone_height + sin(_time * bob_speed) * bob_amplitude
		cone_pivot.rotate_y(delta * rotation_speed)
	if label:
		var current_cone_y := cone_pivot.position.y if cone_pivot else base_cone_height
		label.position.y = current_cone_y + 1.1


func complete_and_free(duration: float = 0.4) -> void:
	if _is_completing:
		return
	_is_completing = true
	pop_particles = _spawn_pop_particles()
	var tween := create_tween()
	if not tween:
		queue_free()
		return
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.4, duration).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	if cone_material:
		cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var target_col := cone_material.albedo_color
		target_col.a = 0.0
		tween.tween_property(cone_material, "albedo_color", target_col, duration)
	if ring_material:
		var target_ring_col := ring_material.albedo_color
		target_ring_col.a = 0.0
		tween.tween_property(ring_material, "albedo_color", target_ring_col, duration)
	if label:
		var target_lbl_mod := label.modulate
		target_lbl_mod.a = 0.0
		tween.tween_property(label, "modulate", target_lbl_mod, duration)
		var target_outline := label.outline_modulate
		target_outline.a = 0.0
		tween.tween_property(label, "outline_modulate", target_outline, duration)
	tween.chain().tween_callback(queue_free)


func _spawn_pop_particles() -> CPUParticles3D:
	var pop := CPUParticles3D.new()
	pop.name = "CompleteParticles"
	pop.emitting = false
	pop.one_shot = true
	pop.explosiveness = 0.95
	pop.amount = 16
	pop.lifetime = 0.5
	pop.direction = Vector3(0.0, 1.0, 0.0)
	pop.spread = 75.0
	pop.initial_velocity_min = 2.5
	pop.initial_velocity_max = 4.5
	pop.gravity = Vector3(0.0, -9.8, 0.0)

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	pop.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = marker_color
	mat.emission_enabled = true
	mat.emission = marker_color
	pop.material_override = mat
	pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var p := get_parent()
	if p:
		p.add_child(pop)
		pop.global_position = global_position + Vector3(0.0, 0.5, 0.0)
	else:
		add_child(pop)
		pop.position = Vector3(0.0, 0.5, 0.0)

	pop.emitting = true
	if is_inside_tree():
		get_tree().create_timer(0.7).timeout.connect(pop.queue_free)
	return pop
