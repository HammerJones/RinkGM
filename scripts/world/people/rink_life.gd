class_name RinkLife
extends RefCounted
## Ties the people to the rink sim. Every booking that goes on the ice gets
## its real crowd (Attendance), everyone who came remembers the night, and
## how they felt nudges the contract's satisfaction and the rink's name.
## Quests hear about sessions, jobs and visits from here. When the building
## is on screen, RinkPeople runs the night live and calls `settle` itself.
##
##   var life := RinkLife.create(sim, Cast.load_region(seed))
##   life.job("resurface")   # instead of sim.job, so quests hear about it

var sim: RinkSim
var world: StoryWorld
var live := false          # RinkPeople is running the building right now
var last_crowd: Array = [] # who came to the last session
var rng := RandomNumberGenerator.new()


static func create(sim_: RinkSim, cast: Cast, quests_data := {}) -> RinkLife:
	var l := RinkLife.new()
	l.sim = sim_
	l.world = StoryWorld.create(cast, sim_, quests_data)
	l.rng.seed = cast.seed * 7919 + 1
	sim_.session_started.connect(l._on_session)
	sim_.day_ended.connect(l._on_day)
	return l


func job(id: String, args := {}) -> Dictionary:
	var r := sim.job(id, args)
	if r.get("ok", false):
		world.quests.notify("job_done", {"job": id})
		world.quests.tick()
	return r


## The event kind and draw of a session from RinkSim.session_at.
func event_for(s: Dictionary) -> Dictionary:
	var kind := world.cast.kind_of_org(str(s.get("org", "")))
	return {"kind": kind, "use": s.get("use", "public"), "org": s.get("org", ""),
		"weekday": sim.weekday(), "hour": float(s.get("start", sim.minute / 60.0)), "hours": float(s.get("hours", 1.0)),
		"ice_rep": sim.ice_rep, "seats": 600}


func _on_session(s: Dictionary, rating: float, wetness: float) -> void:
	var ev := event_for(s)
	world.event_now = ev.kind
	if live:
		return
	last_crowd = Attendance.who_comes(world.cast, ev, rng)
	var how := {"day": sim.day, "kind": ev.kind, "rating": rating, "cancelled": rating < 0.0,
		"wet_wait": wetness * 30.0 if wetness > 0.25 else 0.0}
	settle(s, last_crowd, how)


## Everyone remembers the night; the mood moves the contract and the rink's
## name, and quests hear what happened.
func settle(s: Dictionary, came: Array, how: Dictionary) -> void:
	var d := Attendance.settle(came, how)
	var c: Dictionary = sim.contracts.get(str(s.get("org", "")), {})
	if not c.is_empty():
		c.satisfaction = clampf(float(c.satisfaction) + d * 20.0, 0.0, 100.0)
	sim.ice_rep = clampf(sim.ice_rep + d * 2.0, 0.0, 100.0)
	if how.get("cancelled", false):
		return
	world.quests.notify("event_held", {"event": how.kind, "rating": float(how.get("rating", 0.0))})
	world.quests.notify("rating_gte", {"use": s.get("use", ""), "rating": float(how.get("rating", 0.0))})
	for e in came:
		world.quests.notify("attend", {"person": e.person.id, "event": how.kind})


func _on_day(day: int) -> void:
	world.cast.daily_fade(day)
	world.event_now = ""
	world.quests.tick()


func state() -> Dictionary:
	return world.state()


func apply_state(d: Dictionary) -> void:
	world.apply_state(d)
