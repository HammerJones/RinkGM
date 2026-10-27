extends SceneTree
## Playtest W2: Doris's repairs play in the resurfacer bay, in place, through
## the service hatch on her right side. No teleport: the job's parts sit in
## her motor bay, its own room hides, the camera leans in from the walker's
## eye, and the hatch shuts again when the job's done. All three hatch jobs:
## the plug change, the oil and filter, the carb clean; and the hatch offers
## whichever is due.
##   godot --headless --path . --script res://tools/tests/test_doris_hatch.gd

const DT := 1.0 / 30.0
const MAX_TICKS := 20000
## job id, scene, the part that must sit in her motor bay (a method or a
## point in the bay's space), the result keys the sim reads.
const JOBS := [
	["doris_plugs", "res://scenes/world/jobs/doris_plugs.tscn", ["torque_ok", "cross_threaded"]],
	["doris_oil_change", "res://scenes/world/jobs/doris_oil.tscn", ["oil_level", "filter_ok", "drain_plug_torque_ok"]],
	["doris_carb", "res://scenes/world/jobs/doris_carb.tscn", ["jets_clean", "bowl_clean", "gasket_ok", "choke_freed"]],
]

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
	for spec in JOBS:
		_play(d, place, eye, str(spec[0]), str(spec[1]), spec[2])
	d.free()
	_check_due()
	print("test_doris_hatch: %d ms" % (Time.get_ticks_msec() - t0))
	if _fails == 0:
		print("test_doris_hatch: ok")
	quit(1 if _fails > 0 else 0)


func _play(d: DorisModel, place: Transform3D, eye: Transform3D, job: String, path: String, keys: Array) -> void:
	print("-- ", job)
	var scene: JobScene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var got := {"done": false, "result": {}}
	scene.finished.connect(func(r: Dictionary) -> void:
		got.done = true
		got.result = r)
	scene.begin({"sim": null, "job": job, "target": job, "room": "zamboni_bay",
		"place": place, "host": d, "eye": eye})
	_expect(scene.in_place and scene.global_transform.is_equal_approx(place), "the job plays where Doris is parked")
	_expect(not scene.backdrop.is_empty() and scene.backdrop.all(func(n: Node3D) -> bool: return not n.visible), "the diorama's own room is hidden (%d nodes)" % scene.backdrop.size())
	_expect(d.hatch_want and not d.bay_parts.visible, "the hatch opens and her bay makes way for the job's parts")
	for i in 30:
		d._process(DT)
	_expect(is_equal_approx(d.hatch_open, 1.0), "the hatch swings fully up (%.2f)" % d.hatch_open)
	# the job's parts sit inside her motor bay, behind the hatch
	var inv := d.global_transform.affine_inverse()
	var pts: Array = []
	match job:
		"doris_plugs":
			pts = [scene.call("_well", 2)]
		"doris_oil_change":
			pts = [DorisHatchJob.bay(JobParts.DRAIN_AT), DorisHatchJob.bay(JobParts.FILTER_AT), DorisHatchJob.bay(JobParts.DIPSTICK_AT)]
		"doris_carb":
			pts = [DorisHatchJob.bay(JobParts.CARB_AT), DorisHatchJob.bay(JobParts.CARB_AT + JobParts.CARB_BOWL)]
	var x0 := (23 - DorisModel.PX) * DorisModel.V
	var x1 := (30 - DorisModel.PX) * DorisModel.V
	for p in pts:
		var at: Vector3 = inv * scene.to_global(p)
		_expect(at.x > x0 and at.x < x1 and at.y > DorisModel.HATCH_Y0 and at.y < DorisModel.HATCH_Y1
			and at.z > DorisModel.HATCH_Z0 and at.z < DorisModel.HATCH_Z1, "the job's part is in Doris's motor bay (%s)" % at)
	var note: Label3D = scene.get("_note")
	var n_at: Vector3 = inv * note.global_position
	_expect(absf(n_at.x - (30 - DorisModel.PX) * DorisModel.V) < 0.05 and note.visible, "Gus's note is taped on her side by the hatch (%s)" % n_at)
	if job != "doris_plugs":
		var lit := scene.find_children("*", "MeshInstance3D", true, false).all(func(m: Node) -> bool: return (m as MeshInstance3D).cast_shadow == Look.cast())
		_expect(lit, "every mesh the job builds casts by Look.cast()")
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
	var r: Dictionary = got.result
	_expect(got.done and float(r.get("quality", 0.0)) > 0.8, "%s plays through in place (%d ticks, %s)" % [job, n, r])
	for k in keys:
		_expect(r.has(k), "the result carries %s for the sim" % k)
	_expect(not d.hatch_want and d.bay_parts.visible, "the hatch shuts when the job's done")
	# and the sim takes it
	var sim := RinkSim.create()
	var out := sim.job(job, r)
	_expect(out.get("ok", false), "sim.job('%s') takes the result: %s" % [job, out])
	scene.free()


## The hatch offers whichever job is due: the plugs while she won't start on
## them, then the most worn of the plugs, the oil and the carb.
func _check_due() -> void:
	print("-- the hatch's job")
	var w := WalkStory.new()
	w.sim = RinkSim.create_m1()
	var spot := {"job": "doris_plugs", "target": "doris_plugs", "needs": "spark_plugs", "in_place": "doris_hatch",
		"jobs": [{"job": "doris_oil_change", "target": "doris_oil", "scene": "oil"}, {"job": "doris_carb", "target": "doris_carb", "scene": "carb"}]}
	_expect(w.hatch_job(spot).job == "doris_plugs", "the first morning: the plugs")
	w.sim.job("doris_plugs", {"quality": 1.0})
	w.sim.doris.engine_oil = 0.4
	w.sim.doris.carb = 0.7
	var a := w.hatch_job(spot)
	_expect(a.job == "doris_oil_change" and a.in_place == "doris_hatch" and not a.has("needs"), "black oil: the oil change, in place (%s)" % a)
	w.sim.job("doris_oil_change", {"quality": 1.0, "oil_level": 1.0})
	_expect(w.sim.doris.engine_oil > 0.95, "fresh oil in the sim (%.2f)" % w.sim.doris.engine_oil)
	_expect(w.hatch_job(spot).job == "doris_carb", "then the carb")
	w.sim.job("doris_carb", {"quality": 1.0})
	_expect(w.sim.doris.carb > 0.95, "a clean carb in the sim (%.2f)" % w.sim.doris.carb)


func _expect(ok: bool, msg: String) -> void:
	if ok:
		print("  ok  ", msg)
	else:
		_fails += 1
		print("FAIL: ", msg)
