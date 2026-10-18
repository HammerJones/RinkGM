extends VenueRoom
## The penalty boxes and the timekeeper's box between them on the +Z side.
## The timekeeper's RINK-OS terminal shows the live game clock.

const BOXES := [[-5.8, -1.5], [-1.5, 1.5], [1.5, 5.8]]  # home box, timekeeper, away box

var _terminal: VenueSign


func _ready() -> void:
	room_id = "penalty_boxes"
	display_name = "Penalty boxes"
	bounds = AABB(Vector3(-5.8, 0, Venue.BOARD_OUT), Vector3(11.6, 2.5, Venue.BENCH_BACK - Venue.BOARD_OUT))
	spawn = Vector3(0, 0, 14.6)


## Inside the home and away boxes.
func places() -> Dictionary:
	return {"penalty_box": [Vector3(-3.65, 0, 14.2), Vector3(3.65, 0, 14.2)]}


func build(k: VenueKit) -> void:
	var z0 := Venue.BOARD_OUT
	var z1 := Venue.BENCH_BACK
	var wall: Color = k.by_age(Color("8a8378"), Color("9b958a"), Color("2a2e36"))
	var floor_col: Color = k.by_age(Color("2b2c30"), Color("303237"), Color("1d1f24"))
	k.aged_block(Vector3(-5.8, 0, z0), Vector3(5.8, 0.06, z1), floor_col, 0.5, 0.08)
	for i in BOXES.size():
		var x0: float = BOXES[i][0]
		var x1: float = BOXES[i][1]
		var cx := (x0 + x1) * 0.5
		if i == 1:
			k.wall_x(z1 + 0.12, x0, x1, 0, 1.3, 0.25, wall, [{"at": cx, "w": 0.95, "y0": 0.0, "y1": 1.3}])
		else:
			# the kit's booth: open to the ice, benches either side of the back door
			k.prop("penalty_box", Vector3(cx, 0, (z0 + z1) * 0.5), 0.0, false)
			var gap := Props.PENALTY_DOOR_W * Props.V * 0.5
			k.collider(Vector3(x0, 0, z1 - 0.1), Vector3(cx - gap, 1.3, z1 + 0.25))
			k.collider(Vector3(cx + gap, 0, z1 - 0.1), Vector3(x1, 1.3, z1 + 0.25))
		add_door(k, Vector3(cx, 0, z1 + 0.12), PI, VenueDoor.Kind.SWING, 0.9, 1.25, k.by_age(Color("6d6a64"), Color("7a828c"), Color("3a404a")), ["Box home", "Timekeeper", "Box away"][i])
		k.glass(Vector3(x0, 1.3, z1 + 0.1), Vector3(x1, 2.5, z1 + 0.14))
		if i != 1:
			var pen := VenueSign.make([["// PENALTY", VenueSign.RED], ["--:--", VenueSign.AMBER, true]], 10, 2, 0.022)
			pen.name = "PenaltyClock%d" % i
			pen.dead = k.by_age(0.05, 0.0, 0.0)
			k.sign(pen, Transform3D(Basis(Vector3.UP, PI), Vector3(cx, 2.8, z0 + 0.02)))
	for x in [-5.8, -1.5, 1.5, 5.8]:
		k.aged_block(Vector3(x - 0.08, 0, z0), Vector3(x + 0.08, 1.3, z1 + 0.25), wall, 0.5)
		k.glass(Vector3(x - 0.03, 1.3, z0), Vector3(x + 0.03, 2.5, z1 + 0.25))
	# timekeeper: desk by the glass, terminal, horn
	k.aged_block(Vector3(-1.3, 0, z0 + 0.05), Vector3(1.3, 0.95, z0 + 0.6), k.by_age(Color("6b5a44"), Color("7a6a52"), Color("23262c")), 0.4)
	k.block(Vector3(-0.45, 0.95, z0 + 0.2), Vector3(0.45, 1.5, z0 + 0.5), k.by_age(Color("c9c0a8"), Color("b8b4a8"), Color("1b1d22")), 0.3, 0.04)
	k.block(Vector3(0.8, 0.95, z0 + 0.2), Vector3(1.0, 1.1, z0 + 0.4), Color("b8312f"), 0.2, 0.0)
	k.aged_block(Vector3(-0.3, 0, z0 + 1.0), Vector3(0.3, 0.48, z0 + 1.4), Color("3a3d44"), 0.3)
	_terminal = VenueSign.make([["// GAME CLOCK", VenueSign.CYAN], ["----", VenueSign.DIM], ["1ST 20:00", VenueSign.AMBER, true]], 12, 3, 0.009)
	_terminal.name = "TimekeeperTerminal"
	_terminal.dead = k.by_age(0.03, 0.0, 0.0)
	k.sign(_terminal, Transform3D(Basis.IDENTITY, Vector3(0, 1.22, z0 + 0.505)))


func show_score(st: Dictionary, home: String, away: String) -> void:
	if is_instance_valid(_terminal):
		_terminal.set_lines([["// GAME CLOCK", VenueSign.CYAN], ["%s %d  %s %d" % [home, st.home, away, st.away], VenueSign.WHITE], ["%s %s" % [st.period, st.clock], VenueSign.AMBER, true]])
