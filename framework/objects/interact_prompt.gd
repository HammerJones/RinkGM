class_name InteractPrompt
extends CanvasLayer
## The centre dot and the prompt line under it, fed by an Interactor:
## "COFFEE MUG   [E] take   [F] push   [RMB] inspect". Inspect text shows
## for a few seconds above the prompt.

const INSPECT_SECONDS := 4.0

var interactor: Interactor
var _dot: ColorRect
var _line: Label
var _inspect: Label
var _inspect_t := 0.0


func _ready() -> void:
	layer = 20
	_dot = ColorRect.new()
	_dot.color = Color(1, 1, 1, 0.8)
	_dot.size = Vector2(4, 4)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position = Vector2(-2, -2)
	add_child(_dot)
	_line = Label.new()
	_line.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_line.position = Vector2(-300, -80)
	_line.size = Vector2(600, 24)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_line)
	_inspect = Label.new()
	_inspect.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_inspect.position = Vector2(-320, -130)
	_inspect.size = Vector2(640, 44)
	_inspect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect.autowrap_mode = TextServer.AUTOWRAP_WORD
	_inspect.modulate = Color(1, 0.95, 0.8)
	add_child(_inspect)


func bind(i: Interactor) -> void:
	interactor = i
	if i.objects:
		i.objects.inspected.connect(func(_row: PropRow, text: String) -> void: show_inspect(text))


func show_inspect(text: String) -> void:
	_inspect.text = text
	_inspect_t = INSPECT_SECONDS


func _process(dt: float) -> void:
	_line.text = interactor.prompt() if interactor else ""
	if _inspect_t > 0.0:
		_inspect_t -= dt
		if _inspect_t <= 0.0:
			_inspect.text = ""
