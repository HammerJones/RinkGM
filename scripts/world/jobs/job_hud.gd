class_name JobHud
extends CanvasLayer
## The mini games' RinkOS overlay: the checklist on the left, the tool's feel
## (the tray, effort, the dial, the sight glass) on the right and the current
## prompt along the bottom. JobScene fills it every tick through show_state().

var _title: Label
var _steps: RichTextLabel
var _tool: RichTextLabel
var _prompt: Label
var _hint: RichTextLabel
var _tool_panel: PanelContainer


func _init() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var left := _panel(root, Vector2(20, 20), Vector2(470, 0))
	var lv := VBoxContainer.new()
	left.add_child(lv)
	_title = RinkOS.label("", RinkOS.TITLE)
	lv.add_child(_title)
	lv.add_child(RinkOS.rule_label("steps", 34, RinkOS.TERM_DIM))
	_steps = _rich(440)
	lv.add_child(_steps)

	_tool_panel = _panel(root, Vector2(-20, 20), Vector2(440, 0), true)
	var rv := VBoxContainer.new()
	_tool_panel.add_child(rv)
	rv.add_child(RinkOS.rule_label("tool", 32, RinkOS.TERM_DIM))
	_tool = _rich(410)
	rv.add_child(_tool)

	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = -480
	bottom.offset_right = 480
	bottom.offset_top = -150
	bottom.offset_bottom = -20
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	bv.add_child(RinkOS.rule_label("now", 62, RinkOS.TERM_DIM))
	_prompt = RinkOS.label("")
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(920, 0)
	bv.add_child(_prompt)
	_hint = _rich(920)
	bv.add_child(_hint)


func _panel(root: Control, at: Vector2, size: Vector2, right := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = size
	if right:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.offset_left = at.x - size.x
		p.offset_right = at.x
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		p.offset_left = at.x
		p.offset_right = at.x + size.x
	p.offset_top = at.y
	root.add_child(p)
	return p


func _rich(width: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(width, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", RinkOS.TERM_FONT)
	r.add_theme_font_size_override("normal_font_size", RinkOS.TERM_SIZE)
	r.add_theme_color_override("default_color", RinkOS.TEXT)
	return r


func show_state(title: String, steps: PackedStringArray, prompt: String, hint: String, tool_lines: PackedStringArray, complete: bool) -> void:
	_title.text = "// " + title.to_upper()
	_steps.text = "\n".join(steps)
	_prompt.text = prompt
	_hint.text = "[%s]%s[/color]" % [RinkOS.bb(RinkOS.ACTION), hint]
	_tool.text = "\n".join(tool_lines)
	_tool_panel.visible = not tool_lines.is_empty() and not complete


## The text the HUD shows (tests read it).
func text() -> String:
	return "%s\n%s\n%s\n%s\n%s" % [_title.text, _steps.text, _prompt.text, _hint.text, _tool.text]
