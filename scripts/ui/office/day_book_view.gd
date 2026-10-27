class_name DayBookView
extends Control
## The calendar's day page: one day from 05:00 to 01:00 across, in the same
## 15-minute cells as the ice grid. The top lane is the ice (bookings, the
## floods and who drives them, ice an organisation would bid on); under it
## one lane per staff member working that day: their shift, their break and
## the jobs handed to them. With a job picked up (`armed`) the lanes that
## could take it light up and a ghost block shows where it would go.
## Mouse or arrow keys move the cursor; a click or Enter emits `picked`.
## Drawn on whole pixels like the rest of RINK-OS.

signal picked(lane: int, minute: int)
signal cursor_moved(lane: int, minute: int)

const LABEL_W := 216
const HEAD_H := 30
const ICE_H := 56
const ROW_H := 40
const GAP := 6
const MIN_CELL := 10

var sim: RinkSim
var day := 0
var staff: Array = []        ## [Person], one lane each, below the ice
var armed := ""              ## the job id being handed out, "" for none
var lane := 1                ## cursor lane: 0 is the ice, 1.. the staff
var cell := 0                ## cursor cell from 05:00

var _cell_w := 12


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_day(sim_: RinkSim, day_: int, staff_: Array) -> void:
	sim = sim_
	day = day_
	staff = staff_
	lane = clampi(lane, 0, staff.size())
	custom_minimum_size = Vector2(LABEL_W + OfficeData.GRID_CELLS * MIN_CELL, HEAD_H + ICE_H + staff.size() * ROW_H + 4)
	queue_redraw()


## The staff member in lane `l`, or null for the ice.
func person(l := -1) -> Person:
	var i := (lane if l < 0 else l) - 1
	return staff[i] if i >= 0 and i < staff.size() else null


## Minutes since midnight of cell `c` (cells run past midnight into the next day's 00:xx).
static func minute_of(c: int) -> int:
	return OfficeData.GRID_START_H * 60 + c * OfficeData.CELL_MIN


func cursor_minute() -> int:
	return minute_of(cell)


func _lane_y(l: int) -> int:
	return HEAD_H if l == 0 else HEAD_H + ICE_H + (l - 1) * ROW_H


func _lane_h(l: int) -> int:
	return (ICE_H if l == 0 else ROW_H) - GAP


func _x(hour: float) -> int:
	return LABEL_W + int(round((hour - OfficeData.GRID_START_H) * 4.0)) * _cell_w


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or (e is InputEventMouseButton and e.pressed):
		var p: Vector2 = e.position
		if p.x >= LABEL_W and p.y >= HEAD_H:
			var c := clampi(int((p.x - LABEL_W) / _cell_w), 0, OfficeData.GRID_CELLS - 1)
			var l := 0 if p.y < HEAD_H + ICE_H else clampi(1 + int((p.y - HEAD_H - ICE_H) / ROW_H), 1, staff.size())
			_move(l, c)
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				grab_focus()
				picked.emit(lane, cursor_minute())
				accept_event()
		return
	var dl := 0
	var dc := 0
	if e.is_action_pressed("ui_up", true):
		dl = -1
	elif e.is_action_pressed("ui_down", true):
		dl = 1
	elif e.is_action_pressed("ui_left", true):
		dc = -1
	elif e.is_action_pressed("ui_right", true):
		dc = 1
	elif e.is_action_pressed("ui_accept"):
		picked.emit(lane, cursor_minute())
		accept_event()
		return
	else:
		return
	# Off the top or bottom lane hands focus back to the buttons around the page.
	if lane + dl < 0 or lane + dl > staff.size():
		return
	_move(lane + dl, clampi(cell + dc, 0, OfficeData.GRID_CELLS - 1))
	accept_event()


func _move(l: int, c: int) -> void:
	if l == lane and c == cell:
		return
	lane = l
	cell = c
	queue_redraw()
	cursor_moved.emit(lane, cursor_minute())


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if sim == null:
		return
	_cell_w = maxi(MIN_CELL, int((size.x - LABEL_W) / OfficeData.GRID_CELLS))
	var font := RinkOS.TERM_FONT
	var fs := RinkOS.TERM_SIZE
	var asc := int(font.get_ascent(fs))
	var wd := sim.weekday_of(day)
	var end_x := LABEL_W + OfficeData.GRID_CELLS * _cell_w
	# Hour ticks, and a faint rule down the page every hour.
	for h in OfficeData.GRID_CELLS / 4 + 1:
		var x := LABEL_W + h * 4 * _cell_w
		draw_string(font, Vector2(x, asc), "%02d" % ((OfficeData.GRID_START_H + h) % 24), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RinkOS.DIM)
		draw_rect(Rect2(x, HEAD_H - 6, 2, size.y - HEAD_H + 6), Color(RinkOS.BEZEL, 0.35))

	_draw_ice(font, fs, asc, wd)
	for i in staff.size():
		_draw_staff(i + 1, staff[i], font, fs, asc, wd)

	# Now: an amber line through every lane.
	if day == sim.day:
		var nx := _x(sim.minute / 60.0)
		if nx >= LABEL_W and nx < end_x:
			draw_rect(Rect2(nx - 1, HEAD_H - 4, 2, size.y - HEAD_H + 4), RinkOS.ACTION)

	_draw_cursor()


func _draw_ice(font: Font, fs: int, asc: int, wd: int) -> void:
	var y := _lane_y(0)
	var h := _lane_h(0)
	draw_string(font, Vector2(0, y + asc + 4), "ICE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RinkOS.ACTION if lane == 0 else RinkOS.TEXT)
	draw_string(font, Vector2(0, y + asc + 26), "%s %d" % [RinkSim.DAY_NAMES[wd].to_upper(), int(sim.date_of(day).dom)], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RinkOS.DIM)
	for c in OfficeData.GRID_CELLS:
		var hr := OfficeData.GRID_START_H + c / 4.0
		draw_rect(Rect2(LABEL_W + c * _cell_w, y, _cell_w - 1, h), IceGridView.CLASS_FILL[OfficeData.slot_class(wd, hr)])
	for s: Dictionary in sim.sessions(day):
		var x0 := _x(float(s.start))
		var x1 := _x(float(s.start) + float(s.hours))
		var col := IceGridView.use_color(str(s.use))
		var r := Rect2(x0, y, x1 - x0 - 1, h)
		draw_rect(r, col.darkened(0.72))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), col)
		var name: String = IceGridView.SHORT.get(s.org, str(s.get("name", s.org)).to_upper())
		draw_string(font, Vector2(x0 + 4, y + 6 + asc), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, fs, col)
		draw_string(font, Vector2(x0 + 4, y + 28 + asc), _hhmm(float(s.start)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, fs, RinkOS.DIM)
	for f: Dictionary in sim.floods(day):
		var x := _x(int(f.minute) / 60.0)
		var crew := str(f.crew)
		var r := Rect2(x, y, _cell_w - 1, h)
		draw_rect(r, RinkOS.ALERT.darkened(0.55) if crew == "" else RinkOS.BEZEL)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), RinkOS.ALERT if crew == "" else RinkOS.DIM)
		for k in 3:
			draw_rect(Rect2(x + 2 + (k % 2) * 3, y + 14 + k * 10, _cell_w - 7, 2), RinkOS.ALERT if crew == "" else RinkOS.TEXT)


func _draw_staff(l: int, p: Person, font: Font, fs: int, asc: int, wd: int) -> void:
	var y := _lane_y(l)
	var h := _lane_h(l)
	var can := armed != "" and WorkOrders.can_do(p, armed)
	var name_col := RinkOS.ACTION if (can or lane == l) else RinkOS.TEXT
	if armed != "" and not can:
		name_col = RinkOS.DIM
	draw_string(font, Vector2(0, y + asc + 4), _fit_name(p.name, font, fs, LABEL_W - 64), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
	var trades := WorkOrders.trades_of(p)
	if not trades.is_empty():
		draw_string(font, Vector2(LABEL_W - 60, y + asc + 4), str(trades[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 56, fs, RinkOS.DIM)
	# Lane floor, then the shift on it: bezel blue, breaks cut out as dim ticks.
	draw_rect(Rect2(LABEL_W, y + h - 2, OfficeData.GRID_CELLS * _cell_w, 2), Color(RinkOS.BEZEL, 0.5))
	for c in OfficeData.GRID_CELLS:
		var hr := OfficeData.GRID_START_H + c / 4.0
		if hr >= 24.0 or not p.on_shift(wd, hr):
			continue
		var r := Rect2(LABEL_W + c * _cell_w, y + 4, _cell_w - (0 if p.on_shift(wd, hr + 0.25) else 1), h - 8)
		if p.entry_at(wd, hr).get("break", false):
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y / 2 - 1, _cell_w - 1, 2), RinkOS.DIM)
		else:
			draw_rect(r, Color(RinkOS.BEZEL, 0.55 if can else 0.35))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), RinkOS.BEZEL if not can else RinkOS.ACTION.darkened(0.3))
	# The jobs handed to them.
	for o: Dictionary in WorkOrders.on_day(sim, day):
		if str(o.who) != p.id:
			continue
		var x0 := _x(int(o.minute) / 60.0)
		var w := maxi(int(round(maxf(float(o.hours), 0.25) * 4.0)) * _cell_w - 1, _cell_w - 1)
		var col := RinkOS.ACTION
		if o.has("ok"):
			col = RinkOS.GOOD if o.ok else RinkOS.ALERT
		var r := Rect2(x0, y + 4, w, h - 8)
		draw_rect(r, col.darkened(0.7))
		draw_rect(Rect2(r.position, Vector2(w, 3)), col)
		draw_string(font, Vector2(x0 + 4, y + 6 + asc), short_job(str(o.id)), HORIZONTAL_ALIGNMENT_LEFT, maxi(w - 6, 1), fs, col)


func _draw_cursor() -> void:
	var y := _lane_y(lane)
	var h := _lane_h(lane)
	var x := LABEL_W + cell * _cell_w
	if armed != "" and lane > 0:
		var w := maxi(int(round(maxf(WorkOrders.hours_of(armed), 0.25) * 4.0)), 1) * _cell_w - 1
		var ok := WorkOrders.why_not(sim, person(), armed, day, cursor_minute()) == ""
		_dashed(Rect2(x, y, w, h), RinkOS.ACTION if ok else RinkOS.ALERT)
		return
	_dashed(Rect2(x, y, _cell_w - 1, h), RinkOS.ACTION)


## "Marguerite Lindqvist" -> "Marguerite L." when the whole name won't fit `w`.
static func _fit_name(name: String, font: Font, fs: int, w: int) -> String:
	if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return name
	var parts := name.split(" ")
	return "%s %s." % [parts[0], parts[-1].left(1)] if parts.size() > 1 else name


## A job's name short enough for a calendar block: "Compressor oil change" -> "COMP OIL CHANGE".
static func short_job(id: String) -> String:
	return id.to_upper().replace("_", " ").replace("COMPRESSOR", "COMP").replace("REFRIGERANT", "REFRIG")


static func _hhmm(h: float) -> String:
	return "%02d:%02d" % [int(h) % 24, roundi(fmod(h, 1.0) * 60.0)]


func _dashed(r: Rect2, col: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		var w := minf(6.0, r.end.x - x)
		draw_rect(Rect2(x, r.position.y, w, 2), col)
		draw_rect(Rect2(x, r.end.y - 2, w, 2), col)
		x += 10.0
	var yy := r.position.y
	while yy < r.end.y:
		var hh := minf(6.0, r.end.y - yy)
		draw_rect(Rect2(r.position.x, yy, 2, hh), col)
		draw_rect(Rect2(r.end.x - 2, yy, 2, hh), col)
		yy += 10.0
