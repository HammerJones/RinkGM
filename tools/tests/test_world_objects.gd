extends SceneTree
## World objects (docs/WORLD_OBJECTS.md P1): the store's rows, hash and
## saves; then the venue walk: every prop the lobby places has a row and a
## name on look, the cup on the snack bar can be taken (into the bag, its
## room instance hidden), dropped in the office as a LIVE body that
## settles into a row, saved as the "objects" key and loaded back into a
## fresh venue, with the LIVE node count under the cap through a lobby walk.
##   godot --headless --path . --script res://tools/tests/test_world_objects.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	create_timer(240.0).timeout.connect(func():
		printerr("FAIL: test_world_objects timed out")
		quit(1))
	_store()
	await _walk()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


# ---------------------------------------------------------------- the store

func _store() -> void:
	var s := WorldObjects.new()
	var a := s.spawn(&"coffee_cup", &"lobby", Transform3D(Basis.IDENTITY, Vector3(1, 1, 1)))
	var b := s.spawn(&"lockers", &"locker_home", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(10, 0, 3)))
	var c := s.spawn(&"puck", &"lobby", Transform3D(Basis.IDENTITY, Vector3(1.5, 1, 1)), ["placed_by_player"])
	_expect(a.id == &"p.1" and b.id == &"p.2" and c.id == &"p.3", "player-placed rows get p.<n> ids (%s %s %s)" % [a.id, b.id, c.id])
	_expect(s.query(&"lobby").size() == 2 and s.query(&"", ["handheld"]).size() == 2 and s.query(&"lobby", ["canteen"]).size() == 1, "query by room and tags")
	_expect(s.nearest(Vector3(1.6, 1.0, 1.0), 0.5) == c and s.nearest(Vector3(1.0, 1.05, 1.0), 0.3, &"lobby") == a, "nearest finds the row whose box is nearest")
	_expect(s.at(Vector3(10.0, 1.0, 3.0)) == b and s.at(Vector3(20, 0, 0)) == null, "at() finds the row whose box holds a point")
	_expect(s.raycast(Vector3(1.0, 1.05, -2.0), Vector3(1.0, 1.05, 4.0)) == a, "raycast crosses the cup's box")
	_expect(s.raycast(Vector3(10.0, 1.0, -5.0), Vector3(10.0, 1.0, 8.0)) == b, "raycast crosses the lockers")
	s.set_state(a.id, "read", true)
	s.take(a.id)
	_expect(a.held() and a.room == &"" and s.query(&"lobby").size() == 1 and s.held().size() == 1, "take: the row leaves the room, stays in the store, counts as held")
	s.place(a.id, &"office", Transform3D(Basis.IDENTITY, Vector3(-41, 5, -10)))
	_expect(not a.held() and a.loose() and a.room == &"office" and s.at(Vector3(-41, 5.02, -10)) == a, "place: back in the world, loose, in the new room")
	# the save keeps what the build can't recreate, through JSON
	var d: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := WorldObjects.from_dict(d)
	var ta := t.get_row(&"p.1")
	_expect(ta != null and ta.room == &"office" and ta.loose() and ta.state.get("read", false) == true and ta.xf.origin.is_equal_approx(Vector3(-41, 5, -10)), "to_dict/from_dict keeps the moved cup, its room, state and place")
	_expect(t.get_row(&"p.2") == null and t.get_row(&"p.3") != null, "untouched baked rows aren't saved; player-placed ones are")
	# a room build re-bakes: rows the player touched survive it
	var xf := Transform3D(Basis.IDENTITY, Vector3(-40, 1.1, -11))
	t.bake(&"lobby", [["coffee_cup", xf, null, 0], ["trash_can", Transform3D.IDENTITY, null, 0]], {})
	_expect(t.has(&"lobby.coffee_cup.0") and t.has(&"lobby.trash_can.0"), "bake names rows <room>.<prop>.<n>")
	t.take(&"lobby.coffee_cup.0")
	t.bake(&"lobby", [["coffee_cup", xf, null, 0], ["trash_can", Transform3D.IDENTITY, null, 0]], {})
	var cups := t.query(&"lobby").filter(func(w: WorldObject) -> bool: return w.prop == &"coffee_cup")
	_expect(t.get_row(&"lobby.coffee_cup.0").held() and cups.is_empty() and t.has(&"lobby.trash_can.0"), "a rebuild keeps a taken row held and doesn't put a second cup back")
	t.remove(&"p.3")
	_expect(not t.has(&"p.3") and t.nearest(Vector3(1.5, 1, 1), 0.2) == null, "remove takes the row out of the hash")


# ---------------------------------------------------------------- the walk

func _walk() -> void:
	var walk: Node = load("res://scenes/venue/venue_walk.tscn").instantiate()
	root.add_child(walk)
	await _frames(3)
	var ow: ObjectWalk = walk.objects
	var venue: Venue = walk.venue
	var walker: VenueWalker = walk.walker
	_expect(ow != null and ow.objects == venue.objects, "the walk attaches ObjectWalk on the venue's store")
	var rows := venue.objects.query(&"lobby")
	_expect(rows.size() >= 9, "every prop the lobby places has a row (%d)" % rows.size())
	_expect(venue.objects.count() > 100, "the building has rows for its props (%d)" % venue.objects.count())
	var lobby: VenueRoom = venue.rooms["lobby"]
	var named := 0
	var cup: WorldObject = null
	for w in rows:
		if w.prop == &"coffee_cup":
			cup = w
		await _look_at(walk, lobby, w)
		var seen := ow.looked()
		var hint: String = walk._hint()
		if seen == w and hint.contains(w.name().to_upper()):
			named += 1
		else:
			printerr("  %s (%s) at %s: looked at %s, prompt '%s'" % [w.id, w.name(), w.xf.origin, seen.id if seen else "nothing", hint])
	_expect(named == rows.size(), "every lobby prop has its name on look (%d of %d)" % [named, rows.size()])
	_expect(cup != null and cup.id == &"lobby.coffee_cup.0", "the snack bar cup is lobby.coffee_cup.0")
	# take the cup: E on it
	await _look_at(walk, lobby, cup)
	var hint: String = walk._hint()
	_expect(hint == "[E] TAKE  COFFEE CUP", "the cup's prompt is '[E] TAKE  COFFEE CUP' (got '%s')" % hint)
	walk._use()
	await _frames(1)
	var bag: InventoryGrid = walk.kit.kit.bag
	_expect(bag.has("coffee_cup") and cup.held() and cup.room == &"", "E takes the cup into the bag and the row is held")
	# (the headless renderer doesn't keep MultiMesh transforms, so the hidden
	# instance is checked by its record: the lobby's MultiMesh and index)
	var mmi: MultiMeshInstance3D = cup.bake[0] if cup.bake.size() == 2 else null
	_expect(mmi != null and mmi.get_parent() == venue.rooms["lobby"] and int(cup.bake[1]) < mmi.multimesh.instance_count, "the row knows the lobby MultiMesh instance that drew it, to hide")
	_expect(walk._hint().begins_with("[G] DROP COFFEE CUP") or ow.drop_hint() == "[G] DROP COFFEE CUP", "the prompt offers [G] DROP COFFEE CUP")
	# up to the office, drop it
	var office: VenueRoom = venue.rooms["office"]
	walker.global_position = Vector3(-41.8, office.spawn.y + 0.05, -8.6)
	walk._yaw = 0.0
	walk._pitch = -0.4
	walker.rotation.y = 0.0
	walker.head.rotation.x = -0.4
	await _physics(5)
	var a: Dictionary = ow.drop_held()
	_expect(a.has("toast") and not bag.has("coffee_cup") and cup.loose() and not cup.held(), "G drops the cup out of the bag (%s)" % a.get("toast", ""))
	_expect(ow.live_count() == 1 and cup.tier == WorldObject.LIVE and cup.node is LiveProp, "the dropped cup is one LIVE rigid body")
	var slept := false
	for i in 600:
		await physics_frame
		if cup.node and cup.node.sleeping:
			slept = true
			break
	_expect(slept, "the cup settles and sleeps")
	await _frames(2)
	_expect(cup.room == &"office" and cup.xf.origin.y > office.spawn.y - 0.1 and cup.xf.origin.distance_to(walker.global_position) < 3.0, "its rest is written back to the row: in the office at %s" % cup.xf.origin)
	_expect(ow.live_count() <= ObjectWalk.LIVE_CAP, "LIVE count %d under the cap %d" % [ow.live_count(), ObjectWalk.LIVE_CAP])
	# the LIVE cap: eighty pucks dropped around the owner
	for i in 80:
		var p := walker.global_position + Vector3(0.3 * (i % 10) - 1.5, 0.3, 0.3 * (i / 10) - 1.5)
		venue.objects.spawn(&"puck", &"office", Transform3D(Basis.IDENTITY, p), ["placed_by_player"])
	ow._tier()
	await _frames(2)
	_expect(ow.live_count() == ObjectWalk.LIVE_CAP, "eighty loose pucks: LIVE nodes capped at %d (%d), the rest drawn by the field (%d)" % [ObjectWalk.LIVE_CAP, ow.live_count(), ow.field.count()])
	_expect(ow.field.count() == 81 - ObjectWalk.LIVE_CAP, "the field draws the %d rows without a node" % ow.field.count())
	for w in venue.objects.query(&"office", ["equipment"]):
		if w.tier == WorldObject.LIVE:
			ow.demote(w)
		venue.objects.remove(w.id)
	# save, a fresh building, load
	var saved: Dictionary = JSON.parse_string(JSON.stringify(venue.objects.to_dict()))
	var cup_xf := cup.xf
	walk.queue_free()
	await _frames(2)
	walk = load("res://scenes/venue/venue_walk.tscn").instantiate()
	root.add_child(walk)
	await _frames(3)
	venue = walk.venue
	ow = walk.objects
	venue.objects.load_dict(saved)
	await _frames(2)
	var back := venue.objects.get_row(&"lobby.coffee_cup.0")
	_expect(back != null and back.room == &"office" and back.loose() and back.xf.origin.distance_to(cup_xf.origin) < 0.01, "after save and load the cup is still in the office")
	_expect(venue.objects.query(&"lobby", ["canteen"]).filter(func(w: WorldObject) -> bool: return w.prop == &"coffee_cup").is_empty(), "and not on the snack bar")
	var m2: MultiMeshInstance3D = back.bake[0] if back.bake.size() == 2 else null
	_expect(m2 != null and m2.get_parent() == venue.rooms["lobby"], "the loaded row took over the rebuilt lobby's instance record")
	_expect(ow.field.count() == 1, "the field draws the loaded cup until the walker is near")
	# renovating the lobby rebuilds it: the cup stays where it was dropped
	venue.set_room_age("lobby", VenueRoom.Age.RENOVATED)
	await _frames(2)
	back = venue.objects.get_row(&"lobby.coffee_cup.0")
	_expect(back != null and back.room == &"office" and venue.objects.query(&"lobby").size() >= 7, "a renovation rebuild re-bakes the lobby's rows (%d) and keeps the dropped cup" % venue.objects.query(&"lobby").size())
	venue.set_room_age("lobby", VenueRoom.Age.WORN)
	# a full lobby walk: the LIVE counter's reading
	var lobby2: VenueRoom = venue.rooms["lobby"]
	walker = walk.walker
	walker.global_position = lobby2.spawn + Vector3(0, 0.05, 0)
	var peak := 0
	for p in [Vector3(-36.0, 0, -8.5), Vector3(-36.0, 0, 8.5), Vector3(-44.0, 0, 8.0), Vector3(-44.0, 0, -8.0), Vector3(-39.0, 0, -9.5), Vector3(-40.0, 0, 0.0)]:
		for i in 120 * 8:
			var to: Vector3 = p - walker.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			walker.wish = to.normalized()
			walker.running = true
			await physics_frame
			if i % 30 == 0:
				peak = maxi(peak, ow.live_count())
	walker.wish = Vector3.ZERO
	print("  lobby walk: %s (peak LIVE %d)" % [ow.status(), peak])
	_expect(peak <= ObjectWalk.LIVE_CAP, "LIVE nodes stayed under %d through the lobby walk (peak %d)" % [ObjectWalk.LIVE_CAP, peak])
	walk.queue_free()
	await _frames(2)


## Stands the walker a step back from `w` and points the view at it: its
## front first, then toward the room's middle, then every side, until the
## look ray finds it (a prop on a counter has one open side). The walker
## settles on the floor for two physics steps before the view is aimed.
func _look_at(walk: Node, room: VenueRoom, w: WorldObject) -> void:
	var walker: VenueWalker = walk.walker
	var ow: ObjectWalk = walk.objects
	var b := w.bounds()
	var c := b.get_center()
	var front := w.xf.basis * Vector3.FORWARD
	var mid := room.bounds.get_center() - c
	mid.y = 0.0
	var tries: Array[Vector3] = [front, mid.normalized(), -mid.normalized(), -front, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var back := maxf(b.size.x, b.size.z) * 0.5 + 1.1
	for d in tries:
		d.y = 0.0
		if d.length() < 0.01:
			continue
		var s := c + d.normalized() * back
		s.y = room.bounds.position.y + 0.05
		walker.global_position = s
		walker.velocity = Vector3.ZERO
		walker.wish = Vector3.ZERO
		await _physics(2)
		var eye: Vector3 = walker.head.global_position
		var to := c - eye
		walk._yaw = atan2(-to.x, -to.z)
		walk._pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.4, 1.4)
		walker.rotation.y = walk._yaw
		walker.head.rotation.x = walk._pitch
		await _physics(1)
		if ow.looked() == w:
			return
