extends RecRoom
## The referees' room (west) and the first aid room (east). The refs get a
## bank of lockers, a bench and a whistle board; first aid has a cot, a
## cabinet, a sink and the AED on the wall.

const SPLIT := -9.5


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("8a8676"), Color("9a9a90"), Color("b9bcbf"))


func furnish(k: VenueKit) -> void:
	partition(k, "z", SPLIT, z0, z1, paint(k))
	_refs(k)
	_first_aid(k)
	RecDetail.officials(self, k)  # World: detail pass (#23, #27)


func _refs(k: VenueKit) -> void:
	for i in 2:
		k.prop("lockers", Vector3(-12.85 + 0.23, 0, -31.0 - i * 1.2), -PI * 0.5)
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), Color("2a2e36"))
	bench(k, Vector3(-11.9, 0, -33.4), Vector3(-11.5, 0, -30.4), wood)
	k.block(Vector3(-10.4, 0, -30.6), Vector3(-9.7, 0.9, -30.1), Color("7d8288"), 0.3, 0.04)  # a laundry bin of stripes
	for i in 5:
		k.block(Vector3(-10.35 + i * 0.13, 0.9, -30.5), Vector3(-10.25 + i * 0.13, 1.05, -30.2), Color("1b1d22") if i % 2 == 0 else Color("eeeeea"), 0.1, 0.0, false)
	var board := [["// OFFICIALS", VenueSign.WHITE], ["----", VenueSign.DIM], ["SAT 7PM  SR AAA", VenueSign.CYAN, true], ["SUN 9AM  U13 A", VenueSign.CYAN, true]]
	wall_sign(k, board, 15, 4, 0.016, Vector3(-11.3, 1.7, z0 + 0.15), Vector3(0, 0, 1), "RefBoard")
	rec_light(k, Vector3(-11.2, h - 0.4, -35.0), 5.5)


func _first_aid(k: VenueKit) -> void:
	var white := Color("e8e8e2") if k.age != Age.WORN else Color("cfcbbd")
	# the cot, sheet and pillow
	k.block(Vector3(-9.1, 0, -32.6), Vector3(-8.3, 0.6, -30.6), Color("7d8288"), 0.4, 0.03)
	k.block(Vector3(-9.05, 0.6, -32.55), Vector3(-8.35, 0.68, -30.65), white, 0.4, 0.03, false)
	k.block(Vector3(-9.0, 0.68, -31.0), Vector3(-8.4, 0.78, -30.7), Color("dfe8ef"), 0.2, 0.02, false)
	# cabinet with the red cross, a sink, a chair
	k.aged_block(Vector3(-6.6, 0, -33.8), Vector3(-6.15, 1.9, -32.2), white, 0.4)
	k.block(Vector3(-6.66, 1.3, -33.2), Vector3(-6.6, 1.5, -33.15), Color("d0202a"), 0.1, 0.0, false)
	k.block(Vector3(-6.66, 1.375, -33.3), Vector3(-6.6, 1.425, -33.05), Color("d0202a"), 0.1, 0.0, false)
	k.block(Vector3(-6.7, 0.8, -36.2), Vector3(-6.15, 0.9, -35.4), white, 0.2, 0.02)
	k.block(Vector3(-6.5, 0, -35.9), Vector3(-6.35, 0.8, -35.7), Color("b8bcc2"), 0.2, 0.0, false)
	k.block(Vector3(-8.0, 0, -36.0), Vector3(-7.55, 0.45, -35.55), Color("2b2d33"), 0.25, 0.05)
	# the AED in its green-lit box by the door
	k.block(Vector3(-9.25, 1.2, -39.0), Vector3(-9.38, 1.75, -38.5), Color("2a7a4a"), 0.2, 0.0, false)
	k.glow(Vector3(-9.24, 1.68, -38.95), Vector3(-9.23, 1.73, -38.55), Color("8cf26a"))
	wall_sign(k, [["// FIRST AID", VenueSign.RED]], 13, 1, 0.016, Vector3(-7.8, 2.2, z0 + 0.15), Vector3(0, 0, 1), "FirstAidSign")
	rec_light(k, Vector3(-7.8, h - 0.4, -35.0), 5.5)


func lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("e6eed8"), Color("f4f6f0"), Color("fff6e6"))
	for x in [-11.3, -7.8]:
		for z in [-37.0, -33.0]:
			k.glow(Vector3(x - 0.5, h - 0.05, z - 0.15), Vector3(x + 0.5, h - 0.01, z + 0.15), lit)
