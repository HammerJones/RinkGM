class_name OnIceArt
extends RefCounted
## Voxel-box meshes for the on-ice gear: pucks (black and the light blue
## learn-to-play ones), pylons, mini nets, divider pads, a broomball, puck
## buckets, rental skates and the racks by the Zamboni doors. Pivots on the
## floor; nets open toward -Z with the frame behind (+Z), like Models.net().
##
##   var m := OnIceArt.mesh("pylon")

const ORANGE := Color("ff6a1a")
const PUCK_BLACK := Color("121214")
const PUCK_BLUE := Color("4fa3e0")
const NET_RED := Color("d0202a")
const MESH_WHITE := Color("efede6")
const PAD_BLACK := Color("1b1c1f")
const STEEL := Color("a3a9ae")
const WOOD := Color("7a5c3c")
const RACK := Color("5e6a71")
const BALL := Color("ff7a1a")

static var _cache := {}


static func mesh(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	if id == "full_net":
		_cache[id] = Models.net().build_mesh()
		return _cache[id]
	var b := VoxelMeshBuilder.new()
	match id:
		"puck_black": _puck(b, PUCK_BLACK)
		"puck_blue": _puck(b, PUCK_BLUE)
		"pylon": _pylon(b)
		"mini_net": _mini_net(b)
		"pad": _pad(b)
		"ball": _ball(b)
		"bucket": _bucket(b)
		"skates": _skates(b, Color("1d3557"))
		"skates_kid": _skates(b, Color("8a2f2f"))
		"rack_gear": _rack_gear(b)
		"rack_pads": _rack_pads(b)
		"return_rack": _return_rack(b)
		_: _box(b, Vector3(0, 0.1, 0), Vector3(0.2, 0.2, 0.2), Color.MAGENTA)
	var m := b.commit(VoxelMeshBuilder.material())
	_cache[id] = m
	return m


static func _box(b: VoxelMeshBuilder, c: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	b.add_box(Transform3D(basis.scaled(size), c), col)


static func _puck(b: VoxelMeshBuilder, col: Color) -> void:
	_box(b, Vector3(0, 0.0127, 0), Vector3(0.076, 0.0254, 0.05), col)
	_box(b, Vector3(0, 0.0127, 0), Vector3(0.05, 0.0254, 0.076), col)


static func _pylon(b: VoxelMeshBuilder) -> void:
	_box(b, Vector3(0, 0.01, 0), Vector3(0.24, 0.02, 0.24), ORANGE.darkened(0.15))
	var h := 0.02
	for i in 6:
		var w := lerpf(0.17, 0.05, float(i) / 5.0)
		var col := MESH_WHITE if i == 3 else ORANGE
		_box(b, Vector3(0, h + 0.025, 0), Vector3(w, 0.05, w), col)
		h += 0.05


static func _mini_net(b: VoxelMeshBuilder) -> void:
	var w := 1.22
	var h := 0.9
	var d := 0.6
	var t := 0.04
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(sx * w * 0.5, h * 0.5, 0), Vector3(t, h, t), NET_RED)               # posts
		_box(b, Vector3(sx * w * 0.5, 0.02, d * 0.5), Vector3(t, t, d), NET_RED)            # base sides
		_box(b, Vector3(sx * w * 0.5, h * 0.5, d * 0.5), Vector3(0.01, h * 0.9, d), MESH_WHITE)  # side mesh
	_box(b, Vector3(0, h, 0), Vector3(w, t, t), NET_RED)                                    # crossbar
	_box(b, Vector3(0, 0.02, d), Vector3(w, t, t), NET_RED)                                 # back base
	_box(b, Vector3(0, h * 0.5, d), Vector3(w, h * 0.9, 0.01), MESH_WHITE)                  # back mesh
	_box(b, Vector3(0, h - 0.02, d * 0.5), Vector3(w, 0.01, d), MESH_WHITE)                 # top mesh


static func _pad(b: VoxelMeshBuilder) -> void:
	var L: float = OnIceData.section("peewee").get("pad_length", 4.3)
	_box(b, Vector3(0, 0.14, 0), Vector3(L - 0.04, 0.28, 0.32), PAD_BLACK)
	_box(b, Vector3(0, 0.285, 0), Vector3(L - 0.1, 0.01, 0.2), PAD_BLACK.lightened(0.12))
	for i in 3:
		_box(b, Vector3((i - 1) * L * 0.33, 0.15, -0.165), Vector3(0.18, 0.08, 0.01), Color("d9a62e"))  # handles


static func _ball(b: VoxelMeshBuilder) -> void:
	_box(b, Vector3(0, 0.08, 0), Vector3(0.16, 0.12, 0.12), BALL)
	_box(b, Vector3(0, 0.08, 0), Vector3(0.12, 0.16, 0.12), BALL)
	_box(b, Vector3(0, 0.08, 0), Vector3(0.12, 0.12, 0.16), BALL)


static func _bucket(b: VoxelMeshBuilder) -> void:
	_box(b, Vector3(0, 0.18, 0), Vector3(0.3, 0.36, 0.3), Color("e8e4da"))
	_box(b, Vector3(0, 0.37, 0), Vector3(0.26, 0.02, 0.26), PUCK_BLACK)  # pucks in it
	_box(b, Vector3(0, 0.42, 0), Vector3(0.32, 0.015, 0.02), Color("39424e"))  # handle


static func _skates(b: VoxelMeshBuilder, col: Color) -> void:
	for sx in [-0.06, 0.06]:
		_box(b, Vector3(sx, 0.02, 0), Vector3(0.012, 0.04, 0.27), STEEL)
		_box(b, Vector3(sx, 0.07, 0.01), Vector3(0.09, 0.06, 0.27), col)
		_box(b, Vector3(sx, 0.14, 0.06), Vector3(0.085, 0.12, 0.13), col)
		_box(b, Vector3(sx, 0.11, -0.06), Vector3(0.07, 0.03, 0.1), Color("e8e4da"))  # laces


static func _rack_gear(b: VoxelMeshBuilder) -> void:
	# a steel shelf with pylon stacks and puck buckets
	for x in [-0.6, 0.6]:
		for z in [-0.25, 0.25]:
			_box(b, Vector3(x, 0.55, z), Vector3(0.04, 1.1, 0.04), RACK)
	for y in [0.3, 0.75]:
		_box(b, Vector3(0, y, 0), Vector3(1.25, 0.03, 0.55), RACK.lightened(0.1))
	for i in 3:
		var x := -0.4 + i * 0.4
		for k in 4:
			_box(b, Vector3(x, 0.78 + 0.03 + k * 0.05, 0), Vector3(0.16 - k * 0.02, 0.05, 0.16 - k * 0.02), ORANGE)


static func _rack_pads(b: VoxelMeshBuilder) -> void:
	# an A-frame of pipe with the divider pads hung over it
	var L: float = OnIceData.section("peewee").get("pad_length", 4.3)
	for x in [-L * 0.5 + 0.1, L * 0.5 - 0.1]:
		_box(b, Vector3(x, 0.55, 0), Vector3(0.05, 1.1, 0.05), RACK)
		_box(b, Vector3(x, 0.03, 0), Vector3(0.06, 0.06, 0.8), RACK)
	_box(b, Vector3(0, 1.1, 0), Vector3(L, 0.05, 0.05), RACK)


static func _return_rack(b: VoxelMeshBuilder) -> void:
	# a wooden rack of size-labelled pegs for returned rentals
	_box(b, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 0.06), WOOD)
	for y in [0.35, 0.65, 0.95]:
		_box(b, Vector3(0, y, -0.12), Vector3(1.35, 0.03, 0.22), WOOD.lightened(0.12))
		for i in 7:
			_box(b, Vector3(-0.6 + i * 0.2, y + 0.06, -0.2), Vector3(0.05, 0.03, 0.02), Color("e8c547"))
	for x in [-0.68, 0.68]:
		_box(b, Vector3(x, 0.03, -0.12), Vector3(0.06, 0.06, 0.4), WOOD.darkened(0.2))
