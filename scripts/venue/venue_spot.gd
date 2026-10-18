class_name VenueSpot
extends Node3D
## Something in the building a walker can look at and press use on: a note
## or book to read, a machine to work on, the office phone, a switch. Rooms
## place spots like doors (VenueRoom.add_spot), so they come back after a
## renovation rebuild. The walk scene finds the one in front of the player
## (VenueWalker.nearest_spot) and acts on it by kind; the building itself
## never decides what a job or a screen does.
##
## Kinds and their `data`:
##   READ    {"readable": id} from data/world/readables.json, or
##           {"note": id} from data/venue/notes.json (short notes on doors,
##           drums and dashboards). Optional "gives": a flag set on reading
##           (the envelope gives "keys").
##   JOB     {"job": RinkSim job id, "args": {...}, "scene": path to the mini
##           game under scenes/world/jobs/}. Optional "note" shown first.
##   SCREEN  {"screen": id} an office screen (log_book, phone, goals,
##           ice_grid, pnl), opened by UI's screens.
##   SWITCH  {"system": "arena_lights"} a building system the walker turns
##           on or off.
##   USE     anything else, handled by id (the snow pit).

enum Kind { READ, JOB, SCREEN, SWITCH, USE }

const KIND_VERBS := ["READ", "WORK ON", "USE", "SWITCH", "CHECK"]

var id := ""
var kind := Kind.READ
## What the prompt calls it: "Envelope under the mat".
var label := ""
var data := {}
## How close the walker has to be, in metres from the spot's position.
var reach := 1.6


static func make(kind_: int, id_: String, label_: String, data_ := {}, reach_ := 1.6) -> VenueSpot:
	var s := VenueSpot.new()
	s.kind = kind_
	s.id = id_
	s.label = label_
	s.data = data_
	s.reach = reach_
	s.name = "Spot_%s" % id_
	s.add_to_group("venue_spots")
	return s


## The prompt line: "[E] READ  ENVELOPE UNDER THE MAT".
func prompt() -> String:
	return "%s  %s" % [KIND_VERBS[kind], label.to_upper()]
