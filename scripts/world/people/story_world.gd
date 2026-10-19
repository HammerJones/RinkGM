class_name StoryWorld
extends RefCounted
## The state dialogue and quests read and change: flags, the owner's
## inventory, quests, the cast and (when there is one) the rink sim. Holds the
## condition and effect vocabulary of PEOPLE.md 6 in one place, so dialogue
## trees and quests speak the same language.

var cast: Cast
var sim: RinkSim          # optional: rink conditions read 0 / false without it
var quests: QuestLog
var flags := {}
var items := {}           # item id -> count
var notes: Array = []     # lines for the day log
var owner_name := "the owner"
var path := ""            # "player", "coach" or "gm" once chosen
var rink_name := "Millbrook Memorial Arena"
var town := "Millbrook"
var event_now := ""       # event kind on the ice right now, or ""
var rng := RandomNumberGenerator.new()


static func create(cast_: Cast, sim_: RinkSim = null, quests_data := {}) -> StoryWorld:
	var w := StoryWorld.new()
	w.cast = cast_
	w.sim = sim_
	w.quests = QuestLog.create(w, quests_data)
	return w


func day() -> int:
	return sim.day if sim else int(flags.get("_day", 0))


func hour() -> float:
	return sim.minute / 60.0 if sim else float(flags.get("_hour", 12.0))


func weekday() -> int:
	return sim.weekday() if sim else posmod(day(), 7)


# ------------------------------------------------------------------ conditions

func check(conds: Array, speaker: Person = null) -> bool:
	for c in conds:
		if not _one(c, speaker):
			return false
	return true


func _one(c: Dictionary, sp: Person) -> bool:
	for k in c:
		var v = c[k]
		var ok := true
		match k:
			"flag": ok = flags.has(v)
			"not_flag": ok = not flags.has(v)
			"rel_gte": ok = _rel(v[0], sp) >= int(v[1])
			"rel_lt": ok = _rel(v[0], sp) < int(v[1])
			"quest": ok = quests.status(v[0]) == str(v[1])
			"step": ok = quests.status(v[0]) == "active" and quests.step_id(v[0]) == str(v[1])
			"ice_gte": ok = sim != null and sim.ice_rep >= float(v)
			"rooms_gte": ok = sim != null and sim.facility_score() >= float(v)
			"money_gte": ok = sim != null and sim.money >= float(v)
			"day_gte": ok = day() >= int(v)
			"weekday": ok = weekday() in (v if v is Array else [v])
			"hour_between": ok = hour() >= float(v[0]) and hour() < float(v[1])
			"event_now": ok = event_now == str(v)
			"contract": ok = sim != null and sim.contracts.has(v)
			"path": ok = path == str(v)
			"trait_gte": ok = sp != null and sp.trait_value(v[0]) >= float(v[1])
			"mood_lt": ok = sp != null and sp.mood < float(v)
			"chance": ok = rng.randf() < float(v)
			"item": ok = int(items.get(v[0] if v is Array else v, 0)) >= (int(v[1]) if v is Array else 1)
			_:
				push_warning("StoryWorld: unknown condition '%s'" % k)
		if not ok:
			return false
	return true


## How `who` feels about the owner ("self" is the speaker).
func _rel(who: String, sp: Person) -> int:
	var p: Person = cast.person(who) if who != "self" else sp
	return p.relation("owner") if p else 0


# --------------------------------------------------------------------- effects

func apply(effects: Array, speaker: Person = null) -> Dictionary:
	var out := {}
	for e in effects:
		for k in e:
			var v = e[k]
			match k:
				"set": flags[v] = true
				"clear": flags.erase(v)
				"rel":
					var p: Person = cast.person(v[0]) if str(v[0]) != "self" else speaker
					if p:
						p.change_rel("owner", int(v[1]))
				"mood":
					if speaker:
						speaker.mood = clampf(speaker.mood + float(v), 0.0, 1.0)
				"quest_start": quests.start(v)
				"quest_step": quests.advance_to(v[0], v[1])
				"quest_done": quests.complete(v)
				"quest_fail": quests.fail(v)
				"money":
					if sim:
						sim.book("people", float(v))
				"pay_dues":
					# the owner's Beer League dues, through the sim so the league
					# un-benches them; paying before Dale asks covers the year
					if sim and not sim.pay_dues():
						sim.book("league dues", -RinkSim.LEAGUE_DUES)
						sim.league.paid_through = sim.day + 365
				"item":
					var id := str(v[0]) if v is Array else str(v)
					var n := int(v[1]) if v is Array else 1
					items[id] = maxi(int(items.get(id, 0)) + n, 0)
					if items[id] == 0:
						items.erase(id)
				"rep":
					if sim:
						sim.ice_rep = clampf(sim.ice_rep + float(v), 0.0, 100.0)
				"note": note(str(v))
				"end": out.end = true
				_:
					push_warning("StoryWorld: unknown effect '%s'" % k)
	return out


func note(text: String) -> void:
	notes.append({"day": day(), "text": text})
	if sim:
		sim._note(text)


# ---------------------------------------------------------------------- text

## Fills the tokens of PEOPLE.md 6 in `s`, spoken by `sp`.
func fill(s: String, sp: Person = null) -> String:
	if not "{" in s:
		return s
	var kind_label := str(cast.kind_info(event_now).get("label", event_now.replace("_", " "))) if event_now != "" else "nothing much"
	var t := {
		"owner": owner_name, "rink": rink_name, "town": town, "event": kind_label,
		"weekday": RinkSim.DAY_NAMES[weekday()] if sim else ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday()],
		"time": "%d:%02d" % [int(hour()), int(fmod(hour(), 1.0) * 60.0)],
		"ice_word": ice_word(),
		"name": sp.name if sp else "", "known_as": sp.known_as if sp else "",
	}
	return s.format(t)


func ice_word() -> String:
	if sim == null:
		return "fine"
	if sim.ice.wetness() > 0.4:
		return "wet"
	var r := sim.ice_rep
	return "glass" if r >= 80.0 else ("good" if r >= 62.0 else ("fine" if r >= 45.0 else ("chewed up" if r >= 28.0 else "slush")))


# ---------------------------------------------------------------------- save

func state() -> Dictionary:
	return {"flags": flags, "items": items, "quests": quests.state(), "path": path, "owner": owner_name, "cast": cast.state()}


func apply_state(d: Dictionary) -> void:
	flags = d.get("flags", {})
	items = d.get("items", {})
	path = str(d.get("path", ""))
	owner_name = str(d.get("owner", owner_name))
	quests.apply_state(d.get("quests", {}))
	cast.apply_state(d.get("cast", {}))
