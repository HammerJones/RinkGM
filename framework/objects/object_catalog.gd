class_name ObjectCatalog
extends RefCounted
## Every kind of thing that can be placed: the prop manifests in data/props/
## (one JSON record per .vox) and, behind them, the coded kit (Props). The
## catalog is what WorldObjects spawns from and what the prompt reads names
## and verbs from; nothing else needs to know where a mesh comes from.
##
##   ObjectCatalog.info("coffee_mug")      # the manifest record (or a stand-in for a kit prop)
##   ObjectCatalog.mesh("coffee_mug")      # the baked AO mesh, cached
##   ObjectCatalog.boxes("coffee_mug")     # shape-following collision boxes
##   ObjectCatalog.verbs("coffee_mug")     # ["take", "inspect", "push"]
##
## Manifest fields used here: id, name, vox, voxel_m, pivot, mass_kg, tags,
## verbs, inspect, sound, shape, mesh ("merged"), collision_cell, wear.

const DIR := "res://data/props"
const VERBS_KNOWN := ["inspect", "take", "push", "open", "close", "use", "read", "sit", "contain"]

static var _records := {}  # id -> Dictionary
static var _loaded := false
static var _meshes := {}  # id -> ArrayMesh
static var _lods := {}  # id -> ArrayMesh
static var _boxes := {}  # id -> Array[AABB]


static func reload() -> void:
	_records.clear()
	_meshes.clear()
	_lods.clear()
	_boxes.clear()
	_loaded = false
	_load()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.get_extension() != "json":
			continue
		var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + f))
		if rec is Dictionary and rec.has("id"):
			_records[str(rec.id)] = rec
		else:
			push_error("ObjectCatalog: %s is not a prop record" % f)


## Every manifest id, sorted.
static func ids() -> Array:
	_load()
	var out := _records.keys()
	out.sort()
	return out


static func has(id: String) -> bool:
	_load()
	return _records.has(id)


## True for a coded kit prop with no manifest (Props.ids()).
static func is_kit(id: String) -> bool:
	return not has(id) and Props.ids().has(id)


## The record. A kit prop with no manifest gets a stand-in, named from its
## id, with inspect as its only verb, so everything placed has a name.
static func info(id: String) -> Dictionary:
	_load()
	if _records.has(id):
		return _records[id]
	return {
		"id": id,
		"name": id.capitalize(),
		"verbs": ["inspect"],
		"tags": [],
		"inspect": "",
		"mass_kg": 10.0,
		"sound": "wood",
		"kit": true,
	}


static func display_name(id: String) -> String:
	return str(info(id).get("name", id))


static func verbs(id: String) -> Array:
	return info(id).get("verbs", [])


static func has_verb(id: String, verb: String) -> bool:
	return verbs(id).has(verb)


static func tags(id: String) -> Array:
	return info(id).get("tags", [])


static func mass(id: String) -> float:
	return float(info(id).get("mass_kg", 1.0))


static func sound(id: String) -> String:
	return str(info(id).get("sound", "wood"))


static func inspect_text(id: String) -> String:
	return str(info(id).get("inspect", ""))


## The grid-inventory item for a prop that can be taken, or {} when it
## cannot: name, shape cells, description, and the prop id to spawn it back.
static func item(id: String) -> Dictionary:
	var rec := info(id)
	if not rec.get("verbs", []).has("take"):
		return {}
	var cells: Array = []
	for c in rec.get("shape", [[0, 0]]):
		cells.append(Vector2i(int(c[0]), int(c[1])))
	if cells.is_empty():
		cells.append(Vector2i.ZERO)
	return {
		"name": rec.get("name", id), "shape": cells, "desc": str(rec.get("inspect", "")), "prop": id
	}


## The prop's mesh (the baked AO mesh from the imported .vox, or the kit's
## mesh at `age`), cached.
static func mesh(id: String, age := 0) -> ArrayMesh:
	_load()
	if not _records.has(id):
		return Props.mesh(id, age) if Props.ids().has(id) else null
	if not _meshes.has(id):
		_bake(id)
	return _meshes[id]


## The low-detail mesh (flat colours, no AO), or the full one when none.
static func mesh_lod(id: String, age := 0) -> ArrayMesh:
	_load()
	if not _records.has(id):
		return Props.mesh(id, age, 1) if Props.ids().has(id) else null
	if not _lods.has(id):
		_bake(id)
	return _lods[id]


## Shape-following collision boxes in the prop's space.
static func boxes(id: String, age := 0) -> Array[AABB]:
	_load()
	if not _records.has(id):
		var out: Array[AABB] = []
		if Props.ids().has(id):
			out.assign(Props.collision_boxes(id, age))
		return out
	if not _boxes.has(id):
		_bake(id)
	return _boxes[id]


static func _bake(id: String) -> void:
	var rec: Dictionary = _records[id]
	var path := "res://" + str(rec.get("vox", ""))
	var asset := VoxAsset.load_any(path)
	if asset == null:
		push_error("ObjectCatalog: %s has no model at %s" % [id, path])
		_meshes[id] = ArrayMesh.new()
		_lods[id] = _meshes[id]
		_boxes[id] = [] as Array[AABB]
		return
	if asset.mesh and asset.mesh.get_surface_count() > 0:
		_meshes[id] = asset.mesh
		_lods[id] = asset.mesh_lod if asset.mesh_lod else asset.mesh
		_boxes[id] = asset.boxes
		return
	# no bake (the file was read, not imported): mesh it now
	var vm := float(rec.get("voxel_m", asset.voxel_m))
	var m := asset.to_model(vm)
	var piv: Array = rec.get("pivot", [])
	var b := asset.bounds()
	if piv.size() == 3:
		m.set_pivot(float(piv[0]), float(piv[1]), float(piv[2]))
	else:
		m.set_pivot(
			b.position.x + b.size.x / 2.0 + 0.5, b.position.y, b.position.z + b.size.z / 2.0 + 0.5
		)
	_meshes[id] = VoxMesher.build(m, {"greedy": true})
	_lods[id] = VoxMesher.build(m, {"greedy": true, "ao": false, "quantize": 4})
	_boxes[id] = m.collision_boxes(int(rec.get("collision_cell", 8)))
