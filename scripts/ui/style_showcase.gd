extends Control
## RINK-OS style sheet: every themed control on one screen, laid out like a
## career menu, so new screens can copy from it and theme changes can be
## checked at a glance. Run scenes/ui/rinkos_showcase.tscn.
## `-- --screenshot=out.png` saves a frame and quits.

const SKILLS := [
	["Speed", 64, 1], ["Agility", 58, 0], ["Stick handling", 71, 1],
	["Shot accuracy", 55, 0], ["Shot power", 62, 0], ["Shot release", 72, 1],
	["Pass quality", 49, -1], ["Hitting", 40, 0], ["Toughness", 52, 0],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = RinkOS.CRT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	page.add_child(RinkOS.rule_label("rink-os 3.0  millbrook community arena", 24, RinkOS.TERM_DIM))
	page.add_child(RinkOS.label("Player file", RinkOS.TITLE))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)
	cols.add_child(_player_card())
	cols.add_child(_controls_column())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	page.add_child(buttons)
	buttons.add_child(RinkOS.button("Next game"))
	buttons.add_child(RinkOS.button("Tryouts", false))
	var off := RinkOS.button("Playoffs")
	off.disabled = true
	buttons.add_child(off)
	var hint := RinkOS.label("Long text such as coach notes, emails and tutorials uses the plain body face so it stays easy to read.")
	hint.add_theme_color_override("font_color", RinkOS.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons.add_child(hint)

	RinkOS.capture_from_args(self)


func _player_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	card.add_child(v)
	v.add_child(RinkOS.rule_label("player_file", 44, RinkOS.TERM_DIM))
	v.add_child(RinkOS.label("#17 Kowalski", RinkOS.TITLE))
	v.add_child(RinkOS.label("Left wing · Tuesday Night Pucks · Game 7 of 14"))
	var lines := PackedStringArray()
	for s in SKILLS:
		var trend := ""
		if s[2] > 0:
			trend = " [%s]++[/color]" % RinkOS.bb(RinkOS.GOOD)
		elif s[2] < 0:
			trend = " [%s]--[/color]" % RinkOS.bb(RinkOS.ALERT)
		var val := "[%s]%d[/color]" % [RinkOS.bb(RinkOS.READOUT), s[1]]
		lines.append(RinkOS.dots(s[0], val, 15) + " " + RinkOS.meter_bb(s[1] / 100.0, RinkOS.READOUT) + trend)
	lines.append("[%s]%s[/color]" % [RinkOS.bb(RinkOS.DIM), "-".repeat(36)])
	lines.append(RinkOS.dots("Status", "[%s]FIT[/color]   NEXT: [%s]TRYOUT_INVITE[/color]" % [RinkOS.bb(RinkOS.GOOD), RinkOS.bb(RinkOS.ACTION)], 15))
	var stats := RichTextLabel.new()
	stats.theme_type_variation = "TermText"
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.text = "\n".join(lines)
	v.add_child(stats)
	return card


func _controls_column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tabs := TabBar.new()
	for t in ["Season", "Standings", "Rink", "Settings"]:
		tabs.add_tab(t.to_upper())
	v.add_child(tabs)

	var standings := ItemList.new()
	standings.custom_minimum_size = Vector2(0, 150)
	for row in ["1  ICE DOGS ........ 14 PTS", "2  TUESDAY PUCKS ... 12 PTS", "3  ZAMBONI KINGS ... 9 PTS", "4  OLD TIMERS ...... 4 PTS"]:
		standings.add_item(row)
	standings.select(1)
	v.add_child(standings)

	v.add_child(RinkOS.label("Rink name", RinkOS.PIXEL))
	var name_edit := LineEdit.new()
	name_edit.text = "Millbrook Community Arena"
	v.add_child(name_edit)

	var check := CheckBox.new()
	check.text = "SHOW CONTROLS CARD"
	check.button_pressed = true
	v.add_child(check)

	v.add_child(RinkOS.label("Zamboni repair", RinkOS.PIXEL))
	var bar := ProgressBar.new()
	bar.value = 62
	bar.custom_minimum_size = Vector2(0, 28)
	v.add_child(bar)

	var slider := HSlider.new()
	slider.value = 40
	v.add_child(slider)
	return v
