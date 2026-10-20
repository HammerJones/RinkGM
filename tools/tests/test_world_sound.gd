extends SceneTree
## World's sound hooks (WorldSound) and shadows, headless. With
## WorldSound.recording on nothing plays: each signal World's scenes emit
## must land a sound call in WorldSound.heard, the busy ones rate limited,
## the looping ones on one player each, and every sound must exist in
## assets/audio. Then World's meshes must cast shadows by Look.cast().
##
##   godot --headless --path . --script res://tools/tests/test_world_sound.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


## Emits through `fire` and expects the sound `name` (a loop when `loop`).
func _hears(what: String, fire: Callable, name: String, loop := false) -> void:
	WorldSound.reset()
	fire.call()
	var hit := WorldSound.heard.filter(func(h: Dictionary) -> bool:
		return str(h.sound) == name and (not loop or bool(h.get("loop", false))))
	_expect(not hit.is_empty(), "%s -> %s%s" % [what, name, " (loop)" if loop else ""])
	var file := name if ResourceLoader.exists(RinkSound.DIR + name + ".wav") else RinkSound.variant(name)
	_expect(ResourceLoader.exists(RinkSound.DIR + file + ".wav"), "  %s.wav exists" % file)


func _run() -> void:
	create_timer(120.0).timeout.connect(func():
		printerr("FAIL: test_world_sound timed out")
		quit(1))
	_expect(not RinkSound.enabled(), "headless runs play no sound")
	var off := OnIceSession.create("public_skate", {"seed": 5, "fast": true, "count": 4})
	_expect(off.get_node_or_null("WorldSound") == null, "no hooks attach while sound is off")
	off.free()
	WorldSound.recording = true
	var w := Node3D.new()
	root.add_child(w)

	# on the ice
	var s := OnIceSession.create("public_skate", {"seed": 5, "fast": true, "in_place": true, "count": 12, "hour": 14.0})
	s.auto_run = false
	w.add_child(s)
	var p := Vector3(4, 0, 2)
	_hears("blade_carve", func(): s.blade_carve.emit(p, 5.0), "blade_carve")
	_hears("stop_spray", func(): s.stop_spray.emit(p, 6.0), "stop_spray")
	for k in [["stick", "puck_stick"], ["boards", "puck_boards"], ["post", "puck_post"], ["pad", "puck_pad"], ["net", "puck_net"]]:
		_hears("puck_hit %s" % k[0], func(): s.puck_hit.emit(p, k[0], 20.0), k[1])
	_hears("whistle", func(): s.whistle.emit(p), "ref_whistle")
	_hears("coach_whistle", func(): s.coach_whistle.emit(p), "coach_whistle")
	_hears("crowd_reaction goal", func(): s.crowd_reaction.emit("goal", 1.0), "crowd_cheer")
	_hears("crowd_reaction applause", func(): s.crowd_reaction.emit("applause", 0.8), "crowd_applause")
	_hears("crowd_reaction ooh", func(): s.crowd_reaction.emit("ooh", 0.3), "crowd_ooh")
	_hears("skater_fell", func(): s.skater_fell.emit(p, "skater"), "body_fall")
	WorldSound.reset()
	for i in 30:
		s.blade_carve.emit(p, 5.0)
	var carves := WorldSound.heard.filter(func(h: Dictionary) -> bool: return h.sound == "blade_carve").size()
	_expect(carves == 1, "30 strides at once make one carve, not a wall of noise (%d)" % carves)
	WorldSound.reset()
	s.crowd_reaction.emit("goal", 1.0)
	s.crowd_reaction.emit("final", 1.0)
	_expect(WorldSound.heard.size() == 1, "one goal, one roar (%d)" % WorldSound.heard.size())
	s.run_for(3.0, 1.0 / 20.0)
	WorldSound.reset()
	s.run_for(3.0, 1.0 / 20.0)
	_expect(WorldSound.heard.any(func(h: Dictionary) -> bool: return h.sound == "blade_carve"), "a running public skate carves the ice")

	# pickup basketball
	var g := PickupRun.new()
	g.set_physics_process(false)
	w.add_child(g)
	_hears("bounced", func(): g.bounced.emit(p, 0.6), "ball_bounce")
	_hears("squeaked", func(): g.squeaked.emit(p, 0.6), "sneaker_squeak")
	_hears("swished", func(): g.swished.emit(p), "net_swish")
	_hears("rim_hit", func(): g.rim_hit.emit(p, 0.6), "rim_clang")
	_hears("backboard_hit", func(): g.backboard_hit.emit(p, 0.6), "backboard_bang")
	_hears("scored", func(): g.scored.emit(0, 2, [2, 0]), "voice_bark")
	_hears("PickupBall.hit (through the run)", func(): g.ball().hit.emit("floor", g.ball().global_position, 0.5), "ball_bounce")

	# people
	var people := RinkPeople.new()
	w.add_child(people)
	_hears("chatter", func(): people.chatter.emit(0.6), "hall_chatter", true)
	_hears("cheered", func(): people.cheered.emit(p, 0.8), "crowd_cheer")
	_hears("reacted gasp", func(): people.reacted.emit("gasp", p, 0.5), "crowd_gasp")
	_hears("barked", func(): people.barked.emit(null, "Hi.", p), "voice_bark")
	var ws: WorldSound = people.get_node("WorldSound")
	for i in 10:
		people.chatter.emit(0.1 * i)
	_expect(ws.loop_count() == 1, "chatter is one looping player (%d)" % ws.loop_count())

	# a stick knocked over
	var stick := StickProp.make(StickProps.variant("warlock", 1, false, "black"))
	w.add_child(stick)
	_hears("knocked", func(): stick.knocked.emit(null), "stick_clatter")

	# Doris
	var sim := RinkSim.create_m1()
	var d: DorisDrive = load("res://scenes/world/jobs/doris_drive.tscn").instantiate()
	d.set_physics_process(false)
	w.add_child(d)
	d.begin({"sim": sim, "job": "resurface", "target": "doris_drive"})
	_hears("engine", func(): d.engine.emit(1200.0), "zamboni_idle", true)
	_hears("blade_scrape", func(): d.blade_scrape.emit(0.8, false), "blade_scrape", true)
	_hears("blade_scrape skipping", func(): d.blade_scrape.emit(0.4, true), "blade_skip")
	_hears("flood_flow", func(): d.flood_flow.emit(2.0, "good"), "flood_water", true)
	_hears("wash_pump", func(): d.wash_pump.emit(true), "wash_pump", true)
	_hears("auger", func(): d.auger.emit(true), "auger_grind", true)
	_hears("bin_dump", func(): d.bin_dump.emit(), "bin_dump")
	_hears("hose", func(): d.hose.emit(true), "hose_fill", true)
	var dws: WorldSound = d.get_node("WorldSound")
	var before := dws.loop_count()
	for i in 40:
		d.engine.emit(850.0 + i * 40.0)
		d.flood_flow.emit(1.0 + i * 0.05, "good")
	_expect(dws.loop_count() == before, "engine and flood stay single loops however often they report (%d)" % dws.loop_count())
	_expect(d.body.get_node_or_null("ZamboniIdle") != null, "Doris's engine loop rides on her body")
	WorldSound.reset()
	d.auger.emit(false)
	_expect(WorldSound.heard.any(func(h: Dictionary) -> bool: return h.sound == "auger_grind" and not h.loop), "auger(false) stops the grind")

	# the ice hand
	var h: IceHand = load("res://scenes/world/jobs/ice_hand.tscn").instantiate()
	w.add_child(h)
	h.begin({"sim": sim, "job": "hose_flood", "target": "ice_hose"})
	_hears("ice hand hose", func(): h.hose.emit(true), "hose_spray", true)
	_hears("hose_flow", func(): h.hose_flow.emit(0.5), "hose_spray", true)
	_hears("edger", func(): h.edger.emit(true, 0.5), "edger_motor", true)
	_hears("chipper", func(): h.chipper.emit(1.0), "ice_chip")

	# shadows: World's meshes follow Look.cast()
	await process_frame
	await process_frame
	var want := Look.cast()
	var odd: Array = []
	_collect(s, want, odd)
	_expect(odd.is_empty() and s.find_children("*", "MultiMeshInstance3D", true, false).size() > 0,
			"on-ice figures and gear cast by Look.cast() %s" % [odd])
	_expect(g.ball()._mesh.cast_shadow == want, "the basketball casts by Look.cast()")
	var model: MeshInstance3D = d.body.get_child(0)
	_expect(model.cast_shadow == want, "Doris casts by Look.cast()")
	var field := StickField.new()
	w.add_child(field)
	_expect(field._mi.cast_shadow == want, "a room's resting sticks cast by Look.cast()")
	stick._show(true)
	_expect(stick._mi.cast_shadow == want, "an awake stick casts by Look.cast()")

	WorldSound.recording = false
	WorldSound.reset()
	w.queue_free()
	await process_frame
	await process_frame
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _collect(n: Node, want: int, odd: Array) -> void:
	if n is GeometryInstance3D and n.cast_shadow != want:
		odd.append(n.name)
	for c in n.get_children():
		_collect(c, want, odd)
