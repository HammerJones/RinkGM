@tool
class_name VoxAsset
extends Resource
## A MagicaVoxel model as Godot data: voxel positions (Godot axes, +Y up,
## front toward -Z), a palette index per voxel, and the 256-colour palette.
## The import plugin (addons/vox_import) turns every .vox under res:// into
## one of these, so `load("res://art/props/cup.vox")` gives a VoxAsset that
## is cached by the editor and ships in exports. Code that runs without the
## import step (tools/tests/*.gd under --script) uses `load_file`.
##
## Geometry comes out as a VoxelModel (`to_model`), so everything downstream
## (Wear, VoxMesher, collision boxes, the coded kit) stays one code path.

## Voxel grid positions, three ints per voxel.
@export var positions := PackedInt32Array()
## One palette index per voxel (1..255; 0 is never used by MagicaVoxel).
@export var indices := PackedByteArray()
## 256 colours; slot 0 is empty.
@export var palette := PackedColorArray()
## Emission per palette slot, 0..1, from the file's materials (a screen, a
## lamp). Carried into meshes as 1 - vertex alpha, so a plain colour (alpha
## 1) never glows and the shader reads it without a second attribute.
@export var emissive := PackedFloat32Array()
## Extent of the model in voxels.
@export var size := Vector3i.ZERO
## Metres per voxel. The kit's 0.065 m unless the import says otherwise.
@export var voxel_m := 0.065
## Where the file came from, for error messages and the prop studio.
@export var source := ""
## Baked at import when the file's "bake_mesh" option is on: the greedy
## mesh with ambient occlusion (VoxMesher), its low-detail twin without AO,
## and the shape-following collision boxes, so a 100k-voxel prop loads in
## milliseconds instead of meshing for seconds.
@export var mesh: ArrayMesh
@export var mesh_lod: ArrayMesh
@export var boxes: Array[AABB] = []


func count() -> int:
	return indices.size()


## Lowest and highest voxel on each axis (position + size, inclusive).
func bounds() -> AABB:
	if indices.is_empty():
		return AABB()
	var lo := Vector3i(positions[0], positions[1], positions[2])
	var hi := lo
	for i in range(1, indices.size()):
		var p := Vector3i(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2])
		lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
		hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
	return AABB(Vector3(lo), Vector3(hi - lo))


## Shifts every voxel so the lowest corner sits at `corner` (default the
## origin): what a one-model file already has, and what a scene needs.
func recentre(corner := Vector3i.ZERO) -> void:
	if indices.is_empty():
		return
	var lo := Vector3i(bounds().position) - corner
	for i in indices.size():
		positions[i * 3] -= lo.x
		positions[i * 3 + 1] -= lo.y
		positions[i * 3 + 2] -= lo.z
	emit_changed()


## The model as a VoxelModel, for Wear, VoxMesher and collision boxes.
## `remap` (palette index -> Color) overrides colours, which is how a wear
## palette is applied before meshing; `offset` shifts the voxels onto the
## model's own grid (a manifest's `offset`, undone).
func to_model(voxel_size := -1.0, offset := Vector3i.ZERO, remap := {}) -> VoxelModel:
	var m := VoxelModel.new(voxel_m if voxel_size <= 0.0 else voxel_size)
	m.pivot = Vector3.ZERO
	for i in indices.size():
		var idx := indices[i]
		var c: Color = remap[idx] if remap.has(idx) else palette[idx]
		if idx < emissive.size() and emissive[idx] > 0.0:
			c.a = 1.0 - emissive[idx]
		m.voxels[Vector3i(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]) - offset] = c
	return m


## Palette indices actually used, sorted.
func used_indices() -> PackedInt32Array:
	var seen := {}
	for i in indices:
		seen[i] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


## Reads a .vox directly, bypassing the import cache. For scripts that run
## without the editor's import step, and for the prop studio's live reload.
static func load_file(path: String) -> VoxAsset:
	return VoxReader.read(path)


## Loads the imported asset for `path` when the import has run, else reads
## the file. Code that must work both in the editor and under --script.
static func load_any(path: String) -> VoxAsset:
	if ResourceLoader.exists(path, "VoxAsset"):
		var res := load(path)
		if res is VoxAsset:
			return res
	return load_file(path)
