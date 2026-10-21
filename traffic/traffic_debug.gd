class_name TrafficDebug
extends Node3D

var traffic_manager: TrafficManager = null
var lot: ParkingLot = null

var _spot_discs: Dictionary[int, MeshInstance3D] = {}
var _spot_labels: Dictionary[int, Label3D] = {}
var _car_labels: Dictionary[int, Label3D] = {}
var _mat_free: StandardMaterial3D
var _mat_reserved: StandardMaterial3D
var _mat_occupied: StandardMaterial3D
var _disc_mesh: CylinderMesh
var _path_mesh_instance: MeshInstance3D = null
var _path_mesh: ImmediateMesh = ImmediateMesh.new()
var _mat_path: StandardMaterial3D = null
var _ghost_mesh_instance: MeshInstance3D = null
var _ghost_mesh: ImmediateMesh = ImmediateMesh.new()
var _mat_ghost: StandardMaterial3D = null
var _merge_window_mesh_instance: MeshInstance3D = null
var _merge_window_mesh: ImmediateMesh = ImmediateMesh.new()
var _mat_merge_window: StandardMaterial3D = null
var hud_layer: CanvasLayer = null
var hud_label: Label = null


func _init(p_manager: TrafficManager = null) -> void:
	traffic_manager = p_manager
	visible = false
	_init_materials()


func _init_materials() -> void:
	_mat_free = StandardMaterial3D.new()
	_mat_free.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_free.albedo_color = Color(0.2, 0.8, 0.2)

	_mat_reserved = StandardMaterial3D.new()
	_mat_reserved.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_reserved.albedo_color = Color(0.9, 0.8, 0.1)

	_mat_occupied = StandardMaterial3D.new()
	_mat_occupied.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_occupied.albedo_color = Color(0.85, 0.2, 0.2)

	_mat_path = StandardMaterial3D.new()
	_mat_path.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_path.albedo_color = Color(0.2, 0.7, 1.0)

	_mat_ghost = StandardMaterial3D.new()
	_mat_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ghost.albedo_color = Color(1.0, 0.55, 0.1)

	_mat_merge_window = StandardMaterial3D.new()
	_mat_merge_window.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_merge_window.albedo_color = Color(1.0, 0.25, 0.25)
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.02


func _ready() -> void:
	visible = false
	if traffic_manager != null and lot == null:
		lot = traffic_manager.lot
	if lot != null:
		_setup_spots()

	_path_mesh_instance = MeshInstance3D.new()
	_path_mesh_instance.name = "PathLines"
	_path_mesh_instance.mesh = _path_mesh
	add_child(_path_mesh_instance)
	_ghost_mesh_instance = MeshInstance3D.new()
	_ghost_mesh_instance.name = "GhostLines"
	_ghost_mesh_instance.mesh = _ghost_mesh
	add_child(_ghost_mesh_instance)
	_merge_window_mesh_instance = MeshInstance3D.new()
	_merge_window_mesh_instance.name = "MergeWindowLines"
	_merge_window_mesh_instance.mesh = _merge_window_mesh
	add_child(_merge_window_mesh_instance)

	_setup_hud()


func _setup_spots() -> void:
	for spot in lot.spots:
		_create_spot_disc(spot)
		_create_spot_label(spot)
	if not lot.spot_changed.is_connected(_on_spot_changed):
		lot.spot_changed.connect(_on_spot_changed)


func _create_spot_label(spot: ParkingSpot) -> void:
	var label := Label3D.new()
	label.name = "SpotLabel_%d" % spot.id
	var tag: String = ", ".join(spot.serves) if not spot.serves.is_empty() else ""
	label.text = "%d: %s" % [spot.id, tag]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = 50.0
	var pos := spot.transform.origin
	pos.y = 0.5
	label.position = pos
	add_child(label)
	_spot_labels[spot.id] = label


func _create_spot_disc(spot: ParkingSpot) -> void:
	var disc := MeshInstance3D.new()
	disc.name = "SpotDisc_%d" % spot.id
	disc.mesh = _disc_mesh
	var pos := spot.transform.origin
	pos.y = 0.08
	disc.position = pos
	disc.material_override = _get_material_for_state(spot.state)
	add_child(disc)
	_spot_discs[spot.id] = disc


func _get_material_for_state(state: ParkingSpot.State) -> StandardMaterial3D:
	match state:
		ParkingSpot.State.FREE:
			return _mat_free
		ParkingSpot.State.RESERVED:
			return _mat_reserved
		ParkingSpot.State.OCCUPIED:
			return _mat_occupied
	return _mat_free


func _on_spot_changed(spot: ParkingSpot) -> void:
	if spot == null:
		return
	var disc: MeshInstance3D = _spot_discs.get(spot.id)
	if disc != null:
		disc.material_override = _get_material_for_state(spot.state)
	if visible:
		update_hud()


func _process(_delta: float) -> void:
	if not visible or traffic_manager == null:
		return
	_update_path_curves()
	_update_ghost_lines()
	_update_car_labels()
	_update_merge_window()
	update_hud()


func _update_car_labels() -> void:
	if traffic_manager == null:
		return

	var active_ids := {}
	var all_cars: Array[Car] = []
	for car in traffic_manager.lot_cars:
		if is_instance_valid(car):
			all_cars.append(car)
	for lane in traffic_manager.lanes:
		for car in lane.cars:
			if is_instance_valid(car) and not all_cars.has(car):
				all_cars.append(car)

	for car in all_cars:
		var cid := car.get_instance_id()
		active_ids[cid] = true

		var label: Label3D = _car_labels.get(cid)
		if label == null:
			label = Label3D.new()
			label.name = "CarLabel_%d" % cid
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font_size = 20
			label.outline_size = 3
			label.outline_modulate = Color.BLACK
			label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			label.visibility_range_end = 50.0
			add_child(label)
			_car_labels[cid] = label

		label.global_position = car.global_position + Vector3(0.0, 2.2, 0.0)
		var spot_str := str(car.spot.id) if car.spot != null else "-"
		var state_str := (
			car.get_state_name() if car.has_method("get_state_name") else str(car.state)
		)
		if car.state == Car.State.WAITING_TO_MERGE and "merge_wait_time" in car:
			label.text = (
				"%s (%.1fs)\n%.1f m/s\nspot: %s"
				% [state_str, car.merge_wait_time, car.speed, spot_str]
			)
		else:
			label.text = "%s\n%.1f m/s\nspot: %s" % [state_str, car.speed, spot_str]
	var to_remove: Array[int] = []
	for cid in _car_labels.keys():
		if not active_ids.has(cid):
			var lbl: Label3D = _car_labels[cid]
			if is_instance_valid(lbl):
				lbl.queue_free()
			to_remove.append(cid)
	for cid in to_remove:
		_car_labels.erase(cid)


func _update_path_curves() -> void:
	if _path_mesh == null:
		return
	_path_mesh.clear_surfaces()
	if traffic_manager == null:
		return

	var path_cars: Array[Car] = []
	for car in traffic_manager.lot_cars:
		if is_instance_valid(car) and car.motion == Car.Motion.PATH and car.path != null:
			path_cars.append(car)
	for lane in traffic_manager.lanes:
		for car in lane.cars:
			if is_instance_valid(car) and car.motion == Car.Motion.PATH and car.path != null:
				if not path_cars.has(car):
					path_cars.append(car)

	for car in path_cars:
		var pts := car.path.get_baked_points()
		if pts.size() >= 2:
			_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat_path)
			for pt in pts:
				_path_mesh.surface_add_vertex(pt + Vector3(0.0, 0.15, 0.0))
			_path_mesh.surface_end()


func _update_ghost_lines() -> void:
	if _ghost_mesh == null:
		return
	_ghost_mesh.clear_surfaces()
	if traffic_manager == null:
		return

	var lines: Array = []
	for lane in traffic_manager.lanes:
		for car in lane.cars:
			if is_instance_valid(car) and car.motion == Car.Motion.PATH:
				var car_pos: Vector3 = car.global_position
				var car_pt := car_pos + Vector3(0.0, 0.2, 0.0)
				var lane_pt := Vector3(car_pos.x, car_pos.y + 0.2, lane.z)
				lines.append([car_pt, lane_pt])

	if not lines.is_empty():
		_ghost_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _mat_ghost)
		for pair in lines:
			_ghost_mesh.surface_add_vertex(pair[0])
			_ghost_mesh.surface_add_vertex(pair[1])
		_ghost_mesh.surface_end()


func _update_merge_window() -> void:
	if _merge_window_mesh == null:
		return
	_merge_window_mesh.clear_surfaces()
	if traffic_manager == null or traffic_manager.lanes.is_empty():
		return

	var waiting_cars: Array[Car] = []
	for car in traffic_manager.lot_cars:
		if is_instance_valid(car) and car.state == Car.State.WAITING_TO_MERGE:
			waiting_cars.append(car)

	if waiting_cars.is_empty():
		return

	var lane_half_w: float = 3.75 * 0.5
	var y: float = 0.15

	var lines: Array = []
	for car in waiting_cars:
		var target_lane_id := car.merge_target_lane
		var target_lane: TrafficManager.Lane = (
			traffic_manager.lanes[target_lane_id]
			if traffic_manager.lanes.size() > target_lane_id
			else traffic_manager.lanes[0]
		)
		var merge_d: float
		if target_lane_id == 3:
			merge_d = target_lane.distance_at(traffic_manager.lane3_merge_x(car.global_position.x))
		else:
			merge_d = 61.0

		var window_start_d: float = merge_d - car.car_length - 2.0
		var window_end_d: float = merge_d + 10.0
		var x_start: float = target_lane.start_x + target_lane.direction * window_start_d
		var x_end: float = target_lane.start_x + target_lane.direction * window_end_d
		var z_min: float = target_lane.z - lane_half_w
		var z_max: float = target_lane.z + lane_half_w
		var c1 := Vector3(x_start, y, z_min)
		var c2 := Vector3(x_start, y, z_max)
		var c3 := Vector3(x_end, y, z_max)
		var c4 := Vector3(x_end, y, z_min)

		# Perimeter box
		lines.append([c1, c2])
		lines.append([c2, c3])
		lines.append([c3, c4])
		lines.append([c4, c1])

		# Diagonal hazard cross
		lines.append([c1, c3])
		lines.append([c2, c4])

	if not lines.is_empty():
		_merge_window_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _mat_merge_window)
		for pair in lines:
			_merge_window_mesh.surface_add_vertex(pair[0])
			_merge_window_mesh.surface_add_vertex(pair[1])
		_merge_window_mesh.surface_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			visible = not visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if hud_layer != null:
			hud_layer.visible = visible
		if visible:
			update_hud()


func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "TrafficDebugHUD"
	hud_layer.layer = 100
	hud_layer.visible = visible

	var margin := MarginContainer.new()
	margin.name = "HUDMargin"
	margin.offset_left = 20.0
	margin.offset_top = 100.0
	margin.offset_right = 740.0
	margin.offset_bottom = 136.0

	var panel := PanelContainer.new()
	panel.name = "HUDPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.7, 1.0, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	hud_label = Label.new()
	hud_label.name = "TrafficDebugHUDLabel"
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	hud_label.add_theme_constant_override("outline_size", 2)

	panel.add_child(hud_label)
	margin.add_child(panel)
	hud_layer.add_child(margin)
	add_child(hud_layer)

	update_hud()


func update_hud() -> void:
	if hud_label == null:
		return
	if lot == null and traffic_manager != null:
		lot = traffic_manager.lot

	var free_count := 0
	var reserved_count := 0
	var occupied_count := 0
	if lot != null:
		for spot in lot.spots:
			match spot.state:
				ParkingSpot.State.FREE:
					free_count += 1
				ParkingSpot.State.RESERVED:
					reserved_count += 1
				ParkingSpot.State.OCCUPIED:
					occupied_count += 1

	var dropped := 0
	var watchdog_fires := 0
	var max_stuck := 0.0
	if traffic_manager != null and traffic_manager.stats != null:
		dropped = traffic_manager.stats.get("errands_dropped_lot_full", 0)
		watchdog_fires = traffic_manager.stats.get("watchdog_fires", 0)
		max_stuck = traffic_manager.stats.get("max_stuck_time", 0.0)

	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	hud_label.text = (
		"Draw calls: %d | Objects: %d | Process: %.1fms | Physics: %.1fms\nStalls: %d free, %d reserved, %d occupied | errands_dropped_lot_full: %d | watchdog_fires: %d | max_stuck_time: %.1fs"
		% [
			draw_calls,
			objects,
			proc_ms,
			phys_ms,
			free_count,
			reserved_count,
			occupied_count,
			dropped,
			watchdog_fires,
			max_stuck
		]
	)


func get_hud_text() -> String:
	if hud_label != null:
		return hud_label.text
	return ""
