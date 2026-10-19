class_name Attendance
extends RefCounted
## Who comes to a session, and how they feel about it afterward. Nobody is a
## fill percentage: every person weighs the event against their interests,
## their schedule, the ice and how the rink has treated them (PEOPLE.md 4).

## Away-town people are less likely to make the drive.
const AWAY_TOWN := 0.35
const HOME_TOWN := "millbrook"


## `ev`: {"kind", "weekday", "hour" (start), "hours", "pull" (0..1, optional),
## "seats" (stand capacity), "ice_rep", "rating" (ice rating for its use)}.
## Returns [{"person": Person, "as": "play"|"watch"|"work"}] (families
## included, staff on shift too).
static func who_comes(cast: Cast, ev: Dictionary, rng: RandomNumberGenerator) -> Array:
	var kind: String = ev.kind
	var info := cast.kind_info(kind)
	var pull := float(ev.get("pull", info.get("pull", 0.5)))
	var wd := int(ev.weekday)
	var hour := float(ev.hour)
	var ages: Array = info.get("ages", [0, 99])
	var cap: Array = info.get("participants", [0, 40])
	var seats := int(ev.get("seats", 600))
	var max_watch := int(round(seats * float(info.get("spectator_cap", 1.0))))
	var rep := float(ev.get("ice_rep", 50.0))
	var out: Array = []
	var coming := {}
	var players: Array = []
	var watchers: Array = []
	for p: Person in cast.people.values():
		if p.on_shift(wd, hour):
			out.append({"person": p, "as": "work"})
			coming[p.id] = true
			continue
		if not p.is_free(wd, hour):
			continue
		var town := AWAY_TOWN if p.town != HOME_TOWN else 1.0
		var draw := clampf(0.45 + (rep - 40.0) / 100.0 * (1.3 - p.trait_value("patience")), 0.1, 1.3)
		var mood := clampf(p.mood / 0.7, 0.0, 1.3)
		# a person goes to so many events a week; scale chance to that
		var base := 0.55 * town * draw * mood * (0.5 + pull)
		var play := p.interest(kind, "play")
		if play > 0.0 and p.age >= int(ages[0]) and p.age <= int(ages[1]) and rng.randf() < play * base:
			players.append(p)
			continue
		var watch := p.interest(kind, "watch")
		if watch > 0.0 and rng.randf() < watch * base * 0.8:
			watchers.append(p)
	players.shuffle()
	if players.size() > int(cap[1]):
		players.resize(int(cap[1]))
	for p in players:
		out.append({"person": p, "as": "play"})
		coming[p.id] = true
	# kids don't drive: somebody in the family brings them, maybe the siblings too
	for p in players:
		if not p.is_kid():
			continue
		var brought: bool = p.family.any(func(fid): return coming.has(fid) and cast.person(fid) and not cast.person(fid).is_kid())
		for fid in p.family:
			var f: Person = cast.person(fid)
			if f == null or coming.has(fid) or not f.is_free(wd, hour):
				continue
			var chance := 0.3 if f.is_kid() or brought else 0.9
			if rng.randf() < chance:
				out.append({"person": f, "as": "watch"})
				coming[fid] = true
				brought = brought or not f.is_kid()
	var n_watch := 0
	for e in out:
		if e.as == "watch":
			n_watch += 1
	watchers.shuffle()
	for p in watchers:
		if n_watch >= max_watch:
			break
		if coming.has(p.id):
			continue
		out.append({"person": p, "as": "watch"})
		coming[p.id] = true
		n_watch += 1
	return out


## After the session: everyone who came remembers how it went. `how`:
## {"day", "kind", "rating" (ice 0..100), "wet_wait" (minutes at the gate),
## "cancelled", "line_minutes" (longest canteen wait), "cold" (0..1),
## "extra": {person id: [what, delta]}}. Returns the average mood change.
static func settle(came: Array, how: Dictionary) -> float:
	var total := 0.0
	var day := int(how.get("day", 0))
	for e in came:
		var p: Person = e.person
		if e.as == "work":
			continue
		p.visits += 1
		p.last_visit = day
		var d := 0.0
		var what := ""
		if how.get("cancelled", false):
			d = -0.2
			what = "came all the way for a cancelled %s" % how.kind
		else:
			var r := float(how.get("rating", 60.0))
			# players feel the ice; watchers feel the seats and the canteen
			var w := 1.0 if e.as == "play" else 0.35
			d += (r - 55.0) / 300.0 * w
			if r < 35.0:
				what = "the ice was awful"
			var wet := float(how.get("wet_wait", 0.0))
			if e.as == "play" and wet > 0.0:
				d -= wet / 60.0 * (1.2 - p.trait_value("patience"))
				what = "waited %d minutes for the ice to dry" % int(wet)
			var line := float(how.get("line_minutes", 0.0))
			if line > 8.0:
				d -= (line - 8.0) / 80.0 * (1.2 - p.trait_value("patience"))
				what = "waited %d minutes at the canteen" % int(line)
			d -= float(how.get("cold", 0.0)) * 0.05
			d += 0.02 * p.interest(how.kind, e.as)  # they like this kind of night
		var x: Array = how.get("extra", {}).get(p.id, [])
		if x.size() == 2:
			what = str(x[0])
			d += float(x[1])
		p.remember(day, what if what != "" else ("a good %s" % how.kind if d >= 0.0 else "a so-so %s" % how.kind), d)
		total += d
	return total / maxf(came.size(), 1.0)
