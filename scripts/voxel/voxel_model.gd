class_name VoxelModel
extends RefCounted
## A sparse grid of coloured voxels. Build it with box()/set_voxel(), then turn
## it into a mesh with build_mesh(). Faces between neighbouring voxels are culled.
##
## Convention: +Y is up and the model's front faces -Z (Godot's forward), so
## low z values are the front of a character.

const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const FACES := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]

var voxels := {}  # Vector3i -> Color
var voxel_size := 0.065
## Mesh origin in voxel units (e.g. a joint). Vertices are offset by -pivot.
var pivot := Vector3.ZERO
var jitter := 0.04


func _init(size := 0.065) -> void:
	voxel_size = size


func set_voxel(x: int, y: int, z: int, c: Color) -> VoxelModel:
	voxels[Vector3i(x, y, z)] = c
	return self


func box(x: int, y: int, z: int, sx: int, sy: int, sz: int, c: Color) -> VoxelModel:
	for i in sx:
		for j in sy:
			for k in sz:
				voxels[Vector3i(x + i, y + j, z + k)] = c
	return self


func clear_box(x: int, y: int, z: int, sx: int, sy: int, sz: int) -> VoxelModel:
	for i in sx:
		for j in sy:
			for k in sz:
				voxels.erase(Vector3i(x + i, y + j, z + k))
	return self


func set_pivot(x: float, y: float, z: float) -> VoxelModel:
	pivot = Vector3(x, y, z)
	return self


func build_mesh() -> ArrayMesh:
	var b := VoxelMeshBuilder.new()
	append_to(b, Transform3D.IDENTITY)
	return b.commit()


## Emits this model's visible faces into `b`, transformed by `xf`. Lets several
## models (or several orientations of one model) share a single mesh.
func append_to(b: VoxelMeshBuilder, xf: Transform3D) -> void:
	var nb := xf.basis.inverse().transposed()
	for p in voxels:
		var c: Color = VoxelMeshBuilder.jitter_color(voxels[p], p, jitter)
		var base := (Vector3(p) - pivot) * voxel_size
		for i in 6:
			if voxels.has(p + DIRS[i]):
				continue
			var f: Array = FACES[i]
			var n: Vector3 = (nb * Vector3(DIRS[i])).normalized()
			b.add_quad(
				xf * (base + f[0] * voxel_size), xf * (base + f[1] * voxel_size),
				xf * (base + f[2] * voxel_size), xf * (base + f[3] * voxel_size), n, c)
