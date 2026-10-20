class_name RinkSchedule
extends RefCounted
## The rink's ice schedule as the owner works it (playtest #42): the
## contracts' weekly slots, plus the owner's changes. A slot can be sold
## one-off to a walk-in event, moved to another time, or cancelled. Every
## booking is checked against its event's criteria (EventCatalog), and there
## has to be room either side for a flood.
##
## The contracts stay the source of their recurring slots (RinkSim
## .contract_sessions); this keeps only the exceptions, so a renewed or lost
## contract shows up without rebuilding anything. RinkSim.sessions() reads
## `bookings()` when the sim has a schedule.
##
## Keys: a contract booking is "org@day@start" (start in hours), a sale "sale:<id>".
## The schedule holds no reference to the sim: every call takes it.

const FLOOD_GAP := 0.25    # hours of empty ice between bookings for the Zamboni
## Satisfaction a contract loses when its slot moves (same day, within an
## hour / anything bigger) or is cancelled.
const MOVE_SMALL := 2.0
const MOVE_BIG := 6.0
const CANCEL := 12.0

## One-off sales: [{"id", "kind", "day", "start", "hours", "rate", "per_head", "heads"}].
var sales: Array = []
## Contract bookings moved: key -> {"day", "start"}.
var moves := {}
## Contract bookings cancelled: key -> true.
var cancels := {}
var _next_id := 1


static func key_of(org: String, d: int, start: float) -> String:
	return "%s@%d@%s" % [org, d, str(snappedf(start, 0.01))]


## The bookings on day `d`, by start time: [{"org", "use", "start", "hours",
## "kind", "key", "sale"}] plus "rate"/"per_head"/"heads" on sales.
func bookings(sim: RinkSim, d: int) -> Array:
	var out: Array = []
	for s in sim.contract_sessions(d):
		var k := key_of(s.org, d, float(s.start))
		if cancels.has(k) or moves.has(k):
			continue
		s["key"] = k
		s["kind"] = EventCatalog.for_org(s.org)
		s["sale"] = false
		out.append(s)
	for k in moves:
		var m: Dictionary = moves[k]
		if int(m.day) != d:
			continue
		var parts := (k as String).split("@")
		var org := parts[0]
		var orig := _contract_slot(sim, org, int(parts[1]), float(parts[2]))
		if orig.is_empty():
			continue  # the contract ended
		var e := orig.duplicate()
		e.start = float(m.start)
		e["key"] = k
		e["kind"] = EventCatalog.for_org(org)
		e["sale"] = false
		e["moved_from"] = [int(parts[1]), float(parts[2])]
		out.append(e)
	for s in sales:
		if int(s.day) != d:
			continue
		var kd := EventCatalog.kind(s.kind)
		out.append({"org": "sale:%d" % int(s.id), "use": kd.use, "start": float(s.start), "hours": float(s.hours),
			"kind": s.kind, "key": "sale:%d" % int(s.id), "sale": true, "name": kd.name,
			"rate": float(s.rate), "per_head": float(s.get("per_head", 0.0)), "heads": float(s.get("heads", 0.0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.start) < float(b.start))
	return out


func _contract_slot(sim: RinkSim, org: String, d: int, start: float) -> Dictionary:
	for s in sim.contract_sessions(d):
		if s.org == org and is_equal_approx(float(s.start), start):
			return s
	return {}


func find(sim: RinkSim, key: String, d: int) -> Dictionary:
	for b in bookings(sim, d):
		if b.key == key:
			return b
	return {}


## Why `hours` of `kind_id` from `start` on day `d` can't go on the ice, or
## "" when it can. `ignore` is a booking key to leave out (the one being moved).
func problem(sim: RinkSim, kind_id: String, d: int, start: float, hours: float, ignore := "", contract_start := -1.0) -> String:
	if start < EventCatalog.OPEN_H or start + hours > EventCatalog.CLOSE_H:
		return "The building is closed then."
	var wd := sim.weekday_of(d)
	var why := EventCatalog.criteria_problem(kind_id, wd, start, hours, sim.ice_rep, sim.facility_score())
	# a contract keeps its own usual times even outside the kind's windows
	if why != "" and contract_start >= 0.0 and absf(start - contract_start) <= 2.0 \
			and EventCatalog.criteria_problem(kind_id, wd, start, hours, 100.0, 100.0).ends_with("time."):
		why = ""
	if why != "":
		return why
	if d < sim.day or (d == sim.day and start * 60.0 < sim.minute):
		return "That time has already gone."
	for b in bookings(sim, d):
		if b.key == ignore:
			continue
		var b0 := float(b.start) - FLOOD_GAP
		var b1 := float(b.start) + float(b.hours) + FLOOD_GAP
		if start < b1 and start + hours > b0:
			return "It clashes with %s at %s (and its flood)." % [_name(b), _hhmm(float(b.start))]
	return ""


## Sells a one-off event. Returns "" or why not.
func sell(sim: RinkSim, kind_id: String, d: int, start: float, hours := -1.0) -> String:
	var k := EventCatalog.kind(kind_id)
	if k.is_empty() or not bool(k.get("sell", false)):
		return "That isn't something you can sell on the spot."
	var h := float(k.hours) if hours <= 0.0 else hours
	var why := problem(sim, kind_id, d, start, h)
	if why != "":
		return why
	var wd := sim.weekday_of(d)
	sales.append({"id": _next_id, "kind": kind_id, "day": d, "start": start, "hours": h,
		"rate": EventCatalog.rate(kind_id, wd, start), "per_head": float(k.get("per_head", 0.0)),
		"heads": EventCatalog.expected_heads(kind_id, wd, start, posmod(sim.start_doy + d, 365))})
	_next_id += 1
	sim._note("Sold %s, %s %s." % [k.name, sim.date_text(d), _hhmm(start)], "schedule")
	return ""


## Moves a booking to day `d` at `start`. Returns "" or why not.
func move(sim: RinkSim, key: String, from_day: int, d: int, start: float) -> String:
	var b := find(sim, key, from_day)
	if b.is_empty():
		return "There's no booking there."
	var orig_start := float(b.start)
	if b.has("moved_from"):
		orig_start = float(b.moved_from[1])
	var why := problem(sim, b.kind, d, start, float(b.hours), key, -1.0 if b.sale else orig_start)
	if why != "":
		return why
	if b.sale:
		for s in sales:
			if "sale:%d" % int(s.id) == key:
				s.day = d
				s.start = start
		return ""
	var c: Dictionary = sim.contracts.get(b.org, {})
	var small := d == from_day and absf(start - float(b.start)) <= 1.0
	if not c.is_empty():
		c.satisfaction = maxf(float(c.satisfaction) - (MOVE_SMALL if small else MOVE_BIG), 0.0)
	moves[key] = {"day": d, "start": start}
	sim._note("Moved %s to %s %s." % [_name(b), sim.date_text(d), _hhmm(start)], "schedule")
	return ""


## Cancels a booking. Contracts take it badly; a sale is just refunded.
func cancel(sim: RinkSim, key: String, d: int) -> String:
	var b := find(sim, key, d)
	if b.is_empty():
		return "There's no booking there."
	if b.sale:
		for s in sales.duplicate():
			if "sale:%d" % int(s.id) == key:
				sales.erase(s)
		return ""
	moves.erase(key)
	cancels[key] = true
	var c: Dictionary = sim.contracts.get(b.org, {})
	if not c.is_empty():
		c.satisfaction = maxf(float(c.satisfaction) - CANCEL, 0.0)
	sim._note("Cancelled %s on %s." % [_name(b), sim.date_text(d)], "schedule")
	return ""


## The open stretches of ice on day `d`: [[from_h, to_h]] long enough for
## an hour of something, with the flood gaps taken out.
func open_ice(sim: RinkSim, d: int) -> Array:
	var out: Array = []
	var t := EventCatalog.OPEN_H
	for b in bookings(sim, d):
		var b0 := float(b.start) - FLOOD_GAP
		if b0 - t >= 1.0:
			out.append([t, b0])
		t = maxf(t, float(b.start) + float(b.hours) + FLOOD_GAP)
	if EventCatalog.CLOSE_H - t >= 1.0:
		out.append([t, EventCatalog.CLOSE_H])
	return out


## What the owner could sell into day `d`'s open ice: the event list, each
## with a start that meets its criteria. [{"kind", "name", "start", "hours",
## "revenue", "prime"}], best paying first.
func suggestions(sim: RinkSim, d: int) -> Array:
	var wd := sim.weekday_of(d)
	var doy: int = posmod(sim.start_doy + d, 365)
	var out: Array = []
	for window in open_ice(sim, d):
		for kind_id in EventCatalog.sellable():
			var k := EventCatalog.kind(kind_id)
			var h := float(k.hours)
			var s := float(window[0])
			while s + h <= float(window[1]) + 0.001:
				if problem(sim, kind_id, d, s, h) == "":
					var rev := EventCatalog.rate(kind_id, wd, s) * h + float(k.get("per_head", 0.0)) * EventCatalog.expected_heads(kind_id, wd, s, doy)
					out.append({"kind": kind_id, "name": k.name, "start": s, "hours": h, "revenue": rev, "prime": EventCatalog.is_prime(wd, s)})
					break
				s += 0.5
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.revenue) > float(b.revenue))
	return out


## Why a weekday's daytime ice sits empty, for the office.
static func gap_text() -> String:
	return "Weekdays 08:00 to 16:00 are non-prime ice: the hockey players are at work and the kids are in school, " \
		+ "so no league or club books it. Sell it one-off at %d%% of the rate: noon shinny, parent-and-tot, " % int(EventCatalog.NON_PRIME * 100.0) \
		+ "school skating trips and stick-and-puck. Pro teams practise in the mornings once the ice is good enough."


static func _hhmm(h: float) -> String:
	var m := int(round(h * 60.0))
	return "%02d:%02d" % [posmod(m / 60, 24), m % 60]


static func _name(b: Dictionary) -> String:
	if b.has("name"):
		return str(b.name)
	return str(RinkContracts.org(b.org).get("name", EventCatalog.kind(b.get("kind", "")).get("name", b.org)))


func to_dict() -> Dictionary:
	return {"sales": sales.duplicate(true), "moves": moves.duplicate(true), "cancels": cancels.duplicate(), "next_id": _next_id}


static func from_dict(d: Dictionary) -> RinkSchedule:
	var s := RinkSchedule.new()
	for e in d.get("sales", []):
		var x: Dictionary = e.duplicate()
		x.id = int(x.id)
		x.day = int(x.day)
		s.sales.append(x)
	for k in d.get("moves", {}):
		s.moves[k] = {"day": int(d.moves[k].day), "start": float(d.moves[k].start)}
	s.cancels = d.get("cancels", {}).duplicate()
	s._next_id = int(d.get("next_id", 1))
	return s
