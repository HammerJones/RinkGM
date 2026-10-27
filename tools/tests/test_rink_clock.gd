extends SceneTree
## A rink that follows the clock (Sean, W30): the lobby fills before a game
## night, people who came for a skater line the glass at lessons and
## practices, an early-morning practice is skaters and staff with only a few
## parents, and the walk's people think on the sim's clock.
##
##   godot --headless --path . --script tools/tests/test_rink_clock.gd

var failures := 0


func _init() -> void:
	var cast := Cast.load_region(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fan: Person = cast.people.values().filter(func(p: Person) -> bool: return p.role != "staff" and p.age >= 25)[0]

	# game night: before the puck drops they stand in the lobby, then sit
	var b := NpcBrain.make(fan, "watch", "senior_hockey", rng, {}, {"why": "fan"})
	b.think(1.0, {"phase": "before"})
	_expect(b.activity == "pregame" and b.place == "lobby", "before a game the crowd heads for the lobby (%s, %s)" % [b.activity, b.place])
	b.arrive()
	b.wait = 0.0
	b.think(1.0, {"phase": "before"})
	_expect(b.place == "lobby", "and stays there until play starts")
	b.wait = 0.0
	b.think(1.0, {"phase": "on"})
	_expect(b.activity == "watch" and b.place == b.home and b.home in ["stands", "glass"], "puck drop sends them to their seats (%s)" % b.place)
	var calm := NpcBrain.make(fan, "watch", "public_skate", rng, {}, {"why": "fan"})
	calm.think(1.0, {"phase": "before"})
	_expect(calm.activity != "pregame", "a public skate has no pregame crowd")

	# lessons and practices: whoever came for a skater watches at the glass
	for kind in NpcBrain.GLASS_KINDS:
		var parent := NpcBrain.make(fan, "watch", kind, rng, {}, {"why": "parent", "for": "someone"})
		_expect(parent.home == "glass", "at %s a parent lines the glass" % kind)

	# early morning: the skaters and staff come, most families just drop off
	var came: Array = []
	for i in 40:
		came.append({"as": "play"})
		came.append({"as": "watch"})
	came.append({"as": "work"})
	var dawn := RinkLife.early_crowd(came, 6.0, rng)
	var noon := RinkLife.early_crowd(came, 12.0, rng)
	var count := func(list: Array, as_: String) -> int: return list.filter(func(e) -> bool: return e.as == as_).size()
	_expect(count.call(dawn, "play") == 40 and count.call(dawn, "work") == 1, "every skater and the staff still come at 6:00")
	_expect(count.call(dawn, "watch") <= 16, "but only a few parents stay to watch (%d of 40)" % count.call(dawn, "watch"))
	_expect(noon.size() == came.size(), "a midday session keeps its whole crowd")

	# the walk's people think in building minutes, on the sim's clock
	var src := FileAccess.get_file_as_string("res://scripts/world/people/walk_people.gd")
	_expect("people.time_scale = WalkStory.TIME_SCALE" in src, "the walk's people run on the sim's clock")
	print("rink clock: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)
