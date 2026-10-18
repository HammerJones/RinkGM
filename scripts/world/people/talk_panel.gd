class_name TalkPanel
extends PanelContainer
## The conversation box: who's talking, what they said, and your options.
## Number keys (or up/down and Enter, or the d-pad and A) pick an option.
## Uses the project's RinkOS theme; the UI thread owns the final look.
##
##   var panel := TalkPanel.new(); canvas_layer.add_child(panel)
##   panel.show_conversation(people.talk(agent, me))
##   panel.closed.connect(people.end_talk)

signal closed

var conv: Conversation
var _who: Label
var _line: Label
var _opts: VBoxContainer
var _sel := 0


func _ready() -> void:
	anchor_left = 0.15
	anchor_right = 0.85
	anchor_top = 0.62
	anchor_bottom = 0.96
	var box := VBoxContainer.new()
	add_child(box)
	_who = Label.new()
	_who.add_theme_color_override("font_color", Color("e0a43a"))
	box.add_child(_who)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	box.add_child(HSeparator.new())
	_opts = VBoxContainer.new()
	box.add_child(_opts)
	hide()


func show_conversation(c: Conversation) -> void:
	conv = c
	_sel = 0
	show()
	_refresh()


func _refresh() -> void:
	if conv == null or conv.ended:
		hide()
		conv = null
		closed.emit()
		return
	var p := conv.speaker
	_who.text = "// %s%s" % [p.known_as.to_upper(), "  ----  " + p.name if p.known_as != p.name else ""]
	_line.text = conv.line
	for c in _opts.get_children():
		c.queue_free()
	for i in conv.choices.size():
		var l := Label.new()
		l.text = "%s %d. %s" % [">" if i == _sel else " ", i + 1, conv.choices[i].text]
		_opts.add_child(l)


func pick(i: int) -> void:
	if conv == null:
		return
	conv.choose(i)
	_sel = 0
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if conv == null or not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode >= KEY_1 and e.keycode <= KEY_9:
			pick(e.keycode - KEY_1)
		elif e.keycode == KEY_UP:
			_sel = posmod(_sel - 1, conv.choices.size())
			_refresh()
		elif e.keycode == KEY_DOWN:
			_sel = posmod(_sel + 1, conv.choices.size())
			_refresh()
		elif e.keycode in [KEY_ENTER, KEY_SPACE]:
			pick(_sel)
		elif e.keycode == KEY_ESCAPE:
			conv = null
			_refresh()
		else:
			return
		get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_DPAD_UP:
				_sel = posmod(_sel - 1, conv.choices.size())
				_refresh()
			JOY_BUTTON_DPAD_DOWN:
				_sel = posmod(_sel + 1, conv.choices.size())
				_refresh()
			JOY_BUTTON_A: pick(_sel)
			JOY_BUTTON_B:
				conv = null
				_refresh()
		get_viewport().set_input_as_handled()
