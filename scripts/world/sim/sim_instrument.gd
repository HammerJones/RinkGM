class_name SimInstrument
extends RefCounted
## How the player measures something. Every number the player sees passes
## through an instrument, which adds its error: the starting tools are crude
## (a screwdriver to the ice, the old dial gauge, "it sounds rough") and the
## upgrades narrow the error band. Sean: measurement gets more accurate as
## time goes on.

## Instrument tiers per reading, worst first. `sigma` is the 1-sigma error in
## the reading's unit; `bands` turns a crude reading into words instead.
const CATALOG := {
	"ice_temp": [
		{"id": "screwdriver", "name": "Screwdriver test", "sigma": 2.5, "price": 0,
			"bands": [[-99.0, "rock hard"], [-6.5, "hard"], [-4.5, "about right"], [-3.0, "soft"], [-1.5, "slush"]]},
		{"id": "ir_gun", "name": "Infrared thermometer", "sigma": 0.5, "price": 89},
		{"id": "slab_probe", "name": "Slab temperature probes", "sigma": 0.15, "price": 1400},
	],
	"ice_thickness": [
		{"id": "drill_ruler", "name": "Drill and ruler", "sigma": 5.0, "price": 0},
		{"id": "ice_gauge", "name": "Ice thickness gauge", "sigma": 1.5, "price": 220},
		{"id": "laser_level", "name": "Laser level survey", "sigma": 0.5, "price": 2600},
	],
	"glycol_pct": [
		{"id": "none", "name": "Nobody's checked", "sigma": 12.0, "price": 0},
		{"id": "hydrometer", "name": "Hydrometer", "sigma": 3.0, "price": 35},
		{"id": "refractometer", "name": "Refractometer", "sigma": 0.5, "price": 180},
	],
	"brine_temp": [
		{"id": "dial", "name": "Old dial thermometer", "sigma": 1.5, "price": 0},
		{"id": "digital", "name": "Digital controller", "sigma": 0.2, "price": 3800},
	],
	"compressor_health": [
		{"id": "ear", "name": "It sounds rough", "sigma": 0.2, "price": 0,
			"bands": [[-1.0, "knocking"], [0.3, "rough"], [0.6, "fine, probably"], [0.85, "sweet"]]},
		{"id": "vibration_pen", "name": "Vibration pen", "sigma": 0.08, "price": 450},
		{"id": "oil_analysis", "name": "Oil lab analysis", "sigma": 0.03, "price": 60},
	],
	"oil_quality": [
		{"id": "sight_glass", "name": "Sight glass", "sigma": 0.25, "price": 0,
			"bands": [[-1.0, "black"], [0.3, "dark"], [0.6, "amber"], [0.85, "clear"]]},
		{"id": "oil_analysis", "name": "Oil lab analysis", "sigma": 0.03, "price": 60},
	],
	"oil_level": [
		{"id": "sight_glass_level", "name": "Sight glass", "sigma": 0.06, "price": 0,
			"bands": [[-1.0, "empty"], [0.12, "low"], [0.35, "about half"], [0.65, "high"], [0.85, "full"]]},
	],
	"oil_psi": [
		{"id": "dial", "name": "Oil pressure dial", "sigma": 4.0, "price": 0},
		{"id": "test_gauge", "name": "Calibrated test gauge", "sigma": 1.0, "price": 140},
	],
	"suction_psig": [
		{"id": "dial", "name": "Suction dial gauge", "sigma": 5.0, "price": 0},
		{"id": "test_gauge", "name": "Calibrated test gauge", "sigma": 1.0, "price": 140},
	],
	"discharge_psig": [
		{"id": "dial", "name": "Discharge dial gauge", "sigma": 5.0, "price": 0},
		{"id": "test_gauge", "name": "Calibrated test gauge", "sigma": 1.0, "price": 140},
	],
	"glycol_level": [
		{"id": "tank_glass", "name": "Expansion tank sight glass", "sigma": 150.0, "price": 0,
			"bands": [[-99999.0, "low"], [8600.0, "about half"], [8950.0, "full"]]},
	],
	# the ice's level: where the laser hits the rod, mm (docs/world/ICE.md 3)
	"ice_level": [
		{"id": "survey_rod", "name": "Laser and survey rod", "sigma": 0.6, "price": 0},
		{"id": "lidar_scanner", "name": "Lidar scanner and tablet", "sigma": 0.25, "price": 3400},
		{"id": "level_sense", "name": "Level-Sense resurfacer", "sigma": 0.1, "price": 149000},
	],
	"smoothness": [
		{"id": "walk", "name": "Walk it and look", "sigma": 0.08, "price": 0,
			"bands": [[-1.0, "chewed up at the dots"], [0.55, "a bit rough"], [0.75, "smooth"], [0.9, "like glass"]]},
	],
}


## Finds the reading and tier an instrument id belongs to: {"reading", "tier"},
## or {} if no such instrument ("ir_gun", "refractometer").
static func find(id: String) -> Dictionary:
	for reading in CATALOG:
		var t: Array = CATALOG[reading]
		for i in t.size():
			if t[i].id == id:
				return {"reading": reading, "tier": i}
	return {}


## Reads `true_value` with the given tier of instrument for `reading`.
## Returns {"value": float, "text": String, "sigma": float}.
## `sigma_mult` widens the error (a tired owner misreads the gauge).
static func read(reading: String, tier: int, true_value: float, rng: RandomNumberGenerator, sigma_mult := 1.0) -> Dictionary:
	var tiers: Array = CATALOG[reading]
	var inst: Dictionary = tiers[clampi(tier, 0, tiers.size() - 1)]
	var sigma: float = float(inst.sigma) * sigma_mult
	var v := true_value + rng.randfn(0.0, sigma)
	var text := "%.1f" % v
	if inst.has("bands"):
		for b in inst.bands:
			if v >= float(b[0]):
				text = b[1]
	return {"value": v, "text": text, "sigma": sigma, "instrument": inst.name}


static func tiers(reading: String) -> Array:
	return CATALOG[reading]
