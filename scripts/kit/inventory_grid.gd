class_name InventoryGrid
extends RefCounted
## The owner's grid inventory (playtest #19): a W x H bag where each item
## covers the cells of its shape (ItemCatalog), turned in quarter steps.
## Nothing overlaps or hangs off the edge. Only on foot: hockey has no
## inventory.

const START_SIZE := Vector2i(6, 4)

var size := START_SIZE
## [{"uid", "id", "pos": Vector2i, "rot"}]
var items: Array = []
var _next_uid := 1


## The cells item `id` would cover at `pos` turned `rot` times.
static func cells_of(id: String, pos: Vector2i, rot: int) -> Array:
	var out: Array = []
	for c in ItemCatalog.shape(id, rot):
		out.append(pos + (c as Vector2i))
	return out


func _occupied(ignore_uid := -1) -> Dictionary:
	var taken := {}
	for it in items:
		if int(it.uid) == ignore_uid:
			continue
		for c in cells_of(it.id, it.pos, int(it.rot)):
			taken[c] = int(it.uid)
	return taken


func fits(id: String, pos: Vector2i, rot: int, ignore_uid := -1) -> bool:
	if not ItemCatalog.has(id):
		return false
	var taken := _occupied(ignore_uid)
	for c in cells_of(id, pos, rot):
		var v: Vector2i = c
		if v.x < 0 or v.y < 0 or v.x >= size.x or v.y >= size.y or taken.has(v):
			return false
	return true


## Puts item `id` at `pos`, turned `rot`. Returns its uid, or -1.
func place(id: String, pos: Vector2i, rot := 0) -> int:
	if not fits(id, pos, rot):
		return -1
	var uid := _next_uid
	_next_uid += 1
	items.append({"uid": uid, "id": id, "pos": pos, "rot": posmod(rot, 4)})
	return uid


## Finds room for `id` (row by row, every rotation). Returns its uid, or -1
## when the bag is full for that shape.
func add(id: String) -> int:
	for rot in 4:
		for y in size.y:
			for x in size.x:
				if fits(id, Vector2i(x, y), rot):
					return place(id, Vector2i(x, y), rot)
	return -1


func get_item(uid: int) -> Dictionary:
	for it in items:
		if int(it.uid) == uid:
			return it
	return {}


## Moves (and turns) an item already in the bag. False if it doesn't fit there.
func move(uid: int, pos: Vector2i, rot: int) -> bool:
	var it := get_item(uid)
	if it.is_empty() or not fits(it.id, pos, rot, uid):
		return false
	it.pos = pos
	it.rot = posmod(rot, 4)
	return true


func remove(uid: int) -> Dictionary:
	var it := get_item(uid)
	if not it.is_empty():
		items.erase(it)
	return it


## The uid covering `cell`, or -1.
func uid_at(cell: Vector2i) -> int:
	return int(_occupied().get(cell, -1))


func has(id: String) -> bool:
	return count(id) > 0


func count(id: String) -> int:
	var n := 0
	for it in items:
		if it.id == id:
			n += 1
	return n


## Takes one `id` out of the bag. Returns true if there was one.
func take(id: String) -> bool:
	for it in items:
		if it.id == id:
			items.erase(it)
			return true
	return false


## A bigger bag: everything keeps its place.
func grow(new_size: Vector2i) -> void:
	size = Vector2i(maxi(size.x, new_size.x), maxi(size.y, new_size.y))


func free_cells() -> int:
	return size.x * size.y - _occupied().size()


func to_dict() -> Dictionary:
	var list: Array = []
	for it in items:
		list.append({"id": it.id, "x": it.pos.x, "y": it.pos.y, "rot": it.rot})
	return {"w": size.x, "h": size.y, "items": list}


static func from_dict(d: Dictionary) -> InventoryGrid:
	var g := InventoryGrid.new()
	g.size = Vector2i(int(d.get("w", START_SIZE.x)), int(d.get("h", START_SIZE.y)))
	for e in d.get("items", []):
		g.place(str(e.id), Vector2i(int(e.x), int(e.y)), int(e.rot))
	return g
