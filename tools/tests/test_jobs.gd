extends SceneTree
## The M1 mini games (docs/world/RINK_SIM.md 4.2, 4.7, the 4.8 plug slice):
## each scene played through JobInput.scripted by JobAutopilot, a perfect run
## and a sloppy one, plus a cancel. Checks the quality, the result args the
## venue hands to sim.job(), the flags, and that the parts' art builds within
## budget.
##   godot --headless --path . --script res://tools/tests/test_jobs.gd

const DT := 1.0 / 60.0
const MAX_TICKS := 30000
const SCENES := {
	"compressor_oil_change": "res://scenes/world/jobs/compressor_oil_service.tscn",
	"blade_change": "res://scenes/world/jobs/doris_blade.tscn",
	"doris_plugs": "res://scenes/world/jobs/doris_plugs.tscn",
	"doris_oil_change": "res://scenes/world/jobs/doris_oil.tscn",
	"doris_carb": "res://scenes/world/jobs/doris_carb.tscn",
}

var failures := 0


func _initialize() -> void:
	_check_art()
	_check_oil()
	_check_blade()
	_check_plugs()
	_check_doris_oil()
	_check_carb()
	for job in SCENES:
		_check_cancel(str(job))
	if failures:
		printerr("test_jobs: %d failure(s)" % failures)
	else:
		print("test_jobs: ok")
	quit(1 if failures else 0)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


## Plays `job` on `target` with the autopilot; returns the finished() result
## and the ticks it took.
func _play(job: String, target: String, sloppy: bool) -> Dictionary:
	var scene: JobScene = (load(SCENES[job]) as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var got := {"result": {}, "done": false, "count": 0}
	scene.finished.connect(func(r: Dictionary) -> void:
		got.result = r
		got.done = true
		got.count = int(got.count) + 1)
	scene.begin({"sim": null, "job": job, "target": target, "room": "plant_room"})
	var pilot := JobAutopilot.new(scene, sloppy)
	scene.input.scripted = pilot.drive
	var hud_ok := scene.hud.text().contains("// ") and scene.hud.text().contains("[>]")
	var ticks := 0
	while ticks < MAX_TICKS and not got.done:
		scene.tick(DT)
		ticks += 1
	var stuck := scene.step_id()
	scene.tick(DT)  # a closed scene ignores input: no second finished()
	scene.free()
	_expect(got.done, "%s %s never finished (stuck at '%s')" % [job, "sloppy" if sloppy else "perfect", stuck])
	_expect(int(got.count) <= 1, "%s emitted finished() %d times" % [job, got.count])
	_expect(hud_ok, "%s HUD should show the RinkOS checklist" % job)
	var r: Dictionary = got.result
	print("%s %s (%d ticks): %s" % [job, "sloppy " if sloppy else "perfect", ticks, r])
	return r


func _flags(r: Dictionary) -> Array:
	var f: Variant = r.get("flags", [])
	return f if f is Array else []


func _quality(r: Dictionary) -> float:
	return float(r.get("quality", -1.0))


# ---------------------------------------------------------------- the jobs

func _check_oil() -> void:
	var good := _play("compressor_oil_change", "comp2", false)
	_expect(_quality(good) > 0.85, "oil service: perfect quality %.2f should be > 0.85" % _quality(good))
	_expect(int(good.get("compressor", -1)) == 1, "oil service: target comp2 is compressor 1")
	_expect(absf(float(good.get("oil_level", 0.0)) - 0.5) < 0.03, "oil service: oil_level %.2f should be near 0.5" % float(good.get("oil_level", 0.0)))
	_expect(good.get("filter_ok", false) == true, "oil service: filter_ok on a perfect run")
	_expect(good.get("drain_plug_torque_ok", false) == true, "oil service: drain_plug_torque_ok on a perfect run")
	_expect(_flags(good).is_empty(), "oil service: a perfect run has no flags, got %s" % [_flags(good)])
	var bad := _play("compressor_oil_change", "comp1", true)
	_expect(_quality(bad) < _quality(good) - 0.2, "oil service: sloppy quality %.2f should be well under perfect %.2f" % [_quality(bad), _quality(good)])
	_expect(int(bad.get("compressor", -1)) == 0, "oil service: target comp1 is compressor 0")
	_expect("cross_threaded" in _flags(bad), "oil service: a wrench at the start cross-threads the filter")
	_expect("oil_overfilled" in _flags(bad), "oil service: over the mark flags oil_overfilled")
	_expect(float(bad.get("oil_level", 0.0)) > 0.75, "oil service: the overfilled glass reads high")
	_expect(bad.get("filter_ok", true) == false, "oil service: a crossed filter is not ok")
	_sim_job("compressor_oil_change", good)


func _check_blade() -> void:
	var good := _play("blade_change", "doris", false)
	var h := float(good.get("height_mm", -1.0))
	_expect(_quality(good) > 0.85, "blade: perfect quality %.2f should be > 0.85" % _quality(good))
	_expect(h >= 0.8 and h <= 1.2, "blade: height %.2f mm should be in 0.8..1.2" % h)
	_expect(good.get("bolts_ok", false) == true, "blade: bolts_ok on a perfect run")
	_expect(_flags(good).is_empty(), "blade: a perfect run has no flags, got %s" % [_flags(good)])
	var bad := _play("blade_change", "doris", true)
	_expect(_quality(bad) < _quality(good) - 0.2, "blade: sloppy quality %.2f should be well under perfect %.2f" % [_quality(bad), _quality(good)])
	_expect(float(bad.get("height_mm", 0.0)) > 1.2, "blade: the sloppy height is too deep")
	_expect("blade_too_deep" in _flags(bad), "blade: too deep is flagged")
	_expect("bolt_overtorqued" in _flags(bad), "blade: pulling past the click flags bolt_overtorqued")
	_expect(bad.get("bolts_ok", true) == false, "blade: overtorqued bolts are not ok")
	_sim_job("blade_change", good)


func _check_plugs() -> void:
	var good := _play("doris_plugs", "doris", false)
	_expect(_quality(good) > 0.85, "plugs: perfect quality %.2f should be > 0.85" % _quality(good))
	_expect(good.get("cross_threaded", true) == false, "plugs: started by hand, not cross-threaded")
	_expect(good.get("torque_ok", false) == true, "plugs: torque_ok on a perfect run")
	var bad := _play("doris_plugs", "doris", true)
	_expect(_quality(bad) < _quality(good) - 0.2, "plugs: sloppy quality %.2f should be well under perfect %.2f" % [_quality(bad), _quality(good)])
	_expect(bad.get("cross_threaded", false) == true, "plugs: a wrench at the start cross-threads it")
	_expect(bad.get("torque_ok", true) == false, "plugs: past the click is not torque_ok")
	_sim_job("doris_plugs", good)


func _check_doris_oil() -> void:
	var good := _play("doris_oil_change", "doris_oil", false)
	_expect(_quality(good) > 0.85, "doris oil: perfect quality %.2f should be > 0.85" % _quality(good))
	_expect(absf(float(good.get("oil_level", 0.0)) - 1.0) < 0.1, "doris oil: filled to the FULL line, got %.2f" % float(good.get("oil_level", 0.0)))
	_expect(good.get("filter_ok", false) == true and good.get("drain_plug_torque_ok", false) == true, "doris oil: filter and drain plug ok on a perfect run")
	_expect(_flags(good).is_empty(), "doris oil: a perfect run has no flags, got %s" % [_flags(good)])
	var bad := _play("doris_oil_change", "doris_oil", true)
	_expect(_quality(bad) < _quality(good) - 0.2, "doris oil: sloppy quality %.2f should be well under perfect %.2f" % [_quality(bad), _quality(good)])
	_expect("oil_over" in _flags(bad) and float(bad.get("oil_level", 0.0)) > 1.1, "doris oil: past the FULL line is flagged")
	_expect(bad.get("filter_ok", true) == false, "doris oil: a crossed filter is not ok")
	_sim_job("doris_oil_change", good)


func _check_carb() -> void:
	var good := _play("doris_carb", "doris_carb", false)
	_expect(_quality(good) > 0.85, "carb: perfect quality %.2f should be > 0.85" % _quality(good))
	_expect(float(good.get("jets_clean", 0.0)) > 0.99 and good.get("gasket_ok", false) == true and good.get("choke_freed", false) == true, "carb: clean jets, a new gasket, the choke free")
	_expect(_flags(good).is_empty(), "carb: a perfect run has no flags, got %s" % [_flags(good)])
	var bad := _play("doris_carb", "doris_carb", true)
	_expect(_quality(bad) < _quality(good) - 0.2, "carb: sloppy quality %.2f should be well under perfect %.2f" % [_quality(bad), _quality(good)])
	_expect("old_gasket" in _flags(bad) and "jets_varnished" in _flags(bad), "carb: the old gasket and half-clear jets are flagged")
	_expect("cross_threaded" in _flags(bad), "carb: a screwdriver at the start cross-threads a bowl screw")
	_sim_job("doris_carb", good)


## Back before the job is done: finished({cancelled: true}), once.
func _check_cancel(job: String) -> void:
	var scene: JobScene = (load(SCENES[job]) as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var got := {"result": {}, "count": 0}
	scene.finished.connect(func(r: Dictionary) -> void:
		got.result = r
		got.count = int(got.count) + 1)
	scene.begin({"sim": null, "job": job, "target": "comp1", "room": ""})
	var pilot := JobAutopilot.new(scene, false)
	var n := {"t": 0}
	scene.input.scripted = func(f: JobInput.Frame, dt: float, c: int) -> void:
		n.t = int(n.t) + 1
		if int(n.t) == 40:
			f.back_pressed = true
		else:
			pilot.drive(f, dt, c)
	for i in 60:
		scene.tick(DT)
	scene.free()
	var r: Dictionary = got.result
	_expect(int(got.count) == 1, "%s: cancel should emit finished once, got %d" % [job, got.count])
	_expect(r.get("cancelled", false) == true and r.size() == 1, "%s: cancel should emit {cancelled: true}, got %s" % [job, r])


## Runs the result through the sim when it knows the job.
func _sim_job(job: String, r: Dictionary) -> void:
	if not RinkSim.JOBS.has(job):
		print("sim.job('%s'): not in RinkSim.JOBS yet, skipped" % job)
		return
	var sim := RinkSim.create()
	var out := sim.job(job, r)
	_expect(out.get("ok", false) == true, "sim.job('%s') should be ok, got %s" % [job, out])
	print("sim.job('%s'): %s" % [job, out])


# ---------------------------------------------------------------- art

func _check_art() -> void:
	var line := PackedStringArray()
	for id in JobParts.ids():
		var m := JobParts.mesh(str(id))
		if m == null or m.get_surface_count() == 0:
			_fail("JobParts '%s' built no mesh" % id)
			continue
		var tris := m.surface_get_array_len(0) / 3
		var idx := m.surface_get_array_index_len(0)
		if idx > 0:
			tris = idx / 3
		line.append("%s %d" % [id, tris])
		_expect(tris < 8000, "JobParts '%s' has %d triangles (budget 8000)" % [id, tris])
	var cs := JobParts.compressor_service()
	_expect(cs != null and cs.get_surface_count() > 0, "the opened-up compressor builds")
	print("job parts triangles: " + ", ".join(line))
