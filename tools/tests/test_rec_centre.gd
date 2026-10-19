extends SceneTree
## Headless check of the recreation centre wing (RecPlan): a match venue
## leaves it out; a walking venue has every room, human-scale doors, a
## geometry budget, occluders on its walls, and a person can walk in the
## main doors and from the hall into the gym, a dressing room, the weight
## room, the offices and the pro shop, and come through from the arena.
## Walks are kept short: ci.sh stops a test after 6000 frames.
##
##   godot --headless --path . --script tools/tests/test_rec_centre.gd

## Arena plus wing while walking (the match budget in test_venue is 900k
## without the wing). Walls occlude, so a walker draws far less than this.
const TRI_BUDGET := 1400000
const DRAW_BUDGET := 700

var failures := 0
var _venue: Venue


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(300.0).timeout.connect(func():
		printerr("FAIL: test_rec_centre timed out")
		quit(1))
	var root3d := Node3D.new()
	root.add_child(root3d)
	var match_venue := Venue.instantiate_for(Career.exhibition(0))
	root3d.add_child(match_venue)
	_expect(not match_venue.has_wings() and not match_venue.rooms.has("gym"), "a match venue leaves the wing out")
	match_venue.queue_free()
	await process_frame
	_venue = Venue.instantiate_for(Career.exhibition(0), true)
	root3d.add_child(_venue)
	for id in RecPlan.ROOMS:
		_expect(_venue.rooms.has(id) and _venue.rooms[id].wing == "rec", "room %s exists" % id)
	for age in 3:
		var t0 := Time.get_ticks_msec()
		_venue.set_all_ages(age)
		var st := _venue.stats()
		print("  %-9s built in %d ms: %s" % [VenueRoom.AGE_NAMES[age], Time.get_ticks_msec() - t0, st])
		_expect(st.triangles < TRI_BUDGET, "%s: %d triangles within %d" % [VenueRoom.AGE_NAMES[age], st.triangles, TRI_BUDGET])
		_expect(st.draws < DRAW_BUDGET, "%s: %d draws within %d" % [VenueRoom.AGE_NAMES[age], st.draws, DRAW_BUDGET])
	var occluded := 0
	for id in RecPlan.ROOMS:
		if _venue.rooms[id].find_child("Occluders", false, false):
			occluded += 1
	_expect(occluded >= RecPlan.ROOMS.size() - 2, "%d of %d wing rooms have wall occluders" % [occluded, RecPlan.ROOMS.size()])
	var owned := 0
	for d in RecPlan.DOORS:
		if d[6] != RecPlan.OPEN:
			owned += 1
	var hung := 0
	for d in _venue.all_doors():
		if RecPlan.ROOMS.has(_owner_of(d.label)):
			hung += 1
			_expect(d.width >= 0.9 and d.height >= 2.1, "door %s is %.2f x %.2f m" % [d.label, d.width, d.height])
	_expect(hung == owned, "every planned door is hung (%d of %d)" % [hung, owned])
	_venue.set_all_ages(VenueRoom.Age.WORN)
	await process_frame
	for d in _venue.all_doors():
		d.open()
	for i in 70:
		await physics_frame
	await _walk("in the main doors to the front desk", Vector3(-49.0, 0, -37.0), [Vector3(-43.0, 0, -37.0)], "rec_lobby")
	await _walk("front desk to the gym", Vector3(-42.0, 0, -42.6), [Vector3(-27.0, 0, -42.3), Vector3(-25.0, 0, -42.3), Vector3(-25.0, 0, -47.5)], "gym")
	var at: Vector3 = await _walk("lobby through the bookings office to the meeting room", Vector3(-39.0, 0, -42.6), [Vector3(-39.0, 0, -46.0), Vector3(-39.0, 0, -50.5), Vector3(-39.0, 0, -54.0)], "rec_offices")
	_expect(at.z < -52.3, "the walker got through into the meeting room (z %.2f)" % at.z)
	await _walk("hall to the pro shop", Vector3(-26.0, 0, -42.0), [Vector3(-26.0, 0, -37.5)], "pro_shop")
	await _walk("hall to dressing room 5", Vector3(15.0, 0, -42.0), [Vector3(18.0, 0, -42.0), Vector3(18.0, 0, -38.5), Vector3(19.5, 0, -36.0)], "locker_5")
	await _walk("arena concourse through the link to the hall", Vector3(40.0, 0, -27.5), [Vector3(40.0, 0, -36.0), Vector3(40.0, 0, -42.0), Vector3(36.0, 0, -42.0)], "rec_hall")
	await _walk("dressing room 4 out its rink door, under the stands to the corner", Vector3(13.5, 0, -33.5), [Vector3(15.1, 0, -31.0), Vector3(15.2, 0, -28.4), Vector3(25.0, 0, -28.4), Vector3(24.9, 0, -16.4)], "shell")
	await _walk("equipment store out to the rink corridor", Vector3(-1.75, 0, -33.0), [Vector3(-1.75, 0, -28.4), Vector3(3.0, 0, -28.4)], "stands_bench")
	await _walk("hall to the weight room", Vector3(12.0, 0, -42.0), [Vector3(9.0, 0, -42.0), Vector3(9.0, 0, -47.0)], "weight_room")
	await _walk("hall into the workshop", Vector3(37.0, 0, -42.0), [Vector3(37.0, 0, -47.0), Vector3(40.0, 0, -52.0)], "workshop")
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _owner_of(label: String) -> String:
	for d in RecPlan.DOORS:
		if d[0] == label:
			return d[7]
	return ""


func _walk(what: String, start: Vector3, points: Array, room_id: String) -> Vector3:
	var w := VenueWalker.new()
	_venue.add_child(w)
	w.global_position = start + Vector3(0, 0.05, 0)
	w.running = true
	for i in 10:
		await physics_frame
	for p in points:
		var stuck := 0
		var last: Vector3 = w.global_position
		for i in 120 * 15:
			var to: Vector3 = p - w.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			w.wish = to.normalized()
			await physics_frame
			if i % 60 == 59:
				stuck = stuck + 1 if w.global_position.distance_to(last) < 0.2 else 0
				last = w.global_position
				if stuck >= 3:
					break
	w.wish = Vector3.ZERO
	for i in 20:
		await physics_frame
	var room := _venue.room_at(w.global_position + Vector3(0, 0.5, 0))
	var got := room.room_id if room else "-"
	_expect(got == room_id and absf(w.global_position.y) < 0.4, "walk %s: ended in %s at %s" % [what, got, w.global_position.snapped(Vector3.ONE * 0.01)])
	w.queue_free()
	return w.global_position
