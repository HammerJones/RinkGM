class_name VoxLoader
extends RefCounted
## Minimal MagicaVoxel (.vox) reader so models can be authored in MagicaVoxel
## and dropped in instead of the procedural ones. Reads the first model
## (SIZE/XYZI) and the palette (RGBA). MagicaVoxel is Z-up; this maps it to Y-up
## with the model's -Y side becoming the front (-Z).


static func load_vox(path: String, voxel_size := 0.065) -> VoxelModel:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("VoxLoader: cannot open %s" % path)
		return null
	if f.get_buffer(4).get_string_from_ascii() != "VOX ":
		push_error("VoxLoader: %s is not a .vox file" % path)
		return null
	f.get_32()  # version
	var size := Vector3i.ZERO
	var points: Array = []
	var palette: Array = []
	while f.get_position() + 12 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var content := f.get_32()
		f.get_32()  # children size; children are read inline
		var start := f.get_position()
		match id:
			"MAIN":
				continue
			"SIZE":
				if size == Vector3i.ZERO:
					size = Vector3i(f.get_32(), f.get_32(), f.get_32())
			"XYZI":
				if points.is_empty():
					var n := f.get_32()
					for i in n:
						points.append([f.get_8(), f.get_8(), f.get_8(), f.get_8()])
			"RGBA":
				for i in 256:
					var c := f.get_buffer(4)
					palette.append(Color8(c[0], c[1], c[2], c[3]))
		f.seek(start + content)
	var m := VoxelModel.new(voxel_size)
	for p in points:
		var idx: int = p[3]
		var col := Color(0.7, 0.7, 0.7)
		if palette.size() >= idx and idx > 0:
			col = palette[idx - 1]
		m.set_voxel(p[0], p[2], size.y - 1 - p[1], col)
	m.pivot = Vector3(size.x * 0.5, 0, size.y * 0.5)
	return m
