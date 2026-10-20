@tool
class_name VoxImportPlugin
extends EditorImportPlugin
## Imports every .vox under res:// as a VoxAsset. Dropping a MagicaVoxel
## file into art/ is then the whole authoring step: the editor imports it,
## re-imports it when it changes on disk, and `load()` returns the asset.
##
## Import options (per file, in the Import dock):
##   voxel_m   metres per voxel (0.065 is the kit; handhelds use 0.0125-0.02)
##   recentre  put the lowest corner at the origin (on by default; off keeps
##             a scene's own placement)

enum Presets { DEFAULT }


func _get_importer_name() -> String:
	return "rinkgm.vox"


func _get_visible_name() -> String:
	return "MagicaVoxel model"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vox"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 0


func _get_preset_count() -> int:
	return Presets.size()


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "voxel_m",
			"default_value": 0.065,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.005,1.0,0.0005"
		},
		{"name": "recentre", "default_value": true},
	]


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	_platform_variants: Array[String],
	_gen_files: Array[String]
) -> Error:
	var asset := VoxReader.read(source_file)
	if asset == null:
		return ERR_FILE_CORRUPT
	asset.voxel_m = float(options.get("voxel_m", 0.065))
	if bool(options.get("recentre", true)):
		asset.recentre()
	asset.source = source_file
	return ResourceSaver.save(asset, "%s.%s" % [save_path, _get_save_extension()])
