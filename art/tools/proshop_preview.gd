extends SceneTree
## A quick look at Bev's Edge & Tape, the Millbrook pro shop (docs/world/PROSHOP.md),
## built procedurally from voxels and rendered as a cutaway from above the
## missing front wall. A review sketch, not the shop scene. Needs a renderer
## (not --headless); see docs/ART.md for the cloud recipe:
##   godot --path . --script res://art/tools/proshop_preview.gd -- --out=proshop.png [--age=worn|renovated]
##
## Shop space: x runs across (+x is the left wall as you walk in), z runs from
## the front door (z = 0) to the back wall (z = 12), floor at y = 0.

const V := Models.V  # 0.065 m props grid
const H := V * 0.5  # finer grid for small goods (skates, gloves, masks)
const WALL_V := 0.125  # panelling grid
const W := 4.0  # half width
const D := 12.0  # depth
const CEIL := 3.0

var _out := "proshop.png"
var _age := Wear.WORN
var _frames := 0
var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _stick_meshes := {}

# 5x7 capitals for the hand-painted signs, a fuller set than Props.letters().
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
	"&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
	"$": ["00100", "01111", "10100", "01110", "00101", "11110", "00100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

# The shop's own colours on top of the Wear palettes.
const CAST_IRON := Color("4d6b5c")  # Old Bertha's enamel
const CHALK := Color("e8e4d6")
const CHALKBOARD := Color("2e3b31")
const LINO_A := Color("d2b27a")
const LINO_B := Color("a8774a")
const SECTION := Color("2a1d14")  # cut tops of the walls
const LEATHER := Color("7a4a26")
const PAD_TAN := Color("c08a52")
const CAT := Color("d98a3a")


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--age="):
			_age = Wear.NAMES.find(arg.trim_prefix("--age="))
			if _age < 0:
				_age = Wear.WORN
	_rng.seed = 1979
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	_world = Node3D.new()
	root.add_child(_world)
	_environment()
	_room()
	_counter()
	_tape_tower(Vector3(-1.25, 0, 0.75))
	_skate_wall()
	_try_on_bench()
	_bins()
	_stick_rack()
	_used_rack()
	_broken_barrel()
	_sharpening()
	_stick_bench()
	_goalie_corner()
	_clutter()
	_lights()
	_camera()


func _ren() -> bool:
	return _age == Wear.RENOVATED


# ---------------------------------------------------------------- helpers

func _put(m: VoxelModel, pos: Vector3, yaw_deg := 0.0, weather := true, seed := 0, parent: Node = null) -> MeshInstance3D:
	if weather:
		Wear.weather(m, _age, seed)
	var mi := MeshInstance3D.new()
	mi.mesh = m.build_mesh()
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	(parent if parent else _world).add_child(mi)
	return mi


## Writes text toward -x, readable from -Z, like Props.letters(). (x, y) is
## the top-left of the first letter as the viewer sees it.
static func text(m: VoxelModel, s: String, x: int, y: int, z: int, c: Color, skip := []) -> void:
	for i in s.length():
		if i in skip:
			continue
		var g: Array = GLYPHS.get(s[i], GLYPHS[" "])
		for row in 7:
			for col in 5:
				if g[row][col] == "1":
					m.set_voxel(x - i * 6 - col, y - row, z, c)


static func text_w(s: String) -> int:
	return s.length() * 6 - 1


## A painted board with centred lines of text, front facing -Z, pivot at the
## bottom centre of its back.
func _sign(lines: Array, size: float, board: Color, ink: Color, pad := 2, skip := {}) -> VoxelModel:
	var m := VoxelModel.new(size)
	var w := 0
	for l in lines:
		w = maxi(w, text_w(l))
	w += pad * 2
	var h := lines.size() * 9 - 2 + pad * 2
	m.box(0, 0, 0, w, h, 1, board)
	m.box(0, 0, 1, w, h, 1, board.darkened(0.3))
	for i in lines.size():
		var lw := text_w(lines[i])
		text(m, lines[i], w - 1 - (w - lw) / 2, h - 1 - pad - i * 9, 0, ink, skip.get(i, []))
	m.set_pivot(w * 0.5, 0, 2)
	m.jitter = 0.03
	return m


func _box_mesh(size: Vector3, pos: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emit
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	_world.add_child(mi)
	return mi


# ---------------------------------------------------------------- room

func _room() -> void:
	# floor: 1970s linoleum checker (renovated: grey rubber with a red lane)
	var f := VoxelModel.new(0.25)
	for x in 32:
		for z in 48:
			var c := LINO_A if (x + z) % 2 == 0 else LINO_B
			if _ren():
				c = Color("5d6168") if (x + z) % 2 == 0 else Color("53575e")
			f.set_voxel(x, -1, z, c)
	_put(f, Vector3(-W, 0, 0), 0, true, 3)
	# black rubber runner from the door to the counter and Bertha
	var mat := VoxelModel.new(V)
	mat.box(0, 0, 0, 12, 1, 140, Color("3b332c") if not _ren() else Wear.NAVY)
	_put(mat, Vector3(-6 * V, 0.0, 0.1), 0, true, 4)
	# walls: back, left (+x), right (-x); the front wall is cut away low
	_wall(64, true, Vector3(-W, 0, D))
	_wall(96, false, Vector3(W, 0, 0))
	_wall(96, false, Vector3(-W - 2 * WALL_V, 0, 0))
	_front_stub()
	if not _ren():
		_ceiling_rim()


## A panelled wall `n` panel voxels long and two thick, along x or z.
func _wall(n: int, along_x: bool, origin: Vector3) -> void:
	var m := VoxelModel.new(WALL_V)
	var h := int(CEIL / WALL_V)
	for u in n:
		var plank := float(posmod(hash([u / 2, along_x]), 100)) / 100.0
		for y in h + 1:
			for t in 2:
				var c: Color
				if _ren():
					c = Wear.NAVY if y < 8 else Wear.WHITE
					if y == 8:
						c = Wear.RED
				elif y == 0:
					c = Wear.OLD_BROWN.darkened(0.2)
				elif y < 8:
					c = Wear.OLD_WOOD_DARK  # lower panels
				elif y == 8:
					c = Wear.OLD_ORANGE  # chair rail
				else:
					c = Wear.OLD_WOOD.lerp(Wear.OLD_WOOD_DARK, plank * 0.5)
					if u % 3 == 0:
						c = Wear.OLD_WOOD_DARK.darkened(0.2)  # groove
				if y == h:
					c = SECTION
				if along_x:
					m.set_voxel(u, y, t, c)
				else:
					m.set_voxel(t, y, u, c)
	_put(m, origin, 0, true, n)


## The front wall cut down to knee height, with the door gap in the middle.
func _front_stub() -> void:
	var m := VoxelModel.new(WALL_V)
	for u in 68:
		var x := u - 2
		if x >= 28 and x < 36:
			continue  # door
		for y in 4:
			m.box(u, y, 0, 1, 1, 2, SECTION if y == 3 else (Wear.OLD_WOOD_DARK if not _ren() else Wear.NAVY))
	_put(m, Vector3(-W - 2 * WALL_V, 0, -2 * WALL_V), 0, true, 9)
	# door mat and the SKATE GUARDS ON sign on a post by the door
	var mt := VoxelModel.new(V)
	mt.box(0, 0, 0, 14, 1, 9, Color("4a3a2c") if not _ren() else Wear.CHARCOAL)
	_put(mt, Vector3(-7 * V, 0.01, 0.05), 0, true, 10)
	var s := _sign(["SKATE", "GUARDS ON"], 0.022, Wear.PAPER, Wear.RED.darkened(0.2))
	_put(s, Vector3(-0.85, 0.5, 0.0), 0, true, 11)


## A strip of dropped-ceiling tiles round the cut, with the water stain.
func _ceiling_rim() -> void:
	var m := VoxelModel.new(V)
	var w := int(2 * W / V)
	var d := int(D / V)
	for x in w:
		for z in d:
			if x > 3 and z < d - 4:
				continue  # only along the back and right walls
			var c := Wear.OLD_CREAM
			if x % 9 == 0 or z % 9 == 0:
				c = Wear.OLD_STEEL.darkened(0.1)  # T-bar grid
			m.set_voxel(x, 0, z, c)
	# water stain rings over the goalie corner
	var sc := Vector2(w - 10, d - 3)
	for x in w:
		for z in d:
			var p := Vector3i(x, 0, z)
			if not m.voxels.has(p):
				continue
			var r := Vector2(x, z).distance_to(sc)
			if r < 7.5:
				var k := 0.55 if r < 4.0 else (0.75 if r > 6.0 else 0.4)
				m.voxels[p] = Color("6e4a22").lerp(Wear.OLD_CREAM, k * 0.6)
	_put(m, Vector3(-W, CEIL - V, 0), 0, true, 12)
	# the stain runs down the right wall too, and Bev's bucket catches the drip
	var streak := VoxelModel.new(WALL_V)
	for y in 7:
		streak.box(0, -y, int(y * 0.4), 1, 1, 3 - y / 3, Color("6d4e2c"))
	_put(streak, Vector3(-W - 0.01, CEIL - 0.3, D - 1.8), 0, false)
	var b := VoxelModel.new(H)
	for y in 9:
		for x in 8:
			for z in 8:
				var dx := x - 3.5
				var dz := z - 3.5
				var r2 := dx * dx + dz * dz
				if r2 <= 15.5 and (y == 0 or r2 > 8.5):
					b.set_voxel(x, y, z, Wear.OLD_STEEL)
	b.box(1, 2, 1, 6, 1, 6, Color("5a6d78"))  # water
	_put(b, Vector3(-3.15, 0, D - 1.85), 0, true, 13)


# ---------------------------------------------------------------- counter

func _counter() -> void:
	# runs along z at the front right, customers on the +x side
	var m := VoxelModel.new(V)
	var L := 40
	var dd := 10
	var hh := 15
	var body := Wear.OLD_WOOD if not _ren() else Wear.NAVY
	m.box(0, 0, 0, dd, hh, L, body)
	for z in range(0, L, 3):
		m.box(dd - 1, 1, z, 1, hh - 2, 1, body.darkened(0.25))  # panel grooves
	m.box(dd - 1, 0, 0, 1, 1, L, Wear.OLD_BROWN)
	var top := Wear.OLD_ORANGE if not _ren() else Wear.WHITE
	m.box(-1, hh, -1, dd + 2, 1, L + 2, top)
	if not _ren():
		m.box(dd, 6, 16, 1, 4, 6, Wear.PAPER)  # CASH ONLY note
		m.box(dd, 3, 30, 1, 3, 4, Wear.OLD_GOLD)  # faded hockey sticker
	# cash register
	var reg := Wear.OLD_STEEL.darkened(0.2) if not _ren() else Wear.CHARCOAL
	m.box(2, hh + 1, 6, 7, 3, 8, reg)
	m.box(2, hh + 4, 6, 3, 3, 8, reg)
	for z in range(7, 13, 2):
		m.set_voxel(6, hh + 4, z, Wear.OLD_CREAM)
		m.set_voxel(8, hh + 4, z, Wear.OLD_CREAM)
	m.box(3, hh + 7, 8, 1, 2, 4, Color("2c3a2c"))  # pop-up price flags
	m.set_voxel(3, hh + 8, 9, Wear.OLD_GOLD)
	# coffee pot on its hot plate, and a $1 card
	m.box(4, hh + 1, 28, 4, 1, 4, Wear.RUBBER)
	m.box(5, hh + 2, 29, 2, 3, 2, Color("3a2416"))
	m.box(5, hh + 5, 29, 2, 1, 2, Wear.RUBBER)
	_put(m, Vector3(-2.75, 0, 0.55), 0, true, 20)
	var price := _sign(["$1"], 0.02, Wear.PAPER, Wear.RED.darkened(0.2), 1)
	_put(price, Vector3(-2.06, (hh + 1) * V, 0.55 + 31 * V), -90)
	# jar of pucks
	var j := VoxelModel.new(H)
	j.box(0, 0, 0, 6, 8, 6, Wear.GLASS.lerp(Wear.OLD_CREAM, 0.3))
	j.box(1, 1, -1, 4, 5, 1, Models.PUCK)
	j.box(-1, 1, 1, 1, 5, 4, Models.PUCK)
	j.box(1, 8, 1, 4, 1, 4, Wear.OLD_GOLD)
	_put(j, Vector3(-2.35, (hh + 1) * V, 0.55 + 20 * V), 0, true, 21)
	# shelf behind the counter: tape, laces, a radio, the photo wall above
	var sh := VoxelModel.new(V)
	sh.box(0, 0, 0, 5, 22, 36, Wear.OLD_WOOD_DARK if not _ren() else Wear.WHITE)
	for y in [7, 14, 21]:
		sh.box(0, y, 0, 6, 1, 36, Wear.OLD_WOOD if not _ren() else Wear.STEEL)
	sh.clear_box(1, 0, 1, 4, 7, 34)
	sh.clear_box(1, 8, 1, 4, 6, 34)
	sh.clear_box(1, 15, 1, 4, 6, 34)
	for z in range(2, 34, 2):
		if _rng.randf() < (0.55 if not _ren() else 0.95):
			sh.box(2, 8, z, 2, 2, 1, Models.TAPE if z % 4 == 0 else Models.PUCK)
		if _rng.randf() < 0.5 or _ren():
			sh.box(2, 15, z, 2, 3, 1, [Wear.OLD_ORANGE, Wear.OLD_GOLD, Wear.OLD_CREAM][z % 3])
	sh.box(2, 1, 4, 3, 3, 6, Color("4a3020"))  # a radio
	_put(sh, Vector3(-W, 0, 0.6), 0, true, 22)
	# photo wall: framed team photos from 1971 on
	var ph := VoxelModel.new(H)
	for i in 10:
		var px := (i % 5) * 13
		var py := (i / 5) * 11
		ph.box(0, py, px, 1, 9, 11, Color("2a1d14"))
		var tint := Color("b49a72").lerp(Color("8a8a8a"), float(i) / 10.0)
		ph.box(1, py + 1, px + 1, 1, 7, 9, tint)
		for k in 4:
			ph.set_voxel(1, py + 3, px + 2 + k * 2, tint.darkened(0.45))  # the team, front row
			ph.set_voxel(1, py + 5, px + 3 + k * 2 - (1 if k == 3 else 0), tint.darkened(0.45))
	_put(ph, Vector3(-W + 0.02, 1.75, 0.75), 0, true, 23)


func _tape_tower(at: Vector3) -> void:
	var m := VoxelModel.new(H)
	m.box(0, 0, 0, 10, 1, 10, Wear.RUBBER)
	m.box(4, 0, 4, 2, 44, 2, Wear.OLD_STEEL)
	var cols := [Models.TAPE, Models.PUCK, Wear.OLD_ORANGE, Color("2a6fb0"), Wear.RED, Models.TAPE]
	for tier in 5:
		var y := 6 + tier * 8
		m.box(0, y, 0, 10, 1, 10, Wear.OLD_STEEL.darkened(0.15))
		for k in 8:
			if not _ren() and _rng.randf() < 0.4:
				continue  # half-empty
			var c: Color = cols[(k + tier) % cols.size()]
			var ring := [Vector2i(0, 0), Vector2i(4, 0), Vector2i(8, 0), Vector2i(8, 4), Vector2i(8, 8), Vector2i(4, 8), Vector2i(0, 8), Vector2i(0, 4)]
			var p: Vector2i = ring[k]
			m.box(p.x, y + 1, p.y, 2, 3, 2, c)
			m.set_voxel(p.x, y + 2, p.y, c.darkened(0.4))  # the core
	m.box(1, 45, 1, 8, 6, 1, Wear.OLD_ORANGE if not _ren() else Wear.RED)
	text_tiny(m, "TAPE", 8, 50, 0, Wear.OLD_CREAM)
	_put(m.set_pivot(5, 0, 5), at, 0, true, 30)


## 3x5 letters for tiny labels.
const TINY := {
	"T": ["111", "010", "010", "010", "010"], "A": ["010", "101", "111", "101", "101"],
	"P": ["110", "101", "110", "100", "100"], "E": ["111", "100", "110", "100", "111"],
}


static func text_tiny(m: VoxelModel, s: String, x: int, y: int, z: int, c: Color) -> void:
	for i in s.length():
		var g: Array = TINY.get(s[i], ["000", "000", "000", "000", "000"])
		for row in 5:
			for col in 3:
				if g[row][col] == "1":
					m.set_voxel(x - i * 4 + 2 - col - 1, y - row, z - 1, c)


# ---------------------------------------------------------------- skates

## One skate at the fine grid, length along +z (toe at z = 0), 4 wide.
func _skate(boot: Color, accent: Color) -> VoxelModel:
	var m := VoxelModel.new(H)
	var steel := Models.STEEL
	m.box(1, 0, 0, 2, 1, 11, steel)  # blade
	if _ren():
		m.box(0, 1, 1, 4, 1, 9, Color("e8e8e4"))  # moulded holder
	else:
		m.box(1, 1, 1, 2, 1, 1, steel)  # tube holder posts
		m.box(1, 1, 8, 2, 1, 1, steel)
	m.box(0, 2, 0, 4, 1, 10, boot.darkened(0.35))  # sole
	m.box(0, 3, 0, 4, 2, 10, boot)
	m.box(0, 5, 4, 4, 4, 6, boot)
	m.box(1, 5, 3, 2, 5, 1, boot.lightened(0.15))  # tongue
	m.box(0, 6, 5, 1, 1, 5, accent)
	m.box(3, 6, 5, 1, 1, 5, accent)
	for z in [1, 2, 3]:
		m.set_voxel(1, 5, z, Models.TAPE)  # laces
		m.set_voxel(2, 5, z, Models.TAPE)
	return m


func _skate_wall() -> void:
	# shelving along the right wall from z 3.6 to 9.4, boxes up to the ceiling
	var m := VoxelModel.new(V)
	var L := 88
	var dpt := 7
	var top := 44
	var wood := Wear.OLD_WOOD if not _ren() else Wear.WHITE
	var box_cols := [Wear.OLD_ORANGE, Color("e9e2d0"), Color("1f1f22"), Color("b5312a"), Color("2f5d8a"), Wear.OLD_GOLD]
	if _ren():
		box_cols = [Wear.NAVY, Wear.WHITE, Wear.CHARCOAL, Wear.RED, Wear.TEAL, Wear.STEEL]
	m.box(0, 0, 0, 1, top, L, wood.darkened(0.3))  # back board
	for z in [0, 29, 58, L - 1]:
		m.box(0, 0, z, dpt, top, 1, wood)  # uprights
	var shelves := [0, 24, 30, 36, 42]
	for y in shelves:
		m.box(0, y, 0, dpt, 1, L, wood)
	# pegboard band for display skates (y 2..23)
	for y in range(2, 23):
		for z in range(1, L - 1):
			if z in [29, 58]:
				continue
			m.set_voxel(0, y, z, Color("8b6a45") if (y + z) % 3 != 0 else Color("5e4630"))
	# boxes on the upper shelves, half the slots empty when worn
	for y in [25, 31, 37]:
		var z := 1
		while z < L - 6:
			if z + 5 > 29 and z < 30 or z + 5 > 58 and z < 59:
				z += 1
				continue
			var full := _rng.randf() < (0.5 if not _ren() else 0.97)
			if full:
				var c: Color = box_cols[_rng.randi() % box_cols.size()]
				var stack := 1 if _rng.randf() < 0.6 else 2
				for s in stack:
					m.box(1, y + 1 + s * 2, z, 6, 2, 5, c)
					m.box(6, y + 1 + s * 2, z + 1, 1, 1, 3, Wear.PAPER)  # end label
			z += 6
	# the top: boxes stacked to the ceiling over the middle bay (Toe Drag's spot)
	for k in 3:
		m.box(1, 43 + k * 2, 32 + k, 6, 2, 5, box_cols[k])
	_put(m, Vector3(-W, 0, 3.6), 0, true, 40)
	# display skates on pegs
	var boots := [Color("1b1b1d"), LEATHER, Color("1b1b1d"), Color("e9e5da"), LEATHER]
	var acc := [Wear.OLD_GOLD, Models.TAPE, Wear.RED, Color("2f5d8a"), Wear.OLD_ORANGE]
	if _ren():
		boots = [Wear.CHARCOAL, Wear.WHITE, Color("101114"), Wear.NAVY, Wear.CHARCOAL]
		acc = [Wear.RED, Wear.TEAL, Wear.STEEL, Wear.WHITE, Wear.RED]
	var i := 0
	for row in [1.0, 0.45]:
		for zz in range(0, 15):
			var z := 3.75 + zz * 0.38
			if z > 9.2:
				break
			if not _ren() and _rng.randf() < 0.35:
				continue
			var sk := _skate(boots[i % boots.size()], acc[i % acc.size()])
			_put(sk, Vector3(-W + 0.12, row, z), 0, true, 50 + i)
			i += 1
	if _ren():
		_grafton_case()
	# Toe Drag, asleep on the boxes
	var cat := VoxelModel.new(H)
	cat.box(0, 0, 0, 7, 3, 10, CAT)
	for z in [2, 5, 8]:
		cat.box(0, 2, z, 7, 1, 1, CAT.darkened(0.35))
	cat.box(1, 1, -3, 5, 4, 4, CAT)  # head
	cat.set_voxel(1, 5, -3, CAT.darkened(0.2))
	cat.set_voxel(5, 5, -3, CAT.darkened(0.2))
	cat.box(6, 0, 7, 3, 1, 6, CAT.darkened(0.15))  # tail curled round
	cat.box(2, 2, -4, 1, 1, 1, Color("3a2a1a"))  # shut eyes
	cat.box(4, 2, -4, 1, 1, 1, Color("3a2a1a"))
	_put(cat, Vector3(-W + 0.06, 49 * V, 3.6 + 33 * V), 90, true, 49)


func _grafton_case() -> void:
	var g := VoxelModel.new(H)
	g.box(0, 0, 0, 10, 2, 16, Wear.CHARCOAL)
	_put(g, Vector3(-W + 0.55, 0.0, 9.5), 0, false)
	var gl := _box_mesh(Vector3(0.36, 0.9, 0.55), Vector3(-W + 0.72, 0.53, 9.76), Wear.GLASS)
	var mat: StandardMaterial3D = gl.mesh.material
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.66, 0.83, 0.88, 0.25)
	var sk := _skate(Wear.WHITE, Wear.RED)
	_put(sk, Vector3(-W + 0.66, 0.35, 9.58), 0, false)


func _try_on_bench() -> void:
	var m := VoxelModel.new(V)
	m.box(0, 0, 0, 14, 1, 40, Wear.RUBBER)  # rubber mat
	var seat := Wear.OLD_WOOD if not _ren() else Wear.NEW_WOOD
	m.box(4, 6, 2, 6, 1, 36, seat)
	for z in [3, 20, 35]:
		m.box(5, 1, z, 4, 5, 1, Wear.OLD_STEEL if not _ren() else Wear.CHARCOAL)
	# a pair of skates someone left and the foot measuring board
	_put(m, Vector3(-2.75, 0, 4.9), 0, true, 60)
	var fb := VoxelModel.new(H)
	fb.box(0, 0, 0, 5, 1, 11, Wear.OLD_STEEL)
	for z in range(0, 11, 2):
		fb.set_voxel(0, 1, z, Models.PUCK)
	fb.box(0, 1, 9, 5, 2, 1, Wear.OLD_STEEL.darkened(0.3))
	_put(fb, Vector3(-1.9, 0.07, 5.4), 0, true, 61)
	var a := _skate(LEATHER, Wear.OLD_GOLD)
	_put(a, Vector3(-2.15, 0.07, 6.6), 15, true, 62)
	var b := _skate(LEATHER, Wear.OLD_GOLD)
	_put(b, Vector3(-1.95, 0.07, 6.7), -25, true, 63)


# ---------------------------------------------------------------- bins

func _bins() -> void:
	var glove_cols := [Color("5e3a20"), Color("8a2a22"), Color("2a3f6a"), Color("1c1c1e"), Color("6b6b2a")]
	var n := 1 if not _ren() else 3
	for b in n:
		_wire_bin(Vector3(0.95 - b * 1.25, 0, 4.3), glove_cols, "glove", 70 + b)
	_wire_bin(Vector3(0.95, 0, 6.4), [Models.TAPE, Color("1c1c1e"), Wear.OLD_CREAM], "pad", 80)
	var s := _sign(["SMELL BEFORE", "YOU BUY.", "TRUST ME."], 0.018, Wear.PAPER, Color("2a2a2a"), 2)
	var post := VoxelModel.new(V)
	post.box(0, 0, 0, 1, 22, 1, Wear.OLD_STEEL)
	post.box(-2, 0, -2, 5, 1, 5, Wear.RUBBER)
	_put(post, Vector3(1.75, 0, 5.5), 0, true, 81)
	_put(s, Vector3(1.78, 1.05, 5.45), 20, false)


## A wire bin about 0.9 x 0.75 x 1.1 m, heaped with gloves or pads.
func _wire_bin(at: Vector3, cols: Array, kind: String, seed: int) -> void:
	var m := VoxelModel.new(H)
	var w := 26
	var d := 20
	var h := 22
	var wire := Wear.OLD_STEEL if not _ren() else Wear.STEEL
	for x in w:
		for z in d:
			var edge_x := x == 0 or x == w - 1
			var edge_z := z == 0 or z == d - 1
			if not (edge_x or edge_z):
				m.set_voxel(x, 2, z, wire)
				continue
			for y in range(2, h):
				if (y % 4 == 0 or (x + z) % 4 == 0) or y == h - 1:
					m.set_voxel(x, y, z, wire)
	for c in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, d - 1), Vector2i(w - 1, d - 1)]:
		m.box(c.x, 0, c.y, 1, 2, 1, wire)
	# the heap
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var count := 22 if kind == "glove" else 14
	if not _ren():
		count = int(count * 0.7)
	for i in count:
		var c: Color = cols[r.randi() % cols.size()]
		var px := r.randi_range(1, w - 8)
		var pz := r.randi_range(1, d - 8)
		var py := 3 + r.randi_range(0, 10) + (4 if px > 4 and px < w - 10 else 0) + (5 if kind != "glove" else 0)
		if kind == "glove":
			m.box(px, py, pz, 7, 5, 6, c)  # glove body
			m.box(px + 1, py + 5, pz + 1, 5, 2, 4, c.darkened(0.2))  # fingers
			m.box(px, py, pz + 6, 7, 3, 1, Wear.OLD_CREAM.darkened(0.2))  # cuff palm
		else:
			m.box(px, py, pz, 4, 3, 9, c)  # shin pad lying down
			m.box(px, py + 3, pz + 2, 4, 1, 2, c.darkened(0.3))  # knee cap
	_put(m, at, 0, true, seed)


# ---------------------------------------------------------------- sticks

func _brand(name: String) -> Dictionary:
	match name:
		"honest": return {"shaft": Color("1b1b1e"), "band": Color("d0202a"), "band2": Color("eeeeea")}
		"kodiak": return {"shaft": Color("e4e0d6"), "band": Color("2a6fb0"), "band2": Color("1b1b1e")}
		"warlock": return {"shaft": Color("2c3a28"), "band": Color("9bd13a"), "band2": Color("1b1b1e")}
		"wood": return {"shaft": Color("c99a5a"), "band": Color("6e4220"), "band2": Color("c99a5a")}
	return {"shaft": Color("7a7a7a"), "band": Color("444444"), "band2": Color("aaaaaa")}


func _stick_mesh(brand: String) -> Array:
	if not _stick_meshes.has(brand):
		var p := _brand(brand)
		var s := Models.shaft(p)
		var b := Models.blade(p)
		if not _ren():
			Wear.weather(s, Wear.REPAIRED, 1)
			Wear.weather(b, Wear.REPAIRED, 2)
		_stick_meshes[brand] = [s.build_mesh(), b.build_mesh()]
	return _stick_meshes[brand]


## A whole stick standing on its toe: shaft lean `lean` (Basis applied after
## the shaft is made vertical), blade toe pointing along `toe_yaw`.
func _stick(brand: String, toe_pos: Vector3, toe_yaw_deg: float, lean: Basis) -> Node3D:
	var meshes := _stick_mesh(brand)
	var n := Node3D.new()
	var lie := deg_to_rad(90.0 - Models.BLADE_LIE_DEG)
	var bl := MeshInstance3D.new()
	bl.mesh = meshes[1]
	n.add_child(bl)
	var sh := MeshInstance3D.new()
	sh.mesh = meshes[0]
	sh.transform = Transform3D(Basis(Vector3.BACK, lie), Models.blade_heel)
	n.add_child(sh)
	var upright := Basis(Vector3.BACK, -lie)
	n.transform = Transform3D(lean * Basis(Vector3.UP, deg_to_rad(toe_yaw_deg)) * upright, Vector3.ZERO)
	# lift so the toe touches the floor
	var toe_local := Vector3((17.0 - Models.BLADE_PIVOT.x) * Models.STICK_V, 0, 0)
	var toe_world := n.transform.basis * toe_local
	n.position = toe_pos - toe_world
	_world.add_child(n)
	return n


func _stick_rack() -> void:
	# a wooden rack along the left wall, z 2.4..8.2, three brand bays
	var m := VoxelModel.new(V)
	var L := 90
	var wood := Wear.OLD_WOOD if not _ren() else Wear.NEW_WOOD
	m.box(0, 0, 0, 6, 2, L, wood.darkened(0.2))  # floor trough
	m.box(0, 17, 0, 3, 1, L, wood)  # top rail
	for z in range(0, L, 30):
		m.box(0, 0, z, 6, 18, 1, wood)
	m.box(0, 0, L - 1, 6, 18, 1, wood)
	for z in range(0, L, 2):
		m.set_voxel(2, 17, z, wood.darkened(0.45))  # slots
	_put(m, Vector3(W - 6 * V, 0, 2.4), 0, true, 90)
	var brands := ["honest", "kodiak", "warlock"]
	var lean := Basis(Vector3.BACK, deg_to_rad(-7.0))
	for bay in 3:
		var sg := _sign([brands[bay].to_upper()], 0.03, [Wear.OLD_GOLD, Wear.OLD_CREAM, Wear.OLD_ORANGE][bay] if not _ren() else Wear.NAVY, Color("2a1d14") if not _ren() else Wear.WHITE, 2)
		_put(sg, Vector3(W - 0.02, 1.55, 2.4 + (bay * 30 + 15) * V), 90)
		for k in 11:
			if not _ren() and _rng.randf() < 0.45:
				continue
			var z := 2.4 + (bay * 30 + 2 + k * 2.5) * V
			_stick(brands[bay], Vector3(W - 0.25, 0.02, z), -90, lean)
	# the barrel of Shorewood wood sticks at the end of the rack
	_barrel(Vector3(W - 0.4, 0, 8.75), "wood", 9, false, 91)


## A wooden barrel of sticks (or broken ones).
func _barrel(at: Vector3, brand: String, count: int, broken: bool, seed: int) -> void:
	var m := VoxelModel.new(V)
	var wood := Color("8a5a30")
	for y in 12:
		for x in 9:
			for z in 9:
				var dx := x - 4.0
				var dz := z - 4.0
				var r2 := dx * dx + dz * dz
				var bulge := 18.0 + (2.0 if y > 3 and y < 9 else 0.0)
				if r2 <= bulge and (r2 > 9.0 or y == 0):
					var c := wood.darkened(0.15 * (x % 2))
					if y == 2 or y == 9:
						c = Wear.RUST_DARK if not _ren() else Wear.STEEL  # hoops
					m.set_voxel(x, y, z, c)
	_put(m.set_pivot(4.5, 0, 4.5), at, 0, true, seed)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	for i in count:
		var off := Vector3(r.randf_range(-0.12, 0.12), 0.08, r.randf_range(-0.12, 0.12))
		var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), deg_to_rad(r.randf_range(3, 12)))
		if broken:
			_broken_stick(at + off, tilt, r)
		else:
			_stick(brand, at + off, r.randf_range(0, 360), tilt)


func _broken_stick(at: Vector3, tilt: Basis, r: RandomNumberGenerator) -> void:
	var b: String = ["honest", "kodiak", "warlock", "wood", "wood"][r.randi() % 5]
	var p := _brand(b)
	var m := VoxelModel.new(Models.STICK_V)
	var len := r.randi_range(30, 62)
	m.box(0, 0, 0, 2, len, 2, p.shaft)
	m.box(0, len - 18, 0, 2, 3, 2, p.band)
	# a jagged break at the top: splinters for wood, frayed carbon otherwise
	m.set_voxel(0, len, 0, p.shaft.lightened(0.25))
	m.set_voxel(1, len + 1, 1, p.shaft.lightened(0.25))
	m.set_voxel(1, len + 2, 0, p.shaft.lightened(0.35))
	if b == "wood":
		m.set_voxel(0, len + 3, 1, Color("e2c08a"))
	if r.randf() < 0.5:
		# taped butt end at the bottom of the barrel isn't seen; tape the grip anyway
		m.box(0, 0, 0, 2, 4, 2, Models.TAPE_DARK)
	if r.randf() < 0.35:
		# or it's the blade end, upside down
		for x in range(0, 12):
			m.box(x, len, 0, 1, 4, 1, Models.TAPE if x % 2 == 0 else Models.TAPE_DARK)
	Wear.weather(m, Wear.WORN, len)
	var mi := MeshInstance3D.new()
	mi.mesh = m.set_pivot(1, 0, 1).build_mesh()
	mi.transform = Transform3D(tilt * Basis(Vector3.UP, r.randf() * TAU), at)
	_world.add_child(mi)


func _broken_barrel() -> void:
	_barrel(Vector3(0.95, 0, 0.6), "", 14, true, 95)
	var s := _sign(["BROKEN", "STICKS"], 0.02, Wear.PLYWOOD, Color("2a1d14"), 2)
	_put(s, Vector3(0.95, 0.12, 0.27), 0, true, 96)


func _used_rack() -> void:
	# a bucket of used sticks and a crate of old skates by the front left
	var m := VoxelModel.new(V)
	var pail := Wear.OLD_ORANGE if not _ren() else Wear.TEAL
	for y in 9:
		for x in 7:
			for z in 7:
				var dx := x - 3.0
				var dz := z - 3.0
				var r2 := dx * dx + dz * dz
				if r2 <= 10.5 and (r2 > 4.5 or y == 0):
					m.set_voxel(x, y, z, pail if y != 7 else pail.darkened(0.3))
	_put(m.set_pivot(3.5, 0, 3.5), Vector3(W - 0.45, 0, 1.35), 0, true, 100)
	var r := RandomNumberGenerator.new()
	r.seed = 101
	for i in 6:
		var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), deg_to_rad(r.randf_range(6, 16)))
		_stick(["wood", "honest", "wood", "kodiak", "wood", "warlock"][i], Vector3(W - 0.45 + r.randf_range(-0.08, 0.08), 0.06, 1.35 + r.randf_range(-0.08, 0.08)), r.randf_range(0, 360), tilt)
	var s := _sign(["USED"], 0.035, Wear.PAPER, Wear.RED.darkened(0.15), 2)
	_put(s, Vector3(W - 0.02, 1.6, 1.35), 90, true, 102)
	var crate := VoxelModel.new(V)
	crate.box(0, 0, 0, 8, 5, 7, Wear.PLYWOOD)
	crate.clear_box(1, 1, 1, 6, 4, 5)
	for z in [1, 3, 5]:
		crate.box(0, 2, z, 1, 1, 1, Wear.PLYWOOD.darkened(0.4))
	_put(crate, Vector3(W - 0.95, 0, 0.35), 0, true, 103)
	var a := _skate(LEATHER, Models.TAPE)
	_put(a, Vector3(W - 0.88, 0.1, 0.4), 0, true, 104)
	var b := _skate(Color("1b1b1d"), Wear.OLD_GOLD)
	_put(b, Vector3(W - 0.7, 0.13, 0.42), 10, true, 105)


# ---------------------------------------------------------------- Old Bertha

func _sharpening() -> void:
	# half wall across the back, with the old sign painted on it
	var hw := VoxelModel.new(V)
	var hw_w := 52
	hw.box(0, 0, 0, hw_w, 11, 3, Wear.OLD_WOOD_DARK if not _ren() else Wear.NAVY)
	hw.box(-1, 11, -1, hw_w + 2, 1, 5, Wear.OLD_ORANGE if not _ren() else Wear.WHITE)
	_put(hw.set_pivot(hw_w * 0.5, 0, 0), Vector3(0, 0, 9.55), 0, true, 110)
	var lines := ["SKATES SHARPENED", "OPINIONS FREE"]
	var skip := {1: [3]} if not _ren() else {}  # a letter worn off
	var s := _sign(lines, 0.026, Wear.OLD_CREAM if not _ren() else Wear.WHITE, Wear.OLD_ORANGE.darkened(0.25) if not _ren() else Wear.RED, 3, skip)
	_put(s, Vector3(0, 0.1, 9.53), 0, true, 111)
	# Old Bertha: cast-iron pedestal, table, wheel guard, motor, skate on the jig
	var m := VoxelModel.new(V)
	m.box(2, 0, 2, 12, 1, 8, CAST_IRON.darkened(0.2))  # foot
	m.box(4, 1, 3, 8, 12, 6, CAST_IRON)  # pedestal
	m.box(6, 6, 2, 4, 3, 1, Wear.OLD_CREAM)  # maker's plate, long gone maker
	m.box(0, 13, 1, 16, 2, 9, CAST_IRON.lightened(0.08))  # table
	m.box(0, 15, 6, 16, 1, 2, Wear.OLD_STEEL)  # carriage rails
	# wheel guard: a half drum on the left of the table
	for y in 8:
		for z in 8:
			var dy := y - 0.0
			var dz := z - 3.5
			if dy * dy + dz * dz <= 16.5:
				m.box(11, 15 + y, 1 + z, 3, 1, 1, Color("c8642a") if not _ren() else Wear.RED)
	m.box(12, 15, 4, 1, 3, 2, Color("8d9194"))  # the wheel, where it shows
	m.box(14, 15, 3, 3, 4, 5, Color("2a3530"))  # motor
	m.box(17, 16, 4, 1, 2, 3, Wear.OLD_STEEL)
	# the skate holder jig on the carriage
	m.box(4, 16, 6, 6, 2, 2, Wear.OLD_STEEL.darkened(0.2))
	m.box(6, 18, 6, 2, 2, 2, Wear.OLD_STEEL.darkened(0.2))
	# dust bag hanging off the back
	m.box(12, 4, 9, 4, 9, 3, Color("b8ab8a"))
	m.box(13, 13, 9, 2, 2, 2, Color("8a7f66"))
	Wear.rust(m, CAST_IRON, 0.08, 7)
	var bertha := Node3D.new()
	bertha.position = Vector3(0, 0, 10.8)
	bertha.scale = Vector3.ONE * 1.35
	_world.add_child(bertha)
	_put(m.set_pivot(8, 0, 5), Vector3.ZERO, 0, true, 112, bertha)
	# the skate clamped in the jig, toe to the wheel
	var sk := _skate(Color("1b1b1d"), Wear.OLD_GOLD)
	_put(sk, Vector3(-0.24, 18 * V, 0.13), 90, true, 113, bertha)
	# sparks off the wheel, towards the front
	for i in 12:
		var t := float(i) / 12.0
		var sp := _box_mesh(Vector3.ONE * 0.02, Vector3(0.22 + sin(i * 2.3) * 0.06 + t * 0.1, 1.08 + sin(t * PI) * 0.12 - t * 0.2, -0.05 - t * 0.45), Color("ffc850"), 8.0)
		bertha.add_child(sp.duplicate())
		sp.queue_free()
	# Bev's gooseneck lamp on the table
	var lamp := VoxelModel.new(V * 0.5)
	lamp.box(0, 0, 0, 3, 1, 3, Color("2a3530"))
	lamp.box(1, 1, 1, 1, 8, 1, Color("2a3530"))
	lamp.box(1, 9, 1, 1, 1, 4, Color("2a3530"))
	lamp.box(0, 6, 4, 3, 3, 3, Wear.OLD_GOLD)
	_put(lamp, Vector3(-0.5, 15 * V, 0.0), 0, true, 114, bertha)
	var bulb := _box_mesh(Vector3(0.05, 0.03, 0.05), Vector3(-0.45, 15 * V + 0.18, 0.18), Color(1.0, 0.85, 0.6), 6.0)
	bertha.add_child(bulb.duplicate())
	bulb.queue_free()
	# a stool for Bev, a dressing stone, a stack of skates waiting
	var st := VoxelModel.new(V)
	st.box(0, 9, 0, 5, 1, 5, Wear.OLD_ORANGE)
	for c in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 4)]:
		st.box(c.x, 0, c.y, 1, 9, 1, Wear.OLD_STEEL)
	_put(st, Vector3(-0.95, 0, 10.0), 0, true, 115)
	for i in 3:
		var w := _skate([LEATHER, Color("1b1b1d"), Color("e9e5da")][i], [Wear.OLD_GOLD, Wear.RED, Color("2f5d8a")][i])
		_put(w, Vector3(-1.45 + i * 0.05, i * 0.18 + 0.0, 11.0 + i * 0.03), 90 + i * 12, true, 116 + i)
	# chalkboard of hollows and Bev's opinions of them
	var cb := VoxelModel.new(0.02)
	var cw := 68
	var ch := 60
	cb.box(0, 0, 0, cw, ch, 1, CHALKBOARD)
	cb.box(0, 0, 1, cw, ch, 1, Wear.OLD_WOOD_DARK)
	for x in cw:
		cb.set_voxel(x, 0, 0, Wear.OLD_WOOD)
		cb.set_voxel(x, ch - 1, 0, Wear.OLD_WOOD)
	for y in ch:
		cb.set_voxel(0, y, 0, Wear.OLD_WOOD)
		cb.set_voxel(cw - 1, y, 0, Wear.OLD_WOOD)
	var rows := ["HOLLOWS", "3/8 BRAVE", "1/2 FINE", "5/8 RIGHT", "1 GOALIES", "$5 EACH"]
	for i in rows.size():
		text(cb, rows[i], cw - 4, ch - 4 - i * 9, -1, CHALK if i != 0 else Wear.OLD_GOLD)
	cb.set_pivot(cw * 0.5, 0, 2)
	_put(cb, Vector3(1.85, 0.95, D - 0.01), 0, false)
	# the shop sign on the back wall
	var name_sign := _sign(["BEV'S EDGE & TAPE"], 0.036, Wear.OLD_ORANGE if not _ren() else Wear.NAVY, Wear.OLD_CREAM if not _ren() else Wear.WHITE, 3, {0: [10]} if not _ren() else {})
	for x in range(-1, text_w("BEV'S EDGE & TAPE") + 7):
		name_sign.set_voxel(x, -1, 0, Wear.OLD_BROWN if not _ren() else Wear.RED)
	_put(name_sign, Vector3(-0.6, 2.25, D - 0.01), 0, true, 120)


# ---------------------------------------------------------------- back corners

func _stick_bench() -> void:
	var m := VoxelModel.new(V)
	var bw := 22
	m.box(0, 13, 0, bw, 2, 9, Wear.OLD_WOOD)  # top
	for c in [Vector2i(0, 0), Vector2i(bw - 1, 0), Vector2i(0, 8), Vector2i(bw - 1, 8)]:
		m.box(c.x, 0, c.y, 1, 13, 1, Wear.OLD_WOOD_DARK)
	m.box(0, 3, 0, bw, 1, 9, Wear.OLD_WOOD_DARK)  # lower shelf
	# vice
	m.box(2, 15, 0, 4, 3, 3, Color("3d5a7a"))
	m.box(3, 15, -1, 2, 2, 1, Wear.OLD_STEEL)
	# heat gun (orange) and a steam box for wood sticks
	m.box(9, 15, 2, 4, 2, 2, Wear.OLD_ORANGE)
	m.box(9, 15, 4, 1, 3, 1, Color("2a2a2a"))
	m.box(14, 15, 1, 7, 4, 7, Wear.PLYWOOD.darkened(0.15))
	m.box(15, 19, 2, 5, 1, 5, Wear.PLYWOOD)
	m.box(16, 20, 4, 1, 3, 1, Wear.OLD_STEEL)  # steam pipe
	# bin of plugs on the shelf
	m.box(3, 4, 2, 5, 3, 5, Wear.OLD_AVOCADO)
	for x in range(4, 7):
		m.set_voxel(x, 7, 4, Models.PUCK)
	# pegboard above with a hacksaw and tools
	for x in bw:
		for y in range(16, 40):
			m.set_voxel(x, y, 9, Color("8b6a45") if (x + y) % 3 != 0 else Color("5e4630"))
	m.box(3, 30, 8, 8, 1, 1, Wear.OLD_STEEL)  # hacksaw blade
	m.box(3, 30, 8, 1, 4, 1, Color("3d5a7a"))
	m.box(10, 30, 8, 1, 4, 1, Color("3d5a7a"))
	m.box(3, 33, 8, 8, 1, 1, Color("3d5a7a"))
	m.box(14, 26, 8, 1, 7, 1, Wear.OLD_WOOD)  # file
	m.box(17, 24, 8, 2, 8, 1, Wear.OLD_STEEL.darkened(0.2))  # rasp
	m.box(5, 22, 8, 1, 5, 1, Wear.RED.darkened(0.3))  # screwdriver
	_put(m, Vector3(W - bw * V - 0.05, 0, D - 9 * V - 0.02), 0, true, 130)
	# a stick in the vice, half cut
	_stick("wood", Vector3(W - 0.15, 1.0, D - 0.45), 0, Basis(Vector3.BACK, deg_to_rad(84.0)))


func _goalie_corner() -> void:
	# a rail with leg pads hanging and a shelf of masks on the back wall
	var m := VoxelModel.new(V)
	var gw := 30
	m.box(0, 26, 0, gw, 1, 3, Wear.OLD_WOOD)  # mask shelf
	m.box(0, 22, 1, gw, 1, 1, Wear.OLD_STEEL)  # pad rail
	m.box(0, 22, 0, 1, 5, 3, Wear.OLD_WOOD_DARK)
	m.box(gw - 1, 22, 0, 1, 5, 3, Wear.OLD_WOOD_DARK)
	_put(m, Vector3(-W + 0.05, 0, D - 3 * V - 0.01), 0, true, 140)
	var pads := 2 if not _ren() else 4
	for i in pads:
		for side in 2:
			var p := VoxelModel.new(V)
			var face: Color = PAD_TAN if not _ren() else [Wear.WHITE, Wear.NAVY, Wear.RED, Wear.WHITE][i]
			p.box(0, 0, 0, 4, 13, 2, face)
			for y in [3, 6, 9]:
				p.box(0, y, -1, 4, 1, 1, face.darkened(0.25))  # rolls
			p.box(0, 11, -1, 4, 2, 1, Wear.OLD_CREAM if not _ren() else Wear.RED)  # knee roll
			p.box(1, 13, 1, 2, 1, 1, Wear.RUBBER)  # strap over the rail
			_put(p, Vector3(-W + 0.15 + i * 0.62 + side * 0.28, 22 * V - 13 * V, D - 0.12), 0, true, 141 + i * 2 + side)
	var masks := 2 if not _ren() else 5
	for i in masks:
		var mk := VoxelModel.new(H)
		var c := Wear.OLD_CREAM if (not _ren() or i % 2 == 0) else Wear.WHITE
		mk.box(0, 0, 0, 7, 9, 3, c)
		mk.clear_box(0, 8, 0, 1, 1, 3)
		mk.clear_box(6, 8, 0, 1, 1, 3)
		mk.box(1, 5, 0, 2, 1, 1, Color("1a1a1a"))  # eyes
		mk.box(4, 5, 0, 2, 1, 1, Color("1a1a1a"))
		for x in [2, 4]:
			for y in [1, 2]:
				mk.set_voxel(x, y, 0, Color("1a1a1a"))  # breathing holes
		if not _ren() and i == 1:
			mk.box(3, 2, 0, 1, 7, 1, Wear.RED.darkened(0.2))  # stitch marks
		_put(mk, Vector3(-W + 0.25 + i * 0.36, 27 * V, D - 0.18), 0, true, 150 + i)
	# a goalie stick leaning in the corner and a blocker on the floor
	var gs := Models.stick(Models.palette(1), true)
	Wear.weather(gs, Wear.WORN, 3)
	var gm := MeshInstance3D.new()
	gm.mesh = gs.build_mesh()
	gm.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(-12)) * Basis(Vector3.UP, deg_to_rad(90)), Vector3(-W + 0.12, 0, D - 0.75))
	_world.add_child(gm)
	var bk := VoxelModel.new(H)
	bk.box(0, 0, 0, 8, 2, 11, PAD_TAN if not _ren() else Wear.NAVY)
	bk.box(2, 2, 3, 4, 2, 5, LEATHER)
	_put(bk, Vector3(-3.2, 0, D - 1.0), 30, true, 160)


# ---------------------------------------------------------------- clutter

func _clutter() -> void:
	# helmet table between the door and the bins
	var t := VoxelModel.new(V)
	t.box(0, 10, 0, 14, 1, 10, Wear.OLD_WOOD if not _ren() else Wear.WHITE)
	for c in [Vector2i(0, 0), Vector2i(13, 0), Vector2i(0, 9), Vector2i(13, 9)]:
		t.box(c.x, 0, c.y, 1, 10, 1, Wear.OLD_STEEL)
	_put(t, Vector3(0.9, 0, 2.2), 0, true, 200)
	var hcols := [Color("1b1b1d"), Color("e9e5da"), Color("b5312a"), Color("2f5d8a")]
	if _ren():
		hcols = [Wear.NAVY, Wear.WHITE, Wear.RED, Wear.CHARCOAL]
	var spots := [Vector2(1.05, 2.3), Vector2(1.45, 2.32), Vector2(1.25, 2.6), Vector2(1.6, 2.62)]
	for i in (3 if not _ren() else 4):
		var h := VoxelModel.new(H)
		var c: Color = hcols[i]
		h.box(0, 0, 0, 7, 4, 8, c)
		h.box(1, 4, 1, 5, 1, 6, c)
		h.box(0, 1, 0, 7, 1, 1, Color("1a1a1a"))  # brim
		h.box(0, 0, 3, 1, 3, 2, Color("1a1a1a"))  # ear holes
		h.box(6, 0, 3, 1, 3, 2, Color("1a1a1a"))
		h.clear_box(1, 0, 1, 5, 2, 6)
		_put(h, Vector3(spots[i].x, 11 * V, spots[i].y), _rng.randf_range(-30, 30), true, 201 + i)
	# a rack of club jerseys by the bench
	var jr := VoxelModel.new(V)
	jr.box(0, 0, 0, 1, 24, 1, Wear.OLD_STEEL)
	jr.box(0, 24, -12, 1, 1, 25, Wear.OLD_STEEL)
	jr.box(0, 0, 12, 1, 24, 1, Wear.OLD_STEEL)
	jr.box(-3, 0, -12, 7, 1, 1, Wear.OLD_STEEL)
	jr.box(-3, 0, 12, 7, 1, 1, Wear.OLD_STEEL)
	_put(jr, Vector3(-1.3, 0, 8.4), 0, true, 210)
	var jcols := [[Color("c8191e"), Color("ece7dc")], [Color("1f4f9a"), Color("d6a321")], [Wear.OLD_GOLD, Color("5b3a22")], [Color("2e6b3a"), Color("ece7dc")], [Color("c8191e"), Color("19191c")]]
	for i in 5:
		if not _ren() and i == 2:
			continue
		var j := VoxelModel.new(V)
		var a: Color = jcols[i][0]
		var b: Color = jcols[i][1]
		j.box(0, 0, 0, 1, 10, 7, a)
		j.box(0, 6, -2, 1, 4, 2, a)  # sleeves
		j.box(0, 6, 7, 1, 4, 2, a)
		j.box(0, 2, 0, 1, 1, 7, b)  # hem stripes
		j.box(0, 6, -2, 1, 1, 2, b)
		j.box(0, 6, 7, 1, 1, 2, b)
		j.box(0, 10, 3, 1, 1, 1, Wear.OLD_STEEL)  # hanger
		_put(j, Vector3(-1.3 + (i - 2) * 0.05, 13 * V, 8.4 - 0.25 + (i - 2) * 0.12), 0, true, 211 + i)
	# cardboard shipping boxes, a trash can and the radiator that clanks
	var cb := VoxelModel.new(V)
	var card := Color("b88a55")
	cb.box(0, 0, 0, 9, 6, 7, card)
	cb.box(1, 6, 1, 7, 5, 6, card.darkened(0.08))
	cb.box(0, 0, 3, 9, 6, 1, Color("c9a46a"))  # tape seam
	cb.box(2, 11, 2, 5, 1, 1, Wear.PAPER)
	_put(cb, Vector3(-3.55, 0, 3.0), -8, true, 220)
	var cb2 := VoxelModel.new(V)
	cb2.box(0, 0, 0, 8, 5, 6, card)
	cb2.box(0, 5, 0, 8, 1, 2, card.lightened(0.1))  # flap open
	_put(cb2, Vector3(-2.2, 0, 11.3), 12, true, 221)
	var tc := MeshInstance3D.new()
	tc.mesh = Props.mesh("trash_can", _age)
	tc.position = Vector3(-3.3, 0, 9.9)
	_world.add_child(tc)
	if not _ren():
		var r := VoxelModel.new(V)
		for x in 16:
			r.box(x, 1, 0, 1, 10, 3, Wear.OLD_CREAM if x % 2 == 0 else Wear.OLD_CREAM.darkened(0.25))
		r.box(0, 0, 0, 1, 1, 3, Wear.OLD_STEEL)
		r.box(15, 0, 0, 1, 1, 3, Wear.OLD_STEEL)
		r.box(-1, 2, 1, 1, 1, 1, Wear.OLD_STEEL)
		Wear.rust(r, Wear.OLD_CREAM.darkened(0.25), 0.2, 3)
		_put(r, Vector3(2.0, 0, 0.05), 0, true, 222)


# ---------------------------------------------------------------- light

func _lights() -> void:
	# the fluorescent fixture: two tubes, one lit, one flickering out
	var fx := VoxelModel.new(V)
	fx.box(0, -1, 0, 1, 2, 5, Wear.OLD_CREAM)  # end caps
	fx.box(19, -1, 0, 1, 2, 5, Wear.OLD_CREAM)
	fx.box(1, 0, 2, 18, 1, 1, Wear.OLD_CREAM)  # spine; the tubes show either side
	if not _ren():
		_put(fx.set_pivot(10, 0, 2.5), Vector3(-0.4, 2.75, 4.2), 0, true, 170)
		for k in 2:
			var cm := VoxelModel.new(V)
			cm.box(0, 0, 0, 1, 9, 1, Wear.OLD_STEEL.darkened(0.2))
			_put(cm, Vector3(-0.9 + k * 1.0, 2.8, 4.2), 0, false)
		_box_mesh(Vector3(1.18, 0.05, 0.05), Vector3(-0.4, 2.7, 4.12), Color(0.8, 0.95, 1.0), 9.0)
		var dead := _box_mesh(Vector3(1.18, 0.05, 0.05), Vector3(-0.4, 2.7, 4.28), Color(0.55, 0.55, 0.52), 0.0)
		dead.name = "dead_tube"
		# the flickering end glows a little pink
		_box_mesh(Vector3(0.12, 0.052, 0.052), Vector3(0.13, 2.7, 4.28), Color(0.95, 0.75, 0.8), 1.5)
		_omni(Vector3(-0.4, 2.5, 4.2), Color(0.7, 0.9, 1.0), 2.2, 6.5, true)
		# warm light: a bulb over the counter, a lamp over Bertha, the arena across the lot
		_bulb(Vector3(-2.4, 2.6, 1.8))
		_bulb(Vector3(2.9, 2.5, 11.0))
		_omni(Vector3(-2.4, 2.4, 1.8), Color(1.0, 0.7, 0.4), 1.4, 5.5, true)
		_omni(Vector3(-0.5, 1.9, 10.2), Color(1.0, 0.68, 0.38), 2.0, 4.5, true)
		_omni(Vector3(2.9, 2.3, 10.8), Color(1.0, 0.7, 0.4), 0.9, 4.0, false)
		_omni(Vector3(0.0, 1.2, -1.5), Color(1.0, 0.72, 0.35), 1.0, 5.5, false)  # sodium glow through the door
		_omni(Vector3(-3.0, 2.2, 6.5), Color(1.0, 0.74, 0.45), 0.8, 5.0, false)
		_omni(Vector3(3.0, 2.0, 5.0), Color(1.0, 0.74, 0.45), 0.8, 5.0, false)
	else:
		for z in [2.2, 5.0, 7.8]:
			for x in [-2.0, 2.0]:
				_box_mesh(Vector3(0.5, 0.03, 0.5), Vector3(x, 2.95, z), Wear.LED, 2.0)
				_omni(Vector3(x, 2.7, z), Color(1.0, 0.97, 0.92), 1.0, 6.0, x < 0 and z == 5.0)


func _bulb(at: Vector3) -> void:
	var cord := VoxelModel.new(V)
	cord.box(0, 0, 0, 1, int((CEIL - at.y) / V), 1, Color("2a2a2a"))
	_put(cord, at + Vector3(-V * 0.5, 0.05, -V * 0.5), 0, false)
	_box_mesh(Vector3(0.08, 0.1, 0.08), at, Color(1.0, 0.82, 0.55), 5.0)


func _omni(at: Vector3, c: Color, energy: float, rng: float, shadow: bool) -> void:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = c
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 0.8
	o.shadow_enabled = shadow
	_world.add_child(o)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c1814") if not _ren() else Color("1d2230")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.86, 0.7) if not _ren() else Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58.0, 160.0, 0.0)
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 0.35
	key.shadow_enabled = true
	_world.add_child(key)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 45.0
	_world.add_child(cam)
	cam.look_at_from_position(Vector3(0.2, 9.6, -4.6), Vector3(0.0, 0.2, 6.0))
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		root.get_texture().get_image().save_png(_out)
		print("pro shop preview saved to ", _out)
		return true
	return false
