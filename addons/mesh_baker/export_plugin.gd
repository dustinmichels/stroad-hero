@tool
class_name MeshBakerExportPlugin
extends EditorExportPlugin

const MeshBakerScript = preload("res://addons/mesh_baker/mesh_baker.gd")


func _get_name() -> String:
	return "MeshBakerExportPlugin"


func _get_customization_configuration_hash() -> int:
	return 16


func _begin_customize_scenes(platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	print("[MeshBakerExportPlugin] _begin_customize_scenes")
	return true


func _customize_scene(scene: Node, path: String) -> Node:
	if not scene is Node3D:
		return null
	var baked: Node = MeshBakerScript.bake_scene_for_path(scene as Node3D, path)
	if baked != null:
		print("[MeshBakerExportPlugin] Baked: ", path)
	return baked
