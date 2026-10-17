class_name Wear
extends RefCounted
## Renovation states for the rink's look. Every prop comes in three ages and
## this file holds the shared colour rules, so a worn door and a worn seat age
## the same way. See docs/ART.md.
##
##  WORN       the rink as you find it: faded 1970s paint, grime low down,
##             chipped edges, rust on steel, things missing.
##  REPAIRED   the volunteer fix: fresh coat of the old colours, mismatched
##             replacement parts, tape and plywood patches.
##  RENOVATED  the finished job: the club's new palette, clean edges, steel,
##             glass and LED.

enum { WORN, REPAIRED, RENOVATED }

const NAMES := ["worn", "repaired", "renovated"]

# Old rink (WORN and REPAIRED share these; REPAIRED just fades them less).
const OLD_WOOD := Color("9a6b3f")
const OLD_WOOD_DARK := Color("6e4a2a")
const NEW_WOOD := Color("d4ad78")  # a fresh replacement plank, unpainted
const OLD_MINT := Color("8fbfa8")
const OLD_GOLD := Color("d9a62e")
const OLD_ORANGE := Color("c8642a")
const OLD_AVOCADO := Color("7d8a3a")
const OLD_BROWN := Color("5b3a22")
const OLD_CREAM := Color("e3d9bf")
const CONCRETE := Color("a8a294")
const OLD_STEEL := Color("8f9498")
const RUST := Color("8a4a24")
const RUST_DARK := Color("5e2f18")
const GRIME := Color("6f6450")
const DUCT_TAPE := Color("9ea2a6")
const PLYWOOD := Color("c9a46a")
const PAPER := Color("f1eee4")
const SODIUM := Color("ffb84d")
const SODIUM_DIM := Color("b9853f")

# Renovated club palette: navy, rink red and white, with steel and glass.
const NAVY := Color("1d3557")
const RED := Color("d0202a")
const WHITE := Color("eeeeea")
const STEEL := Color("b9c0c6")
const CHARCOAL := Color("2b2d33")
const TEAL := Color("2a9d8f")
const GLASS := Color("a9d3e0")
const GLASS_DARK := Color("6fa3b5")
const LED := Color("f4f8ff")

const RUBBER := Color("17181b")


## Ages a finished model in place. Colours fade toward grime (more near the
## floor), and WORN also loses a few corner voxels. Deterministic per seed.
static func weather(m: VoxelModel, age: int, seed := 0) -> VoxelModel:
	if age == RENOVATED:
		m.jitter = 0.02
		return m
	var fade := 0.32 if age == WORN else 0.12
	var grime := 0.16 if age == WORN else 0.05
	var lo := 1 << 30
	var hi := -(1 << 30)
	for p in m.voxels:
		lo = mini(lo, p.y)
		hi = maxi(hi, p.y)
	var height := float(maxi(hi - lo, 1))
	var chipped: Array[Vector3i] = []
	for p in m.voxels:
		var c: Color = m.voxels[p]
		var low := 1.0 - clampf(float(p.y - lo) / height, 0.0, 1.0)
		var g := grime * (0.6 + 0.8 * low * low)
		var grey := c.get_luminance()
		c = c.lerp(Color(grey, grey, grey), fade).lerp(GRIME, g)
		m.voxels[p] = c
		if age == WORN and _exposed(m, p) >= 3 and _roll(p, seed) < 0.05:
			chipped.append(p)
	for p in chipped:
		m.voxels.erase(p)
	m.jitter = 0.07 if age == WORN else 0.05
	return m


## Speckles rust over voxels of one colour (steel parts on old props).
static func rust(m: VoxelModel, of: Color, amount: float, seed := 0) -> void:
	for p in m.voxels:
		if m.voxels[p].is_equal_approx(of) and _roll(p, seed + 7) < amount:
			m.voxels[p] = RUST if _roll(p, seed + 11) < 0.6 else RUST_DARK


static func _exposed(m: VoxelModel, p: Vector3i) -> int:
	var n := 0
	for d in VoxelModel.DIRS:
		if not m.voxels.has(p + d):
			n += 1
	return n


static func _roll(p: Vector3i, seed: int) -> float:
	return float(posmod(hash([p, seed]), 10000)) / 10000.0
