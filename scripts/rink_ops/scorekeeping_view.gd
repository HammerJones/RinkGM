class_name ScorekeepingView
extends PanelContainer
## The scorekeeper's box on screen: the referee's call at the top, the game
## sheet to fill in (team, numbers, minutes), and the scoreboard's penalty
## clock, which goes on at the next whistle. Six calls, then the sheet goes to
## the league (Scorekeeping is the model).

signal finished(result: Dictionary)

var game: Scorekeeping
var _i := 0
var _t := 0.0                     # seconds since the current call
var _clock_start := -1.0
var _call: RichTextLabel
var _team: OptionButton
var _fields := {}                 # name -> LineEdit
var _minutes := 2
var _min_row: HBoxContainer
var _goal_row: HBoxContainer
var _pen_row: HBoxContainer
var _whistle: Label
var _start: Button
var _log: RichTextLabel


static func create(game_: Scorekeeping) -> ScorekeepingView:
	var v := ScorekeepingView.new()
	v.game = game_
	return v


func _ready() -> void:
	KitHud.place(self, Control.PRESET_CENTER, Vector2(-380, -280), Vector2(760, 0))
	add_theme_stylebox_override("panel", RinkOS.flat(RinkOS.PANEL, 18.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(RinkOS.label("// SCOREKEEPER'S BOX", RinkOS.TITLE))
	_call = RichTextLabel.new()
	_call.bbcode_enabled = true
	_call.fit_content = true
	_call.custom_minimum_size = Vector2(720, 0)
	v.add_child(_call)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	top.add_child(RinkOS.label("TEAM", RinkOS.TERM_DIM))
	_team = OptionButton.new()
	_team.add_item("HOME")
	_team.add_item("VISITORS")
	top.add_child(_team)

	_goal_row = HBoxContainer.new()
	_goal_row.add_theme_constant_override("separation", 10)
	v.add_child(_goal_row)
	for f in [["scorer", "GOAL #"], ["a1", "ASSIST #"], ["a2", "ASSIST #"]]:
		_goal_row.add_child(RinkOS.label(f[1], RinkOS.TERM_DIM))
		_goal_row.add_child(_number(f[0]))

	_pen_row = HBoxContainer.new()
	_pen_row.add_theme_constant_override("separation", 10)
	v.add_child(_pen_row)
	_pen_row.add_child(RinkOS.label("PLAYER #", RinkOS.TERM_DIM))
	_pen_row.add_child(_number("player"))
	_pen_row.add_child(RinkOS.label("MINUTES", RinkOS.TERM_DIM))
	_min_row = HBoxContainer.new()
	_pen_row.add_child(_min_row)
	for m in [2, 5, 10]:
		var b := RinkOS.button(str(m), false)
		b.set_meta("minutes", m)
		b.pressed.connect(func():
			_minutes = m
			_paint_minutes())
		_min_row.add_child(b)
	_start = RinkOS.button("START PENALTY CLOCK", false)
	_start.pressed.connect(func():
		if _clock_start < 0.0:
			_clock_start = _t
			_start.text = "CLOCK RUNNING")
	_pen_row.add_child(_start)
	_whistle = RinkOS.label("", RinkOS.TERM)
	_whistle.add_theme_color_override("font_color", RinkOS.ACTION)
	v.add_child(_whistle)

	var submit := RinkOS.button("WRITE IT DOWN")
	submit.pressed.connect(_submit)
	v.add_child(submit)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	v.add_child(_log)
	_show_call()


func _number(id: String) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(70, 0)
	e.max_length = 2
	e.placeholder_text = "--"
	_fields[id] = e
	return e


func _process(dt: float) -> void:
	if _i >= game.calls.size():
		return
	_t += dt
	var c: Dictionary = game.calls[_i]
	if c.kind == "penalty":
		_whistle.text = "*TWEET* FACEOFF. THE PLAY'S ON." if _t >= float(c.whistle) else "Players lining up for the faceoff..."


func _show_call() -> void:
	_t = 0.0
	_clock_start = -1.0
	_minutes = 2
	for f in _fields.values():
		f.text = ""
	var c: Dictionary = game.calls[_i]
	var is_goal: bool = c.kind == "goal"
	_goal_row.visible = is_goal
	_pen_row.visible = not is_goal
	_whistle.visible = not is_goal
	_start.text = "START PENALTY CLOCK"
	_paint_minutes()
	_call.text = "[color=#%s]CALL %d OF %d[/color]\n[color=#%s]REF:[/color] \"%s\"" % [RinkOS.DIM.to_html(false), _i + 1, game.calls.size(),
		RinkOS.READOUT.to_html(false), game.call_text(_i)]


func _paint_minutes() -> void:
	for b in _min_row.get_children():
		(b as Button).modulate = RinkOS.ACTION if int(b.get_meta("minutes")) == _minutes else Color.WHITE


func _submit() -> void:
	var sheet := {"team": "home" if _team.selected == 0 else "away", "scorer": _fields.scorer.text.to_int(),
		"assists": [_fields.a1.text.to_int(), _fields.a2.text.to_int()], "player": _fields.player.text.to_int(),
		"minutes": _minutes, "clock_start": _clock_start}
	var m := game.check(_i, sheet)
	_log.text = "[color=#%s]%s[/color]" % [(RinkOS.GOOD if m.ok else RinkOS.ALERT).to_html(false), "Got it." if m.ok else "; ".join(m.errors)]
	_i += 1
	if _i >= game.calls.size():
		finished.emit(game.result())
		return
	_show_call()
