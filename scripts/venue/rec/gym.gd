extends RecRoom
## The gymnasium, the heart of the old Athletic Club: a hardwood court with
## its lines, a hoop at each end on wall arms, plain benches along the back
## wall under the high windows (the room is too tight for bleachers), the club's championship banners,
## exposed roof trusses and high-bay lights. The roof leaks when worn (the
## meeting room's whiteboard has it at number one) and a bucket catches it.

const CX := -15.0       # centre of the court
const CZ := -52.0
const HALF_L := 14.0    # court 28 x 13 m
const HALF_W := 6.5


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_BACK) < 0.05:
		var out := []
		for i in 8:
			out.append({"at": -29.5 + i * 4.0, "w": 2.4, "y0": 5.4, "y1": 7.2})
		return out
	return []


func bare_outer() -> bool:
	return true


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("b07a45"), Color("c99a5f"), Color("dcb27a"))


func floor_tile() -> float:
	return 0.8


func furnish(k: VenueKit) -> void:
	_planks(k)
	_lines(k)
	for end in [-1, 1]:
		_hoop(k, end)
	_benches(k)
	_banners(k)
	_trusses(k)
	# a ball cart, the volleyball posts and a stack of mats in the east corner
	k.block(Vector3(x1 - 1.4, 0, z1 - 1.2), Vector3(x1 - 0.6, 0.9, z1 - 0.5), Color("8f9498"), 0.3, 0.03)
	for i in 6:
		k.block(Vector3(x1 - 1.35 + (i % 3) * 0.25, 0.9, z1 - 1.1 + (i / 3) * 0.28), Vector3(x1 - 1.13 + (i % 3) * 0.25, 1.12, z1 - 0.88 + (i / 3) * 0.28), Color("e06a1a"), 0.1, 0.05, false)
	# shoot around at either hoop (PickupGame, the owner's kit): the rims and
	# backboards in venue space
	var rims := []
	for end in [-1, 1]:
		var board: float = CX + end * (HALF_L - 1.2)
		rims.append({"rim": [board - end * 0.38, 3.05, CZ], "board": board, "end": end})
	add_spot(k, VenueSpot.Kind.USE, "pickup_basketball", Vector3(x1 - 1.0, 1.0, z1 - 0.85), "Ball cart",
		{"pickup": "basketball", "hoops": rims, "verb": "SHOOT AROUND:"}, 1.6)
	for i in 2:
		k.block(Vector3(x1 - 0.5 - i * 0.2, 0, z0 + 1.0), Vector3(x1 - 0.4 - i * 0.2, 2.4, z0 + 1.1), Color("b8bcc2"), 0.3, 0.0)
	stack(k, Vector3(x0 + 0.4, 0, z1 - 1.6), Vector3(1.8, 0.08, 1.2), 6, Color("1d3557") if k.age != Age.WORN else Color("3a4a6a"))
	# the climbing rope, tied off to the wall
	k.block(Vector3(x0 + 2.4, 1.2, z0 + 0.4), Vector3(x0 + 2.45, h - 0.6, z0 + 0.45), Color("c9a46a"), 0.3, 0.0, false)
	if k.age == Age.WORN:
		# the roof leak: a stain on the floor and the bucket under the drip
		k.block(Vector3(-9.2, 0, -48.6), Vector3(-7.6, 0.004, -47.4), Color("7a5a3a"), 0.4, 0.1, false)
		k.block(Vector3(-8.6, 0, -48.2), Vector3(-8.2, 0.35, -47.8), Color("e0b020"), 0.2, 0.04)
		k.block(Vector3(-8.75, h - 0.1, -48.25), Vector3(-8.05, h - 0.01, -47.75), Color("6a5a44"), 0.3, 0.1, false)


## Lighter and darker boards, laid along the court.
func _planks(k: VenueKit) -> void:
	var base := floor_color(k)
	var z := z0 + 0.15
	var row := 0
	while z < z1 - 0.15:
		var x := x0 + 0.15 + (row % 3) * 0.7
		var j := 0
		while x < x1 - 0.15:
			var len := minf(2.1, x1 - 0.15 - x)
			if posmod(hash(Vector2i(row, j)), 3) == 0:
				var c := base.darkened(0.08) if posmod(hash(Vector2i(j, row)), 2) == 0 else base.lightened(0.06)
				if k.age == Age.WORN and posmod(hash(Vector2i(row * 3, j)), 7) == 0:
					c = base.darkened(0.25)  # dead spot
				k.block(Vector3(x, 0, z), Vector3(x + len, 0.003, z + 0.4), c, 2.2, 0.0, false)
			x += len
			j += 1
		z += 0.4
		row += 1


func _line(k: VenueKit, a: Vector2, b: Vector2, col: Color, w := 0.06) -> void:
	var d := b - a
	var mid := (a + b) * 0.5
	var basis := Basis(Vector3.UP, -d.angle()) * Basis.from_scale(Vector3(d.length(), 0.008, w))
	k.oriented(Transform3D(basis, Vector3(mid.x, 0.006, mid.y)), col)


func _arc(k: VenueKit, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color) -> void:
	for i in n:
		var t0 := lerpf(a0, a1, float(i) / n)
		var t1 := lerpf(a0, a1, float(i + 1) / n)
		_line(k, c + Vector2(cos(t0), sin(t0)) * r, c + Vector2(cos(t1), sin(t1)) * r, col)


func _lines(k: VenueKit) -> void:
	var col: Color = k.by_age(Color("e8e0c8"), Color("f0eee6"), Color("1b1d22"))
	var key: Color = k.by_age(Wear.OLD_ORANGE.darkened(0.1), Color("3f6fa8"), home_primary())
	var l := Vector2(CX - HALF_L, CZ - HALF_W)
	var r := Vector2(CX + HALF_L, CZ + HALF_W)
	_line(k, Vector2(l.x, l.y), Vector2(r.x, l.y), col)
	_line(k, Vector2(l.x, r.y), Vector2(r.x, r.y), col)
	_line(k, Vector2(l.x, l.y), Vector2(l.x, r.y), col)
	_line(k, Vector2(r.x, l.y), Vector2(r.x, r.y), col)
	_line(k, Vector2(CX, l.y), Vector2(CX, r.y), col)
	_arc(k, Vector2(CX, CZ), 1.8, 0.0, TAU, 24, col)
	for end in [-1, 1]:
		var bx: float = CX + end * HALF_L
		var ft: float = bx - end * 5.8
		# the painted key
		k.block(Vector3(minf(bx, ft), 0, CZ - 2.45), Vector3(maxf(bx, ft), 0.004, CZ + 2.45), key, 1.0, 0.03, false)
		_line(k, Vector2(ft, CZ - 2.45), Vector2(ft, CZ + 2.45), col)
		_arc(k, Vector2(ft, CZ), 1.8, PI * 0.5, PI * 1.5 if end > 0 else -PI * 0.5, 12, col)
		# the three-point line: straight from the baseline, then the arc
		var hoop := Vector2(bx - end * 1.575, CZ)
		var straight := 1.575 + sqrt(6.75 * 6.75 - 36.0)
		for s in [-1, 1]:
			_line(k, Vector2(bx, CZ + s * 6.0), Vector2(bx - end * straight, CZ + s * 6.0), col)
		var a := asin(6.0 / 6.75)
		if end > 0:
			_arc(k, hoop, 6.75, PI - a, PI + a, 20, col)
		else:
			_arc(k, hoop, 6.75, -a, a, 20, col)


func _hoop(k: VenueKit, end: int) -> void:
	var wall: float = x0 + 0.15 if end < 0 else x1 - 0.15
	var board: float = CX + end * (HALF_L - 1.2)
	var steel: Color = k.by_age(Color("6a6e74"), Color("8f9498"), Color("2b2d33"))
	# the wall arm (a truss) out to the backboard
	for y in [3.0, 4.2]:
		k.block(Vector3(minf(wall, board), y, CZ - 0.06), Vector3(maxf(wall, board), y + 0.1, CZ + 0.06), steel, 0.5, 0.0, false)
	k.block(Vector3(minf(wall, board), 3.0, CZ - 0.05), Vector3(minf(wall, board) + 0.08, 4.3, CZ + 0.05), steel, 0.5, 0.0, false)
	var white := Color("eeeeea") if k.age != Age.WORN else Color("d6d0be")
	k.block(Vector3(board - 0.03, 2.9, CZ - 0.9), Vector3(board + 0.03, 3.95, CZ + 0.9), white, 0.3, 0.02, false)
	k.block(Vector3(board - end * 0.035, 3.05, CZ - 0.3), Vector3(board - end * 0.04, 3.5, CZ + 0.3), Color("1b1d22"), 0.1, 0.0, false)
	var rim := Vector2(board - end * 0.38, CZ)
	for i in 10:
		var t0 := TAU * i / 10.0
		var t1 := TAU * (i + 1) / 10.0
		var p0 := rim + Vector2(cos(t0), sin(t0)) * 0.23
		var p1 := rim + Vector2(cos(t1), sin(t1)) * 0.23
		var d := p1 - p0
		k.oriented(Transform3D(Basis(Vector3.UP, -d.angle()) * Basis.from_scale(Vector3(d.length(), 0.03, 0.03)), Vector3((p0.x + p1.x) * 0.5, 3.05, (p0.y + p1.y) * 0.5)), Color("e06a1a"))
	# the net, a tapered white tube
	for i in 4:
		var rr := 0.21 - i * 0.03
		k.oriented(Transform3D(Basis.from_scale(Vector3(rr * 2.0, 0.1, rr * 2.0)), Vector3(rim.x, 2.98 - i * 0.1, rim.y)), Color(0.95, 0.95, 0.92, 0.5), true)
	# wall pads under the hoop
	var pad: Color = k.by_age(Color("3a4a6a"), Color("1d3557"), home_primary().darkened(0.2))
	k.block(Vector3(wall - end * 0.1, 0.1, CZ - 3.0), Vector3(wall, 2.0, CZ + 3.0), pad, 0.6, 0.04, false)


## Two long wooden benches against the back wall, either side of the exit,
## where the next team waits for winners.
func _benches(k: VenueKit) -> void:
	var wood: Color = k.by_age(Wear.OLD_WOOD, Color("b08050"), Color("c9a46a"))
	var steel := Color("3a3d44")
	for bank in [[x0 + 2.0, -16.0], [-12.0, x1 - 2.0]]:
		k.aged_block(Vector3(bank[0], 0.42, z0 + 0.25), Vector3(bank[1], 0.47, z0 + 0.65), wood, 1.0, 0.06)
		var x: float = bank[0] + 0.2
		while x < bank[1]:
			k.block(Vector3(x, 0, z0 + 0.3), Vector3(x + 0.06, 0.42, z0 + 0.6), steel, 0.3, 0.0)
			x += 2.0


func _banners(k: VenueKit) -> void:
	var cloth: Color = k.by_age(Color("6a2a2a"), Color("7a2a35"), home_primary().darkened(0.15))
	var banners := [
		[["// 1974", Wear.OLD_GOLD], ["REGIONAL CHAMPS", VenueSign.WHITE], ["SR MEN BASKETBALL", VenueSign.WHITE]],
		[["// 1981", Wear.OLD_GOLD], ["VOLLEYBALL", VenueSign.WHITE], ["PROVINCIAL FINAL", VenueSign.WHITE]],
		[["// 1992", Wear.OLD_GOLD], ["MILLBROOK MAD MAX", VenueSign.WHITE], ["MASTERS HOOPS", VenueSign.WHITE]],
	]
	for i in banners.size():
		var x := -26.0 + i * 11.0
		wall_sign(k, banners[i], 17, 3, 0.03, Vector3(x, 6.0, z1 - 0.15), Vector3(0, 0, -1), "Banner%d" % i, cloth)
	wall_sign(k, [["// MILLBROOK ATHLETIC CLUB", Wear.OLD_GOLD]], 27, 1, 0.05, Vector3(CX, 7.1, z1 - 0.15), Vector3(0, 0, -1), "ClubBanner", Color("1b1d22"))
	# the score clock on the back wall
	k.aged_block(Vector3(CX - 1.5, 4.2, z0 + 0.15), Vector3(CX + 1.5, 5.2, z0 + 0.35), Color("2b2d33"), 0.5)
	wall_sign(k, [["HOME 00  GUEST 00", VenueSign.RED, true], ["   PERIOD 1", VenueSign.AMBER, true]], 17, 2, 0.022, Vector3(CX, 4.7, z0 + 0.36), Vector3(0, 0, 1), "GymClock")


func _trusses(k: VenueKit) -> void:
	var steel: Color = k.by_age(Color("5a5e64"), Color("6a6e74"), Color("2b2d33"))
	var x := x0 + 2.0
	while x < x1 - 1.0:
		k.block(Vector3(x - 0.08, h - 0.5, z0 + 0.2), Vector3(x + 0.08, h - 0.35, z1 - 0.2), steel, 1.0, 0.0, false)
		k.block(Vector3(x - 0.05, h - 1.1, z0 + 0.2), Vector3(x + 0.05, h - 1.0, z1 - 0.2), steel, 1.0, 0.0, false)
		x += 4.0


func lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("f0d9a8"), Color("f4f2ea"), Color("ffffff"))  # old metal halide is warm
	for i in 6:
		for j in 3:
			var x := x0 + 3.0 + i * 5.6
			var z := z0 + 3.0 + j * 5.0
			var c := lit
			if k.age == Age.WORN and posmod(i * 3 + j, 7) == 3:
				c = Color("4a4d48")
			k.glow(Vector3(x - 0.35, h - 1.3, z - 0.35), Vector3(x + 0.35, h - 1.2, z + 0.35), c)
	for x in [-26.0, -15.0, -4.0]:
		for z in [CZ - 3.5, CZ + 3.5]:
			rec_light(k, Vector3(x, h - 1.5, z), 13.0, 1.2)
