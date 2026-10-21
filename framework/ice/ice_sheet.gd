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
## minutes; the sim's IceSlab is the source of those numbers. Water that
## has set becomes ice: it joins the column's `ice` thickness (water
## expands 9%), so flooding the same spot again and again builds it up,
## and the new surface is fresh frozen (no cut, no snow). Liquid water
## flows: each visit a wet cell sends part of its head (ice + crust +
## water - gouge) difference to each lower neighbour, except the last
## FILM_PIN that clings to the ice, so a pour spreads into a pool, runs
## downhill, fills gouges and pins as a film at its rim.

const CHUNK := 64  # cells a side
const SNOW_FULL := 1.0  # mm that reads as fully snowed
const WATER_FULL := 0.5  # mm that reads as fully wet
const GOUGE_FULL := 4.0  # mm that reads as the deepest gouge
const FREEZE_K := 0.00033  # per second per degree below zero at 1 mm
const ICE_PER_WATER := 1.09
const FILM_PIN := 0.2  # mm of water that clings to the ice and never runs
const FLOW_K := 0.45  # share of the head difference that moves a visit
const FLAT_EPS := 0.00002  # m of height range a chunk may have and still be one quad

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
var ang := PackedFloat32Array()  # radians: the blade's travel; striations run along it
var gouge := PackedFloat32Array()  # mm
var ice := PackedFloat32Array()  # mm of ice built up over the base by floods
var scar := PackedFloat32Array()  # mm of gouge that water filled: faintly visible, no depth
var crust := PackedFloat32Array()  # mm of slush that set: a rough surface with peaks
var material: ShaderMaterial
var remeshed := 0
var wet_cells := 0

var _cw := 0
var _cd := 0
var _state_img: Image
var _cut_img: Image
var _state_bytes := PackedByteArray()
var _cut_bytes := PackedByteArray()
var _state_tex: ImageTexture
var _cut_tex: ImageTexture
var _chunks := {}  # Vector2i -> MeshInstance3D
var _dirty := {}  # Vector2i -> true
var _wet := {}  # cell index -> true, cells with liquid water
var _wet_list := PackedInt32Array()  # the set as a list, walked in slices
var _wet_next := PackedInt32Array()  # the live cells seen this pass: the next list
var _thermal_cursor := 0


func setup(size_m: Vector2, cell_m := 0.025) -> void:
	size = size_m
	cell = cell_m
	w = int(round(size.x / cell))
	d = int(round(size.y / cell))
	for arr in [snow, water, frozen, cut, ang, gouge, ice, scar, crust]:
		arr.resize(w * d)
		arr.fill(0.0)
	_cw = ceili(float(w) / CHUNK)
	_cd = ceili(float(d) / CHUNK)
	_state_bytes.resize(w * d * 4)
	_cut_bytes.resize(w * d * 4)
	_state_img = Image.create_from_data(w, d, false, Image.FORMAT_RGBA8, _state_bytes)
	_cut_img = Image.create_from_data(w, d, false, Image.FORMAT_RGBA8, _cut_bytes)
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
	_wet_list.resize(0)
	_wet_next.resize(0)
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
		ice[i] = 0.0
		scar[i] = 0.0
		crust[i] = 0.0
	_wet.clear()
	_wet_list.resize(0)
	_wet_next.resize(0)
	_thermal_cursor = 0
	if wt > 0.0 and fz < 1.0:
		_wet_list.resize(w * d)
		for i in w * d:
			_wet[i] = true
			_wet_list[i] = i
	for key in _chunks.keys():
		_dirty[key] = true
	for cz in _cd:
		for cx in _cw:
			_dirty[Vector2i(cx, cz)] = true


## A puddle: `mm` of water in a disc `width` metres across, deeper in the
## middle, starting liquid. Snow it lands on stays in the column as slush
## and sets with the water into a rough crust.
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
			# new water over water still setting: the column is liquid again in proportion
			var old_liquid := water[i] * (1.0 - frozen[i])
			water[i] = minf(water[i] + add, 8.0)
			frozen[i] = (
				clampf(1.0 - (old_liquid + add) / water[i], 0.0, 1.0) if water[i] > 0.0 else 0.0
			)
			if frozen[i] < 0.001:
				frozen[i] = 0.0
			_wet_add(i)
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


## A chip: a round gouge `width` metres across, `depth` mm in the middle
## and shallowing to the rim, with snow thrown in a ring around it.
func chip(at: Vector2, width: float, depth: float, snow_mm := 0.0) -> void:
	var c := cell_at(at)
	var r := int(ceil(width * 0.5 / cell)) + 1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var z := c.y + dz
			if not in_bounds(x, z):
				continue
			var dist := Vector2(dx, dz).length() * cell
			var i := index(x, z)
			if dist <= width * 0.5:
				gouge[i] = maxf(gouge[i], depth * (1.0 - dist / (width * 0.5)))
				cut[i] = maxf(cut[i], 0.6)
				_touch(x, z)
			elif dist <= width * 0.9 and snow_mm > 0.0:
				snow[i] = clampf(snow[i] + snow_mm * 0.3, 0.0, 3.0)
				_touch(x, z)


## The resurfacer over a band (x range, z range in metres): the blade at
## `blade_mm` above the base shaves off everything higher. Snow has
## height: a blade above the snow touches nothing, a blade in the snow
## shaves only snow, and a blade in the solid (built-up ice, crust peaks)
## takes the snow with it and cuts the ice; below zero it cuts into the
## base and takes gouge depth with it. Where it cut the solid it leaves
## a dry cut with striations along `travel`, the blade's direction
## (radians in the sheet's plane). The shavings go up the auger into the
## tank; `spill` (0 by default) leaves that share as a ridge of snow
## along the band's sides, the mark of a worn or badly set conditioner. In flood mode (`film_mm` > 0) the
## conditioner's rag lays the water behind the blade: a new rag
## (`rag_wear` 0) an even film, a worn one (1) streaks and a coarser cut.
## Returns the millimetres shaved, summed over the band's cells.
func resurface(
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	film_mm := 0.8,
	rag_wear := 0.0,
	blade_mm := 0.0,
	travel := 0.0,
	spill := 0.0
) -> float:
	var c0 := cell_at(Vector2(minf(x0, x1), minf(z0, z1)))
	var c1 := cell_at(Vector2(maxf(x0, x1), maxf(z0, z1)))
	var shaved := 0.0
	var touched_z := {}
	for z in range(maxi(c0.y, 0), mini(c1.y + 1, d)):
		var streak := 1.0 + rag_wear * 0.6 * sin(z * cell * 41.0) * sin(z * cell * 7.3)
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
			var i := index(x, z)
			# the column's top: ice, the tallest crust peak, loose snow on it.
			# Snow has height: a blade above the snow touches nothing, a blade
			# in the snow shaves only snow, a blade in the solid takes the snow
			# with it and cuts the ice
			var solid := ice[i] + crust[i]
			var top := solid + snow[i]
			var took := 0.0
			if top > blade_mm:
				if blade_mm > solid:
					var keep := blade_mm - solid
					took += snow[i] - keep
					snow[i] = keep
				else:
					took += snow[i]
					snow[i] = 0.0
					var level := maxf(blade_mm, 0.0)
					if solid > level:
						var cut_mm := solid - level
						took += cut_mm
						# peaks go first, then the ice under them
						var from_crust := minf(crust[i], cut_mm)
						crust[i] -= from_crust
						ice[i] -= cut_mm - from_crust
					if blade_mm < 0.0 and gouge[i] > 0.0:
						# below the base: the blade takes the surface the gouge is in
						var dig := minf(gouge[i], -blade_mm)
						gouge[i] -= dig
						scar[i] = maxf(scar[i] - dig, 0.0)
					cut[i] = lerpf(0.75, 0.5, rag_wear) if film_mm > 0.0 else 0.75
					ang[i] = travel
					touched_z[z] = true
			if film_mm > 0.0:
				water[i] = film_mm * streak
				frozen[i] = 0.0
				_wet_add(i)
			shaved += took
			_touch(x, z)
	# the shavings go up the auger into the tank; a side spill is a flaw
	# of a worn or badly set conditioner, so it is off by default
	if shaved > 0.0 and spill > 0.0:
		var per := shaved / maxf(float(c1.x - c0.x + 1), 1.0) * spill
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
			for z in [c0.y - 1, c1.y + 1]:
				if in_bounds(x, z):
					var i := index(x, z)
					snow[i] = clampf(snow[i] + per, 0.0, 3.0)
					_touch(x, z)
	return shaved


## The freezing step: `dt` seconds of sim time with the slab at `slab_c`
## and the air at `air_c`. Walks the wet cells in slices (`max_cells` a
## call) so a whole wet sheet costs a couple of milliseconds a frame
## rather than one long stall; each cell is visited every size/max_cells
## calls and gets that much time. Deep water runs to lower neighbours on
## the way. The loop is written flat (no calls, no allocations per cell)
## because it is the hot path: about half a microsecond a cell.
func thermal(dt: float, slab_c: float, air_c: float, max_cells := 3000) -> void:
	if _wet.is_empty():
		wet_cells = 0
		_wet_list.resize(0)
		_wet_next.resize(0)
		_thermal_cursor = 0
		return
	if _thermal_cursor >= _wet_list.size():
		# a pass is done: the live cells seen on the way are the next list
		_wet_list = _wet_next
		_wet_next = PackedInt32Array()
		_thermal_cursor = 0
		if _wet_list.is_empty():
			_wet_list = PackedInt32Array(_wet.keys())
	wet_cells = _wet.size()
	var n := mini(max_cells, _wet_list.size() - _thermal_cursor)
	var per_pass := float(_wet_list.size()) / maxi(mini(max_cells, _wet_list.size()), 1)
	var slice_dt := dt * per_pass
	var cold := maxf(0.0, -slab_c)
	var air := clampf(1.0 - air_c / 30.0, 0.3, 1.2)
	var k_air := FREEZE_K * cold * air * slice_dt
	var last := w * d - 1
	for k in n:
		var i := _wet_list[_thermal_cursor + k]
		if not _wet.has(i):
			continue
		var wt := water[i]
		if wt <= 0.0:
			_wet.erase(i)
			continue
		var fz := frozen[i]
		# neighbours (clamped at the rim); an edge that is dry or set pulls heat sideways
		var il := i - 1 if i % w > 0 else i
		var ir := i + 1 if i % w < w - 1 else i
		var iu := i - w if i >= w else i
		var id := i + w if i + w <= last else i
		var edge := 0.0
		if water[il] <= 0.0 or frozen[il] >= 0.999:
			edge += 0.5
		if water[ir] <= 0.0 or frozen[ir] >= 0.999:
			edge += 0.5
		if water[iu] <= 0.0 or frozen[iu] >= 0.999:
			edge += 0.5
		if water[id] <= 0.0 or frozen[id] >= 0.999:
			edge += 0.5
		# liquid runs downhill (a gouge is downhill) by head, all but the film;
		# water that has started to set is slush and stays put
		var liquid := wt * (1.0 - fz)
		if liquid > FILM_PIN and fz < 0.4:
			# only worth the call when a neighbour is actually lower
			var here := ice[i] + crust[i] + wt - gouge[i]
			var low := minf(
				minf(
					ice[il] + crust[il] + water[il] - gouge[il],
					ice[ir] + crust[ir] + water[ir] - gouge[ir]
				),
				minf(
					ice[iu] + crust[iu] + water[iu] - gouge[iu],
					ice[id] + crust[id] + water[id] - gouge[id]
				)
			)
			if here - low > 0.06:
				_flow(i, il, ir, iu, id, liquid)
				wt = water[i]
		var before := int(fz * 255.0)
		fz += k_air * (1.0 + edge) / maxf(wt, 0.3)
		if fz >= 1.0:
			# set through: it fills the gouge first (a scar stays visible,
			# no depth), the rest is new ice; a fresh frozen surface either way
			var set_mm := wt * ICE_PER_WATER
			var filled := minf(gouge[i], set_mm)
			gouge[i] -= filled
			scar[i] += filled
			ice[i] += set_mm - filled
			if snow[i] > 0.0:
				# slush: the snow froze in with the water as a rough crust of peaks
				crust[i] += snow[i] + set_mm * 0.5
				snow[i] = 0.0
			water[i] = 0.0
			frozen[i] = 0.0
			cut[i] = 0.0
			_wet.erase(i)
			_dirty[Vector2i((i % w) / CHUNK, (i / w) / CHUNK)] = true
		else:
			frozen[i] = fz
			_wet_next.append(i)
			if int(fz * 255.0) != before:
				_dirty[Vector2i((i % w) / CHUNK, (i / w) / CHUNK)] = true
	_thermal_cursor += n


func _wet_add(i: int) -> void:
	if not _wet.has(i):
		_wet[i] = true
		_wet_list.append(i)


func _flow(i: int, il: int, ir: int, iu: int, id: int, liquid: float) -> void:
	var here := ice[i] + crust[i] + water[i] - gouge[i]
	var spare := liquid - FILM_PIN
	for nb in [il, ir, iu, id]:
		if nb == i or spare <= 0.0:
			continue
		var diff := here - (ice[nb] + crust[nb] + water[nb] - gouge[nb])
		if diff <= 0.06:
			continue  # level enough: it sits (no sloshing back and forth)
		var give := minf(diff * 0.5 * FLOW_K, spare * 0.25)
		water[i] -= give
		spare -= give
		var had := water[nb]
		water[nb] += give
		if had > 0.0:
			frozen[nb] *= had / (had + give)  # diluted by the new water
		else:
			frozen[nb] = 0.0
		_wet_add(nb)
		_touch(nb % w, nb / w)


## Sets every wet cell at once (a test rig's instant freeze).
func set_now() -> void:
	while not _wet.is_empty():
		thermal(1.0e9, -5.0, 0.0, _wet.size())
	_wet_list.resize(0)
	_wet_next.resize(0)
	_thermal_cursor = 0


## The column's top above the base at a point, mm: ice, crust peaks, snow.
func top_at(p: Vector2) -> float:
	var c := cell_at(p)
	if not in_bounds(c.x, c.y):
		return 0.0
	var i := index(c.x, c.y)
	return ice[i] + crust[i] + snow[i]


## Built-up ice (mm) at a point, for a caliper or a test.
func ice_at(p: Vector2) -> float:
	var c := cell_at(p)
	return ice[index(c.x, c.y)] if in_bounds(c.x, c.y) else 0.0


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
		_upload()


## Everything now (loading, tests).
func flush() -> void:
	for key in _dirty.keys():
		_build_chunk(key)
	_dirty.clear()
	_upload()


func _upload() -> void:
	_state_img.set_data(w, d, false, Image.FORMAT_RGBA8, _state_bytes)
	_cut_img.set_data(w, d, false, Image.FORMAT_RGBA8, _cut_bytes)
	_state_tex.update(_state_img)
	_cut_tex.update(_cut_img)


func _build_chunk(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var x1 := mini(x0 + CHUNK, w)
	var z1 := mini(z0 + CHUNK, d)
	var lo := INF
	var hi := -INF
	for z in range(z0, z1):
		for x in range(x0, x1):
			var i := index(x, z)
			var b := i * 4
			_state_bytes[b] = int(clampf(snow[i] / SNOW_FULL, 0.0, 1.0) * 255.0)
			_state_bytes[b + 1] = int(clampf(cut[i], 0.0, 1.0) * 255.0)
			_state_bytes[b + 2] = int(clampf(water[i] / WATER_FULL, 0.0, 1.0) * 255.0)
			_state_bytes[b + 3] = int(clampf(frozen[i], 0.0, 1.0) * 255.0)
			_cut_bytes[b] = int(fposmod(ang[i], TAU) / TAU * 255.0)
			_cut_bytes[b + 1] = int(clampf(gouge[i] / GOUGE_FULL, 0.0, 1.0) * 255.0)
			_cut_bytes[b + 2] = int(clampf(scar[i] / GOUGE_FULL, 0.0, 1.0) * 255.0)
			_cut_bytes[b + 3] = int(clampf(crust[i] / GOUGE_FULL, 0.0, 1.0) * 255.0)
			var h := _height(x, z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	# the border row shared with the next chunk counts too
	for x in range(x0, x1 + 1):
		var h := _height(x, z1)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	for z in range(z0, z1 + 1):
		var h := _height(x1, z)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var mi: MeshInstance3D = _chunks.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = material
		add_child(mi)
		_chunks[key] = mi
	# a level chunk (dry, or an even film, or built-up ice all one height) is one quad
	mi.mesh = _flat_quad(x0, z0, x1, z1, lo) if hi - lo < FLAT_EPS else _heightfield(x0, z0, x1, z1)
	remeshed += 1


func _height(x: int, z: int) -> float:
	var i := index(mini(x, w - 1), mini(z, d - 1))
	# crust is peaks: each column its own height within the crust depth
	var peak := crust[i] * (0.4 + 0.6 * _hash(i))
	return (ice[i] + snow[i] + peak + water[i] * 0.6 - gouge[i]) * 0.001 * height_scale


static func _hash(i: int) -> float:
	var x := (i * 1103515245 + 12345) & 0x7fffffff
	return float((x >> 8) & 0xffff) / 65535.0


func _flat_quad(x0: int, z0: int, x1: int, z1: int, y := 0.0) -> ArrayMesh:
	var verts := PackedVector3Array(
		[
			Vector3(x0 * cell, y, z0 * cell),
			Vector3(x1 * cell, y, z0 * cell),
			Vector3(x0 * cell, y, z1 * cell),
			Vector3(x1 * cell, y, z1 * cell)
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


## The blade's striations as a tiling normal map over one metre: grooves
## 5 to 10 mm wide at random spacing and depth, running the full length
## with a slow wander, so a cut reads as long random lines rather than a
## comb. U runs across the grooves.
static func striation_normal() -> Texture2D:
	if _stria:
		return _stria
	var size := 1024  # 1 mm per texel over the metre
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var u := 0.0
	while u < size:
		u += rng.randf_range(3.0, 22.0)  # the gap to the next groove
		var width := rng.randf_range(5.0, 10.0)
		var depth := rng.randf_range(0.25, 1.0)
		var wander := rng.randf_range(-6.0, 6.0)
		var phase := rng.randf() * TAU
		for v in size:
			# the groove drifts sideways along its length, back to where it
			# started at the tile edge so it tiles
			var drift := wander * sin(float(v) / size * TAU + phase) - wander * sin(phase)
			var centre := u + drift
			for k in int(ceil(width)) + 2:
				var px := int(floor(centre - width * 0.5)) + k
				var t := (px + 0.5 - centre) / (width * 0.5)  # -1..1 across the groove
				if t < -1.0 or t > 1.0:
					continue
				var slope := -t * depth  # a rounded trough: down on one side, up on the other
				var pxw := posmod(px, size)
				var c := img.get_pixel(pxw, v)
				img.set_pixel(pxw, v, Color(clampf(c.r + 0.4 * slope, 0.0, 1.0), 0.5, 1.0))
	img.generate_mipmaps()
	_stria = ImageTexture.create_from_image(img)
	return _stria
