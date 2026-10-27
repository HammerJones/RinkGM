class_name VenueSign
extends Node3D
## An in-world RINK-OS screen or sign: lines of text on a CRT panel, built
## with RinkOS.sign_3d() so they match the UI style (assets/ui/STYLE.md):
## Silkscreen for names and titles, VT323 for numbers, clocks and prices,
## one font pixel per `px` metres, nearest filtering, no lighting. The face
## looks along +Z. Updating text only changes Label3D strings, so a live
## scoreboard costs next to nothing.

const BG := RinkOS.CRT
const WHITE := RinkOS.TEXT
const CYAN := RinkOS.READOUT
const AMBER := RinkOS.ACTION
const GREEN := RinkOS.GOOD
const RED := RinkOS.ALERT
const DIM := RinkOS.DIM

## World metres per font pixel (the voxel grid is 0.065).
var px := 0.065
## Character columns and text rows the panel is sized for.
var cols := 20
var text_rows := 3
## Font pixels are drawn px * px_scale wide (2 for a big scoreboard).
var px_scale := 1
## How worn the screen's housing looks, 0..1 (the text stays crisp and in
## full colour; only the panel greys).
var dead := 0.0
var background := BG

var _lines: Array = []
var _labels: Array[Label3D] = []
var _panel: MeshInstance3D


## `lines` is an Array of [text, Color] pairs (or plain Strings in WHITE); a
## third element `true` sets that line in the VT323 terminal font.
static func make(lines: Array, cols_: int, rows_: int, px_ := 0.065, scale_ := 1) -> VenueSign:
	var s := VenueSign.new()
	s.cols = cols_
	s.text_rows = rows_
	s.px = px_
	s.px_scale = scale_
	s._lines = lines
	return s


func _ready() -> void:
	var size := size_m()
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = background.lerp(Color("2a2723"), clampf(dead * 8.0, 0.0, 0.6))
	q.material = mat
	_panel = MeshInstance3D.new()
	_panel.mesh = q
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panel)
	var y := size.y * 0.5 - _pad()
	for i in text_rows:
		var l := RinkOS.sign_3d("", WHITE, true, _voxel())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.position = Vector3(-size.x * 0.5 + _pad(), y, 0.004)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)
		_labels.append(l)
		y -= _line_h()
	_apply()


func _voxel() -> float:
	return px * px_scale


func _pad() -> float:
	return _voxel() * 2.0


## Silkscreen 16 is 8 font pixels per line and about 6 per character.
func _line_h() -> float:
	return _voxel() * 9.0


func _char_w() -> float:
	return _voxel() * 6.0


func size_m() -> Vector2:
	return Vector2(cols * _char_w() + _pad() * 2.0, text_rows * _line_h() + _pad() * 2.0)


func set_lines(lines: Array) -> void:
	if lines == _lines:
		return
	_lines = lines
	if not _labels.is_empty():
		_apply()


func _apply() -> void:
	for i in _labels.size():
		var l := _labels[i]
		if i >= _lines.size():
			l.text = ""
			continue
		var entry = _lines[i]
		var text: String = entry if entry is String else entry[0]
		var term: bool = entry is Array and entry.size() > 2 and entry[2]
		if text == "----":
			text = "-".repeat(cols)  # a terminal rule across the panel
		l.text = text.substr(0, cols) if not term else text.substr(0, int(cols * 1.4))
		l.modulate = WHITE if entry is String else entry[1]
		l.font = RinkOS.TERM_FONT if term else RinkOS.PIXEL_FONT
		l.font_size = RinkOS.TERM_SIZE if term else RinkOS.PIXEL_SIZE
