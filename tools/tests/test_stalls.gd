extends SceneTree
## Dressing room stalls (playtest W8): at every age, the arena's two
## dressing rooms and the rec wing's rooms 3 to 6 have real hockey stalls
## instead of kit lockers. Each stall has a bench seat, a hanging bar above
## it and a shelf above that, all inside the room; the room's stalls are one
## shadow-casting mesh within a triangle budget; the coach's whiteboard,
## the room-number signs and the dressing-room spot are still there and the
## spot, the spawn and the doors stay clear of the stalls; and the match
## venue and the walk venue stay inside their draw and triangle budgets.
##   godot --headless --path . --script res://tools/tests/test_stalls.gd

const ROOMS := ["locker_home", "locker_away", "locker_3", "locker_4", "locker_5", "locker_6"]
## Stalls per room at least (a team dresses about twenty in the arena).
const MIN_STALLS := {"locker_home": 18, "locker_away": 18, "locker_3": 14, "locker_4": 14, "locker_5": 14, "locker_6": 14}
## One room's stalls, one mesh.
const ROOM_TRIS := 40000
## As test_venue (match) and test_rec_centre (walk, arena plus wing).
const MATCH_TRIS := 940000
const MATCH_DRAWS := 275
const WALK_TRIS := 1450000
const WALK_DRAWS := 700

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
	create_timer(240.0).timeout.connect(func():
		printerr("FAIL: test_stalls timed out")
		quit(1))
	var root3d := Node3D.new()
	root.add_child(root3d)
	var match_venue := Venue.instantiate_for(Career.exhibition(0))
	root3d.add_child(match_venue)
	for age in 3:
		match_venue.set_all_ages(age)
		var st: Dictionary = match_venue.stats()
		print("  match %-9s %s" % [Wear.NAMES[age], st])
		_expect(st.triangles < MATCH_TRIS and st.draws < MATCH_DRAWS, "%s match venue: %d draws, %d triangles within %d / %d" % [Wear.NAMES[age], st.draws, st.triangles, MATCH_DRAWS, MATCH_TRIS])
	match_venue.queue_free()
	await process_frame
	var venue := Venue.instantiate_for(Career.exhibition(0), true)
	root3d.add_child(venue)
	for age in 3:
		venue.set_all_ages(age)
		await process_frame
		var st: Dictionary = venue.stats()
		print("  walk  %-9s %s" % [Wear.NAMES[age], st])
		_expect(st.triangles < WALK_TRIS and st.draws < WALK_DRAWS, "%s walk venue: %d draws, %d triangles within %d / %d" % [Wear.NAMES[age], st.draws, st.triangles, WALK_DRAWS, WALK_TRIS])
		for id: String in ROOMS:
			_check_room(venue, venue.rooms[id], id, age)
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _check_room(venue: Node, room: VenueRoom, id: String, age: int) -> void:
	var what := "%s %s" % [Wear.NAMES[age], id]
	var meshes := room.find_children("Stalls", "MeshInstance3D", true, false)
	_expect(meshes.size() == 1, "%s: its stalls are one mesh (%d)" % [what, meshes.size()])
	if meshes.is_empty():
		return
	var mi: MeshInstance3D = meshes[0]
	var tris: int = mi.mesh.surface_get_array_len(0) / 3 if mi.mesh.get_surface_count() > 0 else 0
	_expect(tris > 0 and tris < ROOM_TRIS, "%s: stalls mesh %d triangles within %d" % [what, tris, ROOM_TRIS])
	_expect(mi.cast_shadow == Look.cast(), "%s: the stalls cast shadows as Look.cast()" % what)
	var lockers := Props.mesh("lockers", age)
	var has_lockers := room.find_children("*", "MultiMeshInstance3D", true, false).any(func(c: MultiMeshInstance3D) -> bool: return c.multimesh.mesh == lockers)
	_expect(not has_lockers, "%s: no kit lockers left" % what)
	var stalls: Array = mi.get_meta("stalls", [])
	_expect(stalls.size() >= MIN_STALLS[id], "%s: %d stalls (at least %d)" % [what, stalls.size(), MIN_STALLS[id]])
	var bounds := room.bounds.grow(0.05)
	var bad := []
	for i in stalls.size():
		var s: Dictionary = stalls[i]
		if not (s.has("bench") and s.has("bar") and s.has("shelf")):
			bad.append("%d missing a part" % i)
			continue
		var bench: AABB = s.bench
		var bar: AABB = s.bar
		var shelf: AABB = s.shelf
		var top := bench.end.y
		if top < 0.38 or top > 0.6 or bench.size.x * bench.size.z < 0.2:
			bad.append("%d bench top %.2f, %.2f m2" % [i, top, bench.size.x * bench.size.z])
		if bar.position.y < 1.3 or bar.position.y > 1.75 or maxf(bar.size.x, bar.size.z) < 0.5:
			bad.append("%d bar at %.2f, %.2f long" % [i, bar.position.y, maxf(bar.size.x, bar.size.z)])
		if shelf.position.y <= bar.end.y or shelf.end.y > 2.1 or minf(shelf.size.x, shelf.size.z) < 0.3:
			bad.append("%d shelf at %.2f" % [i, shelf.position.y])
		for part: AABB in [bench, bar, shelf]:
			if not bounds.encloses(part):
				bad.append("%d outside the room" % i)
				break
	_expect(bad.is_empty(), "%s: every stall has a bench, a bar above it and a shelf above that, in the room %s" % [what, bad.slice(0, 4)])
	# the room's other kit still there
	var boards := room.find_children("*", "Whiteboard", true, false)
	_expect(boards.size() >= 1, "%s: the coach's whiteboard is up" % what)
	if id.begins_with("locker_") and id.trim_prefix("locker_").is_valid_int():
		_expect(room.find_child("RoomNumber", true, false) != null, "%s: the room number sign is up" % what)
	# walkways: the spot, the spawn and the doors stay clear of the stalls
	var clear: Array = [room.spawn]
	for key in room.places():
		clear.append_array(room.places()[key])
	for d in venue.all_doors():
		if room.bounds.grow(0.3).has_point(d.global_position + Vector3(0, 0.5, 0)):
			clear.append(d.global_position)
	var near := 9.0
	for p: Vector3 in clear:
		for s: Dictionary in stalls:
			var foot: AABB = s.bench
			foot = AABB(Vector3(foot.position.x, 0, foot.position.z), Vector3(foot.size.x, 2.0, foot.size.z))
			var q := Vector3(clampf(p.x, foot.position.x, foot.end.x), 0, clampf(p.z, foot.position.z, foot.end.z))
			near = minf(near, Vector2(p.x - q.x, p.z - q.z).length())
	_expect(near > 0.5, "%s: spot, spawn and doors at least %.2f m from a stall" % [what, near])
