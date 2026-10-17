extends CanvasLayer
## Developer menu for playtesting, toggled with the tilde key (` ~) or the
## `dev_menu` input action when it exists. Autoloaded as DevMenu.
##
## It only edits state through other systems' public fields and functions and
## looks everything up at runtime (has_method / get_node_or_null), so it keeps
## working while the career, physics and UI code change underneath it. Rating
## edits apply to the live game only, unless "Save edits to career" is ticked.

const SKATER_KEYS := ["speed", "agility", "stick_handling", "shot_accuracy", "shot_power",
	"shot_release", "pass_quality", "hitting", "toughness"]
const GOALIE_KEYS := ["reflexes", "positioning", "rebound_control", "glove", "toughness"]
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]

var _panel: PanelContainer
var _tabs: TabContainer
var _status: Label
var _save_edits: CheckBox
var _pause_while_open: CheckBox
var _fps_label: Label
var _was_paused := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	var args := OS.get_cmdline_user_args()
	if "--test=devmenu" in args:
		_self_test.call_deferred()
	elif "--dev-open" in args:  # for screenshots
		set_open.call_deferred(true)


func _input(event: InputEvent) -> void:
	var toggle := false
	if InputMap.has_action("dev_menu"):
		toggle = event.is_action_pressed("dev_menu")
	elif event is InputEventKey and event.pressed and not event.echo:
		toggle = event.physical_keycode == KEY_QUOTELEFT
	if toggle:
		get_viewport().set_input_as_handled()
		set_open(not _panel.visible)


func set_open(open: bool) -> void:
	if open == _panel.visible:
		return
	_panel.visible = open
	if open:
		_was_paused = get_tree().paused
		if _pause_while_open.button_pressed:
			get_tree().paused = true
		refresh()
	else:
		get_tree().paused = _was_paused


func is_open() -> bool:
	return _panel.visible


func _process(_dt: float) -> void:
	if _panel.visible:
		_fps_label.text = "// %d fps   time x%.2f" % [Engine.get_frames_per_second(), Engine.time_scale]


# ---------------------------------------------------------------- lookups

func _game() -> Node:
	var s := get_tree().current_scene
	return s if s != null and "score" in s and "clock" in s else null


func _career() -> Object:
	var cs := get_node_or_null("/root/CareerState")
	if cs == null:
		return null
	if cs.get("career") == null and cs.has_method("load_or_null"):
		cs.load_or_null()
	return cs.get("career")


func _user_profile() -> Object:
	var g := _game()
	if g != null and g.get("user_profile") != null:
		return g.user_profile
	var c := _career()
	return c.user() if c != null and c.has_method("user") else null


## The Skills object being edited: the user's career profile, or the live
## controlled skater's skills in an exhibition game.
func _skills() -> Object:
	var p := _user_profile()
	if p != null and p.get("skills") != null:
		return p.skills
	var g := _game()
	if g != null and g.get("human") != null and g.human.get("skills") != null:
		return g.human.skills
	return null


func _say(text: String) -> void:
	_status.text = "// " + text
	print("[dev] ", text)


# ---------------------------------------------------------------- building

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"HudPanel"  # RinkOS (assets/ui/STYLE.md)
	_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_panel.custom_minimum_size = Vector2(440, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	sb.border_color = Color(0.3, 0.9, 0.6)
	sb.border_width_right = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if str(ProjectSettings.get_setting("gui/theme/custom", "")) == "":
		_panel.add_theme_stylebox_override("panel", sb)  # no project theme yet (RinkOS, PR #6)
	add_child(_panel)

	var root := VBoxContainer.new()
	_panel.add_child(root)
	var title := Label.new()
	title.text = "// RINKGM DEV CONSOLE\n----------------------------------------"
	root.add_child(title)
	_fps_label = Label.new()
	_fps_label.theme_type_variation = &"TermLabel"
	root.add_child(_fps_label)

	var opts := HBoxContainer.new()
	root.add_child(opts)
	_pause_while_open = CheckBox.new()
	_pause_while_open.text = "Pause while open"
	_pause_while_open.toggled.connect(func(on: bool) -> void:
		if _panel.visible:
			get_tree().paused = on or _was_paused)
	opts.add_child(_pause_while_open)
	_save_edits = CheckBox.new()
	_save_edits.text = "Save edits to career"
	opts.add_child(_save_edits)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	for tab_name in ["Player", "Match", "Career", "Sim"]:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
		_tabs.add_child(scroll)
	_tabs.tab_changed.connect(func(_i: int) -> void: refresh())

	_status = Label.new()
	_status.theme_type_variation = &"TermLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	var hint := Label.new()
	hint.text = "----------------------------------------\n// ~ to close"
	root.add_child(hint)


func _tab_box(tab_name: String) -> VBoxContainer:
	var box: VBoxContainer = _tabs.get_node(tab_name).get_child(0)
	for c in box.get_children():
		c.queue_free()
	return box


func _button(parent: Control, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		fn.call()
		refresh())
	parent.add_child(b)
	return b


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	parent.add_child(r)
	return r


func _note(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


func refresh() -> void:
	if not _panel.visible:
		return
	match _tabs.get_current_tab_control().name:
		"Player": _build_player()
		"Match": _build_match()
		"Career": _build_career()
		"Sim": _build_sim()


# ---------------------------------------------------------------- player

func _build_player() -> void:
	var box := _tab_box("Player")
	var sk := _skills()
	if sk == null or sk.get("values") == null:
		_note(box, "// No player ratings found. Start a career game or an exhibition.")
		return
	var p := _user_profile()
	if p != null and p.has_method("full_name"):
		_note(box, "// %s  (%s)" % [p.full_name(), p.get("position")])
	var keys: Array = GOALIE_KEYS if sk.values.has("reflexes") else SKATER_KEYS
	for k in keys:
		var r := _row(box)
		var l := Label.new()
		l.text = k
		l.custom_minimum_size.x = 130
		r.add_child(l)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = 100
		slider.step = 1
		slider.value = sk.values.get(k, 50.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(slider)
		var v := Label.new()
		v.text = str(int(slider.value))
		v.custom_minimum_size.x = 32
		r.add_child(v)
		slider.value_changed.connect(func(val: float) -> void:
			v.text = str(int(val))
			_set_rating(k, val))
	var r2 := _row(box)
	_button(r2, "All 25", func() -> void: _set_all(25.0))
	_button(r2, "All 50", func() -> void: _set_all(50.0))
	_button(r2, "All 75", func() -> void: _set_all(75.0))
	_button(r2, "All 100", func() -> void: _set_all(100.0))

	_note(box, "----------------------------------------\n// Health")
	if p != null:
		var inj: Object = p.get("injury")
		_note(box, "// Injury: %s" % (inj.describe() if inj != null and inj.has_method("describe") else "none"))
		var r3 := _row(box)
		_button(r3, "Injure (minor)", func() -> void: _injure(0.4))
		_button(r3, "Injure (major)", func() -> void: _injure(1.0))
		_button(r3, "Heal", _heal)
		if "fatigue" in p:
			_button(r3, "Clear fatigue", func() -> void:
				p.fatigue = 0.0
				_refresh_mods(p)
				_say("fatigue cleared"))

	_note(box, "----------------------------------------\n// Moves")
	if p != null and p.has_method("unlock_move"):
		var moves_script := "res://scripts/core/moves.gd"
		if ResourceLoader.exists(moves_script):
			var moves = load(moves_script)
			if "ALL" in moves:
				_button(box, "Unlock every move", func() -> void:
					for m in moves.ALL:
						p.unlock_move(m)
					_say("all moves unlocked"))
	else:
		_note(box, "// (move unlocks arrive with the moves system)")


func _set_rating(key: String, val: float) -> void:
	var g := _game()
	if g != null and g.has_method("dev_set_skill"):
		g.dev_set_skill(key, val)
		_maybe_save()
		return
	var sk := _skills()
	if sk == null:
		return
	sk.values[key] = val
	_after_rating_edit()


func _set_all(val: float) -> void:
	var sk := _skills()
	if sk == null:
		return
	for k in sk.values.keys():
		sk.values[k] = val
	_after_rating_edit()
	_say("all ratings set to %d" % int(val))


func _after_rating_edit() -> void:
	# Physics re-reads Skills every frame; older builds need an explicit apply.
	var g := _game()
	if g != null and g.get("human") != null:
		var h: Object = g.human
		if h.has_method("apply_skills") and h.get("skills") != null:
			h.apply_skills(h.skills)
	_maybe_save()


func _refresh_mods(p: Object) -> void:
	if p.has_method("refresh_modifiers"):
		p.refresh_modifiers()
	_maybe_save()


func _injure(impact: float) -> void:
	var p := _user_profile()
	var path := "res://scripts/career/injury.gd"
	var c := _career()
	if c != null and c.has_method("dev_injure"):
		c.dev_injure(3 if impact >= 1.0 else 1)
		_maybe_save()
		_say("injured")
		return
	if p == null or not p.has_method("add_injury") or not ResourceLoader.exists(path):
		_say("injuries aren't available in this build")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var inj = load(path).create(rng, impact)
	p.add_injury(inj)
	_refresh_mods(p)
	_say("injured: %s" % (inj.describe() if inj.has_method("describe") else "yes"))


func _heal() -> void:
	var c := _career()
	if c != null and c.has_method("dev_heal"):
		c.dev_heal()
		_maybe_save()
		_say("healed")
		return
	var p := _user_profile()
	if p == null or not "injury" in p:
		return
	p.injury = null
	_refresh_mods(p)
	_say("healed")


func _maybe_save() -> void:
	if not _save_edits.button_pressed:
		return
	var cs := get_node_or_null("/root/CareerState")
	if cs != null and cs.has_method("save_career"):
		cs.save_career()
		_say("saved to career")
		return
	var c := _career()
	if c != null and c.has_method("save"):
		c.save()
		_say("saved to career")


# ---------------------------------------------------------------- match

func _build_match() -> void:
	var box := _tab_box("Match")
	var g := _game()
	if g == null:
		_note(box, "// Not in a game.")
		return
	var period_text := ""
	if "period" in g:
		period_text = "  period %d%s" % [g.period, " OT" if g.get("overtime") else ""]
	_note(box, "// Score %d - %d   clock %s%s" % [g.score[0], g.score[1], _fmt_time(g.clock), period_text])
	for team in 2:
		var r := _row(box)
		var l := Label.new()
		l.text = "Team %d" % (team + 1) + (" (you)" if team == 0 else "")
		l.custom_minimum_size.x = 130
		r.add_child(l)
		_button(r, "-1", func() -> void: _add_score(team, -1))
		_button(r, "+1", func() -> void: _add_score(team, 1))

	_note(box, "----------------------------------------\n// Clock")
	var r2 := _row(box)
	_button(r2, "10 s left", func() -> void: _set_clock(10.0))
	_button(r2, "1 min left", func() -> void: _set_clock(60.0))
	_button(r2, "Reset period", func() -> void:
		var st: Object = g.get("settings")
		_set_clock(st.period_length() if st != null and st.has_method("period_length") else 300.0))
	var r3 := _row(box)
	var end_period := "dev_end_period" if g.has_method("dev_end_period") else "_end_period"
	var end_game := "dev_end_game" if g.has_method("dev_end_game") else "_game_over"
	if g.has_method(end_period):
		_button(r3, "End period", func() -> void:
			g.call(end_period)
			_say("period ended"))
	if g.has_method(end_game):
		_button(r3, "End game now", func() -> void:
			g.call(end_game)
			_say("game ended %d-%d" % [g.score[0], g.score[1]]))

	_note(box, "----------------------------------------\n// Game speed")
	var r4 := _row(box)
	for sp in SPEEDS:
		_button(r4, "x%s" % str(sp), func() -> void:
			Engine.time_scale = sp
			_say("game speed x%s" % str(sp)))

	_note(box, "----------------------------------------\n// Feel and AI")
	var tuning := get_node_or_null("/root/Tuning")
	if tuning != null and tuning.has_method("cycle_mode"):
		_button(box, "Physics mode: %s (cycle)" % tuning.mode_name(), func() -> void: tuning.cycle_mode())
	if "autoplay" in g:
		var cb := CheckBox.new()
		cb.text = "AI controls my skater (autoplay)"
		cb.button_pressed = g.autoplay
		cb.toggled.connect(func(on: bool) -> void: g.autoplay = on)
		box.add_child(cb)
	if "ai_debug" in g:
		var cb2 := CheckBox.new()
		cb2.text = "Show AI debug"
		cb2.button_pressed = g.ai_debug
		cb2.toggled.connect(func(on: bool) -> void: g.ai_debug = on)
		box.add_child(cb2)


func _add_score(team: int, d: int) -> void:
	var g := _game()
	if g == null:
		return
	var n := maxi(0, g.score[team] + d)
	if g.has_method("dev_set_score"):
		g.dev_set_score(team, n)
	else:
		g.score[team] = n  # the HUD redraws the score every frame
	_say("score %d - %d" % [g.score[0], g.score[1]])


func _set_clock(t: float) -> void:
	var g := _game()
	if g == null:
		return
	if g.has_method("dev_set_clock"):
		g.dev_set_clock(t)
	else:
		g.clock = t
	_say("clock set to %s" % _fmt_time(t))


static func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# ---------------------------------------------------------------- career

func _build_career() -> void:
	var box := _tab_box("Career")
	var c := _career()
	if c == null:
		_note(box, "// No career loaded.")
		return
	var tier_name := str(c.tier)
	var tiers_path := "res://scripts/career/league_tiers.gd"
	var tiers = load(tiers_path) if ResourceLoader.exists(tiers_path) else null
	if tiers != null and tiers.has_method("get_tier"):
		tier_name = "%d %s" % [c.tier, tiers.get_tier(c.tier).get("name", "")]
	_note(box, "// Season %d   tier %s   day %d" % [c.season_number, tier_name, c.day])
	var s: Object = c.get("season")
	if s != null:
		_note(box, "// Round %d of %d" % [s.round_index + 1, s.rounds.size()])

	if tiers != null and tiers.has_method("count"):
		_note(box, "----------------------------------------\n// Move to tier (takes effect next season)")
		var r := _row(box)
		for i in tiers.count():
			_button(r, str(i), func() -> void: _set_tier(i))
	var r2 := _row(box)
	if c.has_method("dev_force_invitations"):
		_button(r2, "Force tryout invites", func() -> void:
			c.dev_force_invitations()
			_maybe_save()
			_say("%d invitation(s)" % c.invitations.size()))
	elif c.has_method("compute_invitations"):
		_button(r2, "Get tryout invites", func() -> void:
			c.invitations = c.compute_invitations()
			_maybe_save()
			_say("%d invitation(s)" % c.invitations.size()))
	if c.has_method("save"):
		_button(r2, "Save career", func() -> void:
			c.save()
			_say("career saved"))


func _set_tier(t: int) -> void:
	var c := _career()
	if c == null:
		return
	if c.has_method("dev_set_tier"):
		c.dev_set_tier(t)
		_maybe_save()
		_say("tier set to %d; season rebuilt at that tier" % t)
		return
	c.tier = t
	_maybe_save()
	_say("tier set to %d; it applies when the next season starts" % t)


# ---------------------------------------------------------------- sim

func _build_sim() -> void:
	var box := _tab_box("Sim")
	var c := _career()
	if c == null or not c.has_method("play_round"):
		_note(box, "// No career loaded.")
		return
	_note(box, "// Sims use the career's quick sim, including your games.")
	_button(box, "Sim 1 round", func() -> void: _sim_rounds(1))
	_button(box, "Sim 5 rounds", func() -> void: _sim_rounds(5))
	_button(box, "Sim to end of regular season", func() -> void: _sim_until_phase_change())
	_button(box, "Sim to end of season", func() -> void: _sim_season())
	if c.has_method("start_next_season"):
		_button(box, "Start next season", func() -> void:
			c.start_next_season()
			_maybe_save()
			_say("season %d started in tier %d" % [c.season_number, c.tier]))


## Plays one round; false once the career has left the season (offseason).
func _play_round(c: Object) -> bool:
	var summary: Dictionary = c.play_round()
	return not summary.get("results", []).is_empty()


func _sim_rounds(n: int) -> void:
	var c := _career()
	var done := 0
	for i in n:
		if not _play_round(c):
			break
		done += 1
	_maybe_save()
	_say("simmed %d round(s)" % done)


func _sim_until_phase_change() -> void:
	var c := _career()
	var start_phase = c.season.phase
	var done := 0
	while c.season.phase == start_phase and done < 500 and _play_round(c):
		done += 1
	_maybe_save()
	_say("simmed %d round(s)" % done)


func _sim_season() -> void:
	var c := _career()
	var done := 0
	while done < 500 and _play_round(c):
		done += 1
	_maybe_save()
	_say("simmed %d round(s); the season is over" % done)


# ---------------------------------------------------------------- self test

## `-- --test=devmenu`: opens every tab and drives the main actions against
## whatever game and career this build has, then quits with 0 or 1.
func _self_test() -> void:
	await get_tree().create_timer(1.0).timeout
	var fails: Array[String] = []
	set_open(true)
	for i in _tabs.get_tab_count():
		_tabs.current_tab = i
		refresh()
		await get_tree().process_frame
	var g := _game()
	if g == null:
		fails.append("no game scene found")
	else:
		_add_score(0, 2)
		if g.score[0] != 2:
			fails.append("score edit did not apply")
		_add_score(0, -5)
		if g.score[0] != 0:
			fails.append("score did not clamp at 0")
		_set_clock(42.0)
		if absf(g.clock - 42.0) > 0.5:
			fails.append("clock edit did not apply")
	var cs := get_node_or_null("/root/CareerState")
	var career_path := "res://scripts/career/career.gd"
	if cs != null and _career() == null and ResourceLoader.exists(career_path):
		cs.career = load(career_path).new_career("Dev", "Tester", "C", 7)  # in memory only
	print("devmenu test: game=%s skills=%s career=%s" % [_game() != null, _skills() != null, _career() != null])
	var sk := _skills()
	if sk != null:
		_set_rating("speed", 99.0)
		if absf(sk.values.get("speed", 0.0) - 99.0) > 0.01:
			fails.append("rating edit did not apply")
	var c := _career()
	if c != null and c.has_method("play_round"):
		var before: int = c.day
		_sim_rounds(1)
		if c.day == before:
			fails.append("sim round did not advance the day")
		_injure(1.0)
		if _user_profile().get("injury") == null:
			fails.append("injure did not apply")
		_heal()
		if _user_profile().get("injury") != null:
			fails.append("heal did not apply")
		_sim_season()
		if c.has_method("next_user_game") and not c.next_user_game().is_empty():
			fails.append("sim season left games to play")
		if c.has_method("start_next_season"):
			var season_before: int = c.season_number
			c.start_next_season()
			if c.season_number != season_before + 1:
				fails.append("next season did not start")
	Engine.time_scale = 1.0
	set_open(false)
	for f in fails:
		print("  FAIL: ", f)
	print("devmenu test: ", "all passed" if fails.is_empty() else "FAILED %d" % fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)
