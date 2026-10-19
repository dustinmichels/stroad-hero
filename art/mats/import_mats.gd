extends SceneTree
## Converts the exported Mats glTF into native meshes under res://player/mats_meshes/,
## one .res per Blender mesh datablock, so mats.tscn needs no editor import step.
## godot --headless --path . -s <this file> -- <in.glb>

const OUT_DIR := "res://player/mats_meshes"


func _init() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var state := GLTFState.new()
	var err := GLTFDocument.new().append_from_file(path, state)
	if err != OK:
		push_error("Failed to read %s: %s" % [path, error_string(err)])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for gltf_mesh: GLTFMesh in state.get_meshes():
		var mesh := gltf_mesh.mesh.get_mesh()
		var out := "%s/%s.res" % [OUT_DIR, gltf_mesh.original_name]
		err = ResourceSaver.save(mesh, out)
		if err != OK:
			push_error("Failed to save %s: %s" % [out, error_string(err)])
			quit(1)
			return
		print("%s: %d surfaces" % [out, mesh.get_surface_count()])
	quit()
