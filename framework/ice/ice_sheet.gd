class_name IceSheet
extends Node3D
## The sheet of ice as columns: per cell (2.5 cm by default) loose snow,
## liquid water, how much of that water has set, the dry-cut amount and
## its angle, and gouge depth. Two data textures carry the state to the
## ice shader (one texel per cell), and a chunked heightfield gives snow,
## water and gouges real height. Only dirty chunks are re-uploaded and
## re-meshed, a few per frame. The textures are tiles of 256 cells a side
## (4 chunks), each with its own copy of the material, so a change uploads
## one tile's 768 KB rather than the whole sheet's 30 MB. A corner radius
## makes the sheet a rink: columns outside the arcs are not ice, nothing
## writes them, water does not run into them and the shader leaves them out.
##
##   var ice := IceSheet.new()
##   add_child(ice)
##   ice.setup(Vector2(60.96, 25.9), 0.025, 8.5)  # metres, per cell, corner radius
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
const TILE := 256  # cells a side of one set of state textures (4 chunks)
const SNOW_FULL := 1.0  # mm that reads as fully snowed
const WATER_FULL := 0.5  # mm that reads as fully wet
const GOUGE_FULL := 4.0  # mm that reads as the deepest gouge
const FREEZE_K := 0.00033  # per second per degree below zero at 1 mm
const ICE_PER_WATER := 1.09
const FILM_PIN := 0.2  # mm of water that clings to the ice and never runs
const FLOW_K := 0.45  # share of the head difference that moves a visit
const FLAT_EPS := 0.00002  # m of height range a chunk may have and still be one quad
const DEPTH_FULL := 64.0  # mm the depth texel spans
const POOL_FULL := 8.0  # mm of water the depth texel's green spans: a pool's depth

static var _stria: Texture2D  # the striation map, generated once

## Metres per cell.
var cell := 0.025
## Ice over the paint at the datum, mm: the lines are painted at a fixed
## depth and read vivid through thin ice, faded and blue through thick.
var base_mm := 25.0
## Vertical exaggeration of the heightfield (1 = true millimetres).
var height_scale := 4.0
## How long a frame may spend uploading and re-meshing dirty chunks.
var budget_ms := 3.0

var size := Vector2(24.0, 14.0)
## Corner radius in metres (0 is a rectangle).
var corner := 0.0
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
## The last resurface() call's shavings by row (mm summed over the row's
## cells), from `shave_z0` on: what the conditioner's auger has to carry.
var shave_rows := PackedFloat32Array()
var shave_z0 := 0
var wet_cells := 0

var _cw := 0
var _cd := 0
var _tw := 0
var _td := 0
var _mask := PackedByteArray()  # 1 where the column is ice (inside the corner arcs)
var _outside := PackedInt32Array()  # the columns that are not ice
var _keys: Array[Vector2i] = []  # the chunks that hold any ice
var _full := {}  # Vector2i -> true, chunks with no column outside the arcs
var _uniform := {}  # Vector2i -> true, full chunks untouched since the last fill
var _tiles := {}  # Vector2i -> Tile
var _tile_dirty := {}  # Vector2i -> true, tiles with a rebuilt chunk to upload
var _chunks := {}  # Vector2i -> MeshInstance3D
var _dirty := {}  # Vector2i -> true
var _wet_flag := PackedByteArray()  # 1 per cell with liquid water
var _wet_n := 0
var _wet_list := PackedInt32Array()  # the wet set as a list, walked in slices
var _wet_next := PackedInt32Array()  # the live cells seen this pass: the next list
var _thermal_cursor := 0


## One tile of the state textures (TILE cells a side) and the material
## that samples them. The images are the store: a cell is a set_pixel, a
## uniform chunk one fill_rect, an upload one update per image.
class Tile:
	var state_img: Image
	var cut_img: Image
	var depth_img: Image
	var state_tex: ImageTexture
	var cut_tex: ImageTexture
	var depth_tex: ImageTexture
	var material: ShaderMaterial


func setup(size_m: Vector2, cell_m := 0.025, corner_m := 0.0) -> void:
	size = size_m
	cell = cell_m
	corner = corner_m
	w = int(round(size.x / cell))
	d = int(round(size.y / cell))
	for arr in [snow, water, frozen, cut, ang, gouge, ice, scar, crust]:
		arr.resize(w * d)
		arr.fill(0.0)
	_wet_flag.resize(w * d)
	_wet_flag.fill(0)
	_wet_n = 0
	_build_mask()
	_cw = ceili(float(w) / CHUNK)
	_cd = ceili(float(d) / CHUNK)
	_tw = ceili(float(_cw) / (TILE / CHUNK))
	_td = ceili(float(_cd) / (TILE / CHUNK))
	material = ShaderMaterial.new()
	material.shader = load("res://framework/render/ice_sheet.gdshader")
	material.set_shader_parameter("sheet", size)
	material.set_shader_parameter("corner_r", corner)
	material.set_shader_parameter("stria_n", striation_normal())
	material.set_shader_parameter("snow_n", noise_normal(0.12, 2, 5.0, 9))
	material.set_shader_parameter("ripple_n", noise_normal(0.02, 3, 2.0, 4))
	for c in _chunks.values():
		c.queue_free()
	_chunks.clear()
	_dirty.clear()
	_tiles.clear()
	_tile_dirty.clear()
	_wet_list.resize(0)
	_wet_next.resize(0)
	_thermal_cursor = 0
	remeshed = 0
	for tz in _td:
		for tx in _tw:
			_tiles[Vector2i(tx, tz)] = _make_tile(tx, tz)
	_keys.clear()
	_full.clear()
	_uniform.clear()
	for cz in _cd:
		for cx in _cw:
			var key := Vector2i(cx, cz)
			var rows := _chunk_ice(key)
			if rows.x > 0:
				_keys.append(key)
				_dirty[key] = true
			if rows.y == mini(cz * CHUNK + CHUNK, d) - cz * CHUNK:
				_full[key] = true


## The mask: 1 where the column is inside the corner arcs. The arcs'
## centres sit `corner` in from each corner.
func _build_mask() -> void:
	_mask.resize(w * d)
	_mask.fill(1)
	_outside.resize(0)
	if corner <= 0.0:
		return
	var r := corner / cell
	var rr := r * r
	var n := int(ceil(r))
	for cz in n:
		for cx in n:
			var dx := r - (cx + 0.5)
			var dz := r - (cz + 0.5)
			if dx * dx + dz * dz > rr:
				for i in [
					index(cx, cz),
					index(w - 1 - cx, cz),
					index(cx, d - 1 - cz),
					index(w - 1 - cx, d - 1 - cz)
				]:
					_mask[i] = 0
					_outside.append(i)


## How many of a chunk's rows hold any ice (x) and how many are ice end
## to end (y). The ice is convex and the corners are at the sheet's
## edges, so a row's ice always reaches one end of the chunk.
func _chunk_ice(key: Vector2i) -> Vector2i:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var x1 := mini(x0 + CHUNK, w) - 1
	var rows := Vector2i.ZERO
	for z in range(z0, mini(z0 + CHUNK, d)):
		var a := _mask[z * w + x0] == 1
		var b := _mask[z * w + x1] == 1
		if a or b:
			rows.x += 1
		if a and b:
			rows.y += 1
	return rows


func _make_tile(tx: int, tz: int) -> Tile:
	var t := Tile.new()
	t.state_img = Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	t.cut_img = Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	t.depth_img = Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	t.state_tex = ImageTexture.create_from_image(t.state_img)
	t.cut_tex = ImageTexture.create_from_image(t.cut_img)
	t.depth_tex = ImageTexture.create_from_image(t.depth_img)
	t.material = material.duplicate()
	t.material.set_shader_parameter("state", t.state_tex)
	t.material.set_shader_parameter("cutmap", t.cut_tex)
	t.material.set_shader_parameter("depthmap", t.depth_tex)
	t.material.set_shader_parameter("tile_off", Vector2(float(tx * TILE) / w, float(tz * TILE) / d))
	t.material.set_shader_parameter("tile_scale", Vector2(float(w) / TILE, float(d) / TILE))
	return t


## A shader parameter on the base material and every tile's copy.
func set_param(name: String, value: Variant) -> void:
	material.set_shader_parameter(name, value)
	for t: Tile in _tiles.values():
		t.material.set_shader_parameter(name, value)


## Ice over the paint at a column, mm (the datum's base plus what floods
## built up, less what a gouge took).
func paint_depth(i: int) -> float:
	return maxf(base_mm + ice[i] - gouge[i], 0.0)


## Re-reads every column (after a change of base_mm).
func mark_all_dirty() -> void:
	for key in _keys:
		_dirty[key] = true


## Lines and logos drawn under the ice (a texture over the whole sheet).
func set_markings(tex: Texture2D) -> void:
	set_param("markings", tex)
	set_param("has_markings", tex != null)


func index(x: int, z: int) -> int:
	return z * w + x


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))


func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < w and z < d


## In the sheet and inside the corner arcs: a column that is ice.
func is_ice(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < w and z < d and _mask[z * w + x] == 1


func chunk_count() -> int:
	return _chunks.size()


func dirty_count() -> int:
	return _dirty.size()


# --- writing the columns ---------------------------------------------------


## Every cell to one state: snow mm, cut amount, water mm, frozen 0..1.
func fill_state(sn: float, ct: float, wt: float, fz: float, angle := 0.0) -> void:
	cut.fill(ct)
	ang.fill(angle)
	water.fill(wt)
	frozen.fill(fz)
	for arr in [gouge, ice, scar, crust]:
		arr.fill(0.0)
	if sn > 0.0:
		# a little unevenness in the snow: one band of chunk rows is drawn
		# once and repeated down the sheet (the shader's grain hides the seam)
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		var band := PackedFloat32Array()
		band.resize(w * CHUNK)
		for i in band.size():
			band[i] = sn * (0.85 + 0.15 * rng.randf())
		snow.resize(0)
		for k in _cd:
			snow.append_array(band)
		snow.resize(w * d)
	else:
		snow.fill(0.0)
	_wet_list.resize(0)
	_wet_next.resize(0)
	_thermal_cursor = 0
	if wt > 0.0 and fz < 1.0:
		_wet_flag.fill(1)
		_wet_n = w * d
		_wet_list = PackedInt32Array(range(w * d))
	else:
		_wet_flag.fill(0)
		_wet_n = 0
	# the columns outside the corner arcs are not ice: nothing on them
	for i in _outside:
		snow[i] = 0.0
		cut[i] = 0.0
		water[i] = 0.0
		frozen[i] = 0.0
		if _wet_flag[i] == 1:
			_wet_flag[i] = 0
			_wet_n -= 1
	for key in _keys:
		_dirty[key] = true
	_uniform = _full.duplicate()


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
			if not is_ice(x, z):
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
				if not is_ice(x, z):
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
			if not is_ice(x, z):
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
## With `cut_mm` at or above zero the blade is set the way a real one is,
## a depth below the surface the sled rides on: the level is the band's
## mean solid height less the cut, so clean ice is thinned (the column's
## ice goes below the base, the paint nearer) and every pass makes snow;
## bumps are taken down more, dips less. Returns the millimetres shaved,
## summed over the band's cells.
func resurface(
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	film_mm := 0.8,
	rag_wear := 0.0,
	blade_mm := 0.0,
	travel := 0.0,
	spill := 0.0,
	cut_mm := -1.0
) -> float:
	var c0 := cell_at(Vector2(minf(x0, x1), minf(z0, z1)))
	var c1 := cell_at(Vector2(maxf(x0, x1), maxf(z0, z1)))
	if cut_mm >= 0.0:
		var sum := 0.0
		var n := 0
		for z in range(maxi(c0.y, 0), mini(c1.y + 1, d)):
			for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
				var i := index(x, z)
				if _mask[i] != 0:
					sum += ice[i] + crust[i]
					n += 1
		blade_mm = (sum / n if n > 0 else 0.0) - cut_mm
	var shaved := 0.0
	var touched_z := {}
	var z_lo := maxi(c0.y, 0)
	shave_z0 = z_lo
	shave_rows.resize(maxi(mini(c1.y + 1, d) - z_lo, 0))
	shave_rows.fill(0.0)
	for z in range(z_lo, mini(c1.y + 1, d)):
		var streak := 1.0 + rag_wear * 0.6 * sin(z * cell * 41.0) * sin(z * cell * 7.3)
		var row_took := 0.0
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
			var i := index(x, z)
			if _mask[i] == 0:
				continue
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
					var cut_here := solid - blade_mm
					if cut_here > 0.0:
						took += cut_here
						# peaks go first, then the ice under them
						var from_crust := minf(crust[i], cut_here)
						crust[i] -= from_crust
						ice[i] -= cut_here - from_crust
						if gouge[i] > 0.0:
							# the blade takes the surface the gouge is in with it
							var dig := minf(gouge[i], cut_here)
							gouge[i] -= dig
							scar[i] = maxf(scar[i] - dig, 0.0)
					cut[i] = lerpf(0.75, 0.5, rag_wear) if film_mm > 0.0 else 0.75
					ang[i] = travel
					touched_z[z] = true
			if film_mm > 0.0:
				water[i] = film_mm * streak
				frozen[i] = 0.0
				_wet_add(i)
			row_took += took
			_touch(x, z)
		shave_rows[z - z_lo] = row_took
		shaved += row_took
	# the shavings go up the auger into the tank; a side spill is a flaw
	# of a worn or badly set conditioner, so it is off by default
	if shaved > 0.0 and spill > 0.0:
		var per := shaved / maxf(float(c1.x - c0.x + 1), 1.0) * spill
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, w)):
			for z in [c0.y - 1, c1.y + 1]:
				if is_ice(x, z):
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
	if _wet_n == 0:
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
			_wet_list = _wet_scan()
	wet_cells = _wet_n
	var n := mini(max_cells, _wet_list.size() - _thermal_cursor)
	var per_pass := float(_wet_list.size()) / maxi(mini(max_cells, _wet_list.size()), 1)
	var slice_dt := dt * per_pass
	var cold := maxf(0.0, -slab_c)
	var air := clampf(1.0 - air_c / 30.0, 0.3, 1.2)
	var k_air := FREEZE_K * cold * air * slice_dt
	var last := w * d - 1
	for k in n:
		var i := _wet_list[_thermal_cursor + k]
		if _wet_flag[i] == 0:
			continue
		var wt := water[i]
		if wt <= 0.0:
			_wet_flag[i] = 0
			_wet_n -= 1
			continue
		var fz := frozen[i]
		# neighbours (clamped at the rim and at the corner arcs); an edge
		# that is dry or set pulls heat sideways
		var il := i - 1 if i % w > 0 and _mask[i - 1] == 1 else i
		var ir := i + 1 if i % w < w - 1 and _mask[i + 1] == 1 else i
		var iu := i - w if i >= w and _mask[i - w] == 1 else i
		var id := i + w if i + w <= last and _mask[i + w] == 1 else i
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
			_wet_flag[i] = 0
			_wet_n -= 1
			_touch(i % w, i / w)
		else:
			frozen[i] = fz
			_wet_next.append(i)
			if int(fz * 255.0) != before:
				_touch(i % w, i / w)
	_thermal_cursor += n


func _wet_add(i: int) -> void:
	if _wet_flag[i] == 0:
		_wet_flag[i] = 1
		_wet_n += 1
		_wet_list.append(i)


## Every wet cell, when the walk list has to be rebuilt.
func _wet_scan() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w * d:
		if _wet_flag[i] == 1:
			out.append(i)
	return out


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
	while _wet_n > 0:
		thermal(1.0e9, -5.0, 0.0, _wet_n)
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


## The ice's thickness over the paint (mm) at a point: the base, what
## floods built up or the blade took, less a gouge.
func thickness_at(p: Vector2) -> float:
	var c := cell_at(p)
	return paint_depth(index(c.x, c.y)) if in_bounds(c.x, c.y) else 0.0


## Loose snow (mm) at a point.
func snow_at(p: Vector2) -> float:
	var c := cell_at(p)
	return snow[index(c.x, c.y)] if in_bounds(c.x, c.y) else 0.0


## Liquid water (mm) at a point.
func water_at(p: Vector2) -> float:
	var c := cell_at(p)
	var i := index(c.x, c.y)
	return water[i] * (1.0 - frozen[i]) if in_bounds(c.x, c.y) else 0.0


func _touch(x: int, z: int) -> void:
	var key := Vector2i(x / CHUNK, z / CHUNK)
	_dirty[key] = true
	_uniform.erase(key)


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


## The tiles with a rebuilt chunk go to the GPU (768 KB each).
func _upload() -> void:
	for tkey in _tile_dirty:
		var t: Tile = _tiles[tkey]
		t.state_tex.update(t.state_img)
		t.cut_tex.update(t.cut_img)
		t.depth_tex.update(t.depth_img)
	_tile_dirty.clear()


## A chunk's columns into its tile's images and its mesh. A uniform chunk
## (untouched since the fill) is three fill_rects and a flat quad; any
## other is encoded cell by cell, the hot path, written flat.
func _build_chunk(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var x1 := mini(x0 + CHUNK, w)
	var z1 := mini(z0 + CHUNK, d)
	var tkey := Vector2i(key.x / (TILE / CHUNK), key.y / (TILE / CHUNK))
	var t: Tile = _tiles[tkey]
	var tx0 := tkey.x * TILE
	var tz0 := tkey.y * TILE
	var sim := t.state_img
	var cim := t.cut_img
	var dim := t.depth_img
	var lo := INF
	var hi := -INF
	var flat := _uniform.has(key)
	if flat:
		# the border row and column shared with the next chunks must be
		# level with it too, or the quads would not meet
		var h := _height(x0, z0)
		for x in range(x0, x1 + 1):
			if absf(_height(x, z1) - h) >= FLAT_EPS:
				flat = false
				break
		if flat:
			for z in range(z0, z1 + 1):
				if absf(_height(x1, z) - h) >= FLAT_EPS:
					flat = false
					break
		if flat:
			lo = h
			hi = h
			var i := z0 * w + x0
			var rect := Rect2i(x0 - tx0, z0 - tz0, x1 - x0, z1 - z0)
			sim.fill_rect(rect, _state_colour(i))
			cim.fill_rect(rect, _cut_colour(i))
			dim.fill_rect(rect, _depth_colour(i))
	if not flat:
		var scale := 0.001 * height_scale
		for z in range(z0, z1):
			var pz := z - tz0
			var row := z * w
			for x in range(x0, x1):
				var i := row + x
				var px := x - tx0
				sim.set_pixel(
					px,
					pz,
					Color(
						clampf(snow[i] / SNOW_FULL, 0.0, 1.0),
						clampf(cut[i], 0.0, 1.0),
						clampf(water[i] / WATER_FULL, 0.0, 1.0),
						clampf(frozen[i], 0.0, 1.0)
					)
				)
				cim.set_pixel(
					px,
					pz,
					Color(
						fposmod(ang[i], TAU) / TAU,
						clampf(gouge[i] / GOUGE_FULL, 0.0, 1.0),
						clampf(scar[i] / GOUGE_FULL, 0.0, 1.0),
						clampf(crust[i] / GOUGE_FULL, 0.0, 1.0)
					)
				)
				dim.set_pixel(
					px,
					pz,
					Color(
						clampf((base_mm + ice[i] - gouge[i]) / DEPTH_FULL, 0.0, 1.0),
						clampf(water[i] / POOL_FULL, 0.0, 1.0),
						0.0,
						1.0
					)
				)
				# the column's height, as _height has it, inline
				var hs := (((i * 1103515245 + 12345) & 0x7fffffff) >> 8) & 0xffff
				var h := (
					(ice[i] + snow[i] + crust[i] * (0.4 + 0.6 * hs / 65535.0) + water[i] - gouge[i])
					* scale
				)
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
	_tile_dirty[tkey] = true
	var mi: MeshInstance3D = _chunks.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = t.material
		add_child(mi)
		_chunks[key] = mi
	# a level chunk (dry, or an even film, or built-up ice all one height) is one quad
	mi.mesh = _flat_quad(x0, z0, x1, z1, lo) if hi - lo < FLAT_EPS else _heightfield(x0, z0, x1, z1)
	remeshed += 1


func _state_colour(i: int) -> Color:
	return Color(
		clampf(snow[i] / SNOW_FULL, 0.0, 1.0),
		clampf(cut[i], 0.0, 1.0),
		clampf(water[i] / WATER_FULL, 0.0, 1.0),
		clampf(frozen[i], 0.0, 1.0)
	)


func _cut_colour(i: int) -> Color:
	return Color(
		fposmod(ang[i], TAU) / TAU,
		clampf(gouge[i] / GOUGE_FULL, 0.0, 1.0),
		clampf(scar[i] / GOUGE_FULL, 0.0, 1.0),
		clampf(crust[i] / GOUGE_FULL, 0.0, 1.0)
	)


func _depth_colour(i: int) -> Color:
	return Color(
		clampf(paint_depth(i) / DEPTH_FULL, 0.0, 1.0),
		clampf(water[i] / POOL_FULL, 0.0, 1.0),
		0.0,
		1.0
	)


func _height(x: int, z: int) -> float:
	var i := index(mini(x, w - 1), mini(z, d - 1))
	# crust is peaks: each column its own height within the crust depth
	var peak := crust[i] * (0.4 + 0.6 * _hash(i))
	# water stands at its full depth, so a pool is level across its hollow
	return (ice[i] + snow[i] + peak + water[i] - gouge[i]) * 0.001 * height_scale


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


static func noise_normal(freq: float, octaves: int, strength: float, noise_seed: int) -> Texture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = noise_seed
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
