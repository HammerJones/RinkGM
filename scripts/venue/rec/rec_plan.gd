class_name RecPlan
extends RefCounted
## The recreation centre wing on the bench side (-Z) of the arena: what is
## left of the old Millbrook Athletic Club, built onto the rink in the 70s.
## One long main hall runs the length of the arena; rooms open off it on
## both sides. The arena's two north fire exits now open into the wing (the
## west one into the front lobby, the east one into a short link to the hall).
##
## Every room is a rectangle in venue space (x0, z0, x1, z1, metres, outer
## faces). Each room builds its own walls just inside its rectangle, so a
## shared wall is two 0.15 m skins. Doors are listed here once, on the edge
## line between two rooms, so both rooms cut the opening and only the owner
## hangs the door. The walk test, the floor plan tool and every RecRoom read
## this one table.
##
##   z -30 .. -40  south band (against the arena wall)
##   z -40 .. -44  the main hall
##   z -44 .. -60  north band (the big rooms)
##
## World (playtest #34): the pro shop grew 1.5 m west into the front lobby's
## empty east strip (lobby x1, hall x0 and the lobby-to-hall opening moved
## from -32 to -33.5 with it).

const Z_ARENA := -30.0
const Z_HALL_S := -40.0
const Z_HALL_N := -44.0
const Z_BACK := -60.0
const X_W := -46.0
const X_E := 46.0
const WALL := 0.15   # one skin of an interior wall
const OPEN := -1     # a door kind with no leaf: just an opening

## id: [display name, script, Rect (x0, z0, x1, z1), ceiling height, walls]
## walls "all" builds every edge but the arena's; "outer" only the building's
## outside edges (the hall and the link, whose sides belong to their rooms).
const ROOMS := {
	"rec_lobby": ["Front desk", "rec_lobby", [-46.0, -44.0, -33.5, -30.0], 4.0, "all"],
	"rec_hall": ["Main hall", "rec_hall", [-33.5, -44.0, 46.0, -40.0], 3.2, "outer"],
	"rec_link": ["Arena link", "rec_hall", [38.0, -40.0, 42.0, -30.0], 3.2, "outer"],
	"pro_shop": ["Pro shop", "pro_shop", [-33.5, -40.0, -20.0, -30.0], 3.4, "all"],
	"rec_washrooms": ["Washrooms", "rec_washrooms", [-20.0, -40.0, -13.0, -30.0], 3.0, "all"],
	"rec_officials": ["Referees and first aid", "rec_officials", [-13.0, -40.0, -6.0, -30.0], 3.0, "all"],
	"rec_storage": ["Storage closets", "rec_storage", [-6.0, -40.0, 0.0, -30.0], 3.0, "all"],
	"locker_3": ["Dressing room 3", "rec_locker", [0.0, -40.0, 8.0, -30.0], 3.2, "all"],
	"locker_4": ["Dressing room 4", "rec_locker", [8.0, -40.0, 16.0, -30.0], 3.2, "all"],
	"locker_5": ["Dressing room 5", "rec_locker", [16.0, -40.0, 24.0, -30.0], 3.2, "all"],
	"locker_6": ["Dressing room 6", "rec_locker", [24.0, -40.0, 32.0, -30.0], 3.2, "all"],
	"rec_electrical": ["Electrical room", "rec_utility", [32.0, -40.0, 38.0, -30.0], 3.2, "all"],
	"rec_boiler": ["Boiler room", "rec_utility", [42.0, -40.0, 46.0, -30.0], 3.2, "all"],
	"rec_offices": ["Offices", "rec_offices", [-46.0, -60.0, -32.0, -44.0], 3.0, "all"],
	"gym": ["Gymnasium", "gym", [-32.0, -60.0, 2.0, -44.0], 8.0, "all"],
	"weight_room": ["Weight room", "weight_room", [2.0, -60.0, 16.0, -44.0], 3.6, "all"],
	"community_room": ["Community hall", "community_room", [16.0, -60.0, 32.0, -44.0], 4.5, "all"],
	"workshop": ["Workshop and loading", "workshop", [32.0, -60.0, 46.0, -44.0], 5.0, "all"],
}

## [label, x, z, wall direction ("x" = the wall runs along X), width, height,
## VenueDoor.Kind or OPEN, owner room id]. Doors on the main hall's edges sit
## on the hall's edge lines (z -40 and -44).
const DOORS := [
	# front lobby
	["Main entrance", -46.0, -37.0, "z", 2.6, 2.5, VenueDoor.Kind.DOUBLE, "rec_lobby"],
	["Lobby to hall", -33.5, -42.0, "z", 3.6, 3.0, OPEN, ""],
	["Programs office", -43.5, -44.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_offices"],
	["Bookings office", -39.0, -44.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_offices"],
	["Director's office", -34.5, -44.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_offices"],
	["Meeting room", -39.0, -52.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_offices"],
	# south band, off the hall
	["Pro shop", -26.0, -40.0, "x", 1.8, 2.3, VenueDoor.Kind.DOUBLE, "pro_shop"],
	["Men's washroom", -18.5, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_washrooms"],
	["Women's washroom", -14.5, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_washrooms"],
	["Referees", -11.5, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_officials"],
	["First aid", -7.5, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_officials"],
	["Janitor", -4.75, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_storage"],
	["Equipment storage", -1.6, -40.0, "x", 1.8, 2.2, VenueDoor.Kind.DOUBLE, "rec_storage"],
	["Dressing room 3", 2.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "locker_3"],
	["Dressing room 4", 10.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "locker_4"],
	["Dressing room 5", 18.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "locker_5"],
	["Dressing room 6", 26.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "locker_6"],
	["Electrical room", 35.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_electrical"],
	["Link to hall", 40.0, -40.0, "x", 3.6, 3.0, OPEN, ""],
	["Boiler room", 44.0, -40.0, "x", 0.95, 2.2, VenueDoor.Kind.SWING, "rec_boiler"],
	# north band, off the hall
	["Gym west", -25.0, -44.0, "x", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "gym"],
	["Gym east", -5.0, -44.0, "x", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "gym"],
	["Weight room", 9.0, -44.0, "x", 1.8, 2.3, VenueDoor.Kind.DOUBLE, "weight_room"],
	["Community hall", 24.0, -44.0, "x", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "community_room"],
	["Workshop", 37.0, -44.0, "x", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "workshop"],
	# outside
	["Hall exit", 46.0, -42.0, "z", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "rec_hall"],
	["Gym exit", -14.0, -60.0, "x", 1.9, 2.3, VenueDoor.Kind.DOUBLE, "gym"],
	["Loading door", 46.0, -53.0, "z", 3.6, 3.4, VenueDoor.Kind.ROLLUP, "workshop"],
]


static func rect(id: String) -> Rect2:
	var r: Array = ROOMS[id][2]
	return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])


## Doors on one edge line of a wall: along "x" at z = `at`, or along "z" at
## x = `at`, between `s0` and `s1` on the other axis.
static func doors_on(along: String, at: float, s0: float, s1: float) -> Array:
	var out := []
	for d in DOORS:
		if d[3] != along:
			continue
		var line: float = d[2] if along == "x" else d[1]
		var pos: float = d[1] if along == "x" else d[2]
		if absf(line - at) < 0.05 and pos > minf(s0, s1) and pos < maxf(s0, s1):
			out.append(d)
	return out


## True for an edge on the building's outside.
static func is_outer(along: String, at: float) -> bool:
	return (along == "x" and absf(at - Z_BACK) < 0.05) or (along == "z" and (absf(at - X_W) < 0.05 or absf(at - X_E) < 0.05))


## "MILLBROOK REC CENTRE" from the venue's rink name.
static func centre_name(rink: String) -> String:
	for suffix in [" COMMUNITY RINK", " ARENA"]:
		if rink.ends_with(suffix):
			rink = rink.trim_suffix(suffix)
	return rink + " REC CENTRE"
