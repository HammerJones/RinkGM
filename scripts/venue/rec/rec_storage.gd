extends RecRoom
## Two closets: the janitor's (mop sink, floor machine, cleaning stock) and
## the equipment store (pylons, spare nets, puck buckets, ball carts, mats).

const SPLIT := -3.5


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("6f6a60"), Color("7d7a72"), Color("8e8f90"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("a8a294"), Color("b4b0a6"), Color("cfd0cf"))


func furnish(k: VenueKit) -> void:
	partition(k, "z", SPLIT, z0, z1, paint(k))
	var steel := Color("8f9498")
	# janitor: mop sink in the corner, shelves of stock, the floor machine
	k.block(Vector3(-5.85, 0, -30.9), Vector3(-5.05, 0.35, -30.1), Color("b8bcc2"), 0.2, 0.03)
	k.block(Vector3(-4.9, 0, -31.0), Vector3(-4.5, 0.4, -30.6), Color("e0b020"), 0.2, 0.04)  # mop bucket
	k.block(Vector3(-4.72, 0.4, -30.82), Vector3(-4.68, 1.5, -30.78), Color("c9a46a"), 0.2, 0.0, false)
	shelves(k, Vector3(-5.85, 0, -35.8), Vector3(-5.4, 1.9, -32.0), 4, steel, [Color("3f6fa8"), Color("eeeeea"), Color("e0b020"), Color("2a7a4a")])
	k.block(Vector3(-4.5, 0, -36.5), Vector3(-3.9, 0.35, -35.9), Color("3a3d44"), 0.2, 0.04)  # floor buffer
	k.block(Vector3(-4.25, 0.35, -36.25), Vector3(-4.15, 1.1, -36.15), Color("6a6e74"), 0.2, 0.0, false)
	# equipment: shelves of pylons and buckets, nets on their sides, mats
	shelves(k, Vector3(-3.25, 0, -30.6), Vector3(-0.3, 2.0, -30.15), 4, steel, [Color("e06a1a"), Color("1b1d22"), Color("e0b020"), Color("3f6fa8")])
	shelves(k, Vector3(-0.6, 0, -37.8), Vector3(-0.15, 2.0, -31.2), 4, steel, [Color("e06a1a"), Color("eeeeea"), Color("1b1d22")])
	var red := k.aged(Color("c8191e"), 3)
	for i in 2:
		var z := -36.0 + i * 1.9
		# a spare goal frame lying on its back
		k.block(Vector3(-3.1, 0, z), Vector3(-1.3, 0.06, z + 0.06), red, 0.3, 0.0)
		k.block(Vector3(-3.1, 0, z + 1.1), Vector3(-1.3, 0.06, z + 1.16), red, 0.3, 0.0)
		k.block(Vector3(-3.1, 0, z), Vector3(-3.04, 0.06, z + 1.16), red, 0.3, 0.0)
		k.block(Vector3(-1.36, 0, z), Vector3(-1.3, 0.06, z + 1.16), red, 0.3, 0.0)
		k.block(Vector3(-3.04, 0.01, z + 0.06), Vector3(-1.36, 0.02, z + 1.1), Color("e8e8e2"), 0.3, 0.1, false)
	stack(k, Vector3(-3.3, 0, -32.6), Vector3(1.4, 0.06, 0.9), 8, Color("3f6fa8"))  # gym mats
