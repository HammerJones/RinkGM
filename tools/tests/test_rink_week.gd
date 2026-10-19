extends SceneTree
## M1, the vertical slice: plays the scripted first week at Millbrook from
## RinkSim.create_m1 and checks the milestone's "done when" line (docs/world/
## RINK_SIM.md section 8): both mini games change the sim (a good oil service
## prevents the Wednesday trip, a bad blade height shows on the ice), the
## minor hockey bid can be won or lost, the P&L adds up, the goals report
## truthfully, and a save mid-week plays on the same.
##   godot --headless --path . --script res://tools/tests/test_rink_week.gd

const WEEK := 7 * 24 * 60

var failures := 0


func _initialize() -> void:
	_check_start()
	_check_job_hours()
	var good := _play({})
	print("good week:   %s" % _summary(good))
	var no_oil := _play({"oil": "none"})
	print("no oil:      %s" % _summary(no_oil))
	var bad_oil := _play({"oil": "overfull"})
	print("overfull:    %s" % _summary(bad_oil))
	var loose := _play({"oil": "loose_plug"})
	print("loose plug:  %s" % _summary(loose))
	var deep := _play({"blade": 1.7})
	print("deep blade:  %s" % _summary(deep))
	var shallow := _play({"blade": 0.5})
	print("shallow:     %s" % _summary(shallow))
	var greedy := _play({"price": 182.0})
	print("greedy bid:  %s" % _summary(greedy))
	var lazy := _play({"floods": false, "blade": 1.7, "price": 165.0, "decide": false, "shave": false})
	print("bad ice:     %s" % _summary(lazy))

	# a good oil service prevents the Wednesday trip; none, or a bad one, causes it
	if _oil_trip(good) != {}:
		_fail("a good oil service should prevent the Wednesday trip: %s" % [good.trips])
	var t := _oil_trip(no_oil)
	if t.is_empty() or int(t.day) != 2 or int(t.minute) < 17 * 60:
		_fail("with no oil service, compressor 1 should trip on low oil pressure on Wednesday night: %s" % [no_oil.trips])
	if _oil_trip(bad_oil).is_empty() or int(_oil_trip(bad_oil).day) > 2:
		_fail("an overfull sight glass should still trip compressor 1 by Wednesday night: %s" % [bad_oil.trips])
	if _oil_trip(loose).is_empty() or int(_oil_trip(loose).day) > 2:
		_fail("a loose drain plug should empty the glass and trip it by Wednesday night: %s" % [loose.trips])

	# a bad blade height shows on the ice
	for b in [deep, shallow]:
		if _avg_rating(b) >= _avg_rating(good) - 2.0 or _flood_smooth(b) >= _flood_smooth(good) - 0.03:
			_fail("a blade at %.1f mm should show on the ice: rating %.1f vs %.1f, smoothness after a flood %.2f vs %.2f" % [
				b.doris.blade_height_mm, _avg_rating(b), _avg_rating(good), _flood_smooth(b), _flood_smooth(good)])

	# the minor hockey bid can be won and lost
	if _bid_state(good) != "won" or not good.contracts.has("minor_hockey"):
		_fail("good ice and a fair price should win the minor hockey slot: %s, rep %.1f" % [good.bids, good.ice_rep])
	if _bid_state(greedy) != "lost":
		_fail("a greedy price should lose to Harlow Falls: %s" % [greedy.bids])
	if _bid_state(lazy) != "lost" or lazy.ice_rep >= 50.0:
		_fail("bad ice should lose the bid on reputation: %s, rep %.1f" % [lazy.bids, lazy.ice_rep])
	if not _played_sunday(good):
		_fail("the won slot should put Minor Hockey on the ice Sunday morning")

	# the P&L adds up, and has real lines
	for s in [good, no_oil, bad_oil, loose, deep, shallow, greedy, lazy]:
		_check_pnl(s)
	var p := good.week_pnl(0)
	for line in ["electricity", "ice rental", "public skate", "insurance", "natural gas", "plant parts", "Doris parts"]:
		if not p.revenue.has(line) and not p.costs.has(line):
			_fail("the week's P&L should have a '%s' line: %s %s" % [line, p.revenue.keys(), p.costs.keys()])

	# the goals report what happened
	_check_goals(good, {"keep_bookings": true, "ice_under_40": true, "compressor_1": true, "minor_hockey_slot": true})
	_check_goals(lazy, {"ice_under_40": false, "compressor_1": false, "minor_hockey_slot": false})
	_check_goals(greedy, {"minor_hockey_slot": false})
	for s in [good, no_oil, lazy]:
		var kb := _goal(s, "keep_bookings")
		if bool(kb.done) != (s.cancelled_sessions == 0 and s.lost_contracts == 0):
			_fail("keep_bookings should be done exactly when nothing was cancelled (%d cancelled): %s" % [s.cancelled_sessions, kb])
		var ig := _goal(s, "ice_under_40")
		if s.ice.thickness_mm < 40.0 and not bool(ig.done):
			_fail("the ice is %.1f mm: the 40 mm goal should be done" % s.ice.thickness_mm)

	# the Tuesday game: free while the owner learns, three hours, a flood at the second intermission
	if good.games.size() != 1 or float(good.league.owed) != 0.0:
		_fail("the owner should have played the Tuesday game free: %s" % [good.games])
	var tue := _flood_at(good, 1, 22 * 60 + RinkSim.INTERMISSION_MIN)
	if tue.is_empty() or str(tue.crew) != "you" or not bool(tue.ok):
		_fail("the owner should flood the second intermission of their own game: %s" % [tue])
	var pre := _flood_at(good, 1, 22 * 60 - RinkSim.RESURFACE_LEAD_MIN)
	if pre.is_empty() or not bool(pre.ok):
		_fail("the pre-game flood should happen: %s" % [pre])
	if good.fatigue <= 0.0 and good.weekly_reports.is_empty():
		_fail("the week should leave a report")

	_check_save()
	if failures:
		printerr("test_rink_week: %d failure(s)" % failures)
	else:
		print("test_rink_week: ok")
	quit(1 if failures else 0)


## Monday 05:00 as the doc tells it.
func _check_start() -> void:
	var s := RinkSim.create_m1(1)
	if s.date_text() != "Mon 1 Sep, Year 1" or s.weekday() != 1 or s.minute != 300 or s.block() != "early":
		_fail("M1 should start Mon 1 Sep, Year 1 at 05:00 in the early block: %s %s" % [s.clock_text(), s.block()])
	if s.money != RinkSim.M1_START_CASH or s.ice.thickness_mm < 47.9 or s.ice.thickness_mm > 48.1:
		_fail("M1 starts with $8,000 and 48 mm of ice: $%.0f, %.1f mm" % [s.money, s.ice.thickness_mm])
	if s.ice.edge_lip_mm() < 11.0:
		_fail("the boards should be about 12 mm higher than centre: %.1f" % s.ice.edge_lip_mm())
	if s.bills.size() != 1 or float(s.bills[0].amount) != 11240.0 or s.pay_bill("hydro_aug"):
		_fail("the $11,240 electricity bill is on the desk, more than the cash: %s" % [s.bills])
	if not s.contracts.has("vbl_d") or not s.contracts.has("public_skate") or s.contracts.has("minor_hockey"):
		_fail("vbl_d and public_skate are signed, minor hockey isn't: %s" % [s.contracts.keys()])
	if s.bids.size() != 1 or str(s.bids[0].state) != "open" or str(s.bids[0].rival) != "Harlow Falls":
		_fail("the minor hockey bid should be open against Harlow Falls: %s" % [s.bids])
	if s.goals.size() != 4 or s.binder.is_empty():
		_fail("Gus's binder and the four goals: %d goals" % s.goals.size())
	if s.job("resurface").ok or s.doris.fault() != "won't start":
		_fail("Doris shouldn't start on Monday morning")
	if s.doris.fault() == "" or not s.job("doris_plugs", {"quality": 0.9}).ok or s.doris.fault() != "":
		_fail("new plugs and a freed choke should start Doris: %s" % s.doris.fault())
	if s.flood_crew(1, 3 * 60) != "" or s.flood_crew(1, 22 * 60 + 70) != "you":
		_fail("nobody floods at 03:00; the owner floods the Tuesday game")
	var tf := s.floods(1)
	var minutes: Array = []
	for f in tf:
		minutes.append(int(f.minute))
	if not 21 * 60 + 30 in minutes or not 23 * 60 + 10 in minutes:
		_fail("Tuesday's floods should include 21:30 and the 23:10 intermission: %s" % [minutes])
	var r := s.job("ice_check")
	if not r.ok or not r.readings.has("temp_centre") or str(r.readings.temp_centre.text) == "" or s.log_book.is_empty():
		_fail("the ice check should read the ice in words and log it: %s" % [r])
	if s.goals[0].done:
		_fail("no goal is done at 05:00")
	if not s.buy_instrument("ir_gun") or s.tools.ice_temp != 1:
		_fail("buying the IR gun")
	var r2 := s.job("ice_check")
	if r2.readings.temp_centre.text.contains("hard") or r2.readings.temp_centre.text.contains("right"):
		_fail("the IR gun should read numbers, not words: %s" % r2.readings.temp_centre.text)
	if not s.buy_instrument("refractometer") or s.tools.glycol_pct != 2:
		_fail("buying the refractometer")


## The UI's bug report: every job that goes ahead charges its hours.
func _check_job_hours() -> void:
	var s := RinkSim.create_m1(2)
	for spec in [["plant_round", {}, 0.5], ["ice_check", {}, 0.2], ["doris_plugs", {"quality": 1.0}, 0.4],
			["dump_snow", {}, 0.25], ["compressor_oil_top_up", {"compressor": 0}, 0.25], ["shave_ice", {}, 0.5],
			["compressor_oil_change", {"compressor": 0, "quality": 1.0}, 2.5], ["blade_change", {"height_mm": 1.0}, 1.0]]:
		var before := s.hours_left
		var r := s.job(spec[0], spec[1])
		if not r.ok or absf(before - s.hours_left - float(spec[2])) > 0.001:
			_fail("%s should cost %.2f owner hours: %.2f (%s)" % [spec[0], spec[2], before - s.hours_left, r.text])
	var before_m := s.money
	s.job("resurface")
	if absf(before_m - s.money - RinkSim.FLOOD_GAS) > 0.001:
		_fail("a flood should cost its gas and hot water")
	if not s.submit_bid("minor_hockey", 170.0) or s.bids[0].state != "submitted":
		_fail("submitting a bid")
	s.hours_left = 0.0
	if s.job("plant_round").ok or s.submit_bid("minor_hockey", 160.0):
		_fail("no hours, no job")


## Plays the week. opts: "oil" good/none/overfull/loose_plug, "blade" mm,
## "price" the bid, "floods" (Doris goes out), "shave" (work the thickness
## down), "decide" (the compressor 1 decision).
func _play(opts: Dictionary, s: RinkSim = null, until := WEEK) -> RinkSim:
	if s == null:
		s = RinkSim.create_m1(11)
		s.auto_resurface = bool(opts.get("floods", true))
	for a in _actions(opts):
		var t: int = a[0]
		if t < _now(s) or t >= until:
			continue
		s.advance(t - _now(s))
		_act(s, str(a[1]), opts)
	if _now(s) < until:
		s.advance(until - _now(s))
	return s


func _now(s: RinkSim) -> int:
	return s.day * 1440 + s.minute


func _actions(opts: Dictionary) -> Array:
	var out: Array = []
	for d in 7:
		var b := d * 1440
		out.append([b + 300, "morning"])
		out.append([b + 1440 + 15, "night"])  # after the late game
		if bool(opts.get("shave", true)) and d <= 4:
			out.append([b + 600, "shave"])
			out.append([b + 660, "shave"])
			out.append([b + 900, "shave"])
	out.append([300 + 15, "plugs"])
	out.append([330, "oil"])
	out.append([480, "blade"])
	out.append([540, "decide"])
	out.append([720, "edge"])
	out.append([2 * 1440 + 720, "edge"])
	out.append([4 * 1440 + 720, "edge"])
	out.append([3 * 1440 + 780, "bid"])
	out.append([2 * 1440, "game"])  # the Tuesday game ends at midnight
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return out


func _act(s: RinkSim, what: String, opts: Dictionary) -> void:
	match what:
		"morning":
			s.set_lights(true)
			for i in s.plant.compressors.size():
				if s.plant.compressors[i].tripped:
					s.job("reset_compressor", {"compressor": i})
					if s.plant.compressors[i].tripped or i == 0:
						s.job("compressor_oil_top_up", {"compressor": i, "oil_level": 0.5})
			s.job("plant_round")
			s.job("ice_check")
			s.job("dump_snow")
			if s.doris.fuel < 0.35:
				s.job("refuel_doris")
		"night":
			s.set_lights(false)
		"plugs":
			s.job("doris_plugs", {"quality": 0.9, "torque_ok": true, "cross_threaded": false})
		"oil":
			match str(opts.get("oil", "good")):
				"good":
					s.job("compressor_oil_change", {"compressor": 0, "quality": 0.95, "oil_level": 0.5, "filter_ok": true, "drain_plug_torque_ok": true})
				"none":
					s.job("compressor_oil_top_up", {"compressor": 0, "oil_level": 0.5})  # Gus's tiny job, not a service
				"overfull":
					s.job("compressor_oil_change", {"compressor": 0, "quality": 0.95, "oil_level": 1.0, "filter_ok": true, "drain_plug_torque_ok": true})
				"loose_plug":
					s.job("compressor_oil_change", {"compressor": 0, "quality": 0.95, "oil_level": 0.5, "filter_ok": true, "drain_plug_torque_ok": false})
		"blade":
			s.job("blade_change", {"height_mm": float(opts.get("blade", 1.0)), "quality": 0.9, "bolts_ok": true})
		"decide":
			if bool(opts.get("decide", true)):
				s.decide_compressor_1("nurse")
		"shave":
			s.job("shave_ice")
			if s.snow_pit > 0.6:
				s.job("dump_snow")
		"edge":
			if bool(opts.get("shave", true)):
				s.job("edge_ice", {"quality": 0.9})
		"bid":
			s.submit_bid("minor_hockey", float(opts.get("price", 165.0)))
		"game":
			s.owner_played_game(120)


func _oil_trip(s: RinkSim) -> Dictionary:
	for t in s.trips:
		if int(t.compressor) == 0 and str(t.reason) == "low oil pressure":
			return t
	return {}


func _avg_rating(s: RinkSim) -> float:
	var t := 0.0
	var n := 0
	for e in s.session_log:
		for k in ["rating", "mid_rating"]:
			if float(e[k]) >= 0.0:
				t += float(e[k])
				n += 1
	return t / maxf(n, 1.0)


## How smooth the ice is just after each flood, from Monday's blade change on.
func _flood_smooth(s: RinkSim) -> float:
	var t := 0.0
	var n := 0
	for f in s.flood_log:
		if f.has("smooth_after") and int(f.day) * 1440 + int(f.minute) > 480:
			t += float(f.smooth_after)
			n += 1
	return t / maxf(n, 1.0)


func _bid_state(s: RinkSim) -> String:
	return str(s.bids[0].state)


func _played_sunday(s: RinkSim) -> bool:
	for e in s.session_log:
		if str(e.org) == "minor_hockey" and int(e.day) == 6 and not bool(e.cancelled):
			return true
	return false


func _flood_at(s: RinkSim, d: int, m: int) -> Dictionary:
	for f in s.flood_log:
		if int(f.day) == d and int(f.minute) == m:
			return f
	return {}


func _goal(s: RinkSim, id: String) -> Dictionary:
	for g in s.goals:
		if g.id == id:
			return g
	return {}


func _check_goals(s: RinkSim, want: Dictionary) -> void:
	for id in want:
		var g := _goal(s, id)
		if bool(g.get("done", false)) != bool(want[id]):
			_fail("goal %s should be %s: %s" % [id, "done" if want[id] else "not done", g])


## Every dollar that moved is on a line: the lines sum to the change in cash,
## day by day and for the week.
func _check_pnl(s: RinkSim) -> void:
	var total := 0.0
	for b in s.books:
		var day_sum := 0.0
		for k in b.ledger:
			day_sum += float(b.ledger[k])
		if absf(day_sum - (float(b.money_end) - float(b.money_start))) > 0.01:
			_fail("day %d: the lines sum to %.2f but the cash moved %.2f" % [b.day, day_sum, float(b.money_end) - float(b.money_start)])
		total += day_sum
	for k in s.ledger:
		total += float(s.ledger[k])
	if absf(total - (s.money - RinkSim.M1_START_CASH)) > 0.01:
		_fail("the ledger sums to %.2f but the cash moved %.2f" % [total, s.money - RinkSim.M1_START_CASH])
	var p := s.week_pnl(0)
	if absf(float(p.net) - (float(p.money_end) - float(p.money_start))) > 0.01 or absf(float(p.money_start) - RinkSim.M1_START_CASH) > 0.01:
		_fail("the week's P&L net %.2f should equal the cash change %.2f from $8,000" % [p.net, float(p.money_end) - float(p.money_start)])


## Saved on Wednesday at noon, reloaded through JSON, the week plays on the same.
func _check_save() -> void:
	var a := _play({}, null, 2 * 1440 + 720)
	var d: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict(), "", true, true))
	var b := RinkSim.from_dict(d)
	if b.mode != "m1" or b.start_weekday != 1 or b.date_text() != a.date_text() or b.goals.size() != 4 \
			or b.bids.size() != 1 or absf(b.ice.thickness_mm - a.ice.thickness_mm) > 1e-6 or b.log_book.size() != a.log_book.size():
		_fail("the save should carry the M1 state: %s vs %s, %s %d %s %d %d %.4f/%.4f %d/%d" % [b.clock_text(), a.clock_text(), b.mode, b.start_weekday,
			b.date_text(), b.goals.size(), b.bids.size(), b.ice.thickness_mm, a.ice.thickness_mm, b.log_book.size(), a.log_book.size()])
	_play({}, a)
	_play({}, b)
	if a.day != b.day or a.minute != b.minute or absf(a.money - b.money) > 1.0 \
			or absf(a.ice.thickness_mm - b.ice.thickness_mm) > 0.05 or absf(a.ice_rep - b.ice_rep) > 0.2 \
			or a.trips.size() != b.trips.size() or _bid_state(a) != _bid_state(b) or absf(a.fatigue - b.fatigue) > 0.5:
		_fail("a reloaded save should play on like the original: $%.2f vs $%.2f, %.2f vs %.2f mm, rep %.2f vs %.2f, trips %d vs %d, bid %s vs %s" % [
			a.money, b.money, a.ice.thickness_mm, b.ice.thickness_mm, a.ice_rep, b.ice_rep, a.trips.size(), b.trips.size(), _bid_state(a), _bid_state(b)])
	for i in a.goals.size():
		if bool(a.goals[i].done) != bool(b.goals[i].done):
			_fail("goal %s differs after a reload" % a.goals[i].id)


func _summary(s: RinkSim) -> String:
	var p := s.week_pnl(0)
	var gd: Array = []
	for g in s.goals:
		gd.append("%s=%s" % [g.id, "done" if g.done else ("missed" if g.failed else "open")])
	return "fsmooth %.2f, rating %.0f, rep %.1f, %.1f mm, smooth %.2f, trips %s, bid %s, net $%.0f (rev %.0f, cost %.0f), fatigue %.0f, pit %.2f, goals %s" % [
		_flood_smooth(s), _avg_rating(s), s.ice_rep, s.ice.thickness_mm, s.ice.felt_smoothness(), s.trips, _bid_state(s), p.net, p.total_revenue, p.total_costs,
		s.fatigue, s.snow_pit, gd]


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
