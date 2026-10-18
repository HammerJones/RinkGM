class_name Townsfolk
extends RefCounted
## Generates a town's ordinary people from archetypes (data/world/archetypes.json).
## Seeded by the town, so the same Ferland family sits in row C every
## Saturday of every playthrough with that seed. Parents bring kids: a hockey
## parent's kids play minor hockey, a figure parent's kids skate.

## What a parent archetype's kids grow up into.
const KID_ARCHETYPE := {"hockey_parent": "minor_player", "figure_parent": "figure_skater", "coffee_coach": "minor_player"}
const KID_FALLBACK := ["minor_player", "figure_skater", "rink_rat", "teen"]


## `count` adults (and their kids on top) for `town`. Ids are "<town>_<n>".
static func generate(data: Dictionary, town: String, count: int, seed_: int) -> Array[Person]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [town, seed_])
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
		for k in nk:
			var kid_arch: String = KID_ARCHETYPE.get(a.id, KID_FALLBACK[rng.randi() % KID_FALLBACK.size()])
			if not by_id.has(kid_arch):
				continue
			var kid := _make(by_id[kid_arch], town, "%s_%d" % [town, n], surname, rng, 0)
			n += 1
			kid.role = "family"
			kid.family.append(p.id)
			p.family.append(kid.id)
			out.append(kid)
	# siblings know each other
	for p in out:
		if p.is_kid() and not p.family.is_empty():
			for q in out:
				if q != p and q.is_kid() and not q.family.is_empty() and q.family[0] == p.family[0]:
					p.family.append(q.id)
	return out


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
		"schedule": a.get("schedule", []), "dialogue": "archetype_" + str(a.id),
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
