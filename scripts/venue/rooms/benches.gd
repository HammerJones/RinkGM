extends VenueRoom
## The two player benches on the -Z side: rubber floor, the bench, a low
## back wall with a gate to the walkway, glass partitions at the ends, stick
## racks and water bottles. Home bench is on the -X half.

const BENCHES := [[-11.4, -2.6], [2.6, 11.4]]


func _ready() -> void:
	room_id = "benches"
	display_name = "Player benches"
	bounds = AABB(Vector3(-11.4, 0, -Venue.BENCH_BACK), Vector3(22.8, 2.5, Venue.BENCH_BACK - Venue.BOARD_OUT))
	spawn = Vector3(-7.0, 0, -14.2)


func build(k: VenueKit) -> void:
	var z0 := -Venue.BOARD_OUT
	var z1 := -Venue.BENCH_BACK
	for bi in 2:
		var x0: float = BENCHES[bi][0]
		var x1: float = BENCHES[bi][1]
		var home := bi == 0
		var team_col := home_primary() if home else Color("4a5563")
		# floor mat
		var mat: Color = k.by_age(Color("2b2c30"), Color("303237"), Color("1d1f24"))
		k.aged_block(Vector3(x0, 0, z0), Vector3(x1, 0.06, z1), mat, 0.5, 0.08)
		# the bench
		var wood: Color = k.by_age(Color("8a6a45"), Color("9b7a50"), team_col)
		k.aged_block(Vector3(x0 + 0.2, 0, -14.65), Vector3(x1 - 0.2, 0.47, z1 + 0.05), k.by_age(Color("4a4c50"), Color("55585e"), Color("23262c")), 0.5, 0.06)
		var seat_y := 0.47
		if k.age == VenueRoom.Age.WORN:
			# slats with one missing
			var n := int((x1 - x0 - 0.4) / 0.9)
			for i in n:
				if i == 3:
					continue
				var sx := x0 + 0.2 + i * (x1 - x0 - 0.4) / n
				k.block(Vector3(sx + 0.02, seat_y, -14.65), Vector3(sx + (x1 - x0 - 0.4) / n - 0.02, seat_y + 0.05, z1 + 0.05), k.aged(wood, i), 0.5, 0.1, false)
		else:
			k.block(Vector3(x0 + 0.2, seat_y, -14.65), Vector3(x1 - 0.2, seat_y + k.by_age(0.0, 0.05, 0.1), z1 + 0.05), wood, 0.5, 0.04, false)
		# back wall with a gate at the end nearer centre ice
		var gate_x := x1 - 0.7 if home else x0 + 0.7
		var wall: Color = k.by_age(Color("8a8378"), Color("9b958a"), Color("2a2e36"))
		k.wall_x(z1 - 0.12, x0, x1, 0, 1.3, 0.25, wall, [{"at": gate_x, "w": 0.95, "y0": 0.0, "y1": 1.3}])
		add_door(k, Vector3(gate_x, 0, z1 - 0.12), 0.0, VenueDoor.Kind.SWING, 0.9, 1.25, k.by_age(Color("6d6a64"), Color("7a828c"), team_col.darkened(0.2)), "Bench %s" % ("home" if home else "away"))
		# end partitions, solid low and glass above
		for ex in [x0, x1]:
			k.aged_block(Vector3(ex - 0.08, 0, z0), Vector3(ex + 0.08, 1.3, z1 - 0.25), wall, 0.5)
			k.glass(Vector3(ex - 0.03, 1.3, z0), Vector3(ex + 0.03, 2.5, z1 - 0.25))
		# stick rack behind the back wall (walkway side) and bottles on its cap
		var rack_x := x0 + 0.6 if home else x1 - 3.6
		for i in 10:
			var sx := rack_x + i * 0.3
			var lean := Basis(Vector3.RIGHT, deg_to_rad(-8.0))
			var shaft := Transform3D(lean.scaled(Vector3(0.03, 1.5, 0.03)), Vector3(sx, 0.85, z1 - 0.34))
			k.oriented(shaft, k.by_age(Color("3a3330"), Color("2d2f35"), Color("16181c")).lerp(Color("c9b48a"), 0.4 if i % 3 == 0 else 0.0))
			k.block(Vector3(sx - 0.02, 0.0, z1 - 0.3), Vector3(sx + 0.02, 0.06, z1 - 0.6), Color("1b1c1f"), 0.5, 0.0, false)
		for i in 8:
			var bx := (x0 + x1) * 0.5 - 1.2 + i * 0.3
			var bottle: Color = Color(["2f80c8", "d8d4c7", "c84b2f", "3e8f4f"][i % 4]) if k.age == VenueRoom.Age.WORN else team_col.lightened(0.1)
			k.block(Vector3(bx - 0.035, 1.3, z1 - 0.15), Vector3(bx + 0.035, 1.52, z1 - 0.08), bottle, 0.5, 0.05, false)
		if k.age == VenueRoom.Age.RENOVATED:
			k.glow(Vector3(x0 + 0.1, 1.22, z1 + 0.01), Vector3(x1 - 0.1, 1.27, z1 + 0.02), team_col.lightened(0.35))
		var label := VenueSign.make([["// " + ("HOME" if home else "VISITORS"), VenueSign.CYAN if home else VenueSign.AMBER]], 11, 1, 0.025)
		label.name = "BenchSign%d" % bi
		label.dead = k.by_age(0.05, 0.0, 0.0)
		k.sign(label, Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, 0.95, z1 + 0.02)))
