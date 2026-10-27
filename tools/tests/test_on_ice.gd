extends SceneTree
## On-ice events: every event kind spawns its roster, nobody overlaps after
## a stretch of skating, every drill in drills.json sets up and runs a full
## cycle, pee-wee kids stay in their zones behind the pads, the rental
## counter runs out of a size and somebody's unhappy about it, returned
## skates pile up with nobody to put them away and shrink once a clerk is
## free, and public skate demand follows the calendar.
##   godot --headless --path . --script res://tools/tests/test_on_ice.gd

var failures := 0
const DT := 1.0 / 20.0


func _initialize() -> void:
	for step: Callable in [_check_demand, _check_rosters, _check_overlap, _check_drills,
			_check_peewee_zones, _check_rental_runs_out, _check_return_pile, _check_figure_ice]:
		var t0 := Time.get_ticks_msec()
		step.call()
		print("  (%s %.1f s)" % [step.get_method(), (Time.get_ticks_msec() - t0) / 1000.0])
	if failures:
		printerr("test_on_ice: %d failure(s)" % failures)
	else:
		print("test_on_ice: ok")
	quit(1 if failures else 0)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _check_demand() -> void:
	var sat := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 10, "dom": 17})
	var tue := SkateDemand.expected({"weekday": 2, "hour": 6.0, "month": 10, "dom": 20})
	var xmas := SkateDemand.expected({"weekday": 5, "hour": 14.0, "month": 12, "dom": 25})
	if not float(sat.expected) > float(tue.expected) * 5.0:
		_fail("Saturday afternoon should be far busier than Tuesday 06:00 (%.0f vs %.0f)" % [sat.expected, tue.expected])
	if not xmas.at_capacity or int(xmas.expected) != int(xmas.capacity):
		_fail("Christmas afternoon should be at capacity (%s)" % str(xmas))
	var cheap := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 10, "dom": 17, "price": 2.0})
	var dear := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 10, "dom": 17, "price": 9.0})
	if not float(cheap.expected) > float(dear.expected):
		_fail("a cheaper ticket should bring more skaters")
	var july := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 7, "dom": 18})
	if not float(july.expected) < float(sat.expected):
		_fail("July should be quieter than October")
	var storm := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 1, "dom": 17, "weather": "blizzard"})
	var rain := SkateDemand.expected({"weekday": 6, "hour": 14.0, "month": 1, "dom": 17, "weather": "rain", "temp_c": 2.0})
	if not float(rain.expected) > float(storm.expected):
		_fail("rain drives people in; a blizzard keeps them home")
	print("demand: Sat 14:00 %.0f, Tue 06:00 %.0f, Christmas %.0f / %d" % [sat.expected, tue.expected, xmas.expected, xmas.capacity])


func _make(kind: String, extra := {}) -> OnIceSession:
	var c := {"seed": 5, "fast": true, "in_place": true, "hour": 14.0, "weekday": 6, "month": 10, "dom": 17}
	c.merge(extra, true)
	var s := OnIceSession.create(kind, c)
	s.auto_run = false
	return s


func _check_rosters() -> void:
	var s := _make("public_skate", {"count": 40})
	var ps := s as OnIcePublicSkate
	if s.on_ice_count() != 40:
		_fail("public skate: 40 skaters on the ice, got %d" % s.on_ice_count())
	if ps.rental == null or ps.rental.staff.is_empty():
		_fail("public skate: somebody works the rental window")
	if not ps.gus_working:
		_fail("public skate: Gus works the very first one")
	var r := s.roles()
	for role in ["beginner", "kid", "regular"]:
		if int(r.get(role, 0)) == 0:
			_fail("public skate: no %s in a crowd of 40 (%s)" % [role, str(r)])
	s.free()

	s = _make("figure_practice", {"hour": 5.0})
	r = s.roles()
	if (s as OnIceFigure).mode != "morning" or int(r.get("figure", 0)) < 4 or int(r.get("figure", 0)) > 8 or int(r.get("coach", 0)) < 2:
		_fail("figure 05:00: 4-8 skaters and their coaches (%s)" % str(r))
	s.free()
	s = _make("figure_practice", {"hour": 16.0})
	if (s as OnIceFigure).mode != "class" or (s as OnIceFigure).groups.size() != 3:
		_fail("figure afternoon: classes grouped by skill")
	s.free()
	s = _make("learn_to_skate")
	if (s as OnIceFigure).mode != "class":
		_fail("learn to skate runs as a class")
	s.free()
	s = _make("figure_show")
	r = s.roles()
	if int(r.get("figure", 0)) < 6:
		_fail("figure show: a field of skaters (%s)" % str(r))
	s.free()

	s = _make("broomball")
	r = s.roles()
	var shoes := true
	for k: IceSkater in s.skaters:
		shoes = shoes and k.shoes
	if int(r.get("broomball", 0)) != 10 or int(r.get("goalie", 0)) != 2 or int(r.get("ref", 0)) != 1 or not shoes:
		_fail("broomball: 6 a side in sneakers and a ref (%s)" % str(r))
	s.free()

	s = _make("minor_hockey")
	var pr := s as OnIcePractice
	if pr.groups.size() != 3:
		_fail("pee-wee: three sub-groups")
	var nick := {}
	for g: Dictionary in pr.groups:
		nick[g.nickname] = true
		if (g.coaches as Array).size() < 2:
			_fail("pee-wee %s: at least two coaches" % g.id)
		var gd: Dictionary = OnIceData.section("peewee").groups[pr.groups.find(g)]
		for sid in g.kids:
			var k := s.by_id(sid)
			if k.age < int(gd.ages[0]) or k.age > int(gd.ages[1]):
				_fail("pee-wee %s: a %d-year-old in the wrong group" % [g.id, k.age])
	if nick.size() != 3:
		_fail("pee-wee: each group has its own nickname")
	if s.gear.count_nets("full") > 4 or s.gear.count_nets("mini") > 8:
		_fail("pee-wee: more nets than the rink owns (%d full, %d mini)" % [s.gear.count_nets("full"), s.gear.count_nets("mini")])
	for n: Dictionary in s.gear.nets:
		if str(n.get("group", "")) == "toddlers" and n.size != "mini":
			_fail("pee-wee: the toddlers only use mini nets")
	var blue := 0
	for p: IceGear.IcePuck in s.gear.pucks:
		blue += 1 if p.blue else 0
	if blue == 0:
		_fail("pee-wee: the youngest use light blue pucks")
	var toddler_runs: Array = pr.groups[0].runs
	var teen_runs: Array = pr.groups[2].runs
	if toddler_runs.size() < 3 or teen_runs.size() != 1:
		_fail("pee-wee: the young groups run 3-4 stations, the teens one team drill (%d, %d)" % [toddler_runs.size(), teen_runs.size()])
	s.free()

	s = _make("high_school")
	r = s.roles()
	if int(r.get("player", 0)) < 18 or int(r.get("goalie", 0)) != 2 or int(r.get("coach", 0)) < 2:
		_fail("high school: a team, two goalies, coaches (%s)" % str(r))
	s.free()
	s = _make("stick_and_puck")
	var with_puck := 0
	for k2: IceSkater in s.skaters:
		with_puck += 1 if k2.puck >= 0 else 0
	if with_puck < 6 or with_puck != s.skaters.size():
		_fail("stick and puck: everybody with a puck (%d of %d)" % [with_puck, s.skaters.size()])
	s.free()
	s = _make("beer_league")
	r = s.roles()
	if int(r.get("player", 0)) != 24 or int(r.get("goalie", 0)) != 4 or int(r.get("ref", 0)) != 2:
		_fail("beer league game: two teams, four goalies, two refs (%s)" % str(r))
	s.free()
	# the warm-up waits for nets
	s = _make("beer_league", {"fast": false, "nets_on_ice": 0})
	var asked := [0]
	s.nets_needed.connect(func(_f: int, _m: int) -> void: asked[0] += 1)
	s.run_for(32.0, DT)
	if (s as OnIceGame).game_phase != "waiting" or asked[0] == 0:
		_fail("game: no warm-up without nets (%s)" % (s as OnIceGame).game_phase)
	s.ctx.nets_on_ice = 2
	s.run_for(40.0, DT)
	if not (s as OnIceGame).game_phase in ["bucket", "warmup"]:
		_fail("game: nets out, the bucket goes out and the warm-up starts (%s)" % (s as OnIceGame).game_phase)
	s.free()


func _check_overlap() -> void:
	for kind in ["public_skate", "minor_hockey", "beer_league", "figure_practice", "broomball"]:
		var s := _make(kind, {"count": 150} if kind == "public_skate" else {"hour": 5.0})
		var whistles := [0]
		s.coach_whistle.connect(func(_p: Vector3) -> void: whistles[0] += 1)
		s.whistle.connect(func(_p: Vector3) -> void: whistles[0] += 1)
		s.run_for(25.0, DT)
		var bad := OnIceMotion.overlaps(s.skaters, 0.02)
		if not bad.is_empty():
			var a: IceSkater = bad[0][0]
			var b: IceSkater = bad[0][1]
			_fail("%s: %d pairs overlap after 25 s (%s and %s, %.2f m apart)" % [kind, bad.size(), a.role, b.role, a.pos.distance_to(b.pos)])
		var outside := 0
		for k: IceSkater in s.skaters:
			if k.on_ice and not k.hidden and Rink.sdf(k.pos) > 0.01:
				outside += 1
		if outside:
			_fail("%s: %d skaters through the boards" % [kind, outside])
		s.free()


## A bare session to host one drill at a time.
func _host() -> OnIceSession:
	var s := OnIceSession.new()
	s.kind = "test"
	s._setup_common({"seed": 9})
	s.auto_run = false
	return s


func _check_drills() -> void:
	var all := OnIceData.drills()
	if all.size() < 24:
		_fail("at least 24 drills (%d)" % all.size())
	var slow: Array = []
	for id in all:
		var d: Dictionary = all[id]
		var s := _host()
		var scope := str(d.get("scope", "full"))
		var area := Rect2(-Rink.HALF_L, -Rink.HALF_W, Rink.LENGTH, Rink.WIDTH)
		var n := 10
		if scope == "zone":
			area = Rect2(10.33, -Rink.HALF_W, Rink.HALF_L - 10.33, Rink.WIDTH)
			n = 8
		elif scope == "station":
			area = Rect2(10.9, 0.6, 9.0, 11.7)
			n = 6
		var run := DrillRun.new(s, d, area)
		var coach := s.add_skater("coach", 40, s.look_for("coach", 40), 0.7)
		coach.pos = area.get_center() + Vector2(0, area.size.y * 0.4)
		run.coaches = [coach.id]
		for i in n:
			var p := s.add_skater("player", 15, s.look_for("player", 15), 0.7)
			p.max_speed = 7.0
			p.accel = 4.5
			p.fall_rate = 0.0
			p.pos = area.get_center() + Vector2((i % 4 - 1.5) * 1.5, (i / 4 - 1.0) * 1.5)
			run.players.append(p.id)
		if d.get("goalie", false):
			var g := s.add_skater("goalie", 17, s.look_for("goalie", 17), 0.7)
			g.pos = area.get_center()
			run.goalies = [g.id]
		run.setup(true)
		var tt := 0.0
		while run.cycles < 1 and tt < 240.0:
			run.step(DT)
			s.step(DT)
			tt += DT
		if run.cycles < 1:
			_fail("drill %s didn't finish a cycle in 240 s (reps %d, state %s)" % [id, run.reps, run.state])
		elif tt > 120.0:
			slow.append("%s %.0fs" % [id, tt])
		s.free()
	print("drills: %d ran a cycle%s" % [all.size(), (" (slow: %s)" % ", ".join(slow)) if not slow.is_empty() else ""])


func _check_peewee_zones() -> void:
	# pads start on the rack: the coaches and two rink hands lay them out
	var s := _make("minor_hockey", {"fast": false, "staff": 2})
	var pr := s as OnIcePractice
	var tt := 0.0
	while not pr.pads_done and tt < 400.0:
		s.step(DT)
		tt += DT
	if not pr.pads_done:
		var left := 0
		for task: Dictionary in pr.setup_tasks:
			left += 0 if task.state == "done" else 1
		_fail("pee-wee: the pads never all went out (%d left after %.0f s)" % [left, tt])
	s.run_for(60.0, DT)
	var placed := 0
	for p: Dictionary in s.gear.pads:
		placed += 1 if p.placed else 0
	if placed != s.gear.pads.size():
		_fail("pee-wee: every pad on the ice")
	var stray := 0
	for gi in pr.groups.size():
		var rect: Rect2 = pr.zones[gi]
		for sid in pr.groups[gi].kids:
			var k := s.by_id(sid)
			if k.pos.x < rect.position.x + k.radius - 0.05 or k.pos.x > rect.end.x - k.radius + 0.05:
				stray += 1
	if stray:
		_fail("pee-wee: %d kids crossed the pads into another zone" % stray)
	var running := 0
	for run: DrillRun in pr.runs:
		running += 1 if run.state in ["run", "paused", "setup"] else 0
	if running < 5:
		_fail("pee-wee: stations running in every zone (%d)" % running)
	print("pee-wee: pads out in %.0f s, %d drills running" % [tt, running])
	s.free()


func _check_rental_runs_out() -> void:
	var r := SkateRental.new()
	r.setup({"staff": 1, "inventory": {"A9": 1}, "seed": 2})
	var got: Array = []
	r.served.connect(func(_c: IceSkater, info: Dictionary) -> void: got.append(info))
	var refunds := [0]
	r.refund_demanded.connect(func(_i: Dictionary) -> void: refunds[0] += 1)
	for i in 3:
		r.enqueue(PeopleArt.random_look(r.rng, 35, "stands"), 35, "A9")
	var tt := 0.0
	while got.size() < 3 and tt < 300.0:
		r.step(DT)
		tt += DT
	if got.size() < 3:
		_fail("rental: three customers served or turned away (%d after %.0f s)" % [got.size(), tt])
	var out := got.filter(func(i: Dictionary) -> bool: return str(i.size_got) == "")
	if out.size() < 2:
		_fail("rental: one pair of 9s for three people: two go without (%s)" % str(got))
	if r.unhappy < 2:
		_fail("rental: no skates makes for unhappy customers (%d)" % r.unhappy)
	if r.stock("A9") != 0:
		_fail("rental: the only A9 went out")
	print("rental: %d turned away, %d refund demands" % [out.size(), refunds[0]])
	# the player serves: ask, grab the right size, hand it over
	var r2 := SkateRental.new()
	r2.setup({"staff": 0, "seed": 4})
	r2.enqueue(PeopleArt.random_look(r2.rng, 30, "stands"), 30, "A8")
	var begin := r2.player_begin()
	if str(begin.get("size", "")) != "A8" or not r2.player_grab("A8"):
		_fail("rental: the owner asks the size and grabs the pair (%s)" % str(begin))
	var handed := r2.player_hand()
	if str(handed.get("got", "")) != "A8":
		_fail("rental: the owner hands over the right pair (%s)" % str(handed))
	r.free()
	r2.free()


func _check_return_pile() -> void:
	var r := SkateRental.new()
	r.setup({"staff": 0, "seed": 3})
	for i in 6:
		r.return_pair({"size": "A%d" % (5 + i), "sharp": 0.7, "clean": 0.7}, PeopleArt.random_look(r.rng, 30, "stands"), 30)
	var tt := 0.0
	while tt < 40.0:
		r.step(DT)
		tt += DT
	var piled := r.pile.size()
	if piled != 6:
		_fail("rental: returns pile up on the counter with nobody to put them away (%d)" % piled)
	r.add_clerk()
	r.add_clerk()
	tt = 0.0
	while tt < 90.0 and not r.pile.is_empty():
		r.step(DT)
		tt += DT
	if r.pile.size() >= piled:
		_fail("rental: free clerks put the pile away (%d left)" % r.pile.size())
	# the return rack: returns never hit the counter
	var r2 := SkateRental.new()
	r2.setup({"staff": 0, "seed": 3, "return_rack": true})
	for i in 4:
		r2.return_pair({"size": "A7", "sharp": 0.7, "clean": 0.7}, PeopleArt.random_look(r2.rng, 30, "stands"), 30)
	tt = 0.0
	while tt < 40.0:
		r2.step(DT)
		tt += DT
	if not r2.pile.is_empty() or r2.rack.size() != 4 or r2.stock("A7") < 4:
		_fail("rental: with the return rack, returns go straight back into stock (pile %d, rack %d)" % [r2.pile.size(), r2.rack.size()])
	print("returns: pile %d, %d after the clerks, rack %d" % [piled, r.pile.size(), r2.rack.size()])
	r.free()
	r2.free()


func _check_figure_ice() -> void:
	var ice := IceSlab.new()
	ice.surface_temp = -3.6
	var warm := OnIceFigure.ice_satisfaction(ice)
	ice.surface_temp = -6.5
	var cold := OnIceFigure.ice_satisfaction(ice)
	if not float(warm.score) > float(cold.score):
		_fail("figure skaters prefer warmer ice (%.2f vs %.2f)" % [warm.score, cold.score])
	var fr := OnIceFigure.flood_request()
	if int(fr.minute) != 285:
		_fail("figure: the heavy flood is at 04:45")
	# broomball grip: snowed up holds, a fresh flood doesn't
	ice.snow = 0.4
	var b := _make("broomball", {"ice": ice})
	var snowy := (b as OnIceBroomball).grip()
	b.free()
	ice.snow = 0.0
	var b2 := _make("broomball", {"ice": ice})
	var bare := (b2 as OnIceBroomball).grip()
	if not snowy > bare:
		_fail("broomball: snowed-up ice grips better than fresh ice (%.2f vs %.2f)" % [snowy, bare])
	b2.free()
