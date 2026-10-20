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


func is_completed() -> bool:
	return _is_completed


func start_warmup(tree: SceneTree, props: Node3D, traffic_manager: Node) -> void:
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
	# Frame 1: major Props building groups start hidden so WebGL2 compiles base
	# shaders (terrain, road, mats) without a huge Frame 1 spike.
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

	if props and is_instance_valid(props) and props.has_meta(&"authored_visibilities"):
		props.remove_meta(&"authored_visibilities")
	_is_warming_up = false
	_is_completed = true
	completed.emit()


func _report_progress(pct: int, text: String) -> void:
	progress_reported.emit(pct, text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			(
				"if (window.godotProgress) { window.godotProgress(%d, %s); }"
				% [pct, JSON.stringify(text)]
			)
		)
