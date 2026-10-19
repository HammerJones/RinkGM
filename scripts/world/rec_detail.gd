class_name RecDetail
extends RefCounted
## World's detail pass on the recreation wing rooms Rink environment lays out
## (playtest #23, #27: "more details to all the assets"): the small things
## that make a room look used. Each room's furnish() calls its function here
## once (marked `# World:`), after its own furniture, so the layout stays
## Rink environment's and the clutter stays World's.
##
## Everything is kit blocks merged into the room's own mesh (no extra draws)
## except the odd Props kit piece (an extinguisher), which is one MultiMesh
## per room. Nothing here collides unless it is something you'd walk into,
## and nothing sits on a walking route (test_rec_centre walks them).


# ---------------------------------------------------------------- shared bits

## A folding chair: seat, back and legs, its back toward `back_dir` (unit X
## or Z). Solid as one box.
static func chair(k: VenueKit, p: Vector3, back_dir: Vector3, col: Color) -> void:
	var side := Vector3(absf(back_dir.z), 0, absf(back_dir.x)) * 0.21
	var depth := back_dir * 0.2
	var lo := p - side - depth
	var hi := p + side + depth
	k.block(Vector3(minf(lo.x, hi.x), 0.42, minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), 0.46, maxf(lo.z, hi.z)), col, 1.0, 0.03, false)
	var b0 := p + back_dir * 0.18 - side
	var b1 := p + back_dir * 0.22 + side
	k.block(Vector3(minf(b0.x, b1.x), 0.46, minf(b0.z, b1.z)), Vector3(maxf(b0.x, b1.x), 0.85, maxf(b0.z, b1.z)), col, 1.0, 0.03, false)
	for c in [lo, hi, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, lo.z)]:
		var q: Vector3 = c
		var ox := 0.03 if q.x < p.x else -0.03
		var oz := 0.03 if q.z < p.z else -0.03
		k.block(Vector3(q.x + ox - 0.012, 0, q.z + oz - 0.012), Vector3(q.x + ox + 0.012, 0.42, q.z + oz + 0.012), Color("3a3d44"), 1.0, 0.0, false)
	k.collider(Vector3(minf(lo.x, hi.x), 0, minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), 0.85, maxf(lo.z, hi.z)))


## A wall clock on a wall face at `p`, facing `n`.
static func clock(k: VenueKit, p: Vector3, n: Vector3) -> void:
	var a := Vector3(absf(n.z), 0, absf(n.x)) * 0.17
	k.block(p - a + Vector3(0, -0.17, 0), p + a + n * 0.04 + Vector3(0, 0.17, 0), Color("eeeeea"), 1.0, 0.0, false)
	k.block(p + n * 0.04 + Vector3(0, -0.01, 0), p + n * 0.045 + a * 0.6 + Vector3(0, 0.01, 0), Color("1b1d22"), 1.0, 0.0, false)
	k.block(p + n * 0.04 - Vector3(0, 0.0, 0) - a * 0.06, p + n * 0.045 + a * 0.06 + Vector3(0, 0.12, 0), Color("1b1d22"), 1.0, 0.0, false)


## A corkboard with pinned papers at `p` (centre) on a wall facing `n`.
static func corkboard(k: VenueKit, p: Vector3, n: Vector3, w: float, h: float, seed: int) -> void:
	var a := Vector3(absf(n.z), 0, absf(n.x))
	k.block(p - a * (w * 0.5) - Vector3(0, h * 0.5, 0), p + a * (w * 0.5) + n * 0.03 + Vector3(0, h * 0.5, 0), Color("b08a5a"), 1.0, 0.04, false)
	var papers := [Wear.PAPER, Color("f3e27a"), Color("f2b8c8"), Color("bfe0f0"), Wear.PAPER]
	for i in 7:
		var u := (posmod(hash(Vector2i(seed, i)), 100) / 100.0 - 0.5) * (w - 0.3)
		var v := (posmod(hash(Vector2i(i, seed)), 100) / 100.0 - 0.5) * (h - 0.3)
		var c: Color = papers[i % papers.size()]
		var q := p + a * u + Vector3(0, v, 0) + n * 0.03
		k.block(q - a * 0.1 - Vector3(0, 0.13, 0), q + a * 0.1 + n * 0.006 + Vector3(0, 0.13, 0), c, 1.0, 0.02, false)
		k.block(q + Vector3(0, 0.1, 0) - a * 0.01, q + Vector3(0, 0.12, 0) + a * 0.01 + n * 0.012, Color("c8191e"), 1.0, 0.0, false)


## A potted plant: dead in a worn room, leggy when repaired, healthy new.
static func plant(k: VenueKit, p: Vector3) -> void:
	k.block(p + Vector3(-0.17, 0, -0.17), p + Vector3(0.17, 0.35, 0.17), k.by_age(Color("8a5a3a"), Color("8a5a3a"), Color("2b2d33")), 1.0, 0.04)
	var leaf: Color = k.by_age(Color("7a6a3a"), Color("4a7a3a"), Color("2f7a3f"))
	var hgt: float = k.by_age(0.5, 0.9, 1.2)
	k.block(p + Vector3(-0.02, 0.35, -0.02), p + Vector3(0.02, 0.35 + hgt, 0.02), Color("5a4030"), 1.0, 0.0, false)
	for i in 4:
		var y := 0.55 + hgt * (0.25 + 0.2 * i)
		var o := Vector3(0.12 * (1 - 2 * (i % 2)), 0, 0.1 * (1 - 2 * ((i / 2) % 2)))
		k.block(p + o + Vector3(-0.14, y - 0.1, -0.12), p + o + Vector3(0.14, y + 0.04, 0.12), leaf.darkened(0.08 * i), 1.0, 0.06, false)
	if k.age == VenueRoom.Age.WORN:
		k.block(p + Vector3(0.2, 0, -0.1), p + Vector3(0.32, 0.004, 0.06), Color("7a6a3a"), 1.0, 0.0, false)  # dropped leaves


## A recessed fire extinguisher cabinet in a wall facing `n`.
static func fire_cabinet(k: VenueKit, p: Vector3, n: Vector3) -> void:
	var a := Vector3(absf(n.z), 0, absf(n.x))
	k.block(p - a * 0.25, p + a * 0.25 + n * 0.03 + Vector3(0, 0.75, 0), Color("c4161c") if k.age != VenueRoom.Age.WORN else Color("9a3a30"), 1.0, 0.03, false)
	k.glass(p - a * 0.18 + Vector3(0, 0.08, 0) + n * 0.03, p + a * 0.18 + n * 0.035 + Vector3(0, 0.62, 0), false, Color(0.85, 0.9, 0.95, 0.3))
	k.block(p - a * 0.06 + Vector3(0, 0.15, 0) + n * 0.005, p + a * 0.06 + n * 0.028 + Vector3(0, 0.55, 0), Color("c4161c"), 1.0, 0.0, false)


## A red fire alarm pull station on a wall facing `n`.
static func pull_station(k: VenueKit, p: Vector3, n: Vector3) -> void:
	var a := Vector3(absf(n.z), 0, absf(n.x))
	k.block(p - a * 0.06 - Vector3(0, 0.08, 0), p + a * 0.06 + n * 0.05 + Vector3(0, 0.08, 0), Color("c4161c"), 1.0, 0.0, false)
	k.block(p - a * 0.04, p + a * 0.04 + n * 0.055 + Vector3(0, 0.03, 0), Color("eeeeea"), 1.0, 0.0, false)


## An old cast-iron radiator under a window (worn and repaired rooms), or a
## slim baseboard heater (renovated).
static func radiator(k: VenueKit, a: Vector3, b: Vector3) -> void:
	if k.age == VenueRoom.Age.RENOVATED:
		k.block(a, Vector3(b.x, a.y + 0.2, b.z), Color("e6e4de"), 1.0, 0.02)
		return
	var col: Color = k.by_age(Color("8a8270"), Color("c8c2b0"), Color("c8c2b0"))
	k.block(a, Vector3(b.x, a.y + 0.08, b.z), col.darkened(0.2), 1.0, 0.02)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var n := int((absf(b.x - a.x) if along_x else absf(b.z - a.z)) / 0.09)
	for i in n:
		var t := (i + 0.5) / n
		var c := a.lerp(b, t)
		if along_x:
			k.block(Vector3(c.x - 0.03, a.y + 0.08, a.z), Vector3(c.x + 0.03, a.y + 0.62, b.z), col.darkened(0.05 * (i % 2)), 1.0, 0.0, false)
		else:
			k.block(Vector3(a.x, a.y + 0.08, c.z - 0.03), Vector3(b.x, a.y + 0.62, c.z + 0.03), col.darkened(0.05 * (i % 2)), 1.0, 0.0, false)
	k.collider(a, Vector3(b.x, a.y + 0.62, b.z))


# ---------------------------------------------------------------- rooms

## The community hall: chairs set at the tables (cloths once it's cared for,
## bingo cards when it isn't), PA speakers and a mic on the stage, a coat
## rack by the door, radiators, a clock, the extinguisher and a chair cart.
static func community_room(r: RecRoom, k: VenueKit) -> void:
	var chair_col: Color = k.by_age(Color("6a6e74"), Color("7d8288"), Color("2b2d33"))
	for row in 2:
		for col in 3:
			var tx := r.x0 + 2.2 + col * 4.4
			var tz := -52.5 + row * 3.2
			if k.age != VenueRoom.Age.WORN:
				var cloth: Color = Color("eeeeea") if (row + col) % 2 == 0 else r.home_primary().lightened(0.1)
				k.block(Vector3(tx - 0.05, 0.74, tz - 0.05), Vector3(tx + 2.45, 0.76, tz + 0.85), cloth, 1.0, 0.03, false)
				k.block(Vector3(tx - 0.05, 0.5, tz - 0.06), Vector3(tx + 2.45, 0.76, tz - 0.05), cloth.darkened(0.05), 1.0, 0.0, false)
			else:
				for j in 4:
					var cx := tx + 0.3 + j * 0.55
					k.block(Vector3(cx, 0.74, tz + 0.25), Vector3(cx + 0.2, 0.745, tz + 0.5), Color("f1eee4"), 1.0, 0.03, false)  # bingo cards
					k.block(Vector3(cx + 0.22, 0.74, tz + 0.3), Vector3(cx + 0.26, 0.86, tz + 0.34), [Color("c8191e"), Color("2f9a4f"), Color("e0308a"), Color("2f5fb7")][j], 1.0, 0.0, false)  # dabbers
			for j in 3:
				var cx := tx + 0.45 + j * 0.75
				chair(k, Vector3(cx, 0, tz - 0.4), Vector3(0, 0, -1), chair_col)
				if row == 0 or j != 1:
					chair(k, Vector3(cx, 0, tz + 1.2), Vector3(0, 0, 1), chair_col)
	# PA speakers on stands and a mic stand on the stage
	var stage_y := 0.8
	for x in [r.x0 + 0.8, r.x1 - 0.8]:
		k.block(Vector3(x - 0.03, stage_y, r.z0 + 3.2), Vector3(x + 0.03, stage_y + 1.4, r.z0 + 3.26), Color("2b2d33"), 1.0, 0.0, false)
		k.block(Vector3(x - 0.22, stage_y + 1.4, r.z0 + 3.05), Vector3(x + 0.22, stage_y + 2.0, r.z0 + 3.4), Color("1b1d22"), 1.0, 0.03, false)
		k.block(Vector3(x - 0.15, stage_y + 1.5, r.z0 + 3.4), Vector3(x + 0.15, stage_y + 1.8, r.z0 + 3.41), Color("3a3d44"), 1.0, 0.0, false)
	k.block(Vector3(23.0, stage_y, r.z0 + 3.3), Vector3(23.04, stage_y + 1.5, r.z0 + 3.34), Color("2b2d33"), 1.0, 0.0, false)
	k.block(Vector3(22.98, stage_y + 1.5, r.z0 + 3.28), Vector3(23.06, stage_y + 1.6, r.z0 + 3.36), Color("8f9498"), 1.0, 0.0, false)
	k.block(Vector3(22.7, stage_y, r.z0 + 3.2), Vector3(23.6, stage_y + 0.01, r.z0 + 3.25), Color("1b1d22"), 1.0, 0.0, false)  # the cable
	# a coat rack by the door with a few coats
	var rack_x := 26.0
	k.block(Vector3(rack_x, 1.75, r.z1 - 0.35), Vector3(rack_x + 1.6, 1.78, r.z1 - 0.3), Color("8f9498"), 1.0, 0.0, false)
	for x in [rack_x, rack_x + 1.57]:
		k.block(Vector3(x, 0, r.z1 - 0.35), Vector3(x + 0.03, 1.78, r.z1 - 0.3), Color("8f9498"), 1.0, 0.0, false)
	var coats := [Color("3a4a6a"), Color("6a2a2a"), Color("8a7a5a"), Color("2b2d33")]
	for i in 4:
		var x := rack_x + 0.2 + i * 0.35
		k.block(Vector3(x, 0.85, r.z1 - 0.45), Vector3(x + 0.28, 1.72, r.z1 - 0.22), coats[i], 1.0, 0.05, false)
	k.collider(Vector3(rack_x, 0, r.z1 - 0.45), Vector3(rack_x + 1.6, 1.8, r.z1 - 0.2))
	# an old radiator on the east wall between the stage and the kitchen
	radiator(k, Vector3(r.x1 - 0.3, 0, -55.6), Vector3(r.x1 - 0.15, 0, -52.2))
	clock(k, Vector3(24.0, 3.3, r.z1 - 0.15), Vector3(0, 0, -1))
	k.prop("fire_extinguisher", Vector3(22.6, 0, r.z1 - 0.3), 0.0)
	pull_station(k, Vector3(25.3, 1.3, r.z1 - 0.15), Vector3(0, 0, -1))
	# a stacking-chair dolly loaded beside the stacks
	k.block(Vector3(r.x0 + 0.3, 0, -44.9), Vector3(r.x0 + 0.85, 0.08, -44.4), Color("3a3d44"), 1.0, 0.02)
	for i in 8:
		k.block(Vector3(r.x0 + 0.33, 0.08 + i * 0.1, -44.85), Vector3(r.x0 + 0.82, 0.16 + i * 0.1, -44.45), k.aged(Color("6a6e74"), i), 1.0, 0.04, false)
	k.collider(Vector3(r.x0 + 0.3, 0, -44.9), Vector3(r.x0 + 0.85, 0.9, -44.4))


## The offices: desk clutter (phone, papers, a mug, an in-tray, a lamp),
## a calendar and a corkboard, a waste basket and a plant in each, a coat
## stand, and in the meeting room binders, a TV cart and a speakerphone.
static func offices(r: RecRoom, k: VenueKit) -> void:
	var edges := [r.x0 + 0.15, -41.33, -36.67, r.x1 - 0.15]
	for i in 3:
		var a: float = edges[i] + 0.1
		var b: float = edges[i + 1] - 0.1
		var cx := (a + b) * 0.5 - (1.3 if i == 1 else 0.0)
		var top := 0.75
		# papers, the in-tray, a phone, a mug, a lamp
		k.block(Vector3(cx - 0.7, top, -49.5), Vector3(cx - 0.4, top + 0.04, -49.2), Wear.PAPER, 1.0, 0.03, false)
		k.block(Vector3(cx - 0.68, top + 0.04, -49.48), Vector3(cx - 0.42, top + 0.07, -49.22), Color("f3e27a"), 1.0, 0.0, false)
		k.block(Vector3(cx - 0.3, top, -49.55), Vector3(cx - 0.05, top + 0.1, -49.2), Color("3a3d44"), 1.0, 0.0, false)  # in-tray
		k.block(Vector3(cx - 0.28, top + 0.02, -49.52), Vector3(cx - 0.07, top + 0.08, -49.23), Wear.PAPER, 1.0, 0.0, false)
		k.block(Vector3(cx + 0.62, top, -49.0), Vector3(cx + 0.78, top + 0.06, -48.85), k.by_age(Color("c9c0a8"), Color("c9c0a8"), Color("1b1d22")), 1.0, 0.0, false)  # phone
		k.block(Vector3(cx + 0.64, top + 0.06, -49.0), Vector3(cx + 0.76, top + 0.09, -48.97), Color("3a3d44"), 1.0, 0.0, false)
		k.block(Vector3(cx - 0.05, top, -48.98), Vector3(cx + 0.03, top + 0.1, -48.9), [Color("c8191e"), Color("eeeeea"), Color("2f5fb7")][i], 1.0, 0.0, false)  # mug
		if k.age == VenueRoom.Age.RENOVATED:
			k.block(Vector3(cx + 0.1, top, -49.0), Vector3(cx + 0.55, top + 0.02, -48.86), Color("2b2d33"), 1.0, 0.0, false)  # keyboard
		else:
			k.block(Vector3(cx - 0.75, top, -48.95), Vector3(cx - 0.65, top + 0.35, -48.85), Color("2b2d33"), 1.0, 0.0, false)  # lamp
			k.block(Vector3(cx - 0.8, top + 0.32, -49.0), Vector3(cx - 0.6, top + 0.42, -48.8), Color("2f6a4a") if i == 2 else Color("2b2d33"), 1.0, 0.0, false)
		# a calendar and a corkboard on the side walls, the waste basket, a plant
		var left: float = edges[i] + (0.0 if i == 0 else 0.1)
		var right: float = edges[i + 1] - (0.0 if i == 2 else 0.1)
		k.block(Vector3(left, 1.4, -47.6), Vector3(left + 0.02, 1.9, -47.2), Wear.PAPER, 1.0, 0.0, false)
		k.block(Vector3(left + 0.02, 1.75, -47.58), Vector3(left + 0.025, 1.88, -47.22), r.home_primary(), 1.0, 0.0, false)
		corkboard(k, Vector3(right, 1.55, -47.0), Vector3(-1, 0, 0), 0.9, 0.6, i * 17 + 3)
		k.block(Vector3(cx - 0.75, 0, -51.0), Vector3(cx - 0.5, 0.3, -50.75), Color("3a3d44"), 1.0, 0.04)
		k.block(Vector3(cx - 0.72, 0.2, -50.97), Vector3(cx - 0.53, 0.29, -50.78), Wear.PAPER, 1.0, 0.0, false)
		if i != 1:
			plant(k, Vector3(b - 0.35, 0, -45.0) if i == 0 else Vector3(a + 0.35, 0, -45.0))
	# a coat stand in the director's office
	var cs := Vector3(-33.0, 0, -51.4)
	k.block(cs + Vector3(-0.2, 0, -0.2), cs + Vector3(0.2, 0.04, 0.2), Color("3a3d44"), 1.0, 0.0, false)
	k.block(cs + Vector3(-0.03, 0, -0.03), cs + Vector3(0.03, 1.8, 0.03), Color("6b4f33"), 1.0, 0.0)
	k.block(cs + Vector3(-0.15, 1.2, -0.12), cs + Vector3(0.15, 1.75, 0.0), Color("3a4a6a"), 1.0, 0.05, false)
	# the meeting room: binders and coffee cups on the table, a speakerphone
	for i in 5:
		var x := -42.8 + i * 1.4
		k.block(Vector3(x, 0.75, -57.0), Vector3(x + 0.08, 1.05, -56.75), [Color("1d3557"), Color("c8191e"), Color("eeeeea"), Color("e0b020"), Color("2f9a4f")][i], 1.0, 0.02, false)
		k.block(Vector3(x + 0.3, 0.75, -56.2), Vector3(x + 0.38, 0.85, -56.12), Color("eeeeea"), 1.0, 0.0, false)
	k.block(Vector3(-40.15, 0.75, -56.65), Vector3(-39.85, 0.8, -56.35), Color("2b2d33"), 1.0, 0.0, false)
	# the TV on its cart (worn and repaired), or a screen on the wall
	if k.age == VenueRoom.Age.RENOVATED:
		k.block(Vector3(r.x1 - 0.2, 1.1, -57.6), Vector3(r.x1 - 0.15, 1.85, -56.3), Color("1b1d22"), 1.0, 0.0, false)
	else:
		var tv := Vector3(-33.0, 0, -55.0)
		k.block(tv + Vector3(-0.4, 0, -0.3), tv + Vector3(0.4, 0.9, 0.3), Color("3a3d44"), 1.0, 0.03)
		k.block(tv + Vector3(-0.32, 0.9, -0.28), tv + Vector3(0.32, 1.4, 0.28), Color("2b2d33"), 1.0, 0.03)
		k.block(tv + Vector3(-0.33, 0.95, -0.22), tv + Vector3(-0.32, 1.35, 0.22), Color("3a4a5a"), 1.0, 0.0, false)  # the screen, facing the table
		k.block(tv + Vector3(-0.35, 0.5, -0.25), tv + Vector3(0.35, 0.6, 0.25), Color("1b1d22"), 1.0, 0.0, false)  # VCR
	clock(k, Vector3(-39.0, 2.4, r.z0 + 0.15), Vector3(0, 0, 1))
	k.prop("fire_extinguisher", Vector3(-35.2, 0, -52.3), 0.0)


## The front lobby: the pay phone, a lost-and-found box, plants, a rubber
## runner from the doors to the desk, a wet-floor sign on a worn day, the
## extinguisher cabinet and a pull station.
static func lobby(r: RecRoom, k: VenueKit) -> void:
	# a rubber runner from the main doors toward the desk (beside the walk line)
	k.block(Vector3(r.x0 + 2.2, 0, -38.3), Vector3(-38.6, 0.012, -36.9), Color("2c2d31").lightened(0.04), 2.0, 0.03, false)
	# the pay phone on the east wall by the hall opening
	var face := r.x1 - 0.15
	k.block(Vector3(face - 0.18, 1.05, -38.6), Vector3(face, 1.75, -38.15), Color("8f9498") if k.age != VenueRoom.Age.RENOVATED else Color("2b2d33"), 1.0, 0.03, false)
	k.block(Vector3(face - 0.2, 1.3, -38.55), Vector3(face - 0.18, 1.5, -38.4), Color("c8c0a8"), 1.0, 0.0, false)  # keypad
	k.block(Vector3(face - 0.26, 1.25, -38.3), Vector3(face - 0.18, 1.65, -38.2), Color("1b1d22"), 1.0, 0.0, false)  # handset
	k.block(Vector3(face - 0.22, 0.9, -38.27), Vector3(face - 0.2, 1.25, -38.25), Color("1b1d22"), 1.0, 0.0, false)  # cord
	k.block(Vector3(face - 0.35, 0.95, -38.65), Vector3(face, 1.0, -38.1), Color("3a3d44"), 1.0, 0.0, false)  # shelf
	k.block(Vector3(face - 0.33, 1.0, -38.6), Vector3(face - 0.05, 1.07, -38.3), Color("e8d890"), 1.0, 0.04, false)  # phone book
	# the lost and found
	k.block(Vector3(-36.2, 0, -32.0), Vector3(-35.6, 0.45, -31.5), Color("b08a5a"), 1.0, 0.05)
	for i in 4:
		k.block(Vector3(-36.15 + i * 0.13, 0.4, -31.95 + (i % 2) * 0.15), Vector3(-36.02 + i * 0.13, 0.55, -31.75 + (i % 2) * 0.15), [Color("c8191e"), Color("1d3557"), Color("eeeeea"), Color("2f9a4f")][i], 1.0, 0.06, false)
	plant(k, Vector3(r.x0 + 0.6, 0, -39.4))
	plant(k, Vector3(-42.5, 0, -30.55))
	if k.age == VenueRoom.Age.WORN:
		# a wet-floor sign left out by the doors, and a bucket under a drip
		var w := Vector3(r.x0 + 1.4, 0, -39.1)
		k.oriented(Transform3D(Basis(Vector3.RIGHT, 0.2) * Basis.from_scale(Vector3(0.3, 0.62, 0.02)), w + Vector3(0, 0.3, -0.06)), Color("f2c230"))
		k.oriented(Transform3D(Basis(Vector3.RIGHT, -0.2) * Basis.from_scale(Vector3(0.3, 0.62, 0.02)), w + Vector3(0, 0.3, 0.06)), Color("f2c230"))
	fire_cabinet(k, Vector3(face, 1.0, -33.0), Vector3(-1, 0, 0))
	pull_station(k, Vector3(r.x0 + 0.3, 1.3, -35.0), Vector3(1, 0, 0))
	clock(k, Vector3(-41.6, 3.2, r.z1 - 0.05), Vector3(0, 0, -1))


## Referees and first aid: whistles on hooks, a stripe shirt hung up, skates
## on the bench, towels, a fan and a mirror for the refs; the spine board,
## the scale, a small freezer of ice packs, the sharps box and a CPR poster
## for first aid.
static func officials(r: RecRoom, k: VenueKit) -> void:
	# refs: hooks with whistles on the west wall, a stripe shirt, skates, towels
	var hook_x := r.x0 + 0.15
	k.block(Vector3(hook_x, 1.6, -38.6), Vector3(hook_x + 0.04, 1.65, -36.6), Color("6b4f33"), 1.0, 0.0, false)
	for i in 5:
		var z := -38.4 + i * 0.42
		k.block(Vector3(hook_x + 0.04, 1.2, z), Vector3(hook_x + 0.05, 1.6, z + 0.02), Color("1b1d22"), 1.0, 0.0, false)  # lanyard
		k.block(Vector3(hook_x + 0.04, 1.15, z - 0.02), Vector3(hook_x + 0.08, 1.2, z + 0.05), Color("8f9498") if i % 2 == 0 else Color("1b1d22"), 1.0, 0.0, false)  # whistle
	for i in 6:
		k.block(Vector3(-10.0 + i * 0.07, 1.0, r.z1 - 0.2), Vector3(-9.93 + i * 0.07, 1.6, r.z1 - 0.18), Color("1b1d22") if i % 2 == 0 else Color("eeeeea"), 1.0, 0.0, false)  # a stripe shirt
	k.block(Vector3(-11.85, 0.45, -32.8), Vector3(-11.55, 0.6, -32.45), Color("1b1d22"), 1.0, 0.03, false)  # skates on the bench
	k.block(Vector3(-11.85, 0.45, -32.35), Vector3(-11.55, 0.6, -32.0), Color("1b1d22"), 1.0, 0.03, false)
	for i in 3:
		k.block(Vector3(-11.88, 0.45 + i * 0.06, -31.0), Vector3(-11.52, 0.5 + i * 0.06, -30.6), Color("eeeeea").darkened(0.05 * i), 1.0, 0.03, false)
	k.glass(Vector3(-9.62, 1.2, -36.5), Vector3(-9.6, 1.9, -35.7), false, Color(0.85, 0.9, 0.95, 0.5))  # a mirror on the partition
	k.block(Vector3(-12.6, 0, -38.9), Vector3(-12.2, 0.5, -38.5), Color("e8e8e2"), 1.0, 0.03)  # bar fridge
	# first aid: the spine board on the wall, scale, freezer, sharps, poster
	k.block(Vector3(-6.2, 0.3, -38.4), Vector3(-6.15, 2.1, -37.95), Color("e06a1a"), 1.0, 0.03, false)
	for y in [0.6, 1.2, 1.8]:
		k.block(Vector3(-6.22, y, -38.4), Vector3(-6.2, y + 0.06, -37.95), Color("1b1d22"), 1.0, 0.0, false)
	k.block(Vector3(-8.8, 0, -37.6), Vector3(-8.5, 0.06, -37.3), Color("8f9498"), 1.0, 0.0, false)  # scale
	k.block(Vector3(-8.7, 0.06, -37.6), Vector3(-8.6, 1.4, -37.55), Color("8f9498"), 1.0, 0.0, false)
	k.block(Vector3(-9.35, 0, -39.75), Vector3(-8.55, 0.85, -39.2), Color("eeeeea"), 1.0, 0.03)  # ice-pack freezer
	k.block(Vector3(-9.25, 0.85, -39.65), Vector3(-8.65, 0.87, -39.3), Color("b8bcc2"), 1.0, 0.0, false)
	k.block(Vector3(-6.2, 1.0, -34.6), Vector3(-6.15, 1.2, -34.4), Color("c8191e"), 1.0, 0.0, false)  # sharps
	k.block(Vector3(-9.38, 1.3, -34.5), Vector3(-9.37, 1.9, -34.0), Wear.PAPER, 1.0, 0.0, false)  # CPR poster
	k.block(Vector3(-9.37, 1.7, -34.45), Vector3(-9.365, 1.85, -34.05), Color("c8191e"), 1.0, 0.0, false)
	k.prop("fire_extinguisher", Vector3(-6.4, 0, -39.55), -PI * 0.5)


## Washrooms: paper towel dispensers and soap by the sinks, a hand dryer by
## each door, waste bins, toilet paper in the stalls, a grab bar in the end
## stall and a baby change table in the women's.
static func washrooms(r: RecRoom, k: VenueKit) -> void:
	var white := Color("e8e8e2") if k.age != VenueRoom.Age.WORN else Color("cfcbbd")
	var steel := Color("b8bcc2")
	for half in [[r.x0 + 0.15, -16.6, true], [-16.4, r.x1 - 0.15, false]]:
		var a: float = half[0]
		var b: float = half[1]
		var mens: bool = half[2]
		var sink_x := b - 0.35 if mens else a + 0.35
		var face := sink_x + (0.3 if mens else -0.3)
		var n := Vector3(-1, 0, 0) if mens else Vector3(1, 0, 0)
		for j in 2:
			var sz := -37.6 + j * 1.0
			k.block(Vector3(face, 1.0, sz - 0.05) + n * 0.0, Vector3(face, 1.15, sz + 0.05) + n * 0.06, white, 1.0, 0.0, false)  # soap
			k.block(Vector3(sink_x - 0.03, 0.9, sz - 0.02) + n * -0.15, Vector3(sink_x + 0.03, 1.0, sz + 0.02) + n * -0.15, steel, 1.0, 0.0, false)  # tap
		k.block(Vector3(face, 1.0, -35.5), Vector3(face, 1.45, -35.15) + n * 0.12, white, 1.0, 0.02, false)  # paper towels
		k.block(Vector3(face, 0, -35.5) + n * 0.02, Vector3(face, 0.6, -35.1) + n * 0.4, Color("7d8288"), 1.0, 0.04)  # waste bin
		# hand dryer on the hall wall beside the door
		var dx := a + 0.5 if mens else b - 0.6
		k.block(Vector3(dx, 1.1, r.z0 + 0.15), Vector3(dx + 0.3, 1.35, r.z0 + 0.35), white if k.age != VenueRoom.Age.RENOVATED else Color("2b2d33"), 1.0, 0.02, false)
		k.block(Vector3(dx + 0.1, 1.06, r.z0 + 0.25), Vector3(dx + 0.2, 1.1, r.z0 + 0.32), steel, 1.0, 0.0, false)
		# toilet paper in each stall, a grab bar in the end one
		var w := (b - a) / 3.0
		for i in 3:
			var sx := a + i * w
			k.block(Vector3(sx + 0.65, 0.65, -30.35), Vector3(sx + 0.78, 0.78, -30.2), steel, 1.0, 0.0, false)
			k.block(Vector3(sx + 0.67, 0.66, -30.38), Vector3(sx + 0.76, 0.76, -30.35), Wear.PAPER, 1.0, 0.0, false)
		k.block(Vector3(b - 0.06, 0.8, -31.5), Vector3(b, 0.84, -30.4), steel, 1.0, 0.0, false)
		if not mens:
			k.block(Vector3(b - 0.12, 0.85, -34.6), Vector3(b, 1.0, -33.8), Color("e8e0d0"), 1.0, 0.02, false)  # baby change table, folded
			k.block(Vector3(b - 0.13, 0.9, -34.3), Vector3(b - 0.12, 0.95, -34.1), Color("3fa0d0"), 1.0, 0.0, false)
	if k.age == VenueRoom.Age.WORN:
		k.block(Vector3(-18.0, 0, -34.0), Vector3(-17.6, 0.004, -33.4), Color("6a7a70"), 1.0, 0.0, false)  # a puddle by the tap


## The main hall: extinguisher cabinets and pull stations, a cork board of
## flyers, clocks, and water stains on the ceiling tiles when it's worn.
static func hall(r: RecRoom, k: VenueKit) -> void:
	if r.plan_id != "rec_hall":
		return
	for x in [-24.0, -3.2, 21.0]:
		fire_cabinet(k, Vector3(x, 1.0, r.z1 - 0.02), Vector3(0, 0, -1))
	for x in [-23.0, 12.0, 43.0]:
		pull_station(k, Vector3(x, 1.25, r.z0 + 0.02), Vector3(0, 0, 1))
	corkboard(k, Vector3(-8.5, 1.6, r.z0 + 0.02), Vector3(0, 0, 1), 1.6, 0.9, 41)
	corkboard(k, Vector3(29.0, 1.6, r.z1 - 0.02), Vector3(0, 0, -1), 1.4, 0.9, 43)
	clock(k, Vector3(5.0, 2.7, r.z1 - 0.02), Vector3(0, 0, -1))
	clock(k, Vector3(30.0, 2.7, r.z0 + 0.02), Vector3(0, 0, 1))
	if k.age == VenueRoom.Age.WORN:
		for i in 6:
			var x := r.x0 + 6.0 + i * 12.5 + posmod(hash(i), 300) / 100.0
			k.block(Vector3(x, r.h - 0.012, -42.8), Vector3(x + 0.6, r.h - 0.005, -42.1), Color("9a8a66"), 1.0, 0.1, false)
