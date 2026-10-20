extends VenueRoom
## The front lobby at the -X end: front doors to the street, snack bar,
## trophy case, a viewing window onto the ice, doors to the rink walkway and
## stairs up to the mezzanine (the lobby roof), where the manager's office
## sits. The ticket and skate rental booth was tacked on later out in the
## arena, against the lobby's north wall where the wing's doors come in.

const X0 := -Venue.HALF_X + Venue.WALL_T  # inside face of the street wall
const X1 := -Venue.END_FRONT              # rink-side wall
const Z := Venue.ROOM_Z
const H := Venue.LOBBY_H
const STAIR_Z := [11.6, 13.7]
const STAIR_X := [-36.8, -44.5]  # bottom step to top step
## The ticket booth in the arena's north-west corner (x0, z0, x1, z1): its
## back is the lobby's north wall, its window faces east, toward the rink.
const BOOTH := [-38.6, -16.6, -35.2, -14.0]


func _ready() -> void:
	room_id = "lobby"
	display_name = "Lobby"
	bounds = AABB(Vector3(X0, 0, -Z), Vector3(X1 - X0, H, Z * 2))
	spawn = Vector3(X0 + 1.5, 0, 0)


## The snack bar line (front first), the skate window and the front doors
## (outside, then just inside).
func places() -> Dictionary:
	var line: Array[Vector3] = []
	for i in 5:
		line.append(Vector3(-39.5, 0, -10.2 + i * 0.8))
	return {"canteen": line, "skate_rental": [Vector3(BOOTH[2] + 0.9, 0, -14.7)],
		"entrance": [Vector3(X0 - 1.4, 0, 0.4), Vector3(X0 + 1.5, 0, 0.4)]}


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
	# the lobby's ceiling, open over the stairwell
	var ceiling: Color = k.by_age(Color("cfc9b6"), Color("d8d3c4"), Color("eceae4"))
	k.slab(Vector3(X0, H, -Z), Vector3(X1, H + 0.02, STAIR_Z[0]), ceiling, 1.0, 0.03, true, false)
	k.slab(Vector3(X0, H, STAIR_Z[0]), Vector3(STAIR_X[1], H + 0.02, Z), ceiling, 1.0, 0.03, true, false)
	k.slab(Vector3(STAIR_X[0], H, STAIR_Z[0]), Vector3(X1, H + 0.02, Z), ceiling, 1.0, 0.03, true, false)
	var steps := 25
	var run := (STAIR_X[0] - STAIR_X[1]) / steps
	k.stairs(Vector3(STAIR_X[0], 0, (STAIR_Z[0] + STAIR_Z[1]) * 0.5), Vector3(-1, 0, 0), STAIR_Z[1] - STAIR_Z[0], H + 0.3, steps, run, slab_col)
	_stair_rails(k, steps, run)
	# mezzanine rail over the rink
	k.block(Vector3(X1 - 0.3, H + 0.3, -Z), Vector3(X1, H + 0.55, Z), slab_col, 1.0)
	k.glass(Vector3(X1 - 0.18, H + 0.55, -Z), Vector3(X1 - 0.12, H + 1.4, Z))
	_floor(k)
	_ticket_booth(k)
	_old_booth_marks(k)
	_snack_bar(k)
	_trophies(k)
	_seating(k)
	_ceiling_lights(k)
	_signs(k)
	_first_hour(k)
	_corkboard(k)
	room_light(k, Vector3(-41.5, H - 0.4, -6.0), 7.5)
	room_light(k, Vector3(-41.5, H - 0.4, 6.0), 7.5)


## Railings on both sides of the office stairs: a balustrade on the open
## side, a handrail on brackets along the wall, and guard rails round the
## stairwell up on the mezzanine.
func _stair_rails(k: VenueKit, steps: int, run: float) -> void:
	var steel: Color = k.by_age(Color("6b6f76"), Color("7d838a"), Color("2a2e36"))
	var cap: Color = k.by_age(Color("5c4330"), Color("6b4f38"), home_primary().darkened(0.2))
	var rise := (H + 0.3) / steps
	var zo: float = STAIR_Z[0] + 0.06
	var zw: float = STAIR_Z[1] - 0.08
	# the handrail's line: 0.9 m over the step nosings, bottom step to the top
	var p0 := Vector3(STAIR_X[0] - run * 0.5, rise + 0.9, 0)
	var p1 := Vector3(STAIR_X[1], H + 0.3 + 0.9, 0)
	for z in [zo, zw]:
		_rail(k, Vector3(p0.x, p0.y, z), Vector3(p1.x, p1.y, z), 0.06, cap)
	# open side: posts on every third step and a mid rail, colliders in runs
	for i in range(0, steps, 3):
		var x: float = STAIR_X[0] - run * (i + 0.5)
		var top := rise * (i + 1)
		k.block(Vector3(x - 0.03, top, zo - 0.03), Vector3(x + 0.03, top + 0.9, zo + 0.03), steel, 0.3, 0.0, false)
	_rail(k, Vector3(p0.x, p0.y - 0.45, zo), Vector3(p1.x, p1.y - 0.45, zo), 0.035, steel)
	for i in range(0, steps, 5):
		var xa: float = STAIR_X[0] - run * i
		var xb: float = STAIR_X[0] - run * minf(i + 5, steps)
		k.collider(Vector3(xb, 0, zo - 0.05), Vector3(xa, rise * minf(i + 5, steps) + 1.0, zo + 0.05))
	# wall side: brackets into the wall every 1.5 m
	for i in range(1, steps, 8):
		var x: float = STAIR_X[0] - run * (i + 0.5)
		var y := rise * (i + 1) + 0.9
		k.block(Vector3(x - 0.03, y - 0.1, zw), Vector3(x + 0.03, y - 0.03, STAIR_Z[1]), steel, 0.3, 0.0, false)
	# guard rails at the mezzanine: along the stairwell and across its foot
	var y0 := H + 0.3
	_guard(k, Vector3(STAIR_X[1], y0, STAIR_Z[0] - 0.05), Vector3(STAIR_X[0], y0, STAIR_Z[0] - 0.05), steel, cap)
	_guard(k, Vector3(STAIR_X[0] + 0.05, y0, STAIR_Z[0]), Vector3(STAIR_X[0] + 0.05, y0, STAIR_Z[1]), steel, cap)


## A straight rail from `a` to `b` (centre line), `t` thick. Visual only.
func _rail(k: VenueKit, a: Vector3, b: Vector3, t: float, col: Color) -> void:
	var d := b - a
	var along := d.normalized()
	var up := along.cross(Vector3(0, 0, 1) if absf(along.z) < 0.9 else Vector3(1, 0, 0)).normalized()
	if up.y < 0.0:
		up = -up
	var side := along.cross(up).normalized()
	k.oriented(Transform3D(Basis(along * d.length(), up * t, side * t), (a + b) * 0.5), col)


## A 1.07 m guard rail on the floor from `a` to `b` (level): posts, a mid
## rail, a top rail and a collider.
func _guard(k: VenueKit, a: Vector3, b: Vector3, steel: Color, cap: Color) -> void:
	var n := maxi(1, int(ceil(a.distance_to(b) / 1.0)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		k.block(p + Vector3(-0.03, 0, -0.03), p + Vector3(0.03, 1.0, 0.03), steel, 0.3, 0.0, false)
	_rail(k, a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), 0.035, steel)
	_rail(k, a + Vector3(0, 1.04, 0), b + Vector3(0, 1.04, 0), 0.06, cap)
	k.collider(a.min(b) - Vector3(0.05, 0, 0.05), a.max(b) + Vector3(0.05, 1.07, 0.05))


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


## The ticket and skate rental booth: a plywood shed somebody built onto the
## outside of the lobby wall, with a sliding window and a counter facing the
## rink, a mismatched sheet-metal roof, an extension cord out of the wall and
## a rack of rental skates behind the glass.
func _ticket_booth(k: VenueKit) -> void:
	var x0: float = BOOTH[0]
	var z0: float = BOOTH[1]
	var x1: float = BOOTH[2]
	var z1: float = BOOTH[3]
	var ply: Color = k.by_age(Color("8a6a45"), Color("9a7a52"), Color("2a2e36"))
	var patch: Color = k.by_age(Color("b89a6a"), Color("a88a5a"), home_primary().darkened(0.3))
	var trim: Color = k.by_age(Color("5c4330"), Color("6b4f38"), Color("16181c"))
	var h := 2.5
	# walls: the back is the lobby wall; a newer sheet patched into the north side
	k.aged_block(Vector3(x0, 0, z0), Vector3(x0 + 0.1, h, z1), ply, 0.4)
	k.aged_block(Vector3(x0, 0, z0), Vector3(x1, h, z0 + 0.1), ply, 0.4)
	k.aged_block(Vector3(x0 + 0.6, 0.3, z0 - 0.01), Vector3(x0 + 1.8, 1.7, z0 + 0.05), patch, 0.4, 0.04, false)
	# the front: low wall, counter, the window and a door at the north end
	k.aged_block(Vector3(x1 - 0.1, 0, z0 + 1.1), Vector3(x1, 1.05, z1), ply, 0.4)
	k.aged_block(Vector3(x1 - 0.1, 0, z0 + 0.1), Vector3(x1, h, z0 + 0.15), trim, 0.3)
	k.block(Vector3(x1 - 0.1, h - 0.45, z0 + 1.1), Vector3(x1, h, z1), ply, 0.4)
	k.block(Vector3(x1 - 0.1, 2.12, z0 + 0.15), Vector3(x1, h, z0 + 1.1), ply, 0.4)
	k.block(Vector3(x1, 1.0, z0 + 1.1), Vector3(x1 + 0.35, 1.07, z1 - 0.1), trim.lightened(0.15), 0.3)
	k.prop("puck", Vector3(x1 + 0.18, 1.07, -14.55), 0.0, false)  # World objects: a puck on the counter
	for z in [z0 + 1.1, (z0 + 1.1 + z1) * 0.5, z1 - 0.05]:
		k.block(Vector3(x1 - 0.1, 1.05, z - 0.04), Vector3(x1, h - 0.45, z + 0.04), trim, 0.3, 0.03, false)
	k.glass(Vector3(x1 - 0.07, 1.05, z0 + 1.14), Vector3(x1 - 0.03, h - 0.45, z1 - 0.09))
	# the speak hole: a round grille in the glass
	k.block(Vector3(x1 - 0.08, 1.45, -15.0), Vector3(x1 - 0.02, 1.6, -14.85), Color("9a9ea4"), 0.1, 0.0, false)
	add_door(k, Vector3(x1 - 0.05, 0, z0 + 0.625), PI * 0.5, VenueDoor.Kind.SWING, 0.9, 2.1, trim.lightened(0.1), "Ticket booth")
	# the roof: a sheet of corrugated metal, a size too big and not quite level
	var tin: Color = k.by_age(Color("8a8f92"), Color("9aa0a4"), Color("3a3d44"))
	var roof := Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-4.0)) * Basis.from_scale(Vector3(x1 - x0 + 0.7, 0.06, z1 - z0 + 0.5)), Vector3((x0 + x1) * 0.5 + 0.25, h + 0.08, (z0 + z1) * 0.5 - 0.15))
	k.oriented(roof, tin)
	for i in 7:
		var rz := z0 - 0.35 + i * 0.5
		k.oriented(Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-4.0)) * Basis.from_scale(Vector3(x1 - x0 + 0.7, 0.03, 0.05)), Vector3((x0 + x1) * 0.5 + 0.25, h + 0.12, rz)), tin.darkened(0.12))
	k.collider(Vector3(x0, h, z0), Vector3(x1 + 0.4, h + 0.2, z1))
	# inside: the till on the counter, a stool, the rental skates in cubbies
	k.block(Vector3(x1 - 0.55, 1.0, -15.35), Vector3(x1 - 0.2, 1.2, -14.95), Color("2b2d33"), 0.2, 0.03)
	k.block(Vector3(x1 - 1.0, 0, -15.5), Vector3(x1 - 0.7, 0.7, -15.2), Color("3a3d44"), 0.2, 0.03)
	var cubby := Color("6b5136")
	k.aged_block(Vector3(x0 + 0.1, 0, z0 + 0.15), Vector3(x0 + 0.55, 2.0, z1 - 0.05), cubby, 0.3)
	for row in 4:
		for col in 5:
			var cz := z0 + 0.35 + col * 0.42
			var cy := 0.25 + row * 0.45
			var skate: Color = [Color("1b1d22"), Color("2a2c33"), Color("e8e4da")][(row + col) % 3]
			k.block(Vector3(x0 + 0.55, cy, cz), Vector3(x0 + 0.85, cy + 0.18, cz + 0.12), skate, 0.1, 0.03, false)
			k.block(Vector3(x0 + 0.55, cy - 0.03, cz), Vector3(x0 + 0.85, cy, cz + 0.12), Color("b8bcc2"), 0.1, 0.0, false)
	# the extension cord from a lobby outlet, taped down across the floor
	k.block(Vector3(x0 - 1.4, 0.3, z1 - 0.01), Vector3(x0 - 1.3, 0.42, z1 + 0.01), Color("e8e4da"), 0.1, 0.0, false)
	k.block(Vector3(x0 - 1.37, 0.0, z1 - 0.06), Vector3(x0 - 1.33, 0.3, z1 - 0.02), Color("e06a1a"), 0.1, 0.0, false)
	k.block(Vector3(x0 - 1.37, 0.0, z1 - 0.06), Vector3(x0, 0.02, z1 - 0.02), Color("e06a1a"), 0.1, 0.0, false)
	# the public skate flyer taped inside the window, prices and all
	var f := Readable.make("cork_public_skate")
	f.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x1 - 0.075, 1.62, (z0 + 1.1 + z1) * 0.5 + 0.5))
	k.add(f)
	# World: sized and centred to the booth's front (2.5 m) so it no longer
	# runs 1.2 m through the lobby wall (W12)
	# World: now a hand-painted plywood board with the skate price repainted (W13)
	var s := Readable.make("sign_tickets")
	s.name = "TicketSign"
	s.transform = Transform3D(Readable.on_wall(Vector3.RIGHT), Vector3(x1 + 0.02, h - 0.26, (z0 + z1) * 0.5))
	k.add(s)


## Where the old booth stood, inside by the street wall: the screw holes and
## a paler patch of floor.
func _old_booth_marks(k: VenueKit) -> void:
	if k.age == Age.RENOVATED:
		return
	var bx := X0 + 2.8
	k.block(Vector3(bx - 0.12, 0.015, -12.5), Vector3(bx + 0.12, 0.02, -9.0), Wear.OLD_CREAM.lightened(0.1), 0.6, 0.06, false)


func _snack_bar(k: VenueKit) -> void:
	# two kit counters facing the lobby, with a gap for staff at the end
	for cx in [-40.8, -38.3]:
		k.prop("concession_counter", Vector3(cx, 0, -11.25), PI)
	# World objects: a mug left on the counter (take it, drop it anywhere)
	k.prop("coffee_cup", Vector3(-40.0, 1.105, -11.1), PI + 0.4, false)
	# back shelf, a coffee urn, a popcorn machine, a cooler
	k.aged_block(Vector3(-42.0, 0, -13.7), Vector3(-36.0, 0.95, -13.1), Color("6f6a5e"), 0.4)
	k.block(Vector3(-41.5, 0.95, -13.7), Vector3(-41.1, 1.45, -13.3), Color("b8bcc2"), 0.2, 0.03)
	k.block(Vector3(-39.8, 0.95, -13.75), Vector3(-39.0, 1.75, -13.25), Color("c8312f"), 0.25, 0.03)
	k.glass(Vector3(-39.75, 1.15, -13.25), Vector3(-39.05, 1.7, -13.22), false, Color(1.0, 0.92, 0.6, 0.35))
	k.block(Vector3(-37.4, 0, -13.7), Vector3(-36.2, 1.9, -13.1), Color("d9d9d6"), 0.3, 0.03)
	k.glow(Vector3(-37.3, 0.2, -13.09), Vector3(-36.3, 1.8, -13.08), k.by_age(Color("7a8a7a"), Color("cfe8ff"), Color("e8f6ff")))
	# the felt letter menu board on the back wall (one price written over)
	var menu := Readable.make("sign_snack_bar")
	menu.transform = Transform3D(Basis.IDENTITY, Vector3(-39.0, 2.45, -13.7))
	k.add(menu)


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
	_rink_wall(k)


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
	# the bronze plaque by the doors and the roof-repair strip screwed under it
	var face_in := Basis(Vector3.UP, PI * 0.5)
	var plaque := Readable.make("sign_plaque")
	plaque.transform = Transform3D(face_in, Vector3(X0 + 0.005, 1.6, 2.0))
	k.add(plaque)
	var strip := Readable.make("sign_roof_strip")
	strip.transform = Transform3D(face_in, Vector3(X0 + 0.005, 1.36, 2.0))
	k.add(strip)
	add_spot(k, VenueSpot.Kind.READ, "dedication_plaque", Vector3(px + 0.05, 1.5, 2.0), "Dedication plaque", {"readable": "dedication_plaque"}, 1.5)


## The rink-side wall: skate guards notices over the rink doors, the public
## skate letter board and the "don't lean on the glass" note.
func _rink_wall(k: VenueKit) -> void:
	var face := Basis(Vector3.UP, -PI * 0.5)  # looking into the lobby (-X)
	var x := X1 - 0.305
	for dz in [-8.5, 8.5]:
		var g := Readable.make("sign_notice_guards")
		g.transform = Transform3D(face, Vector3(x, 2.62, dz))
		k.add(g)
	var rules := Readable.make("sign_letter_board")
	rules.transform = Transform3D(face, Vector3(x, 1.55, 6.3))
	k.add(rules)
	# taped to the inside of the viewing window
	var glass := Readable.make("sign_glass_notice")
	glass.transform = Transform3D(face * Basis(Vector3.BACK, 0.03), Vector3(X1 - 0.185, 1.55, 3.4))
	k.add(glass)


## Notices pinned to the cork board: [readable id, z offset, y offset, tilt]
const CORK := [
	["cork_public_skate", -0.5, 0.18, 0.02], ["cork_lost_cat", -0.18, 0.2, -0.04],
	["cork_vmha", 0.14, 0.16, 0.015], ["cork_bonspiel", 0.47, 0.13, -0.03],
	["cork_wrong_bag", -0.52, -0.22, 0.06], ["cork_manager", -0.24, -0.25, -0.05],
	["cork_piano", 0.06, -0.22, 0.04], ["cork_for_sale", 0.3, -0.24, -0.08],
	["cork_learn_skate", 0.52, -0.25, 0.03],
]


## The lobby's cork board between the north rink doors and the window:
## real paper flyers, each on a push pin, all of them loose (take one down,
## pin it somewhere else).
func _corkboard(k: VenueKit) -> void:
	var x := X1 - 0.3
	var zc := -6.3
	var yc := 1.55
	var w := 1.15
	var h := 0.8
	var wood: Color = k.by_age(Color("6b4a2c"), Color("7a5634"), Color("3a3d44"))
	k.block(Vector3(x - 0.035, yc - h * 0.5 - 0.04, zc - w * 0.5 - 0.04), Vector3(x, yc + h * 0.5 + 0.04, zc + w * 0.5 + 0.04), wood, 0.3, 0.02, false)
	k.block(Vector3(x - 0.045, yc - h * 0.5, zc - w * 0.5), Vector3(x - 0.03, yc + h * 0.5, zc + w * 0.5), k.by_age(Color("9a7448"), Color("a87e4e"), Color("b08a5a")), 0.12, 0.05, false)
	var face := Basis(Vector3.UP, -PI * 0.5)
	var pin_cols := [Color("c8302c"), Color("2f62c0"), Color("e0c030"), Color("2e8a4a"), Color("f2f2f2")]
	var i := 0
	for c in CORK:
		var r := Readable.make(c[0], true)
		var pos := Vector3(x - 0.046, yc + c[2] * 0.82, zc + c[1] * 0.8)
		r.transform = Transform3D(face * Basis(Vector3.BACK, c[3]), pos)
		k.add(r)
		var pin := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.008
		sm.height = 0.016
		sm.radial_segments = 6
		sm.rings = 3
		var pm := StandardMaterial3D.new()
		pm.albedo_color = pin_cols[i % pin_cols.size()]
		pm.roughness = 0.35
		sm.material = pm
		pin.mesh = sm
		pin.position = Vector3(0, r.size.y * 0.5 - 0.02, 0.008)
		r.add_child(pin)
		i += 1
