class_name RefrigerationPlant
extends RefCounted
## The ice plant: two reciprocating compressors, an evaporative condenser on
## the roof, and the glycol loop (pump, header and floor pipes) that carries
## the cold to the slab. Numbers are a 1970s community rink: two compressors
## of about 175 kW of refrigeration each, glycol supplied at about -9 C.
##
## Everything here is the hidden truth; the player reads it through
## SimInstrument and fixes it through jobs on RinkSim. What can replace the
## compressors and the refrigerant is in PlantCatalog.

const COMPRESSOR_KW := 175.0  # the original Nordale RC-4
const GLYCOL_TARGET := Vector2(30.0, 38.0)  # % by volume that runs well
const LOOP_LITRES := 9000.0

var compressors: Array = []  # [{"model", "valves", "rings", "bearings", "seal": SimPart, "oil", "tripped", "out"}]
var refrigerant := "ammonia"  # PlantCatalog.REFRIGERANTS
var charge := 0.93            # refrigerant charge, 1 full; seals and old joints leak it
var rental_kw := 0.0          # a rented portable chiller on the trailer outside
var condenser_scale := 0.15   # 0 clean, 1 choked with scale
var condenser_fan_belt: SimPart
var glycol_pct := 31.0
var glycol_litres := LOOP_LITRES
var pump_bearing: SimPart
var pump_seal: SimPart
var header: SimPart           # leaks glycol as it ages
var supply_temp := -9.0       # glycol leaving the chiller, C
var last_cooling_kw := 0.0
var last_power_kw := 0.0
var last_leak_kg := 0.0       # refrigerant lost in the last run()
var last_release := false     # a toxic release this run: the building empties
var last_recovered_kw := 0.0  # heat recovered for floods and the lobby (CO2)


static func create_old() -> RefrigerationPlant:
	var p := RefrigerationPlant.new()
	for i in 2:
		var worn := 0.55 if i == 0 else 0.7  # number 1 has always been the grumpy one
		p.compressors.append({
			"model": "nordale_rc4", "out": false,
			"valves": SimPart.make("valves", "Suction and discharge valve plates", 6000.0, 340.0, 0.08, worn),
			"rings": SimPart.make("rings", "Piston rings", 20000.0, 520.0, 0.05, worn + 0.15),
			"bearings": SimPart.make("bearings", "Main bearings", 30000.0, 880.0, 0.04, worn + 0.2),
			"seal": SimPart.make("seal", "Shaft seal", 9000.0, 260.0, 0.05, worn),
			"oil": 0.5, "tripped": false,
		})
	p.condenser_fan_belt = SimPart.make("fan_belt", "Condenser fan belt", 3000.0, 45.0, 0.05, 0.45)
	p.pump_bearing = SimPart.make("pump_bearing", "Glycol pump bearing", 15000.0, 190.0, 0.05, 0.6)
	p.pump_seal = SimPart.make("pump_seal", "Glycol pump mechanical seal", 12000.0, 150.0, 0.05, 0.55)
	p.header = SimPart.make("header", "Supply and return header", 200000.0, 18000.0, 0.02, 0.5)
	return p


## How much a compressor can move right now, 0..1 of nominal.
func compressor_health(i: int) -> float:
	var c: Dictionary = compressors[i]
	if c.tripped or c.get("out", false):
		return 0.0
	var valves: SimPart = c.valves
	var rings: SimPart = c.rings
	return (0.35 + 0.65 * valves.condition) * (0.6 + 0.4 * rings.condition)


## Flow through the floor: the pump and the mix. Too little glycol risks
## freezing in the chiller; too much is thick and moves heat badly.
func loop_factor() -> float:
	var f := 0.55 + 0.45 * pump_bearing.condition
	if glycol_pct < GLYCOL_TARGET.x:
		f *= clampf(1.0 - (GLYCOL_TARGET.x - glycol_pct) * 0.04, 0.3, 1.0)
	elif glycol_pct > GLYCOL_TARGET.y:
		f *= clampf(1.0 - (glycol_pct - GLYCOL_TARGET.y) * 0.02, 0.6, 1.0)
	f *= clampf(glycol_litres / LOOP_LITRES, 0.0, 1.0) * 1.0
	return f


func capacity_kw() -> float:
	var cap := 0.0
	for i in compressors.size():
		cap += float(PlantCatalog.compressor(compressors[i].model).kw) * compressor_health(i)
	var fan := 1.0 if not condenser_fan_belt.failed() else 0.45
	cap *= (1.0 - 0.3 * condenser_scale) * fan * charge_factor()
	return (cap + rental_kw) * loop_factor()


## A short charge starves the chiller: fine down to about 85%, then falls off.
func charge_factor() -> float:
	return clampf((charge - 0.55) / 0.3, 0.15, 1.0)


## Efficiency of the running machines on this refrigerant, capacity-weighted.
func efficiency() -> float:
	var t := 0.0
	var w := 0.0
	for c in compressors:
		var m := PlantCatalog.compressor(c.model)
		t += float(m.eff) * float(m.kw)
		w += float(m.kw)
	return t / maxf(w, 1.0) * float(PlantCatalog.refrigerant(refrigerant).cop)


## Runs the plant for `h` hours asking for `duty` (0..1) of its capacity.
## Returns the cooling delivered to the slab in kW.
func run(h: float, duty: float, rng: RandomNumberGenerator) -> float:
	duty = clampf(duty, 0.0, 1.0)
	var head := 1.0 + condenser_scale + (0.6 if condenser_fan_belt.failed() else 0.0)
	last_leak_kg = 0.0
	last_release = false
	var kg: float = PlantCatalog.refrigerant(refrigerant).charge_kg
	for i in compressors.size():
		var c: Dictionary = compressors[i]
		if c.tripped or c.get("out", false):
			continue
		var stress := duty * head * (1.0 + 2.0 * (1.0 - float(c.oil))) / float(PlantCatalog.compressor(c.model).life)
		for k in ["valves", "rings", "bearings", "seal"]:
			(c[k] as SimPart).run(h, stress)
		c.oil = maxf(float(c.oil) - h * duty / 1500.0, 0.0)
		var valves: SimPart = c.valves
		var bearings: SimPart = c.bearings
		var seal: SimPart = c.seal
		if valves.failed() or bearings.failed() or (float(c.oil) < 0.05 and rng.randf() < 0.05 * h):
			c.tripped = true
		if seal.condition < 0.25:
			c.oil = maxf(float(c.oil) - h * 0.002, 0.0)  # weeping seal loses oil
			last_leak_kg += h * (0.25 - seal.condition) * 0.4
			# a failed seal can let go all at once; with ammonia that empties the building
			if seal.failed() and rng.randf() < 0.01 * h:
				last_leak_kg += kg * 0.04
				last_release = PlantCatalog.refrigerant(refrigerant).toxic
	last_leak_kg += h * kg * 0.000002 * (1.0 - header.condition) * 10.0  # old joints and valve packings
	charge = maxf(charge - last_leak_kg / kg, 0.0)
	condenser_scale = minf(condenser_scale + h * duty / 9000.0, 1.0)
	condenser_fan_belt.run(h, duty)
	pump_bearing.run(h)
	pump_seal.run(h)
	header.run(h)
	# an old header weeps glycol; the pump seal drips when worn
	var leak := (1.0 - header.condition) * 0.6 + (0.4 if pump_seal.condition < 0.2 else 0.0)
	glycol_litres = maxf(glycol_litres - leak * h, 0.0)
	last_cooling_kw = capacity_kw() * duty
	var own_kw := maxf(last_cooling_kw - rental_kw * duty * loop_factor(), 0.0)
	var cop := 2.8 * (1.0 - 0.35 * condenser_scale) / head * 1.6 * efficiency() / 0.98
	var part_load := _part_load()
	cop *= lerpf(1.0, part_load, clampf(1.0 - duty, 0.0, 1.0))
	last_power_kw = own_kw / maxf(cop, 0.8) + 11.0 + rental_kw * duty * 0.4  # pumps, fans, the rental's own draw
	last_recovered_kw = (own_kw + last_power_kw) * 0.5 if PlantCatalog.refrigerant(refrigerant).has("heat_recovery") else 0.0
	supply_temp = lerpf(-4.0, -10.0, clampf(capacity_kw() / (2.0 * COMPRESSOR_KW), 0.0, 1.0))
	return last_cooling_kw


func _part_load() -> float:
	var t := 0.0
	for c in compressors:
		t += float(PlantCatalog.compressor(c.model).part_load)
	return t / maxf(compressors.size(), 1.0)


## Swaps compressor `i` for a new `model` package (`quality` from the
## commissioning). New parts last `life` times longer than the old Nordale's.
func install_compressor(i: int, model: String, quality := 1.0) -> void:
	var c: Dictionary = compressors[i]
	c.model = model
	for k in ["valves", "rings", "bearings", "seal"]:
		(c[k] as SimPart).replace(quality)
	c.oil = 1.0
	c.tripped = false
	c.out = false


## Can every compressor run on `id`?
func can_run(id: String) -> bool:
	for c in compressors:
		if not id in PlantCatalog.compressor(c.model).refrigerants:
			return false
	return true


## Adds `litres` of mixed fluid at `pct` glycol and returns the new mix.
func top_up(litres: float, pct: float) -> float:
	var g := glycol_litres * glycol_pct + litres * pct
	glycol_litres = minf(glycol_litres + litres, LOOP_LITRES)
	glycol_pct = g / maxf(glycol_litres, 1.0)
	return glycol_pct


func to_dict() -> Dictionary:
	var cs: Array = []
	for c in compressors:
		cs.append({"model": c.model, "out": c.get("out", false), "valves": c.valves.to_dict(), "rings": c.rings.to_dict(), "bearings": c.bearings.to_dict(),
			"seal": c.seal.to_dict(), "oil": c.oil, "tripped": c.tripped})
	return {"compressors": cs, "condenser_scale": condenser_scale, "fan_belt": condenser_fan_belt.to_dict(),
		"glycol_pct": glycol_pct, "glycol_litres": glycol_litres, "pump_bearing": pump_bearing.to_dict(),
		"pump_seal": pump_seal.to_dict(), "header": header.to_dict(), "refrigerant": refrigerant, "charge": charge,
		"rental_kw": rental_kw}


func load_dict(d: Dictionary) -> void:
	var cs: Array = d.get("compressors", [])
	for i in mini(cs.size(), compressors.size()):
		var c: Dictionary = compressors[i]
		for k in ["valves", "rings", "bearings", "seal"]:
			(c[k] as SimPart).load_dict(cs[i].get(k, {}))
		c.oil = float(cs[i].get("oil", c.oil))
		c.tripped = bool(cs[i].get("tripped", false))
		c.model = str(cs[i].get("model", c.model))
		c.out = bool(cs[i].get("out", false))
	condenser_scale = float(d.get("condenser_scale", condenser_scale))
	condenser_fan_belt.load_dict(d.get("fan_belt", {}))
	glycol_pct = float(d.get("glycol_pct", glycol_pct))
	glycol_litres = float(d.get("glycol_litres", glycol_litres))
	pump_bearing.load_dict(d.get("pump_bearing", {}))
	pump_seal.load_dict(d.get("pump_seal", {}))
	header.load_dict(d.get("header", {}))
	refrigerant = str(d.get("refrigerant", refrigerant))
	charge = float(d.get("charge", charge))
	rental_kw = float(d.get("rental_kw", rental_kw))
