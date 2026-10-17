class_name RinkOS
extends RefCounted
## RINK-OS: the one UI style for the whole game (match HUD, menus, mini games,
## and later the rink office). It looks like the rink's old office computer:
## pixel type, `//` headers, `----` rules, [ BRACKETED ] buttons and text
## meters, drawn crisp and in full colour on a modern screen.
##
## Everything visual comes from here or from the project theme it builds
## (assets/ui/rinkos_theme.tres, set as gui/theme/custom). Don't hard-code
## fonts or colours in screens; use these constants, the theme type variations
## below and the text helpers. Rebuild the theme after changing this file:
##   godot --headless --path . --script res://scripts/ui/build_theme.gd
## See assets/ui/STYLE.md for the rules.

# --- Palette -----------------------------------------------------------------
const CRT := Color("0a1220")      ## screen background
const PANEL := Color("0f1b2e")    ## panel fill
const BEZEL := Color("2f4a6e")    ## panel borders, secondary buttons
const TEXT := Color("d6e4f5")     ## normal text
const DIM := Color("6f87a6")      ## rules, hints, empty meter cells
const ACTION := Color("ffb22e")   ## anything the player can act on; the clock
const READOUT := Color("5fe0f0")  ## numbers and live values
const GOOD := Color("8cf26a")     ## good news, rising skills
const ALERT := Color("ff5f52")    ## bad news, falling skills, injuries
const ON_ACTION := Color("1a1000") ## text on an ACTION button

# --- Fonts -------------------------------------------------------------------
# The pixel faces are imported with antialiasing, hinting and subpixel
# positioning off (see their .import files). They stay sharp only at sizes
# where one font pixel is a whole number of screen pixels:
#   Silkscreen: multiples of 8 (pixel = 1/8 em)  -> 16, 24, 32, 48
#   VT323:      multiples of 12.5 (pixel = 2/25 em) -> 25, 50
const PIXEL_FONT := preload("res://assets/ui/fonts/silkscreen/Silkscreen-Regular.ttf")
const PIXEL_BOLD := preload("res://assets/ui/fonts/silkscreen/Silkscreen-Bold.ttf")
const TERM_FONT := preload("res://assets/ui/fonts/vt323/VT323-Regular.ttf")
const BODY_FONT := preload("res://assets/ui/fonts/saira/Saira-Variable.ttf")

const PIXEL_SIZE := 16
const PIXEL_TITLE := 24
const PIXEL_BANNER := 48
const TERM_SIZE := 25
const TERM_BIG := 50
const BODY_SIZE := 16

## Theme type variations. Set `control.theme_type_variation` to one of these.
const PIXEL := "PixelLabel"          ## Silkscreen 16, small caps headings
const TITLE := "PixelTitle"          ## Silkscreen 24, screen and card titles
const BANNER := "PixelBanner"        ## Silkscreen 48, GOAL! / SAVE / FINAL
const TERM := "TermLabel"            ## VT323 25, readouts and stat lines
const TERM_DIM := "TermDimLabel"     ## VT323 25 in DIM, rules and hints
const TERM_LARGE := "TermBigLabel"   ## VT323 50, scores and clocks
const GHOST_BUTTON := "GhostButton"  ## secondary button (bezel blue)
const HUD_PANEL := "HudPanel"        ## tighter panel for in-match overlays

const FRAMES := "res://assets/ui/frames/"
## Frames are 16x16 with a 4px pixel notch and a 2px border.
const FRAME_MARGIN := 6


# --- Text helpers ------------------------------------------------------------

## "// TITLE ------------" padded with dashes to `width` characters.
static func rule(title := "", width := 32) -> String:
	var head := "// " + title.to_upper() + (" " if title != "" else "")
	return head + "-".repeat(maxi(width - head.length(), 3))


## A text meter: "[######----]". `value` is 0..1.
static func meter(value: float, cells := 10) -> String:
	var n := clampi(roundi(clampf(value, 0.0, 1.0) * cells), 0, cells)
	return "[" + "#".repeat(n) + "-".repeat(cells - n) + "]"


## The same meter as BBCode (for RichTextLabel), filled cells in `col` and
## empty ones in DIM.
static func meter_bb(value: float, col: Color, cells := 10) -> String:
	var n := clampi(roundi(clampf(value, 0.0, 1.0) * cells), 0, cells)
	return "[lb][%s]%s[/color][%s]%s[/color]]" % [bb(col), "#".repeat(n), bb(DIM), "-".repeat(cells - n)]


## A dotted stat line: "SPEED........ 64". `width` is where the value starts.
static func dots(label: String, value: String, width := 13) -> String:
	var l := key(label)
	return l + ".".repeat(maxi(width - l.length(), 1)) + " " + value


## Terminal-style key: "Shot accuracy" -> "SHOT_ACCURACY".
static func key(text: String) -> String:
	return text.strip_edges().to_upper().replace(" ", "_")


## Button caption: "Next game" -> "[ NEXT GAME ]".
static func caption(text: String) -> String:
	return "[ " + text.to_upper() + " ]"


## Clock text "04:55" from seconds.
static func clock(seconds: float) -> String:
	var c := int(ceilf(maxf(seconds, 0.0)))
	return "%02d:%02d" % [c / 60, c % 60]


## The inside of a BBCode colour tag: "[%s]text[/color]" % RinkOS.bb(RinkOS.ACTION).
static func bb(col: Color) -> String:
	return "color=#" + col.to_html(false)


# --- Node helpers -------------------------------------------------------------

static func label(text := "", variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


static func button(text: String, primary := true) -> Button:
	var b := Button.new()
	b.text = caption(text)
	if not primary:
		b.theme_type_variation = GHOST_BUTTON
	return b


## World-space text for rink signage, the arena scoreboard and screens in the
## open world. Each font pixel is drawn exactly `voxel` metres wide, so signs
## sit on the same grid as the voxel art (0.065 m by default) and stay sharp.
## `pixel_font`: Silkscreen for names and titles; false gives VT323 for
## numbers, clocks and schedules.
static func sign_3d(text: String, col := TEXT, pixel_font := true, voxel := 0.065) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = PIXEL_FONT if pixel_font else TERM_FONT
	l.font_size = PIXEL_SIZE if pixel_font else TERM_SIZE
	# Silkscreen 16 and VT323 25 both draw one font pixel as 2 screen pixels.
	l.pixel_size = voxel / 2.0
	l.modulate = col
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.double_sided = false
	return l


# --- Theme -------------------------------------------------------------------

static func frame(name: String, margin := 10.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(FRAMES + name + ".png")
	s.texture_margin_left = FRAME_MARGIN
	s.texture_margin_top = FRAME_MARGIN
	s.texture_margin_right = FRAME_MARGIN
	s.texture_margin_bottom = FRAME_MARGIN
	s.content_margin_left = margin + 4.0
	s.content_margin_right = margin + 4.0
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


static func flat(col: Color, margin := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.anti_aliasing = false
	s.set_content_margin_all(margin)
	return s


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = BODY_SIZE

	# Text
	t.set_color("font_color", "Label", TEXT)
	_label_variation(t, PIXEL, PIXEL_FONT, PIXEL_SIZE, TEXT)
	_label_variation(t, TITLE, PIXEL_FONT, PIXEL_TITLE, TEXT)
	_label_variation(t, BANNER, PIXEL_BOLD, PIXEL_BANNER, ACTION)
	_label_variation(t, TERM, TERM_FONT, TERM_SIZE, TEXT)
	_label_variation(t, TERM_DIM, TERM_FONT, TERM_SIZE, DIM)
	_label_variation(t, TERM_LARGE, TERM_FONT, TERM_BIG, TEXT)
	t.set_color("font_outline_color", BANNER, CRT)
	t.set_constant("outline_size", BANNER, 8)

	t.set_font("normal_font", "RichTextLabel", BODY_FONT)
	t.set_font("mono_font", "RichTextLabel", TERM_FONT)
	t.set_font("bold_font", "RichTextLabel", PIXEL_FONT)
	t.set_font_size("normal_font_size", "RichTextLabel", BODY_SIZE)
	t.set_font_size("mono_font_size", "RichTextLabel", TERM_SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", PIXEL_SIZE)
	t.set_color("default_color", "RichTextLabel", TEXT)
	# A terminal-text RichTextLabel: everything in VT323 25.
	t.set_type_variation("TermText", "RichTextLabel")
	for k in ["normal_font", "bold_font", "italics_font", "mono_font"]:
		t.set_font(k, "TermText", TERM_FONT)
		t.set_font_size(k + "_size", "TermText", TERM_SIZE)

	# Panels
	for type in ["Panel", "PanelContainer"]:
		t.set_stylebox("panel", type, frame("panel"))
	t.set_type_variation(HUD_PANEL, "PanelContainer")
	t.set_stylebox("panel", HUD_PANEL, frame("panel", 8.0))
	for type in ["PopupMenu", "PopupPanel", "TooltipPanel", "AcceptDialog"]:
		t.set_stylebox("panel", type, frame("panel", 8.0))
	t.set_font("font", "TooltipLabel", TERM_FONT)
	t.set_font_size("font_size", "TooltipLabel", TERM_SIZE)
	t.set_color("font_color", "TooltipLabel", TEXT)

	# Buttons (OptionButton, MenuButton and CheckButton inherit from Button)
	_button(t, "Button", "button", "button_hover", "button_pressed", ON_ACTION)
	t.set_type_variation(GHOST_BUTTON, "Button")
	_button(t, GHOST_BUTTON, "button_ghost", "button_ghost_hover", "button_pressed", TEXT)
	for type in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, frame("focus", 2.0))
		t.set_font("font", type, PIXEL_FONT)
		t.set_font_size("font_size", type, PIXEL_SIZE)
		for c in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(c, type, TEXT)
		t.set_color("font_hover_color", type, ACTION)
		t.set_color("font_disabled_color", type, DIM)
		t.set_icon("checked", type, load(FRAMES + "check_on.png"))
		t.set_icon("unchecked", type, load(FRAMES + "check_off.png"))
		t.set_icon("radio_checked", type, load(FRAMES + "check_on.png"))
		t.set_icon("radio_unchecked", type, load(FRAMES + "check_off.png"))

	# Fields and lists
	for type in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", type, frame("field", 6.0))
		t.set_stylebox("focus", type, frame("focus", 6.0))
		t.set_stylebox("read_only", type, frame("field", 6.0))
		t.set_font("font", type, TERM_FONT)
		t.set_font_size("font_size", type, TERM_SIZE)
		t.set_color("font_color", type, READOUT)
		t.set_color("caret_color", type, ACTION)
		t.set_color("selection_color", type, Color(BEZEL, 0.8))
		t.set_color("font_placeholder_color", type, DIM)
	for type in ["ItemList", "Tree"]:
		t.set_stylebox("panel", type, frame("field", 6.0))
		t.set_stylebox("focus", type, frame("focus", 6.0))
		t.set_font("font", type, TERM_FONT)
		t.set_font_size("font_size", type, TERM_SIZE)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_selected_color", type, ACTION)
		t.set_color("guide_color", type, Color(0, 0, 0, 0))
		for st in ["selected", "selected_focus", "cursor", "cursor_unfocused"]:
			t.set_stylebox(st, type, flat(Color(BEZEL, 0.6)) if st.begins_with("selected") else StyleBoxEmpty.new())
		t.set_stylebox("hovered", type, flat(Color(BEZEL, 0.3)))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# Tabs: active tab is an ACTION block, the rest are bezel blocks.
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, frame("button", 6.0))
		t.set_stylebox("tab_hovered", type, frame("button_ghost_hover", 6.0))
		t.set_stylebox("tab_unselected", type, frame("button_ghost", 6.0))
		t.set_stylebox("tab_disabled", type, frame("button_disabled", 6.0))
		t.set_stylebox("tab_focus", type, frame("focus", 6.0))
		t.set_font("font", type, PIXEL_FONT)
		t.set_font_size("font_size", type, PIXEL_SIZE)
		t.set_color("font_selected_color", type, ON_ACTION)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_color("font_unselected_color", type, TEXT)
		t.set_color("font_disabled_color", type, DIM)
	t.set_stylebox("panel", "TabContainer", frame("panel"))

	# Bars and sliders: flat, square, no gradients.
	t.set_stylebox("background", "ProgressBar", frame("field", 0.0))
	t.set_stylebox("fill", "ProgressBar", flat(READOUT))
	t.set_font("font", "ProgressBar", TERM_FONT)
	t.set_font_size("font_size", "ProgressBar", TERM_SIZE)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_outline_color", "ProgressBar", CRT)
	t.set_constant("outline_size", "ProgressBar", 4)
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, flat(BEZEL, 3.0))
		t.set_stylebox("grabber_area", type, flat(ACTION, 3.0))
		t.set_stylebox("grabber_area_highlight", type, flat(ACTION, 3.0))
		t.set_icon("grabber", type, load(FRAMES + "grabber.png"))
		t.set_icon("grabber_highlight", type, load(FRAMES + "grabber_hover.png"))
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = DIM
		line.thickness = 2
		line.vertical = type == "VSeparator"
		t.set_stylebox("separator", type, line)
	return t


static func _label_variation(t: Theme, name: String, font: Font, size: int, col: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, col)


static func _button(t: Theme, type: String, normal: String, hover: String, pressed: String, ink: Color) -> void:
	t.set_stylebox("normal", type, frame(normal, 8.0))
	t.set_stylebox("hover", type, frame(hover, 8.0))
	t.set_stylebox("pressed", type, frame(pressed, 8.0))
	t.set_stylebox("hover_pressed", type, frame(pressed, 8.0))
	t.set_stylebox("disabled", type, frame("button_disabled", 8.0))
	t.set_stylebox("focus", type, frame("focus", 8.0))
	t.set_font("font", type, PIXEL_FONT)
	t.set_font_size("font_size", type, PIXEL_SIZE)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, type, ink)
	t.set_color("font_disabled_color", type, DIM)
