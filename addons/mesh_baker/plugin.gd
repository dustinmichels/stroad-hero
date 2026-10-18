@tool
class_name MeshBakerPlugin
extends EditorPlugin

const MeshBakerExportPluginScript = preload("res://addons/mesh_baker/export_plugin.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = MeshBakerExportPluginScript.new()
	add_export_plugin(_export_plugin)
	if not ProjectSettings.has_setting("debug/bake_preview"):
		ProjectSettings.set_setting("debug/bake_preview", false)
		ProjectSettings.set_initial_value("debug/bake_preview", false)
		(
			ProjectSettings
			. add_property_info(
				{
					"name": "debug/bake_preview",
					"type": TYPE_BOOL,
					"hint": PROPERTY_HINT_NONE,
				}
			)
		)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
