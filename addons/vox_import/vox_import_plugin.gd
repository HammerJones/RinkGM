@tool
class_name VoxImportPlugin
extends EditorImportPlugin
## Imports every .vox under res:// as a VoxAsset. Dropping a MagicaVoxel
## file into art/ is then the whole authoring step: the editor imports it,
## re-imports it when it changes on disk, and `load()` returns the asset.
##
## Import options (per file, in the Import dock):
##   voxel_m   metres per voxel; 0 (the default) reads it from the prop's
##             manifest data/props/<name>.json, else the kit's 0.065
##   recentre  put the lowest corner at the origin (on by default; off keeps
##             a scene's own placement)
##   bake_mesh also store the greedy AO mesh, a low-detail mesh and the
##             collision boxes in the asset (on by default)
##   collision_cell  voxels per collision box cell (VoxelModel.collision_boxes)

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
			"default_value": 0.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,1.0,0.0001"
		},
		{"name": "recentre", "default_value": true},
		{"name": "bake_mesh", "default_value": true},
		{
			"name": "collision_cell",
			"default_value": 8,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,32,1"
		},
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
	asset.voxel_m = float(options.get("voxel_m", 0.0))
	if asset.voxel_m <= 0.0:
		asset.voxel_m = _manifest_voxel_m(source_file)
	if bool(options.get("recentre", true)):
		asset.recentre()
	asset.source = source_file
	if bool(options.get("bake_mesh", true)):
		var m := asset.to_model()
		var b := asset.bounds()
		m.set_pivot(
			b.position.x + b.size.x / 2.0 + 0.5, b.position.y, b.position.z + b.size.z / 2.0 + 0.5
		)
		asset.mesh = VoxMesher.build(m, {"greedy": true})
		asset.mesh_lod = VoxMesher.build(m, {"greedy": true, "ao": false})
		asset.boxes = m.collision_boxes(int(options.get("collision_cell", 8)))
	return ResourceSaver.save(asset, "%s.%s" % [save_path, _get_save_extension()])


## The prop's manifest voxel size, when data/props/<name>.json has one.
static func _manifest_voxel_m(source_file: String) -> float:
	var path := "res://data/props/%s.json" % source_file.get_file().get_basename()
	if FileAccess.file_exists(path):
		var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if rec is Dictionary and rec.has("voxel_m"):
			return float(rec.voxel_m)
	return 0.065
