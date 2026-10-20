class_name ItemCatalog
extends RefCounted
## What the owner can carry, and the shape each thing takes in the grid
## inventory (playtest #19): a list of occupied cells at rotation 0, origin
## at the top-left. Long tools are long, the crampons are a fat square, a
## hammer is a T. `flag` ties an item to WalkStory's pickup flags, so what
## the walk already hands out (the keys, Doris's spark plugs) lands in the
## grid too.

const ITEMS := {
	"keys": {"name": "Rink keys", "shape": [Vector2i(0, 0)], "flag": "keys",
		"desc": "Front doors, plant room, office. The plant room one sticks."},
	"watch_box": {"name": "Watch box", "shape": [Vector2i(0, 0)],
		"desc": "A new watch, still in its box."},
	"spark_plugs": {"name": "Spark plugs (4)", "shape": [Vector2i(0, 0), Vector2i(1, 0)], "flag": "spark_plugs",
		"desc": "Champion RN12YC for Doris's Ford 300."},
	"tape": {"name": "Hockey tape", "shape": [Vector2i(0, 0)], "desc": "Black cloth tape."},
	"puck": {"name": "Puck", "shape": [Vector2i(0, 0)], "desc": "Frozen pucks bounce less."},
	"notebook": {"name": "Notebook", "shape": [Vector2i(0, 0), Vector2i(0, 1)], "desc": "Readings, phone numbers, lists."},
	"gus_note": {"name": "Gus's note", "shape": [Vector2i(0, 0)], "desc": "Folded twice. Smells of glycol."},
	"flashlight": {"name": "Flashlight", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"desc": "Three D cells. The plant room is dark behind the compressors."},
	"wrench": {"name": "Pipe wrench", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
		"desc": "Eighteen inches of Ridgid."},
	"hammer": {"name": "Hammer", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"desc": "Claw hammer from the workshop."},
	"calipers": {"name": "Dial calipers", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
		"desc": "For the ice depth plates."},
	"crampons": {"name": "Gus's ice crampons", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "flag": "crampons",
		"desc": "Strap-on spikes. Walk the ice in shoes without the wobble.", "wear": "feet"},
	"gloves": {"name": "Work gloves", "shape": [Vector2i(0, 0), Vector2i(1, 0)], "desc": "Cold hands shake."},
	"scoresheet": {"name": "Scoresheet pad", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
		"desc": "Carbon triplicate game sheets for the scorekeeper's box."},
}


static func has(id: String) -> bool:
	# World objects: a prop with the `take` verb is an item too (PropLibrary)
	return ITEMS.has(id) or not PropLibrary.item_info(id).is_empty()


static func info(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	return PropLibrary.item_info(id)  # World objects: name, shape and desc from the manifest


static func display_name(id: String) -> String:
	return str(info(id).get("name", id))


## The item's cells at `rot` quarter turns clockwise, shifted back to start
## at (0, 0).
static func shape(id: String, rot := 0) -> Array:
	var cells: Array = info(id).get("shape", [Vector2i.ZERO])
	return rotate_cells(cells, rot)


static func rotate_cells(cells: Array, rot: int) -> Array:
	var out: Array = []
	for c in cells:
		var v: Vector2i = c
		for i in posmod(rot, 4):
			v = Vector2i(-v.y, v.x)  # a quarter turn clockwise (y points down)
		out.append(v)
	var lo := Vector2i(1 << 20, 1 << 20)
	for v in out:
		lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
	for i in out.size():
		out[i] = (out[i] as Vector2i) - lo
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The item id a WalkStory flag stands for, or "".
static func for_flag(flag: String) -> String:
	for id in ITEMS:
		if str(ITEMS[id].get("flag", "")) == flag:
			return id
	return ""
