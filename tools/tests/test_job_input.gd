extends SceneTree
## Checks the rink job verbs the mini game scenes drive from JobInput:
## fasteners run down and tighten, a hand stops at hand tight, a wrench
## before the threads catch cross-threads, the torque wrench clicks on its
## set point, and the oil pump delivers by stroke and slips when rushed.
##   godot --headless --path . --script res://tools/tests/test_job_input.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_fasteners()
	_torque_wrench()
	_pump()
	_picker()
	_input_layer()
	if failures:
		printerr("test_job_input: %d failure(s)" % failures)
	else:
		print("test_job_input: ok")
	quit(1 if failures else 0)


## Turns `total` revolutions in small steps, like a tick's worth of input.
func _spin(f: Fastener, total: float, tool: Fastener.Tool, step := 1.0 / 60.0) -> void:
	var left := total
	while absf(left) > 0.00001:
		var t := signf(left) * minf(absf(left), step)
		f.turn(t, tool)
		left -= t


func _fasteners() -> void:
	# a plug spun in by hand stops at hand tight
	var plug := Fastener.spark_plug()
	_spin(plug, 20.0, Fastener.Tool.HAND)
	_check(plug.seated() and plug.stalled, "a hand runs a plug down and stalls at hand tight")
	_check(absf(plug.turns_past_hand_tight()) < 0.001, "the stall is at hand tight")
	_check(plug.grade()["flags"].has(&"bolt_undertorqued"), "hand tight alone is under the plug's 15 ft-lb")
	# then a ratchet to the spec
	_spin(plug, (15.0 - plug.torque()) / plug.stiffness / 360.0, Fastener.Tool.RATCHET)
	var g := plug.grade()
	_check(g["score"] > 0.99 and g["flags"].is_empty(), "plug at 15 ft-lb scores 1.0 (%s)" % g)
	# hand tight plus a quarter on a filter-style spec
	var filt := Fastener.oil_filter()
	filt.plus_turns = 0.25
	_spin(filt, 10.0, Fastener.Tool.HAND)
	_spin(filt, 0.25, Fastener.Tool.RATCHET)
	g = filt.grade()
	_check(g["score"] > 0.99, "hand tight plus a quarter scores 1.0 (%s)" % g)
	# the real filter spec is + 3/4: a quarter is short
	filt.plus_turns = 0.75
	g = filt.grade()
	_check(g["score"] == 0.7 and g["flags"].has(&"bolt_undertorqued"), "a filter only a quarter past hand tight is undertightened")
	# edge of tolerance scores 0.85
	var bolt := Fastener.blade_bolt()
	_spin(bolt, 5.0, Fastener.Tool.HAND)
	_spin(bolt, (35.0 + 3.5) / bolt.stiffness / 360.0, Fastener.Tool.RATCHET)
	g = bolt.grade(0.3)
	_check(absf(g["score"] - 0.85) < 0.01, "blade bolt at the tolerance edge scores 0.85 (%s)" % g)
	_check(bolt.grade(0.9)["score"] > 0.9, "a skilled owner's wider window forgives it")
	_spin(bolt, 10.0 / bolt.stiffness / 360.0, Fastener.Tool.RATCHET)
	_check(bolt.grade()["flags"].has(&"bolt_overtorqued"), "past tolerance flags overtorque")
	# loosening backs it off and out
	_spin(bolt, -6.0, Fastener.Tool.RATCHET)
	_check(bolt.torque() == 0.0 and not bolt.seated(), "turning anticlockwise loosens it")
	# a wrench before the threads catch
	var crossed := Fastener.housing_bolt()
	_spin(crossed, 4.0, Fastener.Tool.RATCHET)
	_check(crossed.cross_threaded and crossed.grade()["flags"].has(&"cross_threaded"), "starting a bolt with a wrench cross-threads it")
	_check(crossed.grade()["score"] == 0.7, "a cross-threaded bolt scores 0.7")


func _torque_wrench() -> void:
	var bolt := Fastener.blade_bolt()
	_spin(bolt, 5.0, Fastener.Tool.HAND)
	var w := TorqueWrench.new(bolt)
	_check(w.set_point == 35.0, "the wrench takes the bolt's spec as its set point")
	var clicks := 0
	for i in 600:
		w.pull(1.0 / 720.0)
		if w.clicked_now:
			clicks += 1
		if w.clicked:
			break
	_check(clicks == 1 and absf(bolt.torque() - 35.0) < 0.01, "it clicks once, on 35 ft-lb (%.2f)" % bolt.torque())
	# a few degrees more is the head breaking over, not the bolt turning
	w.pull(4.0 / 360.0)
	_check(absf(bolt.torque() - 35.0) < 0.01 and not w.overpulled, "the break-over after the click is free")
	var g := bolt.grade()
	_check(g["score"] > 0.99, "stopping on the click scores 1.0")
	# keep heaving on it and the bolt goes on tightening
	w.pull(10.0 / 360.0)
	_check(w.overpulled and bolt.torque() > 35.0 + 3.5, "pulling through the click overtorques")
	_check(bolt.grade()["flags"].has(&"bolt_overtorqued"), "and flags it")
	# release and pull again: it clicks straight away, nothing moves
	w.release()
	var before := bolt.torque()
	w.pull(1.0 / 360.0)
	_check(w.clicked_now and bolt.torque() == before, "a bolt already past the set point clicks at once")
	# the dial
	w.adjust(-10)
	_check(w.set_point == 25.0, "the dial adjusts the set point")


func _pump() -> void:
	var dt := 1.0 / 120.0
	var p := HandPump.new(26.0, 30.0)
	# steady strokes, a second each (half up, half down)
	for s in 16:
		for i in 120:
			var ph := float(i) / 120.0
			p.stroke(1.0 - ph * 2.0 if ph < 0.5 else (ph - 0.5) * 2.0, dt)
			_check_quiet(not p.slipping, "steady strokes don't slip")
	_check(absf(p.litres - 30.0) < 0.05, "16 full strokes deliver 4 L (%.2f)" % p.litres)
	_check(absf(p.level() - 0.5) < 0.02, "the sight glass reads half")
	_check(p.grade()["score"] > 0.98, "half the glass scores 1.0")
	# a partial stroke counts in proportion
	var q := HandPump.new(0.0)
	q.stroke(1.0, dt)
	for i in 60:
		q.stroke(1.0 - 0.4 * (i + 1) / 60.0, dt)
	_check(absf(q.litres - 0.1) < 0.002, "a 40%% stroke delivers 40%% (%.3f)" % q.litres)
	# rushing it slips
	var r := HandPump.new(0.0)
	var slipped := false
	for s in 8:
		r.stroke(1.0, dt)
		r.stroke(0.0, dt)
		slipped = slipped or r.slipping
	_check(slipped and r.litres < 8 * 0.25 * 0.7, "slamming the handle slips and loses oil (%.2f L)" % r.litres)
	# overfilling
	var o := HandPump.new(32.0, 30.0)
	_check(o.grade()["flags"].has(&"oil_overfilled"), "a full glass flags overfilling")


func _picker() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var door := VenueDoor.make(VenueDoor.Kind.SWING, 0.9, 2.1, Color.BROWN, "Plant room")
	root.add_child(door)
	door.position = Vector3(0, 0, -1.2)
	var bench := Node3D.new()
	root.add_child(bench)
	bench.position = Vector3(1.0, 0.9, -0.8)
	var far := Node3D.new()
	root.add_child(far)
	far.position = Vector3(0, 0, -6.0)
	var picker := InteractPicker.new()
	var all := [door, bench, far]
	_check(picker.pick(Vector3.ZERO, Vector3.FORWARD, null, all) == door, "facing the door picks the door")
	_check(picker.pick(Vector3.ZERO, Vector3(1, 0, -1), null, all) == bench, "facing the bench picks the bench")
	_check(picker.pick(Vector3.ZERO, Vector3.BACK, null, all) == null, "nothing behind you is picked")
	_check(picker.pick(Vector3(0, 0, -4.5), Vector3.FORWARD, null, all) == far, "the far one only once in reach")
	_check(InteractPicker.prompt_for(door) == "Open", "the door's prompt is Open")
	_check(InteractPicker.use(door) and door.is_open, "interact toggles a door open")
	_check(InteractPicker.prompt_for(door) == "Close", "then Close")
	root.queue_free()


## JobInput runs without the autoloads (job scene tests load it under --script).
func _input_layer() -> void:
	var ji := JobInput.new()
	get_root().add_child(ji)
	ji.scripted = func(f, _dt, ctx):
		f.grab = 1.0
		f.turn = 0.25 if ctx == JobInput.Context.BENCH else 0.0
	var f := ji.poll(1.0 / 120.0, JobInput.Context.BENCH)
	_check(f.grab_pressed and f.turn == 0.25, "a scripted frame comes through poll")
	ji.scripted = Callable()
	f = ji.poll(1.0 / 120.0, JobInput.Context.FOOT)
	_check(f.grab_released and f.turn == 0.0, "the devices poll without the autoloads")
	ji.queue_free()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		printerr("FAIL ", what)
		failures += 1


func _check_quiet(ok: bool, what: String) -> void:
	if not ok:
		_check(false, what)
