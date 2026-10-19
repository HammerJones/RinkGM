extends SceneTree
## The ice simulation and the driven resurface (docs/world/ICE.md): IceSlab v2
## cutting, flooding and freezing cell by cell, ResurfaceRun driven round the
## standard pattern by ResurfaceAutopilot (normal, dry and flood-only cuts, a
## blade set too deep, a tank that runs dry), the old IceSlab API and old
## saves, the caliper and survey arithmetic, and the RinkSim jobs.
##   godot --headless --path . --script res://tools/tests/test_ice.gd

const DT := 1.0 / 20.0

var failures := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_check_old_api()
	_check_old_save()
	_check_freeze()
	_check_water_spreads()
	_check_hot_water()
	_check_wear()
	_check_gauges()
	var worn := _worn()
	var normal := _drive(worn, ResurfaceAutopilot.NORMAL)
	_check_normal(normal)
	_check_dry(_drive(worn, ResurfaceAutopilot.DRY))
	_check_flood(_drive(worn, ResurfaceAutopilot.FLOOD))
	_check_deep(worn)
	_check_empty_tank(worn)
	_check_sim_jobs(normal)
	_check_drive_scene()
	_check_measure_scene()
	_check_hand_tools()
	print("test_ice: %d ms" % (Time.get_ticks_msec() - t0))
	if failures:
		printerr("test_ice: %d failure(s)" % failures)
	else:
		print("test_ice: ok")
	quit(1 if failures else 0)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


## Millbrook after an evening's skating.
func _worn() -> IceSlab:
	var ice := IceSlab.create_millbrook()
	ice.surface_temp = -5.0
	ice.wear_sessions(3.0, 20.0)
	return ice


## One autopilot run on a copy of `ice`: {"run", "ap", "r" (the result)}.
func _drive(ice: IceSlab, preset: Dictionary, doris: ResurfacerSim = null, fill := true, max_s := 1500.0) -> Dictionary:
	var d := doris if doris else ResurfacerSim.create_doris()
	var run := ResurfaceRun.start(ice, d)
	var ap := ResurfaceAutopilot.new(run, preset)
	ap.fill_first = fill
	var ev := PackedStringArray()
	var bin_max := 0.0
	while not ap.done and run.time_s < max_s:
		ap.tick(DT)
		ev.append_array(run.drain_events())
		bin_max = maxf(bin_max, run.bin_fill())
	var r := run.result()
	print("  %-6s %4.0f s, cov %.2f, wet %.2f, even %.2f, %+.2f mm, gouge %.2f -> %.2f, q %.2f, jams %d, hits %d, snow %.2f m3, water %.0f L"
		% [str(preset.kind), run.time_s, r.coverage, r.flood_coverage, r.evenness, r.thickness_change_mm, r.gouge_before_mm,
		r.gouge_after_mm, r.quality, r.jams, r.board_hits, r.snow_m3, r.water_l])
	return {"run": run, "ap": ap, "r": r, "events": ev, "bin_max": bin_max}


func _check_old_api() -> void:
	var ice := IceSlab.new()
	_expect(absf(ice.thickness_mm - 48.0) < 0.5, "old API: a new slab is about 48 mm (%.2f)" % ice.thickness_mm)
	ice.thickness_mm = 40.0
	_expect(absf(ice.thickness_mm - 40.0) < 0.01, "old API: thickness_mm sets the sheet (%.2f)" % ice.thickness_mm)
	ice.smoothness = 0.5
	_expect(absf(ice.smoothness - 0.5) < 0.02, "old API: smoothness sets the sheet (%.3f)" % ice.smoothness)
	var before := ice.thickness_mm
	ice.resurface(1.0, 0.4, 450.0)
	_expect(ice.smoothness > 0.8, "old API: resurface smooths (%.2f)" % ice.smoothness)
	_expect(absf(ice.thickness_mm - before) < 0.6, "old API: resurface keeps the thickness about level (%+.2f)" % (ice.thickness_mm - before))
	_expect(ice.wetness() > 0.0, "old API: a fresh flood is wet")
	ice.run(0.5, 120.0, 260.0, 0.0)
	_expect(ice.wetness() < 0.05, "old API: half an hour of the plant freezes it in (%.2f)" % ice.wetness())
	var cl := ice.cell(10, 4)
	_expect(cl.has("thickness_mm") and cl.has("smoothness"), "old API: cell() keeps its keys")
	_expect(ice.rating("hockey") > 0.0, "old API: rating()")
	_expect(ice.grid_text().length() > 50, "old API: grid_text()")


func _check_old_save() -> void:
	# a version 1 save: the coarse grid and the sheet values only
	var thick: Array = []
	var smooth: Array = []
	for x in IceSlab.W:
		for z in IceSlab.D:
			thick.append(30.0 + x)
			smooth.append(0.6)
	var v1 := {"surface_temp": -4.5, "cleanliness": 0.7, "paint": 0.5, "snow": 0.2, "pending_heat_mj": 0.0,
		"thick": thick, "smooth": smooth}
	var ice := IceSlab.new()
	ice.load_dict(v1)
	_expect(absf(float(ice.cell(3, 4).thickness_mm) - 33.0) < 0.6, "old save: coarse thickness comes back (%.2f)" % float(ice.cell(3, 4).thickness_mm))
	_expect(absf(ice.smoothness - 0.6) < 0.08, "old save: smoothness comes back (%.3f)" % ice.smoothness)
	_expect(absf(ice.surface_temp + 4.5) < 0.001, "old save: surface temperature")
	var d2 := ice.to_dict()
	_expect(int(d2.version) == IceSlab.VERSION and d2.has("fine") and d2.has("thick"), "save: v2 keeps the old keys and adds the fine grid")
	var back := IceSlab.new()
	back.load_dict(JSON.parse_string(JSON.stringify(d2)))
	_expect(absf(back.thickness_mm - ice.thickness_mm) < 1e-4, "save: v2 thickness round-trips through JSON")
	_expect(absf(back.smoothness - ice.smoothness) < 0.01, "save: v2 smoothness round-trips")
	var mb := IceSlab.create_millbrook()
	mb.plates.append("away_left")
	var mb2 := IceSlab.new()
	mb2.load_dict(JSON.parse_string(JSON.stringify(mb.to_dict())))
	_expect(absf(mb2.plate_depth_mm("centre") - mb.plate_depth_mm("centre")) < 0.01, "save: the fine grid comes back cell by cell")
	_expect("away_left" in mb2.plates, "save: the plates come back")
	var sim := RinkSim.create_m1()
	sim.ice.load_dict(v1)
	_expect(absf(sim.ice.thickness_mm - 39.5) < 0.6, "old save: a RinkSim loads a v1 ice (%.2f)" % sim.ice.thickness_mm)


## A 1/32 in flood at 60 C on -5 C ice freezes in about the time the pros
## wait before skaters go on (10 to 20 minutes, docs/world/ICE.md 1.4).
func _check_freeze() -> void:
	var ice := IceSlab.new()
	ice.surface_temp = -5.0
	for fz in range(40, 64):
		for fx in range(100, 140):
			ice.add_water(fz * IceSlab.FW + fx, 0.8, 60.0)
	var i := 52 * IceSlab.FW + 120
	_expect(ice.liquid_at(i) > 0.7, "freeze: the water is liquid when laid")
	_expect("wet" in ice.states(), "states: a fresh flood reads wet (%s)" % ", ".join(ice.states()))
	_expect(ice.frozen_at(i) < 0.05, "freeze: not frozen when laid")
	var t := 0.0
	while ice.frozen_at(i) < 0.95 and t < 3600.0:
		ice.freeze(30.0)
		t += 30.0
	print("  freeze: 0.8 mm at 60 C on -5 C ice is frozen in after %.1f min" % (t / 60.0))
	_expect(t >= 6.0 * 60.0 and t <= 25.0 * 60.0, "freeze: a flood freezes in over realistic minutes (%.1f)" % (t / 60.0))
	# cold water has less heat to lose; warm ice freezes slower
	var cold := IceSlab.new()
	cold.surface_temp = -5.0
	cold.add_water(i, 0.8, 15.0)
	var warm := IceSlab.new()
	warm.surface_temp = -2.0
	warm.add_water(i, 0.8, 60.0)
	var hot := IceSlab.new()
	hot.surface_temp = -5.0
	hot.add_water(i, 0.8, 60.0)
	for k in 10:
		cold.freeze(30.0)
		warm.freeze(30.0)
		hot.freeze(30.0)
	_expect(cold.frozen_at(i) > hot.frozen_at(i), "freeze: cold water freezes faster than hot")
	_expect(warm.frozen_at(i) < hot.frozen_at(i), "freeze: warm ice freezes slower")


## Water runs off the high spots and pools in the dish.
func _check_water_spreads() -> void:
	var ice := IceSlab.create_millbrook()
	var hi := IceSlab.cell_at(Vector2(0.0, 0.0))
	var spot := Vector2(-27.0, 0.0)  # near the home boards: the bowl's lip slopes in
	var j := IceSlab.cell_at(spot)
	ice.add_water(j, 3.0, 60.0)
	var before := ice.liquid_at(j)
	ice.settle(8)
	_expect(ice.liquid_at(j) < before, "water: a puddle spreads (%.2f -> %.2f mm)" % [before, ice.liquid_at(j)])
	_expect(hi != j, "water: sanity")
	_expect("bowled" in IceSlab.create_millbrook().states(), "states: Millbrook is bowled")


## Hot water bonds better and costs more gas.
func _check_hot_water() -> void:
	var cold := ResurfacerSim.heat_cost(1100.0, 15.0)
	var hot := ResurfacerSim.heat_cost(1100.0, 60.0)
	_expect(hot > cold * 5.0, "hot water: costs more to heat ($%.2f vs $%.2f)" % [hot, cold])
	_expect(absf(hot - RinkSim.FLOOD_GAS) < 0.25, "hot water: a full tank at 60 C costs about the flood's gas ($%.2f)" % hot)
	var a := _worn()
	var b := _worn()
	a.resurface(0.9, 0.4, 450.0, PackedFloat64Array(), 0.0, false, 60.0)
	b.resurface(0.9, 0.4, 450.0, PackedFloat64Array(), 0.0, false, 15.0)
	_expect(a.felt_smoothness() > b.felt_smoothness(), "hot water: bonds smoother (%.3f vs %.3f)" % [a.felt_smoothness(), b.felt_smoothness()])


func _check_wear() -> void:
	var ice := IceSlab.new()
	ice.smoothness = 1.0
	var p := Vector2(-26.0, 0.0)
	var i := IceSlab.cell_at(p)
	var g0 := ice.g[i]
	ice.wear(p, 0.5)
	ice.flush()
	_expect(ice.g[i] > g0 + 0.3, "wear: a crease's worth of skating gouges the spot (%.2f mm)" % ice.g[i])
	var far := IceSlab.cell_at(Vector2(10.0, 8.0))
	_expect(ice.g[far] < 0.05, "wear: the far ice is untouched")
	var s := IceSlab.new()
	s.smoothness = 1.0
	s.wear_sessions(2.0, 20.0)
	_expect(s.smoothness < 0.9 and s.snow > 0.0, "wear: sessions rough the sheet and throw snow (%.2f, %.2f)" % [s.smoothness, s.snow])


func _check_gauges() -> void:
	var c := IceGauges.caliper(31.76)
	_expect(is_equal_approx(float(c.beam), 31.0), "caliper: beam line 31 (%s)" % c.beam)
	_expect(absf(float(c.dial) - 38.0) < 0.01, "caliper: dial at 38 of 50 (%.2f)" % float(c.dial))
	_expect(str(c.text) == "31.76 mm", "caliper: reads 31.76 mm (%s)" % c.text)
	_expect(absf(float(c.needle) - 0.76 * TAU) < 1e-4, "caliper: needle three quarters round")
	_expect(absf(IceGauges.caliper_mm(31.0, 38.0) - 31.76) < 1e-6, "caliper: read back")
	var ci := IceGauges.caliper(31.75, false)  # 1.25 in exactly
	_expect(absf(float(ci.beam) - 1.2) < 1e-6 and absf(float(ci.dial) - 50.0) < 0.01, "caliper: imperial 1.2 on the beam, 50 on the dial (%s, %.2f)" % [ci.beam, float(ci.dial)])
	_expect(str(ci.text) == "1.250 in", "caliper: imperial reads 1.250 in (%s)" % ci.text)
	_expect(absf(IceGauges.caliper_mm(1.2, 50.0, false) - 31.75) < 1e-6, "caliper: imperial read back")
	var odd := IceGauges.caliper(12.013)
	_expect(str(odd.text) == "12.02 mm" or str(odd.text) == "12.00 mm", "caliper: rounds to the 0.02 graduation (%s)" % odd.text)
	var ro := IceGauges.rod(1263.4)
	_expect(int(ro.cm) == 126 and int(ro.mm) == 3, "rod: 126 cm and 3 mm (%s)" % ro.text)
	var ice := IceSlab.create_millbrook()
	var at_c := ice.rod_reading_mm(Vector2.ZERO)
	var at_b := ice.rod_reading_mm(Vector2(-28.5, 0.0))
	var true_rise := (ice.level_at(IceSlab.cell_at(Vector2(-28.5, 0.0))) - ice.level_at(IceSlab.cell_at(Vector2.ZERO)))
	_expect(absf(IceGauges.rise_mm(at_c, at_b) - true_rise) < 0.6, "survey: the rod finds the bowl's lip (%.1f vs %.1f mm)" % [IceGauges.rise_mm(at_c, at_b), true_rise])
	_expect(IceGauges.rise_mm(at_c, at_b) > 5.0, "survey: the home end sits higher than centre (%.1f)" % IceGauges.rise_mm(at_c, at_b))
	var depth := IceGauges.plate_depth(ice, "centre")
	_expect(absf(float(depth.value) - ice.plate_depth_mm("centre")) <= 0.011, "caliper: the plate depth (%s)" % depth.text)
	var scan := IceGauges.lidar(ice)
	_expect(float(scan.max) - float(scan.min) > 8.0, "lidar: the bowl shows (%.1f mm across)" % (float(scan.max) - float(scan.min)))


func _check_normal(d: Dictionary) -> void:
	var r: Dictionary = d.r
	var ap: ResurfaceAutopilot = d.ap
	_expect(ap.done and ap.phase == "done", "autopilot: drives the standard pattern to the end (%s)" % ap.phase)
	_expect(float(r.coverage) >= 0.92, "normal: covers the sheet (%.3f)" % float(r.coverage))
	_expect(float(r.gouge_after_mm) < float(r.gouge_before_mm) * 0.4, "normal: takes the gouges out (%.2f -> %.2f)" % [float(r.gouge_before_mm), float(r.gouge_after_mm)])
	_expect(absf(float(r.thickness_change_mm)) < 0.4, "normal: keeps the thickness about level (%+.2f)" % float(r.thickness_change_mm))
	_expect(not bool(r.jam) and int(r.board_hits) == 0, "normal: no jam, no boards")
	_expect(float(r.flood_l_left) < 60.0, "normal: 65%% empties the tank over the pattern (%.0f L left)" % float(r.flood_l_left))
	_expect(float(r.flood_l_left) > 0.0 or float(r.flood_coverage) > 0.95, "normal: the tank lasts the pattern (wet %.2f)" % float(r.flood_coverage))
	_expect(float(r.dumped_m3) > 0.5 and float(r.bin_m3) < 0.01, "normal: dumps the snow at the pit (%.2f m3)" % float(r.dumped_m3))
	_expect(float(r.quality) > 0.8 and bool(r.complete), "normal: a good, complete job (%.2f)" % float(r.quality))
	var mins := float(r.minutes)
	_expect(mins > 6.0 and mins < 16.0, "normal: takes the minutes a resurface takes (%.1f)" % mins)
	_expect(r.ice_state is IceSlab, "normal: hands the worked ice back")
	_expect(str(r.kind) == "normal", "normal: kind")
	var ice: IceSlab = r.ice_state
	_expect(ice.wetness() > 0.05, "normal: the ice is wet just after")


func _check_dry(d: Dictionary) -> void:
	var r: Dictionary = d.r
	_expect(str(r.kind) == "dry", "dry: kind (%s)" % r.kind)
	_expect(float(r.thickness_change_mm) < -0.3, "dry: lowers the sheet (%+.2f)" % float(r.thickness_change_mm))
	_expect(float(r.water_l) < 1.0, "dry: no water")


func _check_flood(d: Dictionary) -> void:
	var r: Dictionary = d.r
	_expect(str(r.kind) == "flood", "flood: kind (%s)" % r.kind)
	var dt := float(r.thickness_change_mm)
	_expect(dt > 0.55 and dt < 0.95, "flood: a full tank raises the sheet about 1/32 in (%+.2f mm)" % dt)


## A blade wound down too far: the snow comes faster than a tank holds, the
## bin packs solid and the augers jam.
func _check_deep(worn: IceSlab) -> void:
	var deep := ResurfaceAutopilot.NORMAL.duplicate()
	deep.kind = "deep"
	deep.blade_mm = ResurfacerSim.BLADE_MAX_MM
	var d := _drive(worn, deep)
	var r: Dictionary = d.r
	var ev: PackedStringArray = d.events
	_expect(bool(r.jam), "deep blade: the augers jam")
	_expect(float(d.bin_max) > 0.9, "deep blade: the bin all but overfills (%.2f, %s)" % [float(d.bin_max), ", ".join(ev)])
	_expect(not bool(r.complete), "deep blade: not a complete job")
	_expect(float(r.thickness_change_mm) < -0.2, "deep blade: takes the sheet down (%+.2f)" % float(r.thickness_change_mm))
	# a tank not dumped last time: it packs solid and the driver has to go and dump
	var full := ResurfaceRun.start(worn, ResurfacerSim.create_doris())
	full.bin_m3 = ResurfacerSim.SNOW_TANK_M3 * 0.8
	var ap := ResurfaceAutopilot.new(full, deep)
	var ev2 := PackedStringArray()
	while not ap.done and full.time_s < 1500.0:
		ap.tick(DT)
		ev2.append_array(full.drain_events())
	_expect("bin_full" in ev2, "full bin: it jams solid (%s)" % ", ".join(ev2))
	_expect(ap.gave_up and "dump_done" in ev2, "full bin: the driver gives up the cut and dumps")


## A tank a third full: it runs dry partway round and the rest is cut dry.
func _check_empty_tank(worn: IceSlab) -> void:
	var dor := ResurfacerSim.create_doris()
	dor.flood_l = 350.0
	dor.wash_l = ResurfacerSim.WASH_TANK_L
	var d := _drive(worn, ResurfaceAutopilot.NORMAL, dor, false)
	var r: Dictionary = d.r
	_expect("flood_empty" in (d.events as PackedStringArray), "empty tank: runs dry")
	_expect(float(r.flood_coverage) < 0.6, "empty tank: much of the cut got no water (%.2f)" % float(r.flood_coverage))
	_expect(not bool(r.complete), "empty tank: an incomplete cut")
	_expect(float(r.quality) < 0.85, "empty tank: a worse job (%.2f)" % float(r.quality))


## The drive scene on autopilot: its sound hooks fire, and what it hands
## the venue goes through RinkSim.job("resurface").
func _check_drive_scene() -> void:
	var sim := RinkSim.create_m1()
	sim.doris.part("spark_plugs").condition = 1.0
	sim.doris.choke_stuck = false
	var scene: DorisDrive = load("res://scenes/world/jobs/doris_drive.tscn").instantiate()
	scene.set_physics_process(false)
	root.add_child(scene)
	var heard := {}
	for sig in ["blade_scrape", "flood_flow", "wash_pump", "auger", "bin_dump", "engine", "hose"]:
		scene.connect(sig, func(_a: Variant = null, _b: Variant = null) -> void: heard[sig] = int(heard.get(sig, 0)) + 1)
	var got := {}
	scene.finished.connect(func(r: Dictionary) -> void: got.merge(r))
	scene.begin({"sim": sim, "job": "resurface", "target": "doris_drive", "autopilot": true})
	scene.input.scripted = func(f: JobInput.Frame, _dt: float, _c: int) -> void: f.interact_pressed = true
	var n := 0
	while not scene.closed and n < 30000:
		scene.tick(DT * 2.0)
		n += 1
	_expect(scene.closed and got.has("ice_state"), "drive scene: the autopilot finishes and hands back the ice (%d ticks)" % n)
	for sig in ["blade_scrape", "flood_flow", "wash_pump", "bin_dump", "engine", "hose"]:
		_expect(int(heard.get(sig, 0)) > 0, "drive scene: the %s hook fires" % sig)
	var r := sim.job("resurface", got)
	_expect(bool(r.ok) and sim.doris.cuts_driven == 1, "drive scene: the venue's job goes through (%s)" % r.get("text", ""))
	scene.free()
	# with a driver hired, Earl takes her out
	var s2 := RinkSim.create_m1()
	s2.earl_hired = true
	s2.doris.part("spark_plugs").condition = 1.0
	s2.doris.choke_stuck = false
	var sc2: DorisDrive = load("res://scenes/world/jobs/doris_drive.tscn").instantiate()
	sc2.set_physics_process(false)
	root.add_child(sc2)
	sc2.begin({"sim": s2, "job": "resurface", "target": "doris_drive"})
	_expect(sc2.complete and float(sc2.result.get("coverage", 0.0)) > 0.9, "drive scene: a hired driver's resurface is automatic")
	sc2.free()


## The measuring scene: a caliper reading at the centre plate, a plate ordered
## at an empty dot, survey readings off the laser, and the numbers into the sim.
func _check_measure_scene() -> void:
	var sim := RinkSim.create_m1()
	var sc: IceMeasure = load("res://scenes/world/jobs/ice_measure.tscn").instantiate()
	root.add_child(sc)
	var got := {}
	sc.finished.connect(func(r: Dictionary) -> void: got.merge(r))
	sc.begin({"sim": sim, "job": "ice_depth", "target": "ice_depth"})
	_expect(sc.mode == "depth", "measure: the depth kit opens on the plates")
	sc._take()
	var want := sim.ice.plate_depth_mm("centre")
	_expect(sc.showing and absf(float(sc.cur.value) - want) < 0.2, "measure: the caliper reads the centre plate (%.2f vs %.2f mm)" % [float(sc.cur.get("value", 0.0)), want])
	var cal := IceGauges.caliper(float(sc.cur.value))
	_expect(absf(IceGauges.caliper_mm(float(cal.beam), roundf(float(cal.dial)), true) - float(sc.cur.value)) <= 0.011, "measure: the beam and dial add back up")
	sc._write()
	_expect(sc.readings.has("centre") and sc._choices[sc.sel] == "home_left", "measure: written down, on to the next dot")
	var cash := sim.money
	sc._take()
	_expect(sim.plate_pending("home_left") and sim.money < cash, "measure: an empty dot orders a plate (%s)" % sc.prompt)
	sc.sel = sc._choices.size() - 1
	sc.input.scripted = func(f: JobInput.Frame, _dt: float, _c: int) -> void: f.interact_pressed = true
	var n := 0
	while not sc.closed and n < 20:
		sc.tick(DT)
		n += 1
	_expect(sc.closed and got.has("readings"), "measure: handed in")
	var r := sim.job("ice_depth", got)
	_expect(bool(r.ok) and (r.readings as Dictionary).has("centre"), "measure: the sim logs the caliper's numbers (%s)" % r.get("text", ""))
	sc.free()
	# the survey: centre first, then the rest go off it
	var sv: IceMeasure = load("res://scenes/world/jobs/ice_measure.tscn").instantiate()
	root.add_child(sv)
	sv.begin({"sim": sim, "job": "ice_survey", "target": "ice_survey"})
	for i in [7, 0, 4, 10, 14]:
		sv.sel = i
		sv._take()
		sv._write()
	var res := sv._result()
	_expect(sv.mode == "survey" and (res.readings as Dictionary).size() == 5 and (res.points as Array).size() == 5, "measure: five rod readings with their spots")
	var r2 := sim.job("ice_survey", res)
	_expect(bool(r2.ok) and (r2.readings as Dictionary).size() == 5, "measure: the survey goes in (%s)" % r2.get("text", ""))
	sv.free()


## The hand tools: the big hose lays hot water where it's pointed and the sim
## bills the gas, the edger takes the strip down and spits its snow on the
## ice, the chipper drags the ridge off the boards.
func _hand(sim: RinkSim, target: String, job: String) -> IceHand:
	var sc: IceHand = load("res://scenes/world/jobs/ice_hand.tscn").instantiate()
	root.add_child(sc)
	sc.begin({"sim": sim, "job": job, "target": target})
	return sc


func _check_hand_tools() -> void:
	var sim := RinkSim.create_m1()
	sim.ice.wear_sessions(6.0, 30.0)
	sim.ice.flush()
	# the hose
	var hz := _hand(sim, "ice_hose", "hose_flood")
	var heard := {}
	hz.hose.connect(func(on: bool) -> void: heard["hose"] = on)
	hz.hose_flow.connect(func(_r: float) -> void: heard["flow"] = true)
	_expect(hz.mode == "hose", "hand: the hose scene opens on the hose")
	hz.pos = Vector2(10.0, 3.0)
	var i := IceSlab.cell_at(hz.pos + Vector2(cos(hz.heading), sin(hz.heading)) * (0.9 + 2.2 * hz.flow))
	var t0 := hz.ice.t[i]
	hz._use()
	for k in 200:
		hz.step_work(0.05, Vector2.ZERO)
	var want := IceHand.HOSE_LPS * hz.flow * 10.0
	_expect(heard.get("hose", false) and heard.has("flow") and absf(hz.litres - want) < 0.5, "hand: the hose runs %.1f L in 10 s (%.1f expected), hooks fire" % [hz.litres, want])
	_expect(hz.ice.t[i] > t0 + 1.0 and hz.ice.liquid_at(i) > 0.0, "hand: the water stands where it's pointed (%.1f mm more)" % (hz.ice.t[i] - t0))
	_expect(hz.hose_out(Vector2(-29.0, 0.0)) > IceHand.HOSE_M, "hand: 61 m of hose doesn't reach the far end")
	_expect(is_equal_approx(sim.ice.t[i], t0), "hand: the sim's sheet is untouched till it's handed in")
	hz.input.scripted = func(f: JobInput.Frame, _dt: float, _c: int) -> void: f.back_pressed = true
	var got := {}
	hz.finished.connect(func(r: Dictionary) -> void: got.merge(r))
	hz.tick(DT)
	_expect(hz.complete and not heard.get("hose", true), "hand: X shuts the nozzle and finishes")
	var money := sim.money
	var r := sim.job("hose_flood", hz.result)
	_expect(bool(r.ok) and sim.money < money and sim.ice.t[i] > t0 + 1.0, "hand: the sim takes the flood and bills the hot water (%s)" % r.get("text", ""))
	hz.free()
	# the edger along the home end's side boards
	var ed := _hand(sim, "ice_edger", "edge_ice")
	var lip0 := ed.ice.edge_lip_mm()
	var snow0 := 0.0
	for j in IceSlab.FCELLS:
		snow0 += ed.ice.s[j]
	ed.pos = Vector2(20.0, -Rink.HALF_W + 0.9)
	ed._cy = 0.0  # camera behind, looking up the ice toward -x
	ed.depth_idx = 3
	ed._use()
	for k in 600:
		ed.step_work(0.05, Vector2(0.0, 1.0))
	var snow1 := 0.0
	for j in IceSlab.FCELLS:
		snow1 += ed.ice.s[j]
	_expect(ed.cut_l > 1.0 and ed.pos.x < 5.0, "hand: the edger walks the boards cutting (%.1f L, at x %.1f)" % [ed.cut_l, ed.pos.x])
	_expect(snow1 > snow0, "hand: the edger spits its snow on the ice")
	ed.ice.resync()
	_expect(ed.ice.edge_lip_mm() < lip0, "hand: the strip along the boards comes down (%.2f to %.2f mm)" % [lip0, ed.ice.edge_lip_mm()])
	ed.free()
	# the chipper
	var ch := _hand(sim, "ice_chipper", "chip_ice")
	var ridge0 := ch.ice.board_ridge_litres()
	var hits := [0]
	ch.chipper.connect(func(_m: float) -> void: hits[0] += 1)
	ch.pos = Vector2(15.0, Rink.HALF_W - 0.8)
	ch.heading = PI * 0.5
	for k in 10:
		ch.swing()
		ch.step_work(IceHand.CHIP_COOLDOWN, Vector2.ZERO)
		ch.pos.x -= 1.2
	_expect(hits[0] == 10 and ch.moved_l > 20.0 and ch.ice.board_ridge_litres() < ridge0 - 20.0, "hand: ten swings drag %.0f L of the ridge out" % ch.moved_l)
	var res := ch._result()
	var r3 := sim.job("chip_ice", res)
	_expect(bool(r3.ok) and sim.ice.board_ridge_litres() < ridge0 - 20.0, "hand: the sim takes the chipped boards (%s)" % r3.get("text", ""))
	ch.free()


func _check_sim_jobs(normal: Dictionary) -> void:
	var sim := RinkSim.create_m1()
	sim.doris.part("spark_plugs").condition = 1.0
	sim.doris.choke_stuck = false
	var r: Dictionary = normal.r.duplicate()
	var before_money := sim.money
	var out := sim.job("resurface", r)
	_expect(bool(out.ok), "sim: a driven resurface goes through (%s)" % out.text)
	_expect(absf(sim.ice.thickness_mm - (r.ice_state as IceSlab).thickness_mm) < 1e-3, "sim: adopts the driven ice")
	_expect(sim.money < before_money and sim.doris.cuts_driven == 1, "sim: gas charged, the cut counted")
	_expect(float(out.hours) > 0.1, "sim: the drive's minutes are the job's hours (%.2f)" % float(out.hours))
	# the owner's floods wait for the player in the walk
	var s2 := RinkSim.create_m1()
	s2.owner_drives = true
	s2.advance(60)
	_expect(not s2.flood_waiting().is_empty(), "sim: the 05:50 flood waits for the owner to drive")
	var s3 := RinkSim.create_m1()
	s3.owner_drives = true
	s3.earl_hired = true
	_expect(not s3.owner_waits(), "sim: with a driver hired, floods stay automatic")
	# a depth plate: a day closed, then it's in
	var s4 := RinkSim.create_m1()
	var pr := s4.job("install_plate", {"spot": "away_left"})
	_expect(bool(pr.ok), "plate: ordered (%s)" % pr.get("text", ""))
	_expect(s4.ice_closed(s4.day + 1), "plate: tomorrow's ice is closed")
	var cancelled := s4.cancelled_sessions
	s4.advance_days(2)
	_expect("away_left" in s4.ice.plates, "plate: frozen in after its day")
	_expect(s4.cancelled_sessions >= cancelled, "plate: the closed day's sessions are lost")
	var dr := s4.job("ice_depth")
	_expect(bool(dr.ok) and (dr.readings as Dictionary).has("away_left"), "plate: read at the new plate")
	var sv := s4.job("ice_survey", {"points": [[0.0, 0.0], [-28.0, 0.0]]})
	_expect(bool(sv.ok) and (sv.readings as Dictionary).size() == 2, "survey: two readings logged")
	_expect(SimInstrument.tiers("ice_level").size() == 3, "instrument: the ice_level tiers")
	s4.money = 200000.0
	_expect(s4.buy_tool("ice_level", 2) and s4.doris.auto_level, "instrument: the Level-Sense machine levels itself")
	var d1 := s4.to_dict()
	var s5 := RinkSim.from_dict(JSON.parse_string(JSON.stringify(d1)))
	_expect("away_left" in s5.ice.plates and s5.doris.auto_level and s5.owner_drives == s4.owner_drives, "save: the ice jobs' state round-trips")
