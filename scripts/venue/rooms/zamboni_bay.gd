extends VenueRoom
## The ice resurfacer's garage at the +X end, between the dressing rooms:
## roll-up doors to the rink and to the outside, the resurfacer itself,
## the snow-melt pit, a workbench and tool wall. A worn bay houses a rusty
## old machine; a renovated one has a new electric unit in club colours.

const X0 := Venue.END_FRONT
const X1 := Venue.HALF_X - Venue.WALL_T
const Z := 5.0
const H := 5.0


func _ready() -> void:
	room_id = "zamboni_bay"
	display_name = "Resurfacer bay"
	bounds = AABB(Vector3(X0, 0, -Z), Vector3(X1 - X0, H, Z * 2))
	spawn = Vector3(X0 + 1.5, 0, 3.5)


func build(k: VenueKit) -> void:
	var block_col: Color = k.by_age(Color("8f897c"), Color("a39d90"), Color("c9c5bc"))
	for s in [-1, 1]:
		k.wall_x(s * Z, X0, X1, 0, H, 0.3, block_col, [], 0.6)
	k.wall_z(X0 + 0.15, -Z, Z, 0, H, 0.3, block_col, [{"at": 0.0, "w": 3.4, "y0": 0.0, "y1": 3.0}], 0.6)
	add_door(k, Vector3(X0 + 0.15, 0, 0), PI * 0.5, VenueDoor.Kind.ROLLUP, 3.4, 3.0, k.by_age(Color("6b6f73"), Color("7d858c"), Color("2a2e36")), "Bay rink door")
	var xs := Venue.HALF_X - Venue.WALL_T * 0.5
	k.wall_z(xs, -Z, Z, 0, Venue.ROOF_Y, Venue.WALL_T, Color("a9a191") if k.age == Age.WORN else Color("bdb4a2"), [{"at": 0.0, "w": 4.0, "y0": 0.0, "y1": 4.0}], 1.0)
	add_door(k, Vector3(xs, 0, 0), PI * 0.5, VenueDoor.Kind.ROLLUP, 4.0, 4.0, k.by_age(Color("7a6a52"), Color("8a8f94"), home_primary().darkened(0.35)), "Bay garage door")
	# concrete floor, wet near the pit
	k.block(Vector3(X0 + 0.3, 0, -Z + 0.15), Vector3(X1, 0.02, Z - 0.15), k.by_age(Color("6f6c66"), Color("7d7a73"), Color("8e8b85")), 1.0, 0.07, false)
	k.block(Vector3(42.8, 0.02, -4.6), Vector3(45.3, 0.04, -2.4), Color("2e3033"), 0.25, 0.1, false)  # snow-melt pit grate
	if k.age != Age.RENOVATED:
		k.block(Vector3(41.5, 0.02, -4.2), Vector3(42.8, 0.025, -2.2), Color("4d5257"), 0.5, 0.05, false)  # puddle
	_resurfacer(k)
	# workbench, tool wall, tyres, paint drums
	var wood: Color = k.by_age(Color("6b5136"), Color("7a5c3c"), Color("3a3d44"))
	k.aged_block(Vector3(35.0, 0, -4.85), Vector3(38.5, 0.9, -4.15), wood, 0.4)
	k.block(Vector3(35.0, 1.2, -4.85), Vector3(38.5, 2.4, -4.82), k.by_age(Color("9a8a6a"), Color("b8a888"), Color("50555c")), 0.3, 0.06, false)
	for i in 6:
		var tx := 35.3 + i * 0.55
		k.block(Vector3(tx - 0.03, 1.4, -4.8), Vector3(tx + 0.03, 2.2, -4.74), Color("8c8f94"), 0.2, 0.0, false)
		k.block(Vector3(tx - 0.12, 1.3, -4.8), Vector3(tx + 0.12, 1.45, -4.74), [Color("b8312f"), Color("2f5eb0"), Color("d4a83a")][i % 3], 0.2, 0.0, false)
	for i in 3:
		k.block(Vector3(44.2, i * 0.28, 3.2), Vector3(45.2, i * 0.28 + 0.26, 4.2), Color("1d1e21"), 0.25, 0.08)
	for i in 3:
		var dx := 35.2 + i * 0.7
		k.block(Vector3(dx, 0, 3.9), Vector3(dx + 0.55, 0.85, 4.6), [Color("d42a30"), Color("2f5eb0"), Color("e4e1d8")][i], 0.3, 0.06)
	room_light(k, Vector3(40.0, H - 0.5, 0.0), 7.0)
	# lights and sign
	var lit: Color = k.by_age(Color("e0d8b0"), Color("f4f6f0"), Color("f4f8ff"))
	for x in [37.0, 41.0, 44.0]:
		k.glow(Vector3(x - 0.7, H - 0.1, -0.2), Vector3(x + 0.7, H - 0.05, 0.2), lit)
	var sign := VenueSign.make([["// ICE RESURFACING", VenueSign.AMBER], ["KEEP CLEAR", VenueSign.RED]], 17, 2, 0.03)
	sign.name = "BaySign"
	sign.dead = k.by_age(0.06, 0.0, 0.0)
	k.sign(sign, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(X0 - 0.01, 3.7, 0)))


## The resurfacer, parked nose-first toward the rink door (facing -X).
func _resurfacer(k: VenueKit) -> void:
	var x0 := 37.6
	var x1 := 41.8
	var hw := 1.1
	var body: Color = k.by_age(Color("d8d2c2"), Color("eeeae0"), home_primary())
	var stripe: Color = k.by_age(Color("4a6a96"), Color("2c5aa3"), home_secondary())
	var rust := Color("8a4b2a")
	# wheels
	for wx in [x0 + 0.7, x1 - 0.7]:
		for wz in [-hw, hw]:
			k.block(Vector3(wx - 0.4, 0, wz - 0.18), Vector3(wx + 0.4, 0.75, wz + 0.18), Color("1b1c1f"), 0.2, 0.05)
	# chassis and body
	k.block(Vector3(x0, 0.35, -hw + 0.1), Vector3(x1, 1.0, hw - 0.1), body.darkened(0.15), 0.3, 0.06)
	k.block(Vector3(x0 + 1.2, 1.0, -hw + 0.05), Vector3(x1, 1.9, hw - 0.05), body, 0.3, 0.06)
	k.block(Vector3(x0 + 1.18, 1.25, -hw + 0.03), Vector3(x1 + 0.02, 1.45, hw - 0.03), stripe, 0.3, 0.04, false)
	# snow tank on top
	k.block(Vector3(x0 + 1.4, 1.9, -hw + 0.15), Vector3(x1 - 0.1, 2.3, hw - 0.15), body.darkened(0.08), 0.3, 0.05)
	# cab: seat, wheel, dash
	k.block(Vector3(x0 + 0.2, 1.0, -0.35), Vector3(x0 + 0.75, 1.15, 0.35), Color("2b2d33"), 0.2, 0.04)
	k.block(Vector3(x0 + 0.65, 1.15, -0.35), Vector3(x0 + 0.78, 1.7, 0.35), Color("2b2d33"), 0.2, 0.04)
	k.block(Vector3(x0 + 0.05, 1.0, -hw + 0.1), Vector3(x0 + 0.2, 1.45, hw - 0.1), body.darkened(0.2), 0.2, 0.04)
	k.block(Vector3(x0 + 0.15, 1.45, -0.18), Vector3(x0 + 0.22, 1.5, 0.18), Color("1b1c1f"), 0.1, 0.0, false)
	# conditioner (the blade box) at the back
	k.block(Vector3(x1, 0.1, -hw), Vector3(x1 + 0.5, 0.55, hw), Color("5c6066"), 0.25, 0.06)
	k.glow(Vector3(x1 + 0.5, 0.4, -0.9), Vector3(x1 + 0.52, 0.5, -0.7), Color("ff7a33"))
	k.glow(Vector3(x1 + 0.5, 0.4, 0.7), Vector3(x1 + 0.52, 0.5, 0.9), Color("ff7a33"))
	if k.age == Age.WORN:
		for i in 6:
			var rx := x0 + 1.3 + i * 0.45
			k.block(Vector3(rx, 1.05 + 0.1 * (i % 3), -hw + 0.03), Vector3(rx + 0.18, 1.2 + 0.1 * (i % 3), -hw + 0.04), rust, 0.1, 0.1, false)
	var tag := VenueSign.make([["RINK-1" if k.age != Age.RENOVATED else "// E-RINK", VenueSign.WHITE]], 9, 1, 0.02)
	tag.name = "ResurfacerTag"
	tag.background = stripe.darkened(0.3)
	k.sign(tag, Transform3D(Basis(Vector3.UP, PI), Vector3((x0 + x1) * 0.5 + 0.6, 1.62, -hw - 0.01)))
