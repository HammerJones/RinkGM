class_name Person
extends RefCounted
## Somebody. The same record for the named cast (data/world/cast.json) and the
## generated townsfolk (Townsfolk), so anyone can be promoted to a quest giver.
## The record is fixed; mood, memories and changed relationships are the
## state a save keeps. See docs/world/PEOPLE.md.

const TRAITS := ["warmth", "chatter", "patience", "pride", "nerve", "humour"]
## How far a bad night travels: memories older than this fade from mood.
const MEMORY_DAYS := 28
const MEMORY_MAX := 8

var id := ""
var name := ""
var known_as := ""
var age := 30
var pronouns := "they/them"
var town := "millbrook"
var role := "customer"     # staff, regular, customer, visitor, family
var archetype := ""
var look := {}
var traits := {}           # trait -> 0..1
var interests := {}        # event kind -> {"watch": 0..1, "play": 0..1}
var schedule: Array = []   # [{"days", "from", "to", "place", "doing"}]
var rel := {}              # person id (or "owner") -> -100..100
var family: Array = []     # ids of relatives
var dialogue := ""
## Lines of their own by topic ("idle", "bad_ice"...), dealt by StaffRoster
## so no two staff share one; empty for everyone else.
var lines := {}
var quests: Array = []
var likes: Array = []
var dislikes: Array = []
var voice := ""
var bio := ""
var generated := false
## Work: "job" is what the cast record says ("Owner, Bev's Edge & Tape");
## generated people get one from data/world/jobs.json (Townsfolk). `work`:
## {"title", "employer", "days", "from", "to", "flex" (0..1, how easily they
## swap a shift), "boss"}; empty for kids at school, retirees and anyone
## whose job the record doesn't say.
var job := ""
var work := {}
var home := ""
var commute := "car"       # car, foot, ride (a lift from family) or bike
## A short life story: the cast's bio, or assembled for townsfolk.
var backstory := ""
## How they're related to the people in `family`: id -> "partner", "child",
## "parent", "sibling", "grandparent", "grandchild".
var kin := {}
var friends: Array = []    # ids of friends (teammates, classmates)

# state
var mood := 0.7            # how they feel about the rink, 0..1
var memory: Array = []     # [{"day", "what", "delta"}], newest last
var visits := 0
var last_visit := -1


static func from_record(d: Dictionary, generated_ := false) -> Person:
	var p := Person.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", p.id))
	p.known_as = str(d.get("known_as", p.name.get_slice(" ", 0)))
	p.age = int(d.get("age", 30))
	p.pronouns = str(d.get("pronouns", "they/them"))
	p.town = str(d.get("town", "millbrook"))
	p.role = str(d.get("role", "customer"))
	p.archetype = str(d.get("archetype", ""))
	p.look = d.get("look", {})
	p.traits = d.get("traits", {})
	p.interests = d.get("interests", {})
	p.schedule = []
	for e in d.get("schedule", []):
		var e2: Dictionary = e.duplicate()
		e2.days = int_days(e.get("days", []))
		p.schedule.append(e2)
	p.rel = d.get("rel", {}).duplicate()
	p.family = d.get("family", [])
	p.dialogue = str(d.get("dialogue", ""))
	p.quests = d.get("quests", [])
	p.likes = d.get("likes", [])
	p.dislikes = d.get("dislikes", [])
	p.voice = str(d.get("voice", ""))
	p.bio = str(d.get("bio", ""))
	p.generated = generated_
	p.job = str(d.get("job", ""))
	p.home = str(d.get("home", ""))
	p.work = d.get("work", {}).duplicate()
	if p.work.has("days"):
		p.work.days = int_days(p.work.days)
	p.commute = str(d.get("commute", "ride" if p.age < 16 else "car"))
	p.backstory = str(d.get("backstory", p.bio))
	p.kin = d.get("kin", {}).duplicate()
	p.friends = d.get("friends", []).duplicate()
	if p.work.is_empty() and p.job != "":
		p.work = _work_from_schedule(p)
	return p


## Weekdays as ints: JSON hands them over as floats, and `3 in [3.0]` is
## false in GDScript, so a schedule read straight from data never matched.
static func int_days(days: Array) -> Array:
	var out: Array = []
	for d in days:
		out.append(int(d))
	return out


## A named person's working hours, from the schedule blocks marked "work".
static func _work_from_schedule(p: Person) -> Dictionary:
	for e in p.schedule:
		if str(e.get("doing", "")) == "work":
			var parts := p.job.split(",", false, 1)
			return {"title": p.job, "employer": parts[1].strip_edges() if parts.size() > 1 else "",
				"days": e.get("days", []), "from": float(e.get("from", 9.0)), "to": float(e.get("to", 17.0)),
				"place": str(e.get("place", "away")), "flex": 0.5, "boss": ""}
	return {}


## How `other` is related to them ("partner", "child"...), or "".
func kin_of(other: String) -> String:
	return str(kin.get(other, ""))


## Their work blocks the rink can't have: away from the rink, on the clock.
## Kids' school counts too (they don't negotiate it).
func busy_with(weekday: int, hour: float) -> Dictionary:
	var e := entry_at(weekday, hour)
	if e.is_empty() or str(e.get("place", "away")) != "away":
		return {}
	return e


## True when what keeps them away is a job they could ask to swap.
func job_block(weekday: int, hour: float) -> bool:
	var e := busy_with(weekday, hour)
	if e.is_empty():
		return false
	var doing := str(e.get("doing", ""))
	return doing in ["work", "night shift", "afternoon shift", "day job", "the shop", "school or work"] and not is_kid()


func trait_value(key: String) -> float:
	return float(traits.get(key, 0.5))


## How much they want to watch or play (`mode`) an event `kind`, 0..1.
func interest(kind: String, mode := "watch") -> float:
	var i: Dictionary = interests.get(kind, {})
	return float(i.get(mode, 0.0))


## Their favourite kinds to watch or play, best first.
func favourites(mode := "watch", n := 3) -> Array:
	var ks := interests.keys().filter(func(k): return interest(k, mode) > 0.0)
	ks.sort_custom(func(a, b): return interest(a, mode) > interest(b, mode))
	return ks.slice(0, n)


func is_kid() -> bool:
	return age < 18


## The schedule entry for `weekday` (0 = Sunday) at `hour`, or {} when free.
func entry_at(weekday: int, hour: float) -> Dictionary:
	for e in schedule:
		if weekday in e.get("days", []) and hour >= float(e.get("from", 0.0)) and hour < float(e.get("to", 0.0)):
			return e
	return {}


## Free to come to the rink: nothing scheduled, or what's scheduled is at the
## rink anyway. Nobody comes after their bedtime.
func is_free(weekday: int, hour: float) -> bool:
	if hour >= _bedtime() or hour < 6.0:
		return false
	var e := entry_at(weekday, hour)
	if e.is_empty():
		return true
	return str(e.get("place", "away")) != "away" and str(e.get("doing", "")) != "work"


## Working at the rink right now (staff shifts, volunteers).
func on_shift(weekday: int, hour: float) -> bool:
	var e := entry_at(weekday, hour)
	return not e.is_empty() and str(e.get("place", "away")) != "away" and str(e.get("doing", "")) == "work"


func place_at(weekday: int, hour: float) -> String:
	return str(entry_at(weekday, hour).get("place", "away"))


func _bedtime() -> float:
	if age < 6:
		return 19.5
	if age < 12:
		return 21.0
	if age < 16:
		return 22.5
	if age >= 75:
		return 22.0
	return 24.5


func relation(other: String) -> int:
	return int(rel.get(other, 0))


func change_rel(other: String, delta: int) -> void:
	rel[other] = clampi(relation(other) + delta, -100, 100)


## Something happened to them at the rink. Mood moves by `delta` (scaled by
## pride for bad things), and they remember it for a few weeks.
func remember(day: int, what: String, delta: float) -> void:
	if delta < 0.0:
		delta *= 0.7 + 0.6 * trait_value("pride")
	mood = clampf(mood + delta, 0.0, 1.0)
	memory.append({"day": day, "what": what, "delta": delta})
	if memory.size() > MEMORY_MAX:
		memory.pop_front()


## Bad memories fade; call once a day. Mood drifts back toward neutral.
func fade(day: int) -> void:
	memory = memory.filter(func(m): return day - int(m.day) <= MEMORY_DAYS)
	mood = lerpf(mood, 0.7, 0.03)


## The thing they'd mention if asked how the rink is treating them.
func grudge() -> String:
	var worst := {}
	for m in memory:
		if float(m.delta) < 0.0 and (worst.is_empty() or float(m.delta) < float(worst.delta)):
			worst = m
	return str(worst.get("what", ""))


func state() -> Dictionary:
	return {"mood": mood, "memory": memory, "visits": visits, "last_visit": last_visit, "rel": rel}


func apply_state(d: Dictionary) -> void:
	mood = float(d.get("mood", mood))
	memory = d.get("memory", [])
	visits = int(d.get("visits", 0))
	last_visit = int(d.get("last_visit", -1))
	rel = d.get("rel", rel)
