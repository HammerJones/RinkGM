@tool
extends EditorPlugin
## Registers the .vox importer (VoxImportPlugin) with the editor.

var _importer: VoxImportPlugin


func _enter_tree() -> void:
	_importer = VoxImportPlugin.new()
	add_import_plugin(_importer)


func _exit_tree() -> void:
	remove_import_plugin(_importer)
	_importer = null
