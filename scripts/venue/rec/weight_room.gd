extends RecRoom
## The weight room: a rubber floor, a real mirror along the gym wall, two
## power racks on their platforms, a bench press and a slide board facing the
## mirror, a leg press in the middle, the cable crossover, dumbbell rack and
## lat pulldown down the east wall, treadmills and bikes under the back
## windows, and (worn) the club's old universal machine by the door. Every
## machine is a Props kit piece (scripts/art/shop_props.gd) at the room's
## age. The machines are where Mechanics' USE spots (train_*, data
## {"train": machine}) stand; World places no spots here.

## [prop id, position, rotation, the USE spot that trains on it, where a
## player stands to use it (offset from the prop), the ages it is in].
## Machines face the mirror (-X) unless turned. A spot id of a machine
## Mechanics has no spot for yet is its would-be id (decor for now).
const ALL_AGES := [Age.WORN, Age.REPAIRED, Age.RENOVATED]
const MACHINES := [
	["squat_rack", Vector3(3.62, 0, -57.0), PI * 0.5, "train_squat_rack", Vector3(0.25, 0, 0), ALL_AGES],
	["squat_rack", Vector3(3.62, 0, -53.8), PI * 0.5, "train_squat_rack", Vector3(0.25, 0, 0), ALL_AGES],
	["bench_press", Vector3(3.55, 0, -50.6), PI * 0.5, "train_bench", Vector3(0.0, 0, 0.75), ALL_AGES],
	["slide_board", Vector3(3.2, 0, -47.6), PI * 0.5, "train_slide_board", Vector3(0.3, 0, 0), ALL_AGES],
	["leg_press", Vector3(11.4, 0, -53.6), PI * 0.5, "train_leg_press", Vector3(0.7, 0, 0.8), ALL_AGES],
	["cable_crossover", Vector3(15.45, 0, -57.4), PI * 0.5, "train_cable_crossover", Vector3(-1.1, 0, 0), ALL_AGES],
	["dumbbell_rack", Vector3(15.45, 0, -52.5), PI * 0.5, "train_dumbbells", Vector3(-0.8, 0, 0), ALL_AGES],
	["lat_pulldown", Vector3(15.15, 0, -49.6), PI * 0.5, "train_lat_pulldown", Vector3(-0.3, 0, 0), [Age.REPAIRED, Age.RENOVATED]],
	["universal_gym", Vector3(14.3, 0, -46.15), 0.0, "train_universal", Vector3(0, 0, -1.0), [Age.WORN]],
	["treadmill", Vector3(6.5, 0, -58.75), 0.0, "train_treadmill", Vector3(0, 0, 0.4), ALL_AGES],
	["stationary_bike", Vector3(8.2, 0, -59.15), 0.0, "train_bike", Vector3(0, 0, 0.2), ALL_AGES],
	["treadmill", Vector3(9.9, 0, -58.75), 0.0, "train_treadmill", Vector3(0, 0, 0.4), ALL_AGES],
	["stationary_bike", Vector3(11.6, 0, -59.15), 0.0, "train_bike", Vector3(0, 0, 0.2), ALL_AGES],
	["treadmill", Vector3(13.3, 0, -58.75), 0.0, "train_treadmill", Vector3(0, 0, 0.4), ALL_AGES],
]


## Where a player stands to use each machine at `age`: spot id -> Array of
## Vector3 (room-local, on the floor). For Mechanics' train_* spots.
static func machine_spots(age: int) -> Dictionary:
	var out := {}
	for mc: Array in MACHINES:
		if not (mc[5] as Array).has(age):
			continue
		var id: String = mc[3]
		var at: Vector3 = mc[1]
		var off: Vector3 = mc[4]
		if not out.has(id):
			out[id] = []
		(out[id] as Array).append(at + off)
	return out


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_BACK) < 0.05:
		return [{"at": 5.5, "w": 3.0, "y0": 1.0, "y1": 2.5}, {"at": 12.5, "w": 3.0, "y0": 1.0, "y1": 2.5}]
	return []


func floor_color(k: VenueKit) -> Color:
	return Wear.RUBBER.lightened(k.by_age(0.14, 0.1, 0.06))


func furnish(k: VenueKit) -> void:
	_mirror(k)
	_floor(k)
	_machines(k)
	k.prop("plate_tree", Vector3(5.6, 0, -55.4))
	k.prop("plate_tree", Vector3(13.4, 0, -55.6))
	_utility_bench(k, Vector3(13.6, 0, -52.5))
	_walls(k)
	k.prop("trash_can", Vector3(x1 - 0.4, 0, z1 - 0.5), PI)
	k.prop("fire_extinguisher", Vector3(x1 - 0.2, 0, z1 - 1.3), PI * 0.5)


## The machines at this age (MACHINES), each a solid kit prop.
func _machines(k: VenueKit) -> void:
	for mc: Array in MACHINES:
		if (mc[5] as Array).has(k.age):
			k.prop(mc[0], mc[1], mc[2])


## The mirror wall on the gym side (#30): framed glass a few centimetres off
## the wall (it used to sit in the wall), and a PlanarMirror that reflects
## while someone is in the room looking at it.
func _mirror(k: VenueKit) -> void:
	var face := x0 + 0.15  # the wall's inside face
	var z_a := -58.6
	var z_b := -46.4
	var y_a := 0.35
	var y_b := 2.35
	var trim: Color = k.by_age(Color("8f9498"), Color("b9c0c6"), Color("2b2d33"))
	k.block(Vector3(face, y_a, z_a), Vector3(face + 0.03, y_b, z_b), Color("1b1d22"), 2.0, 0.0, false)  # backing
	k.block(Vector3(face, y_a - 0.06, z_a - 0.05), Vector3(face + 0.06, y_a, z_b + 0.05), trim, 2.0, 0.02, false)
	k.block(Vector3(face, y_b, z_a - 0.05), Vector3(face + 0.06, y_b + 0.06, z_b + 0.05), trim, 2.0, 0.02, false)
	k.block(Vector3(face, y_a, z_a - 0.05), Vector3(face + 0.06, y_b, z_a), trim, 2.0, 0.02, false)
	k.block(Vector3(face, y_a, z_b), Vector3(face + 0.06, y_b, z_b + 0.05), trim, 2.0, 0.02, false)
	k.collider(Vector3(face, 0, z_a), Vector3(face + 0.07, y_b, z_b))
	var m := PlanarMirror.make(Vector2(z_b - z_a, y_b - y_a), 10.0)
	m.pixels_per_metre = 200.0
	m.max_pixels = 2560
	m.position = Vector3(face + 0.035, (y_a + y_b) * 0.5, (z_a + z_b) * 0.5)
	m.rotation.y = PI * 0.5  # the glass faces +X, into the room
	k.add(m)
	if k.age == Age.WORN:
		# a crack across one corner, taped
		k.oriented(Transform3D(Basis(Vector3.RIGHT, 0.5) * Basis.from_scale(Vector3(0.01, 0.6, 0.05)), Vector3(face + 0.045, 2.0, -47.2)), Wear.DUCT_TAPE)


## Rubber tile seams, scuffs where plates get dropped, a rolled mat.
func _floor(k: VenueKit) -> void:
	var seam: Color = Wear.RUBBER.darkened(0.3)
	var x := x0 + 1.0
	while x < x1 - 0.5:
		k.block(Vector3(x - 0.01, 0, z0 + 0.15), Vector3(x + 0.01, 0.003, z1 - 0.15), seam, 4.0, 0.0, false)
		x += 1.0
	if k.age != Age.RENOVATED:
		for i in 10:
			var p := Vector2(3.0 + posmod(hash(Vector2i(i, 3)), 300) / 100.0, -58.5 + posmod(hash(Vector2i(i, 4)), 600) / 100.0)
			k.block(Vector3(p.x, 0, p.y), Vector3(p.x + 0.25, 0.004, p.y + 0.18), Color("5a5a56"), 1.0, 0.0, false)
	# a rolled stretching mat and a foam roller by the slide board
	k.block(Vector3(5.0, 0, -46.4), Vector3(5.7, 0.22, -46.15), k.by_age(Color("3a4a6a"), Color("1d3557"), Color("2a9d8f")), 1.0, 0.03)
	k.block(Vector3(5.0, 0, -45.9), Vector3(5.6, 0.15, -45.75), Color("2b2d33"), 1.0, 0.03, false)


## A flat utility bench in front of the dumbbells.
func _utility_bench(k: VenueKit, p: Vector3) -> void:
	var frame: Color = k.by_age(Color("5a5e64"), Color("2b2d33"), Wear.NAVY)
	var pad: Color = k.by_age(Color("6a2a2a"), Color("1b1d22"), Color("1b1d22"))
	k.block(p + Vector3(-0.15, 0, -0.6), p + Vector3(0.15, 0.08, 0.6), frame, 1.0, 0.03, false)
	k.block(p + Vector3(-0.04, 0.08, -0.5), p + Vector3(0.04, 0.38, 0.5), frame, 1.0, 0.03, false)
	k.block(p + Vector3(-0.15, 0.38, -0.6), p + Vector3(0.15, 0.46, 0.6), pad, 1.0, 0.03)
	k.collider(p + Vector3(-0.15, 0, -0.6), p + Vector3(0.15, 0.46, 0.6))


## Wall dressing: a clock, the workout board, posters, a towel bin and spray
## station, a water fountain, and a fan (the worn room's only air).
func _walls(k: VenueKit) -> void:
	# clock over the mirror
	k.block(Vector3(x0 + 0.15, 2.65, -52.75), Vector3(x0 + 0.2, 3.05, -52.35), Color("eeeeea"), 1.0, 0.0, false)
	k.block(Vector3(x0 + 0.2, 2.84, -52.6), Vector3(x0 + 0.21, 2.86, -52.4), Color("1b1d22"), 1.0, 0.0, false)
	# posters on the back wall between the windows
	var posters := [Color("c8191e"), Color("1d3557"), Color("e0b020")]
	for i in 3:
		var px := 8.3 + i * 0.7
		var c: Color = posters[i]
		k.block(Vector3(px, 1.3, z0 + 0.15), Vector3(px + 0.5, 2.0, z0 + 0.17), k.aged(c, i), 1.0, 0.03, false)
		k.block(Vector3(px + 0.08, 1.45, z0 + 0.17), Vector3(px + 0.42, 1.8, z0 + 0.175), Color("eeeeea").darkened(0.1 * i), 1.0, 0.0, false)
	# towel bin and the wipe-down station by the door
	k.block(Vector3(x1 - 1.6, 0, z1 - 0.65), Vector3(x1 - 1.0, 0.8, z1 - 0.2), k.by_age(Color("7d8288"), Color("2b2d33"), Wear.NAVY), 1.0, 0.04)
	k.block(Vector3(x1 - 1.55, 0.8, z1 - 0.6), Vector3(x1 - 1.05, 0.88, z1 - 0.25), Color("eeeeea"), 1.0, 0.06, false)
	k.block(Vector3(x1 - 2.6, 0.9, z1 - 0.2), Vector3(x1 - 2.0, 1.4, z1 - 0.15), Color("b8bcc2"), 1.0, 0.03, false)
	k.block(Vector3(x1 - 2.5, 1.0, z1 - 0.28), Vector3(x1 - 2.4, 1.25, z1 - 0.2), Color("3fa0d0"), 1.0, 0.0, false)
	k.block(Vector3(x1 - 2.25, 1.0, z1 - 0.28), Vector3(x1 - 2.1, 1.12, z1 - 0.2), Color("eeeeea"), 1.0, 0.0, false)
	# drinking fountain
	var steel: Color = Color("b8bcc2") if k.age != Age.WORN else Color("9a9ea2")
	k.block(Vector3(x1 - 4.2, 0.75, z1 - 0.45), Vector3(x1 - 3.6, 0.95, z1 - 0.15), steel, 1.0, 0.03)
	k.block(Vector3(x1 - 4.0, 0, z1 - 0.3), Vector3(x1 - 3.8, 0.75, z1 - 0.15), steel.darkened(0.2), 1.0, 0.03)
	if k.age == Age.WORN:
		# a box fan on a chair in the corner, pointed at the racks
		k.block(Vector3(x0 + 0.5, 0, z1 - 0.9), Vector3(x0 + 0.95, 0.45, z1 - 0.45), Color("7d5a3a"), 1.0, 0.05)
		k.block(Vector3(x0 + 0.5, 0.45, z1 - 0.8), Vector3(x0 + 0.95, 0.95, z1 - 0.65), Color("c9c0a8"), 1.0, 0.04)
		k.block(Vector3(x0 + 0.55, 0.5, z1 - 0.81), Vector3(x0 + 0.9, 0.9, z1 - 0.8), Color("3a3d44"), 1.0, 0.0, false)
	else:
		# wall fans high on the east wall
		for z in [-56.0, -50.0]:
			k.block(Vector3(x1 - 0.3, h - 0.9, z - 0.3), Vector3(x1 - 0.15, h - 0.3, z + 0.3), Color("2b2d33"), 1.0, 0.03, false)
	wall_sign(k, [["// WEIGHT ROOM", VenueSign.AMBER], ["RE-RACK YOUR WEIGHTS", VenueSign.WHITE, true], ["WIPE DOWN AFTER USE", VenueSign.WHITE, true]], 20, 3, 0.022, Vector3(x1 - 0.15, 2.6, -46.4), Vector3(-1, 0, 0), "WeightRules")
