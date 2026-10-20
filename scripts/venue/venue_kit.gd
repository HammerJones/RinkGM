class_name VenueKit
extends RefCounted
## Builds one venue room: voxel blocks into a few merged meshes plus box
## colliders for walking. Every block is an axis-aligned box whose faces are
## cut into `tile`-sized squares, each with its own colour jitter, which gives
## the speckled voxel look without emitting hidden internal faces.
##
## Meshes: `solid` (lit, vertex colours), `glow` (unshaded, for lamps, LED
## strips and screens) and `glass` (transparent). Colliders go on one
## StaticBody3D on the VENUE_LAYER physics layer, so they never touch the
## custom hockey simulation.

const VENUE_LAYER := 2  # physics layer bit (layer 2 = "venue")
const MAX_TILES := 48   # per face axis, keeps huge walls cheap

static var _glow_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D

var rng := RandomNumberGenerator.new()
var age := VenueRoom.Age.WORN
var _solid := VoxelMeshBuilder.new()
var _glow := VoxelMeshBuilder.new()
var _glass := VoxelMeshBuilder.new()
var _shapes: Array[AABB] = []
var _signs: Array = []  # [VenueSign, Transform3D]
var _extra: Array[Node3D] = []
var _instances := {}  # ArrayMesh -> Array[Transform3D]
## Walls built while this is on also become occluders (one ArrayOccluder3D
## per room), so a walker in the recreation wing never draws the rooms
## behind the walls around them. Needs occlusion culling in the project.
var occlude_walls := false
var _occluders: Array[AABB] = []


func _init(seed_: int, age_: int) -> void:
	rng.seed = seed_
	age = age_


static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.vertex_color_use_as_albedo = true
		_glow_mat.vertex_color_is_srgb = true
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# brighter than white, so the environment's glow blooms the lamps
		_glow_mat.albedo_color = Look.lamp_glow()
	return _glow_mat


static func glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.vertex_color_use_as_albedo = true
		_glass_mat.vertex_color_is_srgb = true
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.roughness = 0.1
		_glass_mat.metallic_specular = 0.8
		_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass_mat


# ---------------------------------------------------------------- picking by age

## One value per age: worn, repaired, renovated.
func by_age(worn: Variant, repaired: Variant, renovated: Variant) -> Variant:
	return [worn, repaired, renovated][age]


## Ageing applied to a base colour: worn is faded and grimy, repaired is a
## patchwork of old and fresh, renovated is the clean colour.
func aged(c: Color, key: Variant = null) -> Color:
	match age:
		VenueRoom.Age.WORN:
			var grime := Color("5a5244")
			var out := c.lerp(grime, 0.32).darkened(0.08)
			if key != null and posmod(hash(key), 7) == 0:
				out = out.darkened(0.22)  # stain
			return out
		VenueRoom.Age.REPAIRED:
			if key != null and posmod(hash(key), 3) == 0:
				return c  # fresh patch
			return c.lerp(Color("6a6355"), 0.16)
	return c


# ---------------------------------------------------------------- geometry

## A solid block from corner `a` to corner `b` (any order). Collides unless
## `solid` is false.
func block(a: Vector3, b: Vector3, col: Color, tile := 0.5, jitter := 0.06, solid := true) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	_faces(_solid, lo, hi, col, tile, jitter)
	if solid:
		_shapes.append(AABB(lo, hi - lo))


## Block whose colour is aged per tile (stains and patches).
func aged_block(a: Vector3, b: Vector3, col: Color, tile := 0.5, jitter := 0.06, solid := true) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	_faces(_solid, lo, hi, col, tile, jitter, true)
	if solid:
		_shapes.append(AABB(lo, hi - lo))


## Emissive block (lamps, LED strips). Never collides.
func glow(a: Vector3, b: Vector3, col: Color) -> void:
	_faces(_glow, a.min(b), a.max(b), col, 100.0, 0.0)


## Transparent block (rink glass, windows). Collides unless told not to.
func glass(a: Vector3, b: Vector3, solid := true, tint := Color(0.78, 0.9, 0.95, 0.16)) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	_faces(_glass, lo, hi, tint, 100.0, 0.0)
	if solid:
		_shapes.append(AABB(lo, hi - lo))


## Collision only (an invisible railing, or the ice under the rink's own mesh).
func collider(a: Vector3, b: Vector3) -> void:
	_shapes.append(AABB(a.min(b), (a - b).abs()))


## Oriented box (for things off the grid, like rink glass on the corner
## curve or a leaning stick). Visual only.
func oriented(xf: Transform3D, col: Color, as_glass := false) -> void:
	(_glass if as_glass else _solid).add_box(xf, col)


## A floor or ceiling slab: only the top (or bottom) face is drawn, since the
## other faces are never seen. Collides.
func slab(a: Vector3, b: Vector3, col: Color, tile := 1.0, jitter := 0.05, bottom := false, solid := true) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	_faces(_solid, lo, hi, col, tile, jitter, true, 3 if bottom else 2)
	if solid:
		_shapes.append(AABB(lo, hi - lo))


## A wall along X at depth z (thickness t, centred on z) with door/window
## openings: each opening is {"at": x centre, "w": width, "y0": sill, "y1": head}.
func wall_x(z: float, x0: float, x1: float, y0: float, y1: float, t: float, col: Color, openings: Array = [], tile := 0.5) -> void:
	_wall(0, z, x0, x1, y0, y1, t, col, openings, tile)


## A wall along Z at x.
func wall_z(x: float, z0: float, z1: float, y0: float, y1: float, t: float, col: Color, openings: Array = [], tile := 0.5) -> void:
	_wall(2, x, z0, z1, y0, y1, t, col, openings, tile)


func _wall(axis: int, at: float, s0: float, s1: float, y0: float, y1: float, t: float, col: Color, openings: Array, tile: float) -> void:
	var lo := minf(s0, s1)
	var hi := maxf(s0, s1)
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p.at < q.at)
	var cursor := lo
	for o in cuts:
		var a: float = o.at - o.w * 0.5
		var b: float = o.at + o.w * 0.5
		if a > cursor:
			_wall_piece(axis, at, cursor, a, y0, y1, t, col, tile)
		# lintel and sill around the opening
		if o.y1 < y1:
			_wall_piece(axis, at, a, b, o.y1, y1, t, col, tile)
		if o.y0 > y0:
			_wall_piece(axis, at, a, b, y0, o.y0, t, col, tile)
		cursor = maxf(cursor, b)
	if cursor < hi:
		_wall_piece(axis, at, cursor, hi, y0, y1, t, col, tile)


func _wall_piece(axis: int, at: float, s0: float, s1: float, y0: float, y1: float, t: float, col: Color, tile: float) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var a := Vector3(s0, y0, at - t * 0.5) if axis == 0 else Vector3(at - t * 0.5, y0, s0)
	var b := Vector3(s1, y1, at + t * 0.5) if axis == 0 else Vector3(at + t * 0.5, y1, s1)
	aged_block(a, b, col, tile)
	if occlude_walls and s1 - s0 >= 1.0 and y1 - y0 >= 1.5:
		occluder(a, b)


## A box that hides what is behind it from the renderer (never drawn).
func occluder(a: Vector3, b: Vector3) -> void:
	_occluders.append(AABB(a.min(b), (a - b).abs()))


## A flight of steps rising along `dir` (unit X or Z, signed) from `start`
## (front-bottom-centre) up to `rise`, `width` wide. Each step is its own
## collider so a walker can climb it.
func stairs(start: Vector3, dir: Vector3, width: float, rise: float, steps: int, run: float, col: Color) -> void:
	var side := Vector3(dir.z, 0, dir.x).abs() * width * 0.5
	for i in steps:
		var h := rise * float(i + 1) / steps
		var a := start + dir * (run * i) - side
		var b := start + dir * (run * (i + 1)) + side + Vector3(0, h, 0)
		block(a, b, aged(col, i), 0.5, 0.05)


## A pixel-terminal sign placed by `xf` (its face looks along the transform's +Z).
func sign(s: VenueSign, xf: Transform3D) -> void:
	_signs.append([s, xf])


## A copy of a shared mesh (a Props kit piece). All copies of one mesh in a
## room become one MultiMesh draw. Visual only; add a collider if it's solid.
func instance(mesh: Mesh, xf: Transform3D) -> void:
	if mesh == null:
		return
	if not _instances.has(mesh):
		_instances[mesh] = []
	_instances[mesh].append(xf)


## A Props kit piece at this room's age, standing on the floor at `pos`
## with its front (-Z) turned by `rot_y`. `solid` adds the kit's
## shape-following box colliders (Props.collision_boxes).
func prop(id: String, pos: Vector3, rot_y := 0.0, solid := true, age_override := -1, lod := 0) -> void:
	var mesh := Props.mesh(id, age if age_override < 0 else age_override, lod)
	if mesh == null:
		return
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	instance(mesh, xf)
	if solid:
		# the kit's shape-following boxes (seat, back, legs), not one hull
		for b in Props.collision_boxes(id, age if age_override < 0 else age_override):
			_shapes.append(xf * b)


## Any other node (doors, lights) to add with the room.
func add(n: Node3D) -> void:
	_extra.append(n)


## Emits the box's faces as jittered tiles. `only` limits it to one face in
## VoxelMeshBuilder.CUBE_FACES order (+X, -X, +Y, -Y, +Z, -Z); -1 = all.
func _faces(b: VoxelMeshBuilder, lo: Vector3, hi: Vector3, col: Color, tile: float, jitter: float, age_tiles := false, only := -1) -> void:
	var size := hi - lo
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var nu := clampi(int(ceil(size[u] / tile - 0.001)), 1, MAX_TILES)
		var nv := clampi(int(ceil(size[v] / tile - 0.001)), 1, MAX_TILES)
		for sgn in [-1, 1]:
			if only >= 0 and only != axis * 2 + (0 if sgn > 0 else 1):
				continue
			var n := Vector3.ZERO
			n[axis] = sgn
			var depth := hi[axis] if sgn > 0 else lo[axis]
			for i in nu:
				for j in nv:
					var u0 := lo[u] + size[u] * i / nu
					var u1 := lo[u] + size[u] * (i + 1) / nu
					var v0 := lo[v] + size[v] * j / nv
					var v1 := lo[v] + size[v] * (j + 1) / nv
					var p: Array[Vector3] = []
					for uv in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
						var q := Vector3()
						q[axis] = depth
						q[u] = uv.x
						q[v] = uv.y
						p.append(q)
					var key := Vector3i(roundi((u0 + u1) * 4.0), roundi((v0 + v1) * 4.0), roundi(depth * 8.0) * 3 + axis)
					var c := aged(col, key) if age_tiles else col
					b.add_quad(p[0], p[1], p[2], p[3], n, VoxelMeshBuilder.jitter_color(c, key, jitter))


## Adds the meshes, colliders, signs and extra nodes under `parent`.
func commit(parent: Node3D) -> void:
	for pair in [[_solid, null], [_glow, glow_material()], [_glass, glass_material()]]:
		var b: VoxelMeshBuilder = pair[0]
		if b.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit(pair[1])
		# furniture casts shadows when the quality allows; overhead rooms (the
		# roof, the lamp truss) never do or they'd black out the ice, and lamp
		# faces and glass never do
		mi.cast_shadow = Look.cast() if pair[1] == null and not parent.get("overhead") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	if not _shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1 << (VENUE_LAYER - 1)
		body.collision_mask = 0
		for box in _shapes:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size.max(Vector3(0.02, 0.02, 0.02))
			cs.shape = shape
			cs.position = box.get_center()
			body.add_child(cs)
		parent.add_child(body)
	for mesh in _instances:
		var xfs: Array = _instances[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if parent.get("overhead") else Look.cast()
		parent.add_child(mmi)
	if not _occluders.is_empty():
		var verts := PackedVector3Array()
		var idx := PackedInt32Array()
		for box in _occluders:
			var base := verts.size()
			for i in 8:
				verts.append(box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
			for q in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
				idx.append_array([base + q[0], base + q[1], base + q[2], base + q[0], base + q[2], base + q[3]])
		var occ := ArrayOccluder3D.new()
		occ.set_arrays(verts, idx)
		var oi := OccluderInstance3D.new()
		oi.name = "Occluders"
		oi.occluder = occ
		parent.add_child(oi)
	for pair in _signs:
		var s: VenueSign = pair[0]
		s.transform = pair[1]
		parent.add_child(s)
	for n in _extra:
		parent.add_child(n)


func collider_count() -> int:
	return _shapes.size()
