extends SceneTree
## Headless check of the physical readables (notes, signs, banners) and the
## walk's hands: every readable has its texture, the lobby's cork board and
## the plant room door carry real paper (the door's notes ride on its leaf),
## E leans in, left mouse takes a loose note down and sticks it somewhere
## else, F crumples a held one, and the locker room whiteboard takes your
## doodles on their own layer (wiping them leaves the coach's plan).
##
##   godot --headless --path . --script tools/tests/test_readables.gd

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
		await process_frame


## Turns the walk's view to `p` and lets the camera follow.
func _look(w: Node, p: Vector3) -> void:
	var to: Vector3 = p - w.cam.global_position
	w._yaw = atan2(-to.x, -to.z)
	w._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(2)


func _run() -> void:
	var defs := Readable.defs()
	_expect(defs.size() >= 40, "readables.json lists the readables (%d)" % defs.size())
	var missing := []
	for id in defs:
		if not ResourceLoader.exists(defs[id].texture):
			missing.append(id)
	_expect(missing.is_empty(), "every readable has its texture %s" % [missing])

	var w: Node3D = load("res://scripts/venue/venue_walk.gd").new()
	root.add_child(w)
	await _frames(4)
	var all := root.get_tree().get_nodes_in_group("readables")
	var cork := all.filter(func(r): return r.id.begins_with("cork_") and r.movable)
	_expect(cork.size() >= 9, "the lobby cork board has its flyers (%d)" % cork.size())
	var door_notes := all.filter(func(r): return r.id == "gus_breaker")
	var on_door := false
	for r in door_notes:
		var p: Node = r.get_parent()
		while p and not on_door:
			on_door = p is VenueDoor
			p = p.get_parent()
	_expect(on_door, "Gus's breaker note is stuck to the plant room door, so it swings with it")
	_expect(all.any(func(r): return r.kind == "banner" and r.string_length > 0.0), "the felt banners hang on strings")

	# stand in front of the cork board and take the lost cat flyer down
	w.walker.global_position = Vector3(-35.6, 0.05, -6.3)
	await _frames(3)
	var cat: Readable = cork.filter(func(r): return r.id == "cork_lost_cat")[0]
	await _look(w, cat.face_center())
	_expect(w._looked_readable(w.HAND_REACH) == cat, "looking at the lost cat flyer picks it")
	w._hand()
	_expect(w._held == cat and cat.get_parent() == w.cam, "left mouse takes it down into your hand")
	# stick it on the bare wall beside the board
	await _look(w, Vector3(-34.3, 1.5, -7.25))
	w._hand()
	await _frames(2)
	_expect(w._held == null and cat.get_parent() is StaticBody3D, "left mouse sticks it to the wall")
	_expect(absf(cat.global_transform.basis.z.dot(Vector3(-1, 0, 0)) - 1.0) < 0.05, "flat against the wall, facing the room")
	_expect(w._looked_readable(w.HAND_REACH) == cat, "and it can be found and taken down again")
	w._hand()
	w._crumple()
	await _frames(2)
	_expect(not is_instance_valid(cat) and w.venue.find_child("CrumpledNote", false, false) != null, "F crumples it into a paper ball")

	# lean in on the bonspiel poster
	var bon: Readable = cork.filter(func(r): return is_instance_valid(r) and r.id == "cork_bonspiel")[0]
	await _look(w, bon.face_center())
	w._use()
	_expect(w._inspect == bon, "E leans in on the poster")
	await _frames(40)
	_expect(w.cam.fov < 40.0, "the view narrows on it (fov %.1f)" % w.cam.fov)
	w._use()
	await _frames(40)
	_expect(w._inspect == null and w.cam.fov > 65.0, "E again steps back")

	# draw on the home locker room's whiteboard, then wipe it
	var boards := root.find_children("*", "Whiteboard", true, false)
	_expect(boards.size() >= 1, "the locker rooms have real whiteboards (%d)" % boards.size())
	var wb: Whiteboard = null
	for b in boards:
		if b.global_position.z > 0.0 and b.global_position.x > 30.0:
			wb = b
	w.walker.global_position = wb.global_position + Vector3(1.6, -1.5, 0.0)
	await _frames(3)
	await _look(w, wb.global_position + Vector3(0, 0.1, -0.3))
	_expect(w._looked_whiteboard() == wb, "looking at the whiteboard")
	w._hand()
	_expect(w._drawing == wb, "left mouse starts drawing")
	for i in 12:
		await _look(w, wb.global_position + Vector3(0, 0.1 - i * 0.02, -0.3 + i * 0.05))
	w._drawing.end_stroke()
	w._drawing = null
	var ink := wb.ink_coverage()
	_expect(ink > 0.0005, "a line of your ink on the board (%.4f)" % ink)
	_expect(is_instance_valid(wb.marks) and wb.marks.id == "whiteboard_marks", "the coach's drawings are their own layer")
	wb.wipe()
	_expect(wb.ink_coverage() == 0.0 and is_instance_valid(wb.marks), "X wipes only your marks")

	# W7, W15: every board shows its own marks, and they change with the day
	var keyed := boards.filter(func(b: Whiteboard) -> bool: return not b.board_key.is_empty())
	var today := {}
	for b: Whiteboard in keyed:
		today[b.signature] = b.board_key
	_expect(keyed.size() >= 4 and today.size() == keyed.size(), "%d whiteboards (pro and rec dressing rooms), no two alike" % keyed.size())
	var inked := keyed.all(func(b: Whiteboard) -> bool: return b._people_img.get_used_rect().size.x > b._people_img.get_width() * 0.5)
	_expect(inked, "each board has the people's marks across it")
	var before := {}
	for b: Whiteboard in keyed:
		before[b] = b.signature
	Whiteboard.set_day(self, Whiteboard.day + 1)
	var changed := keyed.all(func(b: Whiteboard) -> bool: return b.signature != before[b])
	var tomorrow := {}
	for b: Whiteboard in keyed:
		tomorrow[b.signature] = true
	_expect(changed and tomorrow.size() == keyed.size(), "the next day every board shows something new, still no two alike")

	print("readables: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)
