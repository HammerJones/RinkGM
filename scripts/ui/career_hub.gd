extends Control
## Career hub: create a player, see your ratings, team, standings and news,
## pick a training focus and game length, then play (or sim) the next game.
## In the offseason it lists tryout invitations. Deliberately plain: the
## UI/styling thread owns the look; this is the flow and the data.
##
## The first screen picks a save slot: the open career or one of the two
## playtest demos (a low-tier season that leads to a mid-tier tryout, or a
## mid-tier season straight away).
##
## `-- --career --autoplay` plays games hands-off (headless testing);
## `-- --slot=demo_low|demo_mid|career` skips the slot screen;
## `-- --career-new` throws away that slot's save and starts over.

var career: Career
var _root: VBoxContainer
var _auto := "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("16171c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 32
	scroll.offset_top = 24
	scroll.offset_right = -32
	scroll.offset_bottom = -24
	add_child(scroll)
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 14)
	scroll.add_child(_root)
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
	_title("RINK GM")
	_text("Pick a save. The demos are short playtest careers: they grow faster than a normal career so you can feel progression within a season or two.")
	for slot in Career.SLOTS:
		var info: Dictionary = Career.SLOTS[slot]
		var box := VBoxContainer.new()
		_root.add_child(box)
		box.add_child(_label(info.label.to_upper(), 20))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
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
				_open_slot(slot)))
		row.add_child(_label(summary, 15))
		if slot == "demo_low" and _root.get_child_count() > 0:
			b.grab_focus()


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
	if demo:
		var t: int = Career.DEMOS[slot].tier
		_text("%s You start as a regular in the %s. %s" % [Career.SLOTS[slot].desc, LeagueTiers.get_tier(t).name, LeagueTiers.get_tier(t).desc])
	else:
		_text("You start in the beginner beer league as one skater in one position. Play well, train, and earn tryouts with better teams. Every rating can grow, and every rating can slip.")
	var grid := GridContainer.new()
	grid.columns = 2
	_root.add_child(grid)
	var first := _field(grid, "First name", "Sean")
	var last := _field(grid, "Last name", "Rookie")
	grid.add_child(_label("Position", 16))
	var pos := OptionButton.new()
	for p in Career.USER_POSITIONS:
		pos.add_item({"C": "Center", "LW": "Left wing", "RW": "Right wing", "D": "Defence"}[p])
	grid.add_child(pos)
	var go := _button("Start demo" if demo else "Start career", func():
		var fn := first.text.strip_edges()
		var ln := last.text.strip_edges()
		var ps: String = Career.USER_POSITIONS[pos.selected]
		CareerState.career = Career.new_demo(slot, fn, ln, ps) if demo else Career.new_career(fn, ln, ps)
		career = CareerState.career
		career.save()
		_refresh())
	_root.add_child(go)
	_root.add_child(_button("Back", _show_slots))
	go.grab_focus()
	if _auto:
		go.pressed.emit()


func _field(grid: GridContainer, label: String, value: String) -> LineEdit:
	grid.add_child(_label(label, 16))
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(260, 0)
	grid.add_child(e)
	return e


# ------------------------------------------------------------ hub

func _refresh() -> void:
	_clear()
	var u := career.user()
	var team := career.user_team()
	var info := LeagueTiers.get_tier(career.tier)
	_title("%s  #%d  %s" % [u.full_name().to_upper(), u.number, u.position])
	_text("Age %d   Overall %.1f   %s, %s   Season %d%s" % [int(u.age), u.overall(), team.name, info.name, career.season_number, "   [color=#7fd4ff]DEMO[/color]" if career.demo != "" else ""])
	if career.is_demo_over():
		_text("[color=#7fd4ff]Demo complete. That's both demo seasons; keep playing this save or start another from the main menu.[/color]")
	_last_game()
	if u.injury and not u.injury.is_healed():
		_text("[color=#ff7a6b]%s: %s[/color]" % [u.injury.describe(), "out %d more game%s" % [u.injury.games_out, "" if u.injury.games_out == 1 else "s"] if not u.injury.can_play() else "playing through it"])
	if u.fatigue > 0.3:
		_text("[color=#f0c040]Tired (%d%%): skating and hitting are down until you rest.[/color]" % int(u.fatigue * 100))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	_root.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(520, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	_skills_table(left, u)
	_actions(left)
	_season_table(right)
	_news(right)
	_root.add_child(_button("Main menu", func():
		CareerState.career = null
		career = null
		_show_slots()))

	if _auto:
		_autopilot()


## The result of the round just played: your game's score and your line.
func _last_game() -> void:
	var res: Dictionary = CareerState.last_round.get("user_result", {})
	if res.is_empty() or not career.teams.has(int(res.home)) or not career.teams.has(int(res.away)):
		return
	var home: Team = career.teams[int(res.home)]
	var away: Team = career.teams[int(res.away)]
	var tag := " OT" if res.ot else (" SO" if res.so else "")
	var txt := "LAST GAME  %s %d - %d %s%s" % [away.name, res.ag, res.hg, home.name, tag]
	var line: Dictionary = res.box.get(career.user_id, res.box.get(str(career.user_id), {}))
	if not line.is_empty():
		txt += "    You: %dG %dA  %d shots  %d hits  %+d  TOI %d:%02d" % [line.g, line.a, line.shots, line.hits, line.pm, int(line.toi) / 60, int(line.toi) % 60]
	_text("[color=#c8d0dc]%s[/color]" % txt)


func _skills_table(parent: Control, u: PlayerProfile) -> void:
	parent.add_child(_label("RATINGS  (bar = current, mark = potential)", 18))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	parent.add_child(grid)
	for k in Skills.SKATER_KEYS:
		grid.add_child(_label(Skills.LABELS[k], 15))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(220, 14)
		bar.show_percentage = false
		bar.value = u.skills.eff(k)
		var cap := ColorRect.new()
		cap.color = Color("ffd23f")
		cap.size = Vector2(2, 14)
		cap.position = Vector2(220.0 * u.potential[k] / 100.0, 0)
		bar.add_child(cap)
		grid.add_child(bar)
		var mod: float = u.skills.modifiers.get(k, 0.0)
		var gain: float = u.xp_log.get(k, 0.0)
		grid.add_child(_label("%d%s%s" % [round(u.skills.eff(k)), "  (%+d hurt)" % round(mod) if mod <= -1.0 else "", "  +%.1f this season" % gain if gain >= 0.1 else ""], 14))


func _actions(parent: Control) -> void:
	var u := career.user()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	if career.phase == Career.Phase.OFFSEASON:
		parent.add_child(_label("OFFSEASON", 18))
		if career.invitations.is_empty():
			parent.add_child(_label("No tryout invitations.", 15))
		for inv in career.invitations.duplicate():
			var t: Team = career.teams[inv.team]
			row = HBoxContainer.new()
			parent.add_child(row)
			row.add_child(_button("Try out: %s (%s)" % [t.name, LeagueTiers.get_tier(inv.tier).name], func():
				var r := career.try_out(inv.team)
				career.save()
				_refresh()
				_text("[b]%s[/b] (camp score %.1f, cut line %.1f)" % ["You made the team!" if r.made else "Cut.", r.score, r.cut])))
		var next := _button("Start season %d" % (career.season_number + 1), func():
			career.start_next_season()
			career.save()
			_refresh())
		parent.add_child(next)
		next.grab_focus()
		return
	var g := career.next_user_game()
	if g.is_empty():
		parent.add_child(_label("Your team is off this round.", 16))
		row.add_child(_button("Sim round", _sim_round))
	else:
		var opp: Team = g.away if g.user_home else g.home
		var tag := "PLAYOFFS  " if g.playoff else "GAME %d OF %d  " % [u.season_stats.gp + 1, LeagueTiers.get_tier(career.tier).games]
		parent.add_child(_label("%sNEXT: %s %s" % [tag, "vs" if g.user_home else "at", opp.name], 18))
		var play := _button("Play game", func(): CareerState.play_match(g))
		play.disabled = not u.can_play()
		row.add_child(play)
		row.add_child(_button("Sim game", _sim_round))
		if not play.disabled:
			play.grab_focus()
	# training focus + game length
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	parent.add_child(opts)
	opts.add_child(_label("Training focus", 15))
	var focus := OptionButton.new()
	var keys := ["balanced"] + Skills.SKATER_KEYS
	for k in keys:
		focus.add_item("Balanced" if k == "balanced" else Skills.LABELS[k])
	focus.selected = keys.find(u.training_focus)
	focus.item_selected.connect(func(i):
		u.training_focus = keys[i]
		career.save())
	opts.add_child(focus)
	opts.add_child(_label("Period length", 15))
	var plen := OptionButton.new()
	for m in GameSettings.PERIOD_CHOICES:
		plen.add_item("%d min" % m)
	plen.selected = maxi(0, GameSettings.PERIOD_CHOICES.find(career.settings.period_minutes))
	plen.item_selected.connect(func(i):
		career.settings.period_minutes = GameSettings.PERIOD_CHOICES[i]
		career.save())
	opts.add_child(plen)


func _sim_round() -> void:
	CareerState.last_round = career.play_round()
	career.save()
	_refresh()


func _season_table(parent: Control) -> void:
	var s := career.season
	var phase: String = ["REGULAR SEASON", "PLAYOFFS", "FINAL"][s.phase]
	parent.add_child(_label("%s  %s" % [LeagueTiers.get_tier(s.tier).name.to_upper(), phase], 18))
	var lines: Array = ["[table=6][cell][b]Team[/b]   [/cell][cell][b]GP[/b]  [/cell][cell][b]W[/b]  [/cell][cell][b]L[/b]  [/cell][cell][b]OTL[/b]  [/cell][cell][b]PTS[/b][/cell]"]
	for tid in s.ranked():
		var r: Dictionary = s.standings[tid]
		var nm: String = career.teams[tid].name
		if tid == career.user().team_id:
			nm = "[color=#ffd23f]%s[/color]" % nm
		lines.append("[cell]%s   [/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell]" % [nm, r.gp, r.w, r.l, r.otl, r.pts])
	lines.append("[/table]")
	_rich(parent, "".join(lines))
	for ri in s.bracket.size():
		var txt := ""
		for se in s.bracket[ri]:
			txt += "%s %d - %d %s%s\n" % [career.teams[se.a].name, se.wa, se.wb, career.teams[se.b].name, "  (best of %d)" % (se.need * 2 - 1) if se.need > 1 else ""]
		parent.add_child(_label(["Semifinals", "Final"][mini(ri, 1)], 15))
		_rich(parent, txt)
	var u := career.user()
	var st := u.season_stats
	parent.add_child(_label("You: %d GP  %d G  %d A  %d PTS  %d shots  %d hits  %+d" % [st.gp, st.g, st.a, st.g + st.a, st.shots, st.hits, st.pm], 15))


func _news(parent: Control) -> void:
	parent.add_child(_label("NEWS", 18))
	var txt := ""
	for i in range(career.news.size() - 1, maxi(-1, career.news.size() - 13), -1):
		txt += "Day %d  %s\n" % [career.news[i].day, career.news[i].text]
	_rich(parent, txt)


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
	var g := career.next_user_game()
	if g.is_empty() or not career.user().can_play():
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


func _title(t: String) -> void:
	_root.add_child(_label(t, 30))


func _text(t: String) -> void:
	_rich(_root, t)


func _rich(parent: Control, t: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = t
	r.custom_minimum_size = Vector2(400, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	parent.add_child(r)


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b
