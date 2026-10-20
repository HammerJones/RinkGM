class_name RinkLife
extends RefCounted
## Ties the people to the rink sim. Every booking that goes on the ice gets
## its real crowd (Attendance), everyone who came remembers the night, and
## how they felt nudges the contract's satisfaction and the rink's name.
## Quests hear about sessions, jobs and visits from here.
##
## When the building is on screen, RinkPeople runs the night live: call
## `people.drive(life, rate)` and this books each session's crowd as its
## start comes up (people arrive on their own schedule, by car or on foot),
## brings staff in for their shifts and sends them home after, lets the
## drop-ins (rink rats after school, retirees with their coffee) wander in,
## moves every session through before / on / break / after, and settles the
## night when it ends.
##
##   var life := RinkLife.create(sim, Cast.load_region(seed))
##   life.job("resurface")   # instead of sim.job, so quests hear about it

## A session's crowd is booked this many sim minutes before it starts.
const LEAD_MIN := 50.0
## The flood between periods of a long hockey session, minutes after start.
const BREAK_AT := 55.0
const BREAK_MIN := 12.0
const BREAK_KINDS := ["beer_league", "minor_hockey", "high_school", "senior_hockey", "tournament", "broomball"]
## Drop-ins in the building at once, at most.
const DROP_INS_MAX := 30

## Something happened at the rink that quests and tutorials care about:
## ("job_done", {"job"}), ("session", {"kind", "phase", "org"}), ("talk", {"to"}).
signal happened(what: String, data: Dictionary)

var sim: RinkSim
var world: StoryWorld
var live := false          # RinkPeople is running the building right now
var last_crowd: Array = [] # who came to the last session
var rng := RandomNumberGenerator.new()
## Live sessions: key -> {"s", "ev", "start", "end", "came", "phase", "rating", "settled"}.
var sessions := {}

var _people: WeakRef
var _last_staff := -1
var _last_drop := -1
var _rating := {}          # session org -> rating at its start (session_started)


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
		happened.emit("job_done", {"job": id, "result": r})
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
	_rating[str(s.get("org", ""))] = [rating, wetness]
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


# ---------------------------------------------------------------------- live

## RinkPeople calls this when it starts driving (RinkPeople.drive).
func attach_live(people: RinkPeople) -> void:
	_people = weakref(people)
	live = true
	_last_staff = -1
	_last_drop = -1


func people() -> RinkPeople:
	return _people.get_ref() if _people else null


func _now() -> float:
	return float(sim.day * 1440 + sim.minute)


## Twice a second from RinkPeople: book upcoming sessions, move phases on,
## bring staff and drop-ins in, settle what's over.
func tick_live(p: RinkPeople) -> void:
	var now := _now()
	for d in [sim.day, sim.day + 1]:
		for s in sim.sessions(d):
			var start := float(d * 1440) + float(s.start) * 60.0
			var end := start + float(s.hours) * 60.0
			var key := "%d:%s:%d" % [d, s.org, int(float(s.start) * 60.0)]
			if sessions.has(key) or now < start - LEAD_MIN or now >= end - 5.0:
				continue
			_book(p, key, s, d, start, end, now)
	for key in sessions.keys():
		var r: Dictionary = sessions[key]
		var ph := _phase(r, now)
		if ph != r.phase:
			r.phase = ph
			p.session_phase[key] = ph
			if ph == "on":
				world.event_now = r.ev.kind
			happened.emit("session", {"kind": r.ev.kind, "phase": ph, "org": r.s.org, "key": key})
			if ph == "after" and not r.settled:
				_settle_live(p, key, r)
		# forget a session once its people have gone home
		if r.phase == "after" and now > r.end + 90.0:
			sessions.erase(key)
			p.session_phase.erase(key)
	var quarter := int(now) / 15
	if quarter != _last_staff:
		_last_staff = quarter
		_staff(p)
	var half := int(now) / 30
	if half != _last_drop:
		_last_drop = half
		_drop_ins(p)


func _phase(r: Dictionary, now: float) -> String:
	if now < r.start:
		return "before"
	if now >= r.end:
		return "after"
	if r.ev.kind in BREAK_KINDS and r.end - r.start >= 110.0 and now >= r.start + BREAK_AT and now < r.start + BREAK_AT + BREAK_MIN:
		return "break"
	return "on"


func _book(p: RinkPeople, key: String, s: Dictionary, d: int, start: float, end: float, now: float) -> void:
	var ev := event_for(s)
	ev.weekday = sim.weekday_of(d)
	ev.seats = p.map.seats.size() if p.map else 600
	var came := Attendance.who_comes(world.cast, ev, rng)
	var r := {"s": s, "ev": ev, "start": start, "end": end, "came": came, "phase": "", "settled": false}
	sessions[key] = r
	p.session_phase[key] = _phase(r, now)
	r.phase = p.session_phase[key]
	p.populate(came, false, key, ev.kind, start - now)


func _settle_live(p: RinkPeople, key: String, r: Dictionary) -> void:
	r.settled = true
	var rw: Array = _rating.get(str(r.s.org), [60.0, 0.0])
	var how := {"day": sim.day, "kind": r.ev.kind, "rating": float(rw[0]), "cancelled": float(rw[0]) < 0.0,
		"wet_wait": float(rw[1]) * 30.0 if float(rw[1]) > 0.25 else 0.0, "line_minutes": p.longest_line(), "extra": p.extras(key)}
	last_crowd = r.came
	settle(r.s, r.came, how)


## Staff on shift come in through the doors; staff whose shift is over go home.
func _staff(p: RinkPeople) -> void:
	var wd := sim.weekday()
	var hour := sim.minute / 60.0
	var want: Array = []
	for person: Person in world.cast.people.values():
		if person.on_shift(wd, hour):
			want.append(person)
	for person: Person in want:
		if p.agent_of(person.id) == null:
			p.populate([{"person": person, "as": "work", "arrive": 0.0,
				"reason": {"why": "work", "place": person.place_at(wd, hour), "until": Attendance._shift_end(person, wd, hour), "group": "solo:" + person.id}}],
				false, "", world.event_now, rng.randf_range(0.0, 8.0))
	for a: RinkPeople.Agent in p.agents:
		if a.brain.as_ == "work" and a.session == "" and not a.person in want and not p.is_claimed(a):
			a.brain.send_home()
			p._request_path(a)


## The building is never empty while it's open: a few people whose day has
## them at the rink anyway wander in, and go when their time's up.
func _drop_ins(p: RinkPeople) -> void:
	var wd := sim.weekday()
	var hour := sim.minute / 60.0
	for a: RinkPeople.Agent in p.agents:
		if str(a.reason.get("why", "")) == "drop_in" and hour >= float(a.reason.get("until", 24.0)) and not p.is_claimed(a):
			a.brain.send_home()
			p._request_path(a)
	if not sim.lights_on and sim.mode == "m1" and hour < 7.0:
		return  # 05:00 and the place is dark: nobody yet
	var here := p.agents.filter(func(a): return str(a.reason.get("why", "")) == "drop_in").size()
	if here >= DROP_INS_MAX:
		return
	var came := Attendance.drop_ins(world.cast, wd, hour, rng, 0.2)
	came = came.filter(func(e): return p.agent_of(e.person.id) == null)
	came.shuffle()
	if came.size() > DROP_INS_MAX - here:
		came.resize(DROP_INS_MAX - here)
	for e in came:
		e.arrive = rng.randf_range(-25.0, 0.0)
	p.populate(came, false, "", world.event_now, 0.0)


func state() -> Dictionary:
	return world.state()


func apply_state(d: Dictionary) -> void:
	world.apply_state(d)
