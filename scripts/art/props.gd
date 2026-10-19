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
##   var far := Props.mesh("arena_seat", Wear.WORN, 1)   # low detail
##
## Doors also come as two parts so the leaf can swing: "door_frame" (same
## pivot as "door") and "door_leaf", whose pivot is its hinge. Put the leaf at
## DOOR_HINGE in the frame's space.

const V := Models.V

## Every prop id. Add new props here and in _build().
const IDS := [
	"arena_seat", "door", "light", "vending_machine", "trash_can", "rink_sign", "resurfacer",
	"lockers", "player_bench", "penalty_box", "glass_frame", "glass_pane", "concession_counter",
	"scoreboard",
	# the refrigeration plant room (plant_props.gd)
	"compressor_recip", "compressor_screw", "compressor_co2", "chiller", "receiver",
	"glycol_pump", "glycol_tank", "header",
	"pipe_glycol", "pipe_glycol_elbow", "pipe_glycol_valve",
	"pipe_refrig", "pipe_refrig_elbow", "pipe_refrig_valve",
	"condenser", "control_panel", "ammonia_detector", "eyewash_station",
	# the rec wing's workshop, electrical room, weight room and storage (shop_props.gd)
	"workbench", "toolbox", "drill_press", "arbor_press", "knee_mill", "lathe", "bench_grinder",
	"shop_vac", "pegboard", "clamp_rack", "cord_hooks",
	"switchgear", "breaker_panel", "transformer", "meter_bank", "fire_panel", "fire_extinguisher", "step_ladder",
	"bench_press", "squat_rack", "leg_press", "cable_crossover", "lat_pulldown", "dumbbell_rack",
	"plate_tree", "stationary_bike", "treadmill", "slide_board",
	"ball_bin", "pylon_stack", "mini_net", "spare_net", "puck_bucket", "goalie_pads", "broom_bin",
	"skate_cones", "hockey_bags",
]

## The plant room builders live in their own file.
const Plant := preload("res://scripts/art/plant_props.gd")
## So do the rec wing's working rooms (workshop, electrical, weights, storage).
const Shop := preload("res://scripts/art/shop_props.gd")

## Penalty box size in voxels: 4.3 m along the boards, a 1 m door gap.
const PENALTY_BOX_W := 66
const PENALTY_DOOR_W := 16

static var _glass := {}

## Where the door leaf's hinge sits in the door frame's local space (metres).
const DOOR_HINGE := Vector3(7 * Models.V, 0, 0)
const _DOOR_W := 14
const _DOOR_H := 32

static var _cache := {}


static func ids() -> Array:
	return IDS


static func model(id: String, age: int) -> VoxelModel:
	if id == "door_frame" or id == "door_leaf":
		return _door_part(id == "door_leaf", age)
	var m := _build(id, age)
	if m == null:
		push_error("Props: unknown prop '%s'" % id)
		return null
	return Wear.weather(m, age, hash(id))


## Splits the weathered door into its frame and its leaf.
static func _door_part(leaf: bool, age: int) -> VoxelModel:
	var whole := model("door", age)
	var part := VoxelModel.new(whole.voxel_size)
	part.jitter = whole.jitter
	for p in whole.voxels:
		var in_frame: bool = p.x < 0 or p.x >= _DOOR_W or p.y >= _DOOR_H
		if in_frame != leaf:
			part.voxels[p] = whole.voxels[p]
	if leaf:
		return part.set_pivot(_DOOR_W, 0, 1)  # hinge edge, on the viewer's left
	part.pivot = whole.pivot
	return part


static func _build(id: String, age: int) -> VoxelModel:
	match id:
		"arena_seat": return _arena_seat(age)
		"door": return _door(age)
		"light": return _light(age)
		"vending_machine": return _vending_machine(age)
		"trash_can": return _trash_can(age)
		"rink_sign": return _rink_sign(age)
		"resurfacer": return _resurfacer(age)
		"lockers": return _lockers(age)
		"player_bench": return _player_bench(age)
		"penalty_box": return _penalty_box(age)
		"glass_frame": return _glass_frame(age)
		"glass_pane": return _glass_pane(age)
		"concession_counter": return _concession_counter(age)
		"scoreboard": return _scoreboard(age)
	var m := Plant.build(id, age)
	return m if m else Shop.build(id, age)


## Big one-offs whose flat panels would cost too many faces with per-voxel
## speckle: full detail keeps their rust and grime but merges the faces.
const _MERGED := ["resurfacer"]


## Collision boxes that follow a prop's shape (a bench's seat and back, not
## one box around the whole bench), in the mesh's space. Cached per
## (id, age). See VoxelModel.collision_boxes().
static func collision_boxes(id: String, age: int) -> Array[AABB]:
	var key := "col/%s/%d" % [id, age]
	if not _cache.has(key):
		var m := model(id, age)
		var boxes: Array[AABB] = []
		if m:
			boxes = m.collision_boxes(_COLLISION_CELL.get(id, Shop.COLLISION_CELL.get(id, 2)))
		_cache[key] = boxes
	return _cache[key]


## Coarser collision for big props whose detail doesn't matter to a body.
const _COLLISION_CELL := {"resurfacer": 4, "condenser": 4, "scoreboard": 4, "compressor_co2": 3}


## Adds a prop's collision boxes to `body` (any CollisionObject3D), placed by
## `xf` in the body's space. Returns the shapes added.
static func add_collision(body: CollisionObject3D, id: String, age: int, xf := Transform3D.IDENTITY) -> Array[CollisionShape3D]:
	var added: Array[CollisionShape3D] = []
	for b in collision_boxes(id, age):
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b.size
		cs.shape = shape
		cs.transform = xf * Transform3D(Basis.IDENTITY, b.get_center())
		body.add_child(cs)
		added.append(cs)
	return added


## One mesh per (id, age, lod), built on first use. Many seats share one mesh.
## lod 0 is full detail; lod 1 drops the speckle and merges flat faces, for
## big repeats (stands of seats) and distance.
static func mesh(id: String, age: int, lod := 0) -> ArrayMesh:
	var key := "%s/%d/%d" % [id, age, lod]
	if not _cache.has(key):
		Wear.fine = lod == 0
		var m := model(id, age)
		Wear.fine = true
		if m == null:
			_cache[key] = null
		elif lod == 0 and not id in _MERGED and not id in Plant.MERGED and not id in Shop.MERGED:
			_cache[key] = m.build_mesh()
		else:
			_cache[key] = m.build_mesh_merged()
		if id == "glass_pane" and _cache[key]:
			_cache[key].surface_set_material(0, glass_material(age))
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
	var w := _DOOR_W
	var h := _DOOR_H
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

## 5x7 capitals, big enough to read across the rink.
const _GLYPHS := {
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}
const GLYPH_ADVANCE := 6


## Writes text in a 5x7 voxel font on the plane z, readable from the front
## (-Z). (x, y) is the top-left of the first letter as the viewer sees it,
## which is its highest x, since +X is the viewer's left. Paint letters into
## a surface (same z as the board) so ageing doesn't chip them; raised
## letters sit in front of it.
## `skip` lists letter indexes to leave off (letters that fell down).
static func letters(m: VoxelModel, text: String, x: int, y: int, z: int, c: Color, skip := []) -> void:
	for i in text.length():
		if i in skip:
			continue
		var g: Array = _GLYPHS.get(text[i], _GLYPHS[" "])
		for row in 7:
			for col in 5:
				if g[row][col] == "1":
					m.set_voxel(x - i * GLYPH_ADVANCE - col, y - row, z, c)


## The board over the main entrance. Old: hand-painted "RINK" with a letter
## gone. Repaired: the N repainted in a slightly wrong red. New: a charcoal
## box sign with red letters and bulb trim.
static func _rink_sign(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 27
	var h := 11
	if age == Wear.RENOVATED:
		m.box(0, 0, 0, w, h, 2, Wear.CHARCOAL)
		for x in range(0, w, 2):
			m.set_voxel(x, h - 1, -1, Wear.LED)
			m.set_voxel(x, 0, -1, Wear.LED)
		letters(m, "RINK", 24, 8, -1, Wear.RED)
		return m.set_pivot(w * 0.5, 0, 1)
	m.box(0, 0, 0, w, h, 1, Wear.OLD_CREAM)
	m.box(0, 0, 1, w, h, 1, Wear.OLD_WOOD_DARK)
	m.box(-1, -1, 0, w + 2, 1, 1, Wear.OLD_BROWN)
	m.box(-1, h, 0, w + 2, 1, 1, Wear.OLD_BROWN)
	if age == Wear.WORN:
		# painted into the board; the N has peeled off, leaving a cleaner ghost
		letters(m, "  N ", 24, 8, 0, Wear.OLD_CREAM.lightened(0.3))
		letters(m, "RINK", 24, 8, 0, Wear.RED.darkened(0.25), [2])
	else:
		letters(m, "RI K", 24, 8, 0, Wear.RED.darkened(0.25))
		letters(m, "  N ", 24, 8, 0, Color("e0403a"))
	return m.set_pivot(w * 0.5, 0, 0.5)


# ---------------------------------------------------------------- ice

## The ice resurfacer, a Zambelli Model 525 (see the lore): the classic boxy
## gas machine, about 1.9 x 3.6 m and 2 m tall. Front faces -Z. The tall snow
## tank fills the front two thirds; behind it the driver sits up on the
## machine's left (low x) with the engine cowl on the right, and the
## conditioner and towel drag behind. Old: cream with a blue band and an
## exhaust stack. Repaired: a mismatched cowl panel and a taped seat. New: a
## restored machine in the club colours with LED lights and a beacon.
static func _resurfacer(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var new := age == Wear.RENOVATED
	var body := Wear.WHITE if new else Wear.OLD_CREAM
	var band := Wear.NAVY if new else Color("3d6fb0")
	var pin := Wear.RED if new else Color("2b4f86")
	var trim := Wear.STEEL if new else Wear.OLD_STEEL
	var tank_end := 33   # back wall of the snow tank
	var rear_end := 47   # back of the operator deck and engine cowl
	# wheels and frame
	for z in [5, 34]:
		for x in [0, 25]:
			m.box(x, 0, z, 3, 9, 9, Wear.RUBBER)
			m.box(x, 3, z + 3, 3, 3, 3, trim)  # hubs
	m.box(3, 2, 2, 22, 4, rear_end - 2, Wear.CHARCOAL)
	# lower body over the water tank, set back under the nose
	m.box(1, 6, 4, 26, 5, rear_end - 4, body)
	# snow tank: the tall box at the front, its lower front stepped back
	m.box(1, 15, 0, 26, 15, tank_end, body)
	m.box(1, 11, 2, 26, 4, tank_end - 2, body)
	for x in [1, 26]:
		m.clear_box(x, 29, 0, 1, 1, tank_end)  # rounded top edges
	m.clear_box(1, 15, 0, 26, 1, 1)  # chamfer where the nose steps back
	m.box(2, 30, 2, 24, 1, tank_end - 4, body.darkened(0.12))  # tank lid
	# the band and pinstripe round the tank
	m.box(1, 19, 0, 26, 3, tank_end, band)
	m.box(1, 23, 0, 26, 1, tank_end, pin)
	m.box(2, 20, -1, 24, 1, 1, band)
	# front badge: a Z on a panel
	m.box(8, 22, -1, 11, 7, 1, band)
	m.box(10, 27, -2, 7, 1, 1, body)
	m.box(10, 23, -2, 7, 1, 1, body)
	for p in [Vector2i(11, 26), Vector2i(12, 26), Vector2i(13, 25), Vector2i(14, 24), Vector2i(15, 24)]:
		m.set_voxel(p.x, p.y, -2, body)  # the diagonal, read from the front
	# headlights either side of the nose
	var lamp := Wear.LED if new else Wear.SODIUM
	m.box(2, 16, -1, 4, 2, 1, lamp)
	m.box(22, 16, -1, 4, 2, 1, lamp)
	# operator deck on the left: floor, dash, column, wheel and seat
	m.box(1, 11, tank_end, 13, 1, rear_end - tank_end, Wear.CHARCOAL)
	m.box(2, 12, tank_end, 11, 4, 1, Wear.CHARCOAL)  # dash on the tank wall
	m.box(7, 12, tank_end + 1, 1, 7, 1, Wear.CHARCOAL)  # steering column
	for p in [Vector2i(4, 1), Vector2i(4, 2), Vector2i(10, 1), Vector2i(10, 2), Vector2i(5, 0), Vector2i(9, 0), Vector2i(5, 3), Vector2i(9, 3)]:
		m.set_voxel(p.x, 19, tank_end + p.y, Wear.RUBBER)
	for x in range(6, 9):
		m.set_voxel(x, 19, tank_end, Wear.RUBBER)
		m.set_voxel(x, 19, tank_end + 3, Wear.RUBBER)
	var seat := Wear.NAVY if new else Wear.OLD_BROWN
	m.box(4, 12, 39, 7, 3, 5, Wear.CHARCOAL)  # seat box
	m.box(4, 15, 39, 7, 1, 5, seat)
	m.box(4, 16, 44, 7, 6, 1, seat)  # backrest
	# engine cowl on the right, with a vent grille
	m.box(14, 11, tank_end, 13, 11, rear_end - tank_end, body)
	m.box(14, 17, tank_end, 13, 2, rear_end - tank_end, band)
	for z in range(36, 45, 2):
		m.box(27, 12, z, 1, 4, 1, Wear.CHARCOAL)
	m.box(1, 6, rear_end, 26, 6, 1, body)  # rear guard
	# conditioner (the board that shaves, washes and lays water) and towel
	m.box(-1, 1, rear_end + 1, 30, 5, 4, trim)
	m.box(-1, 6, rear_end + 1, 30, 1, 4, trim.darkened(0.25))
	m.box(0, 0, rear_end + 2, 28, 1, 2, Wear.STEEL)  # blade
	m.box(1, 0, rear_end + 5, 26, 1, 3, Wear.PAPER if new else Wear.OLD_CREAM.darkened(0.2))
	if new:
		m.box(23, 22, 44, 2, 3, 2, Wear.CHARCOAL)  # beacon mast and light
		m.box(23, 25, 44, 2, 2, 2, Wear.SODIUM)
	else:
		m.box(23, 22, 43, 2, 13, 2, Wear.CHARCOAL)  # exhaust stack
		m.box(22, 34, 42, 4, 1, 4, Wear.CHARCOAL)
		if age == Wear.WORN:
			Wear.rust(m, trim, 0.15, 17)
			Wear.rust(m, body, 0.02, 17)
			m.box(3, 15, 39, 2, 1, 2, Wear.OLD_CREAM.darkened(0.3))  # seat foam showing
		else:
			m.box(14, 12, 38, 1, 5, 7, Wear.WHITE)  # replacement cowl panel
			m.box(6, 15, 40, 3, 1, 3, Wear.DUCT_TAPE)  # taped seat
	return m.set_pivot(14, 0, 27)


## See-through material for glass panes. Old glass is yellowed and scuffed,
## new glass is nearly clear.
static func glass_material(age: int) -> StandardMaterial3D:
	if not _glass.has(age):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, [0.55, 0.4, 0.22][age])
		m.roughness = [0.6, 0.35, 0.1][age]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass[age] = m
	return _glass[age]


# ---------------------------------------------------------------- dressing rooms

## A bank of three lockers, 1.2 m wide. Old: dented painted steel with vents
## and one door hanging open; repaired: a replacement locker in the wrong
## colour and padlocks. New: open wooden stalls with a navy back, a bench and
## hooks, like a pro dressing room.
static func _lockers(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var each := 6
	var w := each * 3
	var h := 28
	var d := 7
	if age == Wear.RENOVATED:
		m.box(0, 0, d - 1, w, h, 1, Wear.NAVY)
		m.box(0, h, 0, w, 1, d, Wear.NEW_WOOD)  # top shelf
		m.box(0, 20, 1, w, 1, d - 1, Wear.NEW_WOOD)
		for i in 4:
			m.box(i * each - (1 if i == 3 else 0), 0, 0, 1, h, d, Wear.NEW_WOOD)  # dividers
		m.box(0, 6, 0, w, 1, d - 1, Wear.NEW_WOOD)  # bench
		m.box(0, 0, 0, w, 1, d - 1, Wear.CHARCOAL)
		for i in 3:
			m.box(i * each + 3, 16, d - 2, 1, 1, 1, Wear.STEEL)  # hooks
			m.box(i * each + 2, 24, d - 2, 3, 2, 1, Wear.WHITE)  # name plate
		return m.set_pivot(w * 0.5, 0, d * 0.5)
	for i in 3:
		var c := Wear.OLD_MINT
		if age == Wear.REPAIRED and i == 1:
			c = Wear.OLD_ORANGE  # salvaged from another room
		var x := i * each
		m.box(x, 1, 0, each, h - 1, d, c)
		m.box(x, 1, 0, 1, h - 1, 1, c.darkened(0.3))  # door seam
		for y in [23, 21, 19]:
			m.box(x + 2, y, 0, 3, 1, 1, c.darkened(0.45))  # vents
		m.set_voxel(x + each - 2, 14, -1, Wear.OLD_STEEL)  # latch
		if age == Wear.REPAIRED:
			m.box(x + each - 2, 12, -2, 1, 2, 1, Color("c9a227"))  # padlock
	m.box(0, 0, 0, w, 1, d, Wear.CHARCOAL)  # plinth
	if age == Wear.WORN:
		# the middle door hangs open: clear it and stand it out at an angle
		m.clear_box(each, 1, 0, each, h - 1, 1)
		m.box(each + 1, 2, 1, each - 2, h - 4, 1, Wear.CHARCOAL)  # dark inside
		for k in each:
			m.box(each - 1 - k / 2, 2, -1 - k, 1, h - 3, 1, Wear.OLD_MINT)
		m.set_voxel(4, 9, 0, Wear.OLD_MINT.darkened(0.35))  # dents
		m.set_voxel(15, 6, 0, Wear.OLD_MINT.darkened(0.35))
		Wear.rust(m, Wear.OLD_STEEL, 0.5, 21)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


# ---------------------------------------------------------------- benches

## A 2 m section of the players' bench; line them up for the full bench.
## Old: a long plank on steel legs, scuffed by skates. New: a padded navy
## bench with a back rail and a rubber kick plate.
static func _player_bench(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 31
	var d := 6
	if age == Wear.RENOVATED:
		m.box(0, 0, 1, w, 6, d - 1, Wear.CHARCOAL)
		m.box(0, 0, 0, w, 3, 1, Wear.RUBBER)  # kick plate
		m.box(0, 6, 0, w, 2, d, Wear.NAVY)  # pad
		m.box(0, 7, d - 1, w, 1, 1, Wear.RED)
		m.box(0, 8, d, w, 6, 1, Wear.NAVY)  # back pad
		return m.set_pivot(w * 0.5, 0, d * 0.5)
	var legs := Wear.OLD_STEEL.darkened(0.3)
	for x in [1, 15, 29]:
		m.box(x, 0, 1, 1, 6, 1, legs)
		m.box(x, 0, d - 2, 1, 6, 1, legs)
	m.box(0, 6, 0, w, 1, d, Wear.OLD_WOOD)
	m.box(0, 6, 0, w, 1, 1, Wear.OLD_WOOD_DARK)  # front edge
	if age == Wear.WORN:
		for x in range(2, w, 4):
			m.set_voxel(x, 6, 0, Wear.CONCRETE)  # skate gouges
			m.set_voxel(x + 1, 6, 1, Wear.OLD_WOOD_DARK)
		Wear.rust(m, legs, 0.3, 31)
	else:
		m.box(10, 6, 0, 8, 1, d, Wear.NEW_WOOD)  # replaced plank
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## The penalty box: a 4.3 x 1.9 m booth along the boards, open to the ice
## (-Z) where the boards and gate are, with a 1 m door gap in the middle of
## the back wall (+Z) and a bench either side of it. Old: plywood walls under
## a hand-made SIN BIN plank. New: navy walls, padded benches, red trim.
static func _penalty_box(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := PENALTY_BOX_W
	var d := 29
	var h := 16  # wall height, level with the boards
	var gap := PENALTY_DOOR_W
	var g0 := (w - gap) / 2
	var new := age == Wear.RENOVATED
	var wall := Wear.NAVY if new else Wear.PLYWOOD.darkened(0.15)
	var top := Wear.RED if new else Wear.OLD_GOLD
	m.box(0, 0, 0, w, 1, d, Wear.RUBBER)  # rubber floor
	m.box(0, 1, d - 1, w, h, 1, wall)  # back wall...
	m.clear_box(g0, 1, d - 1, gap, h, 1)  # ...with the door gap
	m.box(0, 1, 0, 1, h, d - 1, wall)  # sides
	m.box(w - 1, 1, 0, 1, h, d - 1, wall)
	m.box(0, h + 1, 0, 1, 1, d, top)  # cap rails
	m.box(w - 1, h + 1, 0, 1, 1, d, top)
	m.box(0, h + 1, d - 1, g0, 1, 1, top)
	m.box(g0 + gap, h + 1, d - 1, w - g0 - gap, 1, 1, top)
	var bench := Wear.NAVY.lightened(0.15) if new else Wear.OLD_WOOD
	var base := Wear.CHARCOAL if new else Wear.OLD_WOOD_DARK
	for x0 in [1, g0 + gap + 1]:
		var bw := g0 - 2
		m.box(x0, 1, d - 7, bw, 6, 6, base)
		m.box(x0, 7, d - 7, bw, 1, 6, bench)
		if new:
			m.box(x0, 8, d - 2, bw, 5, 1, Wear.NAVY.lightened(0.15))  # back pad
	if not new:
		m.box(4, 11, d - 2, g0 - 6, 3, 1, Wear.OLD_CREAM)  # the old SIN BIN plank
		for x in range(6, g0 - 3, 2):
			m.set_voxel(x, 12, d - 3, Wear.RED.darkened(0.3))
		if age == Wear.WORN:
			m.box(g0 + gap + 8, 1, d - 1, 3, 4, 1, Wear.CHARCOAL)  # hole kicked in the wall
	else:
		m.box(1, 14, d - 2, g0 - 1, 1, 1, Wear.RED)
		m.box(g0 + gap, 14, d - 2, w - g0 - gap - 1, 1, 1, Wear.RED)
	return m.set_pivot(w * 0.5, 0, d * 0.5)


# ---------------------------------------------------------------- glass

const _GLASS_W := 28  # one 1.83 m panel
const _GLASS_H := 18  # 1.17 m above the boards


## The steel that holds one panel of glass on top of the boards: a stanchion
## on the panel's +X edge and the bottom channel. Its pivot is the top of the
## boards. Pair with "glass_pane". Old: painted posts with rusty bolts. New:
## seamless, just low clear clips, no posts.
static func _glass_frame(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	if age == Wear.RENOVATED:
		for x in [2, _GLASS_W - 3]:
			m.box(x, 0, -1, 2, 1, 3, Wear.STEEL)  # clips
		return m.set_pivot(_GLASS_W * 0.5, 0, 0.5)
	var post := Wear.OLD_GOLD if age == Wear.WORN else Wear.OLD_GOLD.lightened(0.1)
	m.box(0, 0, -1, _GLASS_W, 1, 3, Wear.OLD_STEEL)  # channel
	m.box(_GLASS_W - 1, 0, -1, 2, _GLASS_H + 1, 3, post)  # stanchion
	for y in [3, 9, 15]:
		m.set_voxel(_GLASS_W - 1, y, -2, Wear.OLD_STEEL)  # bolts
	if age == Wear.WORN:
		Wear.rust(m, Wear.OLD_STEEL, 0.5, 41)
	return m.set_pivot(_GLASS_W * 0.5, 0, 0.5)


## One pane of glass, drawn with glass_material(age). Old panes are yellowed
## with puck scuffs; the repaired one has a taped crack.
static func _glass_pane(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var tint := Wear.GLASS.lerp(Wear.OLD_CREAM, 0.5) if age != Wear.RENOVATED else Wear.GLASS
	m.box(0, 1, 0, _GLASS_W - 1, _GLASS_H - 1, 1, tint)
	if age != Wear.RENOVATED:
		for p in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(12, 7), Vector2i(19, 3), Vector2i(20, 5), Vector2i(9, 11)]:
			m.set_voxel(p.x, p.y, 0, tint.darkened(0.3))  # puck marks
	if age == Wear.REPAIRED:
		for i in 7:
			m.set_voxel(14 + i, 6 + i, -1, Wear.DUCT_TAPE)  # tape over a crack
	m.jitter = 0.0
	return m.set_pivot(_GLASS_W * 0.5, 0, 0.5)


# ---------------------------------------------------------------- concessions

## A 2.4 m concession counter. Old: wood-panel front, harvest-gold laminate
## top, a popcorn machine and a chunky cash register. New: navy front with a
## red band, white top, a glass display case and a card reader.
static func _concession_counter(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var w := 37
	var h := 16
	var d := 11
	if age == Wear.RENOVATED:
		m.box(0, 0, 0, w, h, d, Wear.NAVY)
		m.box(0, 12, 0, w, 1, 1, Wear.RED)
		m.box(0, 0, 0, w, 1, 1, Wear.CHARCOAL)
		m.box(-1, h, -1, w + 2, 1, d + 1, Wear.WHITE)
		m.box(2, h + 1, 1, 14, 5, 7, Wear.GLASS)  # display case
		m.box(3, h + 1, 2, 12, 1, 5, Wear.WHITE)
		for x in range(4, 15, 3):
			m.box(x, h + 2, 3, 2, 1, 2, Color("e3b04b"))  # pastries
		m.box(28, h + 1, 2, 3, 3, 2, Wear.CHARCOAL)  # card reader
		m.set_voxel(29, h + 3, 1, Wear.TEAL)
		return m.set_pivot(w * 0.5, 0, d * 0.5)
	m.box(0, 0, 0, w, h, d, Wear.OLD_WOOD)
	for x in range(0, w, 3):
		m.box(x, 1, 0, 1, h - 2, 1, Wear.OLD_WOOD_DARK)  # panel grooves
	m.box(0, 0, 0, w, 1, 1, Wear.OLD_BROWN)
	m.box(-1, h, -1, w + 2, 1, d + 1, Wear.OLD_GOLD)
	# popcorn machine: red cart, glass box of popcorn
	m.box(3, h + 1, 2, 9, 2, 7, Wear.RED.darkened(0.2))
	m.box(3, h + 3, 2, 9, 7, 7, Wear.GLASS)
	m.box(4, h + 3, 3, 7, 3, 5, Color("f3e3a2"))
	m.box(3, h + 10, 2, 9, 2, 7, Wear.RED.darkened(0.2))
	# cash register
	m.box(25, h + 1, 3, 8, 4, 6, Wear.OLD_STEEL.darkened(0.2))
	m.box(26, h + 5, 6, 6, 3, 2, Wear.OLD_STEEL.darkened(0.2))
	for x in range(26, 32, 2):
		m.set_voxel(x, h + 5, 4, Wear.OLD_CREAM)  # keys
	if age == Wear.WORN:
		for p in [Vector3i(7, h, -1), Vector3i(8, h, -1), Vector3i(20, h, -1), Vector3i(33, h, -1)]:
			m.set_voxel(p.x, p.y, p.z, Wear.OLD_WOOD_DARK)  # chipped laminate edge
		m.box(16, 6, -1, 5, 4, 1, Wear.PAPER)  # CASH ONLY note
		Wear.rust(m, Wear.OLD_STEEL.darkened(0.2), 0.15, 51)
	else:
		m.box(14, 2, 0, 9, h - 4, 1, Wear.PLYWOOD)  # patched front panel
	return m.set_pivot(w * 0.5, 0, d * 0.5)


# ---------------------------------------------------------------- scoreboard

## Old: a 6.5 x 3 m wooden cabinet on the end wall, pivot at its bottom
## centre, with a gold sponsor header and an unlit bulb grid behind the
## display. New: a centre-hung four-sided board about 5 m across and 3 m tall,
## hanging from its cables (pivot at the ceiling mount), LED trim and a red
## band round the bottom. The display areas are dark panels for
## RinkOS.sign_3d() text; scoreboard_faces(age) says where they are.
static func _scoreboard(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	if age == Wear.RENOVATED:
		var s := _HUNG_SIDE
		var h := _HUNG_H
		# shell: four walls, a top and a bottom
		m.box(0, 0, 0, s, h, s, Wear.CHARCOAL)
		m.clear_box(1, 1, 1, s - 2, h - 2, s - 2)
		m.box(0, 0, 0, s, 4, s, Wear.RED)  # bottom band
		m.clear_box(1, 0, 1, s - 2, 4, s - 2)
		m.box(1, 0, 1, s - 2, 1, s - 2, Wear.CHARCOAL)
		for f in 4:
			_hung_face(m, f, s, h)
		for c in [Vector2i(6, 6), Vector2i(s - 7, 6), Vector2i(6, s - 7), Vector2i(s - 7, s - 7)]:
			m.box(c.x, h, c.y, 1, _HUNG_CABLE, 1, Wear.STEEL)  # cables
		return m.set_pivot(s * 0.5, h + _HUNG_CABLE, s * 0.5)
	var w := _WALL_W
	var h := _WALL_H
	var d := 6
	m.box(0, 0, 0, w, h, d, Wear.OLD_BROWN)
	m.box(_WALL_INSET, _WALL_INSET, -1, w - 2 * _WALL_INSET, _WALL_DISPLAY_H, 1, Wear.RUBBER)
	m.box(2, h - 9, -1, w - 4, 7, 1, Wear.OLD_GOLD)  # sponsor header
	for x in range(6, w - 6, 4):
		m.box(x, h - 6, -2, 2, 1, 1, Wear.OLD_ORANGE)
	for x in range(_WALL_INSET + 1, w - _WALL_INSET, 2):
		for y in range(_WALL_INSET + 1, _WALL_INSET + _WALL_DISPLAY_H, 2):
			m.set_voxel(x, y, -1, Wear.SODIUM_DIM.darkened(0.6))  # unlit bulbs
	if age == Wear.WORN:
		m.box(w - 20, h - 9, -1, 9, 7, 1, Wear.CHARCOAL)  # header panel missing
	return m.set_pivot(w * 0.5, 0, d * 0.5)


## One face of the hung board: f 0..3 = -Z, +X, +Z, -X sides.
static func _hung_face(m: VoxelModel, f: int, s: int, h: int) -> void:
	for i in range(_HUNG_INSET, s - _HUNG_INSET):
		for y in range(6, h - 3):
			var c := Wear.RUBBER
			if y == h - 4:
				c = Wear.LED if i % 2 == 0 else Wear.CHARCOAL  # LED trim
			match f:
				0: m.set_voxel(i, y, -1, c)
				1: m.set_voxel(s, y, i, c)
				2: m.set_voxel(i, y, s, c)
				3: m.set_voxel(-1, y, i, c)


const _WALL_W := 100  # 6.5 m
const _WALL_H := 46  # 3 m
const _WALL_INSET := 4
const _WALL_DISPLAY_H := 31
const _HUNG_SIDE := 77  # 5 m
const _HUNG_H := 46  # 3 m
const _HUNG_INSET := 4
const _HUNG_CABLE := 12


## Where to put scoreboard text: one entry per display face, each with its
## centre and outward normal (metres, in the scoreboard's local space) and its
## size. Text goes on the plane through `center`, facing `normal`.
static func scoreboard_faces(age: int) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	if age != Wear.RENOVATED:
		var pw := float(_WALL_W - 2 * _WALL_INSET) * V
		var ph := float(_WALL_DISPLAY_H) * V
		faces.append({
			"center": Vector3(0, (_WALL_INSET + _WALL_DISPLAY_H * 0.5) * V, -4.0 * V),
			"normal": Vector3(0, 0, -1),
			"size": Vector2(pw, ph),
		})
		return faces
	var half := (_HUNG_SIDE * 0.5 + 1.0) * V
	var y := ((6 + _HUNG_H - 3 - 1) * 0.5 - _HUNG_H - _HUNG_CABLE) * V
	var size := Vector2((_HUNG_SIDE - 2 * _HUNG_INSET) * V, (_HUNG_H - 10) * V)
	for n in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
		faces.append({"center": Vector3(n.x * half, y, n.z * half), "normal": n, "size": size})
	return faces
