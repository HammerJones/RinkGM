class_name Townsfolk
extends RefCounted
## Generates a town's ordinary people from archetypes (data/world/archetypes.json).
## Seeded by the town, so the same Ferland family sits in row C every
## Saturday of every playthrough with that seed. Parents bring kids: a hockey
## parent's kids play minor hockey, a figure parent's kids skate.
##
## Everyone comes out with a life around the rink: a partner (the archetype's
## `family.partner` chance), grandparents linked to the families in town,
## friends their own age, a day job from data/world/jobs.json whose hours
## replace the archetype's generic work block (so rink time fits around the
## shift), how they get to the rink, and a short backstory assembled from
## data/world/backstory.json. The extras draw from their own random stream.

## What a parent archetype's kids grow up into.
const KID_ARCHETYPE := {"hockey_parent": "minor_player", "figure_parent": "figure_skater", "coffee_coach": "minor_player"}
const KID_FALLBACK := ["minor_player", "figure_skater", "rink_rat", "teen"]
## Their "kids" are grown up: they get grandchildren in town instead.
const ELDERS := ["grandparent", "retiree_regular"]
## A partner of a parent archetype shares the kids; date night couples come as two.
const PARTNER_OF := {"hockey_parent": ["hockey_parent", "beer_leaguer", "superfan", "figure_parent"],
	"figure_parent": ["figure_parent", "hockey_parent", "learn_to_skate_adult"],
	"coffee_coach": ["hockey_parent", "figure_parent"], "date_night": ["date_night"],
	"grandparent": ["grandparent"], "retiree_regular": ["retiree_regular", "grandparent"]}
const JOBS_PATH := "res://data/world/jobs.json"
const BACKSTORY_PATH := "res://data/world/backstory.json"

static var _jobs := {}
static var _story := {}


## `count` adults (and their kids on top) for `town`. Ids are "<town>_<n>".
static func generate(data: Dictionary, town: String, count: int, seed_: int) -> Array[Person]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [town, seed_])
	# the extras (partners, jobs, stories) draw from their own stream
	var xr := RandomNumberGenerator.new()
	xr.seed = hash("%s:%d:life" % [town, seed_])
	var arch: Array = data.get("archetypes", [])
	var by_id := {}
	for a in arch:
		by_id[a.id] = a
	var adults := arch.filter(func(a): return int(a.get("age", [18, 80])[1]) >= 18 and float(a.get("weight", 0.0)) > 0.0)
	var surnames: Array = data.get("surnames", ["Smith"])
	var out: Array[Person] = []
	var n := 0
	for i in count:
		var a: Dictionary = _pick(adults, rng)
		var surname: String = surnames[rng.randi() % surnames.size()]
		var p := _make(a, town, "%s_%d" % [town, n], surname, rng, 18)
		n += 1
		out.append(p)
		var kids: Array = a.get("family", {}).get("kids", [0, 0])
		var nk := rng.randi_range(int(kids[0]), int(kids[1])) if kids.size() == 2 else 0
		if a.id in ELDERS:
			nk = 0  # grown up and moved out; they get grandkids below
		for k in nk:
			var kid_arch: String = KID_ARCHETYPE.get(a.id, KID_FALLBACK[rng.randi() % KID_FALLBACK.size()])
			if not by_id.has(kid_arch):
				continue
			var kid := _make(by_id[kid_arch], town, "%s_%d" % [town, n], surname, rng, 0)
			n += 1
			kid.role = "family"
			kid.family.append(p.id)
			kid.kin[p.id] = "parent"
			p.family.append(kid.id)
			p.kin[kid.id] = "child"
			out.append(kid)
	# siblings know each other
	for p in out:
		if p.is_kid() and not p.family.is_empty():
			for q in out:
				if q != p and q.is_kid() and not q.family.is_empty() and q.family[0] == p.family[0]:
					p.family.append(q.id)
					p.kin[q.id] = "sibling"
	_partners(out, by_id, town, xr, n)
	_grandparents(out, xr)
	_friends(out, xr)
	for p in out:
		assign_job(p, xr)
		p.commute = _commute(p, xr)
		p.backstory = backstory(p, out, xr)
	return out


# ------------------------------------------------------------------ families

## Some adults come with a partner: a new person of a fitting archetype and
## the same surname, who shares the kids.
static func _partners(out: Array[Person], by_id: Dictionary, town: String, rng: RandomNumberGenerator, n: int) -> void:
	var made: Array[Person] = []
	var idx := {}
	for p in out:
		idx[p.id] = p
	for p in out:
		if p.is_kid() or not PARTNER_OF.has(p.archetype):
			continue
		var a: Dictionary = by_id.get(p.archetype, {})
		if rng.randf() >= float(a.get("family", {}).get("partner", 0.0)):
			continue
		var choices: Array = PARTNER_OF[p.archetype]
		var pa: Dictionary = by_id.get(choices[rng.randi() % choices.size()], a)
		var q := _make(pa, town, "%s_%d" % [town, n], p.name.get_slice(" ", 1), rng, 18)
		n += 1
		q.age = clampi(p.age + rng.randi_range(-5, 5), 18, 95)
		q.pronouns = "he/him" if p.pronouns == "she/her" else ("she/her" if p.pronouns == "he/him" else q.pronouns)
		q.family.append(p.id)
		q.kin[p.id] = "partner"
		p.family.append(q.id)
		p.kin[q.id] = "partner"
		q.change_rel(p.id, 60)
		p.change_rel(q.id, 60)
		for kid_id in p.family:
			var kid: Person = idx.get(kid_id)
			if kid and kid.is_kid():
				q.family.append(kid.id)
				q.kin[kid.id] = "child"
				kid.family.append(q.id)
				kid.kin[q.id] = "parent"
		made.append(q)
	out.append_array(made)


## Grandparents and retirees are linked to a family with kids in town, as
## that family's grandparents (a grandparent couple shares one family).
static func _grandparents(out: Array[Person], rng: RandomNumberGenerator) -> void:
	var idx := {}
	var families: Array = []   # parent Persons with kids
	for p in out:
		idx[p.id] = p
		if not p.is_kid() and not p.archetype in ELDERS and p.family.any(func(f): return p.kin_of(f) == "child"):
			families.append(p)
	if families.is_empty():
		return
	var taken := {}
	for g in out:
		if not g.archetype in ELDERS or g.family.any(func(f): return g.kin_of(f) == "grandchild"):
			continue
		if g.archetype == "retiree_regular" and rng.randf() < 0.5:
			continue  # some retirees' families live away
		var fam: Person = null
		for t in 6:
			var c: Person = families[rng.randi() % families.size()]
			if int(taken.get(c.id, 0)) < 2:
				fam = c
				break
		if fam == null:
			continue
		var partner := ""
		for f in g.family:
			if g.kin_of(f) == "partner":
				partner = f
		for gid in [g.id, partner]:
			if gid == "":
				continue
			var gp: Person = idx.get(gid)
			if gp == null or gp.family.any(func(f): return gp.kin_of(f) == "grandchild"):
				continue
			taken[fam.id] = int(taken.get(fam.id, 0)) + 1
			gp.family.append(fam.id)
			gp.kin[fam.id] = "child"
			fam.family.append(gp.id)
			fam.kin[gp.id] = "parent"
			for kid_id in fam.family:
				var kid: Person = idx.get(kid_id)
				if kid and kid.is_kid() and fam.kin_of(kid_id) == "child":
					gp.family.append(kid.id)
					gp.kin[kid.id] = "grandchild"
					kid.family.append(gp.id)
					kid.kin[gp.id] = "grandparent"
					gp.change_rel(kid.id, 80)


## Kids and teens have friends their own age in town; beer leaguers and
## broomballers have teammates.
static func _friends(out: Array[Person], rng: RandomNumberGenerator) -> void:
	var groups := {}
	for p in out:
		var key := ""
		if p.is_kid():
			key = "kid:%d" % (p.age / 3)
		elif p.archetype in ["beer_leaguer", "broomballer", "stick_and_puck_regular", "superfan", "retiree_regular"]:
			key = "adult:" + p.archetype
		if key != "":
			if not groups.has(key):
				groups[key] = []
			groups[key].append(p)
	for key in groups:
		var g: Array = groups[key]
		if g.size() < 2:
			continue
		for p: Person in g:
			var want := rng.randi_range(1, 3)
			for t in want * 3:
				if p.friends.size() >= want:
					break
				var q: Person = g[rng.randi() % g.size()]
				if q == p or q.id in p.friends or q.id in p.family:
					continue
				p.friends.append(q.id)
				q.friends.append(p.id)
				var r := rng.randi_range(25, 70)
				p.change_rel(q.id, r)
				q.change_rel(p.id, r)


# ---------------------------------------------------------------------- jobs

## A day job that fits their archetype, town and age (jobs.json), with its
## hours put into their schedule in place of the archetype's generic work
## block. Kids get a part-time job only from 15 or so; retirees none.
static func assign_job(p: Person, rng: RandomNumberGenerator) -> void:
	var data := jobs_data()
	var pool: Array = data.get("jobs", []).filter(func(j): return p.archetype in j.get("archetypes", []) \
		and (p.town in j.get("towns", []) or j.get("towns", []).is_empty()) and p.age >= int(j.get("min_age", 18)))
	if p.archetype in ELDERS and p.age >= 66:
		pool = []
	if p.is_kid() and rng.randf() < 0.6:
		pool = []  # most kids don't work
	if pool.is_empty():
		p.job = str(data.get("no_job", {}).get(p.archetype, "In school" if p.is_kid() else ("Retired" if p.age >= 65 else "")))
		return
	var j: Dictionary = pool[rng.randi() % pool.size()]
	var hours: Array = j.get("hours", [[[1, 2, 3, 4, 5], 9.0, 17.0]])
	var h: Array = hours[rng.randi() % hours.size()].duplicate()
	h[0] = Person.int_days(h[0])
	p.work = {"title": str(j.title), "employer": str(j.employer), "days": h[0], "from": float(h[1]), "to": float(h[2]),
		"place": "away", "flex": float(j.get("flex", 0.5)), "boss": str(j.get("boss", "the boss")), "id": str(j.id)}
	p.job = "%s, %s" % [j.title, j.employer]
	if j.has("commute"):
		p.commute = str(j.commute)
	var sched: Array = []
	for e in p.schedule:
		var doing := str(e.get("doing", ""))
		# the archetype's stand-in work hours give way to the real job
		if not p.is_kid() and str(e.get("place", "")) == "away" and doing in ["work", "day job", "night shift", "afternoon shift", "the shop", "school or work"]:
			continue
		sched.append(e)
	sched.push_front({"days": h[0], "from": float(h[1]), "to": float(h[2]), "place": "away", "doing": "work"})
	p.schedule = sched


static func _commute(p: Person, rng: RandomNumberGenerator) -> String:
	var c: Dictionary = jobs_data().get("commute", {})
	if p.age < 13:
		return "ride"
	var pick := func(k: String, d: String) -> String:
		var xs = c.get(k, [d])
		return str(xs[rng.randi() % xs.size()]) if xs is Array and not xs.is_empty() else d
	if p.is_kid():
		return pick.call("teen", "foot")
	if p.town != "millbrook":
		return "car"
	if p.age >= 75:
		return pick.call("elder", "car")
	if p.work.get("id", "") != "" and p.commute != "":
		return p.commute
	return pick.call("adult_home", "car")


static func jobs_data() -> Dictionary:
	if _jobs.is_empty():
		_jobs = _json(JOBS_PATH)
		if _jobs.is_empty():
			_jobs = {"jobs": []}
	return _jobs


static func story_data() -> Dictionary:
	if _story.is_empty():
		_story = _json(BACKSTORY_PATH)
		if _story.is_empty():
			_story = {"who": {}}
	return _story


# ----------------------------------------------------------------- backstory

## Two or three sentences that fit their archetype, family, job and town:
## who they are, their work or family, one thing the rink knows about them.
static func backstory(p: Person, people: Array, rng: RandomNumberGenerator) -> String:
	var d := story_data()
	var idx := {}
	for q in people:
		idx[q.id] = q
	var tok := _tokens(p, idx, rng)
	var out: Array = []
	var who: Dictionary = d.get("who", {})
	var s := _pick_line(who.get(p.archetype, who.get("any", [])), tok, rng)
	if s != "":
		out.append(s)
	var fam: Dictionary = d.get("family", {})
	var lines: Array = []
	if p.is_kid():
		lines = fam.get("kid", [])
	elif tok.has("grandkid") and rng.randf() < 0.7:
		lines = fam.get("grandkids", [])
	elif tok.has("kids") and rng.randf() < 0.5:
		lines = fam.get("kids", [])
	elif tok.has("partner"):
		lines = fam.get("partner", [])
	else:
		lines = fam.get("single", [])
	var work_line := ""
	if not p.work.is_empty() and not (out.size() > 0 and str(tok.get("employer", "")) in out[0]):
		work_line = _pick_line(d.get("work", []), tok, rng)
	elif p.job == "Retired" and tok.has("employer"):
		work_line = _pick_line(d.get("retired", []), tok, rng)
	var fam_line := _pick_line(lines, tok, rng)
	if work_line != "" and (fam_line == "" or rng.randf() < 0.55):
		out.append(work_line)
		if fam_line != "" and rng.randf() < 0.35:
			out.append(fam_line)
	elif fam_line != "":
		out.append(fam_line)
	var r := _pick_line(d.get("rink", []), tok, rng)
	if r != "":
		out.append(r)
	for i in out.size():
		out[i] = str(out[i]).left(1).to_upper() + str(out[i]).substr(1)
	return " ".join(out)


static func _tokens(p: Person, idx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var t := {"first": p.known_as, "surname": p.name.get_slice(" ", 1), "town": _town_name(p.town), "age": str(p.age),
		"years": str(clampi(p.age - 20, 2, 40) if p.age > 22 else 2), "since": str(2026 - clampi(p.age - 18, 3, 50)),
		"grade": str(clampi(p.age - 5, 7, 12)), "retired": str(2026 - clampi(p.age - 64, 1, 30))}
	if not p.work.is_empty():
		t.job = str(p.work.get("title", "")).to_lower()
		t.job_a = _a(t.job)
		t.employer = str(p.work.get("employer", ""))
	elif p.job == "Retired":
		t.employer = ["Kessler Pulp & Paper", "the Dairy", "the post office", "the school board", "Maple Tire", "the Hydro"][rng.randi() % 6]
	var kids: Array = []
	for f in p.family:
		var q: Person = idx.get(f)
		if q == null:
			continue
		match p.kin_of(f):
			"partner": t.partner = q.known_as
			"child":
				if q.is_kid():
					kids.append(q.known_as)
			"grandchild": t.grandkid = q.known_as
			"parent":
				if p.is_kid():
					t.parent = q.known_as if rng.randf() < 0.3 else ("their mom" if q.pronouns == "she/her" else ("their dad" if q.pronouns == "he/him" else "their parent"))
	if not kids.is_empty():
		t.kid = kids[0]
		t.kids = kids[0] if kids.size() == 1 else ("%s and %s" % [", ".join(kids.slice(0, kids.size() - 1)), kids.back()])
	if not p.friends.is_empty() and idx.has(p.friends[0]):
		t.friend = idx[p.friends[0]].known_as
	var favs := p.favourites("watch", 2) if p.favourites("play", 1).is_empty() else p.favourites("play", 1) + p.favourites("watch", 1)
	if not favs.is_empty():
		t.fav = _kind_word(favs[0])
		if favs.size() > 1 and favs[1] != favs[0]:
			t.fav2 = _kind_word(favs[1])
	return t


## A random line whose tokens can all be filled, filled; "" if none can.
static func _pick_line(lines: Array, tok: Dictionary, rng: RandomNumberGenerator) -> String:
	if lines.is_empty():
		return ""
	var start := rng.randi() % lines.size()
	for i in lines.size():
		var s := str(lines[(start + i) % lines.size()])
		var ok := true
		var at := s.find("{")
		while at >= 0:
			var end := s.find("}", at)
			if end < 0 or not tok.has(s.substr(at + 1, end - at - 1)):
				ok = false
				break
			at = s.find("{", end)
		if ok:
			return s.format(tok)
	return ""


static func _a(s: String) -> String:
	if s == "":
		return s
	return ("an " if s[0] in ["a", "e", "i", "o", "u"] else "a ") + s


static func _kind_word(kind: String) -> String:
	return {"beer_league": "beer league", "minor_hockey": "minor hockey", "high_school": "high school hockey",
		"senior_hockey": "the Lumber Kings", "pro_practice": "Dukes practice", "tournament": "tournament weekends",
		"figure_practice": "figure practice", "figure_show": "the ice show", "public_skate": "public skate",
		"learn_to_skate": "learn-to-skate", "stick_and_puck": "stick and puck", "broomball": "broomball",
		"special": "the special nights"}.get(kind, kind.replace("_", " "))


static func _town_name(id: String) -> String:
	return {"harlow_falls": "Harlow Falls", "port_ainsley": "Port Ainsley", "sainte_odile": "Sainte-Odile"}.get(id, id.capitalize())


static func _make(a: Dictionary, town: String, id: String, surname: String, rng: RandomNumberGenerator, min_age: int) -> Person:
	var ages: Array = a.get("age", [20, 70])
	var age := rng.randi_range(maxi(int(ages[0]), min_age), maxi(int(ages[1]), min_age))
	var firsts: Array = a.get("first_names", ["Sam"])
	var first: String = firsts[rng.randi() % firsts.size()]
	var traits := {}
	var tr: Dictionary = a.get("traits", {})
	for t in Person.TRAITS:
		var r: Array = tr.get(t, [0.2, 0.8])
		traits[t] = snappedf(rng.randf_range(float(r[0]), float(r[1])), 0.01)
	var interests := {}
	var base: Dictionary = a.get("interests", {})
	for kind in base:
		var w: Dictionary = base[kind]
		interests[kind] = {
			"watch": clampf(float(w.get("watch", 0.0)) + rng.randf_range(-0.15, 0.15), 0.0, 1.0) if float(w.get("watch", 0.0)) > 0.0 else 0.0,
			"play": clampf(float(w.get("play", 0.0)) + rng.randf_range(-0.15, 0.15), 0.0, 1.0) if float(w.get("play", 0.0)) > 0.0 else 0.0,
		}
	var lk: Dictionary = a.get("look", {})
	var colors: Array = lk.get("colors", [["39424e", "c9c2b0"]])
	var look := {
		"build": _any(lk.get("builds", ["average"]), rng),
		"height": snappedf(rng.randf_range(0.9, 1.08), 0.01),
		"skin": rng.randi() % 4,
		"hair": _any(lk.get("hair", ["short"]), rng),
		"hair_color": _any(["2b1d14", "5a3a22", "8a6a3a", "c9a25a", "1d1d22", "8a8a8a", "d9d4c7", "9c3b1f"] if age < 60 else ["8a8a8a", "c9c2b0", "d9d4c7", "5a3a22"], rng),
		"outfit": _any(lk.get("outfits", ["casual"]), rng),
		"colors": colors[rng.randi() % colors.size()],
		"accessory": _any(lk.get("accessories", ["none"]), rng),
	}
	var rec := {
		"id": id, "name": "%s %s" % [first, surname], "known_as": first, "age": age,
		"town": town, "role": a.get("role", "customer"), "archetype": a.id,
		"look": look, "traits": traits, "interests": interests,
		"schedule": a.get("schedule", []).duplicate(true), "dialogue": "archetype_" + str(a.id),
	}
	var p := Person.from_record(rec, true)
	p.pronouns = _any(["she/her", "he/him", "she/her", "he/him", "they/them"], rng)
	return p


static func _pick(arch: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for a in arch:
		total += float(a.get("weight", 0.0))
	var r := rng.randf() * total
	for a in arch:
		r -= float(a.get("weight", 0.0))
		if r <= 0.0:
			return a
	return arch.back()


static func _any(xs: Array, rng: RandomNumberGenerator):
	return xs[rng.randi() % xs.size()] if not xs.is_empty() else ""


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
