extends RecRoom
## Dressing rooms 3 to 6 off the main hall: the old Athletic Club change
## rooms, now used by minor hockey, the beer league and visiting tournament
## teams. Kit lockers on two walls with a bench in front, a shower room in
## the corner by the arena wall, a whiteboard. Each room kept the colour the
## club painted it in.

const COLOURS := [Color("7a2a35"), Color("1d3557"), Color("2a6a4a"), Color("b8862a")]


func _number() -> int:
	return plan_id.trim_prefix("locker_").to_int()


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("4a4a46"), Color("3a3f48"), Color("2b2f36"))


func paint(k: VenueKit) -> Color:
	var c: Color = COLOURS[(_number() - 3) % COLOURS.size()]
	return k.by_age(c.lerp(Color("8a8070"), 0.45), c.lerp(Color("d8d3c4"), 0.55), Color("e6e4de"))


func furnish(k: VenueKit) -> void:
	var team: Color = COLOURS[(_number() - 3) % COLOURS.size()]
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), team.darkened(0.2))
	# lockers down the east wall and along the arena wall
	for i in 6:
		k.prop("lockers", Vector3(x1 - 0.15 - 0.23, 0, -38.6 + i * 1.2 + 0.6), PI * 0.5)
	for i in 4:
		k.prop("lockers", Vector3(x0 + 3.0 + i * 1.2 + 0.6, 0, -30.0 - 0.23), 0.0)
	bench(k, Vector3(x1 - 1.05, 0, -38.6), Vector3(x1 - 0.65, 0, -31.4), wood)
	bench(k, Vector3(x0 + 3.0, 0, -31.05), Vector3(x1 - 1.2, 0, -30.65), wood)
	# the shower room in the corner by the arena wall
	var tile: Color = k.by_age(Color("b9c2bb"), Color("cfd8d2"), Color("f0f2f2"))
	var sx := x0 + 2.7
	k.wall_x(-33.6, x0 + 0.15, sx, 0, h, 0.2, tile, [{"at": x0 + 1.9, "w": 1.0, "y0": 0.0, "y1": 2.2}], 0.4)
	k.wall_z(sx, -33.7, -30.0, 0, h, 0.2, tile, [], 0.4)
	k.block(Vector3(x0 + 0.15, 0, -33.5), Vector3(sx - 0.1, 0.01, -30.0), tile.darkened(0.15), 0.3, 0.05, false)
	for i in 3:
		var hx := x0 + 0.6 + i * 0.75
		k.block(Vector3(hx - 0.06, 2.0, -30.12), Vector3(hx + 0.06, 2.12, -30.0), Color("b8bcc2"), 0.1, 0.0, false)
	# the coach's whiteboard on the west wall
	var plan := [["// ROOM %d" % _number(), VenueSign.WHITE], ["----", Color("8a8f99")], ["SKATE HARD", Color("1b1d22")], ["HAVE FUN", Color("1b1d22")]]
	var board := wall_sign(k, plan, 12, 4, 0.02, Vector3(x0 + 0.15, 1.6, -37.0), Vector3(1, 0, 0), "Whiteboard", Color("eef0f2") if k.age != Age.WORN else Color("d8d6cc"))
	board.dead = 0.0
	# the room number big over the door, inside
	wall_sign(k, [["%d" % _number(), VenueSign.AMBER]], 2, 1, 0.06, Vector3(x0 + 4.5, 2.2, z0 + 0.15), Vector3(0, 0, 1), "RoomNumber")
	# a stick rack by the door and a tape ball someone left
	k.block(Vector3(x0 + 3.4, 0, z0 + 0.2), Vector3(x0 + 5.6, 0.1, z0 + 0.5), Color("3a3d44"), 0.3, 0.0)
	for i in 6:
		var x := x0 + 3.55 + i * 0.35
		k.block(Vector3(x, 0.1, z0 + 0.3), Vector3(x + 0.03, 1.5, z0 + 0.33), [Color("1b1d22"), Color("d0202a"), Color("eeeeea")][i % 3], 0.3, 0.04, false)
	if k.age == Age.WORN:
		k.block(Vector3(x0 + 5.0, 0, -35.0), Vector3(x0 + 5.12, 0.12, -34.88), Color("1b1d22"), 0.1, 0.0, false)
