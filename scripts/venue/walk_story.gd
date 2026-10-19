class_name WalkStory
extends RefCounted
## The first hour at Millbrook (RINK_SIM.md 1.6) as the venue walk plays it:
## 05:00 on Monday in the dark parking lot, the front doors locked until the
## keys come out from under the mat, the ice lights off until someone finds
## the panel, Gus's notes on the doors, and the jobs that hand over to World
## and assets' mini games. The walk scene owns the input and the screens;
## this decides what pressing use on a spot means, and keeps the sim clock.
##
## use(spot) returns what the walk scene should do, one of:
##   {"read": {title, author, text, noticed}}
##   {"job": {job, args, target, scene, room, note, readable}}  (scene "" = instant)
##   {"screen": id}
##   {"toast": text}

const START_MINUTE := RinkSim.WAKE_MIN  # 05:00 on the M1 sim's day 0, a Monday
## Sim minutes per real second while walking: the first hour of play covers
## 05:00 to about 06:45, as in the 1.6 table.
const TIME_SCALE := 1.75 / 60.0
const LOCKED := ["Front doors"]
const NOTES_PATH := "res://data/venue/notes.json"
const READABLES_PATH := "res://data/world/readables.json"

var venue: Venue
var sim: RinkSim
## The owner career's rink when the walk runs inside one (CareerState.rink):
## its sim, and its clock, which stops for the owner's Tuesday game. `flags`
## are then saved with the career (career.world.walk).
var link: RinkLink
## Set when the career's clock stopped for the owner's game: the walk sends
## the player back to the hub to play it.
var game_due := false
## World's RinkLife when the walk has one: jobs go through it so side
## quests hear about them.
var life = null
## What the player has picked up or learned: "keys", "spark_plugs", "read:<id>".
var flags := {}
var _clock_acc := 0.0
var _texts := {}


## The walk's story. With no sim given it uses the owner career's rink when
## there is one (its day and minute are the career's save, so they stay), else
## a fresh M1 sim (05:00 on the first Monday, Doris won't start).
static func start(venue_: Venue, sim_: RinkSim = null, link_: RinkLink = null) -> WalkStory:
	var w := WalkStory.new()
	w.venue = venue_
	if sim_ == null and link_ == null:
		# looked up at runtime so --script tests without the autoloads compile
		var cs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CareerState")
		link_ = cs.rink if cs else null
	w.link = link_
	w.sim = link_.sim if link_ else (sim_ if sim_ else RinkSim.create_m1())
	if link_:
		if not link_.career.world.has("walk"):
			link_.career.world["walk"] = {}
		w.flags = link_.career.world.walk
	# past the first morning Gus has handed the keys over in person
	if not (w.sim.day == 0 and w.sim.minute <= START_MINUTE):
		w.flags["keys"] = true
	w._load_texts()
	w._show_sim()
	return w


## The building as the sim has it: the ice lights' switch and the snow pit.
## (The lamps' warm-up glow stays the venue's, a few seconds long, since the
## sim warms them in quarter-hour steps.)
func _show_sim() -> void:
	if venue.ice_lights_on() != sim.lights_on:
		venue.set_ice_lights(sim.lights_on)
	var bay = venue.rooms.get("zamboni_bay")
	if bay:
		bay.set_snow(sim.snow_pit)


func _load_texts() -> void:
	for path in [READABLES_PATH, NOTES_PATH]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			for r in data:
				_texts[r.id] = r


## Real seconds walked: moves the sim clock on in its 15-minute steps (the
## career's clock when there is one, stopping for the owner's game).
func tick(dt: float) -> void:
	if game_due:
		return
	_clock_acc += dt * TIME_SCALE
	while _clock_acc >= RinkSim.STEP_MIN:
		_clock_acc -= RinkSim.STEP_MIN
		if link:
			game_due = link.advance(RinkSim.STEP_MIN)
		else:
			sim.advance(RinkSim.STEP_MIN)
		_show_sim()
		if game_due:
			return


## The first hour's set-up (dark lot, locked front doors) holds until the
## keys are found.
func first_hour() -> bool:
	return not flags.has("keys")


func clock_text() -> String:
	return "%s %02d:%02d" % [RinkSim.DAY_NAMES[sim.weekday()].to_upper(), sim.minute / 60, sim.minute % 60]


func door_locked(d: VenueDoor) -> bool:
	return d.label in LOCKED and not flags.has("keys")


## A spot's text: its readable (data/world), else its venue note, else {}.
func spot_text(d: Dictionary, fallback := "") -> Dictionary:
	for id in [d.get("readable", ""), d.get("note", ""), fallback]:
		var t := text(id)
		if not t.is_empty():
			return t
	return {}


## The text for a readable or note id, or {}.
func text(id: String) -> Dictionary:
	var r: Dictionary = _texts.get(id, {})
	if r.is_empty():
		return {}
	return {"title": r.get("title", id), "author": r.get("author", ""), "text": r.get("text", r.get("excerpt", "")), "noticed": r.get("noticed", "")}


func use(s: VenueSpot) -> Dictionary:
	var d := s.data
	var gives: String = d.get("gives", "")
	if gives != "":
		flags[gives] = true
	match s.kind:
		VenueSpot.Kind.READ:
			flags["read:" + s.id] = true
			var t := spot_text(d, s.id)
			if gives == "keys":
				t["noticed"] = "You have the keys. Big one's the front."
			elif gives == "spark_plugs":
				t["noticed"] = "You take the four plugs, the gauge and the carb cleaner."
			return {"read": t} if not t.is_empty() else {"toast": s.label}
		VenueSpot.Kind.JOB:
			var need: String = d.get("needs", "")
			if need != "" and not flags.has(need):
				var t := spot_text(d)
				if not t.is_empty():
					t["noticed"] = "She cranks but won't fire. You'll need new plugs."
					return {"read": t}
				return {"toast": "You need %s first." % need.replace("_", " ")}
			var room := venue.room_at(s.global_position)
			return {"job": {"job": d.get("job", ""), "args": d.get("args", {}), "target": d.get("target", s.id), "scene": d.get("scene", ""),
				"room": room.room_id if room else "", "note": d.get("note", ""), "readable": d.get("readable", "")}}
		VenueSpot.Kind.SCREEN:
			return {"screen": d.get("screen", s.id)}
		VenueSpot.Kind.SWITCH:
			if d.get("system", "") == "ice_lights":
				sim.set_lights(not sim.lights_on)
				_show_sim()
				return {"toast": "ICE LIGHTS ON. THEY TAKE A FEW MINUTES." if venue.ice_lights_on() else "ICE LIGHTS OFF."}
	return {"toast": s.label}



## A mini game (or the quick way, when its scene isn't built yet) finished
## with `result` ({quality: 0..1, ...}): the sim does the job.
func finish_job(job: Dictionary, result: Dictionary) -> Dictionary:
	var args: Dictionary = job.get("args", {}).duplicate()
	args.merge(result, true)
	var id: String = job.get("job", "")
	var r: Dictionary = life.job(id, args) if life else sim.job(id, args)
	_show_sim()
	if r.get("ok", false) and job.get("target", "") == "doris_plugs":
		flags["doris_running"] = true
	return r
