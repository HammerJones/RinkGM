extends SceneTree
## Builds every prop in the kit at every renovation age and detail level and
## checks each is a usable, cached mesh with its pivot on the floor. Then the
## manifest props (PropLibrary, data/props/): every one loads at three ages
## from its .vox, has collision and bounds, stays under its triangle cap,
## names only verbs the engine knows, and the ones converted from the kit
## still match it voxel for voxel.
##   godot --headless --path . --script res://tools/tests/test_props.gd

var failures := 0


func _initialize() -> void:
	for id in Props.ids():
		for age in 3:
			_check(id, age)
	# the low-detail seat is what fills the stands, so keep it cheap
	var seat_tris := 0
	for age in 3:
		var full := _tris(Props.mesh("arena_seat", age))
		var lod := _tris(Props.mesh("arena_seat", age, 1))
		seat_tris = maxi(seat_tris, lod)
		print("arena_seat %s: %d tris, low detail %d" % [Wear.NAMES[age], full, lod])
	if seat_tris > 400:
		_fail("low-detail arena_seat has %d triangles (budget 400)" % seat_tris)
	# door parts: the leaf and frame together are the whole door
	for age in 3:
		var whole := Props.model("door", age).voxels.size()
		var parts := Props.model("door_frame", age).voxels.size() + Props.model("door_leaf", age).voxels.size()
		if whole != parts:
			_fail("door %s: frame + leaf have %d voxels, door has %d" % [Wear.NAMES[age], parts, whole])
		var leaf := Props.mesh("door_leaf", age).get_aabb()
		if absf(leaf.end.x) > 0.01 or leaf.position.x > -0.8:
			_fail("door_leaf %s: hinge should be at x=0 with the leaf toward -x, got %s" % [Wear.NAMES[age], leaf])
	_check_plant()
	_check_collision()
	_check_manifest()
	if failures == 0:
		print("props test: all passed (%d props x 3 ages x 2 detail levels, %d manifest props)" % [Props.ids().size(), PropLibrary.ids().size()])
	quit(1 if failures else 0)


## The prop pipeline (docs/WORLD_OBJECTS.md 2.1, P0).
func _check_manifest() -> void:
	var ids := PropLibrary.ids()
	if ids.size() < 20:
		_fail("manifest: %d props in data/props, the pipeline needs at least 20" % ids.size())
	var converted := 0
	var handheld := 0
	for id in ids:
		var rec := PropLibrary.info(id)
		if rec.get("coded", false):
			_fail("%s: no manifest record" % id)
			continue
		if str(rec.get("name", "")) == "":
			_fail("%s: no name" % id)
		for v in rec.get("verbs", []):
			if not ObjectVerbs.known(str(v)):
				_fail("%s: verb '%s' is not one the engine knows (%s)" % [id, v, ObjectVerbs.KNOWN])
		if rec.get("verbs", []).is_empty():
			_fail("%s: no verbs" % id)
		var line := "%-20s" % id
		var worst := 0
		for age in 3:
			var label := "%s/%s" % [id, Wear.NAMES[age]]
			var path := PropLibrary.vox_path(id, age)
			if not FileAccess.file_exists(path):
				_fail("%s: model %s is missing" % [label, path])
				continue
			var m := PropLibrary.model(id, age)
			if m == null or m.voxels.is_empty():
				_fail("%s: no voxels" % label)
				continue
			for lod in 2:
				var mesh := PropLibrary.mesh(id, age, lod)
				if mesh == null or mesh.get_surface_count() == 0 or PropLibrary.triangles(id, age, lod) == 0:
					_fail("%s lod %d: no mesh" % [label, lod])
				elif PropLibrary.mesh(id, age, lod) != mesh:
					_fail("%s lod %d: mesh not cached" % [label, lod])
			if PropLibrary.collision_boxes(id, age).is_empty():
				_fail("%s: no collider" % label)
			var b := PropLibrary.bounds(id, age)
			if b.get_volume() <= 0.0:
				_fail("%s: empty bounds" % label)
			elif absf(b.position.y) > 0.07:
				_fail("%s: bounds start %.2f m off the floor" % [label, b.position.y])
			var size: Array = rec.get("size_m", [])
			if size.size() == 3:
				var s := Vector3(size[0], size[1], size[2])
				if b.size.x > s.x + 0.1 or b.size.y > s.y + 0.1 or b.size.z > s.z + 0.1:
					_fail("%s: the model (%s) is bigger than the manifest's size_m %s" % [label, b.size, size])
			var t := PropLibrary.triangles(id, age)
			worst = maxi(worst, t)
			line += "  %s %d" % [Wear.NAMES[age], t]
			if str(rec.get("source", "")) == "props":
				_check_identical(id, age, m)
		var cap := PropLibrary.tri_cap(id)
		line += "  (cap %d)" % cap
		print(line)
		if worst > cap:
			_fail("%s: %d triangles over its cap of %d" % [id, worst, cap])
		if str(rec.get("source", "")) == "props":
			converted += 1
		if rec.get("tags", []).has("handheld"):
			handheld += 1
			if not rec.get("verbs", []).has("take") or PropLibrary.item_info(id).is_empty():
				_fail("%s: a handheld prop must be takeable with a shape for the bag" % id)
	if converted < 16:
		_fail("manifest: only %d props converted from the coded kit" % converted)
	if handheld < 4:
		_fail("manifest: only %d handheld props" % handheld)
	# the bag reads takeable props through ItemCatalog
	var cup := ItemCatalog.info("coffee_cup")
	if cup.is_empty() or not ItemCatalog.has("coffee_cup") or ItemCatalog.shape("coffee_cup").size() != 1:
		_fail("ItemCatalog doesn't see the coffee cup (%s)" % cup)
	# the unknown id still falls back to the coded kit, with a name on look
	if PropLibrary.mesh("arena_seat", Wear.WORN) != Props.mesh("arena_seat", Wear.WORN):
		_fail("PropLibrary doesn't fall back to Props for arena_seat")
	if PropLibrary.display_name("arena_seat") != "Arena Seat":
		_fail("coded props get a name from their id (got '%s')" % PropLibrary.display_name("arena_seat"))
	_check_round_trip()


## A converted prop at `age` is the coded kit's model: same voxels, colours
## within the 8-bit rounding of the file, same pivot.
func _check_identical(id: String, age: int, m: VoxelModel) -> void:
	var ref := Props.model(id, age)
	var label := "%s/%s" % [id, Wear.NAMES[age]]
	if ref == null:
		_fail("%s: the kit has no builder to compare with" % label)
		return
	if ref.voxels.size() != m.voxels.size():
		_fail("%s: %d voxels from the file, %d from the kit" % [label, m.voxels.size(), ref.voxels.size()])
		return
	var off := 0
	for p in ref.voxels:
		if not m.voxels.has(p):
			off += 1
			continue
		var a: Color = ref.voxels[p]
		var b: Color = m.voxels[p]
		if absf(a.r - b.r) > 0.02 or absf(a.g - b.g) > 0.02 or absf(a.b - b.b) > 0.02:
			off += 1
	if off:
		_fail("%s: %d voxels differ from the kit" % [label, off])
	if not m.pivot.is_equal_approx(ref.pivot):
		_fail("%s: pivot %s from the file, %s from the kit" % [label, m.pivot, ref.pivot])
	if absf(m.jitter - ref.jitter) > 0.001:
		_fail("%s: jitter %.2f from the file, %.2f from the kit" % [label, m.jitter, ref.jitter])


## VoxWriter and VoxLoader are inverses.
func _check_round_trip() -> void:
	var m := VoxelModel.new(0.065)
	m.box(-2, 0, 1, 5, 3, 4, Color("9a6b3f"))
	m.set_voxel(0, 3, 2, Color("d0202a"))
	m.set_voxel(2, 1, 4, Color("1d3557"))
	m.set_pivot(0.5, 0, 3)
	var path := "user://vox_round_trip.vox"
	var r := VoxWriter.write(m, path)
	if not r.ok:
		_fail("VoxWriter: %s" % r.error)
		return
	var back := VoxLoader.load_vox(path, 0.065)
	back.pivot = m.pivot + Vector3(r.shift)
	if back.voxels.size() != m.voxels.size():
		_fail("round trip: %d voxels back, %d written" % [back.voxels.size(), m.voxels.size()])
	for p in m.voxels:
		var q: Vector3i = p + r.shift
		if not back.voxels.has(q) or not (back.voxels[q] as Color).is_equal_approx(m.voxels[p]):
			_fail("round trip: voxel %s came back wrong" % p)
			break
	var a := m.build_mesh().get_aabb()
	var b := back.build_mesh().get_aabb()
	if not a.is_equal_approx(b):
		_fail("round trip: mesh bounds %s became %s" % [a, b])
	var bad := VoxelModel.new(0.065)
	bad.add_oriented(Vector3.ZERO, Basis.IDENTITY, Vector3.ONE, Color.RED)
	if VoxWriter.write(bad, path).ok:
		_fail("VoxWriter wrote a model with oriented voxels")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(id: String, age: int) -> void:
	var label := "%s/%s" % [id, Wear.NAMES[age]]
	var m := Props.model(id, age)
	if m == null or m.voxels.is_empty():
		_fail("%s: no voxels" % label)
		return
	for lod in 2:
		var mesh := Props.mesh(id, age, lod)
		if mesh == null or mesh.get_surface_count() == 0:
			_fail("%s lod %d: no mesh" % [label, lod])
			continue
		if Props.mesh(id, age, lod) != mesh:
			_fail("%s lod %d: mesh not cached" % [label, lod])
		var aabb := mesh.get_aabb()
		# floor props stand on y=0; hung ones sit below their ceiling mount
		var hangs: bool = id == "light" or (id == "scoreboard" and age == Wear.RENOVATED)
		var edge: float = aabb.end.y if hangs else aabb.position.y
		if absf(edge) > 0.07:
			_fail("%s lod %d: pivot is %.2f m off the %s" % [label, lod, edge, "ceiling" if hangs else "floor"])


## Every prop has collision boxes that cover every voxel, stay close to the
## mesh, and are far fewer than the voxels; the bench is not one solid block.
func _check_collision() -> void:
	var worst := ""
	var worst_n := 0
	for id in Props.ids():
		for age in 3:
			var label := "%s/%s" % [id, Wear.NAMES[age]]
			var boxes := Props.collision_boxes(id, age)
			if boxes.is_empty():
				_fail("%s: no collision boxes" % label)
				continue
			var m := Props.model(id, age)
			var missed := 0
			for p in m.voxels:
				var c := (Vector3(p) + Vector3(0.5, 0.5, 0.5) - m.pivot) * m.voxel_size
				var hit := false
				for b in boxes:
					if b.grow(0.001).has_point(c):
						hit = true
						break
				if not hit:
					missed += 1
			if missed:
				_fail("%s: %d voxels outside the collision" % [label, missed])
			var bounds: AABB = boxes[0]
			for b in boxes:
				bounds = bounds.merge(b)
			var mesh_box := Props.mesh(id, age).get_aabb().grow(4 * m.voxel_size)
			if not mesh_box.encloses(bounds):
				_fail("%s: collision %s reaches past the mesh %s" % [label, bounds, mesh_box])
			if boxes.size() > worst_n:
				worst_n = boxes.size()
				worst = label
	print("collision: most boxes %d (%s)" % [worst_n, worst])
	if worst_n > 400:
		_fail("%s has %d collision boxes (budget 400)" % [worst, worst_n])
	# a bench you can sit on: the space in front of the backrest above the seat is open
	var bench := Props.collision_boxes("player_bench", Wear.WORN)
	var total := 0.0
	for b in bench:
		total += b.get_volume()
	var whole: AABB = bench[0]
	for b in bench:
		whole = whole.merge(b)
	if total > whole.get_volume() * 0.8:
		_fail("player_bench collision is nearly one solid block (%.0f%%)" % (100.0 * total / whole.get_volume()))
	var net := Models.net().collision_boxes(1)
	if net.is_empty():
		_fail("the net has no collision")


## Plant room: triangle budgets (docs/ART.md), pipe pieces and header modules
## that tile along X, and the detector's pivot on its wall plane.
func _check_plant() -> void:
	var small := ["pipe_glycol", "pipe_glycol_elbow", "pipe_glycol_valve", "pipe_refrig",
		"pipe_refrig_elbow", "pipe_refrig_valve", "ammonia_detector", "eyewash_station", "header"]
	for id in Props.ids():
		if not Props.Plant.MERGED.has(id) and not small.has(id):
			continue
		var worst := 0
		var line: String = id
		for age in 3:
			var t := _tris(Props.mesh(id, age))
			worst = maxi(worst, t)
			line += "  %s %d (lod1 %d)" % [Wear.NAMES[age], t, _tris(Props.mesh(id, age, 1))]
		print(line)
		var budget := 2000 if small.has(id) else 8000
		if worst > budget:
			_fail("%s: %d triangles (budget %d)" % [id, worst, budget])
	var tile: float = Props.Plant.PIPE_LEN * Models.V
	for id in ["pipe_glycol", "pipe_glycol_valve", "pipe_refrig", "pipe_refrig_valve", "header"]:
		for age in 3:
			var aabb := Props.mesh(id, age).get_aabb()
			if absf(aabb.position.x + tile * 0.5) > 0.01 or absf(aabb.end.x - tile * 0.5) > 0.01:
				_fail("%s %s: should span x = +/-%.2f m to tile, got %s" % [id, Wear.NAMES[age], tile * 0.5, aabb])
	for age in 3:
		var aabb := Props.mesh("ammonia_detector", age).get_aabb()
		if absf(aabb.end.z) > 0.01:
			_fail("ammonia_detector %s: back should be on the wall plane z=0, got %.2f" % [Wear.NAMES[age], aabb.end.z])


func _tris(mesh: ArrayMesh) -> int:
	return mesh.surface_get_array_len(0) / 3


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
