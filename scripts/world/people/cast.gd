class_name Cast
extends RefCounted
## Everyone in the valley: the named cast from data/world/cast.json and the
## generated townsfolk of every town. Load once per save; the people's state
## (mood, memories, relationships) is what the save keeps.
##
##   var cast := Cast.load_region(seed)
##   var bev := cast.person("bev_kowalchuk")

const CAST_PATH := "res://data/world/cast.json"
const ARCHETYPES_PATH := "res://data/world/archetypes.json"
const EVENTS_PATH := "res://data/world/events.json"
## Generated adults in the home town; other towns get their share of this.
const HOME_ADULTS := 220
const HOME_TOWN := "millbrook"

var people := {}        # id -> Person
var archetypes := {}    # id -> archetype dict
var events := {}        # events.json
var seed := 1


static func load_region(seed_ := 1, home_adults := HOME_ADULTS) -> Cast:
	var c := Cast.new()
	c.seed = seed_
	var arch := _json(ARCHETYPES_PATH)
	for a in arch.get("archetypes", []):
		c.archetypes[a.id] = a
	c.events = _json(EVENTS_PATH)
	var towns: Array = arch.get("towns", [{"id": HOME_TOWN, "share": 1.0}])
	var home_share := 1.0
	for t in towns:
		if _town_id(t) == HOME_TOWN:
			home_share = maxf(float(t.get("share", 1.0)), 0.01)
	for t in towns:
		var n := int(round(home_adults * float(t.get("share", 0.0)) / home_share))
		for p in Townsfolk.generate(arch, _town_id(t), n, seed_):
			c.people[p.id] = p
	for d in _json(CAST_PATH).get("people", []):
		var p := Person.from_record(d)
		c.people[p.id] = p
	return c


## A cast built from records, for tests and tools.
static func from_records(records: Array, events_ := {}) -> Cast:
	var c := Cast.new()
	c.events = events_
	for d in records:
		var p := Person.from_record(d)
		c.people[p.id] = p
	return c


func person(id: String) -> Person:
	return people.get(id)


func named() -> Array:
	return people.values().filter(func(p): return not p.generated)


func in_town(town: String) -> Array:
	return people.values().filter(func(p): return p.town == town)


func kind_info(kind: String) -> Dictionary:
	return events.get("kinds", {}).get(kind, {})


## The event kind of a contract org (RinkContracts id).
func kind_of_org(org: String) -> String:
	return str(events.get("contracts", {}).get(org, RinkContracts.org(org).get("event", "public_skate")))


func archetype(id: String) -> Dictionary:
	return archetypes.get(id, {})


## A line for `topic` ("idle", "bad_ice", "goal"...) from the person's
## archetype barks, or "" if they have none.
func bark(p: Person, topic: String, rng: RandomNumberGenerator, kind := "") -> String:
	var b: Dictionary = archetype(p.archetype).get("barks", {})
	var lines: Array = []
	if kind != "" and topic == "event_specific":
		lines = b.get("event_specific", {}).get(kind, [])
	else:
		lines = b.get(topic, [])
	return str(lines[rng.randi() % lines.size()]) if not lines.is_empty() else ""


func daily_fade(day: int) -> void:
	for p in people.values():
		p.fade(day)


func state() -> Dictionary:
	var d := {}
	for id in people:
		var p: Person = people[id]
		if p.visits > 0 or not p.memory.is_empty() or not p.generated:
			d[id] = p.state()
	return {"seed": seed, "people": d}


func apply_state(d: Dictionary) -> void:
	var ps: Dictionary = d.get("people", {})
	for id in ps:
		if people.has(id):
			people[id].apply_state(ps[id])


static func _town_id(t) -> String:
	return str(t.get("id", t.get("name", HOME_TOWN))) if t is Dictionary else str(t)


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
