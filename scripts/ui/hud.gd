class_name Hud
extends CanvasLayer
## In-match overlay in the RINK-OS style (see rinkos.gd): scoreboard and clock,
## physics-mode readout, shot charge and stamina meters, centre-screen banners,
## a bench / injury notice and a toggleable controls card.

const HELP := """[b]Keyboard + mouse[/b]
WASD  skate        Mouse  stick blade / aim
LMB  shoot (hold = slapshot)   RMB / E  pass
Shift  sprint      Space  hockey stop
F  body check      Q / Tab  switch player
F1  physics mode   C  camera   R  restart

[b]Gamepad[/b]
L-stick  skate     R-stick  stickhandle,
  pull back then flick forward to shoot
RT / X  shoot (hold = slapshot)   A  pass / switch
LB  sprint   LT  hockey stop   B  check
Y  switch   Back  physics mode   D-up  camera
H  hide this"""

var _home := ""
var _away := ""
var _score_home: Label
var _score_away: Label
var _clock: Label
var _mode: RichTextLabel
var _message: Label
var _message_panel: PanelContainer
var _bench: Label
var _bench_panel: PanelContainer
var _gauge: RichTextLabel
var _help: RichTextLabel
var _help_panel: PanelContainer
var _power := 0.0
var _stamina := 1.0
var _message_timer := 0.0
var _help_timer := 15.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Scoreboard, top centre.
	var board := _panel(root, Vector2(0.5, 0.0), Vector2(0, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	board.add_child(col)
	col.add_child(RinkOS.label(RinkOS.rule("scoreboard", 34), RinkOS.TERM_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_score_home = RinkOS.label("", RinkOS.TERM_LARGE)
	_clock = RinkOS.label("", RinkOS.TERM_LARGE)
	_clock.add_theme_color_override("font_color", RinkOS.ACTION)
	_score_away = RinkOS.label("", RinkOS.TERM_LARGE)
	for l in [_score_home, _clock, _score_away]:
		row.add_child(l)

	# Physics mode, top left.
	var mode_panel := _panel(root, Vector2(0.0, 0.0), Vector2(16, 12))
	_mode = _term_text()
	mode_panel.add_child(_mode)

	# Banner (GOAL!, SAVE, end of game), centre.
	_message_panel = _panel(root, Vector2(0.5, 0.5), Vector2(0, -150))
	_message_panel.theme_type_variation = ""
	_message = RinkOS.label("", RinkOS.BANNER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message)
	_message_panel.visible = false

	# Bench / injury notice, above the meters.
	_bench_panel = _panel(root, Vector2(0.5, 1.0), Vector2(0, -150))
	_bench = RinkOS.label("", RinkOS.TERM)
	_bench.add_theme_color_override("font_color", RinkOS.ACTION)
	_bench.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bench_panel.add_child(_bench)
	_bench_panel.visible = false

	# Shot charge and stamina, bottom right (clear of the controls card).
	var gauge_panel := _panel(root, Vector2(1.0, 1.0), Vector2(-16, -16))
	_gauge = _term_text()
	gauge_panel.add_child(_gauge)
	_refresh_gauge()

	# Controls card, bottom left.
	_help_panel = _panel(root, Vector2(0.0, 1.0), Vector2(16, -16))
	_help = _term_text()
	_help.text = _terminal_help(HELP)
	_help_panel.add_child(_help)


func _process(delta: float) -> void:
	_message_timer -= delta
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_help_panel.visible = false
	if _message_timer <= 0.0 and _message_panel.visible:
		_message.text = ""
		_message_panel.visible = false


func set_score(home: String, away: String, a: int, b: int, clock: float, period := "") -> void:
	_score_home.text = "%s %02d" % [_team(home), a]
	_score_away.text = "%02d %s" % [b, _team(away)]
	_clock.text = ("%s %s" % [period.to_upper(), RinkOS.clock(clock)]).strip_edges()


## Bench / injury notice for career games ("" hides it).
func set_bench(text: String) -> void:
	_bench.text = ("> " + text.to_upper()) if text != "" else ""
	_bench_panel.visible = text != ""


func set_mode(mode_name: String) -> void:
	_mode.text = "> PHYSICS: [%s]%s[/color] [%s][F1][/color]" % [RinkOS.bb(RinkOS.ACTION), mode_name.to_upper(), RinkOS.bb(RinkOS.DIM)]


func show_message(text: String, seconds: float) -> void:
	_message.text = text.to_upper()
	_message_panel.visible = text != ""
	_message_timer = seconds


func set_power(v: float) -> void:
	if not is_equal_approx(v, _power):
		_power = v
		_refresh_gauge()


func set_stamina(v: float) -> void:
	var q := snappedf(v, 0.05)
	if not is_equal_approx(q, _stamina):
		_stamina = q
		_refresh_gauge()


func toggle_help() -> void:
	_help_timer = 0.0
	_help_panel.visible = not _help_panel.visible


func _refresh_gauge() -> void:
	var stamina_col := RinkOS.READOUT if _stamina > 0.25 else RinkOS.ALERT
	var lines := [
		"[%s]%s[/color]" % [RinkOS.bb(RinkOS.DIM), RinkOS.rule("skater", 31)],
		"[%s]SHT[/color] %s %3d%%" % [RinkOS.bb(RinkOS.ACTION), RinkOS.meter_bb(_power, RinkOS.ACTION, 16), roundi(_power * 100.0)],
		"[%s]STM[/color] %s %3d%%" % [RinkOS.bb(stamina_col), RinkOS.meter_bb(_stamina, stamina_col, 16), roundi(_stamina * 100.0)],
	]
	_gauge.text = "\n".join(lines)


## Turns the plain controls list into terminal text: "[b]Gamepad[/b]" headings
## become "// GAMEPAD ----" rules.
func _terminal_help(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("[b]"):
			var close := line.find("[/b]")
			var title := line.substr(3, close - 3)
			var rest := line.substr(close + 4).strip_edges()
			if not out.is_empty() and out[-1] != "":
				out.append("")
			out.append("[%s]%s[/color]" % [RinkOS.bb(RinkOS.READOUT), RinkOS.rule(title, 44)])
			if rest != "":
				out.append("[%s]%s[/color]" % [RinkOS.bb(RinkOS.DIM), rest])
		else:
			out.append(line.replace("[", "[lb]"))
	return "\n".join(out)


func _panel(root: Control, anchor: Vector2, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = RinkOS.HUD_PANEL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = anchor.x
	p.anchor_right = anchor.x
	p.anchor_top = anchor.y
	p.anchor_bottom = anchor.y
	p.offset_left = offset.x
	p.offset_right = offset.x
	p.offset_top = offset.y
	p.offset_bottom = offset.y
	p.grow_horizontal = [Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN][int(anchor.x * 2.0)]
	p.grow_vertical = [Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN][int(anchor.y * 2.0)]
	root.add_child(p)
	return p


func _term_text() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = "TermText"
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _team(team_name: String) -> String:
	return team_name.to_upper().left(3)
