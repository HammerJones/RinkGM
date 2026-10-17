extends VenueRoom
## A dressing room at the +X end: stalls around the walls, a bench, the
## coach's whiteboard, a shower room at the back. Worn rooms have dented
## metal lockers and cracked tile; renovated ones have wood stalls with
## nameplate lights and the club crest on the carpet.

## -1 = home room (z -14..-5), 1 = visitors (z 5..14).
@export var side := -1

const X0 := Venue.END_FRONT
const X1 := Venue.HALF_X - Venue.WALL_T
const H := 3.6
const PITCH := 0.85


func _ready() -> void:
	room_id = "locker_home" if side < 0 else "locker_away"
	display_name = "Home dressing room" if side < 0 else "Visitors' dressing room"
	var za := side * 5.0
	var zb := side * Venue.ROOM_Z
	bounds = AABB(Vector3(X0, 0, minf(za, zb)), Vector3(X1 - X0, H, 9.0))
	spawn = Vector3(X0 + 1.2, 0, side * 11.5)


func build(k: VenueKit) -> void:
	var s := float(side)
	var home := side < 0
	var team_col := home_primary() if home else Color("4a5563")
	var paint: Color = k.by_age(Wear.OLD_MINT.darkened(0.1), Wear.OLD_MINT, Wear.WHITE)
	var z_in := s * 5.15        # inside face of the wall shared with the Zamboni bay
	var z_out := s * (Venue.ROOM_Z - 0.3)  # inside face of the outer side wall
	# front wall onto the rink walkway, with the door
	var door_z := s * 12.0
	k.wall_z(X0 + 0.15, s * 5.0, s * Venue.ROOM_Z, 0, H, 0.3, paint, [{"at": door_z, "w": 1.0, "y0": 0.0, "y1": 2.2}], 0.5)
	add_door(k, Vector3(X0 + 0.15, 0, door_z), PI * 0.5, VenueDoor.Kind.SWING, 0.95, 2.2, k.by_age(Color("5d6a73"), Color("6b7a86"), team_col.darkened(0.25)), "Dressing room %s" % ("home" if home else "away"))
	k.wall_x(s * (Venue.ROOM_Z - 0.15), X0, X1, 0, H, 0.3, paint, [], 0.5)
	# exterior wall (building envelope, full height)
	k.wall_z(Venue.HALF_X - Venue.WALL_T * 0.5, s * 5.0, s * Venue.ROOM_Z, 0, Venue.ROOF_Y, Venue.WALL_T, Color("a9a191") if k.age == Age.WORN else Color("bdb4a2"), [], 1.0)
	# ceiling
	k.slab(Vector3(X0, H, s * 5.0), Vector3(X1, H + 0.2, s * Venue.ROOM_Z), Color("8b877e"), 1.0)
	k.slab(Vector3(X0 + 0.3, H - 0.02, s * 5.15), Vector3(X1, H, z_out), k.by_age(Color("c8c2ae"), Color("d8d3c4"), Color("eceae4")), 0.6, 0.04, true, false)
	_floor(k, team_col, z_in, z_out)
	# stalls along the back wall and the outer side wall, bench in front
	var back_x := 42.3  # shower room behind (x 42.5..45.5 at the bay side)
	var n_back := int((absf(z_out - s * 8.6)) / PITCH)
	for i in n_back:
		var z := s * 8.6 + s * (i + 0.5) * PITCH
		_stall(k, Vector3(X1, 0, z), Vector3(-1, 0, 0), i, team_col)
	var n_side := int((X1 - 0.9 - (X0 + 2.0)) / PITCH)
	for i in n_side:
		var x := X0 + 2.0 + (i + 0.5) * PITCH
		_stall(k, Vector3(x, 0, z_out), Vector3(0, 0, -s), i + 20, team_col)
	var bench: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), team_col.darkened(0.15))
	k.aged_block(Vector3(X1 - 0.95, 0, s * 8.6), Vector3(X1 - 0.55, 0.45, z_out), bench, 0.5)
	k.aged_block(Vector3(X0 + 2.0, 0, z_out - s * 0.95), Vector3(X1 - 0.95, 0.45, z_out - s * 0.55), bench, 0.5)
	# shower room at the back by the bay wall
	var tile: Color = k.by_age(Color("b9c2bb"), Color("cfd8d2"), Color("f0f2f2"))
	k.wall_z(back_x + 0.1, s * 5.0, s * 8.6, 0, H, 0.2, tile, [{"at": s * 6.8, "w": 1.0, "y0": 0.0, "y1": 2.2}], 0.3)
	k.wall_x(s * 8.6, back_x, X1, 0, H, 0.2, tile, [], 0.3)
	for i in 3:
		var hz := s * (5.6 + i * 1.0)
		k.block(Vector3(X1 - 0.12, 2.0, hz - 0.06), Vector3(X1, 2.12, hz + 0.06), Color("b8bcc2"), 0.1, 0.0, false)
	# coach's whiteboard on the front wall
	var board := VenueSign.make([
		["// GAME PLAN", Color("1d3f8a")], ["----", Color("8a8f99")],
		["1. GET PUCKS DEEP", Color("1b1d22")], ["2. SHOOT EARLY", Color("1b1d22")], ["3. NO DUMB PENALTIES", Color("b8312f")],
	], 20, 5, 0.022)
	board.name = "Whiteboard"
	board.background = Color("eef0f2") if k.age != Age.WORN else Color("d8d6cc")
	k.sign(board, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(X0 + 0.31, 1.7, s * 8.0)))
	# door plate on the walkway side
	var plate := VenueSign.make([["// " + ("HOME" if home else "VISITORS"), VenueSign.CYAN if home else VenueSign.AMBER]], 11, 1, 0.03)
	plate.name = "DoorPlate"
	plate.dead = k.by_age(0.05, 0.0, 0.0)
	k.sign(plate, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(X0 - 0.01, 2.6, door_z)))
	room_light(k, Vector3(39.5, H - 0.4, s * 9.5), 7.0)
	# lights
	var lit: Color = k.by_age(Color("e6f0d8"), Color("f4f6f0"), Color("fff6e6"))
	for x in [36.5, 39.5, 42.5]:
		for zz in [7.5, 11.0]:
			k.glow(Vector3(x - 0.6, H - 0.06, s * zz - 0.15), Vector3(x + 0.6, H - 0.03, s * zz + 0.15), lit if not (k.age == Age.WORN and x == 39.5 and zz == 7.5) else Color("4a4d48"))


func _floor(k: VenueKit, team_col: Color, z_in: float, z_out: float) -> void:
	var cx := 38.5
	var cz := side * 10.0
	var tile := 0.5
	var z_lo := minf(z_in, z_out)
	var z_hi := maxf(z_in, z_out)
	var nx := int((Venue.HALF_X - Venue.WALL_T - Venue.END_FRONT - 0.3) / tile)
	var nz := int((z_hi - z_lo) / tile)
	for i in nx:
		for j in nz:
			var x := Venue.END_FRONT + 0.3 + i * tile
			var z := z_lo + j * tile
			var col: Color
			match k.age:
				Age.WORN:
					col = Color("8a8a80") if (i + j) % 2 == 0 else Color("7a7a70")
					if posmod(hash(Vector2i(i, j)), 9) == 0:
						col = col.darkened(0.25)
				Age.REPAIRED:
					col = Color("4a5260")
				_:
					col = team_col.darkened(0.55)
					var d := Vector2(x + tile * 0.5 - cx, z + tile * 0.5 - cz).length()
					if d < 2.0:
						col = team_col if d > 1.2 or d < 0.5 else home_secondary()
			k.block(Vector3(x, 0, z), Vector3(x + tile, 0.02, z + tile), col, tile, 0.05, false)
	if k.age == Age.WORN:
		k.block(Vector3(cx - 0.25, 0.02, cz - 0.25), Vector3(cx + 0.25, 0.03, cz + 0.25), Color("3a3b3e"), 0.1, 0.0, false)  # drain


## One player's stall against a wall at `at`, opening toward `into`.
func _stall(k: VenueKit, at: Vector3, into: Vector3, i: int, team_col: Color) -> void:
	var across := Vector3(absf(into.z), 0, absf(into.x)) * PITCH * 0.5
	var depth := into * 0.55
	var a := at - across
	var b := at + across + depth
	match k.age:
		Age.WORN:
			# a dented metal locker, door shut
			var metal := Wear.OLD_ORANGE
			k.block(a + Vector3(0, 0, 0), b + Vector3(0, 1.9, 0), k.aged(metal, i).lerp(Color("7a8a9a"), 0.15 if i % 4 == 0 else 0.0), 0.3, 0.12)
			k.block(a + depth * 0.98 + across * 0.2 + Vector3(0, 1.5, 0), a + depth * 1.0 + across * 0.6 + Vector3(0, 1.6, 0), Color("2b2d33"), 0.2, 0.0, false)
		_:
			var wood: Color = Wear.OLD_WOOD if k.age == Age.REPAIRED else Color("a7804f")
			k.block(a, a + depth + Vector3(0, 2.0, 0) + across * 0.06 * 2.0, wood, 0.3, 0.06)  # divider
			k.block(a + across * 0.03, b + Vector3(0, 0, 0) - depth * 0.92 + Vector3(0, 2.0, 0), wood.darkened(0.2), 0.3, 0.06, false)  # back panel
			k.block(a + Vector3(0, 1.75, 0), b + Vector3(0, 1.8, 0), wood, 0.3, 0.06, false)  # shelf
			# hanging jersey
			k.block(a + across * 0.5 + depth * 0.3 + Vector3(0, 0.9, 0), a + across * 1.5 + depth * 0.5 + Vector3(0, 1.6, 0), team_col, 0.2, 0.05, false)
			if k.age == Age.RENOVATED:
				k.glow(a + across * 0.4 + Vector3(0, 2.05, 0) + depth, a + across * 1.6 + Vector3(0, 2.15, 0) + depth * 1.02, team_col.lightened(0.4))
