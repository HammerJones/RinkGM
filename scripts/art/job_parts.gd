class_name JobParts
extends RefCounted
## The parts and tools the M1 mini games put in the player's hands
## (docs/world/RINK_SIM.md 4.2, 4.7 and the 4.8 plug slice): the compressor's
## drain plug, oil filter, sight glass, oil pan and the blue drum with its
## hand pump; the ratchet and the torque wrench; Doris's ice blade, blade
## bolts, conditioner and the feeler gauge; her spark plugs, the plug socket,
## the engine bay and the DORIS parts drawers; and the workbench they sit on.
##
## Built like the props (props.gd, plant_props.gd): one builder per id, front
## facing -Z, +X the viewer's left. They're close-up pieces, so each picks a
## voxel size fine enough to read in the hand (VOXEL below) rather than the
## 0.065 m prop grid. The bench-sized pieces (the drum, the engine bay, the
## conditioner, the drawers) stay coarse enough to cost little.
##
## Pivots:
##   fasteners (drain_plug, blade_bolt, spark_plug, oil_filter): on the axis at
##       the seat face, the head toward +Y; the thread runs into -Y. Turning is
##       a rotation about local Y, backing out a move along +Y.
##   tools (ratchet, torque_wrench, plug_socket): on the drive axis at the
##       bottom of the socket, the handle along +X.
##   pump_handle: its hinge; the lever along +X, a stroke turns it about Z.
##   everything else: on the floor (or the bench top), centred.
##
##   var mesh := JobParts.mesh("ratchet")      # cached, share it freely

const OLD_STEEL := Wear.OLD_STEEL
const BRIGHT := Color("d9dee2")        # a freshly ground edge, a new socket
const CHROME := Color("c3c9ce")
const BLACK_OXIDE := Color("2a2b2e")
const FILTER_ORANGE := Color("d8742e")
const FILTER_OLD := Color("8a5a34")
const DRUM_BLUE := Color("2f6fb0")
const ENGINE := Color("a2452c")        # Doris's industrial engine red, faded
const PORCELAIN := Color("efece2")
const COPPER := Color("b8733a")
const BRASS := Color("c6a24a")
const RED_GRIP := Color("c22a24")
const SOOT := Color("141210")
const OIL_DARK := Color("3a2210")
const OIL_STAIN := Color("1e1a16")
const DORIS_CREAM := Wear.OLD_CREAM
const DORIS_TRIM := Wear.OLD_STEEL
const CABINET := Color("6b7b6e")       # steel cabinet, machinery grey-green
const SHOES := Color("b08454")         # Gus's wooden blade-change stands

## Metres per voxel, per part.
const VOXEL := {
	"drain_plug": 0.004, "blade_bolt": 0.004, "spark_plug": 0.002, "spark_plug_fouled": 0.002,
	"oil_filter": 0.01, "oil_filter_old": 0.01, "sight_glass": 0.004, "oil_pan": 0.02,
	"oil_drum": 0.02, "hand_pump": 0.01, "pump_handle": 0.01,
	"ratchet": 0.004, "torque_wrench": 0.004, "plug_socket": 0.003, "feeler_gauge": 0.002,
	"blade": 0.01, "blade_old": 0.01, "blade_guard": 0.01, "conditioner": 0.02,
	"engine_bay": 0.02, "plug_boot": 0.004, "parts_drawer": 0.02, "drawer_tray": 0.02,
	"workbench": 0.05, "log_book": 0.01,
}

const IDS := [
	"drain_plug", "blade_bolt", "spark_plug", "spark_plug_fouled", "oil_filter", "oil_filter_old",
	"sight_glass", "oil_pan", "oil_drum", "hand_pump", "pump_handle", "ratchet", "torque_wrench",
	"plug_socket", "feeler_gauge", "blade", "blade_old", "blade_guard", "conditioner",
	"engine_bay", "plug_boot", "parts_drawer", "drawer_tray", "workbench", "log_book",
]

## Pieces with big flat faces: merged even at full detail.
const MERGED := ["oil_drum", "conditioner", "engine_bay", "parts_drawer", "workbench", "blade", "blade_old", "oil_pan"]

## The blade is this many voxels (1 cm) long: 77 in.
const BLADE_LEN := 196
## Along the blade and the conditioner (metres from the centre, +X the
## viewer's left): the 7 blade bolts and the 3 height screws.
const BOLT_X := [-0.84, -0.56, -0.28, 0.0, 0.28, 0.56, 0.84]
const SCREW_X := [-0.9, 0.0, 0.9]
## The conditioner's blade slot (metres from its pivot): where the blade's
## pivot sits when it's fitted, and the top of the bolt bosses.
const BLADE_SEAT := Vector3(0.0, 0.10, -0.14)
const BOLT_TOP := 0.2
## The engine bay's 4 plug wells (metres from its pivot; the well floor).
## Number 1 is at the fan end, on the viewer's left (+X).
const PLUG_WELLS := [Vector3(0.31, 0.42, -0.05), Vector3(0.11, 0.42, -0.05), Vector3(-0.09, 0.42, -0.05), Vector3(-0.29, 0.42, -0.05)]
## The parts cabinet's drawers, top first: the face centre of each (metres).
const DRAWER_COUNT := 6
const DRAWER_TOP := 1.08
const DRAWER_STEP := 0.18
## The drum's bung, where the hand pump stands (metres from the drum pivot).
const DRUM_BUNG := Vector3(0.14, 0.9, 0.0)
## The pump handle's hinge on the pump (metres from the pump pivot).
const PUMP_HINGE := Vector3(0.0, 0.43, 0.0)
## Where the pump's hose leaves its spout (metres from the pump pivot).
const PUMP_SPOUT := Vector3(-0.09, 0.36, 0.0)

static var _cache := {}


static func ids() -> Array:
	return IDS


static func voxel_size(id: String) -> float:
	return float(VOXEL.get(id, 0.01))


static func model(id: String) -> VoxelModel:
	var m: VoxelModel = null
	match id:
		"drain_plug": m = _bolt(0.004, 7, 3, 2.3, 5, COPPER, 4.6)
		"blade_bolt": m = _bolt(0.004, 6, 3, 1.6, 9, OLD_STEEL.darkened(0.2), 3.6)
		"spark_plug": m = _spark_plug(false)
		"spark_plug_fouled": m = _spark_plug(true)
		"oil_filter": m = _oil_filter(false)
		"oil_filter_old": m = _oil_filter(true)
		"sight_glass": m = _sight_glass()
		"oil_pan": m = _oil_pan()
		"oil_drum": m = _oil_drum()
		"hand_pump": m = _hand_pump()
		"pump_handle": m = _pump_handle()
		"ratchet": m = _wrench(false)
		"torque_wrench": m = _wrench(true)
		"plug_socket": m = _plug_socket()
		"feeler_gauge": m = _feeler_gauge()
		"blade": m = _blade(false)
		"blade_old": m = _blade(true)
		"blade_guard": m = _blade_guard()
		"conditioner": m = _conditioner()
		"engine_bay": m = _engine_bay()
		"plug_boot": m = _plug_boot()
		"parts_drawer": m = _parts_drawer()
		"drawer_tray": m = _drawer_tray()
		"workbench": m = _workbench()
		"log_book": m = _log_book()
	if m == null:
		push_error("JobParts: unknown part '%s'" % id)
	return m


## One mesh per (id, lod), built on first use. lod 1 merges flat faces.
static func mesh(id: String, lod := 0) -> ArrayMesh:
	var key := "%s/%d" % [id, lod]
	if not _cache.has(key):
		var m := model(id)
		if m == null:
			_cache[key] = null
		elif lod == 0 and not id in MERGED:
			_cache[key] = m.build_mesh()
		else:
			_cache[key] = m.build_mesh_merged()
	return _cache[key]


## Plant room's compressor with its service points opened up: the drain
## plug, oil filter and sight glass voxels are taken out so the job's own
## close-up parts sit in their places (COMP_* below, in the compressor's
## space, metres).
const COMP_DRAIN := Vector3(-0.39, 0.1625, -0.2925)
const COMP_FILTER := Vector3(-0.975, 0.585, -0.39)
const COMP_GLASS := Vector3(-0.26, 0.325, -0.372)


static func compressor_service(age := Wear.WORN) -> ArrayMesh:
	var key := "compressor_service/%d" % age
	if not _cache.has(key):
		var m := Props.model("compressor_recip", age)
		# the filter canister and its head
		for x in range(1, 7):
			for y in range(3, 10):
				for z in range(0, 3):
					var dx := x + 0.5 - 3.5
					var dz := z + 0.5 - 1.5
					if dx * dx + dz * dz <= 1.6 * 1.6 or y == 9:
						m.voxels.erase(Vector3i(x, y, z))
		# the drain valve and the sight glass's front ring
		m.voxels.erase(Vector3i(12, 2, 1))
		m.voxels.erase(Vector3i(12, 2, 2))
		m.clear_box(13, 3, 1, 3, 4, 1)
		m.box(13, 3, 2, 3, 4, 1, Wear.OLD_STEEL.darkened(0.2))
		m.box(3, 9, 2, 1, 1, 1, Wear.OLD_STEEL)  # the filter head's boss
		_cache[key] = m.build_mesh_merged()
	return _cache[key]


# ---------------------------------------------------------------- helpers

static func _disc_y(m: VoxelModel, cx: float, cz: float, y: int, n: int, r: float, c: Color, r_in := -1.0) -> void:
	for x in range(floori(cx - r), ceili(cx + r)):
		for z in range(floori(cz - r), ceili(cz + r)):
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			var d2 := dx * dx + dz * dz
			if d2 <= r * r and (r_in < 0.0 or d2 > r_in * r_in):
				m.box(x, y, z, 1, n, 1, c)


static func _disc_x(m: VoxelModel, x: int, n: int, cy: float, cz: float, r: float, c: Color) -> void:
	for y in range(floori(cy - r), ceili(cy + r)):
		for z in range(floori(cz - r), ceili(cz + r)):
			var dy := y + 0.5 - cy
			var dz := z + 0.5 - cz
			if dy * dy + dz * dz <= r * r:
				m.box(x, y, z, n, 1, 1, c)


static func _disc_z(m: VoxelModel, cx: float, cy: float, z: int, n: int, r: float, c: Color, r_in := -1.0) -> void:
	for x in range(floori(cx - r), ceili(cx + r)):
		for y in range(floori(cy - r), ceili(cy + r)):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var d2 := dx * dx + dy * dy
			if d2 <= r * r and (r_in < 0.0 or d2 > r_in * r_in):
				m.box(x, y, z, 1, 1, n, c)


## A hex, as a square with the corners clipped, `w` across flats.
static func _hex_y(m: VoxelModel, cx: float, cz: float, y: int, n: int, w: int, c: Color) -> void:
	var h := w * 0.5
	for x in range(floori(cx - h), ceili(cx + h)):
		for z in range(floori(cz - h), ceili(cz + h)):
			var dx := absf(x + 0.5 - cx)
			var dz := absf(z + 0.5 - cz)
			if dx + dz <= h * 1.35:
				m.box(x, y, z, 1, n, 1, c)


static func _roll(p: Vector3i, seed: int) -> float:
	return float(posmod(hash([p, seed, 17]), 10000)) / 10000.0


## Speckles surface voxels of colour `from` with `to`.
static func _speckle(m: VoxelModel, from: Color, to: Color, amount: float, seed: int) -> void:
	for k in m.voxels.keys():
		var p: Vector3i = k
		var c: Color = m.voxels[p]
		if c.is_equal_approx(from) and _roll(p, seed) < amount:
			m.voxels[p] = to


# ---------------------------------------------------------------- fasteners

## A hex-head bolt or plug: a washer of `washer` colour at y 0, the hex head
## above it, the thread below. Pivot on the axis at the washer's underside.
static func _bolt(v: float, hex: int, head_h: int, thread_r: float, thread_l: int, washer: Color, washer_r: float) -> VoxelModel:
	var m := VoxelModel.new(v)
	m.jitter = 0.03
	var c := hex * 0.5
	_disc_y(m, c, c, 0, 1, washer_r, washer)
	_hex_y(m, c, c, 1, head_h, hex, OLD_STEEL)
	_hex_y(m, c, c, head_h + 1, 1, hex - 1, OLD_STEEL.lightened(0.12))  # chamfer
	for y in range(-thread_l, 0):
		_disc_y(m, c, c, y, 1, thread_r, OLD_STEEL.darkened(0.12 if posmod(y, 2) == 0 else 0.3))
	return m.set_pivot(c, 0, c)


## A spark plug, standing on its seat: thread and electrodes below, the hex,
## the porcelain with its ribs and the terminal nut above. Fouled: the nose
## black and wet, the porcelain sooted.
static func _spark_plug(fouled: bool) -> VoxelModel:
	var m := VoxelModel.new(0.002)
	m.jitter = 0.03
	var c := 5.0
	var nose := SOOT if fouled else Color("b89a6a")  # a tan nose is a happy plug
	# electrodes and the thread's end
	m.box(4, -13, 4, 2, 2, 2, OLD_STEEL.darkened(0.2))         # centre electrode
	m.box(2, -13, 4, 1, 3, 2, OLD_STEEL.darkened(0.25))        # ground strap
	m.box(2, -14, 4, 4, 1, 2, OLD_STEEL.darkened(0.25))
	_disc_y(m, c, c, -11, 1, 2.0, nose)
	for y in range(-10, 0):
		_disc_y(m, c, c, y, 1, 3.4, (BRIGHT if posmod(y, 2) == 0 else OLD_STEEL) if not fouled else (OLD_STEEL.darkened(0.35 if posmod(y, 2) == 0 else 0.5)))
	_disc_y(m, c, c, 0, 1, 4.6, OLD_STEEL.darkened(0.1))       # crush washer
	_hex_y(m, c, c, 1, 6, 10, CHROME if not fouled else OLD_STEEL)
	var por := PORCELAIN if not fouled else PORCELAIN.darkened(0.25)
	for y in range(7, 25):
		var rib := y > 14 and posmod(y, 3) == 0
		_disc_y(m, c, c, y, 1, 3.4 if rib else 2.9, por)
	if fouled:
		for y in range(7, 10):
			_disc_y(m, c, c, y, 1, 3.0, SOOT.lightened(0.15))
	_disc_y(m, c, c, 25, 3, 1.5, OLD_STEEL)                    # terminal stud
	_disc_y(m, c, c, 28, 2, 2.2, OLD_STEEL.lightened(0.1))     # terminal nut
	if fouled:
		_speckle(m, PORCELAIN.darkened(0.25), SOOT, 0.2, 3)
	return m.set_pivot(c, 0, c)


## A spin-on oil filter, hanging from its seat: the base plate with the
## gasket ring at the top, the can below with its grip ribs and a label band.
static func _oil_filter(old: bool) -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.jitter = 0.03
	var c := 8.0
	var can := FILTER_OLD if old else FILTER_ORANGE
	_disc_y(m, c, c, -1, 1, 7.0, Wear.RUBBER, 5.6)             # the gasket
	_disc_y(m, c, c, -3, 2, 7.8, OLD_STEEL.darkened(0.15))     # base plate
	_disc_y(m, c, c, -1, 1, 2.0, OLD_STEEL.darkened(0.35))     # threaded centre
	for y in range(-33, -3):
		var col := can
		if y >= -17 and y <= -10:
			col = Wear.PAPER if not old else Wear.PAPER.darkened(0.35)  # label band
		if y == -14 and not old:
			col = Wear.NAVY
		_disc_y(m, c, c, y, 1, 8.0, col)
	for y in range(-33, -27):
		_disc_y(m, c, c, y, 1, 8.4, can.darkened(0.18))         # grip ribs, crossed
	_disc_y(m, c, c, -34, 1, 6.6, can.darkened(0.1))
	if old:
		_speckle(m, FILTER_OLD, OIL_STAIN, 0.25, 5)
		_speckle(m, Wear.PAPER.darkened(0.35), OIL_DARK, 0.3, 6)
	return m.set_pivot(c, 0, c)


# ---------------------------------------------------------------- the oil job

## The sight glass close-up: a square plate with four bolts and a round
## window. The window is open to the glass at the back so the scene can fill
## it to the oil level. Gus scratched a HALF mark on the plate in red paint.
## Pivot at the window's centre on the plate's front face.
static func _sight_glass() -> VoxelModel:
	var m := VoxelModel.new(0.004)
	m.jitter = 0.03
	m.box(0, 0, 0, 30, 30, 3, OLD_STEEL)
	_disc_z(m, 15.0, 15.0, -1, 1, 11.5, OLD_STEEL.lightened(0.1), 9.0)  # the ring
	for y in range(6, 24):
		for x in range(6, 24):
			var dx := x + 0.5 - 15.0
			var dy := y + 0.5 - 15.0
			if dx * dx + dy * dy <= 81.0:
				m.voxels.erase(Vector3i(x, y, 0))
				m.voxels.erase(Vector3i(x, y, 1))
				m.voxels[Vector3i(x, y, 2)] = Wear.GLASS_DARK.darkened(0.45)
	for p in [Vector2i(2, 2), Vector2i(26, 2), Vector2i(2, 26), Vector2i(26, 26)]:
		_hex_y_z(m, p.x, p.y)
	# the HALF mark, either side of the window
	m.box(1, 14, -1, 4, 2, 1, Wear.RED)
	m.box(25, 14, -1, 4, 2, 1, Wear.RED)
	_speckle(m, OLD_STEEL, Wear.RUST, 0.06, 9)
	return m.set_pivot(15, 15, 0)


static func _hex_y_z(m: VoxelModel, x: int, y: int) -> void:
	m.box(x, y, -2, 2, 2, 2, OLD_STEEL.lightened(0.15))


## A black plastic drain pan, 44 x 32 cm, its inside open so the scene can
## pour oil into it.
static func _oil_pan() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var pan := Color("23252a")
	m.box(0, 0, 0, 22, 1, 16, pan)
	m.box(0, 1, 0, 22, 3, 1, pan)
	m.box(0, 1, 15, 22, 3, 1, pan)
	m.box(0, 1, 0, 1, 3, 16, pan)
	m.box(21, 1, 0, 1, 3, 16, pan)
	m.box(1, 4, 0, 20, 1, 1, pan.lightened(0.08))  # rolled lip at the front
	m.box(8, 3, -1, 6, 1, 1, pan.lightened(0.08))  # pour spout
	m.box(2, 1, 2, 4, 1, 3, OIL_STAIN)             # last time's oil
	return m.set_pivot(11, 0, 8)


## The blue 205 L oil drum (Gus: "Oil's in the blue drum"), with rolling
## hoops, a white ISO 68 patch and the bung the hand pump stands in.
static func _oil_drum() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var c := 14.5
	for y in 44:
		var col := DRUM_BLUE
		if y in [0, 14, 15, 29, 30, 43]:
			col = DRUM_BLUE.darkened(0.25)
		_disc_y(m, c, c, y, 1, 14.5, col, 13.0)
	_disc_y(m, c, c, 0, 1, 13.0, DRUM_BLUE.darkened(0.3))
	_disc_y(m, c, c, 44, 1, 14.5, DRUM_BLUE.darkened(0.12))  # chime
	_disc_y(m, c, c, 43, 1, 13.0, DRUM_BLUE.darkened(0.05))  # lid
	m.box(9, 18, 0, 11, 8, 1, Wear.PAPER)  # the label patch
	m.box(10, 23, -1, 9, 1, 1, Wear.CHARCOAL)
	m.box(10, 21, -1, 6, 1, 1, Wear.CHARCOAL)
	m.box(10, 19, -1, 7, 1, 1, Color("d29a2c"))  # an oil-coloured stripe
	_disc_y(m, c + 7.0, c, 45, 1, 2.0, OLD_STEEL)  # bung
	_disc_y(m, c - 6.0, c - 3.0, 45, 1, 1.4, OLD_STEEL.darkened(0.2))  # vent
	for y in [6, 7, 36]:
		for x in [3, 4, 25]:
			m.set_voxel(x, y, 2, Wear.RUST)  # chipped paint at the hoops
	return m.set_pivot(c, 0, c)


## The hand pump barrel standing in the drum's bung: the barrel, its head,
## the spout to the hose. The handle is its own part (pump_handle).
static func _hand_pump() -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.jitter = 0.03
	var c := 3.0
	_disc_y(m, c, c, 0, 3, 3.0, OLD_STEEL.darkened(0.2))   # bung adaptor
	_disc_y(m, c, c, 3, 36, 2.2, Color("7d1f1a"))          # red barrel
	_disc_y(m, c, c, 39, 4, 3.0, OLD_STEEL)                # head
	m.box(c - 1, 43, c - 1, 2, 3, 2, OLD_STEEL.darkened(0.15))  # hinge lug
	m.box(-6, 35, 2, 7, 2, 2, OLD_STEEL.darkened(0.1))     # spout
	m.box(-7, 33, 2, 2, 3, 2, OLD_STEEL.darkened(0.1))
	return m.set_pivot(c, 0, c)


## The pump lever, hinged at its left end (+X out to the grip).
static func _pump_handle() -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.jitter = 0.03
	m.box(0, 0, 0, 34, 2, 2, OLD_STEEL.darkened(0.05))
	m.box(26, -1, -1, 10, 4, 4, Wear.RUBBER)
	m.box(-2, -1, 0, 3, 3, 2, OLD_STEEL.darkened(0.25))   # the hinge eye
	return m.set_pivot(0, 1, 1)


static func _log_book() -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.box(0, 0, 0, 22, 2, 30, Color("1e3b6a"))
	m.box(1, 2, 1, 20, 1, 28, Wear.PAPER)
	m.box(0, 2, 14, 22, 1, 1, Color("1e3b6a"))
	m.box(14, 3, 8, 1, 1, 12, Color("e0b33a"))  # the pencil on its string
	return m.set_pivot(11, 0, 15)


# ---------------------------------------------------------------- tools

## The long ratchet or the click-type torque wrench, lying flat: the socket
## pointing down at the pivot, the head above it and the handle along +X.
## The torque wrench is longer, with its scale window and a red-banded grip.
static func _wrench(torque: bool) -> VoxelModel:
	var m := VoxelModel.new(0.004)
	m.jitter = 0.03
	var c := 5.0
	var body := CHROME if not torque else BLACK_OXIDE
	_disc_y(m, c, c, 0, 9, 4.2, CHROME)               # the socket
	_hex_y(m, c, c, 0, 1, 6, SOOT)                     # its hex opening
	_disc_y(m, c, c, 9, 4, 5.4, body)                  # the head
	m.box(3, 13, 3, 4, 1, 4, body.lightened(0.1))      # reverse lever
	var length := 64 if not torque else 104
	m.box(9, 10, 3, length - 9, 2, 4, body)
	if torque:
		m.box(40, 12, 3, 22, 1, 4, Wear.PAPER)         # the scale window
		for x in range(42, 62, 3):
			m.box(x, 13, 4, 1, 1, 2, SOOT)
		m.box(52, 13, 3, 1, 1, 4, RED_GRIP)            # the set line
		m.box(66, 9, 2, 38, 4, 6, SOOT)                # knurled grip
		for x in range(68, 102, 4):
			m.box(x, 9, 1, 2, 4, 8, RED_GRIP if x > 92 else SOOT.lightened(0.12))
		m.box(length, 10, 4, 3, 2, 2, BRASS)           # the locking knob
	else:
		m.box(40, 9, 2, 24, 4, 6, Wear.RUBBER)         # the grip
		m.box(40, 9, 1, 2, 4, 8, Color("2b5d9a"))
	return m.set_pivot(c, 0, c)


## A 5/8 in deep plug socket on a short extension, the rubber insert showing.
static func _plug_socket() -> VoxelModel:
	var m := VoxelModel.new(0.003)
	m.jitter = 0.03
	var c := 5.0
	_disc_y(m, c, c, 0, 22, 5.0, CHROME, 3.6)
	_disc_y(m, c, c, 14, 8, 3.6, Wear.RUBBER)
	_disc_y(m, c, c, 22, 3, 5.0, CHROME)
	_disc_y(m, c, c, 25, 26, 2.2, CHROME.darkened(0.08))  # extension
	m.box(3, 2, -1, 4, 6, 1, Color("2b5d9a"))  # the stamped size band
	return m.set_pivot(c, 0, c)


## A feeler gauge: its stamped holder with the leaves fanned out of it.
## Pivot at the holder's screw.
static func _feeler_gauge() -> VoxelModel:
	var m := VoxelModel.new(0.002)
	m.jitter = 0.02
	m.box(-4, 0, -4, 46, 3, 8, OLD_STEEL.darkened(0.15))
	m.box(-3, 3, -3, 6, 1, 6, BRASS)  # the screw
	for i in 5:
		var ang := deg_to_rad(-8.0 - i * 9.0)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var basis := Basis(Vector3.UP, -ang)
		m.add_oriented(dir * 26.0 + Vector3(0, 3.5 + i * 0.3, 0), basis, Vector3(52, 0.5, 6), BRIGHT.darkened(i * 0.04))
	return m.set_pivot(0, 0, 0)


# ---------------------------------------------------------------- Doris's blade

## The 77 in ice blade, lying flat with its edge to the front (-Z): the bright
## ground edge, the bevel, and 7 bolt slots along the back. The old one is
## dull, rusty and chipped where a puck went through the conditioner.
static func _blade(old: bool) -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.jitter = 0.02
	var steel := Color("8c949a") if old else Color("aab3b9")
	m.box(0, 0, 0, BLADE_LEN, 1, 12, steel)
	m.box(0, 0, 0, BLADE_LEN, 1, 1, Color("6e757a") if old else BRIGHT)  # the edge
	m.box(0, 1, 2, BLADE_LEN, 1, 9, steel.darkened(0.06))                # the spine
	for bx in BOLT_X:
		var x := int(round(float(bx) / 0.01 + BLADE_LEN * 0.5))
		m.clear_box(x - 1, 0, 7, 3, 2, 2)
	if old:
		_speckle(m, steel, Wear.RUST, 0.08, 21)
		_speckle(m, steel.darkened(0.06), Wear.RUST_DARK, 0.06, 22)
		m.clear_box(121, 0, 0, 3, 1, 1)  # the chip
		m.clear_box(122, 0, 1, 1, 1, 1)
	else:
		m.box(4, 1, 4, 14, 1, 3, Wear.PAPER)  # the maker's sticker
	return m.set_pivot(BLADE_LEN * 0.5, 0, 6)


## The yellow rubber blade guard that clips over the edge while it's handled.
static func _blade_guard() -> VoxelModel:
	var m := VoxelModel.new(0.01)
	m.jitter = 0.03
	m.box(0, -1, -1, BLADE_LEN - 4, 3, 3, Color("e8b82a"))
	for x in range(10, BLADE_LEN - 10, 30):
		m.box(x, 2, -1, 4, 1, 2, Wear.RUBBER)  # the clips
	return m.set_pivot((BLADE_LEN - 4) * 0.5, 0, 0)


## Doris's conditioner off the machine on Gus's stands ("DORIS'S SHOES"):
## the blade holder bar with its bolt bosses and the three height screws,
## the runners at the ends, and the auger housing behind. The blade slot is
## open at the front bottom (BLADE_SEAT).
static func _conditioner() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var w := 104
	var c := w * 0.5
	var trim := DORIS_TRIM
	# the stands, one at each end, and the runners on them
	for x in [2, w - 12]:
		m.box(x, 0, -6, 10, 4, 18, SHOES)
		m.box(x, 4, -6, 10, 2, 16, OLD_STEEL.darkened(0.3))  # runner skid
	# the holder bar: a channel above the blade slot
	m.box(0, 6, -8, w, 3, 6, trim)
	m.box(0, 9, -8, w, 1, 7, trim.darkened(0.15))
	# bolt bosses along the top
	for bx in BOLT_X:
		var x := int(round(float(bx) / 0.02 + c))
		m.box(x - 1, 9, -7, 3, 1, 3, trim.lightened(0.08))
	# the height screws: a block on the back of the bar with a big slotted head
	for sx in SCREW_X:
		var x := int(round(float(sx) / 0.02 + c))
		m.box(x - 2, 6, -2, 5, 6, 3, trim.darkened(0.1))
		_disc_y(m, x + 0.5, -0.5, 12, 2, 2.2, BRASS)
		m.box(x - 1, 14, -1, 3, 1, 1, SOOT)
	# the auger housing behind and its end plates
	_disc_x(m, 0, w, 10.0, 6.0, 6.0, DORIS_CREAM.darkened(0.08))
	for x in [0, w - 1]:
		_disc_x(m, x, 1, 10.0, 6.0, 6.6, trim.darkened(0.2))
	m.box(10, 15, 2, w - 20, 1, 6, Color("3d6fb0"))  # the band paint carried round
	Wear.rust(m, trim, 0.025, 31)
	Wear.rust(m, trim.darkened(0.15), 0.04, 32)
	return m.set_pivot(c, 0, 0)


## Gus's workbench: a thick worn plank top on angle-iron legs with a shelf,
## old oil and paint on it, and a vise on the right end.
static func _workbench() -> VoxelModel:
	var m := VoxelModel.new(0.05)
	m.jitter = 0.05
	var w := 52
	var d := 18
	for x in w:
		var plank := Wear.OLD_WOOD if posmod(x / 9, 2) == 0 else Wear.OLD_WOOD.darkened(0.08)
		m.box(x, 16, 0, 1, 2, d, plank)
	for p in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, d - 1), Vector2i(w - 1, d - 1)]:
		m.box(p.x, 0, p.y, 1, 16, 1, Wear.OLD_STEEL.darkened(0.3))
	m.box(1, 3, 1, w - 2, 1, d - 2, Wear.OLD_WOOD_DARK)  # the shelf
	m.box(0, 15, 0, w, 1, 1, Wear.OLD_STEEL.darkened(0.3))
	m.box(1, 4, 3, 5, 3, 4, Color("8a3a2a"))  # a red toolbox on the shelf
	m.box(38, 4, 6, 4, 4, 4, Color("2f6fb0"))  # an oil pail
	for p in [Vector2i(6, 4), Vector2i(7, 4), Vector2i(30, 11), Vector2i(31, 12), Vector2i(44, 6)]:
		m.set_voxel(p.x, 17, p.y, OIL_STAIN)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


# ---------------------------------------------------------------- Doris's engine

## The engine bay: Doris's inline-4 in her cream cowl. The block and the head
## with the valve cover along the back, the four plug wells along the front of
## the head (PLUG_WELLS, Number 1 at the fan end on the viewer's left), the
## distributor, the air cleaner, the plug wires and the radiator's fan shroud.
static func _engine_bay() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var w := 48
	var c := w * 0.5
	# the bay: a floor pan and the cowl sides
	m.box(0, 0, -10, w, 1, 22, Wear.CHARCOAL)
	m.box(0, 1, -10, 2, 20, 22, DORIS_CREAM)
	m.box(w - 2, 1, -10, 2, 20, 22, DORIS_CREAM)
	m.box(0, 13, -10, 2, 2, 22, Color("3d6fb0"))
	m.box(w - 2, 13, -10, 2, 2, 22, Color("3d6fb0"))
	m.box(2, 1, 10, w - 4, 26, 2, DORIS_CREAM.darkened(0.12))  # the firewall
	# the block, the pan and the head
	m.box(9, 2, -6, 30, 4, 12, ENGINE.darkened(0.2))   # oil pan
	m.box(8, 6, -7, 32, 10, 14, ENGINE)
	m.box(8, 16, -6, 32, 6, 12, ENGINE.lightened(0.05))  # the head
	m.box(9, 22, 0, 30, 3, 6, Color("2a2b2e"))           # valve cover
	m.box(10, 25, 1, 28, 1, 4, Color("3a3b3e"))
	m.box(30, 26, 2, 3, 1, 2, Wear.RUBBER)               # oil filler cap
	# the plug wells along the front of the head, open so the plugs sit in
	for pw in PLUG_WELLS:
		var p: Vector3 = pw
		var x := int(round(p.x / 0.02 + c - 0.5))
		var z := int(round(p.z / 0.02 - 0.5))
		m.clear_box(x - 1, 21, z - 1, 3, 2, 3)
		m.box(x - 1, 20, z - 1, 3, 1, 3, ENGINE.darkened(0.35))
		m.box(x - 2, 22, z - 2, 5, 1, 1, ENGINE.lightened(0.05))
	# exhaust manifold low on the front, sooty
	m.box(10, 12, -8, 28, 3, 1, Color("5a4a3e"))
	for x in [12, 19, 26, 33]:
		m.box(x, 15, -8, 3, 2, 1, Color("5a4a3e"))
	# the fan end (+X): shroud, fan and the radiator's top tank
	m.box(40, 4, -8, 2, 20, 16, Wear.CHARCOAL)
	_disc_x(m, 42, 1, 13.0, 0.0, 7.0, Color("3a3b3e"))
	m.box(42, 22, -6, 4, 4, 12, Color("2a2b2e"))
	# distributor on the far end (-X) and the wires to the wells
	_disc_y(m, 5.5, 0.0, 14, 8, 2.6, Color("1a1a1c"))
	_disc_y(m, 5.5, 0.0, 22, 2, 3.2, Color("7a1f1a"))  # the cap
	m.box(4, 22, -2, 3, 1, 1, Color("101012"))  # the coil lead
	# the air cleaner: a round pan on the carburettor at the back
	_disc_y(m, 18.0, 6.0, 26, 3, 6.5, Color("2a2b2e"))
	_disc_y(m, 18.0, 6.0, 29, 1, 2.0, OLD_STEEL)  # wing nut
	m.box(16, 26, 12, 4, 2, 1, Wear.PAPER)       # the CHOKE tag
	_speckle(m, ENGINE, ENGINE.darkened(0.3), 0.08, 41)
	_speckle(m, ENGINE.darkened(0.2), OIL_STAIN, 0.15, 42)
	return m.set_pivot(c, 0, 0)


## A plug wire's boot (it pushes onto the plug's terminal) with the wire
## going up. Pivot at the bottom of the boot.
static func _plug_boot() -> VoxelModel:
	var m := VoxelModel.new(0.004)
	m.jitter = 0.03
	_disc_y(m, 3.0, 3.0, 0, 14, 3.0, Color("101012"))
	_disc_y(m, 3.0, 3.0, 14, 2, 2.0, Color("7a1f1a"))
	_disc_y(m, 3.0, 3.0, 16, 4, 1.3, Color("101012"))
	m.box(2, 19, 3, 2, 2, 8, Color("101012"))  # the wire, back over the head
	return m.set_pivot(3, 0, 3)


## The DORIS parts cabinet: a steel cabinet of six drawers, each with a
## handle and a label holder (the scene writes the labels). Hollow behind.
static func _parts_drawer() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var w := 45
	var d := 22
	var h := 60
	m.box(0, 0, 0, w, h, 1, CABINET)       # the front frame (drawers cut in below)
	m.box(0, 0, 0, 1, h, d, CABINET)
	m.box(w - 1, 0, 0, 1, h, d, CABINET)
	m.box(0, h - 1, 0, w, 1, d, CABINET.darkened(0.05))
	m.box(0, 0, d - 1, w, h, 1, CABINET.darkened(0.15))
	m.box(1, 0, 0, w - 2, 2, d, Wear.CHARCOAL)  # the plinth
	for i in DRAWER_COUNT:
		var top := int(round(DRAWER_TOP / 0.02)) + 4 - i * 9
		m.box(2, top - 8, -1, w - 4, 8, 1, CABINET.lightened(0.06))
		m.box(17, top - 6, -2, 11, 1, 1, OLD_STEEL)      # handle
		m.box(19, top - 3, -2, 7, 2, 1, Wear.PAPER)      # label holder
	Wear.rust(m, CABINET.lightened(0.06), 0.015, 51)
	return m.set_pivot(w * 0.5, 0, 0)


## A drawer pulled out of the cabinet: the tray with three boxes of plugs in
## it. Pivot at the middle of its front face, at its bottom.
static func _drawer_tray() -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var w := 41
	m.box(0, 0, 0, w, 8, 1, CABINET.lightened(0.06))
	m.box(15, 2, -1, 11, 1, 1, OLD_STEEL)
	m.box(17, 5, -1, 7, 2, 1, Wear.PAPER)
	m.box(0, 0, 1, w, 1, 18, CABINET.darkened(0.1))
	m.box(0, 1, 1, 1, 5, 18, CABINET)
	m.box(w - 1, 1, 1, 1, 5, 18, CABINET)
	m.box(0, 1, 18, w, 5, 1, CABINET)
	for i in 3:
		m.box(4 + i * 12, 1, 4, 9, 3, 5, Color("2b5d9a") if i < 2 else Color("c8642a"))
		m.box(5 + i * 12, 4, 5, 7, 1, 3, Wear.WHITE)
	return m.set_pivot(w * 0.5, 0, 0)
