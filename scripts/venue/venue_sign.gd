class_name VenueSign
extends MeshInstance3D
## An in-world pixel-terminal screen: lines of PixelFont text on a dark panel,
## in the RINK-OS "Mission Control" style (`//` headers, `----` rules, full
## colour). The face looks along +Z. Redraws only when the text changes, so
## a live scoreboard costs one small texture upload per clock tick.

const BG := Color("0b0f17")
const WHITE := Color("e8f0ff")
const CYAN := Color("4fd6ff")
const GREEN := Color("7ee787")
const AMBER := Color("ffb454")
const MAGENTA := Color("ff7ad9")
const RED := Color("ff5f56")
const DIM := Color("6b7a90")

## World metres per font pixel.
var px := 0.05
## Character columns and text rows the panel is sized for.
var cols := 20
var text_rows := 3
var pad := 3
## Font pixels per glyph pixel (big digits on a scoreboard use 2 or 3).
var px_scale := 1
## Fraction of dead pixels (worn screens). Fixed per sign, not flickering.
var dead := 0.0
var background := BG

var _lines: Array = []
var _img: Image
var _tex: ImageTexture
var _mat: StandardMaterial3D
var _seed := 0


## `lines` is an Array of [text, Color] pairs (or plain Strings in WHITE).
static func make(lines: Array, cols_: int, rows_: int, px_ := 0.05, scale_ := 1) -> VenueSign:
	var s := VenueSign.new()
	s.cols = cols_
	s.text_rows = rows_
	s.px = px_
	s.px_scale = scale_
	s._lines = lines
	return s


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seed = hash(name) ^ hash(_lines)
	var w := (cols * PixelFont.ADVANCE * px_scale) + pad * 2
	var h := (text_rows * PixelFont.LINE * px_scale) + pad * 2
	_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	_tex = ImageTexture.create_from_image(_img)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.albedo_texture = _tex
	var q := QuadMesh.new()
	q.size = Vector2(w, h) * px
	q.material = _mat
	mesh = q
	_redraw()


func size_m() -> Vector2:
	return Vector2((cols * PixelFont.ADVANCE * px_scale) + pad * 2, (text_rows * PixelFont.LINE * px_scale) + pad * 2) * px


func set_lines(lines: Array) -> void:
	if lines == _lines:
		return
	_lines = lines
	if _img:
		_redraw()


func _redraw() -> void:
	_img.fill(background)
	for i in mini(_lines.size(), text_rows):
		var entry = _lines[i]
		var text: String = entry if entry is String else entry[0]
		var col: Color = WHITE if entry is String else entry[1]
		if text == "----":
			text = "-".repeat(cols)  # a terminal rule across the panel
		PixelFont.draw(_img, text.substr(0, cols), pad, pad + i * PixelFont.LINE * px_scale + px_scale, col, px_scale)
	if dead > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var n := int(_img.get_width() * _img.get_height() * dead)
		for k in n:
			_img.set_pixel(rng.randi_range(0, _img.get_width() - 1), rng.randi_range(0, _img.get_height() - 1), background.darkened(0.4))
	_tex.update(_img)
