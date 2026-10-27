extends RefCounted
## The refrigeration plant room: compressors, the chiller, the receiver,
## pumps, tanks, headers, pipe pieces, the rooftop condenser, the control
## panel and the safety kit. Built like every other prop (see props.gd): one
## builder per id and age, pivot on the floor and centred, front facing -Z,
## +X the viewer's left. Props.model() and Props.mesh() dispatch here.
##
## The parts the player services in the plant mini games (docs/world/RINK_SIM.md
## 3.1 and 4.2 to 4.6, 4.12) are modelled where they can be seen: cylinder
## heads and valve plates, the oil sight glass (filled to its level), the
## shaft seal and its drip tray, coupling and belt guards, the pump bearing
## housing and seal, dial gauges, the chiller oil pot, level glasses and
## relief valves.
##
## Ages: WORN is Millbrook's 1974 ammonia plant (machinery-green enamel, black
## pipe, frosted suction lines, rust, oil stains and drip trays). REPAIRED is
## the same plant kept going: fresh paint, yellow replacement guards, a new
## gauge or hose. RENOVATED is modern clean equipment: navy and charcoal,
## stainless, jacketed insulation, yellow pipe labels, screens.

const V := Models.V

## Plant colours on top of the Wear palettes.
const OLD_PLANT := Color("4f6e5d")       # 1970s machinery-green enamel
const OLD_PLANT_DARK := Color("3a5446")
const OLD_MOTOR := Color("566a7e")       # blue-grey motor enamel
const OLD_PIPE := Color("4a4e52")        # black-painted steel pipe
const OLD_PANEL := Color("8a9188")       # ANSI grey electrical cabinet
const HEAD_IRON := Color("6d7276")       # bare cast iron
const SCREW_BLUE := Color("2f5f8f")      # the second-hand screw package
const CO2_BODY := Color("3c5f86")
const SAFETY_YELLOW := Color("f2c230")
const SAFETY_ORANGE := Color("ee7a22")
const SAFETY_GREEN := Color("2f9a4f")
const OIL := Color("d29a2c")
const OIL_DARK := Color("4a2a12")
const OIL_STAIN := Color("1e1a16")
const FROST := Color("eef3f6")
const INSUL_OLD := Color("d6cfb8")       # canvas-jacketed insulation
const INSUL_NEW := Color("f3f4f1")       # PVC jacket
const ALU_JACKET := Color("c9cfd3")
const GLYCOL := Color("57b86a")          # inhibited ethylene glycol, dyed green
const GLYCOL_CRUST := Color("e9e6d6")    # dried glycol round a weeping seal
const WATER_STAIN := Color("9a8a66")
const SCALE := Color("e6e2d4")           # white condenser scale
const COPPER := Color("b8733a")
const BRASS := Color("c6a24a")
const GALV := Color("a7adaf")
const SCREEN := Color("3fb6e8")
const SCREEN_DARK := Color("0f2a3a")
const LCD := Color("8fbf5a")
const LAMP_RED := Color("e8332a")
const LAMP_GREEN := Color("41d161")
const LAMP_AMBER := Color("f5a623")
const WHEEL := Color("b02a22")           # valve handwheels

## Pipe pieces and header modules are this many voxels long (1.04 m) along X,
## so they tile end to end.
const PIPE_LEN := 16
const HEADER_LEN := 16
## The header sits on the floor of a trench this deep (voxels, 0.72 m); its
## jumper hoses meet the floor pipes at the trench's back (+Z) wall.
const HEADER_TRENCH := 11

## Big pieces whose flat panels would cost too many faces with per-voxel
## speckle (see Props._MERGED).
const MERGED := [
	"compressor_recip", "compressor_screw", "compressor_co2", "chiller", "receiver",
	"glycol_pump", "glycol_tank", "header", "condenser", "control_panel",
]


static func build(id: String, age: int) -> VoxelModel:
	match id:
		"compressor_recip": return _compressor_recip(age)
		"compressor_screw": return _compressor_screw(age)
		"compressor_co2": return _compressor_co2(age)
		"chiller": return _chiller(age)
		"receiver": return _receiver(age)
		"glycol_pump": return _glycol_pump(age)
		"glycol_tank": return _glycol_tank(age)
		"header": return _header(age)
		"pipe_glycol": return _pipe_glycol(age, 0)
		"pipe_glycol_elbow": return _pipe_glycol(age, 1)
		"pipe_glycol_valve": return _pipe_glycol(age, 2)
		"pipe_refrig": return _pipe_refrig(age, 0)
		"pipe_refrig_elbow": return _pipe_refrig(age, 1)
		"pipe_refrig_valve": return _pipe_refrig(age, 2)
		"condenser": return _condenser(age)
		"control_panel": return _control_panel(age)
		"ammonia_detector": return _ammonia_detector(age)
		"eyewash_station": return _eyewash_station(age)
	return null


# ---------------------------------------------------------------- helpers

## A cylinder along X: n voxels from x, round in the YZ plane about (cy, cz).
static func _cyl_x(m: VoxelModel, x: int, n: int, cy: float, cz: float, r: float, c: Color) -> void:
	for y in range(floori(cy - r), ceili(cy + r)):
		for z in range(floori(cz - r), ceili(cz + r)):
			var dy := y + 0.5 - cy
			var dz := z + 0.5 - cz
			if dy * dy + dz * dz <= r * r:
				m.box(x, y, z, n, 1, 1, c)


## A vertical cylinder: n voxels up from y, round about (cx, cz).
static func _cyl_y(m: VoxelModel, cx: float, cz: float, y: int, n: int, r: float, c: Color) -> void:
	for x in range(floori(cx - r), ceili(cx + r)):
		for z in range(floori(cz - r), ceili(cz + r)):
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			if dx * dx + dz * dz <= r * r:
				m.box(x, y, z, 1, n, 1, c)


## A cylinder along Z, round about (cx, cy).
static func _cyl_z(m: VoxelModel, cx: float, cy: float, z: int, n: int, r: float, c: Color) -> void:
	for x in range(floori(cx - r), ceili(cx + r)):
		for y in range(floori(cy - r), ceili(cy + r)):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				m.box(x, y, z, 1, 1, n, c)


## A motor along X with axial cooling fins, end bells and a fan cowl with a
## grille on its +X end.
static func _motor_x(m: VoxelModel, x: int, n: int, cy: float, cz: float, r: float, c: Color) -> void:
	var fin := c.darkened(0.22)
	for xi in range(x + 1, x + n - 1):
		for y in range(floori(cy - r), ceili(cy + r)):
			for z in range(floori(cz - r), ceili(cz + r)):
				var dy := y + 0.5 - cy
				var dz := z + 0.5 - cz
				var d2 := dy * dy + dz * dz
				if d2 <= r * r:
					var outer := d2 > (r - 1.0) * (r - 1.0)
					m.set_voxel(xi, y, z, fin if outer and posmod(y + z, 2) == 0 else c)
	_cyl_x(m, x, 1, cy, cz, r - 0.6, c.darkened(0.12))
	_cyl_x(m, x + n - 1, 1, cy, cz, r - 0.6, c.darkened(0.12))
	_cyl_x(m, x + n, 2, cy, cz, r - 0.4, c.darkened(0.3))  # fan cowl
	for y in range(floori(cy - r), ceili(cy + r)):
		for z in range(floori(cz - r), ceili(cz + r)):
			if m.voxels.has(Vector3i(x + n + 1, y, z)) and posmod(y + z, 2) == 0:
				m.set_voxel(x + n + 1, y, z, Wear.RUBBER)


## A round dial gauge, 3x3 voxels on the plane z, read from the front, with a
## thin off-grid needle at `angle` (radians, 0 = straight up).
static func _gauge(m: VoxelModel, x: int, y: int, z: int, face: Color, bezel: Color, angle := 0.6) -> void:
	for i in 3:
		for j in 3:
			m.set_voxel(x + i, y + j, z, bezel if i != 1 and j != 1 else face)
	m.set_voxel(x + 1, y + 1, z, face)
	var dir := Vector3(-sin(angle), cos(angle), 0.0)
	m.add_oriented(Vector3(x + 1.5, y + 1.5, z - 0.08) + dir * 0.55, Basis(Vector3(0, 0, 1), angle),
		Vector3(0.22, 1.1, 0.14), Wear.RUBBER)


## A square panel meter, w x h on the plane z, with a needle.
static func _meter(m: VoxelModel, x: int, y: int, z: int, w: int, h: int, face: Color, bezel: Color, angle := 0.4) -> void:
	m.box(x, y, z, w, h, 1, bezel)
	m.box(x + 1, y + 1, z, w - 2, h - 1, 1, face)
	var pivot := Vector3(x + w * 0.5, y + 1.2, z - 0.08)
	var dir := Vector3(-sin(angle), cos(angle), 0.0)
	m.add_oriented(pivot + dir * (h - 2) * 0.5, Basis(Vector3(0, 0, 1), angle), Vector3(0.2, h - 1.6, 0.12), Wear.RUBBER)


## A valve handwheel lying flat on a stem: stem at (cx, y, cz), wheel at y + 1.
static func _handwheel(m: VoxelModel, cx: int, y: int, cz: int, c: Color, stem := Wear.OLD_STEEL) -> void:
	m.set_voxel(cx, y, cz, stem)
	for i in range(-1, 2):
		for k in range(-1, 2):
			m.set_voxel(cx + i, y + 1, cz + k, c if i != 0 or k != 0 else stem)


static func _surface(m: VoxelModel, p: Vector3i) -> bool:
	for d in VoxelModel.DIRS:
		if not m.voxels.has(p + d):
			return true
	return false


## Recolours the surface voxels of a region in a checker (perforated guards,
## louvres, grilles).
static func _perforate(m: VoxelModel, x: int, y: int, z: int, sx: int, sy: int, sz: int, c: Color) -> void:
	for i in sx:
		for j in sy:
			for k in sz:
				var p := Vector3i(x + i, y + j, z + k)
				if m.voxels.has(p) and posmod(p.x + p.y + p.z, 2) == 0 and _surface(m, p):
					m.voxels[p] = c


## Paints the surface of a region with `c`, keeping about `keep` of the old
## colour in speckles (frost on a suction line, scale on a casing).
static func _coat(m: VoxelModel, x: int, y: int, z: int, sx: int, sy: int, sz: int, c: Color, keep := 0.2, seed := 0) -> void:
	for i in sx:
		for j in sy:
			for k in sz:
				var p := Vector3i(x + i, y + j, z + k)
				if m.voxels.has(p) and _surface(m, p) and _roll(p, seed) >= keep:
					m.voxels[p] = c


static func _roll(p: Vector3i, seed: int) -> float:
	return float(posmod(hash([p, seed, 41]), 10000)) / 10000.0


## Insulation straps: rings of `c` round a cylinder along X every `step`.
static func _bands_x(m: VoxelModel, x0: int, x1: int, step: int, c: Color) -> void:
	for p in m.voxels.keys():
		var q: Vector3i = p
		if q.x >= x0 and q.x < x1 and posmod(q.x - x0, step) == step / 2 and _surface(m, q):
			m.voxels[q] = c


# ---------------------------------------------------------------- compressors

## The Nordale RC-4 (docs/world/RINK_SIM.md 3.1): an open-drive V-4 ammonia
## reciprocating compressor package, 2.4 x 1.0 x 1.4 m. Along X from the
## viewer's right: the suction strainer and stop valve on the crankcase end,
## the crankcase with its inspection cover, oil filter and oil sight glass
## (filled to half), two banks of two cylinders leaning out in a V, each with
## a bare valve plate under a bolted head, the discharge manifold in the
## valley and its stop valve; then the shaft seal (with its drip tray), the
## coupling guard with the gauge board above it (suction, discharge, oil),
## and the 75 hp motor, all on a steel skid.
static func _compressor_recip(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var paint := Wear.NAVY if new else OLD_PLANT
	var dark := paint.darkened(0.25)
	var skid := Wear.CHARCOAL if new else OLD_PLANT_DARK.darkened(0.25)
	var pipe := Wear.STEEL.darkened(0.2) if new else OLD_PIPE
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var head := Wear.STEEL.darkened(0.1) if new else HEAD_IRON
	var motor := Wear.CHARCOAL.lightened(0.12) if new else OLD_MOTOR
	var guard := OLD_PLANT.lightened(0.08) if worn else SAFETY_YELLOW
	var length := 37
	var depth := 15
	# skid: a steel base with lifting lugs
	m.box(0, 0, 0, length, 2, depth, skid)
	m.box(0, 0, 0, length, 1, 1, skid.darkened(0.2))  # channel lip
	for x in [0, length - 1]:
		m.set_voxel(x, 2, 0, skid).set_voxel(x, 2, depth - 1, skid)
	# crankcase
	m.box(2, 2, 3, 15, 9, 10, paint)
	m.clear_box(2, 10, 3, 15, 1, 1)
	m.clear_box(2, 10, 12, 15, 1, 1)
	m.box(5, 4, 2, 7, 5, 1, dark)  # inspection cover
	for p in [Vector2i(5, 4), Vector2i(11, 4), Vector2i(5, 8), Vector2i(11, 8)]:
		m.set_voxel(p.x, p.y, 1, bare)  # cover bolts
	# oil sight glass, filled to half: the level the oil service aims for
	var oil := OIL if new else (OIL_DARK if worn else OIL.darkened(0.25))
	m.box(13, 3, 2, 3, 4, 1, bare)
	m.set_voxel(14, 4, 1, oil)
	m.set_voxel(14, 5, 1, Wear.GLASS_DARK)
	m.box(13, 3, 1, 3, 1, 1, bare)
	m.box(13, 6, 1, 3, 1, 1, bare)
	# oil filter canister and crankcase drain
	_cyl_y(m, 3.5, 1.5, 3, 6, 1.3, Wear.WHITE if new else Wear.OLD_ORANGE.darkened(0.15))
	m.box(3, 9, 1, 1, 1, 1, bare)
	m.set_voxel(12, 2, 2, bare).set_voxel(12, 2, 1, Wear.RED)
	# two banks of two cylinders, leaning out in a V
	for bank in 2:
		for cx in [3, 11]:
			for y in range(11, 17):
				var s := (y - 11) >> 1
				m.box(cx, y, 3 - s if bank == 0 else 8 + s, 5, 1, 4, paint)
			var hz := 0 if bank == 0 else 11
			var hot: bool = worn and bank == 0 and cx == 11  # the head that runs hot
			m.box(cx, 17, hz, 5, 1, 4, Wear.RUST if hot else bare)  # valve plate
			m.box(cx, 18, hz, 5, 3, 4, Color("7b5b45") if hot else head)
			m.box(cx, 19, hz, 5, 1, 4, (Color("7b5b45") if hot else head).darkened(0.15))  # fin
			for b in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 3), Vector2i(4, 3), Vector2i(2, 0), Vector2i(2, 3)]:
				m.set_voxel(cx + b.x, 21, hz + b.y, bare)  # head bolts
			# outlet into the discharge manifold in the valley
			m.box(cx + 2, 19, 4 if bank == 0 else 9, 1, 1, 2, pipe)
	if age == Wear.REPAIRED:
		m.box(11, 18, 0, 5, 3, 4, Wear.STEEL.darkened(0.25))  # the head from the valve job
		m.box(12, 16, -1, 2, 2, 1, Wear.PAPER)  # its tag
	if not new:
		# water-jacket line along the front heads
		m.box(3, 15, 0, 13, 1, 1, COPPER)
		for cx in [3, 11]:
			m.set_voxel(cx + 1, 16, 0, COPPER)
	# discharge manifold, out the back with its stop valve
	m.box(1, 19, 6, 16, 2, 3, pipe)
	m.box(0, 19, 6, 2, 2, 9, pipe)
	m.box(0, 18, 11, 3, 4, 2, bare)
	_handwheel(m, 1, 22, 11, WHEEL, bare)
	# suction: in from the back, through the stop valve and strainer into the
	# crankcase end. Frosted on the old plant; insulated on the new one.
	var suction := INSUL_NEW if new else pipe
	m.box(0, 7, 6, 2, 2, 9, suction)
	m.box(0, 5, 3, 2, 6, 4, suction if new else bare)  # strainer housing
	m.box(0, 6, 9, 3, 4, 2, suction if new else bare)  # stop valve
	_handwheel(m, 1, 10, 10, WHEEL, bare)
	if not new:
		_coat(m, 0, 5, 3, 2, 6, 12, FROST, 0.25, 7)
		_coat(m, 0, 6, 9, 3, 4, 2, FROST, 0.5, 8)
	else:
		m.box(0, 7, 13, 2, 2, 1, SAFETY_YELLOW)  # ammonia pipe label
		m.box(0, 19, 13, 2, 2, 1, SAFETY_YELLOW)
	# shaft seal on the crankcase end, under the coupling guard
	m.box(17, 4, 5, 1, 5, 5, dark)
	m.box(17, 6, 7, 5, 2, 2, bare)  # shaft
	m.box(18, 2, 4, 4, 10, 8, guard)
	m.clear_box(18, 11, 4, 4, 1, 1)
	m.clear_box(18, 11, 11, 4, 1, 1)
	_perforate(m, 18, 2, 4, 4, 10, 8, guard.darkened(0.35))
	# drip tray under the seal
	if not new:
		m.box(15, 2, 0, 6, 1, 4, bare.darkened(0.2))
		m.box(16, 2, 1, 4, 1, 2, OIL_STAIN if worn else bare.darkened(0.45))
		if worn:
			for p in [Vector2i(14, 1), Vector2i(21, 2), Vector2i(22, 1), Vector2i(17, 0), Vector2i(23, 3)]:
				m.set_voxel(p.x, 1, p.y, OIL_STAIN)  # oil down the skid
	# gauge board over the guard: suction, discharge, oil
	var board := Wear.CHARCOAL if new else OLD_PLANT_DARK
	m.box(17, 12, 4, 13, 6, 1, board)
	m.box(29, 2, 4, 1, 10, 1, board)  # its leg
	var face := Wear.WHITE if new else Wear.OLD_CREAM.darkened(0.1)
	var faces := [face, face, face]
	if age == Wear.REPAIRED:
		faces[1] = Wear.WHITE  # a new discharge gauge
	var angles := [-0.2, 1.1, 0.5] if not worn else [-0.6, 1.5, 0.15]
	for i in 3:
		_gauge(m, 18 + i * 4, 13, 3, faces[i], bare, angles[i])
	m.box(16, 11, 5, 1, 5, 1, COPPER)  # gauge lines
	if new:
		m.box(18, 16, 3, 11, 1, 1, Wear.CHARCOAL.lightened(0.2))
		m.set_voxel(28, 16, 3, LAMP_GREEN)
	# the motor
	_motor_x(m, 22, 13, 7.5, 7.5, 4.6, motor)
	m.box(23, 2, 3, 3, 1, 9, motor.darkened(0.3))  # feet
	m.box(31, 2, 3, 3, 1, 9, motor.darkened(0.3))
	m.box(30, 10, 3, 4, 3, 3, motor.darkened(0.08))  # terminal box
	m.box(31, 12, 6, 2, 1, 9, Wear.OLD_STEEL if not new else Wear.STEEL)  # conduit
	m.box(26, 7, 2, 2, 1, 1, BRASS if not new else Wear.WHITE)  # nameplate
	if new:
		m.box(23, 11, 7, 10, 1, 1, Wear.TEAL)  # premium-efficiency band
	if worn:
		Wear.rust(m, skid, 0.15, 41)
		Wear.rust(m, pipe, 0.2, 42)
		Wear.rust(m, bare, 0.15, 43)
		Wear.rust(m, guard, 0.12, 44)
		Wear.rust(m, paint, 0.03, 45)
	return m.set_pivot(length * 0.5, 0, depth * 0.5)


## A screw compressor package, the first upgrade: about 3.0 x 1.3 x 1.9 m.
## The long oil separator vessel is the base; on it sit the screw compressor
## (its twin-rotor housing, slide valve actuator and suction stop valve and
## strainer stacked on top), the coupling guard and the motor. An oil cooler
## hangs off the end, oil filters and level glasses on the front, and a
## control panel on legs with its screen. Worn and repaired: a second-hand
## 1990s package with a small LCD; renovated: new, with a colour touchscreen.
static func _compressor_screw(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var paint := Wear.CHARCOAL.lightened(0.15) if new else SCREW_BLUE
	var vessel := Wear.STEEL.darkened(0.1) if new else SCREW_BLUE.darkened(0.15)
	var skid := Wear.CHARCOAL if new else OLD_PIPE
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var motor := Wear.NAVY if new else OLD_MOTOR
	var length := 46
	var depth := 20
	m.box(0, 0, 0, length, 2, depth, skid)
	m.box(0, 0, 0, length, 1, 1, skid.darkened(0.2))
	# oil separator vessel with dished ends on saddles
	for x in [6, 29]:
		m.box(x, 2, 8, 3, 2, 9, skid)
	_cyl_x(m, 3, 31, 8.5, 12.5, 5.6, vessel)
	_cyl_x(m, 2, 1, 8.5, 12.5, 4.4, vessel.darkened(0.08))
	_cyl_x(m, 34, 1, 8.5, 12.5, 4.4, vessel.darkened(0.08))
	_bands_x(m, 4, 34, 10, vessel.darkened(0.2))  # weld seams
	# oil level glasses and oil filters on the front
	for y in [6, 10]:
		m.box(26, y, 6, 3, 2, 1, bare)
		m.set_voxel(27, y, 6, OIL if y == 6 else Wear.GLASS_DARK)
	for x in [9.5, 13.5]:
		_cyl_y(m, x, 4.5, 2, 6, 1.4, Wear.WHITE if new else Wear.OLD_ORANGE.darkened(0.1))
		m.box(int(x) - 1, 8, 4, 2, 1, 3, bare)
	# oil cooler: a plate heat exchanger on the end
	m.box(36, 2, 12, 6, 10, 5, bare)
	for x in range(37, 41, 2):
		m.box(x, 3, 11, 1, 8, 1, bare.darkened(0.3))
	m.box(36, 6, 14, 2, 2, 6, Wear.OLD_STEEL.darkened(0.1))  # cooling water to the back
	# the screw compressor: twin-rotor housing on the separator
	_cyl_x(m, 6, 12, 17.5, 10.5, 3.6, paint)
	_cyl_x(m, 6, 12, 17.5, 15.0, 3.2, paint)
	m.box(6, 13, 9, 12, 2, 8, paint.darkened(0.1))  # discharge into the separator
	_cyl_x(m, 2, 4, 17.5, 12.5, 2.3, bare)  # slide valve actuator
	m.box(1, 16, 12, 1, 3, 1, bare)
	# suction strainer, check and stop valve stacked on the inlet
	var suction := INSUL_NEW if new else bare
	m.box(9, 21, 10, 4, 3, 4, suction)
	m.box(10, 24, 11, 2, 4, 2, suction)
	m.box(9, 27, 10, 4, 1, 4, bare)  # flange
	_handwheel(m, 13, 25, 12, WHEEL, bare)
	m.box(13, 24, 12, 1, 1, 1, bare)
	if not new:
		_coat(m, 9, 21, 10, 4, 7, 4, FROST, 0.35, 11)
	else:
		m.box(10, 25, 10, 2, 1, 1, SAFETY_YELLOW)
	# coupling guard and motor
	m.box(18, 13, 9, 4, 9, 8, SAFETY_YELLOW)
	_perforate(m, 18, 13, 9, 4, 9, 8, SAFETY_YELLOW.darkened(0.35))
	m.box(23, 13, 9, 11, 1, 8, skid)  # motor stool
	_motor_x(m, 22, 13, 19.5, 12.5, 5.2, motor)
	m.box(27, 23, 9, 4, 2, 4, motor.darkened(0.1))  # terminal box
	# discharge out of the separator to the condenser, with its stop valve
	m.box(30, 14, 16, 2, 10, 2, bare)
	m.box(29, 22, 15, 4, 3, 4, bare.darkened(0.1))
	_handwheel(m, 31, 25, 17, WHEEL, bare)
	# the control panel on legs at the front
	var cab := Wear.CHARCOAL if new else Color("c9c3ae")
	m.box(35, 2, 4, 1, 12, 1, skid)
	m.box(44, 2, 4, 1, 12, 1, skid)
	m.box(34, 14, 2, 12, 13, 3, cab)
	m.box(34, 14, 1, 12, 1, 1, cab.darkened(0.2))
	if new:
		m.box(36, 18, 1, 8, 6, 1, SCREEN_DARK)  # touchscreen
		m.box(36, 23, 0, 8, 1, 1, Wear.TEAL)
		for p in [Vector2i(37, 21), Vector2i(38, 21), Vector2i(40, 21), Vector2i(41, 20), Vector2i(42, 19), Vector2i(37, 19)]:
			m.set_voxel(p.x, p.y, 0, SCREEN)
		m.set_voxel(43, 21, 0, LAMP_GREEN)
		m.box(39, 15, 1, 2, 2, 1, SAFETY_YELLOW)  # e-stop
		m.set_voxel(39, 16, 0, Wear.RED).set_voxel(40, 16, 0, Wear.RED)
	else:
		m.box(37, 21, 1, 6, 3, 1, Wear.CHARCOAL)  # LCD window
		m.box(38, 22, 0, 4, 1, 1, LCD)
		for x in range(37, 43, 2):
			for y in [17, 19]:
				m.set_voxel(x, y, 1, Wear.OLD_CREAM)  # keypad
		m.set_voxel(43, 17, 1, LAMP_RED).set_voxel(43, 19, 1, LAMP_GREEN)
		m.box(36, 13, 3, 1, 2, 1, Wear.OLD_STEEL)
	if worn:
		m.box(38, 15, 0, 3, 2, 1, Wear.PAPER)  # "HOLD RESET 5 SEC"
		Wear.rust(m, skid, 0.2, 51)
		Wear.rust(m, bare, 0.1, 52)
		for p in [Vector2i(10, 3), Vector2i(11, 2), Vector2i(14, 3), Vector2i(20, 4)]:
			m.set_voxel(p.x, 1, p.y, OIL_STAIN)
	return m.set_pivot(length * 0.5, 0, depth * 0.5)


## A CO2 (R-744) transcritical rack, the high-end upgrade: about 2.6 x 1.0 x
## 1.9 m, an open steel frame so the parts show. Three semi-hermetic
## compressors on the base rails, the suction header behind them and the
## heavy-wall discharge header above, each joint a welded collar; on the
## shelf the insulated flash tank, an oil separator, and the control panel
## with its screen; high-pressure relief valves on top. Bright yellow and
## orange labels everywhere, because CO2 at 120 bar demands them.
static func _compressor_co2(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var frame := Wear.WHITE.darkened(0.05) if new else Color("b7b9b3")
	var body := CO2_BODY if new else CO2_BODY.darkened(0.1)
	var steel := Wear.STEEL.lightened(0.15)
	var collar := Wear.STEEL.darkened(0.2)
	var length := 40
	var depth := 15
	# frame: corner posts, base rails, a shelf and a top
	for x in [0, length - 1]:
		for z in [0, depth - 1]:
			m.box(x, 0, z, 1, 30, 1, frame)
	for y in [0, 14, 29]:
		m.box(0, y, 0, length, 1, 1, frame)
		m.box(0, y, depth - 1, length, 1, 1, frame)
		m.box(0, y, 0, 1, 1, depth, frame)
		m.box(length - 1, y, 0, 1, 1, depth, frame)
	m.box(1, 0, 3, length - 2, 1, 2, frame)
	m.box(1, 0, 10, length - 2, 1, 2, frame)
	m.box(1, 14, 3, length - 2, 1, 9, frame.darkened(0.15))  # shelf
	# three semi-hermetic compressors: motor barrel and head block
	for i in 3:
		var cx := 3 + i * 12
		_cyl_x(m, cx, 6, 6.0, 7.5, 3.2, body)
		_cyl_x(m, cx - 1, 1, 6.0, 7.5, 2.6, body.darkened(0.2))  # motor end cover
		m.box(cx + 6, 2, 4, 4, 8, 7, body.darkened(0.1))  # compressor block
		m.box(cx + 6, 10, 4, 4, 1, 3, steel)  # valve plates
		m.box(cx + 6, 10, 8, 4, 1, 3, steel)
		m.box(cx + 6, 11, 4, 4, 2, 3, body.darkened(0.25))  # heads
		m.box(cx + 6, 11, 8, 4, 2, 3, body.darkened(0.25))
		m.box(cx + 1, 1, 5, 4, 1, 5, Wear.RUBBER)  # isolation feet
		m.box(cx + 2, 4, 3, 2, 3, 1, SAFETY_YELLOW)  # data label
		m.box(cx + 7, 13, 5, 2, 1, 1, collar)  # discharge riser collar
		m.box(cx + 7, 13, 5, 1, 5, 1, steel)  # discharge riser to the header
		m.box(cx + 2, 9, 11, 2, 3, 2, steel)  # suction drop from the header
	# suction header behind (insulated) and heavy-wall discharge header above
	m.box(1, 11, 11, length - 2, 2, 2, INSUL_NEW if new else INSUL_OLD)
	for x in range(3, length - 3, 6):
		m.box(x, 11, 10, 1, 2, 1, SAFETY_YELLOW)  # labels
	m.box(1, 17, 4, length - 2, 2, 2, steel)
	for x in range(2, length - 2, 7):
		m.box(x, 16, 3, 2, 4, 4, collar)
	for x in range(5, length - 4, 7):
		m.box(x, 17, 3, 2, 2, 1, SAFETY_ORANGE)  # high-pressure labels
		m.set_voxel(x, 18, 2, Wear.RUBBER)  # flow arrow
	# shelf: insulated flash tank, oil separator, control panel
	_cyl_x(m, 2, 20, 21.5, 10.0, 3.6, INSUL_NEW if new else INSUL_OLD)
	_cyl_x(m, 1, 1, 21.5, 10.0, 3.0, steel)
	_cyl_x(m, 22, 1, 21.5, 10.0, 3.0, steel)
	_bands_x(m, 3, 22, 6, Wear.STEEL)
	m.box(8, 20, 6, 6, 3, 1, SAFETY_YELLOW)  # "R-744 FLASH TANK"
	m.box(9, 21, 5, 4, 1, 1, Wear.RUBBER)
	_cyl_y(m, 27.0, 11.0, 15, 11, 2.4, steel)  # oil separator
	m.box(26, 26, 10, 2, 1, 2, collar)
	var cab := Wear.CHARCOAL if new else Color("8c8f94")
	m.box(29, 15, 1, 10, 13, 3, cab)
	m.box(30, 20, 0, 6, 5, 1, SCREEN_DARK)
	if new or age == Wear.REPAIRED:
		for p in [Vector2i(31, 23), Vector2i(32, 23), Vector2i(33, 22), Vector2i(34, 21), Vector2i(31, 21)]:
			m.set_voxel(p.x, p.y, 0, SCREEN)
		m.box(30, 24, 0, 6, 1, 1, Wear.TEAL)
	m.box(37, 22, 0, 1, 3, 1, Wear.RUBBER)
	m.set_voxel(37, 24, -1, LAMP_GREEN)
	m.set_voxel(37, 22, -1, LAMP_AMBER if worn else Wear.RUBBER)
	m.box(30, 16, 0, 8, 2, 1, SAFETY_YELLOW)  # warning placard
	for x in range(31, 37, 2):
		m.set_voxel(x, 17, -1, Wear.RUBBER)
	# relief valves on top, vented up through the roof
	for x in [6, 14]:
		m.box(x, 25, 9, 2, 5, 2, steel)
		m.box(x, 30, 9, 2, 2, 2, Wear.RED)
		m.box(x, 32, 9, 2, 3, 2, steel)
	m.box(6, 34, 9, 10, 1, 2, steel)
	# gauges on the discharge header
	_gauge(m, 20, 20, 3, Wear.WHITE, steel, 1.2)
	m.box(21, 19, 4, 1, 1, 1, steel)
	if worn:
		m.box(17, 17, 2, 3, 2, 1, Wear.DUCT_TAPE)  # a label taped back on
		Wear.rust(m, frame, 0.05, 61)
		m.box(1, 1, 1, 1, 13, 1, frame.darkened(0.3))  # scuffed post
	return m.set_pivot(length * 0.5, 0, depth * 0.5)


# ---------------------------------------------------------------- vessels

## The shell-and-tube chiller (flooded): ammonia boils in the insulated
## shell and cools the glycol in the tubes. 3.2 m long, 0.9 m shell. Bolted
## tube-sheet heads at each end; the glycol nozzles rise from the right-hand
## head with dial thermometers; the surge drum rides on top with its float
## chamber and the frosted suction outlet; the oil pot hangs underneath with
## its red drain valve (drained weekly, RINK_SIM 3.1).
static func _chiller(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var jacket := ALU_JACKET if new else INSUL_OLD
	var heads := Wear.NAVY if new else OLD_PLANT
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var saddle := Wear.CHARCOAL if new else OLD_PLANT_DARK
	var length := 49
	for x in [8, 37]:
		m.box(x, 0, 1, 4, 5, 13, saddle)
	_cyl_x(m, 3, 43, 10.5, 7.5, 7.1, jacket)
	_bands_x(m, 3, 46, 7, jacket.darkened(0.18))
	# tube-sheet flanges and bolted heads
	for x in [2, 46]:
		_cyl_x(m, x, 1, 10.5, 7.5, 7.3, bare)
	_cyl_x(m, 0, 2, 10.5, 7.5, 6.2, heads)
	_cyl_x(m, 47, 2, 10.5, 7.5, 6.2, heads)
	for p in m.voxels.keys():
		var q: Vector3i = p
		if (q.x == 2 or q.x == 46) and _surface(m, q) and posmod(q.y + q.z, 3) == 0:
			m.voxels[q] = Wear.RUBBER  # flange bolts
	m.box(48, 15, 7, 1, 2, 1, bare)  # lifting lug
	# glycol supply and return nozzles off the right-hand head
	var gpipe := INSUL_NEW if new else bare
	for z in [3, 10]:
		m.box(0, 14, z, 2, 9, 2, gpipe)
		m.box(0, 22, z - 1, 2, 1, 4, bare)  # flange
		_gauge(m, 2, 18, z, Wear.WHITE if new else Wear.OLD_CREAM, bare, 0.9 if z == 3 else 0.6)
	if new:
		m.box(0, 16, 2, 2, 1, 1, Wear.NAVY)
		m.box(0, 16, 12, 2, 1, 1, Wear.TEAL)
	# surge drum with its standpipes, suction outlet and float chamber
	for x in [17, 30]:
		m.box(x, 17, 6, 2, 4, 3, bare)
	_cyl_x(m, 14, 22, 23.5, 7.5, 3.6, jacket)
	_cyl_x(m, 13, 1, 23.5, 7.5, 2.8, bare)
	_cyl_x(m, 36, 1, 23.5, 7.5, 2.8, bare)
	m.box(23, 27, 6, 3, 4, 3, INSUL_NEW if new else OLD_PIPE)  # suction to the compressors
	m.box(22, 31, 5, 5, 1, 5, bare)
	m.box(38, 19, 6, 3, 9, 3, bare)  # float chamber
	m.box(37, 20, 7, 1, 1, 1, bare)
	m.box(37, 25, 7, 1, 1, 1, bare)
	m.box(39, 13, 7, 1, 6, 1, bare)  # liquid feed with the hand expansion valve
	_handwheel(m, 41, 15, 7, WHEEL, bare)
	m.box(40, 15, 7, 1, 1, 1, bare)
	m.box(26, 20, 3, 2, 4, 1, Wear.GLASS_DARK)  # level glass on the drum
	m.box(26, 22, 3, 2, 2, 1, Wear.GLASS)
	# oil pot under the shell, with its drain valve
	_cyl_y(m, 23.5, 7.5, 1, 3, 1.9, bare.darkened(0.15))
	m.box(23, 0, 3, 1, 1, 3, bare)
	m.set_voxel(23, 0, 2, Wear.RED).set_voxel(22, 0, 2, Wear.RED)
	if not new:
		_coat(m, 23, 27, 6, 3, 4, 3, FROST, 0.3, 21)
		_coat(m, 37, 19, 6, 4, 9, 3, FROST, 0.6, 22)
	if worn:
		# water stains, a split in the canvas showing the rusty shell
		_coat(m, 4, 3, 0, 40, 4, 15, WATER_STAIN, 0.7, 23)
		_coat(m, 26, 8, 0, 6, 5, 2, Wear.RUST, 0.3, 24)
		Wear.rust(m, bare, 0.15, 25)
		Wear.rust(m, saddle, 0.2, 26)
	elif age == Wear.REPAIRED:
		_coat(m, 25, 6, 0, 8, 9, 3, INSUL_NEW, 0.0, 27)  # new insulation patch
		m.box(25, 4, 0, 1, 13, 1, Wear.DUCT_TAPE)
		m.box(32, 4, 0, 1, 13, 1, Wear.DUCT_TAPE)
	else:
		m.box(16, 10, -1, 6, 3, 1, SAFETY_YELLOW)  # ammonia label
		m.box(17, 11, -2, 3, 1, 1, Wear.RUBBER)
	return m.set_pivot(length * 0.5, 0, 7.5)


## The high-pressure receiver: a 2.4 m horizontal ammonia vessel on saddles.
## On the front its gauge glass between two shut-off valves shows the liquid
## level; on top the king valve, a pressure gauge, and the dual relief valve
## manifold (two valves on a three-way changeover, red caps, the five-year
## date tag) venting up through the roof. A brass pressure-vessel nameplate.
static func _receiver(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var shell := Wear.WHITE if new else OLD_PLANT
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var saddle := Wear.CHARCOAL if new else OLD_PLANT_DARK
	for x in [6, 28]:
		m.box(x, 0, 1, 3, 6, 8, saddle)
	_cyl_x(m, 2, 33, 9.5, 5.0, 4.8, shell)
	_cyl_x(m, 1, 1, 9.5, 5.0, 4.0, shell.darkened(0.08))
	_cyl_x(m, 35, 1, 9.5, 5.0, 4.0, shell.darkened(0.08))
	_cyl_x(m, 0, 1, 9.5, 5.0, 2.6, shell.darkened(0.12))
	_cyl_x(m, 36, 1, 9.5, 5.0, 2.6, shell.darkened(0.12))
	# gauge glass on the front, with valves top and bottom and guard rods
	m.box(18, 6, -1, 1, 1, 1, bare)
	m.box(18, 13, -1, 1, 1, 1, bare)
	m.box(17, 5, -2, 3, 1, 1, bare)
	m.box(17, 14, -2, 3, 1, 1, bare)
	m.set_voxel(20, 5, -2, WHEEL).set_voxel(20, 14, -2, WHEEL)
	var level := 9 if not worn else 7  # a low charge shows here first
	for y in range(6, 14):
		m.set_voxel(18, y, -2, Wear.GLASS_DARK if y < level else Wear.GLASS)
	m.box(17, 6, -2, 1, 8, 1, bare.darkened(0.2))
	m.box(19, 6, -2, 1, 8, 1, bare.darkened(0.2))
	# king valve and inlet from the condenser
	m.box(9, 14, 4, 2, 3, 2, bare)
	_handwheel(m, 10, 17, 5, WHEEL, bare)
	m.box(3, 14, 4, 2, 6, 2, bare)  # condensate inlet
	m.box(2, 19, 3, 4, 1, 4, bare)
	# pressure gauge on a stem
	m.box(14, 14, 3, 1, 3, 1, bare)
	_gauge(m, 13, 16, 2, Wear.WHITE if new else Wear.OLD_CREAM, bare, 1.0)
	# dual relief valves on a three-way changeover, vented up
	m.box(25, 14, 3, 5, 2, 4, bare)
	for x in [25, 28]:
		m.box(x, 16, 4, 2, 3, 2, BRASS)
		m.box(x, 19, 4, 2, 1, 2, Wear.RED)
	m.box(27, 16, 3, 1, 1, 1, WHEEL)  # changeover handle
	m.box(25, 20, 4, 5, 1, 2, bare)
	m.box(27, 21, 4, 2, 4, 2, bare)  # vent to the roof
	m.box(26, 24, 3, 4, 1, 4, bare)
	m.box(29, 18, 3, 1, 1, 1, Wear.PAPER if age != Wear.WORN else Wear.OLD_CREAM.darkened(0.3))  # date tag
	m.box(25, 8, -1, 3, 2, 1, BRASS)  # nameplate
	if new:
		m.box(4, 8, -1, 8, 3, 1, SAFETY_YELLOW)  # ammonia label
		m.box(5, 9, -2, 6, 1, 1, Wear.RUBBER)
	if worn:
		Wear.rust(m, bare, 0.15, 31)
		Wear.rust(m, saddle, 0.25, 32)
		Wear.rust(m, shell, 0.03, 33)
	return m.set_pivot(18.5, 0, 4.5)


# ---------------------------------------------------------------- glycol loop

## The glycol pump: a 15 kW end-suction pump on its base. From the viewer's
## right: the suction nozzle and flange with its gauge, the volute with the
## discharge rising off the top (and its gauge), the seal chamber (drips and
## dried glycol when worn), the bearing housing with its oiler, the coupling
## guard and the motor. 1.9 x 0.6 m.
static func _glycol_pump(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var paint := Wear.NAVY if new else OLD_PLANT
	var base := Wear.CHARCOAL if new else OLD_PLANT_DARK.darkened(0.2)
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var motor := Wear.CHARCOAL.lightened(0.12) if new else OLD_MOTOR
	var guard := OLD_PLANT.lightened(0.05) if worn else SAFETY_YELLOW
	m.box(0, 0, 0, 30, 2, 10, base)
	m.box(0, 0, 0, 30, 1, 1, base.darkened(0.2))
	# suction nozzle and flange
	_cyl_x(m, 0, 1, 8.5, 5.0, 3.2, bare)
	_cyl_x(m, 1, 3, 8.5, 5.0, 2.2, paint)
	m.box(2, 11, 5, 1, 1, 1, bare)
	_gauge(m, 1, 12, 4, Wear.WHITE if new else Wear.OLD_CREAM, bare, -0.5)
	m.box(1, 12, 5, 3, 3, 1, bare)
	# volute and discharge
	_cyl_x(m, 4, 4, 8.5, 5.0, 4.8, paint)
	m.box(4, 2, 2, 4, 3, 6, paint.darkened(0.15))  # pump foot
	m.box(4, 12, 1, 4, 4, 4, paint)
	m.box(3, 16, 0, 6, 1, 6, bare)  # discharge flange
	_gauge(m, 4, 13, 0, Wear.WHITE if new else Wear.OLD_CREAM, bare, 1.0)
	# seal chamber and bearing housing
	_cyl_x(m, 8, 1, 8.5, 5.0, 2.2, bare)
	_cyl_x(m, 9, 5, 8.5, 5.0, 2.7, paint.darkened(0.08))
	m.box(10, 2, 3, 3, 4, 4, paint.darkened(0.15))
	m.box(11, 11, 4, 1, 1, 1, bare)  # vent
	m.box(12, 7, 1, 1, 2, 1, Wear.GLASS)  # constant-level oiler
	m.set_voxel(12, 9, 1, bare).set_voxel(12, 6, 2, bare)
	m.set_voxel(12, 7, 1, OIL if not worn else OIL_DARK)
	# coupling guard and motor
	m.box(14, 2, 1, 4, 11, 8, guard)
	_perforate(m, 14, 2, 1, 4, 11, 8, guard.darkened(0.35))
	_motor_x(m, 18, 10, 8.5, 5.0, 4.3, motor)
	m.box(19, 2, 2, 3, 2, 6, motor.darkened(0.3))
	m.box(25, 2, 2, 3, 2, 6, motor.darkened(0.3))
	m.box(22, 12, 2, 3, 2, 3, motor.darkened(0.08))  # terminal box
	if worn:
		# the seal weeps: dried glycol on the chamber, a green puddle under it
		for p in [Vector3i(8, 6, 3), Vector3i(8, 7, 2), Vector3i(8, 6, 6), Vector3i(8, 10, 3)]:
			m.set_voxel(p.x, p.y, p.z, GLYCOL_CRUST)
		m.box(7, 2, 0, 4, 1, 3, GLYCOL.darkened(0.3))
		m.set_voxel(9, 2, 0, GLYCOL)
		Wear.rust(m, base, 0.25, 71)
		Wear.rust(m, guard, 0.15, 72)
		Wear.rust(m, bare, 0.1, 73)
	elif age == Wear.REPAIRED:
		m.box(9, 5, 1, 1, 1, 1, Wear.PAPER)  # seal date tag
	return m.set_pivot(15, 0, 5)


## The glycol expansion and fill tank: a 0.6 m vertical drum on legs with a
## sight tube up the front (worn: low), a fill cap on top and the makeup
## water line with its valve on the side. The repaired tank's valve is
## tagged NO WATER (RINK_SIM 4.4).
static func _glycol_tank(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var shell := Wear.WHITE if new else OLD_PLANT
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	for x in [1, 8]:
		for z in [1, 8]:
			m.box(x, 0, z, 1, 5, 1, bare.darkened(0.2))
	_cyl_y(m, 5.0, 5.0, 5, 17, 4.8, shell)
	_cyl_y(m, 5.0, 5.0, 22, 1, 3.8, shell.darkened(0.06))
	_cyl_y(m, 5.0, 5.0, 23, 1, 1.4, bare)
	m.box(4, 24, 4, 2, 1, 2, Wear.RED if new else Wear.OLD_GOLD)  # fill cap
	for y in [8, 19]:
		_bands_x_y(m, y, shell.darkened(0.15))
	# sight tube up the front with a scale beside it
	m.box(5, 6, -1, 1, 1, 1, bare)
	m.box(5, 20, -1, 1, 1, 1, bare)
	var level := 10 if worn else (14 if age == Wear.REPAIRED else 15)
	for y in range(7, 20):
		m.set_voxel(5, y, -1, GLYCOL if y < level else Wear.GLASS)
	for y in range(7, 20, 2):
		m.set_voxel(4, y, 0, Wear.RUBBER)
	# bottom outlet to the loop
	m.box(4, 3, 4, 2, 2, 2, bare)
	m.box(4, 3, 6, 2, 2, 5, bare)
	# makeup water line, copper, with its valve on the side
	m.box(10, 15, 4, 4, 1, 1, COPPER)
	m.box(13, 15, 5, 1, 1, 5, COPPER)
	m.box(12, 14, 3, 1, 3, 3, BRASS)
	m.box(11, 17, 4, 3, 1, 1, Wear.RED if not new else Wear.NAVY)  # lever
	if age == Wear.REPAIRED:
		m.box(12, 12, 2, 2, 2, 1, Wear.PAPER)  # NO WATER tag
		m.set_voxel(12, 13, 1, Wear.RED)
	if new:
		m.box(1, 12, -1, 3, 3, 1, Wear.CHARCOAL)  # level transmitter
		m.set_voxel(2, 13, -2, LAMP_GREEN)
		m.box(6, 16, -1, 3, 2, 1, Wear.TEAL)  # GLYCOL label
	if worn:
		for p in [Vector3i(4, 24, 3), Vector3i(6, 23, 4), Vector3i(3, 22, 6), Vector3i(6, 21, 0), Vector3i(6, 20, 0)]:
			m.set_voxel(p.x, p.y, p.z, GLYCOL_CRUST)
		Wear.rust(m, bare, 0.25, 81)
		Wear.rust(m, shell, 0.04, 82)
	return m.set_pivot(5, 0, 5)


## Horizontal band round the tank at height y.
static func _bands_x_y(m: VoxelModel, y: int, c: Color) -> void:
	for p in m.voxels.keys():
		var q: Vector3i = p
		if q.y == y and _surface(m, q):
			m.voxels[q] = c


## One 1.04 m module of the supply and return headers, to repeat along X.
## It sits on the floor of the header trench (HEADER_TRENCH deep): the two
## insulated headers (supply in front, return behind) on pipe stands, a valve
## stub on each, and the jumper hoses rising to the floor pipes that come out
## of the trench's back (+Z) wall just under the slab. Eight circuits per
## module, alternating supply and return. Worn: perished grey hoses, rusty
## clamps, a glycol weep and a puddle; repaired: some new black hoses and a
## weld patch; renovated: jacketed headers with colour bands and new hoses.
static func _header(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var jacket := INSUL_NEW if new else INSUL_OLD
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	var hose_old := Color("5d6158")
	var n := HEADER_LEN
	for x in [2, 13]:
		m.box(x, 0, 1, 1, 2, 15, bare.darkened(0.25))  # pipe stands
	_cyl_x(m, 0, n, 5.0, 4.5, 3.2, jacket)
	_cyl_x(m, 0, n, 5.0, 11.5, 3.2, jacket)
	_bands_x(m, 0, n, 8, jacket.darkened(0.18))
	if new:
		m.box(4, 3, 1, 2, 4, 1, Wear.NAVY)  # supply
		m.box(10, 3, 1, 2, 4, 1, Wear.NAVY)
		m.box(0, 8, 11, n, 1, 1, Wear.TEAL)  # return stripe on top
	for i in 8:
		var x := 1 + i * 2
		var supply := i % 2 == 0
		var z := 4 if supply else 11
		m.box(x, 8, z, 1, 1, 1, bare)  # nipple
		m.set_voxel(x, 9, z, BRASS)  # balancing valve
		m.set_voxel(x, 9, z - 1, WHEEL if supply else Wear.NAVY.lightened(0.2))  # lever
		var hose := Wear.RUBBER if new else hose_old
		if age == Wear.REPAIRED and (i == 2 or i == 5):
			hose = Wear.RUBBER
		m.box(x, 10, z, 1, 1, 18 - z, hose)
		m.set_voxel(x, 10, 17, bare)  # clamp
		m.box(x, 10, 18, 1, 1, 1, bare.darkened(0.3))  # floor pipe end
	m.box(7, 8, 8, 1, 1, 1, BRASS)  # air bleeder
	if worn:
		_coat(m, 4, 2, 0, 5, 4, 3, Color("b7a37a"), 0.4, 91)  # glycol weep stain
		m.box(3, 0, 0, 8, 1, 4, GLYCOL.darkened(0.35))  # puddle on the trench floor
		for x in [3, 7, 9]:
			m.set_voxel(x, 10, 17, Wear.RUST)
		Wear.rust(m, bare, 0.3, 92)
	elif age == Wear.REPAIRED:
		m.box(11, 3, 1, 1, 5, 1, Wear.DUCT_TAPE)
	return m.set_pivot(n * 0.5, 0, 9)


# ---------------------------------------------------------------- pipe pieces

## Insulated glycol pipe, 0.26 m over the jacket. kind 0 straight, 1 elbow,
## 2 valve (a butterfly valve with a gear operator and handwheel). Each runs
## PIPE_LEN along X with its centreline 0.13 m above the pivot; the elbow
## joins the -X end to the front (-Z), so its corner is at the pivot.
static func _pipe_glycol(age: int, kind: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var jacket := INSUL_NEW if new else INSUL_OLD
	var band := jacket.darkened(0.18)
	var n := PIPE_LEN
	if kind == 1:
		_cyl_x(m, 0, 10, 2.0, 2.0, 2.05, jacket)
		_cyl_z(m, 8.0, 2.0, -6, 10, 2.05, jacket)
		for y in 4:
			m.voxels.erase(Vector3i(9, y, 3))  # round the outside of the bend
		_cyl_x(m, 5, 1, 2.0, 2.0, 2.05, band)
		_cyl_z(m, 8.0, 2.0, -1, 1, 2.05, band)
		m.voxels.erase(Vector3i(9, 0, 3))
	else:
		_cyl_x(m, 0, n, 2.0, 2.0, 2.05, jacket)
		for x in [0, 7, n - 1]:
			_cyl_x(m, x, 1, 2.0, 2.0, 2.05, band)
	if kind == 2:
		var body := Wear.NAVY if new else OLD_PLANT
		var bare := Wear.STEEL if new else Wear.OLD_STEEL
		_cyl_x(m, 7, 2, 2.0, 2.0, 2.9, bare)  # wafer body between flanges
		m.box(7, 4, 1, 2, 3, 2, body)  # neck
		m.box(6, 7, 0, 4, 2, 4, body)  # gear operator
		m.box(10, 7, 1, 1, 1, 1, bare)
		for y in range(6, 11):
			for z in range(-1, 4):
				var ring := (y == 6 or y == 10 or z == -1 or z == 3) and not ((y == 6 or y == 10) and (z == -1 or z == 3))
				if ring:
					m.set_voxel(11, y, z, WHEEL)  # handwheel on the side
	if new:
		var lx := 11 if kind != 1 else 1
		m.box(lx, 4, 1, 2, 1, 2, Wear.TEAL)  # GLYCOL label and flow arrow
		m.set_voxel(lx + 2, 4, 1, Wear.TEAL)
	elif worn:
		# a torn jacket over the rusty pipe, water stains underneath
		if kind != 2:
			m.box(3, 1, 0, 2, 2, 1, Wear.RUST)
		_coat(m, 0, 0, -6, n, 1, 10, WATER_STAIN, 0.6, 101 + kind)
	else:
		_cyl_x(m, 2 if kind != 1 else 1, 2, 2.0, 2.0, 2.05, Wear.DUCT_TAPE)  # taped-up tear
	return m.set_pivot(8, 0, 2)


## Bare refrigerant pipe (ammonia liquid and hot gas), 0.13 m, with welded
## collars at the ends. Same kinds and layout as _pipe_glycol: centreline
## 0.13 m above the pivot, the elbow joining -X to the front. The valve is a
## globe stop valve with a bonnet and handwheel. Renovated: grey with yellow
## ammonia labels and flow arrows.
static func _pipe_refrig(age: int, kind: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var pipe := Wear.STEEL.darkened(0.15) if new else OLD_PIPE
	var collar := Wear.STEEL.darkened(0.35) if new else Wear.OLD_STEEL.darkened(0.25)
	var n := PIPE_LEN
	if kind == 1:
		m.box(0, 1, 1, 9, 2, 2, pipe)
		m.box(7, 1, -6, 2, 2, 7, pipe)
		m.box(0, 0, 0, 1, 4, 4, collar)
		m.box(6, 0, -6, 4, 4, 1, collar)
		m.voxels.erase(Vector3i(8, 1, 2))
		m.voxels.erase(Vector3i(8, 2, 2))
		m.box(7, 1, 1, 1, 2, 1, collar)  # weld at the bend
	else:
		m.box(0, 1, 1, n, 2, 2, pipe)
		m.box(0, 0, 0, 1, 4, 4, collar)
		m.box(n - 1, 0, 0, 1, 4, 4, collar)
	if kind == 2:
		var body := Wear.CHARCOAL if new else OLD_PLANT
		m.box(6, 0, 0, 4, 4, 4, body)  # globe body
		m.box(7, 4, 1, 2, 2, 2, body.darkened(0.15))  # bonnet
		m.box(7, 6, 1, 2, 2, 2, Wear.STEEL if new else Wear.OLD_STEEL)  # packing gland
		for i in range(-1, 3):
			for k in range(-1, 3):
				if i == -1 or i == 2 or k == -1 or k == 2:
					m.set_voxel(7 + i, 8, 1 + k, WHEEL)
		m.box(7, 8, 1, 2, 1, 2, Wear.OLD_STEEL)
	if new:
		var x0 := 11 if kind != 1 else 2
		m.box(x0, 1, 0, 3, 2, 1, SAFETY_YELLOW)  # ammonia label
		m.box(x0, 3, 1, 3, 1, 2, SAFETY_YELLOW)
		m.set_voxel(x0, 2, -1, Wear.RUBBER)  # flow arrow
	elif worn:
		Wear.rust(m, pipe, 0.3, 111 + kind)
		Wear.rust(m, collar, 0.4, 114 + kind)
	return m.set_pivot(8, 0, 2)


# ---------------------------------------------------------------- roof

## The evaporative condenser on the roof (the 1974 Boreal Aire): a
## galvanised box 3.0 x 1.6 x 3.0 m on two roof beams. The water basin at
## the bottom, louvred air inlets above it, the casing with seams and an
## access door, and on top the round fan shroud with its fan and guard. The
## fan motor sits on the top deck beside the shroud with the belt guard
## running to the fan (RINK_SIM 4.6). The spray pump stands on the side with
## its riser; refrigerant connections come out the other side. Worn: white
## scale streaking the louvres, a rusting basin.
static func _condenser(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var galv := GALV.lightened(0.1) if new else GALV
	var dark := Color("3a3e42")
	var beam := Wear.CHARCOAL if new else OLD_PIPE
	var w := 46
	var d := 24
	m.box(0, 0, 1, w, 2, 2, beam)
	m.box(0, 0, d - 3, w, 2, 2, beam)
	# basin
	m.box(0, 2, 0, w, 5, d, galv.darkened(0.08))
	m.box(0, 6, 0, w, 1, d, galv.darkened(0.15))
	# casing
	m.box(0, 7, 0, w, 32, d, galv)
	# louvred air inlets on the front and both ends
	for y in range(7, 17):
		var slat := (y - 7) % 3 == 0
		if slat:
			m.box(1, y, -1, w - 2, 1, 1, galv.darkened(0.05))
			m.box(-1, y, 1, 1, 1, d - 2, galv.darkened(0.05))
			m.box(w, y, 1, 1, 1, d - 2, galv.darkened(0.05))
		else:
			m.box(1, y, 0, w - 2, 1, 1, dark)
			m.box(0, y, 1, 1, 1, d - 2, dark)
			m.box(w - 1, y, 1, 1, 1, d - 2, dark)
	m.box(0, 17, 0, w, 1, d, galv.darkened(0.1))  # ledge over the louvres
	# panel seams and the access door
	for x in [11, 23, 34]:
		m.box(x, 18, 0, 1, 21, 1, galv.darkened(0.12))
	m.box(25, 20, -1, 8, 14, 1, galv.darkened(0.04))
	m.box(25, 20, -1, 8, 1, 1, galv.darkened(0.2))
	m.box(31, 27, -2, 1, 2, 1, Wear.RUBBER)  # handle
	m.box(25, 22, -2, 1, 2, 1, galv.darkened(0.3))  # hinges
	m.box(25, 31, -2, 1, 2, 1, galv.darkened(0.3))
	# top deck and the fan shroud
	m.box(0, 39, 0, w, 1, d, galv.darkened(0.1))
	_cyl_y(m, 21.0, 12.0, 40, 6, 10.6, galv.darkened(0.05))
	_cyl_y(m, 21.0, 12.0, 40, 6, 9.6, dark)
	for p in m.voxels.keys():
		var q: Vector3i = p
		if q.y >= 41 and q.y <= 45:
			var dx := q.x + 0.5 - 21.0
			var dz := q.z + 0.5 - 12.0
			if dx * dx + dz * dz <= 9.6 * 9.6:
				m.voxels.erase(q)
	_cyl_y(m, 21.0, 12.0, 40, 1, 9.6, dark)  # the throat floor
	_cyl_y(m, 21.0, 12.0, 41, 2, 1.6, Wear.CHARCOAL)  # fan hub
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		m.add_oriented(Vector3(21.0, 42.0, 12.0) + dir * 5.0, Basis(Vector3.UP, -a) * Basis(Vector3(1, 0, 0), 0.35),
			Vector3(7.6, 0.3, 2.2), Wear.CHARCOAL.lightened(0.15))
	# fan guard: a grid across the top of the shroud
	for x in range(11, 32):
		for z in range(2, 23):
			var dx := x + 0.5 - 21.0
			var dz := z + 0.5 - 12.0
			if dx * dx + dz * dz <= 9.8 * 9.8 and (x % 4 == 1 or z % 4 == 0):
				m.set_voxel(x, 45, z, Wear.OLD_STEEL if not new else Wear.STEEL)
	# fan motor on the deck and the belt guard to the fan shaft
	var guard := Wear.STEEL if new else (SAFETY_YELLOW if age == Wear.REPAIRED else Wear.OLD_GOLD)
	var motor := Wear.NAVY if new else OLD_MOTOR
	_cyl_z(m, 38.5, 43.5, 2, 6, 2.6, motor)
	m.box(36, 40, 2, 6, 1, 6, motor.darkened(0.3))
	m.box(37, 46, 4, 3, 1, 2, motor.darkened(0.1))
	m.box(28, 41, 8, 11, 4, 3, guard)  # belt guard, motor pulley to fan
	m.box(21, 43, 9, 7, 2, 1, guard)
	_perforate(m, 28, 41, 8, 11, 4, 3, guard.darkened(0.3))
	# spray pump on the -X end and its riser to the spray header
	var bare := Wear.STEEL if new else Wear.OLD_STEEL
	m.box(-4, 2, 14, 4, 5, 5, Wear.NAVY if new else OLD_PLANT)
	_cyl_x(m, -7, 3, 4.5, 16.5, 2.0, motor)
	m.box(-3, 7, 15, 2, 27, 2, bare)
	m.box(-3, 32, 15, 3, 2, 2, bare)
	# refrigerant in (hot gas, top) and out (liquid, bottom) on the same end
	m.box(-3, 34, 8, 3, 2, 2, OLD_PIPE if not new else Wear.STEEL.darkened(0.15))
	m.box(-3, 20, 8, 3, 2, 2, OLD_PIPE if not new else Wear.STEEL.darkened(0.15))
	m.box(-4, 33, 7, 1, 4, 4, bare)
	m.box(-4, 19, 7, 1, 4, 4, bare)
	if new:
		m.box(-3, 34, 7, 2, 2, 1, SAFETY_YELLOW)
		m.box(-3, 20, 7, 2, 2, 1, SAFETY_YELLOW)
	if worn:
		# scale streaks down from the louvres and casing seams, a rusty basin
		for x in range(1, w - 1):
			var streak := int(_roll(Vector3i(x, 0, 0), 121) * 9.0)
			for y in range(16 - streak, 17):
				if m.voxels.has(Vector3i(x, y, -1)):
					m.voxels[Vector3i(x, y, -1)] = SCALE
			if streak > 5:
				m.box(x, 2, 0, 1, streak - 3, 1, SCALE)
		_coat(m, 0, 2, 0, w, 5, d, Wear.RUST, 0.75, 122)
		_coat(m, 0, 18, 0, w, 6, 1, SCALE, 0.8, 123)
		Wear.rust(m, beam, 0.3, 124)
		Wear.rust(m, guard, 0.2, 125)
	elif age == Wear.REPAIRED:
		m.box(4, 2, -1, 9, 3, 1, galv.lightened(0.15))  # basin patch
	return m.set_pivot(w * 0.5, 0, d * 0.5)


# ---------------------------------------------------------------- controls and safety

## The plant control panel and motor starters: a 1.2 x 0.5 x 2.0 m
## two-door floor cabinet. Worn: grey 1970s steel with analog ammeters for
## both compressors, pilot lamps, selector switches, start and stop buttons,
## the clock setback timer and the glycol return thermometer, with Gus's
## notes taped on. Repaired adds a retrofit digital temperature controller.
## Renovated: a charcoal PLC cabinet with a touchscreen, e-stop and a stack
## light on top.
static func _control_panel(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var cab := Wear.CHARCOAL.lightened(0.08) if new else OLD_PANEL
	var w := 19
	var d := 8
	m.box(0, 0, 0, w, 2, d, Wear.RUBBER if new else OLD_PANEL.darkened(0.45))
	m.box(0, 2, 0, w, 28, d, cab)
	m.box(0, 30, 0, w, 1, d, cab.darkened(0.15))
	m.box(9, 2, 0, 1, 28, 1, cab.darkened(0.3))  # door seam
	m.set_voxel(8, 15, -1, Wear.OLD_STEEL).set_voxel(10, 15, -1, Wear.OLD_STEEL)  # handles
	m.set_voxel(8, 14, -1, Wear.OLD_STEEL).set_voxel(10, 14, -1, Wear.OLD_STEEL)
	for y in range(3, 7, 2):
		m.box(2, y, 0, 5, 1, 1, cab.darkened(0.35))  # vents
		m.box(12, y, 0, 5, 1, 1, cab.darkened(0.35))
	if new:
		m.box(4, 13, 0, 11, 13, 1, Wear.CHARCOAL)  # HMI bezel
		m.box(5, 14, -1, 9, 11, 1, SCREEN_DARK)
		m.box(5, 24, -1, 9, 1, 1, Wear.TEAL)  # title bar
		var tiles := [LAMP_GREEN, LAMP_GREEN, SCREEN, SCREEN, LAMP_AMBER, SCREEN]
		for i in tiles.size():
			m.box(12 - (i % 3) * 3, 20 - (i / 3) * 4, -1, 2, 2, 1, tiles[i])
		m.box(6, 15, -1, 7, 1, 1, SCREEN.darkened(0.3))  # trend line
		m.box(12, 9, -1, 2, 2, 1, SAFETY_YELLOW)  # e-stop
		m.box(12, 9, -2, 2, 2, 1, Wear.RED)
		m.box(5, 9, -1, 2, 2, 1, Wear.STEEL)  # key switch
		m.box(16, 31, 3, 2, 1, 2, Wear.CHARCOAL)  # stack light
		m.box(16, 32, 3, 2, 1, 2, LAMP_GREEN)
		m.box(16, 33, 3, 2, 1, 2, LAMP_AMBER)
		m.box(16, 34, 3, 2, 1, 2, Wear.RED)
		m.box(3, 27, -1, 13, 1, 1, Wear.WHITE)  # label strip
		return m.set_pivot(w * 0.5, 0, d * 0.5)
	var face := Wear.OLD_CREAM
	var bezel := Wear.CHARCOAL
	# right-hand door (+X): ammeters, lamps, selectors and buttons per compressor
	for i in 2:
		var x := 11 + i * 4
		_meter(m, x, 22, -1, 4, 4, face, bezel, -0.2 + i * 0.5 if not worn else (0.9 if i == 0 else -0.1))
		m.set_voxel(x + 1, 19, -1, LAMP_GREEN if not (worn and i == 0) else LAMP_RED)
		m.set_voxel(x + 2, 19, -1, LAMP_RED.darkened(0.5))
		m.box(x + 1, 16, -1, 2, 2, 1, Wear.RUBBER)  # selector switch
		m.set_voxel(x + 2, 17, -2, Wear.WHITE)
		m.set_voxel(x + 1, 13, -1, LAMP_GREEN.darkened(0.2))  # start
		m.set_voxel(x + 2, 13, -1, Wear.RED)  # stop
		m.box(x, 11, -1, 4, 1, 1, Wear.PAPER)  # engraved label
	# left-hand door: the setback clock, the glycol thermometer, notes
	_gauge(m, 3, 22, -1, face, bezel, 2.4)
	m.box(3, 21, -1, 3, 1, 1, Wear.PAPER)
	_meter(m, 3, 15, -1, 4, 5, Wear.WHITE.darkened(0.08), bezel, 0.3)
	m.box(1, 9, -1, 4, 5, 1, Wear.PAPER)  # Gus's notes
	m.box(5, 10, -1, 3, 3, 1, Color("f3e27a"))
	m.set_voxel(2, 13, -2, Wear.RED)
	if age == Wear.REPAIRED:
		m.box(2, 9, -1, 6, 4, 1, Wear.CHARCOAL)  # retrofit digital controller
		m.box(3, 11, -2, 4, 1, 1, LAMP_RED)
		m.set_voxel(6, 10, -2, LAMP_GREEN)
	if worn:
		m.box(13, 25, -2, 2, 1, 1, Wear.DUCT_TAPE)  # a cracked meter glass taped
		Wear.rust(m, cab, 0.02, 131)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## The fixed ammonia detector, a wall prop: its pivot is the bottom centre of
## the backplate on the wall plane (mount it about 2 m up: ammonia rises).
## A sensor box with a display, a strobe and horn on top, and an NFPA hazard
## diamond above. Worn: a dusty 1990s unit with a dead display and a CAL
## OVERDUE note; repaired: calibrated, a green sticker, the display on;
## renovated: a new unit with a green display and a red and amber beacon.
static func _ammonia_detector(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var plate := Wear.CHARCOAL if new else Wear.OLD_STEEL
	var box := SAFETY_YELLOW if new else Color("cbbf9e")
	m.box(0, 0, 3, 7, 12, 1, plate)
	m.box(1, 2, 1, 5, 6, 2, box)
	m.box(2, 0, 2, 3, 2, 1, Wear.CHARCOAL)  # sensor head
	m.set_voxel(3, 0, 1, Wear.RUBBER)
	m.box(2, 5, 0, 3, 2, 1, SCREEN_DARK)  # display
	if not worn:
		m.box(2, 5, 0, 3, 1, 1, LAMP_GREEN)  # reading 0 ppm
		m.set_voxel(3, 6, 0, LAMP_GREEN)
	m.set_voxel(5, 3, 0, LAMP_GREEN)  # power lamp
	m.box(1, 3, 0, 2, 1, 1, box.darkened(0.25))  # keys
	# strobe and horn
	m.box(1, 9, 2, 5, 1, 1, plate.darkened(0.2))
	m.box(1, 10, 1, 2, 2, 2, Wear.RED if not new else LAMP_AMBER)
	m.box(4, 10, 1, 2, 2, 2, Wear.CHARCOAL if not new else Wear.RED)
	m.set_voxel(4, 11, 0, Wear.RUBBER)
	# conduit up the wall, hazard diamond above
	m.box(3, 12, 3, 1, 10, 1, Wear.OLD_STEEL)
	# NFPA 704 diamond: health blue (left), fire red (top), instability
	# yellow (right), special white (bottom), black dividers
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var s := absi(dx) + absi(dy)
			if s > 3:
				continue
			var c := Wear.WHITE
			if s == 3 or (absi(dx) == absi(dy) and s > 0):
				c = Wear.RUBBER
			elif dy > absi(dx):
				c = Wear.RED
			elif dx > absi(dy):
				c = Color("2f5bb7")
			elif -dx > absi(dy):
				c = SAFETY_YELLOW
			m.set_voxel(3 + dx, 15 + dy, 2, c)
	if worn:
		m.box(1, 4, 0, 3, 2, 1, Wear.PAPER)  # CAL OVERDUE
		m.set_voxel(2, 5, -1, Wear.RED)
	elif age == Wear.REPAIRED:
		m.set_voxel(5, 7, 0, LAMP_GREEN.darkened(0.2))  # calibration sticker
	return m.set_pivot(3.5, 0, 4)


## A plumbed emergency shower and eyewash station, the floor-standing kind:
## a pipe pedestal on its foot, the eyewash bowl with its push flag at waist
## height, the shower head overhead with its pull rod, and the green sign.
## Worn: old galvanised pipe with chipped yellow paint, a rusty bowl and no
## test tag; repaired: repainted with a weekly test tag; renovated: a new
## ANSI-yellow station.
static func _eyewash_station(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var worn := age == Wear.WORN
	var pipe := SAFETY_YELLOW if not worn else SAFETY_YELLOW.darkened(0.15)
	var bowl := SAFETY_YELLOW if new else Wear.OLD_STEEL
	m.box(3, 0, 3, 4, 1, 4, Wear.OLD_STEEL.darkened(0.2))  # foot
	m.box(4, 1, 4, 2, 31, 2, pipe)  # pedestal
	# shower arm and head
	m.box(4, 30, -3, 2, 1, 7, pipe)
	_cyl_y(m, 5.0, -4.0, 28, 2, 2.6, pipe)
	m.box(3, 28, -5, 4, 1, 2, pipe.darkened(0.2))
	m.box(6, 19, -4, 1, 9, 1, Wear.OLD_STEEL)  # pull rod
	m.box(5, 18, -4, 3, 1, 1, Wear.OLD_STEEL)
	# eyewash arm, bowl and push flag
	m.box(4, 14, 0, 2, 1, 4, pipe)
	m.box(2, 14, -5, 6, 1, 5, bowl)
	m.box(2, 15, -5, 6, 1, 1, bowl)
	m.box(2, 15, -1, 6, 1, 1, bowl)
	m.box(2, 15, -5, 1, 1, 5, bowl)
	m.box(7, 15, -5, 1, 1, 5, bowl)
	m.set_voxel(4, 15, -3, Wear.STEEL).set_voxel(5, 15, -3, Wear.STEEL)  # nozzles
	m.box(3, 12, -6, 4, 3, 1, SAFETY_GREEN if not worn else SAFETY_YELLOW.darkened(0.1))  # push flag
	# sign
	m.box(2, 22, 3, 6, 5, 1, SAFETY_GREEN)
	m.box(4, 23, 2, 2, 3, 1, Wear.WHITE)
	m.box(3, 24, 2, 4, 1, 1, Wear.WHITE)
	if worn:
		Wear.rust(m, pipe, 0.25, 141)
		_coat(m, 4, 1, 4, 2, 31, 2, Wear.OLD_STEEL, 0.75, 142)  # paint chipped to galvanised
		Wear.rust(m, bowl, 0.3, 143)
	else:
		m.box(6, 12, 3, 2, 2, 1, Wear.PAPER)  # weekly test tag
	return m.set_pivot(5, 0, 5)
