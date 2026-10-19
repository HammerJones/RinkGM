class_name IceSlab
extends RefCounted
## The sheet of ice: a 61 x 26 m slab on a concrete floor full of glycol pipe.
## Hockey wants a hard surface around -5.5 C, figure skating a softer -3.5 C.
## The numbers and their sources are in docs/world/ICE.md.
##
## Thickness is a trade-off (Sean, 2026-10-17):
##   thin (25 to 32 mm): cheap to cool, colder and harder at the surface, fast
##     and dry, what hockey wants; but little thermal mass, so it warms and
##     melts quickly, and deep gouges reach the paint and the soft layer below.
##   thick (40 mm and up): costs more plant power, holds its cold longer and
##     melts slowly, holds deep edges, what figure skaters want; but a flood
##     takes longer to freeze in, so it can still be wet when the next group
##     steps on, and hockey wants bone-dry ice the second its window starts.
##
## Two grids (v2, docs/world/ICE.md 2):
##   the FINE grid, 240 x 104 cells of 0.254 x 0.249 m inside the rounded
##     boards, is the truth: per cell the ice thickness (mm), the gouge depth
##     (mm), the surface texture roughness (striations, chatter, chips), loose
##     snow on top (mm), the unfrozen water film (mm) with the heat it still
##     has to give up, and the angle of the last cut. Index fz * FW + fx;
##     fx runs along the rink from the home end (-X), fz across it from the
##     bench side (-Z).
##   the COARSE grid, 20 x 8 cells of about 3.05 x 3.24 m (index x * D + z),
##     is what RinkSim, the office and the old saves know: `thick` and
##     `smooth` are the block averages of the fine grid. `thickness_mm` and
##     `smoothness` are the sheet averages; setting either shifts every cell,
##     so old callers keep working.
##
## Skating wear is cheap: run() adds it to the coarse grid at once (so the
## ratings move every step) and keeps it pending per block, and the fine grid
## gets it as gouge strokes and snow the next time anyone looks closely
## (flush(): a resurface, the view, a measurement, wear()).

const AREA := 61.0 * 26.0
const W := 20   # coarse cells along the rink
const D := 8    # coarse cells across it
const CELLS := W * D
const TARGET_TEMP := {"hockey": -5.5, "figure": -3.5, "public": -4.5}
## Thickness each use likes best, in mm (it rates fine anywhere in the range).
const IDEAL_THICKNESS := {"hockey": Vector2(25.0, 34.0), "figure": Vector2(36.0, 50.0), "public": Vector2(28.0, 45.0)}
## How much a wet surface costs each use (0 shrugs, 1 refuses to skate on it).
const WET_PENALTY := {"hockey": 0.6, "figure": 0.2, "public": 0.3}
## Rating weights (docs/world/RINK_SIM.md 3.2, "Ice rating").
const WEIGHTS := {"temp": 0.30, "smooth": 0.25, "snow": 0.10, "clean": 0.10, "thick": 0.10, "level": 0.08, "paint": 0.07}

const VERSION := 2
## The fine grid. 12 x 13 fine cells make one coarse cell.
const FW := 240
const FD := 104
const FCELLS := FW * FD
const BX := 12
const BZ := 13
const LENGTH := 60.96
const WIDTH := 25.9
const HALF_L := LENGTH * 0.5
const HALF_W := WIDTH * 0.5
const CX := LENGTH / FW    # 0.254 m (10 in)
const CZ := WIDTH / FD     # 0.249 m
const CELL_AREA := CX * CZ
## Mean gouge depth at which a cell reads fully chewed up, mm.
const GOUGE_FULL := 2.5
## The deepest a gouge or rut gets before it is a hole, mm.
const GOUGE_MAX := 4.0
## Loose snow that reads as the old sheet-wide `snow` of 1.0, mm.
const SNOW_FULL_MM := 3.0
## Water film that stays put (surface tension) instead of running downhill, mm.
const FILM_PIN_MM := 0.15
## Ice is 9% bigger than the water it froze from.
const ICE_PER_WATER := 1.09
const C_WATER := 4.18     # kJ/kg K
const L_FUSION := 334.0   # kJ/kg
## Hot flood water from the bay's tank heater, C (140 F).
const FLOOD_TEMP_C := 60.0
## The blade can't reach this close to the boards, m: snow and water collect there.
const BLADE_REACH := 0.35
## Faceoff dots and centre ice, for the depth plates (world metres, x along).
const PLATE_SPOTS := {
	"centre": Vector2(0.0, 0.0),
	"home_left": Vector2(-21.03, -6.71), "home_right": Vector2(-21.03, 6.71),
	"home_nz_left": Vector2(-6.12, -6.71), "home_nz_right": Vector2(-6.12, 6.71),
	"away_nz_left": Vector2(6.12, -6.71), "away_nz_right": Vector2(6.12, 6.71),
	"away_left": Vector2(21.03, -6.71), "away_right": Vector2(21.03, 6.71),
}
## The laser plane above the concrete datum at centre ice, mm (a tripod
## with the head at about 1.25 m over the ice).
const LASER_HEIGHT_MM := 1298.0

var surface_temp := -4.0
var cleanliness := 0.8  # tape, puck marks, rust, mud from the lobby door
var paint := 0.6        # lines and logos; shaved through as the ice thins
var flood_heat_mj := 0.0    # heat of the last flood, for how wet it still is
## Depth plates set in the concrete under the ice: ids from PLATE_SPOTS.
var plates: Array = ["centre"]

## Coarse truth for RinkSim and the office, index x * D + z: block averages.
var thick := PackedFloat64Array()
var smooth := PackedFloat64Array()

## The fine grid (see the header). `t` thickness mm, `g` gouge depth mm,
## `r` texture roughness 0..1, `s` loose snow mm, `w` water film mm not yet
## frozen (already counted in `t`), `hq` heat still to come out of it and
## `hq0` its heat when laid (kJ/m2; frozen fraction 1 - hq/hq0), `ang` the
## direction of the last cut (0..1 of half a turn) and `stri` how plain its
## striations are.
var t := PackedFloat32Array()
var g := PackedFloat32Array()
var r := PackedFloat32Array()
var s := PackedFloat32Array()
var w := PackedFloat32Array()
var hq := PackedFloat32Array()
var hq0 := PackedFloat32Array()
var ang := PackedFloat32Array()
var stri := PackedFloat32Array()
## 1 inside the boards. The concrete under each cell (its heave, mm) and the
## distance from it to the boards (m) never change.
var inside := PackedByteArray()
var floor_mm := PackedFloat32Array()
var board_m := PackedFloat32Array()
var block := PackedInt32Array()   # fine cell -> coarse index
## Bumped on every change, with the fine cells touched since the view last looked.
var revision := 0
var dirty := Rect2i()

var _block_n := PackedInt32Array()
var _wear_pending := PackedFloat32Array()   # per coarse cell, in smoothness units
var _snow_pending := 0.0                    # sheet-wide, in old `snow` units
var _melt_pending_h := 0.0                  # hours of melting the fine grid hasn't had yet
var _active := {}                           # fine cells with water still freezing
var _pending_mj := 0.0
var _avg_t := 48.0
var _avg_s := 0.7
var _inside_n := 0
var _ring_n := 0
var _edge := PackedByteArray()      # 1 where the coarse cell is on the outer ring
var _trf := PackedFloat32Array()    # the traffic map per fine cell
var _snow_cache := -1.0
var _snow_rev := -1
var _rng := RandomNumberGenerator.new()

## Average thickness over the grid, mm. Setting it shifts every cell.
var thickness_mm: float:
	get:
		return _avg_t
	set(v):
		var dv := v - _avg_t
		for i in FCELLS:
			t[i] = maxf(t[i] + dv, 0.0)
		_touch_all()
		_recalc()

## Average smoothness over the grid, 1 glass, 0 ruts and chips everywhere.
var smoothness: float:
	get:
		return _avg_s
	set(v):
		flush()
		var dv := v - _avg_s
		for i in FCELLS:
			_set_rough(i, clampf(rough_at(i) - dv, 0.0, 1.0))
		_touch_all()
		_recalc()

## Loose snow, 0 clean to 1 a skipped flood or three (SNOW_FULL_MM of it on
## average). Setting it scales the snow on every cell.
var snow: float:
	get:
		return clampf(_snow_mean_mm() / SNOW_FULL_MM + _snow_pending, 0.0, 1.0)
	set(v):
		flush()
		var cur := _snow_mean_mm()
		var want := clampf(v, 0.0, 1.0) * SNOW_FULL_MM
		if cur > 0.0001:
			var k := want / cur
			for i in FCELLS:
				if board_m[i] >= BLADE_REACH:
					s[i] *= k
		else:
			for i in FCELLS:
				if inside[i] == 1 and board_m[i] >= BLADE_REACH:
					s[i] = want
		_touch_all()

## Heat the flood water still has to give up before it is ice, MJ.
var pending_heat_mj: float:
	get:
		return _pending_mj
	set(v):
		_set_pending(v)


## The rink's shape never changes: worked out once for every slab.
static var _geo := {}


static func _geometry() -> Dictionary:
	if not _geo.is_empty():
		return _geo
	var ins := PackedByteArray()
	var bm := PackedFloat32Array()
	var fl := PackedFloat32Array()
	var bl := PackedInt32Array()
	var eg := PackedByteArray()
	var tr := PackedFloat32Array()
	var bn := PackedInt32Array()
	ins.resize(FCELLS)
	bm.resize(FCELLS)
	fl.resize(FCELLS)
	bl.resize(FCELLS)
	eg.resize(FCELLS)
	tr.resize(FCELLS)
	bn.resize(CELLS)
	var n_in := 0
	var n_ring := 0
	for fz in FD:
		for fx in FW:
			var i := fz * FW + fx
			var p := cell_pos(fx, fz)
			var d := -Rink.sdf(p)
			bm[i] = d
			ins[i] = 1 if d > 0.02 else 0
			var bx := mini(fx / BX, W - 1)
			var bz := mini(fz / BZ, D - 1)
			var b := bx * D + bz
			bl[i] = b
			eg[i] = 1 if is_edge(bx, bz) else 0
			tr[i] = traffic(bx, bz)
			fl[i] = _heave(p)
			if ins[i] == 1:
				bn[b] += 1
				n_in += 1
				if d < BLADE_REACH:
					n_ring += 1
	_geo = {"inside": ins, "board_m": bm, "floor": fl, "block": bl, "edge": eg, "traffic": tr, "block_n": bn, "n_in": n_in, "n_ring": n_ring}
	return _geo


func _init() -> void:
	thick.resize(CELLS)
	smooth.resize(CELLS)
	var geo := _geometry()
	inside = geo.inside
	board_m = geo.board_m
	floor_mm = geo.floor
	block = geo.block
	_edge = geo.edge
	_trf = geo.traffic
	_block_n = geo.block_n
	_inside_n = int(geo.n_in)
	_ring_n = int(geo.n_ring)
	_wear_pending.resize(CELLS)
	_rng.seed = 1974
	t.resize(FCELLS)
	t.fill(48.0)
	# a fresh sheet as old callers knew it: smoothness 0.7
	g.resize(FCELLS)
	g.fill(0.2 * GOUGE_FULL)
	r.resize(FCELLS)
	r.fill(0.1)
	s.resize(FCELLS)
	w.resize(FCELLS)
	hq.resize(FCELLS)
	hq0.resize(FCELLS)
	ang.resize(FCELLS)
	stri.resize(FCELLS)
	_touch_all()
	_recalc()


## The concrete isn't flat: a few mm of frost heave and a pour seam, the same
## at every rink built by Hal Brenner's crew in 1971. mm, 0 at centre ice.
static func _heave(p: Vector2) -> float:
	var h := 2.2 * sin(p.x * 0.083 + 0.6) * cos(p.y * 0.19 - 0.3) + 1.4 * sin(p.x * 0.031 - p.y * 0.07 + 1.1)
	return h - (2.2 * sin(0.6) * cos(-0.3) + 1.4 * sin(1.1))


## Millbrook as Earl left it: 48 mm on average (Earl likes it thick), the
## sheet bowled about 12 mm up toward the boards where the blade never
## reaches and Earl's water runs, a 6 mm dish at the home blue line where the
## roof drips in spring, surface around -4 C, and a week of skating in it.
static func create_millbrook() -> IceSlab:
	var sl := IceSlab.new()
	var home_blue := Vector2(-7.62 - 5.0, 0.0)
	for i in FCELLS:
		var fx := i % FW
		var fz := i / FW
		var p := cell_pos(fx, fz)
		var d := sl.board_m[i]
		var bowl := 22.0 * pow(clampf(1.0 - d / 4.5, 0.0, 1.0), 1.3)
		var dip := 6.5 * clampf(1.0 - Vector2((p.x - home_blue.x) / 4.5, (p.y - home_blue.y) / 3.3).length(), 0.0, 1.0)
		sl.t[i] = bowl - dip
	sl._recalc()
	# the coarse ring reads 12 mm over the rest, as the M1 design has it
	var lip := sl.edge_lip_mm()
	if lip > 0.1:
		for i in FCELLS:
			var d := sl.board_m[i]
			sl.t[i] *= 12.0 / lip if d < 4.6 else 1.0
	sl._recalc()
	sl.thickness_mm = 48.0
	sl._scuff(0.3)
	return sl


## Replaces the even texture of a new slab with a summer's worth of old
## strokes, keeping each coarse cell's smoothness at 1 - `rough`.
func _scuff(rough: float) -> void:
	for i in FCELLS:
		g[i] = 0.0
		r[i] = 0.04
	for b in CELLS:
		var units := (rough - 0.04) * float(_block_n[b])
		var n := clampi(int(units / 0.4), 1, 60)
		var bx := b / D
		var bz := b % D
		for k in n:
			var fx := bx * BX + _rng.randi() % BX
			var fz := mini(bz * BZ + _rng.randi() % BZ, FD - 1)
			if inside[fz * FW + fx] == 1:
				_wear_stroke(fz * FW + fx, units / float(n))
	var sums := PackedFloat64Array()
	sums.resize(CELLS)
	for i in FCELLS:
		if inside[i] == 1:
			sums[block[i]] += rough_at(i)
	for i in FCELLS:
		if inside[i] == 1:
			var b := block[i]
			r[i] = maxf(r[i] + rough - sums[b] / float(maxi(_block_n[b], 1)), 0.0)
	_touch_all()
	_recalc()


## A copy for a mini game to work on (cancel throws it away).
func copy() -> IceSlab:
	var c := IceSlab.new()
	c.adopt(self)
	return c


## Takes every value from `o` (a mini game's copy coming back).
func adopt(o: IceSlab) -> void:
	o.flush()
	surface_temp = o.surface_temp
	cleanliness = o.cleanliness
	paint = o.paint
	flood_heat_mj = o.flood_heat_mj
	plates = o.plates.duplicate()
	t = o.t.duplicate()
	g = o.g.duplicate()
	r = o.r.duplicate()
	s = o.s.duplicate()
	w = o.w.duplicate()
	hq = o.hq.duplicate()
	hq0 = o.hq0.duplicate()
	ang = o.ang.duplicate()
	stri = o.stri.duplicate()
	_wear_pending.fill(0.0)
	_snow_pending = 0.0
	_melt_pending_h = 0.0
	_active = o._active.duplicate()
	_pending_mj = o._pending_mj
	_rng.state = o._rng.state
	_touch_all()
	_recalc()


static func is_edge(x: int, z: int) -> bool:
	return x == 0 or z == 0 or x == W - 1 or z == D - 1


## The centre of fine cell (fx, fz) in rink metres (x along, y across).
static func cell_pos(fx: int, fz: int) -> Vector2:
	return Vector2((fx + 0.5) * CX - HALF_L, (fz + 0.5) * CZ - HALF_W)


## The fine cell under rink point `p` (metres), clamped to the grid.
static func cell_at(p: Vector2) -> int:
	var fx := clampi(int(floor((p.x + HALF_L) / CX)), 0, FW - 1)
	var fz := clampi(int(floor((p.y + HALF_W) / CZ)), 0, FD - 1)
	return fz * FW + fx


## How much traffic a cell takes relative to the average: the creases, the
## faceoff dots and centre ice get chewed, the strip along the boards less.
static func traffic(x: int, z: int) -> float:
	var tr := 1.0
	if (x <= 2 or x >= W - 3) and (z == 3 or z == 4):
		tr = 1.8
	elif (x == 4 or x == W - 5) and (z == 2 or z == 5):
		tr = 1.5
	elif (x == 9 or x == 10) and (z == 3 or z == 4):
		tr = 1.3
	elif is_edge(x, z):
		tr = 0.7
	return tr / 0.99  # the mean of the map above, so the sheet wears as before on average


## The standard flood pattern: two laps around the boards, then long
## overlapping passes. Coverage per cell, 0..1: the corners get half.
static func standard_pattern() -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(CELLS)
	for x in W:
		for z in D:
			var c := 1.0
			if (x == 0 or x == W - 1) and (z == 0 or z == D - 1):
				c = 0.5
			p[x * D + z] = c
	return p


# ------------------------------------------------------------------ fine cells

## 0 glass .. 1 chewed: the gouges and the surface texture together.
func rough_at(i: int) -> float:
	return minf(g[i] / GOUGE_FULL + r[i], 1.0)


func _set_rough(i: int, v: float) -> void:
	var gr := g[i] / GOUGE_FULL
	if v >= gr:
		r[i] = clampf(v - gr, 0.0, 1.0)
	else:
		g[i] = v * GOUGE_FULL
		r[i] = 0.0


## Unfrozen water on cell `i`, mm.
func liquid_at(i: int) -> float:
	if w[i] <= 0.0 or hq0[i] <= 0.0:
		return 0.0
	return w[i] * clampf(hq[i] / hq0[i], 0.0, 1.0)


## 0 just laid .. 1 frozen in (a cell with no water is frozen).
func frozen_at(i: int) -> float:
	if hq0[i] <= 0.0:
		return 1.0
	return 1.0 - clampf(hq[i] / hq0[i], 0.0, 1.0)


## Surface temperature of cell `i`: thin spots sit colder over the pipes, wet
## ones at the melting point.
func temp_at(i: int) -> float:
	var base := surface_temp - (t[i] - _avg_t) * 0.03
	var liq := liquid_at(i)
	if liq > 0.0:
		return lerpf(base, 0.0, clampf(liq / 0.1, 0.0, 1.0))
	return base


## The top of the ice at cell `i` over the concrete datum, mm.
func level_at(i: int) -> float:
	return floor_mm[i] + t[i]


## Bilinear thickness at rink point `p`, mm.
func thickness_at(p: Vector2) -> float:
	flush()
	var fx := (p.x + HALF_L) / CX - 0.5
	var fz := (p.y + HALF_W) / CZ - 0.5
	var x0 := clampi(int(floor(fx)), 0, FW - 2)
	var z0 := clampi(int(floor(fz)), 0, FD - 2)
	var ax := clampf(fx - x0, 0.0, 1.0)
	var az := clampf(fz - z0, 0.0, 1.0)
	var i := z0 * FW + x0
	return lerpf(lerpf(t[i], t[i + 1], ax), lerpf(t[i + FW], t[i + FW + 1], ax), az)


## Where the laser hits a survey rod stood on the ice at `p`, mm up the rod.
func rod_reading_mm(p: Vector2) -> float:
	var i := cell_at(p)
	return LASER_HEIGHT_MM - floor_mm[i] - thickness_at(p)


## The true depth at a plate, mm (what the drill and the calipers find).
func plate_depth_mm(id: String) -> float:
	var p: Vector2 = PLATE_SPOTS.get(id, Vector2.ZERO)
	return thickness_at(p)


func _touch(fx0: int, fz0: int, fx1: int, fz1: int) -> void:
	var rr := Rect2i(fx0, fz0, fx1 - fx0 + 1, fz1 - fz0 + 1)
	dirty = rr if dirty.size == Vector2i.ZERO else dirty.merge(rr)
	revision += 1


func _touch_all() -> void:
	dirty = Rect2i(0, 0, FW, FD)
	revision += 1


## The fine cells under a disc at `p` of radius `rad` metres: [i, weight 0..1].
func _disc(p: Vector2, rad: float) -> Array:
	var out: Array = []
	var fx0 := clampi(int(floor((p.x - rad + HALF_L) / CX)), 0, FW - 1)
	var fx1 := clampi(int(floor((p.x + rad + HALF_L) / CX)), 0, FW - 1)
	var fz0 := clampi(int(floor((p.y - rad + HALF_W) / CZ)), 0, FD - 1)
	var fz1 := clampi(int(floor((p.y + rad + HALF_W) / CZ)), 0, FD - 1)
	for fz in range(fz0, fz1 + 1):
		for fx in range(fx0, fx1 + 1):
			var i := fz * FW + fx
			if inside[i] == 0:
				continue
			var d := cell_pos(fx, fz).distance_to(p)
			if d <= rad + 0.5 * CX:
				out.append([i, clampf(1.0 - d / maxf(rad + 0.5 * CX, 0.01), 0.15, 1.0)])
	_touch(fx0, fz0, fx1, fz1)
	return out


# ------------------------------------------------------------------ wear

## Skating at rink point `p`: `amount` is skater-hours spent right there (one
## skater crossing a spot is about 0.001; a goalie's crease over a game is
## 0.5). Cuts gouges that go deeper on soft or thin ice and throws a little
## snow. Events and NPC skaters call this.
func wear(pos: Vector2, amount: float, heading := -1.0) -> void:
	flush()
	# a skater-hour spread over the whole sheet is about 300 cell-units of
	# roughness (run()'s rate); here it all lands in a metre or so
	var units := amount * 300.0
	var n := clampi(int(units / 0.4), 1, 48)
	var rad := clampf(0.15 + units * 0.02, 0.15, 1.2)
	for k in n:
		var off := Vector2(_rng.randfn(0.0, rad * 0.5), _rng.randfn(0.0, rad * 0.5)) if n > 1 else Vector2.ZERO
		_wear_at(pos + off, units / float(n), heading)
	_recalc_blocks_near(pos, rad + 1.0)


func _wear_at(pos: Vector2, rough_units: float, heading := -1.0) -> void:
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	var i0 := cell_at(pos)
	var thin := 1.0 + clampf((30.0 - t[i0]) / 8.0, 0.0, 2.0)
	var dir := heading if heading >= 0.0 else _rng.randf() * PI
	if heading < 0.0 and _rng.randf() < 0.7:
		dir = _rng.randfn(0.0, 0.5)  # most strides run along the rink
	var v := Vector2(cos(dir), sin(dir))
	var n := 3 + _rng.randi() % 4
	var per := rough_units * (0.6 + soft) * thin / float(n)
	for k in n:
		var q := pos + v * (float(k) - n * 0.5) * CX * 0.9
		var i := cell_at(q)
		if inside[i] == 0:
			continue
		g[i] = minf(g[i] + per * 0.8 * GOUGE_FULL, GOUGE_MAX)
		r[i] = minf(r[i] + per * 0.2, 1.0)
		# a stop at the end of a stride throws snow
		if k == n - 1:
			s[i] += per * 1.6
	var fx := i0 % FW
	var fz := i0 / FW
	_touch(maxi(fx - 4, 0), maxi(fz - 4, 0), mini(fx + 4, FW - 1), mini(fz + 4, FD - 1))


## Default wear for `skater_hours` of a session of `skaters`, spread by the
## traffic map: what run() keeps pending, done now.
func wear_sessions(hours: float, skaters: float) -> void:
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	for x in W:
		for z in D:
			var b := x * D + z
			var gouge := 1.0 + clampf((30.0 - thick[b]) / 8.0, 0.0, 2.0)
			_wear_pending[b] += skaters * hours * 0.012 * (0.6 + soft) * gouge * traffic(x, z)
	_snow_pending += skaters * hours * 0.006 * (0.6 + soft)


## Puts the pending skating into the fine grid: gouge strokes by the traffic,
## snow sprayed from the stops, and a share of it pushed to a ridge along the
## boards. Bounded work: at most a few dozen strokes a coarse cell.
func flush() -> void:
	if _melt_pending_h > 0.0:
		_apply_melt(_melt_pending_h)
		_melt_pending_h = 0.0
	var any := _snow_pending > 0.0
	for b in CELLS:
		if _wear_pending[b] > 0.0:
			any = true
			break
	if not any:
		return
	for b in CELLS:
		var p := _wear_pending[b]
		if p <= 0.0:
			continue
		_wear_pending[b] = 0.0
		var units := p * float(_block_n[b])
		var n := clampi(int(units / 1.2), 1, 10)
		var bx := b / D
		var bz := b % D
		for k in n:
			var fx := bx * BX + _rng.randi() % BX
			var fz := mini(bz * BZ + _rng.randi() % BZ, FD - 1)
			var i := fz * FW + fx
			if inside[i] == 0:
				continue
			_wear_stroke(i, units / float(n))
	if _snow_pending > 0.0:
		var mm := _snow_pending * SNOW_FULL_MM
		_snow_pending = 0.0
		# snow lies where the stops threw it, most of it by the traffic, and
		# slush scraped off along the wall piles into a ridge at the boards on
		# top (a quarter as much again: the chipper's job)
		var ridge := mm * 0.25 * float(_inside_n) / float(maxi(_ring_n, 1))
		for i in FCELLS:
			if inside[i] == 0:
				continue
			if board_m[i] < BLADE_REACH:
				s[i] += ridge
			else:
				s[i] += mm * _trf[i]
	_touch_all()
	_recalc()


## `h` hours of a surface above -0.5 C: the ice goes soft and runs, the
## gouges round off, the snow turns to slush and water, and the melt stands
## on top.
func _apply_melt(h: float) -> void:
	var add_kj := 0.0
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var mm := h * 0.3 * clampf(40.0 / maxf(t[i], 10.0), 0.6, 2.5)
		t[i] = maxf(t[i] - mm, 0.0)
		g[i] = maxf(g[i] - mm * 0.5, 0.0)
		s[i] = maxf(s[i] - mm * 3.0, 0.0)
		if w[i] < 1.5:
			var film := minf(mm * 0.5, 1.5 - w[i])
			w[i] += film
			t[i] += film
			hq[i] += film * L_FUSION
			hq0[i] += film * L_FUSION
			add_kj += film * L_FUSION
			_active[i] = true
	_pending_mj += add_kj * CELL_AREA / 1000.0
	_touch_all()
	_recalc()


func _wear_stroke(i: int, rough_units: float) -> void:
	var dir := _rng.randfn(0.0, 0.55) if _rng.randf() < 0.7 else _rng.randf() * PI
	var vx := cos(dir) * 0.9
	var vz := sin(dir) * 0.9
	var n := 3 + _rng.randi() % 4
	var per := rough_units / float(n)
	var fx0 := float(i % FW)
	var fz0 := float(i / FW)
	for k in n:
		var o := float(k) - n * 0.5
		var fx := clampi(int(fx0 + vx * o + 0.5), 0, FW - 1)
		var fz := clampi(int(fz0 + vz * o + 0.5), 0, FD - 1)
		var j := fz * FW + fx
		if inside[j] == 0:
			continue
		var room := 1.0 - minf(g[j] / GOUGE_FULL + r[j], 1.0)
		var add := minf(per, room)
		var gadd := minf(add * 0.8 * GOUGE_FULL, GOUGE_MAX - g[j])
		g[j] += gadd
		r[j] = minf(r[j] + add - gadd / GOUGE_FULL, 1.0)


# ------------------------------------------------------------------ coarse sync

func _recalc() -> void:
	var st := PackedFloat64Array()
	var ss := PackedFloat64Array()
	st.resize(CELLS)
	ss.resize(CELLS)
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var b := block[i]
		st[b] += t[i]
		ss[b] += minf(g[i] / GOUGE_FULL + r[i], 1.0)
	var tt := 0.0
	var sm := 0.0
	for b in CELLS:
		var n := float(maxi(_block_n[b], 1))
		thick[b] = st[b] / n
		smooth[b] = clampf(1.0 - ss[b] / n - _wear_pending[b], 0.0, 1.0)
		tt += thick[b]
		sm += smooth[b]
	_avg_t = tt / CELLS
	_avg_s = sm / CELLS


## Recomputes the coarse cells within `rad` metres of `p` (cheap: a few
## blocks instead of the whole sheet).
func _recalc_blocks_near(p: Vector2, rad: float) -> void:
	var bx0 := clampi(int(floor((p.x - rad + HALF_L) / (CX * BX))), 0, W - 1)
	var bx1 := clampi(int(floor((p.x + rad + HALF_L) / (CX * BX))), 0, W - 1)
	var bz0 := clampi(int(floor((p.y - rad + HALF_W) / (CZ * BZ))), 0, D - 1)
	var bz1 := clampi(int(floor((p.y + rad + HALF_W) / (CZ * BZ))), 0, D - 1)
	for bx in range(bx0, bx1 + 1):
		for bz in range(bz0, bz1 + 1):
			_recalc_block(bx * D + bz)
	var tt := 0.0
	var sm := 0.0
	for b in CELLS:
		tt += thick[b]
		sm += smooth[b]
	_avg_t = tt / CELLS
	_avg_s = sm / CELLS


func _recalc_block(b: int) -> void:
	var bx := b / D
	var bz := b % D
	var st := 0.0
	var ss := 0.0
	for fz in range(bz * BZ, mini((bz + 1) * BZ, FD)):
		for fx in range(bx * BX, (bx + 1) * BX):
			var i := fz * FW + fx
			if inside[i] == 1:
				st += t[i]
				ss += rough_at(i)
	var n := float(maxi(_block_n[b], 1))
	thick[b] = st / n
	smooth[b] = clampf(1.0 - ss / n - _wear_pending[b], 0.0, 1.0)


## Mean loose snow on the playing surface (the ridge along the boards is
## board_ridge_litres()), mm.
func _snow_mean_mm() -> float:
	if _snow_rev == revision:
		return _snow_cache
	var tot := 0.0
	for i in FCELLS:
		if inside[i] == 1 and board_m[i] >= BLADE_REACH:
			tot += s[i]
	_snow_cache = tot / float(maxi(_inside_n - _ring_n, 1))
	_snow_rev = revision
	return _snow_cache


## {"thickness_mm", "smoothness", "edge"} for one coarse cell, plus the
## block's snow, water and gouges.
func cell(x: int, z: int) -> Dictionary:
	var i := clampi(x, 0, W - 1) * D + clampi(z, 0, D - 1)
	return {"thickness_mm": thick[i], "smoothness": smooth[i], "edge": is_edge(x, z)}


## Everything about one fine cell, for the tools and the tests.
func fine_cell(i: int) -> Dictionary:
	return {"thickness_mm": t[i], "gouge_mm": g[i], "rough": rough_at(i), "snow_mm": s[i], "water_mm": liquid_at(i),
		"frozen": frozen_at(i), "temp": temp_at(i), "level_mm": level_at(i), "inside": inside[i] == 1, "boards_m": board_m[i]}


# ------------------------------------------------------------------ heat

## Heat the slab and the top of the concrete hold per kelvin: thicker ice has
## more thermal mass, so it warms (and cools) more slowly.
func heat_capacity_mj() -> float:
	return 150.0 + 2.5 * thickness_mm


## How well the pipes reach the surface: thicker ice insulates it.
func insulation() -> float:
	return clampf(1.0 - (thickness_mm - 32.0) / 80.0, 0.5, 1.08)


## How fast a flood freezes in, kW: the cold has to come up through the ice.
func freeze_kw() -> float:
	return 320.0 * clampf(1.0 - (thickness_mm - 25.0) / 55.0, 0.35, 1.15)


## 1 just flooded and wet, 0 bone dry.
func wetness() -> float:
	if flood_heat_mj <= 0.0:
		return 0.0
	return clampf(pending_heat_mj / flood_heat_mj * 1.6 - 0.3, 0.0, 1.0)


## Minutes until a fresh flood is dry enough for hockey, at this thickness.
func dry_minutes(flood_litres: float) -> float:
	var heat := flood_litres * (4.18 * 60.0 + 334.0) / 1000.0
	return heat * (1.0 - 0.3 / 1.6) / (freeze_kw() * 3.6) * 60.0


## Heat per mm of water at `temp_c` to freeze it, kJ/m2 (1 mm on 1 m2 is 1 kg).
static func heat_per_mm(temp_c: float) -> float:
	return C_WATER * maxf(temp_c, 0.0) + L_FUSION


## Lays `mm` of water at `temp_c` on fine cell `i` (it counts in the
## thickness at once, as ice-to-be). Hot water melts into the old surface:
## it fills the gouges first and bonds.
func add_water(i: int, mm: float, temp_c := FLOOD_TEMP_C) -> void:
	if mm <= 0.0 or inside[i] == 0:
		return
	var ice_mm := mm * ICE_PER_WATER
	t[i] += ice_mm
	var fill := minf(g[i], ice_mm * (0.6 + 0.4 * clampf(temp_c / 60.0, 0.0, 1.2)))
	g[i] -= fill
	w[i] += mm
	var h := mm * heat_per_mm(temp_c)
	hq[i] += h
	hq0[i] += h
	_pending_mj += h * CELL_AREA / 1000.0
	_active[i] = true


func _set_pending(v: float) -> void:
	if v <= 0.0:
		for i in _active:
			w[i] = 0.0
			hq[i] = 0.0
			hq0[i] = 0.0
		_active.clear()
		_pending_mj = 0.0
		return
	if _pending_mj > 0.0001:
		var k := v / _pending_mj
		for i in _active:
			hq[i] *= k
			hq0[i] = maxf(hq0[i], hq[i])
		_pending_mj = v
		return
	# an old save: a film spread evenly over the sheet
	var per := v * 1000.0 / (float(_inside_n) * CELL_AREA)
	for i in FCELLS:
		if inside[i] == 1:
			hq[i] = per
			hq0[i] = per
			w[i] = per / heat_per_mm(FLOOD_TEMP_C)
			_active[i] = true
	_pending_mj = v


## Freezes the water for `seconds`: heat goes down through the ice to the
## pipes at a rate set by the thickness and the slab temperature, and slower
## under a deep pool. Returns the heat taken out, MJ (it warms the slab).
func freeze(seconds: float) -> float:
	if _active.is_empty():
		_pending_mj = 0.0
		return 0.0
	var q := freeze_kw() / AREA * clampf(0.55 + (-surface_temp) * 0.09, 0.4, 1.6)  # kJ/s per m2
	var qs := q * seconds
	var out_kj := 0.0
	var done := PackedInt32Array()
	for i: int in _active:
		var h := hq[i]
		var h0 := hq0[i]
		var liq := w[i] * (h / h0) if h0 > 0.0 else 0.0
		var dq := qs
		if liq > 1.0:
			dq = qs / (1.0 + (liq - 1.0) / 1.5)
		if dq >= h - 0.001:
			out_kj += h
			hq[i] = 0.0
			hq0[i] = 0.0
			w[i] = 0.0
			done.append(i)
		else:
			hq[i] = h - dq
			out_kj += dq
	for i in done:
		_active.erase(i)
	var mj := out_kj * CELL_AREA / 1000.0
	_pending_mj = maxf(_pending_mj - mj, 0.0)
	if _active.is_empty():
		_pending_mj = 0.0
	revision += 1
	dirty = Rect2i(0, 0, FW, FD)
	return mj


## Lets standing water run downhill to the low spots: a film thinner than
## FILM_PIN_MM stays put. `passes` sweeps over the wet cells.
func settle(passes := 2) -> void:
	for _p in passes:
		var moved := false
		var cells: Array = _active.keys()
		for i: int in cells:
			var liq := liquid_at(i) - FILM_PIN_MM
			if liq <= 0.0:
				continue
			var fx := i % FW
			var fz := i / FW
			var best := -1
			var drop := 0.3  # mm of fall before it bothers to move
			for nb: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x := fx + nb.x
				var z := fz + nb.y
				if x < 0 or z < 0 or x >= FW or z >= FD:
					continue
				var j := z * FW + x
				if inside[j] == 0:
					continue
				var dh := level_at(i) - level_at(j)
				if dh > drop:
					drop = dh
					best = j
			if best < 0:
				continue
			var mm := minf(liq, drop * 0.45 / ICE_PER_WATER)
			_move_water(i, best, mm)
			moved = true
		if not moved:
			break
	_touch_all()


func _move_water(i: int, j: int, mm: float) -> void:
	var share := clampf(mm / maxf(w[i], 0.0001), 0.0, 1.0)
	var h := hq[i] * share
	var h0 := hq0[i] * share
	w[i] -= mm
	hq[i] -= h
	hq0[i] -= h0
	t[i] -= mm * ICE_PER_WATER
	w[j] += mm
	hq[j] += h
	hq0[j] += h0
	t[j] += mm * ICE_PER_WATER
	var fill := minf(g[j], mm * ICE_PER_WATER)
	g[j] -= fill
	_active[j] = true


## Advances `h` hours: `load_kw` heats the slab, `cooling_kw` comes from the
## plant, `skater_hours` carve it up.
func run(h: float, load_kw: float, cooling_kw: float, skater_hours: float) -> void:
	var flood := freeze(h * 3600.0)
	var net_mj := (load_kw - cooling_kw * insulation()) * 3.6 * h + flood
	surface_temp = clampf(surface_temp + net_mj / heat_capacity_mj(), -14.0, 2.0)
	var melting := surface_temp > -0.5
	if not melting and skater_hours <= 0.0:
		return
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	if melting:
		# the same heat takes a bigger share of a thin sheet: the coarse cells
		# melt now, the fine grid when someone next looks (flush())
		_melt_pending_h += h
		var tt := 0.0
		for b in CELLS:
			thick[b] = maxf(thick[b] - h * 0.3 * clampf(40.0 / maxf(thick[b], 10.0), 0.6, 2.5), 0.0)
			tt += thick[b]
		_avg_t = tt / CELLS
	if skater_hours > 0.0:
		for x in W:
			for z in D:
				var b := x * D + z
				# gouges: thin ice chips through to the soft layer, thick ice holds a deep edge
				var gouge := 1.0 + clampf((30.0 - thick[b]) / 8.0, 0.0, 2.0)
				var d := skater_hours * 0.012 * (0.6 + soft) * gouge * traffic(x, z)
				d = minf(d, smooth[b])
				_wear_pending[b] += d
				smooth[b] -= d
		_snow_pending += skater_hours * 0.006 * (0.6 + soft)
	if true:
		var sm := 0.0
		for b in CELLS:
			sm += smooth[b]
		_avg_s = sm / CELLS
	cleanliness = clampf(cleanliness - skater_hours * 0.015, 0.0, 1.0)
	_snow_pending = minf(_snow_pending, maxf(1.0 - _snow_mean_mm() / SNOW_FULL_MM, 0.0))
	if _avg_t < 25.0:
		paint = maxf(paint - skater_hours * 0.0015 * (25.0 - _avg_t), 0.0)


# ------------------------------------------------------------------ the machines

## A resurface the quick way (a hired driver, or the owner on autopilot):
## shaves `shave_mm` where the blade reaches, floods hot water, and leaves the
## surface as good as `quality` (0..1) allows. `pattern` is the coverage per
## coarse cell (CELLS values, the standard pattern when empty). `chatter`
## 0..1 is a badly set or loose blade: a washboard that caps how smooth the
## ice can get. `level_map` true is the Level-Sense machine: it reads the
## lidar and cuts the high cells deeper and floods the low ones more.
func resurface(quality: float, shave_mm: float, flood_litres: float, pattern: PackedFloat64Array = PackedFloat64Array(), chatter := 0.0, level_map := false, water_c := FLOOD_TEMP_C) -> void:
	flush()
	var p := pattern if pattern.size() == CELLS else standard_pattern()
	var water_mm := flood_litres / AREA
	var mean := _avg_t
	var hpm := heat_per_mm(water_c)
	var targets := PackedFloat32Array()
	targets.resize(CELLS)
	for b in CELLS:
		targets[b] = 1.0 - chatter * (0.25 + 0.2 * float(((b / D) * 7 + (b % D) * 3) % 5) / 4.0)
	var heat_kj := 0.0
	var st := clampf(0.25 + chatter * 1.5 + (1.0 - quality) * 0.3, 0.0, 1.0)
	var snow_keep := 1.0 - (0.5 + 0.5 * quality)
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var b := block[i]
		var c := clampf(p[b], 0.0, 1.0)
		if c <= 0.0:
			continue
		var edge := _edge[i] == 1
		# the blade can't reach the boards; the water runs there
		var cut := shave_mm * c * (0.5 if edge else 1.0)
		var water := water_mm * c * (1.3 if edge else 0.885)
		if level_map:
			var dev := t[i] - mean
			cut = clampf(cut + dev * 0.5, 0.0, shave_mm * 2.5)
			water = maxf(water - dev * 0.3, 0.0)
		var gi := g[i]
		var before := minf(gi / GOUGE_FULL + r[i], 1.0)
		var want := lerpf(before, 1.0 - targets[b], quality * c)
		var ridge := board_m[i] < BLADE_REACH
		if ridge:
			cut *= 0.2
		gi = maxf(gi - cut, 0.0)
		g[i] = gi
		# the blade takes the gouges it reaches; the towel does the rest
		var after := minf(gi / GOUGE_FULL + r[i], 1.0)
		var v := want if want > before else minf(want, after)
		var gr := gi / GOUGE_FULL
		if v >= gr:
			r[i] = clampf(v - gr, 0.0, 1.0)
		else:
			g[i] = v * GOUGE_FULL
			r[i] = 0.0
		s[i] *= 0.85 if ridge else 1.0 - (1.0 - snow_keep) * c
		ang[i] = 0.0
		stri[i] = st
		# old rule: litres over the area count as mm of ice (no 9%)
		t[i] = maxf(t[i] - cut, 0.0) + water
		w[i] += water
		var hh := water * hpm
		hq[i] += hh
		hq0[i] += hh
		heat_kj += hh
		_active[i] = true
	_pending_mj += heat_kj * CELL_AREA / 1000.0
	_touch_all()
	_recalc()
	cleanliness = lerpf(cleanliness, 1.0, 0.4 + 0.6 * quality)
	paint = maxf(paint - shave_mm * 0.004, 0.0)
	flood_heat_mj = pending_heat_mj


## A dry cut: the blade down and no water. Takes `shave_mm` off where the
## pattern goes, makes snow, and leaves a cut surface.
func dry_cut(shave_mm: float, quality: float, chatter := 0.0) -> void:
	flush()
	var p := standard_pattern()
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var b := block[i]
		var edge := is_edge(b / D, b % D)
		var cut := shave_mm * p[b] * (0.5 if edge else 1.0)
		t[i] = maxf(t[i] - cut, 0.0)
		g[i] = maxf(g[i] - cut, 0.0)
		var want := lerpf(rough_at(i), 1.0 - (0.85 - chatter * 0.3), 0.5 * quality * p[b])
		_set_rough(i, want)
		ang[i] = 0.0
		stri[i] = clampf(0.6 + chatter, 0.0, 1.0)
		if board_m[i] >= BLADE_REACH:
			s[i] += 0.15 * SNOW_FULL_MM
	_touch_all()
	_recalc()
	paint = maxf(paint - shave_mm * 0.004, 0.0)


## The edger along the boards: takes up to `mm` off the strip the blade
## can't reach (and a little more, feathered out to a metre), and spits the
## shavings onto the ice beside it for the resurfacer to pick up.
func edge_cut(mm: float, quality: float) -> void:
	flush()
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var b := block[i]
		if not is_edge(b / D, b % D):
			continue
		var d := board_m[i]
		var k := 1.0 if d < 1.6 else clampf(1.0 - (d - 1.6) / 1.5, 0.0, 1.0)
		var cut := minf(mm * quality * k, t[i])
		t[i] -= cut
		g[i] = maxf(g[i] - cut, 0.0)
		r[i] = maxf(r[i] - 0.1 * quality * k, 0.0)
		# the disc throws its snow a pace out from the boards
		var p := cell_pos(i % FW, i / FW)
		var j := cell_at(p - Rink.board_normal(p) * 0.9)
		s[j] += cut * 1.5
	_touch_all()
	_recalc()


## The chipper along the boards: breaks up the slush and snow ridge the
## blade can't reach and drags it out where the resurfacer can pick it up.
## `quality` 0..1 is how much of it comes away. Returns snow moved, litres.
func chip_boards(quality: float) -> float:
	flush()
	var moved := 0.0
	for i in FCELLS:
		if inside[i] == 0 or board_m[i] >= BLADE_REACH or s[i] <= 0.0:
			continue
		var take := s[i] * clampf(quality, 0.0, 1.0)
		s[i] -= take
		var p := cell_pos(i % FW, i / FW)
		var j := cell_at(p - Rink.board_normal(p) * 0.7)
		s[j] += take
		moved += take * CELL_AREA
	_touch_all()
	return moved


## Snow in the ridge along the boards, litres.
func board_ridge_litres() -> float:
	var tot := 0.0
	for i in FCELLS:
		if inside[i] == 1 and board_m[i] < BLADE_REACH:
			tot += s[i] * CELL_AREA
	return tot


## How much higher the strip along the boards is than the rest, mm.
func edge_lip_mm() -> float:
	var e := 0.0
	var ne := 0
	var c := 0.0
	var nc := 0
	for x in W:
		for z in D:
			if is_edge(x, z):
				e += thick[x * D + z]
				ne += 1
			else:
				c += thick[x * D + z]
				nc += 1
	return e / ne - c / nc


## The shape of the sheet, mm: `bowl` is how much higher the ice is a metre
## from the boards than at centre (a soup bowl from the stands when it's
## positive, a crown when negative); `dish` is how far the lowest 3 m patch
## sits under the sheet's middle (Earl's dish at the home blue line).
func profile() -> Dictionary:
	flush()
	var ring := 0.0
	var nr := 0
	var mid := 0.0
	var nm := 0
	for i in FCELLS:
		if inside[i] == 0:
			continue
		var d := board_m[i]
		if d < 1.2:
			ring += level_at(i)
			nr += 1
		elif d > 6.0:
			mid += level_at(i)
			nm += 1
	mid /= maxf(nm, 1)
	var low := 1e9
	for x in range(1, W - 1):
		for z in range(1, D - 1):
			low = minf(low, thick[x * D + z])
	var inner := 0.0
	var ni := 0
	for x in range(1, W - 1):
		for z in range(1, D - 1):
			inner += thick[x * D + z]
			ni += 1
	inner /= ni
	return {"bowl": ring / maxf(nr, 1) - mid, "dish": inner - low}


## Words for how the ice is right now, for the tools and the walk.
func states() -> PackedStringArray:
	var out := PackedStringArray()
	if wetness() > 0.25:
		out.append("wet")
	if snow > 0.35:
		out.append("snowed up")
	if surface_temp > -0.5:
		out.append("melting")
	elif surface_temp > -3.0:
		out.append("warm")
	elif surface_temp < -7.0:
		out.append("cold")
	if thickness_mm > 40.0:
		out.append("thick")
	elif thickness_mm < 25.0:
		out.append("thin")
	var pr := profile()
	if float(pr.bowl) > 6.0:
		out.append("bowled")
	elif float(pr.bowl) < -4.0:
		out.append("crowned")
	if float(pr.dish) > 4.0:
		out.append("dished")
	if felt_smoothness() < 0.45:
		out.append("chewed up")
	if board_ridge_litres() > 120.0:
		out.append("ridged at the boards")
	return out


## 0..1: a flat sheet with no lip at the boards is 1.
func level_score() -> float:
	var mean := 0.0
	var n := 0
	for x in range(1, W - 1):
		for z in range(1, D - 1):
			mean += thick[x * D + z]
			n += 1
	mean /= n
	var v := 0.0
	for x in range(1, W - 1):
		for z in range(1, D - 1):
			v += pow(thick[x * D + z] - mean, 2.0)
	var sd := sqrt(v / n)
	return clampf(1.0 - maxf(edge_lip_mm(), 0.0) / 25.0 - sd / 10.0, 0.0, 1.0)


## Standard deviation of the ice top (concrete heave plus ice) over the
## fine cells away from the boards, mm: what a survey finds.
func level_sd_mm() -> float:
	var mean := 0.0
	var n := 0
	for i in FCELLS:
		if inside[i] == 1 and board_m[i] > 1.0:
			mean += level_at(i)
			n += 1
	mean /= maxf(n, 1)
	var v := 0.0
	for i in FCELLS:
		if inside[i] == 1 and board_m[i] > 1.0:
			v += pow(level_at(i) - mean, 2.0)
	return sqrt(v / maxf(n, 1))


## Mean gouge depth over the sheet, mm.
func mean_gouge_mm() -> float:
	flush()
	var tot := 0.0
	for i in FCELLS:
		if inside[i] == 1:
			tot += g[i]
	return tot / float(_inside_n)


## Smoothness as players feel it: half the average, half the worst quarter.
func felt_smoothness() -> float:
	var a := Array(smooth)
	a.sort()
	var q := 0.0
	var n := CELLS / 4
	for i in n:
		q += float(a[i])
	return 0.5 * _avg_s + 0.5 * q / n


## How hard and fast the surface plays, 0 soft and grippy to 1 hard, fast and
## skiddy: colder and thinner is harder, a wet flood softens it. This is the one
## value Hockey physics reads (PhysicsProfile maps it to puck friction, skid
## and skate grip).
func hardness() -> float:
	var cold := clampf((-surface_temp - 2.0) / 6.0, 0.0, 1.0)      # -2 C soft, -8 C rock hard
	var thin := clampf((50.0 - thickness_mm) / 25.0, 0.0, 1.0)      # 50 mm soft, 25 mm hard
	return clampf((0.7 * cold + 0.3 * thin) * (1.0 - 0.5 * wetness()), 0.0, 1.0)


## How good the ice is for `use`, 0..100. This is what organisations judge.
func rating(use: String) -> float:
	var target: float = TARGET_TEMP.get(use, -5.0)
	var temp_score := clampf(1.0 - absf(surface_temp - target) / 4.0, 0.0, 1.0)
	var ideal: Vector2 = IDEAL_THICKNESS.get(use, Vector2(28.0, 40.0))
	var tk := thickness_mm
	var thick_score := 1.0
	if tk < ideal.x:
		thick_score = clampf(1.0 - (ideal.x - tk) / 14.0, 0.0, 1.0)
	elif tk > ideal.y:
		thick_score = clampf(1.0 - (tk - ideal.y) / 30.0, 0.4, 1.0)
	var rt: float = WEIGHTS.temp * temp_score + WEIGHTS.smooth * felt_smoothness() + WEIGHTS.snow * (1.0 - snow) \
		+ WEIGHTS.clean * cleanliness + WEIGHTS.thick * thick_score + WEIGHTS.level * level_score() + WEIGHTS.paint * paint
	rt *= 1.0 - float(WET_PENALTY.get(use, 0.3)) * wetness()
	return 100.0 * rt * (clampf((tk - 6.0) / 12.0, 0.0, 1.0) if tk < 18.0 else 1.0)


## The grid for the office screen: thickness in mm, then smoothness as a
## shade (" " glass to "#" chewed up). Home end on the left.
func grid_text() -> String:
	var shades := " .:-=+*#"
	var lines: Array = ["Thickness (mm), home end left:"]
	for z in D:
		var row := ""
		for x in W:
			row += "%3d" % int(round(thick[x * D + z]))
		lines.append(row)
	lines.append("Smoothness (blank is glass, # is chewed up):")
	for z in D:
		var row := ""
		for x in W:
			var k := clampi(int((1.0 - smooth[x * D + z]) * shades.length()), 0, shades.length() - 1)
			row += "  " + shades[k]
		lines.append(row)
	return "\n".join(lines)


# ------------------------------------------------------------------ save

## The fine arrays in a save: 16 bits a cell at these steps, deflated (the
## thickness keeps all 32, so a loaded rink plays on exactly).
const SAVE_STEP := {"t": 0.0, "g": 0.0001, "r": 1.0 / 65535.0, "s": 0.002, "w": 0.0005, "hq": 0.05, "hq0": 0.05,
	"ang": 1.0 / 65535.0, "stri": 1.0 / 65535.0}


static func _pack16(arr: PackedFloat32Array, step: float) -> String:
	if step <= 0.0:
		return Marshalls.raw_to_base64(arr.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))
	var raw := PackedByteArray()
	raw.resize(arr.size() * 2)
	for i in arr.size():
		raw.encode_u16(i * 2, clampi(int(round(arr[i] / step)), 0, 65535))
	return Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))


static func _unpack16(b64: String, step: float) -> PackedFloat32Array:
	if step <= 0.0:
		return Marshalls.base64_to_raw(b64).decompress(FCELLS * 4, FileAccess.COMPRESSION_DEFLATE).to_float32_array()
	var raw := Marshalls.base64_to_raw(b64).decompress(FCELLS * 2, FileAccess.COMPRESSION_DEFLATE)
	var out := PackedFloat32Array()
	if raw.size() != FCELLS * 2:
		return out
	out.resize(FCELLS)
	for i in FCELLS:
		out[i] = float(raw.decode_u16(i * 2)) * step
	return out


## Version 2 keeps the old keys (`thick`, `smooth` and the sheet values) for
## anything that reads them, and adds the fine grid, 16 bits a cell.
func to_dict() -> Dictionary:
	flush()
	var fine := {}
	for k: String in SAVE_STEP:
		fine[k] = _pack16(get(k), float(SAVE_STEP[k]))
	return {"version": VERSION, "surface_temp": surface_temp, "cleanliness": cleanliness, "paint": paint, "snow": snow,
		"pending_heat_mj": pending_heat_mj, "flood_heat_mj": flood_heat_mj,
		"thick": Array(thick), "smooth": Array(smooth), "plates": plates.duplicate(), "fine": fine,
		"rng_state": str(_rng.state)}


func load_dict(d: Dictionary) -> void:
	var fine: Dictionary = d.get("fine", {})
	if int(d.get("version", 1)) >= 2 and not fine.is_empty():
		for k: String in fine:
			if not SAVE_STEP.has(k):
				continue
			var arr := _unpack16(str(fine[k]), float(SAVE_STEP[k]))
			if arr.size() == FCELLS:
				set(k, arr)
		_active.clear()
		_pending_mj = 0.0
		for i in FCELLS:
			if w[i] > 0.0 and hq[i] > 0.0:
				_active[i] = true
				_pending_mj += hq[i] * CELL_AREA / 1000.0
		_wear_pending.fill(0.0)
		_snow_pending = 0.0
		surface_temp = float(d.get("surface_temp", surface_temp))
		cleanliness = float(d.get("cleanliness", cleanliness))
		paint = float(d.get("paint", paint))
		flood_heat_mj = float(d.get("flood_heat_mj", flood_heat_mj))
		var pl: Array = d.get("plates", ["centre"])
		plates = pl.duplicate()
		_rng.state = int(d.get("rng_state", "0")) if str(d.get("rng_state", "")) != "" else _rng.state
		_touch_all()
		_recalc()
		return
	_load_v1(d)


## A version 1 save: the coarse grid (or just the sheet averages) becomes the
## fine grid block by block.
func _load_v1(d: Dictionary) -> void:
	var tk: Array = d.get("thick", [])
	var sm: Array = d.get("smooth", [])
	if tk.size() == CELLS:
		for i in FCELLS:
			t[i] = float(tk[block[i]])
	if sm.size() == CELLS:
		for i in FCELLS:
			var v := 1.0 - float(sm[block[i]])
			g[i] = minf(v, 0.6) * 0.6 * GOUGE_FULL
			r[i] = maxf(v - g[i] / GOUGE_FULL, 0.0)
	_recalc()
	for k in d:
		if k in ["thick", "smooth", "version", "fine", "plates", "rng_state", "pending_heat_mj"]:
			continue
		if tk.size() == CELLS and k == "thickness_mm":
			continue
		if sm.size() == CELLS and k == "smoothness":
			continue
		if k in self:
			set(k, float(d[k]))  # old saves: thickness_mm and smoothness shift the grid
	if d.has("pending_heat_mj"):
		_set_pending(float(d.pending_heat_mj))
	_touch_all()
	_recalc()
