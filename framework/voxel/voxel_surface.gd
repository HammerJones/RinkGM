class_name VoxelSurface
extends Node3D
## A voxel volume that changes at runtime, drawn in chunks that re-mesh
## only where they changed: the ice (skate marks, snow, a flood), a dented
## wall, anything carved. Set voxels; dirty chunks are rebuilt a few per
## frame within a time budget, so a Zamboni pass never hitches.
##
##   var ice := VoxelSurface.new()
##   ice.setup(Vector3i(640, 2, 300), 0.05)         # voxels, metres per voxel
##   ice.fill(AABB(...), Color.WHITE)               # or set_voxel(x, y, z, colour)
##   ice.set_voxel(x, 1, z, Color.TRANSPARENT)      # carve (alpha 0 = empty)
##
## Chunks are CHUNK voxels a side; each is one MeshInstance3D with the
## prop material (AO, emission). `budget_ms` is how long a frame may spend
## re-meshing; `remesh_now()` finishes everything at once. This is the
## GDScript mesher (about a millisecond per thousand surface voxels); the
## hook for a native mesher later is `_build_chunk`.

const CHUNK := 16

@export var budget_ms := 2.0

var size := Vector3i.ZERO
var voxel_m := 0.05
## Chunks rebuilt since setup (tests, the dev menu).
var remeshed := 0
## Colour per voxel, flat; alpha 0 is empty.
var data := PackedColorArray()
var _chunks := {}  # Vector3i -> MeshInstance3D
var _dirty := {}  # Vector3i -> true
var _ncx := 0
var _ncy := 0
var _ncz := 0


func setup(voxels: Vector3i, metres_per_voxel: float) -> void:
	size = voxels
	voxel_m = metres_per_voxel
	data.resize(size.x * size.y * size.z)
	data.fill(Color(0, 0, 0, 0))
	for c in _chunks.values():
		c.queue_free()
	_chunks.clear()
	_dirty.clear()
	_ncx = ceili(float(size.x) / CHUNK)
	_ncy = ceili(float(size.y) / CHUNK)
	_ncz = ceili(float(size.z) / CHUNK)
	remeshed = 0


func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < size.x and y < size.y and z < size.z


func get_voxel(x: int, y: int, z: int) -> Color:
	if not in_bounds(x, y, z):
		return Color(0, 0, 0, 0)
	return data[(x * size.y + y) * size.z + z]


func set_voxel(x: int, y: int, z: int, c: Color) -> void:
	if not in_bounds(x, y, z):
		return
	data[(x * size.y + y) * size.z + z] = c
	_touch(x, y, z)


## Fills a box (voxel coordinates, end exclusive) with one colour.
func fill(lo: Vector3i, hi: Vector3i, c: Color) -> void:
	for x in range(maxi(lo.x, 0), mini(hi.x, size.x)):
		for y in range(maxi(lo.y, 0), mini(hi.y, size.y)):
			for z in range(maxi(lo.z, 0), mini(hi.z, size.z)):
				data[(x * size.y + y) * size.z + z] = c
	for cx in range(lo.x / CHUNK, (hi.x - 1) / CHUNK + 1):
		for cy in range(lo.y / CHUNK, (hi.y - 1) / CHUNK + 1):
			for cz in range(lo.z / CHUNK, (hi.z - 1) / CHUNK + 1):
				_dirty[Vector3i(cx, cy, cz)] = true


func dirty_count() -> int:
	return _dirty.size()


## Rebuilds every dirty chunk now.
func remesh_now() -> void:
	for key in _dirty.keys():
		_build_chunk(key)
	_dirty.clear()


func _process(_dt: float) -> void:
	if _dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var limit := int(budget_ms * 1000.0)
	for key in _dirty.keys():
		_build_chunk(key)
		_dirty.erase(key)
		if Time.get_ticks_usec() - t0 > limit:
			break


## A changed voxel dirties its chunk and, on a chunk face, the neighbour
## (whose faces against it may now show or hide).
func _touch(x: int, y: int, z: int) -> void:
	var c := Vector3i(x / CHUNK, y / CHUNK, z / CHUNK)
	_dirty[c] = true
	for axis in 3:
		var v: int = [x, y, z][axis]
		var n := c
		if v % CHUNK == 0:
			n[axis] -= 1
			_dirty[n] = true
		elif v % CHUNK == CHUNK - 1:
			n[axis] += 1
			_dirty[n] = true


func _build_chunk(key: Vector3i) -> void:
	if key.x < 0 or key.y < 0 or key.z < 0 or key.x >= _ncx or key.y >= _ncy or key.z >= _ncz:
		return
	var m := VoxelModel.new(voxel_m)
	m.jitter = 0.0
	var lo := key * CHUNK
	var hi := Vector3i(
		mini(lo.x + CHUNK, size.x), mini(lo.y + CHUNK, size.y), mini(lo.z + CHUNK, size.z)
	)
	# a one-voxel skirt of neighbours so faces at the chunk border cull right
	for x in range(maxi(lo.x - 1, 0), mini(hi.x + 1, size.x)):
		for y in range(maxi(lo.y - 1, 0), mini(hi.y + 1, size.y)):
			for z in range(maxi(lo.z - 1, 0), mini(hi.z + 1, size.z)):
				var c := data[(x * size.y + y) * size.z + z]
				if c.a > 0.0:
					m.voxels[Vector3i(x, y, z)] = c
	# faces of skirt voxels must not be emitted: mesh the chunk's own voxels only
	var own := VoxelModel.new(voxel_m)
	own.jitter = 0.0
	for p in m.voxels:
		if p.x >= lo.x and p.x < hi.x and p.y >= lo.y and p.y < hi.y and p.z >= lo.z and p.z < hi.z:
			own.voxels[p] = m.voxels[p]
	var mi: MeshInstance3D = _chunks.get(key)
	if own.voxels.is_empty():
		if mi:
			mi.queue_free()
			_chunks.erase(key)
		return
	# neighbours only hide faces: give the mesher the skirt as occluders
	var mesh := _mesh_with_skirt(own, m)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = PropMaterial.shared()
		add_child(mi)
		_chunks[key] = mi
	mi.mesh = mesh
	remeshed += 1


## Meshes `own` with faces against `all` (own plus the skirt) culled.
func _mesh_with_skirt(own: VoxelModel, all: VoxelModel) -> ArrayMesh:
	# VoxMesher culls against the model it is given; build from `all` and
	# drop faces that belong to skirt voxels by meshing `all` restricted to
	# own voxels: the simplest correct way is a model holding own voxels
	# plus skirt voxels marked by a flag the mesher respects. Lacking that
	# flag, mesh `all` and cut the skirt's faces by position.
	var b := VoxMesher.new()
	b.append(all, {"greedy": true, "ao": true, "skip": _skirt_of(own, all)})
	return b.commit(PropMaterial.shared())


func _skirt_of(own: VoxelModel, all: VoxelModel) -> Dictionary:
	var skirt := {}
	for p in all.voxels:
		if not own.voxels.has(p):
			skirt[p] = true
	return skirt
