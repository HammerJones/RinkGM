class_name WalkHud
extends CanvasLayer
## The one first-person overlay, in the RINK-OS style (assets/ui/STYLE.md):
## every walking scene (the venue walk, the framework demos, a job) draws
## its hints through this and nowhere else, so a hint always looks the
## same and sits in the same place.
##
##   readout   top left, READOUT cyan: live values (where you are, counts)
##   prompt    just under the centre dot, ACTION amber: what a press does
##             now, as "[KEY] VERB" pairs in caps ("[LMB] TAKE   [E] USE")
##   toast     lower centre, ACTION amber, 3.5 s: what just happened
##   legend    bottom left, DIM: the controls that always apply
##   panel     centre: long text (a notice, a screen), BBCode
##   dot       the 3 px centre mark everything aims through
##
##   var hud := WalkHud.new()
##   add_child(hud)
##   hud.bind(interactor)        # prompt and inspect toasts come by themselves
##   hud.readout("LOBBY   12 ROWS")
##   hud.legend("[WASD] WALK   [SHIFT] RUN")
##   hud.toast("SAVED")
##
## Nothing here takes mouse events: the captured cursor sits on the dot.

const TOAST_SECONDS := 3.5
const WIDE := 600.0

var readout_label: Label
var prompt_label: Label
var toast_label: Label
var legend_label: Label
var panel: PanelContainer
var panel_text: RichTextLabel
var dot: ColorRect

var extra_prompt := ""  # shown while the interactor has nothing to say
var _toast_t := 0.0
var _interactor: Interactor


func _ready() -> void:
	layer = 20
	readout_label = _label(RinkOS.READOUT)
	readout_label.position = Vector2(16, 12)
	add_child(readout_label)
	prompt_label = _label(RinkOS.ACTION, true)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-WIDE / 2, 10)  # right under the dot
	prompt_label.size = Vector2(WIDE, 40)
	add_child(prompt_label)
	toast_label = _label(RinkOS.ACTION, true)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-WIDE / 2, -120)
	toast_label.size = Vector2(WIDE, 40)
	toast_label.visible = false
	add_child(toast_label)
	legend_label = _label(RinkOS.DIM)
	legend_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend_label.offset_left = 16
	legend_label.offset_top = -44
	legend_label.offset_bottom = -12
	legend_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(legend_label)
	dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.size = Vector2(3, 3)
	dot.position = Vector2(-1.5, -1.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 420)
	panel.position = Vector2(-360, -210)
	panel.add_theme_stylebox_override("panel", RinkOS.flat(RinkOS.PANEL, 18.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_text = RichTextLabel.new()
	panel_text.bbcode_enabled = true
	panel_text.fit_content = true
	panel_text.scroll_active = true
	panel_text.custom_minimum_size = Vector2(684, 384)
	panel_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_text)
	panel.visible = false
	add_child(panel)


func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			toast_label.visible = false
	if _interactor:
		var p := _interactor.prompt()
		prompt_label.text = p if p != "" else extra_prompt


## Prompt and inspect text follow this interactor.
func bind(i: Interactor) -> void:
	_interactor = i
	if i.objects and not i.objects.inspected.is_connected(_on_inspected):
		i.objects.inspected.connect(_on_inspected)


func readout(text: String) -> void:
	readout_label.text = text


func prompt(text: String) -> void:
	prompt_label.text = text


func legend(text: String) -> void:
	legend_label.text = text


func toast(text: String, seconds := TOAST_SECONDS) -> void:
	toast_label.text = text
	toast_label.visible = text != ""
	_toast_t = seconds


func show_panel(bb: String) -> void:
	panel_text.text = bb
	panel.visible = true


func hide_panel() -> void:
	panel.visible = false


func panel_open() -> bool:
	return panel.visible


func _on_inspected(_row: PropRow, text: String) -> void:
	toast(text)


static func _label(col: Color, centred := false) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
