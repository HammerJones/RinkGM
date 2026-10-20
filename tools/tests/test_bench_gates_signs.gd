extends SceneTree
## Headless check of the bench layout and the rink's physical signs (W9-W11,
## W13, W17, W19): each bench has a gate onto the ice at both of its ends, on
## the line-change spots (Game.bench_spot / bench_exit), its walkway door on
## the narrow end wall, and the ticket booth, Programs board and dressing room
## numbers are real readables, not RinkOS signs.
##
##   godot --headless --path . --script tools/tests/test_bench_gates_signs.gd

const Shell := preload("res://scripts/venue/rooms/shell.gd")
## Game.BENCH_GATES (|x| of each bench's centre-ice and far gate centres)
const BENCH_GATES := [3.05, 10.95]
const Benches := preload("res://scripts/venue/rooms/benches.gd")

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
	create_timer(90.0).timeout.connect(func():
		printerr("FAIL: test_bench_gates_signs timed out")
		quit(1))
	# gates: two per bench, one at each end, centred on the line-change spots
	for bi in 2:
		var x0: float = Benches.BENCHES[bi][0]
		var x1: float = Benches.BENCHES[bi][1]
		var centres: Array[float] = []
		for g: Array in Shell.GATES:
			var a: float = g[1]
			var b: float = g[2]
			if g[0] == "z-" and a >= x0 - 0.01 and b <= x1 + 0.01:
				centres.append((a + b) * 0.5)
		_expect(centres.size() == 2, "bench %d has two ice gates (%s)" % [bi, centres])
		var sgn := -1.0 if bi == 0 else 1.0
		for want: float in BENCH_GATES:
			var hit := false
			for c in centres:
				hit = hit or absf(c - sgn * want) < 0.01
			_expect(hit, "bench %d gate at x %.2f (BENCH_GATES)" % [bi, sgn * want])
		for c in centres:
			_expect(absf(c - x0) < 1.0 or absf(c - x1) < 1.0, "bench %d gate x %.2f sits at an end" % [bi, c])
	# signs are readables with definitions
	for id in ["sign_tickets", "sign_programs", "sign_room_3", "sign_room_4", "sign_room_5", "sign_room_6"]:
		_expect(Readable.has_def(id), "readable %s defined" % id)
	# the built venue: walkway doors on the end walls, signs in place
	var v := Venue.instantiate_for(Career.exhibition(0), true)
	root.add_child(v)
	for i in 3:
		await physics_frame
	var found := 0
	for d in v.all_doors():
		if d.label.begins_with("Bench "):
			found += 1
			var p: Vector3 = d.global_position
			_expect(absf(absf(p.x) - 2.6) < 0.01 and absf(p.z - Benches.END_DOOR_Z) < 0.01 and absf(absf(d.rotation.y) - PI * 0.5) < 0.01,
				"%s door on the end wall at (%.2f, %.2f)" % [d.label, p.x, p.z])
	_expect(found == 2, "two bench walkway doors (%d)" % found)
	var names := {}
	for n in v.find_children("*", "Readable", true, false):
		names[n.name] = true
	for want in ["TicketSign", "ProgramsBoard", "RoomNumber", "RoomNumberHall"]:
		_expect(names.has(want), "%s is a physical readable" % want)
	var left := 0
	for n in v.find_children("*", "VenueSign", true, false):
		if n.name in ["TicketSign", "ProgramsBoard", "RoomNumber"]:
			left += 1
	_expect(left == 0, "no RinkOS ticket, programs or room number signs left (%d)" % left)
	v.queue_free()
	await process_frame
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)
