extends VenueRoom
## The front lobby at the -X end: front doors to the street, ticket booth,
## snack bar, trophy case, a viewing window onto the ice, doors to the rink
## walkway and stairs up to the mezzanine (the lobby roof), where the
## manager's office sits.

const X0 := -Venue.HALF_X + Venue.WALL_T  # inside face of the street wall
const X1 := -Venue.END_FRONT              # rink-side wall
const Z := Venue.ROOM_Z
const H := Venue.LOBBY_H
const STAIR_Z := [11.6, 13.7]
const STAIR_X := [-36.8, -44.5]  # bottom step to top step


func _ready() -> void:
	room_id = "lobby"
	display_name = "Lobby"
	bounds = AABB(Vector3(X0, 0, -Z), Vector3(X1 - X0, H, Z * 2))
	spawn = Vector3(X0 + 1.5, 0, 0)


func build(k: VenueKit) -> void:
	var t := Venue.WALL_T
	var brick: Color = k.by_age(Color("8e5a45"), Color("9c6650"), Wear.STEEL)
	var paint: Color = k.by_age(Wear.OLD_MINT, Wear.OLD_MINT, Wear.WHITE)
	# street wall (full height, it is the building's envelope here)
	var xs := -Venue.HALF_X + t * 0.5
	k.wall_z(xs, -Z, Z, 0, Venue.ROOF_Y, t, brick, [
		{"at": 0.0, "w": 2.6, "y0": 0.0, "y1": 2.5},
		{"at": -5.0, "w": 3.0, "y0": 1.0, "y1": 2.6}, {"at": 5.0, "w": 3.0, "y0": 1.0, "y1": 2.6},
	], 1.0)
	add_door(k, Vector3(xs, 0, 0), PI * 0.5, VenueDoor.Kind.DOUBLE, 2.6, 2.5, k.by_age(Color("5d4a36"), Color("6b737c"), home_primary().darkened(0.3)), "Front doors")
	for wz in [-5.0, 5.0]:
		k.glass(Vector3(xs - 0.03, 1.0, wz - 1.5), Vector3(xs + 0.03, 2.6, wz + 1.5))
	# rink-side wall: two doors and the viewing window
	var xi := X1 - 0.15
	k.wall_z(xi, -Z, Z, 0, H + 0.3, 0.3, paint, [
		{"at": -8.5, "w": 1.9, "y0": 0.0, "y1": 2.3}, {"at": 8.5, "w": 1.9, "y0": 0.0, "y1": 2.3},
		{"at": 0.0, "w": 10.0, "y0": 1.0, "y1": 3.0},
	], 0.6)
	k.glass(Vector3(xi - 0.03, 1.0, -5.0), Vector3(xi + 0.03, 3.0, 5.0))
	for dz in [-8.5, 8.5]:
		add_door(k, Vector3(xi, 0, dz), PI * 0.5, VenueDoor.Kind.DOUBLE, 1.9, 2.3, k.by_age(Color("6f6a5e"), Color("7a828c"), Color("2a2e36")), "Rink doors %s" % ("N" if dz < 0 else "S"))
	# side walls, with a door out to the south corner
	for s in [-1, 1]:
		var zw: float = s * (Z - 0.15)
		var openings := [{"at": -35.6, "w": 1.0, "y0": 0.0, "y1": 2.2}] if s > 0 else []
		k.wall_x(zw, X0, X1, 0, H + 0.3, 0.3, paint, openings, 0.6)
	add_door(k, Vector3(-35.6, 0, Z - 0.15), PI, VenueDoor.Kind.SWING, 0.95, 2.2, k.by_age(Color("6f6a5e"), Color("7a828c"), Color("2a2e36")), "Lobby side")
	# mezzanine floor (the lobby ceiling), open over the stairs
	var slab_col: Color = k.by_age(Color("7d786e"), Color("8b877e"), Color("5b5f66"))
	k.slab(Vector3(X0, H, -Z), Vector3(X1, H + 0.3, STAIR_Z[0]), slab_col)
	k.slab(Vector3(X0, H, STAIR_Z[0]), Vector3(STAIR_X[1], H + 0.3, Z), slab_col)
	k.slab(Vector3(STAIR_X[0], H, STAIR_Z[0]), Vector3(X1, H + 0.3, Z), slab_col)
	k.slab(Vector3(X0, H, -Z), Vector3(X1, H + 0.02, Z), k.by_age(Color("cfc9b6"), Color("d8d3c4"), Color("eceae4")), 1.0, 0.03, true, false)
	var steps := 25
	var run := (STAIR_X[0] - STAIR_X[1]) / steps
	k.stairs(Vector3(STAIR_X[0], 0, (STAIR_Z[0] + STAIR_Z[1]) * 0.5), Vector3(-1, 0, 0), STAIR_Z[1] - STAIR_Z[0], H + 0.3, steps, run, slab_col)
	k.block(Vector3(STAIR_X[1], H + 0.3, STAIR_Z[0] - 0.05), Vector3(STAIR_X[0], H + 1.3, STAIR_Z[0]), Color("6b6f76"), 0.5, 0.0)
	# mezzanine rail over the rink
	k.block(Vector3(X1 - 0.3, H + 0.3, -Z), Vector3(X1, H + 0.55, Z), slab_col, 1.0)
	k.glass(Vector3(X1 - 0.18, H + 0.55, -Z), Vector3(X1 - 0.12, H + 1.4, Z))
	_floor(k)
	_ticket_booth(k)
	_snack_bar(k)
	_trophies(k)
	_seating(k)
	_ceiling_lights(k)
	_signs(k)
	_first_hour(k)
	room_light(k, Vector3(-41.5, H - 0.4, -6.0), 7.5)
	room_light(k, Vector3(-41.5, H - 0.4, 6.0), 7.5)


func _floor(k: VenueKit) -> void:
	var a: Color = k.by_age(Wear.OLD_CREAM.darkened(0.12), Wear.OLD_CREAM, Color("9c9a94"))
	var b: Color = k.by_age(Wear.OLD_BROWN.lightened(0.1), Wear.OLD_BROWN.lightened(0.2), Color("8e8c86"))
	var tile := 0.6
	var nx := int((X1 - X0) / tile)
	var nz := int(Z * 2 / tile)
	for i in nx:
		for j in nz:
			var x := X0 + i * tile
			var z := -Z + j * tile
			var col := a if (i + j) % 2 == 0 else b
			if k.age == VenueRoom.Age.WORN and posmod(hash(Vector2i(i, j)), 11) == 0:
				col = col.darkened(0.3)  # cracked tile
			if k.age == VenueRoom.Age.RENOVATED:
				# polished floor with the club crest at the centre
				var d := Vector2(x + tile * 0.5 - (X0 + X1) * 0.5, z + tile * 0.5).length()
				col = a
				if d < 2.4:
					col = home_primary() if d > 1.5 or d < 0.7 else home_secondary()
			k.block(Vector3(x, 0, z), Vector3(x + tile, 0.015, z + tile), col, tile, 0.04, false)


func _ticket_booth(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("6b4f33"), Color("7a5c3c"), Color("2a2e36"))
	var bx := X0 + 2.8
	k.aged_block(Vector3(bx - 0.1, 0, -12.5), Vector3(bx + 0.1, 1.1, -9.0), wood, 0.4)
	k.glass(Vector3(bx - 0.03, 1.1, -12.5), Vector3(bx + 0.03, 2.4, -9.0))
	k.aged_block(Vector3(X0, 0, -9.1), Vector3(bx + 0.1, 2.4, -8.9), wood, 0.4)
	k.aged_block(Vector3(X0, 2.4, -12.6), Vector3(bx + 0.3, 2.6, -8.9), wood, 0.4)
	k.block(Vector3(bx + 0.1, 1.05, -12.2), Vector3(bx + 0.4, 1.12, -9.3), wood.lightened(0.15), 0.4)
	var s := VenueSign.make([["// TICKETS", VenueSign.CYAN], ["SKATE 4.00", VenueSign.CYAN, true]], 10, 2, 0.03)
	s.name = "TicketSign"
	s.dead = k.by_age(0.04, 0.0, 0.0)
	k.sign(s, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(bx + 0.32, 2.9, -10.75)))


func _snack_bar(k: VenueKit) -> void:
	# two kit counters facing the lobby, with a gap for staff at the end
	for cx in [-40.8, -38.3]:
		k.prop("concession_counter", Vector3(cx, 0, -11.25), PI)
	# back shelf, a coffee urn, a popcorn machine, a cooler
	k.aged_block(Vector3(-42.0, 0, -13.7), Vector3(-36.0, 0.95, -13.1), Color("6f6a5e"), 0.4)
	k.block(Vector3(-41.5, 0.95, -13.7), Vector3(-41.1, 1.45, -13.3), Color("b8bcc2"), 0.2, 0.03)
	k.block(Vector3(-39.8, 0.95, -13.75), Vector3(-39.0, 1.75, -13.25), Color("c8312f"), 0.25, 0.03)
	k.glass(Vector3(-39.75, 1.15, -13.25), Vector3(-39.05, 1.7, -13.22), false, Color(1.0, 0.92, 0.6, 0.35))
	k.block(Vector3(-37.4, 0, -13.7), Vector3(-36.2, 1.9, -13.1), Color("d9d9d6"), 0.3, 0.03)
	k.glow(Vector3(-37.3, 0.2, -13.09), Vector3(-36.3, 1.8, -13.08), k.by_age(Color("7a8a7a"), Color("cfe8ff"), Color("e8f6ff")))
	var menu := VenueSign.make([
		["// SNACK BAR", VenueSign.AMBER], ["----", VenueSign.DIM],
		["HOT DOG   3.50", VenueSign.CYAN, true], ["POPCORN   2.00", VenueSign.CYAN, true], ["COFFEE    1.25", VenueSign.CYAN, true],
	], 14, 5, 0.03)
	menu.name = "SnackMenu"
	menu.dead = k.by_age(0.05, 0.01, 0.0)
	k.sign(menu, Transform3D(Basis.IDENTITY, Vector3(-39.0, 2.7, -13.68)))


func _trophies(k: VenueKit) -> void:
	var x0 := -42.6
	var x1 := -39.4
	k.aged_block(Vector3(x0, 0, 6.0), Vector3(x1, 0.9, 6.8), k.by_age(Color("5c4330"), Color("6b4f38"), Color("23262c")), 0.4)
	k.glass(Vector3(x0, 0.9, 6.0), Vector3(x1, 2.0, 6.8))
	k.block(Vector3(x0, 2.0, 6.0), Vector3(x1, 2.08, 6.8), Color("3a3d44"), 0.4, 0.0)
	var gold := Color("d4a83a")
	for i in 5:
		var tx := x0 + 0.35 + i * 0.62
		var h := 0.35 + 0.18 * (i % 3)
		k.block(Vector3(tx - 0.08, 0.9, 6.3), Vector3(tx + 0.08, 0.98, 6.5), Color("3b2a1e"), 0.2, 0.0, false)
		k.block(Vector3(tx - 0.04, 0.98, 6.36), Vector3(tx + 0.04, 0.98 + h, 6.44), gold.darkened(0.25 if k.age == VenueRoom.Age.WORN else 0.0), 0.2, 0.05, false)
		k.block(Vector3(tx - 0.1, 0.98 + h, 6.3), Vector3(tx + 0.1, 1.12 + h, 6.5), gold.darkened(0.25 if k.age == VenueRoom.Age.WORN else 0.0), 0.2, 0.05, false)
	if k.age == VenueRoom.Age.RENOVATED:
		k.glow(Vector3(x0 + 0.05, 1.98, 6.05), Vector3(x1 - 0.05, 2.0, 6.75), Color("fff2d6"))


func _seating(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), Color("2a2e36"))
	for z in [-2.5, 2.5]:
		k.aged_block(Vector3(-40.0, 0, z - 0.25), Vector3(-37.0, 0.45, z + 0.25), wood, 0.5)
	# vending machines by the rink doors, bins by the doors
	for i in 2:
		k.prop("vending_machine", Vector3(-34.72, 0, 11.45 + i * 1.0), PI * 0.5)
	k.prop("trash_can", Vector3(-44.9, 0, 2.2), PI * 0.5)
	k.prop("trash_can", Vector3(-34.75, 0, -6.6), -PI * 0.5)


func _ceiling_lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("e6f0d8"), Color("f4f6f0"), Color("fff6e6"))
	var i := 0
	for x in [-43.0, -39.5, -36.0]:
		for z in [-10.0, -5.0, 0.0, 5.0, 10.0]:
			var c := lit
			if k.age == VenueRoom.Age.WORN and i % 5 == 2:
				c = Color("4a4d48")  # dead tube
			k.glow(Vector3(x - 0.6, H - 0.06, z - 0.15), Vector3(x + 0.6, H - 0.01, z + 0.15), c)
			i += 1


func _signs(k: VenueKit) -> void:
	var name := rink_name()
	if k.age == VenueRoom.Age.RENOVATED:
		var outside := VenueSign.make([["// " + name, VenueSign.CYAN]], name.length() + 3, 1, 0.07)
		outside.name = "StreetSign"
		k.sign(outside, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-Venue.HALF_X - 0.02, 4.2, 0)))
	else:
		# the old hand-painted board over the front doors (letters missing when worn)
		k.prop("rink_sign", Vector3(-Venue.HALF_X - 0.12, 2.65, 0), PI * 0.5, false)
	var over_ice := VenueSign.make([["// " + name, VenueSign.CYAN]], name.length() + 3, 1, 0.05)
	over_ice.name = "MezzanineSign"
	over_ice.dead = k.by_age(0.06, 0.01, 0.0)
	k.sign(over_ice, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(X1 + 0.02, H + 0.15, 0)))
	var welcome := VenueSign.make([
		["// WELCOME TO", VenueSign.WHITE], [name, VenueSign.CYAN], ["PUBLIC SKATE SAT 2PM", VenueSign.CYAN, true],
	], maxi(20, name.length()), 3, 0.025)
	welcome.name = "WelcomeBoard"
	welcome.dead = k.by_age(0.04, 0.0, 0.0)
	k.sign(welcome, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(X1 - 0.31, 3.55, 0)))


## RINK_SIM 1.6: the mat outside the front doors with Gus's envelope under
## it (the keys), the ice lighting panel inside the doors, and the
## dedication plaque beside them.
func _first_hour(k: VenueKit) -> void:
	var xo := -Venue.HALF_X - 0.05
	k.block(Vector3(xo - 1.1, 0.0, -0.9), Vector3(xo - 0.1, 0.03, 0.9), k.by_age(Color("3b3a36"), Color("2f3236"), Color("1d1f24")), 0.3, 0.08, false)
	if k.age == Age.WORN:
		k.block(Vector3(xo - 0.75, 0.03, 0.15), Vector3(xo - 0.45, 0.035, 0.5), Color("e8e0c8"), 0.2, 0.02, false)  # the envelope's corner
	add_spot(k, VenueSpot.Kind.READ, "gus_envelope", Vector3(xo - 0.6, 0.1, 0.3), "Envelope under the mat",
		{"readable": "gus_envelope", "gives": "keys"}, 1.8)
	# the lighting panel: grey box, a column of breakers, one taped over
	var px := X0 + 0.02
	k.aged_block(Vector3(px, 1.0, -2.75), Vector3(px + 0.14, 1.9, -1.85), Color("7d8288"), 0.3)
	for i in 6:
		var y := 1.1 + i * 0.13
		k.block(Vector3(px + 0.14, y, -2.55), Vector3(px + 0.17, y + 0.06, -2.4), Color("1b1d22"), 0.1, 0.0, false)
		k.block(Vector3(px + 0.14, y, -2.25), Vector3(px + 0.17, y + 0.06, -2.1), Color("e0b020") if i == 2 else Color("1b1d22"), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.SWITCH, "ice_lights", Vector3(px + 0.15, 1.45, -2.3), "Ice lighting panel",
		{"system": "ice_lights", "note": "breaker_panel"}, 1.6)
	k.block(Vector3(px, 1.3, 1.7), Vector3(px + 0.04, 1.75, 2.3), Color("8a6a2a"), 0.2, 0.03, false)
	add_spot(k, VenueSpot.Kind.READ, "dedication_plaque", Vector3(px + 0.05, 1.5, 2.0), "Dedication plaque", {"readable": "dedication_plaque"}, 1.5)
