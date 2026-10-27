extends SceneTree
## The doors in the rink boards (RinkDoors / RinkDoor): every door in place
## on its gate, the bench gates where the line changes happen (Shell.GATES,
## Game.BENCH_GATES), each one opening and closing, a shut door flush with
## the boards (its ice face within 1 cm of the board line, no gap along the
## opening), the walker kept out while it's shut and let through while it's
## open, the rink's own board mesh cut away in each opening, no fixed glass
## over a glass door, and Doris driving the standard pattern through the
## Zamboni door, which opens as she comes up to it and shuts behind her.
##
##   godot --headless --path . --script res://tools/tests/test_rink_doors.gd

const Shell := preload("res://scripts/venue/rooms/shell.gd")
const PenaltyBoxes := preload("res://scripts/venue/rooms/penalty_boxes.gd")
## [label, style, wall, centre along the wall, width]
const WANT := [
	["Ice gate home far", RinkDoor.Style.BENCH, "z-", -10.95, 0.9],
	["Ice gate home centre", RinkDoor.Style.BENCH, "z-", -3.05, 0.9],
	["Ice gate away centre", RinkDoor.Style.BENCH, "z-", 3.05, 0.9],
	["Ice gate away far", RinkDoor.Style.BENCH, "z-", 10.95, 0.9],
	["Rink door west", RinkDoor.Style.RINK, "z+", -19.0, 1.8],
	["Penalty box home", RinkDoor.Style.RINK, "z+", -2.45, 0.9],
	["Penalty box away", RinkDoor.Style.RINK, "z+", 2.45, 0.9],
	["Rink door east", RinkDoor.Style.RINK, "z+", 19.0, 1.8],
	["Zamboni door", RinkDoor.Style.ZAMBONI, "x+", 0.0, 5.0],
]

var failures := 0
var _world: Node3D
var _venue: Venue
var _rink: Rink
var _doors := {}


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
		printerr("FAIL: test_rink_doors timed out")
		quit(1))
	_bench_gates()
	_world = Node3D.new()
	root.add_child(_world)
	_rink = Rink.new()
	_world.add_child(_rink)
	_venue = Venue.instantiate_for(Career.exhibition(0), true)
	_world.add_child(_venue)
	for i in 4:
		await physics_frame
		await process_frame
	_placement()
	_flush_all("shut")
	_rink_cut()
	_no_fixed_glass()
	await _walker_blocked(true)
	for d: RinkDoor in _doors.values():
		d.open()
	await create_timer(1.8).timeout
	for i in 3:
		await physics_frame
	_opened()
	await _walker_blocked(false)
	for d: RinkDoor in _doors.values():
		d.close()
	await create_timer(1.8).timeout
	for i in 3:
		await physics_frame
	_expect(_doors.values().all(func(d: RinkDoor) -> bool: return not d.is_open and d.leaves.all(func(p: Node3D) -> bool: return absf(p.rotation.y) < 0.001)), "every door swings shut again")
	_flush_all("shut again")
	await _walker_blocked(true)
	await _walk_through()
	_doris_drive()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


# ---------------------------------------------------------------- data

func _bench_gates() -> void:
	var bench: Array = Shell.GATES.filter(func(g: Array) -> bool: return g[0] == "z-")
	var spans := bench.map(func(g: Array) -> Vector2: return Vector2(g[1], g[2]))
	_expect(spans == [Vector2(-11.4, -10.5), Vector2(-3.5, -2.6), Vector2(2.6, 3.5), Vector2(10.5, 11.4)], "bench gates unchanged in Shell.GATES (%s)" % [spans])
	# Game.BENCH_GATES, read from the source (loading the match script here
	# would pull in the whole career)
	var src := FileAccess.get_file_as_string("res://scripts/game/game.gd")
	var re := RegEx.create_from_string("const BENCH_GATES := \\[([^\\]]*)\\]")
	var m := re.search(src)
	var bg: Array = Array(m.get_string(1).split_floats(",")) if m else []
	_expect(bg.size() == 2, "Game.BENCH_GATES found (%s)" % [bg])
	for g: Array in bench:
		var c := (float(g[1]) + float(g[2])) * 0.5
		_expect(bg.any(func(x: float) -> bool: return absf(absf(c) - x) < 0.001), "bench gate centre x %.2f is a Game.BENCH_GATES spot %s" % [c, bg])


func _placement() -> void:
	for d in _venue.all_doors():
		if d is RinkDoor:
			_doors[d.label] = d
	_expect(_doors.size() == WANT.size(), "%d doors in the boards (%d)" % [WANT.size(), _doors.size()])
	for w: Array in WANT:
		var d: RinkDoor = _doors.get(w[0])
		if d == null:
			_expect(false, "%s is hung" % w[0])
			continue
		var p := d.global_position
		var at: float
		var line: float
		match w[2]:
			"z-":
				at = p.x
				line = absf(p.z + Rink.HALF_W)
			"z+":
				at = p.x
				line = absf(p.z - Rink.HALF_W)
			_:
				at = p.z
				line = absf(p.x - Rink.HALF_L)
		_expect(d.style == w[1] and d.wall == w[2] and absf(at - float(w[3])) < 0.005 and line < 0.005 and absf(d.width - float(w[4])) < 0.005,
			"%s: %s door at %s %.2f, %.2f m wide, on the board line (%.3f off)" % [w[0], RinkDoor.Style.keys()[d.style], "x" if w[2] != "x+" else "z", at, d.width, line])
		var glass := VenuePhysics.glass_height(Vector2(p.x, p.z), Rink.board_normal(Vector2(p.x, p.z)) if w[2] != "z-" else Vector2(0, -1))
		if d.style == RinkDoor.Style.BENCH:
			_expect(d.glass_h == 0.0 and d.leaves.size() == 1, "%s: one board leaf, no glass" % w[0])
		else:
			_expect(absf(d.glass_h - glass) < 0.001 and d.glass_h > 0.0, "%s: glass on top as tall as the rink glass beside it (%.2f m)" % [w[0], d.glass_h])
	var zd: RinkDoor = _doors.get("Zamboni door")
	if zd:
		_expect(zd.kind == VenueDoor.Kind.DOUBLE and zd.leaves.size() == 2, "the Zamboni door is a double door")
	# the penalty box doors open into the boxes, beside the timekeeper
	for i in [0, 2]:
		var box: Array = PenaltyBoxes.BOXES[i]
		var d: RinkDoor = _doors.get("Penalty box home" if i == 0 else "Penalty box away")
		if d:
			var keeper: float = PenaltyBoxes.BOXES[1][1]  # the timekeeper's box: |x| < 1.5
			var near := minf(absf(absf(d.span.x) - keeper), absf(absf(d.span.y) - keeper))
			_expect(d.span.x >= float(box[0]) and d.span.y <= float(box[1]) and near < 1.0,
				"%s opens into its box (%.2f..%.2f), %.2f m from the timekeeper's wall" % [d.label, d.span.x, d.span.y, near])
	# every gate has its door
	for g: Array in Shell.GATES:
		var hit := _doors.values().any(func(d: RinkDoor) -> bool: return d.wall == g[0] and absf(d.span.x - float(g[1])) < 0.001 and absf(d.span.y - float(g[2])) < 0.001)
		_expect(hit, "gate %s %.2f..%.2f has a door" % g)


# ---------------------------------------------------------------- geometry

func _rig() -> RinkDoors.Rig:
	return _venue.rooms["glass"].find_child("RinkDoorRig", true, false) as RinkDoors.Rig


## The leaf vertices of `d` as drawn now (the bone pose applied), in venue
## space: the board sections and hardware, without the glass.
func _leaf_points(d: RinkDoor) -> PackedVector3Array:
	var rig := _rig()
	var out := PackedVector3Array()
	var a := rig.solid.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
	for bi in rig.bones.size():
		if rig.bones[bi][0] != d:
			continue
		var pose := rig.get_bone_global_pose(bi)
		for i in vs.size():
			if bs[i * 4] == bi:
				out.append(pose * vs[i])
	return out


## [along the wall, depth out from the board line (+ away from the ice)].
static func _wall_coords(d: RinkDoor, p: Vector3) -> Vector2:
	match d.wall:
		"z-":
			return Vector2(p.x, -p.z - Rink.HALF_W)
		"z+":
			return Vector2(p.x, p.z - Rink.HALF_W)
	return Vector2(p.z, p.x - Rink.HALF_L)


func _flush_all(when: String) -> void:
	for d: RinkDoor in _doors.values():
		var pts := _leaf_points(d)
		var face := INF
		var lo := INF
		var hi := -INF
		for p in pts:
			var w := _wall_coords(d, p)
			face = minf(face, w.y)
			if w.y < 0.05 and p.y < Rink.BOARD_H:
				lo = minf(lo, w.x)
				hi = maxf(hi, w.x)
		_expect(not pts.is_empty() and absf(face) <= 0.01, "%s %s: ice face %.4f m from the board line (flush, no lip)" % [d.label, when, face])
		_expect(lo - d.span.x <= 0.01 and d.span.y - hi <= 0.01 and lo >= d.span.x - 0.001 and hi <= d.span.y + 0.001,
			"%s %s: leaves fill the opening (%.3f..%.3f of %.3f..%.3f)" % [d.label, when, lo, hi, d.span.x, d.span.y])


func _opened() -> void:
	for d: RinkDoor in _doors.values():
		var turned := d.leaves.all(func(p: Node3D) -> bool: return absf(absf(p.rotation.y) - d.swing) < 0.01)
		var inside := 0
		var onto_ice := 0
		for p in _leaf_points(d):
			var w := _wall_coords(d, p)
			if w.x > d.span.x + 0.03 and w.x < d.span.y - 0.03 and w.y < RinkDoor.THICK - 0.01:
				inside += 1
			if w.y < -0.01:
				onto_ice += 1
		_expect(d.is_open and turned and inside == 0 and onto_ice == 0,
			"%s opens: leaves swung %.0f deg away from the ice, the opening clear (%d points in it, %d on the ice)" % [d.label, rad_to_deg(d.swing), inside, onto_ice])


func _rink_cut() -> void:
	var mi := RinkDoors.board_mesh(_rink)
	_expect(mi != null and _rink.has_meta(RinkDoors.CUT_META), "the rink's board mesh is cut at the doors")
	if mi == null:
		return
	var vs: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for d: RinkDoor in _doors.values():
		var left := 0
		for t in vs.size() / 3:
			var c := (vs[t * 3] + vs[t * 3 + 1] + vs[t * 3 + 2]) / 3.0
			var w := _wall_coords(d, c)
			if w.x > d.span.x + 0.005 and w.x < d.span.y - 0.005 and w.y > -0.01 and w.y < 0.4:
				left += 1
		_expect(left == 0, "%s: none of the rink's own boards left in the opening (%d triangles)" % [d.label, left])


func _no_fixed_glass() -> void:
	var room: Node = _venue.rooms["glass"]
	var pane := Props.mesh("glass_pane", room.age, 1)
	for c in room.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh.mesh != pane:
			continue
		var over := 0
		for i in mmi.multimesh.instance_count:
			var xf := mmi.multimesh.get_instance_transform(i)
			var half := xf.basis.x.length() * RinkDoors.PANEL * 0.5
			for d: RinkDoor in _doors.values():
				if d.glass_h <= 0.0:
					continue
				var w := _wall_coords(d, xf.origin)
				if absf(w.y - 0.16) < 0.05 and w.x + half > d.span.x + 0.01 and w.x - half < d.span.y - 0.01:
					over += 1
		_expect(over == 0, "no fixed glass panel over a glass door (%d)" % over)


## A ray across each opening at knee and at head height, from the ice to
## the walkway, on the venue layer: blocked while shut, clear while open.
func _walker_blocked(shut: bool) -> void:
	await physics_frame
	var space := _world.get_world_3d().direct_space_state
	for d: RinkDoor in _doors.values():
		var hits := 0
		var rays := 0
		for u: float in [-0.3, 0.07, 0.3]:
			for y: float in [0.5, d.height - 0.2]:
				var a := d.global_transform * Vector3(u * d.width, y, -0.6)
				var b := d.global_transform * Vector3(u * d.width, y, 0.6)
				var q := PhysicsRayQueryParameters3D.create(a, b, 1 << (VenueKit.VENUE_LAYER - 1))
				rays += 1
				if not space.intersect_ray(q).is_empty():
					hits += 1
		if shut:
			_expect(hits == rays, "%s shut keeps the walker out (%d of %d rays blocked)" % [d.label, hits, rays])
		else:
			_expect(hits == 0, "%s open lets the walker through (%d of %d rays blocked)" % [d.label, hits, rays])


## A walker in the bench, the box, the walkway or the bay side: the door is
## the one the walk's use key works (VenueWalker.nearest_door, toggle), it
## can't get onto the ice while the door's shut, and can once it's open.
func _walk_through() -> void:
	var w := VenueWalker.new()
	_world.add_child(w)
	for label in ["Ice gate home centre", "Ice gate away far", "Penalty box away", "Rink door west", "Zamboni door"]:
		var d: RinkDoor = _doors.get(label)
		if d == null:
			continue
		var inv := d.global_transform.affine_inverse()
		# beside the opening on the latch side, just out of the leaf's sweep
		var stand := Vector3(0, 0.1, 0.75)
		var spec: Array = d.leaf_specs()[0]
		if d.leaves.size() == 1:
			var piv: Vector3 = spec[3]
			var reach := Vector2(float(spec[1]) + RinkDoor.POST_HINGE.x, RinkDoor.THICK).length() + 0.35
			stand.x = -float(spec[0]) * 0.5
			stand.z = piv.z + sqrt(maxf(reach * reach - pow(stand.x - piv.x, 2.0), 0.36))
		w.global_position = d.global_transform * stand
		w.velocity = Vector3.ZERO
		var toward_ice := -d.global_transform.basis.z
		w.wish = toward_ice
		for i in 60:
			await physics_frame
		var shut_z := (inv * w.global_position).z
		var near := w.nearest_door(_venue)
		_expect(near == d, "%s: the door the walk's use key works, stood at it (%s)" % [label, near.label if near else "none"])
		# back out of the leaf's way, then the use key
		w.wish = Vector3.ZERO
		w.global_position = d.global_transform * stand
		w.velocity = Vector3.ZERO
		await physics_frame
		d.toggle()
		await create_timer(d.swing_time + 0.3).timeout
		# then through the middle of the opening (the leaf may have pushed
		# the walker aside as it swung)
		var target := d.global_transform * Vector3(0, 0, -1.5)
		for i in 240:
			var to := target - w.global_position
			to.y = 0.0
			w.wish = to.normalized() if to.length() > 0.2 else Vector3.ZERO
			await physics_frame
		var open_z := (inv * w.global_position).z
		w.wish = Vector3.ZERO
		_expect(shut_z > 0.25 and d.is_open and open_z < -0.5, "%s: the walker stays off the ice while it's shut (%.2f m), walks through once it's open (%.2f m)" % [label, shut_z, open_z])
		d.close()
	w.queue_free()
	await create_timer(1.6).timeout


# ---------------------------------------------------------------- Doris

## The autopilot drives the standard pattern from the bay; a DorisModel
## follows her as DorisDrive's _sync_body places it, and the Zamboni door
## watches her.
func _doris_drive() -> void:
	var door: RinkDoor = _doors.get("Zamboni door")
	if door == null:
		return
	_expect(ResurfaceRun.GATE_HALF + 0.05 < door.width * 0.5, "Doris's lane through the gate (%.2f m each side) fits the door (%.2f)" % [ResurfaceRun.GATE_HALF, door.width * 0.5])
	var run := ResurfaceRun.start(IceSlab.create_millbrook(), ResurfacerSim.create_doris())
	var ap := ResurfaceAutopilot.new(run, ResurfaceAutopilot.NORMAL)
	ap.fill_first = false
	var body := DorisModel.new(Wear.WORN)
	_world.add_child(body)
	var dt := 0.1
	var opens := 0
	var was_open := door.is_open
	var crossings := 0
	var outside := 0
	var shut_while_in := 0
	var shut_on_ice := false
	var shut_at_end := false
	while not ap.done and run.time_s < 1800.0:
		ap.tick(dt)
		var f := run.fwd()
		body.transform = Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(run.pos.x + f.x * DorisModel.AXLE_Z, 0.0, run.pos.y + f.y * DorisModel.AXLE_Z))
		door._process(dt)
		if door.is_open and not was_open:
			opens += 1
			print("    door opens: Doris at %s heading %s t %.0f" % [run.pos, run.fwd(), run.time_s])
		if was_open and not door.is_open:
			print("    door shuts: Doris at %s t %.0f" % [run.pos, run.time_s])
		was_open = door.is_open
		# every part of her that's at the board line is inside the opening
		var l := run.left()
		for c: Vector2 in [run.pos + f * ResurfaceRun.BODY_FRONT + l * ResurfaceRun.BODY_HALF_W, run.pos + f * ResurfaceRun.BODY_FRONT - l * ResurfaceRun.BODY_HALF_W,
				run.pos - f * ResurfaceRun.BODY_REAR + l * ResurfaceRun.BODY_HALF_W, run.pos - f * ResurfaceRun.BODY_REAR - l * ResurfaceRun.BODY_HALF_W]:
			if c.x > Rink.HALF_L and c.x < Rink.HALF_L + RinkDoor.THICK + 0.05:
				crossings += 1
				if absf(c.y) > door.width * 0.5 - 0.05:
					outside += 1
				if not door.is_open:
					shut_while_in += 1
		if run.on_ice() and run.pos.x < 0.0 and not door.is_open:
			shut_on_ice = true
	for i in 20:
		door._process(dt)
	shut_at_end = not door.is_open
	print("  Doris: %.0f s, %d door openings, %d corner samples at the board line" % [run.time_s, opens, crossings])
	_expect(ap.done, "the autopilot finished the standard pattern")
	_expect(crossings > 0 and outside == 0, "Doris's path goes through the Zamboni door's opening (%d of %d samples outside it)" % [outside, crossings])
	_expect(shut_while_in == 0, "the door is open whenever she's in it (%d samples shut)" % shut_while_in)
	_expect(opens == 2, "it opens as she goes out and as she comes back (%d openings)" % opens)
	_expect(shut_on_ice, "it shuts behind her while she cuts the ice")
	_expect(shut_at_end, "it's shut once she's parked again")
	body.queue_free()
