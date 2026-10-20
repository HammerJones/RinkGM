extends SceneTree
## Playtest W2: Doris's repair plays in the resurfacer bay, in place, through
## the service hatch on her right side. No teleport: the job's parts sit in
## her motor bay, its own room hides, the camera leans in from the walker's
## eye, and the hatch shuts again when the job's done.
##   godot --headless --path . --script res://tools/tests/test_doris_hatch.gd

const DT := 1.0 / 30.0
const MAX_TICKS := 20000

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var d := DorisModel.new(Wear.WORN)
	d.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(39.7, 0, 0))
	root.add_child(d)
	var place := d.global_transform * DorisModel.hatch_frame()
	var stand := d.global_transform * DorisModel.hatch_stand()
	var eye := Transform3D.IDENTITY.looking_at(Vector3(0, 0.8, 0) - (stand + Vector3(0, 1.65, 0)), Vector3.UP)
	eye.origin = stand + Vector3(0, 1.65, 0)
	_expect(eye.origin.distance_to(place.origin) < 2.5, "the walker stands at the hatch, not somewhere else (%.2f m)" % eye.origin.distance_to(place.origin))

	var scene: JobScene = (load("res://scenes/world/jobs/doris_plugs.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var got := {"done": false, "result": {}}
	scene.finished.connect(func(r: Dictionary) -> void:
		got.done = true
		got.result = r)
	scene.begin({"sim": null, "job": "doris_plugs", "target": "doris_plugs", "room": "zamboni_bay",
		"place": place, "host": d, "eye": eye})
	_expect(scene.in_place and scene.global_transform.is_equal_approx(place), "the job plays where Doris is parked")
	_expect(not scene.backdrop.is_empty() and scene.backdrop.all(func(n: Node3D) -> bool: return not n.visible), "the diorama's own room is hidden (%d nodes)" % scene.backdrop.size())
	_expect(d.hatch_want and not d.bay_parts.visible, "the hatch opens and her bay makes way for the job's parts")
	for i in 30:
		d._process(DT)
	_expect(is_equal_approx(d.hatch_open, 1.0), "the hatch swings fully up (%.2f)" % d.hatch_open)
	# the job's parts sit inside her motor bay, behind the hatch
	var inv := d.global_transform.affine_inverse()
	var well: Vector3 = inv * scene.to_global(scene.call("_well", 2))
	var x0 := (23 - DorisModel.PX) * DorisModel.V
	var x1 := (30 - DorisModel.PX) * DorisModel.V
	_expect(well.x > x0 and well.x < x1 and well.y > DorisModel.HATCH_Y0 and well.y < DorisModel.HATCH_Y1
		and well.z > DorisModel.HATCH_Z0 and well.z < DorisModel.HATCH_Z1, "the plug wells are in Doris's motor bay (%s)" % well)
	var note: Label3D = scene.get("_note")
	var n_at: Vector3 = inv * note.global_position
	_expect(absf(n_at.x - (30 - DorisModel.PX) * DorisModel.V) < 0.05 and note.visible, "Gus's note is taped on her side by the hatch (%s)" % n_at)
	# the camera leans in from the walker's eye: no cut
	scene.input.scripted = func(_f: JobInput.Frame, _dt: float, _c: int) -> void: pass
	scene.tick(DT)
	var c0 := scene.cam.global_position
	_expect(c0.distance_to(eye.origin) < 0.4, "the camera starts at the walker's eye (%.2f m off)" % c0.distance_to(eye.origin))
	for i in 45:
		scene.tick(DT)
	var target: Vector3 = scene.to_global(scene.get("_eye"))
	_expect(scene.cam.global_position.distance_to(target) < c0.distance_to(target) * 0.3, "and eases in to the hatch view")
	# play it through; the hatch shuts after
	var pilot := JobAutopilot.new(scene, false)
	scene.input.scripted = pilot.drive
	var n := 0
	while n < MAX_TICKS and not got.done:
		scene.tick(DT)
		n += 1
	_expect(got.done and float((got.result as Dictionary).get("quality", 0.0)) > 0.8, "the plug change plays through in place (%d ticks, %s)" % [n, got.result])
	_expect(not d.hatch_want and d.bay_parts.visible, "the hatch shuts when the job's done")
	scene.free()
	d.free()
	print("test_doris_hatch: %d ms" % (Time.get_ticks_msec() - t0))
	if _fails == 0:
		print("test_doris_hatch: ok")
	quit(1 if _fails > 0 else 0)


func _expect(ok: bool, msg: String) -> void:
	if ok:
		print("  ok  ", msg)
	else:
		_fails += 1
		print("FAIL: ", msg)
