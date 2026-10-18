class_name OfficeData
extends RefCounted
## The rink office's view of a RinkSim: turns the sim's state into what the
## office screens draw (the ice grid, the log book, the week's P&L, the job
## queue, Gus's corkboard and the on-foot clock). Screens never reach into the
## sim directly, so when World adds a field the sim lacks today only this file
## changes. Where the sim has nothing yet, this keeps a stand-in on the sim's
## metadata (`log_book`, `job_queue`), which is not saved.
##
## Readings come through the player's instruments: until a better tool is
## bought they read as words ("amber, probably"), never as numbers.

## The four blocks of a day (RINK_SIM 1.1): [name, start hour, end hour].
const BLOCKS := [
	["Early morning", 5, 7],
	["Day", 7, 17],
	["Evening", 17, 25],
	["Night", 25, 29],
]
## The grid runs 05:00 to 01:00 in 15-minute cells (80 a day).
const GRID_START_H := 5
const GRID_CELLS := 80
const CELL_MIN := 15

## Last month's power bill, on the desk on day one (RINK_SIM 1.6).
const FIRST_POWER_BILL := 11240.0

## The week's goals on the corkboard (RINK_SIM 1.6).
const M1_GOALS := [
	{"id": "keep_bookings", "text": "Keep every booking."},
	{"id": "thin_ice", "text": "Get the ice under 40 mm. Earl likes it thick. Earl doesn't pay the bill."},
	{"id": "compressor_1", "text": "Decide what to do about number 1."},
	{"id": "minor_hockey", "text": "Win back one Minor Hockey slot."},
]

## Words for readings taken with the starting tool, for readings whose tool
## gives a number: [threshold, words], lowest first. Band tools (sight glass,
## ear, screwdriver) already give words in SimInstrument.
const WORDS := {
	"ice_thickness": [[-99.0, "paper thin"], [25.0, "thin"], [30.0, "about right"], [38.0, "thick"], [46.0, "way too thick"]],
	"glycol_pct": [[-99.0, "never tested"]],
	"brine_temp": [[-99.0, "very cold"], [-11.0, "cold"], [-7.5, "cool"], [-5.0, "warm"]],
}
const UNITS := {"ice_temp": "C", "ice_thickness": "mm", "glycol_pct": "%", "brine_temp": "C",
	"compressor_health": "", "oil_quality": ""}


# ------------------------------------------------------------------ clock

static func block_of(minute: int) -> int:
	var h := posmod(minute, 24 * 60) / 60.0
	if h < 5.0:
		h += 24.0
	for i in BLOCKS.size():
		if h >= BLOCKS[i][1] and h < BLOCKS[i][2]:
			return i
	return 3


## {"day_name", "time", "block", "block_index", "hours_left", "hours_max"}.
static func clock(sim: RinkSim) -> Dictionary:
	var b := block_of(sim.minute)
	return {"day_name": RinkSim.DAY_NAMES[sim.weekday()], "time": "%02d:%02d" % [sim.minute / 60, sim.minute % 60],
		"block": BLOCKS[b][0], "block_index": b, "hours_left": sim.hours_left, "hours_max": RinkSim.OWNER_HOURS,
		"week": week_number(sim), "money": sim.money}


## Weeks run Monday to Sunday; sim day 1 is the first Monday.
static func week_start(sim: RinkSim, day := -1) -> int:
	var d := sim.day if day < 0 else day
	return d - posmod(d - 1, 7)


static func week_number(sim: RinkSim) -> int:
	return 1 + maxi(week_start(sim) - 1, 0) / 7


# ------------------------------------------------------------------ ice grid

## Slot class of a cell (RINK_SIM 5.1): "prime", "shoulder" or "dead".
static func slot_class(weekday: int, hour: float) -> String:
	var weekend := weekday == 0 or weekday == 6
	if weekend:
		if hour >= 7.0 and hour < 21.0:
			return "prime"
		return "shoulder" if hour >= 21.0 and hour < 23.5 else "dead"
	if hour >= 16.0 and hour < 22.0:
		return "prime"
	if (hour >= 6.0 and hour < 8.0) or (hour >= 22.0 and hour < 23.5):
		return "shoulder"
	return "dead"


## Bookings on a weekday: [{"org", "name", "use", "start", "hours"}].
static func bookings(sim: RinkSim, weekday: int) -> Array:
	var out: Array = []
	for id in sim.contracts:
		var o := RinkContracts.org(id)
		for s in o.slots:
			if int(s[0]) == weekday:
				out.append({"org": id, "name": o.name, "use": o.use, "start": float(s[1]), "hours": float(s[2])})
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## Slots organisations would bid for on a weekday, where the ice is free:
## [{"org", "name", "use", "start", "hours"}].
static func offer_slots(sim: RinkSim, weekday: int) -> Array:
	var out: Array = []
	var taken := bookings(sim, weekday)
	for o in sim.offers():
		for s in o.slots:
			if int(s[0]) != weekday:
				continue
			var a := float(s[1])
			var clash := false
			for b in taken:
				if a < b.start + b.hours and b.start < a + float(s[2]):
					clash = true
			if not clash:
				out.append({"org": o.id, "name": o.name, "use": o.use, "start": a, "hours": float(s[2])})
	return out


## Who floods at this time. The sim has no staff yet, so the owner does every
## flood, except while they're playing their own Beer League game.
static func flood_crew(sim: RinkSim, weekday: int, hour: float) -> String:
	if sim.has_method("flood_crew"):
		return sim.call("flood_crew", weekday, hour)
	for b in bookings(sim, weekday):
		if b.org == "vbl_d" and hour > b.start and hour < b.start + b.hours:
			return ""
	return "you"


## One day of the grid: 80 cells, each {"kind": "free"|"session"|"flood",
## "class", ...}. Session cells carry the booking; floods carry "crew"
## ("" is unstaffed). `first` marks a block's first cell.
static func grid_day(sim: RinkSim, weekday: int) -> Array:
	var cells: Array = []
	for i in GRID_CELLS:
		var h := GRID_START_H + i * CELL_MIN / 60.0
		cells.append({"kind": "free", "class": slot_class(weekday, fmod(h, 24.0)), "hour": h})
	for b in bookings(sim, weekday):
		var c0 := _cell(b.start)
		var n := int(round(b.hours * 60.0 / CELL_MIN))
		for k in n:
			if c0 + k >= 0 and c0 + k < GRID_CELLS:
				cells[c0 + k].merge({"kind": "session", "booking": b, "first": k == 0}, true)
		# Doris goes out RESURFACE_LEAD_MIN before the booking (one cell).
		var f := c0 - RinkSim.RESURFACE_LEAD_MIN / CELL_MIN
		if f >= 0 and cells[f].kind == "free":
			cells[f].merge({"kind": "flood", "crew": flood_crew(sim, weekday, b.start - 0.5), "first": true}, true)
		# Two-game beer league ice gets a flood between games.
		if b.use == "hockey" and b.hours >= 2.0 and b.org.begins_with("vbl"):
			var mid := c0 + n / 2
			if mid < GRID_CELLS:
				cells[mid].merge({"kind": "flood", "crew": flood_crew(sim, weekday, b.start + b.hours / 2.0), "first": true}, true)
	return cells


static func _cell(hour: float) -> int:
	var h := hour if hour >= GRID_START_H else hour + 24.0
	return int(round((h - GRID_START_H) * 60.0 / CELL_MIN))


## The grid for the whole week, Monday first: [{"weekday", "name", "cells"}].
static func grid_week(sim: RinkSim) -> Array:
	var out: Array = []
	for i in 7:
		var wd := (i + 1) % 7
		out.append({"weekday": wd, "name": RinkSim.DAY_NAMES[wd], "cells": grid_day(sim, wd), "offers": offer_slots(sim, wd)})
	return out


## Booked hours by slot class this week, unstaffed floods, and rental income.
static func grid_summary(sim: RinkSim) -> Dictionary:
	var hours := {"prime": 0.0, "shoulder": 0.0, "dead": 0.0}
	var free := {"prime": 0.0, "shoulder": 0.0, "dead": 0.0}
	var floods := 0
	var unstaffed := 0
	for d in grid_week(sim):
		for c in d.cells:
			match c.kind:
				"session":
					hours[c["class"]] += CELL_MIN / 60.0
				"free":
					free[c["class"]] += CELL_MIN / 60.0
				"flood":
					floods += 1
					if c.crew == "":
						unstaffed += 1
	var income := 0.0
	for id in sim.contracts:
		income += RinkContracts.weekly_revenue(RinkContracts.org(id))
	return {"booked": hours, "free": free, "floods": floods, "unstaffed": unstaffed, "income": income}


# ------------------------------------------------------------------ readings

## A reading as the player sees it: {"text", "fuzzy", "instrument"}. With the
## starting tool the text is words; with a bought tool it's a number and its
## error ("-4.6 C +/-0.5").
static func reading_text(kind: String, r: Dictionary) -> Dictionary:
	var tier := _tier_of(kind, r)
	var text: String = r.text
	var fuzzy := tier == 0
	if fuzzy:
		if not text.is_valid_float():
			if not text.ends_with("probably"):
				text += ", probably"
		else:
			var words: Array = WORDS.get(kind, [])
			for w in words:
				if float(r.value) >= float(w[0]):
					text = w[1]
			if not words.is_empty() and kind != "glycol_pct":
				text += "?"
	else:
		var unit: String = UNITS.get(kind, "")
		text = "%.1f%s +/-%s" % [float(r.value), (" " + unit) if unit != "" else "", str(r.sigma)]
	return {"text": text, "fuzzy": fuzzy, "instrument": r.get("instrument", "")}


static func _tier_of(kind: String, r: Dictionary) -> int:
	var tiers := SimInstrument.tiers(kind)
	for i in tiers.size():
		if tiers[i].name == r.get("instrument", ""):
			return i
	return 0


## The kind of instrument a readings() key uses ("oil_1" -> "oil_quality").
static func reading_kind(key: String) -> String:
	if key.begins_with("oil_"):
		return "oil_quality"
	if key.begins_with("compressor_"):
		return "compressor_health"
	return key


## Takes a plant round and writes it in the log book. Returns the job result.
static func plant_round(sim: RinkSim) -> Dictionary:
	var r := sim.job("plant_round")
	if r.ok:
		var book := log_book(sim)
		book.append({"day": sim.day, "minute": sim.minute, "readings": r.readings})
		if not "log_book" in sim:
			sim.set_meta("log_book", book)
	return r


## Every plant round written down, oldest first: [{"day", "minute", "readings"}].
static func log_book(sim: RinkSim) -> Array:
	if "log_book" in sim:
		return sim.get("log_book")
	return sim.get_meta("log_book", [])


## Log book rows for a table: the readings in a fixed order with their text.
static func log_columns(sim: RinkSim) -> Array:
	var cols := ["ice_temp", "ice_thickness", "brine_temp", "glycol_pct"]
	for i in sim.plant.compressors.size():
		cols.append("oil_%d" % (i + 1))
		cols.append("compressor_%d" % (i + 1))
	return cols


static func column_title(key: String) -> String:
	match key:
		"ice_temp": return "Ice"
		"ice_thickness": return "Depth"
		"brine_temp": return "Brine"
		"glycol_pct": return "Glycol"
	if key.begins_with("oil_"):
		return "Oil " + key.trim_prefix("oil_")
	return "Comp " + key.trim_prefix("compressor_")


# ------------------------------------------------------------------ money

## The week so far, Monday first: line items summed over finished days plus
## today. {"revenue": [[category, $]], "costs": [[category, $]], "total_in",
## "total_out", "kwh", "days"}.
static func week_pl(sim: RinkSim) -> Dictionary:
	var start := week_start(sim)
	var sums := {}
	var kwh := 0.0
	var days := 0
	for b in sim.books:
		if int(b.day) >= start and int(b.day) < start + 7:
			days += 1
			kwh += float(b.kwh)
			for k in b.get("ledger", {}):
				sums[k] = float(sums.get(k, 0.0)) + float(b.ledger[k])
	for k in sim.ledger:
		sums[k] = float(sums.get(k, 0.0)) + float(sim.ledger[k])
	var rev: Array = []
	var cost: Array = []
	var tin := 0.0
	var tout := 0.0
	for k in sums:
		if sums[k] >= 0.0:
			rev.append([k, sums[k]])
			tin += sums[k]
		else:
			cost.append([k, -sums[k]])
			tout -= sums[k]
	rev.sort_custom(func(a, b): return a[1] > b[1])
	cost.sort_custom(func(a, b): return a[1] > b[1])
	return {"revenue": rev, "costs": cost, "total_in": tin, "total_out": tout, "kwh": kwh, "days": days}


## The power bill on the desk and the pace this week's metered kWh is on.
static func power_bill(sim: RinkSim) -> Dictionary:
	var last: float = sim.get("last_power_bill") if "last_power_bill" in sim else FIRST_POWER_BILL
	var pl := week_pl(sim)
	var pace := -1.0
	if pl.days > 0:
		pace = pl.kwh / pl.days * 30.0 * RinkSim.POWER_PRICE
	return {"last": last, "pace": pace, "kwh": pl.kwh, "price": RinkSim.POWER_PRICE}


# ------------------------------------------------------------------ jobs

## Jobs the player can do, with hours and cost: [{"id", "name", "hours", "cost"}].
static func job_menu() -> Array:
	var out: Array = []
	for id in RinkSim.JOBS:
		if id in ["install_compressor", "convert_refrigerant"]:
			continue  # these start from orders, not the list
		out.append({"id": id, "name": job_name(id), "hours": float(RinkSim.JOBS[id].hours), "cost": float(RinkSim.JOBS[id].cost)})
	return out


static func job_name(id: String) -> String:
	return id.replace("_", " ").capitalize()


## Jobs queued for later today: [{"id", "args"}].
static func job_queue(sim: RinkSim) -> Array:
	if "queue" in sim:
		return sim.get("queue")
	if not sim.has_meta("job_queue"):
		sim.set_meta("job_queue", [])
	return sim.get_meta("job_queue")


static func queue_hours(sim: RinkSim) -> float:
	var h := 0.0
	for j in job_queue(sim):
		h += float(RinkSim.JOBS[j.id].hours)
	return h


## Runs the first queued job. Returns the sim's result, or {} if none.
static func run_next(sim: RinkSim) -> Dictionary:
	var q := job_queue(sim)
	if q.is_empty():
		return {}
	var j: Dictionary = q.pop_front()
	if j.id == "plant_round":
		return plant_round(sim)
	return sim.job(j.id, j.get("args", {}))


## What the readings suggest doing, from the last log book entry.
static func suggestions(sim: RinkSim) -> Array:
	var book := log_book(sim)
	if book.is_empty():
		return [{"id": "plant_round", "why": "Nobody's written the log today."}]
	var out: Array = []
	var last: Dictionary = book[-1].readings
	for i in sim.plant.compressors.size():
		var oil: Dictionary = last.get("oil_%d" % (i + 1), {})
		if oil.get("text", "") in ["black", "dark"]:
			out.append({"id": "compressor_oil_change", "args": {"compressor": i},
				"why": "Number %d's sight glass reads %s." % [i + 1, oil.text]})
	var depth: Dictionary = last.get("ice_thickness", {})
	if float(depth.get("value", 0.0)) > 40.0:
		out.append({"id": "edge_ice", "why": "The ice reads %s" % reading_text("ice_thickness", depth).text})
	return out


# ------------------------------------------------------------------ goals

## Gus's sticky notes: [{"id", "text", "status", "done"}]. `status` is a short
## line in the player's own words of where it stands.
static func goals(sim: RinkSim) -> Array:
	if "goals" in sim:
		return sim.get("goals")
	var out: Array = []
	var start := week_start(sim)
	for g in M1_GOALS:
		var e := {"id": g.id, "text": g.text, "status": "", "done": false}
		match g.id:
			"keep_bookings":
				var lost := 0
				for ev in sim.events:
					if int(ev.day) >= start and (ev.text.begins_with("Cancelled") or ev.text.contains("took their ice elsewhere")):
						lost += 1
				e.status = "%d lost this week" % lost if lost > 0 else "none lost so far"
				e.done = lost == 0 and sim.day >= start + 6
				e.failed = lost > 0
			"thin_ice":
				var book := log_book(sim)
				var depth: Dictionary = {}
				for i in range(book.size() - 1, -1, -1):
					if book[i].readings.has("ice_thickness"):
						depth = book[i].readings.ice_thickness
						break
				e.status = "last check: %s" % reading_text("ice_thickness", depth).text if not depth.is_empty() else "not measured yet"
				e.done = sim.ice.thickness_mm < 40.0 and not depth.is_empty() and float(depth.value) < 40.0
			"compressor_1":
				var decided := not sim.orders.is_empty() or not sim.installs.is_empty() or not sim.delivered.is_empty()
				for ev in sim.events:
					if int(ev.day) >= start and ev.text in ["Fresh oil.", "New valve plates."]:
						decided = true
				e.status = "decided" if decided else "it sounds rough"
				e.done = decided
			"minor_hockey":
				e.done = sim.contracts.has("minor_hockey")
				e.status = "signed" if e.done else ("they'll take a bid" if RinkContracts.org("minor_hockey") in sim.offers() else "they want better ice")
		out.append(e)
	return out


# ------------------------------------------------------------------ demo

## A sim at the start of M1 (Monday 05:00, week 1) played forward to
## `weekday` and `minute`, with a plant round each morning and Doris
## flooding before every booking. For screens and screenshots.
static func demo_sim(weekday := 3, minute := 14 * 60, seed_ := 7) -> RinkSim:
	var sim := RinkSim.create(seed_)
	sim.auto_resurface = true
	sim.day = 1
	sim.minute = 5 * 60
	var target_day := 1 + posmod(weekday - 1, 7)
	while sim.day < target_day or (sim.day == target_day and sim.minute < minute):
		if sim.minute == 5 * 60 + 15:
			plant_round(sim)
		sim.advance(CELL_MIN)
	if sim.minute >= 5 * 60 + 15 and (log_book(sim).is_empty() or int(log_book(sim)[-1].day) != sim.day):
		plant_round(sim)
	return sim
