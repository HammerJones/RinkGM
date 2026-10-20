extends SceneTree
## People as characters, first slice (W28): the town's generated rink staff
## each hold a position of their own (place, shifts, title, clothes), no two
## staff share a line, and a work point holds one worker at a time. Slice
## two (W29): breaks, days off, lateness habits, and lines that follow the
## time of day and what's happened.
##
##   godot --headless --path . --script tools/tests/test_staff_roster.gd

var failures := 0


func _init() -> void:
	var cast := Cast.load_region(1)
	var staff: Array = cast.people.values().filter(func(p: Person) -> bool: return p.role == "staff")
	var gen: Array = staff.filter(func(p: Person) -> bool: return p.generated)
	_expect(gen.size() >= 4, "the town has generated staff (%d)" % gen.size())
	var titles := {}
	for p: Person in gen:
		titles[p.job] = true
	_expect(titles.size() == gen.size(), "each generated staff member has their own job (%d titles)" % titles.size())
	var places := {}
	for p: Person in gen:
		for e in p.schedule:
			if str(e.get("doing", "")) == "work":
				places[e.place] = true
	_expect(places.size() >= 5, "and they work all over the building (%s)" % ", ".join(places.keys()))
	# W28: at most one generated tech in the bay at any hour of the week
	var worst := 0
	for wd in 7:
		for h in 24:
			var n := gen.filter(func(p: Person) -> bool: return p.on_shift(wd, h + 0.5) and p.place_at(wd, h + 0.5) == "zamboni_bay").size()
			worst = maxi(worst, n)
	_expect(worst <= 1, "never two generated techs in the zamboni bay at once (%d)" % worst)
	var said := {}
	var shared := 0
	for p: Person in staff:
		for topic in p.lines:
			for line in p.lines[topic]:
				if said.has(line) and said[line] != p.id:
					shared += 1
				said[line] = p.id
	_expect(shared == 0 and said.size() > 20, "no two staff share a line (%d lines, %d shared)" % [said.size(), shared])
	var rng := RandomNumberGenerator.new()
	var someone: Person = gen[0]
	_expect(str(cast.bark(someone, "idle", rng)) in someone.lines.idle, "a staff bark is one of their own lines")

	# W29: breaks, days off, how they keep time, and lines for what's going on
	var crew: Person = null
	var styles := {}
	var lates := {}
	for p: Person in gen:
		styles[p.habits.get("punctuality", "")] = true
		if p.habits.get("position", "") == "ice_crew":
			crew = p
		if p.habits.get("punctuality", "") in ["runs late", "late a lot"]:
			for d in 14:
				lates[StaffRoster.late_minutes(p, d)] = true
	_expect(styles.size() >= 3, "staff keep time their own way (%s)" % ", ".join(styles.keys()))
	_expect(lates.size() >= 4, "and the late ones aren't late the same way every day (%d)" % lates.size())
	_expect(crew != null, "someone holds the ice crew job")
	if crew:
		var rested := crew.schedule.filter(func(e) -> bool: return e.get("break", false))
		_expect(not rested.is_empty() and rested.all(func(e) -> bool: return e.place == StaffRoster.BREAK_PLACE), "a six-hour shift has a break in the hall")
		var mid: float = float(rested[0].from) + 0.1 if not rested.is_empty() else 9.0
		_expect(crew.on_shift(1, mid), "a break is still on the clock")
		_expect(StaffRoster.shift_span(crew, 1, mid) == [6.0, 12.0], "the shift spans the break (%s)" % [StaffRoster.shift_span(crew, 1, mid)])
		_expect(not crew.on_shift(0, 8.0) and not crew.on_shift(6, 8.0), "the weekday crew has the weekend off")
		var txt := StaffRoster.week_text(crew)
		_expect(txt.begins_with("Mon-Fri 6:00-12:00 (break ") and "off Sun, Sat" in txt, "the staff screen reads their week: " + txt)
		crew.habits.late = [20, 20]
		_expect(not StaffRoster.due(crew, 1, 6.1, 0, false), "a late one isn't in at 6:06")
		_expect(StaffRoster.due(crew, 1, 6.4, 0, false), "but is by 6:24")
		_expect(not StaffRoster.due(crew, 1, 12.1, 0, true), "and still leaves at noon")
		crew.habits.late = [-15, -15]
		_expect(StaffRoster.due(crew, 1, 5.8, 0, false), "an early bird is wanted at 5:48")
		crew.habits.late = [0, 0]

		var sim := RinkSim.create()
		var w := StoryWorld.create(cast, sim)
		sim.day = 1  # a Monday
		sim.minute = 6 * 60 + 20
		sim.doris.choke_stuck = true
		_expect(StaffRoster.situation(sim, crew) == "broken", "a dead machine is what everyone talks about")
		sim.doris.choke_stuck = false
		sim._last_flood_abs = sim._abs_minute() - 5
		_expect(StaffRoster.situation(sim, crew) == "resurfaced", "then a fresh flood")
		sim._last_flood_abs = -100000
		var tonight := sim.sessions(sim.day).any(func(s) -> bool: return str(s.get("use", "")) == "hockey" and float(s.start) >= 17.0)
		var now := StaffRoster.situation(sim, crew)
		_expect(now == ("game_tonight" if tonight else "start"), "then a game tonight or the start of the shift (%s)" % now)
		var heard := {}
		for i in 40:
			heard[Conversation.bark(w, crew, "idle")] = true
		var on_topic: int = crew.lines[now].filter(func(l) -> bool: return heard.has(l)).size()
		var idle: int = crew.lines.idle.filter(func(l) -> bool: return heard.has(l)).size()
		_expect(on_topic > 0 and idle > 0, "their idle talk mixes in what's going on (%d topical, %d idle)" % [on_topic, idle])
		sim.minute = 9 * 60 + 30
		_expect(StaffRoster.situation(sim, crew) in ["", "game_tonight"], "mid-shift with nothing on, nothing special")

	var map := PlaceMap.new()
	map.places = {"zamboni_bay": [Vector3(1, 0, 0), Vector3(2, 0, 0)]}
	var a := map.claim("zamboni_bay", "a")
	var b := map.claim("zamboni_bay", "b")
	_expect(a != b and a != Vector3.INF and b != Vector3.INF, "two workers get two work points")
	_expect(map.claim("zamboni_bay", "c") == Vector3.INF, "a third finds the bay full")
	_expect(map.claim("zamboni_bay", "a") == a, "a worker keeps their own point")
	map.release("a")
	_expect(map.claim("zamboni_bay", "c") == a, "and it frees up when they leave")
	map.free()
	print("staff roster: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)
