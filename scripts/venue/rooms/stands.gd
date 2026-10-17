extends VenueRoom
## A side grandstand: ten rows on concrete risers in seven sections, aisles
## with half-height steps (0.21 m) a walker can climb, a front rail and a
## concourse along the top. Worn stands are splintered bleacher planks with
## gaps, repaired ones are painted planks, renovated ones are individual
## seats in the home colours.

## -1 = the players' bench side (-Z), 1 = the penalty-box side (+Z).
@export var side := -1

const SECTIONS := 7
const AISLE := 1.2
const SEAT_PITCH := 0.55
const CONCRETE := Color("8f8a80")

var _seats: Array = []


func _ready() -> void:
	room_id = "stands_bench" if side < 0 else "stands_box"
	display_name = "Bench-side stands" if side < 0 else "Penalty-box-side stands"
	var z0 := Venue.STAND_FRONT
	var z1 := Venue.HALF_Z - Venue.WALL_T
	bounds = AABB(Vector3(-Venue.STAND_X, 0, minf(side * z0, side * z1)), Vector3(Venue.STAND_X * 2, 7.5, z1 - z0))
	spawn = Vector3(0, top_y(), side * (front(Venue.STAND_ROWS) + 1.5))


static func front(row: int) -> float:
	return Venue.STAND_FRONT + row * Venue.ROW_RUN


static func tread(row: int) -> float:
	return Venue.STAND_Y0 + row * Venue.ROW_RISE


static func top_y() -> float:
	return tread(Venue.STAND_ROWS)


## [[position, facing], ...] for the crowd: one per usable seat.
func seats() -> Array:
	return _seats


func build(k: VenueKit) -> void:
	_seats.clear()
	var s := float(side)
	var span := Venue.STAND_X * 2.0
	var sec_w := (span - AISLE * (SECTIONS + 1)) / SECTIONS
	var concrete: Color = k.by_age(Color("7f7a70"), CONCRETE, Color("a7a39b"))
	var rows := Venue.STAND_ROWS
	# aisles: half steps inside the stand and a short stair down to the walkway
	for a in SECTIONS + 1:
		var ax0 := -Venue.STAND_X + a * (sec_w + AISLE)
		var ax1 := ax0 + AISLE
		for r in rows:
			var f0 := front(r)
			var half := Venue.ROW_RUN * 0.5
			# the first row's front half is level with the walkway stair's top
			var h0 := tread(r) - Venue.ROW_RISE * 0.5 if r > 0 else tread(0)
			k.aged_block(Vector3(ax0, 0, s * f0), Vector3(ax1, h0, s * (f0 + half)), concrete, 0.6)
			k.aged_block(Vector3(ax0, 0, s * (f0 + half)), Vector3(ax1, tread(r), s * (f0 + Venue.ROW_RUN)), concrete, 0.6)
		var steps := 4
		var run := 0.3
		k.stairs(Vector3((ax0 + ax1) * 0.5, 0, s * (Venue.STAND_FRONT - steps * run)), Vector3(0, 0, s), AISLE, Venue.STAND_Y0, steps, run, concrete)
		# yellow nosing on the aisle steps (safety paint, chipped when worn)
		var nose: Color = k.by_age(Color("8f7a2e"), Color("c9a227"), Color("f2c230"))
		for r in rows:
			k.block(Vector3(ax0 + 0.05, tread(r) + 0.001, s * (front(r) + Venue.ROW_RUN - 0.06)), Vector3(ax1 - 0.05, tread(r) + 0.012, s * (front(r) + Venue.ROW_RUN)), nose, 0.3, 0.1, false)
	# sections: one riser block per row, then the seats
	for sec in SECTIONS:
		var x0 := -Venue.STAND_X + AISLE + sec * (sec_w + AISLE)
		var x1 := x0 + sec_w
		for r in rows:
			k.aged_block(Vector3(x0, 0, s * front(r)), Vector3(x1, tread(r), s * front(r + 1)), concrete, 0.6)
			_seat_row(k, x0, x1, r, sec)
		# front rail: glass on a low wall, open at the aisles
		k.aged_block(Vector3(x0, Venue.STAND_Y0, s * (Venue.STAND_FRONT + 0.02)), Vector3(x1, Venue.STAND_Y0 + 0.25, s * (Venue.STAND_FRONT + 0.14)), concrete, 0.6)
		k.glass(Vector3(x0, Venue.STAND_Y0 + 0.25, s * (Venue.STAND_FRONT + 0.06)), Vector3(x1, Venue.STAND_Y0 + 1.05, s * (Venue.STAND_FRONT + 0.1)))
		_section_sign(k, sec, (x0 + x1) * 0.5)
	# concourse along the top, with a rail at its front edge; its front strip
	# carries one more half step at each aisle
	var cz0 := front(rows)
	var cz1 := Venue.HALF_Z - Venue.WALL_T
	var strip := cz0 + Venue.ROW_RUN * 0.5
	k.aged_block(Vector3(-Venue.STAND_X, 0, s * strip), Vector3(Venue.STAND_X, top_y(), s * cz1), concrete, 1.0)
	for a in SECTIONS + 1:
		var ax0 := -Venue.STAND_X + a * (sec_w + AISLE)
		k.aged_block(Vector3(ax0, 0, s * cz0), Vector3(ax0 + AISLE, top_y() - Venue.ROW_RISE * 0.5, s * strip), concrete, 0.6)
		if a < SECTIONS:
			k.aged_block(Vector3(ax0 + AISLE, 0, s * cz0), Vector3(ax0 + AISLE + sec_w, top_y(), s * strip), concrete, 0.6)
	var rail: Color = k.by_age(Color("6b5d4a"), Color("5c6a78"), Color("2a2d33"))
	for sec in SECTIONS:
		var x0 := -Venue.STAND_X + AISLE + sec * (sec_w + AISLE)
		k.block(Vector3(x0, top_y() + 0.95, s * (cz0 + 0.05)), Vector3(x0 + sec_w, top_y() + 1.02, s * (cz0 + 0.12)), rail, 0.5, 0.04)
		for p in 4:
			var px := x0 + sec_w * (p + 0.5) / 4.0
			k.block(Vector3(px - 0.03, top_y(), s * (cz0 + 0.05)), Vector3(px + 0.03, top_y() + 0.95, s * (cz0 + 0.12)), rail, 0.5, 0.0)
		k.collider(Vector3(x0, top_y(), s * (cz0 + 0.05)), Vector3(x0 + sec_w, top_y() + 1.02, s * (cz0 + 0.12)))
	# closing walls at the stand ends (the corner spaces are open floor)
	for ex in [-1, 1]:
		var x: float = ex * (Venue.STAND_X + 0.15)
		k.aged_block(Vector3(x - 0.15, 0, s * Venue.STAND_FRONT), Vector3(x + 0.15, top_y() + 1.0, s * cz1), concrete, 0.6)
	if k.age == VenueRoom.Age.RENOVATED:
		# LED ribbon along the concourse fascia in the home colour
		k.glow(Vector3(-Venue.STAND_X, top_y() - 0.25, s * (cz0 - 0.02)), Vector3(Venue.STAND_X, top_y() - 0.05, s * cz0), home_primary().lightened(0.15))


func _seat_row(k: VenueKit, x0: float, x1: float, r: int, sec: int) -> void:
	var s := float(side)
	var y := tread(r)
	var zf := front(r)
	var facing := Vector3(0, 0, -s)
	match k.age:
		VenueRoom.Age.RENOVATED:
			var n := int(floor((x1 - x0) / 0.5))
			var pad := ((x1 - x0) - n * 0.5) * 0.5
			var c1 := home_primary()
			var c2 := home_primary().darkened(0.25)
			for i in n:
				var cx := x0 + pad + (i + 0.5) * 0.5
				var col := c1 if (r + sec) % 2 == 0 else c2
				if r == Venue.STAND_ROWS - 1:
					col = home_secondary()
				k.block(Vector3(cx - 0.21, y + 0.36, s * (zf + 0.22)), Vector3(cx + 0.21, y + 0.44, s * (zf + 0.6)), col, 0.5, 0.03, false)
				k.block(Vector3(cx - 0.21, y + 0.44, s * (zf + 0.6)), Vector3(cx + 0.21, y + 0.86, s * (zf + 0.66)), col, 0.5, 0.03, false)
				k.block(Vector3(cx - 0.03, y, s * (zf + 0.35)), Vector3(cx + 0.03, y + 0.36, s * (zf + 0.45)), Color("2a2d33"), 0.5, 0.0, false)
				_seats.append([Vector3(cx, y + 0.44, s * (zf + 0.42)), facing])
			k.collider(Vector3(x0, y, s * (zf + 0.22)), Vector3(x1, y + 0.44, s * (zf + 0.6)))
		_:
			# bleacher planks in 1.1 m pieces; worn rows are missing some
			var piece := 1.1
			var n := int(floor((x1 - x0) / piece))
			var pad := ((x1 - x0) - n * piece) * 0.5
			var wood := Color("9a7a52")
			var paint := Color("4f6d8a")
			for i in n:
				var px0 := x0 + pad + i * piece
				var key := Vector3i(sec, r, i * side)
				if k.age == VenueRoom.Age.WORN and posmod(hash(key), 9) == 0:
					continue  # plank gone
				var col: Color = k.aged(wood, key) if k.age == VenueRoom.Age.WORN else (paint if posmod(hash(key), 5) != 0 else wood)
				k.block(Vector3(px0 + 0.02, y + 0.38, s * (zf + 0.2)), Vector3(px0 + piece - 0.02, y + 0.45, s * (zf + 0.55)), col, 0.55, 0.08)
				k.block(Vector3(px0 + 0.45, y, s * (zf + 0.3)), Vector3(px0 + 0.65, y + 0.38, s * (zf + 0.45)), Color("55575c"), 0.5, 0.05, false)
				for j in 2:
					_seats.append([Vector3(px0 + SEAT_PITCH * (j + 0.5), y + 0.45, s * (zf + 0.38)), facing])


func _section_sign(k: VenueKit, sec: int, x: float) -> void:
	var n := (100 if side < 0 else 200) + sec + 1
	var sign := VenueSign.make([[str(n), VenueSign.CYAN if side < 0 else VenueSign.AMBER]], 3, 1, 0.03)
	sign.name = "Section%d" % n
	sign.dead = k.by_age(0.06, 0.0, 0.0)
	var basis := Basis.IDENTITY if side < 0 else Basis(Vector3.UP, PI)
	k.sign(sign, Transform3D(basis, Vector3(x, Venue.STAND_Y0 + 0.13, side * (Venue.STAND_FRONT + 0.0))))
