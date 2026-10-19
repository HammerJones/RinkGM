class_name IceGridView
extends Control
## The weekly ice grid (RINK_SIM 5.1): Monday to Sunday down the side, 05:00
## to 01:00 across in 15-minute cells. Free ice is shaded by slot class
## (prime, shoulder, dead); bookings are coloured by ice use; floods sit in
## the gap before each booking and show who does them, red when nobody can.
## A thin amber line marks now. Drawn cell by cell on whole pixels so it
## stays as crisp as the pixel type.

const CELL_W := 18
const ROW_H := 60
const LABEL_W := 56
const HEAD_H := 30

const SHORT := {
	"vbl_d": "BL D/C", "public_skate": "PUBLIC", "learn_to_skate": "LTS", "broomball": "BROOMBALL",
	"minor_hockey": "MINOR", "figure_club": "FIGURE", "high_school": "MALLARDS", "vbl_a": "BL A",
	"lumber_kings": "KINGS", "tournament": "TOURNEY", "dukes_practice": "DUKES",
}
const CLASS_FILL := {
	"prime": Color("1d3150"),
	"shoulder": Color("15243b"),
	"dead": Color("0f1b2e"),
}

var week: Array = []
var today := -1       ## weekday of today, -1 for none
var now_hour := -1.0  ## hours since midnight


func _init() -> void:
	custom_minimum_size = Vector2(LABEL_W + OfficeData.GRID_CELLS * CELL_W, HEAD_H + 7 * ROW_H)


func show_sim(sim: RinkSim) -> void:
	week = OfficeData.grid_week(sim)
	today = sim.weekday()
	now_hour = sim.minute / 60.0
	queue_redraw()


static func use_color(use: String) -> Color:
	match use:
		"hockey": return RinkOS.READOUT
		"public": return RinkOS.GOOD
	return RinkOS.TEXT


func _draw() -> void:
	var font := RinkOS.TERM_FONT
	var fs := RinkOS.TERM_SIZE
	var asc := int(font.get_ascent(fs))
	# Hour ticks: 05 .. 00.
	for h in 21:
		var x := LABEL_W + h * 4 * CELL_W
		draw_string(font, Vector2(x, asc), "%02d" % ((OfficeData.GRID_START_H + h) % 24), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RinkOS.DIM)
		draw_rect(Rect2(x, HEAD_H - 6, 2, 6), RinkOS.DIM)
	for r in week.size():
		var day: Dictionary = week[r]
		var y := HEAD_H + r * ROW_H
		var is_today: bool = day.weekday == today
		draw_string(font, Vector2(0, y + (ROW_H - 8) / 2 + asc / 2), day.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			RinkOS.ACTION if is_today else RinkOS.TEXT)
		var cells: Array = day.cells
		for i in cells.size():
			var c: Dictionary = cells[i]
			var rect := Rect2(LABEL_W + i * CELL_W, y, CELL_W - 1, ROW_H - 8)
			match c.kind:
				"free":
					draw_rect(rect, CLASS_FILL[c["class"]])
				"session":
					var col := use_color(c.booking.use)
					draw_rect(rect, col.darkened(0.72))
					draw_rect(Rect2(rect.position, Vector2(CELL_W, 4)), col)
				"flood":
					var crew: String = c.crew
					draw_rect(rect, RinkOS.ALERT.darkened(0.55) if crew == "" else RinkOS.BEZEL)
					draw_rect(Rect2(rect.position, Vector2(CELL_W - 1, 4)), RinkOS.ALERT if crew == "" else RinkOS.DIM)
					# Pixel ripples for the flood water; a red bar for nobody.
					for k in 3:
						var ry := rect.position.y + 14 + k * 12
						if crew == "":
							draw_rect(Rect2(rect.position.x + 7, ry, 4, 8), RinkOS.ALERT)
						else:
							draw_rect(Rect2(rect.position.x + 3 + (k % 2) * 4, ry, 8, 2), RinkOS.TEXT)
		# Booking captions over their run of cells.
		for i in cells.size():
			var c: Dictionary = cells[i]
			if c.kind == "session" and c.get("first", false):
				var b: Dictionary = c.booking
				var n := 0
				while i + n < cells.size() and cells[i + n].kind == "session":
					n += 1
				var x := LABEL_W + i * CELL_W + 4
				var w := n * CELL_W - 6
				var col := use_color(b.use)
				draw_string(font, Vector2(x, y + 6 + asc), SHORT.get(b.org, b.org.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
				var t := "%02d:%02d %sH" % [int(b.start) % 24, int(fmod(b.start, 1.0) * 60.0), str(b.hours)]
				draw_string(font, Vector2(x, y + 26 + asc), t, HORIZONTAL_ALIGNMENT_LEFT, w, fs, RinkOS.DIM)
		# Ice an organisation would bid on: an amber dashed outline.
		for o in day.get("offers", []):
			var c0 := LABEL_W + OfficeData._cell(o.start) * CELL_W
			var ow := int(round(o.hours * 4.0)) * CELL_W - 1
			_dashed(Rect2(c0, y, ow, ROW_H - 8), RinkOS.ACTION)
			draw_string(font, Vector2(c0 + 6, y + 6 + asc), "BID?", HORIZONTAL_ALIGNMENT_LEFT, ow - 8, fs, RinkOS.ACTION)
			draw_string(font, Vector2(c0 + 6, y + 26 + asc), SHORT.get(o.org, o.org.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, ow - 8, fs, RinkOS.ACTION)
		if is_today and now_hour >= 0.0:
			var h := now_hour if now_hour >= OfficeData.GRID_START_H else now_hour + 24.0
			var nx := LABEL_W + int((h - OfficeData.GRID_START_H) * 4.0 * CELL_W)
			if nx >= LABEL_W and nx < size.x:
				draw_rect(Rect2(nx - 1, y - 4, 2, ROW_H), RinkOS.ACTION)


func _dashed(r: Rect2, col: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		var w := minf(6.0, r.end.x - x)
		draw_rect(Rect2(x, r.position.y, w, 2), col)
		draw_rect(Rect2(x, r.end.y - 2, w, 2), col)
		x += 10.0
	var y := r.position.y
	while y < r.end.y:
		var h := minf(6.0, r.end.y - y)
		draw_rect(Rect2(r.position.x, y, 2, h), col)
		draw_rect(Rect2(r.end.x - 2, y, 2, h), col)
		y += 10.0
