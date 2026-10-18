extends CanvasLayer
## The Esc / Start menu, autoloaded as PauseMenu. In a match it pauses the
## game and offers Resume, Restart, Controls, Practice, Quit to hub and Quit
## game; in practice, Reset puck and a goalie toggle; on the hub screens just
## Quit game. Leaving a career game that isn't over asks first, since nothing
## from it is recorded. RINK-OS styled (assets/ui/STYLE.md).
##
## Opening it frees the cursor and closing it recaptures the cursor in a
## match; while it's closed, Esc still frees the cursor (PlayerInput's
## free_mouse). It talks to the match through Game's menu API (restart,
## practice_reset_puck, set_practice_goalie, leaving_loses_game, is_recorded)
## and to CareerState for scene changes.

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _info: RichTextLabel
var _was_paused := false


func _ready() -> void:
	layer = 90  # under the dev menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_visible(false)
	if "--test=pausemenu" in OS.get_cmdline_user_args():
		_self_test.call_deferred()


func _input(event: InputEvent) -> void:
	var pressed := false
	if InputMap.has_action("pause_menu"):
		pressed = event.is_action_pressed("pause_menu")
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = event.physical_keycode == KEY_ESCAPE
	if not pressed:
		return
	var dev := get_node_or_null("/root/DevMenu")
	if dev and dev.has_method("is_open") and dev.is_open():
		return
	get_viewport().set_input_as_handled()
	if is_open() and _list.get_child_count() > 0 and _title.text != _main_title():
		_show_main()  # Esc on a sub-page goes back
	else:
		set_open(not is_open())


func is_open() -> bool:
	return _panel.visible


func set_open(open: bool) -> void:
	if open == is_open():
		return
	_set_visible(open)
	if open:
		_was_paused = get_tree().paused
		get_tree().paused = true
		Engine.time_scale = 1.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_main()
	else:
		get_tree().paused = _was_paused
		_recapture()


# ---------------------------------------------------------------- pages

func _show_main() -> void:
	_clear()
	_info.visible = false
	var g := _game()
	_title.text = _main_title()
	_add("Resume", set_open.bind(false))
	if g == null:
		_add("Quit game", _quit_game, false)
		_focus_first()
		return
	if g.practice:
		_add("Reset puck", func():
			set_open(false)
			g.practice_reset_puck())
		_add("Goalie: %s" % ("on" if g.practice_has_goalie() else "off"), func():
			g.set_practice_goalie(not g.practice_has_goalie())
			_show_main(), false)
	if g.career_mode and g.is_recorded():
		_add("Continue", _leave.bind(CareerState.back_to_hub))
	else:
		_add("Restart", _confirmed.bind(g.leaving_loses_game(), "Restart this game?", "You'll start over from the opening faceoff. Nothing from this game is recorded.", "Restart", _leave.bind(g.restart)), false)
	_add("Controls", _show_controls, false)
	if not g.practice:
		_add("Practice", _confirmed.bind(g.leaving_loses_game(), "Leave for practice?", "This game won't be recorded. Your career picks up at the same game.", "Practice", _leave.bind(CareerState.start_practice)), false)
	_add("Leave practice" if g.practice else "Quit to hub", _confirmed.bind(g.leaving_loses_game(), "Quit to the hub?", "This game won't be recorded. Your career picks up at the same game.", "Quit to hub", _leave.bind(CareerState.back_to_hub)), false)
	_add("Quit game", _confirmed.bind(g.leaving_loses_game(), "Quit the game?", "This game won't be recorded. Your career picks up at the same game.", "Quit game", _quit_game), false)
	_focus_first()


func _main_title() -> String:
	var g := _game()
	if g == null:
		return "MENU"
	return "PRACTICE" if g.practice else "PAUSED"


func _show_controls() -> void:
	_clear()
	_title.text = "CONTROLS"
	_info.text = Hud._terminal_help(Hud.HELP)
	_info.visible = true
	_add("Back", _show_main)
	_focus_first()


## Runs `action`, or first asks when `ask` (leaving a career game in progress).
func _confirmed(ask: bool, question: String, detail: String, yes: String, action: Callable) -> void:
	if not ask:
		action.call()
		return
	_clear()
	_title.text = question.to_upper()
	_info.text = "[%s]%s[/color]" % [RinkOS.bb(RinkOS.ALERT), detail]
	_info.visible = true
	_add(yes, action)
	_add("Back", _show_main, false)
	_focus_first()


## Closes the menu and unpauses before a scene change (or a restart).
func _leave(action: Callable) -> void:
	_set_visible(false)
	get_tree().paused = false
	action.call()


func _quit_game() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- helpers

func _game() -> Node:
	var s := get_tree().current_scene
	return s if s != null and "practice" in s and s.has_method("restart") else null


func _recapture() -> void:
	var g := _game()
	if g and not g.autoplay and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_visible(v: bool) -> void:
	_dim.visible = v
	_panel.visible = v


func _clear() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func _add(text: String, cb: Callable, primary := true) -> Button:
	var b := RinkOS.button(text, primary)
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_FILL
	_list.add_child(b)
	return b


func _focus_first() -> void:
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(RinkOS.CRT, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_title = RinkOS.label("", RinkOS.TITLE)
	v.add_child(_title)
	v.add_child(RinkOS.label(RinkOS.rule("rink-os", 34), RinkOS.TERM_DIM))
	_info = RichTextLabel.new()
	_info.theme_type_variation = "TermText"
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_info)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)


# ---------------------------------------------------------------- self test
# `-- --test=pausemenu`: drives the menu through a match, practice, the hub
# and a career game, then quits. Prints "pausemenu test: all passed".

var _fails := 0


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


func _labels() -> Array:
	return _list.get_children().map(func(b): return b.text)


func _press(caption: String) -> bool:
	for b in _list.get_children():
		if b.text == RinkOS.caption(caption):
			b.pressed.emit()
			return true
	print("  no button ", caption, " in ", _labels())
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = "pause_menu"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)


func _self_test() -> void:
	await _frames(10)
	var g := _game()
	_check(g != null and not g.practice, "starts in a match")

	# Esc opens and pauses
	await _esc()
	_check(is_open() and get_tree().paused, "Esc opens the menu and pauses")
	var t: float = g.time
	await _frames(20)
	_check(g.time == t, "the match is paused")
	for want in ["Resume", "Restart", "Controls", "Practice", "Quit to hub", "Quit game"]:
		_check(_labels().has(RinkOS.caption(want)), "match menu has " + want)
	_press("Controls")
	_check(_info.visible and _info.text.contains("WASD"), "Controls shows the controls card")
	await _esc()
	_check(is_open() and _title.text == "PAUSED", "Esc on a sub-page goes back")

	# Restart (an exhibition starts over), then Resume
	g.dev_set_score(0, 3)
	_press("Restart")
	await _frames(2)
	_check(not is_open() and not get_tree().paused and g.score == [0, 0], "Restart starts the exhibition over")
	await _esc()
	_press("Resume")
	await _frames(20)
	_check(not is_open() and g.time > t, "Resume unpauses")

	# practice
	await _esc()
	_press("Practice")
	await _frames(10)
	var p := _game()
	_check(p != null and p != g and p.practice, "Practice opens practice mode")
	if p:
		_check(p.skaters.size() == 1 and p.goalies.is_empty(), "practice: one skater, no goalie")
		await _esc()
		for want in ["Reset puck", "Goalie: off", "Leave practice"]:
			_check(_labels().has(RinkOS.caption(want)), "practice menu has " + want)
		_check(not _labels().has(RinkOS.caption("Practice")), "practice menu has no Practice")
		_press("Goalie: off")
		_check(p.goalies.size() == 1 and _labels().has(RinkOS.caption("Goalie: on")), "goalie toggle adds a goalie")
		_press("Leave practice")
		await _frames(10)
	_check(_game() == null and not get_tree().paused, "Leave practice goes to the hub")
	await _esc()
	_check(is_open() and _labels() == [RinkOS.caption("Resume"), RinkOS.caption("Quit game")], "hub menu: Resume and Quit game")
	await _esc()
	_check(not is_open(), "Esc closes the hub menu")

	# a career game asks before leaving, and records nothing
	var c := Career.new_demo("demo_low", "Menu", "Test", "C", 3)
	c.save_path = "user://test_pausemenu.json"
	CareerState.career = c
	var m := c.next_user_game()
	while m.is_empty():
		c.play_round()
		m = c.next_user_game()
	var gp: int = c.user().season_stats.gp
	CareerState.play_match(m)
	await _frames(10)
	var cg := _game()
	_check(cg != null and cg.career_mode and cg.leaving_loses_game(), "career game running")
	await _esc()
	_press("Quit to hub")
	_check(_title.text == "QUIT TO THE HUB?", "leaving a career game asks first")
	_press("Back")
	_check(_title.text == "PAUSED", "Back returns to the menu")
	_press("Quit to hub")
	_press("Quit to hub")
	await _frames(10)
	_check(_game() == null and CareerState.fixture.is_empty() and c.user().season_stats.gp == gp, "quitting records nothing")
	CareerState.career = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pausemenu.json"))

	print("pausemenu test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)
