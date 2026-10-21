extends RecRoom
## The centre's offices behind the front desk: programs, bookings and the
## director, each with a desk and a filing cabinet, and the meeting room at
## the back with its long table, the facility plan on the whiteboard and the
## staff coffee corner. The doors open onto the front lobby.

const SPLITS := [-41.33, -36.67]
const BACK := -52.0


func windows(along: String, line: float) -> Array:
	if along == "x" and absf(line - RecPlan.Z_BACK) < 0.05:
		return [{"at": -43.0, "w": 2.4, "y0": 1.0, "y1": 2.3}, {"at": -39.0, "w": 2.4, "y0": 1.0, "y1": 2.3}, {"at": -35.0, "w": 2.4, "y0": 1.0, "y1": 2.3}]
	return []


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("6a5a44"), Color("4a5260"), Color("5b5f66"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("b8a888"), Color("cfc8b4"), Color("e6e4de"))


func furnish(k: VenueKit) -> void:
	var wall := paint(k)
	for x in SPLITS:
		partition(k, "z", x, BACK, z1, wall)
	partition(k, "x", BACK, x0, x1, wall)
	var names := ["PROGRAMS", "BOOKINGS", "DIRECTOR"]
	var edges := [x0 + 0.15, SPLITS[0], SPLITS[1], x1 - 0.15]
	for i in 3:
		_office(k, edges[i] + 0.1, edges[i + 1] - 0.1, names[i], i)
	_meeting(k)
	RecDetail.offices(self, k)  # World: detail pass (#23, #27)


func _office(k: VenueKit, a: float, b: float, title: String, i: int) -> void:
	var desk: Color = k.by_age(Color("5c4330"), Color("6b4f38"), Color("2a2e36"))
	# desk facing the door, the chair behind it, a visitor's chair in front;
	# the middle office keeps a path clear to the meeting room door
	var cx := (a + b) * 0.5 - (1.3 if i == 1 else 0.0)
	k.aged_block(Vector3(cx - 0.8, 0, -49.6), Vector3(cx + 0.8, 0.75, -48.8), desk, 0.4)
	k.block(Vector3(cx - 0.25, 0, -50.5), Vector3(cx + 0.25, 0.48, -50.0), Color("2b2d33"), 0.25, 0.05)
	k.block(Vector3(cx - 0.25, 0.48, -50.6), Vector3(cx + 0.25, 1.05, -50.5), Color("2b2d33"), 0.25, 0.05, false)
	k.block(Vector3(cx - 0.6, 0, -47.6), Vector3(cx - 0.15, 0.46, -47.15), Color("7d5a3a"), 0.25, 0.05)
	var crt: Color = k.by_age(Color("c9c0a8"), Color("c9c0a8"), Color("1b1d22"))
	k.block(Vector3(cx + 0.1, 0.75, -49.5), Vector3(cx + 0.6, 1.15, -49.0 if k.age != Age.RENOVATED else -49.4), crt, 0.2, 0.03, false)
	# filing cabinet and a bookshelf
	k.aged_block(Vector3(a, 0, -51.8), Vector3(a + 0.5, 1.35, -51.2), Color("7d8288"), 0.3)
	shelves(k, Vector3(b - 0.4, 0, -51.8), Vector3(b, 1.8, -50.0), 4, Color("6b4f33"), [Color("1d3557"), Color("c8191e"), Color("e0b020"), Color("eeeeea")])
	# one keepsake each: a framed jersey, a plant, a pennant
	match i:
		0: k.block(Vector3(a, 1.4, -47.0), Vector3(a + 0.04, 2.1, -46.2), home_primary(), 0.2, 0.04, false)
		1: k.block(Vector3(b - 0.5, 0, -45.0), Vector3(b - 0.2, 0.9, -44.7), Color("2a6a4a"), 0.2, 0.08, false)
		2: k.block(Vector3(cx - 0.6, 2.0, BACK + 0.11), Vector3(cx + 0.6, 2.35, BACK + 0.13), Wear.OLD_GOLD, 0.2, 0.04, false)
	wall_sign(k, [["// " + title, VenueSign.CYAN]], title.length() + 4, 1, 0.014, Vector3(cx, 2.4, BACK + 0.11), Vector3(0, 0, 1), "Nameplate%d" % i)
	rec_light(k, Vector3(cx, h - 0.4, -48.0), 4.5)


func _meeting(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("5c4330"), Color("6b4f38"), Color("3a3d44"))
	table(k, Vector3(-43.5, 0, -57.4), Vector3(-36.5, 0, -55.6), 0.75, wood)
	for i in 6:
		for s in [-1, 1]:
			var x := -43.0 + i * 1.2
			var z := -56.5 + float(s) * 1.25
			k.block(Vector3(x, 0, z - 0.22), Vector3(x + 0.45, 0.46, z + 0.22), Color("2b2d33"), 0.25, 0.05)
	# the whiteboard: the plan for the building
	var plan := [
		["// FACILITY PLAN", Color("1d3f8a")], ["----", Color("8a8f99")],
		["1. FIX GYM ROOF LEAK", Color("1b1d22")], ["2. NEW DRESSING RM FLOORS", Color("1b1d22")],
		["3. GRANT APP DUE MAR 1", Color("b8312f")],
	]
	var board := wall_sign(k, plan, 25, 5, 0.02, Vector3(x0 + 0.15, 1.7, -56.5), Vector3(1, 0, 0), "FacilityPlan", Color("eef0f2") if k.age != Age.WORN else Color("d8d6cc"))
	board.dead = 0.0
	# the coffee corner: counter, coffee maker, a small fridge
	k.aged_block(Vector3(-34.6, 0, -59.7), Vector3(-32.2, 0.9, -59.1), Color("7d8288"), 0.4)
	k.block(Vector3(-34.3, 0.9, -59.6), Vector3(-33.9, 1.3, -59.25), Color("1b1d22"), 0.2, 0.03, false)
	k.block(Vector3(-33.0, 0, -58.9), Vector3(-32.25, 0.85, -58.2), Color("e8e8e2"), 0.2, 0.03)
	rec_light(k, Vector3(-42.0, h - 0.4, -56.0), 7.0)
	rec_light(k, Vector3(-36.0, h - 0.4, -56.0), 7.0)


func lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("e6eed8"), Color("f4f6f0"), Color("fff6e6"))
	for x in [-43.67, -39.0, -34.33]:
		k.glow(Vector3(x - 0.5, h - 0.05, -48.2), Vector3(x + 0.5, h - 0.01, -47.9), lit)
		k.glow(Vector3(x - 0.5, h - 0.05, -56.2), Vector3(x + 0.5, h - 0.01, -55.9), lit)
