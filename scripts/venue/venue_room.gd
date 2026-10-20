class_name VenueRoom
extends Node3D
## One modular piece of the building (a stand, the lobby, a locker room...).
## Each room rebuilds itself for its renovation `age`, so the career's
## renovation story can swap a room from worn to repaired to renovated
## without touching the rest of the venue.
##
## Subclasses override build(kit). Everything a room makes (meshes,
## colliders, doors, signs) is rebuilt from scratch by rebuild(); the Venue
## calls it once it has set the club colours.

enum Age { WORN, REPAIRED, RENOVATED }

const AGE_NAMES := ["worn", "repaired", "renovated"]

## Stable id used by saves and the renovation system ("lobby", "stands_bench"...).
var room_id := ""
var display_name := ""
var age := Age.WORN
## Hung from the roof (roof, lights, scoreboard). Hidden while the camera is
## above the roof line (the isometric view), so they never block the ice.
var overhead := false
## Floor area of the room in venue space, for "which room am I in".
var bounds := AABB()
## Where a walker enters the room, in venue space.
var spawn := Vector3.ZERO
var doors: Array[VenueDoor] = []
## Things a walker can read, work on or use here (VenueSpot), rebuilt with
## the room like its doors.
var spots: Array[VenueSpot] = []
## "" for the arena itself; "rec" for the recreation centre wing, which is
## only built when someone can walk to it (Venue.instantiate_for's `wings`).
var wing := ""
## Set by the venue: colours of the home club, the rink name.
var venue: Node3D

var _built := false


func set_age(a: int) -> void:
	a = clampi(a, Age.WORN, Age.RENOVATED)
	if a == age and _built:
		return
	age = a
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	doors.clear()
	spots.clear()
	var kit := VenueKit.new(hash(room_id), age)
	build(kit)
	kit.commit(self)
	_built = true


## Override: add this room's blocks, colliders, doors and signs to `kit`.
func build(_kit: VenueKit) -> void:
	pass


## Called by the venue for overhead rooms when the camera goes above the
## roof (true) or comes back under it (false).
func set_overhead_hidden(hidden: bool) -> void:
	visible = not hidden


## Helper for subclasses: a door placed at `pos` (bottom centre of the
## opening) in a wall running along X (rot 0) or Z (rot PI/2).
func add_door(kit: VenueKit, pos: Vector3, rot_y: float, kind: int, w: float, h: float, col: Color, label := "") -> VenueDoor:
	var d := VenueDoor.make(kind, w, h, col, label)
	d.name = "Door_%s" % (label.replace(" ", "_") if label != "" else str(doors.size()))
	d.position = pos
	d.rotation.y = rot_y
	doors.append(d)
	kit.add(d)
	return d


## Helper for subclasses: a VenueSpot at `pos` (venue space; the point the
## walker looks at). See VenueSpot for kinds and data.
## Named places people go in this room, in venue space: {"canteen": [Vector3,
## ...]} (World's RinkPeople). Venue.places() adds each room's spawn under its
## own key, so rooms only list what that doesn't cover.
func places() -> Dictionary:
	return {}


func add_spot(kit: VenueKit, kind: int, id: String, pos: Vector3, label: String, data := {}, reach := 1.6) -> VenueSpot:
	var s := VenueSpot.make(kind, id, label, data, reach)
	s.position = pos
	spots.append(s)
	kit.add(s)
	return s


## A shadowless ceiling light for an interior room (worn rooms are dimmer
## and greener). Range is kept inside the room so it doesn't leak.
func room_light(kit: VenueKit, pos: Vector3, reach: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.light_energy = kit.by_age(0.55, 0.8, 1.0)
	l.light_color = kit.by_age(Color("e6eed8"), Color("f6f3ea"), Color("fff4e2"))
	Look.fixture(l)
	# on HIGH the nearest room lights cast soft shadows (they fade out with
	# distance, so only the room you're in pays for them)
	l.shadow_enabled = Look.at_least(Look.Quality.HIGH)
	kit.add(l)


func home_primary() -> Color:
	return venue.get("primary") if venue else Color("c8191e")


func home_secondary() -> Color:
	return venue.get("secondary") if venue else Color("ece7dc")


func rink_name() -> String:
	return venue.get("rink_name") if venue else "COMMUNITY RINK"
