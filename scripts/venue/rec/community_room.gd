extends RecRoom
## The community hall: the room the town rents for bingo, banquets, minor
## hockey's awards night and the odd wedding. A stage with a curtain at the
## back, folding tables and stacked chairs, a kitchen counter through a
## pass-through and the bingo board.


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("8a7a5a"), Color("9c9070"), Color("a8a39a"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("b8a080"), Color("cfc0a0"), Color("e8e2d8"))


func furnish(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("6b4f33"), Color("7a5c3c"), Color("3a3d44"))
	# the stage across the back with steps up at one end
	k.aged_block(Vector3(x0 + 0.15, 0, z0 + 0.15), Vector3(x1 - 0.15, 0.8, z0 + 4.0), wood, 0.6)
	var steps := 4
	for i in steps:
		var y := 0.8 * (i + 1) / steps
		k.block(Vector3(x1 - 2.2, 0, z0 + 4.0 + (steps - 1 - i) * 0.3), Vector3(x1 - 1.0, y, z0 + 4.0 + (steps - i) * 0.3), wood.darkened(0.1), 0.5, 0.04)
	var curtain: Color = k.by_age(Color("6a2a2a"), Color("8a2a2a"), home_primary().darkened(0.2))
	for i in 24:
		var x := x0 + 0.3 + i * 0.64
		var fold := 0.06 * (i % 2)
		k.block(Vector3(x, 0.8, z0 + 0.4 + fold), Vector3(x + 0.62, h - 0.2, z0 + 0.55 + fold), curtain.darkened(0.06 * (i % 3)), 1.0, 0.03, false)
	k.block(Vector3(x0 + 0.15, h - 0.6, z0 + 3.9), Vector3(x1 - 0.15, h, z0 + 4.1), wood.darkened(0.3), 1.0, 0.0, false)  # proscenium
	# a lectern and a piano on stage
	k.block(Vector3(23.6, 0.8, z0 + 2.6), Vector3(24.4, 2.0, z0 + 3.1), wood.lightened(0.1), 0.3, 0.04)
	k.aged_block(Vector3(x0 + 1.0, 0.8, z0 + 1.0), Vector3(x0 + 2.6, 2.1, z0 + 1.6), Color("1b1d22"), 0.4)
	# folding tables in two rows, chairs stacked along the wall
	for row in 2:
		for col in 3:
			var tx := x0 + 2.2 + col * 4.4
			var tz := -52.5 + row * 3.2
			table(k, Vector3(tx, 0, tz), Vector3(tx + 2.4, 0, tz + 0.8), 0.74, Color("d8d4c4"))
	for i in 4:
		stack(k, Vector3(x0 + 0.3, 0, -47.5 + i * 0.6), Vector3(0.45, 0.1, 0.45), 10, Color("6a6e74"))
	# the kitchen counter through a pass-through in the east wall
	k.aged_block(Vector3(x1 - 0.8, 0, -51.5), Vector3(x1 - 0.15, 0.95, -46.0), Color("7d8288"), 0.4)
	k.block(Vector3(x1 - 0.85, 0.95, -51.6), Vector3(x1 - 0.1, 1.0, -45.9), k.by_age(Color("c9b48a"), Color("d6c39a"), Color("e8e6e1")), 0.4, 0.03, false)
	k.block(Vector3(x1 - 0.6, 1.0, -50.6), Vector3(x1 - 0.3, 1.5, -50.2), Color("b8bcc2"), 0.2, 0.03, false)  # the coffee urn
	k.block(Vector3(x1 - 0.9, 0, -45.6), Vector3(x1 - 0.15, 1.8, -44.6), Color("e8e8e2"), 0.2, 0.03)  # fridge
	# the bingo board and the events board
	var bingo := [["// BINGO", VenueSign.AMBER], ["B 7  I 22  N 41", VenueSign.CYAN, true], ["G 53  O 68", VenueSign.CYAN, true]]
	wall_sign(k, bingo, 15, 3, 0.03, Vector3(x0 + 0.15, 2.6, -52.0), Vector3(1, 0, 0), "BingoBoard")
	var events := [
		["// THIS MONTH", VenueSign.AMBER], ["THU 7PM   BINGO", VenueSign.WHITE, true],
		["SAT       AWARDS NIGHT", VenueSign.WHITE, true], ["SUN 10AM  CRAFT FAIR", VenueSign.WHITE, true],
	]
	wall_sign(k, events, 22, 4, 0.02, Vector3(20.0, 1.8, z1 - 0.15), Vector3(0, 0, -1), "EventsBoard")
	# bunting over the stage when it's been looked after
	if k.age != Age.WORN:
		for i in 20:
			var c: Color = [home_primary(), home_secondary(), Color("e0b020")][i % 3]
			var x := x0 + 0.6 + i * 0.75
			k.block(Vector3(x, h - 1.0 - 0.15 * absf(sin(i * 0.6)), z0 + 4.2), Vector3(x + 0.3, h - 0.8 - 0.15 * absf(sin(i * 0.6)), z0 + 4.23), c, 0.2, 0.0, false)
	RecDetail.community_room(self, k)  # World: detail pass (#23, #27)
