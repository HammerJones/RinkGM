extends SceneTree
## The framework's prop and streaming layer under Jolt: a PropField with
## ten thousand rows (instanced draw + static colliders, no nodes), waking
## rows into rigid bodies, bodies settling back to rows, ray picking, and a
## ChunkStreamer loading and freeing a chunk around the focus. Prints
## timings and fails CI when the budgets break.
##   godot --headless --path . --script res://tools/tests/test_framework_props.gd

const ROWS := 10000
const AREA := 100.0
const FIXTURE := "res://framework/bench/chunk_fixture.tscn"

var failures := 0
var field: PropField
var streamer: ChunkStreamer
var meshes: Array[ArrayMesh] = []
var boxes: Array = []
var frame := 0
var phase := 0
var phase_frame := 0
var frame_usec: Array[int] = []
var woken: Array[PropRow] = []
var _last := 0


func _initialize() -> void:
	var engine: String = ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")
	print("physics engine: %s" % engine)
	# flat out: the headless loop otherwise sleeps 6.9 ms a frame and hides all work
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	_check(engine.begins_with("Jolt"), "project runs on Jolt (got %s)" % engine)
	var holder := Node3D.new()
	root.add_child(holder)
	# a floor so woken bodies have something to settle on
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(AREA * 2, 1.0, AREA * 2)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	floor_body.collision_layer = 0b11
	holder.add_child(floor_body)
	field = PropField.new()
	field.live_cap = 64
	field.sleep_radius = 30.0
	holder.add_child(field)
	_meshes()
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in ROWS:
		var k := i % meshes.size()
		var xf := Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(rng.randf() * AREA - AREA / 2, 0.0, rng.randf() * AREA - AREA / 2)
		)
		field.add(
			StringName("row.%d" % i), StringName("prop%d" % k), meshes[k], boxes[k], xf, 0.5 + k
		)
	var add_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("added %d rows in %.0f ms (%s)" % [ROWS, add_ms, field.stats()])
	_check(field.count() == ROWS, "all rows added")
	_check(add_ms < 6000.0, "adding 10k rows takes under 6 s (%.0f ms)" % add_ms)
	streamer = ChunkStreamer.new()
	streamer.load_radius = 10.0
	streamer.unload_radius = 15.0
	holder.add_child(streamer)
	streamer.register(FIXTURE, AABB(Vector3(50, 0, 50), Vector3(8, 4, 8)))
	streamer.focus = Vector3(200, 0, 200)


func _process(_dt: float) -> bool:
	# wall-clock per frame; tools/ci.sh runs this script with --fixed-fps 120,
	# so every frame is exactly one physics step and no real-time pacing
	var now := Time.get_ticks_usec()
	if _last > 0 and (phase > 0 or phase_frame > 4):  # the first frames build the cells
		frame_usec.append(now - _last)
	_last = now
	frame += 1
	phase_frame += 1
	match phase:
		0:  # idle: nothing live, measure the frame cost of 10k instanced rows
			if phase_frame >= 60:
				_report("idle")
				_check(
					_avg_ms() < 1.0,
					"idle frame (one physics step) under 1 ms with 10k rows (%.3f ms)" % _avg_ms()
				)
				_pick()
				_wake()
				_next()
		1:  # live: 64 bodies dropped from 1 m, let them settle
			if phase_frame >= 240:
				_report("live")
				_check(
					_avg_ms() < 2.5,
					"frame under 2.5 ms with 64 live bodies among 10k rows (%.3f ms)" % _avg_ms()
				)
				var asleep := 0
				for r in woken:
					if r.node and r.node.sleeping:
						asleep += 1
					elif r.node == null:
						asleep += 1
				print(
					"woke %d rows, %d settled (field: %s)" % [woken.size(), asleep, field.stats()]
				)
				_check(
					asleep >= woken.size() / 2,
					"most bodies settle within 2 s (%d of %d)" % [asleep, woken.size()]
				)
				_check(field.live_count() <= field.live_cap, "live count within cap")
				_next()
		2:  # move away: settled bodies go back to rows
			field.focus = Vector3(500, 0, 500)
			if phase_frame >= 90:
				print("after leaving: %s" % field.stats())
				_check(
					field.live_count() < woken.size() / 2,
					"far sleeping bodies are demoted (%d live)" % field.live_count()
				)
				var r := woken[0]
				_check(r.node == null or not r.node.sleeping, "demoted row has no node")
				_check(
					r.tier == PropRow.Tier.INSTANCED or r.node != null,
					"demoted row is instanced again"
				)
				_streaming_in()
				_next()
		3:  # streaming in
			if streamer.is_loaded(FIXTURE) or phase_frame > 240:
				_check(streamer.is_loaded(FIXTURE), "chunk loads when the focus comes near")
				streamer.focus = Vector3(500, 0, 500)
				_next()
		4:  # streaming out
			if not streamer.is_loaded(FIXTURE) or phase_frame > 120:
				_check(not streamer.is_loaded(FIXTURE), "chunk unloads when the focus leaves")
				_remove()
				_finish()
				return true
	return false


func _next() -> void:
	phase += 1
	phase_frame = 0
	frame_usec.clear()
	_last = 0


func _meshes() -> void:
	var cols := [Color("9a6b3f"), Color("8fbfa8"), Color("d0202a")]
	var sizes := [Vector3i(6, 4, 6), Vector3i(3, 8, 3), Vector3i(10, 2, 4)]
	for i in 3:
		var m := VoxelModel.new(0.065)
		var s: Vector3i = sizes[i]
		m.box(0, 0, 0, s.x, s.y, s.z, cols[i])
		m.set_pivot(s.x / 2.0, 0, s.z / 2.0)
		meshes.append(VoxMesher.build(m, {"greedy": true}))
		boxes.append(m.collision_boxes())


func _pick() -> void:
	var r0 := field.rows[0]
	var top := r0.xf.origin + Vector3(0, 3, 0)
	var hit := field.raycast(top, r0.xf.origin - Vector3(0, 1, 0))
	_check(hit != null, "a ray down onto a row hits it")
	_check(
		hit == r0 or (hit != null and hit.xf.origin.distance_to(r0.xf.origin) < 1.0),
		"the ray reports the row under it"
	)
	var near := field.nearest(r0.xf.origin, 3.0)
	_check(not near.is_empty() and near[0] == r0, "nearest() finds the row at its own position")


func _wake() -> void:
	field.focus = Vector3.ZERO
	var near := field.nearest(Vector3.ZERO, 40.0)
	for r in near:
		if woken.size() >= 64:
			break
		var b := field.wake(r)
		if b:
			b.position.y += 1.0
			woken.append(r)
	_check(woken.size() == 64, "64 rows woke (got %d)" % woken.size())
	_check(field.live_count() == 64, "live count is 64")
	# the 65th waker is refused while every body is awake
	var extra := field.wake(near[70])
	_check(extra == null, "wake past the cap is refused while bodies are awake")
	_check(field.stats().cells > 0, "instanced rows sit in cell bodies")


func _streaming_in() -> void:
	streamer.focus = Vector3(54, 0, 54)
	streamer.refresh()


func _remove() -> void:
	var before := field.count()
	for i in 100:
		field.remove(field.rows[0])
	_check(field.count() == before - 100, "rows remove")
	_check(field.get_row(&"row.0") == null, "removed row is gone by id")
	var dicts := field.to_dicts()
	_check(dicts.size() == field.count() and dicts[0].has("xf"), "rows save to dicts")


func _report(label: String) -> void:
	print(
		(
			"%s: %d frames, %.3f ms/frame avg, %.3f max, field tick %.2f ms, rebuilds %d (%.1f ms)"
			% [
				label,
				frame_usec.size(),
				_avg_ms(),
				_max_ms(),
				field.stats().tick_ms,
				field.stats().rebuilds,
				field.stats().rebuild_ms
			]
		)
	)


func _avg_ms() -> float:
	if frame_usec.is_empty():
		return 0.0
	var s := 0
	for u in frame_usec:
		s += u
	return s / 1000.0 / frame_usec.size()


func _max_ms() -> float:
	var m := 0
	for u in frame_usec:
		m = maxi(m, u)
	return m / 1000.0


func _finish() -> void:
	if failures == 0:
		print("framework_props test: all passed")
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)
