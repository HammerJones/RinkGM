class_name PlantCatalog
extends RefCounted
## What the owner can buy for the plant room: compressor packages and the
## refrigerants they run on. Every choice trades cost, safety and performance
## (Sean, 2026-10-17). A new compressor is a logistics job, not a click: a
## quote, a lead time, a crane, a licensed contractor, days with half a plant.
## See docs/world/RINK_SIM.md, "The compressor problem".

## cop: efficiency multiplier (higher is cheaper to run). price_kg: refill,
## climbing `price_rise` a year. toxic: a leak empties the building.
## inspection: yearly compliance cost. gwp_tax: $ per kg leaked from year 4.
const REFRIGERANTS := {
	"ammonia": {"name": "Ammonia (R-717)", "cop": 1.15, "charge_kg": 340.0, "price_kg": 4.0, "price_rise": 0.0,
		"toxic": true, "inspection": 1800.0, "gwp_tax": 0.0,
		"pitch": "The old workhorse. Cheapest to run and to refill, but a leak means evacuating the building and a call from the inspector."},
	"r22": {"name": "R-22 (Freon)", "cop": 1.0, "charge_kg": 900.0, "price_kg": 95.0, "price_rise": 0.6,
		"toxic": false, "inspection": 400.0, "gwp_tax": 0.0, "banned_from_year": 3,
		"pitch": "Nobody gets hurt when it leaks, but it's being phased out: every refill costs more than the last, and from Year 3 there's none to buy."},
	"r507": {"name": "R-507A (HFC)", "cop": 0.93, "charge_kg": 800.0, "price_kg": 38.0, "price_rise": 0.08,
		"toxic": false, "inspection": 400.0, "gwp_tax": 30.0,
		"pitch": "The safe, boring retrofit. Costs more power than ammonia, and the climate levy on leaks keeps growing."},
	"co2": {"name": "CO2 (R-744)", "cop": 1.08, "charge_kg": 450.0, "price_kg": 3.0, "price_rise": 0.0,
		"toxic": false, "inspection": 900.0, "gwp_tax": 0.0, "heat_recovery": true,
		"pitch": "The modern answer. Cheap gas, no levy, and the waste heat floods the ice and warms the lobby for free. Very high pressure and a very big cheque."},
}

## kw: refrigeration per compressor. eff: efficiency multiplier. part_load:
## how well it saves power at low duty (screws unload, recips cycle).
## lead_weeks: order to delivery. install_days: the compressor is out while
## the contractor sets, pipes, charges and tests it. contractor: their bill.
const COMPRESSORS := {
	"nordale_rc4": {"name": "Nordale RC-4 (1974, reciprocating)", "kw": 175.0, "eff": 0.85, "part_load": 0.8,
		"price": 0.0, "lead_weeks": 0, "install_days": 0, "contractor": 0.0, "refrigerants": ["ammonia", "r22"],
		"life": 1.0, "pitch": "Built like a tractor and running on its third set of valves."},
	"nordale_rc6": {"name": "Nordale RC-6 (new reciprocating)", "kw": 200.0, "eff": 1.0, "part_load": 0.85,
		"price": 38000.0, "lead_weeks": 6, "install_days": 4, "contractor": 9000.0, "refrigerants": ["ammonia", "r22", "r507"],
		"life": 1.6, "pitch": "The same idea, forty years better. Fits the old skid."},
	"frostline_fs90": {"name": "Frostline FS-90 (screw)", "kw": 260.0, "eff": 1.08, "part_load": 1.0,
		"price": 92000.0, "lead_weeks": 12, "install_days": 7, "contractor": 18000.0, "refrigerants": ["ammonia", "r507"],
		"life": 2.5, "pitch": "Quiet, smooth and efficient at part load. Needs a new oil separator and a bigger starter."},
	"kryomax_co2": {"name": "Kryomax CO2 rack (transcritical)", "kw": 300.0, "eff": 1.12, "part_load": 1.0,
		"price": 240000.0, "lead_weeks": 20, "install_days": 21, "contractor": 60000.0, "refrigerants": ["co2"],
		"life": 2.5, "pitch": "A whole new plant in a frame. The old compressors, chiller and receiver all go."},
}

## A portable chiller on a trailer keeps the ice in while a compressor is out.
const RENTAL_CHILLER_KW := 180.0
const RENTAL_CHILLER_DAY := 650.0
const RENTAL_CHILLER_DELIVERY := 1200.0


static func refrigerant(id: String) -> Dictionary:
	return REFRIGERANTS.get(id, REFRIGERANTS.ammonia)


static func compressor(id: String) -> Dictionary:
	return COMPRESSORS.get(id, COMPRESSORS.nordale_rc4)


## Refill price per kg in `year` (Year 1 is 1), or -1 if it can't be bought.
static func refill_price(id: String, year: int) -> float:
	var r := refrigerant(id)
	if year >= int(r.get("banned_from_year", 999)):
		return -1.0
	return float(r.price_kg) * pow(1.0 + float(r.price_rise), maxi(year - 1, 0))
