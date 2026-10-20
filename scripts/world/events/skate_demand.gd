class_name SkateDemand
extends RefCounted
## How many people come to a public skate (docs/world/ON_ICE.md 2). Pure
## logic, numbers in data/world/on_ice.json "public_skate.demand":
##
##   expected = base(day type, hour)        a weekday 06:00 is a handful, Saturday 15:00 a crowd
##            x season(month)               winter high, summer low
##            x holiday                     Christmas break, March break, long weekends
##            x weather                     rain and cold snaps drive people indoors; blizzards and warm days don't
##            x price                       (price / 4.00) ^ -elasticity
##            x reputation                  0.6 + 0.8 * ice_rep / 100
##            x line                        a long rental line puts walk-ups off
##   capped at the rink's capacity; Christmas (23-27 Dec, New Year) fills it.
##
##   var d := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 10, "dom": 17})
##   d.expected  # skaters; d.factors has every multiplier, d.at_capacity
##
## ctx keys (all optional): weekday (0 = Sunday), hour, month (1..12), dom
## (1..31), temp_c (outside), weather ("clear", "rain", "snow", "blizzard"),
## price, ice_rep (0..100), line_minutes, capacity. `from_sim()` fills them
## from a RinkSim.


static func expected(ctx: Dictionary) -> Dictionary:
	var ps: Dictionary = OnIceData.section("public_skate")
	var dem: Dictionary = ps.get("demand", {})
	var cap := int(ctx.get("capacity", ps.get("capacity", 260)))
	var wd := int(ctx.get("weekday", 6))
	var hour := float(ctx.get("hour", 14.0))
	var month := clampi(int(ctx.get("month", 10)), 1, 12)
	var dom := clampi(int(ctx.get("dom", 15)), 1, 31)
	var f := {}
	var hol := holiday(month, dom)
	var school_out: bool = hol.get("schedule_cleared", false) or hol.get("at_capacity", false)
	var curve := "weekend" if wd == 0 or wd == 6 or school_out else ("friday" if wd == 5 else "school_day")
	var curves: Dictionary = dem.get("weekday_hour", {})
	var base := _interp(curves.get(curve, []), hour)
	f["base"] = base
	f["day_type"] = curve
	var seasons: Array = dem.get("season_by_month", [])
	f["season"] = float(seasons[month - 1]) if seasons.size() >= 12 else 1.0
	f["holiday"] = float(hol.get("mult", 1.0))
	f["holiday_id"] = str(hol.get("id", ""))
	f["weather"] = weather_factor(dem.get("weather", {}), float(ctx.get("temp_c", 0.0)), str(ctx.get("weather", "clear")), month)
	var ref := float(ps.get("price_ref", 4.0))
	var price := maxf(float(ctx.get("price", ref)), 0.25)
	f["price"] = pow(price / ref, -float(ps.get("price_elasticity", 0.9)))
	f["reputation"] = 0.6 + 0.8 * clampf(float(ctx.get("ice_rep", 40.0)), 0.0, 100.0) / 100.0
	f["line"] = clampf(1.0 - maxf(float(ctx.get("line_minutes", 0.0)) - 5.0, 0.0) / 30.0, 0.5, 1.0)
	var e: float = base * float(f.season) * float(f.holiday) * float(f.weather) * float(f.price) * float(f.reputation) * float(f.line)
	var at_cap := bool(hol.get("at_capacity", false)) and hour >= 9.0 and hour < 22.0
	if at_cap or e >= cap:
		e = cap
		at_cap = true
	return {"expected": e, "capacity": cap, "at_capacity": at_cap, "factors": f}


## A whole number of skaters for one session: the expected count with a
## little day-to-day noise (never above capacity).
static func sample(ctx: Dictionary, rng: RandomNumberGenerator) -> int:
	var d := expected(ctx)
	if d.at_capacity:
		return int(d.capacity)
	var e: float = d.expected
	return clampi(roundi(e * rng.randf_range(0.85, 1.15)), 0, int(d.capacity))


## The best holiday covering a date ({} when none).
static func holiday(month: int, dom: int) -> Dictionary:
	var dem: Dictionary = OnIceData.section("public_skate").get("demand", {})
	var best := {}
	for h in dem.get("holidays", []):
		if not h is Dictionary:
			continue
		var a := OnIceData.v2(h.get("from", [1, 1]))
		var b := OnIceData.v2(h.get("to", [1, 1]))
		if _in_range(month, dom, int(a.x), int(a.y), int(b.x), int(b.y)):
			if best.is_empty() or float(h.get("mult", 1.0)) > float(best.get("mult", 1.0)):
				best = h
	return best


static func weather_factor(w: Dictionary, temp_c: float, cond: String, month: int) -> float:
	var m := 1.0
	match cond:
		"rain": m *= float(w.get("rain", 1.2))
		"snow": m *= float(w.get("snowing", 1.1))
		"blizzard": m *= float(w.get("blizzard", 0.35))
	if temp_c <= float(w.get("cold_snap_c", -15.0)):
		m *= float(w.get("cold_snap", 1.15))
	elif temp_c >= float(w.get("warm_c", 15.0)):
		m *= float(w.get("warm", 0.75))
	elif cond == "clear" and temp_c < -5.0 and month in [1, 2]:
		m *= float(w.get("outdoor_rinks_open", 0.85))  # the pond and the park rink are open
	return m


## The demand context for the session at `hour` on day `d` of a RinkSim.
static func from_sim(sim: RinkSim, d := -1, hour := -1.0) -> Dictionary:
	var dd := sim.day if d < 0 else d
	var dt := sim.date_of(dd)
	var out := {"weekday": sim.weekday_of(dd), "hour": hour if hour >= 0.0 else sim.minute / 60.0,
		"month": int(dt.month), "dom": int(dt.dom), "ice_rep": sim.ice_rep}
	for k in ["weather", "temp_c", "skate_price"]:
		var v: Variant = sim.get(k)
		if v != null:
			out["price" if k == "skate_price" else k] = v
	return out


static func _interp(pts: Array, hour: float) -> float:
	if pts.is_empty():
		return 20.0
	var prev: Array = pts[0]
	if hour <= float(prev[0]):
		return float(prev[1])
	for p in pts:
		if hour <= float(p[0]):
			var t := (hour - float(prev[0])) / maxf(float(p[0]) - float(prev[0]), 0.001)
			return lerpf(float(prev[1]), float(p[1]), t)
		prev = p
	return float(prev[1])


static func _in_range(m: int, d: int, m0: int, d0: int, m1: int, d1: int) -> bool:
	var x := m * 100 + d
	var a := m0 * 100 + d0
	var b := m1 * 100 + d1
	if a <= b:
		return x >= a and x <= b
	return x >= a or x <= b  # wraps the new year
