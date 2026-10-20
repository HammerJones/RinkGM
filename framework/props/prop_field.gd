class_name PropField
extends Node3D
## Thousands of physical props with no node each. Every placed thing is a
## PropRow; the field draws rows through RenderingServer MultiMeshes (one per
## mesh per CELL-metre cell, so frustum culling and visibility range work
## per cell) and collides them through PhysicsServer3D static bodies (one
## per row, so a physics ray reports which row it hit). A row becomes a real
## RigidBody3D (Jolt) only while something needs it to move: `wake()` on a
## shove, a pick-up, a drop. When the body sleeps, and is far from `focus`
## or the live cap is reached, the field writes its resting transform back
## and the row is instanced again. This generalises StickField / LooseProp
## to everything in the building.
##
##   var row := field.add(&"lobby.cup.17", &"coffee_cup", mesh, boxes, xf, 0.25)
##   field.wake(row).apply_central_impulse(Vector3(0, 2, 0))
##   var hit := field.raycast(from, to)        # -> PropRow or null
##   field.focus = walker.global_position      # every frame or so
##
## Layers: rows sit on `layer` and collide with `mask`; live bodies the
## same, so a walker that shoves a LooseProp shoves these too.

signal woke(row: PropRow, body: RigidBody3D)
signal slept(row: PropRow)

const CELL := 8.0
const TICK := 0.5
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0, -1000, 0))

## Most rows that may be rigid bodies at once.
@export var live_cap := 64
## A sleeping body farther than this from `focus` goes back to a row.
@export var sleep_radius := 24.0
## Rows are not drawn beyond this distance (0 = always).
@export var draw_range := 60.0
## Physics layer bit (1-based) rows and bodies sit on, and what they hit.
@export var layer := 3
@export var mask := 0b111
@export var cast_shadows := true

var focus := Vector3.ZERO
var rows: Array[PropRow] = []

var _by_id := {}  # StringName -> PropRow
var _by_rid := {}  # static body RID -> PropRow
var _by_node := {}  # RigidBody3D -> PropRow
var _batches := {}  # "mesh rid id:cx,cy,cz" -> _Batch
var _cells := {}  # Vector3i -> Array[PropRow]
var _shapes := {}  # Mesh -> Array[Array[RID, Transform3D]] (shared box shapes)
var _live: Array[PropRow] = []
var _pending: Array[PropRow] = []  # added before the field entered the tree
var _t := 0.0
var _tick_usec := 0
var _scenario := RID()
var _space := RID()


func _enter_tree() -> void:
	_scenario = get_world_3d().scenario
	_space = get_world_3d().space
	set_notify_transform(true)
	for r in _pending:
		_instance(r)
	_pending.clear()


## Leaving the tree drops every server object; the rows stay and come back
## when the field re-enters (a live body settles to its row first).
func _exit_tree() -> void:
	for r in rows.duplicate():
		if r.node:
			r.xf = r.node.transform
			_by_node.erase(r.node)
			r.node.queue_free()
			r.node = null
			r.tier = PropRow.Tier.INSTANCED
		_uninstance(r)
	_live.clear()
	for b in _batches.values():
		b.dispose()
	_batches.clear()
	_cells.clear()
	for shapes in _shapes.values():
		for s in shapes:
			PhysicsServer3D.free_rid(s[0])
	_shapes.clear()
	_pending = rows.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		for b in _batches.values():
			RenderingServer.instance_set_transform(b.instance, global_transform)


func _process(dt: float) -> void:
	_t += dt
	if _t < TICK:
		return
	_t = 0.0
	var t0 := Time.get_ticks_usec()
	_settle()
	_tick_usec = Time.get_ticks_usec() - t0


# --- rows ----------------------------------------------------------------


## Adds a row. `boxes` are shape-following boxes in the prop's space (as
## VoxelModel.collision_boxes gives), `xf` in this field's space.
func add(
	id: StringName, prop: StringName, mesh: Mesh, boxes: Array[AABB], xf: Transform3D, mass := 1.0
) -> PropRow:
	if _by_id.has(id):
		push_error("PropField: duplicate row id %s" % id)
		return _by_id[id]
	var r := PropRow.new()
	r.id = id
	r.prop = prop
	r.mesh = mesh
	r.boxes = boxes
	r.xf = xf
	r.mass = mass
	rows.append(r)
	_by_id[id] = r
	if is_inside_tree():
		_instance(r)
	else:
		_pending.append(r)
	return r


func remove(r: PropRow) -> void:
	if r == null or not _by_id.has(r.id):
		return
	if r.node:
		_live.erase(r)
		_by_node.erase(r.node)
		r.node.queue_free()
		r.node = null
	_uninstance(r)
	_pending.erase(r)
	rows.erase(r)
	_by_id.erase(r.id)


func get_row(id: StringName) -> PropRow:
	return _by_id.get(id)


func count() -> int:
	return rows.size()


func live_count() -> int:
	return _live.size()


## Moves an instanced row (a live one moves itself).
func move_row(r: PropRow, xf: Transform3D) -> void:
	if r.node:
		r.node.global_transform = global_transform * xf
		return
	var cell := _cell_of(xf.origin)
	if cell != r.cell or r.batch == null:
		_uninstance(r)
		r.xf = xf
		_instance(r)
		return
	r.xf = xf
	r.batch.set_transform(r.slot, xf)
	PhysicsServer3D.body_set_state(
		r.body, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * xf
	)


# --- tiers ---------------------------------------------------------------


## Makes the row a rigid body and returns it (the same body when already
## live). Returns null when the cap is full of bodies that are still awake.
func wake(r: PropRow) -> RigidBody3D:
	if r.node:
		return r.node
	while _live.size() >= live_cap:
		var victim := _farthest_sleeping()
		if victim == null:
			return null
		sleep(victim)
	_uninstance(r)
	var b := RigidBody3D.new()
	b.name = String(r.id)
	b.mass = maxf(r.mass, 0.01)
	b.collision_layer = 1 << (layer - 1)
	b.collision_mask = mask
	b.can_sleep = true
	b.continuous_cd = r.mass < 1.0
	if r.boxes.is_empty():
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.1, 0.1, 0.1)
		cs.shape = bs
		b.add_child(cs)
	for box in r.boxes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size.max(Vector3(0.02, 0.02, 0.02))
		cs.shape = bs
		cs.position = box.get_center()
		b.add_child(cs)
	if r.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = r.mesh
		mi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		b.add_child(mi)
	b.transform = r.xf
	add_child(b)
	b.sleeping_state_changed.connect(_on_sleep_change.bind(r))
	r.node = b
	r.tier = PropRow.Tier.LIVE
	_live.append(r)
	_by_node[b] = r
	woke.emit(r, b)
	return b


## Puts a live row back as an instance where its body now rests.
func sleep(r: PropRow) -> void:
	if r.node == null:
		return
	var b := r.node
	r.xf = b.transform
	_live.erase(r)
	_by_node.erase(b)
	r.node = null
	b.queue_free()
	r.tier = PropRow.Tier.INSTANCED
	_instance(r)
	slept.emit(r)


func is_live(r: PropRow) -> bool:
	return r.node != null


# --- queries -------------------------------------------------------------


## The row a physics ray hit (its `rid` or `collider`), or null.
func row_of(hit: Dictionary) -> PropRow:
	if hit.is_empty():
		return null
	if _by_rid.has(hit.get("rid")):
		return _by_rid[hit.rid]
	var col: Variant = hit.get("collider")
	if col is RigidBody3D and _by_node.has(col):
		return _by_node[col]
	return null


## Casts a ray against rows (instanced and live) and returns the nearest
## row, or null. `extra_mask` adds layers so the hit can be blocked by walls.
func raycast(from: Vector3, to: Vector3, extra_mask := 0) -> PropRow:
	var q := PhysicsRayQueryParameters3D.create(from, to, (1 << (layer - 1)) | extra_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return row_of(hit)


## Rows within `radius` of `pos` (field space), nearest first.
func nearest(pos: Vector3, radius: float) -> Array[PropRow]:
	var out: Array[PropRow] = []
	var lo := _cell_of(pos - Vector3.ONE * radius)
	var hi := _cell_of(pos + Vector3.ONE * radius)
	var r2 := radius * radius
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var list: Array = _cells.get(Vector3i(x, y, z), [])
				for r in list:
					if r.xf.origin.distance_squared_to(pos) <= r2:
						out.append(r)
	for r in _live:
		if r.node and r.node.position.distance_squared_to(pos) <= r2:
			out.append(r)
	out.sort_custom(
		func(a: PropRow, b: PropRow) -> bool:
			return a.position().distance_squared_to(pos) < b.position().distance_squared_to(pos)
	)
	return out


func stats() -> Dictionary:
	return {
		"rows": rows.size(),
		"live": _live.size(),
		"batches": _batches.size(),
		"cells": _cells.size(),
		"tick_ms": _tick_usec / 1000.0,
	}


# --- save ----------------------------------------------------------------


func to_dicts() -> Array:
	var out := []
	for r in rows:
		out.append(r.to_dict())
	return out


# --- internals -----------------------------------------------------------


func _cell_of(p: Vector3) -> Vector3i:
	return Vector3i((p / CELL).floor())


func _instance(r: PropRow) -> void:
	r.cell = _cell_of(r.xf.origin)
	var key := (
		"%d:%d,%d,%d" % [r.mesh.get_rid().get_id() if r.mesh else 0, r.cell.x, r.cell.y, r.cell.z]
	)
	var b: _Batch = _batches.get(key)
	if b == null:
		b = _Batch.new(r.mesh, _scenario, global_transform, draw_range, cast_shadows)
		_batches[key] = b
	r.batch = b
	r.slot = b.add(r)
	if not _cells.has(r.cell):
		_cells[r.cell] = []
	_cells[r.cell].append(r)
	_make_static(r)


func _uninstance(r: PropRow) -> void:
	if r.batch:
		var moved: PropRow = r.batch.remove(r.slot)
		if moved:
			moved.slot = r.slot
		if r.batch.count == 0:
			for key in _batches:
				if _batches[key] == r.batch:
					_batches.erase(key)
					break
			r.batch.dispose()
		r.batch = null
		r.slot = -1
	if _cells.has(r.cell):
		_cells[r.cell].erase(r)
		if _cells[r.cell].is_empty():
			_cells.erase(r.cell)
	_free_static(r)


func _make_static(r: PropRow) -> void:
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	for s in _shapes_for(r):
		PhysicsServer3D.body_add_shape(body, s[0], s[1])
	PhysicsServer3D.body_set_collision_layer(body, 1 << (layer - 1))
	PhysicsServer3D.body_set_collision_mask(body, mask)
	PhysicsServer3D.body_attach_object_instance_id(body, get_instance_id())
	PhysicsServer3D.body_set_space(body, _space)
	PhysicsServer3D.body_set_state(
		body, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * r.xf
	)
	r.body = body
	_by_rid[body] = r


func _free_static(r: PropRow) -> void:
	if r.body.is_valid():
		_by_rid.erase(r.body)
		PhysicsServer3D.free_rid(r.body)
		r.body = RID()


## Box shapes are shared by every row of one mesh (the boxes come from the
## mesh's model, so they match).
func _shapes_for(r: PropRow) -> Array:
	var key: Variant = r.mesh if r.mesh else r.prop
	if _shapes.has(key):
		return _shapes[key]
	var out: Array = []
	var boxes := r.boxes
	if boxes.is_empty():
		boxes = [AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))]
	for box in boxes:
		var s := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(s, box.size.max(Vector3(0.02, 0.02, 0.02)) * 0.5)
		out.append([s, Transform3D(Basis.IDENTITY, box.get_center())])
	_shapes[key] = out
	return out


func _on_sleep_change(r: PropRow) -> void:
	if r.node == null or not r.node.sleeping:
		return
	if r.node.position.distance_to(focus) > sleep_radius:
		sleep.call_deferred(r)


## Every TICK: settle sleeping bodies that are far away or over the cap.
func _settle() -> void:
	var over := _live.size() - live_cap
	for r in _live.duplicate():
		if r.node == null or not r.node.sleeping:
			continue
		if over > 0 or r.node.position.distance_to(focus) > sleep_radius:
			sleep(r)
			over -= 1


func _farthest_sleeping() -> PropRow:
	var best: PropRow = null
	var best_d := -1.0
	for r in _live:
		if r.node and r.node.sleeping:
			var d := r.node.position.distance_squared_to(focus)
			if d > best_d:
				best_d = d
				best = r
	return best


## One MultiMesh for one mesh in one cell, kept on the RenderingServer.
class _Batch:
	extends RefCounted
	var multimesh := RID()
	var instance := RID()
	var mesh: Mesh
	var rows: Array[PropRow] = []
	var count := 0
	var capacity := 0

	func _init(m: Mesh, scenario: RID, xf: Transform3D, draw_range: float, shadows: bool) -> void:
		mesh = m
		multimesh = RenderingServer.multimesh_create()
		if m:
			RenderingServer.multimesh_set_mesh(multimesh, m.get_rid())
		instance = RenderingServer.instance_create2(multimesh, scenario)
		RenderingServer.instance_set_transform(instance, xf)
		RenderingServer.instance_geometry_set_cast_shadows_setting(
			instance,
			(
				RenderingServer.SHADOW_CASTING_SETTING_ON
				if shadows
				else RenderingServer.SHADOW_CASTING_SETTING_OFF
			)
		)
		if draw_range > 0.0:
			RenderingServer.instance_geometry_set_visibility_range(
				instance,
				0.0,
				draw_range,
				0.0,
				draw_range * 0.1,
				RenderingServer.VISIBILITY_RANGE_FADE_DISABLED
			)
		_reserve(16)

	func dispose() -> void:
		if instance.is_valid():
			RenderingServer.free_rid(instance)
		if multimesh.is_valid():
			RenderingServer.free_rid(multimesh)
		instance = RID()
		multimesh = RID()

	func add(r: PropRow) -> int:
		if count == capacity:
			_reserve(capacity * 2)
		var slot := count
		rows.append(r)
		count += 1
		RenderingServer.multimesh_set_visible_instances(multimesh, count)
		RenderingServer.multimesh_instance_set_transform(multimesh, slot, r.xf)
		return slot

	## Swap-removes `slot`; returns the row that moved into it (or null).
	func remove(slot: int) -> PropRow:
		var last := count - 1
		var moved: PropRow = null
		if slot != last:
			moved = rows[last]
			rows[slot] = moved
			RenderingServer.multimesh_instance_set_transform(multimesh, slot, moved.xf)
		rows.resize(last)
		count = last
		RenderingServer.multimesh_instance_set_transform(multimesh, last, HIDDEN)
		RenderingServer.multimesh_set_visible_instances(multimesh, count)
		return moved

	func set_transform(slot: int, xf: Transform3D) -> void:
		RenderingServer.multimesh_instance_set_transform(multimesh, slot, xf)

	## Allocating clears the buffer, so every transform is written again.
	func _reserve(n: int) -> void:
		capacity = n
		RenderingServer.multimesh_allocate_data(
			multimesh, capacity, RenderingServer.MULTIMESH_TRANSFORM_3D
		)
		for i in count:
			RenderingServer.multimesh_instance_set_transform(multimesh, i, rows[i].xf)
		for i in range(count, capacity):
			RenderingServer.multimesh_instance_set_transform(multimesh, i, HIDDEN)
		RenderingServer.multimesh_set_visible_instances(multimesh, count)
