class_name ResurfacerSim
extends RefCounted
## Doris, Millbrook's 1974 Zambelli Model 525, as a machine that wears out.
## A resurface takes about 15 minutes: the blade shaves, the augers carry the
## snow to the tank, the conditioner washes and the towel lays hot water.
## A dull blade, a torn towel or a tired engine all show up on the ice.

const FLOOD_LITRES := 450.0
const RESURFACE_HOURS := 0.25

var parts := {}         # id -> SimPart
var engine_oil := 0.6   # 1 fresh, 0 sludge
var fuel := 0.7         # tank fraction
var blade_height_mm := 1.0  # set when the blade is changed; 0.8-1.2 shaves cleanly


static func create_doris() -> ResurfacerSim:
	var r := ResurfacerSim.new()
	# life in resurfacing hours; four resurfaces a day is about one hour
	for p in [
		SimPart.make("blade", "Ice blade (77 in)", 30.0, 160.0, 0.05, 0.4),
		SimPart.make("spark_plugs", "Spark plugs (set of 4)", 400.0, 28.0, 0.05, 0.35),
		SimPart.make("air_filter", "Air filter", 250.0, 22.0, 0.0, 0.3),
		SimPart.make("towel", "Conditioner towel", 60.0, 85.0, 0.05, 0.5),
		SimPart.make("squeegee", "Squeegee", 180.0, 55.0, 0.05, 0.6),
		SimPart.make("auger_bearing", "Horizontal auger bearing", 900.0, 120.0, 0.05, 0.5),
		SimPart.make("hydraulic_hose", "Conditioner hydraulic hose", 1500.0, 95.0, 0.05, 0.45),
		SimPart.make("tires", "Studded tires (set)", 2500.0, 640.0, 0.05, 0.6),
	]:
		r.parts[p.id] = p
	return r


func part(id: String) -> SimPart:
	return parts[id]


## Why Doris won't go, or "" if she will.
func fault() -> String:
	if engine_oil < 0.03:
		return "seized"
	if part("spark_plugs").failed():
		return "won't start"
	if fuel <= 0.0:
		return "out of gas"
	if part("hydraulic_hose").failed():
		return "hydraulic leak"
	return ""


## Runs one resurface on `ice`. `skill` is the driver (the owner starts around
## 0.6). Returns the quality 0..1, or -1 if Doris won't go.
func resurface(ice: IceSlab, skill: float) -> float:
	if fault() != "":
		return -1.0
	var hard := clampf((-ice.surface_temp - 3.0) / 4.0, 0.0, 1.5)
	var blade := part("blade")
	var height_ok := clampf(1.0 - absf(blade_height_mm - 1.0) * 2.0, 0.2, 1.0)
	var cut := blade.condition * height_ok
	var condition := part("towel").condition * 0.6 + part("squeegee").condition * 0.4
	var engine := 0.7 + 0.3 * minf(part("spark_plugs").condition, 1.0 - 0.5 * (1.0 - part("air_filter").condition))
	var q := clampf((0.45 * cut + 0.35 * condition + 0.2 * engine) * (0.6 + 0.4 * skill), 0.0, 1.0)
	var shave := 0.5 * cut * engine
	ice.resurface(q, shave, FLOOD_LITRES * (0.7 + 0.3 * condition))
	for id in parts:
		var stress := 1.0 + (hard * 0.8 if id == "blade" else 0.0)
		(parts[id] as SimPart).run(RESURFACE_HOURS, stress)
	engine_oil = maxf(engine_oil - RESURFACE_HOURS / 120.0, 0.0)
	fuel = maxf(fuel - 0.045, 0.0)
	return q


func to_dict() -> Dictionary:
	var ps := {}
	for id in parts:
		ps[id] = parts[id].to_dict()
	return {"parts": ps, "engine_oil": engine_oil, "fuel": fuel, "blade_height_mm": blade_height_mm}


func load_dict(d: Dictionary) -> void:
	var ps: Dictionary = d.get("parts", {})
	for id in ps:
		if parts.has(id):
			parts[id].load_dict(ps[id])
	engine_oil = float(d.get("engine_oil", engine_oil))
	fuel = float(d.get("fuel", fuel))
	blade_height_mm = float(d.get("blade_height_mm", blade_height_mm))
