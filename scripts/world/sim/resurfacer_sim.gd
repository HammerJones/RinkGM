class_name ResurfacerSim
extends RefCounted
## Doris, Millbrook's 1974 Zambelli Model 525, as a machine that wears out.
## A resurface takes about 15 minutes: the blade shaves, the augers carry the
## snow to the tank, the conditioner washes and the towel lays hot water.
## A dull blade, a torn towel or a tired engine all show up on the ice.

## What the quick way (a hired driver, the auto floods) lays per flood, L:
## about 40% of the tank, which drivers do between periods.
const FLOOD_LITRES := 450.0
const RESURFACE_HOURS := 0.25
## Doris's tanks and tools (docs/world/ICE.md 4; a Zambelli 525 carries an
## arena-size flood tank like the big Zamboni-class machines).
const FLOOD_TANK_L := 1100.0     # 290 US gal: a full tank laid evenly is 1/32 in of ice
const WASH_TANK_L := 270.0       # 72 US gal
const SNOW_TANK_M3 := 3.5        # 124 cu ft of compacted snow
const SNOW_PACK := 0.6           # t/m3: the augers pack the shavings in the tank
const BLADE_W_M := 1.956         # 77 in
const BLADE_MAX_MM := 3.175      # 1/8 in: the hand wheel's stop
const WHEEL_MM_PER_TURN := 0.79375  # 1/32 in a turn of the blade wheel
## Bay hot-water heater: flood water at this temperature by default, C.
const FLOOD_TEMP_C := 60.0
## Gas to heat flood water from the 10 C main, $ per MJ (an 80% heater).
const GAS_PER_MJ := 0.0148
## Hours of running from a clean carburettor to a varnished one.
const CARB_LIFE_H := 200.0

var parts := {}         # id -> SimPart
var engine_oil := 0.6   # 1 fresh, 0 sludge
## The carburettor's jets and float bowl, 1 clean, 0 varnished shut. It gums
## up over about 200 h; below half it starves her a little (engine_factor).
var carb := 0.8
var fuel := 0.7         # tank fraction
var blade_height_mm := 1.0  # set when the blade is changed; 0.8-1.2 shaves cleanly
var blade_level_mm := 0.0   # one end deeper than the other; within 0.1 is level
var blade_bolts_ok := true  # a loose blade chatters (washboard)
var choke_stuck := false    # "Unless it's the choke": stuck half closed, she won't fire
var flood_l := 0.0          # flood (ice-making) water in the tank, L
var wash_l := 0.0           # wash water, L
var flood_temp_c := FLOOD_TEMP_C  # the bay heater's setting
var cuts_driven := 0        # resurfaces the owner has driven (Gus rides the first)
## The Level-Sense machine (the top ice_level instrument): reads the lidar
## map and sets the blade and water cell by cell.
var auto_level := false
var model := "Zambelli Model 525 (1974)"


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
	if part("spark_plugs").failed() or choke_stuck:
		return "won't start"
	if fuel <= 0.0:
		return "out of gas"
	if part("hydraulic_hose").failed():
		return "hydraulic leak"
	return ""


## How well the blade cuts, 0..1: sharpness, height (1.0 mm target, 0.8 to
## 1.2 cuts cleanly) and level.
func cut_quality() -> float:
	var height_ok := clampf(1.0 - maxf(absf(blade_height_mm - 1.0) - 0.2, 0.0) * 1.6, 0.25, 1.0)
	var level_ok := clampf(1.0 - maxf(absf(blade_level_mm) - 0.1, 0.0) * 2.0, 0.4, 1.0)
	return (0.4 + 0.6 * part("blade").condition) * height_ok * level_ok


## Washboard from a blade set too deep, out of level or loose, 0..0.6.
func chatter() -> float:
	var c := maxf(blade_height_mm - 1.2, 0.0) * 0.8 + maxf(absf(blade_level_mm) - 0.1, 0.0) * 0.8
	if not blade_bolts_ok:
		c += 0.25
	return clampf(c, 0.0, 0.6)


func engine_factor() -> float:
	var starve := 1.0 - 0.2 * maxf(0.5 - carb, 0.0)
	return (0.7 + 0.3 * minf(part("spark_plugs").condition, 1.0 - 0.5 * (1.0 - part("air_filter").condition))) * starve


## Runs one resurface on `ice`. `skill` is the driver (the owner starts around
## 0.6); `pattern` is the coverage per grid cell (the standard pattern when
## empty). Returns the quality 0..1, or -1 if Doris won't go.
func resurface(ice: IceSlab, skill: float, pattern: PackedFloat64Array = PackedFloat64Array()) -> float:
	if fault() != "":
		return -1.0
	var hard := clampf((-ice.surface_temp - 3.0) / 4.0, 0.0, 1.5)
	var cut := cut_quality()
	var condition := part("towel").condition * 0.6 + part("squeegee").condition * 0.4
	var engine := engine_factor()
	var q := clampf((0.45 * cut + 0.35 * condition + 0.2 * engine) * (0.6 + 0.4 * skill), 0.0, 1.0)
	# a sharp blade at 1.0 mm takes about 0.4 mm and the flood lays back about 0.3:
	# a set too shallow (or a dull blade) lets the ice thicken, too deep thins it fast
	var shave := blade_height_mm * (0.15 + 0.25 * part("blade").condition) * engine
	ice.resurface(q, shave, FLOOD_LITRES * (0.7 + 0.3 * condition), pattern, chatter(), auto_level, flood_temp_c)
	_wear(hard)
	return q


## A dry cut: blade down, no water, to take the sheet down. Returns the mm
## taken off the centre, or -1 if Doris won't go.
func dry_cut(ice: IceSlab, skill: float) -> float:
	if fault() != "":
		return -1.0
	var shave := blade_height_mm * (0.4 + 0.6 * part("blade").condition) * engine_factor()
	ice.dry_cut(shave, cut_quality() * (0.6 + 0.4 * skill), chatter())
	_wear(clampf((-ice.surface_temp - 3.0) / 4.0, 0.0, 1.5))
	return shave


func _wear(hard: float) -> void:
	for id in parts:
		var stress := 1.0 + (hard * 0.8 if id == "blade" else 0.0)
		(parts[id] as SimPart).run(RESURFACE_HOURS, stress)
	engine_oil = maxf(engine_oil - RESURFACE_HOURS / 120.0, 0.0)
	carb = maxf(carb - RESURFACE_HOURS / CARB_LIFE_H, 0.0)
	fuel = maxf(fuel - 0.045, 0.0)


func to_dict() -> Dictionary:
	var ps := {}
	for id in parts:
		ps[id] = parts[id].to_dict()
	return {"parts": ps, "engine_oil": engine_oil, "carb": carb, "fuel": fuel, "blade_height_mm": blade_height_mm,
		"blade_level_mm": blade_level_mm, "blade_bolts_ok": blade_bolts_ok, "choke_stuck": choke_stuck,
		"flood_l": flood_l, "wash_l": wash_l, "flood_temp_c": flood_temp_c, "cuts_driven": cuts_driven,
		"auto_level": auto_level, "model": model}


func load_dict(d: Dictionary) -> void:
	var ps: Dictionary = d.get("parts", {})
	for id in ps:
		if parts.has(id):
			parts[id].load_dict(ps[id])
	engine_oil = float(d.get("engine_oil", engine_oil))
	carb = float(d.get("carb", carb))
	fuel = float(d.get("fuel", fuel))
	blade_height_mm = float(d.get("blade_height_mm", blade_height_mm))
	blade_level_mm = float(d.get("blade_level_mm", blade_level_mm))
	blade_bolts_ok = bool(d.get("blade_bolts_ok", blade_bolts_ok))
	choke_stuck = bool(d.get("choke_stuck", choke_stuck))
	flood_l = float(d.get("flood_l", flood_l))
	wash_l = float(d.get("wash_l", wash_l))
	flood_temp_c = float(d.get("flood_temp_c", flood_temp_c))
	cuts_driven = int(d.get("cuts_driven", cuts_driven))
	auto_level = bool(d.get("auto_level", auto_level))
	model = str(d.get("model", model))


## Gas to heat `litres` of flood water to `temp_c`, $.
static func heat_cost(litres: float, temp_c: float) -> float:
	return litres * IceSlab.C_WATER * maxf(temp_c - 10.0, 0.0) / 1000.0 * GAS_PER_MJ
