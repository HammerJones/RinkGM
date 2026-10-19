extends VenueRoom
## The rink manager's office on the mezzanine above the lobby, with a window
## over the ice and the RINK-OS terminal: the in-world home of the
## renovation story (and of the pixel-terminal UI).

const X0 := -Venue.HALF_X + Venue.WALL_T
const X1 := -40.0
const Z0 := -13.7
const Z1 := -6.0
const Y := Venue.LOBBY_H + 0.3
const H := 2.6

var _terminal: VenueSign


func _ready() -> void:
	room_id = "office"
	display_name = "Manager's office"
	bounds = AABB(Vector3(X0, Y, Z0), Vector3(X1 - X0, H, Z1 - Z0))
	spawn = Vector3(X1 + 1.0, Y, -7.2)


func build(k: VenueKit) -> void:
	var panel: Color = k.by_age(Color("6b5136"), Color("8a7a62"), Color("d8d4cb"))
	k.wall_z(X1, Z0, Z1, Y, Y + H, 0.2, panel, [
		{"at": -7.2, "w": 1.0, "y0": Y, "y1": Y + 2.2},
		{"at": -10.5, "w": 3.0, "y0": Y + 0.9, "y1": Y + 2.1},
	], 0.5)
	k.glass(Vector3(X1 - 0.03, Y + 0.9, -12.0), Vector3(X1 + 0.03, Y + 2.1, -9.0))
	add_door(k, Vector3(X1, Y, -7.2), PI * 0.5, VenueDoor.Kind.SWING, 0.95, 2.2, k.by_age(Color("5d4a36"), Color("6b5a44"), home_primary().darkened(0.3)), "Office")
	k.wall_x(Z1, X0, X1, Y, Y + H, 0.2, panel, [], 0.5)
	k.wall_x(Z0 - 0.15, X0, X1, Y, Y + H, 0.3, panel, [], 0.5)
	k.slab(Vector3(X0, Y + H, Z0), Vector3(X1 + 0.1, Y + H + 0.15, Z1), panel.darkened(0.2), 0.5, 0.04)
	k.slab(Vector3(X0, Y + H - 0.02, Z0), Vector3(X1, Y + H, Z1), k.by_age(Color("b8b09a"), Color("cfc9b6"), Color("eceae4")), 0.6, 0.04, true, false)
	# carpet
	k.block(Vector3(X0, Y, Z0), Vector3(X1, Y + 0.02, Z1), k.by_age(Color("5a4a3a"), Color("4a5260"), home_primary().darkened(0.45)), 0.5, 0.08, false)
	# desk, chair, filing cabinet, the terminal
	var desk: Color = k.by_age(Color("5c4330"), Color("6b4f38"), Color("2a2e36"))
	k.aged_block(Vector3(-42.6, Y, -12.0), Vector3(-41.0, Y + 0.75, -9.8), desk, 0.4)
	k.block(Vector3(-43.8, Y, -11.2), Vector3(-43.3, Y + 0.48, -10.7), Color("2b2d33"), 0.25, 0.05)
	k.block(Vector3(-43.9, Y + 0.48, -11.2), Vector3(-43.8, Y + 1.1, -10.7), Color("2b2d33"), 0.25, 0.05)
	k.aged_block(Vector3(X0, Y, -13.6), Vector3(X0 + 0.7, Y + 1.35, -13.0), Color("7d8288"), 0.3)
	var crt: Color = k.by_age(Color("c9c0a8"), Color("c9c0a8"), Color("1b1d22"))
	var depth: float = k.by_age(0.5, 0.5, 0.08)
	k.block(Vector3(-42.2, Y + 0.75, -11.3), Vector3(-42.2 + depth, Y + 1.25, -10.5), crt, 0.2, 0.03)
	_terminal = VenueSign.make(_terminal_lines(), 18, 5, 0.0075)
	_terminal.name = "RinkOS"
	_terminal.dead = k.by_age(0.02, 0.0, 0.0)
	k.sign(_terminal, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-42.21, Y + 1.0, -10.9)))
	room_light(k, Vector3(-42.7, Y + H - 0.3, -9.8), 5.0)
	# a wall calendar and the ceiling light
	var cal := VenueSign.make([["// OCT", VenueSign.RED], ["GAME NIGHT", Color("1b1d22")]], 10, 2, 0.02)
	cal.name = "Calendar"
	cal.background = Color("e8e4da")
	k.sign(cal, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(X0 + 0.01, Y + 1.6, -8.0)))
	_m1(k)
	k.glow(Vector3(-43.5, Y + H - 0.06, -10.4), Vector3(-42.0, Y + H - 0.02, -9.8), k.by_age(Color("e6f0d8"), Color("f4f6f0"), Color("fff6e6")))


func _terminal_lines() -> Array:
	var done := 0
	var total := 0
	if venue and venue.get("rooms"):
		for id in venue.rooms:
			total += 1
			if venue.rooms[id].age == Age.RENOVATED:
				done += 1
	return [
		["// RINK-OS V0.1", VenueSign.CYAN], ["----", VenueSign.DIM],
		["> RENOVATED %d/%d" % [done, total], VenueSign.GREEN],
		["> FACILITY: %s" % AGE_NAMES[age].to_upper(), VenueSign.AMBER],
		["> _", VenueSign.WHITE],
	]


## RINK_SIM M1: the desk, the rotary phone, last month's power bill, the
## corkboard of goals and the ice grid whiteboard, each a spot that opens
## UI's office screens (or reads, for the bill).
func _m1(k: VenueKit) -> void:
	var beige := Color("cbbf9f")
	k.block(Vector3(-41.55, Y + 0.75, -11.85), Vector3(-41.15, Y + 0.86, -11.45), beige, 0.1, 0.03, false)
	k.block(Vector3(-41.5, Y + 0.86, -11.82), Vector3(-41.2, Y + 0.9, -11.48), beige.darkened(0.2), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.SCREEN, "office_phone", Vector3(-41.35, Y + 0.85, -11.65), "Phone", {"screen": "phone"}, 1.4)
	if k.age != Age.RENOVATED:
		k.block(Vector3(-41.75, Y + 0.75, -10.5), Vector3(-41.45, Y + 0.755, -10.1), Color("eeeae0"), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.READ, "power_bill", Vector3(-41.6, Y + 0.8, -10.3), "Electricity bill", {"note": "power_bill"}, 1.3)
	add_spot(k, VenueSpot.Kind.SCREEN, "office_desk", Vector3(-41.8, Y + 0.8, -10.9), "Desk", {"screen": "desk"}, 1.4)
	# corkboard on the inner wall, sticky notes for the week's goals
	var cork := Color("a9814f")
	k.block(Vector3(-44.4, Y + 1.15, Z1 - 0.13), Vector3(-42.4, Y + 2.05, Z1 - 0.1), cork, 0.3, 0.06, false)
	for i in 4:
		var nx := -44.2 + i * 0.48
		k.block(Vector3(nx, Y + 1.5 + (i % 2) * 0.2, Z1 - 0.135), Vector3(nx + 0.3, Y + 1.78 + (i % 2) * 0.2, Z1 - 0.13), Color("f2e27a"), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.SCREEN, "corkboard", Vector3(-43.4, Y + 1.6, Z1 - 0.15), "Corkboard", {"screen": "goals"}, 1.6)
	# the ice grid whiteboard with its magnets
	k.block(Vector3(-44.8, Y + 1.0, Z0 - 0.02), Vector3(-42.9, Y + 2.0, Z0 + 0.02), Color("eef0f0"), 0.3, 0.02, false)
	for i in 10:
		var mx := -44.6 + (i % 5) * 0.34
		k.block(Vector3(mx, Y + 1.3 + (i / 5) * 0.35, Z0 + 0.02), Vector3(mx + 0.1, Y + 1.38 + (i / 5) * 0.35, Z0 + 0.04), [Color("c8191e"), Color("1d3557"), Color("2a8a4a"), Color("e0b020")][i % 4], 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.SCREEN, "ice_grid", Vector3(-43.85, Y + 1.5, Z0 + 0.05), "Ice grid", {"screen": "ice_grid"}, 1.6)
