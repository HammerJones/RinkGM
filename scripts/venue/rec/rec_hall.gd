extends RecRoom
## The main hall (the long corridor of the wing, 78 m from the front desk to
## the loading end) and the short link from the arena's north-east fire exit.
## The hall's walls belong to the rooms off it, so it only adds a wainscot
## between their doors, painted wayfinding stripes, benches, a fountain and
## the programme boards.

const ORANGE := Color("c8642a")
const BLUE := Color("3f6fa8")


func floor_color(k: VenueKit) -> Color:
	if plan_id == "rec_link":
		return Wear.RUBBER.lightened(0.12)  # skate-safe rubber
	return k.by_age(Color("b9ad90"), Color("c6bea9"), Color("a7a6a2"))


func furnish(k: VenueKit) -> void:
	if plan_id == "rec_link":
		_link(k)
		return
	# two wayfinding stripes the length of the hall: orange to the arena,
	# blue to the gym (worn ones are scuffed through in the busy spots)
	for s in [[ORANGE, -42.25], [BLUE, -41.75]]:
		var x := x0
		while x < x1:
			var seg := minf(2.0, x1 - x)
			if not (k.age == Age.WORN and posmod(hash(Vector2(x, s[1])), 5) == 0):
				k.block(Vector3(x, 0, s[1] - 0.12), Vector3(x + seg, 0.006, s[1] + 0.12), k.aged(s[0], x), 1.0, 0.04, false)
			x += seg
	var panel: Color = k.by_age(Wear.OLD_WOOD_DARK, Wear.OLD_WOOD, Color("c9c7c2"))
	for side in [[z1, -1.0], [z0, 1.0]]:
		var face: float = side[0] + side[1] * 0.0
		for span in free_spans("x", side[0], x0, x1, 0.15):
			k.aged_block(Vector3(span.x, 0, face), Vector3(span.y, 0.95, face + side[1] * 0.025), panel, 0.6, 0.05, false)
			k.block(Vector3(span.x, 0.95, face), Vector3(span.y, 1.0, face + side[1] * 0.04), panel.darkened(0.25), 0.6, 0.0, false)
	_benches(k)
	_boards(k)
	# drinking fountain by the washrooms
	var steel := Color("b8bcc2") if k.age != Age.WORN else Color("9a9ea2")
	k.block(Vector3(-16.9, 0.75, z1 - 0.4), Vector3(-16.1, 0.95, z1), steel, 0.2, 0.03)
	k.block(Vector3(-16.7, 0, z1 - 0.2), Vector3(-16.3, 0.75, z1), steel.darkened(0.2), 0.2, 0.03)
	k.prop("trash_can", Vector3(-15.5, 0, z1 - 0.3), PI)
	k.prop("vending_machine", Vector3(30.5, 0, z0 + 0.45), PI)
	# exit sign over the east doors
	var ex := VenueSign.make([["EXIT", VenueSign.GREEN]], 4, 1, 0.025)
	ex.name = "ExitSign"
	k.sign(ex, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x1 - 0.32, 2.6, -42.0)))


## Spans of the wall face on edge line `line` (along X) not cut by a door.
func free_spans(along: String, line: float, s0: float, s1: float, margin: float) -> Array[Vector2]:
	var cuts := []
	for d in RecPlan.doors_on(along, line, s0, s1):
		var pos: float = d[1] if along == "x" else d[2]
		cuts.append(Vector2(pos - d[4] * 0.5 - margin, pos + d[4] * 0.5 + margin))
	# the pro shop's display windows sit above the wainscot; the link is open
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var out: Array[Vector2] = []
	var cur := s0
	for c in cuts:
		if c.x > cur + 0.3:
			out.append(Vector2(cur, c.x))
		cur = maxf(cur, c.y)
	if s1 > cur + 0.3:
		out.append(Vector2(cur, s1))
	return out


func _benches(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), Color("2a2e36"))
	var i := 0
	for side in [[z1, -1.0], [z0, 1.0]]:
		for span in free_spans("x", side[0], x0, x1, 0.6):
			if span.y - span.x < 3.2:
				continue
			if posmod(i, 2) == 0:
				var cx := (span.x + span.y) * 0.5
				var zf: float = side[0] + side[1] * 0.1
				bench(k, Vector3(cx - 1.2, 0, zf), Vector3(cx + 1.2, 0, zf + side[1] * 0.45), wood)
			i += 1


## Programme boards on the hall walls: what the centre still runs.
func _boards(k: VenueKit) -> void:
	var programs := [
		["// PROGRAMS", VenueSign.AMBER], ["----", VenueSign.DIM],
		["LEARN TO SKATE   SAT 9AM", VenueSign.CYAN, true], ["PICKLEBALL   MON/WED 6PM", VenueSign.CYAN, true],
		["YOUTH HOOPS      FRI 7PM", VenueSign.CYAN, true], ["SENIOR FIT       TUE 10AM", VenueSign.CYAN, true],
		["BINGO           THU 7PM", VenueSign.CYAN, true],
	]
	wall_sign(k, programs, 25, 7, 0.02, Vector3(-28.0, 1.9, z0), Vector3(0, 0, 1), "ProgramsBoard")
	var hockey := [
		["// MINOR HOCKEY", VenueSign.AMBER], ["----", VenueSign.DIM],
		["U9 TRYOUTS     SEPT 14", VenueSign.CYAN, true], ["REFS WANTED  SEE DESK", VenueSign.WHITE, true],
		["DRESSING ROOMS 3-6", VenueSign.WHITE, true], ["   -> THIS HALL", VenueSign.WHITE, true],
	]
	wall_sign(k, hockey, 22, 6, 0.02, Vector3(13.5, 1.9, z1), Vector3(0, 0, -1), "HockeyBoard")
	# hanging direction signs every 20 m
	for x in [-20.0, 4.0, 28.0]:
		# back to back: westbound walkers read one face, eastbound the other
		for f in [[PI * 0.5, "// FRONT DESK  ENTRANCE", 0.03], [-PI * 0.5, "// GYM  ROOMS 3-6  WORKSHOP", -0.03]]:
			var dir := VenueSign.make([[f[1], VenueSign.CYAN]], String(f[1]).length() + 1, 1, 0.02)
			dir.name = "Wayfinding%d_%d" % [int(x), 0 if f[2] > 0 else 1]
			dir.dead = k.by_age(0.05, 0.0, 0.0)
			k.sign(dir, Transform3D(Basis(Vector3.UP, f[0]), Vector3(x + f[2], h - 0.45, -42.0)))
		k.block(Vector3(x - 0.02, h - 0.3, -43.4), Vector3(x + 0.02, h, -43.36), Color("3a3d44"), 0.2, 0.0, false)
		k.block(Vector3(x - 0.02, h - 0.3, -40.64), Vector3(x + 0.02, h, -40.6), Color("3a3d44"), 0.2, 0.0, false)


func _link(k: VenueKit) -> void:
	var wood: Color = k.by_age(Color("7a5c3c"), Color("8a6a45"), Color("2a2e36"))
	bench(k, Vector3(x0 + 0.1, 0, -37.5), Vector3(x0 + 0.55, 0, -33.0), wood)
	bench(k, Vector3(x1 - 0.55, 0, -37.5), Vector3(x1 - 0.1, 0, -33.0), wood)
	wall_sign(k, [["// ARENA", VenueSign.CYAN], ["SKATE GUARDS ON", VenueSign.AMBER, true]], 15, 2, 0.022, Vector3(40.0, 2.6, -30.0), Vector3(0, 0, -1), "LinkSign")
	k.prop("trash_can", Vector3(x0 + 0.35, 0, -31.0), PI * 0.5)
