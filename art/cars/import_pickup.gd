extends SceneTree
## Converts exported Pickup glTF into native meshes under res://cars/bodies/pickup_meshes/
## and generates res://cars/bodies/pickup.tscn.
## godot --headless --path . -s <this file> -- <in.glb>

const OUT_DIR := "res://cars/bodies/pickup_meshes"
const SCENE_PATH := "res://cars/bodies/pickup.tscn"

const BASE_WHEEL_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Missing input glb path")
		quit(1)
		return
	var path := args[0]
	var state := GLTFState.new()
	var err := GLTFDocument.new().append_from_file(path, state)
	if err != OK:
		push_error("Failed to read %s: %s" % [path, error_string(err)])
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var mesh_map: Dictionary = {}
	for gltf_mesh: GLTFMesh in state.get_meshes():
		var mesh: ArrayMesh = gltf_mesh.mesh.get_mesh()
		var mesh_name := gltf_mesh.original_name.to_snake_case()
		var out := "%s/%s.res" % [OUT_DIR, mesh_name]
		err = ResourceSaver.save(mesh, out)
		if err != OK:
			push_error("Failed to save %s: %s" % [out, error_string(err)])
			quit(1)
			return
		mesh_map[gltf_mesh.original_name] = load(out)
		print("Saved %s" % out)

	# Build pickup.tscn scene
	var root := Node3D.new()
	root.name = "Pickup"

	# Helper to add mesh instance
	var add_mesh := func(
		parent: Node,
		node_name: String,
		mesh_key: String,
		pos: Vector3 = Vector3.ZERO,
		basis: Basis = Basis.IDENTITY
	) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh_map.get(mesh_key)
		mi.transform = Transform3D(basis, pos)
		parent.add_child(mi)
		mi.owner = root
		return mi

	# Body parts
	add_mesh.call(root, "Body", "Body")
	add_mesh.call(root, "Windows", "Windows")
	add_mesh.call(root, "Trim", "Trim")
	add_mesh.call(root, "BedLiner", "BedLiner")

	# Lights (markers for turn signals and spot headlamps)
	add_mesh.call(root, "HeadlightL", "HeadlightMesh", Vector3(2.18, 0.88, 0.74))
	add_mesh.call(root, "HeadlightR", "HeadlightMesh", Vector3(2.18, 0.88, -0.74))
	add_mesh.call(root, "TaillightL", "TaillightMesh", Vector3(-2.44, 1.12, 0.93))
	add_mesh.call(root, "TaillightR", "TaillightMesh", Vector3(-2.44, 1.12, -0.93))

	# Wheels
	var wheel_configs = [
		{"name": "Wheel_FL", "pos": Vector3(1.30, 0.35, 0.98)},
		{"name": "Wheel_FR", "pos": Vector3(1.30, 0.35, -0.98)},
		{"name": "Wheel_RL", "pos": Vector3(-1.35, 0.35, 0.98)},
		{"name": "Wheel_RR", "pos": Vector3(-1.35, 0.35, -0.98)},
	]

	for w in wheel_configs:
		var wheel: MeshInstance3D = add_mesh.call(
			root, w["name"], "WheelMesh", w["pos"], BASE_WHEEL_BASIS
		)
		# Spoke marker child so car.gd knows custom wheel is in place
		var spoke := Node3D.new()
		spoke.name = "Spoke"
		wheel.add_child(spoke)
		spoke.owner = root

	var packed := PackedScene.new()
	err = packed.pack(root)
	if err != OK:
		push_error("Failed to pack scene: %s" % error_string(err))
		quit(1)
		return

	err = ResourceSaver.save(packed, SCENE_PATH)
	if err != OK:
		push_error("Failed to save %s: %s" % [SCENE_PATH, error_string(err)])
		quit(1)
		return

	print("Successfully generated %s" % SCENE_PATH)
	root.free()
	quit()
