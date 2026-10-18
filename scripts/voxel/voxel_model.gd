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
## Off-grid voxels for shapes the grid can't follow (a curved heel, an angled
## brace): [Transform3D of a unit cube centred on the origin, in voxel units,
## Color]. Drawn whole, with no face culling or speckle.
var oriented: Array = []


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


## Adds an off-grid voxel: a box of `size` voxels centred on `center`, its
## local axes turned by `basis` (no scale). All in voxel units.
func add_oriented(center: Vector3, basis: Basis, size: Vector3, c: Color) -> VoxelModel:
	oriented.append([Transform3D(basis * Basis.from_scale(size), center), c])
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
	_append_oriented(b, xf)


func _append_oriented(b: VoxelMeshBuilder, xf: Transform3D) -> void:
	for o in oriented:
		var t: Transform3D = o[0]
		b.add_box(xf * Transform3D(t.basis * voxel_size, (t.origin - pivot) * voxel_size), o[1])


## Solid boxes that follow the model's shape, for collision: the voxels are
## binned into `cell`-voxel cubes, then neighbouring solid cells merge into as
## few boxes as possible (along x, then z, then up through y). Off-grid voxels
## count by their bounds. Returned in metres, relative to the pivot, like the
## mesh. A bigger `cell` gives fewer, looser boxes.
func collision_boxes(cell := 2) -> Array[AABB]:
	var solid := {}  # Vector3i cell -> true
	for p in voxels:
		solid[Vector3i(floori(p.x / float(cell)), floori(p.y / float(cell)), floori(p.z / float(cell)))] = true
	for o in oriented:
		var t: Transform3D = o[0]
		var bb := t * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		var lo := Vector3i((bb.position / cell).floor())
		var hi := Vector3i((bb.end / cell).ceil())
		for x in range(lo.x, hi.x):
			for y in range(lo.y, hi.y):
				for z in range(lo.z, hi.z):
					solid[Vector3i(x, y, z)] = true
	if solid.is_empty():
		return []
	# one layer at a time: greedy rectangles in x then z
	var layers := {}  # y -> Array of [x0, z0, x1, z1] (cells, end exclusive)
	var ys := {}
	for c in solid:
		ys[c.y] = true
	for y in ys:
		var taken := {}
		var rects: Array = []
		var cells: Array = []
		for c in solid:
			if c.y == y:
				cells.append(c)
		cells.sort_custom(func(a, b): return a.z < b.z or (a.z == b.z and a.x < b.x))
		for c in cells:
			if taken.has(c):
				continue
			var x1: int = c.x + 1
			while solid.has(Vector3i(x1, y, c.z)) and not taken.has(Vector3i(x1, y, c.z)):
				x1 += 1
			var z1: int = c.z + 1
			while true:
				var row_ok := true
				for x in range(c.x, x1):
					var q := Vector3i(x, y, z1)
					if not solid.has(q) or taken.has(q):
						row_ok = false
						break
				if not row_ok:
					break
				z1 += 1
			for x in range(c.x, x1):
				for z in range(c.z, z1):
					taken[Vector3i(x, y, z)] = true
			rects.append([c.x, c.z, x1, z1])
		layers[y] = rects
	# stack identical rectangles up through the layers
	var out: Array[AABB] = []
	var sorted_ys := ys.keys()
	sorted_ys.sort()
	var open := {}  # rect key -> [y0, rect]
	var prev_y := -999999
	for y in sorted_ys:
		var next_open := {}
		for r in layers[y]:
			var key := "%d,%d,%d,%d" % r
			if open.has(key) and prev_y == y - 1:
				next_open[key] = open[key]
				open.erase(key)
			else:
				next_open[key] = [y, r]
		for key in open:
			out.append(_cell_box(open[key][1], open[key][0], prev_y + 1, cell))
		open = next_open
		prev_y = y
	for key in open:
		out.append(_cell_box(open[key][1], open[key][0], prev_y + 1, cell))
	return out


func _cell_box(r: Array, y0: int, y1: int, cell: int) -> AABB:
	var lo := Vector3(r[0], y0, r[1]) * cell
	var hi := Vector3(r[2], y1, r[3]) * cell
	return AABB((lo - pivot) * voxel_size, (hi - lo) * voxel_size)


## A lighter mesh for distance and big repeats: no per-voxel speckle, and
## neighbouring faces of the same colour merge into one quad (greedy meshing).
## `quantize` > 0 snaps colours to that many steps per channel first, so faded
## or grimy surfaces merge too.
func build_mesh_merged(quantize := 0) -> ArrayMesh:
	var b := VoxelMeshBuilder.new()
	var cols := {}
	for p in voxels:
		var c: Color = voxels[p]
		if quantize > 0:
			var q := float(quantize)
			c = Color(roundf(c.r * q) / q, roundf(c.g * q) / q, roundf(c.b * q) / q)
		cols[p] = c
	for i in 6:
		var dir: Vector3i = DIRS[i]
		var d := 0 if dir.x != 0 else (1 if dir.y != 0 else 2)
		var ua := (d + 1) % 3
		var va := (d + 2) % 3
		var positive := dir[d] > 0
		# exposed faces grouped by layer: layer -> {Vector2i(u, v): Color}
		var layers := {}
		for key in cols:
			var p: Vector3i = key
			if cols.has(p + dir):
				continue
			var k: int = p[d]
			if not layers.has(k):
				layers[k] = {}
			layers[k][Vector2i(p[ua], p[va])] = cols[p]
		var n := Vector3(dir)
		for layer in layers:
			var k: int = layer
			var mask: Dictionary = layers[k]
			var keys := mask.keys()
			keys.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool: return a.y < b2.y or (a.y == b2.y and a.x < b2.x))
			var used := {}
			for key in keys:
				var start: Vector2i = key
				if used.has(start):
					continue
				var c: Color = mask[start]
				var w := 1
				while _same(mask, start + Vector2i(w, 0), c) and not used.has(start + Vector2i(w, 0)):
					w += 1
				var h := 1
				var grow := true
				while grow:
					for x in w:
						var q2 := start + Vector2i(x, h)
						if not _same(mask, q2, c) or used.has(q2):
							grow = false
							break
					if grow:
						h += 1
				for x in w:
					for y in h:
						used[start + Vector2i(x, y)] = true
				var plane := float(k + 1) if positive else float(k)
				var corners: Array[Vector3] = []
				for uv in [Vector2(start.x, start.y), Vector2(start.x + w, start.y), Vector2(start.x + w, start.y + h), Vector2(start.x, start.y + h)]:
					var v3 := Vector3.ZERO
					v3[d] = plane
					v3[ua] = uv.x
					v3[va] = uv.y
					corners.append((v3 - pivot) * voxel_size)
				b.add_quad(corners[0], corners[1], corners[2], corners[3], n, c)
	_append_oriented(b, Transform3D.IDENTITY)
	return b.commit()


static func _same(mask: Dictionary, at: Vector2i, c: Color) -> bool:
	return mask.has(at) and mask[at] == c
