class_name VoxelMeshBuilder
extends RefCounted
## Accumulates voxel faces into one ArrayMesh with per-vertex colors.
##
## Two kinds of voxels are supported:
##  * grid voxels, emitted by VoxelModel with hidden faces culled, and
##  * oriented voxels, via add_box(): a box with an arbitrary Transform3D
##    (any rotation, scale or skew). Use these for things that don't sit on
##    the grid, like the curved rink boards or a stick lying at an angle.

const CUBE_FACES := [
	[Vector3(1, 0, 0), [Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, -0.5, 0.5)]],
	[Vector3(-1, 0, 0), [Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, 0.5, -0.5)]],
	[Vector3(0, 1, 0), [Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, -0.5)]],
	[Vector3(0, -1, 0), [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5)]],
	[Vector3(0, 0, 1), [Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]],
	[Vector3(0, 0, -1), [Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, -0.5, -0.5)]],
]

static var _material: StandardMaterial3D

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
	return _material


## Slight per-voxel brightness noise gives the speckled look of the reference renders.
static func jitter_color(c: Color, key: Variant, amount: float) -> Color:
	if amount <= 0.0:
		return c
	var n := float(posmod(hash(key), 1000)) / 1000.0 - 0.5
	var f := 1.0 + n * 2.0 * amount
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	# Godot treats clockwise triangles as front-facing; fix the winding from the normal.
	if (b - a).cross(c - a).dot(n) > 0.0:
		_tri(a, c, b, n, col)
		_tri(a, d, c, n, col)
	else:
		_tri(a, b, c, n, col)
		_tri(a, c, d, n, col)


## Adds an oriented voxel: a unit cube centred on the origin, transformed by `xf`.
func add_box(xf: Transform3D, col: Color) -> void:
	var nb := xf.basis.inverse().transposed()
	for face in CUBE_FACES:
		var n: Vector3 = (nb * face[0]).normalized()
		var cs: Array = face[1]
		add_quad(xf * cs[0], xf * cs[1], xf * cs[2], xf * cs[3], n, col)


func is_empty() -> bool:
	return _verts.is_empty()


func commit(mat: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat if mat else material())
	return mesh


func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	_verts.append(a)
	_verts.append(b)
	_verts.append(c)
	for i in 3:
		_norms.append(n)
		_cols.append(col)
