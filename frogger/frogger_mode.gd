class_name FroggerMode
extends Node3D
## Experimental "frogger mode". Near the stroad the camera locks to a steep view behind Mats, the
## ground shows a hop grid, the arrow keys hop Mats one cell forward/back/left/right instead of
## walking, and traffic is slowed and shown moving on a fixed beat (FroggerTraffic). Landing beyond
## `exit_distance` from the centerline (or outside the stroad corridor) returns to normal play.
##
## Main adds this node only when `Main.frogger_mode_enabled` is on; nothing else references it.
## It drives Mats through `Mats.locomotion_override`, the camera through
## `FollowCamera.set_view_override()`, and traffic through `TrafficManager.sim_time_scale` and its
## `sim_step_started` / `sim_step_finished` signals.

signal mode_changed(is_active: bool)

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]

## Mats enters frogger mode within this distance (m) of the stroad centerline (z = 0)...
@export var enter_distance := 13.0
## ...and leaves after landing on a cell whose center is farther than this.
@export var exit_distance := 15.0
## Stretch of the stroad (world x) where frogger mode applies.
@export var min_x := Mats.MIN_RESPAWN_X
@export var max_x := Mats.MAX_RESPAWN_X
## Half a lane, so lane lines and the road edge fall on cell edges.
@export var cell_size := 1.875
@export var hop_duration := 0.22
@export var hop_height := 0.45
## Pause after landing before the next held-key hop.
@export var landing_pause := 0.06
@export var camera_pitch_degrees := 58.0
@export var camera_distance := 16.5
## Yaw away from straight-across, toward where traffic in Mats' half of the stroad comes from.
@export var camera_traffic_angle_degrees := 25.0
## Grid tiles shown on each side of Mats along the road.
@export var grid_half_width_cells := 12
## Ground hits above this world height (benches, planters) get no grid tile.
@export var max_tile_ground_height := 0.6

var mats: Mats = null
var camera: FollowCamera = null
var traffic: TrafficManager = null
var is_active := false

var _grid: FroggerGrid = null
var _traffic_beat: FroggerTraffic = null
var _grid_center_x := 0
## Grid step for "up": across the stroad, away from the side Mats entered from.
var _forward := Vector2i(0, -1)
var _facing_yaw := NAN
## Stroad half Mats is in (+1 south/eastbound lanes, -1 north/westbound) for the camera angle.
var _camera_half := 1.0
var _is_hopping := false
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_elapsed := 0.0
var _pause_left := 0.0
var _queued_step := Vector2i.ZERO


func _ready() -> void:
	_grid = FroggerGrid.new()
	_grid.name = "Grid"
	add_child(_grid)
	_traffic_beat = FroggerTraffic.new()
	_traffic_beat.name = "TrafficBeat"
	add_child(_traffic_beat)


func setup(p_mats: Mats, p_camera: FollowCamera, p_traffic: TrafficManager) -> void:
	mats = p_mats
	camera = p_camera
	traffic = p_traffic
	if not mats.died.is_connected(_on_mats_died):
		mats.died.connect(_on_mats_died)
	if not mats.respawned.is_connected(exit):
		mats.respawned.connect(exit)


func _exit_tree() -> void:
	exit()
	if mats and is_instance_valid(mats):
		if mats.died.is_connected(_on_mats_died):
			mats.died.disconnect(_on_mats_died)
		if mats.respawned.is_connected(exit):
			mats.respawned.disconnect(exit)


func _physics_process(_delta: float) -> void:
	if not is_active and _can_enter():
		enter()


func _can_enter() -> bool:
	if not mats or mats.is_dead or mats.is_pushing_cart or not mats.is_physics_processing():
		return false
	var pos := mats.global_position
	return absf(pos.z) < enter_distance and _in_corridor(pos.x)


func _in_corridor(x: float) -> bool:
	return x >= min_x and x <= max_x


func enter() -> void:
	if is_active or not mats:
		return
	is_active = true
	_forward = Vector2i(0, -1 if mats.global_position.z >= 0.0 else 1)
	_facing_yaw = atan2(float(_forward.x), float(_forward.y))
	_queued_step = Vector2i.ZERO
	_pause_left = 0.0
	mats.locomotion_override = _drive
	# Settle onto the nearest cell so every later hop lands on a cell center.
	_start_hop(FroggerGrid.cell_of(mats.global_position, cell_size))
	_rebuild_grid()
	_grid.fade_in()
	_aim_camera(mats.global_position.z)
	if traffic:
		_traffic_beat.start(traffic)
	mode_changed.emit(true)


## Looks across the stroad from behind Mats, turned upstream toward traffic in his half: eastbound
## lanes (z > 0) come from -x, westbound lanes (z < 0) from +x.
func _aim_camera(z: float) -> void:
	_camera_half = 1.0 if z >= 0.0 else -1.0
	if not camera:
		return
	var angle := deg_to_rad(camera_traffic_angle_degrees)
	var yaw := atan2(-_camera_half * sin(angle), float(_forward.y) * cos(angle))
	camera.set_view_override(yaw, deg_to_rad(camera_pitch_degrees), camera_distance)


func exit() -> void:
	if not is_active:
		return
	is_active = false
	_is_hopping = false
	if mats and is_instance_valid(mats) and mats.locomotion_override == _drive:
		mats.locomotion_override = Callable()
	_grid.fade_out()
	_traffic_beat.stop()
	if camera and is_instance_valid(camera):
		camera.clear_view_override()
	mode_changed.emit(false)


func _on_mats_died(_death_position: Vector3) -> void:
	exit()


## Mats' locomotion while active: hops between cell centers. Returns the yaw Mats should face.
func _drive(delta: float) -> float:
	if mats.is_pushing_cart:
		exit()
		return NAN
	var pressed := _input_step(true)
	if _is_hopping:
		if pressed != Vector2i.ZERO:
			_queued_step = pressed
		_advance_hop(delta)
		return _facing_yaw
	_pause_left = maxf(0.0, _pause_left - delta)
	if pressed != Vector2i.ZERO:
		_queued_step = pressed
	var step := _queued_step
	if step == Vector2i.ZERO:
		step = _input_step(false)
	if step != Vector2i.ZERO and _pause_left <= 0.0:
		_queued_step = Vector2i.ZERO
		_facing_yaw = atan2(float(step.x), float(step.y))
		_start_hop(FroggerGrid.cell_of(mats.global_position, cell_size) + step)
		_advance_hop(delta)
	else:
		_stand(delta)
	return _facing_yaw


## First matching move action as a grid step; `just_pressed` reads fresh presses, else held keys.
func _input_step(just_pressed: bool) -> Vector2i:
	for action in MOVE_ACTIONS:
		var is_on := (
			Input.is_action_just_pressed(action)
			if just_pressed
			else Input.is_action_pressed(action)
		)
		if is_on:
			return _action_step(action)
	return Vector2i.ZERO


func _action_step(action: StringName) -> Vector2i:
	# Screen-right while looking along `_forward` (camera sits behind Mats).
	var right := Vector2i(-_forward.y, 0)
	match action:
		&"move_up":
			return _forward
		&"move_down":
			return -_forward
		&"move_left":
			return -right
		_:
			return right


func _hop_gravity() -> float:
	return 8.0 * hop_height / (hop_duration * hop_duration)


func _start_hop(cell: Vector2i) -> void:
	var center := FroggerGrid.cell_center(cell, cell_size)
	_hop_from = mats.global_position
	_hop_to = Vector3(center.x, _hop_from.y, center.y)
	_hop_elapsed = 0.0
	_is_hopping = true
	mats.velocity.y = 4.0 * hop_height / hop_duration


func _advance_hop(delta: float) -> void:
	# Advance by this tick's share of the hop, not toward a lerped goal: a blocked hop then just
	# stops instead of building up speed, and _land() snaps it back onto a cell.
	var t_before := minf(_hop_elapsed / hop_duration, 1.0)
	_hop_elapsed += delta
	var t := minf(_hop_elapsed / hop_duration, 1.0)
	var planar := (_hop_to - _hop_from) * ((t - t_before) / delta)
	mats.velocity.x = planar.x
	mats.velocity.z = planar.z
	mats.velocity.y -= _hop_gravity() * delta
	mats.move_and_slide()
	if t >= 1.0 and mats.is_on_floor():
		_land()


func _stand(delta: float) -> void:
	mats.velocity.x = 0.0
	mats.velocity.z = 0.0
	mats.velocity.y = 0.0 if mats.is_on_floor() else mats.velocity.y - _hop_gravity() * delta
	mats.move_and_slide()


func _land() -> void:
	_is_hopping = false
	_pause_left = landing_pause
	mats.velocity = Vector3.ZERO
	# A blocked hop ends off-center; settle on the nearest cell if nothing is in the way.
	var cell := FroggerGrid.cell_of(mats.global_position, cell_size)
	var center := FroggerGrid.cell_center(cell, cell_size)
	var snap := Vector3(center.x - mats.global_position.x, 0.0, center.y - mats.global_position.z)
	if not snap.is_zero_approx() and not mats.test_move(mats.global_transform, snap):
		mats.global_position += snap
	mats.visual.trigger_jump_squash()
	if absf(center.y) > exit_distance or not _in_corridor(center.x):
		exit()
		return
	if signf(center.y) != _camera_half:
		_aim_camera(center.y)
	if absi(cell.x - _grid_center_x) * 2 > grid_half_width_cells:
		_rebuild_grid()


func _rebuild_grid() -> void:
	var center := FroggerGrid.cell_of(mats.global_position, cell_size)
	_grid_center_x = center.x
	var max_row := ceili(exit_distance / cell_size)
	var cells: Array[Vector2i] = []
	for x in range(center.x - grid_half_width_cells, center.x + grid_half_width_cells + 1):
		for z in range(-max_row, max_row + 1):
			var cell := Vector2i(x, z)
			var cell_pos := FroggerGrid.cell_center(cell, cell_size)
			if absf(cell_pos.y) <= exit_distance and _in_corridor(cell_pos.x):
				cells.append(cell)
	_grid.build(cells, cell_size, max_tile_ground_height, [mats.get_rid()])
