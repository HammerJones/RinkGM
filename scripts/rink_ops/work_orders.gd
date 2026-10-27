class_name WorkOrders
extends RefCounted
## Jobs handed to staff on the RINK-OS calendar. The owner can do any job on
## their own hours; a staff member does the jobs of their trade, inside their
## shift and off their break, and RinkSim runs the order when its time comes
## (RinkSim.work_orders, `_run_work_orders`) without touching the owner's day.

## Each job's trade: who on staff can be handed it.
const TRADE := {
	"resurface": "ice", "ice_check": "ice", "shave_ice": "ice", "edge_ice": "ice", "dump_snow": "ice",
	"refuel_doris": "ice", "ice_depth": "ice", "ice_survey": "ice", "hose_flood": "ice", "chip_ice": "ice",
	"plant_round": "plant", "reset_compressor": "plant", "compressor_oil_change": "plant",
	"compressor_oil_top_up": "plant", "compressor_valve_job": "plant", "descale_condenser": "plant",
	"replace_fan_belt": "plant", "glycol_top_up": "plant", "pump_bearing": "plant",
	"recharge_refrigerant": "plant", "install_plate": "plant",
	"blade_change": "doris", "doris_plugs": "doris", "doris_carb": "doris", "doris_oil_change": "doris",
	"engine_tune": "doris", "towel_change": "doris",
	"clean_building": "clean",
}

## The trades each staff position works in (StaffRoster.POSITIONS).
const POSITION_TRADES := {
	"ice_crew": ["ice", "clean"], "night_crew": ["ice", "clean"],
	"maintenance": ["plant", "doris"], "custodian": ["clean"],
}

## The named cast have no position: their trades come from their job, by word.
const JOB_WORDS := {
	"icemaker": ["ice", "doris"], "driver": ["ice", "doris"], "plant operator": ["plant"],
	"maintenance": ["plant", "doris"], "custodian": ["clean"], "janitor": ["clean"],
}


## The trades `p` works in; empty for staff with no hands-on job (the desk,
## the snack bar).
static func trades_of(p: Person) -> Array:
	var pos := str(p.habits.get("position", ""))
	if POSITION_TRADES.has(pos):
		return POSITION_TRADES[pos]
	var out: Array = []
	var job := p.job.to_lower()
	for w: String in JOB_WORDS:
		if job.contains(w):
			for t: String in JOB_WORDS[w]:
				if not t in out:
					out.append(t)
	return out


static func can_do(p: Person, id: String) -> bool:
	return TRADE.get(id, "") in trades_of(p)


static func first(p: Person) -> String:
	return p.name.get_slice(" ", 0)


static func hours_of(id: String) -> float:
	return float(RinkSim.JOBS.get(id, {}).get("hours", 0.0))


## The orders on day `d`, earliest first.
static func on_day(sim: RinkSim, d: int) -> Array:
	var out: Array = sim.work_orders.filter(func(o: Dictionary) -> bool: return int(o.day) == d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.minute) < int(b.minute))
	return out


## Why `p` can't take job `id` at `minute` of day `d`, or "" if they can:
## their trade, their shift (the whole job inside it, off their break), the
## clock (not in the past) and their other orders.
static func why_not(sim: RinkSim, p: Person, id: String, d: int, minute: int) -> String:
	if not RinkSim.JOBS.has(id):
		return "No such job."
	if not can_do(p, id):
		return "%s doesn't do that job." % first(p)
	if d < sim.day or (d == sim.day and minute < sim.minute):
		return "That's already gone by."
	var wd := sim.weekday_of(d)
	var from := minute / 60.0
	var to := from + maxf(hours_of(id), 0.25)
	var h := from
	while h < to - 0.001:
		var e := p.entry_at(wd, h)
		if not p.on_shift(wd, h):
			return "%s isn't on shift then." % first(p)
		if e.get("break", false):
			return "That's %s's break." % first(p)
		h += 0.25
	for o: Dictionary in on_day(sim, d):
		if str(o.who) != p.id:
			continue
		var of := int(o.minute) / 60.0
		if from < of + maxf(float(o.hours), 0.25) - 0.001 and of < to - 0.001:
			return "%s is on another job then." % first(p)
	return ""


## Hands job `id` to `p` at `minute` of day `d`. Returns {"ok", "text"}.
static func assign(sim: RinkSim, p: Person, id: String, d: int, minute: int, args := {}) -> Dictionary:
	var why := why_not(sim, p, id, d, minute)
	if why != "":
		return {"ok": false, "text": why}
	sim.work_orders.append({"id": id, "args": args.duplicate(), "day": d, "minute": minute,
		"by": first(p), "who": p.id, "hours": hours_of(id)})
	return {"ok": true, "text": "Handed to %s: %s at %02d:%02d." % [first(p), OfficeData.job_name(id).to_lower(), minute / 60, minute % 60]}


## Takes back an order that hasn't run yet.
static func cancel(sim: RinkSim, order: Dictionary) -> bool:
	if order.has("ok"):
		return false
	var n := sim.work_orders.size()
	sim.work_orders.erase(order)
	return sim.work_orders.size() < n
