extends RecRoom
## Dressing rooms 3 to 6 off the main hall: the old Athletic Club change
## rooms, now used by minor hockey, the beer league and visiting tournament
## teams. Hockey stalls on two walls (DressingStalls), a shower room in
## the corner by the arena wall, a whiteboard, and a door straight out to
## the rink. Each room kept the colour the
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
	# hockey stalls (W8) down the east wall and along the arena wall, short
	# of the door out to the rink: open cubbies with a bench seat, a bar for
	# gear and a shelf above, all one mesh (DressingStalls). Worn: the club's
	# 70s ply with a stripe in the room's colour; repaired: patched and
	# repainted; renovated: maple with backs in the room's colour.
	var n_east := DressingStalls.fit(7.2)
	var n_rink := DressingStalls.fit(3.6)
	var east_z := -38.6 + (7.2 - n_east * DressingStalls.STALL_W) * 0.5
	var rink_x := x0 + 3.0 + (3.6 - n_rink * DressingStalls.STALL_W) * 0.5
	DressingStalls.build(k, [
		{"start": Vector3(x1 - 0.15, 0, east_z), "along": Vector3(0, 0, 1), "out": Vector3(-1, 0, 0), "count": n_east},
		{"start": Vector3(rink_x, 0, -30.0), "along": Vector3(1, 0, 0), "out": Vector3(0, 0, -1), "count": n_rink},
	], {"paint": k.by_age(team.lightened(0.1), team.lerp(Color("d8d3c4"), 0.3), team), "team": team}, hash(plan_id))
	# the shower room in the corner by the arena wall
	var tile: Color = k.by_age(Color("b9c2bb"), Color("cfd8d2"), Color("f0f2f2"))
	var sx := x0 + 2.7
	k.wall_x(-33.6, x0 + 0.15, sx, 0, h, 0.2, tile, [{"at": x0 + 1.9, "w": 1.0, "y0": 0.0, "y1": 2.2}], 0.4)
	k.wall_z(sx, -33.7, -30.0, 0, h, 0.2, tile, [], 0.4)
	k.block(Vector3(x0 + 0.15, 0, -33.5), Vector3(sx - 0.1, 0.01, -30.0), tile.darkened(0.15), 0.3, 0.05, false)
	for i in 3:
		var hx := x0 + 0.6 + i * 0.75
		k.block(Vector3(hx - 0.06, 2.0, -30.12), Vector3(hx + 0.06, 2.12, -30.0), Color("b8bcc2"), 0.1, 0.0, false)
	# World: the coach's whiteboard on the west wall, a real dry-erase board
	# with this room's own marks for the day (evening notes W7, W15)
	var board := Whiteboard.make("whiteboard_marks", "room_%d" % _number())
	board.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.6), Vector3(x0 + 0.16, 1.6, -37.0))
	k.add(board)
	# World: the room number, a real sign in each room's own 90s style (an
	# engraved plate, painted plywood, a steel plate, a brass numeral that
	# swung round), over the door inside and beside the door in the hall (W17)
	var num_id := "sign_room_%d" % _number()
	if Readable.has_def(num_id):
		readable(k, num_id, Vector3(x0 + 4.5, 2.25, z0 + 0.15), Vector3(0, 0, 1)).name = "RoomNumber"
		readable(k, num_id, Vector3(x0 + 3.0, 1.75, z0 - 0.15), Vector3(0, 0, -1)).name = "RoomNumberHall"
	# World: a stick rack by the door, a different design in each room, full
	# of real sticks (playtest #28, #35), and a tape ball someone left
	_stick_racks(k, team)
	if k.age == Age.WORN:
		k.block(Vector3(x0 + 5.0, 0, -35.0), Vector3(x0 + 5.12, 0.12, -34.88), Color("1b1d22"), 0.1, 0.0, false)


## World: the room's stick racks (StickProps): room 3 a wall slot rack and a
## corner barrel, 4 a team rack with name tape, 5 a barrel and a wall rack,
## 6 a floor A-frame and a team rack. The hall wall's inside face is z0 + 0.15.
func _stick_racks(k: VenueKit, team: Color) -> void:
	var n := _number()
	var pal := Models.team_palette("ROOM %d" % n, team, Color("ece7dc"))
	var field := StickField.new()
	field.name = "Sticks"
	k.add(field)
	var wall := z0 + 0.15
	var at := Vector3(x0 + 4.6, 0, 0)
	match n:
		3, 5:
			StickProps.fill(k, "stick_rack_wall", at + Vector3(0, 0, wall + 0.205), PI, StickProps.room_mix(pal, n, 14, 9), true, field)
			StickProps.fill(k, "stick_barrel", Vector3(x1 - 0.6, 0, wall + 0.5), 0.0, StickProps.room_mix(pal, n + 10, 6, 4, 0.3), true, field)
		4:
			StickProps.fill(k, "stick_rack_team", at + Vector3(0, 0, wall + 0.27), PI, StickProps.room_mix(pal, n, 12, 10, 0.8), true, field)
		_:
			StickProps.fill(k, "stick_rack_team", at + Vector3(0, 0, wall + 0.27), PI, StickProps.room_mix(pal, n, 12, 8, 0.8), true, field)
			StickProps.fill(k, "stick_rack_aframe", Vector3(x0 + 5.0, 0, -35.6), 0.0, StickProps.room_mix(pal, n + 20, 12, 7, 0.4), true, field)
