class_name FootHud
extends PanelContainer
## The small clock the owner carries on foot around the rink: day and time,
## the four blocks of the day with the current one lit, the owner's hours
## left today and the cash. Also sits in the office's top bar.
## Call `show_sim(sim)` whenever the sim advances.

var _clock: Label
var _blocks: RichTextLabel
var _hours: RichTextLabel


func _init() -> void:
	theme_type_variation = RinkOS.HUD_PANEL
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	_clock = RinkOS.label("", RinkOS.TERM_LARGE)
	_clock.add_theme_color_override("font_color", RinkOS.ACTION)
	v.add_child(_clock)
	_blocks = _rich()
	v.add_child(_blocks)
	_hours = _rich()
	v.add_child(_hours)


func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = "TermText"
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.custom_minimum_size = Vector2(392, 0)
	return r


func show_sim(sim: RinkSim) -> void:
	var c := OfficeData.clock(sim)
	_clock.text = "%s %s  WK %d" % [c.day_name.to_upper(), c.time, c.week]
	var parts: Array = []
	for i in OfficeData.BLOCKS.size():
		var name: String = ["EARLY", "DAY", "EVENING", "NIGHT"][i]
		var col := RinkOS.ACTION if i == c.block_index else RinkOS.DIM
		parts.append("[%s]%s[/color]" % [RinkOS.bb(col), name])
	_blocks.text = " / ".join(parts)
	var frac: float = c.hours_left / c.hours_max
	var col := RinkOS.GOOD if frac > 0.4 else (RinkOS.ACTION if frac > 0.15 else RinkOS.ALERT)
	var money_col := RinkOS.READOUT if c.money >= 0.0 else RinkOS.ALERT
	# Straight time first; once it's gone the meter reads the overtime left.
	var label := "HRS"
	var shown: float = c.hours_left
	if c.hours_left <= 0.0 and c.get("overtime_left", 0.0) > 0.0:
		label = "[%s]OT [/color]" % RinkOS.bb(RinkOS.ALERT)
		shown = c.overtime_left
		frac = shown / 4.0
		col = RinkOS.ALERT
	_hours.text = "%s %s [%s]%4.1f[/color]  [%s]$%s[/color]" % [label, RinkOS.meter_bb(frac, col, 10), RinkOS.bb(RinkOS.READOUT),
		shown, RinkOS.bb(money_col), _money(c.money)]


static func _money(v: float) -> String:
	var s := str(int(round(absf(v))))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0.0 else "") + s + out
