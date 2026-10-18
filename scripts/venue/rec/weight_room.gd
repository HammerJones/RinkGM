extends RecRoom
## The weight room: rubber floor, a mirror wall, squat racks and benches, a
## dumbbell rack, plate trees, and a row of cardio machines under the back
## windows. Worn is the club's old universal machine and torn vinyl;
## renovated is a modern rack line in the club colour.


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_BACK) < 0.05:
		return [{"at": 5.5, "w": 3.0, "y0": 1.0, "y1": 2.5}, {"at": 12.5, "w": 3.0, "y0": 1.0, "y1": 2.5}]
	return []


func floor_color(k: VenueKit) -> Color:
	return Wear.RUBBER.lightened(k.by_age(0.14, 0.1, 0.06))


func furnish(k: VenueKit) -> void:
	var frame: Color = k.by_age(Color("5a5e64"), Color("2b2d33"), home_primary().darkened(0.2))
	var vinyl: Color = k.by_age(Color("6a2a2a"), Color("1b1d22"), Color("1b1d22"))
	var iron := Color("2b2d33")
	# the mirror wall (west, shared with the gym) with a rail
	k.glass(Vector3(x0 + 0.15, 0.3, -58.5), Vector3(x0 + 0.17, 2.4, -46.0), false, Color(0.85, 0.9, 0.95, 0.5))
	# three squat racks facing the mirror, a bench in each
	for i in 3:
		var z := -57.0 + i * 3.2
		var xa := x0 + 2.0
		for c in [[xa, z - 0.6], [xa, z + 0.6], [xa + 1.2, z - 0.6], [xa + 1.2, z + 0.6]]:
			k.block(Vector3(c[0] - 0.04, 0, c[1] - 0.04), Vector3(c[0] + 0.04, 2.3, c[1] + 0.04), frame, 0.5, 0.0, false)
		k.block(Vector3(xa - 0.04, 2.25, z - 0.64), Vector3(xa + 1.24, 2.3, z + 0.64), frame, 0.5, 0.0, false)
		k.collider(Vector3(xa - 0.05, 0, z - 0.65), Vector3(xa + 1.25, 2.3, z + 0.65))
		# the bar on the hooks with plates
		k.block(Vector3(xa + 0.3, 1.4, z - 1.0), Vector3(xa + 0.34, 1.44, z + 1.0), Color("b8bcc2"), 0.5, 0.0, false)
		for s in [-1, 1]:
			k.block(Vector3(xa + 0.12, 1.2, z + s * 0.85 - 0.04), Vector3(xa + 0.52, 1.64, z + s * 0.85 + 0.04), iron, 0.2, 0.02, false)
		k.block(Vector3(xa + 0.4, 0, z - 0.15), Vector3(xa + 1.6, 0.45, z + 0.15), vinyl, 0.3, 0.05)
	# dumbbell rack along the east wall
	k.aged_block(Vector3(x1 - 0.85, 0, -56.0), Vector3(x1 - 0.2, 0.75, -49.0), frame, 0.5)
	for i in 14:
		var z := -55.8 + i * 0.48
		var sz := 0.06 + 0.01 * (i / 2)
		for s in [-1, 1]:
			k.block(Vector3(x1 - 0.7 + (0.0 if s < 0 else 0.35), 0.75, z), Vector3(x1 - 0.7 + (0.0 if s < 0 else 0.35) + sz * 2.0, 0.75 + sz * 2.0, z + 0.3), iron, 0.1, 0.02, false)
	# plate trees
	for p in [Vector2(8.5, -55.0), Vector2(8.5, -48.5)]:
		k.block(Vector3(p.x - 0.03, 0, p.y - 0.03), Vector3(p.x + 0.03, 1.2, p.y + 0.03), frame, 0.3, 0.0)
		for j in 4:
			k.block(Vector3(p.x - 0.25, 0.2 + j * 0.25, p.y - 0.04), Vector3(p.x + 0.25, 0.6 + j * 0.25, p.y + 0.04), iron, 0.2, 0.02, false)
	# flat benches in the middle
	for i in 2:
		k.block(Vector3(10.5, 0, -54.0 + i * 3.5), Vector3(11.0, 0.45, -52.6 + i * 3.5), vinyl, 0.3, 0.05)
	# cardio under the windows: treadmills and bikes
	for i in 5:
		var x := x0 + 4.5 + i * 1.7
		if i % 2 == 0:
			k.block(Vector3(x - 0.4, 0, z0 + 0.6), Vector3(x + 0.4, 0.25, z0 + 2.4), iron, 0.3, 0.03)
			k.block(Vector3(x - 0.4, 0.25, z0 + 0.5), Vector3(x + 0.4, 1.3, z0 + 0.7), Color("3a3d44"), 0.3, 0.03, false)
			k.glow(Vector3(x - 0.2, 1.1, z0 + 0.71), Vector3(x + 0.2, 1.25, z0 + 0.72), Color("5fe0f0") if k.age != Age.WORN else Color("ff5f52"))
		else:
			k.block(Vector3(x - 0.2, 0, z0 + 0.8), Vector3(x + 0.2, 0.9, z0 + 1.9), Color("3a3d44"), 0.3, 0.03)
			k.block(Vector3(x - 0.15, 0.9, z0 + 1.5), Vector3(x + 0.15, 0.95, z0 + 1.8), vinyl, 0.2, 0.0, false)
	if k.age == Age.WORN:
		# the old universal machine in the corner by the door
		var gold := k.aged(Color("8a6a2a"), 2)
		for px in [x1 - 2.6, x1 - 0.7]:
			k.block(Vector3(px, 0, z1 - 2.6), Vector3(px + 0.1, 2.2, z1 - 2.5), gold, 0.5, 0.0)
		k.block(Vector3(x1 - 2.6, 2.1, z1 - 2.6), Vector3(x1 - 0.6, 2.2, z1 - 2.5), gold, 0.5, 0.0, false)
		k.block(Vector3(x1 - 1.9, 0, z1 - 2.6), Vector3(x1 - 1.4, 1.3, z1 - 2.35), iron, 0.2, 0.03)  # the weight stack
		k.block(Vector3(x1 - 2.2, 0, z1 - 2.3), Vector3(x1 - 1.0, 0.45, z1 - 1.6), vinyl, 0.3, 0.05)
	wall_sign(k, [["// WEIGHT ROOM", VenueSign.AMBER], ["RE-RACK YOUR WEIGHTS", VenueSign.WHITE, true], ["NO CHALK", VenueSign.WHITE, true]], 20, 3, 0.022, Vector3(x1 - 0.15, 2.6, -52.5), Vector3(-1, 0, 0), "WeightRules")
	k.prop("trash_can", Vector3(x1 - 0.4, 0, z1 - 0.5), PI)
