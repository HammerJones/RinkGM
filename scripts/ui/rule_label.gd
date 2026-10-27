class_name RuleLabel
extends Label
## A "// TITLE --------" header whose dashes run to the edge of whatever holds
## it. `min_chars` is the narrowest it gets; past that it fills, and clips
## rather than pushing the screen wider, so a rule never sets a page's width
## (RinkOS.rule() counts characters and does).

var title := ""
var min_chars := 24


func _init(title_ := "", min_chars_ := 24, variation := RinkOS.TERM_DIM) -> void:
	title = title_
	min_chars = min_chars_
	theme_type_variation = variation
	clip_text = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_fill)


func _ready() -> void:
	_fill()


func _fill() -> void:
	var cw := get_theme_font("font").get_char_size("-".unicode_at(0), get_theme_font_size("font_size")).x
	if cw <= 0.0:
		return
	custom_minimum_size.x = min_chars * cw
	text = RinkOS.rule(title, maxi(int(size.x / cw), min_chars))
