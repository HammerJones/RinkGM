extends SceneTree
## Headless check of VenueWalker's moves on a test floor: the walk and sprint
## speeds it reaches, the jump apex, crouch height and eyes, getting under a
## low beam crouched (and not standing up under it), steps still climbed
## at a sprint, and the eyes gliding up and down stairs instead of jumping
## a step at a time.
##
##   godot --headless --path . --script tools/tests/test_walker_moves.gd

var failures := 0
var world: Node3D


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _box(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	b.collision_mask = 0
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	b.position = pos
	world.add_child(b)


func _walker(pos: Vector3) -> VenueWalker:
	var w := VenueWalker.new()
	world.add_child(w)
	w.global_position = pos
	return w


## Waits `n` sixtieths of a second of physics (the project runs physics at
## its own rate).
func _ticks(n: int) -> void:
	for i in roundi(n / 60.0 * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	create_timer(60.0).timeout.connect(func():
		printerr("FAIL: test_walker_moves timed out")
		quit(1))
	world = Node3D.new()
	root.add_child(world)
	# a big floor, a low beam at x 30 (underside 1.4 m), a 0.3 m step at x -30
	_box(Vector3(200, 1, 40), Vector3(0, -0.5, 0))
	_box(Vector3(2, 0.4, 40), Vector3(30, 1.6, 0))
	_box(Vector3(20, 0.3, 40), Vector3(-40, 0.15, 0))
	await _ticks(2)

	# walk and sprint
	var w := _walker(Vector3(0, 0.05, 10))
	await _ticks(20)
	w.wish = Vector3(1, 0, 0)
	await _ticks(60)
	var v := Vector2(w.velocity.x, w.velocity.z).length()
	_expect(absf(v - VenueWalker.WALK) < 0.05, "walks at %.2f m/s (want 2.2)" % v)
	w.running = true
	await _ticks(15)
	var ramp := Vector2(w.velocity.x, w.velocity.z).length()
	_expect(ramp > VenueWalker.WALK and ramp < VenueWalker.RUN, "sprint ramps up (%.2f m/s after 0.25 s)" % ramp)
	await _ticks(45)
	v = Vector2(w.velocity.x, w.velocity.z).length()
	_expect(absf(v - VenueWalker.RUN) < 0.05, "sprints at %.2f m/s (want 6.5)" % v)
	w.queue_free()

	# jump straight up from standing
	w = _walker(Vector3(0, 0.05, -10))
	await _ticks(30)
	var floor_y := w.global_position.y
	_expect(w.is_on_floor(), "stands on the floor")
	w.jump()
	var apex := floor_y
	var left_floor := false
	for i in 2 * Engine.physics_ticks_per_second:
		await physics_frame
		apex = maxf(apex, w.global_position.y)
		left_floor = left_floor or not w.is_on_floor()
	_expect(left_floor, "the jump leaves the floor")
	_expect(absf(apex - floor_y - VenueWalker.JUMP_HEIGHT) < 0.06, "jump apex %.2f m (want 0.45)" % (apex - floor_y))
	_expect(w.is_on_floor() and absf(w.global_position.y - floor_y) < 0.02, "lands back on the floor")
	w.queue_free()

	# crouch: height, eyes, speed; under the beam; can't stand under it
	w = _walker(Vector3(25, 0.05, 0))
	await _ticks(20)
	w.wish = Vector3(1, 0, 0)
	await _ticks(150)
	_expect(w.global_position.x < 29.0 - VenueWalker.RADIUS + 0.05, "standing, the low beam stops you (x %.2f)" % w.global_position.x)
	w.crouch = true
	await _ticks(60)
	_expect(w.crouched and absf(w.height() - 1.2) < 0.001, "crouched height 1.2 m")
	_expect(absf(w.head.position.y - VenueWalker.CROUCH_EYE) < 0.01, "crouched eyes at %.2f m (want 1.1)" % w.head.position.y)
	v = Vector2(w.velocity.x, w.velocity.z).length()
	_expect(absf(v - VenueWalker.CROUCH_SPEED) < 0.05, "crouch-walks at %.2f m/s (want 1.0)" % v)
	_expect(w.global_position.x > 29.0, "crouched, you get under the beam (x %.2f)" % w.global_position.x)
	w.wish = Vector3.ZERO
	await _ticks(10)
	w.global_position.x = 30.0
	w.crouch = false
	w.jump()
	await _ticks(10)
	_expect(w.crouched and w.global_position.y < 0.1, "can't stand up (or jump) under the beam")
	w.wish = Vector3(1, 0, 0)
	await _ticks(150)
	_expect(not w.crouched and absf(w.head.position.y - VenueWalker.EYE) < 0.01, "stands up once clear (eyes %.2f)" % w.head.position.y)
	w.queue_free()

	# steps at a sprint
	w = _walker(Vector3(-20, 0.05, 5))
	await _ticks(20)
	w.wish = Vector3(-1, 0, 0)
	w.running = true
	await _ticks(150)
	_expect(w.global_position.x < -33.0 and w.global_position.y > 0.25, "sprints up a 0.3 m step (at %s)" % w.global_position)
	w.queue_free()

	# stairs (0.21 m rise, 0.28 m going): the eyes climb smoothly instead of
	# jumping a step at a time
	for i in 8:
		_box(Vector3(0.28 * (8 - i) + 4.0, 0.21, 6), Vector3(60.0 + 0.28 * i + (0.28 * (8 - i) + 4.0) * 0.5, 0.21 * i + 0.105, 15))
	await _ticks(2)
	w = _walker(Vector3(57, 0.05, 15))
	await _ticks(30)
	w.wish = Vector3(1, 0, 0)
	var last := w.head.global_position.y
	var worst := 0.0
	for i in 3 * Engine.physics_ticks_per_second:
		await physics_frame
		var eye := w.head.global_position.y
		worst = maxf(worst, absf(eye - last))
		last = eye
	var climb := 0.21 / 0.28 * VenueWalker.WALK / Engine.physics_ticks_per_second
	_expect(w.global_position.y > 1.6, "walks up the stairs (at %s)" % w.global_position)
	_expect(worst < climb * 2.0, "the eyes climb the stairs smoothly (worst jump %.3f m in a tick, want under %.3f)" % [worst, climb * 2.0])
	# and back down
	w.global_position.x = 63.0
	await _ticks(30)
	w.wish = Vector3(-1, 0, 0)
	last = w.head.global_position.y
	worst = 0.0
	for i in 3 * Engine.physics_ticks_per_second:
		await physics_frame
		var eye := w.head.global_position.y
		worst = maxf(worst, absf(eye - last))
		last = eye
	_expect(w.global_position.y < 0.1, "walks back down (at %s)" % w.global_position)
	_expect(worst < climb * 2.0, "the eyes come down the stairs smoothly (worst jump %.3f m in a tick, want under %.3f)" % [worst, climb * 2.0])
	w.queue_free()

	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)
