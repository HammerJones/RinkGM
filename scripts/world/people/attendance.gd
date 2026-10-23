class_name Attendance
extends RefCounted
## Who comes to a session, and how they feel about it afterward. Nobody is a
## fill percentage: every person weighs the event against their interests,
## their schedule, the ice and how the rink has treated them (PEOPLE.md 4).
##
## Everyone who comes has a reason, and most come in groups: the kids on the
## ice bring a parent, sometimes a sibling and a grandparent; a high-school
## player's friends wait for him in the stands; a beer leaguer's partner
## comes to the big games; a scout comes for one player; a figure coach's
## next student waits by the glass; a little one comes to see the Zambelli.
## Each entry carries that as `reason` (see `who_comes`). Working people come
## around their shifts, and for a game that really matters some of them swap
## a shift (`reason.negotiated`).

## Away-town people are less likely to make the drive.
const AWAY_TOWN := 0.35
const HOME_TOWN := "millbrook"
## Events that matter enough to swap a shift for, and how much (0..1).
const STAKES := {"tournament": 0.8, "figure_show": 0.85, "special": 0.7, "senior_hockey": 0.45, "high_school": 0.4,
	"minor_hockey": 0.3, "learn_to_skate": 0.25, "figure_practice": 0.1, "beer_league": 0.15}
## Kinds a scout comes to, and the ones with a resurfacer flood worth seeing.
const SCOUTED := ["minor_hockey", "high_school", "tournament", "senior_hockey", "pro_practice"]
const RINK_PLACES := ["lobby", "glass", "stands", "canteen", "pro_shop", "skate_rental", "community_room"]
## What someone is to a player, from what the player is to them.
const INVERSE_KIN := {"child": "parent", "grandchild": "grandparent", "parent": "child", "sibling": "sibling",
	"partner": "partner", "grandparent": "grandchild"}
## What to call the event in a line ("Tyler's game").
const EVENT_NOUN := {"tournament": "tournament", "figure_show": "ice show", "special": "big night", "senior_hockey": "game",
	"high_school": "game", "minor_hockey": "game", "learn_to_skate": "lesson", "beer_league": "game",
	"figure_practice": "practice", "public_skate": "skate", "broomball": "game", "pro_practice": "practice"}


## `ev`: {"kind", "weekday", "hour" (start), "hours", "pull" (0..1, optional),
## "seats" (stand capacity), "ice_rep", "rating" (ice rating for its use),
## "stakes" (0..1, optional: a final, a test day; defaults by kind)}.
## Returns [{"person": Person, "as": "play"|"watch"|"work", "reason": {...},
## "arrive": minutes before the start (negative: late), "group": id}].
## `reason`: {"why": player, work, parent, sibling, grandparent, partner,
## friend, date, scout, next_student, zamboni, fan, autograph; "for": the
## person id they came for ("" for none); "for_name"; "group"; "until": the
## hour they expect to leave; "negotiated": a line about the shift they
## swapped, or absent}.
static func who_comes(cast: Cast, ev: Dictionary, rng: RandomNumberGenerator) -> Array:
	var kind: String = ev.kind
	var info := cast.kind_info(kind)
	var pull := float(ev.get("pull", info.get("pull", 0.5)))
	var stakes := float(ev.get("stakes", STAKES.get(kind, 0.2)))
	var wd := int(ev.weekday)
	var hour := float(ev.hour)
	var until := hour + float(ev.get("hours", 1.5))
	var ages: Array = info.get("ages", [0, 99])
	var cap: Array = info.get("participants", [0, 40])
	var seats := int(ev.get("seats", 600))
	var max_watch := int(round(seats * float(info.get("spectator_cap", 1.0))))
	var rep := float(ev.get("ice_rep", 50.0))
	var out: Array = []
	var coming := {}
	var players: Array = []
	var watchers: Array = []
	var add := func(p: Person, as__: String, why: Dictionary, arrive: float) -> void:
		var g := str(why.get("group", "solo:" + p.id))
		why.group = g
		if not why.has("until"):
			why.until = until
		out.append({"person": p, "as": as__, "reason": why, "arrive": arrive, "group": g})
		coming[p.id] = true
	for p: Person in cast.people.values():
		if p.on_shift(wd, hour):
			add.call(p, "work", {"why": "work", "place": p.place_at(wd, hour), "until": _shift_end(p, wd, hour)}, rng.randf_range(10.0, 40.0))
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
	coming["_arrive"] = {}
	for p: Person in players:
		var at := rng.randf_range(15.0, 40.0)
		coming["_arrive"][p.id] = [at]
		add.call(p, "play", {"why": "player", "group": "g:" + p.id}, at)
	# the people who come for the players: families first, then friends
	for p: Person in players:
		_bring_family(cast, p, ev, stakes, rng, coming, add)
	for p: Person in players:
		_bring_friends(cast, p, ev, rng, coming, add)
	var n_watch := 0
	for e in out:
		if e.as == "watch":
			n_watch += 1
	watchers.shuffle()
	var scouted := false
	for p: Person in watchers:
		if n_watch >= max_watch:
			break
		if coming.has(p.id):
			continue
		var why := _why_watch(cast, p, kind, players, rng)
		if why.why == "scout":
			if scouted or not kind in SCOUTED:
				continue
			scouted = true
		add.call(p, "watch", why, rng.randf_range(-10.0, 15.0))
		n_watch += 1
		# date night: they come as two
		for fid in p.family:
			if p.kin_of(fid) == "partner" and not coming.has(fid) and p.archetype == "date_night":
				var q: Person = cast.person(fid)
				if q and q.is_free(wd, hour):
					var as_q := "play" if players.has(p) else "watch"
					add.call(q, as_q, {"why": "date", "for": p.id, "for_name": p.known_as, "group": why.group}, out.back().arrive)
	coming.erase("_arrive")
	# a figure coach's next student, waiting by the glass for their lesson
	if kind == "figure_practice":
		_next_students(cast, ev, rng, coming, add)
	# the little one who came to see the Zambelli
	if kind in ["public_skate", "minor_hockey", "figure_practice", "tournament", "learn_to_skate"]:
		_zamboni_fan(cast, ev, rng, coming, add, out)
	return out


## Who brings a player, and who else from the family tags along. A kid
## always gets a ride; a parent who's working may swap the shift when the
## event matters (`stakes`).
static func _bring_family(cast: Cast, p: Person, ev: Dictionary, stakes: float, rng: RandomNumberGenerator, coming: Dictionary, add: Callable) -> void:
	var wd := int(ev.weekday)
	var hour := float(ev.hour)
	var group := "g:" + p.id
	var ride := 25.0
	for e in coming.get("_arrive", {}).get(p.id, []):
		ride = float(e)
	var brought: bool = p.family.any(func(fid): return coming.has(fid) and cast.person(fid) and not cast.person(fid).is_kid())
	# parents first, then siblings and grandparents
	var fam: Array = p.family.duplicate()
	fam.sort_custom(func(a, b): return _kin_rank(p.kin_of(a)) < _kin_rank(p.kin_of(b)))
	for fid in fam:
		var f: Person = cast.person(fid)
		if f == null or coming.has(fid):
			continue
		var rel := p.kin_of(fid)
		if rel == "":
			rel = "sibling" if f.is_kid() else "parent"
		var why := {"why": rel, "for": p.id, "for_name": p.known_as, "group": group}
		var chance := 0.0
		match rel:
			"parent":
				chance = 0.9 if p.is_kid() and not brought else (0.3 + 0.4 * stakes if p.is_kid() else 0.1 + 0.3 * stakes)
			"sibling":
				chance = 0.3 if brought else 0.0
			"grandparent":
				chance = 0.2 + 0.5 * stakes
			"partner":
				chance = 0.12 + 0.6 * stakes
			"child":
				chance = 0.15 if f.is_kid() and brought else 0.0
			_:
				chance = 0.1
		if rel == "partner" and f.archetype == "date_night":
			chance = 0.95
		if rng.randf() >= chance:
			continue
		if not f.is_free(wd, hour):
			var line := negotiate(f, p, ev, stakes, rng)
			if line == "":
				continue
			why.negotiated = line
		var as_f := "watch"
		if rel == "partner" and f.archetype == "date_night":
			chance = 0.95
			why.why = "date"
			as_f = "play" if p.interest(ev.kind, "play") > 0.0 and ev.kind in ["public_skate", "learn_to_skate"] else "watch"
		var arrive := ride if (rel == "parent" and not brought) or rel == "sibling" or why.why == "date" else rng.randf_range(-15.0, 10.0)
		if why.has("negotiated"):
			arrive = rng.randf_range(-20.0, 5.0)  # straight from work, a bit late
		add.call(f, as_f, why, arrive)
		if not f.is_kid():
			brought = true


static func _kin_rank(k: String) -> int:
	return {"parent": 0, "partner": 1, "grandparent": 2, "sibling": 3, "child": 4}.get(k, 5)


## A teen or adult player's friends come to watch, and wait for them after.
static func _bring_friends(cast: Cast, p: Person, ev: Dictionary, rng: RandomNumberGenerator, coming: Dictionary, add: Callable) -> void:
	if p.friends.is_empty() or (p.age < 12 and ev.kind != "tournament"):
		return
	var chance := 0.35 if p.age < 20 else 0.12
	for fid in p.friends:
		var f: Person = cast.person(fid)
		if f == null or coming.has(fid) or not f.is_free(int(ev.weekday), float(ev.hour)):
			continue
		if rng.randf() < chance:
			add.call(f, "watch", {"why": "friend", "for": p.id, "for_name": p.known_as, "group": "g:" + p.id}, rng.randf_range(-20.0, 10.0))


## Why a fan who came on their own is here: somebody they know on the ice,
## a player to scout, an autograph, or just the event.
static func _why_watch(cast: Cast, p: Person, kind: String, players: Array, rng: RandomNumberGenerator) -> Dictionary:
	for q: Person in players:
		if q.id in p.friends or q.id in p.family:
			# kin_of says what the player is to them; the reason is what they are to the player
			var rel: String = INVERSE_KIN.get(p.kin_of(q.id), "friend")
			return {"why": rel, "for": q.id, "for_name": q.known_as, "group": "g:" + q.id}
	if p.archetype == "scout" and not players.is_empty():
		var best: Person = players[0]
		for q: Person in players:
			if q.interest(kind, "play") > best.interest(kind, "play"):
				best = q
		return {"why": "scout", "for": best.id, "for_name": best.known_as}
	if p.archetype == "autograph_hunter" and not players.is_empty():
		var q: Person = players[rng.randi() % players.size()]
		return {"why": "autograph", "for": q.id, "for_name": q.known_as}
	return {"why": "fan", "for": "", "kind": kind}


static func _next_students(cast: Cast, ev: Dictionary, rng: RandomNumberGenerator, coming: Dictionary, add: Callable) -> void:
	var wd := int(ev.weekday)
	var end := float(ev.hour) + float(ev.get("hours", 2.0))
	var n := 0
	for p: Person in cast.people.values():
		if n >= 2:
			break
		if p.archetype != "figure_skater" or coming.has(p.id) or not p.is_free(wd, end - 0.4) or rng.randf() > 0.04:
			continue
		var group := "n:" + p.id
		add.call(p, "watch", {"why": "next_student", "for": "", "group": group, "until": end + 0.5}, rng.randf_range(-60.0, -30.0))
		n += 1
		for fid in p.family:
			var f: Person = cast.person(fid)
			if f and not f.is_kid() and p.kin_of(fid) == "parent" and not coming.has(fid) and f.is_free(wd, end - 0.4):
				add.call(f, "watch", {"why": "parent", "for": p.id, "for_name": p.known_as, "group": group, "until": end + 0.5}, rng.randf_range(-60.0, -30.0))
				break


static func _zamboni_fan(cast: Cast, ev: Dictionary, rng: RandomNumberGenerator, coming: Dictionary, add: Callable, out: Array) -> void:
	# a small kid already here with family, or one brought specially
	for e in out:
		var p: Person = e.person
		if e.as == "watch" and p.age >= 3 and p.age <= 9 and rng.randf() < 0.35:
			e.reason["zamboni"] = true
			if e.reason.why == "sibling":
				e.reason.why = "zamboni"
			return
	for p: Person in cast.people.values():
		if p.age < 3 or p.age > 9 or coming.has(p.id) or rng.randf() > 0.02:
			continue
		if not p.is_free(int(ev.weekday), float(ev.hour)):
			continue
		var group := "z:" + p.id
		add.call(p, "watch", {"why": "zamboni", "for": "", "group": group}, rng.randf_range(0.0, 20.0))
		for fid in p.family:
			var f: Person = cast.person(fid)
			if f and not f.is_kid() and not coming.has(fid) and f.is_free(int(ev.weekday), float(ev.hour)):
				add.call(f, "watch", {"why": "parent", "for": p.id, "for_name": p.known_as, "group": group}, out.back().arrive)
				break
		return


## Somebody whose job keeps them away asks for the time off: worth it when
## the event matters (`stakes`), easier with a flexible job and some nerve.
## Returns the line they'll say about it, or "".
static func negotiate(p: Person, for_: Person, ev: Dictionary, stakes: float, rng: RandomNumberGenerator) -> String:
	if not p.job_block(int(ev.weekday), float(ev.hour)) or stakes < 0.25:
		return ""
	var flex := float(p.work.get("flex", 0.4))
	var chance := stakes * flex * (0.6 + 0.8 * p.trait_value("nerve"))
	if rng.randf() >= chance:
		return ""
	var lines: Array = Townsfolk.jobs_data().get("negotiate", {}).get("lines", ["Swapped a shift for this."])
	var s := str(lines[rng.randi() % lines.size()])
	var label := str(ev.get("name", EVENT_NOUN.get(ev.kind, "big night")))
	return s.format({"boss": str(p.work.get("boss", "the boss")) if str(p.work.get("boss", "")) != "" else "the boss",
		"for": for_.known_as if for_ else "the kid", "event": label, "employer": str(p.work.get("employer", "work")) if str(p.work.get("employer", "")) != "" else "work",
		"job": str(p.work.get("title", "the job")), "kid": for_.known_as if for_ else "the kid"})


static func _shift_end(p: Person, wd: int, hour: float) -> float:
	var e := p.entry_at(wd, hour)
	return float(e.get("to", hour + 4.0))


## People at the rink with no event to watch: rink rats in the lobby after
## school, retirees having their coffee, weekend parents at the glass. The
## schedule says when (a non-work block at a rink place); `chance` thins it.
static func drop_ins(cast: Cast, weekday: int, hour: float, rng: RandomNumberGenerator, chance := 0.5) -> Array:
	var out: Array = []
	for p: Person in cast.people.values():
		var e := p.entry_at(weekday, hour)
		if e.is_empty() or str(e.get("doing", "")) == "work":
			continue
		var place := str(e.get("place", "away"))
		if not place in RINK_PLACES or rng.randf() >= chance * (1.0 if p.town == HOME_TOWN else AWAY_TOWN):
			continue
		out.append({"person": p, "as": "watch", "reason": {"why": "drop_in", "for": "", "place": place,
			"doing": str(e.get("doing", "")), "group": "solo:" + p.id, "until": float(e.get("to", hour + 2.0))},
			"arrive": rng.randf_range(-30.0, 0.0), "group": "solo:" + p.id})
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
