class_name IceSlab
extends RefCounted
## The sheet of ice: a 61 x 26 m slab on a concrete floor full of glycol pipe.
## Hockey wants a hard surface around -5.5 C, figure skating a softer -3.5 C.
## Ideal thickness is about 32 mm (1 1/4 in): thinner risks soft spots and
## cracks, thicker insulates the surface from the pipes and costs power.

const AREA := 61.0 * 26.0
const HEAT_CAPACITY_MJ_PER_K := 250.0  # ice plus the top of the concrete
const TARGET_TEMP := {"hockey": -5.5, "figure": -3.5, "public": -4.5}

var surface_temp := -4.0
var thickness_mm := 38.0
var smoothness := 0.7   # 1 glass, 0 ruts and chips everywhere
var cleanliness := 0.8  # snow, tape, puck marks
var paint := 0.6        # lines and logos; shaved through as the ice thins
var pending_heat_mj := 0.0  # flood water still freezing in


## Advances `h` hours: `load_kw` heats the slab, `cooling_kw` comes from the
## plant, `skater_hours` carve it up.
func run(h: float, load_kw: float, cooling_kw: float, skater_hours: float) -> void:
	var insulation := clampf(1.0 - (thickness_mm - 32.0) / 120.0, 0.55, 1.05)
	var flood := minf(pending_heat_mj, 90.0 * 3.6 * h)  # freezes in at up to ~90 kW
	pending_heat_mj -= flood
	var net_mj := (load_kw - cooling_kw * insulation) * 3.6 * h + flood
	surface_temp = clampf(surface_temp + net_mj / HEAT_CAPACITY_MJ_PER_K, -14.0, 2.0)
	if surface_temp > -0.5:
		thickness_mm = maxf(thickness_mm - h * 1.5, 0.0)  # it's melting
	var soft := clampf((surface_temp + 6.0) / 4.0, 0.0, 1.5)
	smoothness = clampf(smoothness - skater_hours * 0.012 * (0.6 + soft), 0.0, 1.0)
	cleanliness = clampf(cleanliness - skater_hours * 0.015, 0.0, 1.0)


## A resurface: shaves `shave_mm`, floods hot water, and leaves the surface
## as good as `quality` (0..1) allows.
func resurface(quality: float, shave_mm: float, flood_litres: float) -> void:
	thickness_mm = maxf(thickness_mm - shave_mm + flood_litres / AREA, 0.0)
	smoothness = lerpf(smoothness, 1.0, quality)
	cleanliness = lerpf(cleanliness, 1.0, 0.4 + 0.6 * quality)
	paint = maxf(paint - shave_mm * 0.004, 0.0)
	# 60 C water: cool it to 0, freeze it, then chill the new ice a little
	pending_heat_mj += flood_litres * (4.18 * 60.0 + 334.0) / 1000.0


## How good the ice is for `use`, 0..100. This is what organisations judge.
func rating(use: String) -> float:
	var target: float = TARGET_TEMP.get(use, -5.0)
	var temp_score := clampf(1.0 - absf(surface_temp - target) / 4.0, 0.0, 1.0)
	var thick_score := 1.0
	if thickness_mm < 25.0:
		thick_score = clampf((thickness_mm - 12.0) / 13.0, 0.0, 1.0)
	elif thickness_mm > 45.0:
		thick_score = clampf(1.0 - (thickness_mm - 45.0) / 40.0, 0.4, 1.0)
	var r := 0.35 * temp_score + 0.3 * smoothness + 0.15 * cleanliness + 0.12 * thick_score + 0.08 * paint
	return 100.0 * r * (thick_score if thickness_mm < 18.0 else 1.0)


func to_dict() -> Dictionary:
	return {"surface_temp": surface_temp, "thickness_mm": thickness_mm, "smoothness": smoothness,
		"cleanliness": cleanliness, "paint": paint, "pending_heat_mj": pending_heat_mj}


func load_dict(d: Dictionary) -> void:
	for k in d:
		if k in self:
			set(k, float(d[k]))
