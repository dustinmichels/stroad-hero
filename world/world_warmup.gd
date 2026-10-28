class_name WorldWarmup
extends RefCounted

signal progress_reported(percent: int, message: String)
signal completed

const STAGGERED_WARMUP_STEPS: Array[Dictionary] = [
	{
		"names": ["Walgroins", "WalgroinsShoppingCarts"],
		"pct": 87,
		"label": "Warming up Walgroins...",
	},
	{
		"names": ["TacoHell"],
		"pct": 89,
		"label": "Warming up Taco Hell...",
	},
	{
		"names": ["BoogerKingSite"],
		"pct": 91,
		"label": "Warming up Booger King...",
	},
	{
		"names": ["StripMall"],
		"pct": 93,
		"label": "Warming up Strip Mall...",
	},
	{
		"names": ["CrampedInn"],
		"pct": 95,
		"label": "Warming up Cramped Inn...",
	},
	{
		"names": ["SmellGasStation"],
		"pct": 97,
		"label": "Warming up Gas Station...",
	},
	{
		"names": ["Streetlights", "Trees", "Flags", "OverheadRoadSign", "FireHydrant"],
		"pct": 98,
		"label": "Warming up street props...",
	},
]

var _is_completed: bool = false
var _is_warming_up: bool = false
var _warmed_car: Car = null
var _warmed_env_controller: EnvironmentController = null
var _fallback_warmup_node: Node3D = null


func is_completed() -> bool:
	return _is_completed


func start_warmup(
	tree: SceneTree,
	props: Node3D,
	traffic_manager: Node,
	environment_controller: EnvironmentController = null
) -> void:
	if _is_completed:
		completed.emit()
		return
	if _is_warming_up:
		return
	_is_warming_up = true
	var authored_visibilities: Dictionary = {}
	if props:
		if props.has_meta(&"authored_visibilities"):
			authored_visibilities = props.get_meta(&"authored_visibilities")
		else:
			for child in props.get_children():
				if child is Node3D:
					authored_visibilities[child] = child.visible
			props.set_meta(&"authored_visibilities", authored_visibilities)
		for child in props.get_children():
			if child is Node3D:
				child.visible = false

	_report_progress(85, "Warming up shaders...")
	# Frame 1: major Props building groups start hidden so the base shaders
	# (terrain, road, mats) compile without a huge Frame 1 spike.
	await tree.process_frame
	if not tree:
		return

	if props:
		for step in STAGGERED_WARMUP_STEPS:
			for node_name in step["names"]:
				var node := props.get_node_or_null(node_name) as Node3D
				if node and authored_visibilities.get(node, true):
					node.visible = true
			_report_progress(step["pct"], step["label"])
			await tree.process_frame
			if not tree:
				return

		# Restore authored visibility for any remaining Props children
		for child in props.get_children():
			if child is Node3D:
				if authored_visibilities.has(child):
					child.visible = authored_visibilities[child]
		await tree.process_frame
		if not tree:
			return
	else:
		await tree.process_frame
		if not tree:
			return

	if (
		traffic_manager
		and "is_initial_traffic_ready" in traffic_manager
		and not traffic_manager.is_initial_traffic_ready
	):
		_report_progress(99, "Spawning initial traffic...")
		await traffic_manager.initial_traffic_ready

	_report_progress(99, "Warming up lighting...")
	_warmup_night_lighting(tree, props, traffic_manager, environment_controller)
	await tree.process_frame
	if not tree:
		return
	_restore_night_lighting()
	if props and is_instance_valid(props) and props.has_meta(&"authored_visibilities"):
		props.remove_meta(&"authored_visibilities")
	_is_warming_up = false
	_is_completed = true
	completed.emit()


func _report_progress(pct: int, text: String) -> void:
	progress_reported.emit(pct, text)


func _find_warmup_car(traffic_manager: Node) -> Car:
	if not traffic_manager:
		return null
	var candidate_car: Car = null
	var min_dist_sq := INF

	var all_cars: Array[Car] = []
	if "lanes" in traffic_manager:
		for lane in traffic_manager.lanes:
			if "cars" in lane:
				for c in lane.cars:
					if is_instance_valid(c) and c is Car:
						all_cars.append(c)
	if "lot_cars" in traffic_manager:
		for c in traffic_manager.lot_cars:
			if is_instance_valid(c) and c is Car:
				all_cars.append(c)

	for c in all_cars:
		if c.is_inside_tree():
			var dist_sq := c.global_position.length_squared()
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				candidate_car = c
	return candidate_car


func _warmup_night_lighting(
	tree: SceneTree,
	props: Node3D,
	traffic_manager: Node,
	environment_controller: EnvironmentController
) -> void:
	var ec := environment_controller
	if ec == null and props and is_instance_valid(props) and props.get_parent():
		ec = props.get_parent().get_node_or_null("EnvironmentController") as EnvironmentController
	if ec:
		_warmed_env_controller = ec
		ec.warmup_streetlights(true, true)

	var candidate_car := _find_warmup_car(traffic_manager)
	if candidate_car:
		_warmed_car = candidate_car
		candidate_car.set_headlights_override(true, true)
	elif tree and tree.current_scene:
		var fallback := Node3D.new()
		fallback.name = "LightingWarmupFallback"
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.material_override = Car.get_headlight_mat_on()
		fallback.add_child(mesh_inst)
		var spot := SpotLight3D.new()
		spot.visible = true
		fallback.add_child(spot)
		tree.current_scene.add_child(fallback)
		_fallback_warmup_node = fallback


func _restore_night_lighting() -> void:
	if _warmed_env_controller and is_instance_valid(_warmed_env_controller):
		_warmed_env_controller.warmup_streetlights(false, true)
		_warmed_env_controller = null

	if _warmed_car and is_instance_valid(_warmed_car):
		_warmed_car.restore_headlamps()
		_warmed_car = null

	if _fallback_warmup_node and is_instance_valid(_fallback_warmup_node):
		_fallback_warmup_node.queue_free()
		_fallback_warmup_node = null
