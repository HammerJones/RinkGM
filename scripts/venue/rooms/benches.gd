extends VenueRoom
## The two player benches on the -Z side: rubber floor, the bench, a low
## back wall, glass partitions at the ends, stick racks and water bottles.
## Home bench is on the -X half. Each bench has a gate onto the ice at both
## ends (the centre-ice one fresh skaters step on from, Game.bench_spot; the
## far one tired skaters come off at, Game.bench_exit; Shell.GATES) and a
## half door to the walkway in its centre-ice end wall.

const BENCHES := [[-11.4, -2.6], [2.6, 11.4]]
const Shell := preload("res://scripts/venue/rooms/shell.gd")
## World: the walkway door's span along the end wall (z), clear of the bench
## seat at the back and the ice gate at the boards (W11).
const END_DOOR_Z := -14.4
const END_DOOR_W := 0.95


func _ready() -> void:
	room_id = "benches"
	display_name = "Player benches"
	bounds = AABB(Vector3(-11.4, 0, -Venue.BENCH_BACK), Vector3(22.8, 2.5, Venue.BENCH_BACK - Venue.BOARD_OUT))
	spawn = Vector3(-7.0, 0, -14.2)


## One standing spot behind each bench (spawn is the home one).
func places() -> Dictionary:
	return {"bench": [Vector3(7.0, 0, -14.2)]}


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
		# the bench: 2 m kit sections facing the ice
		var n := int((x1 - x0 - 0.4) / 2.0)
		var bx0 := (x0 + x1) * 0.5 - n * 1.0
		for i in n:
			k.prop("player_bench", Vector3(bx0 + 1.0 + i * 2.0, 0, z1 + 0.3), PI)
		# World: a solid back wall; the walkway door is in the centre-ice end
		# wall, at right angles to the bench (W11)
		var wall: Color = k.by_age(Color("8a8378"), Color("9b958a"), Color("2a2e36"))
		var leaf: Color = k.by_age(Color("6d6a64"), Color("7a828c"), team_col.darkened(0.2))
		k.wall_x(z1 - 0.12, x0, x1, 0, 1.3, 0.25, wall)
		var door_x := x1 if home else x0
		add_door(k, Vector3(door_x, 0, END_DOOR_Z), PI * 0.5, VenueDoor.Kind.SWING, 0.9, 1.25, leaf, "Bench %s" % ("home" if home else "away"))
		# end partitions, solid low and glass above; the door end has its opening
		var dz0 := END_DOOR_Z + END_DOOR_W * 0.5
		var dz1 := END_DOOR_Z - END_DOOR_W * 0.5
		for ex in [x0, x1]:
			if ex == door_x:
				k.aged_block(Vector3(ex - 0.08, 0, dz0), Vector3(ex + 0.08, 1.3, z0), wall, 0.5)
				k.aged_block(Vector3(ex - 0.08, 0, z1 - 0.25), Vector3(ex + 0.08, 1.3, dz1), wall, 0.5)
			else:
				k.aged_block(Vector3(ex - 0.08, 0, z1 - 0.25), Vector3(ex + 0.08, 1.3, z0), wall, 0.5)
			k.glass(Vector3(ex - 0.03, 1.3, z1 - 0.25), Vector3(ex + 0.03, 2.5, z0))
		# World: the two gates onto the ice, one at each end (W9, W10)
		for g: Array in Shell.GATES:
			var gx0: float = g[1]
			var gx1: float = g[2]
			if g[0] == "z-" and gx0 >= x0 - 0.01 and gx1 <= x1 + 0.01:
				_ice_gate(k, gx0, gx1, leaf, x0)
		# World: real sticks leaning on the back wall from the walkway side
		# (playtest #40): StickProp bodies on a walk, static copies in a match;
		# a rubber blade mat under them. Bottles on the wall's cap.
		var rack_x := x0 + 0.6 if home else x1 - 3.6
		var face := z1 - 0.245
		var pal := Models.team_palette("", team_col, home_secondary() if home else Color("eeeeea"))
		var mix := StickProps.room_mix(pal, 30 + bi, 10, 10, 0.75)
		var vs: Array[Dictionary] = []
		var poses: Array[Transform3D] = []
		for i in 10:
			var v: Dictionary = mix[i]
			vs.append(v)
			poses.append(StickProps.pose(v, StickProps.lean_slot(Vector3(rack_x + i * 0.3, 1.33, face - 0.022), Vector3.BACK, 12.0)))
		StickProps.place(k, vs, poses, StickProps.walkable(self))
		k.block(Vector3(rack_x - 0.2, 0.0, face - 0.7), Vector3(rack_x + 2.9, 0.012, face), Color("1b1c1f"), 0.5, 0.04, false)
		for i in 8:
			var bx := (x0 + x1) * 0.5 - 1.2 + i * 0.3
			var bottle: Color = Color(["2f80c8", "d8d4c7", "c84b2f", "3e8f4f"][i % 4]) if k.age == VenueRoom.Age.WORN else team_col.lightened(0.1)
			k.block(Vector3(bx - 0.035, 1.3, z1 - 0.15), Vector3(bx + 0.035, 1.52, z1 - 0.08), bottle, 0.5, 0.05, false)
		if k.age == VenueRoom.Age.RENOVATED:
			k.glow(Vector3(x0 + 0.1, 1.22, z1 + 0.01), Vector3(x1 - 0.1, 1.27, z1 + 0.02), team_col.lightened(0.35))
		var label := VenueSign.make([["// " + ("HOME" if home else "VISITORS"), VenueSign.CYAN if home else VenueSign.AMBER]], 12, 1, 0.025)
		label.name = "BenchSign%d" % bi
		label.dead = k.by_age(0.05, 0.0, 0.0)
		k.sign(label, Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, 0.95, z1 + 0.02)))
	# the morning ice check: Gus's screwdriver, from the home bench's
	# centre-ice gate (Game.bench_spot)
	add_spot(k, VenueSpot.Kind.JOB, "ice_check", Vector3(-3.05, 1.0, z0 - 0.3), "Check the ice",
		{"job": "ice_check", "target": "ice", "readable": "note_screwdriver"}, 1.6)


## World: a gate leaf cut into the boards over the walker's gap (Shell.GATES):
## seams on both faces, two hinges at the end nearer the bench's own end wall,
## a drop latch at the other.
func _ice_gate(k: VenueKit, gx0: float, gx1: float, col: Color, bench_x0: float) -> void:
	var zi := -Rink.HALF_W
	var zo := -Venue.BOARD_OUT
	var top := Rink.BOARD_H
	var seam := Color("1b1c1f")
	k.block(Vector3(gx0 + 0.02, 0.05, zo - 0.035), Vector3(gx1 - 0.02, top - 0.04, zo), col, 0.5, 0.03, false)
	for sx: float in [gx0, gx1]:
		k.block(Vector3(sx - 0.012, 0.02, zo - 0.04), Vector3(sx + 0.012, top, zo + 0.01), seam, 0.5, 0.0, false)
		k.block(Vector3(sx - 0.01, 0.02, zi - 0.004), Vector3(sx + 0.01, top - 0.02, zi + 0.002), seam, 0.5, 0.0, false)
	var near_x0 := absf(gx0 - bench_x0) < 1.5
	var hx := gx0 + 0.05 if near_x0 else gx1 - 0.05
	var lx := gx1 - 0.08 if near_x0 else gx0 + 0.08
	for hy: float in [0.2, top - 0.25]:
		k.block(Vector3(hx - 0.03, hy, zo - 0.06), Vector3(hx + 0.03, hy + 0.12, zo - 0.03), Color("8a8f96"), 0.5, 0.0, false)
	k.block(Vector3(lx - 0.025, top - 0.35, zo - 0.08), Vector3(lx + 0.025, top - 0.12, zo - 0.035), Color("b8bcc2"), 0.5, 0.0, false)
