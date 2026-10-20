extends RecRoom
## The workshop and loading bay at the east end: where the building gets
## fixed. A roll-up door to the yard; two workbenches with vises under the
## pegboard and the clamp rack; the old machine-tool line down the west wall
## (a toolroom lathe, a Bridgeport-style knee mill, a drill press and the
## arbor press the volunteers use as a riveter); a bench grinder, a rolling
## tool chest and the shop vac; spare board panels and rink glass in a rack
## with uprights; paint, pallets, cords on hooks, oil on the floor and the
## old ice edger waiting for parts.
##
## The machines are Props kit pieces (scripts/art/shop_props.gd). Each has a
## USE spot stub beside it ({"machine": id, "stub": true}) for the machine
## mini games to come.

## [prop id, position, rotation, spot label, spot position]
const MACHINES := [
	["lathe", Vector3(32.55, 0, -54.0), -PI * 0.5, "Lathe", Vector3(33.45, 1.1, -54.0)],
	["knee_mill", Vector3(32.95, 0, -51.2), -PI * 0.5, "Knee mill", Vector3(34.0, 1.2, -51.2)],
	["drill_press", Vector3(32.7, 0, -48.65), -PI * 0.5, "Drill press", Vector3(33.4, 1.1, -48.6)],
	["arbor_press", Vector3(32.45, 0, -47.35), -PI * 0.5, "Arbor press", Vector3(33.1, 1.0, -47.3)],
	["bench_grinder", Vector3(37.95, 0, -59.35), PI, "Bench grinder", Vector3(37.95, 1.1, -58.6)],
	["workbench", Vector3(34.3, 0, -59.34), PI, "Workbench", Vector3(34.3, 1.0, -58.5)],
	["workbench", Vector3(36.35, 0, -59.34), PI, "Workbench", Vector3(36.35, 1.0, -58.5)],
]


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("7a776e"), Color("858278"), Color("8e8f90"))


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("a8a294"), Color("b4b0a6"), Color("cfd0cf"))


func bare_outer() -> bool:
	return true


func plate_color() -> Color:
	return VenueSign.AMBER


func furnish(k: VenueKit) -> void:
	var steel := Color("8f9498")
	var yellow := k.aged(Color("e0b020"), 5)
	var back := z0 + 0.3  # the north wall's inside face (bare block, 0.3 m)
	# the old stencilled LOADING by the roll-up door, painted over: RECEIVING
	readable(k, "sign_receiving", Vector3(x1 - 0.3, 2.0, -50.6), Vector3(-1, 0, 0))
	# a painted keep-clear box inside the roll-up door
	for z in [-55.0, -51.0]:
		k.block(Vector3(x1 - 4.0, 0, z - 0.06), Vector3(x1 - 0.3, 0.005, z + 0.06), yellow, 1.0, 0.04, false)
	k.block(Vector3(x1 - 4.0, 0, -55.0), Vector3(x1 - 3.88, 0.005, -51.0), yellow, 1.0, 0.04, false)
	_oil(k)
	for i in MACHINES.size():
		var mc: Array = MACHINES[i]
		k.prop(mc[0], mc[1], mc[2])
		var id: String = mc[0]
		add_spot(k, VenueSpot.Kind.USE, "shop_%s_%d" % [id, i], mc[4], mc[3], {"machine": id, "stub": true})
	# the pegboard over the benches and the clamp rack beside it
	k.prop("pegboard", Vector3(34.6, 1.06, back + 0.1), PI, false)
	k.prop("clamp_rack", Vector3(36.85, 1.2, back + 0.1), PI, false)
	k.prop("toolbox", Vector3(33.95, 0, -57.15), PI)
	k.prop("shop_vac", Vector3(37.0, 0, -58.25), PI)
	k.prop("cord_hooks", Vector3(40.6, 1.15, z1 - 0.25), 0.0, false)
	k.prop("fire_extinguisher", Vector3(38.3, 0, z1 - 0.3), 0.0)
	k.prop("step_ladder", Vector3(x1 - 0.75, 0, -46.9), PI * 0.5)
	k.prop("trash_can", Vector3(38.8, 0, z1 - 0.4), PI)
	# parts shelving down the west wall, past the lathe
	var parts := [Color("6a6e74"), Color("e06a1a"), Color("3f6fa8"), Color("c9a46a"), Color("1b1d22")]
	shelves(k, Vector3(x0 + 0.15, 0, -58.9), Vector3(x0 + 0.75, 2.6, -55.4), 5, steel, parts)
	_board_rack(k, back)
	# a cord from the wall outlet to the edger
	var cord: Color = k.by_age(Color("b8601e"), Color("e8701e"), Color("e8c21e"))
	k.block(Vector3(x0 + 0.15, 0.3, -49.9), Vector3(x0 + 0.25, 0.42, -49.82), Color("d8d4c8"), 1.0, 0.0, false)  # outlet
	k.oriented(Transform3D(Basis(Vector3.UP, -0.25) * Basis.from_scale(Vector3(3.1, 0.02, 0.03)), Vector3(34.0, 0.01, -50.3)), cord)
	# paint cans, a pallet stack, a drum
	for i in 6:
		k.block(Vector3(33.4 + i * 0.32, 0, -45.0), Vector3(33.65 + i * 0.32, 0.3, -44.75), [Color("eeeeea"), Color("c8191e"), Color("3f6fa8")][i % 3], 0.1, 0.03)
	stack(k, Vector3(x1 - 2.0, 0, -59.6), Vector3(1.2, 0.15, 1.0), 5, Wear.PLYWOOD)
	k.block(Vector3(x1 - 0.9, 0, -46.2), Vector3(x1 - 0.3, 0.9, -45.6), Color("2a5a8a"), 0.2, 0.04)
	k.block(Vector3(x1 - 0.9, 0.9, -46.2), Vector3(x1 - 0.3, 0.92, -45.6), Color("1f4a75"), 1.0, 0.0, false)
	# the old ice edger, half taken apart on the floor
	k.aged_block(Vector3(35.5, 0, -50.5), Vector3(36.3, 0.55, -49.7), Color("c8312f"), 0.2)
	k.block(Vector3(35.85, 0.55, -50.3), Vector3(35.95, 1.0, -50.2), Color("2b2d33"), 0.2, 0.0, false)
	k.block(Vector3(35.9, 1.0, -50.6), Vector3(36.0, 1.05, -49.6), Color("2b2d33"), 0.2, 0.0, false)
	k.block(Vector3(36.6, 0, -50.2), Vector3(36.9, 0.08, -49.9), Color("6a6e74"), 0.1, 0.0, false)  # its blade
	k.block(Vector3(36.5, 0, -49.6), Vector3(36.8, 0.04, -49.3), Color("3a3d44"), 1.0, 0.0, false)  # a rag of bolts
	wall_sign(k, [["// WORKSHOP", VenueSign.AMBER], ["EYE PROTECTION", VenueSign.WHITE, true]], 14, 2, 0.022, Vector3(35.2, 3.0, back), Vector3(0, 0, 1), "ShopSign")
	wall_sign(k, [["KEEP CLEAR", VenueSign.AMBER]], 10, 1, 0.03, Vector3(x1 - 0.3, 3.8, -53.0), Vector3(-1, 0, 0), "KeepClear")


## Oil on the floor: dark pools under the machines and drips across the
## shop. A renovated shop has been degreased and sealed (one faint stain).
func _oil(k: VenueKit) -> void:
	var stain := Color("2e2a24")
	var n: int = k.by_age(22, 12, 2)
	for mc in [Vector3(33.2, 0, -54.0), Vector3(33.4, 0, -51.2), Vector3(33.0, 0, -48.6)]:
		var p: Vector3 = mc
		if k.age == Age.RENOVATED:
			break
		k.block(Vector3(p.x - 0.5, 0, p.z - 0.7), Vector3(p.x + 0.4, 0.004, p.z + 0.6), stain.lightened(0.15 if k.age == Age.REPAIRED else 0.0), 1.0, 0.08, false)
	for i in n:
		var x := x0 + 1.0 + posmod(hash(Vector2i(i, 11)), 1100) / 100.0
		var z := z0 + 1.2 + posmod(hash(Vector2i(i, 12)), 1300) / 100.0
		var s := 0.08 + posmod(hash(Vector2i(i, 13)), 30) / 100.0
		k.block(Vector3(x, 0, z), Vector3(x + s, 0.004, z + s * 0.7), stain.lightened(0.1 * (i % 3)), 1.0, 0.0, false)


## Spare dasher-board panels and rink glass in a rack along the north wall
## (#25): a steel base channel, an upright between every panel and pane and
## at each end, and a top tie across them, like a real panel rack.
func _board_rack(k: VenueKit, back: float) -> void:
	var steel: Color = k.by_age(Color("6f7478"), Color("8f9498"), Color("2b2d33"))
	var white: Color = k.by_age(Color("d8d4c4"), Color("eeeeea"), Color("f4f4f0"))
	var kick: Color = k.by_age(Color("b89a30"), Color("e0b020"), Color("f0c020"))
	var z_a := back + 0.08
	var z_b := back + 0.98
	k.block(Vector3(38.5, 0, z_a), Vector3(42.55, 0.12, z_b), steel.darkened(0.2), 1.0, 0.03)  # base channel
	# board panels: white HDPE with the yellow kick plate along the bottom
	var boards := 5
	for i in boards:
		var z := z_a + 0.06 + i * 0.16
		k.block(Vector3(38.6, 0.12, z), Vector3(41.0, 1.22, z + 0.04), white, 1.0, 0.02, false)
		k.block(Vector3(38.6, 0.12, z - 0.003), Vector3(41.0, 0.32, z + 0.043), kick, 1.0, 0.03, false)
		if k.age == Age.WORN and i % 2 == 0:
			k.block(Vector3(39.2 + i * 0.2, 0.5, z - 0.004), Vector3(39.6 + i * 0.2, 0.62, z + 0.044), Color("2b2d33"), 1.0, 0.0, false)  # puck marks
	# rink glass panes
	var panes := 4
	for i in panes:
		var z := z_a + 0.08 + i * 0.2
		k.glass(Vector3(41.2, 0.12, z), Vector3(42.4, 1.62, z + 0.03), false)
	# uprights: between every panel and pane and at each end, at three spots
	# along the boards and two along the glass, with a top tie across them
	var slots := []
	for i in boards + 1:
		slots.append(z_a + 0.06 + i * 0.16 - 0.06)
	for xs in [[38.55, 1.36], [39.78, 1.36], [41.02, 1.36]]:
		var x: float = xs[0]
		var top: float = xs[1]
		for z: float in slots:
			k.block(Vector3(x, 0.12, z - 0.015), Vector3(x + 0.04, top, z + 0.015), steel, 1.0, 0.02, false)
		k.block(Vector3(x - 0.01, top, z_a), Vector3(x + 0.05, top + 0.04, z_a + 0.06 + boards * 0.16), steel, 1.0, 0.02, false)
	var glass_slots := []
	for i in panes + 1:
		glass_slots.append(z_a + 0.08 + i * 0.2 - 0.085)
	for x: float in [41.12, 42.45]:
		for z: float in glass_slots:
			k.block(Vector3(x, 0.12, z - 0.015), Vector3(x + 0.04, 1.76, z + 0.015), steel, 1.0, 0.02, false)
		k.block(Vector3(x - 0.01, 1.76, z_a), Vector3(x + 0.05, 1.8, z_a + 0.08 + panes * 0.2), steel, 1.0, 0.02, false)
	k.collider(Vector3(38.5, 0, z_a), Vector3(42.55, 1.8, z_b))
	# a stencilled tag on the end upright
	k.block(Vector3(38.5, 0.9, z_a + 0.2), Vector3(38.52, 1.1, z_a + 0.5), Color("e8e4d8"), 1.0, 0.0, false)


func door_color(k: VenueKit, d: Array) -> Color:
	if d[6] == VenueDoor.Kind.ROLLUP:
		return k.by_age(Color("7a776e"), Color("8f9498"), Color("b9c0c6"))
	return super(k, d)
