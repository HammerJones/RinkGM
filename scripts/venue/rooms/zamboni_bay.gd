extends VenueRoom
## The ice resurfacer's garage at the +X end, between the dressing rooms:
## roll-up doors to the rink and to the outside, the resurfacer itself,
## the snow-melt pit, a workbench and tool wall. A worn bay houses a rusty
## old machine; a renovated one has a new electric unit in club colours.
## Outside it, the pair of big gates in the boards where the resurfacer
## goes on the ice, and the net storage along the wall either side.

const X0 := Venue.END_FRONT
const X1 := Venue.HALF_X - Venue.WALL_T
const Z := 5.0
const H := 5.0
## The snow-melt pit under its grate, in venue space.
const PIT := Rect2(42.8, -4.6, 2.5, 2.2)
## The resurfacer gate in the end boards (Shell.GATES "x+").
const GATE_HALF := 1.8
## Net storage along the walkway wall: [z from, z to, kind]. Big nets are
## 1.83 m regulation goals, small ones the 1.2 m peewee nets, two high.
const NET_BAYS := [[2.1, 3.95, "large"], [4.15, 6.0, "large"], [6.3, 8.85, "small"]]
const NET_LARGE := Vector3(1.83, 1.22, 1.0)
const NET_SMALL := Vector3(1.22, 0.9, 0.7)

## Snow in the melt pit, 0 (empty) to 1 (heaped over the grate), as the
## walk shows RinkSim.snow_pit: Doris adds a load per flood, the tired heater
## melts a little, and the dump_snow job hoses it down the drain.
var snow := 0.6
var _heap: MeshInstance3D


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
	# the Props kit's resurfacer, parked nose-first toward the rink door
	k.prop("resurfacer", Vector3(39.7, 0, 0), PI * 0.5)
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
	# the roof over the bay
	k.slab(Vector3(X0, H, -Z - 0.15), Vector3(X1, H + 0.25, Z + 0.15), block_col.darkened(0.15), 1.0)
	k.slab(Vector3(X0 + 0.3, H - 0.02, -Z + 0.15), Vector3(X1, H, Z - 0.15), k.by_age(Color("8f8b80"), Color("a39f94"), Color("c9c7c0")), 1.0, 0.05, true, false)
	_m1(k)
	_gates(k)
	_net_storage(k)
	room_light(k, Vector3(40.0, H - 0.5, 0.0), 7.0)
	# lights and sign
	var lit: Color = k.by_age(Color("e0d8b0"), Color("f4f6f0"), Color("f4f8ff"))
	for x in [37.0, 41.0, 44.0]:
		k.glow(Vector3(x - 0.7, H - 0.1, -0.2), Vector3(x + 0.7, H - 0.05, 0.2), lit)
	var sign := VenueSign.make([["// ICE RESURFACING", VenueSign.AMBER], ["KEEP CLEAR", VenueSign.RED]], 19, 2, 0.03)
	sign.name = "BaySign"
	sign.dead = k.by_age(0.06, 0.0, 0.0)
	k.sign(sign, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(X0 - 0.01, 3.7, 0)))


## RINK_SIM M1: Doris's dash note and her two jobs (the won't-start plug
## change, the blade), the DORIS parts drawers with the plugs, the manual on
## the bench, and the snow pit with Mount Doris out the back.
func _m1(k: VenueKit) -> void:
	add_spot(k, VenueSpot.Kind.JOB, "doris", Vector3(40.4, 1.5, 0.55), "Doris",
		{"job": "doris_plugs", "target": "doris_plugs", "readable": "note_doris_dash", "note": "doris_dash", "needs": "spark_plugs", "scene": "res://scenes/world/jobs/doris_plugs.tscn"}, 2.0)
	add_spot(k, VenueSpot.Kind.JOB, "doris_blade", Vector3(41.9, 0.5, 0.0), "Doris's blade",
		{"job": "blade_change", "target": "doris_blade", "scene": "res://scenes/world/jobs/doris_blade.tscn"}, 1.6)
	# the parts cabinet: every drawer labelled DORIS
	var steel: Color = k.by_age(Color("6f7378"), Color("8a8f94"), Color("50555c"))
	k.aged_block(Vector3(38.5, 0, 4.3), Vector3(39.6, 1.3, 4.85), steel, 0.3)
	for i in 5:
		var y := 0.12 + i * 0.24
		k.block(Vector3(38.6, y, 4.28), Vector3(39.5, y + 0.2, 4.3), steel.lightened(0.08), 0.2, 0.02, false)
		k.block(Vector3(38.9, y + 0.07, 4.27), Vector3(39.2, y + 0.13, 4.28), Color("e8e4da"), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.READ, "plug_drawer", Vector3(39.05, 1.0, 4.25), "Drawer labelled DORIS", {"note": "plug_drawer", "gives": "spark_plugs"}, 1.5)
	add_spot(k, VenueSpot.Kind.READ, "zambelli_525_manual", Vector3(36.0, 1.0, -4.5), "Zambelli 525 manual", {"readable": "zambelli_525_manual"}, 1.4)
	# the pit: a heap of old snow over the grate, and its heater switch
	var b := VoxelMeshBuilder.new()
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Color("e9eef2"))
	_heap = MeshInstance3D.new()
	_heap.name = "SnowHeap"
	_heap.mesh = b.commit()
	_heap.position = Vector3(PIT.get_center().x, 0.03, PIT.get_center().y)
	_heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.add(_heap)
	set_snow(snow)
	k.block(Vector3(X1 - 0.12, 1.3, -2.2), Vector3(X1 - 0.02, 1.6, -1.9), Color("7d8288"), 0.2, 0.02, false)
	add_spot(k, VenueSpot.Kind.JOB, "snow_pit", Vector3(PIT.get_center().x, 0.4, PIT.get_center().y), "Hose down the snow pit",
		{"job": "dump_snow", "target": "snow_pit", "note": "snow_pit"}, 2.0)
	# Mount Doris, out the back by the garage door, behind a snow fence
	var xo := Venue.HALF_X + 0.6
	for i in 4:
		var r := 2.6 - i * 0.6
		k.block(Vector3(xo + 2.6 - r, i * 0.45, -9.0 + 2.6 - r), Vector3(xo + 2.6 + r, (i + 1) * 0.45, -9.0 + 2.6 + r), Color("dfe5ea").darkened(0.05 * i), 0.5, 0.05)
	for i in 8:
		k.block(Vector3(xo - 0.5 + i * 0.85, 0, -12.2), Vector3(xo - 0.45 + i * 0.85, 1.2, -12.15), Color("c8562a"), 0.2, 0.0, false)
	k.block(Vector3(xo - 0.5, 0.8, -12.2), Vector3(xo + 5.5, 1.0, -12.18), Color("e06a1a"), 0.3, 0.05, false)
	var sign := VenueSign.make([["MOUNT DORIS", VenueSign.AMBER], ["NO CLIMBING", VenueSign.RED]], 11, 2, 0.02)
	sign.name = "MountDorisSign"
	k.sign(sign, Transform3D(Basis(Vector3.UP, PI), Vector3(xo + 2.5, 1.25, -12.24)))


## The resurfacer gate: two big leaves in the end boards and the glass over
## them, hinged at the outer posts and latched in the middle. Trim over the
## rink's own boards (they stay shut until the gate mechanic opens them).
func _gates(k: VenueKit) -> void:
	var xo := Rink.HALF_L + 0.32  # walkway face of the boards
	var top := VenuePhysics.board_top()
	var glass_top := top + VenuePhysics.END_GLASS
	var steel: Color = k.by_age(Color("8a7a5a"), Color("9aa0a6"), Color("2a2e36"))
	var hinge := Color("55585e")
	for side in [-1.0, 1.0]:
		var z_out: float = side * GATE_HALF
		var z_in: float = side * 0.03
		var zl := minf(z_out, z_in)
		var zh := maxf(z_out, z_in)
		# the leaf's frame on the walkway side: stiles, rails and a brace
		for z in [z_out, z_in]:
			k.block(Vector3(xo, 0.05, z - 0.04), Vector3(xo + 0.05, glass_top, z + 0.04), steel, 0.3, 0.03, false)
		for y in [0.05, top - 0.08, glass_top - 0.08]:
			k.block(Vector3(xo, y, zl), Vector3(xo + 0.05, y + 0.08, zh), steel, 0.3, 0.03, false)
		var d := Vector3(0, top - 0.25, z_in - z_out)
		var brace := Transform3D(Basis(Vector3(0.05, 0, 0), d.normalized() * d.length(), Vector3(0, -d.z, d.y).normalized() * 0.06), Vector3(xo + 0.025, 0.1 + d.y * 0.5, (z_out + z_in) * 0.5))
		k.oriented(brace, steel)
		# hinges on the outer post, a handle by the latch
		for y in [0.3, 0.85, 1.6, 2.6]:
			k.block(Vector3(xo + 0.02, y, z_out - 0.06), Vector3(xo + 0.09, y + 0.12, z_out + 0.06), hinge, 0.2, 0.0, false)
		k.block(Vector3(xo + 0.05, 0.75, z_in - side * 0.14), Vector3(xo + 0.12, 0.95, z_in - side * 0.1), hinge, 0.2, 0.0, false)
		# the seams show on the ice side too
		k.block(Vector3(Rink.HALF_L - 0.012, 0.02, z_out - 0.015), Vector3(Rink.HALF_L, top - 0.02, z_out + 0.015), Color("2a2c30"), 0.2, 0.0, false)
	k.block(Vector3(Rink.HALF_L - 0.012, 0.02, -0.015), Vector3(Rink.HALF_L, top - 0.02, 0.015), Color("2a2c30"), 0.2, 0.0, false)
	# the drop bolt in the middle and a yellow-and-black stripe over the gate
	k.block(Vector3(xo + 0.05, 0.0, -0.03), Vector3(xo + 0.1, 0.6, 0.03), hinge, 0.2, 0.0, false)
	for i in 8:
		var z0 := -GATE_HALF + i * GATE_HALF * 0.25
		k.block(Vector3(xo + 0.05, top - 0.2, z0), Vector3(xo + 0.06, top - 0.1, z0 + GATE_HALF * 0.25), Color("e0b020") if i % 2 == 0 else Color("1b1d22"), 0.3, 0.0, false)


## Nets stored against the walkway wall either side of the bay door, each
## standing on its painted bay: two big goals and four small ones a side.
func _net_storage(k: VenueKit) -> void:
	var red: Color = k.aged(Color("c8191e"), 7)
	var x_wall := X0
	for side in [-1.0, 1.0]:
		for bay in NET_BAYS:
			var za: float = side * bay[0]
			var zb: float = side * bay[1]
			var zc := (za + zb) * 0.5
			var big: bool = bay[2] == "large"
			var size: Vector3 = NET_LARGE if big else NET_SMALL
			# the painted outline of the bay on the floor
			var paint := Color("d9b84a").darkened(0.25 if k.age == Age.WORN else 0.0)
			var x_out := x_wall - (NET_LARGE.z + 0.2)
			for zz in [za, zb]:
				k.block(Vector3(x_out, 0.0, zz - 0.04), Vector3(x_wall, 0.012, zz + 0.04), paint, 0.3, 0.06, false)
			k.block(Vector3(x_out - 0.04, 0.0, minf(za, zb)), Vector3(x_out + 0.04, 0.012, maxf(za, zb)), paint, 0.3, 0.06, false)
			if big:
				_net(k, Vector3(x_wall - 0.05, 0, zc), size, red)
			else:
				for i in 2:
					var zi: float = zc + side * (i - 0.5) * (size.x + 0.04)
					_net(k, Vector3(x_wall - 0.05, 0, zi), size, red)
					_net(k, Vector3(x_wall - 0.05, size.y + 0.02, zi), size, red)


## A goal frame and its net, its back against a wall at `back` (x) and its
## mouth facing -X (out to the walkway).
func _net(k: VenueKit, back: Vector3, size: Vector3, red: Color) -> void:
	var t := 0.05
	var front := back.x - size.z
	var z0 := back.z - size.x * 0.5
	var z1 := back.z + size.x * 0.5
	var y0 := back.y
	for z in [z0, z1 - t]:
		k.block(Vector3(front, y0, z), Vector3(front + t, y0 + size.y, z + t), red, 0.3, 0.04, false)  # posts
		k.block(Vector3(front, y0, z), Vector3(back.x, y0 + t, z + t), Color("e8e8e2"), 0.3, 0.04, false)  # base frame
	k.block(Vector3(front, y0 + size.y - t, z0), Vector3(front + t, y0 + size.y, z1), red, 0.3, 0.04, false)  # crossbar
	k.block(Vector3(back.x - t, y0, z0), Vector3(back.x, y0 + t, z1), Color("e8e8e2"), 0.3, 0.04, false)
	# the mesh: top, back and sides
	var mesh := Color(0.92, 0.92, 0.9, 0.4)
	k.glass(Vector3(front + t, y0 + size.y - 0.02, z0), Vector3(back.x - size.z * 0.5, y0 + size.y, z1), false, mesh)
	k.glass(Vector3(back.x - size.z * 0.5, y0 + t, z0), Vector3(back.x - size.z * 0.5 + 0.02, y0 + size.y, z1), false, mesh)
	for z in [z0, z1 - 0.02]:
		k.glass(Vector3(front + t, y0 + t, z), Vector3(back.x - size.z * 0.5, y0 + size.y, z + 0.02), false, mesh)
	k.collider(Vector3(front, y0, z0), Vector3(back.x, y0 + size.y, z1))


## Where the nets live, for the net mechanic: [{pos, kind}] in venue space
## (pos is the middle of the bay on the floor).
func net_slots() -> Array:
	var out := []
	for side in [-1.0, 1.0]:
		for bay in NET_BAYS:
			var zc: float = side * (bay[0] + bay[1]) * 0.5
			out.append({"pos": Vector3(X0 - 0.6, 0, zc), "kind": bay[2]})
	return out


## Shows the pit's snow at `level` 0..1 (the heap grows over the grate).
func set_snow(level: float) -> void:
	snow = clampf(level, 0.0, 1.0)
	if _heap and is_instance_valid(_heap):
		_heap.visible = snow > 0.02
		_heap.scale = Vector3(PIT.size.x * (0.6 + 0.4 * snow), 0.05 + 0.9 * snow, PIT.size.y * (0.6 + 0.4 * snow))
