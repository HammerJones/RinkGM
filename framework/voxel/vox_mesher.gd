class_name VoxMesher
extends VoxelMeshBuilder
## The framework's mesher for VoxelModel: one pass that does what the kit's
## two meshers do (speckled full detail, merged low detail) and adds baked
## ambient occlusion, the single biggest step toward the ray-traced look of
## the references.
##
##   VoxMesher.build(model)                         # speckle + AO, full detail
##   VoxMesher.build(model, {"greedy": true})       # flat faces merged, AO kept
##   VoxMesher.build(model, {"ao": false})          # the kit's plain look
##
## Options: ao (true), ao_strength (0.42: how dark a fully tucked corner
## gets), greedy (false: merge same-colour faces; AO edges still split
## them, so a box keeps its soft corners), jitter (the model's), quantize
## (0: colour steps a channel, so dithered tones merge), material.
##
## A voxel colour's alpha below 1 means emission (1 - alpha, see VoxAsset)
## and passes through untouched; the shader turns it into glow.
##
## AO is the classic voxel kind: each face corner counts its three
## neighbouring voxels (two sides and the diagonal) and darkens by how many
## are solid, with the quad's diagonal flipped so the shading never shows a
## seam. Costs nothing at runtime: it is vertex colour.

const DIRS := VoxelModel.DIRS


static func build(m: VoxelModel, opts := {}) -> ArrayMesh:
	var b := VoxMesher.new()
	b.append(m, opts)
	return b.commit(opts.get("material", null))


## Emits `m` into this builder (several models can share one mesh).
func append(m: VoxelModel, opts := {}, xf := Transform3D.IDENTITY) -> void:
	var ao: bool = opts.get("ao", true)
	var strength: float = opts.get("ao_strength", 0.42)
	var greedy: bool = opts.get("greedy", false)
	var jitter: float = opts.get("jitter", 0.0 if greedy else m.jitter)
	# snap colours to this many steps a channel first, so a dithered surface
	# (two close tones) becomes one colour and its faces merge (for a
	# low-detail mesh; 0 keeps every colour)
	var quantize: int = opts.get("quantize", 0)
	var vox := m.voxels
	var nb := xf.basis.inverse().transposed()
	for i in 6:
		var dir: Vector3i = DIRS[i]
		var d := 0 if dir.x != 0 else (1 if dir.y != 0 else 2)
		var ua := (d + 1) % 3
		var va := (d + 2) % 3
		var positive := dir[d] > 0
		var n: Vector3 = (nb * Vector3(dir)).normalized()
		var u_axis := Vector3i.ZERO
		u_axis[ua] = 1
		var v_axis := Vector3i.ZERO
		v_axis[va] = 1
		# exposed faces by layer: layer -> {Vector2i(u, v): [Color, ao0..ao3]}
		var layers := {}
		for key in vox:
			var p: Vector3i = key
			if vox.has(p + dir):
				continue
			var c: Color = jitter_color(vox[p], p, jitter)
			if quantize > 0:
				var q := float(quantize)
				c = Color(roundf(c.r * q) / q, roundf(c.g * q) / q, roundf(c.b * q) / q, c.a)
			var face: Array = [c, 3, 3, 3, 3]
			if ao:
				var o := p + dir
				# corners in quad order: (u0,v0) (u1,v0) (u1,v1) (u0,v1)
				face[1] = _corner(vox, o, -u_axis, -v_axis)
				face[2] = _corner(vox, o, u_axis, -v_axis)
				face[3] = _corner(vox, o, u_axis, v_axis)
				face[4] = _corner(vox, o, -u_axis, v_axis)
			var k: int = p[d]
			if not layers.has(k):
				layers[k] = {}
			layers[k][Vector2i(p[ua], p[va])] = face
		for layer in layers:
			var k: int = layer
			var mask: Dictionary = layers[k]
			var keys := mask.keys()
			keys.sort_custom(
				func(a: Vector2i, b2: Vector2i) -> bool:
					return a.y < b2.y or (a.y == b2.y and a.x < b2.x)
			)
			var used := {}
			for key in keys:
				var start: Vector2i = key
				if used.has(start):
					continue
				var face: Array = mask[start]
				var w := 1
				var h := 1
				if greedy:
					while (
						_same(mask, start + Vector2i(w, 0), face)
						and not used.has(start + Vector2i(w, 0))
					):
						w += 1
					var grow := true
					while grow:
						for x in w:
							var q2 := start + Vector2i(x, h)
							if not _same(mask, q2, face) or used.has(q2):
								grow = false
								break
						if grow:
							h += 1
				for x in w:
					for y in h:
						used[start + Vector2i(x, y)] = true
				var plane := float(k + 1) if positive else float(k)
				var corners: Array[Vector3] = []
				for uv in [
					Vector2(start.x, start.y),
					Vector2(start.x + w, start.y),
					Vector2(start.x + w, start.y + h),
					Vector2(start.x, start.y + h)
				]:
					var v3 := Vector3.ZERO
					v3[d] = plane
					v3[ua] = uv.x
					v3[va] = uv.y
					corners.append(xf * ((v3 - m.pivot) * m.voxel_size))
				var c: Color = face[0]
				var cols: Array[Color] = []
				for j in 4:
					var occ: int = face[1 + j]
					cols.append(c.darkened(strength * (3 - occ) / 3.0))
				_quad_ao(corners, n, cols, face)
	m._append_oriented(self, xf)


## Occlusion at one face corner: 3 is open, 0 is a fully tucked corner.
## `o` is the voxel in front of the face; `su`, `sv` point along the face
## toward the corner.
static func _corner(vox: Dictionary, o: Vector3i, su: Vector3i, sv: Vector3i) -> int:
	var s1 := 1 if vox.has(o + su) else 0
	var s2 := 1 if vox.has(o + sv) else 0
	if s1 == 1 and s2 == 1:
		return 0
	var c := 1 if vox.has(o + su + sv) else 0
	return 3 - (s1 + s2 + c)


static func _same(mask: Dictionary, at: Vector2i, face: Array) -> bool:
	if not mask.has(at):
		return false
	var f: Array = mask[at]
	return (
		f[0] == face[0]
		and f[1] == face[1]
		and f[2] == face[2]
		and f[3] == face[3]
		and f[4] == face[4]
	)


## A quad with a colour per corner, split along the diagonal that keeps the
## AO gradient smooth (the standard flip: join the two brighter corners).
func _quad_ao(p: Array[Vector3], n: Vector3, cols: Array[Color], face: Array) -> void:
	var flip: bool = face[1] + face[3] > face[2] + face[4]
	var order := [0, 1, 2, 0, 2, 3] if not flip else [1, 2, 3, 1, 3, 0]
	# Godot treats clockwise triangles as front-facing; fix the winding
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2] if not flip else [1, 3, 2, 1, 0, 3]
	for idx in order:
		_verts.append(p[idx])
		_norms.append(n)
		_cols.append(cols[idx])
