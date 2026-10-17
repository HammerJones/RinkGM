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

const AREA := 61.0 * 26.0
const TARGET_TEMP := {"hockey": -5.5, "figure": -3.5, "public": -4.5}
## Thickness each use likes best, in mm (it rates fine anywhere in the range).
const IDEAL_THICKNESS := {"hockey": Vector2(25.0, 34.0), "figure": Vector2(36.0, 50.0), "public": Vector2(28.0, 45.0)}
## How much a wet surface costs each use (0 shrugs, 1 refuses to skate on it).
const WET_PENALTY := {"hockey": 0.6, "figure": 0.2, "public": 0.3}

var surface_temp := -4.0
var thickness_mm := 48.0  # Millbrook starts thick: Earl likes it that way
var smoothness := 0.7   # 1 glass, 0 ruts and chips everywhere
var cleanliness := 0.8  # snow, tape, puck marks
var paint := 0.6        # lines and logos; shaved through as the ice thins
var pending_heat_mj := 0.0  # flood water still freezing in
var flood_heat_mj := 0.0    # heat of the last flood, for how wet it still is


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
	if surface_temp > -0.5:
		# melting: the same heat takes a bigger share of a thin sheet
		thickness_mm = maxf(thickness_mm - h * 1.5 * clampf(40.0 / maxf(thickness_mm, 10.0), 0.6, 2.5), 0.0)
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	# gouges: thin ice chips through to the soft layer, thick ice holds a deep edge
	var gouge := 1.0 + clampf((30.0 - thickness_mm) / 8.0, 0.0, 2.0)
	smoothness = clampf(smoothness - skater_hours * 0.012 * (0.6 + soft) * gouge, 0.0, 1.0)
	cleanliness = clampf(cleanliness - skater_hours * 0.015, 0.0, 1.0)
	if thickness_mm < 25.0:
		paint = maxf(paint - skater_hours * 0.0015 * (25.0 - thickness_mm), 0.0)


## A resurface: shaves `shave_mm`, floods hot water, and leaves the surface
## as good as `quality` (0..1) allows.
func resurface(quality: float, shave_mm: float, flood_litres: float) -> void:
	thickness_mm = maxf(thickness_mm - shave_mm + flood_litres / AREA, 0.0)
	smoothness = lerpf(smoothness, 1.0, quality)
	cleanliness = lerpf(cleanliness, 1.0, 0.4 + 0.6 * quality)
	paint = maxf(paint - shave_mm * 0.004, 0.0)
	# 60 C water: cool it to 0, freeze it, then chill the new ice a little
	var heat := flood_litres * (4.18 * 60.0 + 334.0) / 1000.0
	pending_heat_mj += heat
	flood_heat_mj = pending_heat_mj


## How good the ice is for `use`, 0..100. This is what organisations judge.
func rating(use: String) -> float:
	var target: float = TARGET_TEMP.get(use, -5.0)
	var temp_score := clampf(1.0 - absf(surface_temp - target) / 4.0, 0.0, 1.0)
	var ideal: Vector2 = IDEAL_THICKNESS.get(use, Vector2(28.0, 40.0))
	var thick_score := 1.0
	if thickness_mm < ideal.x:
		thick_score = clampf(1.0 - (ideal.x - thickness_mm) / 14.0, 0.0, 1.0)
	elif thickness_mm > ideal.y:
		thick_score = clampf(1.0 - (thickness_mm - ideal.y) / 30.0, 0.4, 1.0)
	var r := 0.33 * temp_score + 0.3 * smoothness + 0.15 * cleanliness + 0.14 * thick_score + 0.08 * paint
	r *= 1.0 - float(WET_PENALTY.get(use, 0.3)) * wetness()
	return 100.0 * r * (clampf((thickness_mm - 6.0) / 12.0, 0.0, 1.0) if thickness_mm < 18.0 else 1.0)


func to_dict() -> Dictionary:
	return {"surface_temp": surface_temp, "thickness_mm": thickness_mm, "smoothness": smoothness,
		"cleanliness": cleanliness, "paint": paint, "pending_heat_mj": pending_heat_mj, "flood_heat_mj": flood_heat_mj}


func load_dict(d: Dictionary) -> void:
	for k in d:
		if k in self:
			set(k, float(d[k]))
