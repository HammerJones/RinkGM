extends SceneTree
## Builds every prop in the kit at every renovation age and detail level and
## checks each is a usable, cached mesh with its pivot on the floor.
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
	if failures == 0:
		print("props test: all passed (%d props x 3 ages x 2 detail levels)" % Props.ids().size())
	quit(1 if failures else 0)


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
