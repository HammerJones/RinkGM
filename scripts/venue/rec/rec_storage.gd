extends RecRoom
## Two closets: the janitor's (mop sink, floor machine, cleaning stock) and
## the equipment store (pylons, spare nets, puck buckets, ball carts, mats),
## which has double doors out to the rink for the nets.

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
	shelves(k, Vector3(-3.25, 0, -39.75), Vector3(-2.7, 2.0, -38.0), 4, steel, [Color("e06a1a"), Color("1b1d22"), Color("e0b020"), Color("3f6fa8")])
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
	_kit_detail(k)  # World: the equipment store's kit (#31)


# World: the equipment store's kit (#31) and a few janitor's things, added
# around the room's own shelves, frames and mats. Props kit pieces from
# scripts/art/shop_props.gd. The strip along the arena wall in front of the
# rink door (x -2.7..-0.8, within 1 m of z -30) and the hall door stay clear.
func _kit_detail(k: VenueKit) -> void:
	var wall := SPLIT + 0.1
	# the floor along the partition (x -3.4..-2.5, z -38..-34.4) stays clear
	# for real net racks; a ball cart and pucks stand off it
	k.prop("ball_bin", Vector3(-2.0, 0, -37.3), PI * 0.5)
	k.prop("puck_bucket", Vector3(-2.0, 0, -36.4), 0.3)
	# two pee-wee nets parked on the spare frames
	k.prop("mini_net", Vector3(-2.2, 0.06, -33.5), -PI * 0.5)
	k.prop("mini_net", Vector3(-2.9, 0.06, -33.5), -PI * 0.5)
	# the team bags piled on the mats, goalie gear in the corner
	k.prop("hockey_bags", Vector3(-2.6, 0.48, -32.15))
	k.prop("goalie_pads", Vector3(wall + 0.2, 0, -30.6), -PI * 0.5)
	k.prop("broom_bin", Vector3(-0.95, 0, -31.6))
	# pylons, cones and a pail of pucks on top of the east shelving
	k.prop("pylon_stack", Vector3(-0.38, 2.03, -36.6), PI * 0.5, false)
	k.prop("pylon_stack", Vector3(-0.38, 2.03, -35.2), PI * 0.5, false)
	k.prop("skate_cones", Vector3(-0.38, 2.03, -33.9), PI * 0.5, false)
	k.prop("puck_bucket", Vector3(-0.38, 2.03, -32.5), PI * 0.5, false)
	# a clipboard sign-out sheet by the door, and the sign
	var east := x1 - 0.15
	k.block(Vector3(east - 0.02, 1.2, -39.6), Vector3(east, 1.55, -39.35), Color("8a6a45"), 1.0, 0.0, false)
	k.block(Vector3(east - 0.025, 1.22, -39.58), Vector3(east - 0.02, 1.5, -39.37), Wear.PAPER, 1.0, 0.0, false)
	wall_sign(k, [["// EQUIPMENT", VenueSign.AMBER], ["SIGN IT OUT", VenueSign.WHITE, true]], 12, 2, 0.016, Vector3(-1.6, 2.6, z0 + 0.15), Vector3(0, 0, 1), "EquipmentSign")
	# janitor: the wringer and tap, a mop rack, the wet-floor sign, jugs
	k.block(Vector3(-5.6, 0.35, -30.2), Vector3(-5.5, 0.9, -30.1), Color("b8bcc2"), 1.0, 0.0, false)
	k.block(Vector3(-4.88, 0.4, -30.95), Vector3(-4.7, 0.55, -30.65), Color("3a3d44"), 1.0, 0.0, false)
	k.block(Vector3(-3.66, 1.5, -34.6), Vector3(-3.6, 1.58, -33.2), Color("3a3d44"), 1.0, 0.0, false)
	for i in 4:
		var z := -34.4 + i * 0.35
		k.block(Vector3(-3.7, 0.15, z), Vector3(-3.66, 1.55, z + 0.04), Color("c9a46a") if i % 2 == 0 else Color("3f6fa8"), 1.0, 0.0, false)
		k.block(Vector3(-3.76, 0.02, z - 0.08), Vector3(-3.62, 0.17, z + 0.12), Color("d8d4c8") if i % 2 == 0 else Color("2b2d33"), 1.0, 0.04, false)
	k.block(Vector3(-5.8, 0, -37.4), Vector3(-5.72, 0.65, -36.95), Color("f2c230"), 1.0, 0.03, false)
	k.block(Vector3(-5.73, 0.3, -37.3), Vector3(-5.71, 0.45, -37.05), Color("1b1d22"), 1.0, 0.0, false)
	for i in 3:
		k.block(Vector3(-5.8 + i * 0.25, 0, -39.6), Vector3(-5.6 + i * 0.25, 0.32, -39.4), Color("eeeeea").darkened(0.08 * i), 1.0, 0.04)
