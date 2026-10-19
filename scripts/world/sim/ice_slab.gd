class_name IceSlab
extends RefCounted
## The sheet of ice: a 61 x 26 m slab on a concrete floor full of glycol pipe.
## Hockey wants a hard surface around -5.5 C, figure skating a softer -3.5 C.
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
## The sheet is a 20 x 8 grid of cells (about 3.05 x 3.24 m each) for
## thickness and smoothness. x runs along the rink (0 is the home end), z
## across it (0 is the bench side). The outer ring of cells is the strip
## along the boards, where flood water collects and the blade can't reach.
## `thickness_mm` and `smoothness` are the averages over the grid; setting
## either shifts every cell by the same amount, so old callers keep working.

const AREA := 61.0 * 26.0
const W := 20   # cells along the rink
const D := 8    # cells across it
const CELLS := W * D
const TARGET_TEMP := {"hockey": -5.5, "figure": -3.5, "public": -4.5}
## Thickness each use likes best, in mm (it rates fine anywhere in the range).
const IDEAL_THICKNESS := {"hockey": Vector2(25.0, 34.0), "figure": Vector2(36.0, 50.0), "public": Vector2(28.0, 45.0)}
## How much a wet surface costs each use (0 shrugs, 1 refuses to skate on it).
const WET_PENALTY := {"hockey": 0.6, "figure": 0.2, "public": 0.3}
## Rating weights (docs/world/RINK_SIM.md 3.2, "Ice rating").
const WEIGHTS := {"temp": 0.30, "smooth": 0.25, "snow": 0.10, "clean": 0.10, "thick": 0.10, "level": 0.08, "paint": 0.07}

var surface_temp := -4.0
var cleanliness := 0.8  # tape, puck marks, rust, mud from the lobby door
var paint := 0.6        # lines and logos; shaved through as the ice thins
var snow := 0.0         # loose snow from skating, 0 clean to 1 a skipped flood or three
var pending_heat_mj := 0.0  # flood water still freezing in
var flood_heat_mj := 0.0    # heat of the last flood, for how wet it still is

## Per-cell truth, index x * D + z.
var thick := PackedFloat64Array()
var smooth := PackedFloat64Array()

var _avg_t := 48.0
var _avg_s := 0.7

## Average thickness over the grid, mm. Setting it shifts every cell.
var thickness_mm: float:
	get:
		return _avg_t
	set(v):
		var dv := v - _avg_t
		for i in CELLS:
			thick[i] = maxf(thick[i] + dv, 0.0)
		_recalc()

## Average smoothness over the grid, 1 glass, 0 ruts and chips everywhere.
var smoothness: float:
	get:
		return _avg_s
	set(v):
		var dv := v - _avg_s
		for i in CELLS:
			smooth[i] = clampf(smooth[i] + dv, 0.0, 1.0)
		_recalc()


func _init() -> void:
	thick.resize(CELLS)
	smooth.resize(CELLS)
	for i in CELLS:
		thick[i] = 48.0
		smooth[i] = 0.7
	_recalc()


## Millbrook as Earl left it: 48 mm on average (Earl likes it thick), 12 mm
## higher along the boards than at centre, a 6 mm low spot at the home blue
## line where the roof drips in spring, surface around -4 C.
static func create_millbrook() -> IceSlab:
	var s := IceSlab.new()
	for x in W:
		for z in D:
			var t := 0.0
			if is_edge(x, z):
				t += 12.0
			if x == 7 and (z == 3 or z == 4):
				t -= 6.0
			s.thick[x * D + z] = t
	s._recalc()
	s.thickness_mm = 48.0
	return s


static func is_edge(x: int, z: int) -> bool:
	return x == 0 or z == 0 or x == W - 1 or z == D - 1


## How much traffic a cell takes relative to the average: the creases, the
## faceoff dots and centre ice get chewed, the strip along the boards less.
static func traffic(x: int, z: int) -> float:
	var t := 1.0
	if (x <= 2 or x >= W - 3) and (z == 3 or z == 4):
		t = 1.8
	elif (x == 4 or x == W - 5) and (z == 2 or z == 5):
		t = 1.5
	elif (x == 9 or x == 10) and (z == 3 or z == 4):
		t = 1.3
	elif is_edge(x, z):
		t = 0.7
	return t / 0.99  # the mean of the map above, so the sheet wears as before on average


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


func _recalc() -> void:
	var t := 0.0
	var s := 0.0
	for i in CELLS:
		t += thick[i]
		s += smooth[i]
	_avg_t = t / CELLS
	_avg_s = s / CELLS


## {"thickness_mm", "smoothness", "edge"} for one cell.
func cell(x: int, z: int) -> Dictionary:
	var i := clampi(x, 0, W - 1) * D + clampi(z, 0, D - 1)
	return {"thickness_mm": thick[i], "smoothness": smooth[i], "edge": is_edge(x, z)}


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


## Advances `h` hours: `load_kw` heats the slab, `cooling_kw` comes from the
## plant, `skater_hours` carve it up.
func run(h: float, load_kw: float, cooling_kw: float, skater_hours: float) -> void:
	var flood := minf(pending_heat_mj, freeze_kw() * 3.6 * h)
	pending_heat_mj -= flood
	var net_mj := (load_kw - cooling_kw * insulation()) * 3.6 * h + flood
	surface_temp = clampf(surface_temp + net_mj / heat_capacity_mj(), -14.0, 2.0)
	var melting := surface_temp > -0.5
	if not melting and skater_hours <= 0.0:
		return
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	for x in W:
		for z in D:
			var i := x * D + z
			var t := thick[i]
			if melting:
				# the same heat takes a bigger share of a thin sheet
				t = maxf(t - h * 0.3 * clampf(40.0 / maxf(t, 10.0), 0.6, 2.5), 0.0)
				thick[i] = t
			if skater_hours > 0.0:
				# gouges: thin ice chips through to the soft layer, thick ice holds a deep edge
				var gouge := 1.0 + clampf((30.0 - t) / 8.0, 0.0, 2.0)
				smooth[i] = clampf(smooth[i] - skater_hours * 0.012 * (0.6 + soft) * gouge * traffic(x, z), 0.0, 1.0)
	_recalc()
	cleanliness = clampf(cleanliness - skater_hours * 0.015, 0.0, 1.0)
	snow = clampf(snow + skater_hours * 0.006 * (0.6 + soft), 0.0, 1.0)
	if _avg_t < 25.0:
		paint = maxf(paint - skater_hours * 0.0015 * (25.0 - _avg_t), 0.0)


## A resurface: shaves `shave_mm` where the blade reaches, floods hot water,
## and leaves the surface as good as `quality` (0..1) allows. `pattern` is the
## coverage per cell (CELLS values, the standard pattern when empty).
## `chatter` 0..1 is a badly set or loose blade: a washboard that caps how
## smooth the ice can get.
func resurface(quality: float, shave_mm: float, flood_litres: float, pattern: PackedFloat64Array = PackedFloat64Array(), chatter := 0.0) -> void:
	var p := pattern if pattern.size() == CELLS else standard_pattern()
	var water_mm := flood_litres / AREA
	for x in W:
		for z in D:
			var i := x * D + z
			var c := clampf(p[i], 0.0, 1.0)
			var edge := is_edge(x, z)
			# the blade can't reach the boards; the water runs there
			var cut := shave_mm * c * (0.5 if edge else 1.0)
			var water := water_mm * c * (1.3 if edge else 0.885)
			thick[i] = maxf(thick[i] - cut + water, 0.0)
			var target := 1.0 - chatter * (0.25 + 0.2 * float((x * 7 + z * 3) % 5) / 4.0)
			smooth[i] = lerpf(smooth[i], target, quality * c)
	_recalc()
	cleanliness = lerpf(cleanliness, 1.0, 0.4 + 0.6 * quality)
	snow = lerpf(snow, 0.0, 0.5 + 0.5 * quality)
	paint = maxf(paint - shave_mm * 0.004, 0.0)
	# 60 C water: cool it to 0, freeze it, then chill the new ice a little
	var heat := flood_litres * (4.18 * 60.0 + 334.0) / 1000.0
	pending_heat_mj += heat
	flood_heat_mj = pending_heat_mj


## A dry cut: the blade down and no water. Takes `shave_mm` off where the
## pattern goes, makes snow, and leaves a cut surface.
func dry_cut(shave_mm: float, quality: float, chatter := 0.0) -> void:
	var p := standard_pattern()
	for x in W:
		for z in D:
			var i := x * D + z
			thick[i] = maxf(thick[i] - shave_mm * p[i] * (0.5 if is_edge(x, z) else 1.0), 0.0)
			smooth[i] = lerpf(smooth[i], 0.85 - chatter * 0.3, 0.5 * quality * p[i])
	_recalc()
	paint = maxf(paint - shave_mm * 0.004, 0.0)
	snow = clampf(snow + 0.15, 0.0, 1.0)


## The edger along the boards: takes up to `mm` off the strip by the boards.
func edge_cut(mm: float, quality: float) -> void:
	for x in W:
		for z in D:
			if is_edge(x, z):
				var i := x * D + z
				thick[i] = maxf(thick[i] - mm * quality, 0.0)
				smooth[i] = minf(smooth[i] + 0.1 * quality, 1.0)
	_recalc()
	snow = clampf(snow + 0.05, 0.0, 1.0)


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
	var t := thickness_mm
	var thick_score := 1.0
	if t < ideal.x:
		thick_score = clampf(1.0 - (ideal.x - t) / 14.0, 0.0, 1.0)
	elif t > ideal.y:
		thick_score = clampf(1.0 - (t - ideal.y) / 30.0, 0.4, 1.0)
	var r: float = WEIGHTS.temp * temp_score + WEIGHTS.smooth * felt_smoothness() + WEIGHTS.snow * (1.0 - snow) \
		+ WEIGHTS.clean * cleanliness + WEIGHTS.thick * thick_score + WEIGHTS.level * level_score() + WEIGHTS.paint * paint
	r *= 1.0 - float(WET_PENALTY.get(use, 0.3)) * wetness()
	return 100.0 * r * (clampf((t - 6.0) / 12.0, 0.0, 1.0) if t < 18.0 else 1.0)


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


func to_dict() -> Dictionary:
	return {"surface_temp": surface_temp, "cleanliness": cleanliness, "paint": paint, "snow": snow,
		"pending_heat_mj": pending_heat_mj, "flood_heat_mj": flood_heat_mj,
		"thick": Array(thick), "smooth": Array(smooth)}


func load_dict(d: Dictionary) -> void:
	for k in d:
		if k == "thick" or k == "smooth":
			continue
		if k in self:
			set(k, float(d[k]))  # old saves: thickness_mm and smoothness shift the grid
	var t: Array = d.get("thick", [])
	var s: Array = d.get("smooth", [])
	if t.size() == CELLS:
		for i in CELLS:
			thick[i] = float(t[i])
	if s.size() == CELLS:
		for i in CELLS:
			smooth[i] = float(s[i])
	_recalc()
