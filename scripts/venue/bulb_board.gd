class_name BulbBoard
extends Node3D
## A classic incandescent scoreboard face: digits are seven-segment patterns
## of round bulbs on a painted board, labels (HOME, GUEST, PERIOD, the rink
## name) are painted on in a blocky 3x5 font built from voxel blocks. Every
## bulb of every face is one instance of a single MultiMesh with per-instance
## colours, so a board is one draw and a score change only recolours bulbs.
##
## Build: make(), add_face() for each display face (paints the board through
## the kit and records the bulbs), then k.add() the node. Positions are in
## the room's space; a face transform looks along its +Z with +X to the
## viewer's right.

## Segment bits: a top, b top right, c bottom right, d bottom, e bottom left,
## f top left, g middle.
const _A := 1
const _B := 2
const _C := 4
const _D := 8
const _E := 16
const _F := 32
const _G := 64
const GLYPHS := {
	"0": 63, "1": 6, "2": 91, "3": 79, "4": 102, "5": 109, "6": 125, "7": 7, "8": 127, "9": 111,
	"-": 64, " ": 0,
}

## Painted lettering, 3 x 5 pixels per character ("#" = paint).
const FONT := {
	"A": ["###", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": ["###", "#..", "#..", "#..", "###"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": ["###", "#..", "#.#", "#.#", "###"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", "###"],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["###", "#.#", "###", "#..", "#.."],
	"Q": ["###", "#.#", "#.#", "###", "..#"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": ["###", "#..", "###", "..#", "###"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", "..#", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
	"-": ["...", "...", "###", "...", "..."], ".": ["...", "...", "...", "...", ".#."],
	"'": [".#.", ".#.", "...", "...", "..."], "&": [".#.", "#.#", ".#.", "#.#", ".##"],
}

## Bulb colours (sRGB): unlit sockets, and lit per role and age.
const UNLIT := Color(0.2, 0.16, 0.12)
const PLATE_T := 0.03  # board face thickness in front of the housing
const PAINT_T := 0.006

static var _mat: ShaderMaterial
static var _bulb: SphereMesh

## "game" shows score, period and clock; "clock" shows the time of day in
## the clock digits with scores and period dark (set between events).
var mode := "game":
	set(v):
		mode = v
		_refresh()
## Share of bulbs burnt out for good (worn boards), chosen by `seed`.
var dead := 0.0
## Lit bulbs are this much darker (an old board on tired wiring).
var dim := 0.0
var palette := {"score": Color(1.0, 0.36, 0.16), "clock": Color(1.0, 0.7, 0.28), "period": Color(1.0, 0.7, 0.28)}
var seed_ := 0

var _xfs: Array[Transform3D] = []
var _slot: PackedStringArray = []  # which digit each bulb belongs to
var _mask: PackedInt32Array = []  # segments that light it
var _role: PackedStringArray = []
var _dead: PackedByteArray = []
var _mm: MultiMesh
var _digits := {}  # slot -> glyph character
var _score := {"home": 0, "away": 0, "period": "1ST", "clock": "20:00"}
var _time := Vector2i(19, 0)
var _shown := ""


static func make(age: int, seed_value: int) -> BulbBoard:
	var b := BulbBoard.new()
	b.seed_ = seed_value
	b.dead = [0.035, 0.008, 0.0][age]
	b.dim = [0.22, 0.1, 0.0][age]
	if age == VenueRoom.Age.RENOVATED:
		b.palette = {"score": Color(1.0, 0.95, 0.86), "clock": Color(1.0, 0.74, 0.3), "period": Color(1.0, 0.95, 0.86)}
	return b


# ---------------------------------------------------------------- building

## One display face: paints the board and its labels with the kit at face
## transform `xf` (size in metres) and lays out the bulbs. `stacked` puts
## the scores under the clock (the centre-hung board's squarer faces) and
## paints `title` across the top; the wide wall layout runs HOME | clock |
## GUEST and leaves the rink name to paint_strip().
func add_face(k: VenueKit, xf: Transform3D, size: Vector2, stacked: bool, title := "", plate := Color("191613"), ink := Color("e9dfc6")) -> void:
	var items := _stacked_layout(title) if stacked else _wall_layout()
	# fit the layout (in bulb pitches) to the face
	var lo := Vector2(INF, INF)
	var hi := -lo
	for it in items:
		lo = lo.min(it.lo)
		hi = hi.max(it.hi)
	var span := hi - lo + Vector2(1.6, 1.4)
	var p := minf(size.x / span.x, size.y / span.y)
	var off := -(lo + hi) * 0.5
	var at := func(v: Vector2) -> Vector2: return (v + off) * p
	# the painted board over the housing's display
	var corner := Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	k.block(xf * -corner, xf * (corner + Vector3(0, 0, PLATE_T)), k.aged(plate), 0.5, 0.03, false)
	for it in items:
		match it.kind:
			"digit":
				_add_digit(xf, at.call(it.pos), it.n, it.s * p, it.slot, it.role)
			"colon":
				for dy in [-1.6, 1.6]:
					_add_bulb(xf, at.call(it.pos + Vector2(0, dy)), p, "colon", 1, "clock")
			"label":
				paint_text(k, xf, it.text, at.call(it.pos), it.px * p, k.aged(ink), PLATE_T)
			"box":
				_paint_box(k, xf, at.call(it.pos), it.size * p, 0.22 * p, k.aged(ink))


## A painted name strip (the wall board's sponsor header): `text` fitted to
## `size` in `ink` on a `bg` panel `depth` thick.
static func paint_strip(k: VenueKit, xf: Transform3D, size: Vector2, text: String, bg: Color, ink: Color, depth := 0.08) -> void:
	var corner := Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	k.block(xf * -corner, xf * (corner + Vector3(0, 0, depth)), k.aged(bg), 0.5, 0.04, false)
	var px := minf(size.y * 0.6 / 5.0, size.x * 0.92 / maxf(1.0, text_width(text)))
	paint_text(k, xf, text, Vector2.ZERO, px, k.aged(ink), depth)


## Width of `text` in font pixels (3 per letter, 1 between letters).
static func text_width(text: String) -> int:
	return maxi(0, text.length() * 4 - 1)


## Paints `text` centred on `c` (face metres), `px` metres per font pixel,
## as small blocks standing `z` off the face. Runs of pixels in a row merge
## into one block.
static func paint_text(k: VenueKit, xf: Transform3D, text: String, c: Vector2, px: float, col: Color, z: float) -> void:
	var x0 := c.x - text_width(text) * px * 0.5
	var y0 := c.y + 2.5 * px
	for i in text.length():
		var g: Array = FONT.get(text[i], [])
		for r in g.size():
			var row: String = g[r]
			var run := -1
			for x in 4:
				var on := x < 3 and row[x] == "#"
				if on and run < 0:
					run = x
				elif not on and run >= 0:
					var a := Vector3(x0 + (i * 4 + run) * px, y0 - (r + 1) * px, z)
					var b := Vector3(x0 + (i * 4 + x) * px, y0 - r * px, z + PAINT_T)
					k.block(xf * a, xf * b, col, 100.0, 0.03, false)
					run = -1


## A painted rectangle outline centred on `c`, `size` outside, line `w`.
static func _paint_box(k: VenueKit, xf: Transform3D, c: Vector2, size: Vector2, w: float, col: Color) -> void:
	var h := size * 0.5
	var z0 := PLATE_T
	var z1 := PLATE_T + PAINT_T
	for r in [[Vector2(-h.x, h.y - w), Vector2(h.x, h.y)], [Vector2(-h.x, -h.y), Vector2(h.x, -h.y + w)],
			[Vector2(-h.x, -h.y), Vector2(-h.x + w, h.y)], [Vector2(h.x - w, -h.y), Vector2(h.x, h.y)]]:
		var a: Vector2 = c + r[0]
		var b: Vector2 = c + r[1]
		k.block(xf * Vector3(a.x, a.y, z0), xf * Vector3(b.x, b.y, z1), col, 100.0, 0.03, false)


## Wide wall board: HOME score | MM:SS | GUEST score, PERIOD under the clock.
## Units are bulb pitches; y up.
func _wall_layout() -> Array:
	var out := []
	out.append_array(_clock(Vector2.ZERO))
	out.append({"kind": "box", "pos": Vector2(0, 0), "size": Vector2(27.5, 10.6), "lo": Vector2(-13.75, -5.3), "hi": Vector2(13.75, 5.3)})
	out.append_array(_label("PERIOD", Vector2(-2.2, -8.4), 0.55))
	out.append(_digit("period", Vector2(6.8, -8.4), 2, 0.8, "period"))
	for side in [["home", "HOME", -20.0], ["away", "GUEST", 20.0]]:
		out.append_array(_label(side[1], Vector2(side[2], 3.6), 0.6))
		out.append(_digit(side[0] + "0", Vector2(side[2] - 2.5, -2.2), 2, 1.0, "score"))
		out.append(_digit(side[0] + "1", Vector2(side[2] + 2.5, -2.2), 2, 1.0, "score"))
	return out


## Squarer hung-board face: title, then the clock, then HOME | PERIOD | GUEST.
func _stacked_layout(title: String) -> Array:
	var out := []
	if title != "":
		var px := minf(0.5, 30.0 / maxf(1.0, text_width(title)))
		out.append_array(_label(title, Vector2(0, 7.6), px))
	out.append_array(_clock(Vector2.ZERO))
	out.append({"kind": "box", "pos": Vector2(0, 0), "size": Vector2(27.5, 10.6), "lo": Vector2(-13.75, -5.3), "hi": Vector2(13.75, 5.3)})
	for side in [["home", "HOME", -12.5], ["away", "GUEST", 12.5]]:
		out.append_array(_label(side[1], Vector2(side[2], -7.2), 0.55))
		out.append(_digit(side[0] + "0", Vector2(side[2] - 2.5, -12.6), 2, 1.0, "score"))
		out.append(_digit(side[0] + "1", Vector2(side[2] + 2.5, -12.6), 2, 1.0, "score"))
	out.append_array(_label("PERIOD", Vector2(0, -7.2), 0.45))
	out.append(_digit("period", Vector2(0, -12.6), 2, 1.0, "period"))
	return out


## The MM:SS clock (big digits, a two-bulb colon) centred on `c`.
func _clock(c: Vector2) -> Array:
	var out := []
	var xs := [-10.0, -4.0, 4.0, 10.0]
	for i in 4:
		out.append(_digit("clock%d" % i, c + Vector2(xs[i], 0), 3, 1.0, "clock"))
	out.append({"kind": "colon", "pos": c, "lo": c - Vector2(0.5, 2.1), "hi": c + Vector2(0.5, 2.1)})
	return out


func _digit(slot: String, pos: Vector2, n: int, s: float, role: String) -> Dictionary:
	var h := Vector2(n + 2, 2 * n + 3) * s * 0.5
	return {"kind": "digit", "slot": slot, "pos": pos, "n": n, "s": s, "role": role, "lo": pos - h, "hi": pos + h}


func _label(text: String, pos: Vector2, px: float) -> Array:
	var h := Vector2(text_width(text), 5) * px * 0.5
	return [{"kind": "label", "text": text, "pos": pos, "px": px, "lo": pos - h, "hi": pos + h}]


## The bulbs of one seven-segment digit: n bulbs per segment plus shared
## corners, `s` metres apart, centred on `c`.
func _add_digit(xf: Transform3D, c: Vector2, n: int, s: float, slot: String, role: String) -> void:
	var w := n + 1
	var h := 2 * n + 2
	for col in w + 1:
		for row in h + 1:
			var m := 0
			var edge_x := col == 0 or col == w
			var mid_x := not edge_x
			if row == 0:
				m = _A if mid_x else (_A | (_F if col == 0 else _B))
			elif row == n + 1:
				m = _G if mid_x else (_G | (_F | _E if col == 0 else _B | _C))
			elif row == h:
				m = _D if mid_x else (_D | (_E if col == 0 else _C))
			elif edge_x:
				var upper := row <= n
				m = (_F if upper else _E) if col == 0 else (_B if upper else _C)
			if m == 0:
				continue
			_add_bulb(xf, c + Vector2((col - w * 0.5) * s, (h * 0.5 - row) * s), s, slot, m, role)


func _add_bulb(xf: Transform3D, at: Vector2, s: float, slot: String, m: int, role: String) -> void:
	var d := s * 0.74
	# the hemisphere's dome (+Y) turned to face out of the board
	var basis := xf.basis * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(d, d * 0.55, d))
	_xfs.append(Transform3D(basis, xf * Vector3(at.x, at.y, PLATE_T)))
	_slot.append(slot)
	_mask.append(m)
	_role.append(role)
	# burnt out for good: the same bulbs every build
	var r := float(posmod(hash(Vector2i(seed_, _xfs.size())), 10000)) / 10000.0
	_dead.append(1 if r < dead else 0)


# ---------------------------------------------------------------- runtime

func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = _bulb_mesh()
	_mm.instance_count = _xfs.size()
	for i in _xfs.size():
		_mm.set_instance_transform(i, _xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bulbs"
	mmi.multimesh = _mm
	mmi.material_override = _material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_shown = ""
	_refresh()


func bulb_count() -> int:
	return _xfs.size()


## How many bulbs are lit right now.
func lit_count() -> int:
	var n := 0
	for i in _xfs.size():
		if _lit(i):
			n += 1
	return n


## st = {home, away, period "1ST".."OT"/"SO", clock "MM:SS"}.
func show_score(st: Dictionary) -> void:
	_score = st
	_refresh()


## The time of day for "clock" mode, 24-hour in; shown 12-hour like an old board.
func show_time(hours: int, minutes: int) -> void:
	_time = Vector2i(posmod(hours, 24), clampi(minutes, 0, 59))
	_refresh()


func _refresh() -> void:
	var d := {}
	if mode == "clock":
		var h12 := posmod(_time.x - 1, 12) + 1
		_put_clock(d, "%2d" % h12, "%02d" % _time.y)
		for slot in ["home0", "home1", "away0", "away1", "period"]:
			d[slot] = " "
	else:
		var mm_ss := String(_score.get("clock", "00:00")).split(":")
		var mins := mm_ss[0].to_int() if mm_ss.size() > 1 else 0
		var secs := mm_ss[1].to_int() if mm_ss.size() > 1 else 0
		_put_clock(d, "%2d" % mini(mins, 99), "%02d" % secs)
		for side in ["home", "away"]:
			var s := "%2d" % posmod(int(_score.get(side, 0)), 100)
			d[side + "0"] = s[0]
			d[side + "1"] = s[1]
		d["period"] = period_glyph(String(_score.get("period", "1ST")))
	var key := str(d)
	if key == _shown or _mm == null:
		_digits = d
		return
	_digits = d
	_shown = key
	for i in _xfs.size():
		var c := UNLIT
		if _lit(i):
			c = (palette[_role[i]] as Color).darkened(dim)
		_mm.set_instance_color(i, c.srgb_to_linear())


func _put_clock(d: Dictionary, left: String, right: String) -> void:
	d["clock0"] = left[0]
	d["clock1"] = left[1]
	d["clock2"] = right[0]
	d["clock3"] = right[1]
	d["colon"] = ":"


func _lit(i: int) -> bool:
	if _dead[i]:
		return false
	var g: String = _digits.get(_slot[i], " ")
	if _slot[i] == "colon":
		return g == ":"
	return (GLYPHS.get(g, 0) & _mask[i]) != 0


## The period digit: 1-3, overtime shows 4, a shootout shows 5 (S).
static func period_glyph(p: String) -> String:
	match p:
		"OT":
			return "4"
		"SO":
			return "5"
	var n := p.to_int()
	return str(n) if n >= 1 and n <= 9 else " "


static func _bulb_mesh() -> SphereMesh:
	if _bulb == null:
		_bulb = SphereMesh.new()
		_bulb.radius = 0.5
		_bulb.height = 1.0
		_bulb.is_hemisphere = true
		_bulb.radial_segments = 6
		_bulb.rings = 2
	return _bulb


## Unshaded so lit bulbs glow in a dark arena; the dome is brighter where it
## faces the viewer, so bulbs read round.
static func _material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_back;

void fragment() {
	float dome = 0.5 + 0.5 * clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = COLOR.rgb * dome * 1.35;
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat
