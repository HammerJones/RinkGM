class_name IceSheet
extends Node3D
## The sheet of ice as columns: per cell (2.5 cm by default) loose snow,
## liquid water, how much of that water has set, the dry-cut amount and
## its angle, and gouge depth. Two data textures carry the state to the
## ice shader (one texel per cell), and a chunked heightfield gives snow,
## water and gouges real height. Only dirty chunks are re-uploaded and
## re-meshed, a few per frame.
##
##   var ice := IceSheet.new()
##   add_child(ice)
##   ice.setup(Vector2(24, 14), 0.025)
##   ice.fill_state(0.0, 0.8, 0.0, 0.0)          # snow mm, cut, water mm, frozen
##   ice.pour(Vector2(3, 2), 0.4, 1.2)            # a 1.2 mm puddle, 0.4 m across
##   ice.stroke(Vector2(1, 1), Vector2(4, 3), 0.03, 0.9, 1.5, 0.3)
##   ice.thermal(dt, slab_c, air_c)               # water sets from the edges in
##
## Freezing (the heat balance, simplified until the plant model drives it):
## a cell's water sets at a rate from the slab temperature under it,
## slower in deep water and warm air, faster next to cells already set or
## dry, which is why a pool shrinks inward. 1.2 mm at -5 C takes about 12
## minutes; the sim's IceSlab is the source of those numbers.

const CHUNK := 64  # cells a side
const SNOW_FULL := 1.0  # mm that reads as fully snowed
const WATER_FULL := 0.5  # mm that reads as fully wet
const GOUGE_FULL := 4.0  # mm that reads as the deepest gouge
const FREEZE_K := 0.00033  # per second per degree below zero at 1 mm

## Metres per cell.
var cell := 0.025
## Vertical exaggeration of the heightfield (1 = true millimetres).
var height_scale := 4.0
## How long a frame may spend uploading and re-meshing dirty chunks.
var budget_ms := 3.0

var size := Vector2(24.0, 14.0)
var w := 0
var d := 0
var snow := PackedFloat32Array()  # mm
var water := PackedFloat32Array()  # mm
var frozen := PackedFloat32Array()  # 0..1 of the water that has set
var cut := PackedFloat32Array()  # 0..1
var ang := PackedFloat32Array()  # radians
var gouge := PackedFloat32Array()  # mm
var material: ShaderMaterial
var remeshed := 0
var wet_cells := 0

var _cw := 0
var _cd := 0
var _state_img: Image
var _cut_img: Image
var _state_tex: ImageTexture
var _cut_tex: ImageTexture
var _chunks := {}  # Vector2i -> MeshInstance3D
var _dirty := {}  # Vector2i -> true
var _wet := {}  # cell index -> true, cells with liquid water
var _thermal_cursor := 0


func setup(size_m: Vector2, cell_m := 0.025) -> void:
	size = size_m
	cell = cell_m
	w = int(round(size.x / cell))
	d = int(round(size.y / cell))
	for arr in [snow, water, frozen, cut, ang, gouge]:
		arr.resize(w * d)
		arr.fill(0.0)
	_cw = ceili(float(w) / CHUNK)
	_cd = ceili(float(d) / CHUNK)
	_state_img = Image.create(w, d, false, Image.FORMAT_RGBA8)
	_cut_img = Image.create(w, d, false, Image.FORMAT_RGBA8)
	_state_tex = ImageTexture.create_from_image(_state_img)
	_cut_tex = ImageTexture.create_from_image(_cut_img)
	material = ShaderMaterial.new()
	material.shader = load("res://framework/render/ice_sheet.gdshader")
	material.set_shader_parameter("state", _state_tex)
	material.set_shader_parameter("cutmap", _cut_tex)
	material.set_shader_parameter("sheet", size)
	material.set_shader_parameter("stria_n", striation_normal())
	material.set_shader_parameter("snow_n", noise_normal(0.12, 2, 5.0, 9))
	material.set_shader_parameter("ripple_n", noise_normal(0.02, 3, 2.0, 4))
	for c in _chunks.values():
		c.queue_free()
	_chunks.clear()
	_dirty.clear()
	_wet.clear()
	remeshed = 0
	for cz in _cd:
		for cx in _cw:
			_dirty[Vector2i(cx, cz)] = true


## Lines and logos drawn under the ice (a texture over the whole sheet).
func set_markings(tex: Texture2D) -> void:
	material.set_shader_parameter("markings", tex)
	material.set_shader_parameter("has_markings", tex != null)


func index(x: int, z: int) -> int:
	return z * w + x


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))


func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < w and z < d


func chunk_count() -> int:
	return _chunks.size()


func dirty_count() -> int:
	return _dirty.size()


# --- writing the columns ---------------------------------------------------


## Every cell to one state: snow mm, cut amount, water mm, frozen 0..1.
func fill_state(sn: float, ct: float, wt: float, fz: float, angle := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in w * d:
		snow[i] = sn * (0.85 + 0.15 * rng.randf()) if sn > 0.0 else 0.0
		cut[i] = ct
		ang[i] = angle
		water[i] = wt
		frozen[i] = fz
		gouge[i] = 0.0
	_wet.clear()
	if wt > 0.0 and fz < 1.0:
		for i in w * d:
			_wet[i] = true
	for key in _chunks.keys():
		_dirty[key] = true
	for cz in _cd:
		for cx in _cw:
			_dirty[Vector2i(cx, cz)] = true


## A puddle: `mm` of water in a disc `width` metres across, deeper in the
## middle, taking the snow with it and starting liquid.
func pour(at: Vector2, width: float, mm: float) -> void:
	var c := cell_at(at)
	var r := int(ceil(width * 0.5 / cell))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var z := c.y + dz
			if not in_bounds(x, z):
				continue
			var f := 1.0 - Vector2(dx, dz).length() / r
			if f <= 0.0:
				continue
			var i := index(x, z)
			var add := mm * clampf(f * 1.5, 0.0, 1.0)
			# new water over set water: the whole column is liquid again in proportion
			var old_liquid := water[i] * (1.0 - frozen[i])
			water[i] = minf(water[i] + add, 4.0)
			frozen[i] = (
				clampf(1.0 - (old_liquid + add) / water[i], 0.0, 1.0) if water[i] > 0.0 else 0.0
			)
			if frozen[i] < 0.001:
				frozen[i] = 0.0
			snow[i] = 0.0
			_wet[i] = true
			_touch(x, z)


## A blade stroke from a to b: cut at the stroke's angle `width` m wide,
## a gouge `depth` mm along it, snow thrown to its sides.
func stroke(
	a: Vector2, b: Vector2, width: float, strength: float, depth: float, snow_mm: float
) -> void:
	var dir := (b - a).normalized()
	var angle := dir.angle()
	var steps := int(a.distance_to(b) / cell)
	var r := int(ceil(width * 2.5 / cell)) + 1
	for s in steps:
		var c := cell_at(a + dir * (s * cell))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := c.x + dx
				var z := c.y + dz
				if not in_bounds(x, z):
					continue
				var dist := Vector2(dx, dz).length() * cell
				var i := index(x, z)
				if dist <= width:
					cut[i] = maxf(cut[i], strength)
					ang[i] = angle
					gouge[i] = maxf(gouge[i], depth * (1.0 - dist / width))
					_touch(x, z)
				elif dist <= width * 2.5 and snow_mm > 0.0:
					snow[i] = clampf(snow[i] + snow_mm * 0.25, 0.0, 3.0)
					_touch(x, z)


## A resurfacer pass over a band (x range, z range in metres): shaved to a
## fresh cut along x, gouges and snow gone, `film_mm` of water left wet.
func resurface(x0: float, x1: float, z0: float, z1: float, film_mm := 0.8) -> void:
	var c0 := cell_at(Vector2(minf(x0, x1), minf(z0, z1)))
	var c1 := cell_at(Vector2(maxf(x0, x1), maxf(z0, z1)))
	for z in range(maxi(c0.y, 0), mini(c1.y + 1, d)):
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
			var i := index(x, z)
			cut[i] = 0.35
			ang[i] = 0.0
			snow[i] = 0.0
			gouge[i] = 0.0
			water[i] = film_mm
			frozen[i] = 0.0
			if film_mm > 0.0:
				_wet[i] = true
			_touch(x, z)


## The freezing step: `dt` seconds of sim time with the slab at `slab_c`
## and the air at `air_c`. Walks the wet cells in slices so a whole wet
## sheet costs a few milliseconds a frame rather than one long stall.
func thermal(dt: float, slab_c: float, air_c: float, max_cells := 40000) -> void:
	if _wet.is_empty():
		wet_cells = 0
		return
	var keys := _wet.keys()
	wet_cells = keys.size()
	var n := mini(max_cells, keys.size())
	var slice_dt := dt * float(keys.size()) / n  # each cell is visited every size/n calls
	var cold := maxf(0.0, -slab_c)
	var air := clampf(1.0 - air_c / 30.0, 0.3, 1.2)
	for k in n:
		var i: int = keys[(_thermal_cursor + k) % keys.size()]
		if water[i] <= 0.0 or frozen[i] >= 1.0:
			_wet.erase(i)
			continue
		var x := i % w
		var z := i / w
		# an edge: a neighbour that is dry or set pulls heat sideways too
		var edge := 0.0
		for nb in [
			index(maxi(x - 1, 0), z),
			index(mini(x + 1, w - 1), z),
			index(x, maxi(z - 1, 0)),
			index(x, mini(z + 1, d - 1))
		]:
			if water[nb] <= 0.0 or frozen[nb] >= 0.999:
				edge += 0.5
		var rate := FREEZE_K * cold * air * (1.0 + edge) / maxf(water[i], 0.3)
		frozen[i] = minf(frozen[i] + rate * slice_dt, 1.0)
		if frozen[i] >= 1.0:
			_wet.erase(i)
		_touch(x, z)
	_thermal_cursor = (_thermal_cursor + n) % maxi(keys.size(), 1)


func _touch(x: int, z: int) -> void:
	_dirty[Vector2i(x / CHUNK, z / CHUNK)] = true


# --- to the GPU, a few chunks a frame --------------------------------------


func _process(_dt: float) -> void:
	if _dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var limit := int(budget_ms * 1000.0)
	var any := false
	for key in _dirty.keys():
		_build_chunk(key)
		_dirty.erase(key)
		any = true
		if Time.get_ticks_usec() - t0 > limit:
			break
	if any:
		_state_tex.update(_state_img)
		_cut_tex.update(_cut_img)


## Everything now (loading, tests).
func flush() -> void:
	for key in _dirty.keys():
		_build_chunk(key)
	_dirty.clear()
	_state_tex.update(_state_img)
	_cut_tex.update(_cut_img)


func _build_chunk(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var x1 := mini(x0 + CHUNK, w)
	var z1 := mini(z0 + CHUNK, d)
	var flat := true
	for z in range(z0, z1):
		for x in range(x0, x1):
			var i := index(x, z)
			_state_img.set_pixel(
				x,
				z,
				Color(
					clampf(snow[i] / SNOW_FULL, 0.0, 1.0),
					cut[i],
					clampf(water[i] / WATER_FULL, 0.0, 1.0),
					frozen[i]
				)
			)
			_cut_img.set_pixel(
				x,
				z,
				Color(fposmod(ang[i], TAU) / TAU, clampf(gouge[i] / GOUGE_FULL, 0.0, 1.0), 0.0, 1.0)
			)
			if snow[i] > 0.0 or water[i] > 0.0 or gouge[i] > 0.0:
				flat = false
	var mi: MeshInstance3D = _chunks.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = material
		add_child(mi)
		_chunks[key] = mi
	mi.mesh = _flat_quad(x0, z0, x1, z1) if flat else _heightfield(x0, z0, x1, z1)
	remeshed += 1


func _height(x: int, z: int) -> float:
	var i := index(mini(x, w - 1), mini(z, d - 1))
	return (snow[i] + water[i] * 0.6 - gouge[i]) * 0.001 * height_scale


func _flat_quad(x0: int, z0: int, x1: int, z1: int) -> ArrayMesh:
	var verts := PackedVector3Array(
		[
			Vector3(x0 * cell, 0, z0 * cell),
			Vector3(x1 * cell, 0, z0 * cell),
			Vector3(x0 * cell, 0, z1 * cell),
			Vector3(x1 * cell, 0, z1 * cell)
		]
	)
	var uvs := PackedVector2Array(
		[
			Vector2(float(x0) / w, float(z0) / d),
			Vector2(float(x1) / w, float(z0) / d),
			Vector2(float(x0) / w, float(z1) / d),
			Vector2(float(x1) / w, float(z1) / d)
		]
	)
	var norms := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0, 1, 2, 1, 3, 2])
	return _mesh(verts, norms, uvs, idx)


func _heightfield(x0: int, z0: int, x1: int, z1: int) -> ArrayMesh:
	var nx := x1 - x0 + 1
	var nz := z1 - z0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	uvs.resize(nx * nz)
	for z in nz:
		for x in nx:
			var gx := x0 + x
			var gz := z0 + z
			var k := z * nx + x
			verts[k] = Vector3(gx * cell, _height(gx, gz), gz * cell)
			uvs[k] = Vector2(float(gx) / w, float(gz) / d)
			var hl := _height(maxi(gx - 1, 0), gz)
			var hr := _height(gx + 1, gz)
			var hd := _height(gx, maxi(gz - 1, 0))
			var hu := _height(gx, gz + 1)
			norms[k] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
	for z in nz - 1:
		for x in nx - 1:
			var a := z * nx + x
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	return _mesh(verts, norms, uvs, idx)


static func _mesh(
	verts: PackedVector3Array,
	norms: PackedVector3Array,
	uvs: PackedVector2Array,
	idx: PackedInt32Array
) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# --- detail maps (generated once, shared) ----------------------------------

static var _stria: Texture2D


static func noise_normal(freq: float, octaves: int, strength: float, seed_: int) -> Texture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_
	var t := NoiseTexture2D.new()
	t.noise = n
	t.as_normal_map = true
	t.bump_strength = strength
	t.width = 256
	t.height = 256
	t.seamless = true
	return t


## Parallel grooves with a little wander, tiling: the blade's striations.
static func striation_normal() -> Texture2D:
	if _stria:
		return _stria
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var phase := PackedFloat32Array()
	phase.resize(size)
	for v in size:
		phase[v] = rng.randf() * 0.4
	var k := TAU / size
	for v in size:
		for u in size:
			var g := (
				sin(u * k * 37.0 + phase[v])
				+ 0.6 * sin(u * k * 94.0 + 1.7 * phase[v])
				+ 0.3 * sin(u * k * 209.0)
			)
			var slope := clampf(g * 0.35, -1.0, 1.0)
			img.set_pixel(u, v, Color(0.5 + 0.35 * slope, 0.5, 1.0))
	img.generate_mipmaps()
	_stria = ImageTexture.create_from_image(img)
	return _stria
