extends DorisHatchJob
## Doris's oil and filter change, job `doris_oil_change` (docs/world/RINK_SIM.md
## 7: engine oil and filter, 120 h). Through her service hatch, in place like
## the plug change: the drain pan on the floor under the hatch, the drain
## plug on her oil pan's front face, the spin-on filter hanging under its
## boss on the block, the dipstick and the filler on top.
##
## Steps and verbs:
##   note        interact: read Gus's note
##   pan         interact: slide the drain pan under her
##   drain       grab + turn left with the ratchet cracks the drain plug; it
##               spins out and the old oil runs into the pan
##   plug_in     the drain plug with a new washer: hand, then ratchet + 1/4
##   filter_off  grab + turn left with the filter wrench: the old one off
##   gasket      interact: a fingertip of clean oil round the new gasket
##   filter_on   start it by HAND, hand tight, then + 3/4 with the wrench
##   fill        hold grab to pour; interact pulls the dipstick and reads it.
##               It goes on once the oil's up to the FULL line (or past it)
##   cap         interact: dipstick home, filler cap on
##   start       interact: start her and watch the oil light
##
## Result: {quality, oil_level (on the stick: 0.5 the ADD mark, 1 FULL),
## filter_ok, drain_plug_torque_ok, quarts, flags}.

const OIL_SERVICE := preload("res://scripts/world/jobs/compressor_oil_service.gd")
const FULL_QT := 4.0          # to the FULL line; ADD is a quart under
const POUR_QPS := 0.5
const DRAIN_S := 3.0
const PITCH := 0.004
const DIP_OUT_S := 1.6
const DRAIN_AXIS := Basis(Vector3.RIGHT, -PI / 2.0)   # the plug's +Y out of the pan (-Z)
const PAN_AT := Vector3(0.1, 0.0, -0.56)
const PAN_STAGE := Vector3(0.55, 0.0, -0.95)

var old_plug: Fastener
var plug: Fastener
var old_filter: Fastener
var filter: Fastener
var gasket_oiled := false
var quarts := 0.0
var start_text := ""

var _phase := ""
var _t := 0.0
var _pan_in := false
var _pan_oil := 0.0
var _dip_t := 0.0
var _pouring := false

var _plug_node: MeshInstance3D
var _old_filter_node: MeshInstance3D
var _filter_node: MeshInstance3D
var _pan: MeshInstance3D
var _pan_oil_node: MeshInstance3D
var _stream: Array[MeshInstance3D] = []
var _dip: MeshInstance3D
var _dip_grip: MeshInstance3D
var _bottle: MeshInstance3D


func _note_text() -> String:
	return "Oil every 120 hours\nor when the stick's black.\nPAN UNDER FIRST.\nFilter: oil the gasket,\nhand tight + three quarters.\nDrain plug: snug + a quarter.\nFULL line. Not past it.\nFour quarts.  - G"


func _setup() -> void:
	title = "Doris // oil + filter"
	steps = [
		{"id": "note", "text": "Read Gus's note"},
		{"id": "pan", "text": "Drain pan under her"},
		{"id": "drain", "text": "Drain the old oil"},
		{"id": "plug_in", "text": "Drain plug: hand tight + 1/4"},
		{"id": "filter_off", "text": "Spin off the old filter"},
		{"id": "gasket", "text": "Oil the new gasket"},
		{"id": "filter_on", "text": "New filter: hand tight + 3/4"},
		{"id": "fill", "text": "Fill to the FULL line"},
		{"id": "cap", "text": "Dipstick home, cap on"},
		{"id": "start", "text": "Start her up"},
	]
	var dp: Fastener = OIL_SERVICE.drain_plug()
	old_plug = JobScene.installed(dp, dp.hand_tight_deg() + 90.0)
	plug = OIL_SERVICE.drain_plug()
	var of := Fastener.oil_filter()
	old_filter = JobScene.installed(of, of.hand_tight_deg() + 270.0)
	filter = Fastener.oil_filter()
	gasket_oiled = false
	quarts = 0.0
	start_text = ""
	_phase = ""
	_pan_in = false
	_pan_oil = 0.0
	_dip_t = 0.0
	_sync(0.0)
	snap_camera()


## On the stick: 0.5 is the ADD mark, 1.0 the FULL line (a quart apart).
func level() -> float:
	return clampf((quarts - (FULL_QT - 2.0)) / 2.0, 0.0, 1.5)


func _enter_step(i: int) -> void:
	_phase = ""
	_t = 0.0
	var drain := bay(JobParts.DRAIN_AT)
	var fil := bay(JobParts.FILTER_AT)
	var drain_view := [drain + Vector3(0.04, 0.26, -0.5), drain]
	var filter_view := [fil + Vector3(0.12, 0.16, -0.46), fil + Vector3(0, -0.05, 0)]
	match str(steps[i].id):
		"note":
			note_view()
			prompt = "Gus: \"Oil every 120 hours or when the stick's black. PAN UNDER FIRST. Filter: oil the gasket, hand tight then three quarters. Drain plug snug and a quarter. FULL line, not past it. Four quarts.\""
			hint = "%s read it" % RinkOS.key("E")
		"pan":
			view(Vector3(0.2, 0.95, -1.15), PAN_AT + Vector3(0, 0.2, 0.15))
			prompt = "The drain plug's low on her oil pan, behind the hatch sill. Pan under first, like the note says."
			hint = "%s slide the pan under" % RinkOS.key("E")
		"drain":
			view(drain_view[0], drain_view[1])
			tools = PackedStringArray(["hand", "ratchet"])
			prompt = "Crack the drain plug with the ratchet; once it breaks it spins out by hand, and here comes the oil."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"plug_in":
			view(drain_view[0], drain_view[1])
			tools = PackedStringArray(["hand", "ratchet"])
			prompt = "New copper washer on the plug. Fingers till it's snug, then a quarter turn with the ratchet. It's a washer, not a wheel nut."
			hint = "%s pick tool   HOLD %s + drag RIGHT tighten   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"filter_off":
			view(filter_view[0], filter_view[1])
			tools = PackedStringArray(["hand", "filter_wrench"])
			prompt = "The old filter hangs under the boss on the block. Strap wrench to break it; it's full, so tip it into the pan."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"gasket":
			view(rag_at + Vector3(-0.12, 0.3, -0.3), rag_at + Vector3(0, 0.03, 0))
			prompt = "New filter off the rag. A fingertip of clean oil round its rubber gasket, or it'll seep."
			hint = "%s oil the gasket" % RinkOS.key("E")
		"filter_on":
			view(filter_view[0], filter_view[1])
			tools = PackedStringArray(["hand", "filter_wrench"])
			prompt = "Start it by HAND so it can't cross-thread. Up till the gasket touches and your hand stops, then three quarters with the wrench."
			hint = "%s pick tool   HOLD %s + drag RIGHT tighten   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"fill":
			var fill := bay(JobParts.FILLER_AT)
			view(fill + Vector3(-0.1, 0.04, -0.56), fill + Vector3(0.05, -0.09, -0.16))
			prompt = "Cap off, quart bottles from the shelf. Pour, then check the stick. ADD is a quart under FULL."
			hint = "HOLD %s pour   %s pull the dipstick" % [RinkOS.key("LMB"), RinkOS.key("E")]
		"cap":
			var fill2 := bay(JobParts.FILLER_AT)
			view(fill2 + Vector3(-0.1, 0.04, -0.56), fill2 + Vector3(0.05, -0.09, -0.16))
			prompt = "Wipe the stick, push it home. Filler cap on: Gus has found it on the ice before."
			hint = "%s cap on" % RinkOS.key("E")
		"start":
			view(WIDE_EYE, BAY_AT + Vector3(0, 0.3, 0.1))
			prompt = "Start her and watch the oil light. Then look under for drips."
			hint = "%s turn the key" % RinkOS.key("E")


func _work(f: JobInput.Frame, dt: float) -> void:
	_dip_t = maxf(_dip_t - dt, 0.0)
	_pouring = false
	match step_id():
		"note":
			if f.interact_pressed:
				advance()
		"pan":
			if f.interact_pressed:
				_pan_in = true
				advance("Pan under")
		"drain":
			if _phase == "":
				work(old_plug, f)
				if JobScene.cracked(old_plug):
					_phase = "spin_out"
					prompt = "It's loose. Out it comes..."
			elif _phase == "spin_out":
				old_plug.run = maxf(0.0, old_plug.run - dt * 4.0)
				if old_plug.run <= 0.0:
					_phase = "draining"
					_t = 0.0
					prompt = "Let it run. Black as the parking lot, but no glitter in it. Just tired."
			elif _phase == "draining":
				_t += dt
				_pan_oil = clampf(_t / DRAIN_S, 0.0, 1.0) * 0.75
				if _t >= DRAIN_S:
					advance("Drained: black, no metal")
		"plug_in":
			work(plug, f)
			if plug.cross_threaded:
				prompt = "That's crossed. Should have started it with fingers."
			elif plug.stalled:
				prompt = "Snug by hand. A quarter turn with the ratchet. %s" % RinkOS.key("A/D")
			if f.interact_pressed:
				if plug.seated():
					advance("Drain plug, new washer")
				else:
					hint = "Not seated yet."
		"filter_off":
			if _phase == "":
				work(old_filter, f)
				if JobScene.cracked(old_filter):
					_phase = "spin_out"
					prompt = "It breaks loose with a squelch. Spin it off; mind, it's full."
			elif _phase == "spin_out":
				old_filter.run = maxf(0.0, old_filter.run - dt * 3.0)
				if old_filter.run <= 0.0:
					_pan_oil = minf(_pan_oil + 0.1, 1.0)
					advance("Old filter in the pan")
		"gasket":
			if f.interact_pressed:
				gasket_oiled = true
				advance()
		"filter_on":
			work(filter, f)
			if filter.cross_threaded:
				prompt = "It's binding: the wrench went on before the threads caught. It'll seep."
			elif filter.stalled:
				prompt = "Hand tight. Now three quarters with the filter wrench. %s for the wrench." % RinkOS.key("A/D")
			if f.interact_pressed:
				if filter.seated():
					advance("New filter, %+.2f turn past hand tight" % filter.turns_past_hand_tight())
				else:
					hint = "Not seated yet: keep turning it on."
		"fill":
			if f.grab > 0.5 and _dip_t <= 0.0:
				quarts += POUR_QPS * dt
				_pouring = true
			if f.interact_pressed:
				_dip_t = DIP_OUT_S
				var lv := level()
				if lv >= 0.9:
					advance("Dipstick: %s (%.1f qt)" % [_stick_words(lv), quarts])
				elif lv >= 0.5:
					prompt = "Between ADD and FULL. Gus said FULL. A bit more."
				elif quarts > 0.5:
					prompt = "Not up to the ADD mark yet. Keep pouring."
				else:
					prompt = "Dry stick. You've drained her; she wants four quarts."
		"cap":
			if f.interact_pressed:
				advance("Cap on")
		"start":
			if f.interact_pressed:
				start_text = _start_text()
				advance(start_text)
				prompt = start_text + "  " + prompt


func _stick_words(lv: float) -> String:
	if lv > 1.1:
		return "over the FULL line"
	if lv >= 0.9:
		return "FULL"
	if lv >= 0.5:
		return "between ADD and FULL"
	return "under ADD"


func _level_score() -> float:
	var lv := level()
	if lv > 1.1 or lv < 0.5:
		return 0.75
	if lv < 0.9:
		return 0.9
	return 1.0


func _start_text() -> String:
	var fp: Array = plug.grade(skill).flags
	var ff: Array = filter.grade(skill).flags
	if level() > 1.1:
		return "She starts, and a puff of blue out of the stack: that's the extra quart."
	if not fp.is_empty():
		return "She starts, the light goes out. A drip off the drain plug, though: the washer."
	if not ff.is_empty() or not gasket_oiled:
		return "She starts. Oil weeping round the filter. Gus would see that."
	return "She starts, the oil light flickers out in two seconds. Nothing drips."


func _result() -> Dictionary:
	var gp := plug.grade(skill)
	var gf := filter.grade(skill)
	var flags: Array = []
	for g in [gp, gf]:
		for fl in g.flags:
			if not str(fl) in flags:
				flags.append(str(fl))
	if level() > 1.1:
		flags.append("oil_over")
	elif level() < 0.5:
		flags.append("oil_under")
	if not gasket_oiled:
		flags.append("gasket_dry")
	var fl_f: Array = gf.flags
	var fl_p: Array = gp.flags
	var q := float(gp.score) * float(gf.score) * _level_score() * (1.0 if gasket_oiled else 0.9)
	return {
		"quality": q, "oil_level": level(), "quarts": quarts,
		"filter_ok": fl_f.is_empty() and gasket_oiled, "drain_plug_torque_ok": fl_p.is_empty(),
		"flags": flags,
	}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match step_id():
		"drain":
			out.append_array(JobScene.fastener_lines(old_plug))
			if _phase == "draining":
				out.append(meter_line("PAN", _pan_oil, RinkOS.READOUT))
		"plug_in":
			out.append_array(JobScene.fastener_lines(plug))
		"filter_off":
			out.append_array(JobScene.fastener_lines(old_filter))
		"filter_on":
			out.append_array(JobScene.fastener_lines(filter))
		"fill":
			out.append(RinkOS.dots("POURED", "%.1f qt" % quarts, 10))
			if _dip_t > 0.0:
				out.append_array(_stick_lines(level()))
	return out


## The dipstick as a row of text: ADD and FULL marks, the oil up to the level.
static func _stick_lines(lv: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cells := ""
	for i in 12:
		var at := (i + 0.5) / 8.0     # 8 cells to FULL, 4 past it
		var mark := "|" if i == 3 or i == 7 else "="
		cells += "[%s]%s[/color]" % [RinkOS.bb(Color("d29a2c") if lv >= at else RinkOS.DIM), mark]
	out.append("STICK  " + cells)
	out.append("[%s]          ADD  FULL[/color]" % RinkOS.bb(RinkOS.DIM))
	return out


# ---------------------------------------------------------------- visuals

func _build_parts() -> void:
	_pan = part("oil_pan", PAN_STAGE)
	_pan_oil_node = slab(Vector3(0.4, 0.05, 0.28), PAN_STAGE, Color("1a120a"))
	for i in 3:
		_stream.append(slab(Vector3(0.012, 0.012, 1.0), Vector3.ZERO, Color("1e140a")))
	_plug_node = part("drain_plug", bay(JobParts.DRAIN_AT), null, DRAIN_AXIS)
	slab(Vector3(0.07, 0.03, 0.07), bay(JobParts.FILTER_AT) + Vector3(0, 0.015, 0), JobParts.ENGINE.darkened(0.25))  # the filter boss
	_old_filter_node = part("oil_filter_old", bay(JobParts.FILTER_AT))
	_old_filter_node.scale = Vector3.ONE * 0.5
	_filter_node = part("oil_filter", rag_at)
	_filter_node.scale = Vector3.ONE * 0.5
	# the dipstick: a rod in its tube, a yellow ring to pull
	_dip = slab(Vector3(0.006, 0.36, 0.006), Vector3.ZERO, JobParts.OLD_STEEL)
	_dip_grip = slab(Vector3(0.036, 0.022, 0.008), Vector3.ZERO, Color("d8b02e"))
	slab(Vector3(0.014, 0.3, 0.014), bay(JobParts.DIPSTICK_AT) + Vector3(0, 0.15, 0), JobParts.ENGINE.darkened(0.15))  # the tube
	# a quart bottle of 10W-30
	_bottle = slab(Vector3(0.07, 0.17, 0.045), Vector3.ZERO, Color("2b5d9a"))


func _sync(_dt: float) -> void:
	if _plug_node == null:
		return
	var sid := step_id()
	# the pan: on the floor by the bench till it's slid under
	var pan_at := PAN_AT if _pan_in else (rag_at + Vector3(0.0, -0.92, -0.45) if in_place else PAN_STAGE)
	_pan.position = pan_at
	_pan_oil_node.visible = _pan_oil > 0.01
	_pan_oil_node.scale = Vector3(1, maxf(_pan_oil, 0.01), 1)
	_pan_oil_node.position = pan_at + Vector3(0, 0.02 + 0.025 * _pan_oil, 0)
	# the drain plug backs out along -Z; out of sight while the oil runs
	var fp := old_plug if step < 3 else plug
	var drain := bay(JobParts.DRAIN_AT)
	var out := (fp.thread_turns - fp.run) * PITCH * 3.0
	_plug_node.visible = step >= 3 or _phase != "draining"
	_plug_node.transform = Transform3D(DRAIN_AXIS * Basis(Vector3.UP, JobScene.spin(fp)), drain + Vector3(0, 0, -out))
	# the old oil arcs out over the hatch sill into the pan
	var running := sid == "drain" and _phase == "draining" and _t < DRAIN_S * 0.9
	var pts := [drain + Vector3(0, -0.005, -0.03), drain + Vector3(0, -0.03, -0.2), pan_at + Vector3(0, 0.3, 0.12), pan_at + Vector3(0, 0.03, 0.0)]
	for i in 3:
		_stream[i].visible = running
		if running:
			lay(_stream[i], pts[i], pts[i + 1])
	# the filters: the old one on till it's off, then in the pan; the new one
	# on the rag till it's fitted
	var fil := bay(JobParts.FILTER_AT)
	if step < 4 or sid == "filter_off":
		var dn := (old_filter.thread_turns - old_filter.run) * PITCH
		_old_filter_node.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(old_filter)).scaled(Vector3.ONE * 0.5), fil - Vector3(0, dn, 0))
	else:
		_old_filter_node.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0).scaled(Vector3.ONE * 0.5), pan_at + Vector3(-0.08, 0.06, 0.05))
	if step >= 6:
		var dn2 := (filter.thread_turns - filter.run) * PITCH
		_filter_node.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(filter)).scaled(Vector3.ONE * 0.5), fil - Vector3(0, dn2, 0))
	else:
		_filter_node.transform = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * 0.5), rag_at + Vector3(-0.06, 0.012, 0.0))
	# the dipstick, pulled while it's read
	var dip := bay(JobParts.DIPSTICK_AT)
	var pull := 0.24 if _dip_t > 0.0 else 0.0
	_dip.position = dip + Vector3(0, 0.18 + pull, 0)
	_dip_grip.position = dip + Vector3(0, 0.37 + pull, 0)
	# the bottle: on the rag, tipped into the filler while pouring
	var fill := bay(JobParts.FILLER_AT)
	if _pouring:
		_bottle.transform = Transform3D(Basis(Vector3.FORWARD, -2.2), fill + Vector3(-0.07, 0.11, 0.0))
	else:
		_bottle.transform = Transform3D(Basis.IDENTITY, rag_at + Vector3(0.09, 0.09, 0.03))
	# the tool in hand on the part it's working
	_tool_node.visible = false
	var t := tool()
	if t == "ratchet" and sid in ["drain", "plug_in"]:
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet")
		var spinb := Basis(Vector3.UP, -2.45 - fposmod(-JobScene.spin(fp), deg_to_rad(30.0)))
		_tool_node.transform = Transform3D(DRAIN_AXIS * spinb, _plug_node.position + DRAIN_AXIS * Vector3(0, 0.022, 0))
	elif t == "filter_wrench" and sid in ["filter_off", "filter_on"]:
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet")
		var fn := _old_filter_node if sid == "filter_off" else _filter_node
		_tool_node.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, 0.6), fn.position + Vector3(0, -0.08, -0.06))
