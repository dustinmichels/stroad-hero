class_name TrafficDebug
extends Node3D

var traffic_manager: TrafficManager = null
var lot: ParkingLot = null

var _spot_discs: Dictionary = {}
var _spot_labels: Dictionary = {}
var _car_labels: Dictionary = {}
var _mat_free: StandardMaterial3D
var _mat_reserved: StandardMaterial3D
var _mat_occupied: StandardMaterial3D
var _disc_mesh: CylinderMesh
var _path_mesh_instance: MeshInstance3D = null
var _path_mesh: ImmediateMesh = null
var _mat_path: StandardMaterial3D = null


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

	_path_mesh = ImmediateMesh.new()
	_path_mesh_instance = MeshInstance3D.new()
	_path_mesh_instance.name = "PathLines"
	_path_mesh_instance.mesh = _path_mesh
	add_child(_path_mesh_instance)


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


func _process(_delta: float) -> void:
	if not visible or traffic_manager == null:
		return
	_update_path_curves()
	_update_car_labels()


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
			add_child(label)
			_car_labels[cid] = label

		label.global_position = car.global_position + Vector3(0.0, 2.2, 0.0)
		var spot_str := str(car.spot.id) if car.spot != null else "-"
		var state_str := (
			car.get_state_name() if car.has_method("get_state_name") else str(car.state)
		)
		label.text = "%s\n%.1f m/s\nspot: %s" % [state_str, car.speed, spot_str]

	var to_remove: Array = []
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			visible = not visible
