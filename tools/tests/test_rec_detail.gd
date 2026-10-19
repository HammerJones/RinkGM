extends SceneTree
## The recreation wing's detail pass (playtest #23-#31): every workshop,
## electrical, weight room and storage prop builds at all three ages with
## shape-following collision inside a triangle budget; the rooms build with
## their machines, spots and mirror; the wing stays inside its draw and
## triangle budget; a TrainingSpot moves the clock on 15 minutes and emits
## `trained`; and the weight room's mirror only renders when someone near is
## looking at it.
##   godot --headless --path . --script res://tools/tests/test_rec_detail.gd

const Shop := preload("res://scripts/art/shop_props.gd")

## Merged at full detail, a shop prop stays under this (docs/ART.md: one-offs
## up to 8,000; these repeat a little, so lower).
const PROP_TRIS := 6000
## Arena plus wing, as test_rec_centre.
const TRI_BUDGET := 1400000
const DRAW_BUDGET := 700

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(120.0).timeout.connect(func():
		printerr("FAIL: test_rec_detail timed out")
		quit(1))
	_props()
	await _rooms()
	await _training()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _props() -> void:
	for id: String in Shop.IDS:
		_expect(Props.IDS.has(id), "%s is in Props.IDS" % id)
		var worst := 0
		for age in 3:
			var m := Props.model(id, age)
			var mesh := Props.mesh(id, age)
			var boxes := Props.collision_boxes(id, age)
			if m == null or m.voxels.is_empty() or mesh == null or boxes.is_empty():
				_expect(false, "%s %s builds with a mesh and collision" % [id, Wear.NAMES[age]])
				continue
			worst = maxi(worst, mesh.surface_get_array_len(0) / 3)
			var aabb := mesh.get_aabb()
			if absf(aabb.position.y) > 0.07:
				_expect(false, "%s %s stands on the floor (bottom %.2f)" % [id, Wear.NAMES[age], aabb.position.y])
		_expect(worst > 0 and worst <= PROP_TRIS, "%s: three ages with collision, at most %d triangles" % [id, worst])


func _rooms() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var v := Venue.instantiate_for(Career.exhibition(0), true)
	root3d.add_child(v)
	await process_frame
	for age in 3:
		v.set_all_ages(age)
		var st := v.stats()
		var name: String = VenueRoom.AGE_NAMES[age]
		_expect(st.triangles < TRI_BUDGET and st.draws < DRAW_BUDGET, "%s wing: %d draws, %d triangles within %d / %d" % [name, st.draws, st.triangles, DRAW_BUDGET, TRI_BUDGET])
		var weights: VenueRoom = v.rooms["weight_room"]
		var training := weights.spots.filter(func(s): return s is TrainingSpot)
		_expect(training.size() >= 10, "%s weight room: %d training spots" % [name, training.size()])
		var keys_ok := true
		for s: TrainingSpot in training:
			for key: String in s.skill_keys:
				if not Skills.SKATER_KEYS.has(key):
					keys_ok = false
		_expect(keys_ok, "%s: every training spot uses real Skills keys" % name)
		var shop: VenueRoom = v.rooms["workshop"]
		var stubs := shop.spots.filter(func(s): return s.kind == VenueSpot.Kind.USE and s.data.get("stub", false))
		_expect(stubs.size() >= 6, "%s workshop: %d machine spots" % [name, stubs.size()])
		_expect(_find(weights, "PlanarMirror") != null, "%s weight room has its mirror" % name)
		_expect(_has_prop(v.rooms["rec_electrical"], "switchgear", age), "%s electrical room has the switchgear" % name)
		_expect(_has_prop(v.rooms["rec_storage"], "spare_net", age), "%s storage has a spare net" % name)
	await _mirror(v)
	root3d.queue_free()
	await process_frame


## The mirror renders only for a near camera on its glass side looking at it.
func _mirror(v: Venue) -> void:
	v.set_all_ages(VenueRoom.Age.WORN)
	await process_frame
	var mirror: PlanarMirror = _find(v.rooms["weight_room"], "PlanarMirror")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(40.0, 1.6, -20.0), Vector3(40.0, 1.6, -10.0))  # far away in the arena
	await process_frame
	await process_frame
	_expect(not mirror.active, "the mirror is idle from the arena")
	cam.look_at_from_position(Vector3(8.0, 1.6, -52.5), Vector3(2.0, 1.4, -52.5))  # in the weight room, facing it
	await process_frame
	await process_frame
	_expect(mirror.active and mirror.renders > 0, "the mirror reflects for someone in front of it")
	cam.look_at_from_position(Vector3(8.0, 1.6, -52.5), Vector3(14.0, 1.4, -52.5))  # turned away
	await process_frame
	await process_frame
	_expect(not mirror.active, "the mirror stops when nobody looks at it")
	cam.look_at_from_position(Vector3(-4.0, 1.6, -52.5), Vector3(2.0, 1.4, -52.5))  # behind it, in the gym
	await process_frame
	await process_frame
	_expect(not mirror.active, "the mirror is idle from behind the wall")
	cam.queue_free()


func _training() -> void:
	var sim := RinkSim.create_m1()
	var s := TrainingSpot.make_training("bench", "Bench press", ["shot_power", "hitting"], 0.85)
	root.add_child(s)
	var got := []
	s.trained.connect(func(keys: Array, minutes: int, intensity: float): got.append([keys, minutes, intensity]))
	var before := sim.minute
	var r := s.train(sim)
	_expect(got.size() == 1 and got[0][0] == ["shot_power", "hitting"] and got[0][1] == 15 and is_equal_approx(got[0][2], 0.85),
		"a set emits trained(skill_keys, 15, intensity): %s" % [got])
	_expect(sim.minute == before + 15 or (before + 15 >= 24 * 60), "a set moves the sim clock 15 minutes (%d -> %d)" % [before, sim.minute])
	_expect(String(r.get("toast", "")).contains("BENCH PRESS"), "a set says what it did: %s" % r.get("toast", ""))
	s.train(null)
	_expect(got.size() == 2, "with no sim it still emits")
	_expect(s.is_in_group(TrainingSpot.GROUP) and s.kind == VenueSpot.Kind.USE, "training spots are USE spots in their group")
	# through the walk's story, as the player would
	var root3d := Node3D.new()
	root.add_child(root3d)
	var v := Venue.instantiate_for(Career.exhibition(0), true)
	root3d.add_child(v)
	await process_frame
	var story := WalkStory.start(v, RinkSim.create_m1())
	var spot: TrainingSpot = null
	for sp in v.rooms["weight_room"].spots:
		if sp is TrainingSpot:
			spot = sp
			break
	var heard := []
	spot.trained.connect(func(keys: Array, _m: int, _i: float): heard.append(keys))
	var m0 := story.sim.minute
	var res := story.use(spot)
	_expect(heard.size() == 1 and res.has("toast") and story.sim.minute == m0 + 15, "using a machine on the walk trains and moves the clock (%d -> %d)" % [m0, story.sim.minute])
	s.queue_free()
	root3d.queue_free()
	await process_frame


func _find(n: Node, cls: String) -> Node:
	for c in n.get_children():
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
		var f := _find(c, cls)
		if f:
			return f
	return null


## True when the room draws `id`'s mesh at `age` (one MultiMesh per prop).
func _has_prop(room: Node, id: String, age: int) -> bool:
	var mesh := Props.mesh(id, age)
	for c in room.get_children():
		if c is MultiMeshInstance3D and c.multimesh and c.multimesh.mesh == mesh:
			return true
	return false
