extends Control
## The rink office computer: the ice grid, the schedule (sell, move and
## cancel ice, the event list, the between-session chores), the plant log
## book, the week's P&L, the job queue and Gus's corkboard, as RINK-OS screens (see
## assets/ui/STYLE.md). Reads the sim only through OfficeData.
##
## Uses the career's rink when there is one (CareerState.rink, a RinkLink:
## time goes through it so the career's calendar keeps up, and it stops for
## the owner's own Beer League game), otherwise a demo sim at the start of M1
## played to Wednesday afternoon.
## `-- --tab=grid|sched|log|pl|jobs|board` opens a screen;
## `-- --owner` starts a fresh owner career (unsaved) when none is running;
## `-- --screenshot=out.png` saves a frame and quits.

const TABS := [["grid", "Ice grid"], ["sched", "Schedule"], ["log", "Log book"], ["pl", "P&L"], ["jobs", "Jobs"], ["board", "Corkboard"]]
const NOTE := Color("f2d16b")   ## sticky note paper
const CORK := Color("4a3424")   ## the corkboard
const INK := Color("2a1d08")    ## Gus's pencil

var sim: RinkSim
var rink: RinkLink  ## null in the standalone demo
var tab := "grid"
var _hud: FootHud
var _tabs: HBoxContainer
var _actions: HBoxContainer
var _title: Label
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	sim = _find_sim()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tab="):
			tab = a.trim_prefix("--tab=")
	var bg := ColorRect.new()
	bg.color = RinkOS.CRT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	page.add_child(RinkOS.label(RinkOS.rule("rink-os 3.0 // office // millbrook community arena", 120), RinkOS.TERM_DIM))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	top.add_child(left)
	_title = RinkOS.label("", RinkOS.TITLE)
	left.add_child(_title)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 32)
	left.add_child(bar)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	bar.add_child(_tabs)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	bar.add_child(_actions)
	_hud = FootHud.new()
	top.add_child(_hud)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)

	_refresh()
	RinkOS.capture_from_args(self)


func _find_sim() -> RinkSim:
	if CareerState.rink == null and "--owner" in OS.get_cmdline_user_args():
		CareerState.rink = RinkLink.new_owner("Test", "Owner", "C", 7)
		CareerState.career = CareerState.rink.career
	rink = CareerState.rink
	return rink.sim if rink else OfficeData.demo_sim()


## Runs the clock to the start of the next block (stopping for the owner's
## game, which sends them back to the hub to play it).
func _next_block() -> void:
	var m := OfficeData.minutes_to_next_block(sim.minute)
	if rink:
		if rink.advance(m):
			_leave()
			return
	else:
		sim.advance(m)
	_refresh()


func _walk() -> void:
	CareerState.career.save()
	CareerState.open_walk()


func _leave() -> void:
	if rink:
		CareerState.career.save()
		CareerState.back_to_hub()


func open(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	_hud.show_sim(sim)
	for c in _tabs.get_children():
		c.queue_free()
	for t in TABS:
		var b := RinkOS.button(t[1], t[0] == tab)
		b.pressed.connect(open.bind(t[0]))
		_tabs.add_child(b)
	for c in _actions.get_children():
		c.queue_free()
	if rink and rink.game_due():
		_actions.add_child(_btn("To the game", _leave))
	else:
		_actions.add_child(_btn("Next block", _next_block, false))
	if float(sim.league.owed) > 0.0:
		_actions.add_child(_btn("Pay dues $%d" % int(sim.league.owed), func():
			sim.pay_dues()
			_refresh(), false))
	if rink:
		_actions.add_child(_btn("Walk the rink", _walk, false))
		_actions.add_child(_btn("Hub", _leave, false))
	for c in _body.get_children():
		c.queue_free()
	match tab:
		"log": _show_log()
		"pl": _show_pl()
		"jobs": _show_jobs()
		"sched": _show_schedule()
		"board": _show_board()
		_: _show_grid()


# ------------------------------------------------------------------ ice grid

func _show_grid() -> void:
	_title.text = "Ice grid // week %d" % OfficeData.week_number(sim)
	var panel := PanelContainer.new()
	_body.add_child(panel)
	var grid := IceGridView.new()
	grid.show_sim(sim)
	panel.add_child(grid)

	var row := _row(_body, 16)
	var legend := _section(row, "key", 52)
	var k := _term()
	k.text = "\n".join([
		"%s hockey   %s public skate   %s figure" % [_swatch(RinkOS.READOUT), _swatch(RinkOS.GOOD), _swatch(RinkOS.TEXT)],
		"%s flood, you   %s flood, nobody free   %s open bid" % [_swatch(RinkOS.BEZEL.lightened(0.2)), _swatch(RinkOS.ALERT), _c(RinkOS.ACTION, "[--]")],
		"%s prime   %s shoulder   %s dead time" % [_swatch(IceGridView.CLASS_FILL.prime.lightened(0.25)),
			_swatch(IceGridView.CLASS_FILL.shoulder.lightened(0.25)), _swatch(IceGridView.CLASS_FILL.dead.lightened(0.25))],
	])
	legend.add_child(k)
	var s := OfficeData.grid_summary(sim)
	var week := _section(row, "this week", 52)
	var t := _term()
	var lines := []
	for cls in ["prime", "shoulder", "dead"]:
		lines.append(RinkOS.dots(cls, "%s booked  %s free" % [_c(RinkOS.READOUT, "%4.1fh" % s.booked[cls]), _c(RinkOS.DIM, "%4.1fh" % s.free[cls])], 10))
	lines.append(RinkOS.dots("floods", _c(RinkOS.READOUT, str(s.floods)) + ("  " + _c(RinkOS.ALERT, "%d unstaffed" % s.unstaffed) if s.unstaffed > 0 else ""), 10))
	lines.append(RinkOS.dots("rentals", _c(RinkOS.READOUT, "$" + FootHud._money(s.income)) + " a week", 10))
	t.text = "\n".join(lines)
	week.add_child(t)


func _swatch(col: Color) -> String:
	return _c(col, "##")


# ------------------------------------------------------------------ schedule

## The day the schedule screen shows (sim day), -1 for today.
var _sched_day := -1
var _sched_msg := ""


func _show_schedule() -> void:
	var sch := sim.schedule
	var d := sim.day if _sched_day < sim.day else _sched_day
	_title.text = "Schedule // %s" % sim.date_text(d)
	var days := _row(_body, 8)
	for i in 7:
		var dd := sim.day + i
		var b := RinkOS.button("%s %d" % [RinkSim.DAY_NAMES[sim.weekday_of(dd)], int(sim.date_of(dd).dom)], dd == d)
		b.pressed.connect(func():
			_sched_day = dd
			_sched_msg = ""
			_refresh())
		days.add_child(b)
	if _sched_msg != "":
		var m := RinkOS.label("> " + _sched_msg, RinkOS.TERM)
		m.add_theme_color_override("font_color", RinkOS.READOUT)
		_body.add_child(m)

	var row := _row(_body, 16)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(720, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var booked := _section(left, "on the ice", 70)
	var list := sch.bookings(sim, d)
	if list.is_empty():
		booked.add_child(_cell("nothing booked", RinkOS.DIM))
	for b in list:
		var r := _row(booked, 8)
		var need := RinkOps.needs(b)
		var what := "%s  %s" % [_hhmm(float(b.start)), RinkSchedule._name(b)]
		if b.has("moved_from"):
			what += "  (moved)"
		var l := _cell(what, RinkOS.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(_cell("%s, nets %d+%d%s" % [need.board, need.nets[0], need.nets[1], ", scorer" if need.scorekeeper else ""], RinkOS.DIM))
		for step in [-1.0, 1.0]:
			r.add_child(_btn("-1h" if step < 0.0 else "+1h", _sched_do.bind(func(): return sch.move(sim, b.key, d, d, float(b.start) + step)), false))
		r.add_child(_btn("Cancel", _sched_do.bind(func(): return sch.cancel(sim, b.key, d)), false))

	var sell := _section(left, "open ice to sell", 70)
	var wd := sim.weekday_of(d)
	if not EventCatalog.is_weekend(wd):
		var gap := RinkOS.label(RinkSchedule.gap_text(), RinkOS.TERM_DIM)
		gap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gap.custom_minimum_size = Vector2(680, 0)
		sell.add_child(gap)
	var ideas := sch.suggestions(sim, d)
	if ideas.is_empty():
		sell.add_child(_cell("nothing fits the open ice that day", RinkOS.DIM))
	for idea in ideas.slice(0, 8):
		var r := _row(sell, 8)
		var l := _cell("%s  %s" % [_hhmm(float(idea.start)), idea.name], RinkOS.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(_cell("about $%d%s" % [int(idea.revenue), "" if idea.prime else ", non-prime"], RinkOS.DIM))
		r.add_child(_btn("Sell", _sched_do.bind(func(): return sch.sell(sim, idea.kind, d, float(idea.start)))))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(500, 0)
	row.add_child(right)
	_show_ops(right)
	var events := _section(right, "event list", 44)
	var t := _term()
	var lines := []
	for id in EventCatalog.KINDS:
		var k: Dictionary = EventCatalog.KINDS[id]
		var when := []
		for w in k.windows:
			when.append("%s %s-%s" % [w[0], _hhmm(float(w[1])), _hhmm(float(w[2]))])
		var wants := []
		if float(k.min_ice) > 0.0:
			wants.append("ice %d" % int(k.min_ice))
		if float(k.min_rooms) > 0.0:
			wants.append("rooms %d" % int(k.min_rooms))
		lines.append("%s %s" % [_c(RinkOS.ACTION if k.get("sell", false) else RinkOS.TEXT, str(k.name)), _c(RinkOS.DIM, "%s; %sh%s" % [", ".join(when), str(k.hours), ("; " + ", ".join(wants)) if not wants.is_empty() else ""])])
	t.text = "\n".join(lines)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 0)
	events.add_child(t)


## The between-session chores: setup, the scoreboard, the nets, the scorekeeper.
func _show_ops(parent: Control) -> void:
	var ops := sim.ops
	var box := _section(parent, "between sessions", 44)
	var t := _term()
	var keeper := {"volunteer": "%s, volunteering" % RinkOps.SCOREKEEPER_NAME, "paid": "%s, $%d a game" % [RinkOps.SCOREKEEPER_NAME, int(RinkOps.SCOREKEEPER_PAY)],
		"owner": "you keep score", "none": _c(RinkOS.ALERT, "nobody")}
	t.text = "\n".join([
		RinkOS.dots("setup", "you do it, %d min a change" % RinkOps.SETUP_MIN if ops.auto else "by hand in the walk", 14),
		RinkOS.dots("scoreboard", ops.board, 14),
		RinkOS.dots("nets out", "%d large, %d small" % [ops.nets_on[0], ops.nets_on[1]], 14),
		RinkOS.dots("scorekeeper", keeper.get(ops.scorekeeper, ops.scorekeeper), 14),
		RinkOS.dots("league rules", LeagueRules.describe(LeagueRules.BEER_LEAGUE).get_slice(":", 1).strip_edges(), 14)])
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 0)
	box.add_child(t)
	var r := _row(box, 8)
	r.add_child(_btn("Setup: %s" % ("auto" if ops.auto else "by hand"), func():
		ops.auto = not ops.auto
		_refresh(), false))
	if ops.scorekeeper != "paid":
		r.add_child(_btn("Pay %s" % RinkOps.SCOREKEEPER_NAME.get_slice(" ", 0), func():
			ops.pay_scorekeeper()
			_refresh(), ops.asked_for_pay))
	if ops.scorekeeper != "owner":
		r.add_child(_btn("Keep score", func():
			ops.keep_score_yourself()
			_refresh(), false))


func _sched_do(action: Callable) -> void:
	var why: String = action.call()
	_sched_msg = why if why != "" else "Done."
	_refresh()


static func _hhmm(h: float) -> String:
	return RinkSchedule._hhmm(h)


# ------------------------------------------------------------------ log book

func _show_log() -> void:
	_title.text = "Plant log book"
	var cols := OfficeData.log_columns(sim)
	var box := _section(_body, "readings as written", 140)
	var g := GridContainer.new()
	g.columns = cols.size() + 1
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 2)
	box.add_child(g)
	g.add_child(_cell("DAY", RinkOS.DIM))
	for key in cols:
		g.add_child(_cell(OfficeData.column_title(key).to_upper(), RinkOS.DIM))
	var book := OfficeData.log_book(sim).filter(func(e): return e.readings.has("ice_temp") or e.readings.has("oil_1"))
	var recent: Array = book.slice(maxi(book.size() - 7, 0))
	for e in recent:
		g.add_child(_cell("%s %02d:%02d" % [OfficeData.day_name(sim, int(e.day)).to_upper(), int(e.minute) / 60, int(e.minute) % 60], RinkOS.TEXT))
		for key in cols:
			var r: Dictionary = e.readings.get(key, {})
			if r.is_empty():
				g.add_child(_cell("--", RinkOS.DIM))
				continue
			var shown := OfficeData.reading_text(OfficeData.reading_kind(key), r)
			g.add_child(_cell(shown.text, _word_color(shown.text, shown.fuzzy)))
	var ccols := OfficeData.compressor_columns(sim)
	var rounds: Array = recent.filter(func(e): return e.readings.has("oil_1"))
	if not rounds.is_empty() and not ccols.is_empty():
		box.add_child(RinkOS.label(RinkOS.rule("compressors", 60), RinkOS.TERM_DIM))
		var cg := GridContainer.new()
		cg.columns = ccols.size() + 2
		cg.add_theme_constant_override("h_separation", 24)
		cg.add_theme_constant_override("v_separation", 2)
		box.add_child(cg)
		cg.add_child(_cell("DAY", RinkOS.DIM))
		cg.add_child(_cell("#", RinkOS.DIM))
		for key in ccols:
			cg.add_child(_cell(OfficeData.column_title(key).to_upper(), RinkOS.DIM))
		for e in rounds.slice(maxi(rounds.size() - 3, 0)):
			for i in sim.plant.compressors.size():
				cg.add_child(_cell("%s %02d:%02d" % [OfficeData.day_name(sim, int(e.day)).to_upper(), int(e.minute) / 60, int(e.minute) % 60], RinkOS.TEXT if i == 0 else RinkOS.DIM))
				cg.add_child(_cell(str(i + 1), RinkOS.READOUT))
				for key in ccols:
					var r: Dictionary = e.readings.get("%s_%d" % [key, i + 1], {})
					if r.is_empty():
						cg.add_child(_cell("--", RinkOS.DIM))
						continue
					var shown := OfficeData.reading_text(OfficeData.reading_kind("%s_%d" % [key, i + 1]), r)
					var col := _word_color(shown.text, shown.fuzzy)
					if key == "status":
						col = RinkOS.GOOD if shown.text == "running" else RinkOS.ALERT
					cg.add_child(_cell(shown.text, col))
	if book.is_empty():
		box.add_child(RinkOS.label("Nothing written yet. Gus: \"Every morning. Oil first. Number 1 drinks.\"", RinkOS.TERM_DIM))
	_row(box, 12).add_child(_btn("Take a plant round", func():
		OfficeData.plant_round(sim)
		_refresh()))

	var tools := _section(_body, "instruments", 140)
	var lines := []
	var buys := HFlowContainer.new()
	buys.add_theme_constant_override("h_separation", 8)
	buys.add_theme_constant_override("v_separation", 8)
	for kind in SimInstrument.CATALOG:
		var tiers := SimInstrument.tiers(kind)
		var have: int = sim.tools.get(kind, 0)
		var next := ""
		if have + 1 < tiers.size():
			var n: Dictionary = tiers[have + 1]
			next = "next: %s $%d" % [n.name, int(n.price)]
			if have == 0 and int(n.price) <= 200:
				var b := _btn("%s $%d" % [n.name, int(n.price)], func():
					sim.buy_tool(kind, have + 1)
					_refresh(), false)
				b.disabled = sim.money < float(n.price)
				buys.add_child(b)
		lines.append(RinkOS.dots(OfficeData.column_title(kind) if kind in cols else kind.replace("_", " "),
			"%s  %s" % [_c(RinkOS.READOUT if have > 0 else RinkOS.TEXT, tiers[have].name), _c(RinkOS.DIM, next)], 18))
	var t := _term()
	t.text = "\n".join(lines)
	tools.add_child(t)
	tools.add_child(RinkOS.label("Words until you buy a tool that gives a number. Every tool narrows the error.", RinkOS.TERM_DIM))
	tools.add_child(buys)


## Words that mean trouble read red, words that mean fine read green.
func _word_color(text: String, fuzzy: bool) -> Color:
	if not fuzzy:
		return RinkOS.READOUT
	for w in ["black", "knocking", "slush", "rock hard", "way too thick", "paper thin", "never tested", "low", "empty"]:
		if text.begins_with(w):
			return RinkOS.ALERT
	for w in ["clear", "sweet", "about right"]:
		if text.begins_with(w):
			return RinkOS.GOOD
	return RinkOS.TEXT


# ------------------------------------------------------------------ P&L

func _show_pl() -> void:
	_title.text = "Week %d P&L" % OfficeData.week_number(sim)
	var pl := OfficeData.week_pl(sim)
	var row := _row(_body, 16)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	var money := _section(left, "money in", 60)
	money.add_child(_lines(pl.revenue, RinkOS.GOOD, "+"))
	var out := _section(left, "money out", 60)
	out.add_child(_lines(pl.costs, RinkOS.ALERT, "-"))
	var tot := _section(left, "week so far", 60)
	var net: float = pl.total_in - pl.total_out
	var t := _term()
	t.text = "\n".join([
		RinkOS.dots("in", _c(RinkOS.GOOD, "+$" + FootHud._money(pl.total_in)), 24),
		RinkOS.dots("out", _c(RinkOS.ALERT, "-$" + FootHud._money(pl.total_out)), 24),
		RinkOS.dots("net", _c(RinkOS.GOOD if net >= 0.0 else RinkOS.ALERT, ("+$" if net >= 0.0 else "-$") + FootHud._money(absf(net))), 24),
		RinkOS.dots("in the bank", _c(RinkOS.READOUT, "$" + FootHud._money(sim.money)), 24),
	])
	tot.add_child(t)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var bill := OfficeData.power_bill(sim)
	var b := _section(right, "valley hydro // last month", 60)
	var big := RinkOS.label("$" + FootHud._money(bill.last), RinkOS.TERM_LARGE)
	big.add_theme_color_override("font_color", RinkOS.ALERT)
	b.add_child(big)
	var bt := _term()
	var pace := "not enough days yet" if bill.pace < 0.0 else _c(RinkOS.ALERT if bill.pace > bill.last * 0.9 else RinkOS.GOOD, "$" + FootHud._money(bill.pace) + " a month")
	bt.text = "\n".join([
		RinkOS.dots("this week", _c(RinkOS.READOUT, "%s kWh" % FootHud._money(bill.kwh)), 18),
		RinkOS.dots("at", _c(RinkOS.READOUT, "$%.2f/kWh" % bill.price), 18),
		RinkOS.dots("pace", pace, 18),
	])
	b.add_child(bt)
	var note := _sticky("Ice is too thick. Earl likes it thick. Earl doesn't pay the bill.  -G", 360)
	b.add_child(note)

	var days := _section(right, "by day", 60)
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 28)
	days.add_child(g)
	for h in ["DAY", "IN", "OUT", "KWH", "ICE"]:
		g.add_child(_cell(h, RinkOS.DIM))
	var start := OfficeData.week_start(sim)
	for e in sim.books:
		if int(e.day) < start:
			continue
		g.add_child(_cell(OfficeData.day_name(sim, int(e.day)).to_upper(), RinkOS.TEXT))
		g.add_child(_cell("+$" + FootHud._money(e.revenue), RinkOS.GOOD))
		g.add_child(_cell("-$" + FootHud._money(e.costs), RinkOS.ALERT))
		g.add_child(_cell(FootHud._money(e.kwh), RinkOS.READOUT))
		g.add_child(_cell("--" if float(e.ice) < 0.0 else "%d" % int(e.ice), RinkOS.READOUT))


func _lines(items: Array, col: Color, sign: String) -> RichTextLabel:
	var t := _term()
	var lines := []
	for it in items:
		lines.append(RinkOS.dots(it[0], _c(col, "%s$%s" % [sign, FootHud._money(it[1])]), 24))
	t.text = "\n".join(lines) if not lines.is_empty() else _c(RinkOS.DIM, "nothing yet")
	return t


# ------------------------------------------------------------------ jobs

func _show_jobs() -> void:
	_title.text = "Job queue"
	var row := _row(_body, 16)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(720, 0)
	row.add_child(left)

	var q := _section(left, "today", 64)
	var queue := OfficeData.job_queue(sim)
	var qh := OfficeData.queue_hours(sim)
	var t := _term()
	var lines := []
	var i := 0
	for j in queue:
		i += 1
		var spec: Dictionary = RinkSim.JOBS[j.id]
		lines.append("%s %s" % [_c(RinkOS.DIM, "%d." % i), RinkOS.dots(OfficeData.job_name(j.id) + _which(j), _job_cost(spec), 30)])
	if lines.is_empty():
		lines.append(_c(RinkOS.DIM, "nothing queued"))
	lines.append("")
	var over: bool = qh > sim.hours_left
	lines.append(RinkOS.dots("queued", _c(RinkOS.ALERT if over else RinkOS.READOUT, "%.1fh" % qh) + " of " + _c(RinkOS.READOUT, "%.1fh" % sim.hours_left) + " left", 30))
	t.text = "\n".join(lines)
	q.add_child(t)
	var qb := _row(q, 8)
	var run := _btn("Do next job", func():
		var r := OfficeData.run_next(sim)
		if not r.is_empty():
			_toast = r.text
		_refresh())
	run.disabled = queue.is_empty()
	qb.add_child(run)
	qb.add_child(_btn("Clear", func():
		queue.clear()
		_refresh(), false))
	if _toast != "":
		var l := RinkOS.label("> " + _toast, RinkOS.TERM)
		l.add_theme_color_override("font_color", RinkOS.READOUT)
		q.add_child(l)

	var sug := _section(left, "the log book says", 64)
	for s in OfficeData.suggestions(sim):
		var r := _row(sug, 12)
		var l := RinkOS.label(s.why, RinkOS.TERM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(_btn(OfficeData.job_name(s.id) + _which(s), _enqueue.bind(s.id, s.get("args", {}))))

	var done := _section(left, "done today", 64)
	var dt := _term()
	var dl := []
	for e in sim.events:
		if int(e.day) == sim.day:
			dl.append("%s %s" % [_c(RinkOS.DIM, "%02d:%02d" % [int(e.minute) / 60, int(e.minute) % 60]), e.text])
	dt.text = "\n".join(dl.slice(maxi(dl.size() - 6, 0))) if not dl.is_empty() else _c(RinkOS.DIM, "nothing yet")
	done.add_child(dt)

	var menu := _section(row, "jobs", 56)
	for j in OfficeData.job_menu():
		var r := _row(menu, 8)
		var l := RinkOS.label(RinkOS.dots(j.name, "%sh %s" % [str(j.hours), ("$%d" % int(j.cost)) if j.cost > 0.0 else ""], 26), RinkOS.TERM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var add := RinkOS.button("+", false)
		add.pressed.connect(_enqueue.bind(j.id, {}))
		r.add_child(add)

var _toast := ""


func _enqueue(id: String, args: Dictionary) -> void:
	OfficeData.job_queue(sim).append({"id": id, "args": args})
	_refresh()


func _which(j: Dictionary) -> String:
	return " #%d" % (int(j.args.compressor) + 1) if j.get("args", {}).has("compressor") else ""


func _job_cost(spec: Dictionary) -> String:
	var s := _c(RinkOS.READOUT, "%sh" % str(spec.hours))
	if float(spec.cost) > 0.0:
		s += " " + _c(RinkOS.ALERT, "$%d" % int(spec.cost))
	return s


# ------------------------------------------------------------------ corkboard

func _show_board() -> void:
	_title.text = "Gus's corkboard"
	var cork := PanelContainer.new()
	cork.add_theme_stylebox_override("panel", RinkOS.flat(CORK, 28))
	_body.add_child(cork)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	cork.add_child(v)
	var head := RinkOS.label(RinkOS.rule("this week", 40), RinkOS.TERM)
	head.add_theme_color_override("font_color", NOTE)
	v.add_child(head)
	var notes := HBoxContainer.new()
	notes.add_theme_constant_override("separation", 24)
	v.add_child(notes)
	var i := 0
	for g in OfficeData.goals(sim):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		notes.add_child(col)
		var n := _sticky(g.text, 300, 150)
		col.add_child(n)
		var status := RinkOS.label(("[x] " if g.done else "[ ] ") + g.status.to_upper(), RinkOS.TERM)
		status.add_theme_color_override("font_color", RinkOS.GOOD if g.done else (RinkOS.ALERT if g.get("failed", false) else NOTE))
		col.add_child(status)
		i += 1
	var foot := RinkOS.label("Gus: \"Take Mondays. I never did. Look at me.\"", RinkOS.TERM)
	foot.add_theme_color_override("font_color", NOTE.darkened(0.25))
	v.add_child(foot)


func _sticky(text: String, w := 300, h := 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := RinkOS.flat(NOTE, 16)
	sb.border_width_top = 10
	sb.border_color = NOTE.darkened(0.12)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, h)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := RinkOS.label(text, RinkOS.TERM)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w - 32, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.add_child(l)
	return p


# ------------------------------------------------------------------ helpers

func _section(parent: Control, title: String, width := 44) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := RinkOS.label(RinkOS.rule(title, width), RinkOS.TERM)
	head.add_theme_color_override("font_color", RinkOS.READOUT)
	v.add_child(head)
	return v


func _row(parent: Control, sep := 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", sep)
	if parent:
		parent.add_child(row)
	return row


func _term() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = "TermText"
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _cell(text: String, col: Color) -> Label:
	var l := RinkOS.label(text, RinkOS.TERM)
	l.add_theme_color_override("font_color", col)
	return l


func _btn(t: String, cb: Callable, primary := true) -> Button:
	var b := RinkOS.button(t, primary)
	b.pressed.connect(cb)
	return b


func _c(col: Color, t: String) -> String:
	return "[%s]%s[/color]" % [RinkOS.bb(col), t]
