extends RecRoom
## The recreation centre's front lobby: the main entrance off the parking
## lot, the front desk where you pay for a drop-in or pick up a key, the
## Athletic Club's trophy case and wall of fame, and the doors to the offices,
## the main hall and (through the old fire exit) the arena.


func windows(along: String, line: float) -> Array:
	if along == "z" and absf(line - RecPlan.X_W) < 0.05:
		return [{"at": -41.5, "w": 3.0, "y0": 1.2, "y1": 2.6}, {"at": -33.0, "w": 3.0, "y0": 1.2, "y1": 2.6}]
	return []


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("a49a86"), Color("b3ab98"), Color("8f9296"))


func furnish(k: VenueKit) -> void:
	# terrazzo flecks and an entrance mat
	for i in 70:
		var x := x0 + 0.4 + posmod(hash(Vector2i(i, 1)), 1300) / 100.0
		var z := z0 + 0.4 + posmod(hash(Vector2i(i, 2)), 1300) / 100.0
		var c: Color = [Color("6e665a"), Color("d8d0bf"), Wear.OLD_ORANGE.darkened(0.2)][i % 3]
		k.block(Vector3(x, 0, z), Vector3(x + 0.12, 0.005, z + 0.12), c, 0.2, 0.0, false)
	k.block(Vector3(x0 + 0.3, 0, -38.6), Vector3(x0 + 2.2, 0.015, -35.4), Color("2c2d31"), 0.5, 0.04, false)
	# wainscot: 70s wood panel to 1.2 m on the outside wall
	var panel: Color = k.by_age(Wear.OLD_WOOD_DARK, Wear.OLD_WOOD, Color("d8d4cb"))
	k.aged_block(Vector3(x0 + 0.3, 0, z0 + 0.15), Vector3(x0 + 0.33, 1.2, -38.4), panel, 0.6, 0.05, false)
	k.aged_block(Vector3(x0 + 0.3, 0, -35.6), Vector3(x0 + 0.33, 1.2, z1), panel, 0.6, 0.05, false)
	_desk(k)
	_trophies(k)
	_wall_of_fame(k)
	# seating by the windows, a rack of programme flyers, a coat rack
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), Color("2a2e36"))
	bench(k, Vector3(x0 + 0.5, 0, -42.8), Vector3(x0 + 1.0, 0, -40.2), wood)
	bench(k, Vector3(x0 + 0.5, 0, -34.4), Vector3(x0 + 1.0, 0, -31.6), wood)
	k.aged_block(Vector3(-44.6, 0, -30.4), Vector3(-43.6, 1.5, -30.15), Color("7d8288"), 0.4)
	for i in 6:
		var c: Color = [Wear.OLD_ORANGE, Color("3f6fa8"), Wear.OLD_GOLD, Color("6a9a4a")][i % 4]
		k.block(Vector3(-44.5 + (i % 3) * 0.3, 0.5 + (i / 3) * 0.5, -30.45), Vector3(-44.3 + (i % 3) * 0.3, 0.8 + (i / 3) * 0.5, -30.4), c, 0.2, 0.04, false)
	k.prop("vending_machine", Vector3(-36.0, 0, -30.55), 0.0)
	k.prop("trash_can", Vector3(-37.2, 0, -30.4), 0.0)
	# a bank of kit lockers for drop-in players by the arena door
	k.prop("lockers", Vector3(-38.4, 0, -30.25), 0.0)
	_signs(k)
	RecDetail.lobby(self, k)  # World: detail pass (#23, #27)


## The front desk, an L facing the main doors, with the RINK-OS booking
## terminal and a key board behind it.
func _desk(k: VenueKit) -> void:
	var front: Color = k.by_age(Wear.OLD_ORANGE.darkened(0.15), Color("b46a3c"), Color("2a2e36"))
	var top: Color = k.by_age(Color("c9b48a"), Color("d6c39a"), Color("e8e6e1"))
	k.aged_block(Vector3(-38.0, 0, -41.0), Vector3(-37.4, 1.05, -36.0), front, 0.5)
	k.aged_block(Vector3(-37.4, 0, -36.6), Vector3(-34.6, 1.05, -36.0), front, 0.5)
	k.block(Vector3(-38.15, 1.05, -41.1), Vector3(-37.3, 1.1, -35.9), top, 0.5, 0.03, false)
	k.block(Vector3(-37.3, 1.05, -36.75), Vector3(-34.5, 1.1, -35.9), top, 0.5, 0.03, false)
	# the low desk behind, with the terminal
	k.aged_block(Vector3(-37.3, 0, -40.9), Vector3(-36.6, 0.75, -38.0), front.darkened(0.2), 0.4)
	var crt: Color = k.by_age(Color("c9c0a8"), Color("c9c0a8"), Color("1b1d22"))
	k.block(Vector3(-37.2, 0.75, -39.8), Vector3(-36.75, 1.2, -39.0), crt, 0.2, 0.03)
	var term := VenueSign.make([["// FRONT DESK", VenueSign.CYAN], ["> DROP-IN 2/5", VenueSign.GREEN, true], ["> _", VenueSign.WHITE]], 13, 3, 0.0075)
	term.name = "DeskTerminal"
	term.dead = k.by_age(0.02, 0.0, 0.0)
	k.sign(term, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-37.21, 1.0, -39.4)))
	# key board and a cork board on the back (hall-side) area
	k.aged_block(Vector3(-36.2, 0, -37.4), Vector3(-34.8, 1.9, -36.9), Color("7d8288"), 0.4)
	k.block(Vector3(-36.0, 0, -40.8), Vector3(-35.5, 0.48, -40.3), Color("2b2d33"), 0.25, 0.05)  # stool
	k.block(Vector3(-37.25, 1.1, -37.6), Vector3(-36.95, 1.22, -37.2), Color("2b2d33"), 0.15, 0.03, false)  # the bell
	# the lost and found clipboard and a pile of concussion pamphlets on the counter
	readable(k, "lost_found_clip", Vector3(-37.72, 1.1, -38.6), Vector3.UP, true, Vector3.RIGHT)
	readable(k, "moose_pamphlet", Vector3(-37.72, 1.1, -40.4), Vector3.UP, true, Vector3.RIGHT)
	# a bulkhead over the counter carries the desk sign
	k.aged_block(Vector3(-38.15, 2.4, -41.1), Vector3(-37.3, h, -35.9), paint(k), 0.6)


func _trophies(k: VenueKit) -> void:
	var xa := -42.7
	var xb := -39.7
	var zf := z0 + 0.35
	k.aged_block(Vector3(xa, 0, zf), Vector3(xb, 0.9, zf + 0.7), k.by_age(Color("5c4330"), Color("6b4f38"), Color("23262c")), 0.4)
	k.glass(Vector3(xa, 0.9, zf), Vector3(xb, 2.1, zf + 0.7))
	k.block(Vector3(xa, 2.1, zf), Vector3(xb, 2.18, zf + 0.7), Color("3a3d44"), 0.4, 0.0)
	var gold := Color("d4a83a").darkened(0.3 if k.age == Age.WORN else 0.0)
	for i in 6:
		var tx := xa + 0.3 + i * 0.48
		var th := 0.3 + 0.16 * (i % 3)
		k.block(Vector3(tx - 0.07, 0.9, zf + 0.3), Vector3(tx + 0.07, 0.97, zf + 0.45), Color("3b2a1e"), 0.2, 0.0, false)
		k.block(Vector3(tx - 0.03, 0.97, zf + 0.34), Vector3(tx + 0.03, 0.97 + th, zf + 0.41), gold, 0.2, 0.05, false)
		k.block(Vector3(tx - 0.08, 0.97 + th, zf + 0.3), Vector3(tx + 0.08, 1.1 + th, zf + 0.45), gold, 0.2, 0.05, false)
	wall_sign(k, [["// MILLBROOK ATHLETIC CLUB", Wear.OLD_GOLD]], 27, 1, 0.012, Vector3((xa + xb) * 0.5, 2.4, z0 + 0.15), Vector3(0, 0, 1), "ClubPlaque", Color("3b2a1e"))


## Framed team photos of the club's old teams: basketball, hockey, track.
func _wall_of_fame(k: VenueKit) -> void:
	for i in 8:
		var x := -38.2 + (i % 4) * 0.8
		var y := 1.3 + (i / 4) * 0.75
		var frame := Color("2b2d33") if k.age != Age.WORN else Color("5c4330")
		k.block(Vector3(x, y, z0 + 0.15), Vector3(x + 0.6, y + 0.5, z0 + 0.19), frame, 0.3, 0.0, false)
		var photo: Color = Color("b8a88a").lerp(Color("6a6458"), posmod(hash(i), 5) / 6.0)
		if k.age == Age.WORN:
			photo = photo.lerp(Color("c8b07a"), 0.35)  # sun-faded
		k.block(Vector3(x + 0.05, y + 0.05, z0 + 0.19), Vector3(x + 0.55, y + 0.45, z0 + 0.2), photo, 0.25, 0.06, false)


func _signs(k: VenueKit) -> void:
	var name := _centre_name()
	wall_sign(k, [["// " + name, VenueSign.CYAN], ["FRONT DESK  //  DROP-IN  //  KEYS", VenueSign.WHITE, true]],
		maxi(name.length() + 3, 34), 2, 0.022, Vector3(-38.15, 2.95, -38.5), Vector3(-1, 0, 0), "DeskSign")
	var hours := [
		["// HOURS", VenueSign.AMBER], ["MON-FRI  6AM-11PM", VenueSign.CYAN, true],
		["SAT-SUN  7AM-10PM", VenueSign.CYAN, true], ["GYM DROP-IN   $5", VenueSign.WHITE, true],
		["WEIGHT ROOM   $4", VenueSign.WHITE, true],
	]
	wall_sign(k, hours, 18, 5, 0.022, Vector3(-43.6, 2.1, -30.0), Vector3(0, 0, -1), "HoursBoard")
	wall_sign(k, [["// ARENA", VenueSign.CYAN], ["->", VenueSign.CYAN]], 9, 2, 0.03, Vector3(-40.0, 2.9, -30.05), Vector3(0, 0, -1), "ToArena")
	if k.age == Age.WORN:
		# the club's old painted letters, half gone, over the hall opening
		# World: on the east wall wherever RecPlan puts it (the pro shop grew)
		wall_sign(k, [["ATH ETIC C UB  EST 19 8", Color("8a7a5a")]], 23, 1, 0.025, Vector3(x1 - 0.15, 3.5, -42.0), Vector3(-1, 0, 0), "OldLetters", Color("c9b98f"))


func _centre_name() -> String:
	return RecPlan.centre_name(rink_name())
