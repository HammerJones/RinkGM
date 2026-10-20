extends SceneTree
## People as characters, first slice (W28): the town's generated rink staff
## each hold a position of their own (place, shifts, title, clothes), no two
## staff share a line, and a work point holds one worker at a time.
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
