class_name Hud
extends CanvasLayer
## Scoreboard, clock, physics-mode readout, shot power / stamina bars,
## centre-screen messages and a toggleable controls card.

const HELP := """[b]Gamepad[/b]
L-stick  skate      L3  dash      R3  hockey stop
R-stick  stick blade (90 deg arc), side to side to stickhandle
  pull back, then push forward = shot
LT  lift stick (hold while pulling back = slapshot,
  on D = stick lift)   RT  tilt blade (raise shots/passes)
A / RB  pass, or call for it    B  body check
Back  physics mode   D-up  camera   Start  restart

[b]Keyboard + mouse[/b]  (the mouse is the right stick)
WASD  skate    Shift  dash    Space  stop
RMB  lift stick    LMB  tilt blade (hold for more)
E  pass / call for it    F  check    [ ]  mouse sensitivity
Esc  free the cursor   F1  physics mode   C  camera   R  restart
H  hide this"""

var _score: Label
var _mode: Label
var _message: Label
var _power: ProgressBar
var _stamina: ProgressBar
var _help: RichTextLabel
var _message_timer := 0.0
var _help_timer := 15.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-170, 12)
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.08, 0.1, 0.85)))
	root.add_child(panel)
	_score = _label(26)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_score)

	var mode_panel := PanelContainer.new()
	mode_panel.position = Vector2(12, 12)
	mode_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.08, 0.1, 0.75)))
	root.add_child(mode_panel)
	_mode = _label(15)
	mode_panel.add_child(_mode)

	_message = _label(56)
	_message.set_anchors_preset(Control.PRESET_CENTER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.position = Vector2(-300, -140)
	_message.size = Vector2(600, 80)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 10)
	root.add_child(_message)

	_power = _bar(Color("f0c040"))
	_power.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_power.position = Vector2(-120, -60)
	root.add_child(_power)
	_stamina = _bar(Color("5fd38a"))
	_stamina.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina.position = Vector2(-120, -34)
	_stamina.custom_minimum_size = Vector2(240, 8)
	root.add_child(_stamina)

	_help = RichTextLabel.new()
	_help.bbcode_enabled = true
	_help.text = HELP
	_help.fit_content = true
	_help.custom_minimum_size = Vector2(470, 0)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(16, -340)
	_help.add_theme_font_size_override("normal_font_size", 13)
	_help.add_theme_font_size_override("bold_font_size", 14)
	_help.add_theme_stylebox_override("normal", _box(Color(0.08, 0.08, 0.1, 0.7)))
	root.add_child(_help)


func _process(delta: float) -> void:
	_message_timer -= delta
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_help.visible = false
	if _message_timer <= 0.0:
		_message.text = ""


func set_score(home: String, away: String, a: int, b: int, clock: float) -> void:
	var c := maxf(clock, 0.0)
	_score.text = "%s  %d   %d:%02d   %d  %s" % [home, a, int(c) / 60, int(c) % 60, b, away]


func set_mode(mode_name: String) -> void:
	_mode.text = "Physics: %s   (F1 / Back to change)" % mode_name


func show_message(text: String, seconds: float) -> void:
	_message.text = text
	_message_timer = seconds


func set_power(v: float) -> void:
	_power.visible = v > 0.0
	_power.value = v * 100.0


func set_stamina(v: float) -> void:
	_stamina.value = v * 100.0


func toggle_help() -> void:
	_help_timer = 0.0
	_help.visible = not _help.visible


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	return l


func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(240, 14)
	b.show_percentage = false
	b.add_theme_stylebox_override("fill", _box(col))
	b.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5)))
	return b


func _box(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s
