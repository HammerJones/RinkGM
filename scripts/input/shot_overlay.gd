class_name ShotOverlay
extends CanvasLayer
## What the keyboard + mouse player sees of their own hands:
##   - the centre dot while looking around (LMB): it's the aim
##   - while drawing a shot (RMB), the chosen pattern as a faint guide with a
##     dot where the mouse has got to (V cycles: wrist, snap, slap, toe drag,
##     off; wrist by default, per Sean's sketch)
##   - the stickhandling rhythm gauge while carrying the puck: green is
##     within what your stickhandling handles, amber close, red and the puck
##     starts getting away

const KINDS: Array = [&"wrist_shot", &"snap_shot", &"slapshot", &"toe_drag_shot", &""]

## The pattern shown while drawing (&"" = off). Kept for the session.
static var guide: StringName = &"wrist_shot"

var _looking := false
var _tracing := false
var _pos := Vector2.ZERO
var _load := -1.0
var _shown := 0.0
var _canvas: Control


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shot_overlay"):
		guide = KINDS[(KINDS.find(guide) + 1) % KINDS.size()]
		_shown = 1.5


## Called every tick by HumanController. `handle_load` < 0 hides the gauge.
func show_state(looking: bool, tracing: bool, trace_pos: Vector2, handle_load: float) -> void:
	_looking = looking
	_tracing = tracing
	_pos = trace_pos
	_load = handle_load
	_canvas.queue_redraw()


func _process(dt: float) -> void:
	if _shown > 0.0:
		_shown -= dt
		_canvas.queue_redraw()


func _draw_canvas() -> void:
	var size := _canvas.size
	var mid := size * 0.5
	if _looking or _tracing:
		_canvas.draw_circle(mid, 3.0, Color(1, 1, 1, 0.9))
		_canvas.draw_arc(mid, 5.0, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
	if _tracing or _shown > 0.0:
		# the guide sits low in the middle; a pattern starts at its origin
		var origin := mid + Vector2(0, size.y * 0.3)
		if guide != &"":
			var pts := ShotPatterns.outline(guide)
			var line := PackedVector2Array()
			for p in pts:
				line.append(origin + Vector2(p.x, -p.y))
			_canvas.draw_polyline(line, Color(1, 1, 1, 0.28), 6.0, true)
			_canvas.draw_circle(line[0], 7.0, Color(1, 1, 1, 0.28))
			var tip := line[line.size() - 1]
			var back := (line[line.size() - 2] - tip).normalized() * 14.0
			_canvas.draw_line(tip, tip + back.rotated(0.5), Color(1, 1, 1, 0.28), 6.0)
			_canvas.draw_line(tip, tip + back.rotated(-0.5), Color(1, 1, 1, 0.28), 6.0)
		if _tracing:
			_canvas.draw_circle(origin + Vector2(_pos.x, -_pos.y), 6.0, RinkOS.ACTION)
		if _shown > 0.0:
			var label := "SHOT GUIDE: %s" % (ShotPatterns.NAMES[guide] if guide != &"" else "OFF")
			_canvas.draw_string(RinkOS.PIXEL_FONT, origin + Vector2(-90, 40), label, HORIZONTAL_ALIGNMENT_LEFT, -1, RinkOS.PIXEL_SIZE, RinkOS.TEXT)
	if _load >= 0.0:
		# the rhythm gauge: 0 .. 1.5 of the limit across, the limit at two thirds
		var w := 180.0
		var at := Vector2(mid.x - w * 0.5, size.y - 64.0)
		var cells := 18
		for i in cells:
			var v := (i + 0.5) / cells * 1.5
			var col := RinkOS.GOOD if v < 0.85 else (RinkOS.ACTION if v < 1.0 else RinkOS.ALERT)
			if v > _load:
				col = Color(col, 0.18)
			_canvas.draw_rect(Rect2(at + Vector2(i * w / cells, 0), Vector2(w / cells - 2.0, 8.0)), col)
		_canvas.draw_string(RinkOS.PIXEL_FONT, at + Vector2(0, -6), "HANDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RinkOS.DIM)
