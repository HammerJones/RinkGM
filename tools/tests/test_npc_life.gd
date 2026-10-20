extends SceneTree
## NPC life in the real building: RinkPeople on a sim, driven by RinkLife.
## A booked minor hockey practice fills the stands with the players'
## families, every watcher has a reason, the people who came for a player
## leave with them, Gus's tutorial opt-out sticks across a save, and 400
## people tick inside the frame budget.
##   godot --headless --path . --script res://tools/tests/test_npc_life.gd

## Mean RinkPeople update with 400 people, headless (no drawing), ms.
## Generous for loaded CI machines; a quiet machine does about 4 ms.
const BUDGET_MS := 12.0

var failures := 0
var world3d: Node3D
var venue: Venue


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(170.0).timeout.connect(func():
		printerr("FAIL: test_npc_life timed out")
		quit(1))
	AiDialogue.blocked = true  # no network, ever, in tests
	WorldSettings.path = "user://test_npc_life_settings.cfg"
	WorldSettings.reload()
	world3d = Node3D.new()
	root.add_child(world3d)
	world3d.add_child(Rink.new())
	venue = Venue.instantiate_for(Career.exhibition(0), true)
	world3d.add_child(venue)
	await process_frame
	var cast := Cast.load_region(1)
	await _check_booked_event(cast)
	await _check_tutorial(cast)
	await _check_ice_controller(cast)
	await _check_benchmark(cast)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSettings.path))
	if failures:
		printerr("test_npc_life: %d failure(s)" % failures)
	else:
		print("test_npc_life: ok")
	quit(1 if failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A minor hockey practice on the M1 sim's Wednesday: the crowd is booked as
## its start comes up, watchers come for players, and go home with them.
func _check_booked_event(cast: Cast) -> void:
	var sim := RinkSim.create_m1()
	sim.contracts["minor_hockey"] = {"weeks_left": 10, "satisfaction": 60.0}
	sim.day = 2           # Wednesday (day 0 is a Monday)
	sim.minute = 16 * 60 + 30
	var life := RinkLife.create(sim, cast)
	var people := RinkPeople.new()
	venue.add_child(people)
	people.setup(venue, life.world, {"kind": "", "weekday": sim.weekday(), "hour": 16.5})
	people.time_scale = 2.0
	people.set_phase("on")
	people.drive(life, 30.0)  # fast: a sim minute every 2 frames or so
	await _frames(4)
	var key := ""
	for k in life.sessions:
		if life.sessions[k].ev.kind == "minor_hockey":
			key = k
	_expect(key != "", "the 17:00 minor hockey practice gets its crowd booked half an hour out (%s)" % [life.sessions.keys()])
	if key == "":
		people.queue_free()
		return
	var mine := people.agents.filter(func(a): return a.session == key)
	var players := mine.filter(func(a): return a.brain.as_ == "play")
	var watchers := mine.filter(func(a): return a.brain.as_ == "watch")
	print("    minor hockey: %d players, %d watchers, %d others in the building" % [players.size(), watchers.size(), people.count() - mine.size()])
	_expect(players.size() >= 8 and watchers.size() >= 5, "kids on the ice and people in the stands (%d, %d)" % [players.size(), watchers.size()])
	var no_reason := watchers.filter(func(a): return str(a.reason.get("why", "")) == "")
	_expect(no_reason.is_empty(), "every watcher has a reason to be there (%d without)" % no_reason.size())
	var whys := {}
	for a in watchers:
		whys[str(a.reason.why)] = int(whys.get(str(a.reason.why), 0)) + 1
	print("    why they came: %s" % whys)
	var ids := {}
	for a in players:
		ids[a.person.id] = true
	var families := watchers.filter(func(a): return a.brain.watch_for != "" and ids.has(a.brain.watch_for))
	_expect(families.size() >= players.size() / 3, "most kids brought family who watch them (%d of %d watchers)" % [families.size(), watchers.size()])
	var parents := watchers.filter(func(a): return str(a.reason.why) == "parent")
	_expect(not parents.is_empty(), "parents among the watchers")
	# a parent says why in conversation: who they're waiting for, till when
	if not parents.is_empty():
		var c := people.talk(parents[0], parents[0].pos + Vector3(1, 0, 0))
		var why := c.why_line()
		people.end_talk()
		var kid: Person = cast.person(parents[0].brain.watch_for)
		_expect(why != "" and (kid.known_as in why or "my " in why.to_lower()), "a parent says who they came for: '%s'" % why)
	# time passes: the practice starts, and everyone walks in
	sim.minute = 17 * 60 + 15
	await _frames(240)
	_expect(str(people.session_phase.get(key, "")) == "on", "the session is on once its start passes (%s)" % people.session_phase.get(key, ""))
	var arrived := mine.filter(func(a): return a.delay <= 0.0).size()
	_expect(arrived > mine.size() / 2, "people have walked in (%d of %d)" % [arrived, mine.size()])
	# one family heads home early: the kid leaves, the family goes with them
	var fam: Array = families.filter(func(a): return a.delay <= 0.0)
	if fam.is_empty():
		fam = families
	if not fam.is_empty():
		var kid_agent: RinkPeople.Agent = people.agent_of(fam[0].brain.watch_for)
		var group: Array = people.agents.filter(func(a): return a.brain.watch_for == kid_agent.person.id)
		people.send_home(kid_agent)
		await _frames(12)
		var with_kid := group.filter(func(a): return a.brain.activity == "leave" or not a in people.agents)
		_expect(with_kid.size() == group.size(), "the family leaves with their kid (%d of %d)" % [with_kid.size(), group.size()])
	# the end: watchers wait in the lobby for their player, then go
	sim.minute = 20 * 60 + 5
	for i in 300:
		if str(people.session_phase.get(key, "")) == "after" and life.sessions[key].settled:
			break
		await process_frame
	await _frames(10)
	_expect(str(people.session_phase.get(key, "")) == "after", "after the practice (%s)" % people.session_phase.get(key, ""))
	var waiting := people.agents.filter(func(a): return a.session == key and a.brain.activity == "wait_for")
	var players_left := people.agents.filter(func(a): return a.session == key and a.brain.as_ == "play" and a.brain.activity != "leave")
	_expect(not waiting.is_empty() or players_left.is_empty(), "parents wait in the lobby for kids still changing (%d waiting)" % waiting.size())
	_expect(life.sessions[key].settled, "the night is settled: everyone who came remembers it")
	people.queue_free()
	await _frames(2)


## Gus offers his help on the first morning; "no thanks" turns it off and
## the choice survives a save.
func _check_tutorial(cast: Cast) -> void:
	var sim := RinkSim.create_m1()
	var life := RinkLife.create(sim, cast)
	var people := RinkPeople.new()
	venue.add_child(people)
	people.setup(venue, life.world, {"kind": ""})
	var flags := {}
	var guide := TutorialGuide.create(people, life, venue, null, flags)
	root.add_child(guide)
	await _frames(2)
	_expect(guide.agent != null and guide.agent.person.id == "gus_tremblay", "Gus is in the building on the first morning")
	var c := Conversation.open(life.world, cast.person("gus_tremblay"))
	_expect(c.node_id == "tutorial_ask", "Gus asks whether you want his help (%s)" % c.node_id)
	var no := -1
	for i in c.choices.size():
		if "figure it out" in str(c.choices[i].text):
			no = i
	c.choose(no)
	await _frames(2)
	_expect(guide.state() == "off" and flags.get("tutorial", "") == "off", "saying no turns the tutorial off (%s)" % guide.state())
	# the career saves the walk's flags; a new walk on a reload finds them
	var saved: Dictionary = JSON.parse_string(JSON.stringify(flags))
	guide.queue_free()
	people.queue_free()
	await _frames(2)
	var life2 := RinkLife.create(RinkSim.create_m1(), Cast.load_region(1))
	var people2 := RinkPeople.new()
	venue.add_child(people2)
	people2.setup(venue, life2.world, {"kind": ""})
	var guide2 := TutorialGuide.create(people2, life2, venue, null, saved)
	root.add_child(guide2)
	await _frames(2)
	_expect(guide2.agent == null and not guide2.wanted(), "the opt-out persists: no Gus after a reload")
	guide2.queue_free()
	# outside a career it's kept in WorldSettings
	var guide3 := TutorialGuide.create(people2, life2, venue, null, null)
	guide3.set_state("off")
	WorldSettings.reload()
	_expect(WorldSettings.get_string("tutorial") == "off", "a free walk's opt-out is kept in the settings file")
	guide3.free()
	# yes: the steps run and advance on the sim's jobs
	WorldSettings.set_value("tutorial", "")
	var flags4 := {}
	var guide4 := TutorialGuide.create(people2, life2, venue, null, flags4)
	root.add_child(guide4)
	await _frames(2)
	life2.world.flags["tutorial_yes"] = true
	await _frames(2)
	_expect(guide4.state() == "on" and guide4.current().get("id", "") == "plant_round", "yes: the plant round first")
	life2.job("plant_round")
	await _frames(2)
	_expect(guide4.current().get("id", "") == "ice_check" and int(flags4.get("tutorial_step", 0)) == 1, "a finished job moves Gus on to the next step")
	guide4.add_step({"id": "extra", "say": "One more.", "hint": "Extra.", "done": [{"signal": "extra_done"}]}, "ice_check")
	life2.world.flags["tutorial_skip"] = true
	await _frames(2)
	_expect(guide4.current().get("id", "") == "extra", "steps added by other systems slot in after their anchor")
	guide4.notify("signal", {"name": "extra_done"})
	await _frames(2)
	_expect(guide4.current().get("id", "") == "office", "a signal finishes a step")
	guide4.queue_free()
	people2.queue_free()
	await _frames(2)


## 400 people moving, thinking and talking: the update stays in budget.
## Stands in for OnIceSession: records who it was handed.
class FakeIce:
	extends Node
	var taken: Array = []
	func take(p: Person) -> void:
		taken.append(p.id)


## While another system draws the ice, players hand off to it in the
## dressing room and RinkPeople draws nobody on the ice; spectators stay.
func _check_ice_controller(cast: Cast) -> void:
	var w := StoryWorld.create(cast)
	w.event_now = "minor_hockey"
	var people := RinkPeople.new()
	venue.add_child(people)
	var ev := {"kind": "minor_hockey", "weekday": 6, "hour": 9.0, "hours": 1.5, "ice_rep": 60.0}
	people.setup(venue, w, ev)
	var fake := FakeIce.new()
	venue.add_child(fake)
	people.ice_controller = fake
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	people.populate(Attendance.who_comes(cast, ev, rng), true)
	people.set_phase("on")
	await _frames(30)
	var players := people.agents.filter(func(a): return a.brain.as_ == "play")
	var watchers := people.agents.filter(func(a): return a.brain.as_ == "watch" and a.brain.arrived)
	_expect(not players.is_empty() and fake.taken.size() == players.size(), "players hand off to the ice controller (%d of %d)" % [fake.taken.size(), players.size()])
	_expect(people.on_ice().is_empty(), "nobody of RinkPeople's own is drawn on the ice while it's taken (%d)" % people.on_ice().size())
	_expect(watchers.size() > 10, "spectators keep watching (%d)" % watchers.size())
	people.ice_controller = null
	await _frames(240)
	_expect(players.all(func(a): return not a.handed), "cleared: players are RinkPeople's again")
	fake.queue_free()
	people.queue_free()
	await _frames(2)


func _check_benchmark(cast: Cast) -> void:
	var w := StoryWorld.create(cast)
	w.event_now = "public_skate"
	var people := RinkPeople.new()
	venue.add_child(people)
	var ev := {"kind": "public_skate", "weekday": 6, "hour": 13.0, "hours": 2.0, "ice_rep": 70.0, "pull": 0.9}
	people.setup(venue, w, ev)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var came := Attendance.who_comes(cast, ev, rng)
	var extra := 0
	for p: Person in cast.people.values():
		if came.size() >= 400:
			break
		if not came.any(func(e): return e.person == p):
			came.append({"person": p, "as": "play" if rng.randf() < 0.6 else "watch", "reason": {"why": "fan", "for": ""}})
			extra += 1
	came.resize(mini(came.size(), 400))
	var cam := Node3D.new()
	venue.add_child(cam)
	cam.position = Vector3(0, 6, 22)
	people.focus = cam
	people.profile = true
	people.populate(came, false)
	people.set_phase("on")
	# everyone walks in within a couple of seconds, so the whole crowd is live
	for a: RinkPeople.Agent in people.agents:
		a.delay = rng.randf_range(0.0, 1.5)
	var t0 := Time.get_ticks_msec()
	while (not people.map.baked or Time.get_ticks_msec() - t0 < 2000) and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	var total := 0
	var worst := 0
	var n := 0
	var thinks := 0
	var writes := 0
	for i in 600:
		await process_frame
		if i < 60:
			continue
		total += people.stats.frame_us
		worst = maxi(worst, people.stats.frame_us)
		thinks += people.stats.thinks
		writes += people.stats.writes
		n += 1
		if i == 300:
			people.goal()
	var mean := total / 1000.0 / n
	print("    benchmark: %d people (%d topped up), RinkPeople update mean %.2f ms, worst %.2f ms, %.0f thinks and %.0f instance writes a frame" % [
		people.count(), extra, mean, worst / 1000.0, float(thinks) / n, float(writes) / n])
	print("    benchmark sections (us a frame): %s" % JSON.stringify(_per_frame(people.stats.get("sections", {}), n + 60)))
	_expect(people.count() >= 380, "400 people in the building (%d)" % people.count())
	_expect(mean < BUDGET_MS, "400 people update in %.2f ms a frame on average (budget %.1f)" % [mean, BUDGET_MS])
	people.queue_free()
	await _frames(2)


func _per_frame(d: Dictionary, n: int) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k]) / maxi(n, 1)
	return out
