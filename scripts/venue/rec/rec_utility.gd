extends RecRoom
## The wing's two plant closets. The electrical room has the main
## switchgear, a caged transformer, breaker panels, meters, conduit and a
## cable tray (Props kit pieces from shop_props.gd). The boiler room has
## the old gas boiler that heats the wing and its showers, a water heater, an
## expansion tank and the pipes that tie them together.


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("6f6a60"), Color("7d7a72"), Color("8e8f90"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("a8a294"), Color("b4b0a6"), Color("cfd0cf"))


func bare_outer() -> bool:
	return true


func plate_color() -> Color:
	return VenueSign.AMBER


func furnish(k: VenueKit) -> void:
	if plan_id == "rec_electrical":
		_electrical(k)
	else:
		_boiler(k)


## The electrical room (#26): the main switchgear against the arena wall
## with a rubber mat in front of it, the transformer in its cage, breaker
## panels with their directories down the east wall, the utility meters,
## conduit up the walls and a cable tray along the ceiling, the fire alarm
## panel by the door, an extinguisher and a step ladder.
func _electrical(k: VenueKit) -> void:
	var face := -30.05  # the arena wall
	var east := x1 - 0.15
	var west := x0 + 0.15
	var conduit: Color = k.by_age(Color("8a8e90"), Color("b8bcc2"), Color("c9cfd3"))
	# the transformer in its chain-link cage, west corner
	k.prop("transformer", Vector3(33.0, 0, face - 0.47))
	k.block(Vector3(west, 0, face - 1.5), Vector3(34.05, 0.08, face), Color("7a776e"), 1.0, 0.03, false)  # pad
	var cage: Color = k.by_age(Color("7d8288"), Color("9aa0a4"), Color("b9c0c6"))
	for i in 5:
		var x := west + 0.05 + i * 0.45
		k.block(Vector3(x, 0, face - 1.32), Vector3(x + 0.04, 2.1, face - 1.28), cage, 1.0, 0.02, false)
	for y in [0.05, 1.05, 2.06]:
		k.block(Vector3(west, y, face - 1.32), Vector3(34.05, y + 0.04, face - 1.28), cage, 1.0, 0.02, false)
	for side in [west, 34.01]:
		k.block(Vector3(side, 2.06, face - 1.32), Vector3(side + 0.04, 2.1, face), cage, 1.0, 0.02, false)
	k.glass(Vector3(west, 0.05, face - 1.31), Vector3(34.05, 2.06, face - 1.29), false, Color(0.6, 0.62, 0.62, 0.22))  # the mesh
	k.collider(Vector3(west, 0, face - 1.33), Vector3(34.06, 2.1, face))
	wall_sign(k, [["DANGER", VenueSign.RED], ["HIGH VOLTAGE", VenueSign.WHITE], ["KEEP OUT", VenueSign.AMBER]], 12, 3, 0.016, Vector3(33.1, 1.45, face - 1.335), Vector3(0, 0, -1), "Danger", Color("2a2723"))
	# the main switchgear and the mat in front of it
	k.prop("switchgear", Vector3(35.5, 0, face - 0.4))
	k.block(Vector3(34.25, 0, face - 1.95), Vector3(36.75, 0.012, face - 0.82), Color("1b1d22"), 1.0, 0.03, false)
	for i in 6:
		k.block(Vector3(34.3, 0.012, face - 1.9 + i * 0.18), Vector3(36.7, 0.014, face - 1.88 + i * 0.18), Color("2b2d33"), 4.0, 0.0, false)  # ribs
	for i in 6:
		var x := 34.6 + i * 0.36
		k.block(Vector3(x, 2.47, face - 0.5), Vector3(x + 0.07, 2.95, face - 0.43), conduit, 1.0, 0.02, false)
	wall_sign(k, [["// MAIN SWITCHGEAR", VenueSign.AMBER], ["600A 3PH 4W  120/208V", VenueSign.CYAN, true]], 21, 2, 0.014, Vector3(35.5, 2.75, face), Vector3(0, 0, -1), "PanelLabel")
	# the cable tray along the arena wall and down the east wall
	var tray: Color = k.by_age(Color("8a8e90"), Color("a7adaf"), Color("b9c0c6"))
	for run in [[Vector3(west, 2.95, face - 0.7), Vector3(east, 3.0, face - 0.25)], [Vector3(east - 0.45, 2.95, -39.6), Vector3(east, 3.0, face - 0.25)]]:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		k.block(a, b, tray, 1.0, 0.02, false)
		if absf(b.x - a.x) > absf(b.z - a.z):
			k.block(Vector3(a.x, 3.0, a.z), Vector3(b.x, 3.08, a.z + 0.02), tray, 1.0, 0.0, false)
		else:
			k.block(Vector3(a.x, 3.0, a.z), Vector3(a.x + 0.02, 3.08, b.z), tray, 1.0, 0.0, false)
	# breaker panels down the east wall, each with conduit up to the tray
	for i in 3:
		var z := -38.6 + i * 1.25
		k.prop("breaker_panel", Vector3(east - 0.07, 0.95, z), PI * 0.5, false)
		k.block(Vector3(east - 0.18, 2.0, z - 0.04), Vector3(east - 0.1, 2.95, z + 0.04), conduit, 1.0, 0.02, false)
	k.collider(Vector3(east - 0.2, 0.9, -38.95), Vector3(east, 2.0, -35.75))
	var directory := [
		["// LP-1  HALL + WING", VenueSign.AMBER], ["1 HALL LTS     2 GYM LTS", VenueSign.WHITE, true],
		["3 DR 3-4       4 DR 5-6", VenueSign.WHITE, true], ["5 WEIGHT RM    6 WORKSHOP", VenueSign.WHITE, true],
		["7 BOILER       8 SPARE", VenueSign.WHITE, true],
	]
	wall_sign(k, directory, 24, 5, 0.011, Vector3(east, 2.3, -37.35), Vector3(-1, 0, 0), "PanelDirectory", Color("e8e4d8") if k.age != Age.WORN else Color("c8c0a8"))
	# the utility meters
	k.prop("meter_bank", Vector3(east - 0.13, 0.9, -34.2), PI * 0.5, false)
	k.block(Vector3(east - 0.2, 1.75, -34.25), Vector3(east - 0.12, 2.95, -34.15), conduit, 1.0, 0.02, false)
	k.collider(Vector3(east - 0.3, 0.9, -34.65), Vector3(east, 1.75, -33.75))
	# conduit up the west wall from the transformer to the tray
	for z in [face - 0.3, face - 0.6]:
		k.block(Vector3(west, 1.7, z - 0.04), Vector3(west + 0.08, 2.95, z + 0.04), conduit, 1.0, 0.02, false)
	# by the door: the fire alarm panel, the extinguisher, the ladder
	k.prop("fire_panel", Vector3(west + 0.07, 1.35, -38.9), -PI * 0.5, false)
	k.block(Vector3(west, 1.94, -38.94), Vector3(west + 0.06, 2.95, -38.86), Color("c4161c"), 1.0, 0.02, false)
	k.prop("fire_extinguisher", Vector3(west + 0.2, 0, -37.9), -PI * 0.5)
	k.prop("step_ladder", Vector3(west + 0.45, 0, -35.2), -PI * 0.5)
	if k.age == Age.WORN:
		# a bucket under a weeping conduit fitting, and a dusty old fuse box
		k.block(Vector3(36.9, 0, -33.4), Vector3(37.2, 0.3, -33.1), Color("7d8288"), 1.0, 0.04)
		k.aged_block(Vector3(east - 0.18, 1.3, -32.6), Vector3(east, 1.8, -32.1), Color("5a5e58"), 1.0)
		k.block(Vector3(east - 0.19, 1.45, -32.5), Vector3(east - 0.18, 1.65, -32.2), Wear.PAPER, 1.0, 0.0, false)


func _boiler(k: VenueKit) -> void:
	var red := k.aged(Color("9a3a2a"), 1)
	var steel := Color("8f9498")
	var copper := Color("b87333") if k.age != Age.WORN else Color("7a6a4a")
	# the boiler against the arena wall, its flue up through the roof
	k.aged_block(Vector3(x0 + 0.4, 0, -32.2), Vector3(x1 - 0.5, 1.8, -30.3), red, 0.4)
	k.block(Vector3(x0 + 1.5, 1.8, -31.5), Vector3(x0 + 1.9, h, -31.1), steel, 0.4, 0.03, false)
	k.block(Vector3(x0 + 0.6, 1.0, -32.25), Vector3(x0 + 1.0, 1.4, -32.2), Color("1b1d22"), 0.1, 0.0, false)
	k.glow(Vector3(x0 + 0.65, 1.05, -32.26), Vector3(x0 + 0.95, 1.35, -32.255), Color("ff9a3a") if k.age != Age.RENOVATED else Color("5fe0f0"))
	# the water heater, the expansion tank, a pump between them
	k.block(Vector3(x1 - 1.0, 0, -36.2), Vector3(x1 - 0.2, 1.7, -35.4), Color("d8d8d0") if k.age != Age.WORN else Color("b8b0a0"), 0.3, 0.04)
	k.block(Vector3(x1 - 0.8, 1.9, -34.6), Vector3(x1 - 0.3, 2.4, -34.0), Color("8a9aa8"), 0.2, 0.03, false)
	k.block(Vector3(x1 - 0.7, 0, -34.2), Vector3(x1 - 0.35, 0.4, -33.8), Color("3f6fa8"), 0.2, 0.03)
	# pipe runs: supply and return along the ceiling and down to the boiler
	for p in [[2.6, copper], [2.8, steel]]:
		k.block(Vector3(x0 + 0.3, p[0], -36.0), Vector3(x1 - 0.3, p[0] + 0.1, -35.9), p[1], 0.4, 0.0, false)
		k.block(Vector3(x0 + 0.3, p[0], -39.5), Vector3(x0 + 0.4, p[0] + 0.1, -32.2), p[1], 0.4, 0.0, false)
	k.block(Vector3(x0 + 0.3, 1.8, -32.3), Vector3(x0 + 0.4, 2.7, -32.2), copper, 0.3, 0.0, false)
	# a gauge board and the log clipboard
	wall_sign(k, [["// BOILER 2", VenueSign.AMBER], ["82C  14PSI", VenueSign.CYAN, true]], 11, 2, 0.014, Vector3(x0 + 0.15, 1.6, -36.5), Vector3(1, 0, 0), "BoilerGauge")
	k.block(Vector3(x0 + 0.15, 1.1, -37.6), Vector3(x0 + 0.18, 1.45, -37.35), Color("c9a46a"), 0.1, 0.0, false)
