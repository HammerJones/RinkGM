extends "res://scripts/venue/venue_walk.gd"
## The venue walk with an event's crowd: pick an event and walk around among
## everyone who came for it. Talk to anyone. (The plain venue walk has the
## same people, run from the sim's own bookings; this one picks the event.)
##
##   godot --path . res://scenes/world/people_walk.tscn -- --event=figure_practice [--hour=6] [--weekday=2]
##
## Walk as in the venue walk; T / X talks to whoever is nearest, 1-9 or
## arrows and Enter pick what to say. `--event=` takes any kind from
## data/world/events.json; `--event-on=0` starts with play already on;
## `--shot=<png>` saves a screenshot after `--shot-after=` seconds (default
## 20) from `--people-cam=` (or `--venue-cam=`) and quits. See WalkPeople.


func _ready() -> void:
	WalkPeople.default_event = "public_skate"
	super._ready()
	# the venue walk attaches WalkPeople; without that hook, attach it here
	if get_node_or_null("WalkPeople") == null:
		WalkPeople.attach(self)
