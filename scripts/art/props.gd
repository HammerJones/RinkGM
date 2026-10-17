class_name Props
extends RefCounted
## The props kit: everything in the building that isn't the ice, the players
## or the boards. Each prop comes in three renovation ages (Wear.WORN,
## Wear.REPAIRED, Wear.RENOVATED). Rink environment places them and picks the
## age; this file decides how they look.
##
## Props share the character voxel size so they sit in the same world. Every
## prop has its pivot at the floor, centred, with its front facing -Z.
##
##   var mesh := Props.mesh("door", Wear.WORN)   # cached, share it freely

const V := Models.V

## Every prop id. Add new props here and in _build().
const IDS := ["arena_seat", "door", "light", "vending_machine", "trash_can", "rink_sign", "resurfacer"]

static var _cache := {}


static func ids() -> Array:
	return IDS


static func model(id: String, age: int) -> VoxelModel:
	var m := _build(id, age)
	if m == null:
		push_error("Props: unknown prop '%s'" % id)
		return null
	return Wear.weather(m, age, hash(id))


static func _build(id: String, age: int) -> VoxelModel:
	match id:
		"arena_seat": return _arena_seat(age)
		"door": return _door(age)
		"light": return _light(age)
		"vending_machine": return _vending_machine(age)
		"trash_can": return _trash_can(age)
		"rink_sign": return _rink_sign(age)
		"resurfacer": return _resurfacer(age)
	return null


## One mesh per (id, age), built on first use. Many seats share one mesh.
static func mesh(id: String, age: int) -> ArrayMesh:
	var key := "%s/%d" % [id, age]
	if not _cache.has(key):
		var m := model(id, age)
		_cache[key] = m.build_mesh() if m else null
	return _cache[key]


# ---------------------------------------------------------------- seating

## One arena seat. Old: painted wooden slats on cast-iron sides. New: a
## moulded navy seat on a steel pedestal with a cup holder.
static func _arena_seat(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	if age == Wear.RENOVATED:
		m.box(3, 0, 1, 2, 6, 3, Wear.STEEL)  # pedestal
		m.box(1, 0, 0, 6, 1, 5, Wear.STEEL)
		m.box(0, 6, 0, 8, 1, 6, Wear.NAVY)  # seat pan
		m.box(0, 7, 0, 8, 1, 1, Wear.NAVY)  # front lip
		m.box(0, 7, 5, 8, 4, 1, Wear.NAVY)  # back, curving back as it rises
		m.box(0, 11, 6, 8, 3, 1, Wear.NAVY)
		m.box(1, 13, 6, 6, 1, 1, Wear.WHITE)  # seat number plate
		m.box(-2, 7, 1, 2, 1, 2, Wear.CHARCOAL)  # cup holder
		m.set_voxel(-2, 8, 1, Wear.CHARCOAL).set_voxel(-1, 8, 2, Wear.CHARCOAL)
		return m.set_pivot(4, 0, 3)
	var paint := Wear.OLD_ORANGE
	var iron := Wear.OLD_STEEL.darkened(0.35)
	for x in [0, 7]:
		m.box(x, 0, 0, 1, 1, 7, iron)  # feet
		m.box(x, 1, 3, 1, 5, 1, iron)
		m.box(x, 6, 0, 1, 1, 7, iron)  # arm rails
		m.box(x, 7, 6, 1, 7, 1, iron)
	var slats := [1, 3, 5]
	for i in slats.size():
		var z: int = slats[i]
		var c := paint
		if age == Wear.REPAIRED and i == 1:
			c = Wear.NEW_WOOD  # replacement plank, never painted
		m.box(1, 6, z, 6, 1, 1, c)
	var backs := [8, 10, 12]
	for i in backs.size():
		var y: int = backs[i]
		if age == Wear.WORN and i == 1:
			continue  # missing back slat
		m.box(1, y, 6, 6, 1, 1, paint)
	if age == Wear.WORN:
		# paint worn through to the wood where people sit
		for p in [Vector3i(3, 6, 3), Vector3i(4, 6, 3), Vector3i(4, 6, 1), Vector3i(2, 12, 6), Vector3i(5, 8, 6)]:
			m.set_voxel(p.x, p.y, p.z, Wear.OLD_WOOD)
		Wear.rust(m, iron, 0.25)
	return m.set_pivot(4, 0, 3.5)


# ---------------------------------------------------------------- doors

## A single 0.9 x 2.1 m door in its frame. Old: steel door in institutional
## mint with a wired-glass window. New: a glass door in a charcoal frame.
static func _door(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 14
	var h := 32
	if age == Wear.RENOVATED:
		m.box(-1, 0, 0, 1, h + 1, 2, Wear.CHARCOAL)
		m.box(w, 0, 0, 1, h + 1, 2, Wear.CHARCOAL)
		m.box(-1, h, 0, w + 2, 1, 2, Wear.CHARCOAL)
		m.box(0, 0, 1, w, 2, 1, Wear.CHARCOAL)  # kick rail
		m.box(0, 2, 1, w, h - 4, 1, Wear.GLASS)
		m.box(0, h - 2, 1, w, 2, 1, Wear.CHARCOAL)
		for x in range(1, w - 1, 3):
			m.set_voxel(x, h - 6, 1, Wear.GLASS_DARK)  # frosted band
		m.box(0, 22, 1, w, 1, 1, Wear.RED)
		m.box(2, 14, 0, w - 4, 1, 1, Wear.STEEL)  # push bar
		return m.set_pivot(w * 0.5, 0, 1)
	var frame := Wear.OLD_BROWN
	m.box(-1, 0, 0, 1, h + 1, 2, frame)
	m.box(w, 0, 0, 1, h + 1, 2, frame)
	m.box(-1, h, 0, w + 2, 1, 2, frame)
	m.box(0, 0, 1, w, h, 1, Wear.OLD_MINT)
	m.box(0, 0, 0, w, 5, 1, Wear.OLD_STEEL)  # kick plate
	# wired-glass window
	for x in range(3, w - 3):
		for y in range(20, 28):
			var wire := x % 3 == 0 or y % 3 == 0
			m.set_voxel(x, y, 1, Wear.OLD_STEEL if wire else Wear.GLASS_DARK)
	m.box(w - 3, 14, 0, 2, 1, 1, Wear.OLD_STEEL)  # handle
	if age == Wear.WORN:
		Wear.rust(m, Wear.OLD_STEEL, 0.3, 3)
		for p in [Vector3i(5, 9, 1), Vector3i(6, 10, 1), Vector3i(8, 7, 1)]:
			m.set_voxel(p.x, p.y, p.z, Wear.OLD_MINT.darkened(0.3))  # dents
	else:
		# a cracked pane boarded over, a new chrome handle
		m.box(3, 22, 0, w - 6, 5, 1, Wear.PLYWOOD)
		m.box(w - 3, 14, 0, 2, 1, 1, Wear.STEEL)
	return m.set_pivot(w * 0.5, 0, 1)


# ---------------------------------------------------------------- lighting

## A ceiling light, hanging from its cable. Pivot is the ceiling mount.
## Old: a sodium high-bay dome. New: a flat LED panel.
static func _light(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	if age == Wear.RENOVATED:
		m.box(4, 0, 2, 1, 6, 1, Wear.CHARCOAL)
		m.box(10, 0, 2, 1, 6, 1, Wear.CHARCOAL)
		m.box(0, -1, 0, 15, 1, 5, Wear.CHARCOAL)
		m.box(1, -2, 1, 13, 1, 3, Wear.LED)
		m.set_pivot(7.5, 6, 2.5)
		return m
	var dome := Wear.OLD_STEEL
	var bulb := Wear.SODIUM_DIM if age == Wear.WORN else Wear.SODIUM
	m.box(4, 0, 4, 1, 8, 1, Wear.CHARCOAL)  # cable
	m.box(3, -2, 3, 3, 2, 3, dome)  # ballast
	m.box(1, -4, 1, 7, 2, 7, dome)
	m.box(0, -6, 0, 9, 2, 9, dome)
	m.clear_box(1, -6, 1, 7, 1, 7)
	m.box(2, -5, 2, 5, 1, 5, bulb)
	if age == Wear.WORN:
		Wear.rust(m, dome, 0.2, 5)
	return m.set_pivot(4.5, 8, 4.5)


# ---------------------------------------------------------------- concessions

## A drinks machine. Old: burnt-orange 70s cabinet with a selection column
## and an OUT OF ORDER note. New: charcoal with a lit glass front.
static func _vending_machine(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 14
	var h := 28
	var d := 11
	if age == Wear.RENOVATED:
		m.box(0, 0, 0, w, h, d, Wear.CHARCOAL)
		m.box(1, 4, 0, 9, h - 6, 1, Wear.GLASS_DARK)
		var cans := [Wear.RED, Wear.TEAL, Wear.WHITE, Wear.NAVY, Color("f2b134")]
		for row in 5:
			for col in 4:
				m.set_voxel(2 + col * 2, 6 + row * 4, 0, cans[(row + col) % cans.size()])
		m.box(0, h - 2, 0, w, 1, 1, Wear.TEAL)  # LED strip
		m.box(11, 14, 0, 2, 4, 1, Wear.RUBBER)  # card reader
		m.set_voxel(11, 16, 0, Wear.TEAL)
		m.box(1, 1, 0, 9, 2, 1, Wear.RUBBER)  # pickup slot
		return m.set_pivot(w * 0.5, 0, d * 0.5)
	m.box(0, 0, 0, w, h, d, Wear.OLD_ORANGE)
	m.box(0, h - 6, 0, w, 5, 1, Wear.OLD_GOLD)  # brand panel
	for x in range(2, 12, 3):
		m.box(x, h - 5, 0, 2, 3, 1, Wear.OLD_CREAM)  # bottle-cap logo dots
	m.box(1, 6, 0, 8, 14, 1, Wear.CHARCOAL)  # dark window
	for row in 4:
		for col in 3:
			m.set_voxel(2 + col * 3, 8 + row * 3, 0, Wear.OLD_BROWN.lightened(0.15))
	for i in 6:
		var y := 18 - i * 2
		var missing := age == Wear.WORN and i == 2
		m.set_voxel(11, y, 0, Wear.RUBBER if missing else Wear.OLD_CREAM)
	m.box(11, 5, 0, 1, 2, 1, Wear.OLD_STEEL)  # coin slot
	m.box(1, 1, 0, 8, 3, 1, Wear.RUBBER)
	m.box(0, 0, 0, w, 1, d, Wear.OLD_STEEL)
	if age == Wear.WORN:
		m.box(2, 10, -1, 5, 4, 1, Wear.PAPER)  # OUT OF ORDER
		m.box(3, 12, -1, 3, 1, 1, Wear.RED.darkened(0.2))
		Wear.rust(m, Wear.OLD_STEEL, 0.4, 9)
		Wear.rust(m, Wear.OLD_ORANGE, 0.03, 9)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## A bin. Old: a dented avocado drum. Repaired: a tape band where it split.
## New: a navy and teal waste/recycling pair.
static func _trash_can(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	if age == Wear.RENOVATED:
		m.box(0, 0, 0, 7, 13, 7, Wear.NAVY)
		m.box(8, 0, 0, 7, 13, 7, Wear.TEAL)
		m.box(0, 13, 0, 15, 1, 7, Wear.STEEL)
		m.box(2, 13, 0, 3, 1, 2, Wear.RUBBER)  # slots
		m.box(10, 13, 0, 3, 1, 2, Wear.RUBBER)
		m.box(2, 8, -1, 3, 3, 1, Wear.WHITE)  # labels
		m.box(10, 8, -1, 3, 3, 1, Wear.WHITE)
		return m.set_pivot(7.5, 0, 3.5)
	var drum := Wear.OLD_AVOCADO
	for y in 14:
		for x in 8:
			for z in 8:
				var dx := x - 3.5
				var dz := z - 3.5
				if dx * dx + dz * dz <= 16.5:
					m.set_voxel(x, y, z, drum)
	for y in [3, 10]:
		for x in 8:
			for z in 8:
				if m.voxels.has(Vector3i(x, y, z)):
					m.voxels[Vector3i(x, y, z)] = drum.darkened(0.25)  # ribs
	m.clear_box(1, 13, 1, 6, 1, 6)  # open top
	if age == Wear.WORN:
		m.clear_box(1, 6, 0, 2, 2, 1)  # dent
		m.box(1, 6, 1, 2, 2, 1, drum.darkened(0.4))
		Wear.rust(m, drum.darkened(0.25), 0.35, 13)
	else:
		for x in 8:
			for z in 8:
				if m.voxels.has(Vector3i(x, 6, z)) or m.voxels.has(Vector3i(x, 7, z)):
					m.voxels[Vector3i(x, 6, z)] = Wear.DUCT_TAPE
					m.voxels[Vector3i(x, 7, z)] = Wear.DUCT_TAPE
		m.clear_box(1, 6, 1, 6, 2, 6)
	return m.set_pivot(4, 0, 4)


# ---------------------------------------------------------------- signage

const _GLYPHS := {
	"R": ["110", "101", "110", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"N": ["101", "111", "111", "111", "101"],
	"K": ["101", "110", "100", "110", "101"],
	"E": ["111", "100", "110", "100", "111"],
	"C": ["011", "100", "100", "100", "011"],
	"A": ["010", "101", "111", "101", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"M": ["101", "111", "111", "101", "101"],
	"U": ["101", "101", "101", "101", "111"],
	"T": ["111", "010", "010", "010", "010"],
	"Y": ["101", "101", "010", "010", "010"],
	" ": ["000", "000", "000", "000", "000"],
}


## Writes text in a 3x5 voxel font on the plane z, readable from the front
## (-Z). (x, y) is the top-left of the first letter as the viewer sees it,
## which is its highest x, since +X is the viewer's left.
## `skip` lists letter indexes to leave off (letters that fell down).
static func letters(m: VoxelModel, text: String, x: int, y: int, z: int, c: Color, skip := []) -> void:
	for i in text.length():
		if i in skip:
			continue
		var g: Array = _GLYPHS.get(text[i], _GLYPHS[" "])
		for row in 5:
			for col in 3:
				if g[row][col] == "1":
					m.set_voxel(x - i * 4 - col, y - row, z, c)


## The board over the main entrance. Old: hand-painted "RINK" with a letter
## gone. Repaired: the N repainted in a slightly wrong red. New: a charcoal
## box sign with red letters and bulb trim.
static func _rink_sign(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 25
	var h := 11
	if age == Wear.RENOVATED:
		m.box(0, 0, 0, w, h, 2, Wear.CHARCOAL)
		for x in range(0, w, 2):
			m.set_voxel(x, h - 1, -1, Wear.LED)
			m.set_voxel(x, 0, -1, Wear.LED)
		letters(m, "RINK", 19, 7, -1, Wear.RED)
		return m.set_pivot(w * 0.5, 0, 1)
	m.box(0, 0, 0, w, h, 1, Wear.OLD_CREAM)
	m.box(0, 0, 1, w, h, 1, Wear.OLD_WOOD_DARK)
	m.box(-1, -1, 0, w + 2, 1, 1, Wear.OLD_BROWN)
	m.box(-1, h, 0, w + 2, 1, 1, Wear.OLD_BROWN)
	if age == Wear.WORN:
		letters(m, "RINK", 19, 7, -1, Wear.RED.darkened(0.25), [2])
		# the ghost of the missing N, where the paint stayed cleaner
		letters(m, "  N ", 19, 7, 0, Wear.OLD_CREAM.lightened(0.25))
	else:
		letters(m, "RI K", 19, 7, -1, Wear.RED.darkened(0.25))
		letters(m, "  N ", 19, 7, -1, Color("e0403a"))
	return m.set_pivot(w * 0.5, 0, 0.5)


# ---------------------------------------------------------------- ice

## The ice resurfacer, about 2 x 4 m. Front (driver end) faces -Z.
## Old: a boxy cream machine with an exhaust stack. New: electric, white
## with club stripes and no stack.
static func _resurfacer(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 28
	var l := 58
	var new := age == Wear.RENOVATED
	var body := Wear.WHITE if new else Wear.OLD_CREAM
	var stripe := Wear.RED if new else Color("3d6fb0")
	var trim := Wear.NAVY if new else Wear.OLD_STEEL
	# chassis and wheels
	m.box(1, 3, 2, w - 2, 4, l - 4, Wear.CHARCOAL)
	for z in [8, l - 14]:
		m.box(0, 0, z, 3, 8, 8, Wear.RUBBER)
		m.box(w - 3, 0, z, 3, 8, 8, Wear.RUBBER)
		m.box(0, 3, z + 3, 3, 2, 2, trim)
		m.box(w - 3, 3, z + 3, 3, 2, 2, trim)
	# snow tank: the big box over the back two thirds
	m.box(1, 7, 18, w - 2, 16, l - 22, body)
	m.box(1, 12, 18, w - 2, 2, l - 22, stripe)
	m.box(1, 23, 18, w - 2, 1, l - 22, body.darkened(0.08))
	# cab: low nose with the seat and wheel
	m.box(1, 7, 0, w - 2, 7, 18, body)
	m.box(1, 12, 0, w - 2, 2, 18, stripe)
	m.box(8, 14, 6, 12, 2, 6, Wear.CHARCOAL)  # seat
	m.box(8, 16, 11, 12, 6, 1, Wear.CHARCOAL)
	m.box(12, 14, 2, 4, 4, 1, Wear.CHARCOAL)  # steering column
	m.box(10, 18, 1, 8, 1, 3, Wear.RUBBER)  # wheel
	# conditioner at the back
	m.box(0, 3, l - 4, w, 5, 4, trim)
	m.box(1, 2, l - 3, w - 2, 1, 2, Wear.STEEL)
	if new:
		m.box(w - 4, 15, 0, 3, 2, 1, Wear.LED)  # headlights
		m.box(1, 15, 0, 3, 2, 1, Wear.LED)
	else:
		m.box(w - 5, 14, 14, 2, 18, 2, Wear.CHARCOAL)  # exhaust stack
		m.box(w - 4, 15, 0, 3, 2, 1, Wear.SODIUM)
		m.box(1, 15, 0, 3, 2, 1, Wear.SODIUM)
		if age == Wear.WORN:
			Wear.rust(m, trim, 0.12, 17)
			Wear.rust(m, body, 0.02, 17)
		else:
			m.box(1, 15, 30, 1, 6, 10, Wear.WHITE)  # replacement side panel
	return m.set_pivot(w * 0.5, 0, l * 0.5)
