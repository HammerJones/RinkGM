class_name VoxReader
extends RefCounted
## Reads a MagicaVoxel .vox file into a VoxAsset: every model in the file,
## placed by the file's scene graph (nTRN / nGRP / nSHP) when it has one, with
## the 256-colour palette. This is the full reader behind the import plugin
## (addons/vox_import) and the runtime fallback (VoxAsset.load_file), and
## replaces the one-model VoxLoader for new code.
##
## Axes: MagicaVoxel is Z-up with +Y toward the model's back. A file voxel
## (x, y, z) becomes Godot (x, z, -y), so +Y is up and the front faces -Z,
## the same mapping VoxLoader and VoxWriter use. A one-model file with no
## scene graph lands with its lowest corner at the origin, like VoxLoader; a
## scene lands wherever its transforms put it (MagicaVoxel centres each model
## on its node), which the import's "recentre" option undoes.

const MAX_SIZE := 256


## Reads `path` (res:// or absolute). Returns null and pushes an error when
## the file is missing or malformed.
static func read(path: String) -> VoxAsset:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("VoxReader: cannot open %s" % path)
		return null
	return read_buffer(f.get_buffer(f.get_length()), path)


## Reads a .vox file already in memory.
static func read_buffer(data: PackedByteArray, label := "") -> VoxAsset:
	var r := _Stream.new(data)
	if r.remaining() < 8 or r.fourcc() != "VOX ":
		push_error("VoxReader: %s is not a .vox file" % label)
		return null
	r.u32()  # version (150 or 200)
	var models: Array = []  # [{size: Vector3i, voxels: PackedByteArray}]
	var palette := PackedColorArray()
	var nodes := {}  # id -> {type, children, model_ids, frames}
	var pending_size := Vector3i.ZERO
	while r.remaining() >= 12:
		var id := r.fourcc()
		var content := r.u32()
		r.u32()  # children size: children follow inline, so just keep reading
		var end := r.pos + content
		match id:
			"MAIN":
				pass
			"SIZE":
				pending_size = Vector3i(r.u32(), r.u32(), r.u32())
			"XYZI":
				var n := r.u32()
				models.append({"size": pending_size, "voxels": r.bytes(n * 4)})
			"RGBA":
				palette.resize(256)
				# the file's colour i (1-based in XYZI) is stored at slot i-1
				for i in 255:
					palette[i + 1] = Color8(r.u8(), r.u8(), r.u8(), r.u8())
				r.skip(4)
				palette[0] = Color(0, 0, 0, 0)
			"nTRN":
				var nid := r.u32()
				r.dict()  # node attributes (_name, _hidden)
				var child := r.u32()
				r.u32()  # reserved
				r.u32()  # layer
				var frames := r.u32()
				var xfs: Array = []
				for i in frames:
					xfs.append(r.dict())
				nodes[nid] = {"type": "trn", "child": child, "frames": xfs}
			"nGRP":
				var nid := r.u32()
				r.dict()
				var count := r.u32()
				var children: Array = []
				for i in count:
					children.append(r.u32())
				nodes[nid] = {"type": "grp", "children": children}
			"nSHP":
				var nid := r.u32()
				r.dict()
				var count := r.u32()
				var ids: Array = []
				for i in count:
					ids.append(r.u32())
					r.dict()  # model attributes (_f frame index)
				nodes[nid] = {"type": "shp", "models": ids}
			_:
				pass  # MATL, LAYR, rOBJ, rCAM, NOTE, IMAP, PACK: not needed
		r.pos = end
	if models.is_empty():
		push_error("VoxReader: %s has no models" % label)
		return null
	if palette.is_empty():
		palette = default_palette()
	var asset := VoxAsset.new()
	asset.palette = palette
	asset.source = label
	var placed: Array = []  # [model index, Basis (file space), Vector3i translation]
	if nodes.has(0):
		_walk(nodes, 0, Basis.IDENTITY, Vector3i.ZERO, placed)
	if placed.is_empty():
		for i in models.size():
			placed.append([i, Basis.IDENTITY, Vector3i.ZERO])
	var scene := nodes.has(0)
	for item in placed:
		var m: Dictionary = models[item[0]]
		_emit(asset, m, item[1], item[2], scene)
	asset.size = (
		Vector3i(asset.bounds().size) + Vector3i.ONE if asset.count() > 0 else Vector3i.ZERO
	)
	return asset


## Follows the scene graph from node `id`, composing transforms in file
## space, and collects every shape node's models with their placement.
static func _walk(nodes: Dictionary, id: int, basis: Basis, origin: Vector3i, out: Array) -> void:
	if not nodes.has(id):
		return
	var n: Dictionary = nodes[id]
	match n.type:
		"trn":
			var fr: Dictionary = n.frames[0] if not n.frames.is_empty() else {}
			var local_b := _rotation(int(fr.get("_r", "4")))
			var local_t := _translation(str(fr.get("_t", "0 0 0")))
			# parent * local: rotate the child's offset by the parent's basis
			var world_t := origin + Vector3i((basis * Vector3(local_t)).round())
			_walk(nodes, n.child, basis * local_b, world_t, out)
		"grp":
			for c in n.children:
				_walk(nodes, c, basis, origin, out)
		"shp":
			for m in n.models:
				out.append([m, basis, origin])


## Adds one model's voxels to the asset. In a scene each model is centred on
## its node (MagicaVoxel's convention: voxel v sits at v - floor(size / 2))
## before the node transform; a plain file keeps its corner at the origin.
static func _emit(
	asset: VoxAsset, m: Dictionary, basis: Basis, origin: Vector3i, scene: bool
) -> void:
	var size: Vector3i = m.size
	var vox: PackedByteArray = m.voxels
	var centre := Vector3i(size.x / 2, size.y / 2, size.z / 2) if scene else Vector3i.ZERO
	var n := vox.size() / 4
	var pos := PackedInt32Array()
	pos.resize(n * 3)
	var idx := PackedByteArray()
	idx.resize(n)
	for i in n:
		var fp := Vector3i(vox[i * 4], vox[i * 4 + 1], vox[i * 4 + 2]) - centre
		var wp := Vector3i((basis * Vector3(fp)).round()) + origin
		# file (x, y, z) -> Godot (x, z, -y); a plain file is cornered at the
		# origin right away (size.y - 1 - y), the way VoxLoader reads it
		pos[i * 3] = wp.x
		pos[i * 3 + 1] = wp.z
		pos[i * 3 + 2] = -wp.y if scene else size.y - 1 - wp.y
		idx[i] = vox[i * 4 + 3]
	asset.positions.append_array(pos)
	asset.indices.append_array(idx)


## MagicaVoxel's packed rotation byte: bits 0-1 and 2-3 pick which column
## holds the non-zero entry of rows 1 and 2 (row 3 takes the one left), bits
## 4-6 are the signs of the three rows.
static func _rotation(code: int) -> Basis:
	var r0 := code & 3
	var r1 := (code >> 2) & 3
	var r2 := 3 - r0 - r1
	var rows := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	rows[0][r0] = -1.0 if code & 16 else 1.0
	rows[1][r1] = -1.0 if code & 32 else 1.0
	rows[2][r2] = -1.0 if code & 64 else 1.0
	# Basis takes columns; the file gives rows
	return Basis(rows[0], rows[1], rows[2]).transposed()


static func _translation(s: String) -> Vector3i:
	var parts := s.split(" ", false)
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


## MagicaVoxel's built-in palette, used by files saved without an RGBA chunk.
static func default_palette() -> PackedColorArray:
	var p := PackedColorArray()
	p.resize(256)
	p[0] = Color(0, 0, 0, 0)
	# the default palette is a 6x6x6 colour cube followed by greys, in the
	# order MagicaVoxel lists it (index 1 is white)
	var i := 1
	for r in 6:
		for g in 6:
			for b in 6:
				if i < 256:
					p[i] = Color((5 - r) / 5.0, (5 - g) / 5.0, (5 - b) / 5.0)
					i += 1
	var steps := [238, 221, 204, 187, 170, 153, 136, 119, 102, 85, 68, 51, 34, 17]
	for v in steps:
		if i < 256:
			p[i] = Color8(v, v, v)
			i += 1
	while i < 256:
		p[i] = Color.BLACK
		i += 1
	return p


class _Stream:
	var data: PackedByteArray
	var pos := 0

	func _init(d: PackedByteArray) -> void:
		data = d

	func remaining() -> int:
		return data.size() - pos

	func u8() -> int:
		var v := data[pos]
		pos += 1
		return v

	func u32() -> int:
		var v := data.decode_u32(pos)
		pos += 4
		return v

	func fourcc() -> String:
		var s := data.slice(pos, pos + 4).get_string_from_ascii()
		pos += 4
		return s

	func bytes(n: int) -> PackedByteArray:
		var b := data.slice(pos, pos + n)
		pos += n
		return b

	func skip(n: int) -> void:
		pos += n

	func string() -> String:
		var n := u32()
		return bytes(n).get_string_from_utf8()

	func dict() -> Dictionary:
		var out := {}
		var n := u32()
		for i in n:
			var k := string()
			out[k] = string()
		return out
