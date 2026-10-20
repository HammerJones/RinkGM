extends SceneTree
## Headless checks of running the rink's ice: league rules per level, the
## schedule (#42: the event list, criteria, selling and moving slots), and
## the between-session chores (#18 scoreboard, #19 nets, the scorekeeper).
##
##   godot --headless --path . --script tools/tests/test_rink_ops.gd

var failures := 0


func _init() -> void:
	_rules()
	_schedule()
	_ops()
	_season_ties()
	_scorekeeping()
	print("rink ops: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _rules() -> void:
	var bl := LeagueRules.for_tier(0)
	var pro := LeagueRules.for_tier(5)
	_expect(bl.clock == "running" and pro.clock == "stop", "beer league runs the clock, pro stops it")
	# a 20-minute beer league period: running until the last minute, the last 3 in the third
	_expect(LeagueRules.clock_runs_in_stoppage(bl, 300.0, 1200.0, false, false, 0), "running time mid-period")
	_expect(not LeagueRules.clock_runs_in_stoppage(bl, 50.0, 1200.0, false, false, 0), "stop time in the last minute")
	_expect(not LeagueRules.clock_runs_in_stoppage(bl, 150.0, 1200.0, true, false, 0), "stop time in the last 3 of the third")
	_expect(LeagueRules.clock_runs_in_stoppage(bl, 150.0, 1200.0, true, false, 5), "a five-goal lead keeps it running")
	_expect(LeagueRules.clock_runs_in_stoppage(bl, 20.0, 300.0, false, false, 0) and not LeagueRules.clock_runs_in_stoppage(bl, 10.0, 300.0, false, false, 0),
		"the window scales to a 5-minute period (15 s)")
	_expect(not LeagueRules.clock_runs_in_stoppage(pro, 600.0, 1200.0, false, false, 0), "pro never runs time")
	_expect(LeagueRules.after_tie(bl, false, false) == "tie", "beer league ties stand in the regular season")
	_expect(LeagueRules.after_tie(bl, true, false) == "overtime" and LeagueRules.after_tie(bl, true, true) == "shootout", "beer league playoffs: OT then a shootout")
	_expect(LeagueRules.after_tie(pro, false, false) == "overtime" and LeagueRules.after_tie(pro, false, true) == "shootout", "pro regular season: OT then a shootout")
	_expect(LeagueRules.after_tie(pro, true, true) == "overtime", "pro playoffs: sudden death until someone scores")
	_expect(LeagueRules.after_tie({}, false, false) == "overtime" and LeagueRules.after_tie({}, false, true) == "shootout", "no rules: the old behaviour")
	_expect(LeagueRules.describe(LeagueRules.SENIOR).contains("body checking"), "the rules describe themselves")


func _schedule() -> void:
	var sim := RinkSim.create_m1(4)
	var sch := sim.schedule
	# day 1 is a Tuesday: the owner's beer league game at 22:00
	var tue := sch.bookings(sim, 1)
	var bl: Dictionary = {}
	for b in tue:
		if b.org == "vbl_d":
			bl = b
	_expect(not bl.is_empty() and bl.kind == "beer_league_game" and float(bl.start) == 22.0, "the schedule shows the contracts' slots")
	_expect(sim.sessions(1).size() == tue.size(), "the sim's sessions come from the schedule")
	# the empty weekday daytime: noon shinny, parent-and-tot, school trips
	var ideas := sch.suggestions(sim, 1)
	var kinds := ideas.map(func(x: Dictionary) -> String: return x.kind)
	_expect(kinds.has("noon_shinny") and not kinds.has("school_skate"), "weekday daytime has things to sell: %s" % [kinds])
	_expect(EventCatalog.criteria_problem("school_skate", 2, 10.0, 1.5, 45.0, 6.0).contains("rooms"), "schools want decent rooms first")
	_expect(EventCatalog.criteria_problem("parent_tot", 2, 10.0, 1.0, 45.0, 40.0) == "", "with better rooms the parents come")
	_expect(RinkSchedule.gap_text().contains("08:00 to 16:00"), "the office can explain the blank weekday")
	# criteria: a school trip on a Saturday, pro practice with bad ice, a clash
	_expect(sch.sell(sim, "school_skate", 5, 10.0) != "", "no school trips on a Saturday")
	_expect(sch.sell(sim, "public_skate", 1, 21.5) != "", "nothing that clashes with the game and its flood")
	_expect(EventCatalog.criteria_problem("pro_practice", 2, 10.0, 2.0, 40.0, 40.0).contains("ice isn't good enough"), "pro teams want better ice")
	var money0 := sim.money
	_expect(sch.sell(sim, "noon_shinny", 1, 12.0) == "", "noon shinny sells into Tuesday's daytime")
	var sale: Dictionary = {}
	for b in sim.sessions(1):
		if b.kind == "noon_shinny":
			sale = b
	_expect(not sale.is_empty() and sale.sale and float(sale.rate) == 0.0 and float(sale.per_head) > 0.0, "the sale is on the ice schedule")
	_expect(EventCatalog.rate("private_rental", 2, 10.0) < EventCatalog.rate("private_rental", 2, 19.0), "non-prime ice sells cheaper")
	_expect(EventCatalog.expected_heads("public_skate", 6, 13.0, 360) > EventCatalog.expected_heads("public_skate", 2, 10.0, 300) * 3.0, "Christmas Saturday afternoons are busy, weekday mornings aren't")
	# run the sim through the sale: it starts and earns
	sim.advance(int((24 + 13) * 60 - sim.minute))
	_expect(sim.money != money0 and sim.session_log.any(func(e: Dictionary) -> bool: return str(e.org).begins_with("sale:")), "the sale runs and books revenue")
	# move the owner's game an hour later, then cancel it
	var sat0 := float(sim.contracts.vbl_d.satisfaction)
	var key := RinkSchedule.key_of("vbl_d", 8, 22.0)
	_expect(sch.move(sim, key, 8, 8, 21.0) == "", "the beer league game moves an hour earlier")
	var moved: Dictionary = sch.find(sim, key, 8)
	_expect(not moved.is_empty() and float(moved.start) == 21.0, "it shows at the new time")
	_expect(float(sim.contracts.vbl_d.satisfaction) < sat0, "and the league notices")
	_expect(sch.move(sim, key, 8, 8, 9.0) != "", "but beer league won't play at 09:00 on a Tuesday")
	_expect(sch.cancel(sim, key, 8) == "" and sch.find(sim, key, 8).is_empty(), "the game cancels")
	var sch2 := RinkSchedule.from_dict(JSON.parse_string(JSON.stringify(sch.to_dict())))
	_expect(sch2.cancels.has(key) and sch2.sales.size() == sch.sales.size(), "the schedule saves and loads")
	var sim2 := RinkSim.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	_expect(sim2.schedule.cancels.has(key), "it saves with the sim")


func _ops() -> void:
	var ops := RinkOps.new()
	ops.auto = false
	var game := {"org": "vbl_d", "kind": "beer_league_game", "start": 22.0, "hours": 2.0}
	var practice := {"org": "high_school", "kind": "high_school_practice", "start": 15.5, "hours": 1.5}
	_expect(RinkOps.needs(game).board == "game" and RinkOps.needs(practice).board == "clock", "games want the score, practices the clock")
	_expect((RinkOps.needs({"org": "minor_hockey"}).nets as Array) == [2, 6] and RinkOps.needs({"org": "minor_hockey"}).pads, "cross-ice minor hockey wants mini nets and pads")
	ops.board = "game"
	ops.set_nets(2, 0)
	var r := ops.on_session_start(game, 1)
	_expect(float(r.satisfaction) == 0.0, "a game with the board and nets ready starts clean")
	r = ops.on_session_start(practice, 1)
	_expect(float(r.satisfaction) >= RinkOps.WRONG_BOARD and ops.late_minutes > 0, "game mode on a practice: they overstay")
	r = ops.on_session_start(game, 1)
	_expect(str(r.notes).contains("late"), "the next booking starts late")
	ops.set_nets(0, 0)
	ops.board = "game"
	var helps := RinkOps.coach_helps("vbl_d")
	r = ops.on_session_start(game, 2)
	_expect(helps == str(r.notes).contains("skated the nets"), "nice coaches fetch their own nets")
	_expect(ops.nets_on == [2, 0], "either way the nets end up on the ice")
	# the scorekeeper volunteers for a week
	r = ops.on_session_start(game, RinkOps.VOLUNTEER_DAYS)
	_expect(ops.asked_for_pay and ops.scorekeeper == "none" and float(r.satisfaction) >= RinkOps.NO_SCOREKEEPER, "after a week the volunteer wants paying")
	ops.pay_scorekeeper()
	r = ops.on_session_start(game, RinkOps.VOLUNTEER_DAYS + 1)
	_expect(float(r.cost) == RinkOps.SCOREKEEPER_PAY, "paid scorekeeping costs per game")
	# fast-forward: the owner does the chores for owner hours
	var auto := RinkOps.new()
	r = auto.on_session_start(practice, 0)
	_expect(float(r.satisfaction) == 0.0 and float(r.hours) > 0.0 and auto.board == "clock", "auto setup costs hours, not customers")
	_expect(RinkOps.from_dict(JSON.parse_string(JSON.stringify(ops.to_dict()))).scorekeeper == "paid", "ops save and load")


func _season_ties() -> void:
	var s := Season.new()
	s.standings = {1: {"gp": 0, "w": 0, "l": 0, "otl": 0, "t": 0, "pts": 0, "gf": 0, "ga": 0},
		2: {"gp": 0, "w": 0, "l": 0, "otl": 0, "pts": 0, "gf": 0, "ga": 0}}
	s.record({"home": 1, "away": 2}, {"hg": 3, "ag": 3, "ot": false, "so": false})
	_expect(int(s.standings[1].t) == 1 and int(s.standings[2].t) == 1 and int(s.standings[1].pts) == 1, "a tie is a point each")
	var rng := RandomNumberGenerator.new()
	var c := Career.new_career("Tie", "Test", "C", 2)
	var ties := 0
	for i in 200:
		rng.seed = i
		var lu: Dictionary = c.lineup_for(c.user_team())
		var res := QuickSim.simulate(1, 2, lu, lu, c.settings, false, rng, LeagueRules.for_tier(0))
		if res.hg == res.ag:
			ties += 1
			_expect(not res.ot and not res.so, "a beer league tie has no OT or shootout")
	_expect(ties > 0, "beer league sim games can end tied (%d of 200)" % ties)


func _scorekeeping() -> void:
	var g := Scorekeeping.create(11, [4, 9, 17, 22, 30], [3, 8, 12, 19, 27])
	_expect(g.calls.size() == Scorekeeping.CALLS, "a game deals %d calls" % Scorekeeping.CALLS)
	var right := 0
	for i in g.calls.size():
		var c: Dictionary = g.calls[i]
		_expect(g.call_text(i).contains(str(c.scorer if c.kind == "goal" else c.player)), "the ref names the number: %s" % g.call_text(i))
		var sheet := {"team": c.team}
		if c.kind == "goal":
			sheet.scorer = c.scorer
			sheet.assists = c.assists.duplicate()
		else:
			sheet.merge({"player": c.player, "minutes": c.minutes, "clock_start": float(c.whistle) + 0.5})
		if i == 0:
			sheet.team = "away" if c.team == "home" else "home"  # one slip
		if g.check(i, sheet).ok:
			right += 1
	_expect(right == g.calls.size() - 1, "a correct sheet checks out, the slip doesn't")
	_expect(is_equal_approx(float(g.result().quality), float(right) / g.calls.size()), "the quality is the share of clean calls")
	for i in g.calls.size():
		if g.calls[i].kind == "penalty":
			var c: Dictionary = g.calls[i]
			var early := g.check(i, {"team": c.team, "player": c.player, "minutes": c.minutes, "clock_start": 0.5})
			_expect(not early.ok and str(early.errors).contains("before the whistle"), "starting the clock before the whistle is wrong")
			break
	# keeping score for the game on the ice moves the league's mood
	var sim := RinkSim.create_m1(4)
	sim.advance(int((24 + 22) * 60 + 30 - sim.minute))  # Tuesday 22:30, mid-game
	var before := float(sim.contracts.vbl_d.satisfaction)
	_expect(sim.ops.sheet_kept(sim, 1.0) != "" and float(sim.contracts.vbl_d.satisfaction) > before, "a clean sheet pleases the league")
	sim.advance(120)
	_expect(sim.ops.sheet_kept(sim, 1.0) == "", "with no game on it's practice")
