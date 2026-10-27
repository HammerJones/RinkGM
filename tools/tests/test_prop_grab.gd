extends SceneTree
## Headless check of picking up loose things (PropGrab, LooseProp): on a
## floor with a wall and a counter, a cup is picked up from under the
## centre dot, follows the hold point as the walker turns, turns with the
## wheel, can't be pulled through the wall, and falls and comes to rest
## when dropped; a stick (StickProp) is picked up the same way; the counter
## and a too-far cup can't be. Then a walking venue: loose things are bodies
## across the building (every LooseProps.PLACES entry and the kit's loose
## pieces), a match venue has none, and doors, benches and machines are not
## in reach of the hands.
##
##   godot --headless --path . --script tools/tests/test_prop_grab.gd

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
		await physics_frame


func _run() -> void:
	create_timer(240.0).timeout.connect(func():
		printerr("FAIL: test_prop_grab timed out")
		quit(1))
	var world := Node3D.new()
	root.add_child(world)
	var k := VenueKit.new(1, 0)
	k.block(Vector3(-10, -0.2, -10), Vector3(10, 0, 10), Color.GRAY)       # floor
	k.block(Vector3(-10, 0, -3.0), Vector3(10, 3, -2.8), Color.GRAY)       # a wall 3 m ahead (-Z)
	k.block(Vector3(1.2, 0, -1.6), Vector3(2.2, 0.9, -0.6), Color.BROWN)   # a counter to the right
	var holder := Node3D.new()
	world.add_child(holder)
	k.commit(holder)
	var w := VenueWalker.new()
	world.add_child(w)
	w.global_position = Vector3(0, 0.05, 1.0)
	var cam := Camera3D.new()
	w.head.add_child(cam)
	w.grab.eye = cam
	var field := StickField.new()
	world.add_child(field)
	var cup := LooseProps.body("coffee_cup", 0)
	cup.position = Vector3(0, 0, -0.4)
	field.add_prop(cup)
	var far_cup := LooseProps.body("soda_can", 0)
	far_cup.position = Vector3(-1.2, 0, -2.6)  # past the hands' reach
	field.add_prop(far_cup)
	await _frames(40)
	_expect(cup.sleeping and absf(cup.global_position.y) < 0.01, "a cup rests asleep on the floor (y %.3f)" % cup.global_position.y)
	_expect(field.find_child("Resting", false, false).mesh != null, "the field draws resting loose things as one mesh")
	# look down at the cup
	_aim(w, cam, cup.global_position + Vector3(0, 0.05, 0))
	await _frames(2)
	_expect(w.grab.looked() == cup, "the cup is under the centre dot")
	_expect(w.grab.try_pick() and w.grab.held == cup, "LMB picks it up")
	_expect(not cup.sleeping and cup.held, "a held cup is awake and marked held")
	await _frames(60)
	var err := _hold_error(w, cup)
	_expect(err < 0.08, "the held cup floats at the hold point (%.3f m off)" % err)
	_expect(absf(cup.global_basis.y.dot(Vector3.UP) - 1.0) < 0.05, "it stays upright while held")
	# turn round to the left: it follows on the spring
	var before := cup.global_position
	w.rotation.y = PI * 0.5
	cam.rotation.x = 0.0
	await _frames(60)
	err = _hold_error(w, cup)
	_expect(err < 0.08 and cup.global_position.distance_to(before) > 0.5, "turning, the cup follows the view (%.3f m off, moved %.2f m)" % [err, cup.global_position.distance_to(before)])
	# the wheel turns it about the vertical
	var yaw0 := _yaw(cup)
	w.grab.turn_by(3)
	await _frames(60)
	var turned := wrapf(_yaw(cup) - yaw0, -PI, PI)
	_expect(absf(turned - PI * 0.25) < 0.08, "three wheel notches turn it 45 degrees (%.1f)" % rad_to_deg(turned))
	# walk up to the wall: the cup bumps it, it doesn't go through
	w.rotation.y = 0.0
	w.wish = Vector3(0, 0, -1)
	await _frames(400)
	w.wish = Vector3.ZERO
	await _frames(20)
	_expect(w.grab.held == cup and cup.global_position.z > -2.8 and w.grab.hold_point().z < -2.8, "walked up to the wall, the cup stays on this side of it (z %.2f, hold point %.2f)" % [cup.global_position.z, w.grab.hold_point().z])
	w.wish = Vector3(0, 0, 1)
	await _frames(200)
	w.wish = Vector3.ZERO
	await _frames(30)
	# drop it: it falls, settles and sleeps on the floor
	w.grab.drop()
	_expect(w.grab.held == null and not cup.held, "letting go drops it")
	var fell := false
	for i in 400:
		await physics_frame
		if cup.sleeping:
			break
	fell = cup.sleeping
	_expect(fell and cup.global_position.y < 0.12, "dropped, it falls and comes to rest (y %.3f, asleep %s)" % [cup.global_position.y, cup.sleeping])
	# the counter (a venue collider) and a cup out of reach can't be picked up
	_aim(w, cam, Vector3(1.7, 0.9, -1.1))
	await _frames(2)
	_expect(w.grab.looked() == null and not w.grab.try_pick(), "the counter is a fixed part: nothing to pick up")
	_aim(w, cam, far_cup.global_position + Vector3(0, 0.05, 0))
	await _frames(2)
	_expect(not w.grab.try_pick(), "a cup %.1f m away is out of reach" % cam.global_position.distance_to(far_cup.global_position))
	# a stick goes the same way
	var stick := StickProp.make(StickProps.variant("honest", 1, false, "white"))
	stick.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5 - StickProps.LIE), Vector3(0.6, 0.05, -0.2))
	world.add_child(stick)
	await _frames(120)
	_aim(w, cam, stick.global_transform * Vector3(0, 0.6, 0))
	await _frames(2)
	_expect(w.grab.try_pick() and w.grab.held == stick, "a stick is picked up like any loose thing")
	await _frames(60)
	_expect(_hold_error(w, stick) < 0.15, "the held stick hangs at the hold point (%.3f m off)" % _hold_error(w, stick))
	w.grab.drop()
	await _frames(240)
	_expect(not stick.held and stick.global_position.y < 0.3, "a dropped stick lands on the floor")
	world.queue_free()
	await process_frame
	await _venues()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


## Points the walker and its camera at `p`.
func _aim(w: VenueWalker, cam: Camera3D, p: Vector3) -> void:
	var to := p - cam.global_position
	w.rotation.y = atan2(-to.x, -to.z)
	cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _hold_error(w: VenueWalker, b: RigidBody3D) -> float:
	return (b.global_transform * PropGrab._shape_box(b).get_center()).distance_to(w.grab.hold_point())


func _yaw(b: Node3D) -> float:
	var f := b.global_basis.z
	return atan2(f.x, f.z)


## Walk and match venues: the loose things are where they should be.
func _venues() -> void:
	var r := Node3D.new()
	root.add_child(r)
	var m := Venue.instantiate_for(Career.exhibition(0))
	r.add_child(m)
	_expect(_loose_in(m).is_empty(), "a match venue has no loose bodies (static copies only)")
	m.queue_free()
	await process_frame
	var v := Venue.instantiate_for(Career.exhibition(0), true)
	r.add_child(v)
	await _frames(3)  # placed and dropped onto their surfaces
	var loose := _loose_in(v)
	var props := loose.filter(func(b: Node) -> bool: return b is LooseProp)
	var start := {}
	for p: LooseProp in props:
		start[p] = p.global_position
	await _frames(240)
	var placed := LooseProps.placed_count()
	print("  %d loose bodies in a walk (%d LooseProps, %d PLACES entries)" % [loose.size(), props.size(), placed])
	_expect(placed >= 60 and props.size() >= placed, "every PLACES entry is a body in a walk (%d >= %d)" % [props.size(), placed])
	var kinds := {}
	for p: LooseProp in props:
		kinds[p.prop_id] = true
	for id in ["trash_can", "toolbox", "fire_extinguisher", "coffee_cup", "puck", "folding_chair", "box_small"]:
		_expect(kinds.has(id), "the walk has a loose %s" % id)
	var rooms := {}
	for p: LooseProp in props:
		var room := v.room_at(v.to_local(p.global_position) + Vector3(0, 0.3, 0))
		if room:
			rooms[room.room_id] = true
	for id in ["lobby", "stands_bench", "office", "rec_offices", "workshop", "zamboni_bay", "locker_home", "locker_3"]:
		_expect(rooms.has(id), "%s has loose things" % id)
	var knocked := loose.filter(func(b: Node) -> bool: return b is StickProp and not b.sleeping)
	_expect(knocked.is_empty(), "no stick is knocked over by a placed prop (%d awake)" % knocked.size())
	var moved := props.filter(func(p: LooseProp) -> bool: return not p.sleeping or p.global_position.distance_to(start[p]) > 0.05)
	_expect(moved.is_empty(), "every loose thing rests asleep where it was put (%d moved: %s)" % [moved.size(), moved.slice(0, 12).map(func(p): return "%s %s->%s" % [p.prop_id, (start[p] as Vector3).snapped(Vector3.ONE * 0.01), p.global_position.snapped(Vector3.ONE * 0.01)])])
	_expect(not PropGrab.grabbable(v.rooms["lobby"].find_child("Collision", false, false)), "the building's colliders (walls, counters, benches) are not grabbable")
	for id in ["workbench", "lockers", "player_bench", "door", "concession_counter", "drill_press"]:
		_expect(not LooseProps.is_loose(id), "%s stays a fixed part" % id)
	v.queue_free()
	await process_frame


func _loose_in(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "RigidBody3D", true, false):
		if c.is_in_group("loose_props"):
			out.append(c)
	return out
