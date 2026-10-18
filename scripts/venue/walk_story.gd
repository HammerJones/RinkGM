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
##   {"job": {job, args, target, scene, room, note?}}
##   {"screen": id}
##   {"toast": text}

const START_DAY := 1        # RinkSim day 1 is a Monday
const START_MINUTE := 5 * 60
## Sim minutes per real second while walking: the first hour of play covers
## 05:00 to about 06:45, as in the 1.6 table.
const TIME_SCALE := 1.75 / 60.0
const LOCKED := ["Front doors"]
const NOTES_PATH := "res://data/venue/notes.json"
const READABLES_PATH := "res://data/world/readables.json"

var venue: Venue
var sim: RinkSim
## What the player has picked up or learned: "keys", "spark_plugs", "read:<id>".
var flags := {}
var _clock_acc := 0.0
var _texts := {}


static func start(venue_: Venue, sim_: RinkSim = null) -> WalkStory:
	var w := WalkStory.new()
	w.venue = venue_
	w.sim = sim_ if sim_ else RinkSim.create()
	w.sim.day = START_DAY
	w.sim.minute = START_MINUTE
	w._load_texts()
	venue_.set_ice_lights(false)
	return w


func _load_texts() -> void:
	for path in [READABLES_PATH, NOTES_PATH]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			for r in data:
				_texts[r.id] = r


## Real seconds walked: moves the sim clock on in its 15-minute steps and
## melts the snow pit while its heater runs.
func tick(dt: float) -> void:
	_clock_acc += dt * TIME_SCALE
	while _clock_acc >= RinkSim.STEP_MIN:
		_clock_acc -= RinkSim.STEP_MIN
		sim.advance(RinkSim.STEP_MIN)
		var bay = venue.rooms.get("zamboni_bay")
		if bay and bay.has_method("tick_pit"):
			bay.tick_pit(RinkSim.STEP_MIN)


func clock_text() -> String:
	return "%s %02d:%02d" % [RinkSim.DAY_NAMES[sim.weekday()].to_upper(), sim.minute / 60, sim.minute % 60]


func door_locked(d: VenueDoor) -> bool:
	return d.label in LOCKED and not flags.has("keys")


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
			var t := text(d.get("readable", d.get("note", s.id)))
			if gives == "keys":
				t["noticed"] = "You have the keys. Big one's the front."
			elif gives == "spark_plugs":
				t["noticed"] = "You take the four plugs, the gauge and the carb cleaner."
			return {"read": t} if not t.is_empty() else {"toast": s.label}
		VenueSpot.Kind.JOB:
			var need: String = d.get("needs", "")
			if need != "" and not flags.has(need):
				var t := text(d.get("note", ""))
				if not t.is_empty():
					t["noticed"] = "She cranks but won't fire. You'll need new plugs."
					return {"read": t}
				return {"toast": "You need %s first." % need.replace("_", " ")}
			var room := venue.room_at(s.global_position)
			return {"job": {"job": d.get("job", ""), "args": d.get("args", {}), "target": d.get("target", s.id), "scene": d.get("scene", ""),
				"room": room.room_id if room else "", "note": d.get("note", "")}}
		VenueSpot.Kind.SCREEN:
			return {"screen": d.get("screen", s.id)}
		VenueSpot.Kind.SWITCH:
			if d.get("system", "") == "ice_lights":
				venue.set_ice_lights(not venue.ice_lights_on())
				return {"toast": "ICE LIGHTS ON. THEY TAKE A FEW MINUTES." if venue.ice_lights_on() else "ICE LIGHTS OFF."}
		VenueSpot.Kind.USE:
			if s.id == "snow_pit":
				return _snow_pit()
	return {"toast": s.label}


func _snow_pit() -> Dictionary:
	var bay = venue.rooms.get("zamboni_bay")
	if bay == null:
		return {}
	if not bay.pit_heater:
		bay.pit_heater = true
		return {"toast": "PIT HEATER RESET. IT HUMS, THEN CLICKS ON. %d%% FULL." % roundi(bay.snow * 100.0)}
	return {"toast": "THE PIT IS %d%% FULL AND MELTING." % roundi(bay.snow * 100.0)}


## A mini game (or the quick way, when its scene isn't built yet) finished
## with `result` ({quality: 0..1, ...}): the sim does the job.
func finish_job(job: Dictionary, result: Dictionary) -> Dictionary:
	var args: Dictionary = job.get("args", {}).duplicate()
	args.merge(result, true)
	var r := sim.job(job.get("job", ""), args)
	if r.get("ok", false) and job.get("target", "") == "doris_plugs":
		flags["doris_running"] = true
	return r
