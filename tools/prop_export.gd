extends SceneTree
## Converts props from the coded kit (Props) into assets: one .vox per age
## in art/props/ (or one file when the ages share a shape) and a manifest
## record in data/props/, and authors the handheld props that have no coded
## builder (puck, tape, coffee cup, notebook) the same way. Run it again to
## re-export after a builder changes; the manifest's hand-edited fields
## (name, verbs, inspect, ...) come from the tables below.
##
##   godot --headless --path . --script res://tools/prop_export.gd [-- --ids=a,b,c]
##
## PropLibrary loads what this writes; tools/tests/test_props.gd checks the
## converted ones still match the coded kit voxel for voxel.

const VOX_DIR := "res://art/props"
const DATA_DIR := "res://data/props"

## The props converted from the kit, with the fields a builder can't know.
const CONVERTED := {
	"vending_machine": {"name": "Vending machine", "tags": ["lobby", "canteen", "machine"], "verbs": ["inspect"],
		"inspect": "A 1970s drinks machine. The OUT OF ORDER note is older than some of the customers.", "mass_kg": 180, "sound": "metal"},
	"trash_can": {"name": "Trash can", "tags": ["lobby", "clutter"], "verbs": ["inspect", "push"],
		"inspect": "An avocado drum with a dent that matches a Zamboni fender.", "mass_kg": 6, "sound": "metal"},
	"concession_counter": {"name": "Snack bar counter", "tags": ["canteen", "lobby", "furniture"], "verbs": ["inspect"],
		"inspect": "The Hot Stove's counter. Fifty years of elbows.", "mass_kg": 90, "sound": "wood"},
	"rink_sign": {"name": "Rink sign", "tags": ["lobby", "sign"], "verbs": ["inspect", "read"],
		"inspect": "Hand-painted, 1974. The letters fall off in different winters.", "mass_kg": 25, "sound": "wood"},
	"lockers": {"name": "Lockers", "tags": ["dressing_room", "furniture"], "verbs": ["inspect", "open"],
		"inspect": "Steel stalls, one door per player. Number 9's door never shut right.", "mass_kg": 70, "sound": "metal"},
	"player_bench": {"name": "Players' bench", "tags": ["benches", "furniture"], "verbs": ["inspect", "sit"],
		"inspect": "Rubber matting over plywood over a lot of history.", "mass_kg": 40, "sound": "wood"},
	"hockey_bags": {"name": "Hockey bags", "tags": ["storage", "dressing_room", "clutter"], "verbs": ["inspect"],
		"inspect": "Three bags. Two of them smell exactly like you'd think.", "mass_kg": 9, "sound": "cloth"},
	"goalie_pads": {"name": "Goalie pads", "tags": ["storage", "equipment"], "verbs": ["inspect"],
		"inspect": "A spare set of pads, leaning. Someone wrote LOANER on the strap.", "mass_kg": 5, "sound": "cloth"},
	"dumbbell_rack": {"name": "Dumbbell rack", "tags": ["gym", "furniture"], "verbs": ["inspect"],
		"inspect": "Two tiers of rubber dumbbells, five to fifty, with the thirties missing.", "mass_kg": 120, "sound": "metal"},
	"pylon_stack": {"name": "Pylon stack", "tags": ["storage", "equipment", "small"], "verbs": ["inspect", "push"],
		"inspect": "Orange pylons, stacked. One is a different orange.", "mass_kg": 3, "sound": "plastic"},
	"toolbox": {"name": "Toolbox", "tags": ["workshop", "small"], "verbs": ["inspect", "open"],
		"inspect": "Red steel, two drawers. The top tray is all tape measures.", "mass_kg": 12, "sound": "metal"},
	"plate_tree": {"name": "Plate tree", "tags": ["gym", "furniture"], "verbs": ["inspect"],
		"inspect": "Olympic plates on a tree, heavy end down. The 45s are the old ones with painted numbers.", "mass_kg": 160, "sound": "metal"},
	"tape_tower": {"name": "Tape tower", "tags": ["pro_shop", "small"], "verbs": ["inspect"],
		"inspect": "Rolls of tape in a column, black at the bottom, white up top, one roll of lime green.", "mass_kg": 4, "sound": "cloth"},
	"puck_bin": {"name": "Puck bin", "tags": ["pro_shop", "small"], "verbs": ["inspect", "contain"],
		"inspect": "A wire bin of pucks. Help yourself; Bev counts them anyway.", "mass_kg": 15, "sound": "metal"},
	"shop_till": {"name": "Shop till", "tags": ["pro_shop", "small", "machine"], "verbs": ["inspect", "use"],
		"inspect": "Bev's till. The drawer sticks on the way out, never on the way in.", "mass_kg": 7, "sound": "metal"},
	"foot_measure": {"name": "Foot measure", "tags": ["pro_shop", "small", "handheld"], "verbs": ["inspect", "take"],
		"inspect": "A Brannock device. Everyone in the valley is half a size bigger than they think.", "mass_kg": 1.2, "sound": "metal",
		"shape": [[0, 0], [1, 0]]},
}

## Authored here: handheld things with no coded builder. Finer voxels than
## the kit's 0.065 m, since a puck is one kit voxel across (docs/ART.md keeps
## regulation sizes for the puck the same way).
const HANDHELD := {
	"puck": {"name": "Puck", "tags": ["handheld", "equipment", "clutter"], "verbs": ["take", "inspect", "push"],
		"inspect": "Frozen pucks bounce less. This one isn't frozen.", "mass_kg": 0.17, "sound": "rubber", "shape": [[0, 0]],
		"voxel_m": 0.0125},
	"tape": {"name": "Hockey tape", "tags": ["handheld", "equipment", "clutter"], "verbs": ["take", "inspect"],
		"inspect": "Black cloth tape. About half a roll.", "mass_kg": 0.1, "sound": "cloth", "shape": [[0, 0]],
		"voxel_m": 0.0125},
	"coffee_cup": {"name": "Coffee cup", "tags": ["handheld", "clutter", "canteen"], "verbs": ["take", "inspect", "push"],
		"inspect": "Hot Stove mug. Chipped on the handle side.", "mass_kg": 0.25, "sound": "ceramic", "shape": [[0, 0]],
		"voxel_m": 0.02, "wear": {"worn": "weather", "repaired": "palette:clean", "renovated": "palette:new"}},
	"notebook": {"name": "Notebook", "tags": ["handheld", "clutter", "office"], "verbs": ["take", "inspect", "read"],
		"inspect": "Readings, phone numbers, lists. Earl's handwriting.", "mass_kg": 0.2, "sound": "paper", "shape": [[0, 0], [0, 1]],
		"voxel_m": 0.02, "wear": {"worn": "weather", "repaired": "palette:clean", "renovated": "palette:new"}},
}

var _only: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			_only = Array(a.trim_prefix("--ids=").split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var failed := 0
	for id in CONVERTED:
		if _only.is_empty() or id in _only:
			if not _export_coded(id):
				failed += 1
	for id in HANDHELD:
		if _only.is_empty() or id in _only:
			if not _export_handheld(id):
				failed += 1
	print("prop export: %s" % ("done" if failed == 0 else "%d failed" % failed))
	quit(1 if failed else 0)


## One kit prop: the builder's model before Wear.weather (which PropLibrary
## applies at load), one file per age unless all three are the same.
func _export_coded(id: String) -> bool:
	var models: Array[VoxelModel] = []
	for age in 3:
		var m: VoxelModel = Props._build(id, age)
		if m == null:
			printerr("%s: no builder" % id)
			return false
		models.append(m)
	var same := _same(models[0], models[1]) and _same(models[1], models[2])
	var rec := _record(id, CONVERTED[id])
	rec["source"] = "props"
	var cell: int = Props._COLLISION_CELL.get(id, StickProps.COLLISION_CELL.get(id, Props.Shop.COLLISION_CELL.get(id, 2)))
	if cell != 2:
		rec["collision_cell"] = cell
	if id in Props._MERGED or id in Props.Plant.MERGED or id in Props.Shop.MERGED or id in StickProps.MERGED:
		rec["mesh"] = "merged"
	if same:
		var w := _write(id, models[0], "%s/%s.vox" % [VOX_DIR, id])
		if w.is_empty():
			return false
		rec["vox"] = w.path
		rec["pivot"] = w.pivot
		rec["offset"] = w.offset
	else:
		var vox := {}
		var pivot := []
		var offset := []
		for age in 3:
			var w := _write(id, models[age], "%s/%s.%s.vox" % [VOX_DIR, id, Wear.NAMES[age]])
			if w.is_empty():
				return false
			vox[Wear.NAMES[age]] = w.path
			pivot.append(w.pivot)
			offset.append(w.offset)
		rec["vox"] = vox
		# per age only when the ages differ
		rec["pivot"] = pivot[0]
		if pivot[0] != pivot[1] or pivot[1] != pivot[2]:
			rec["pivot"] = {"worn": pivot[0], "repaired": pivot[1], "renovated": pivot[2]}
		rec["offset"] = offset[0]
		if offset[0] != offset[1] or offset[1] != offset[2]:
			rec["offset"] = {"worn": offset[0], "repaired": offset[1], "renovated": offset[2]}
	_finish(id, rec, models)
	return true


func _export_handheld(id: String) -> bool:
	var spec: Dictionary = HANDHELD[id]
	var m := _handheld(id, float(spec.voxel_m))
	var rec := _record(id, spec)
	rec["voxel_m"] = float(spec.voxel_m)
	var w := _write(id, m, "%s/%s.vox" % [VOX_DIR, id])
	if w.is_empty():
		return false
	rec["vox"] = w.path
	rec["pivot"] = w.pivot
	rec["offset"] = w.offset
	_finish(id, rec, [m])
	return true


func _record(id: String, spec: Dictionary) -> Dictionary:
	var rec := {"id": id}
	for k in ["name", "tags", "verbs", "inspect", "mass_kg", "sound", "shape", "wear"]:
		if spec.has(k):
			rec[k] = spec[k]
	return rec


## Writes the .vox and returns {"path": project-relative, "pivot": [x, y, z]
## on the model's grid, "offset": the shift the file's voxels carry}.
func _write(id: String, m: VoxelModel, res_path: String) -> Dictionary:
	var r := VoxWriter.write(m, res_path)
	if not r.ok:
		printerr("%s: %s" % [id, r.error])
		return {}
	var p: Vector3 = m.pivot
	var o: Vector3i = r.shift
	print("  %s -> %s (%s voxels, %d colours)" % [id, res_path.trim_prefix("res://"), r.size, r.colours])
	return {"path": res_path.trim_prefix("res://"), "pivot": [p.x, p.y, p.z], "offset": [o.x, o.y, o.z]}


## size_m is the box every age fits in.
func _finish(id: String, rec: Dictionary, models: Array) -> void:
	var size := Vector3.ZERO
	for m in models:
		var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
		var hi := -lo
		for p in m.voxels:
			lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
			hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
		size = size.max(Vector3(hi - lo + Vector3i.ONE) * m.voxel_size)
	rec["size_m"] = [snappedf(size.x, 0.001), snappedf(size.y, 0.001), snappedf(size.z, 0.001)]
	# full-detail triangles at the worst age, rounded up to a budget band
	PropLibrary.reload()
	var f := FileAccess.open("%s/%s.json" % [DATA_DIR, id], FileAccess.WRITE)
	f.store_string(JSON.stringify(rec, "  ") + "\n")
	f.close()
	PropLibrary.reload()
	var worst := 0
	for age in 3:
		worst = maxi(worst, PropLibrary.triangles(id, age))
	var cap := 600
	for band in [600, 1000, 2000, 4000, 8000, 16000]:
		cap = band
		if worst <= band:
			break
	rec["tri_cap"] = cap
	f = FileAccess.open("%s/%s.json" % [DATA_DIR, id], FileAccess.WRITE)
	f.store_string(JSON.stringify(rec, "  ") + "\n")
	f.close()
	print("  %s: %d triangles (cap %d), %s m" % [id, worst, cap, rec.size_m])


func _same(a: VoxelModel, b: VoxelModel) -> bool:
	if a.voxels.size() != b.voxels.size() or a.pivot != b.pivot:
		return false
	for p in a.voxels:
		if not b.voxels.has(p) or not (b.voxels[p] as Color).is_equal_approx(a.voxels[p]):
			return false
	return true


# ---------------------------------------------------------------- handheld models

## +Y up, front -Z, pivot at the bottom centre.
func _handheld(id: String, v: float) -> VoxelModel:
	var m := _handheld_voxels(id, v)
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := -lo
	for p in m.voxels:
		lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
		hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
	m.pivot = Vector3((lo.x + hi.x + 1) * 0.5, lo.y, (lo.z + hi.z + 1) * 0.5)
	return m


func _handheld_voxels(id: String, v: float) -> VoxelModel:
	var m := VoxelModel.new(v)
	match id:
		"puck":
			# 76 mm across, 25 mm thick: a 6-voxel disc, two high, with the
			# league's worn logo on top
			_disc(m, 3.0, 3.0, 0, 2, 3.0, Wear.RUBBER)
			m.set_voxel(2, 1, 2, Color("3a3a3e")).set_voxel(3, 1, 3, Color("3a3a3e"))
			m.set_voxel(3, 1, 2, Color("46464a")).set_voxel(2, 1, 3, Color("46464a"))
		"tape":
			# a roll lying flat: 100 mm across, 25 mm wide, a cardboard core
			_disc(m, 4.0, 4.0, 0, 2, 4.0, Color("1f1f22"))
			_disc(m, 4.0, 4.0, 0, 2, 1.6, Wear.PLYWOOD)
			for y in 2:
				m.clear_box(3, y, 3, 2, 1, 2)
		"coffee_cup":
			# 80 mm across, 100 mm tall: cream mug, red band, handle on the right
			_disc(m, 2.0, 2.0, 0, 5, 2.3, Wear.OLD_CREAM)
			for y in 5:
				for x in 5:
					for z in 5:
						var p := Vector3i(x, y, z)
						if m.voxels.has(p) and y == 3:
							m.voxels[p] = Wear.OLD_ORANGE  # the band
			for y in range(1, 5):
				m.clear_box(1, y, 1, 3, 1, 3)  # hollow
			m.box(1, 4, 1, 3, 1, 3, Color("4a3524"))  # the coffee
			m.set_voxel(4, 1, 2, Wear.OLD_CREAM).set_voxel(4, 3, 2, Wear.OLD_CREAM)
			m.set_voxel(5, 1, 2, Wear.OLD_CREAM).set_voxel(5, 2, 2, Wear.OLD_CREAM).set_voxel(5, 3, 2, Wear.OLD_CREAM)
		"notebook":
			# 150 x 200 mm coil notebook, 40 mm thick, lying flat; spiral at the back
			m.box(0, 0, 0, 7, 1, 10, Wear.PAPER)
			m.box(0, 1, 0, 7, 1, 10, Wear.OLD_AVOCADO)
			for z in range(0, 10, 2):
				m.set_voxel(0, 1, z, Wear.OLD_STEEL)
				m.set_voxel(0, 0, z, Wear.OLD_STEEL)
			m.box(2, 1, 2, 3, 1, 1, Wear.OLD_CREAM)  # the label
	return m


## A vertical cylinder of voxels centred on (cx, cz), radius r, from y0 up h.
func _disc(m: VoxelModel, cx: float, cz: float, y0: int, h: int, r: float, c: Color) -> void:
	for x in ceili(cx + r) + 1:
		for z in ceili(cz + r) + 1:
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			if dx * dx + dz * dz <= r * r:
				for y in h:
					m.set_voxel(x, y0 + y, z, c)
