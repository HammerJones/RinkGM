class_name StickField
extends Node3D
## The real sticks of one room (StickProp bodies, its children), and its
## other loose things (LooseProp: cups, cones, boxes, chairs). Keeps them
## cheap: every resting stick and prop is drawn as part of one merged mesh
## (one draw for the room, rebuilt only when one falls asleep or wakes), and
## while the camera is more than FAR metres away the resting ones leave the
## physics space altogether.

const FAR := 24.0
const CHECK := 0.5        # seconds between distance checks
const DRAW_RANGE := 45.0  # sticks are not drawn beyond this

static var _arrays := {}  # ArrayMesh -> [verts, normals, colours]

var sticks: Array[StickProp] = []
var props: Array[LooseProp] = []
var _mi: MeshInstance3D
var _dirty := true
var _t := 0.0
var _near := true
var _bounds := AABB()


func add_stick(s: StickProp) -> void:
	s.field = self
	sticks.append(s)
	add_child(s)
	_dirty = true


func remove_stick(s: StickProp) -> void:
	sticks.erase(s)
	_dirty = true


func add_prop(p: LooseProp) -> void:
	p.field = self
	props.append(p)
	add_child(p)
	_dirty = true


func remove_prop(p: LooseProp) -> void:
	props.erase(p)
	if p.field == self:
		p.field = null
	_dirty = true


func mark_dirty() -> void:
	_dirty = true


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Resting"
	_mi.cast_shadow = Look.cast()
	_mi.visibility_range_end = DRAW_RANGE
	add_child(_mi)
	_rebuild()


func _process(dt: float) -> void:
	if _dirty:
		_rebuild()
	_t += dt
	if _t >= CHECK:
		_t = 0.0
		_check_distance()


## How many sticks are resting (drawn in the merged mesh) and awake.
func counts() -> Vector2i:
	var asleep := 0
	for s in sticks:
		if is_instance_valid(s) and s.sleeping:
			asleep += 1
	return Vector2i(asleep, sticks.size() - asleep)


func _rebuild() -> void:
	_dirty = false
	var meshes: Array[ArrayMesh] = []
	var xfs: Array[Transform3D] = []
	var first := true
	for b in _bodies():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		var s := b as RigidBody3D
		var p := s.transform.origin
		_bounds = AABB(p, Vector3.ZERO) if first else _bounds.expand(p)
		first = false
		var m: ArrayMesh = s.get("mesh") as ArrayMesh
		if (s.sleeping or s.freeze) and m:  # frozen: placed, not yet let go
			meshes.append(m)
			xfs.append(s.transform)
	_mi.mesh = merge(meshes, xfs)


func _bodies() -> Array:
	var out := []
	out.append_array(sticks)
	out.append_array(props)
	return out


## One mesh of many stick meshes placed by `xfs` (null when empty): a whole
## rack of sticks in one draw.
static func merge(meshes: Array[ArrayMesh], xfs: Array[Transform3D]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for j in meshes.size():
		var xf := xfs[j]
		var a: Array = _mesh_arrays(meshes[j])
		var v: PackedVector3Array = a[0]
		var n: PackedVector3Array = a[1]
		var base := verts.size()
		verts.resize(base + v.size())
		norms.resize(base + v.size())
		for i in v.size():
			verts[base + i] = xf * v[i]
			norms[base + i] = (xf.basis * n[i]).normalized()
		cols.append_array(a[2])
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, VoxelMeshBuilder.material())
	return m


static func _mesh_arrays(m: ArrayMesh) -> Array:
	if not _arrays.has(m):
		var a := m.surface_get_arrays(0)
		_arrays[m] = [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_COLOR]]
	return _arrays[m]


## Resting sticks far from the camera leave the physics space; they come
## back (still asleep) when it nears. No camera (a headless test): all near.
func _check_distance() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := true
	if cam:
		var c := global_transform * _bounds.get_center()
		near = cam.global_position.distance_to(c) - _bounds.size.length() * 0.5 < FAR
	if near == _near:
		return
	_near = near
	for b in _bodies():
		if not is_instance_valid(b) or b.get("held") == true:
			continue
		var s := b as RigidBody3D
		if near and s.process_mode == Node.PROCESS_MODE_DISABLED:
			s.process_mode = Node.PROCESS_MODE_INHERIT
			s.sleeping = true
		elif not near and s.sleeping:
			s.process_mode = Node.PROCESS_MODE_DISABLED
