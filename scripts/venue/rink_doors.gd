class_name RinkDoors
extends RefCounted
## The doors in the rink boards, one RinkDoor over each of the walker's
## gates (Shell.GATES): the four bench gates (z -12.95), the two penalty
## box doors and the two wide rink doors on the far side (z +12.95), and the
## Zamboni door in the +X end boards. The rink glass room builds them
## (their glass is its glass, at its age).
##
## Every leaf is drawn by one Rig: a Skeleton3D with a bone per leaf, one
## skinned mesh for the board sections and their hardware and one for the
## glass, the bones following the doors' hinge pivots. The draw budget
## (test_venue) has no room for a mesh per leaf.
##
## The rink's own board mesh (Rink, owned by Hockey) is continuous; the Rig
## clips it at runtime at each opening so the doors can open (`cut_boards`),
## visual only. Rink.confine and the puck never see any of this.

const Shell := preload("res://scripts/venue/rooms/shell.gd")
## The rink board colours Rink._build_boards uses (kick plate, board, cap).
const KICK := Color("b8921f")
const BOARD := Color("8f877b")
const CAP := Color("2c5aa3")
const COLUMN := 0.15  # Rink's board column spacing
const PANEL := 1.83   # glass room: the kit panel and its height above the boards
const PANE_H := 1.17
const CUT_META := &"rink_doors_cut"


## The doors for a room: built, named, hung in `room.doors`, with the fixed
## jambs and hinge knuckles in `k` and the leaves' Rig. Returns the doors.
static func build(room: VenueRoom, k: VenueKit) -> Array[RinkDoor]:
	var out: Array[RinkDoor] = []
	var fixed := []
	for g: Array in Shell.GATES:
		var d := RinkDoor.for_gate(g)
		room.doors.append(d)
		k.add(d)
		out.append(d)
		fixed.append_array(_jambs(k, d))
	var rig := Rig.new()
	rig.name = "RinkDoorRig"
	rig.setup(out, k.age, fixed)
	k.add(rig)
	return out


## Spans with glass doors along a wall ("z+", "x+"): [[from, to], ...].
static func glass_spans(wall: String) -> Array:
	var out := []
	for g: Array in Shell.GATES:
		if g[0] == wall and wall != "z-":
			out.append([g[1], g[2]])
	return out


## Steel posts at each edge of the opening, on the walkway side: they close
## the cut ends of the boards either side and carry the hinge knuckles.
## [[Transform3D of a unit cube, Color], ...] in room space (the Rig draws
## them on its fixed bone, which saves the room a mesh of its own).
static func _jambs(k: VenueKit, d: RinkDoor) -> Array:
	var out := []
	# the glass frame's posts (Props glass_frame) at this age
	var steel: Color = k.by_age(Wear.OLD_GOLD, Wear.OLD_GOLD.lightened(0.1), Wear.STEEL)
	if d.glass_h <= 0.0:
		steel = BOARD.darkened(0.3)  # a bench gate's jamb is just the boards' end
	var top := VenuePhysics.board_top() + d.glass_h
	var xf := d.transform
	for side in [-1.0, 1.0]:
		var e: float = side * d.width * 0.5
		var a := xf * Vector3(e, 0.0, 0.01)
		var b := xf * Vector3(e + side * 0.05, top - 0.01, RinkDoor.THICK - 0.005)
		out.append([_box(a.min(b), a.max(b)), steel])
	for spec in d.leaf_specs():
		var hx: float = spec[0]
		var dir: float = spec[2]
		for y: float in [0.2, Rink.BOARD_H - 0.35]:
			var a := xf * Vector3(hx - dir * 0.06, y, RinkDoor.THICK)
			var b := xf * Vector3(hx - dir * 0.01, y + 0.14, RinkDoor.THICK + 0.04)
			out.append([_box(a.min(b), a.max(b)), Color("55585e")])
	return out


## One leaf's geometry, closed, in door space: [[Transform3D of a unit cube,
## Color], ...] for the solid parts. The board columns are Rink's profile.
static func leaf_boxes(d: RinkDoor, spec: Array, age: int, key: int) -> Array:
	var out := []
	var r := RinkDoor.leaf_range(spec)
	var w := r.y - r.x
	var n := maxi(1, roundi(w / COLUMN))
	var cw := w / n
	for i in n:
		var x0 := r.x + i * cw
		var j := 0
		for prof: Array in RinkDoor.PROFILE:
			var col: Color = [KICK, BOARD, CAP][j]
			var c := VoxelMeshBuilder.jitter_color(col, Vector2i(key * 97 + i, j), [0.05, 0.07, 0.04][j])
			out.append([_box(Vector3(x0, prof[0], 0.0), Vector3(x0 + cw, prof[1], prof[2])), c])
			j += 1
	# hardware on the walkway face: hinge straps, a handle or drop latch
	var steel: Color = [Color("7d7a72"), Color("8a8f96"), Color("b8bcc2")][age]
	var hx: float = spec[0]
	var dir: float = spec[2]
	var face := 0.18  # the board's back face
	for y: float in [0.2, Rink.BOARD_H - 0.35]:
		var a := Vector3(hx + dir * 0.01, y + 0.02, face)
		var b := Vector3(hx + dir * 0.3, y + 0.12, face + 0.015)
		out.append([_box(a.min(b), a.max(b)), steel])
	var free_x: float = hx + dir * (r.y - r.x - 0.12)
	if d.style == RinkDoor.Style.BENCH:
		out.append([_box(Vector3(free_x - 0.025, Rink.BOARD_H - 0.35, face), Vector3(free_x + 0.025, Rink.BOARD_H - 0.12, face + 0.045)), Color("b8bcc2")])
	else:
		out.append([_box(Vector3(free_x - 0.03, 0.75, face), Vector3(free_x + 0.03, 0.95, face + 0.07)), Color("55585e")])
	if d.style == RinkDoor.Style.ZAMBONI:
		# a yellow-and-black stripe across the walkway face, a drop bolt
		var stripes := 6
		for i in stripes:
			var sx0 := r.x + (r.y - r.x) * i / stripes
			var sx1 := r.x + (r.y - r.x) * (i + 1) / stripes
			out.append([_box(Vector3(sx0, Rink.BOARD_H - 0.25, face), Vector3(sx1, Rink.BOARD_H - 0.15, face + 0.01)), Color("e0b020") if (i + key) % 2 == 0 else Color("1b1d22")])
		out.append([_box(Vector3(free_x - 0.02, 0.0, face), Vector3(free_x + 0.03, 0.6, face + 0.05)), Color("55585e")])
	return out


static func _box(lo: Vector3, hi: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(hi - lo), (lo + hi) * 0.5)


## The pane over a leaf, in door space: the glass room's kit panel stretched
## to the leaf, standing on the boards where the glass room's panels stand.
static func glass_xf(spec: Array, glass_h: float) -> Transform3D:
	var r := RinkDoor.leaf_range(spec)
	var basis := Basis(Vector3.RIGHT * ((r.y - r.x) / PANEL), Vector3.UP * (glass_h / PANE_H), Vector3.BACK)
	return Transform3D(basis, Vector3((r.x + r.y) * 0.5, VenuePhysics.board_top(), 0.16))


# ---------------------------------------------------------------- the boards

## Clips Rink's board mesh (a child MeshInstance3D of `rink`) at each door's
## opening, so the leaves are the only boards there. Visual only, and only
## once per rink. Returns how many triangles it removed (0 if already cut).
static func cut_boards(rink: Node3D, doors: Array) -> int:
	if rink.has_meta(CUT_META):
		return 0
	var mi := board_mesh(rink)
	if mi == null:
		return 0
	rink.set_meta(CUT_META, true)
	var to_rink := rink.global_transform.affine_inverse()
	var spans := []  # [axis (0 x, 2 z), side, a, b] in rink space
	for d: RinkDoor in doors:
		if not d.is_inside_tree():
			continue
		var a: Vector3 = to_rink * (d.global_transform * Vector3(-d.width * 0.5, 0, 0))
		var b: Vector3 = to_rink * (d.global_transform * Vector3(d.width * 0.5, 0, 0))
		if d.wall == "x+":
			spans.append([2, 1.0, minf(a.z, b.z), maxf(a.z, b.z)])
		else:
			spans.append([0, -1.0 if d.wall == "z-" else 1.0, minf(a.x, b.x), maxf(a.x, b.x)])
	var arr := mi.mesh.surface_get_arrays(0)
	var mat := mi.mesh.surface_get_material(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var oc := PackedColorArray()
	var before := vs.size() / 3
	for t in before:
		var tri: Array = [[vs[t * 3], vs[t * 3 + 1], vs[t * 3 + 2]]]
		for s: Array in spans:
			if not _on_wall(tri[0], s):
				continue
			var next: Array = []
			for q: Array in tri:
				next.append_array(_clip(q, s[0], s[2], s[3]))
			tri = next
			if tri.is_empty():
				break
		for q: Array in tri:
			for i in 3:
				ov.append(q[i])
				on.append(ns[t * 3 + i])
				oc.append(cs[t * 3 + i])
	var nm := ArrayMesh.new()
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = ov
	out[Mesh.ARRAY_NORMAL] = on
	out[Mesh.ARRAY_COLOR] = oc
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	nm.surface_set_material(0, mat)
	mi.mesh = nm
	return before - ov.size() / 3


## Rink's board mesh: the child mesh as long as the rink and as tall as the
## boards.
static func board_mesh(rink: Node3D) -> MeshInstance3D:
	for c in rink.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
			var bb := mi.mesh.get_aabb()
			if bb.size.x > Rink.LENGTH and absf(bb.size.y - (Rink.BOARD_H + 0.04)) < 0.05:
				return mi
	return null


static func _on_wall(tri: Array, s: Array) -> bool:
	for p: Vector3 in tri:
		if s[0] == 0:
			var d: float = p.z * s[1] - Rink.HALF_W
			if d < -0.01 or d > 0.4:
				return false
		else:
			var d: float = p.x * s[1] - Rink.HALF_L
			if d < -0.01 or d > 0.4:
				return false
	return true


## A board triangle against the opening [a, b] along `axis`: the parts of it
## either side, clamped to the edges (exact for the axis-aligned box faces
## the straight boards are made of); nothing of it inside.
static func _clip(tri: Array, axis: int, a: float, b: float) -> Array:
	var lo := minf(minf(tri[0][axis], tri[1][axis]), tri[2][axis])
	var hi := maxf(maxf(tri[0][axis], tri[1][axis]), tri[2][axis])
	if hi <= a + 0.0001 or lo >= b - 0.0001:
		return [tri]
	var out := []
	if lo < a - 0.0001:
		out.append(_clamped(tri, axis, -INF, a))
	if hi > b + 0.0001:
		out.append(_clamped(tri, axis, b, INF))
	return out.filter(func(q: Array) -> bool: return (q[1] - q[0]).cross(q[2] - q[0]).length() > 1e-8)


static func _clamped(tri: Array, axis: int, a: float, b: float) -> Array:
	var out := []
	for p: Vector3 in tri:
		var q := p
		q[axis] = clampf(q[axis], a, b)
		out.append(q)
	return out


# ---------------------------------------------------------------- the rig

## The leaves of all the rink doors as two skinned meshes on one skeleton.
## Bone i is one leaf; its pose is the leaf's swing about its hinge, in the
## room's space. Also clips the rink's boards once a Rink turns up beside
## the venue.
class Rig extends Skeleton3D:
	var doors: Array[RinkDoor] = []
	var bones: Array = []      # [door, leaf index] per bone
	var solid: MeshInstance3D
	var glass: MeshInstance3D
	var _last: PackedFloat32Array = []
	var _cut_tries := 0

	## `fixed`: [[Transform3D, Color], ...] room-space boxes that never move
	## (the door frames), drawn on the last bone, which stays put.
	func setup(doors_: Array[RinkDoor], age: int, fixed := []) -> void:
		doors = doors_
		var sv := PackedVector3Array()
		var sn := PackedVector3Array()
		var sc := PackedColorArray()
		var sb := PackedInt32Array()
		var sw := PackedFloat32Array()
		var gv := PackedVector3Array()
		var gn := PackedVector3Array()
		var gc := PackedColorArray()
		var gb := PackedInt32Array()
		var gw := PackedFloat32Array()
		var pane := Props.mesh("glass_pane", age, 1)
		var frame := Props.mesh("glass_frame", age, 1)
		for d in doors:
			var specs := d.leaf_specs()
			for li in specs.size():
				var bone := bones.size()
				add_bone("leaf_%d" % bone)
				bones.append([d, li])
				var b := VoxelMeshBuilder.new()
				for box: Array in RinkDoors.leaf_boxes(d, specs[li], age, bone):
					b.add_box(d.transform * (box[0] as Transform3D), box[1])
				_append(b.commit(), Transform3D.IDENTITY, bone, sv, sn, sc, sb, sw)
				if d.glass_h > 0.0:
					var gx := d.transform * RinkDoors.glass_xf(specs[li], d.glass_h)
					_append(frame, gx, bone, sv, sn, sc, sb, sw)
					_append(pane, gx, bone, gv, gn, gc, gb, gw)
		_last.resize(bones.size())
		_last.fill(0.0)
		var still := add_bone("frames")
		var fb := VoxelMeshBuilder.new()
		for box: Array in fixed:
			fb.add_box(box[0], box[1])
		_append(fb.commit(), Transform3D.IDENTITY, still, sv, sn, sc, sb, sw)
		var skin := Skin.new()
		for i in get_bone_count():
			skin.add_bind(i, Transform3D.IDENTITY)
		solid = _mesh("Leaves", sv, sn, sc, sb, sw, VoxelMeshBuilder.material(), skin)
		solid.cast_shadow = Look.cast()
		if not gv.is_empty():
			glass = _mesh("LeafGlass", gv, gn, gc, gb, gw, Props.glass_material(age), skin)
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _mesh(n: String, v: PackedVector3Array, nr: PackedVector3Array, c: PackedColorArray, b: PackedInt32Array, w: PackedFloat32Array, mat: Material, skin: Skin) -> MeshInstance3D:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nr
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_BONES] = b
		arr[Mesh.ARRAY_WEIGHTS] = w
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.mesh = m
		mi.skin = skin
		mi.skeleton = NodePath("..")
		mi.extra_cull_margin = 3.0  # the leaves swing up to 2.5 m out of the mesh's box
		add_child(mi)
		return mi

	## Appends mesh `m`'s triangles, moved by `xf`, all on bone `bone`.
	static func _append(m: Mesh, xf: Transform3D, bone: int, v: PackedVector3Array, nr: PackedVector3Array, c: PackedColorArray, b: PackedInt32Array, w: PackedFloat32Array) -> void:
		if m == null:
			return
		var nb := xf.basis.inverse().transposed()
		for si in m.get_surface_count():
			var a := m.surface_get_arrays(si)
			var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var pc = a[Mesh.ARRAY_COLOR]
			var idx = a[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = idx if idx != null and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(pv.size()))
			for i in order:
				v.append(xf * pv[i])
				nr.append((nb * pn[i]).normalized())
				c.append(pc[i] if pc != null and not (pc as PackedColorArray).is_empty() else Color.WHITE)
				b.append_array([bone, 0, 0, 0])
				w.append_array([1.0, 0.0, 0.0, 0.0])

	func _process(_dt: float) -> void:
		for i in bones.size():
			var d: RinkDoor = bones[i][0]
			var li: int = bones[i][1]
			if not is_instance_valid(d) or d.leaves.size() <= li:
				continue
			var pivot := d.leaves[li]
			var th := pivot.rotation.y
			if th == _last[i]:
				continue
			_last[i] = th
			# the swing about the hinge, in door space, then in the room's
			var p := pivot.position
			var swing := Transform3D(Basis.IDENTITY, p) * Transform3D(Basis(Vector3.UP, th), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -p)
			var pose := d.transform * swing * d.transform.affine_inverse()
			set_bone_pose_position(i, pose.origin)
			set_bone_pose_rotation(i, pose.basis.get_rotation_quaternion())
		if _cut_tries < 120:
			_cut_tries += 1
			var rink := find_rink()
			if rink:
				RinkDoors.cut_boards(rink, doors)
				_cut_tries = 120

	## The Rink beside the venue (the walk's, the match's), or null.
	func find_rink() -> Node3D:
		var room := get_parent()
		var venue: Node = room.get("venue") if room else null
		if venue == null or venue.get_parent() == null:
			return null
		for c in venue.get_parent().get_children():
			if c is Rink:
				return c
		return null
