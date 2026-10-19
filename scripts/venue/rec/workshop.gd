extends RecRoom
## The workshop and loading bay at the east end: where the building gets
## fixed. A roll-up door to the yard, a workbench with a pegboard, parts
## shelving, spare board panels and glass in racks, paint, pallets, and the
## old ice edger waiting for parts.


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("7a776e"), Color("858278"), Color("8e8f90"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("a8a294"), Color("b4b0a6"), Color("cfd0cf"))


func bare_outer() -> bool:
	return true


func plate_color() -> Color:
	return VenueSign.AMBER


func furnish(k: VenueKit) -> void:
	var steel := Color("8f9498")
	var wood: Color = k.by_age(Color("8a6a45"), Color("9a7a50"), Color("6a6e74"))
	var yellow := k.aged(Color("e0b020"), 5)
	# the old stencilled LOADING by the roll-up door, painted over: RECEIVING
	readable(k, "sign_receiving", Vector3(x1 - 0.15, 2.0, -50.6), Vector3(-1, 0, 0))
	# a painted keep-clear box inside the roll-up door
	for z in [-55.0, -51.0]:
		k.block(Vector3(x1 - 4.0, 0, z - 0.06), Vector3(x1 - 0.3, 0.005, z + 0.06), yellow, 1.0, 0.04, false)
	k.block(Vector3(x1 - 4.0, 0, -55.0), Vector3(x1 - 3.88, 0.005, -51.0), yellow, 1.0, 0.04, false)
	# the workbench on the north wall with its vice and pegboard
	k.aged_block(Vector3(33.0, 0, z0 + 0.15), Vector3(37.5, 0.9, z0 + 0.9), wood, 0.5)
	k.block(Vector3(33.0, 0.9, z0 + 0.15), Vector3(37.5, 0.95, z0 + 0.95), wood.darkened(0.2), 0.5, 0.0, false)
	k.block(Vector3(36.6, 0.95, z0 + 0.6), Vector3(37.0, 1.15, z0 + 0.95), Color("3f6fa8"), 0.1, 0.03, false)
	k.block(Vector3(33.0, 1.2, z0 + 0.15), Vector3(37.5, 2.4, z0 + 0.18), Color("c9a46a"), 0.6, 0.04, false)
	for i in 14:
		var x := 33.3 + i * 0.3
		k.block(Vector3(x, 1.45 + (i % 3) * 0.3, z0 + 0.18), Vector3(x + 0.05, 1.7 + (i % 3) * 0.3, z0 + 0.22), [Color("c8191e"), Color("2b2d33"), Color("b8bcc2")][i % 3], 0.1, 0.0, false)
	# parts shelving down the west wall
	var parts := [Color("6a6e74"), Color("e06a1a"), Color("3f6fa8"), Color("c9a46a"), Color("1b1d22")]
	shelves(k, Vector3(x0 + 0.15, 0, -58.5), Vector3(x0 + 0.75, 2.6, -51.0), 5, steel, parts)
	# spare board panels and rink glass in racks
	k.block(Vector3(38.5, 0, z0 + 0.3), Vector3(42.5, 0.15, z0 + 1.2), steel.darkened(0.2), 0.5, 0.0)
	for i in 5:
		var z := z0 + 0.4 + i * 0.16
		k.block(Vector3(38.6, 0.15, z), Vector3(41.0, 1.22, z + 0.04), Color("eeeeea"), 0.5, 0.02, false)
	for i in 4:
		var z := z0 + 0.45 + i * 0.18
		k.glass(Vector3(41.2, 0.15, z), Vector3(42.4, 1.6, z + 0.03), false)
	k.collider(Vector3(38.5, 0, z0 + 0.3), Vector3(42.5, 1.6, z0 + 1.2))
	# paint cans, a pallet stack, a drum
	for i in 6:
		k.block(Vector3(33.2 + i * 0.32, 0, -46.0), Vector3(33.45 + i * 0.32, 0.3, -45.75), [Color("eeeeea"), Color("c8191e"), Color("3f6fa8")][i % 3], 0.1, 0.03)
	stack(k, Vector3(x1 - 2.0, 0, -59.6), Vector3(1.2, 0.15, 1.0), 5, Wear.PLYWOOD)
	k.block(Vector3(x1 - 0.9, 0, -46.2), Vector3(x1 - 0.3, 0.9, -45.6), Color("2a5a8a"), 0.2, 0.04)
	# the old ice edger, half taken apart on the floor
	k.aged_block(Vector3(35.5, 0, -50.5), Vector3(36.3, 0.55, -49.7), Color("c8312f"), 0.2)
	k.block(Vector3(35.85, 0.55, -50.3), Vector3(35.95, 1.0, -50.2), Color("2b2d33"), 0.2, 0.0, false)
	k.block(Vector3(35.9, 1.0, -50.6), Vector3(36.0, 1.05, -49.6), Color("2b2d33"), 0.2, 0.0, false)
	k.block(Vector3(36.6, 0, -50.2), Vector3(36.9, 0.08, -49.9), Color("6a6e74"), 0.1, 0.0, false)  # its blade
	wall_sign(k, [["// WORKSHOP", VenueSign.AMBER], ["EYE PROTECTION", VenueSign.WHITE, true]], 14, 2, 0.022, Vector3(35.2, 3.0, z0 + 0.15), Vector3(0, 0, 1), "ShopSign")
	wall_sign(k, [["KEEP CLEAR", VenueSign.AMBER]], 10, 1, 0.03, Vector3(x1 - 0.3, 3.8, -53.0), Vector3(-1, 0, 0), "KeepClear")


func door_color(k: VenueKit, d: Array) -> Color:
	if d[6] == VenueDoor.Kind.ROLLUP:
		return k.by_age(Color("7a776e"), Color("8f9498"), Color("b9c0c6"))
	return super(k, d)
