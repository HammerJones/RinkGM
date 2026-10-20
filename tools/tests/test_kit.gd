extends SceneTree
## Headless checks of the owner's kit: the watch (#13), the grid inventory
## (#19), the ice balance game and the slip injury (#19), and off-ice
## training (#29, #33).
##
##   godot --headless --path . --script tools/tests/test_kit.gd

var failures := 0


func _init() -> void:
	_watch()
	_inventory()
	_balance()
	_slip()
	_training()
	print("kit: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _watch() -> void:
	var w := Watch.new()
	var now := 3 * Watch.DAY_MIN + 5 * 60 + 42
	var face := w.read(now, 1)
	_expect(face.time == "05:42" and face.day == "MON", "the watch reads the rink's clock (%s %s)" % [face.day, face.time])
	_expect(w.set_timer(30, "Flood freezes", now), "a timer starts")
	_expect(not w.set_timer(10, "Second", now), "the gas-station watch holds one timer")
	_expect(w.tick(now + 29).is_empty(), "the timer hasn't gone off at 29 minutes")
	var fired := w.tick(now + 30)
	_expect(fired.size() == 1 and fired[0].label == "Flood freezes", "the timer goes off at 30 minutes")
	_expect(not w.set_alarm(5 * 60), "no alarm on the cheap watch")
	_expect(not w.read(now, 1, true).lit and w.upgrade("sport") and w.read(now, 1, true).lit, "only a backlit watch reads in the dark")
	_expect(w.set_alarm(6 * 60) and w.tick(3 * Watch.DAY_MIN + 6 * 60).size() == 1, "the alarm rings at 06:00")
	_expect(w.tick(3 * Watch.DAY_MIN + 6 * 60 + 15).is_empty(), "and only once that day")
	_expect(w.tick(4 * Watch.DAY_MIN + 6 * 60).size() == 1, "and again the next morning")
	w.set_timer(45, "Doris", now)
	var w2 := Watch.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	_expect(w2.model == "sport" and w2.timers.size() == 1 and w2.alarm == 6 * 60, "the watch saves and loads")


func _inventory() -> void:
	var g := InventoryGrid.new()
	_expect(g.size == Vector2i(6, 4) and g.free_cells() == 24, "the bag starts 6 x 4")
	var wrench := g.place("wrench", Vector2i(0, 0), 0)
	_expect(wrench > 0, "the wrench goes in the top-left")
	_expect(not g.fits("keys", Vector2i(0, 1), 0), "nothing overlaps the wrench's hook")
	_expect(g.fits("keys", Vector2i(1, 1), 0), "but the cell beside the hook is free")
	_expect(not g.fits("flashlight", Vector2i(4, 0), 0), "a 3-long flashlight doesn't hang off the edge")
	_expect(g.fits("flashlight", Vector2i(5, 0), 1), "turned upright it fits down the right side")
	var cells: Array = ItemCatalog.shape("hammer", 1)
	_expect(cells.size() == 5 and cells.has(Vector2i(0, 1)) and cells.has(Vector2i(2, 1)), "the hammer turns a quarter: %s" % [cells])
	_expect(ItemCatalog.shape("crampons", 3) == ItemCatalog.shape("crampons", 0), "a square looks the same turned")
	var cr := g.add("crampons")
	_expect(cr > 0 and g.has("crampons"), "the crampons find a spot")
	_expect(g.move(wrench, Vector2i(3, 2), 2) or g.move(wrench, Vector2i(2, 2), 0), "the wrench moves elsewhere")
	g.add("scoresheet")
	var filled := 0
	while g.add("tape") > 0:
		filled += 1
	_expect(g.free_cells() == 0 and filled > 0, "tape fills every gap")
	_expect(g.add("keys") == -1, "a full bag takes nothing more")
	var g2 := InventoryGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	_expect(g2.items.size() == g.items.size() and g2.free_cells() == 0, "the bag saves and loads")
	_expect(g2.take("crampons") and not g2.has("crampons"), "the crampons come back out")
	_expect(ItemCatalog.for_flag("keys") == "keys" and ItemCatalog.for_flag("spark_plugs") == "spark_plugs", "walk flags map to items")


func _balance() -> void:
	_expect(IceBalance.needed(true, false) and not IceBalance.needed(true, true) and not IceBalance.needed(false, false),
		"the wobble runs on the ice in shoes, not with crampons or off the ice")
	# nobody touching the controls, carrying a net: the owner goes down
	var b := IceBalance.create(7, 0.5)
	var fell_at := -1.0
	for i in 60 * 30:
		if b.tick(1.0 / 60.0, Vector2.ZERO, 1.1, 1.0) == "fell":
			fell_at = i / 60.0
			break
	_expect(fell_at > 0.0, "left alone with a net, the owner falls (%.1f s)" % fell_at)
	# a player who pushes back toward the centre stays up
	var c := IceBalance.create(7, 0.5)
	var fell := false
	for i in 60 * 30:
		if c.tick(1.0 / 60.0, -c.pos * 3.0 - c.vel * 0.6, 1.1, 1.0) == "fell":
			fell = true
	_expect(not fell, "pushing the dot back keeps the owner up for 30 s")
	# standing still with nothing is easier than walking with a net
	var still := _mean_offset(IceBalance.create(3, 0.5), 0.0, 0.0)
	var loaded := _mean_offset(IceBalance.create(3, 0.5), 1.1, 1.0)
	_expect(loaded > still, "walking with a net wobbles more (%.2f vs %.2f)" % [loaded, still])


func _mean_offset(b: IceBalance, speed: float, load: float) -> float:
	var t := 0.0
	for i in 600:
		b.tick(1.0 / 60.0, -b.pos * 2.0, speed, load)
		t += b.pos.length()
	return t / 600.0


func _slip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var inj := Injury.slip(rng)
	_expect(inj.days_out >= 1 and inj.days_out <= 2 and not inj.can_play(), "a slip keeps the owner out a day or two")
	var c := Career.new_career("Slip", "Test", "C", 4)
	c.follows_world = true
	c.user().injury = inj
	c.user().refresh_modifiers()
	c.pass_day(true)
	c.pass_day(true)
	_expect(c.user().injury == null, "two days later it's healed")
	var inj2 := Injury.from_dict(JSON.parse_string(JSON.stringify(Injury.slip(rng).to_dict())))
	_expect(inj2.days_total > 0, "the slip's days save and load")


func _training() -> void:
	var c := Career.new_career("Gym", "Rat", "C", 9)
	var p := c.user()
	_expect(p.skills.values.has("stamina"), "skaters have stamina")
	var sim := RinkSim.create_m1(3)
	var t := Training.new()
	var speed0: float = p.skills.values.speed
	var m0 := sim.minute
	var r := t.do_set("squat_rack", p, sim)
	_expect(r.ok and float(p.skills.values.speed) > speed0, "a squat set builds speed")
	_expect(sim.minute == m0 + Training.SET_MIN, "a set takes 15 minutes")
	_expect(sim.fatigue > 0.0, "and tires the owner")
	var st0: float = p.skills.values.stamina
	t.do_set("treadmill", p, sim)
	_expect(float(p.skills.values.stamina) > st0, "the treadmill builds stamina")
	for i in 12:
		t.do_set("bench", p, sim)
	var pow0: float = p.skills.values.shot_power
	var late := t.do_set("bench", p, sim)
	_expect(not late.gains.is_empty() and float(p.skills.values.shot_power) > pow0, "no daily cap: a 14th set still builds something")
	_expect(Training.freshness(90.0) < Training.freshness(10.0), "a tired owner gains less")
	var acc0: float = p.skills.values.shot_accuracy
	var ag0: float = p.skills.values.agility
	var pk := t.pickup("basketball", 30, 20, 9, p, sim)
	_expect(float(p.skills.values.shot_accuracy) > acc0 and float(p.skills.values.agility) > ag0, "pickup basketball trains accuracy and agility: %s" % pk.text)
	var sim2 := RinkSim.create_m1(5)
	var t2 := Training.new()
	var hit0: float = p.skills.values.hitting
	t2.trained(["hitting"], 30, 1.0, p, sim2)
	_expect(float(p.skills.values.hitting) > hit0, "World's trained signal builds the named skill")
	sim2.ops.set_nets(2, 3)
	_expect(sim2.get("nets_on_ice") == {"large": 2, "mini": 3}, "World reads the nets on the ice by name")
