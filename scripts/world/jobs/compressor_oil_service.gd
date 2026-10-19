extends JobScene
## Compressor oil and filter service (docs/world/RINK_SIM.md 4.2), job
## `compressor_oil_change`. First person in front of a Nordale RC-4 in the
## plant room, built as its own small room so it works without the venue.
##
## Steps and verbs:
##   read      interact: the sight glass, the before reading
##   drain     grab + turn left with the ratchet cracks the drain plug; it
##             spins out and the oil drains into the pan
##   filter    grab + turn left with the filter wrench: the old one off
##   gasket    interact: a fingertip of clean oil on the new gasket
##   fit       start it by HAND (a wrench in the first turns cross-threads
##             it), hand tight, then + 3/4 with the filter wrench; interact
##   plug      the drain plug with a new washer: hand, then ratchet + 1/4
##   fill      grab + pump the hand pump to HALF the sight glass; interact
##   log       interact: the after reading in the log book
##
## Result: {quality, compressor 0|1, oil_level 0..1 of the glass (0.5 is the
## mark), filter_ok, drain_plug_torque_ok, flags, before_level}.

const SUMP_L := 30.0          # oil to the half mark
const STROKE_L := 2.0         # the drum pump's big barrel: 15 strokes to half
const PITCH := 0.004          # metres a turn backs a fastener out (drawn a bit long)
const DRAIN_S := 3.0

var compressor := 0
var before_level := 0.25
var old_plug: Fastener
var old_filter: Fastener
var plug: Fastener            # the refitted drain plug, graded
var filter: Fastener          # the new filter, graded
var pump: HandPump
var gasket_oiled := false

var _phase := ""              # within a step: "", "spin_out", "draining"
var _t := 0.0
var _pan_oil := 0.0           # 0..1 of the pan
var _handle := 1.0

var _plug_node: MeshInstance3D
var _filter_node: MeshInstance3D
var _old_filter_node: MeshInstance3D
var _oil_col: MeshInstance3D
var _oil_mat: StandardMaterial3D
var _pan_oil_node: MeshInstance3D
var _stream: MeshInstance3D
var _handle_node: MeshInstance3D
var _tool_node: MeshInstance3D
var _comp_node: MeshInstance3D
var _chalk: Label3D
var _chalk2: Label3D
var _plate: Label3D

const DRAIN_AXIS := Basis(Vector3.RIGHT, -PI / 2.0)   # the plug's +Y points out of the crankcase (-Z)
const PAN_AT := Vector3(-0.62, 0.0, -0.68)
const DRUM_AT := Vector3(-1.78, 0.0, -0.62)
const BOOK_AT := Vector3(-2.55, 0.62, -0.75)


static func drain_plug() -> Fastener:
	## A gasket plug: hand tight + 1/4 (RINK_SIM 4.2 step 11, Controls' spec).
	var f := Fastener.new()
	f.thread_turns = 3.0
	f.hand_start = 1.0
	f.stiffness = 0.5
	f.hand_limit = 3.0
	f.target_torque = 0.0
	f.plus_turns = 0.25
	f.turns_tol = 1.0 / 12.0
	return f


func _setup() -> void:
	title = "Compressor %d // oil + filter" % (compressor + 1)
	steps = [
		{"id": "read", "text": "Read the sight glass"},
		{"id": "drain", "text": "Drain the old oil"},
		{"id": "filter_off", "text": "Spin off the old filter"},
		{"id": "gasket", "text": "Oil the new gasket"},
		{"id": "filter_on", "text": "New filter: hand tight + 3/4"},
		{"id": "plug_in", "text": "Drain plug: hand tight + 1/4"},
		{"id": "fill", "text": "Pump to HALF the glass"},
		{"id": "log", "text": "Log it"},
	]
	compressor = 1 if target.contains("2") else 0
	title = "Compressor %d // oil + filter" % (compressor + 1)
	before_level = 0.22 if compressor == 0 else 0.42
	var plant: Variant = sim.get("plant") if sim else null
	if plant is Object:
		var comps: Array = plant.get("compressors")
		if compressor < comps.size():
			var c: Variant = comps[compressor]
			var lv: Variant = c.get("oil_level")
			if lv != null:
				before_level = clampf(float(lv), 0.0, 1.0)
	_chalk.text = "No. 1 (DRINKS)" if compressor == 0 else "No. 2 (FINE)"
	_chalk2.text = "No. 2 (FINE)" if compressor == 0 else "No. 1 (DRINKS)"
	_plate.text = "NORDALE REFRIGERATION MACHINERY CO.\nMODEL RC-4  SERIAL 7403-11%d" % (8 + compressor)
	var dp := drain_plug()
	old_plug = JobScene.installed(dp, dp.hand_tight_deg() + 90.0)
	var of := Fastener.oil_filter()
	old_filter = JobScene.installed(of, of.hand_tight_deg() + 270.0)
	plug = drain_plug()
	filter = Fastener.oil_filter()
	pump = HandPump.new(0.0, SUMP_L)
	pump.stroke_l = STROKE_L
	gasket_oiled = false
	_phase = ""
	_pan_oil = 0.0
	log_lines.clear()
	_sync(0.0)
	snap_camera()


func _enter_step(i: int) -> void:
	_phase = ""
	_t = 0.0
	var drain_view := [Vector3(-0.3, 0.52, -1.0), JobParts.COMP_DRAIN + Vector3(0, 0.02, -0.12)]
	var filter_view := [Vector3(-0.72, 0.78, -1.08), JobParts.COMP_FILTER + Vector3(0, -0.17, 0)]
	match str(steps[i].id):
		"read":
			view(Vector3(-0.22, 0.5, -0.86), JobParts.COMP_GLASS)
			prompt = "Gus: \"Every morning. Oil first. Number 1 drinks.\" Look at the oil glass on Number %d before you touch anything." % (compressor + 1)
			hint = "%s read the glass" % RinkOS.key("E")
		"drain":
			view(drain_view[0], drain_view[1])
			tools = PackedStringArray(["hand", "ratchet"])
			prompt = "The pan's under the drain plug. Crack it with the ratchet; once it breaks loose it spins out by hand."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"filter_off":
			view(filter_view[0], filter_view[1])
			tools = PackedStringArray(["hand", "filter_wrench"])
			prompt = "Old filter off. It's on tighter than fingers; the strap wrench breaks it, then it unscrews into the pan."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"gasket":
			view(filter_view[0], filter_view[1])
			prompt = "New Nordale RC-4 out of the box. A fingertip of clean oil round the rubber gasket, or it seeps."
			hint = "%s oil the gasket" % RinkOS.key("E")
		"filter_on":
			view(filter_view[0], filter_view[1])
			tools = PackedStringArray(["hand", "filter_wrench"])
			prompt = "Start it by HAND so it can't cross-thread. Spin it up till the gasket touches and your hand stops: hand tight. Then three quarters more with the wrench."
			hint = "%s pick tool   HOLD %s + drag RIGHT tighten   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"plug_in":
			view(drain_view[0], drain_view[1])
			tools = PackedStringArray(["hand", "ratchet"])
			prompt = "Drain plug back in with a new copper washer. By hand till it's snug, then a quarter turn with the ratchet. No more: it's a washer, not a wheel nut."
			hint = "%s pick tool   HOLD %s + drag RIGHT tighten   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"fill":
			view(Vector3(-0.55, 1.5, -2.05), Vector3(-1.1, 0.48, -0.45))
			prompt = "Gus: \"Oil's in the blue drum. Hand pump. HALF the glass, not full.\" The glass stays empty till you're close, so slow down when it shows."
			hint = "HOLD %s + drag UP/DOWN pump   %s done" % [RinkOS.key("LMB"), RinkOS.key("E")]
		"log":
			view(Vector3(-1.9, 1.35, -1.5), BOOK_AT)
			prompt = "Gus: \"Write it in the log WITH THE PENCIL ON THE STRING.\" Glass, hours, filter."
			hint = "%s log it" % RinkOS.key("E")


func _work(f: JobInput.Frame, dt: float) -> void:
	match step_id():
		"read":
			if f.interact_pressed:
				advance("BEFORE: glass %s, %s" % [_glass_words(before_level), "dark" if compressor == 0 else "amber-brown"])
		"drain":
			if _phase == "":
				work(old_plug, f)
				if JobScene.cracked(old_plug):
					_phase = "spin_out"
					prompt = "It's loose. Out it comes, and here comes the oil..."
			elif _phase == "spin_out":
				old_plug.run = maxf(0.0, old_plug.run - dt * 4.0)
				if old_plug.run <= 0.0:
					_phase = "draining"
					_t = 0.0
					prompt = "Let it drain. Look at it: dark, but no glitter and no milk. That's just tired oil."
			elif _phase == "draining":
				_t += dt
				_pan_oil = clampf(_t / DRAIN_S, 0.0, 1.0) * 0.8
				if _t >= DRAIN_S:
					advance("Drained: dark, no metal, no water")
		"filter_off":
			if _phase == "":
				work(old_filter, f)
				if JobScene.cracked(old_filter):
					_phase = "spin_out"
					prompt = "It breaks loose with a squelch. Spin it off; it's full, mind."
			elif _phase == "spin_out":
				old_filter.run = maxf(0.0, old_filter.run - dt * 3.0)
				if old_filter.run <= 0.0:
					_pan_oil = minf(_pan_oil + 0.15, 1.0)
					advance()
		"gasket":
			if f.interact_pressed:
				gasket_oiled = true
				advance()
		"filter_on":
			work(filter, f)
			if filter.cross_threaded:
				prompt = "It's binding. That's crossed: the wrench went on before the threads caught. It'll go on, but it'll seep."
			elif filter.stalled:
				prompt = "Hand tight. Now three quarters with the filter wrench. %s for the wrench." % RinkOS.key("A/D")
			if f.interact_pressed:
				if filter.seated():
					advance("New filter, %+.2f turn past hand tight" % filter.turns_past_hand_tight())
				else:
					hint = "Not seated yet: keep turning it on."
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
		"fill":
			if f.grab > 0.5:
				pump.stroke(f.pump, dt)
				_handle = f.pump
			var lv := pump.level()
			if lv > 0.9:
				prompt = "That's past half. Full is for people who like cleaning chillers."
			elif lv > 0.0 and lv < 0.4:
				prompt = "There it is in the glass. Little strokes now."
			if f.interact_pressed:
				advance("AFTER: glass %s, clear" % _glass_words(lv))
		"log":
			if f.interact_pressed:
				advance("Logged")


func _glass_words(lv: float) -> String:
	if lv <= 0.02:
		return "EMPTY"
	if lv >= 0.98:
		return "FULL"
	return "%d%%" % roundi(lv * 100.0)


func _result() -> Dictionary:
	var gp := plug.grade(skill)
	var gf := filter.grade(skill)
	var go := pump.grade(skill)
	var flags: Array = []
	for g in [gp, gf, go]:
		for fl in g.flags:
			if not str(fl) in flags:
				flags.append(str(fl))
	var q := float(gp.score) * float(gf.score) * float(go.score)
	var fl_f: Array = gf.flags
	var fl_p: Array = gp.flags
	return {
		"quality": q, "compressor": compressor, "oil_level": pump.level(),
		"filter_ok": fl_f.is_empty() and gasket_oiled, "drain_plug_torque_ok": fl_p.is_empty(),
		"flags": flags, "before_level": before_level,
	}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match step_id():
		"read", "log":
			out.append_array(_glass_lines(before_level if step_id() == "read" else pump.level()))
		"drain":
			out.append_array(JobScene.fastener_lines(old_plug))
			if _phase == "draining":
				out.append(meter_line("PAN", _pan_oil, RinkOS.READOUT))
		"filter_off":
			out.append_array(JobScene.fastener_lines(old_filter))
		"filter_on":
			out.append_array(JobScene.fastener_lines(filter))
		"plug_in":
			out.append_array(JobScene.fastener_lines(plug))
		"fill":
			out.append(meter_line("HANDLE", _handle, RinkOS.ACTION))
			out.append(RinkOS.dots("SUMP", "%.1f L" % pump.litres, 10))
			if pump.slipping:
				out.append("[%s]// SUCKING AIR. SLOWER[/color]" % RinkOS.bb(RinkOS.ALERT))
			out.append_array(_glass_lines(pump.level()))
	return out


## The sight glass as a column of text, the HALF mark in the middle.
static func _glass_lines(lv: float) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(RinkOS.dots("OIL_GLASS", "%d%%" % roundi(clampf(lv, 0.0, 1.0) * 100.0), 10))
	var rows := 7
	for r in rows:
		var top := 1.0 - float(r) / rows
		var filled := lv >= top - 0.5 / rows
		var cell := "[%s]######[/color]" % RinkOS.bb(Color("d29a2c")) if filled else "[%s]......[/color]" % RinkOS.bb(RinkOS.DIM)
		var mark := ""
		if r == rows / 2:
			mark = "[%s] < HALF[/color]" % RinkOS.bb(RinkOS.ALERT)
		elif r == 0:
			mark = "[%s]   FULL[/color]" % RinkOS.bb(RinkOS.DIM)
		elif r == rows - 1:
			mark = "[%s]   EMPTY[/color]" % RinkOS.bb(RinkOS.DIM)
		out.append("   |%s|%s" % [cell, mark])
	return out


# ---------------------------------------------------------------- visuals

func _sync(_dt: float) -> void:
	if _plug_node == null:
		return
	var sid := step_id()
	# the drain plug: the old one until it's out, then the new one from plug_in
	var fp := old_plug if step < 5 else plug
	var plug_in := sid in ["plug_in", "fill", "log", "done"]
	_plug_node.visible = plug_in or (step <= 1 and _phase != "draining")
	var out := (fp.thread_turns - fp.run) * PITCH * 3.0
	_plug_node.transform = Transform3D(DRAIN_AXIS * Basis(Vector3.UP, JobScene.spin(fp)), JobParts.COMP_DRAIN + Vector3(0, 0, -out))
	_stream.visible = sid == "drain" and _phase == "draining" and _t < DRAIN_S * 0.9
	# the filter: old one on until it's off, then the new one beside the
	# compressor until it's fitted
	var on_old := step < 2 or (sid == "filter_off")
	_old_filter_node.visible = true
	if on_old:
		var dn := (old_filter.thread_turns - old_filter.run) * PITCH * 2.0
		_old_filter_node.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(old_filter)), JobParts.COMP_FILTER - Vector3(0, dn, 0))
	else:
		_old_filter_node.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), PAN_AT + Vector3(-0.08, 0.1, 0.05))
	var fitted := step >= 4
	if fitted:
		var dn2 := (filter.thread_turns - filter.run) * PITCH * 2.0
		_filter_node.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(filter)), JobParts.COMP_FILTER - Vector3(0, dn2, 0))
	else:
		_filter_node.transform = Transform3D(Basis.IDENTITY, Vector3(-1.32, 0.34, -0.8))
	_filter_node.visible = step >= 3
	# the oil in the glass, the pan and the pump handle
	var lv := before_level if step <= 1 else (0.0 if step < 6 else pump.level())
	if step == 1 and _phase == "draining":
		lv = before_level * (1.0 - clampf(_t / DRAIN_S * 2.0, 0.0, 1.0))
	var h := clampf(lv, 0.0, 1.0) * 0.072
	_oil_col.visible = h > 0.001
	_oil_col.scale = Vector3(1, maxf(h, 0.001) / 0.072, 1)
	_oil_col.position = JobParts.COMP_GLASS + Vector3(0, -0.036 + h * 0.5, 0.006)
	_oil_mat.albedo_color = Color("4a2a12") if step <= 1 else Color("d8a032")
	_oil_mat.emission = _oil_mat.albedo_color
	_pan_oil_node.visible = _pan_oil > 0.01
	_pan_oil_node.scale = Vector3(1, maxf(_pan_oil, 0.01), 1)
	_pan_oil_node.position = PAN_AT + Vector3(0, 0.02 + 0.025 * _pan_oil, 0)
	_handle_node.rotation = Vector3(0, 0, deg_to_rad(lerpf(-28.0, 22.0, _handle)))
	# the tool in hand, on the part it's working
	_tool_node.visible = false
	var t := tool()
	if t != "hand" and sid in ["drain", "plug_in"]:
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet")
		var spinb := Basis(Vector3.UP, -2.7 + 0.25 * sin(JobScene.spin(fp)))
		_tool_node.transform = Transform3D(DRAIN_AXIS * spinb, _plug_node.position + DRAIN_AXIS * Vector3(0, 0.022, 0))
	elif t == "filter_wrench" and sid in ["filter_off", "filter_on"]:
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet")
		var fn := _old_filter_node if sid == "filter_off" else _filter_node
		_tool_node.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, 0.6), fn.position + Vector3(0, -0.12, -0.1))


# ---------------------------------------------------------------- the room

func _build() -> void:
	environment(Color("15171a"), 0.42)
	var concrete := Color("6f6a60")
	slab(Vector3(7.0, 0.2, 5.0), Vector3(-0.5, -0.1, 0.6), concrete)
	slab(Vector3(7.0, 3.2, 0.2), Vector3(-0.5, 1.6, 2.1), Wear.OLD_CREAM.darkened(0.15))
	slab(Vector3(7.0, 1.2, 0.21), Vector3(-0.5, 0.6, 2.09), Wear.OLD_MINT.darkened(0.2))
	slab(Vector3(0.2, 3.2, 5.0), Vector3(-3.0, 1.6, 0.6), Wear.OLD_CREAM.darkened(0.2))
	slab(Vector3(0.21, 1.2, 5.0), Vector3(-2.99, 0.6, 0.6), Wear.OLD_MINT.darkened(0.25))
	slab(Vector3(2.9, 0.012, 0.06), Vector3(0, 0.006, -0.85), Wear.OLD_GOLD.darkened(0.2))  # the safety line
	slab(Vector3(0.7, 0.008, 0.45), Vector3(-0.4, 0.004, -0.6), Color("2a241d"))           # years of oil
	# the compressor being serviced, opened up, and its neighbour
	_comp_node = MeshInstance3D.new()
	_comp_node.mesh = JobParts.compressor_service(Wear.WORN)
	add_child(_comp_node)
	prop("compressor_recip", Vector3(3.3, 0, 0.0))
	# chalk on the belt guards (DECOR: the plant room)
	_chalk = note("", Vector3(0.1, 0.42, -0.236), 0.0, 0.0018, Color("e8e6dc"))
	_chalk2 = note("", Vector3(3.4, 0.42, -0.236), 0.0, 0.0018, Color("e8e6dc"))
	_plate = note("", Vector3(0.6, 0.48, -0.36), 0.0, 0.0008, Color("3a2a10"), Color("c6a24a"), 0.15, 0.03)
	# the door of notes on the right wall, behind the drum
	var door := prop("door", Vector3(-2.88, 0, -0.1), 90.0)
	door.name = "DoorOfNotes"
	var notes := [
		["Every morning.\nOil first.\nNumber 1 drinks.", Vector3(0, 1.5, 0), 0.2],
		["Oil's in the blue drum.\nHand pump. HALF the glass,\nnot full.", Vector3(0.05, 1.28, 0.18), 0.24],
		["If the glass is empty\nyou are already late.", Vector3(-0.02, 1.08, -0.12), 0.2],
		["BREAKER 14\nSTAYS ON", Vector3(0.0, 1.72, -0.2), 0.12],
	]
	for n in notes:
		var off: Vector3 = n[1]
		var w: float = n[2]
		note(str(n[0]), Vector3(-2.86, 0, -0.1) + Vector3(0.0, off.y, off.z), 90.0, 0.0011, Color("1b2a4a"), Color("f3e7a2"), w, 0.11)
	# the oil pan, the drum with its pump and hose, the log book on a crate
	part("oil_pan", PAN_AT)
	_pan_oil_node = slab(Vector3(0.4, 0.05, 0.28), PAN_AT, Color("24160c"))
	_stream = slab(Vector3(0.012, 0.12, 0.012), JobParts.COMP_DRAIN + Vector3(0, -0.07, -0.08), Color("2a180a"))
	part("oil_drum", DRUM_AT)
	var pump_at := DRUM_AT + JobParts.DRUM_BUNG
	var pump_node := part("hand_pump", pump_at)
	_handle_node = part("pump_handle", JobParts.PUMP_HINGE, pump_node)
	var spout := pump_at + JobParts.PUMP_SPOUT
	var fill := Vector3(-0.95, 0.74, -0.15)
	_hose(spout, spout + Vector3(0.0, -0.3, -0.05), spout + Vector3(0.45, -0.12, 0.0), fill)
	slab(Vector3(0.45, 0.6, 0.35), BOOK_AT - Vector3(0, 0.32, 0), Wear.OLD_WOOD)
	part("log_book", BOOK_AT + Vector3(0, 0.002, 0))
	note("PLANT LOG", BOOK_AT + Vector3(0.0, 0.035, 0.02), 0.0, 0.001, Color("f1eee4"))
	# the parts that come and go
	_plug_node = part("drain_plug", JobParts.COMP_DRAIN, null, DRAIN_AXIS)
	_old_filter_node = part("oil_filter_old", JobParts.COMP_FILTER)
	_filter_node = part("oil_filter", Vector3(-1.32, 0.34, -0.8))
	part("sight_glass", JobParts.COMP_GLASS)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.072, 0.004)
	_oil_mat = StandardMaterial3D.new()
	_oil_mat.albedo_color = Color("4a2a12")
	_oil_mat.emission_enabled = true
	_oil_mat.emission_energy_multiplier = 0.35
	bm.material = _oil_mat
	_oil_col = MeshInstance3D.new()
	_oil_col.mesh = bm
	add_child(_oil_col)
	_tool_node = MeshInstance3D.new()
	add_child(_tool_node)
	# lights: two old fluorescents, the work light on the floor
	for p in [Vector3(-0.8, 3.0, -0.4), Vector3(2.2, 3.0, 0.2)]:
		slab(Vector3(1.2, 0.06, 0.12), p, Color(0.85, 0.95, 1.0), 3.0)
		light(p - Vector3(0, 0.3, 0), 0.9, 7.0, Color(0.86, 0.95, 1.0), p.x < 0.0)
	light(Vector3(-0.5, 0.55, -1.25), 0.9, 2.6, Color(1.0, 0.86, 0.62))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 160.0, 0.0)
	key.light_energy = 0.25
	add_child(key)


## A rubber hose through the given points, as short boxes.
func _hose(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var pts := [a, b, c, d]
	for i in 3:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var segs := 6
		for s in segs:
			var u0 := p0.lerp(p1, float(s) / segs)
			var u1 := p0.lerp(p1, float(s + 1) / segs)
			var mid := (u0 + u1) * 0.5
			var len := u0.distance_to(u1) + 0.01
			var seg := slab(Vector3(0.022, 0.022, len), mid, Color("17181b"))
			if len > 0.011:
				seg.look_at_from_position(mid, u1, Vector3.UP if absf((u1 - u0).normalized().y) < 0.95 else Vector3.RIGHT)
