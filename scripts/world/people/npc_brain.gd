class_name NpcBrain
extends RefCounted
## What one person in the building wants to do next. Pure logic: RinkPeople
## asks it where to go and how to stand, moves the body there, and tells it
## when it has arrived. Needs (hunger, bladder, cold, boredom) climb at the
## person's archetype rates; the event, the ice and the canteen push them
## around; what happens to them is tallied for Attendance.settle.
##
## Everyone is here for a reason (Attendance): `reason.why` and `watch_for`,
## the person they came for. A parent watches their kid and waits in the
## lobby after until the kid comes out of the dressing room; then they leave
## together (RinkPeople tells the brain with `person_left()`).
##
## Two clocks: `think()` runs in building minutes (needs, activities);
## `fidget()` runs in real seconds and picks the small things a body does
## while it waits: phone, coffee, a stretch, a clap for their kid.

enum Pose { STAND, WALK, SIT, SKATE, SKATE_WOBBLY, SPIN, CHEER, CLAP, TALK, WAVE, QUEUE,
	CARRY, WORK, FALL, SIT_CLAP, SIT_CHEER, SIP, STRETCH, SIT_PHONE, SIT_SIP, LEAN }

## What the building is doing, set by RinkPeople: "before" (warm-up, people
## arriving), "on" (play), "break" (intermission, flood), "after" (go home).
const PHASES := ["before", "on", "break", "after"]
const DEFAULT_NEEDS := {"hunger": 0.45, "bladder": 0.5, "cold": 0.2, "boredom": 0.3}
const SEATED := [Pose.SIT, Pose.SIT_CLAP, Pose.SIT_CHEER, Pose.SIT_PHONE, Pose.SIT_SIP]
## Where a bored or restless person drifts to.
const WANDER := ["lobby", "hall", "vending", "glass", "pro_shop"]
## Activities a body can fidget through (it is standing or sitting still).
const STILL := ["watch", "wait_for", "wander", "vending", "drop_in", "lesson_wait", "wait", "work", "pregame"]
## Game nights: before the puck drops the crowd stands around the lobby
## (activity "pregame") and heads for the seats once play starts.
const PREGAME_KINDS := ["beer_league", "senior_hockey", "high_school", "tournament", "minor_hockey"]
## Sessions where whoever came for a skater watches from the glass.
const GLASS_KINDS := ["learn_to_skate", "figure_practice", "public_skate"]

var person: Person
var as_ := "watch"      # play, watch or work
var kind := ""          # event kind
var needs := {"hunger": 0.0, "bladder": 0.0, "cold": 0.0, "boredom": 0.0}
var rates := DEFAULT_NEEDS.duplicate()
var activity := "arrive"
var place := "entrance"  # where they're headed or standing (PEOPLE.md 7)
var pose := Pose.WALK
var arrived := false
var wait := 0.0          # minutes left at the current activity
var home := "stands"     # where they go back to: stands, glass, ice, a work place
## Why they came (Attendance): {"why", "for", "for_name", "group", "until", "negotiated"}.
var reason := {}
var watch_for := ""      # the person they came for, or ""
var their_left := false  # their person has gone home (RinkPeople)
var idle_pose := -1      # a fidget drawn instead of `pose`, or -1
var idle_left := 0.0     # real seconds the fidget lasts
var chat_with := ""      # person id they're chatting to (RinkPeople pairs them)
# tallies for the end of the night
var line_minutes := 0.0
var wet_minutes := 0.0
var cold_peak := 0.0
var left_early := ""
var mood_bits: Array = []  # [what, delta] worth remembering
var bark_topic := ""       # set when something is worth saying; RinkPeople clears it
var rng: RandomNumberGenerator
var _undressed := false


static func make(p: Person, as__: String, kind_: String, rng_: RandomNumberGenerator, archetype := {}, why := {}) -> NpcBrain:
	var b := NpcBrain.new()
	b.person = p
	b.as_ = as__
	b.kind = kind_
	b.rng = rng_
	b.reason = why
	b.watch_for = str(why.get("for", ""))
	var r: Dictionary = archetype.get("needs", {})
	for k in DEFAULT_NEEDS:
		b.rates[k] = float(r.get(k, DEFAULT_NEEDS[k]))
	for k in b.needs:
		b.needs[k] = rng_.randf() * 0.35
	b.idle_left = rng_.randf_range(1.0, 8.0)
	match as__:
		"play":
			b.home = "ice"
			b.place = "dressing_room" if kind_ != "public_skate" else "skate_rental"
			b.activity = "dress"
		"work":
			# RinkPeople puts them at their scheduled place
			b.activity = "work"
		_:
			var why_s := str(why.get("why", ""))
			match why_s:
				"drop_in":
					b.home = str(why.get("place", "lobby"))
					b.activity = "drop_in"
				"next_student":
					b.home = "glass"
					b.activity = "lesson_wait"
				"zamboni":
					b.home = "glass"
					b.activity = "watch"
				_:
					# some people never sit: the glass-leaners and the coffee coaches
					var stand := p.archetype in ["coffee_coach", "scout", "superfan"] or p.trait_value("chatter") > 0.8
					b.home = "glass" if stand and rng_.randf() < 0.6 else "stands"
					if kind_ in GLASS_KINDS and str(why.get("for", "")) != "":
						b.home = "glass"  # parents line the glass at lessons and practices
					b.activity = "watch"
			b.place = b.home
	return b


## Advance `minutes` of building time. `ctx`: {"phase", "ice_wet" (bool),
## "canteen_open" (bool), "line" (people queued), "air_c" (stand
## temperature), "goal" (true on the frame a goal is scored)}.
## Returns true when the brain wants to go somewhere new (read `place`).
func think(minutes: float, ctx: Dictionary) -> bool:
	var phase: String = ctx.get("phase", "on")
	var interest := person.interest(kind, "play" if as_ == "play" else "watch")
	needs.hunger += rates.hunger * minutes / 60.0
	needs.bladder += rates.bladder * minutes / 60.0
	# cold: the stands are about 6 C; parkas and blankets help, players are warm
	var warm := 0.4 if person.look.get("outfit", "") in ["parka", "coveralls"] or person.look.get("accessory", "") in ["blanket", "scarf", "toque", "thermos"] else 0.0
	var chill := clampf((14.0 - float(ctx.get("air_c", 7.0))) / 10.0, 0.0, 1.5)
	if as_ == "watch":
		needs.cold += rates.cold * chill * (1.0 - warm) * minutes / 60.0
		# you don't get bored watching your own kid
		var mine := 0.35 if watch_for != "" else 1.0
		needs.boredom += rates.boredom * (1.1 - interest) * mine * minutes / 60.0 * (0.4 if phase == "on" else 1.0)
	cold_peak = maxf(cold_peak, needs.cold)
	if ctx.get("goal", false) and as_ == "watch" and activity == "watch":
		cheer(0.3 + 0.6 * interest)
		needs.boredom = maxf(needs.boredom - 0.3, 0.0)
		if rng.randf() < 0.15:
			bark_topic = "goal"
	if wait > 0.0:
		wait -= minutes
		if activity == "queue":
			line_minutes += minutes
		if activity == "gate" and ctx.get("ice_wet", false):
			wet_minutes += minutes
		if wait > 0.0:
			return false
	return _next(phase, ctx)


func _next(phase: String, ctx: Dictionary) -> bool:
	if activity == "leave":
		return false
	match as_:
		"play":
			return _next_player(phase, ctx)
		"work":
			if phase == "after":
				return _go("leave", "entrance", Pose.WALK)
			return false
	if phase == "after":
		# people who came for somebody wait for them, then go home together
		if watch_for != "" and not their_left:
			if activity != "wait_for":
				if rng.randf() < 0.25:
					bark_topic = "waiting"
				return _go("wait_for", "lobby", Pose.WALK)
			wait = 1.0
			return false
		return _go("leave", "entrance", Pose.WALK)
	if activity == "drop_in":
		# a drop-in stays a while, then moves on
		if rng.randf() < 0.15:
			return _go("leave", "entrance", Pose.WALK)
		if rng.randf() < 0.35:
			return _go("wander", _wander_place(), Pose.WALK)
		wait = rng.randf_range(3.0, 8.0)
		return false
	# spectators
	if needs.cold > 1.0 and person.trait_value("patience") < 0.7 and watch_for == "":
		left_early = "too cold"
		mood_bits.append(["froze in the stands", -0.05])
		bark_topic = "cold"
		return _go("leave", "entrance", Pose.WALK)
	if needs.boredom > 1.2 and person.interest(kind, "watch") < 0.3 and watch_for == "":
		left_early = "bored"
		bark_topic = "bored"
		return _go("leave", "entrance", Pose.WALK)
	if activity == "queue" and arrived:
		# in line until served (RinkPeople serves the front), or fed up
		if line_minutes > 6.0 + 14.0 * person.trait_value("patience"):
			mood_bits.append(["gave up on the canteen line", -0.04])
			bark_topic = "long_line"
			needs.hunger = 0.5
			return _go("watch", home, Pose.WALK)
		wait = 0.5
		return false
	if not arrived and activity != "watch":
		return false  # still on the way there
	if activity in ["watch", "wander", "vending", "lesson_wait", "pregame"]:
		var urgent: bool = needs.bladder > 0.85 or (phase == "break" and needs.bladder > 0.5)
		if urgent:
			return _go("washroom", "washroom", Pose.WALK)
		if needs.hunger > 0.8 or (phase == "break" and needs.hunger > 0.45):
			if ctx.get("canteen_open", true):
				return _go("queue", "canteen", Pose.WALK)
			if needs.hunger > 0.9 and rng.randf() < 0.5:
				return _go("vending", "vending", Pose.WALK)
			if rng.randf() < 0.3:
				mood_bits.append(["the canteen was closed", -0.03])
				bark_topic = "hungry"
			needs.hunger = 0.5
		if needs.boredom > 0.9 and activity in ["watch", "lesson_wait"]:
			return _go("wander", _wander_place(), Pose.WALK)
		# the zamboni kid runs to the glass for every flood
		if str(reason.get("why", "")) == "zamboni" and phase == "break" and place != "glass":
			bark_topic = "zamboni"
			return _go("watch", "glass", Pose.WALK)
	if activity == "lesson_wait":
		return false
	if phase == "before" and kind in PREGAME_KINDS:
		if activity != "pregame":
			return _go("pregame", "lobby", Pose.WALK)
		wait = rng.randf_range(2.0, 6.0)
		return false
	if activity != "watch" or place != home:
		return _go("watch", home, Pose.WALK)
	return false


func _next_player(phase: String, ctx: Dictionary) -> bool:
	match activity:
		"dress":
			if phase == "after":
				return _go("leave", "entrance", Pose.WALK)
			if phase in ["on", "break"] or (phase == "before" and arrived):
				return _go("gate", "bench", Pose.WALK)
		"gate":
			if phase == "after":
				return _go("undress", place_to_change(), Pose.WALK)
			if ctx.get("ice_wet", false):
				if wet_minutes > 3.0 and bark_topic == "" and rng.randf() < 0.3:
					bark_topic = "wet_ice"
				wait = 1.0
				pose = Pose.QUEUE
				return false
			return _go("skate", "ice", _skate_pose())
		"skate":
			if phase == "after":
				return _go("undress", place_to_change(), Pose.WALK)
			if phase == "break":
				return _go("gate", "bench", Pose.WALK)
			# a lap somewhere else on the ice
			wait = rng.randf_range(0.2, 0.6)
			pose = _skate_pose()
			place = "ice"
			return true
		"undress":
			if _undressed:
				return _go("leave", "entrance", Pose.WALK)
	return false


## Where a player changes: the dressing rooms, or the lobby benches at a public skate.
func place_to_change() -> String:
	return "skate_rental" if kind in ["public_skate", "learn_to_skate"] else "dressing_room"


func _wander_place() -> String:
	if person.is_kid() and rng.randf() < 0.45:
		return "vending"
	return WANDER[rng.randi() % WANDER.size()]


func _skate_pose() -> int:
	if kind == "learn_to_skate" or (kind == "public_skate" and person.interest("public_skate", "play") < 0.4):
		return Pose.FALL if rng.randf() < 0.06 else Pose.SKATE_WOBBLY
	if kind in ["figure_practice", "figure_show"] and rng.randf() < 0.25:
		return Pose.SPIN
	return Pose.SKATE


func _go(act: String, where: String, walking: int) -> bool:
	activity = act
	place = where
	pose = walking
	arrived = false
	wait = 0.0
	idle_pose = -1
	chat_with = ""
	return true


## The body got where it was going: settle into the activity.
func arrive() -> void:
	arrived = true
	idle_pose = -1
	match activity:
		"watch", "lesson_wait":
			pose = Pose.SIT if place == "stands" else (Pose.LEAN if place == "glass" and rng.randf() < 0.5 else Pose.STAND)
			wait = rng.randf_range(2.0, 6.0)
		"wait_for", "drop_in", "wait", "pregame":
			pose = Pose.STAND
			wait = rng.randf_range(1.0, 4.0)
		"queue":
			pose = Pose.QUEUE
			wait = 0.5   # RinkPeople serves the queue; until then keep waiting
		"vending":
			pose = Pose.QUEUE
			wait = rng.randf_range(0.5, 1.2)
			needs.hunger = maxf(needs.hunger - 0.45, 0.0)
		"washroom":
			pose = Pose.STAND
			wait = rng.randf_range(2.0, 4.0)
			needs.bladder = 0.0
		"wander":
			pose = Pose.STAND
			wait = rng.randf_range(2.0, 5.0)
			needs.boredom = maxf(needs.boredom - 0.6, 0.0)
		"dress":
			pose = Pose.STAND
			wait = rng.randf_range(4.0, 9.0)
		"undress":
			pose = Pose.STAND
			wait = rng.randf_range(3.0, 8.0)
			_undressed = true
		"gate":
			pose = Pose.QUEUE
			wait = 0.5
		"skate":
			pose = _skate_pose()
			wait = rng.randf_range(0.2, 0.5)
		"work":
			pose = Pose.WORK
		"leave":
			pose = Pose.WALK


## Served at the canteen: fed, and back to their spot.
func served() -> void:
	needs.hunger = 0.0
	needs.cold = maxf(needs.cold - 0.3, 0.0)  # hot chocolate
	wait = 0.0
	if line_minutes > 8.0:
		bark_topic = "long_line"
	activity = "carry"
	_go("watch", home, Pose.CARRY)


func is_gone() -> bool:
	return activity == "leave" and arrived


## Their person went home (or never came out): leave now.
func person_left() -> void:
	their_left = true
	if as_ != "play" and activity != "leave":
		_go("leave", "entrance", Pose.WALK)


## Told to go home now (the session ended for them, an event let them go).
func send_home() -> void:
	if activity != "leave":
		_go("leave", "entrance", Pose.WALK)


# -------------------------------------------------------------- the small stuff

## Something happened on the ice. `what`: "goal", "fall" or "save";
## `mine`: it happened to the person they came for.
func react(what: String, mine: bool) -> void:
	if as_ != "watch" or not arrived:
		return
	match what:
		"goal":
			cheer(0.95 if mine else 0.5)
			if mine:
				bark_topic = "goal_mine"
		"fall":
			if mine:
				idle_pose = Pose.STAND if not _seated() else Pose.SIT_CHEER
				idle_left = 2.5
				bark_topic = "fall_mine"
			elif rng.randf() < 0.3:
				idle_pose = Pose.WAVE if not _seated() else Pose.SIT_CLAP
				idle_left = 1.5
		"save":
			if rng.randf() < 0.5:
				idle_pose = Pose.SIT_CLAP if _seated() else Pose.CLAP
				idle_left = 2.0


## A goal: on their feet, or clapping in the seat. `keen` 0..1.
func cheer(keen: float) -> void:
	var up := rng.randf() < keen
	if _seated():
		idle_pose = Pose.SIT_CHEER if up else Pose.SIT_CLAP
	else:
		idle_pose = Pose.CHEER if up else Pose.CLAP
	idle_left = rng.randf_range(2.0, 4.0)


func _seated() -> bool:
	return pose in SEATED


## Real seconds pass while they stand or sit still: pick the next small
## thing to do (phone, coffee, a stretch, a clap for their kid on the ice).
## `their_on_ice`: the person they came for is skating right now. Returns
## true when the drawn pose changed.
func fidget(dt: float, their_on_ice := false) -> bool:
	if not arrived or not activity in STILL:
		if idle_pose != -1:
			idle_pose = -1
			return true
		return false
	idle_left -= dt
	if idle_left > 0.0:
		return false
	var before := idle_pose
	idle_pose = _pick_fidget(their_on_ice)
	idle_left = rng.randf_range(3.0, 11.0) if idle_pose != -1 else rng.randf_range(4.0, 14.0)
	return idle_pose != before


func _pick_fidget(their_on_ice: bool) -> int:
	if chat_with != "":
		return Pose.TALK if not _seated() else Pose.SIT
	var coffee: bool = person.look.get("accessory", "") in ["coffee", "thermos"] or activity == "carry"
	var phoneish := 0.35 if person.age < 30 else (0.15 if person.age < 60 else 0.04)
	var r := rng.randf()
	if _seated():
		if their_on_ice and r < 0.18:
			if rng.randf() < 0.3:
				bark_topic = "encourage"
			return Pose.SIT_CLAP
		r = rng.randf()
		if coffee and r < 0.35:
			return Pose.SIT_SIP
		if r < 0.35 + phoneish:
			return Pose.SIT_PHONE
		return -1
	if activity == "work":
		return -1
	if their_on_ice and r < 0.2:
		if rng.randf() < 0.35:
			bark_topic = "encourage"
		return Pose.WAVE if rng.randf() < 0.4 else Pose.CLAP
	r = rng.randf()
	if coffee and r < 0.3:
		return Pose.SIP
	if r < 0.3 + phoneish:
		return Pose.QUEUE
	if r < 0.45 + phoneish and person.age < 70:
		return Pose.STRETCH
	if r < 0.6 + phoneish and pose != Pose.LEAN and place == "glass":
		return Pose.LEAN
	return -1


## The pose to draw now: the fidget if there is one.
func shown_pose() -> int:
	return idle_pose if idle_pose >= 0 else pose


## What they'll remember, for Attendance.settle's "extra".
func verdict() -> Array:
	if left_early == "too cold":
		return ["left early, frozen", -0.08]
	var worst: Array = []
	for b in mood_bits:
		if worst.is_empty() or float(b[1]) < float(worst[1]):
			worst = b
	return worst
