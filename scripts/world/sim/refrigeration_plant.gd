class_name RefrigerationPlant
extends RefCounted
## The ice plant: two reciprocating compressors, an evaporative condenser on
## the roof, and the glycol loop (pump, header and floor pipes) that carries
## the cold to the slab. Numbers are a 1970s community rink: two compressors
## of about 175 kW of refrigeration each, glycol supplied at about -9 C.
##
## Everything here is the hidden truth; the player reads it through
## SimInstrument and fixes it through jobs on RinkSim.

const COMPRESSOR_KW := 175.0
const GLYCOL_TARGET := Vector2(30.0, 38.0)  # % by volume that runs well
const LOOP_LITRES := 9000.0

var compressors: Array = []  # [{"valves", "rings", "bearings", "seal": SimPart, "oil": float, "tripped": bool}]
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


static func create_old() -> RefrigerationPlant:
	var p := RefrigerationPlant.new()
	for i in 2:
		var worn := 0.55 if i == 0 else 0.7  # number 1 has always been the grumpy one
		p.compressors.append({
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
	if c.tripped:
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
		cap += COMPRESSOR_KW * compressor_health(i)
	var fan := 1.0 if not condenser_fan_belt.failed() else 0.45
	cap *= (1.0 - 0.3 * condenser_scale) * fan
	return cap * loop_factor()


## Runs the plant for `h` hours asking for `duty` (0..1) of its capacity.
## Returns the cooling delivered to the slab in kW.
func run(h: float, duty: float, rng: RandomNumberGenerator) -> float:
	duty = clampf(duty, 0.0, 1.0)
	var head := 1.0 + condenser_scale + (0.6 if condenser_fan_belt.failed() else 0.0)
	for i in compressors.size():
		var c: Dictionary = compressors[i]
		if c.tripped:
			continue
		var stress := duty * head * (1.0 + 2.0 * (1.0 - float(c.oil)))
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
	condenser_scale = minf(condenser_scale + h * duty / 9000.0, 1.0)
	condenser_fan_belt.run(h, duty)
	pump_bearing.run(h)
	pump_seal.run(h)
	header.run(h)
	# an old header weeps glycol; the pump seal drips when worn
	var leak := (1.0 - header.condition) * 0.6 + (0.4 if pump_seal.condition < 0.2 else 0.0)
	glycol_litres = maxf(glycol_litres - leak * h, 0.0)
	last_cooling_kw = capacity_kw() * duty
	var cop := 2.8 * (1.0 - 0.35 * condenser_scale) / head * 1.6
	last_power_kw = last_cooling_kw / maxf(cop, 0.8) + 11.0  # pumps and fans
	supply_temp = lerpf(-4.0, -10.0, clampf(capacity_kw() / (2.0 * COMPRESSOR_KW), 0.0, 1.0))
	return last_cooling_kw


## Adds `litres` of mixed fluid at `pct` glycol and returns the new mix.
func top_up(litres: float, pct: float) -> float:
	var g := glycol_litres * glycol_pct + litres * pct
	glycol_litres = minf(glycol_litres + litres, LOOP_LITRES)
	glycol_pct = g / maxf(glycol_litres, 1.0)
	return glycol_pct


func to_dict() -> Dictionary:
	var cs: Array = []
	for c in compressors:
		cs.append({"valves": c.valves.to_dict(), "rings": c.rings.to_dict(), "bearings": c.bearings.to_dict(),
			"seal": c.seal.to_dict(), "oil": c.oil, "tripped": c.tripped})
	return {"compressors": cs, "condenser_scale": condenser_scale, "fan_belt": condenser_fan_belt.to_dict(),
		"glycol_pct": glycol_pct, "glycol_litres": glycol_litres, "pump_bearing": pump_bearing.to_dict(),
		"pump_seal": pump_seal.to_dict(), "header": header.to_dict()}


func load_dict(d: Dictionary) -> void:
	var cs: Array = d.get("compressors", [])
	for i in mini(cs.size(), compressors.size()):
		var c: Dictionary = compressors[i]
		for k in ["valves", "rings", "bearings", "seal"]:
			(c[k] as SimPart).load_dict(cs[i].get(k, {}))
		c.oil = float(cs[i].get("oil", c.oil))
		c.tripped = bool(cs[i].get("tripped", false))
	condenser_scale = float(d.get("condenser_scale", condenser_scale))
	condenser_fan_belt.load_dict(d.get("fan_belt", {}))
	glycol_pct = float(d.get("glycol_pct", glycol_pct))
	glycol_litres = float(d.get("glycol_litres", glycol_litres))
	pump_bearing.load_dict(d.get("pump_bearing", {}))
	pump_seal.load_dict(d.get("pump_seal", {}))
	header.load_dict(d.get("header", {}))
