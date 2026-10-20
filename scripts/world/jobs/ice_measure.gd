class_name IceMeasure
extends JobScene
## Measuring the ice (docs/world/ICE.md 3): the depth plates with the dial
## caliper, the laser and survey rod with the clipboard, and the lidar
## tablet once it's bought. The popups are drawn, RinkOS world-object style:
## a "Mitsutoya" dial caliper read off its beam and dial, an E-pattern rod
## with the laser's red line across it, a clipboard with the rink on it and
## the numbers in pencil, a tablet with the heat map.
##
## target "ice_depth"   pick a plate (A/D), E drills and reads it, E writes
##                      it down. An empty faceoff dot: E orders a plate (the
##                      ice shuts for a day while it freezes in).
## target "ice_survey"  pick a spot on the clipboard, E stands the rod there
##                      and reads the laser, E writes it down.
## target "ice_lidar"   the tablet scans the sheet (needs the lidar tier).
## Pick DONE and E to hand the readings to the sim (RinkSim "ice_depth" /
## "ice_survey" log them).

## The survey's spots: a grid of three lines along the sheet.
const SURVEY_POINTS := [
	Vector2(-24, -8), Vector2(-12, -8), Vector2(0, -8), Vector2(12, -8), Vector2(24, -8),
	Vector2(-24, 0), Vector2(-12, 0), Vector2(0, 0), Vector2(12, 0), Vector2(24, 0),
	Vector2(-24, 8), Vector2(-12, 8), Vector2(0, 8), Vector2(12, 8), Vector2(24, 8),
]
const PLATE_ORDER := ["centre", "home_left", "home_right", "home_nz_left", "home_nz_right",
	"away_nz_left", "away_nz_right", "away_left", "away_right"]

var mode := "depth"
var ice: IceSlab
var tier := 0
var sel := 0
var readings := {}       # id -> {"value", "text", "sigma", "instrument", "at"}
var showing := false
var cur := {}            # the reading in the popup
var popup: MeasurePopup
var preview := ""
var _rng := RandomNumberGenerator.new()
var _choices: Array = []
var _own_world := false


func _build() -> void:
	title = "ICE"
	environment(Color("101318"), 0.45)
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	popup = MeasurePopup.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.owner_scene = self
	layer.add_child(popup)


func begin(ctx: Dictionary) -> void:
	preview = str(ctx.get("preview", ""))
	_rng.seed = 1298
	var sm: Object = ctx.get("sim", null) as Object
	ice = sm.get("ice") as IceSlab if sm else null
	if ice == null:
		ice = ctx.get("ice") as IceSlab
	if ice == null:
		ice = IceSlab.create_millbrook()
	var t: Variant = sm.get("tools") if sm else {}
	tier = int((t as Dictionary).get("ice_level", 0)) if t is Dictionary else 0
	var tg := str(ctx.get("target", ""))
	mode = str({"ice_depth": "depth", "ice_survey": "survey", "ice_lidar": "lidar"}.get(tg, "depth" if str(ctx.get("job", "")) == "ice_depth" else "survey"))
	if preview != "":
		mode = str({"caliper": "depth", "survey": "survey", "lidar": "lidar"}.get(preview, mode))
		if preview == "lidar":
			tier = maxi(tier, 1)
	super.begin(ctx)
	_world()
	if preview != "":
		_preview()


func _setup() -> void:
	_choices = []
	match mode:
		"depth":
			for id in PLATE_ORDER:
				_choices.append(id)
			steps = [{"id": "read", "text": "Drill the plates and read the caliper"}, {"id": "done", "text": "Hand in the numbers"}]
		"survey":
			for i in SURVEY_POINTS.size():
				_choices.append("p%d" % i)
			steps = [{"id": "read", "text": "Stand the rod and read the laser"}, {"id": "done", "text": "Hand in the clipboard"}]
		_:
			_choices.append("scan")
			steps = [{"id": "read", "text": "Scan the sheet with the tablet"}, {"id": "done", "text": "Save the scan"}]
	_choices.append("done")
	title = {"depth": "DEPTH PLATES", "survey": "SURVEY", "lidar": "LIDAR"}.get(mode, "ICE")


func _enter_step(_i: int) -> void:
	_prompt_for_selection()


## A rink to look at when there's no venue around.
func _world() -> void:
	var views: Array = []
	if is_inside_tree():
		for v: Node in get_tree().get_nodes_in_group("ice_view"):
			if not v.is_queued_for_deletion():
				views.append(v)
	if views.is_empty():
		_own_world = true
		var rink := Rink.new()
		add_child(rink)
		IceView.attach(rink, ice)
		light(Vector3(0, 9, 0), 2.0, 40.0, Color(1, 0.97, 0.9), false)
		light(Vector3(-20, 9, 0), 1.4, 30.0, Color(1, 0.97, 0.9), false)
		light(Vector3(20, 9, 0), 1.4, 30.0, Color(1, 0.97, 0.9), false)
	# the tripod and laser at centre ice
	var steel := Color("8a8f94")
	for k in 3:
		var a := k * TAU / 3.0
		var leg := slab(Vector3(0.03, 1.3, 0.03), Vector3(cos(a) * 0.25, 0.62, sin(a) * 0.25), steel)
		leg.rotation = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)
	slab(Vector3(0.16, 0.12, 0.16), Vector3(0, 1.3, 0), Color("d4a83a"))
	slab(Vector3(0.06, 0.05, 0.06), Vector3(0, 1.39, 0), Color("b8312f"), 1.5)
	view(Vector3(-6.0, 1.7, -9.5), Vector3(0.0, 0.6, 0.0))
	snap_camera()


func _preview() -> void:
	match preview:
		"caliper":
			sel = 0
			_take()
		"survey":
			for i in [0, 2, 4, 5, 6, 7, 9, 12]:
				sel = i
				_take()
				_write()
			sel = 10
			_take()
		"lidar":
			_take()


func _on_pick_x(d: int) -> void:
	if showing or complete:
		return
	sel = posmod(sel + d, _choices.size())
	_prompt_for_selection()


func _prompt_for_selection() -> void:
	var id: String = _choices[sel] if sel < _choices.size() else "done"
	hint = "%s pick   %s %s   %s leave" % [RinkOS.key("A/D"), RinkOS.key("E"), "take it" if not showing else "write it down", RinkOS.key("X")]
	if id == "done":
		prompt = "Done: hand in %d reading%s." % [readings.size(), "" if readings.size() == 1 else "s"]
		return
	match mode:
		"depth":
			if id in ice.plates:
				prompt = "The plate at %s. Drill down to it and put the caliper's depth rod in." % id.replace("_", " ")
			else:
				prompt = "No plate at %s. %s orders one: \\$65, and the ice shuts for a day while it freezes in." % [id.replace("_", " "), RinkOS.key("E")]
		"survey":
			var p: Vector2 = SURVEY_POINTS[int(id.substr(1))]
			prompt = "Stand the rod at %.0f m along, %.0f m across. The laser's on the tripod at centre ice." % [p.x, p.y]
		_:
			prompt = "Walk the tablet round the boards and let it scan." if tier >= 1 else "You don't have a scanner. The office can order one (lidar, \\$3,400)."


func _work(f: JobInput.Frame, _dt: float) -> void:
	if not f.interact_pressed:
		return
	var id: String = _choices[sel] if sel < _choices.size() else "done"
	if showing:
		_write()
	elif id == "done":
		advance()
		advance("Handed in %d readings." % readings.size())
	else:
		_take()


## Takes the reading at the selection and opens the popup on it.
func _take() -> void:
	var id: String = _choices[sel]
	match mode:
		"depth":
			if not id in ice.plates:
				_order_plate(id)
				return
			var mm := ice.plate_depth_mm(id) + _rng.randfn(0.0, 0.04)  # frost on the hole's lip
			cur = {"id": id, "value": mm, "text": IceGauges.caliper(mm).text, "sigma": 0.04, "instrument": "Mitsutoya dial caliper"}
		"survey":
			var p: Vector2 = SURVEY_POINTS[int(id.substr(1))]
			var tiers: Array = SimInstrument.tiers("ice_level")
			var sig := float(tiers[0].sigma)
			var mm := ice.rod_reading_mm(p) + _rng.randfn(0.0, sig)
			cur = {"id": id, "value": mm, "text": IceGauges.rod(mm).text, "sigma": sig, "instrument": "Laser and survey rod", "at": [p.x, p.y]}
		_:
			if tier < 1:
				prompt = "No scanner yet."
				return
			var tiers2: Array = SimInstrument.tiers("ice_level")
			var scan := IceGauges.lidar(ice, 4, float(tiers2[mini(tier, tiers2.size() - 1)].sigma), _rng)
			cur = {"id": "scan", "value": float(scan.max) - float(scan.min), "text": "%.1f mm high to low" % (float(scan.max) - float(scan.min)),
				"sigma": float(tiers2[mini(tier, tiers2.size() - 1)].sigma), "instrument": str(tiers2[mini(tier, tiers2.size() - 1)].name), "scan": scan}
	showing = true
	popup.queue_redraw()
	_prompt_for_selection()


func _write() -> void:
	if cur.is_empty():
		showing = false
		return
	var rec := cur.duplicate()
	rec.erase("scan")
	readings[str(cur.id)] = rec
	log_lines.append("%s: %s" % [str(cur.id).replace("_", " "), cur.text])
	showing = mode == "lidar"  # the tablet stays up
	popup.queue_redraw()
	if mode != "lidar":
		sel = mini(sel + 1, _choices.size() - 1)
	_prompt_for_selection()


func _order_plate(id: String) -> void:
	if sim == null:
		prompt = "No rink to order for."
		return
	var r: Dictionary = sim.call("job", "install_plate", {"spot": id})
	prompt = str(r.get("text", ""))
	log_lines.append(prompt)


func _result() -> Dictionary:
	var pts: Array = []
	for k: String in readings:
		if (readings[k] as Dictionary).has("at"):
			pts.append(readings[k].at)
	return {"quality": 1.0, "readings": readings.duplicate(true), "points": pts, "mode": mode}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if showing:
		return out  # the clipboard has them
	for k: String in readings:
		out.append("%s %s" % [RinkOS.dots(k.replace("_", " ").to_upper(), "", 16).strip_edges(), readings[k].text])
	return out


## The popup: the instrument on the left, the clipboard (or tablet) right.
class MeasurePopup extends Control:
	var owner_scene: IceMeasure

	func _draw() -> void:
		if owner_scene == null or owner_scene.ice == null:
			return
		var s := owner_scene
		var vs := size
		var w := minf(1100.0, vs.x - 40.0)
		var h := minf(500.0, vs.y - 300.0)
		var r := Rect2((vs.x - w) * 0.5, 170.0, w, h)
		if s.mode == "lidar":
			if s.showing and s.cur.has("scan"):
				_tablet(Rect2(r.position.x + r.size.x * 0.12, r.position.y, r.size.x * 0.76, r.size.y), s.cur.scan, s.cur)
			return
		var left := Rect2(r.position, Vector2(r.size.x * 0.56, r.size.y))
		var right := Rect2(r.position + Vector2(r.size.x * 0.59, 0), Vector2(r.size.x * 0.41, r.size.y))
		if s.showing:
			if s.mode == "depth":
				_caliper(left, float(s.cur.value))
			else:
				_rod(left, float(s.cur.value))
		_clipboard(right)

	# ---------------------------------------------------------------- caliper

	func _caliper(r: Rect2, mm: float) -> void:
		var steel := Color("c9ccd0")
		var dark := Color("2a2c30")
		var ink := Color("1d1e21")
		draw_rect(r, Color(0.04, 0.06, 0.1, 0.88))
		draw_rect(r, RinkOS.BEZEL, false, 2.0)
		var c := IceGauges.caliper(mm)
		var beam_mm := float(c.beam)
		# the beam: a 30 mm window either side of the jaw, a line every mm
		var by := r.position.y + r.size.y * 0.30
		var bx0 := r.position.x + 20.0
		var bx1 := r.end.x - 20.0
		var px_per_mm := (bx1 - bx0) / 34.0
		var jaw_x := bx0 + (bx1 - bx0) * 0.38
		draw_rect(Rect2(bx0, by - 26, bx1 - bx0, 52), steel)
		draw_rect(Rect2(bx0, by - 26, bx1 - bx0, 52), Color("8a8f94"), false, 1.0)
		for k in range(-14, 22):
			var v := int(beam_mm) + k
			if v < 0:
				continue
			var x := jaw_x + (v - mm) * px_per_mm
			if x < bx0 + 2 or x > bx1 - 2:
				continue
			var long := v % 10 == 0
			var mid := v % 5 == 0
			draw_line(Vector2(x, by - 26), Vector2(x, by - 26 + (22.0 if long else (15.0 if mid else 9.0))), ink, 1.5)
			if long:
				draw_string(RinkOS.TERM_FONT, Vector2(x - 8, by + 18), str(v / 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		draw_string(RinkOS.PIXEL_FONT, Vector2(bx1 - 70, by + 22), "mm x10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		# the slider and its jaw: the index line reads the beam
		var sl := Rect2(jaw_x - 50, by - 34, 190, 150)
		draw_rect(sl, Color("b3b7bc"))
		draw_rect(sl, Color("6f7378"), false, 2.0)
		draw_line(Vector2(jaw_x, by - 34), Vector2(jaw_x, by - 4), RinkOS.ALERT, 2.0)
		draw_rect(Rect2(jaw_x - 50, by + 30, 26, 120), Color("a3a7ac"))  # the jaw going down the hole
		# the dial: 50 divisions, a turn a millimetre
		var dc := Vector2(jaw_x + 50, by + 58)
		var rad := 62.0
		draw_circle(dc, rad + 6, dark)
		draw_circle(dc, rad, Color("f3f1ea"))
		for k in 50:
			var a := k / 50.0 * TAU - PI * 0.5
			var inner := rad - (12.0 if k % 5 == 0 else 6.0)
			draw_line(dc + Vector2(cos(a), sin(a)) * inner, dc + Vector2(cos(a), sin(a)) * (rad - 1.0), ink, 1.5 if k % 5 == 0 else 1.0)
			if k % 10 == 0:
				var lp := dc + Vector2(cos(a), sin(a)) * (rad - 24.0) - Vector2(8, -6)
				draw_string(RinkOS.TERM_FONT, lp, "%d" % (k * 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		var na := float(c.needle) - PI * 0.5
		draw_line(dc, dc + Vector2(cos(na), sin(na)) * (rad - 8.0), RinkOS.ALERT, 2.5)
		draw_circle(dc, 4.0, ink)
		draw_string(RinkOS.PIXEL_BOLD, dc + Vector2(-40, -18), "MITSUTOYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		draw_string(RinkOS.PIXEL_FONT, dc + Vector2(-22, 30), "0.02mm", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		draw_string(RinkOS.PIXEL_FONT, Vector2(r.position.x + 12, r.position.y + 20), "// DIAL CALIPER, DEPTH ROD IN THE HOLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RinkOS.ACTION)
		draw_string(RinkOS.TERM_FONT, Vector2(r.position.x + 12, r.end.y - 14),
			"beam %d mm + dial %d x 0.02" % [int(beam_mm), roundi(float(c.dial))], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RinkOS.READOUT)

	# ---------------------------------------------------------------- rod

	func _rod(r: Rect2, mm: float) -> void:
		draw_rect(r, Color(0.04, 0.06, 0.1, 0.88))
		draw_rect(r, RinkOS.BEZEL, false, 2.0)
		draw_string(RinkOS.PIXEL_FONT, Vector2(r.position.x + 12, r.position.y + 20), "// SURVEY ROD, LASER AT CENTRE ICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RinkOS.ACTION)
		var rod := Rect2(r.position.x + r.size.x * 0.32, r.position.y + 34, 110, r.size.y - 60)
		draw_rect(rod, Color("f4f1e6"))
		var px_per_mm := rod.size.y / 120.0  # 12 cm of rod in view
		var mid_y := rod.position.y + rod.size.y * 0.5
		var lo := int(floor(mm - 60.0))
		var red := Color("c8322b")
		var black := Color("1d1e21")
		for v in range(lo, lo + 121):
			var y := mid_y - (v - mm) * px_per_mm
			if y < rod.position.y or y > rod.end.y:
				continue
			var cm := int(floor(v / 10.0))
			var col := red if int(floor(cm / 10.0)) % 2 == 1 else black
			# the E pattern: the first five mm of every cm, a bar on alternate sides
			if posmod(v, 10) < 5:
				var x0 := rod.position.x + (8.0 if cm % 2 == 0 else rod.size.x * 0.5)
				draw_line(Vector2(x0, y), Vector2(x0 + rod.size.x * 0.42, y), col, maxf(px_per_mm, 1.0))
			if posmod(v, 10) == 0:
				draw_string(RinkOS.TERM_FONT, Vector2(rod.end.x + 8, y + 8), "%d" % cm, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RinkOS.TEXT)
			draw_line(Vector2(rod.end.x - 10, y), Vector2(rod.end.x, y), black, 1.0)
		# the laser: a red line across the rod, a little fuzzy
		draw_line(Vector2(rod.position.x - 30, mid_y), Vector2(rod.end.x + 60, mid_y), Color(1, 0.1, 0.1, 0.35), 7.0)
		draw_line(Vector2(rod.position.x - 30, mid_y), Vector2(rod.end.x + 60, mid_y), Color(1, 0.15, 0.1, 0.95), 2.0)
		draw_string(RinkOS.TERM_FONT, Vector2(r.position.x + 12, r.end.y - 14), "laser on the rod: %s" % IceGauges.rod(mm).text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RinkOS.READOUT)

	# ---------------------------------------------------------------- clipboard

	func _clipboard(r: Rect2) -> void:
		var s := owner_scene
		draw_rect(r, Color("8a6d3b"))
		var paper := r.grow(-14)
		paper.position.y += 18
		paper.size.y -= 18
		draw_rect(paper, Color("f2efe4"))
		draw_rect(Rect2(r.get_center().x - 50, r.position.y + 4, 100, 26), Color("9aa0a6"))
		var ink := Color("2b2b33")
		var pencil := Color("3a3a48")
		draw_string(RinkOS.PIXEL_FONT, paper.position + Vector2(10, 18), "MILLBROOK ICE  " + ("DEPTHS" if s.mode == "depth" else "LEVELS (mm, + high)"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		# the rink outline
		var rk := Rect2(paper.position + Vector2(14, 34), Vector2(paper.size.x - 28, (paper.size.x - 28) * Rink.WIDTH / Rink.LENGTH))
		var to_px := func(p: Vector2) -> Vector2:
			return rk.position + Vector2((p.x + Rink.HALF_L) / Rink.LENGTH * rk.size.x, (p.y + Rink.HALF_W) / Rink.WIDTH * rk.size.y)
		var pts := PackedVector2Array()
		for k in 64:
			var a := k / 64.0 * TAU
			var q := Vector2(cos(a), sin(a))
			# a rounded rectangle
			var cx := Rink.HALF_L - Rink.CORNER_R
			var cy := Rink.HALF_W - Rink.CORNER_R
			var c := Vector2(signf(q.x) * cx, signf(q.y) * cy)
			pts.append(to_px.call(c + q * Rink.CORNER_R))
		pts.append(pts[0])
		draw_polyline(pts, ink, 1.5)
		draw_line(to_px.call(Vector2(0, -Rink.HALF_W)), to_px.call(Vector2(0, Rink.HALF_W)), Color("c8322b"), 1.0)
		for bx in [-Rink.BLUE_X, Rink.BLUE_X]:
			draw_line(to_px.call(Vector2(bx, -Rink.HALF_W)), to_px.call(Vector2(bx, Rink.HALF_W)), Color("2f5eb0"), 1.0)
		var sel_id: String = s._choices[s.sel] if s.sel < s._choices.size() else ""
		if s.mode == "depth":
			for id: String in IceSlab.PLATE_SPOTS:
				var p: Vector2 = to_px.call(IceSlab.PLATE_SPOTS[id])
				var has := id in s.ice.plates
				draw_circle(p, 5.0, ink if has else Color(0, 0, 0, 0.2))
				if id == sel_id:
					draw_arc(p, 10.0, 0, TAU, 20, RinkOS.ACTION, 2.0)
				if s.readings.has(id):
					draw_string(RinkOS.TERM_FONT, p + Vector2(8, -6), "%.2f" % float(s.readings[id].value), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pencil)
		else:
			var ref := float(s.readings["p7"].value) if s.readings.has("p7") else NAN
			for i in SURVEY_POINTS.size():
				var id := "p%d" % i
				var p: Vector2 = to_px.call(SURVEY_POINTS[i])
				draw_line(p - Vector2(4, 4), p + Vector2(4, 4), ink, 1.0)
				draw_line(p - Vector2(4, -4), p + Vector2(4, -4), ink, 1.0)
				if id == sel_id:
					draw_arc(p, 10.0, 0, TAU, 20, RinkOS.ACTION, 2.0)
				if s.readings.has(id):
					var v := float(s.readings[id].value)
					var txt := ("%+.0f" % IceGauges.rise_mm(ref, v)) if not is_nan(ref) else ("%.0f" % v)
					draw_string(RinkOS.TERM_FONT, p + Vector2(6, -4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pencil)
			draw_string(RinkOS.TERM_FONT, Vector2(paper.position.x + 10, rk.end.y + 26),
				"rod at centre = 0" if not is_nan(ref) else "read centre ice first: the rest go off it", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pencil)
		var y := rk.end.y + 52
		var col := 0.0
		for k: String in s.readings:
			if y > paper.end.y - 8:
				if col > 0.0:
					break
				col = paper.size.x * 0.5
				y = rk.end.y + 52
			draw_string(RinkOS.TERM_FONT, Vector2(paper.position.x + 10 + col, y), "%s  %s" % [k.replace("_", " "), s.readings[k].text], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pencil)
			y += 20

	# ---------------------------------------------------------------- tablet

	func _tablet(r: Rect2, scan: Dictionary, cur: Dictionary) -> void:
		draw_rect(r, Color("16181c"))
		draw_rect(r.grow(-6), Color("0b0d10"))
		var scr := r.grow(-18)
		draw_string(RinkOS.PIXEL_FONT, scr.position + Vector2(8, 18), "LEVELSCAN  //  %s" % str(cur.instrument).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RinkOS.ACTION)
		var w := int(scan.w)
		var h := int(scan.h)
		var vals: PackedFloat32Array = scan.values
		var map := Rect2(scr.position + Vector2(8, 30), Vector2(scr.size.x - 120, (scr.size.x - 120) * float(h) / float(w)))
		if map.size.y > scr.size.y - 70:
			var k := (scr.size.y - 70) / map.size.y
			map.size *= k
		var lo := float(scan.min)
		var hi := float(scan.max)
		var cw := map.size.x / w
		var ch := map.size.y / h
		for z in h:
			for x in w:
				var v := vals[z * w + x]
				if is_nan(v):
					continue
				var t := clampf((v - lo) / maxf(hi - lo, 0.01), 0.0, 1.0)
				draw_rect(Rect2(map.position + Vector2(x * cw, z * ch), Vector2(cw + 0.5, ch + 0.5)), _heat(t))
		# legend
		var lg := Rect2(map.end.x + 20, map.position.y, 22, map.size.y)
		for k in 32:
			var t2 := 1.0 - k / 31.0
			draw_rect(Rect2(lg.position + Vector2(0, k * lg.size.y / 32.0), Vector2(lg.size.x, lg.size.y / 32.0 + 0.5)), _heat(t2))
		draw_string(RinkOS.TERM_FONT, lg.position + Vector2(28, 14), "%+.1f" % hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, RinkOS.TEXT)
		draw_string(RinkOS.TERM_FONT, Vector2(lg.position.x + 28, lg.end.y), "%+.1f mm" % lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, RinkOS.TEXT)
		draw_string(RinkOS.TERM_FONT, Vector2(scr.position.x + 8, scr.end.y - 8), "high to low %.1f mm   +-%.2f mm" % [hi - lo, float(cur.sigma)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RinkOS.READOUT)

	static func _heat(t: float) -> Color:
		# low blue, level green, high red
		if t < 0.5:
			return Color("2f5eb0").lerp(Color("8cf26a"), t * 2.0)
		return Color("8cf26a").lerp(Color("ff5f52"), (t - 0.5) * 2.0)
