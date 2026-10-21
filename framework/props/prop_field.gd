class_name PropField
extends Node3D
## Thousands of physical props with no node each. Every placed thing is a
## PropRow; the field draws rows through RenderingServer MultiMeshes (one per
## mesh per CELL-metre cell, so frustum culling and visibility range work
## per cell; a row with a low-detail mesh has a second batch that takes over
## beyond lod_distance) and collides them through PhysicsServer3D: one static body per
## cell carrying every row's box shapes (two hundred bodies instead of ten
## thousand: Jolt's step cost for resting rows is then too small to
## measure). A physics ray reports the cell body and the shape
## index, which maps back to the row. A row becomes a real RigidBody3D
## (Jolt) only while something needs it to move: `wake()` on a shove, a
## pick-up, a drop. When the body sleeps, and is far from `focus` or the
## live cap is reached, the field writes its resting transform back and the
## row is instanced again. This generalises StickField / LooseProp to
## everything in the building.
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
## A live row hit something (a wall, the floor, another body): the row, what
## it hit, the closing speed in m/s and where. Rate limited per row, so a
## rolling mug does not fire every step; ContactAudio listens to this.
signal contact(row: PropRow, other: Node, speed: float, at: Vector3)

const CELL := 8.0
const TICK := 0.5
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0, -1000, 0))
const MIN_BOX := Vector3(0.02, 0.02, 0.02)
const CONTACT_GAP := 0.12  # s between contact signals from one row

## Most rows that may be rigid bodies at once.
@export var live_cap := 64
## A sleeping body farther than this from `focus` goes back to a row.
@export var sleep_radius := 24.0
## Rows are not drawn beyond this distance (0 = always).
@export var draw_range := 60.0
## Beyond this distance a row with a low-detail mesh draws that instead
## (per cell, with a short fade; 0 = always full detail).
@export var lod_distance := 7.0
## Physics layer bit (1-based) rows and bodies sit on, and what they hit.
@export var layer := Layers.PROPS
@export var mask := Layers.mask([Layers.VENUE, Layers.PROPS, Layers.WALKER])
@export var cast_shadows := true
## Off: rows collide and pick but are not drawn (a server, a test, a field
## whose rows are drawn by something else).
@export var draw := true

var focus := Vector3.ZERO
var rows: Array[PropRow] = []

var _by_id := {}  # StringName -> PropRow
var _by_rid := {}  # cell body RID -> _Cell
var _by_node := {}  # RigidBody3D -> PropRow
var _batches := {}  # "mesh rid id:cx,cy,cz" -> _Batch
var _cells := {}  # Vector3i -> _Cell
var _shapes := {}  # Mesh -> Array[[RID, Transform3D]] (shared box shapes)
var _live: Array[PropRow] = []
var _pending: Array[PropRow] = []  # added before the field entered the tree
var _dirty := {}  # _Cell -> true: shapes changed, body rebuilt at end of frame
var _rebuilds := 0
var _flush_usec := 0
var _t := 0.0
var _tick_usec := 0
var _scenario := RID()
var _space := RID()
var _contact_t := {}  # PropRow -> last contact time (s)
var _prev_v := {}  # PropRow -> linear velocity before the last physics step


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
	for c in _cells.values():
		c.dispose()
	_cells.clear()
	_by_rid.clear()
	_dirty.clear()
	for shapes in _shapes.values():
		for s in shapes:
			PhysicsServer3D.free_rid(s[0])
	_shapes.clear()
	_pending = rows.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		for b in _batches.values():
			RenderingServer.instance_set_transform(b.instance, global_transform)
		for c in _cells.values():
			PhysicsServer3D.body_set_state(
				c.body, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform
			)


func _physics_process(_dt: float) -> void:
	# the velocity a body had going into the step: by the time body_entered
	# fires the contact has already taken it away
	for r in _live:
		if r.node:
			_prev_v[r] = r.node.linear_velocity


func _process(dt: float) -> void:
	if not _dirty.is_empty():
		flush()
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
	id: StringName,
	prop: StringName,
	mesh: Mesh,
	boxes: Array[AABB],
	xf: Transform3D,
	mass := 1.0,
	mesh_lod: Mesh = null
) -> PropRow:
	if _by_id.has(id):
		push_error("PropField: duplicate row id %s" % id)
		return _by_id[id]
	var r := PropRow.new()
	r.id = id
	r.prop = prop
	r.mesh = mesh
	r.mesh_lod = mesh_lod if mesh_lod != mesh else null
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
	if r.batch_lod:
		r.batch_lod.set_transform(r.slot_lod, xf)
	_mark(_cells[r.cell])


## The look-at glow (0..1) on a row, instanced or live.
func set_highlight(r: PropRow, h: float) -> void:
	r.highlight = clampf(h, 0.0, 1.0)
	_restyle(r)


## The colour multiplier (the renovation ages) on a row.
func set_tint(r: PropRow, c: Color) -> void:
	r.tint = c
	_restyle(r)


func _restyle(r: PropRow) -> void:
	if r.node:
		for c in r.node.get_children():
			if c is MeshInstance3D and c.material_override is ShaderMaterial:
				c.material_override.set_shader_parameter("inst_tint", r.tint)
				c.material_override.set_shader_parameter("inst_highlight", r.highlight)
	elif r.batch and r.slot >= 0:
		r.batch.set_style(r.slot, r.tint, r.highlight)
		if r.batch_lod:
			r.batch_lod.set_style(r.slot_lod, r.tint, r.highlight)


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
	for box in _boxes_of(r):
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size.max(MIN_BOX)
		cs.shape = bs
		cs.position = box.get_center()
		b.add_child(cs)
	if r.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = r.mesh
		mi.material_override = PropMaterial.for_body(r.tint, r.highlight)
		mi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		b.add_child(mi)
	b.transform = r.xf
	b.contact_monitor = true
	b.max_contacts_reported = 4
	add_child(b)
	b.sleeping_state_changed.connect(_on_sleep_change.bind(r))
	b.body_entered.connect(_on_body_entered.bind(r))
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
	_prev_v.erase(r)
	_contact_t.erase(r)
	r.node = null
	b.queue_free()
	r.tier = PropRow.Tier.INSTANCED
	_instance(r)
	slept.emit(r)


func is_live(r: PropRow) -> bool:
	return r.node != null


# --- queries -------------------------------------------------------------


## The row a physics ray hit (its `rid` and `shape`, or `collider`), or null.
func row_of(hit: Dictionary) -> PropRow:
	if hit.is_empty():
		return null
	var rid: Variant = hit.get("rid")
	if rid is RID and _by_rid.has(rid):
		var c: _Cell = _by_rid[rid]
		return c.row_at_shape(int(hit.get("shape", -1)))
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
				var c: _Cell = _cells.get(Vector3i(x, y, z))
				if c == null:
					continue
				for r in c.rows:
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
		"rebuilds": _rebuilds,
		"rebuild_ms": _flush_usec / 1000.0,
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
	if draw:
		var far := draw_range
		var near := lod_distance if (r.mesh_lod and lod_distance > 0.0) else 0.0
		var b: _Batch = _batches.get(key)
		if b == null:
			b = _Batch.new(
				r.mesh, _scenario, global_transform, 0.0, near if near > 0.0 else far, cast_shadows
			)
			_batches[key] = b
		r.batch = b
		r.slot = b.add(r)
		if near > 0.0:
			var lkey := key + ":lod"
			var bl: _Batch = _batches.get(lkey)
			if bl == null:
				bl = _Batch.new(r.mesh_lod, _scenario, global_transform, near, far, cast_shadows)
				_batches[lkey] = bl
			r.batch_lod = bl
			r.slot_lod = bl.add(r)
	var c: _Cell = _cells.get(r.cell)
	if c == null:
		c = _Cell.new()
		_cells[r.cell] = c
	c.rows.append(r)
	_mark(c)


func _uninstance(r: PropRow) -> void:
	if r.batch:
		var moved: PropRow = r.batch.remove(r.slot)
		if moved:
			moved.slot = r.slot
		_drop_empty(r.batch)
		r.batch = null
		r.slot = -1
	if r.batch_lod:
		var moved_l: PropRow = r.batch_lod.remove(r.slot_lod)
		if moved_l:
			moved_l.slot_lod = r.slot_lod
		_drop_empty(r.batch_lod)
		r.batch_lod = null
		r.slot_lod = -1
	var c: _Cell = _cells.get(r.cell)
	if c and c.rows.has(r):
		c.rows.erase(r)
		if c.rows.is_empty():
			_cells.erase(r.cell)
			_by_rid.erase(c.body)
			_dirty.erase(c)
			c.dispose()
		else:
			_mark(c)


## Shape changes are batched: a cell whose rows changed rebuilds its body
## once, at the start of the next idle frame, with every shape added before
## the body enters the space (so Jolt builds one static compound; the whole
## rebuild of ten thousand rows in two hundred cells takes about 30 ms, and
## a single cell well under a millisecond). Rows show up to rays and bodies
## on the frame after `add`; `flush()` forces it in the same frame.
func _mark(c: _Cell) -> void:
	_dirty[c] = true


## Applies pending shape changes now (otherwise they apply at the start of
## the next idle frame).
func flush() -> void:
	if not is_inside_tree():
		return
	var t0 := Time.get_ticks_usec()
	for c in _dirty:
		if c.body.is_valid():
			_by_rid.erase(c.body)
		c.rebuild(_space, global_transform, 1 << (layer - 1), mask, get_instance_id(), _shapes_for)
		_by_rid[c.body] = c
		_rebuilds += 1
	_dirty.clear()
	_flush_usec += Time.get_ticks_usec() - t0


func _drop_empty(b: _Batch) -> void:
	if b.count > 0:
		return
	for key in _batches:
		if _batches[key] == b:
			_batches.erase(key)
			break
	b.dispose()


func _boxes_of(r: PropRow) -> Array[AABB]:
	if r.boxes.is_empty():
		return [AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))]
	return r.boxes


## Box shapes are shared by every row of one mesh (the boxes come from the
## mesh's model, so they match).
func _shapes_for(r: PropRow) -> Array:
	var key: Variant = r.mesh if r.mesh else r.prop
	if _shapes.has(key):
		return _shapes[key]
	var out: Array = []
	for box in _boxes_of(r):
		var s := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(s, box.size.max(MIN_BOX) * 0.5)
		out.append([s, Transform3D(Basis.IDENTITY, box.get_center())])
	_shapes[key] = out
	return out


func _on_body_entered(other: Node, r: PropRow) -> void:
	var b := r.node
	if b == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_contact_t.get(r, -1.0)) < CONTACT_GAP:
		return
	_contact_t[r] = now
	var v: Vector3 = _prev_v.get(r, b.linear_velocity)
	if other is RigidBody3D:
		v -= other.linear_velocity
	elif other is CharacterBody3D:
		v -= other.velocity
	contact.emit(r, other, v.length(), b.global_position)


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


## One static body for one cell: every instanced row's box shapes, in row
## order, so a ray's shape index finds its row. The body is rebuilt whole
## (see PropField._mark) rather than edited in place.
class _Cell:
	extends RefCounted
	var body := RID()
	var rows: Array[PropRow] = []  # in shape order
	var _start := {}  # PropRow -> first shape index
	var _count := {}  # PropRow -> shapes

	func dispose() -> void:
		if body.is_valid():
			PhysicsServer3D.free_rid(body)
		body = RID()

	func rebuild(
		space: RID,
		xf: Transform3D,
		layer_bits: int,
		mask_bits: int,
		owner_id: int,
		shapes_for: Callable
	) -> void:
		dispose()
		_start.clear()
		_count.clear()
		body = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, layer_bits)
		PhysicsServer3D.body_set_collision_mask(body, mask_bits)
		PhysicsServer3D.body_attach_object_instance_id(body, owner_id)
		var total := 0
		for r in rows:
			var shapes: Array = shapes_for.call(r)
			_start[r] = total
			_count[r] = shapes.size()
			for s in shapes:
				PhysicsServer3D.body_add_shape(body, s[0], r.xf * s[1])
			total += shapes.size()
		# into the space last, so Jolt builds one static compound
		PhysicsServer3D.body_set_space(body, space)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)

	func row_at_shape(idx: int) -> PropRow:
		if idx < 0:
			return null
		for r in rows:
			var s: int = _start.get(r, -1)
			if s >= 0 and idx >= s and idx < s + _count[r]:
				return r
		return null


## One MultiMesh for one mesh in one cell, kept on the RenderingServer.
class _Batch:
	extends RefCounted
	var multimesh := RID()
	var instance := RID()
	var mesh: Mesh
	var rows: Array[PropRow] = []
	var count := 0
	var capacity := 0

	func _init(
		m: Mesh, scenario: RID, xf: Transform3D, near: float, far: float, shadows: bool
	) -> void:
		mesh = m
		multimesh = RenderingServer.multimesh_create()
		if m:
			RenderingServer.multimesh_set_mesh(multimesh, m.get_rid())
		instance = RenderingServer.instance_create2(multimesh, scenario)
		RenderingServer.instance_set_transform(instance, xf)
		RenderingServer.instance_geometry_set_material_override(
			instance, PropMaterial.shared().get_rid()
		)
		RenderingServer.instance_geometry_set_cast_shadows_setting(
			instance,
			(
				RenderingServer.SHADOW_CASTING_SETTING_ON
				if shadows
				else RenderingServer.SHADOW_CASTING_SETTING_OFF
			)
		)
		if near > 0.0 or far > 0.0:
			# the full-detail batch ends where the low-detail one begins; the
			# margins overlap a little so the switch is a short cross-fade
			RenderingServer.instance_geometry_set_visibility_range(
				instance,
				near,
				far,
				0.5 if near > 0.0 else 0.0,
				0.5 if far > 0.0 else 0.0,
				RenderingServer.VISIBILITY_RANGE_FADE_SELF
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
		RenderingServer.multimesh_instance_set_custom_data(
			multimesh, slot, PropMaterial.custom(r.tint, r.highlight)
		)
		return slot

	## Swap-removes `slot`; returns the row that moved into it (or null).
	func remove(slot: int) -> PropRow:
		var last := count - 1
		var moved: PropRow = null
		if slot != last:
			moved = rows[last]
			rows[slot] = moved
			RenderingServer.multimesh_instance_set_transform(multimesh, slot, moved.xf)
			RenderingServer.multimesh_instance_set_custom_data(
				multimesh, slot, PropMaterial.custom(moved.tint, moved.highlight)
			)
		rows.resize(last)
		count = last
		RenderingServer.multimesh_instance_set_transform(multimesh, last, HIDDEN)
		RenderingServer.multimesh_set_visible_instances(multimesh, count)
		return moved

	func set_transform(slot: int, xf: Transform3D) -> void:
		RenderingServer.multimesh_instance_set_transform(multimesh, slot, xf)

	func set_style(slot: int, tint: Color, highlight: float) -> void:
		RenderingServer.multimesh_instance_set_custom_data(
			multimesh, slot, PropMaterial.custom(tint, highlight)
		)

	## Allocating clears the buffer, so every transform is written again.
	func _reserve(n: int) -> void:
		capacity = n
		# colour on as well as custom data: the Compatibility renderer feeds a
		# zero instance colour to a MultiMesh that has custom data but no colour
		RenderingServer.multimesh_allocate_data(
			multimesh, capacity, RenderingServer.MULTIMESH_TRANSFORM_3D, true, true
		)
		for i in capacity:
			RenderingServer.multimesh_instance_set_color(multimesh, i, Color.WHITE)
		for i in count:
			RenderingServer.multimesh_instance_set_transform(multimesh, i, rows[i].xf)
			RenderingServer.multimesh_instance_set_custom_data(
				multimesh, i, PropMaterial.custom(rows[i].tint, rows[i].highlight)
			)
		for i in range(count, capacity):
			RenderingServer.multimesh_instance_set_transform(multimesh, i, HIDDEN)
		RenderingServer.multimesh_set_visible_instances(multimesh, count)
