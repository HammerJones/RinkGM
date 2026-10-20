extends RecRoom
## Bev's Edge & Tape, the pro shop (docs/world/PROSHOP.md; playtest notes
## #34, #35, #36). Display windows on the hall, the skate wall on the west
## wall (skates on hooks over shelves of boxes), the stick wall on the east
## wall (real sticks in divided racks, racked by brand), a Warlock A-frame on
## the floor, a barrel of Shorewood wood sticks, gloves and helmets on the
## arena wall, the counter with the till and its BACK IN 5 MIN card, the
## tape tower, puck and glove bins, a fitting bench with a foot measure, a
## jersey rail, posters, and through a door behind the counter the small
## back room: Old Bertha, the skate sharpener with its dust collector, and
## the racks of customers' skates waiting with their tags.

## The back room in the arena-side west corner: its east wall (x) and its
## north wall (z), and the door between it and the shop.
const BACK_X := -29.0
const BACK_Z := -33.3
const BACK_DOOR_Z := -31.0
const ARENA := -30.0  # the arena wall's face


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_HALL_S) < 0.05:
		return [{"at": -29.5, "w": 3.0, "y0": 1.0, "y1": 2.4}, {"at": -22.5, "w": 3.0, "y0": 1.0, "y1": 2.4}]
	return []


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("5a4636"), Color("3c4656"), Color("2f3540"))


func plate_color() -> Color:
	return VenueSign.AMBER


## Behind the till, and at the sharpener in the back room.
func places() -> Dictionary:
	return {"pro_shop": [Vector3(-26.8, 0, -32.4), Vector3(-30.3, 0, -31.3)]}


func furnish(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("6b4f33"), Color("7a5c3c"), Color("2a2e36"))
	var steel := Color("8f9498")
	_back_room(k, wood)
	_counter(k, wood)
	_skate_wall(k, steel)
	_stick_wall(k)
	_gloves_and_helmets(k, steel)
	_floor_stock(k, wood, steel)
	_posters(k)
	# the shop's painted arrow board over the counter's photo wall, and Bev's
	# chalkboard (hollows, prices and her opinions) on the back room
	# partition by the till, clear of the glove pegboard that hid it
	readable(k, "sign_bev_arrow", Vector3(-26.6, 2.8, ARENA), Vector3(0, 0, -1))
	readable(k, "bev_chalkboard", Vector3(BACK_X + 0.07, 1.75, -32.4), Vector3(1, 0, 0))


# ---------------------------------------------------------------- back room

## The back room (#36): a partition with a door, Old Bertha against the
## arena wall, customers' skates on tagged racks, spare wheels, a chalkboard.
func _back_room(k: VenueKit, wood: Color) -> void:
	var wall: Color = k.by_age(Wear.OLD_WOOD_DARK, paint(k), paint(k))
	k.wall_z(BACK_X, BACK_Z, ARENA, 0, h, 0.12, wall, [{"at": BACK_DOOR_Z, "w": 0.95, "y0": 0.0, "y1": 2.2}], 0.6)
	k.wall_x(BACK_Z, x0 + 0.15, BACK_X + 0.06, 0, h, 0.12, wall, [], 0.6)
	var door_col: Color = k.by_age(Color("5c4330"), Color("7a828c"), Color("2a2e36"))
	add_door(k, Vector3(BACK_X, 0, BACK_DOOR_Z), PI * 0.5, VenueDoor.Kind.SWING, 0.9, 2.15, door_col, "Back room")
	wall_sign(k, [["STAFF ONLY", VenueSign.AMBER]], 10, 1, 0.008, Vector3(BACK_X + 0.07, 2.35, BACK_DOOR_Z), Vector3(1, 0, 0), "StaffOnly")
	# Old Bertha and her stool, a rubber mat in front
	k.prop("skate_sharpener", Vector3(-31.4, 0, ARENA - 0.34))
	k.block(Vector3(-32.3, 0, -31.6), Vector3(-30.4, 0.012, -30.8), Wear.RUBBER, 0.5, 0.04, false)
	k.block(Vector3(-32.75, 0, -31.55), Vector3(-32.4, 0.6, -31.2), Color("2b2d33"), 0.2, 0.04)
	# customers' skates waiting, with tags, on the west wall and the partition
	k.prop("skate_rack_tags", Vector3(x0 + 0.15 + 0.2, 0, -32.6), -PI * 0.5)
	k.prop("skate_rack_tags", Vector3(-31.0, 0, BACK_Z + 0.06 + 0.2), PI)
	# a shelf of spare wheels and a coffee can of plugs over the rack
	k.block(Vector3(x0 + 0.15, 1.85, -33.1), Vector3(x0 + 0.45, 1.88, -31.9), wood, 0.3, 0.03, false)
	for i in 4:
		var z := -32.95 + i * 0.28
		k.block(Vector3(x0 + 0.2, 1.88, z), Vector3(x0 + 0.4, 2.08, z + 0.05), Color("d8d6cc") if i % 2 == 0 else Color("6a6e74"), 0.1, 0.03, false)
	k.block(Vector3(x0 + 0.22, 1.88, -32.0), Vector3(x0 + 0.36, 2.02, -31.92), Color("b8312f"), 0.1, 0.03, false)
	var chalk := [["// HOLLOWS", Color("e8e6e1")], ["1/2  STANDARD", Color("e8e6e1"), true], ["3/8  BITE", Color("e8e6e1"), true],
		["5/8  GLIDE", Color("e8e6e1"), true], ["1    BUTTER KNIFE", Color("f2c230"), true]]
	wall_sign(k, chalk, 13, 5, 0.012, Vector3(-31.4, 2.3, ARENA), Vector3(0, 0, -1), "HollowBoard", Color("2a3a30"))
	rec_light(k, Vector3(-31.2, h - 0.4, -31.6), 4.0, 0.8)


# ---------------------------------------------------------------- counter

## The counter (an L off the back room wall), the till, coffee, a puck jar,
## the BACK IN 5 MIN card, the photo wall behind and the tape tower.
func _counter(k: VenueKit, wood: Color) -> void:
	var top: Color = k.by_age(Color("c9b48a"), Color("d6c39a"), Color("e8e6e1"))
	k.aged_block(Vector3(-28.8, 0, -33.9), Vector3(-24.8, 1.0, -33.3), wood, 0.5)
	k.aged_block(Vector3(-24.8, 0, -33.9), Vector3(-24.2, 1.0, -32.0), wood, 0.5)
	k.block(Vector3(-28.9, 1.0, -34.0), Vector3(-24.7, 1.05, -33.25), top, 0.5, 0.03, false)
	k.block(Vector3(-24.9, 1.0, -34.0), Vector3(-24.1, 1.05, -31.9), top, 0.5, 0.03, false)
	if k.age == Age.RENOVATED:
		k.glass(Vector3(-28.4, 0.2, -33.92), Vector3(-25.2, 0.9, -33.88), false)  # a glass display front
	k.prop("shop_till", Vector3(-27.6, 1.05, -33.6), PI, false)
	# coffee pot ($1) and a jar of pucks
	k.block(Vector3(-25.6, 1.05, -33.75), Vector3(-25.35, 1.32, -33.5), Color("2b2d33"), 0.1, 0.03, false)
	k.block(Vector3(-25.57, 1.06, -33.72), Vector3(-25.38, 1.16, -33.53), Color("4a2a12"), 0.1, 0.02, false)
	k.glass(Vector3(-26.3, 1.05, -33.75), Vector3(-26.1, 1.3, -33.55), false, Color(0.85, 0.9, 0.95, 0.35))
	k.block(Vector3(-26.28, 1.05, -33.73), Vector3(-26.12, 1.17, -33.57), Models.PUCK, 0.1, 0.02, false)
	# the card Bev leaves when she is in the back
	k.block(Vector3(-27.0, 1.05, -33.78), Vector3(-26.55, 1.23, -33.76), Color("eeeae0"), 0.2, 0.0, false)
	wall_sign(k, [["BACK IN 5 MIN", VenueSign.RED]], 13, 1, 0.0055, Vector3(-26.775, 1.15, -33.79), Vector3(0, 0, -1), "BackIn5", Color("eeeae0"))
	# Millbrook team photos from 1971 on, behind the counter
	for i in 10:
		var x := -28.5 + (i % 5) * 0.75
		var y := 1.45 + (i / 5) * 0.55
		k.block(Vector3(x, y, ARENA - 0.04), Vector3(x + 0.55, y + 0.42, ARENA), Color("2b2d33") if k.age == Age.RENOVATED else Color("5c4330"), 0.3, 0.0, false)
		var photo: Color = Color("b8a88a").lerp(Color("6a6458"), posmod(hash(i * 3), 5) / 6.0)
		if k.age == Age.WORN:
			photo = photo.lerp(Color("c8b07a"), 0.35)
		k.block(Vector3(x + 0.04, y + 0.04, ARENA - 0.05), Vector3(x + 0.51, y + 0.38, ARENA - 0.04), photo, 0.25, 0.06, false)
	k.prop("tape_tower", Vector3(-29.25, 0, -34.45))


# ---------------------------------------------------------------- walls of stock

## The skate wall: a pegboard of skates on hooks over shelves of boxes, and
## Grafton's glass case once the shop is renovated.
func _skate_wall(k: VenueKit, steel: Color) -> void:
	var xw := x0 + 0.15
	var boxes := [Color("1b1d22"), Color("c8191e"), Color("eeeeea"), Color("3a3d44"), Color("e0b020")]
	shelves(k, Vector3(xw, 0, -39.6), Vector3(xw + 0.5, 0.9, -33.8), 2, steel, boxes)
	var peg: Color = k.by_age(Color("a08a64"), Color("c9b48a"), Color("d8d4cb"))
	k.block(Vector3(xw, 0.95, -39.6), Vector3(xw + 0.02, 2.6, -33.8), peg, 0.3, 0.05, false)
	var boot := [Color("1b1d22"), Color("1b1d22"), Color("eeeeea"), Color("1d3557"), Color("2b2d33"), Color("5b3a1e")]
	var i := 0
	for row in 2:
		var y := 1.25 + row * 0.65
		var z := -39.35
		while z < -34.8:
			if posmod(hash(Vector2i(i, k.age)), 7) != 0 or k.age != Age.WORN:
				_skate(k, Vector3(xw + 0.03, y, z), boot[i % boot.size()])
				_skate(k, Vector3(xw + 0.03, y, z + 0.16), boot[i % boot.size()])
			z += 0.55
			i += 1
	if k.age == Age.RENOVATED:
		k.aged_block(Vector3(xw, 0.9, -34.6), Vector3(xw + 0.55, 0.95, -33.8), Color("2a2e36"), 0.3)
		k.glass(Vector3(xw, 0.95, -34.6), Vector3(xw + 0.55, 1.7, -33.8))
		_skate(k, Vector3(xw + 0.2, 1.2, -34.35), Color("d6d9dc"))
		_skate(k, Vector3(xw + 0.2, 1.2, -34.15), Color("d6d9dc"))


## One skate hanging on a hook against the west wall, toe out into the shop.
func _skate(k: VenueKit, p: Vector3, boot: Color) -> void:
	k.block(p + Vector3(0, 0.1, 0), p + Vector3(0.02, 0.13, 0.04), Color("b8bcc2"), 0.05, 0.0, false)  # hook
	k.block(p + Vector3(0.02, -0.12, 0), p + Vector3(0.3, 0.1, 0.1), boot, 0.15, 0.05, false)  # boot
	k.block(p + Vector3(0.02, 0.1, 0), p + Vector3(0.14, 0.2, 0.1), boot.lightened(0.15), 0.15, 0.05, false)  # cuff
	k.block(p + Vector3(0.0, -0.2, 0.03), p + Vector3(0.32, -0.12, 0.07), Color("d8d6cc") if boot.get_luminance() < 0.5 else Color("1b1d22"), 0.15, 0.03, false)  # holder
	k.block(p + Vector3(0.0, -0.23, 0.045), p + Vector3(0.33, -0.2, 0.055), Color("c9ccd1"), 0.15, 0.0, false)  # steel


## The stick wall (#35): three retail racks on the east wall, racked by brand
## (Honest, Kodiak, juniors), real sticks blade up in divided slots; a
## Warlock A-frame on the floor (Kodiak won't share a wall with Warlock) and
## a barrel of Shorewood wood sticks by the window.
func _stick_wall(k: VenueKit) -> void:
	var field := StickField.new()
	field.name = "Sticks"
	k.add(field)
	var physics := StickProps.walkable(self)
	var xr := x1 - 0.15 - 0.195 - 0.01
	var racks := [
		[-38.7, ["honest", "honest_plus"], 0.0, "// HONEST HOCKEY CO.", Color("c9a66b")],
		[-36.68, ["kodiak", "kodiak_grizzly"], 0.0, "// KODIAK  EST 1898", Color("a3262a")],
		[-34.66, ["honest", "kodiak", "warlock", "shorewood"], 1.0, "// JUNIOR AND YOUTH", VenueSign.CYAN],
	]
	var n := 0
	for r in racks:
		var stock := _stock(r[1], 10, hash(r[3]), r[2], 10 if k.age != Age.WORN else 6)
		StickProps.fill(k, "stick_rack_shop", Vector3(xr, 0, r[0]), PI * 0.5, stock, physics, field)
		wall_sign(k, [[r[3], r[4]]], 19, 1, 0.009, Vector3(xr - 0.005, 1.885, r[0]), Vector3(-1, 0, 0), "StickHeader%d" % n, Color("1b1d22"))
		n += 1
	StickProps.fill(k, "stick_rack_aframe", Vector3(-23.4, 0, -35.3), PI * 0.5,
		_stock(["warlock", "warlock_coven", "warlock_necro"], 12, 66, 0.0, 10), physics, field)
	# the Warlock sign hung over its A-frame: black, an acid-green star
	k.block(Vector3(-23.45, 2.35, -36.0), Vector3(-23.35, 2.95, -34.6), Color("121212"), 0.2, 0.03, false)
	k.block(Vector3(-23.47, 2.5, -35.45), Vector3(-23.33, 2.8, -35.15), Color("9be22d"), 0.1, 0.0, false)
	k.block(Vector3(-23.47, 2.6, -35.95), Vector3(-23.33, 2.7, -34.65), Color("6a1b9a"), 0.1, 0.0, false)
	for zz in [-35.9, -34.7]:
		k.block(Vector3(-23.41, 2.95, zz), Vector3(-23.39, h, zz + 0.02), Color("6a6e74"), 0.2, 0.0, false)
	StickProps.fill(k, "stick_barrel", Vector3(-21.8, 0, -39.3), 0.0,
		_stock(["shorewood", "shorewood_1952"], 6, 1894, 0.0, 6), physics, field)


## Shop stock for a rack: `n` slots, `filled` of them with sticks from
## `pool`, new and untaped.
func _stock(pool: Array, n: int, seed: int, junior: float, filled: int) -> Array:
	var out := []
	for i in n:
		if i >= filled and posmod(hash(Vector2i(seed, i)), 3) != 0:
			out.append({})
			continue
		var v := StickProps.pick(pool, seed, i, junior)
		v["tape"] = "none"
		out.append(v)
	return out


## Gloves hung on a pegboard on the arena wall, helmets on a shelf under.
func _gloves_and_helmets(k: VenueKit, steel: Color) -> void:
	var peg: Color = k.by_age(Color("a08a64"), Color("c9b48a"), Color("d8d4cb"))
	k.block(Vector3(-23.8, 1.05, ARENA - 0.02), Vector3(-20.5, 2.25, ARENA), peg, 0.3, 0.05, false)
	var gloves := [Color("1b1d22"), Color("c8102e"), Color("1d3557"), Color("8a8d8f"), Color("6a1b9a"), Color("5b3a1e")]
	for row in 2:
		for i in 6:
			var x := -23.6 + i * 0.52
			var y := 1.2 + row * 0.5
			var c: Color = gloves[(i + row * 2) % gloves.size()]
			if k.age == Age.WORN and (i + row) % 4 == 3:
				continue  # half-empty hooks
			k.block(Vector3(x, y, ARENA - 0.14), Vector3(x + 0.18, y + 0.3, ARENA - 0.03), c, 0.1, 0.05, false)
			k.block(Vector3(x + 0.21, y, ARENA - 0.14), Vector3(x + 0.39, y + 0.3, ARENA - 0.03), c, 0.1, 0.05, false)
			k.block(Vector3(x, y - 0.06, ARENA - 0.14), Vector3(x + 0.39, y, ARENA - 0.03), c.darkened(0.3), 0.1, 0.03, false)  # cuffs
	shelves(k, Vector3(-23.6, 0, ARENA - 0.5), Vector3(-21.0, 0.95, ARENA - 0.02), 2, steel)
	var helmets := [Color("1b1d22"), Color("eeeeea"), Color("c8102e"), Color("1d3557")]
	for tier in 2:
		for i in 5:
			var x := -23.4 + i * 0.5
			var y := 0.03 + tier * 0.475
			var c: Color = helmets[(i + tier) % helmets.size()]
			k.block(Vector3(x, y, ARENA - 0.42), Vector3(x + 0.26, y + 0.2, ARENA - 0.12), c, 0.1, 0.05, false)
			if (i + tier) % 2 == 0:
				k.block(Vector3(x + 0.02, y + 0.02, ARENA - 0.46), Vector3(x + 0.24, y + 0.16, ARENA - 0.42), Models.CAGE, 0.1, 0.0, false)


## Things on the shop floor: puck bins and a glove bin, the fitting bench
## with its foot measure, the jersey rail by the window, a radiator, the
## tape and laces island, the entrance mat.
func _floor_stock(k: VenueKit, wood: Color, steel: Color) -> void:
	k.prop("puck_bin", Vector3(-28.0, 0, -35.2), 0.2)
	k.prop("puck_bin", Vector3(-27.25, 0, -35.15), -0.15)
	# the glove and pads bin with Bev's warning on it
	k.aged_block(Vector3(-31.3, 0, -35.0), Vector3(-30.1, 0.7, -34.3), steel.darkened(0.2), 0.3)
	var pads := [Color("1b1d22"), Color("c8102e"), Color("ece6da"), Color("1d3557"), Color("8a8d8f")]
	for i in 8:
		var px := -31.2 + (i % 4) * 0.27
		var pz := -34.95 + (i / 4) * 0.33
		k.block(Vector3(px, 0.7, pz), Vector3(px + 0.24, 0.8 + 0.04 * (i % 3), pz + 0.28), pads[i % pads.size()], 0.1, 0.06, false)
	wall_sign(k, [["SMELL BEFORE YOU BUY.", VenueSign.AMBER], ["TRUST ME.", VenueSign.WHITE]], 21, 2, 0.0045, Vector3(-30.7, 0.45, -35.0), Vector3(0, 0, -1), "SmellSign", Color("1b1d22"))
	# the fitting bench on a rubber mat, the foot measure in front
	k.block(Vector3(-32.4, 0, -37.7), Vector3(-29.6, 0.012, -35.8), Wear.RUBBER, 0.5, 0.04, false)
	bench(k, Vector3(-32.2, 0, -36.4), Vector3(-29.8, 0, -36.0), wood)
	k.prop("foot_measure", Vector3(-31.2, 0.012, -37.05), PI)
	k.prop("foot_measure", Vector3(-30.3, 0.012, -37.1), PI + 0.2)
	# jersey rail by the west window
	k.block(Vector3(-31.0, 1.75, -38.6), Vector3(-28.4, 1.8, -38.55), Color("c9ccd1"), 0.3, 0.0, false)
	for x in [-31.0, -28.45]:
		k.block(Vector3(x, 0, -38.62), Vector3(x + 0.05, 1.8, -38.53), Color("c9ccd1"), 0.2, 0.0)
	for i in 7:
		var c: Color = [home_primary(), Color("1d3557"), Color("e0b020"), Color("2a7a4a"), Color("eeeeea")][i % 5]
		var x := -30.9 + i * 0.35
		k.block(Vector3(x, 1.0, -38.75), Vector3(x + 0.3, 1.75, -38.4), k.aged(c, i), 0.2, 0.05, false)
	k.collider(Vector3(-31.0, 1.0, -38.75), Vector3(-28.4, 1.8, -38.4))
	# the radiator under the east window clanks
	k.aged_block(Vector3(-23.6, 0.15, -39.83), Vector3(-22.4, 0.8, -39.62), k.by_age(Color("c9c0a8"), Color("e6e4de"), Color("d8d4cb")), 0.2)
	# tape and laces on an island
	var tape := [Color("eeeeea"), Color("1b1d22"), Color("3f6fa8"), Color("c8191e"), Color("e0b020")]
	shelves(k, Vector3(-25.5, 0, -37.4), Vector3(-24.2, 1.2, -36.8), 3, steel, tape)
	k.block(Vector3(-27.0, 0, -39.85), Vector3(-25.0, 0.015, -38.7), Color("2c2d31"), 0.5, 0.04, false)


## Brand posters (pictures, not readables): Warlock by the skate wall,
## Gripley's tape on the back-room wall, Kodiak by the door.
func _posters(k: VenueKit) -> void:
	var fade := 0.3 if k.age == Age.WORN else 0.0
	# Warlock: black, a jagged green star
	_poster(k, Vector3(-32.9, 1.4, -39.85), Vector3(-31.9, 2.6, -39.83), Color("121212"), Color("9be22d"), Color("6a1b9a"), fade)
	# Gripley's: yellow, a black tape ring with a white centre
	var gz := BACK_Z - 0.08
	k.block(Vector3(-32.6, 1.3, gz - 0.02), Vector3(-31.6, 2.3, gz), Color("f2c230").lerp(Color("d8d0b8"), fade), 0.2, 0.03, false)
	k.block(Vector3(-32.35, 1.55, gz - 0.03), Vector3(-31.85, 2.05, gz - 0.02), Color("1a1a1a"), 0.1, 0.0, false)
	k.block(Vector3(-32.2, 1.7, gz - 0.04), Vector3(-32.0, 1.9, gz - 0.03), Color("f4f4f0"), 0.1, 0.0, false)
	# Kodiak: parchment, the bear's brown shield
	_poster(k, Vector3(-24.95, 1.3, -39.85), Vector3(-24.15, 2.4, -39.83), Color("e8dcc0"), Color("5b3a1e"), Color("a3262a"), fade)


## A poster on the hall wall, its picture facing into the shop (+Z).
func _poster(k: VenueKit, a: Vector3, b: Vector3, bg: Color, mark: Color, band: Color, fade: float) -> void:
	k.block(a, b, bg.lerp(Color("d8d0b8"), fade), 0.2, 0.03, false)
	var c := (a + b) * 0.5
	var w := (b.x - a.x) * 0.25
	k.block(Vector3(c.x - w, c.y - 0.05, b.z), Vector3(c.x + w, c.y + 0.35, b.z + 0.01), mark.lerp(Color("d8d0b8"), fade * 0.5), 0.1, 0.0, false)
	k.block(Vector3(a.x + 0.05, a.y + 0.08, b.z), Vector3(b.x - 0.05, a.y + 0.2, b.z + 0.01), band.lerp(Color("d8d0b8"), fade * 0.5), 0.1, 0.0, false)
