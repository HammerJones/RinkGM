class_name QuestLog
extends RefCounted
## Side quests and favours (data/world/quests.json, PEOPLE.md 8): which are on
## offer, which are running, and their goals. Goals advance from what happens
## (`notify`: a talk, a visit, a session, a job) or from the state of the rink
## (`tick`: reputation, facility score, items, flags).

const QUESTS_PATH := "res://data/world/quests.json"
## Goal types checked from state rather than from an event.
const POLLED := ["rep_gte", "rooms_gte", "item", "flag", "contract"]

## Weak, so the world and its quest log don't keep each other alive.
var world: StoryWorld:
	get: return _world.get_ref() if _world else null
	set(w): _world = weakref(w)
var _world: WeakRef
var defs := {}       # quest id -> definition
var favours: Array = []
var states := {}     # quest id -> {"status", "step", "count", "started", "giver"}


static func create(w: StoryWorld, data := {}) -> QuestLog:
	var q := QuestLog.new()
	q.world = w
	if data.is_empty() and FileAccess.file_exists(QUESTS_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH))
	for d in data.get("quests", []):
		q.defs[d.id] = d
	q.favours = data.get("favours", [])
	return q


func def(id: String) -> Dictionary:
	return defs.get(id, {})


## "inactive", "active", "done" or "failed".
func status(id: String) -> String:
	return str(states.get(id, {}).get("status", "inactive"))


func step_id(id: String) -> String:
	var st: Dictionary = states.get(id, {})
	var steps: Array = def(id).get("steps", [])
	var i := int(st.get("step", 0))
	return str(steps[i].id) if i < steps.size() else ""


func step_text(id: String) -> String:
	var steps: Array = def(id).get("steps", [])
	var i := int(states.get(id, {}).get("step", 0))
	return world.fill(str(steps[i].get("text", ""))) if i < steps.size() else ""


func active() -> Array:
	return states.keys().filter(func(id): return status(id) == "active")


## Quests `giver` could offer right now (not started, conditions met, any
## chain predecessor done).
func offers_from(giver: Person) -> Array:
	var out: Array = []
	for id in defs:
		var d: Dictionary = defs[id]
		if not _gives(d, giver) or status(id) != "inactive":
			continue
		if d.has("after") and status(d.after) != "done":
			continue
		if world.check(d.get("start", []), giver):
			out.append(id)
	return out


## Running quests whose current step is a talk with `giver`, or that they gave.
func involving(giver: Person) -> Array:
	return active().filter(func(id): return _gives(def(id), giver) or _talk_target(id) == giver.id)


## A favour `p` could ask today, made from their archetype's templates and
## registered under its own id ("<template>@<person>"), or "" if none. One
## open favour per person at a time; each template once a fortnight.
func favour_from(p: Person) -> String:
	for id in active():
		if str(def(id).get("giver", "")) == p.id:
			return ""
	for f in favours:
		if str(f.get("giver", "")) != "archetype:" + p.archetype:
			continue
		var id := "%s@%s" % [f.id, p.id]
		var st: Dictionary = states.get(id, {})
		if not st.is_empty() and (st.status == "active" or world.day() - int(st.get("done", st.started)) < 14):
			continue
		if not world.check(f.get("start", []), p):
			continue
		var d: Dictionary = f.duplicate(true)
		d.id = id
		d.giver = p.id
		d.kind = "favour"
		d.title = str(d.get("title", f.id)).format({"name": p.name, "known_as": p.known_as})
		d.summary = str(d.get("summary", "")).format({"name": p.name, "known_as": p.known_as})
		d.template = f.id
		defs[id] = d
		states.erase(id)
		return id
	return ""


func _gives(d: Dictionary, p: Person) -> bool:
	var g := str(d.get("giver", ""))
	return g == p.id or g == "archetype:" + p.archetype


## Running quests whose current step is a talk with `p` (not as giver).
func talk_steps(p: Person) -> Array:
	return active().filter(func(id): return _talk_target(id) == p.id)


func _talk_target(id: String) -> String:
	var steps: Array = def(id).get("steps", [])
	var i := int(states.get(id, {}).get("step", 0))
	if i < steps.size() and str(steps[i].goal.get("type", "")) == "talk":
		return str(steps[i].goal.get("to", ""))
	return ""


func start(id: String, giver := "") -> bool:
	if not defs.has(id) or status(id) == "active":
		return false
	states[id] = {"status": "active", "step": 0, "count": 0, "started": world.day(), "giver": giver}
	world.note("New: %s" % world.fill(str(def(id).get("title", id))))
	tick()
	return true


func advance_to(id: String, step: String) -> void:
	var steps: Array = def(id).get("steps", [])
	for i in steps.size():
		if str(steps[i].id) == step:
			states[id].step = i
			states[id].count = 0
			return


func complete(id: String) -> void:
	if status(id) != "active":
		return
	states[id].status = "done"
	states[id].done = world.day()
	world.apply(def(id).get("reward", []), world.cast.person(str(def(id).get("giver", ""))))
	world.note("Done: %s" % world.fill(str(def(id).get("title", id))))


func fail(id: String) -> void:
	if status(id) != "active":
		return
	states[id].status = "failed"
	world.apply(def(id).get("fail", {}).get("effects", []))


## Something happened. `type` is a goal type ("talk", "visit", "event_held",
## "job_done", "rating_gte", "attend"); `data` carries its fields.
func notify(type: String, data: Dictionary) -> void:
	for id in active():
		var g := _goal(id)
		if str(g.get("type", "")) != type:
			continue
		var hit := false
		match type:
			"talk": hit = str(g.to) == str(data.get("to", ""))
			"visit": hit = str(g.place) == str(data.get("place", ""))
			"event_held": hit = str(g.get("event", "")) in ["", str(data.get("event", ""))] \
					and str(g.get("name", "")) in ["", str(data.get("name", ""))] \
					and float(data.get("rating", 0.0)) >= float(g.get("min_rating", 0.0))
			"job_done": hit = str(g.job) == str(data.get("job", ""))
			"rating_gte": hit = str(g.get("use", "")) in ["", str(data.get("use", ""))] and float(data.get("rating", 0.0)) >= float(g.value)
			"attend": hit = str(g.person) == str(data.get("person", "")) and str(g.get("event", "")) in ["", str(data.get("event", ""))]
		if hit:
			states[id].count = int(states[id].count) + 1
			if states[id].count >= int(g.get("count", 1)):
				_step_done(id)


## Polled goals and timeouts; call after anything changes and once a day.
func tick() -> void:
	for id in active():
		var g := _goal(id)
		var t := str(g.get("type", ""))
		if t in POLLED:
			var ok := false
			match t:
				"rep_gte": ok = world.sim != null and world.sim.ice_rep >= float(g.value)
				"rooms_gte": ok = world.sim != null and world.sim.facility_score() >= float(g.value)
				"item": ok = int(world.items.get(g.id, 0)) >= int(g.get("count", 1))
				"flag": ok = world.flags.has(g.flag)
				"contract": ok = world.sim != null and world.sim.contracts.has(g.org)
			if ok:
				_step_done(id)
				continue
		var after := int(def(id).get("fail", {}).get("after_days", 0))
		if after > 0 and world.day() - int(states[id].started) > after:
			fail(id)


func _goal(id: String) -> Dictionary:
	var steps: Array = def(id).get("steps", [])
	var i := int(states[id].step)
	return steps[i].get("goal", {}) if i < steps.size() else {}


func _step_done(id: String) -> void:
	var steps: Array = def(id).get("steps", [])
	var i := int(states[id].step)
	world.apply(steps[i].get("on_done", []))
	if status(id) != "active":
		return
	if i + 1 >= steps.size():
		complete(id)
	else:
		states[id].step = i + 1
		states[id].count = 0
		tick()


func state() -> Dictionary:
	var favour_defs := {}
	for id in states:
		if str(def(id).get("kind", "")) == "favour":
			favour_defs[id] = def(id)
	return {"states": states.duplicate(true), "favours": favour_defs}


func apply_state(d: Dictionary) -> void:
	states = d.get("states", {}).duplicate(true)
	for id in d.get("favours", {}):
		defs[id] = d.favours[id]
