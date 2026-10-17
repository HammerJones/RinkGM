class_name RinkSim
extends RefCounted
## The owner-operator rink: one building, its ice plant, its ice, Doris the
## resurfacer, the contracts that rent the ice and the books. Pure logic (no
## nodes), saved with to_dict()/from_dict(), advanced in in-game minutes.
##
## The player is the whole staff at first: every job costs hours from the
## owner's day (`hours_left`) and the mini games feed a `quality` into the job.
## What the player sees of the machines comes through SimInstrument, so better
## tools mean truer numbers. See docs/world/RINK_SIM.md.

const STEP_MIN := 15
const OWNER_HOURS := 16.0
const POWER_PRICE := 0.14       # $ per kWh
const DAILY_FIXED := 95.0       # insurance, property tax, water, phone
const GLYCOL_PRICE := 4.0       # $ per litre of concentrate
const ROOMS := ["lobby", "home_dressing", "visitor_dressing", "washrooms", "stands", "pro_shop"]
const DAY_NAMES := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var rng := RandomNumberGenerator.new()
var day := 0          # day 0 is a Sunday in October
var minute := 6 * 60  # minutes since midnight
var money := 2500.0
var hours_left := OWNER_HOURS
var skill := {"driving": 0.55, "mechanic": 0.4}
var tools := {}       # reading -> instrument tier (SimInstrument.CATALOG)
var rooms := {}       # room id -> Wear age, 0..2
var cleanliness := 0.55
var ice_rep := 40.0   # what customers think of the ice, 0..100
var contracts := {}   # org id -> {"weeks_left", "satisfaction"}
var events: Array = []  # [{"day", "minute", "text"}]
var ledger := {}      # category -> dollars this day (negative is spending)
var books: Array = [] # one entry per finished day: {"day", "revenue", "costs", "kwh", "ice"}
var auto_resurface := false  # tests and fast-forward: Doris goes out before every session

var plant: RefrigerationPlant
var ice: IceSlab
var doris: ResurfacerSim
var _kwh_today := 0.0
var _session_key := ""
var _ratings_today: Array = []  # ice rating at the start of each session


static func create(seed_ := 1) -> RinkSim:
	var s := RinkSim.new()
	s.rng.seed = seed_
	s.plant = RefrigerationPlant.create_old()
	s.ice = IceSlab.new()
	s.doris = ResurfacerSim.create_doris()
	for k in SimInstrument.CATALOG:
		s.tools[k] = 0
	for r in ROOMS:
		s.rooms[r] = Wear.WORN
	s.contracts = {"vbl_d": {"weeks_left": 16, "satisfaction": 55.0},
		"public_skate": {"weeks_left": 52, "satisfaction": 55.0}}
	return s


func weekday() -> int:
	return posmod(day, 7)


func clock_text() -> String:
	return "%s day %d %02d:%02d" % [DAY_NAMES[weekday()], day, minute / 60, minute % 60]


## The session on the ice at this minute, or {} if the ice is free.
func session_now() -> Dictionary:
	var h := minute / 60.0
	for id in contracts:
		var o := RinkContracts.org(id)
		for s in o.slots:
			if int(s[0]) == weekday() and h >= float(s[1]) and h < float(s[1]) + float(s[2]):
				return {"org": id, "use": o.use, "start": float(s[1]), "hours": float(s[2])}
	return {}


## 0..100 from the rooms' renovation ages and how clean they are.
func facility_score() -> float:
	var t := 0.0
	for r in ROOMS:
		t += float(rooms.get(r, 0)) * 50.0
	return t / ROOMS.size() * (0.55 + 0.45 * cleanliness) + 12.0 * cleanliness


func offers() -> Array:
	return RinkContracts.offers(ice_rep, facility_score(), contracts.keys())


func sign(org_id: String) -> bool:
	for o in offers():
		if o.id == org_id:
			contracts[org_id] = {"weeks_left": int(o.weeks), "satisfaction": 60.0}
			_note("Signed %s." % o.name)
			return true
	return false


# ------------------------------------------------------------------ time

## Advances the sim by `minutes`, in 15-minute steps.
func advance(minutes: int) -> void:
	var steps := maxi(1, minutes / STEP_MIN)
	for i in steps:
		_step()


func advance_days(n: int) -> void:
	advance(n * 24 * 60)


func _step() -> void:
	var h := STEP_MIN / 60.0
	var s := session_now()
	var key := "%d/%s/%s" % [day, s.get("org", ""), s.get("start", "")]
	if not s.is_empty() and key != _session_key:
		_session_key = key
		_start_session(s)
	var use: String = s.get("use", "hockey")
	var skaters := 0.0
	if not s.is_empty():
		skaters = 20.0 if use == "hockey" else 30.0
	# the controller chases the target for whatever skates next, or idles warmer overnight
	var target: float = IceSlab.TARGET_TEMP.get(use, -5.0)
	if s.is_empty() and (minute < 5 * 60 or minute >= 23 * 60 + 30):
		target += 1.0
	var duty := clampf(0.5 + (ice.surface_temp - target) * 0.8, 0.0, 1.0)
	var cooling := plant.run(h, duty, rng)
	var air := _air_temp()
	var lights := 38.0 if minute >= 6 * 60 and minute < 24 * 60 else 6.0  # old metal halides
	var load := 4.2 * (air - ice.surface_temp) + lights + skaters * 0.35 + 40.0
	ice.run(h, load, cooling, skaters * h)
	_kwh_today += (plant.last_power_kw + lights + 25.0) * h
	cleanliness = clampf(cleanliness - skaters * h * 0.0008, 0.0, 1.0)
	minute += STEP_MIN
	if minute >= 24 * 60:
		_end_day()


func _start_session(s: Dictionary) -> void:
	if auto_resurface and hours_left >= ResurfacerSim.RESURFACE_HOURS:
		job("resurface")
	var rating := ice.rating(s.use)
	_ratings_today.append(rating)
	var o := RinkContracts.org(s.org)
	var c: Dictionary = contracts[s.org]
	if rating < 25.0:
		c.satisfaction = maxf(float(c.satisfaction) - 15.0, 0.0)
		ice_rep = maxf(ice_rep - 4.0, 0.0)
		_book("refunds", -50.0)
		_note("Cancelled %s: the ice is unplayable (%.0f)." % [o.name, rating])
		return
	c.satisfaction = lerpf(float(c.satisfaction), rating, 0.2)
	ice_rep = lerpf(ice_rep, rating, 0.04)
	var pay := float(o.get("rate", 0.0)) * float(s.hours)
	if o.has("per_head"):
		pay += float(o.per_head) * float(o.heads) * clampf(rating / 70.0, 0.3, 1.3)
	_book("ice rental", pay)


func _end_day() -> void:
	_book("electricity", -_kwh_today * POWER_PRICE)
	_book("fixed costs", -DAILY_FIXED)
	var rev := 0.0
	var cost := 0.0
	for k in ledger:
		if ledger[k] > 0:
			rev += ledger[k]
		else:
			cost -= ledger[k]
	var avg := -1.0
	if not _ratings_today.is_empty():
		avg = 0.0
		for r in _ratings_today:
			avg += r
		avg /= _ratings_today.size()
	books.append({"day": day, "revenue": rev, "costs": cost, "kwh": _kwh_today, "ice": avg,
		"ledger": ledger.duplicate()})
	ledger = {}
	_ratings_today = []
	_kwh_today = 0.0
	minute = 0
	day += 1
	hours_left = OWNER_HOURS
	if weekday() == 0:
		_end_week()


func _end_week() -> void:
	for id in contracts.keys():
		var c: Dictionary = contracts[id]
		c.weeks_left = int(c.weeks_left) - 1
		var o := RinkContracts.org(id)
		if float(c.satisfaction) < 35.0:
			contracts.erase(id)
			_note("%s took their ice elsewhere." % o.name)
		elif int(c.weeks_left) <= 0:
			if ice_rep >= float(o.min_ice) and float(c.satisfaction) >= 50.0:
				c.weeks_left = int(o.weeks)
				_note("%s renewed." % o.name)
			else:
				contracts.erase(id)
				_note("%s didn't renew." % o.name)


## Air temperature in the bowl: an old building with no dehumidifier.
func _air_temp() -> float:
	var season := cos(TAU * (posmod(day + 280, 365)) / 365.0)  # day 0 is mid October
	return 9.0 - 4.0 * season


# ------------------------------------------------------------------ jobs

const JOBS := {
	"resurface": {"hours": 0.25, "cost": 0.0},
	"plant_round": {"hours": 0.5, "cost": 0.0},
	"reset_compressor": {"hours": 0.25, "cost": 0.0},
	"compressor_oil_change": {"hours": 2.0, "cost": 90.0},
	"compressor_valve_job": {"hours": 6.0, "cost": 340.0},
	"descale_condenser": {"hours": 4.0, "cost": 120.0},
	"replace_fan_belt": {"hours": 0.75, "cost": 45.0},
	"glycol_top_up": {"hours": 1.0, "cost": 0.0},
	"pump_bearing": {"hours": 4.0, "cost": 190.0},
	"blade_change": {"hours": 1.0, "cost": 160.0},
	"engine_tune": {"hours": 1.5, "cost": 70.0},
	"towel_change": {"hours": 0.5, "cost": 85.0},
	"edge_ice": {"hours": 1.5, "cost": 0.0},
	"clean_building": {"hours": 2.0, "cost": 15.0},
	"refuel_doris": {"hours": 0.25, "cost": 45.0},
}


## Does a job. `args`: "quality" 0..1 from the mini game (default from the
## owner's skill), "compressor" index, "litres" and "pct" for glycol,
## "height_mm" for a blade change. Returns {"ok": bool, "text": String}.
func job(id: String, args := {}) -> Dictionary:
	var spec: Dictionary = JOBS.get(id, {})
	if spec.is_empty():
		return {"ok": false, "text": "No such job."}
	var hours: float = spec.hours
	if hours > hours_left + 0.001:
		return {"ok": false, "text": "Not enough hours left today."}
	var q: float = args.get("quality", clampf(skill.mechanic + 0.3, 0.0, 1.0))
	var cost: float = spec.cost
	var text := ""
	match id:
		"resurface":
			var r := doris.resurface(ice, skill.driving)
			if r < 0.0:
				return {"ok": false, "text": "Doris %s." % doris.fault()}
			skill.driving = minf(skill.driving + 0.002, 1.0)
			text = "Resurfaced (%.0f%%)." % (r * 100.0)
		"plant_round":
			return {"ok": true, "text": "Plant round.", "readings": readings()}
		"reset_compressor":
			var i: int = args.get("compressor", 0)
			plant.compressors[i].tripped = false
			plant.run(0.0, 0.0, rng)
			text = "Compressor %d %s." % [i + 1, "back on" if not plant.compressors[i].tripped else "trips again"]
		"compressor_oil_change":
			plant.compressors[args.get("compressor", 0)].oil = 0.75 + 0.25 * q
			text = "Fresh oil."
		"compressor_valve_job":
			var c: Dictionary = plant.compressors[args.get("compressor", 0)]
			c.valves.replace(0.7 + 0.3 * q)
			c.tripped = false
			text = "New valve plates."
		"descale_condenser":
			plant.condenser_scale *= 0.4 - 0.3 * q
			text = "Condenser descaled."
		"replace_fan_belt":
			plant.condenser_fan_belt.replace(0.8 + 0.2 * q)
			text = "New fan belt."
		"glycol_top_up":
			var litres: float = args.get("litres", 200.0)
			var pct: float = args.get("pct", 50.0)
			cost = litres * pct / 100.0 * GLYCOL_PRICE
			text = "Glycol now %.0f%%." % plant.top_up(litres, pct)
		"pump_bearing":
			plant.pump_bearing.replace(0.75 + 0.25 * q)
			text = "New pump bearing."
		"blade_change":
			doris.part("blade").replace(0.85 + 0.15 * q)
			doris.blade_height_mm = args.get("height_mm", 1.0 + rng.randfn(0.0, 0.3 * (1.0 - q)))
			text = "New blade, set at %.1f mm." % doris.blade_height_mm
		"engine_tune":
			doris.part("spark_plugs").replace()
			doris.part("air_filter").replace()
			doris.engine_oil = 1.0
			text = "Doris tuned up."
		"towel_change":
			doris.part("towel").replace()
			text = "New towel."
		"edge_ice":
			ice.smoothness = minf(ice.smoothness + 0.06 * q, 1.0)
			text = "Edged the boards."
		"clean_building":
			cleanliness = minf(cleanliness + 0.35 * q, 1.0)
			text = "Building cleaned."
		"refuel_doris":
			doris.fuel = 1.0
			text = "Doris refuelled."
	hours_left -= hours
	if cost > 0.0:
		_book("parts and supplies", -cost)
	if id != "resurface":
		skill.mechanic = minf(skill.mechanic + 0.004, 1.0)
	_note(text)
	return {"ok": true, "text": text}


## What the owner can see on a plant round, through the current tools.
func readings() -> Dictionary:
	var out := {}
	out["ice_temp"] = SimInstrument.read("ice_temp", tools.ice_temp, ice.surface_temp, rng)
	out["ice_thickness"] = SimInstrument.read("ice_thickness", tools.ice_thickness, ice.thickness_mm, rng)
	out["glycol_pct"] = SimInstrument.read("glycol_pct", tools.glycol_pct, plant.glycol_pct, rng)
	out["brine_temp"] = SimInstrument.read("brine_temp", tools.brine_temp, plant.supply_temp, rng)
	for i in plant.compressors.size():
		out["compressor_%d" % (i + 1)] = SimInstrument.read("compressor_health", tools.compressor_health, plant.compressor_health(i), rng)
		out["oil_%d" % (i + 1)] = SimInstrument.read("oil_quality", tools.oil_quality, float(plant.compressors[i].oil), rng)
	return out


func buy_tool(reading: String, tier: int) -> bool:
	var t: Array = SimInstrument.tiers(reading)
	if tier <= int(tools.get(reading, 0)) or tier >= t.size() or money < float(t[tier].price):
		return false
	_book("tools", -float(t[tier].price))
	tools[reading] = tier
	_note("Bought a %s." % t[tier].name)
	return true


func _book(category: String, dollars: float) -> void:
	ledger[category] = float(ledger.get(category, 0.0)) + dollars
	money += dollars


func _note(text: String) -> void:
	events.append({"day": day, "minute": minute, "text": text})
	if events.size() > 400:
		events = events.slice(events.size() - 400)


# ------------------------------------------------------------------ save

func to_dict() -> Dictionary:
	return {"day": day, "minute": minute, "money": money, "hours_left": hours_left, "skill": skill.duplicate(),
		"tools": tools.duplicate(), "rooms": rooms.duplicate(), "cleanliness": cleanliness, "ice_rep": ice_rep,
		"contracts": contracts.duplicate(true), "ledger": ledger.duplicate(), "kwh_today": _kwh_today,
		"session_key": _session_key, "ratings_today": _ratings_today.duplicate(),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"plant": plant.to_dict(), "ice": ice.to_dict(), "doris": doris.to_dict()}


static func from_dict(d: Dictionary) -> RinkSim:
	var s := RinkSim.create()
	s.day = int(d.get("day", 0))
	s.minute = int(d.get("minute", 360))
	s.money = float(d.get("money", s.money))
	s.hours_left = float(d.get("hours_left", OWNER_HOURS))
	for k in ["skill", "tools", "rooms"]:
		var v: Dictionary = d.get(k, {})
		for kk in v:
			s.get(k)[kk] = v[kk]
	s.cleanliness = float(d.get("cleanliness", s.cleanliness))
	s.ice_rep = float(d.get("ice_rep", s.ice_rep))
	s.contracts = d.get("contracts", s.contracts).duplicate(true)
	s.ledger = d.get("ledger", {}).duplicate()
	s._kwh_today = float(d.get("kwh_today", 0.0))
	s._session_key = str(d.get("session_key", ""))
	s._ratings_today = d.get("ratings_today", []).duplicate()
	s.rng.seed = int(d.get("rng_seed", "1"))
	s.rng.state = int(d.get("rng_state", "0"))
	s.plant.load_dict(d.get("plant", {}))
	s.ice.load_dict(d.get("ice", {}))
	s.doris.load_dict(d.get("doris", {}))
	return s
