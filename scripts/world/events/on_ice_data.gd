class_name OnIceData
extends RefCounted
## The data behind the on-ice events (docs/world/ON_ICE.md):
## data/world/on_ice.json (rosters, pee-wee groups, demand, rental, racks)
## and data/world/drills.json (every drill: layout, paths, timing).
## Loaded once and cached.

const ON_ICE_PATH := "res://data/world/on_ice.json"
const DRILLS_PATH := "res://data/world/drills.json"
const CAST_PATH := "res://data/world/cast.json"

static var _on_ice := {}
static var _drills := {}
static var _cast_looks := {}


static func on_ice() -> Dictionary:
	if _on_ice.is_empty():
		_on_ice = _json(ON_ICE_PATH)
	return _on_ice


static func section(key: String) -> Dictionary:
	var v: Variant = on_ice().get(key, {})
	return v if v is Dictionary else {}


static func drills() -> Dictionary:
	if _drills.is_empty():
		var d := _json(DRILLS_PATH)
		for e in d.get("drills", []):
			if e is Dictionary:
				_drills[str(e.get("id", ""))] = e
	return _drills


static func drill(id: String) -> Dictionary:
	var v: Variant = drills().get(id, {})
	return v if v is Dictionary else {}


## Which controller runs an event kind ("public_skate", "figure", "game", ...).
static func controller_for(kind: String) -> String:
	var c: Dictionary = section("controllers")
	return str(c.get(kind, "public_skate"))


static func roster(controller: String) -> Dictionary:
	var r: Dictionary = section("rosters")
	var v: Variant = r.get(controller, {})
	return v if v is Dictionary else {}


## [x, z] in the data -> Vector2(x, z).
static func v2(a: Variant, fallback := Vector2.ZERO) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback


## A cast member's look (for Gus at the first public skate).
static func cast_look(id: String) -> Dictionary:
	if _cast_looks.is_empty():
		for p in _json(CAST_PATH).get("people", []):
			if p is Dictionary:
				_cast_looks[str(p.get("id", ""))] = {"look": p.get("look", {}), "age": int(p.get("age", 40)),
					"name": str(p.get("known_as", p.get("name", "")))}
	var v: Variant = _cast_looks.get(id, {})
	return v if v is Dictionary else {}


static func _json(path: String) -> Dictionary:
	var f := FileAccess.get_file_as_string(path)
	if f == "":
		return {}
	var d: Variant = JSON.parse_string(f)
	return d if d is Dictionary else {}
