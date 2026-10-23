class_name VoxWriter
extends RefCounted
## Writes a VoxelModel out as a MagicaVoxel .vox file (version 150, one
## model: SIZE, XYZI, an RGBA palette and a MATL per emissive colour), the inverse of VoxReader,
## so a prop built in code can become an asset in art/props/ and be opened in
## MagicaVoxel. Only grid voxels are written: a model with oriented voxels
## (VoxelModel.oriented) is refused, since the format has no place for them.
##
## Axes: MagicaVoxel is Z-up and faces -Y; VoxReader maps a file's (x, y, z)
## to Godot's (-x, z, y) and this writes the same rotation back, so a prop
## that faces -Z here opens in MagicaVoxel facing its camera. The model is
## shifted so its lowest voxel sits at 0 on every axis (the format has no
## negative coordinates); the shift is returned so a manifest can keep the
## model's pivot.

const MAX_COLOURS := 255
const MAX_SIZE := 256


## Writes `m` to `path`. Returns {"ok": bool, "shift": Vector3i, "size":
## Vector3i, "colours": int, "error": String}. `shift` is what was added to
## every voxel (so pivot_in_file = pivot + shift).
static func write(m: VoxelModel, path: String) -> Dictionary:
	var out := {
		"ok": false, "shift": Vector3i.ZERO, "size": Vector3i.ZERO, "colours": 0, "error": ""
	}
	if m == null or m.voxels.is_empty():
		out.error = "no voxels"
		return out
	if not m.oriented.is_empty():
		out.error = "%d oriented voxels can't be written to .vox" % m.oriented.size()
		return out
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := -lo
	for p in m.voxels:
		lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
		hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
	var size := hi - lo + Vector3i.ONE
	if size.x > MAX_SIZE or size.y > MAX_SIZE or size.z > MAX_SIZE:
		out.error = "model is %s voxels; .vox holds at most %d a side" % [size, MAX_SIZE]
		return out
	# palette: one slot per distinct 8-bit colour, in first-seen order
	var palette: Array[Color] = []
	var index := {}  # Color8 key -> 1-based palette index
	var voxels := PackedByteArray()
	for p in m.voxels:
		var c: Color = m.voxels[p]
		# alpha below 1 is emission (1 - a), kept as its own palette slot
		var key := Color8(
			roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), roundi(c.a * 255.0)
		)
		if not index.has(key):
			if palette.size() >= MAX_COLOURS:
				out.error = "more than %d colours" % MAX_COLOURS
				return out
			palette.append(key)
			index[key] = palette.size()
		var q: Vector3i = p - lo
		# Godot (x, y, z) -> file (size_x - 1 - x, z, y), where the file's y
		# extent is the model's z extent
		voxels.append(size.x - 1 - q.x)
		voxels.append(q.z)
		voxels.append(q.y)
		voxels.append(index[key])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		out.error = "cannot write %s" % path
		return out
	var n := m.voxels.size()
	var size_chunk := 12
	var xyzi_chunk := 4 + 4 * n
	var rgba_chunk := 1024
	# one MATL chunk per emissive colour: id, then a dict of strings
	var matl := PackedByteArray()
	for i in palette.size():
		if palette[i].a8 >= 255:
			continue
		var d := {"_type": "_emit", "_emit": "%.3f" % (1.0 - palette[i].a), "_flux": "0"}
		var body := PackedByteArray()
		body.append_array(_u32(i + 1))
		body.append_array(_u32(d.size()))
		for k in d:
			body.append_array(_str(k))
			body.append_array(_str(d[k]))
		matl.append_array("MATL".to_ascii_buffer())
		matl.append_array(_u32(body.size()))
		matl.append_array(_u32(0))
		matl.append_array(body)
	f.store_buffer("VOX ".to_ascii_buffer())
	f.store_32(150)
	f.store_buffer("MAIN".to_ascii_buffer())
	f.store_32(0)
	f.store_32((12 + size_chunk) + (12 + xyzi_chunk) + (12 + rgba_chunk) + matl.size())
	f.store_buffer("SIZE".to_ascii_buffer())
	f.store_32(size_chunk)
	f.store_32(0)
	f.store_32(size.x)
	f.store_32(size.z)  # the file's y runs along the model's z
	f.store_32(size.y)
	f.store_buffer("XYZI".to_ascii_buffer())
	f.store_32(xyzi_chunk)
	f.store_32(0)
	f.store_32(n)
	f.store_buffer(voxels)
	f.store_buffer("RGBA".to_ascii_buffer())
	f.store_32(rgba_chunk)
	f.store_32(0)
	for i in 256:
		var c := palette[i] if i < palette.size() else Color8(0, 0, 0, 255)
		f.store_8(c.r8)
		f.store_8(c.g8)
		f.store_8(c.b8)
		f.store_8(255)
	f.store_buffer(matl)
	f.close()
	out.ok = true
	out.shift = -lo
	out.size = size
	out.colours = palette.size()
	return out


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _str(v: String) -> PackedByteArray:
	var b := v.to_utf8_buffer()
	return _u32(b.size()) + b
