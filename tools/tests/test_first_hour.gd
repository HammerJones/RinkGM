extends SceneTree
## Headless check of the first hour at Millbrook (RINK_SIM.md 1.6) as the
## venue walk plays it: every M1 spot is in the building, the front doors stay
## locked until the envelope under the mat gives the keys, the walker gets
## from the dark lot into the lobby, the ice lights come on from the panel and
## warm up, Doris needs the plugs from her drawer before her job opens, jobs
## hand over to the sim, and the snow pit melts once its heater is reset.
##
##   godot --headless --path . --script tools/tests/test_first_hour.gd

const SPOTS := [
	"gus_envelope", "ice_lights", "dedication_plaque",
	"office_phone", "office_desk", "power_bill", "corkboard", "ice_grid",
	"door_of_notes", "screwdriver", "gus_binder", "pamphlet_ammonia", "compressor_1", "compressor_2", "oil_drum", "glycol_thermometer", "log_book", "nordale_manual",
	"doris", "doris_blade", "plug_drawer", "zambelli_525_manual", "snow_pit",
	"ice_check",
]

var failures := 0
var _venue: Venue


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
		printerr("FAIL: test_first_hour timed out")
		quit(1))
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(Rink.new())
	_venue = Venue.instantiate_for(Career.exhibition(0), true)
	world.add_child(_venue)
	var story := WalkStory.start(_venue)
	for id in SPOTS:
		_expect(_venue.spot(id) != null, "spot %s is in the building" % id)
	_expect(story.clock_text() == "MON 05:00", "it starts at %s" % story.clock_text())
	_expect(not _venue.ice_lights_on(), "the ice lights start off")
	for id in ["gus_envelope", "door_of_notes", "gus_binder", "doris_dash", "plug_drawer", "power_bill", "zambelli_525_manual", "nordale_manual", "pamphlet_ammonia", "dedication_plaque"]:
		_expect(str(story.text(id).get("text", "")).length() > 20, "%s has text to read" % id)

	# locked out until the keys come out from under the mat
	var front := _venue.door("Front doors")
	_expect(front != null and story.door_locked(front), "the front doors are locked at 05:00")
	var w := VenueWalker.new()
	world.add_child(w)
	w.global_position = Vector3(-51.0, 0.05, 0.4)
	for i in 10:
		await physics_frame
	var looked := w.nearest_spot(_venue, (_venue.spot("gus_envelope").global_position - (w.global_position + Vector3(0, 1.6, 0))).normalized())
	_expect(looked == null, "the envelope is out of reach from the lot")
	await _walk(w, [Vector3(-47.4, 0, 0.4)])
	looked = w.nearest_spot(_venue, (_venue.spot("gus_envelope").global_position - w.head.global_position).normalized())
	_expect(looked != null and looked.id == "gus_envelope", "standing on the mat, looking down, you see the envelope (%s)" % (looked.id if looked else "-"))
	var a := story.use(_venue.spot("gus_envelope"))
	_expect(a.has("read") and story.flags.has("keys") and not story.door_locked(front), "reading the envelope gives the keys and unlocks the front doors")
	front.open()
	for i in 60:
		await physics_frame
	var at := await _walk(w, [Vector3(-44.0, 0, 0.4)])
	var room := _venue.room_at(at + Vector3(0, 0.5, 0))
	_expect(room != null and room.room_id == "lobby", "in through the front doors to the lobby (%s)" % (room.room_id if room else "-"))

	# the lighting panel
	a = story.use(_venue.spot("ice_lights"))
	_expect(_venue.ice_lights_on() and a.has("toast"), "the panel turns the ice lights on")
	var lights = _venue.rooms["lighting"]
	for i in 30:
		await process_frame
	_expect(lights.power > 0.0 and lights.power < 1.0, "the metal halides are warming up (power %.2f)" % lights.power)

	# Doris needs her plugs first
	a = story.use(_venue.spot("doris"))
	_expect(a.has("read") and not a.has("job"), "Doris without plugs: just the note on her dash")
	story.use(_venue.spot("plug_drawer"))
	a = story.use(_venue.spot("doris"))
	_expect(a.has("job") and a.job.job == "doris_plugs" and a.job.room == "zamboni_bay", "with the plugs, Doris opens her job (%s)" % a.get("job", {}))
	var r := story.finish_job(a.job, {"quality": 0.8})
	_expect(r.get("ok", false), "the sim does the plug change (%s)" % r.get("text", ""))

	# compressor 1's oil, the quick way
	a = story.use(_venue.spot("compressor_1"))
	_expect(a.has("job") and a.job.args.get("compressor", -1) == 0 and a.job.room == "plant_room", "compressor No. 1 opens the oil service on compressor 0")
	r = story.finish_job(a.job, {"quality": 0.9})
	_expect(r.get("ok", false), "the sim does the oil service (%s)" % r.get("text", ""))
	a = story.use(_venue.spot("glycol_thermometer"))
	_expect(a.has("job") and a.job.job == "plant_round" and a.job.scene == "", "the glycol thermometers are the plant round, done on the spot (no scene)")
	_expect(story.finish_job(a.job, {}).get("ok", false), "the sim does the plant round")
	_expect(story.use(_venue.spot("log_book")).get("screen", "") == "log_book", "the log book asks for UI's log book screen")
	_expect(story.use(_venue.spot("office_phone")).get("screen", "") == "phone", "the office phone asks for the phone screen")

	# the snow pit
	var bay = _venue.rooms["zamboni_bay"]
	var snow0: float = bay.snow
	story.use(_venue.spot("snow_pit"))
	_expect(bay.pit_heater, "resetting the pit heater")
	story.tick(60.0 / (WalkStory.TIME_SCALE))  # an hour of sim time
	_expect(bay.snow < snow0, "the pit melts down (%.2f -> %.2f)" % [snow0, bay.snow])
	_expect(story.sim.minute > WalkStory.START_MINUTE, "the clock moved on (%s)" % story.clock_text())
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _walk(w: VenueWalker, points: Array) -> Vector3:
	w.running = true
	for p in points:
		var stuck := 0
		var last: Vector3 = w.global_position
		for i in 120 * 10:
			var to: Vector3 = p - w.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			w.wish = to.normalized()
			await physics_frame
			if i % 60 == 59:
				stuck = stuck + 1 if w.global_position.distance_to(last) < 0.2 else 0
				last = w.global_position
				if stuck >= 3:
					break
	w.wish = Vector3.ZERO
	for i in 10:
		await physics_frame
	return w.global_position
