extends VenueRoom
## The penalty boxes and the timekeeper's box between them on the +Z side.
## The boxes open only to the ice (their back wall carries on behind them);
## the timekeeper's box has a full-height door from the walkway, a round
## talk hole in the glass for the referee, and a paper slot through each
## side glass to the boxes. The timekeeper's RINK-OS terminal shows the live
## game clock.

const BOXES := [[-5.8, -1.5], [-1.5, 1.5], [1.5, 5.8]]  # home box, timekeeper, away box
const TOP := 1.3       # the walls' top, level with the boards
const GLASS_TOP := 2.5
const KEEPER_DOOR := [1.0, 2.1]
## The paper slots: a gap in the side glass where it meets the wall.
const SLOT := Vector2(0.32, 0.07)
## The talk hole in the rink glass in front of the timekeeper.
const TALK_HOLE := Vector3(0.6, 1.8, Rink.HALF_W + 0.16)

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
			# the timekeeper's own door from the walkway, glass either side
			var dw: float = KEEPER_DOOR[0]
			var dh: float = KEEPER_DOOR[1]
			k.wall_x(z1 + 0.12, x0, x1, 0, TOP, 0.25, wall, [{"at": cx, "w": dw, "y0": 0.0, "y1": TOP}])
			k.aged_block(Vector3(cx - dw * 0.5 - 0.06, 0, z1 + 0.04), Vector3(cx - dw * 0.5, GLASS_TOP, z1 + 0.2), wall, 0.5)
			k.aged_block(Vector3(cx + dw * 0.5, 0, z1 + 0.04), Vector3(cx + dw * 0.5 + 0.06, GLASS_TOP, z1 + 0.2), wall, 0.5)
			k.aged_block(Vector3(cx - dw * 0.5, dh, z1 + 0.04), Vector3(cx + dw * 0.5, GLASS_TOP, z1 + 0.2), wall, 0.5)
			k.glass(Vector3(x0, TOP, z1 + 0.1), Vector3(cx - dw * 0.5 - 0.06, GLASS_TOP, z1 + 0.14))
			k.glass(Vector3(cx + dw * 0.5 + 0.06, TOP, z1 + 0.1), Vector3(x1, GLASS_TOP, z1 + 0.14))
			add_door(k, Vector3(cx, 0, z1 + 0.12), PI, VenueDoor.Kind.SWING, dw - 0.05, dh, k.by_age(Color("6d6a64"), Color("7a828c"), Color("3a404a")), "Timekeeper")
		else:
			# the kit's booth, open to the ice; its back door gap is walled up
			# so the boards carry on behind it
			k.prop("penalty_box", Vector3(cx, 0, (z0 + z1) * 0.5), 0.0, false)
			var gap := Props.PENALTY_DOOR_W * Props.V * 0.5
			var ply: Color = k.by_age(Wear.PLYWOOD.darkened(0.25), Wear.PLYWOOD.darkened(0.15), Wear.NAVY)
			var patch := z1 - Props.V * 1.5  # just inside the kit's back wall
			k.aged_block(Vector3(cx - gap, Props.V, patch), Vector3(cx + gap, TOP - Props.V, z1), ply, 0.4)
			k.block(Vector3(cx - gap, TOP - Props.V, patch), Vector3(cx + gap, TOP, z1), k.by_age(Wear.OLD_GOLD.darkened(0.2), Wear.OLD_GOLD, Wear.RED), 0.4, 0.04, false)
			k.collider(Vector3(x0, 0, z1 - 0.1), Vector3(x1, TOP, z1 + 0.25))
			k.aged_block(Vector3(x0, 0, z1 + 0.04), Vector3(x1, TOP, z1 + 0.2), wall, 0.5)
			k.glass(Vector3(x0, TOP, z1 + 0.1), Vector3(x1, GLASS_TOP, z1 + 0.14))
		if i != 1:
			var pen := VenueSign.make([["// PENALTY", VenueSign.RED], ["--:--", VenueSign.AMBER, true]], 10, 2, 0.022)
			pen.name = "PenaltyClock%d" % i
			pen.dead = k.by_age(0.05, 0.0, 0.0)
			k.sign(pen, Transform3D(Basis(Vector3.UP, PI), Vector3(cx, 2.8, z0 + 0.02)))
	for x in [-5.8, -1.5, 1.5, 5.8]:
		k.aged_block(Vector3(x - 0.08, 0, z0), Vector3(x + 0.08, TOP, z1 + 0.25), wall, 0.5)
		if absf(x) < 2.0:
			_slotted_glass(k, x, z0, z1 + 0.25)
		else:
			k.glass(Vector3(x - 0.03, TOP, z0), Vector3(x + 0.03, GLASS_TOP, z1 + 0.25))
	_talk_hole(k)
	# timekeeper: desk by the glass, terminal, horn
	k.aged_block(Vector3(-1.3, 0, z0 + 0.05), Vector3(1.3, 0.95, z0 + 0.6), k.by_age(Color("6b5a44"), Color("7a6a52"), Color("23262c")), 0.4)
	k.block(Vector3(-0.45, 0.95, z0 + 0.2), Vector3(0.45, 1.5, z0 + 0.5), k.by_age(Color("c9c0a8"), Color("b8b4a8"), Color("1b1d22")), 0.3, 0.04)
	k.block(Vector3(0.8, 0.95, z0 + 0.2), Vector3(1.0, 1.1, z0 + 0.4), Color("b8312f"), 0.2, 0.0)
	k.aged_block(Vector3(-0.3, 0, z0 + 1.0), Vector3(0.3, 0.48, z0 + 1.4), Color("3a3d44"), 0.3)
	_terminal = VenueSign.make([["// GAME CLOCK", VenueSign.CYAN], ["----", VenueSign.DIM], ["1ST 20:00", VenueSign.AMBER, true]], 12, 3, 0.009)
	_terminal.name = "TimekeeperTerminal"
	_terminal.dead = k.by_age(0.03, 0.0, 0.0)
	k.sign(_terminal, Transform3D(Basis.IDENTITY, Vector3(0, 1.22, z0 + 0.505)))


## The side glass between the timekeeper and a box, with the paper slot cut
## where it meets the wall, halfway along: the wall's cap is the slot's floor.
func _slotted_glass(k: VenueKit, x: float, z0: float, z1: float) -> void:
	var zm := (z0 + z1) * 0.5
	var a := zm - SLOT.x * 0.5
	var b := zm + SLOT.x * 0.5
	k.glass(Vector3(x - 0.03, TOP, z0), Vector3(x + 0.03, GLASS_TOP, a))
	k.glass(Vector3(x - 0.03, TOP, b), Vector3(x + 0.03, GLASS_TOP, z1))
	k.glass(Vector3(x - 0.03, TOP + SLOT.y, a), Vector3(x + 0.03, GLASS_TOP, b))
	# a steel lip over the slot
	var steel := Color("8c9096")
	k.block(Vector3(x - 0.035, TOP + SLOT.y, a - 0.02), Vector3(x + 0.035, TOP + SLOT.y + 0.015, b + 0.02), steel, 0.2, 0.0, false)
	for zz in [a - 0.02, b]:
		k.block(Vector3(x - 0.035, TOP, zz), Vector3(x + 0.035, TOP + SLOT.y, zz + 0.02), steel, 0.2, 0.0, false)


## The round talk hole in the rink glass at the timekeeper's seat: a steel
## grommet ring, open in the middle.
func _talk_hole(k: VenueKit) -> void:
	var c := TALK_HOLE
	var steel := Color("9a9ea4")
	var n := 10
	for i in n:
		var a := TAU * i / n
		var p := c + Vector3(cos(a), sin(a), 0) * 0.085
		var xf := Transform3D(Basis(Vector3(0, 0, 1), a) * Basis.from_scale(Vector3(0.025, 0.06, 0.05)), p)
		k.oriented(xf, steel)


func show_score(st: Dictionary, home: String, away: String) -> void:
	if is_instance_valid(_terminal):
		_terminal.set_lines([["// GAME CLOCK", VenueSign.CYAN], ["%s %d  %s %d" % [home, st.home, away, st.away], VenueSign.WHITE], ["%s %s" % [st.period, st.clock], VenueSign.AMBER, true]])
