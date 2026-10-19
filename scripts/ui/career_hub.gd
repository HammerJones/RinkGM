extends Control
## Career hub: create a player, see your ratings, team, standings and news,
## pick a training focus and game length, then play (or sim) the next game.
## In the offseason it lists tryout invitations. Drawn as RINK-OS screens
## (see rinkos.gd / assets/ui/STYLE.md): a system bar, a screen title, then
## framed panels with `// HEADER ----` rules and terminal text.
##
## The first screen picks a save slot: the open career or one of the two
## playtest demos (a low-tier season that leads to a mid-tier tryout, or a
## mid-tier season straight away).
##
## `-- --career --autoplay` plays games hands-off (headless testing);
## `-- --slot=demo_low|demo_mid|career|owner` skips the slot screen;
## `-- --career-new` throws away that slot's save and starts over.

var career: Career
var _root: VBoxContainer
var _auto := "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = RinkOS.CRT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_top = 24
	scroll.offset_right = -40
	scroll.offset_bottom = -24
	add_child(scroll)
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 16)
	scroll.add_child(_root)
	RinkOS.capture_from_args(self)
	var slot_arg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slot="):
			slot_arg = a.trim_prefix("--slot=")
	if CareerState.career != null:
		career = CareerState.career
		_refresh()
		return
	if slot_arg == "" and _auto:
		slot_arg = "career"
	if slot_arg != "" and Career.SLOTS.has(slot_arg):
		if "--career-new" in OS.get_cmdline_user_args():
			CareerState.delete_slot(slot_arg)
		_open_slot(slot_arg)
	else:
		_show_slots()


# ------------------------------------------------------------ save slots

func _show_slots() -> void:
	_clear()
	_title("Select save")
	_text("Pick a save. The demos are short playtest careers: they grow faster than a normal career so you can feel progression within a season or two.")
	for slot in Career.SLOTS:
		var info: Dictionary = Career.SLOTS[slot]
		var box := _section(_root, RinkOS.key(info.label.replace(":", "")), 60)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var summary: String = info.desc
		var has: bool = CareerState.has_save(slot)
		if has:
			var c := Career.load_from(CareerState.slot_path(slot))
			if c:
				var u := c.user()
				summary = "%s, %s. Season %d, %s, overall %.1f." % [u.full_name(), u.position, c.season_number, LeagueTiers.get_tier(c.tier).name, u.overall()]
		var b := _button("Continue" if has else "New", _open_slot.bind(slot))
		row.add_child(b)
		if has:
			row.add_child(_button("Start over", func():
				CareerState.delete_slot(slot)
				_open_slot(slot), false))
		var sum := _label(summary)
		sum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sum)
		if slot == "demo_low" and _root.get_child_count() > 0:
			b.grab_focus()
	var practice := _section(_root, "PRACTICE", 60)
	var prow := _row(practice)
	prow.add_child(_button("Practice", CareerState.start_practice, false))
	var pl := _label("Skate alone with a puck and the nets: no opponents, no clock, nothing recorded.")
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(pl)


func _open_slot(slot: String) -> void:
	CareerState.use_slot(slot)
	career = CareerState.load_or_null()
	if career == null:
		_show_new_career()
	else:
		_refresh()


# ------------------------------------------------------------ new career

func _show_new_career() -> void:
	_clear()
	var slot := CareerState.slot
	var demo := Career.DEMOS.has(slot)
	_title("NEW " + Career.SLOTS[slot].label.to_upper())
	if slot == "owner":
		_text("You just bought Millbrook Community Arena: an old ammonia plant, a resurfacer called Doris, and the Valley Beer League's late ice. You play in that league too. The rink's clock runs your calendar: your Beer League D game is Tuesday at 22:00 on your own ice.")
	elif demo:
		var t: int = Career.DEMOS[slot].tier
		_text("%s You start as a regular in the %s. %s" % [Career.SLOTS[slot].desc, LeagueTiers.get_tier(t).name, LeagueTiers.get_tier(t).desc])
	else:
		_text("You start in the beginner beer league as one skater in one position. Play well, train, and earn tryouts with better teams. Every rating can grow, and every rating can slip.")
	var form := _section(_root, "player_file", 48)
	form.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	form.add_child(grid)
	var first := _field(grid, "First name", "Sean")
	var last := _field(grid, "Last name", "Rookie")
	grid.add_child(_label("Position", RinkOS.PIXEL))
	var pos := OptionButton.new()
	for p in Career.USER_POSITIONS:
		pos.add_item({"C": "Center", "LW": "Left wing", "RW": "Right wing", "D": "Defence"}[p])
	grid.add_child(pos)
	var go := _button("Start demo" if demo else "Start career", func():
		var fn := first.text.strip_edges()
		var ln := last.text.strip_edges()
		var ps: String = Career.USER_POSITIONS[pos.selected]
		if slot == "owner":
			CareerState.rink = RinkLink.new_owner(fn, ln, ps)
			CareerState.career = CareerState.rink.career
			CareerState.career.save()
			if not _auto:
				CareerState.open_walk()  # the week starts at 05:00 in the parking lot
				return
		else:
			CareerState.career = Career.new_demo(slot, fn, ln, ps) if demo else Career.new_career(fn, ln, ps)
		career = CareerState.career
		career.save()
		_refresh())
	var buttons := _row(_root)
	buttons.add_child(go)
	buttons.add_child(_button("Back", _show_slots, false))
	go.grab_focus()
	if _auto:
		go.pressed.emit()


func _field(grid: GridContainer, label: String, value: String) -> LineEdit:
	var l := _label(label, RinkOS.PIXEL)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(260, 0)
	grid.add_child(e)
	return e


# ------------------------------------------------------------ hub

func _refresh() -> void:
	_clear()
	career.check_league_gate()
	var u := career.user()
	var team := career.user_team()
	var info := LeagueTiers.get_tier(career.tier)
	_title("#%d %s" % [u.number, u.full_name()])
	_term("%s  AGE %d  OVR %s  //  %s  //  %s  //  SEASON %d%s" % [u.position, int(u.age), _c(RinkOS.READOUT, "%.1f" % u.overall()), team.name.to_upper(), info.name.to_upper(), career.season_number, "  " + _c(RinkOS.READOUT, "[DEMO]".replace("[", "[lb]")) if career.demo != "" else ""])
	if career.is_demo_over():
		_term(_c(RinkOS.READOUT, "> DEMO COMPLETE. Keep playing this save or start another from the main menu."))
	if u.injury and not u.injury.is_healed():
		_term(_c(RinkOS.ALERT, "> INJURED: %s, %s" % [u.injury.describe(), "out %d more game%s" % [u.injury.games_out, "" if u.injury.games_out == 1 else "s"] if not u.injury.can_play() else "playing through it"]))
	if u.benched:
		_term(_c(RinkOS.ALERT, "> BENCHED: league dues unpaid. Your team plays without you."))
	if u.fatigue > 0.3:
		_term(_c(RinkOS.ACTION, "> TIRED %d%%: skating and hitting are down until you rest." % int(u.fatigue * 100)))
	var rink := CareerState.rink
	if rink:
		_term("MILLBROOK  //  %s  //  CASH %s  //  OWNER FATIGUE %s" % [rink.sim.clock_text().to_upper(), _c(RinkOS.READOUT, "$%.0f" % rink.sim.money), _c(RinkOS.READOUT, "%d" % int(rink.fatigue()))])

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	_root.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.custom_minimum_size = Vector2(640, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	_actions(left)
	_skills_table(left, u)
	_moves_table(left, u)
	_last_game(right)
	_season_table(right)
	_news(right)
	var bottom := _row(_root)
	bottom.add_child(_button("Practice", CareerState.start_practice, false))
	if CareerState.has_office() and CareerState.rink.game_due():
		bottom.add_child(_button("Rink office", CareerState.open_office, false))
	bottom.add_child(_button("Main menu", func():
		CareerState.career = null
		CareerState.rink = null
		career = null
		_show_slots(), false))

	if _auto:
		_autopilot()


## The result of the round just played: your game's score and your line.
func _last_game(parent: Control) -> void:
	var res: Dictionary = CareerState.last_round.get("user_result", {})
	if res.is_empty() or not career.teams.has(int(res.home)) or not career.teams.has(int(res.away)):
		return
	var home: Team = career.teams[int(res.home)]
	var away: Team = career.teams[int(res.away)]
	var tag := " OT" if res.ot else (" SO" if res.so else "")
	var box := _section(parent, "last_game")
	var lines := PackedStringArray()
	lines.append("%s %s  %s  %s %s%s" % [away.name.to_upper(), _c(RinkOS.READOUT, "%02d" % res.ag), _c(RinkOS.DIM, "@"), home.name.to_upper(), _c(RinkOS.READOUT, "%02d" % res.hg), _c(RinkOS.ACTION, tag)])
	var line: Dictionary = res.box.get(career.user_id, res.box.get(str(career.user_id), {}))
	if not line.is_empty():
		lines.append("YOU  %s G  %s A  %s SHOTS  %s HITS  %s  TOI %s" % [_c(RinkOS.READOUT, str(line.g)), _c(RinkOS.READOUT, str(line.a)), _c(RinkOS.READOUT, str(line.shots)), _c(RinkOS.READOUT, str(line.hits)), _c(RinkOS.GOOD if line.pm > 0 else (RinkOS.ALERT if line.pm < 0 else RinkOS.TEXT), "%+d" % line.pm), _c(RinkOS.READOUT, "%d:%02d" % [int(line.toi) / 60, int(line.toi) % 60])])
	box.add_child(_term_text("\n".join(lines)))


## One terminal line per rating: value, a 20-cell meter (# = now, amber
## dashes = room left to your potential, dim dashes = beyond it), then
## injuries and this season's growth.
func _skills_table(parent: Control, u: PlayerProfile) -> void:
	var box := _section(parent, "ratings")
	var lines := PackedStringArray()
	for k in Skills.SKATER_KEYS:
		var now := clampi(roundi(u.skills.eff(k)), 0, 100)
		var cells := 20
		var n := clampi(roundi(now / 100.0 * cells), 0, cells)
		var p := clampi(roundi(float(u.potential[k]) / 100.0 * cells), n, cells)
		var meter := "[lb]%s%s%s]" % [_c(RinkOS.READOUT, "#".repeat(n)), _c(RinkOS.ACTION, "-".repeat(p - n)), _c(RinkOS.DIM, "-".repeat(cells - p))]
		var mod: float = u.skills.modifiers.get(k, 0.0)
		var gain: float = u.xp_log.get(k, 0.0)
		var notes := ""
		if mod <= -1.0:
			notes += " " + _c(RinkOS.ALERT, "%+d HURT" % round(mod))
		if gain >= 0.1:
			notes += " " + _c(RinkOS.GOOD, "+%.1f" % gain)
		lines.append("%s %s%s" % [RinkOS.dots(Skills.LABELS[k], _c(RinkOS.READOUT, "%2d" % now), 15), meter, notes])
	lines.append(_c(RinkOS.DIM, "%s NOW  %s ROOM TO GROW  +SEASON GAIN" % [_c(RinkOS.READOUT, "#"), _c(RinkOS.ACTION, "-")]))
	box.add_child(_term_text("\n".join(lines)))


## Known shots and stick moves, and what the next ones need.
func _moves_table(parent: Control, u: PlayerProfile) -> void:
	var box := _section(parent, "moves")
	var lines := PackedStringArray()
	for m in MoveUnlocks.ORDER:
		if u.knows_move(m):
			lines.append("%s %s" % [_c(RinkOS.GOOD, "[x]"), MoveUnlocks.LABELS[m].to_upper()])
		else:
			lines.append("%s %s  %s" % [_c(RinkOS.DIM, "[ ]"), _c(RinkOS.DIM, MoveUnlocks.LABELS[m].to_upper()), _c(RinkOS.DIM, MoveUnlocks.requirement_text(u, m))])
	box.add_child(_term_text("\n".join(lines)))


func _actions(parent: Control) -> void:
	var u := career.user()
	if career.phase == Career.Phase.OFFSEASON:
		parent = _section(parent, "offseason // tryouts")
		if career.invitations.is_empty():
			parent.add_child(_term_text(_c(RinkOS.DIM, "> NO TRYOUT INVITATIONS.")))
		for inv in career.invitations.duplicate():
			var t: Team = career.teams[inv.team]
			var row := _row(parent)
			row.add_child(_button("Try out: %s" % t.name, func():
				var r := career.try_out(inv.team)
				career.save()
				_refresh()
				_term(_c(RinkOS.GOOD if r.made else RinkOS.ALERT, "> %s" % ("MADE THE TEAM" if r.made else "CUT")) + "  CAMP SCORE %s  CUT LINE %s" % [_c(RinkOS.READOUT, "%.1f" % r.score), _c(RinkOS.READOUT, "%.1f" % r.cut)])))
			var lbl := _label(LeagueTiers.get_tier(inv.tier).name.to_upper(), RinkOS.TERM)
			lbl.add_theme_color_override("font_color", RinkOS.DIM)
			row.add_child(lbl)
		var next := _button("Start season %d" % (career.season_number + 1), func():
			career.start_next_season()
			career.save()
			_refresh())
		parent.add_child(next)
		next.grab_focus()
		return
	var rink := CareerState.rink
	if rink and not rink.game_due():
		parent = _section(parent, "millbrook")
		parent.add_child(_term_text("> NEXT GAME: %s 22:00 ON YOUR OWN ICE." % RinkSim.DAY_NAMES[RinkLink.GAME_WEEKDAY].to_upper()))
		parent.add_child(_term_text("> RUN THE RINK FROM THE OFFICE OR ON FOOT. EITHER SENDS YOU BACK HERE AT GAME TIME."))
		var go := _button("Rink office", CareerState.open_office)
		go.disabled = not CareerState.has_office()
		var row := _row(parent)
		row.add_child(go)
		row.add_child(_button("Walk the rink", CareerState.open_walk, false))
		go.grab_focus()
		return
	var g := career.next_user_game()
	parent = _section(parent, "next_game")
	if g.is_empty():
		parent.add_child(_term_text(_c(RinkOS.DIM, "> YOUR TEAM IS OFF THIS ROUND.")))
		_row(parent).add_child(_button("Sim round", _sim_round))
	else:
		var opp: Team = g.away if g.user_home else g.home
		var tag := _c(RinkOS.ACTION, "PLAYOFFS") if g.playoff else "GAME %s OF %d" % [_c(RinkOS.READOUT, str(u.season_stats.gp + 1)), LeagueTiers.get_tier(career.tier).games]
		parent.add_child(_term_text("%s  //  %s %s" % [tag, "VS" if g.user_home else "AT", _c(RinkOS.ACTION, opp.name.to_upper())]))
		var row := _row(parent)
		var play := _button("Play game", func(): CareerState.play_match(g))
		play.disabled = not u.dressed()
		row.add_child(play)
		row.add_child(_button("Sim game", _sim_round, false))
		if not play.disabled:
			play.grab_focus()
	# training focus + game length
	var opts := _row(parent)
	opts.add_child(_label("Training", RinkOS.PIXEL))
	var focus := OptionButton.new()
	var keys := ["balanced"] + Skills.SKATER_KEYS
	for k in keys:
		focus.add_item("Balanced" if k == "balanced" else Skills.LABELS[k])
	focus.selected = keys.find(u.training_focus)
	focus.item_selected.connect(func(i):
		u.training_focus = keys[i]
		career.save())
	opts.add_child(focus)
	opts.add_child(_label("Period", RinkOS.PIXEL))
	var plen := OptionButton.new()
	for m in GameSettings.PERIOD_CHOICES:
		plen.add_item("%d min" % m)
	plen.selected = maxi(0, GameSettings.PERIOD_CHOICES.find(career.settings.period_minutes))
	plen.item_selected.connect(func(i):
		career.settings.period_minutes = GameSettings.PERIOD_CHOICES[i]
		career.save())
	opts.add_child(plen)


## Runs the owner's rink until the next game is due (autopilot only; a player
## runs the rink from the office).
func _run_rink() -> void:
	CareerState.rink.advance_to_game()
	career.save()
	_refresh()


func _sim_round() -> void:
	CareerState.last_round = CareerState.play_round()
	career.save()
	_refresh()


func _season_table(parent: Control) -> void:
	var s := career.season
	var phase: String = ["regular season", "playoffs", "final"][s.phase]
	var box := _section(parent, "%s // %s" % [LeagueTiers.get_tier(s.tier).name, phase])
	var lines := PackedStringArray()
	lines.append(_c(RinkOS.DIM, "%-3s %-22s %3s %3s %3s %3s %4s" % ["#", "TEAM", "GP", "W", "L", "OTL", "PTS"]))
	var pos := 0
	for tid in s.ranked():
		pos += 1
		var r: Dictionary = s.standings[tid]
		var nm: String = career.teams[tid].name.to_upper().left(22)
		var row := "%-3d %-22s %3d %3d %3d %3d %s" % [pos, nm, r.gp, r.w, r.l, r.otl, _c(RinkOS.READOUT, "%4d" % r.pts)]
		if tid == career.user().team_id:
			row = _c(RinkOS.ACTION, "%-3d %-22s %3d %3d %3d %3d %4d" % [pos, nm, r.gp, r.w, r.l, r.otl, r.pts])
		lines.append(row)
	for ri in s.bracket.size():
		lines.append("")
		lines.append(_c(RinkOS.DIM, RinkOS.rule(["semifinals", "final"][mini(ri, 1)], 44)))
		for se in s.bracket[ri]:
			lines.append("%s %s - %s %s%s" % [career.teams[se.a].name.to_upper(), _c(RinkOS.READOUT, str(se.wa)), _c(RinkOS.READOUT, str(se.wb)), career.teams[se.b].name.to_upper(), _c(RinkOS.DIM, "  BEST OF %d" % (se.need * 2 - 1)) if se.need > 1 else ""])
	var u := career.user()
	var st := u.season_stats
	lines.append("")
	lines.append(_c(RinkOS.DIM, RinkOS.rule("you", 44)))
	lines.append("GP %s  G %s  A %s  PTS %s  SHOTS %s  HITS %s  %s" % [_c(RinkOS.READOUT, str(st.gp)), _c(RinkOS.READOUT, str(st.g)), _c(RinkOS.READOUT, str(st.a)), _c(RinkOS.READOUT, str(st.g + st.a)), _c(RinkOS.READOUT, str(st.shots)), _c(RinkOS.READOUT, str(st.hits)), _c(RinkOS.GOOD if st.pm > 0 else (RinkOS.ALERT if st.pm < 0 else RinkOS.TEXT), "%+d" % st.pm)])
	box.add_child(_term_text("\n".join(lines)))


func _news(parent: Control) -> void:
	var box := _section(parent, "news")
	var lines := PackedStringArray()
	for i in range(career.news.size() - 1, maxi(-1, career.news.size() - 13), -1):
		lines.append("%s %s" % [_c(RinkOS.DIM, "D%03d" % career.news[i].day), career.news[i].text.replace("[", "[lb]")])
	if lines.is_empty():
		lines.append(_c(RinkOS.DIM, "> NOTHING YET."))
	var t := _term_text("\n".join(lines))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(t)


## Headless test loop: play every game live (AI driving you), take tryouts,
## start new seasons, stop after `--seasons=N` (default 1).
func _autopilot() -> void:
	var limit := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			limit = a.trim_prefix("--seasons=").to_int()
	await get_tree().create_timer(0.2).timeout
	if career.phase == Career.Phase.OFFSEASON:
		print(_season_line())
		if career.season_number >= limit:
			get_tree().quit()
			return
		for inv in career.invitations.duplicate():
			if career.try_out(inv.team).made:
				break
		career.start_next_season()
		career.save()
		_refresh()
		return
	if CareerState.rink and not CareerState.rink.game_due():
		_run_rink()
		return
	var g := career.next_user_game()
	if g.is_empty() or not career.user().dressed():
		_sim_round()
	else:
		CareerState.play_match(g)


func _season_line() -> String:
	var u := career.user()
	var h: Dictionary = u.history[-1]
	return "season %d %s %s: %s, %d GP %d G %d A, overall %.1f%s" % [h.season, LeagueTiers.get_tier(h.tier).short, h.team, h.record, h.stats.gp, h.stats.g, h.stats.a, h.overall, " CHAMPS" if h.champion else ""]


# ------------------------------------------------------------ widgets

func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_root.add_child(RinkOS.label(RinkOS.rule("rink-os 3.0  //  career", 120), RinkOS.TERM_DIM))


func _title(t: String) -> void:
	_root.add_child(RinkOS.label(t.to_upper(), RinkOS.TITLE))


## A sentence in the body face.
func _text(t: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = t
	r.custom_minimum_size = Vector2(400, 0)
	_root.add_child(r)


## A terminal line under the title (status, alerts).
func _term(t: String) -> void:
	_root.add_child(_term_text(t))


func _term_text(t: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = "TermText"
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.text = t
	return r


## A framed panel headed by a `// TITLE ----` rule; returns its content box.
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


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row


func _label(t: String, variation := "") -> Label:
	return RinkOS.label(t, variation)


func _button(t: String, cb: Callable, primary := true) -> Button:
	var b := RinkOS.button(t, primary)
	b.pressed.connect(cb)
	return b


func _c(col: Color, t: String) -> String:
	return "[%s]%s[/color]" % [RinkOS.bb(col), t]
