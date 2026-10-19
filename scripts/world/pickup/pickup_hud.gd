class_name PickupHud
extends CanvasLayer
## The pickup game's few words on screen: the score in the corner, what E
## does near the court, the call ("CHECK.", "GAME."), a dot to aim with and
## the power bar while the player holds the ball (RinkOS colours, STYLE.md).

var game: PickupRun

var _score: Label
var _prompt: Label
var _call: Label
var _call_t := 0.0
var _dot: ColorRect
var _meter: Control
var _fill: ColorRect
var _band: ColorRect
var _result_t := 0.0
var _was_charging := false

const METER_H := 160.0


func _ready() -> void:
	layer = 5
	_score = _label(RinkOS.READOUT)
	_score.size = Vector2(600, 30)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt = _label(RinkOS.ACTION)
	_prompt.size = Vector2(800, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call = _label(RinkOS.TEXT)
	_call.size = Vector2(800, 30)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dot = ColorRect.new()
	_dot.color = RinkOS.TEXT
	_dot.size = Vector2(4, 4)
	add_child(_dot)
	_meter = Control.new()
	add_child(_meter)
	var back := ColorRect.new()
	back.color = RinkOS.PANEL
	back.size = Vector2(16, METER_H)
	_meter.add_child(back)
	_band = ColorRect.new()
	_band.color = RinkOS.GOOD.darkened(0.2)
	_meter.add_child(_band)
	_fill = ColorRect.new()
	_fill.color = RinkOS.ACTION
	_meter.add_child(_fill)
	if game:
		game.said.connect(_on_said)


func _label(col: Color) -> Label:
	var l := RinkOS.label("", RinkOS.TERM)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(l)
	return l


func _on_said(text: String) -> void:
	_call.text = text
	_call_t = 3.0


func _process(dt: float) -> void:
	if game == null or not is_instance_valid(game):
		visible = false
		return
	# laid out against the window each frame (a CanvasLayer has no parent rect)
	var vp := get_viewport().get_visible_rect().size
	_score.position = Vector2(vp.x - 620.0, 12.0)
	_prompt.position = Vector2(vp.x * 0.5 - 400.0, vp.y - 170.0)
	_call.position = Vector2(vp.x * 0.5 - 400.0, 90.0)
	_dot.position = vp * 0.5 - Vector2(2, 2)
	_meter.position = vp * 0.5 + Vector2(60.0, -METER_H * 0.5)
	_score.text = game.score_text()
	_prompt.text = game.prompt()
	_call_t -= dt
	_call.visible = _call_t > 0.0
	_dot.visible = game.is_playing()
	var band := game.meter_band()
	var charging := game.meter >= 0.0
	if _was_charging and not charging:
		_result_t = 0.8  # show where the shot went for a moment
	_was_charging = charging
	_result_t -= dt
	_meter.visible = game.player_has_ball() or charging or _result_t > 0.0
	var v := game.meter_value() if charging else float(game.last_meter.get("power", 0.0)) if _result_t > 0.0 else 0.0
	_band.position = Vector2(0, METER_H * (1.0 - band.x - band.y))
	_band.size = Vector2(16, METER_H * band.y * 2.0)
	_fill.position = Vector2(4, METER_H * (1.0 - v))
	_fill.size = Vector2(8, METER_H * v)
	if _result_t > 0.0 and not charging:
		_fill.color = RinkOS.GOOD if bool(game.last_meter.get("green", false)) else RinkOS.ALERT
	else:
		_fill.color = RinkOS.ACTION
		if not charging:
			_fill.size.y = 0.0
