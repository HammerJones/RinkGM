extends RefCounted
## Props for the recreation wing's working rooms: the workshop's machines and
## benches, the electrical room's gear, the weight room's machines and the
## equipment store's kit. Built like every other prop (see props.gd): one
## builder per id and age, pivot on the floor and centred, front facing -Z
## (low z is the front), all three ages. Props.model() and Props.mesh()
## dispatch here; every id is merged at full detail (Props.mesh keeps the
## rust and grime, drops the speckle) so a room of machines stays cheap.
##
## Wall pieces (breaker_panel, meter_bank, fire_panel, pegboard, clamp_rack,
## cord_hooks) still have their pivot at the bottom centre with their back on
## z = +d/2 like a floor prop: the room places them at mounting height with
## their back to the wall.
##
## Ages: WORN is the 1970s Athletic Club's kit, kept past its time: faded
## machine-grey enamel, rust on bare steel, oil stains, torn vinyl, tape and
## missing knobs. REPAIRED is the same kit kept going by volunteers: fresh
## paint, a yellow replacement guard, a new handle or pad, tags. RENOVATED is
## new or properly restored equipment: clean paint, navy and charcoal, digital
## readouts, LED work lamps, bumper plates.

const V := Models.V
const Plant := preload("res://scripts/art/plant_props.gd")

const MACHINE_OLD := Color("6b7d74")      # 1950s machine-tool grey-green
const MACHINE_REPAIRED := Color("7a888a")  # repainted grey
const MACHINE_NEW := Color("9aa3a5")       # restored, fresh grey
const CAST := Color("5f6466")
const WAYS := Color("c4c8ca")              # ground steel, bright where it slides
const BLACK := Color("1e1f22")
const KNOB := Color("b8302a")
const CHROME := Color("d6dadc")
const ALU := Color("c2c6c8")
const TOOL_RED := Color("b0282a")
const ANSI61 := Color("8f9690")            # old switchgear grey
const ANSI49 := Color("aeb5b8")            # new switchgear grey
const FIRE_RED := Color("c4161c")
const FIBERGLASS := Color("e8a31c")
const VINYL_OLD := Color("6a2a2a")
const IRON := Color("2b2d33")
const GOLD_FRAME := Color("8a6a2a")        # the old universal gym's brown-gold
const ORANGE := Color("ee6a1a")
const NET_RED := Color("c8191e")
const NET_WHITE := Color("eeeeea")
const LEATHER := Color("8a6a45")
const OIL_STAIN := Color("26221d")
const CORD_ORANGE := Color("e8701e")
const CORD_YELLOW := Color("e8c21e")
const BUMPER := [Color("c8191e"), Color("2f5fb7"), Color("e8c21e"), Color("2f9a4f")]

## Every shop id, in Props.IDS order.
const IDS := [
	# workshop
	"workbench", "toolbox", "drill_press", "arbor_press", "knee_mill", "lathe", "bench_grinder",
	"shop_vac", "pegboard", "clamp_rack", "cord_hooks",
	# electrical room
	"switchgear", "breaker_panel", "transformer", "meter_bank", "fire_panel", "fire_extinguisher", "step_ladder",
	# weight room
	"bench_press", "squat_rack", "leg_press", "cable_crossover", "lat_pulldown", "dumbbell_rack",
	"plate_tree", "stationary_bike", "treadmill", "slide_board",
	# equipment storage
	"ball_bin", "pylon_stack", "mini_net", "spare_net", "puck_bucket", "goalie_pads", "broom_bin",
	"skate_cones", "hockey_bags",
]

## Every shop prop merges its faces at full detail (see Props._MERGED).
const MERGED := IDS

## Coarser collision for the big machines (Props._COLLISION_CELL).
const COLLISION_CELL := {"knee_mill": 3, "lathe": 3, "switchgear": 3, "transformer": 3, "leg_press": 3, "cable_crossover": 3}


static func build(id: String, age: int) -> VoxelModel:
	match id:
		"workbench": return _workbench(age)
		"toolbox": return _toolbox(age)
		"drill_press": return _drill_press(age)
		"arbor_press": return _arbor_press(age)
		"knee_mill": return _knee_mill(age)
		"lathe": return _lathe(age)
		"bench_grinder": return _bench_grinder(age)
		"shop_vac": return _shop_vac(age)
		"pegboard": return _pegboard(age)
		"clamp_rack": return _clamp_rack(age)
		"cord_hooks": return _cord_hooks(age)
		"switchgear": return _switchgear(age)
		"breaker_panel": return _breaker_panel(age)
		"transformer": return _transformer(age)
		"meter_bank": return _meter_bank(age)
		"fire_panel": return _fire_panel(age)
		"fire_extinguisher": return _fire_extinguisher(age)
		"step_ladder": return _step_ladder(age)
		"bench_press": return _bench_press(age)
		"squat_rack": return _squat_rack(age)
		"leg_press": return _leg_press(age)
		"cable_crossover": return _cable_crossover(age)
		"lat_pulldown": return _lat_pulldown(age)
		"dumbbell_rack": return _dumbbell_rack(age)
		"plate_tree": return _plate_tree(age)
		"stationary_bike": return _stationary_bike(age)
		"treadmill": return _treadmill(age)
		"slide_board": return _slide_board(age)
		"ball_bin": return _ball_bin(age)
		"pylon_stack": return _pylon_stack(age)
		"mini_net": return _net(age, 19, 12, 9)
		"spare_net": return _net(age, 29, 19, 17)
		"puck_bucket": return _puck_bucket(age)
		"goalie_pads": return _goalie_pads(age)
		"broom_bin": return _broom_bin(age)
		"skate_cones": return _skate_cones(age)
		"hockey_bags": return _hockey_bags(age)
	return null


# ---------------------------------------------------------------- helpers

## A thin off-grid bar from `a` to `b` (voxel units), `t` voxels thick.
static func _bar(m: VoxelModel, a: Vector3, b: Vector3, t: float, c: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD) if absf(y.z) < 0.9 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	m.add_oriented((a + b) * 0.5, Basis(x, y, z), Vector3(t, l, t), c)


## A ring of `n` bars round `center`, in the plane with normal `axis`.
static func _ring(m: VoxelModel, center: Vector3, axis: Vector3, r: float, t: float, n: int, c: Color) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_bar(m, center + (u * cos(a0) + v * sin(a0)) * r, center + (u * cos(a1) + v * sin(a1)) * r, t, c)


## Recolours the voxels that exist in a region.
static func _paint(m: VoxelModel, x: int, y: int, z: int, sx: int, sy: int, sz: int, c: Color) -> void:
	for i in sx:
		for j in sy:
			for k in sz:
				var p := Vector3i(x + i, y + j, z + k)
				if m.voxels.has(p):
					m.voxels[p] = c


## Speckles `c` over the surface voxels of a region (stains, scuffs, chips).
static func _speckle(m: VoxelModel, x: int, y: int, z: int, sx: int, sy: int, sz: int, c: Color, amount: float, seed: int) -> void:
	if not Wear.fine:
		return
	for i in sx:
		for j in sy:
			for k in sz:
				var p := Vector3i(x + i, y + j, z + k)
				if m.voxels.has(p) and Plant._surface(m, p) and Plant._roll(p, seed) < amount:
					m.voxels[p] = c


## A ball about 3 voxels across (a cube with its corners off).
static func _ball(m: VoxelModel, x: int, y: int, z: int, c: Color, seam := Color(0, 0, 0, 0)) -> void:
	for i in 3:
		for j in 3:
			for k in 3:
				if (i != 1 and j != 1 and k != 1):
					continue
				var col := c
				if seam.a > 0.0 and j == 1 and (i == 1 or k == 1):
					col = seam
				m.set_voxel(x + i, y + j, z + k, col)


## The body colour of a machine tool at this age.
static func _machine(age: int) -> Color:
	return [MACHINE_OLD, MACHINE_REPAIRED, MACHINE_NEW][age]


## A weight plate standing in the YZ plane: `n` voxels thick from x.
static func _plate(m: VoxelModel, x: int, n: int, cy: float, cz: float, r: float, c: Color) -> void:
	Plant._cyl_x(m, x, n, cy, cz, r, c)
	if r > 1.6:
		Plant._cyl_x(m, x, n, cy, cz, 0.8, CHROME)  # the hub


# ---------------------------------------------------------------- workshop

## A heavy workbench, 2.0 x 0.7 m, top at 0.9 m, with a machinist's vise on
## its front left, drawers on the right and a shelf under. Worn: scarred and
## oil-black maple on wooden legs, a rusty cast vise and a coffee can of
## bolts; repaired: a plywood patch let into the top and a blue vise;
## renovated: a steel frame, a fresh butcher-block top and a work lamp.
static func _workbench(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var w := 30
	var d := 11
	var leg := Wear.CHARCOAL if new else Wear.OLD_WOOD_DARK
	var top := Wear.NEW_WOOD if new else Wear.OLD_WOOD
	for x: int in [1, w - 3]:
		for z: int in [1, d - 3]:
			m.box(x, 0, z, 2, 12, 2, leg)
	m.box(1, 3, 1, w - 2, 1, d - 2, Wear.PLYWOOD if not new else Wear.CHARCOAL.lightened(0.1))  # shelf
	m.box(0, 12, 0, w, 2, d, top)
	m.box(0, 14, d - 1, w, 2, 1, top.darkened(0.15))  # back stop
	# drawers on the right
	var front := top.darkened(0.25) if not new else Wear.CHARCOAL
	m.box(18, 9, 0, 11, 3, 1, front)
	for x: int in [18, 23]:
		m.box(x + 1, 10, -1, 3, 1, 1, CHROME if new else Wear.OLD_STEEL)
	m.box(23, 9, 0, 1, 3, 1, front.darkened(0.3))
	# the vise on the front left: base, body, jaws, screw and handle
	var vise := CAST if worn else Color("2f5f9f")
	m.box(3, 14, 1, 5, 1, 4, vise)
	m.box(4, 15, 1, 3, 2, 4, vise)
	m.box(3, 15, 4, 5, 3, 1, vise)  # fixed jaw
	m.box(3, 15, -1, 5, 3, 1, vise)  # moving jaw
	m.box(4, 15, 0, 3, 1, 1, vise.darkened(0.2))
	m.box(3, 17, 4, 5, 1, 1, WAYS)  # jaw plates
	m.box(3, 17, -1, 5, 1, 1, WAYS)
	m.box(5, 15, -3, 1, 1, 2, WAYS)  # screw
	_bar(m, Vector3(2.3, 15.5, -2.5), Vector3(8.7, 15.5, -2.5), 0.35, WAYS)  # handle
	m.set_voxel(2, 15, -3, BLACK).set_voxel(8, 15, -3, BLACK)
	# a hammer and a rag on the top
	_bar(m, Vector3(12, 14.3, 3), Vector3(16, 14.3, 5), 0.5, Wear.OLD_WOOD if not new else BLACK)
	m.box(15, 14, 4, 2, 1, 2, IRON)
	m.box(20, 14, 5, 3, 1, 2, Color("c8c0a8") if not worn else Color("8a8070"))
	if new:
		# a work lamp clamped at the back
		m.box(26, 14, 8, 2, 1, 2, Wear.CHARCOAL)
		_bar(m, Vector3(27, 15, 9), Vector3(26, 22, 6), 0.4, Wear.CHARCOAL)
		m.box(24, 21, 4, 3, 1, 3, Wear.CHARCOAL)
		m.box(25, 20, 5, 1, 1, 1, Wear.LED)
	elif worn:
		Plant._cyl_y(m, 10.5, 7.5, 14, 2, 1.4, Wear.RUST)  # coffee can of bolts
		m.set_voxel(10, 16, 7, Wear.OLD_STEEL)
		_speckle(m, 0, 13, 0, w, 1, d, OIL_STAIN, 0.12, 5)
		Wear.rust(m, vise, 0.15, 6)
	else:
		m.box(12, 13, 2, 6, 1, 5, Wear.NEW_WOOD)  # the patch let into the top
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## A rolling tool chest with a top box: drawers on chrome pulls, casters, a
## side handle. Worn: faded red, a dented drawer left open, a missing pull;
## repaired: masking-tape labels on the drawers; renovated: glossy red with
## black trim.
static func _toolbox(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var red := Color("c0141c") if new else TOOL_RED
	var trim := BLACK if new else red.darkened(0.3)
	for x: int in [0, 9]:
		for z: int in [0, 5]:
			m.box(x, 0, z, 2, 1, 2, BLACK)
	m.box(0, 1, 0, 11, 12, 7, red)
	m.box(0, 13, 0, 11, 1, 7, trim)
	m.box(0, 14, 0, 11, 5, 7, red)
	m.box(0, 19, 0, 11, 1, 7, trim)
	m.box(4, 20, 3, 3, 1, 1, CHROME)  # lid handle
	for y: int in [2, 4, 6, 8, 10, 15, 17]:
		m.box(0, y + 1, 0, 11, 1, 1, trim)  # drawer seams
		if worn and y == 6:
			continue  # pull missing
		m.box(3, y, -1, 5, 1, 1, CHROME)
		if age == Wear.REPAIRED and y < 12:
			m.box(1, y, -1, 1, 1, 1, Wear.PAPER)  # tape labels
	m.box(-1, 9, 2, 1, 1, 3, CHROME)  # side handle
	if worn:
		m.box(0, 4, -3, 11, 2, 3, red)  # a drawer left open
		m.box(1, 5, -3, 9, 1, 2, IRON)  # sockets in it
		m.set_voxel(4, 5, -3, CHROME).set_voxel(7, 5, -2, CHROME)
		_speckle(m, 0, 1, 0, 11, 19, 7, red.darkened(0.35), 0.06, 11)
	return m.set_pivot(5.5, 0, 3.5)


## A floor drill press, about 1.75 m: base, column, table on its arm, the
## head with the belt guard on top and the motor behind, the quill and chuck,
## a three-spoke feed handle and the switch. Worn: rust on the table and
## column, an oil stain on the base; repaired: a yellow replacement belt
## guard; renovated: fresh paint, a chuck guard and an LED lamp.
static func _drill_press(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body := _machine(age)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	m.box(0, 0, 1, 9, 1, 12, CAST)
	m.box(1, 1, 2, 7, 1, 5, CAST.darkened(0.15))  # T-slotted base
	Plant._cyl_y(m, 4.5, 10.0, 1, 26, 1.3, WAYS)
	m.box(3, 11, 8, 3, 2, 4, body)  # table collar
	m.box(4, 12, 4, 1, 1, 4, body)
	Plant._cyl_y(m, 4.5, 4.5, 13, 1, 3.2, body)
	m.box(2, 13, 4, 5, 1, 1, CAST.darkened(0.3))  # slot
	m.box(1, 20, 3, 7, 6, 9, body)  # head
	Plant._cyl_y(m, 4.5, 13.0, 19, 6, 2.1, body.darkened(0.12))  # motor behind
	m.box(0, 26, 2, 9, 2, 11, Plant.SAFETY_YELLOW if age == Wear.REPAIRED else body)  # belt guard
	Plant._cyl_y(m, 4.5, 4.5, 16, 4, 1.0, WAYS)  # quill
	m.box(4, 15, 4, 1, 1, 1, BLACK)  # chuck
	_bar(m, Vector3(4.5, 15, 4.5), Vector3(4.5, 13.6, 4.5), 0.3, WAYS)  # bit
	# feed handle on the right
	m.set_voxel(9, 22, 6, CHROME)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var tip := Vector3(9.6, 22.5 + sin(a) * 3.2, 6.5 + cos(a) * 3.2)
		_bar(m, Vector3(9.6, 22.5, 6.5), tip, 0.4, CHROME)
		m.add_oriented(tip, Basis(), Vector3(0.9, 0.9, 0.9), BLACK)
	m.box(6, 23, 2, 2, 2, 1, Wear.CHARCOAL)  # switch
	m.set_voxel(6, 24, 1, Plant.LAMP_GREEN).set_voxel(7, 23, 1, Wear.RED)
	if new:
		m.box(3, 17, 2, 3, 2, 1, Color("c8e8f0"))  # chuck guard
		_bar(m, Vector3(1, 25, 4), Vector3(-1, 21, 2), 0.4, Wear.CHARCOAL)
		m.box(-2, 20, 1, 2, 1, 2, Wear.LED)
	elif worn:
		Wear.rust(m, WAYS, 0.2, 21)
		Wear.rust(m, body, 0.04, 22)
		_speckle(m, 0, 0, 1, 9, 2, 12, OIL_STAIN, 0.25, 23)
	return m.set_pivot(4.5, 0, 7)


## A hand arbor press on its pedestal, the shop's riveter: a cast C-frame,
## the ram with its rack, a long pinion lever with a ball end, and a tin of
## rivets on the stand. Worn: rust and an oily anvil; repaired: a red lever;
## renovated: fresh green-grey paint and a bright ram.
static func _arbor_press(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body := _machine(age).darkened(0.08)
	m.box(0, 0, 0, 7, 1, 7, CAST)
	m.box(2, 1, 2, 3, 10, 3, body)
	m.box(1, 11, 1, 5, 1, 5, CAST)
	m.box(2, 12, 4, 3, 9, 2, body)  # back of the C
	m.box(2, 12, 0, 3, 2, 4, body)  # anvil
	m.box(2, 19, 0, 3, 3, 4, body)  # head
	m.box(3, 14, 1, 1, 5, 1, WAYS)  # ram
	m.set_voxel(3, 14, 1, CHROME)
	var lever := KNOB if age == Wear.REPAIRED else WAYS
	_bar(m, Vector3(5.5, 20.5, 2.0), Vector3(10.0, 25.5, 2.0), 0.45, lever)
	m.add_oriented(Vector3(10.2, 25.7, 2.0), Basis(), Vector3(1.2, 1.2, 1.2), BLACK)
	Plant._cyl_y(m, 5.5, 1.5, 12, 1, 0.9, Wear.OLD_STEEL)  # tin of rivets
	if age == Wear.WORN:
		Wear.rust(m, WAYS, 0.25, 31)
		_speckle(m, 2, 13, 0, 3, 1, 4, OIL_STAIN, 0.4, 32)
	return m.set_pivot(3.5, 0, 3.5)


## The old knee mill, a Bridgeport-style turret mill about 2.15 m tall: the
## base and column, the knee on its ways with the elevating crank, the
## saddle, the long table with T-slots, handwheels and the power feed, a vise
## on the table, the ram on the turret and the head with its quill, feed
## handle and motor on top. Worn: rusty ways, chips on the table, a missing
## handwheel knob and oil everywhere; repaired: repainted with a red knob
## and a tag; renovated: restored with a digital readout and an LED lamp.
static func _knee_mill(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body := _machine(age)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	m.box(7, 0, 8, 14, 3, 16, body)  # base
	m.box(6, 0, 7, 16, 1, 18, body.darkened(0.15))  # chip lip
	m.box(9, 3, 12, 10, 19, 10, body)  # column
	m.box(10, 3, 11, 8, 15, 1, WAYS.darkened(0.15))  # knee ways
	m.box(9, 7, 3, 10, 7, 9, body)  # knee
	Plant._cyl_y(m, 14.0, 7.5, 0, 7, 1.0, WAYS)  # elevating screw
	m.box(13, 9, 1, 1, 1, 2, WAYS)
	_bar(m, Vector3(13.5, 9.5, 1.0), Vector3(13.5, 12.0, -0.5), 0.45, WAYS)  # crank
	m.box(10, 14, 4, 8, 2, 8, body.darkened(0.06))  # saddle
	Plant._cyl_z(m, 14.0, 15.0, 2, 1, 2.0, CHROME)  # cross feed wheel
	m.box(0, 16, 5, 28, 2, 5, WAYS.darkened(0.1))  # table
	m.box(0, 17, 6, 28, 1, 1, BLACK)  # T-slots
	m.box(0, 17, 8, 28, 1, 1, BLACK)
	for e: Array in [[-1, -1], [28, 1]]:
		var ex: int = e[0]
		Plant._cyl_x(m, ex, 1, 17.0, 7.5, 2.0, CHROME)
		if not (worn and ex > 0):
			m.set_voxel(ex + int(e[1]), 18, 6, KNOB if age == Wear.REPAIRED else BLACK)
	m.box(22, 13, 6, 3, 3, 3, BLACK)  # power feed
	m.set_voxel(23, 15, 5, Plant.LAMP_GREEN if not worn else Plant.LAMP_RED)
	m.box(11, 18, 6, 6, 1, 4, body.darkened(0.2))  # vise
	m.box(11, 19, 6, 1, 2, 4, body.darkened(0.2))
	m.box(16, 19, 6, 1, 2, 4, body.darkened(0.2))
	m.box(12, 19, 7, 4, 1, 2, Wear.OLD_STEEL)  # a part in the jaws
	Plant._cyl_y(m, 14.0, 17.0, 22, 1, 4.2, body.darkened(0.1))  # turret
	m.box(10, 23, 6, 8, 3, 16, body)  # ram
	m.box(11, 20, 3, 6, 7, 6, body)  # head
	Plant._cyl_y(m, 14.0, 5.5, 18, 2, 1.0, WAYS)  # quill
	_bar(m, Vector3(14, 18, 5.5), Vector3(14, 16.4, 5.5), 0.35, WAYS)  # end mill
	m.box(11, 27, 3, 6, 1, 6, body.darkened(0.2))  # belt housing
	Plant._cyl_y(m, 14.0, 6.0, 28, 4, 2.6, body.darkened(0.08))  # motor
	m.box(13, 32, 5, 2, 1, 2, BLACK)
	Plant._cyl_y(m, 14.0, 6.0, 32, 1, 0.6, WAYS)  # drawbar
	for i in 3:
		var a := TAU * i / 3.0
		var tip := Vector3(17.6, 23.5 + sin(a) * 3.0, 6.0 + cos(a) * 3.0)
		_bar(m, Vector3(17.6, 23.5, 6.0), tip, 0.4, CHROME)
		m.add_oriented(tip, Basis(), Vector3(0.9, 0.9, 0.9), BLACK)
	m.box(17, 22, 5, 1, 3, 2, body.darkened(0.2))
	m.box(19, 21, 11, 2, 3, 1, Color("d29a2c").darkened(0.2 if worn else 0.0))  # one-shot oiler
	if new:
		m.box(20, 19, 3, 6, 4, 1, Wear.CHARCOAL)  # digital readout
		m.box(21, 20, 2, 4, 2, 1, Plant.LCD)
		_bar(m, Vector3(11, 26, 7), Vector3(7, 24, 2), 0.4, Wear.CHARCOAL)
		m.box(6, 23, 1, 2, 1, 2, Wear.LED)
	elif worn:
		Wear.rust(m, WAYS.darkened(0.1), 0.25, 41)
		Wear.rust(m, body, 0.03, 42)
		for i in 9:
			m.set_voxel(2 + i * 3, 18, 5 + i % 4, ALU)  # chips on the table
		_speckle(m, 6, 0, 7, 16, 3, 18, OIL_STAIN, 0.3, 43)
	else:
		m.box(9, 13, 2, 2, 2, 1, Wear.PAPER)  # service tag
		m.set_voxel(9, 14, 1, Wear.RED)
	return m.set_pivot(14, 0, 13)


## A toolroom lathe in the South Bend style, 1.8 m: cabinet legs and a chip
## pan, the bed and its ways, the headstock with the gear cover and the
## quick-change box, the chuck, the carriage with apron, cross slide,
## compound and tool post, the lead screw and feed rod, and the tailstock.
## Worn: rusty ways, a pan of chips and oil; repaired: repainted with a new
## belt guard; renovated: restored with a digital readout and a lamp.
static func _lathe(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body := _machine(age)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	m.box(0, 0, 1, 8, 12, 8, body.darkened(0.08))  # headstock cabinet
	m.box(1, 2, 0, 6, 8, 1, body.darkened(0.2))  # its door
	m.set_voxel(6, 7, -1, CHROME)
	m.box(22, 0, 2, 5, 12, 6, body.darkened(0.08))  # tailstock pedestal
	m.box(0, 12, 0, 28, 1, 10, body.darkened(0.25))  # chip pan
	m.box(0, 13, 9, 28, 4, 1, body.darkened(0.25))  # splash back
	m.box(3, 13, 3, 23, 3, 5, body)  # bed
	m.box(3, 15, 3, 23, 1, 1, WAYS)
	m.box(3, 15, 7, 23, 1, 1, WAYS)
	m.box(0, 13, 2, 7, 8, 7, body)  # headstock
	m.box(-1, 13, 2, 1, 7, 7, body.darkened(0.15))  # gear cover
	m.box(1, 21, 3, 5, 1, 5, Plant.SAFETY_YELLOW if age == Wear.REPAIRED else body.darkened(0.1))  # belt guard
	m.box(0, 13, 0, 6, 3, 2, body.darkened(0.1))  # quick-change box
	m.set_voxel(1, 14, -1, CHROME).set_voxel(3, 14, -1, CHROME).set_voxel(5, 15, -1, KNOB)
	Plant._cyl_x(m, 7, 2, 18.0, 5.5, 2.6, CAST)  # chuck
	for p: Vector3i in [Vector3i(9, 19, 5), Vector3i(9, 16, 4), Vector3i(9, 17, 7)]:
		m.set_voxel(p.x, p.y, p.z, BLACK)
	Plant._cyl_x(m, 9, 3, 18.0, 5.5, 0.6, Wear.OLD_STEEL)  # the work
	m.box(11, 16, 2, 5, 1, 7, body.darkened(0.05))  # saddle
	m.box(11, 10, 0, 6, 6, 2, body)  # apron
	Plant._cyl_z(m, 13.5, 13.5, -1, 1, 1.8, CHROME)
	m.set_voxel(15, 12, -1, KNOB).set_voxel(16, 14, -1, CHROME)
	m.box(12, 17, 2, 3, 1, 5, body.darkened(0.1))  # cross slide
	m.box(12, 18, 3, 3, 1, 3, body.darkened(0.1))  # compound
	m.box(13, 19, 4, 1, 2, 1, BLACK)  # tool post
	_bar(m, Vector3(13.5, 19.5, 4.5), Vector3(11.6, 19.0, 5.0), 0.3, WAYS)
	m.box(7, 14, 2, 18, 1, 1, WAYS)  # lead screw
	m.box(7, 13, 2, 18, 1, 1, WAYS.darkened(0.2))  # feed rod
	m.box(20, 16, 3, 4, 4, 5, body)  # tailstock
	Plant._cyl_x(m, 18, 2, 18.0, 5.5, 0.8, WAYS)
	Plant._cyl_x(m, 24, 1, 18.0, 5.5, 1.6, CHROME)
	m.set_voxel(25, 19, 5, BLACK)
	Plant._cyl_x(m, 1, 6, 6.0, 9.5, 1.8, body.darkened(0.2))  # motor under, at the back
	if new:
		m.box(16, 17, 0, 4, 3, 1, Wear.CHARCOAL)  # readout on the carriage
		m.box(17, 18, -1, 2, 1, 1, Plant.LCD)
		_bar(m, Vector3(1, 21, 8), Vector3(5, 25, 4), 0.4, Wear.CHARCOAL)
		m.box(5, 24, 3, 2, 1, 2, Wear.LED)
	elif worn:
		Wear.rust(m, WAYS, 0.25, 51)
		for i in 10:
			m.set_voxel(2 + i * 2, 13, 1 + i % 2, ALU)  # chips in the pan
		_speckle(m, 0, 12, 0, 28, 1, 10, OIL_STAIN, 0.3, 52)
	return m.set_pivot(14, 0, 5)


## A bench grinder on a pedestal: the motor, two wheels under their guards,
## tool rests, eye shields and a water pot. Worn: a rusty pedestal, wheels
## worn small and black spark marks; renovated: fresh paint, clear shields.
static func _bench_grinder(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body := _machine(age)
	var worn := age == Wear.WORN
	m.box(1, 0, 0, 7, 1, 6, CAST)
	Plant._cyl_y(m, 4.5, 3.0, 1, 12, 1.2, body.darkened(0.15))
	m.box(2, 13, 1, 5, 1, 4, CAST)
	Plant._cyl_x(m, 3, 3, 16.0, 3.0, 1.7, body)
	var stone := Color("8a8a84") if not worn else Color("6a6a64")
	var r := 2.2 if not worn else 1.7
	for x: int in [0, 7]:
		Plant._cyl_x(m, x, 2, 16.0, 3.0, r, stone)
		m.box(x, 18, 1, 2, 1, 4, body)  # guard over the wheel
		m.box(x, 14, 4, 2, 4, 1, body)
		m.box(x, 14, 0, 2, 1, 1, Wear.OLD_STEEL)  # tool rest
		m.box(x, 18, -1, 2, 1, 1, Color("c8e8f0") if age == Wear.RENOVATED else Color("9aa8a0"))  # eye shield
	m.box(3, 14, 0, 2, 1, 1, Color("6a8aa0"))  # water pot
	if worn:
		_speckle(m, 1, 0, 0, 7, 1, 6, BLACK, 0.3, 61)
		Wear.rust(m, body.darkened(0.15), 0.2, 62)
	return m.set_pivot(4.5, 0, 3)


## A wet/dry shop vac on casters with its hose looped round. Worn: dusty
## yellow with a taped hose; renovated: red and grey.
static func _shop_vac(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var drum := Color("d8b020") if age != Wear.RENOVATED else Color("c0141c")
	if age == Wear.WORN:
		drum = drum.lerp(Color("a89a70"), 0.4)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(5, 1), Vector2i(1, 5), Vector2i(5, 5)]:
		m.set_voxel(p.x, 0, p.y, BLACK)
	Plant._cyl_y(m, 3.5, 3.5, 1, 7, 3.2, drum)
	Plant._cyl_y(m, 3.5, 3.5, 8, 2, 3.4, BLACK if age != Wear.RENOVATED else Wear.CHARCOAL)
	m.box(2, 10, 3, 3, 1, 1, BLACK)  # handle
	m.set_voxel(0, 7, 3, CHROME).set_voxel(6, 7, 3, CHROME)  # latches
	m.box(3, 6, -1, 1, 1, 1, BLACK)  # inlet
	var hose := [Vector3(3.5, 6.5, -0.5), Vector3(3.5, 3, -2.5), Vector3(6, 1, -2), Vector3(8, 1, 2), Vector3(7.5, 6, 6), Vector3(5, 9, 7.5)]
	for i in hose.size() - 1:
		_bar(m, hose[i], hose[i + 1], 0.8, Color("3a3d44"))
	if age == Wear.WORN:
		_bar(m, Vector3(6.4, 1, -1.6), Vector3(7.4, 1, 0.4), 0.9, Wear.DUCT_TAPE)
	return m.set_pivot(3.5, 0, 3.5)


## A pegboard panel, 2.4 x 1.2 m, with its tools: wrenches in a row, hammers,
## screwdrivers, pliers, a hand saw, a square, a tape measure. A wall piece
## (back on z = +d/2). Worn: brown hardboard with gaps where tools went
## missing; repaired: the same with a few new tools; renovated: white board
## with the tools' outlines painted on (a shadow board).
static func _pegboard(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var w := 37
	var hh := 18
	var board := Color("eeeeea") if new else Color("8a6a45")
	m.box(0, 0, 2, w, hh, 1, board)
	m.box(0, 0, 3, w, 1, 1, Wear.OLD_WOOD_DARK)  # furring strips behind
	m.box(0, hh - 1, 3, w, 1, 1, Wear.OLD_WOOD_DARK)
	if Wear.fine:
		for x in range(1, w, 3):
			for y in range(1, hh, 3):
				m.set_voxel(x, y, 2, board.darkened(0.35))  # holes
	var shadow := Color("3a3d44")
	var steel := CHROME if new else Wear.OLD_STEEL
	# wrenches, small to big, hanging from pegs
	for i in 8:
		var x := 2 + i * 2
		if worn and (i == 2 or i == 5):
			continue
		var l := 4 + i / 2
		if new:
			m.box(x, hh - 3 - l, 1, 1, l + 1, 1, shadow)
		m.box(x, hh - 3 - l, 0, 1, l, 1, steel)
		m.set_voxel(x, hh - 3, 1, BLACK)  # peg
	# hammers
	for i in 2:
		var x := 20 + i * 4
		if new:
			m.box(x, 8, 1, 1, 7, 1, shadow)
		m.box(x, 8, 0, 1, 6, 1, Wear.OLD_WOOD if not new else BLACK)
		m.box(x - 1, 14, 0, 3, 1, 1, IRON)
	# screwdrivers
	for i in 5:
		var x := 28 + i * 2
		if worn and i == 3:
			continue
		m.box(x, 10, 0, 1, 3, 1, [Color("c8191e"), Color("e0b020"), Color("2f5f9f")][i % 3])
		m.box(x, 7, 0, 1, 3, 1, steel)
	# pliers, a square, a tape measure and the hand saw along the bottom
	_bar(m, Vector3(3, 2, 0.5), Vector3(4, 6, 0.5), 0.5, Color("c8191e"))
	_bar(m, Vector3(5, 2, 0.5), Vector3(4, 6, 0.5), 0.5, Color("c8191e"))
	m.box(8, 1, 0, 6, 1, 1, steel)
	m.box(8, 1, 0, 1, 5, 1, steel)
	m.box(16, 3, 0, 2, 2, 1, Color("e0b020"))
	m.box(20, 1, 0, 9, 4, 1, steel)  # saw blade
	m.box(29, 1, 0, 3, 4, 1, Wear.OLD_WOOD)  # saw handle
	if new:
		m.box(19, 0, 1, 14, 6, 1, shadow)
	return m.set_pivot(w * 0.5, 0, 1.5)


## A wall rail of clamps: bar clamps hanging in a row and C-clamps on pegs.
## A wall piece. Worn: rusty; renovated: new blue and orange clamps.
static func _clamp_rack(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	m.box(0, 13, 2, 22, 1, 1, Wear.OLD_WOOD_DARK if not new else Wear.CHARCOAL)  # rail
	for i in 7:
		var x := 1 + i * 2
		var l := 9 + (i % 3) * 1
		var bar := Wear.OLD_STEEL if not new else CHROME
		m.box(x, 13 - l, 1, 1, l, 1, bar)
		m.box(x, 12, 0, 1, 2, 1, Color("2f5f9f") if new else Wear.RUST)  # fixed jaw
		m.box(x, 13 - l + 2, 0, 1, 2, 1, ORANGE if new else Wear.RUST)  # sliding jaw
	for i in 3:
		var x := 16 + i * 2
		m.box(x, 8, 1, 1, 4, 1, Color("2f5f9f") if new else CAST)
		m.set_voxel(x, 8, 0, Color("2f5f9f") if new else CAST).set_voxel(x, 11, 0, Color("2f5f9f") if new else CAST)
		m.set_voxel(x, 9, 0, Wear.OLD_STEEL)
	if age == Wear.WORN:
		Wear.rust(m, Wear.OLD_STEEL, 0.25, 71)
	m.box(0, 0, 2, 1, 1, 1, Wear.OLD_WOOD_DARK)  # a foot so the piece sits on y = 0
	return m.set_pivot(11, 0, 1.5)


## Extension cords coiled on wall hooks, and a cord reel. A wall piece.
static func _cord_hooks(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	m.box(0, 12, 2, 16, 2, 1, Wear.PLYWOOD if not new else Wear.CHARCOAL)  # cleat
	var cols := [CORD_ORANGE, CORD_YELLOW, Color("3a3d44")]
	for i in 3:
		var cx := 2.5 + i * 5.0
		m.box(int(cx), 11, 1, 1, 1, 1, Wear.OLD_STEEL)  # hook
		var c: Color = cols[i]
		if age == Wear.WORN:
			c = c.lerp(Color("6a6050"), 0.35)
		_ring(m, Vector3(cx + 0.5, 8.0, 0.8), Vector3(0, 0, 1), 3.0, 0.5, 10, c)
		_ring(m, Vector3(cx + 0.5, 7.6, 0.4), Vector3(0, 0, 1), 2.6, 0.5, 10, c)
		_bar(m, Vector3(cx + 0.5, 5.0, 0.6), Vector3(cx + 1.2, 2.0, 0.2), 0.5, c)  # the plug end
		m.box(int(cx + 1), 1, 0, 1, 1, 1, BLACK)
	m.box(0, 0, 2, 1, 1, 1, Wear.PLYWOOD)  # a foot so the piece sits on y = 0
	return m.set_pivot(8, 0, 1.5)


# ---------------------------------------------------------------- electrical

## The main switchgear lineup, three sections 2.34 m wide: the incoming
## main breaker, the feeder breaker, and the metering section. Each has a
## meter compartment (ammeter, voltmeter, lamps, selector), a draw-out
## breaker behind its door with an open/closed flag, and louvred cable
## compartments below. Worn: faded ANSI 61 grey, rust low down, a dead lamp
## and a taped meter glass; repaired: a red lockout tag and a new meter;
## renovated: ANSI 49 light grey, digital power meters and arc-flash labels.
static func _switchgear(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var grey := ANSI49 if new else ANSI61
	var w := 36
	var d := 12
	m.box(0, 0, 0, w, 1, d, BLACK)
	m.box(0, 1, 0, w, 34, d, grey)
	m.box(0, 35, -1, w, 1, d + 1, grey.darkened(0.12))
	for s in 3:
		var x0 := s * 12
		_paint(m, x0, 1, 0, 1, 34, 1, grey.darkened(0.25))  # section seams
		_paint(m, x0 + 1, 23, 0, 11, 1, 1, grey.darkened(0.2))
		_paint(m, x0 + 1, 11, 0, 11, 1, 1, grey.darkened(0.2))
		# meter compartment
		if new:
			m.box(x0 + 3, 27, -1, 6, 5, 1, Wear.CHARCOAL)
			m.box(x0 + 4, 28, -2, 4, 3, 1, Plant.SCREEN_DARK)
			m.box(x0 + 4, 30, -2, 4, 1, 1, Plant.LCD)
		else:
			var dead := worn and s == 1
			Plant._meter(m, x0 + 2, 28, -1, 4, 4, Wear.OLD_CREAM, Wear.CHARCOAL, -0.3 + s * 0.3)
			Plant._meter(m, x0 + 7, 28, -1, 4, 4, Wear.OLD_CREAM if not (age == Wear.REPAIRED and s == 2) else Wear.WHITE, Wear.CHARCOAL, 0.4)
			m.set_voxel(x0 + 3, 26, -1, Plant.LAMP_GREEN if not dead else Plant.LAMP_GREEN.darkened(0.6))
			m.set_voxel(x0 + 5, 26, -1, Plant.LAMP_RED.darkened(0.5))
			if worn and s == 0:
				m.box(x0 + 7, 30, -2, 3, 1, 1, Wear.DUCT_TAPE)
		m.box(x0 + 8, 25, -1, 2, 1, 1, Wear.CHARCOAL)  # selector
		# the breaker behind its door
		m.box(x0 + 2, 13, -1, 8, 9, 1, Wear.CHARCOAL if not worn else Wear.CHARCOAL.lightened(0.1))
		m.box(x0 + 4, 17, -2, 4, 1, 1, BLACK)  # handle
		m.set_voxel(x0 + 4, 19, -2, Plant.LAMP_RED if s != 1 else Plant.LAMP_GREEN)  # closed / open flag
		m.box(x0 + 3, 21, -2, 6, 1, 1, Wear.PAPER)  # engraved label
		m.box(x0 + 10, 15, -1, 1, 4, 1, CHROME)  # door handle
		# louvres
		for y in range(3, 10, 2):
			_paint(m, x0 + 2, y, 0, 8, 1, 1, grey.darkened(0.35))
		# warning label
		m.box(x0 + 2, 33, -1, 4, 1, 1, Plant.SAFETY_ORANGE if new else Plant.SAFETY_YELLOW)
		if new:
			m.box(x0 + 6, 33, -1, 4, 1, 1, Wear.WHITE)  # arc-flash label
		# conduit stubs up to the ceiling
		Plant._cyl_y(m, x0 + 4.0, 7.0, 36, 2, 1.0, Wear.OLD_STEEL)
		Plant._cyl_y(m, x0 + 8.0, 7.0, 36, 2, 1.0, Wear.OLD_STEEL)
	if age == Wear.REPAIRED:
		m.box(16, 16, -3, 1, 2, 1, Wear.RED)  # lockout tag on the feeder
		m.set_voxel(16, 18, -2, Plant.SAFETY_YELLOW)
	if worn:
		Wear.rust(m, grey, 0.03, 81)
		_speckle(m, 0, 1, 0, w, 4, 1, Wear.RUST, 0.25, 82)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## A breaker panel, 0.52 x 1.04 m, with its door swung open: two columns of
## breakers with a label strip beside each, the main breaker on top and the
## typed directory card on the inside of the door. A wall piece; mount it
## about 1 m up. Worn: rusty, a tripped breaker, handwritten tape labels and
## a missing knockout; repaired: a red lockout on one breaker; renovated: a
## new white-grey panel with printed labels.
static func _breaker_panel(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var grey := Color("d2d6d8") if new else ANSI61
	var w := 8
	var hh := 16
	m.box(0, 0, 1, w, hh, 2, grey)
	m.box(1, 1, 0, w - 2, hh - 2, 1, grey.lightened(0.08))  # dead front
	m.box(2, 12, -1, 4, 2, 1, BLACK)  # main breaker
	m.set_voxel(3, 13, -2, BLACK)
	for y in range(2, 11):
		var label := Wear.PAPER if not worn else Wear.DUCT_TAPE
		m.set_voxel(1, y, -1, label)
		m.set_voxel(6, y, -1, label)
		for x: int in [2, 4]:
			m.box(x, y, -1, 2, 1, 1, BLACK)
			var flip := posmod(y * 3 + x, 5) == 0
			m.set_voxel(x + (1 if flip else 0), y, -2, Plant.SAFETY_ORANGE if worn and y == 6 and x == 4 else Wear.CHARCOAL)
			if flip:
				pass
	# the door, swung open toward the viewer's right (+X), with its card
	m.box(w, 0, -6, 1, hh, 6, grey)
	m.box(w - 1, 4, -5, 1, 8, 4, Wear.PAPER)
	for y in range(5, 12, 2):
		m.box(w - 1, y, -4, 1, 1, 2, Color("3a3d44"))  # typed lines
	m.set_voxel(w, 8, -5, CHROME)  # latch
	Plant._cyl_y(m, 4.0, 2.0, hh, 2, 1.0, Wear.OLD_STEEL)  # conduit stub
	if worn:
		Wear.rust(m, grey, 0.05, 91)
		m.set_voxel(2, 0, 0, BLACK)  # a missing knockout
	elif age == Wear.REPAIRED:
		m.box(4, 8, -2, 1, 1, 1, Wear.RED)  # lockout on a breaker
	return m.set_pivot(w * 0.5, 0, 2)


## A dry-type transformer, 1.3 x 0.9 x 1.7 m: an enclosure on a skid with
## louvred vents low and high, lifting eyes, a nameplate, the warning label,
## a ground strap and the bus duct on top. Worn: dusty grey with rust streaks;
## renovated: light grey with a temperature monitor.
static func _transformer(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var grey := ANSI49 if new else ANSI61.darkened(0.05)
	m.box(0, 0, 0, 20, 1, 14, BLACK)
	m.box(1, 1, 1, 18, 24, 12, grey)
	for y: int in [3, 5, 7, 19, 21, 23]:
		_paint(m, 3, y, 1, 14, 1, 1, grey.darkened(0.4))  # front louvres
		_paint(m, 1, y, 3, 1, 1, 8, grey.darkened(0.4))  # side louvres
		_paint(m, 18, y, 3, 1, 1, 8, grey.darkened(0.4))
	for p: Vector2i in [Vector2i(2, 2), Vector2i(17, 2), Vector2i(2, 11), Vector2i(17, 11)]:
		m.box(p.x, 25, p.y, 1, 1, 1, grey.darkened(0.2))  # lifting eyes
	m.box(8, 14, 0, 4, 2, 1, ALU)  # nameplate
	m.box(7, 17, 0, 6, 2, 1, Plant.SAFETY_YELLOW)  # DANGER label
	m.box(8, 17, -1, 4, 1, 1, BLACK)
	m.box(6, 25, 4, 8, 2, 6, grey.darkened(0.1))  # bus duct
	m.box(19, 1, 6, 1, 3, 1, Plant.COPPER)  # ground strap
	if new:
		m.box(14, 12, 0, 3, 3, 1, Wear.CHARCOAL)
		m.box(15, 13, -1, 1, 1, 1, Plant.LCD)
	if age == Wear.WORN:
		for x: int in [4, 9, 15]:
			_speckle(m, x, 6, 1, 1, 12, 1, Wear.RUST, 0.6, 101 + x)
		Wear.rust(m, grey, 0.02, 104)
	return m.set_pivot(10, 0, 7)


## A bank of three utility meters on their sockets, on a backboard with the
## gutter below. A wall piece. Worn: glass-domed dial meters on plywood with
## wire seals; renovated: digital smart meters.
static func _meter_bank(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	m.box(0, 0, 3, 13, 13, 1, Wear.PLYWOOD if not new else Wear.CHARCOAL.lightened(0.15))
	m.box(0, 0, 1, 13, 2, 2, ANSI61 if not new else ANSI49)  # gutter
	for i in 3:
		var x := 1 + i * 4
		m.box(x, 3, 1, 3, 7, 2, ANSI61 if not new else ANSI49)  # socket
		m.box(x + 1, 2, 2, 1, 1, 1, Wear.OLD_STEEL)
		if new:
			m.box(x, 5, 0, 3, 3, 1, Wear.WHITE)
			m.set_voxel(x + 1, 6, -1, Plant.LCD)
		else:
			Plant._cyl_z(m, x + 1.5, 6.5, -1, 2, 1.4, Color("d8e4e8"))  # glass dome
			m.set_voxel(x + 1, 6, -2, BLACK)  # the disc and dials
			m.set_voxel(x + 1, 4, 0, Wear.RED)  # wire seal
	Plant._cyl_y(m, 6.5, 2.0, 13, 2, 0.9, Wear.OLD_STEEL)
	return m.set_pivot(6.5, 0, 2)


## The fire alarm control panel. A wall piece. Worn: an old zone panel with
## lamps and a paper zone list; renovated: an addressable panel with an LCD.
static func _fire_panel(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	m.box(0, 0, 0, 7, 9, 2, FIRE_RED.darkened(0.2 if age == Wear.WORN else 0.0))
	if new:
		m.box(1, 5, -1, 5, 2, 1, Plant.SCREEN_DARK)
		m.box(2, 6, -1, 3, 1, 1, Plant.LCD)
	else:
		for i in 4:
			m.set_voxel(1 + i, 6, -1, Plant.LAMP_AMBER.darkened(0.5) if i != 0 else Plant.LAMP_GREEN)
		m.box(1, 2, -1, 3, 3, 1, Wear.PAPER)  # zone list
	m.set_voxel(5, 3, -1, Plant.LAMP_GREEN)  # AC power
	m.set_voxel(5, 2, -1, CHROME)  # key switch
	m.box(1, 8, -1, 5, 1, 1, Wear.WHITE)  # FIRE ALARM label
	return m.set_pivot(3.5, 0, 1)


## A 10 lb ABC extinguisher: cylinder, valve and handle, gauge, hose and the
## inspection tag. Worn: faded with an old tag; renovated: bright.
static func _fire_extinguisher(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var red := FIRE_RED if age != Wear.WORN else FIRE_RED.lerp(Color("8a5a50"), 0.3)
	Plant._cyl_y(m, 2.0, 2.0, 0, 8, 1.5, red)
	m.box(1, 8, 1, 2, 1, 2, BLACK)
	m.box(1, 9, 1, 2, 1, 2, CHROME)
	_bar(m, Vector3(2, 10.2, 2), Vector3(2, 10.2, -0.2), 0.4, BLACK)
	m.set_voxel(2, 9, 0, Plant.LAMP_GREEN)  # gauge
	_bar(m, Vector3(3, 9, 2), Vector3(3.6, 3, 2.5), 0.45, BLACK)  # hose
	m.box(0, 6, 0, 1, 2, 1, Wear.PAPER if age != Wear.WORN else Color("c8b07a"))  # tag
	return m.set_pivot(2, 0, 2)


## A 6-ft step ladder standing open: rails, steps, spreaders and the top cap.
## Worn: an old wooden ladder spattered with paint; repaired: the same with a
## taped rail; renovated: yellow fibreglass with aluminium steps.
static func _step_ladder(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var rail := FIBERGLASS if new else Wear.OLD_WOOD
	var step := ALU if new else Wear.OLD_WOOD.lightened(0.1)
	for x: float in [0.5, 7.5]:
		_bar(m, Vector3(x, 0.4, 0.5), Vector3(x, 26.5, 5.5), 0.8, rail)
		_bar(m, Vector3(x, 0.4, 11.5), Vector3(x, 26.0, 6.5), 0.7, rail)
	for i in 4:
		var y := 6.0 + i * 5.5
		var z := 0.5 + (y / 26.5) * 5.0
		m.add_oriented(Vector3(4.0, y, z + 0.6), Basis(), Vector3(7.0, 0.5, 1.6), step)
	m.box(0, 26, 4, 8, 1, 3, BLACK if new else rail.darkened(0.2))  # top cap
	m.add_oriented(Vector3(4.0, 13, 8.5), Basis(), Vector3(7.0, 0.3, 0.3), Wear.OLD_STEEL)  # spreader
	for x: int in [0, 7]:
		m.set_voxel(x, 0, 0, BLACK).set_voxel(x, 0, 11, BLACK)  # feet
	if age == Wear.WORN:
		for p: Vector3 in [Vector3(4, 11.5, 2.8), Vector3(2, 17, 3.8), Vector3(6, 6, 1.8)]:
			m.add_oriented(p, Basis(), Vector3(0.8, 0.3, 0.8), Color("eeeeea"))  # paint drips
	elif age == Wear.REPAIRED:
		m.add_oriented(Vector3(0.5, 9, 2.2), Basis(Vector3.RIGHT, 0.19), Vector3(1.0, 2.0, 1.0), Wear.DUCT_TAPE)
	return m.set_pivot(4, 0, 6)


# ---------------------------------------------------------------- weight room

## The bench colours: frame, pad, plates.
static func _gym(age: int) -> Dictionary:
	match age:
		Wear.WORN: return {"frame": Color("5a5e64"), "pad": VINYL_OLD, "plate": IRON, "bar": WAYS}
		Wear.REPAIRED: return {"frame": Wear.CHARCOAL, "pad": BLACK, "plate": IRON, "bar": CHROME}
	return {"frame": Wear.NAVY, "pad": BLACK, "plate": BUMPER[0], "bar": CHROME}


## A flat bench press: the pad, the uprights with J-hooks at the head end,
## safety arms, and a loaded bar on the hooks. Worn: torn red vinyl with a
## taped split, rusty uprights and iron plates; repaired: a new black pad;
## renovated: a navy frame and colour-coded bumper plates.
static func _bench_press(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame
	var pad: Color = g.pad
	var plate: Color = g.plate
	var bar: Color = g.bar
	m.box(14, 0, 1, 5, 1, 2, frame)  # foot
	m.box(16, 1, 2, 1, 5, 1, frame)
	m.box(14, 0, 13, 5, 1, 3, frame)
	m.box(16, 1, 2, 1, 1, 13, frame)  # spine
	m.box(16, 1, 13, 1, 5, 1, frame)
	m.box(14, 6, 2, 5, 1, 13, pad)
	m.box(14, 5, 2, 5, 1, 13, frame.darkened(0.2))
	for x: int in [12, 20]:
		m.box(x, 0, 14, 1, 18, 2, frame)  # uprights
		m.box(x, 0, 12, 1, 1, 5, frame)
		m.box(x, 17, 13, 1, 1, 1, frame)  # J-hooks
		m.box(x, 10, 12, 1, 1, 2, frame)  # safety arms
	m.box(12, 18, 15, 9, 1, 1, frame)  # cross brace
	m.box(0, 18, 13, 33, 1, 1, bar)  # the bar
	var plates: Color = plate
	_plate(m, 3, 2, 18.5, 13.5, 3.5, plates)
	_plate(m, 28, 2, 18.5, 13.5, 3.5, plates)
	_plate(m, 5, 1, 18.5, 13.5, 2.5, BUMPER[1] if age == Wear.RENOVATED else plates)
	_plate(m, 27, 1, 18.5, 13.5, 2.5, BUMPER[1] if age == Wear.RENOVATED else plates)
	m.box(6, 18, 13, 1, 1, 1, CHROME).box(26, 18, 13, 1, 1, 1, CHROME)  # collars
	if age == Wear.WORN:
		m.box(15, 7, 7, 3, 1, 2, Wear.DUCT_TAPE)  # the split in the vinyl
		m.set_voxel(14, 6, 10, Color("d8c890"))  # foam showing
		Wear.rust(m, frame, 0.12, 111)
		Wear.rust(m, bar, 0.2, 112)
	return m.set_pivot(16.5, 0, 9)


## A power rack, 1.24 m square and 2.34 m tall: four uprights with their
## hole pattern, top cross members and a pull-up bar, J-hooks with a loaded
## bar, safety pins, plate horns on the back with plates, and a lifting
## platform under it. Worn: brown-red paint, a rusty bar, iron plates;
## repaired: black; renovated: navy with bumper plates and a band hanging.
static func _squat_rack(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame if age != Wear.WORN else Color("6a3a2a")
	var bar: Color = g.bar
	var plate: Color = g.plate
	var wood := Wear.OLD_WOOD if age != Wear.RENOVATED else Wear.NEW_WOOD
	m.box(-6, 0, -3, 31, 1, 25, Wear.RUBBER.lightened(0.08))  # platform
	m.box(1, 0, -1, 17, 1, 21, wood)
	for x: int in [1, 16]:
		for z: int in [1, 16]:
			m.box(x, 1, z, 2, 35, 2, frame)
			if Wear.fine:
				for y in range(4, 34, 2):
					m.set_voxel(x, y, z, frame.darkened(0.45))  # hole pattern
	for z: int in [1, 16]:
		m.box(1, 34, z, 17, 2, 2, frame)
	for x: int in [1, 16]:
		m.box(x, 34, 1, 2, 2, 17, frame)
	m.box(0, 32, -1, 19, 1, 1, bar)  # pull-up bar
	for x: int in [1, 16]:
		m.box(x, 21, 0, 2, 1, 1, frame.darkened(0.2))  # J-hooks
		m.box(x, 11, 1, 1, 1, 17, bar)  # safety pins
	m.box(-7, 22, 0, 33, 1, 1, bar)
	_plate(m, -5, 2, 22.5, 0.5, 3.5, plate)
	_plate(m, 22, 2, 22.5, 0.5, 3.5, plate)
	_plate(m, -3, 1, 22.5, 0.5, 2.5, BUMPER[2] if age == Wear.RENOVATED else plate)
	_plate(m, 21, 1, 22.5, 0.5, 2.5, BUMPER[2] if age == Wear.RENOVATED else plate)
	# plate horns on the back uprights, plates stored on them
	for x: int in [-2, 19]:
		m.box(x, 6, 17, 2, 1, 1, bar)
		m.box(x, 14, 17, 2, 1, 1, bar)
		_plate(m, x if x < 0 else x + 1, 1, 6.5, 17.5, 3.5, plate)
		_plate(m, x if x < 0 else x + 1, 1, 14.5, 17.5, 2.5, BUMPER[1] if age == Wear.RENOVATED else plate)
	if age == Wear.RENOVATED:
		_bar(m, Vector3(2, 33, 2), Vector3(2.5, 18, 2.5), 0.4, Color("2f9a4f"))  # a band
	elif age == Wear.WORN:
		Wear.rust(m, bar, 0.2, 121)
		_speckle(m, 1, 0, -1, 17, 1, 21, Wear.OLD_WOOD_DARK, 0.25, 122)
	return m.set_pivot(9.5, 0, 9.5)


## A 45-degree leg press: the base frame, the reclined seat, the sled on its
## rails with the footplate and plate horns, the front support and the
## handles. Worn: the old gold frame and red vinyl; renovated: navy.
static func _leg_press(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame if age != Wear.WORN else GOLD_FRAME
	var pad: Color = g.pad
	var plate: Color = g.plate
	for x: int in [2, 13]:
		m.box(x, 0, 0, 2, 2, 30, frame)  # base rails
	m.box(2, 0, 28, 13, 2, 2, frame)
	m.box(2, 0, 0, 13, 2, 2, frame)
	m.box(5, 2, 0, 6, 20, 3, frame)  # front support
	for x: float in [4.5, 11.5]:
		_bar(m, Vector3(x, 4, 21), Vector3(x, 22, 3), 1.2, frame)  # rails
	var tilt := Basis(Vector3.RIGHT, PI * 0.25)
	m.add_oriented(Vector3(8, 14.5, 11.0), tilt, Vector3(11, 1.0, 8), frame.darkened(0.25))  # footplate
	m.add_oriented(Vector3(8, 15.5, 12.0), tilt, Vector3(9, 0.4, 6), Wear.RUBBER)  # its grip
	for x: float in [0.0, 16.0]:
		_bar(m, Vector3(8, 15.5, 12.5), Vector3(x, 15.5, 12.5), 0.8, CHROME)  # horns
		m.add_oriented(Vector3(x + (0.5 if x < 1 else -0.5), 15.5, 12.5), tilt, Vector3(1.5, 7, 7), plate)
	m.box(4, 2, 20, 9, 3, 8, frame)  # seat base
	m.box(4, 5, 20, 9, 1, 6, pad)  # seat
	m.add_oriented(Vector3(8.5, 9.5, 27.0), Basis(Vector3.RIGHT, -0.45), Vector3(9, 9, 1.2), pad)  # back
	for x: int in [3, 13]:
		m.box(x, 5, 19, 1, 2, 1, CHROME)  # handles
	if age == Wear.WORN:
		Wear.rust(m, frame, 0.05, 131)
		m.box(6, 6, 21, 3, 1, 2, Wear.DUCT_TAPE)
	return m.set_pivot(8.5, 0, 15)


## A cable crossover 3 m wide: two towers with weight stacks and guide rods,
## pulleys high and low, cables with D handles, the top beam and a multi-grip
## pull-up bar between. Worn: the old gold frame; renovated: navy.
static func _cable_crossover(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame if age != Wear.WORN else GOLD_FRAME
	for x0: int in [0, 40]:
		m.box(x0, 0, 0, 6, 1, 10, frame)
		m.box(x0, 1, 3, 1, 34, 2, frame)
		m.box(x0 + 5, 1, 3, 1, 34, 2, frame)
		m.box(x0, 1, 8, 6, 34, 1, frame.darkened(0.15))  # back shroud
		for y in 14:
			m.box(x0 + 2, 1 + y, 4, 2, 1, 2, IRON if y % 2 == 0 else IRON.lightened(0.12))  # stack
		m.box(x0 + 1, 1, 6, 1, 30, 1, CHROME)  # guide rods
		m.box(x0 + 4, 1, 6, 1, 30, 1, CHROME)
		var px := x0 + 3.0
		Plant._cyl_z(m, px, 30.5, 2, 1, 1.2, BLACK)  # high pulley
		Plant._cyl_z(m, px, 4.5, 2, 1, 1.2, BLACK)  # low pulley
		_bar(m, Vector3(px, 30, 2), Vector3(px + (2.5 if x0 == 0 else -2.5), 21, 0), 0.25, Color("3a3d44"))  # cable
		m.add_oriented(Vector3(px + (2.5 if x0 == 0 else -2.5), 20.5, 0), Basis(), Vector3(1.6, 0.4, 0.4), BLACK)  # D handle
		m.box(x0 + 2, 15, 4, 2, 1, 1, Wear.RED)  # the pin
	m.box(0, 35, 3, 46, 1, 3, frame)
	m.box(6, 33, 2, 34, 1, 1, CHROME)  # pull-up bar
	m.set_voxel(21, 32, 2, BLACK).set_voxel(24, 32, 2, BLACK)
	if age == Wear.WORN:
		Wear.rust(m, frame, 0.04, 141)
		Wear.rust(m, CHROME, 0.2, 142)
	return m.set_pivot(23, 0, 5)


## A lat pulldown: the upright with its weight stack, the beam out front with
## the pulley, the bar on its cable, the seat and the knee roller. Worn: the
## old universal's gold frame and red vinyl; renovated: navy.
static func _lat_pulldown(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame if age != Wear.WORN else GOLD_FRAME
	var pad: Color = g.pad
	var bar: Color = g.bar
	m.box(5, 0, 0, 4, 1, 20, frame)
	m.box(6, 1, 14, 2, 35, 2, frame)  # upright
	m.box(4, 1, 16, 6, 18, 3, frame.darkened(0.15))  # stack shroud
	for y in 14:
		m.box(5, 2 + y, 16, 4, 1, 1, IRON if y % 2 == 0 else IRON.lightened(0.12))  # stack showing at the front
	m.box(6, 34, 2, 2, 2, 12, frame)  # beam
	Plant._cyl_x(m, 6, 2, 33.5, 2.5, 1.2, BLACK)
	_bar(m, Vector3(7, 33, 2.5), Vector3(7, 24.5, 2.5), 0.25, Color("3a3d44"))
	m.box(0, 24, 2, 14, 1, 1, bar)
	m.box(0, 23, 2, 1, 1, 1, BLACK).box(13, 23, 2, 1, 1, 1, BLACK)  # grips
	m.box(6, 1, 7, 2, 6, 2, frame)  # seat post
	m.box(4, 7, 6, 6, 1, 5, pad)
	Plant._cyl_x(m, 3, 8, 11.0, 7.5, 1.2, pad)  # knee roller
	m.box(6, 7, 7, 2, 4, 1, frame)
	if age == Wear.WORN:
		Wear.rust(m, frame, 0.05, 151)
		m.box(5, 8, 7, 2, 1, 2, Wear.DUCT_TAPE)
	return m.set_pivot(7, 0, 10)


## A two-tier dumbbell rack, 2 m long, with dumbbells from light to heavy
## across the front tier and on the back. Worn: chrome-and-iron dumbbells,
## rust, mismatched, a pair missing; renovated: black urethane heads with red
## end caps.
static func _dumbbell_rack(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	for x: int in [0, 15, 30]:
		m.box(x, 0, 0, 1, 7, 1, frame)
		m.box(x, 0, 8, 1, 12, 1, frame)
		m.box(x, 0, 0, 1, 1, 9, frame)
	for y: int in [6, 11]:
		var z0 := 0 if y == 6 else 5
		m.box(0, y, z0, 31, 1, 1, frame)
		m.box(0, y, z0 + 3, 31, 1, 1, frame)
	for tier in 2:
		var y := 7 if tier == 0 else 12
		var z0 := 0 if tier == 0 else 5
		for i in 10:
			if worn and tier == 1 and (i == 3 or i == 4):
				continue  # a pair gone missing
			var x := 1 + i * 3
			var s := 2 if i + tier * 10 < 12 else 3
			var head := BLACK if new else IRON
			if worn and posmod(i * 7 + tier, 4) == 0:
				head = CHROME.darkened(0.25)  # an odd old chrome one
			m.box(x, y, z0 + 1, 1, 1, 2, CHROME)  # handle
			m.box(x - (s - 1) / 2, y, z0 - 1, s, s, 2, head)
			m.box(x - (s - 1) / 2, y, z0 + 3, s, s, 2, head)
			if new:
				m.box(x - (s - 1) / 2, y, z0 - 1, s, s, 1, Wear.RED)  # end caps
	if worn:
		Wear.rust(m, CHROME, 0.25, 161)
		Wear.rust(m, frame, 0.08, 162)
	return m.set_pivot(15.5, 0, 4.5)


## A plate tree: a cross base, the post, and three pairs of horns loaded
## with plates, big at the bottom. Worn: iron plates, rust; renovated:
## bumper plates in their colours.
static func _plate_tree(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var g := _gym(age)
	var frame: Color = g.frame
	var new := age == Wear.RENOVATED
	m.box(0, 0, 4, 10, 1, 2, frame)
	m.box(4, 0, 0, 2, 1, 10, frame)
	m.box(4, 1, 4, 2, 19, 2, frame)
	var tiers := [[4, 3.5], [10, 2.6], [15, 1.8]]
	for t in tiers.size():
		var y: int = tiers[t][0]
		var r: float = tiers[t][1]
		m.box(1, y, 4, 3, 1, 1, CHROME)
		m.box(6, y, 4, 3, 1, 1, CHROME)
		var c: Color = BUMPER[t] if new else IRON
		_plate(m, 1, 2, y + 0.5, 4.5, r, c)
		_plate(m, 7, 2, y + 0.5, 4.5, r, c)
	if age == Wear.WORN:
		Wear.rust(m, IRON, 0.08, 171)
		Wear.rust(m, CHROME, 0.3, 172)
	return m.set_pivot(5, 0, 5)


## An upright exercise bike: stabiliser feet, the frame, the flywheel at the
## front, cranks and pedals, the saddle, the handlebars and the console.
## Worn: a beige 80s bike with chrome and a taped saddle; renovated: black and
## red with an LCD.
static func _stationary_bike(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var body := Color("1b1d22") if new else Color("c9bfa4")
	var accent := Wear.RED if new else CHROME
	m.box(0, 0, 1, 8, 1, 2, accent.darkened(0.2))
	m.box(0, 0, 15, 8, 1, 2, accent.darkened(0.2))
	m.box(3, 1, 2, 2, 1, 14, body)
	Plant._cyl_x(m, 3, 2, 6.0, 5.0, 4.4, body)  # flywheel and its shroud
	_bar(m, Vector3(4, 2, 14), Vector3(4, 13, 11.5), 1.2, body)  # seat tube
	_bar(m, Vector3(4, 6, 6), Vector3(4, 17, 4.5), 1.2, body)  # head tube
	_bar(m, Vector3(4, 6, 8), Vector3(4, 5, 12), 1.0, body)
	m.box(2, 13, 10, 4, 1, 4, BLACK)  # saddle
	m.box(0, 17, 4, 8, 1, 1, accent)  # handlebars
	m.box(0, 18, 4, 1, 1, 1, BLACK).box(7, 18, 4, 1, 1, 1, BLACK)
	m.box(2, 18, 3, 4, 2, 1, Wear.CHARCOAL)  # console
	m.set_voxel(3, 19, 2, Plant.LCD if new else Plant.LAMP_RED.darkened(0.3))
	for s: int in [-1, 1]:
		var p := Vector3(4 + s * 2.5, 6 + s * 2.0, 9.5)
		_bar(m, Vector3(4, 6, 9.5), p, 0.6, CHROME)
		m.add_oriented(p + Vector3(s * 0.6, 0, 0), Basis(), Vector3(1.0, 0.4, 1.6), BLACK)  # pedal
	if age == Wear.WORN:
		m.box(3, 14, 11, 2, 1, 2, Wear.DUCT_TAPE)
		Wear.rust(m, CHROME, 0.2, 181)
	return m.set_pivot(4, 0, 9)


## A treadmill: the motor hood at the front, the deck and belt, uprights,
## handrails and the console. Worn: a tired 90s unit with an OUT OF ORDER
## sheet taped to the console and a grey, glazed belt; renovated: a new unit
## with a big screen.
static func _treadmill(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var body := Wear.CHARCOAL if new else Color("8a8a84")
	m.box(0, 0, 4, 13, 2, 26, Wear.CHARCOAL)  # deck frame
	m.box(1, 2, 5, 11, 1, 24, Color("3a3a38") if worn else Wear.RUBBER)  # belt
	m.box(0, 2, 5, 1, 1, 24, body)  # side rails
	m.box(12, 2, 5, 1, 1, 24, body)
	m.box(0, 0, 0, 13, 4, 5, body)  # motor hood
	m.box(0, 4, 3, 1, 14, 2, body)
	m.box(12, 4, 3, 1, 14, 2, body)
	m.box(0, 15, 4, 1, 1, 9, body.lightened(0.15))  # handrails
	m.box(12, 15, 4, 1, 1, 9, body.lightened(0.15))
	m.box(0, 18, 2, 13, 3, 4, body)  # console
	m.box(3, 19, 1, 7, 2, 1, Plant.SCREEN if new else Plant.SCREEN_DARK)
	m.box(2, 18, 5, 9, 1, 1, Wear.RED if new else Plant.LAMP_RED.darkened(0.3))  # stop key
	if worn:
		m.box(4, 19, 0, 5, 2, 1, Wear.PAPER)  # OUT OF ORDER
		m.set_voxel(5, 20, -1, Wear.RED)
	return m.set_pivot(6.5, 0, 15)


## A slide board for skating strides, 2.4 x 0.6 m, with its end bumpers and
## a pair of booties. Worn: scuffed white; renovated: black with red bumpers.
static func _slide_board(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var top := Color("1b1d22") if new else Color("dcdcd4")
	m.box(0, 0, 0, 37, 1, 9, top)
	var bump := Wear.RED if new else Color("3a3d44")
	m.box(0, 0, 0, 2, 3, 9, bump)
	m.box(35, 0, 0, 2, 3, 9, bump)
	m.box(16, 1, 2, 2, 1, 2, Color("c8191e") if new else Color("6a2a2a"))  # booties
	m.box(19, 1, 5, 2, 1, 2, Color("c8191e") if new else Color("6a2a2a"))
	if age != Wear.RENOVATED:
		_speckle(m, 2, 0, 0, 33, 1, 9, Color("8a8a84"), 0.15 if age == Wear.WORN else 0.05, 191)
	return m.set_pivot(18.5, 0, 4.5)


# ---------------------------------------------------------------- equipment storage

## A wire ball cart full of basketballs, volleyballs and red playground
## balls. Worn: chipped red paint and a few flat balls; renovated: chrome.
static func _ball_bin(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var wire := CHROME if new else (Color("8a3a2a") if age == Wear.WORN else Color("b8302a"))
	for p: Vector2i in [Vector2i(0, 0), Vector2i(13, 0), Vector2i(0, 8), Vector2i(13, 8)]:
		m.set_voxel(p.x, 0, p.y, BLACK)
		m.box(p.x, 1, p.y, 1, 14, 1, wire)
	m.box(0, 2, 0, 14, 1, 9, wire.darkened(0.15))  # floor of the basket
	for y: float in [6.5, 10.5, 14.5]:
		_bar(m, Vector3(0.5, y, 0.5), Vector3(13.5, y, 0.5), 0.3, wire)
		_bar(m, Vector3(0.5, y, 8.5), Vector3(13.5, y, 8.5), 0.3, wire)
		_bar(m, Vector3(0.5, y, 0.5), Vector3(0.5, y, 8.5), 0.3, wire)
		_bar(m, Vector3(13.5, y, 0.5), Vector3(13.5, y, 8.5), 0.3, wire)
	for x: float in [3.5, 6.5, 9.5]:
		_bar(m, Vector3(x, 3, 0.5), Vector3(x, 14.5, 0.5), 0.3, wire)
		_bar(m, Vector3(x, 3, 8.5), Vector3(x, 14.5, 8.5), 0.3, wire)
	var kinds := [[ORANGE, BLACK], [Color("eeeeea"), Color("2f5fb7")], [Color("c8191e"), Color(0, 0, 0, 0)]]
	var n := 0
	for y: int in [3, 6, 9]:
		for x: int in [1, 4, 7, 10]:
			for z: int in [1, 5]:
				n += 1
				if y == 9 and posmod(x + z, 3) == 0:
					continue
				var k: Array = kinds[posmod(hash(Vector3i(x, y, z)), 3)]
				var c: Color = k[0]
				if age == Wear.WORN:
					c = c.darkened(0.2)
				_ball(m, x, y + (1 if y == 9 and posmod(x, 2) == 0 else 0), z, c, k[1])
	return m.set_pivot(7, 0, 4.5)


## Stacks of orange hockey pylons and two loose ones. Worn: faded and one
## cracked; renovated: bright with a reflective band.
static func _pylon_stack(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var c := ORANGE if age != Wear.WORN else ORANGE.lerp(Color("a07050"), 0.35)
	var band := Wear.WHITE if age == Wear.RENOVATED else c.darkened(0.15)
	for s: Array in [[0, 0, 5], [5, 0, 4], [0, 5, 1], [5, 5, 1]]:
		var x0: int = s[0]
		var z0: int = s[1]
		var n: int = s[2]
		for i in n:
			m.box(x0, i, z0, 4, 1, 4, c.darkened(0.1 * (i % 2)))
		var y0 := n - 1
		m.box(x0 + 1, y0 + 1, z0 + 1, 2, 3, 2, c)
		m.box(x0 + 1, y0 + 3, z0 + 1, 2, 1, 2, band)
		m.box(x0 + 1, y0 + 4, z0 + 1, 1, 2, 1, c)
	if age == Wear.WORN:
		m.set_voxel(6, 4, 6, OIL_STAIN)  # the crack
	return m.set_pivot(4.5, 0, 4.5)


## A hockey net, mini (pee-wee, 1.2 m) or regulation (1.83 m): red posts
## and crossbar, white base frame, and the mesh drawn as thin strips on the
## sides, the slanted back and the top. Worn: faded red with a taped tear;
## renovated: a new net.
static func _net(age: int, w: int, hh: int, d: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var red := NET_RED if age != Wear.WORN else NET_RED.lerp(Color("8a5a50"), 0.35)
	var white := NET_WHITE if age != Wear.WORN else Color("cfcbbd")
	m.box(0, 0, 0, 1, hh, 1, red)
	m.box(w - 1, 0, 0, 1, hh, 1, red)
	m.box(0, hh - 1, 0, w, 1, 1, red)
	m.box(0, 0, 1, 1, 1, d - 1, white)
	m.box(w - 1, 0, 1, 1, 1, d - 1, white)
	m.box(0, 0, d - 1, w, 1, 1, white)
	var top_d := float(d) * 0.35
	var mesh := Color(white.r, white.g, white.b)
	var step := 3
	# the back panel slants from the top bar's depth down to the base
	for x in range(step, w - 1, step):
		_bar(m, Vector3(x + 0.5, hh - 0.5, top_d), Vector3(x + 0.5, 1.0, d - 0.5), 0.2, mesh)
		_bar(m, Vector3(x + 0.5, hh - 0.5, 0.5), Vector3(x + 0.5, hh - 0.5, top_d), 0.2, mesh)
	for y in range(step, hh - 1, step):
		var z := lerpf(d - 0.5, top_d, float(y) / hh)
		_bar(m, Vector3(0.5, y + 0.5, z), Vector3(w - 0.5, y + 0.5, z), 0.2, mesh)
		_bar(m, Vector3(0.5, y + 0.5, 0.5), Vector3(0.5, y + 0.5, z), 0.2, mesh)
		_bar(m, Vector3(w - 0.5, y + 0.5, 0.5), Vector3(w - 0.5, y + 0.5, z), 0.2, mesh)
	_bar(m, Vector3(0.5, hh - 0.5, top_d), Vector3(w - 0.5, hh - 0.5, top_d), 0.4, white)
	m.box(1, 1, d - 2, w - 2, 1, 1, white)  # skirt padding
	if age == Wear.WORN:
		m.add_oriented(Vector3(w * 0.4, hh * 0.5, (d + top_d) * 0.5), Basis(Vector3.RIGHT, 0.6), Vector3(2.0, 1.4, 0.3), Wear.DUCT_TAPE)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## A five-gallon pail of practice pucks, heaped, with a few loose on the
## floor. Worn: a cracked orange pail; renovated: a white one with a lid.
static func _puck_bucket(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var pail := Color("e06a1a") if age != Wear.RENOVATED else Color("eeeeea")
	if age == Wear.WORN:
		pail = pail.lerp(Color("8a7060"), 0.35)
	Plant._cyl_y(m, 3.0, 3.0, 0, 6, 2.8, pail)
	Plant._cyl_y(m, 3.0, 3.0, 6, 1, 3.0, pail.darkened(0.15))
	Plant._cyl_y(m, 3.0, 3.0, 6, 1, 2.2, BLACK)  # pucks to the brim
	for p: Vector3i in [Vector3i(2, 7, 2), Vector3i(3, 7, 3), Vector3i(3, 7, 2), Vector3i(2, 7, 3), Vector3i(3, 8, 3)]:
		m.set_voxel(p.x, p.y, p.z, BLACK)
	_bar(m, Vector3(0.2, 6.5, 3), Vector3(3, 9, 3), 0.25, Wear.OLD_STEEL)
	_bar(m, Vector3(3, 9, 3), Vector3(5.8, 6.5, 3), 0.25, Wear.OLD_STEEL)
	for p: Vector3 in [Vector3(7.5, 0.2, 1.0), Vector3(8.2, 0.2, 3.2), Vector3(6.8, 0.2, 5.5)]:
		m.add_oriented(p, Basis(Vector3.UP, p.x), Vector3(1.2, 0.4, 1.2), BLACK)  # loose pucks
	m.set_voxel(7, 0, 4, BLACK)
	return m.set_pivot(4, 0, 3)


## A pair of goalie leg pads standing against the wall with the blocker and
## catcher on top. Worn: brown leather patched and cracked; repaired: brown
## with new straps; renovated: white with navy and red graphics.
static func _goalie_pads(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var leather := Wear.WHITE if new else LEATHER
	var accent := Wear.NAVY if new else LEATHER.darkened(0.3)
	for x0: int in [0, 5]:
		m.box(x0, 0, 0, 4, 13, 3, leather)
		m.box(x0, 1, -1, 4, 2, 1, leather.darkened(0.08))  # toe
		m.box(x0, 7, -1, 4, 3, 1, leather.darkened(0.08))  # knee roll
		m.box(x0, 12, -1, 4, 1, 1, accent)  # thigh rise
		for y: int in [3, 6, 10]:
			m.box(x0 + 3, y, 1, 2 if x0 == 0 else 1, 1, 1, BLACK)  # straps
		if new:
			m.box(x0 + 1, 2, -1, 2, 5, 1, Wear.RED)
	m.box(1, 13, 0, 3, 4, 2, leather)  # blocker
	m.box(1, 13, -1, 3, 4, 1, accent)
	m.box(5, 13, 0, 4, 3, 3, leather)  # catcher
	m.box(6, 16, 0, 2, 1, 2, accent)
	if age == Wear.WORN:
		m.box(1, 4, -1, 2, 2, 1, Color("5a4030"))  # a patch
		_speckle(m, 0, 0, -1, 9, 13, 4, LEATHER.darkened(0.25), 0.12, 201)
	return m.set_pivot(4.5, 0, 1.5)


## A bin of broomball brooms, heads up: the sticks and their moulded rubber
## heads. Worn: a dented grey can and taped shafts; renovated: a navy bin and
## new red and blue heads.
static func _broom_bin(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	Plant._cyl_y(m, 3.0, 3.0, 0, 8, 2.8, Wear.NAVY if new else Wear.OLD_STEEL.darkened(0.1))
	Plant._cyl_y(m, 3.0, 3.0, 8, 1, 3.0, Wear.NAVY.darkened(0.2) if new else Wear.OLD_STEEL)
	var heads := [Color("c8191e"), Color("2f5fb7")] if new else [Color("a83a2a"), Color("3a4a6a")]
	for i in 7:
		var a := TAU * i / 7.0
		var base := Vector3(3 + cos(a) * 1.2, 1, 3 + sin(a) * 1.2)
		var tip := Vector3(3 + cos(a) * 3.0, 20 + (i % 3), 3 + sin(a) * 3.0)
		_bar(m, base, tip, 0.45, Wear.OLD_WOOD if not new else BLACK)
		m.add_oriented(tip + Vector3(0, 1.0, 0), Basis(Vector3.UP, a), Vector3(2.6, 1.6, 0.9), heads[i % 2])
		if age == Wear.WORN and i % 3 == 0:
			m.add_oriented(base.lerp(tip, 0.6), Basis(), Vector3(0.8, 1.2, 0.8), Wear.DUCT_TAPE)
	return m.set_pivot(3, 0, 3)


## Figure skating and learn-to-skate markers: a carry pole of stacked disc
## cones in two colours, slim marker cones and flat spot markers.
static func _skate_cones(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var a := Color("f0d020")
	var b := Color("ee6a1a")
	if age == Wear.WORN:
		a = a.lerp(Color("a09060"), 0.35)
		b = b.lerp(Color("a07050"), 0.35)
	elif age == Wear.RENOVATED:
		b = Color("e0308a")  # fluorescent pink for the figure club
	m.box(2, 0, 2, 3, 1, 3, BLACK)  # pole base
	m.box(3, 1, 3, 1, 8, 1, BLACK)
	for i in 7:
		Plant._cyl_y(m, 3.5, 3.5, 1 + i, 1, 2.6, a if i % 2 == 0 else b)
	for p: Vector2i in [Vector2i(8, 1), Vector2i(10, 4), Vector2i(8, 6)]:
		m.box(p.x, 0, p.y, 2, 1, 2, b)
		m.box(p.x, 1, p.y, 1, 3, 1, b)
	for p: Vector3 in [Vector3(12.5, 0.1, 1.5), Vector3(13, 0.1, 5)]:
		m.add_oriented(p, Basis(), Vector3(2.4, 0.2, 2.4), a)  # spot markers
	return m.set_pivot(7, 0, 4)


## A pile of hockey bags: two big duffels with their straps and zips, and a
## mesh laundry bag of practice jerseys on top. Worn: faded, a split seam;
## renovated: club navy and red.
static func _hockey_bags(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var c1 := Wear.NAVY if new else Color("3a4a6a")
	var c2 := Wear.RED if new else Color("6a2a2a")
	if age == Wear.WORN:
		c1 = c1.lerp(Color("6a6458"), 0.3)
		c2 = c2.lerp(Color("6a6458"), 0.3)
	for b: Array in [[0, 0, 0, c1], [1, 5, 6, c2]]:
		var x0: int = b[0]
		var y0: int = b[1]
		var z0: int = b[2]
		var col: Color = b[3]
		m.box(x0, y0, z0, 13, 5, 6, col)
		for c: Vector3i in [Vector3i(0, 0, 0), Vector3i(12, 0, 0), Vector3i(0, 4, 0), Vector3i(12, 4, 0), Vector3i(0, 0, 5), Vector3i(12, 0, 5), Vector3i(0, 4, 5), Vector3i(12, 4, 5)]:
			m.voxels.erase(Vector3i(x0, y0, z0) + c)  # round the corners
		m.box(x0 + 1, y0 + 4, z0 + 2, 11, 1, 1, Wear.CHARCOAL)  # zip
		m.box(x0 + 4, y0 + 5, z0 + 2, 1, 1, 2, BLACK)  # strap
		m.box(x0 + 8, y0 + 5, z0 + 2, 1, 1, 2, BLACK)
		m.box(x0 + 1, y0 + 1, z0 - 1, 3, 2, 1, Wear.WHITE if new else Wear.PAPER)  # name tag
	# the laundry bag of jerseys, mesh over colours
	for x in 6:
		for y in 4:
			for z in 4:
				var jersey: Color = [Color("e8e8e2"), Color("c8191e"), Color("2f5fb7"), Color("e0b020")][posmod(hash(Vector3i(x, y, z)), 4)]
				m.set_voxel(1 + x, 5 + y, z, jersey if posmod(x + y + z, 2) == 0 else Color("d8d8d0"))
	if age == Wear.WORN:
		m.box(6, 2, -1, 3, 1, 1, Color("d8c890"))  # the split seam
	return m.set_pivot(6.5, 0, 6)
