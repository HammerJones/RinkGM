extends RecRoom
## The wing's two plant closets. The electrical room has the main panels, a
## transformer and conduit running up into the ceiling. The boiler room has
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


func _electrical(k: VenueKit) -> void:
	var grey := Color("8f9498") if k.age != Age.WORN else Color("7d7f78")
	# panels down the east wall, each with its door and a status lamp
	for i in 5:
		var z := -38.6 + i * 1.5
		k.aged_block(Vector3(x1 - 0.45, 0.4, z), Vector3(x1 - 0.15, 2.1, z + 1.1), grey, 0.4)
		k.block(Vector3(x1 - 0.47, 1.9, z + 0.2), Vector3(x1 - 0.45, 1.98, z + 0.28), Color("8cf26a") if i != 2 or k.age != Age.WORN else Color("ff5f52"), 0.1, 0.0, false)
		# conduit up to the ceiling
		k.block(Vector3(x1 - 0.35, 2.1, z + 0.5), Vector3(x1 - 0.27, h, z + 0.58), Color("b8bcc2"), 0.3, 0.0, false)
	# the transformer on its pad, a cage round it
	k.block(Vector3(x0 + 0.6, 0, -33.0), Vector3(x0 + 2.4, 0.1, -30.6), Color("7a776e"), 0.4, 0.03)
	k.aged_block(Vector3(x0 + 0.8, 0.1, -32.7), Vector3(x0 + 2.2, 1.6, -30.9), Color("4a6a50"), 0.4)
	for i in 6:
		var x := x0 + 0.5 + i * 0.4
		k.block(Vector3(x, 0, -33.15), Vector3(x + 0.03, 2.0, -33.1), Color("6a6e74"), 0.5, 0.0, false)
	k.collider(Vector3(x0 + 0.5, 0, -33.15), Vector3(x0 + 2.6, 2.0, -30.3))
	wall_sign(k, [["DANGER", VenueSign.RED], ["HIGH VOLTAGE", VenueSign.WHITE]], 12, 2, 0.016, Vector3(x0 + 1.5, 2.3, -30.0), Vector3(0, 0, -1), "Danger", Color("2a2723"))
	wall_sign(k, [["// MAIN PANEL", VenueSign.AMBER], ["600A 3PH", VenueSign.CYAN, true]], 12, 2, 0.014, Vector3(x1 - 0.15, 2.45, -37.5), Vector3(-1, 0, 0), "PanelLabel")


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
