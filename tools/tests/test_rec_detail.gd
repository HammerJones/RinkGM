extends SceneTree
## The recreation wing's detail pass (playtest #23-#31): every workshop,
## electrical, weight room and storage prop builds at all three ages with
## shape-following collision inside a triangle budget; the rooms build with
## their machines, spots and mirror; the wing stays inside its draw and
## triangle budget; the weight room has a machine for each of Mechanics'
## train_* spots; and the weight room's mirror only renders when someone
## near is looking at it.
##   godot --headless --path . --script res://tools/tests/test_rec_detail.gd

const Shop := preload("res://scripts/art/shop_props.gd")
const WeightRoom := preload("res://scripts/venue/rec/weight_room.gd")

## Merged at full detail, a shop prop stays under this (docs/ART.md: one-offs
## up to 8,000; these repeat a little, so lower).
const PROP_TRIS := 6000
## Arena plus wing, as test_rec_centre.
const TRI_BUDGET := 1450000
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
		var at: Dictionary = WeightRoom.machine_spots(age)
		var want := ["train_squat_rack", "train_bench", "train_dumbbells", "train_treadmill", "train_bike"]
		if age == VenueRoom.Age.WORN:
			want.append("train_universal")
		var missing := want.filter(func(id): return not at.has(id))
		_expect(missing.is_empty(), "%s weight room has a machine for every train_* spot (missing %s)" % [name, missing])
		_expect(at.has("train_universal") == (age == VenueRoom.Age.WORN), "%s: the old universal is only in the worn room" % name)
		_expect(_has_prop(weights, "squat_rack", age) and _has_prop(weights, "treadmill", age), "%s weight room draws its machines" % name)
		var shop: VenueRoom = v.rooms["workshop"]
		var stubs := shop.spots.filter(func(s): return s.kind == VenueSpot.Kind.USE and s.data.get("stub", false))
		_expect(stubs.size() >= 6, "%s workshop: %d machine spots" % [name, stubs.size()])
		_expect(_find(weights, "PlanarMirror") != null, "%s weight room has its mirror" % name)
		_expect(_has_prop(v.rooms["rec_electrical"], "switchgear", age), "%s electrical room has the switchgear" % name)
		_expect(_has_prop(v.rooms["rec_storage"], "ball_bin", age) and _has_prop(v.rooms["rec_storage"], "mini_net", age), "%s storage has its kit" % name)
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
