@tool
class_name MeshBakerExportPlugin
extends EditorExportPlugin

const MeshBakerScript = preload("res://addons/mesh_baker/mesh_baker.gd")


func _get_name() -> String:
	return "MeshBakerExportPlugin"


func _get_customization_configuration_hash() -> int:
	return 1


func _begin_customize_scenes(platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	print("[MeshBakerExportPlugin] _begin_customize_scenes")
	return true


func _customize_scene(scene: Node, path: String) -> Node:
	if not scene is Node3D:
		return null
	if path.begins_with("res://cars/bodies/"):
		print("[MeshBakerExportPlugin] Baking car body: ", path)
		return MeshBakerScript.bake_car_body(scene as Node3D)
	elif path.begins_with("res://buildings/"):
		print("[MeshBakerExportPlugin] Baking building: ", path)
		return MeshBakerScript.bake_static_scene(scene as Node3D)
	return null
