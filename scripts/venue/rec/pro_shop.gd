extends RecRoom
## Bev's Edge & Tape, the pro shop (docs/world/PROSHOP.md): display windows on
## the hall, a wall of skates, a stick rack, tape and puck islands, the
## counter and, behind it, the sharpening bench that is the real business.


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_HALL_S) < 0.05:
		return [{"at": -29.5, "w": 3.0, "y0": 1.0, "y1": 2.4}, {"at": -22.5, "w": 3.0, "y0": 1.0, "y1": 2.4}]
	return []


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("5a4636"), Color("3c4656"), Color("2f3540"))


func plate_color() -> Color:
	return VenueSign.AMBER


## At the till and at the sharpening bench.
func places() -> Dictionary:
	return {"pro_shop": [Vector3(-26.0, 0, -34.4), Vector3(-25.7, 0, -31.6)]}


func furnish(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("6b4f33"), Color("7a5c3c"), Color("2a2e36"))
	var steel := Color("8f9498")
	# the counter across the back, the till on it
	k.aged_block(Vector3(-28.6, 0, -33.6), Vector3(-23.4, 1.0, -33.0), wood, 0.5)
	k.block(Vector3(-28.7, 1.0, -33.7), Vector3(-23.3, 1.05, -32.9), k.by_age(Color("c9b48a"), Color("d6c39a"), Color("e8e6e1")), 0.5, 0.03, false)
	k.block(Vector3(-27.6, 1.05, -33.5), Vector3(-27.1, 1.3, -33.1), Color("2b2d33"), 0.2, 0.03, false)
	# the sharpening bench: a grinder, its dust hood, a rack of skates waiting
	k.aged_block(Vector3(-27.0, 0, -30.85), Vector3(-24.4, 0.9, -30.15), steel.darkened(0.15), 0.4)
	k.block(Vector3(-26.4, 0.9, -30.75), Vector3(-25.4, 1.35, -30.25), Color("3a5f8a") if k.age != Age.WORN else Color("4a5a6a"), 0.2, 0.04)
	k.block(Vector3(-26.0, 1.35, -30.7), Vector3(-25.8, 1.55, -30.3), Color("c9ccd1"), 0.1, 0.0, false)  # the wheel
	k.block(Vector3(-24.9, 0.9, -30.7), Vector3(-24.5, 1.1, -30.3), Color("b8312f"), 0.1, 0.03, false)  # the jig
	for i in 6:
		var x := -29.6 + i * 0.32
		k.block(Vector3(x, 0.9, -30.6), Vector3(x + 0.12, 1.15, -30.3), Color("1b1d22"), 0.1, 0.04, false)
	k.aged_block(Vector3(-29.8, 0, -30.85), Vector3(-27.6, 0.9, -30.15), wood.darkened(0.2), 0.4)
	_skate_wall(k)
	_stick_rack(k)
	# islands: tape, laces, pucks; gloves and helmets
	var tape := [Color("eeeeea"), Color("1b1d22"), Color("3f6fa8"), Color("c8191e"), Color("e0b020")]
	shelves(k, Vector3(-30.0, 0, -37.6), Vector3(-27.8, 1.3, -36.9), 3, steel, tape)
	shelves(k, Vector3(-24.2, 0, -37.6), Vector3(-22.0, 1.3, -36.9), 3, steel, [Color("1b1d22"), Color("6a6e74"), Color("c8191e"), Color("1d3557")])
	# a jersey rail by the window
	k.block(Vector3(-31.0, 1.75, -38.6), Vector3(-28.0, 1.8, -38.55), Color("c9ccd1"), 0.3, 0.0, false)
	for i in 8:
		var c: Color = [home_primary(), Color("1d3557"), Color("e0b020"), Color("2a7a4a"), Color("eeeeea")][i % 5]
		var x := -30.9 + i * 0.36
		k.block(Vector3(x, 1.0, -38.75), Vector3(x + 0.3, 1.75, -38.4), k.aged(c, i), 0.2, 0.05, false)
	k.collider(Vector3(-31.0, 1.0, -38.75), Vector3(-28.0, 1.8, -38.4))
	# signs: the shop name over the counter, the price board
	# the shop's painted arrow board over the counter, and Bev's chalkboard:
	# hollows, prices and her opinions
	readable(k, "sign_bev_arrow", Vector3(-26.0, 2.5, -30.0), Vector3(0, 0, -1))
	readable(k, "bev_chalkboard", Vector3(-22.95, 1.8, -30.0), Vector3(0, 0, -1))


## Shelves of skate boxes on the west wall.
func _skate_wall(k: VenueKit) -> void:
	var boxes := [Color("1b1d22"), Color("c8191e"), Color("eeeeea"), Color("3a3d44"), Color("e0b020")]
	shelves(k, Vector3(x0 + 0.15, 0, -38.8), Vector3(x0 + 0.6, 2.2, -31.4), 5, Color("7d8288"), boxes)


## A rack of sticks against the east wall, blades down.
func _stick_rack(k: VenueKit) -> void:
	var xw := x1 - 0.15
	k.block(Vector3(xw - 0.25, 1.35, -38.6), Vector3(xw, 1.4, -31.6), Color("3a3d44"), 0.5, 0.0)
	k.block(Vector3(xw - 0.25, 0, -38.6), Vector3(xw, 0.12, -31.6), Color("3a3d44"), 0.5, 0.0)
	var cols := [Color("1b1d22"), Color("2b2d33"), Color("d0202a"), Color("eeeeea"), Color("c9a46a"), Color("3f6fa8")]
	for i in 34:
		var z := -38.45 + i * 0.2
		var c: Color = cols[posmod(hash(i * 7), cols.size())]
		if k.age == Age.WORN and i % 3 == 0:
			c = Wear.OLD_WOOD  # old wooden sticks nobody buys
		k.block(Vector3(xw - 0.18, 0.12, z), Vector3(xw - 0.15, 1.6, z + 0.03), c, 0.3, 0.04, false)
		k.block(Vector3(xw - 0.28, 0.12, z), Vector3(xw - 0.15, 0.2, z + 0.03), c, 0.1, 0.0, false)  # the blade
