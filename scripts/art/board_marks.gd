class_name BoardMarks
extends RefCounted
## What the people of the rink wrote on a whiteboard today (evening notes
## W7, W15): drawn in wobbly marker, never in a UI font. Each board has a key
## (its room) and the content comes from that key and the day, so boards
## change from day to day and no two boards show the same thing on a day.
##
## A board's marks: a header (the day and who has the room), a half-rink
## drill diagram with X's, O's, skating arrows and dashed passes, a list of
## drills or line combos, a note, sometimes tally marks or a doodle, and the
## ghost of yesterday's wiped ink.
##
##   draw(img, key, day) -> String   draws into `img` (cleared first) and
##                                   returns the board's signature (its text)

const BLUE := Color("1b2a4a")
const RED := Color("b8312f")
const GREEN := Color("2a7a4a")
const GHOST := Color(0.84, 0.86, 0.87)  # a faint grey smear on the white

## Stroke glyphs on a 4 x 6 grid (y down), strokes split by "|". A one-point
## stroke is a dot.
const GLYPHS := {
	"A": "0 6 0 2 2 0 4 2 4 6|0 3 4 3", "B": "0 0 0 6 3 6 4 5 4 4 3 3 0 3|0 0 3 0 4 1 4 2 3 3",
	"C": "4 1 3 0 1 0 0 1 0 5 1 6 3 6 4 5", "D": "0 0 0 6 2 6 4 4 4 2 2 0 0 0",
	"E": "4 0 0 0 0 6 4 6|0 3 3 3", "F": "4 0 0 0 0 6|0 3 3 3",
	"G": "4 1 3 0 1 0 0 1 0 5 1 6 3 6 4 5 4 3 2 3", "H": "0 0 0 6|4 0 4 6|0 3 4 3",
	"I": "1 0 3 0|2 0 2 6|1 6 3 6", "J": "4 0 4 5 3 6 1 6 0 5",
	"K": "0 0 0 6|4 0 0 4|1 3 4 6", "L": "0 0 0 6 4 6", "M": "0 6 0 0 2 3 4 0 4 6",
	"N": "0 6 0 0 4 6 4 0", "O": "1 0 3 0 4 1 4 5 3 6 1 6 0 5 0 1 1 0",
	"P": "0 6 0 0 3 0 4 1 4 2 3 3 0 3", "Q": "1 0 3 0 4 1 4 5 3 6 1 6 0 5 0 1 1 0|2 4 4 6",
	"R": "0 6 0 0 3 0 4 1 4 2 3 3 0 3|2 3 4 6", "S": "4 1 3 0 1 0 0 1 0 2 1 3 3 3 4 4 4 5 3 6 1 6 0 5",
	"T": "0 0 4 0|2 0 2 6", "U": "0 0 0 5 1 6 3 6 4 5 4 0", "V": "0 0 2 6 4 0",
	"W": "0 0 1 6 2 3 3 6 4 0", "X": "0 0 4 6|4 0 0 6", "Y": "0 0 2 3 4 0|2 3 2 6",
	"Z": "0 0 4 0 0 6 4 6",
	"0": "1 0 3 0 4 1 4 5 3 6 1 6 0 5 0 1 1 0", "1": "1 1 2 0 2 6|1 6 3 6",
	"2": "0 1 1 0 3 0 4 1 4 2 0 6 4 6", "3": "0 0 4 0 2 2 3 2 4 3 4 5 3 6 1 6 0 5",
	"4": "3 6 3 0 0 4 4 4", "5": "4 0 0 0 0 3 3 3 4 4 4 5 3 6 0 6",
	"6": "3 0 1 0 0 2 0 5 1 6 3 6 4 5 4 4 3 3 0 3", "7": "0 0 4 0 1 6",
	"8": "1 0 3 0 4 1 4 2 3 3 1 3 0 4 0 5 1 6 3 6 4 5 4 4 3 3|1 3 0 2 0 1 1 0",
	"9": "4 3 1 3 0 2 0 1 1 0 3 0 4 1 4 4 3 6 1 6",
	"-": "1 3 3 3", ":": "2 1|2 5", "!": "2 0 2 4|2 6", "/": "4 0 0 6", ".": "2 6",
	"+": "2 1 2 5|0 3 4 3", "?": "0 1 1 0 3 0 4 1 4 2 2 3 2 4|2 6", "'": "2 0 2 2",
}

const DAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const GROUPS := ["U7", "U9", "U11", "U13", "U15", "MIDGET", "JR B", "SR A", "BEER LG", "OLD TIMERS",
	"LEARN TO SKATE", "GIRLS U12", "WOMENS REC", "GOALIE CLINIC", "POWER SKATE", "SHINNY"]
const DRILLS := ["2 ON 1", "3 ON 2", "BREAKOUT", "TIGHT TURNS", "BACKCHECK", "OVERSPEED", "PASS AND GO",
	"NET FRONT", "CIRCLE DRILL", "CROSSOVERS", "STOPS + STARTS", "REGROUP", "D TO D", "CYCLE LOW",
	"ONE TIMERS", "BOARD BATTLES", "FIGURE 8S", "EDGES", "SHOOT THE PUCK", "RED LIGHT GREEN LIGHT",
	"SHARKS + MINNOWS", "POINT SHOTS", "FORECHECK 2-1-2", "PK BOX", "PP UMBRELLA", "BAD ANGLE"]
const NOTES := ["HAVE FUN!", "SKATE HARD", "TAPE YOUR STICKS", "WATER BOTTLES!", "NO SNOW SHOWERS",
	"HEADS UP", "LISTEN FOR THE WHISTLE", "PICTURE DAY THU", "DUES TO DONNA", "BUS LEAVES 6:15",
	"SKATES SHARP?", "WHO TOOK MY TAPE", "GUS SAYS NO PUCKS IN THE LOBBY", "PIZZA AFTER", "WIN THE DAY",
	"GOOD JOB YESTERDAY", "HELMETS ON", "TOURNEY SAT 8AM", "MOUTHGUARDS", "BACK BY 4", "ALL HANDS ON THE ICE"]


static func draw(img: Image, key: String, day: int, salt := 0) -> String:
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%d" % [key, day, salt])
	var w := img.get_width()
	var h := img.get_height()
	var u := w / 528.0  # layout units: a 2.4 m board at 220 px/m
	# yesterday's ink, wiped but not quite
	var ghost := RandomNumberGenerator.new()
	ghost.seed = hash("%s/%d" % [key, day - 1])
	for i in 3:
		_text(img, ghost, DRILLS[ghost.randi() % DRILLS.size()], Vector2(ghost.randf_range(0.05, 0.6) * w, ghost.randf_range(0.2, 0.85) * h), 3.0 * u, GHOST, 3)
	var ink: Color = [BLUE, BLUE, RED, GREEN][rng.randi() % 4]
	var group: String = GROUPS[rng.randi() % GROUPS.size()]
	var header := "%s %s" % [DAYS[posmod(day, 7)], group]
	if rng.randf() < 0.5:
		header += " %d:%02d" % [5 + rng.randi() % 4, [0, 15, 30, 45][rng.randi() % 4]]
	_text(img, rng, header, Vector2(16, 14) * u, 4.0 * u, ink, 3)
	var sig := header
	# the drill diagram: left or right half
	var left := rng.randf() < 0.6
	var rink := Rect2(Vector2(w * (0.04 if left else 0.55), h * 0.25), Vector2(w * 0.41, h * 0.68))
	_rink(img, rng, rink, BLUE if ink != BLUE else RED)
	var players := 2 + rng.randi() % 4
	for i in players:
		var p := rink.position + rink.size * Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.15, 0.85))
		if i % 2 == 0:
			_cross(img, p, 7.0 * u, BLUE)
		else:
			_circle(img, p, 6.0 * u, RED, 2)
		sig += "|%d,%d" % [int(p.x / 8), int(p.y / 8)]
		if rng.randf() < 0.8:
			var q := rink.position + rink.size * Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
			_arrow(img, rng, p, q, BLUE if i % 2 == 0 else RED, rng.randi() % 3)
	# the list: drills or lines, then a note
	var x0 := w * (0.5 if left else 0.04) + 8 * u
	var y := h * 0.3
	if rng.randf() < 0.35:
		_text(img, rng, "LINES", Vector2(x0, y), 3.2 * u, ink, 3)
		y += 28 * u
		for l in 3:
			var nums := []
			for n in 3:
				nums.append(str(2 + rng.randi() % 96))
			var line := "-".join(nums)
			_text(img, rng, line, Vector2(x0 + 6 * u, y), 3.0 * u, ink, 2)
			sig += "|" + line
			y += 24 * u
	else:
		var picks := []
		while picks.size() < 3:
			var d: String = DRILLS[rng.randi() % DRILLS.size()]
			if not d in picks:
				picks.append(d)
		for i in picks.size():
			var line := "%d. %s" % [i + 1, picks[i]]
			_text(img, rng, line, Vector2(x0, y), 3.0 * u, ink, 2)
			sig += "|" + line
			y += 24 * u
	var note: String = NOTES[rng.randi() % NOTES.size()]
	_text(img, rng, note, Vector2(x0, minf(y + 8 * u, h - 30 * u)), 3.0 * u, RED if ink != RED else GREEN, 2)
	sig += "|" + note
	# tally marks or a doodle in a corner
	var corner := Vector2(w - 70 * u, h - 40 * u) if left else Vector2(w * 0.47, h - 40 * u)
	if rng.randf() < 0.5:
		var n := 3 + rng.randi() % 9
		for i in n:
			var bx := corner.x + (i % 5) * 7 * u + floori(i / 5.0) * 44 * u
			if i % 5 == 4:
				_line(img, Vector2(bx - 30 * u, corner.y + 18 * u), Vector2(bx + 2 * u, corner.y + 2 * u), GREEN, 2)
			else:
				_line(img, Vector2(bx, corner.y), Vector2(bx + rng.randf_range(-1, 1), corner.y + 20 * u), GREEN, 2)
		sig += "|tally%d" % n
	else:
		_circle(img, corner + Vector2(14, 12) * u, 12 * u, GREEN, 2)
		_circle(img, corner + Vector2(10, 9) * u, 1.0, GREEN, 2)
		_circle(img, corner + Vector2(18, 9) * u, 1.0, GREEN, 2)
		_poly(img, [corner + Vector2(8, 15) * u, corner + Vector2(14, 19) * u, corner + Vector2(20, 15) * u], GREEN, 2)
		sig += "|smile"
	return sig


# ---------------------------------------------------------------- drawing

static func _text(img: Image, rng: RandomNumberGenerator, s: String, at: Vector2, scale: float, col: Color, thick: int) -> void:
	var x := at.x
	var slope := rng.randf_range(-0.03, 0.03)
	for ch in s.to_upper():
		if ch == " ":
			x += scale * 4.0
			continue
		var g: String = GLYPHS.get(ch, "")
		var base := Vector2(x, at.y + (x - at.x) * slope)
		for stroke in g.split("|"):
			var n := stroke.split(" ")
			var pts := []
			for i in range(0, n.size() - 1, 2):
				var j := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				pts.append(base + (Vector2(float(n[i]), float(n[i + 1])) + j) * scale)
			if pts.size() == 1:
				_dot(img, pts[0], col, thick + 1)
			else:
				_poly(img, pts, col, thick)
		x += scale * rng.randf_range(5.4, 6.2)


static func _rink(img: Image, rng: RandomNumberGenerator, r: Rect2, col: Color) -> void:
	var c := r.size.y * 0.3
	var pts := []
	var corners := [[r.position + Vector2(c, c), PI, 1.5 * PI], [r.position + Vector2(r.size.x - c, c), 1.5 * PI, TAU],
		[r.end - Vector2(c, c), 0.0, 0.5 * PI], [r.position + Vector2(c, r.size.y - c), 0.5 * PI, PI]]
	for k in corners:
		var o: Vector2 = k[0]
		for i in 7:
			var a: float = lerpf(k[1], k[2], i / 6.0)
			pts.append(o + Vector2(cos(a), sin(a)) * c + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
	pts.append(pts[0])
	_poly(img, pts, col, 2)
	# the blue line across, the goal line and crease near one end
	var bx := r.position.x + r.size.x * 0.62
	_line(img, Vector2(bx, r.position.y + 2), Vector2(bx + rng.randf_range(-2, 2), r.end.y - 2), col, 2)
	var gx := r.position.x + r.size.x * 0.1
	_line(img, Vector2(gx, r.position.y + c * 0.5), Vector2(gx, r.end.y - c * 0.5), RED, 1)
	_circle(img, Vector2(gx, r.get_center().y), r.size.y * 0.08, RED, 1)
	for s in [-1.0, 1.0]:
		_circle(img, Vector2(r.position.x + r.size.x * 0.32, r.get_center().y + s * r.size.y * 0.25), r.size.y * 0.13, RED, 1)


static func _arrow(img: Image, rng: RandomNumberGenerator, a: Vector2, b: Vector2, col: Color, style: int) -> void:
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * rng.randf_range(-0.3, 0.3) * a.distance_to(b)
	var pts := []
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	if style == 1:  # a pass: dashed
		for i in range(0, pts.size() - 1, 2):
			_line(img, pts[i], pts[i + 1], col, 1)
	elif style == 2:  # skating backwards: a zigzag
		for i in pts.size() - 1:
			var n: Vector2 = (pts[i + 1] - pts[i]).orthogonal().normalized() * (3.0 if i % 2 == 0 else -3.0)
			_line(img, pts[i] + n, pts[i + 1] - n, col, 1)
	else:
		_poly(img, pts, col, 2)
	var d: Vector2 = (pts[12] - pts[10]).normalized()
	_line(img, b, b - d.rotated(0.5) * 9.0, col, 2)
	_line(img, b, b - d.rotated(-0.5) * 9.0, col, 2)


static func _cross(img: Image, p: Vector2, r: float, col: Color) -> void:
	_line(img, p - Vector2(r, r), p + Vector2(r, r), col, 2)
	_line(img, p + Vector2(-r, r), p + Vector2(r, -r), col, 2)


static func _circle(img: Image, p: Vector2, r: float, col: Color, thick: int) -> void:
	var pts := []
	var n := maxi(6, int(r))
	for i in n + 1:
		var a := TAU * i / n
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	_poly(img, pts, col, thick)


static func _poly(img: Image, pts: Array, col: Color, thick: int) -> void:
	for i in pts.size() - 1:
		_line(img, pts[i], pts[i + 1], col, thick)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, thick: int) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i in steps + 1:
		_dot(img, a.lerp(b, float(i) / steps), col, thick)


static func _dot(img: Image, p: Vector2, col: Color, thick: int) -> void:
	var r := thick * 0.5
	for dy in range(-int(r), int(ceil(r))):
		for dx in range(-int(r), int(ceil(r))):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				if col.a >= 1.0 or img.get_pixel(x, y).a < 0.5:
					img.set_pixel(x, y, col)
