@tool
class_name Tunnel
extends StaticBody3D
## Highway tunnel portal and enclosure for stroad edges.
## Prevents the player from entering via chainlink fences and portal barrier,
## while providing a dark interior tube for cars to disappear into.

const TUNNEL_DEPTH := 25.0
const PORTAL_DEPTH := 2.0
const ROAD_WIDTH := 23.5
const CLEARANCE_HEIGHT := 6.2
const ABUTMENT_WIDTH := 3.5
const WALL_THICKNESS := 1.0

const SHADER_CHAINLINK := "res://shaders/chainlink.gdshader"

var _concrete_mat: StandardMaterial3D
var _dark_concrete_mat: StandardMaterial3D
var _blackout_mat: StandardMaterial3D
var _hazard_mat: StandardMaterial3D
var _sign_mat: StandardMaterial3D

@export var tunnel_name: String = "TUNNEL":
	set(value):
		tunnel_name = value
		_update_labels()


func _ready() -> void:
	_init_materials()
	_build_tunnel()


func _init_materials() -> void:
	if _concrete_mat == null:
		_concrete_mat = StandardMaterial3D.new()
		_concrete_mat.resource_name = "TunnelConcrete"
		_concrete_mat.albedo_color = Color(0.68, 0.67, 0.65)
		_concrete_mat.roughness = 0.85

	if _dark_concrete_mat == null:
		_dark_concrete_mat = StandardMaterial3D.new()
		_dark_concrete_mat.resource_name = "TunnelInteriorDark"
		_dark_concrete_mat.albedo_color = Color(0.08, 0.08, 0.09)
		_dark_concrete_mat.roughness = 0.95

	if _blackout_mat == null:
		_blackout_mat = StandardMaterial3D.new()
		_blackout_mat.resource_name = "TunnelBlackout"
		_blackout_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blackout_mat.albedo_color = Color(0.01, 0.01, 0.01)

	if _hazard_mat == null:
		_hazard_mat = StandardMaterial3D.new()
		_hazard_mat.resource_name = "TunnelHazard"
		_hazard_mat.albedo_color = Color(0.96, 0.72, 0.08)
		_hazard_mat.roughness = 0.5

	if _sign_mat == null:
		_sign_mat = StandardMaterial3D.new()
		_sign_mat.resource_name = "TunnelSignBacking"
		_sign_mat.albedo_color = Color(0.12, 0.28, 0.16)
		_sign_mat.roughness = 0.4


func _build_tunnel() -> void:
	for child in get_children():
		child.queue_free()

	_build_portal_structure()
	_build_tube_structure()
	_build_signage()
	_build_fences()
	_build_collision_shapes()


func _build_portal_structure() -> void:
	var portal_group := Node3D.new()
	portal_group.name = "PortalStructure"
	add_child(portal_group)

	var half_road := ROAD_WIDTH * 0.5
	var abut_z := half_road + ABUTMENT_WIDTH * 0.5
	var abut_h := CLEARANCE_HEIGHT

	# Left (South) Abutment Pillar
	var left_abut := _create_box(
		Vector3(PORTAL_DEPTH, abut_h, ABUTMENT_WIDTH),
		Vector3(-PORTAL_DEPTH * 0.5, abut_h * 0.5, abut_z),
		_concrete_mat,
		"LeftAbutment"
	)
	portal_group.add_child(left_abut)

	# Right (North) Abutment Pillar
	var right_abut := _create_box(
		Vector3(PORTAL_DEPTH, abut_h, ABUTMENT_WIDTH),
		Vector3(-PORTAL_DEPTH * 0.5, abut_h * 0.5, -abut_z),
		_concrete_mat,
		"RightAbutment"
	)
	portal_group.add_child(right_abut)

	# Overhead Header Lintel
	var header_span := ROAD_WIDTH + ABUTMENT_WIDTH * 2.0
	var header_beam := _create_box(
		Vector3(PORTAL_DEPTH, 1.2, header_span),
		Vector3(-PORTAL_DEPTH * 0.5, CLEARANCE_HEIGHT + 0.6, 0.0),
		_concrete_mat,
		"HeaderBeam"
	)
	portal_group.add_child(header_beam)

	# Top Parapet / Headwall
	var parapet := _create_box(
		Vector3(1.8, 1.2, header_span + 4.0),
		Vector3(-1.0, CLEARANCE_HEIGHT + 1.8, 0.0),
		_concrete_mat,
		"Parapet"
	)
	portal_group.add_child(parapet)

	# Retaining Wing Walls angling outward to retain earth/embankment
	var wing_len := 6.0
	var wing_angle := deg_to_rad(25.0)
	var wing_x_extent := wing_len * 0.5 * cos(wing_angle) + 0.6 * sin(wing_angle)
	var wing_z_extent := wing_len * 0.5 * sin(wing_angle) + 0.6 * cos(wing_angle)
	var wing_x := -PORTAL_DEPTH - wing_x_extent
	var wing_z := abut_z + ABUTMENT_WIDTH * 0.5 + wing_z_extent
	var left_wing := _create_box(
		Vector3(wing_len, abut_h * 0.8, 1.2),
		Vector3(wing_x, abut_h * 0.4, wing_z),
		_concrete_mat,
		"LeftWingWall"
	)
	left_wing.rotation.y = wing_angle
	portal_group.add_child(left_wing)

	var right_wing := _create_box(
		Vector3(wing_len, abut_h * 0.8, 1.2),
		Vector3(wing_x, abut_h * 0.4, -wing_z),
		_concrete_mat,
		"RightWingWall"
	)
	right_wing.rotation.y = -wing_angle
	portal_group.add_child(right_wing)

	# Hazard warning clearance bar
	var hazard_bar := _create_box(
		Vector3(0.12, 0.35, ROAD_WIDTH),
		Vector3(0.06, CLEARANCE_HEIGHT - 0.175, 0.0),
		_hazard_mat,
		"HazardBar"
	)
	portal_group.add_child(hazard_bar)


func _build_tube_structure() -> void:
	var tube_group := Node3D.new()
	tube_group.name = "TunnelTube"
	add_child(tube_group)

	var tube_depth := TUNNEL_DEPTH - PORTAL_DEPTH
	var tube_x := -(TUNNEL_DEPTH + PORTAL_DEPTH) * 0.5
	var half_road := ROAD_WIDTH * 0.5
	var wall_z := half_road + WALL_THICKNESS * 0.5

	# South interior wall
	var south_wall := _create_box(
		Vector3(tube_depth, CLEARANCE_HEIGHT, WALL_THICKNESS),
		Vector3(tube_x, CLEARANCE_HEIGHT * 0.5, wall_z),
		_dark_concrete_mat,
		"SouthWall"
	)
	tube_group.add_child(south_wall)

	# North interior wall
	var north_wall := _create_box(
		Vector3(tube_depth, CLEARANCE_HEIGHT, WALL_THICKNESS),
		Vector3(tube_x, CLEARANCE_HEIGHT * 0.5, -wall_z),
		_dark_concrete_mat,
		"NorthWall"
	)
	tube_group.add_child(north_wall)

	# Ceiling / Roof slab
	var roof := _create_box(
		Vector3(tube_depth, 0.8, ROAD_WIDTH + WALL_THICKNESS * 2.0),
		Vector3(tube_x, CLEARANCE_HEIGHT + 0.4, 0.0),
		_dark_concrete_mat,
		"Ceiling"
	)
	tube_group.add_child(roof)

	# Blackout backplane wall at depth = TUNNEL_DEPTH
	var blackout := _create_box(
		Vector3(0.2, CLEARANCE_HEIGHT, ROAD_WIDTH),
		Vector3(-TUNNEL_DEPTH - 0.1, CLEARANCE_HEIGHT * 0.5, 0.0),
		_blackout_mat,
		"BlackoutWall"
	)
	tube_group.add_child(blackout)


func _build_signage() -> void:
	var sign_group := Node3D.new()
	sign_group.name = "Signage"
	add_child(sign_group)

	# Highway green sign plate above portal
	var sign_board := _create_box(
		Vector3(0.08, 1.0, 10.0), Vector3(0.05, CLEARANCE_HEIGHT + 0.8, 0.0), _sign_mat, "SignBoard"
	)
	sign_group.add_child(sign_board)

	var label := Label3D.new()
	label.name = "SignLabel"
	label.text = "%s\nCLEARANCE 16' - 0\"" % tunnel_name
	label.font_size = 48
	label.pixel_size = 0.007
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	label.position = Vector3(0.12, CLEARANCE_HEIGHT + 0.8, 0.0)
	label.rotation.y = deg_to_rad(90.0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign_group.add_child(label)


func _update_labels() -> void:
	var label := get_node_or_null("Signage/SignLabel") as Label3D
	if label:
		label.text = "%s\nCLEARANCE 16' - 0\"" % tunnel_name


func _build_fences() -> void:
	var fences_group := Node3D.new()
	fences_group.name = "ChainlinkFences"
	add_child(fences_group)

	const FenceScene = preload("res://props/chainlink_fence_section.tscn")
	var half_road := ROAD_WIDTH * 0.5

	# 1. South Fence across sidewalk, shoulder, and grass (Z = half_road to half_road + 10.0)
	var south_fence := FenceScene.instantiate() as ChainlinkFence
	south_fence.name = "Fence_SouthAcross"
	south_fence.mode = ChainlinkFence.Mode.SINGLE_SECTION
	south_fence.single_section_length = 10.0
	south_fence.fence_height = 2.4
	south_fence.position = Vector3(0.0, 0.0, half_road + 5.0)
	south_fence.rotation.y = deg_to_rad(90.0)
	fences_group.add_child(south_fence)

	# 2. North Fence across sidewalk, shoulder, and grass (Z = -(half_road + 10.0) to -half_road)
	var north_fence := FenceScene.instantiate() as ChainlinkFence
	north_fence.name = "Fence_NorthAcross"
	north_fence.mode = ChainlinkFence.Mode.SINGLE_SECTION
	north_fence.single_section_length = 10.0
	north_fence.fence_height = 2.4
	north_fence.position = Vector3(0.0, 0.0, -(half_road + 5.0))
	north_fence.rotation.y = deg_to_rad(90.0)
	fences_group.add_child(north_fence)

	# 3. South Side Return Fence running along embankment
	var south_return := FenceScene.instantiate() as ChainlinkFence
	south_return.name = "Fence_SouthSide"
	south_return.mode = ChainlinkFence.Mode.SINGLE_SECTION
	south_return.single_section_length = TUNNEL_DEPTH
	south_return.fence_height = 2.4
	south_return.position = Vector3(-TUNNEL_DEPTH * 0.5, 0.0, half_road + 10.0)
	south_return.rotation.y = 0.0
	fences_group.add_child(south_return)

	# 4. North Side Return Fence running along embankment
	var north_return := FenceScene.instantiate() as ChainlinkFence
	north_return.name = "Fence_NorthSide"
	north_return.mode = ChainlinkFence.Mode.SINGLE_SECTION
	north_return.single_section_length = TUNNEL_DEPTH
	north_return.fence_height = 2.4
	north_return.position = Vector3(-TUNNEL_DEPTH * 0.5, 0.0, -(half_road + 10.0))
	north_return.rotation.y = 0.0
	fences_group.add_child(north_return)


func _build_collision_shapes() -> void:
	var half_road := ROAD_WIDTH * 0.5
	var abut_z := half_road + ABUTMENT_WIDTH * 0.5
	var abut_h := CLEARANCE_HEIGHT

	# Left Abutment collision
	var left_col := CollisionShape3D.new()
	left_col.name = "Col_LeftAbutment"
	var left_box := BoxShape3D.new()
	left_box.size = Vector3(PORTAL_DEPTH, abut_h, ABUTMENT_WIDTH)
	left_col.shape = left_box
	left_col.position = Vector3(-PORTAL_DEPTH * 0.5, abut_h * 0.5, abut_z)
	add_child(left_col)

	# Right Abutment collision
	var right_col := CollisionShape3D.new()
	right_col.name = "Col_RightAbutment"
	var right_box := BoxShape3D.new()
	right_box.size = Vector3(PORTAL_DEPTH, abut_h, ABUTMENT_WIDTH)
	right_col.shape = right_box
	right_col.position = Vector3(-PORTAL_DEPTH * 0.5, abut_h * 0.5, -abut_z)
	add_child(right_col)

	# South Tunnel Wall collision
	var tube_depth := TUNNEL_DEPTH - PORTAL_DEPTH
	var tube_x := -(TUNNEL_DEPTH + PORTAL_DEPTH) * 0.5
	var south_col := CollisionShape3D.new()
	south_col.name = "Col_SouthWall"
	var south_box := BoxShape3D.new()
	south_box.size = Vector3(tube_depth, CLEARANCE_HEIGHT, WALL_THICKNESS)
	south_col.shape = south_box
	south_col.position = Vector3(tube_x, CLEARANCE_HEIGHT * 0.5, half_road + WALL_THICKNESS * 0.5)
	add_child(south_col)

	# North Tunnel Wall collision
	var north_col := CollisionShape3D.new()
	north_col.name = "Col_NorthWall"
	var north_box := BoxShape3D.new()
	north_box.size = Vector3(tube_depth, CLEARANCE_HEIGHT, WALL_THICKNESS)
	north_col.shape = north_box
	north_col.position = Vector3(
		tube_x, CLEARANCE_HEIGHT * 0.5, -(half_road + WALL_THICKNESS * 0.5)
	)
	add_child(north_col)

	# Portal Road Blocker - prevents Mats (player) from walking into the tunnel on foot
	# Cars are Area3D and are NOT blocked by StaticBody3D collision shapes.
	var blocker := CollisionShape3D.new()
	blocker.name = "Col_PortalPlayerBlocker"
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(0.6, 5.0, ROAD_WIDTH)
	blocker.shape = blocker_box
	blocker.position = Vector3(-0.3, 2.5, 0.0)
	add_child(blocker)


func _create_box(
	p_size: Vector3, p_pos: Vector3, p_mat: Material, p_name: String
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	var box := BoxMesh.new()
	box.size = p_size
	box.material = p_mat
	mi.mesh = box
	mi.position = p_pos
	return mi
