class_name WorldObjects
extends RefCounted
## Every placed thing in a venue, as rows (docs/WORLD_OBJECTS.md 2.2): the
## one record the look prompt, the verbs, the inventory and the save agree
## on. Pure data with a per-room spatial hash; nothing here is a node.
##
##   spawn(prop, room, xf)        a new row (ids "p.<n>" for player-placed)
##   remove(id), set_state(id, key, value), move(id, room, xf)
##   query(room, tags)            rows in a room, optionally with every tag
##   nearest(pos, r, room)        the row whose box is nearest a point
##   at(pos, room)                the smallest row whose box holds a point
##   raycast(from, to)            the first row a look ray crosses
##   to_dict() / from_dict()      the "objects" key of the owner save
##
## Rooms place through the store: VenueKit.commit() calls bake() with the
## props it just drew, and every one gets a row (tier BAKED) with the
## MultiMesh instance that draws it, so a taken thing can be hidden without
## rebuilding the room. A rebuild (renovation) re-bakes: rows the player
## moved, took or placed survive it.

signal changed(row: WorldObject)

const CELL := 1.0
## Rows are filed under every cell within this of their box, so a ray or a
## point needs one cell lookup per step, no neighbour scan.
const FILE_GROW := 0.55
const SAVE_VERSION := 1

var rows := {}         # id -> WorldObject
var _hash := {}        # room -> {Vector3i -> Array[StringName]}
var _counts := {}      # "room/prop" -> next bake index
var _next_player := 1


# ---------------------------------------------------------------- rows

func spawn(prop: StringName, room: StringName, xf: Transform3D, flags: Array = [], id := &"", age := 0) -> WorldObject:
	var w := WorldObject.new()
	if id == &"":
		while rows.has(StringName("p.%d" % _next_player)):
			_next_player += 1
		id = StringName("p.%d" % _next_player)
		_next_player += 1
	w.id = id
	w.prop = prop
	w.room = room
	w.xf = xf
	w.age = age
	for f in flags:
		w.add_flag(str(f))
	rows[id] = w
	_file(w)
	changed.emit(w)
	return w


func remove(id: StringName) -> void:
	var w: WorldObject = rows.get(id)
	if w == null:
		return
	_unfile(w)
	rows.erase(id)
	changed.emit(w)


func get_row(id: StringName) -> WorldObject:
	return rows.get(id)


func has(id: StringName) -> bool:
	return rows.has(id)


func set_state(id: StringName, key: String, value: Variant) -> void:
	var w: WorldObject = rows.get(id)
	if w:
		w.state[key] = value
		changed.emit(w)


## Moves a row (a drop, a push that settled): refiles it under its new room.
func move(id: StringName, room: StringName, xf: Transform3D) -> void:
	var w: WorldObject = rows.get(id)
	if w == null:
		return
	_unfile(w)
	w.room = room
	w.xf = xf
	_file(w)
	changed.emit(w)


## Takes a row out of the world (into the bag): it keeps its id and state,
## leaves the hash, and its baked instance (if any) is hidden.
func take(id: StringName) -> void:
	var w: WorldObject = rows.get(id)
	if w == null:
		return
	_unfile(w)
	hide_bake(w)
	w.room = &""
	w.add_flag("held")
	w.tier = WorldObject.BAKED
	changed.emit(w)


## Puts a held row back into the world, loose, at `xf` in `room`.
func place(id: StringName, room: StringName, xf: Transform3D) -> void:
	var w: WorldObject = rows.get(id)
	if w == null:
		return
	w.remove_flag("held")
	w.add_flag("placed_by_player")
	move(id, room, xf)


func count() -> int:
	return rows.size()


func count_live() -> int:
	var n := 0
	for w in rows.values():
		if w.tier == WorldObject.LIVE:
			n += 1
	return n


func count_loose() -> int:
	var n := 0
	for w in rows.values():
		if w.loose() and not w.held():
			n += 1
	return n


## Rows held in the bag.
func held() -> Array[WorldObject]:
	var out: Array[WorldObject] = []
	for w in rows.values():
		if w.held():
			out.append(w)
	return out


# ---------------------------------------------------------------- queries

## Rows in `room` ("" for every room) carrying every tag in `tags`.
func query(room: StringName, tags: Array = []) -> Array[WorldObject]:
	var out: Array[WorldObject] = []
	for w in rows.values():
		if room != &"" and w.room != room:
			continue
		if w.held():
			continue
		var ok := true
		for t in tags:
			if not PropLibrary.tags(w.prop).has(t):
				ok = false
				break
		if ok:
			out.append(w)
	return out


## The row whose box is nearest `pos` within `r` metres, or null.
func nearest(pos: Vector3, r: float, room := &"") -> WorldObject:
	var best: WorldObject = null
	var best_d := r
	for w in _candidates(AABB(pos - Vector3.ONE * r, Vector3.ONE * 2.0 * r), room):
		var b := w.bounds()
		var d := _box_distance(b, pos)
		if d < best_d:
			best_d = d
			best = w
	return best


## The smallest row whose box (grown by `slack`) holds `pos`, or null.
func at(pos: Vector3, room := &"", slack := 0.05) -> WorldObject:
	var best: WorldObject = null
	var best_v := INF
	for w in _candidates(AABB(pos, Vector3.ZERO).grow(slack), room):
		var b := w.bounds().grow(slack)
		if b.has_point(pos) and b.get_volume() < best_v:
			best_v = b.get_volume()
			best = w
	return best


## How much nearer a big thing's box must be entered before it beats a
## small thing behind or on it (a cup on a counter is the cup).
const NEAR_TIE := 0.35


## The first row a segment crosses (a look ray), or null: the nearest of
## the rows' shape boxes (WorldObject.boxes) along it, the smaller row
## winning a near tie. Walks the hash cells along the segment so a room of
## hundreds of rows costs a handful of lookups.
func raycast(from: Vector3, to: Vector3, room := &"") -> WorldObject:
	var best: WorldObject = null
	var best_t := INF
	var best_v := INF
	var seen := {}
	var dir := to - from
	var len := dir.length()
	if len < 0.001:
		return at(from, room)
	var steps := ceili(len / (CELL * 0.5))
	for i in steps + 1:
		var p := from + dir * (float(i) / steps)
		var cell := _cell(p)
		for rm in ([room] if room != &"" else _hash.keys()):
			var cells: Dictionary = _hash.get(rm, {})
			if not cells.has(cell):
				continue
			for id in cells[cell]:
				if seen.has(id):
					continue
				seen[id] = true
				var w: WorldObject = rows[id]
				if w.bounds().grow(0.03).intersects_segment(from, to) == null:
					continue
				var t := INF
				for box in w.boxes():
					var hit: Variant = box.grow(0.03).intersects_segment(from, to)
					if hit != null:
						t = minf(t, (hit as Vector3).distance_to(from))
				if t == INF:
					continue
				var v := w.bounds().get_volume()
				var wins := t < best_t - NEAR_TIE or (t < best_t + NEAR_TIE and v < best_v)
				if wins:
					best_t = t
					best_v = v
					best = w
		if best and best_t + NEAR_TIE < float(i) / steps * len:
			break
	return best


# ---------------------------------------------------------------- baking

## The rooms' props: `props` is VenueKit's list of [prop id, Transform3D,
## mesh, age] in build order, `mm_by_mesh` the MultiMeshInstance3D that
## draws each mesh. The room's old baked rows go first; rows the player has
## taken, moved or placed survive and keep hiding the instance that would
## have drawn them.
func bake(room: StringName, props: Array, mm_by_mesh: Dictionary) -> void:
	unbake(room)
	var index := {}  # mesh -> next instance index
	for p in props:
		var prop: StringName = StringName(p[0])
		var xf: Transform3D = p[1]
		var mesh = p[2]
		var age: int = p[3]
		var i: int = index.get(mesh, 0)
		index[mesh] = i + 1
		var key := "%s/%s" % [room, prop]
		var n: int = _counts.get(key, 0)
		_counts[key] = n + 1
		var id := StringName("%s.%s.%d" % [room, prop, n])
		var mmi: MultiMeshInstance3D = mm_by_mesh.get(mesh)
		var info: Array = [mmi, i] if mmi else []
		var w: WorldObject = rows.get(id)
		if w and (w.loose() or w.held()):
			# the player did something to it: the build's copy isn't drawn
			w.bake = info
			hide_bake(w)
			continue
		if w:
			_unfile(w)
		else:
			w = WorldObject.new()
			w.id = id
			rows[id] = w
		w.prop = prop
		w.room = room
		w.xf = xf
		w.age = age
		w.tier = WorldObject.BAKED
		w.bake = info
		_file(w)


## Forgets the rows a room's build made (before it builds again). Loose and
## held rows stay.
func unbake(room: StringName) -> void:
	for id in rows.keys():
		var w: WorldObject = rows[id]
		if w.room == room and not w.loose() and not w.held():
			_unfile(w)
			rows.erase(id)
		elif w.loose() or w.held():
			w.bake = []  # the old MultiMesh is gone with the room
	for key in _counts.keys():
		if key.begins_with("%s/" % room):
			_counts.erase(key)


## Hides the room instance that drew a row (a taken or moved thing).
func hide_bake(w: WorldObject) -> void:
	if w.bake.size() != 2 or not is_instance_valid(w.bake[0]):
		return
	var mmi: MultiMeshInstance3D = w.bake[0]
	if mmi.multimesh and int(w.bake[1]) < mmi.multimesh.instance_count:
		mmi.multimesh.set_instance_transform(int(w.bake[1]), Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -1000, 0)))


# ---------------------------------------------------------------- saves

## Everything the build can't recreate: rows the player placed, moved, took
## or changed. Untouched baked rows come back from the room build.
func to_dict() -> Dictionary:
	var list: Array = []
	for w in rows.values():
		if w.loose() or w.held() or not w.state.is_empty():
			list.append(w.to_dict())
	return {"version": SAVE_VERSION, "rows": list, "next": _next_player}


static func from_dict(d: Dictionary) -> WorldObjects:
	var s := WorldObjects.new()
	s.load_dict(d)
	return s


## Merges a save into this store (over the rows the rooms baked): a saved
## row replaces the baked one with the same id, hiding its instance when
## the player moved or took it; new ids are player-placed rows.
func load_dict(d: Dictionary) -> void:
	_next_player = maxi(_next_player, int(d.get("next", 1)))
	for e in d.get("rows", []):
		var w := WorldObject.from_dict(e)
		if w.id == &"" or w.prop == &"":
			continue
		var old: WorldObject = rows.get(w.id)
		if old:
			_unfile(old)
			w.bake = old.bake
			if w.loose() or w.held():
				hide_bake(w)
		rows[w.id] = w
		if not w.held():
			_file(w)
		changed.emit(w)


# ---------------------------------------------------------------- the hash

func _cell(p: Vector3) -> Vector3i:
	return Vector3i((p / CELL).floor())


func _file(w: WorldObject) -> void:
	if w.room == &"":
		return
	if not _hash.has(w.room):
		_hash[w.room] = {}
	var cells: Dictionary = _hash[w.room]
	var b := w.bounds().grow(FILE_GROW)
	var lo := _cell(b.position)
	var hi := _cell(b.end)
	w.cells.clear()
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var c := Vector3i(x, y, z)
				if not cells.has(c):
					cells[c] = []
				cells[c].append(w.id)
				w.cells.append(c)


func _unfile(w: WorldObject) -> void:
	var cells: Dictionary = _hash.get(w.room, {})
	for c in w.cells:
		if cells.has(c):
			cells[c].erase(w.id)
			if cells[c].is_empty():
				cells.erase(c)
	w.cells.clear()


func _candidates(box: AABB, room: StringName) -> Array[WorldObject]:
	var out: Array[WorldObject] = []
	var seen := {}
	var lo := _cell(box.position)
	var hi := _cell(box.end)
	for rm in ([room] if room != &"" else _hash.keys()):
		var cells: Dictionary = _hash.get(rm, {})
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					for id in cells.get(Vector3i(x, y, z), []):
						if not seen.has(id):
							seen[id] = true
							out.append(rows[id])
	return out


static func _box_distance(b: AABB, p: Vector3) -> float:
	var q := p.clamp(b.position, b.end)
	return q.distance_to(p)
