class_name WorldObject
extends RefCounted
## One placed thing (docs/WORLD_OBJECTS.md 2.2): a row in WorldObjects.
## Pure data; what draws it is decided per frame by its tier.
##
##   id      "lobby.coffee_cup.0", stable across saves. Rooms number their
##           baked props in build order; things the player places get
##           "p.<n>".
##   prop    the manifest id (PropLibrary)
##   room    the VenueRoom id, or "" while held in the bag
##   xf      transform in venue space (pivot at the prop's floor centre)
##   state   {"read": true, "open": false, ...}, written by verbs
##   flags   "placed_by_player" (the row is loose: not part of its room's
##           build, drawn by the field or its own node), "held" (in the
##           bag), "keepsake", "owner"
##   tier    BAKED (in the room's MultiMesh or the resting field, no node),
##           INSTANCED (reserved for P2), LIVE (a node: LiveProp)
##   age     the look it was placed with (Wear.WORN ...)

enum { BAKED, INSTANCED, LIVE }

var id := &""
var prop := &""
var room := &""
var xf := Transform3D.IDENTITY
var state := {}
var flags := PackedStringArray()
var tier := BAKED
var age := 0

## Runtime only (never saved): the room MultiMesh and instance that draws a
## baked row, the live node, and the hash cells the row is filed under.
var bake: Array = []  # [MultiMeshInstance3D, index]
var node: Node3D
var cells: Array[Vector3i] = []


func has_flag(f: String) -> bool:
	return flags.has(f)


func add_flag(f: String) -> void:
	if not flags.has(f):
		flags.append(f)


func remove_flag(f: String) -> void:
	var i := flags.find(f)
	if i >= 0:
		flags.remove_at(i)


## Loose rows aren't drawn by their room's build: the field or a node draws them.
func loose() -> bool:
	return has_flag("placed_by_player")


func held() -> bool:
	return has_flag("held")


func name() -> String:
	return PropLibrary.display_name(prop)


## The row's box in venue space (the prop's voxel bounds, placed).
func bounds() -> AABB:
	var b := PropLibrary.bounds(prop, age)
	return xf * b


## The prop's shape-following boxes, placed: what a look ray tests, so a
## cup on a counter is the cup, not the counter's box around it.
func boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for b in PropLibrary.collision_boxes(prop, age):
		out.append(xf * b)
	if out.is_empty():
		out.append(bounds())
	return out


func to_dict() -> Dictionary:
	var o := xf.origin
	var b := xf.basis
	return {
		"id": String(id), "prop": String(prop), "room": String(room),
		"pos": [snappedf(o.x, 0.001), snappedf(o.y, 0.001), snappedf(o.z, 0.001)],
		"basis": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z],
		"state": state.duplicate(true), "flags": Array(flags), "age": age,
	}


static func from_dict(d: Dictionary) -> WorldObject:
	var w := WorldObject.new()
	w.id = StringName(str(d.get("id", "")))
	w.prop = StringName(str(d.get("prop", "")))
	w.room = StringName(str(d.get("room", "")))
	var p: Array = d.get("pos", [0, 0, 0])
	var b: Array = d.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
	w.xf = Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])), Vector3(p[0], p[1], p[2]))
	w.state = (d.get("state", {}) as Dictionary).duplicate(true)
	for f in d.get("flags", []):
		w.flags.append(str(f))
	w.age = int(d.get("age", 0))
	return w
