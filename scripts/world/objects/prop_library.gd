class_name PropLibrary
extends RefCounted
## Props as assets (docs/WORLD_OBJECTS.md 2.1). A prop is a MagicaVoxel
## model in art/props/ plus one JSON record in data/props/, and everything
## that draws a prop goes through here:
##
##   PropLibrary.mesh("coffee_cup", Wear.WORN)        # cached per (id, age, lod)
##   PropLibrary.collision_boxes("coffee_cup", age)   # shape-following boxes
##   PropLibrary.bounds("coffee_cup", age)            # one box, for a rigid body
##   PropLibrary.info("coffee_cup")                   # the manifest record
##
## An id with no manifest falls back to the coded kit (Props.mesh), so every
## prop the rooms already place keeps working while they convert over time.
##
## Manifest fields (data/props/<id>.json):
##   id, name            the id and what the prompt calls it
##   vox                 "art/props/x.vox", or {"worn": ..., "repaired": ...,
##                       "renovated": ...} when the ages differ in shape
##   offset              [x, y, z]: the file's voxels sit this far from the
##                       model's own grid (a .vox has no negative
##                       coordinates); undone on load so ageing and speckle,
##                       which hash the grid position, match the coded kit
##   pivot               [x, y, z] in voxels on the model's grid (default:
##                       bottom centre); `offset` and `pivot` may be one per
##                       age like `vox`
##   voxel_m             voxel size in metres (default 0.065; handhelds finer)
##   wear                how each age looks: "weather" (Wear.weather, the
##                       kit's shared ageing), "none", "palette:<name>" (a
##                       colour remap from data/props/palettes.json, then
##                       weathered) or "tint:<hex>[:amount]"; one value, or
##                       {"worn": ..., "repaired": ..., "renovated": ...}
##   mesh                "voxel" (speckled, default) or "merged" (flat faces)
##   collision_cell      voxels per collision cell (VoxelModel.collision_boxes)
##   tri_cap             triangles the prop may use at full detail
##   size_m, mass_kg, tags, verbs, inspect, sound, shape: see the design doc

const DIR := "res://data/props"
const PALETTES := "res://data/props/palettes.json"
const VOXEL := 0.065

static var _manifest := {}   # id -> record
static var _loaded := false
static var _palettes := {}
static var _models := {}     # "id/age/fine" -> VoxelModel
static var _meshes := {}     # "id/age/lod" -> ArrayMesh
static var _boxes := {}      # "id/age" -> Array[AABB]
static var _bounds := {}     # "id/age" -> AABB


## Every manifest id, sorted.
static func ids() -> Array:
	_load()
	var out := _manifest.keys()
	out.sort()
	return out


## True when `id` has a manifest (a converted or authored prop).
static func has(id: String) -> bool:
	_load()
	return _manifest.has(id)


## The manifest record, or a stand-in for a coded kit prop ({"coded": true},
## named from its id, with `inspect` as its only verb) so every placed thing
## has a name on look.
static func info(id: String) -> Dictionary:
	_load()
	if _manifest.has(id):
		return _manifest[id]
	return {"id": id, "name": id.capitalize(), "verbs": ["inspect"], "tags": [], "inspect": "", "coded": true}


static func display_name(id: String) -> String:
	return str(info(id).get("name", id))


static func verbs(id: String) -> Array:
	return info(id).get("verbs", [])


static func has_verb(id: String, verb: String) -> bool:
	return verbs(id).has(verb)


static func tags(id: String) -> Array:
	return info(id).get("tags", [])


## What the grid inventory needs (ItemCatalog reads this for ids it doesn't
## list): name, shape cells and a description; {} when the prop can't be taken.
static func item_info(id: String) -> Dictionary:
	var rec := info(id)
	if not rec.get("verbs", []).has("take"):
		return {}
	var cells: Array = []
	for c in rec.get("shape", [[0, 0]]):
		cells.append(Vector2i(int(c[0]), int(c[1])))
	if cells.is_empty():
		cells.append(Vector2i.ZERO)
	return {"name": rec.get("name", id), "shape": cells, "desc": str(rec.get("inspect", "")), "prop": id}


## The weathered model at `age`. Loads the .vox (per age when the manifest
## lists one per age), applies the wear rule, caches. Coded props come from
## Props.model.
static func model(id: String, age: int) -> VoxelModel:
	_load()
	if not _manifest.has(id):
		return Props.model(id, age)
	var key := "%s/%d/%s" % [id, age, Wear.fine]
	if not _models.has(key):
		_models[key] = _build(id, age)
	return _models[key]


## One mesh per (id, age, lod), shared by every copy. lod 1 drops the
## speckle and merges flat faces, like Props.mesh.
static func mesh(id: String, age: int, lod := 0) -> ArrayMesh:
	_load()
	if not _manifest.has(id):
		return Props.mesh(id, age, lod)
	var key := "%s/%d/%d" % [id, age, lod]
	if not _meshes.has(key):
		Wear.fine = lod == 0
		var m := model(id, age)
		Wear.fine = true
		if m == null:
			_meshes[key] = null
		elif lod == 0 and str(_manifest[id].get("mesh", "voxel")) != "merged":
			_meshes[key] = m.build_mesh()
		else:
			_meshes[key] = m.build_mesh_merged()
	return _meshes[key]


## Shape-following collision boxes in the mesh's space (VenueKit.prop bakes
## these into the room's collider).
static func collision_boxes(id: String, age: int) -> Array[AABB]:
	_load()
	if not _manifest.has(id):
		return Props.collision_boxes(id, age)
	var key := "%s/%d" % [id, age]
	if not _boxes.has(key):
		var m := model(id, age)
		var boxes: Array[AABB] = []
		if m:
			boxes = m.collision_boxes(int(_manifest[id].get("collision_cell", 2)))
		_boxes[key] = boxes
	return _boxes[key]


## The voxel bounds in metres, relative to the pivot: the one-box collider
## of a LIVE rigid body, and the box the look ray picks against.
static func bounds(id: String, age: int) -> AABB:
	var key := "%s/%d" % [id, age]
	if not _bounds.has(key):
		var m := model(id, age)
		var box := AABB()
		if m and not m.voxels.is_empty():
			var first := true
			for p in m.voxels:
				var lo := (Vector3(p) - m.pivot) * m.voxel_size
				var cell := AABB(lo, Vector3.ONE * m.voxel_size)
				box = cell if first else box.merge(cell)
				first = false
			for o in m.oriented:
				var t: Transform3D = o[0]
				var ob := t * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
				box = box.merge(AABB((ob.position - m.pivot) * m.voxel_size, ob.size * m.voxel_size))
		_bounds[key] = box
	return _bounds[key]


static func triangles(id: String, age: int, lod := 0) -> int:
	var m := mesh(id, age, lod)
	if m == null or m.get_surface_count() == 0:
		return 0
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s) / 3
	return n


## The triangle cap for a manifest prop at full detail (docs/ART.md bands:
## 600 handheld, 2000 small, 8000 one-offs), from the manifest when it says.
static func tri_cap(id: String) -> int:
	var rec := info(id)
	if rec.has("tri_cap"):
		return int(rec.tri_cap)
	var t: Array = rec.get("tags", [])
	if t.has("handheld"):
		return 600
	return 2000 if t.has("small") else 8000


## Forgets everything (tools and tests that rewrite manifests).
static func reload() -> void:
	_loaded = false
	_manifest.clear()
	_palettes.clear()
	_models.clear()
	_meshes.clear()
	_boxes.clear()
	_bounds.clear()


# ---------------------------------------------------------------- loading

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json") and not dir.current_is_dir() and name != "palettes.json":
			var rec: Variant = _read_json("%s/%s" % [DIR, name])
			if rec is Dictionary and rec.has("id"):
				_manifest[str(rec.id)] = rec
			else:
				push_error("PropLibrary: %s is not a prop record" % name)
		name = dir.get_next()
	dir.list_dir_end()
	var pal: Variant = _read_json(PALETTES)
	if pal is Dictionary:
		_palettes = pal


static func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


## The model file for `age`: one for all ages, or one per age.
static func vox_path(id: String, age: int) -> String:
	var rec := info(id)
	var v: Variant = rec.get("vox", "")
	if v is Dictionary:
		v = v.get(Wear.NAMES[age], v.get("worn", ""))
	var path := str(v)
	if path == "":
		return ""
	return path if path.begins_with("res://") else "res://" + path


## The wear rule for `age`: "weather" unless the manifest says otherwise.
static func wear_rule(id: String, age: int) -> String:
	var w: Variant = info(id).get("wear", "weather")
	if w is Dictionary:
		return str(w.get(Wear.NAMES[age], "weather"))
	return str(w)


static func _build(id: String, age: int) -> VoxelModel:
	var rec: Dictionary = _manifest[id]
	var path := vox_path(id, age)
	var m := VoxLoader.load_vox(path, float(rec.get("voxel_m", VOXEL))) if path != "" else null
	if m == null or m.voxels.is_empty():
		push_error("PropLibrary: %s has no model for %s (%s)" % [id, Wear.NAMES[age], path])
		return null
	var offset: Variant = rec.get("offset")
	if offset is Dictionary:
		offset = offset.get(Wear.NAMES[age])
	if offset is Array and offset.size() == 3:
		var o := Vector3i(int(offset[0]), int(offset[1]), int(offset[2]))
		if o != Vector3i.ZERO:
			var moved := {}
			for p in m.voxels:
				moved[p - o] = m.voxels[p]
			m.voxels = moved
			m.pivot -= Vector3(o)
	var pivot: Variant = rec.get("pivot")
	if pivot is Dictionary:
		pivot = pivot.get(Wear.NAMES[age])
	if pivot is Array and pivot.size() == 3:
		m.pivot = Vector3(float(pivot[0]), float(pivot[1]), float(pivot[2]))
	return apply_wear(m, wear_rule(id, age), age, hash(id))


## Applies one wear rule to a fresh model (see the file comment).
static func apply_wear(m: VoxelModel, rule: String, age: int, seed := 0) -> VoxelModel:
	var parts := rule.split(":")
	match parts[0]:
		"none":
			return m
		"palette":
			var name := parts[1] if parts.size() > 1 else ""
			_remap(m, _palettes.get(name, {}))
		"tint":
			var c := Color(parts[1]) if parts.size() > 1 else Color.WHITE
			var amount := float(parts[2]) if parts.size() > 2 else 0.35
			for p in m.voxels:
				m.voxels[p] = (m.voxels[p] as Color).lerp(c, amount)
	return Wear.weather(m, age, seed)


static func _remap(m: VoxelModel, map: Dictionary) -> void:
	if map.is_empty():
		return
	var lut := {}
	for k in map:
		lut[Color(str(k)).to_html(false)] = Color(str(map[k]))
	for p in m.voxels:
		var key := (m.voxels[p] as Color).to_html(false)
		if lut.has(key):
			m.voxels[p] = lut[key]
