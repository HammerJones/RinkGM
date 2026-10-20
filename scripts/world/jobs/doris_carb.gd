extends DorisHatchJob
## Doris's carburettor clean, job `doris_carb`: the jets and the float bowl
## varnished with old gas, so she stumbles off idle and the choke sticks.
## Through her service hatch, in place like the plug change: the carb sits
## on its riser behind the valve cover with the air cleaner on its throat;
## the cleaner and the bowl come off onto the rag on its stand.
##
## Steps and verbs:
##   note        interact: read Gus's note
##   cleaner     grab + turn left by hand: the wing nut off, the cleaner up
##   bowl_off    the bowl's two screws: grab + turn left with the screwdriver
##   jets        move x picks the main jet, the idle jet or the needle seat;
##               hold grab sprays carb cleaner till it runs clear; interact
##   bowl        on the rag: grab + drag scrubs the varnish out; interact
##   gasket      move x picks the NEW cork gasket or the old one; interact
##   bowl_on     each screw by hand, then + 1/4 with the screwdriver (pot
##               metal: snug, not tight); interact per screw
##   cleaner_on  interact: the air cleaner back, the wing nut finger tight
##   choke       grab + drag works the choke plate with a spray on its shaft
##   start       interact: try the key
##
## Result: {quality, jets_clean 0..1, bowl_clean 0..1, gasket_ok,
## choke_freed, flags}.

const JETS := ["MAIN JET", "IDLE JET", "NEEDLE SEAT"]
const SPRAY_PER_S := 0.6
const SCRUB_PER_TURN := 1.5
const CHOKE_WORK := 1.2
const PITCH := 0.002
const JET_AXIS := Basis(Vector3.RIGHT, -PI / 2.0)   # a jet's head toward the viewer (-Z)

var wing: Fastener
var old_screws: Array[Fastener] = []
var screws: Array[Fastener] = []
var screw_idx := 0
var jets := PackedFloat32Array([0.15, 0.2, 0.3])
var bowl_clean := 0.1
var gasket_ok := false
var choke_work := 0.0
var start_text := ""

var _phase := ""

var _carb: MeshInstance3D
var _cleaner: MeshInstance3D
var _bowl: MeshInstance3D
var _bowl_shine: MeshInstance3D
var _jet_nodes: Array[Node3D] = []
var _screw_nodes: Array[MeshInstance3D] = []
var _gasket: MeshInstance3D
var _sel_mark: MeshInstance3D
var _can: MeshInstance3D
var _driver: Node3D


static func bowl_screw() -> Fastener:
	## A little pot-metal screw: fingers till it's snug, then a quarter.
	var f := Fastener.new()
	f.thread_turns = 3.0
	f.hand_start = 1.0
	f.stiffness = 0.3
	f.hand_limit = 1.2
	f.plus_turns = 0.25
	f.turns_tol = 1.0 / 12.0
	return f


static func wing_nut() -> Fastener:
	var f := Fastener.new()
	f.thread_turns = 3.0
	f.hand_start = 3.0
	f.stiffness = 0.2
	f.hand_limit = 3.0
	return f


func _engine_id() -> String:
	return "engine_bay_open"


func _drop_light_at() -> Vector3:
	return Vector3(-0.15, 1.2, -0.32)


func _note_text() -> String:
	return "If she stumbles off idle\nand the choke sticks,\nthe carb's varnished.\nCleaner off, bowl off,\nspray the jets till clear.\nNEW gasket (the cork one).\nBowl screws: snug + a\nquarter. It's pot metal.  - G"


func _setup() -> void:
	title = "Doris // carb clean"
	steps = [
		{"id": "note", "text": "Read Gus's note"},
		{"id": "cleaner", "text": "Air cleaner off"},
		{"id": "bowl_off", "text": "Float bowl off: two screws"},
		{"id": "jets", "text": "Spray the jets clear"},
		{"id": "bowl", "text": "Scrub the bowl"},
		{"id": "gasket", "text": "Bowl gasket"},
		{"id": "bowl_on", "text": "Bowl on: snug + 1/4"},
		{"id": "cleaner_on", "text": "Air cleaner back on"},
		{"id": "choke", "text": "Free the choke"},
		{"id": "start", "text": "Try the start"},
	]
	var w := wing_nut()
	wing = JobScene.installed(w, w.hand_tight_deg())
	old_screws.clear()
	screws.clear()
	for i in 2:
		var s := bowl_screw()
		old_screws.append(JobScene.installed(s, s.hand_tight_deg() + 90.0))
		screws.append(bowl_screw())
	screw_idx = 0
	jets = PackedFloat32Array([0.15, 0.2, 0.3])
	bowl_clean = 0.1
	gasket_ok = false
	choke_work = 0.0
	start_text = ""
	_phase = ""
	_sync(0.0)
	snap_camera()


func carb_at() -> Vector3:
	return bay(JobParts.CARB_AT)


func _enter_step(i: int) -> void:
	_phase = ""
	screw_idx = 0
	var c := carb_at()
	var top_view := [c + Vector3(0.02, 0.17, -0.5), c + Vector3(0, 0.06, 0)]
	var bowl_view := [c + Vector3(0.03, 0.1, -0.33), c + Vector3(0, 0.02, -0.02)]
	var rag_view := [rag_at + Vector3(-0.12, 0.3, -0.3), rag_at + Vector3(0, 0.03, 0)]
	match str(steps[i].id):
		"note":
			note_view()
			prompt = "Gus: \"If she stumbles off idle and the choke sticks, the carb's varnished. Cleaner off, bowl off, spray the jets till they run clear. NEW gasket, the cork one. Bowl screws snug and a quarter: it's pot metal.\""
			hint = "%s read it" % RinkOS.key("E")
		"cleaner":
			view(top_view[0], top_view[1])
			prompt = "The air cleaner sits on the carb's throat behind the valve cover. Wing nut off by hand, lift it clear."
			hint = "HOLD %s + drag LEFT undo the wing nut" % RinkOS.key("LMB")
		"bowl_off":
			view(bowl_view[0], bowl_view[1])
			tools = PackedStringArray(["hand", "screwdriver"])
			prompt = "The float bowl hangs off the front of the carb on two screws. Screwdriver; mind the gas in it."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"jets":
			view(bowl_view[0], bowl_view[1])
			prompt = "Brown varnish in every passage. Spray each one till it runs clear: the main jet, the idle jet, the needle seat."
			hint = "%s pick one   HOLD %s spray   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"bowl":
			view(rag_view[0], rag_view[1])
			prompt = "The bowl on the rag. A ring of varnish round the floor, gas that smells like 1979. Scrub it out."
			hint = "HOLD %s + drag scrub   %s done" % [RinkOS.key("LMB"), RinkOS.key("E")]
		"gasket":
			view(rag_view[0], rag_view[1])
			prompt = "A new cork gasket in the kit, and the old one, only a bit torn."
			hint = "%s pick   %s fit it" % [RinkOS.key("A/D"), RinkOS.key("E")]
		"bowl_on":
			view(bowl_view[0], bowl_view[1])
			tools = PackedStringArray(["hand", "screwdriver"])
			prompt = "Bowl back on. Start each screw with your fingers, snug, then a quarter with the screwdriver. Pot metal strips if you lean on it."
			hint = "%s pick tool   HOLD %s + drag RIGHT tighten   %s next screw" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"cleaner_on":
			view(top_view[0], top_view[1])
			prompt = "Air cleaner back on the throat, the wing nut finger tight."
			hint = "%s cleaner on" % RinkOS.key("E")
		"choke":
			view(top_view[0], top_view[1])
			prompt = "A shot of cleaner on the choke shaft. Work the plate till it snaps shut on its own."
			hint = "HOLD %s + drag work the choke" % RinkOS.key("LMB")
		"start":
			view(WIDE_EYE, BAY_AT + Vector3(0, 0.3, 0.1))
			prompt = "Key in, a touch of choke. Try her."
			hint = "%s turn the key" % RinkOS.key("E")


func _on_pick_x(d: int) -> void:
	match step_id():
		"jets":
			selection = posmod(selection + d, JETS.size())
		"gasket":
			selection = posmod(selection + d, 2)


func _work(f: JobInput.Frame, dt: float) -> void:
	match step_id():
		"note":
			if f.interact_pressed:
				advance()
		"cleaner":
			if _phase == "":
				work(wing, f)
				if JobScene.cracked(wing):
					_phase = "spin_out"
			else:
				wing.run = maxf(0.0, wing.run - dt * 4.0)
				if wing.run <= 0.0:
					advance("Air cleaner off: the element's oily")
		"bowl_off":
			var s := old_screws[screw_idx]
			if _phase == "":
				work(s, f)
				if JobScene.cracked(s):
					_phase = "spin_out"
			else:
				s.run = maxf(0.0, s.run - dt * 5.0)
				if s.run <= 0.0:
					_phase = ""
					screw_idx += 1
					if screw_idx >= old_screws.size():
						screw_idx = old_screws.size() - 1
						advance("Bowl off: varnish, and gas that smells of 1979")
		"jets":
			if f.grab > 0.5:
				jets[selection] = minf(jets[selection] + SPRAY_PER_S * dt, 1.0)
				if jets[selection] >= 1.0:
					prompt = "%s: clear, you can see light through it." % JETS[selection].capitalize()
			if f.interact_pressed:
				advance("Jets %d%% clear" % roundi(_jets_clean() * 100.0))
		"bowl":
			if f.grab > 0.5 and f.turn != 0.0:
				bowl_clean = minf(bowl_clean + absf(f.turn) * SCRUB_PER_TURN, 1.0)
			if f.interact_pressed:
				advance("Bowl %d%% clean" % roundi(bowl_clean * 100.0))
		"gasket":
			if f.interact_pressed:
				gasket_ok = selection == 0
				advance("New cork gasket" if gasket_ok else "The old gasket, again")
		"bowl_on":
			var s2 := screws[screw_idx]
			work(s2, f)
			if s2.cross_threaded:
				prompt = "That's crossed: the screwdriver went in before the threads caught."
			elif s2.stalled:
				prompt = "Snug by hand. A quarter with the screwdriver. %s" % RinkOS.key("A/D")
			if f.interact_pressed:
				if not s2.seated():
					hint = "Not seated yet."
				elif screw_idx + 1 < screws.size():
					screw_idx += 1
				else:
					advance("Bowl screws snug")
		"cleaner_on":
			if f.interact_pressed:
				advance()
		"choke":
			if f.grab > 0.5 and f.turn != 0.0:
				choke_work += absf(f.turn) * 4.0
				if choke_work >= CHOKE_WORK:
					advance("The choke snaps shut on its own")
		"start":
			if f.interact_pressed:
				start_text = _start_text()
				advance(start_text)
				prompt = start_text + "  " + prompt


func _jets_clean() -> float:
	var t := 0.0
	for j in jets:
		t += j
	return t / jets.size()


func _screw_score() -> float:
	var s := 0.0
	for sc in screws:
		s += float(sc.grade(skill).score)
	return s / screws.size()


func _start_text() -> String:
	if _jets_clean() < 0.6:
		return "She starts on the choke, then stumbles off idle. Something's still varnished."
	if not gasket_ok:
		return "She starts, and you can smell gas: the old gasket weeps."
	if _screw_score() < 0.85:
		return "She starts. A bowl screw's not right; Gus will hear about it."
	return "She catches, settles to an even idle and takes the throttle clean. Good girl."


func _result() -> Dictionary:
	var flags: Array = []
	for sc in screws:
		for fl in sc.grade(skill).flags:
			if not str(fl) in flags:
				flags.append(str(fl))
	var j := _jets_clean()
	if j < 0.6:
		flags.append("jets_varnished")
	if not gasket_ok:
		flags.append("old_gasket")
	var q := (0.7 + 0.3 * j) * (0.9 + 0.1 * bowl_clean) * _screw_score() * (1.0 if gasket_ok else 0.85)
	return {
		"quality": clampf(q, 0.0, 1.0), "jets_clean": j, "bowl_clean": bowl_clean,
		"gasket_ok": gasket_ok, "choke_freed": choke_work >= CHOKE_WORK, "flags": flags,
	}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match step_id():
		"cleaner":
			out.append_array(JobScene.fastener_lines(wing))
		"bowl_off":
			out.append(RinkOS.dots("SCREW", "%d / 2" % (screw_idx + 1), 10))
			out.append_array(JobScene.fastener_lines(old_screws[screw_idx]))
		"jets":
			for i in JETS.size():
				var sel := i == selection
				var col := RinkOS.GOOD if jets[i] >= 1.0 else (RinkOS.ACTION if sel else RinkOS.READOUT)
				out.append(("> " if sel else "  ") + meter_line(JETS[i].replace(" ", "_"), jets[i], col))
		"bowl":
			out.append(meter_line("BOWL", bowl_clean, RinkOS.GOOD if bowl_clean >= 0.95 else RinkOS.READOUT))
		"gasket":
			for i in 2:
				var sel := i == selection
				out.append("[%s]%s %s[/color]" % [RinkOS.bb(RinkOS.ACTION if sel else RinkOS.TEXT), ">" if sel else " ", ["NEW CORK GASKET", "THE OLD ONE"][i]])
		"bowl_on":
			out.append(RinkOS.dots("SCREW", "%d / 2" % (screw_idx + 1), 10))
			out.append_array(JobScene.fastener_lines(screws[screw_idx]))
		"choke":
			out.append(meter_line("CHOKE", clampf(choke_work / CHOKE_WORK, 0.0, 1.0), RinkOS.READOUT))
	return out


# ---------------------------------------------------------------- visuals

func _build_parts() -> void:
	var c := carb_at()
	_carb = part("carburettor", c)
	_cleaner = part("air_cleaner", c + Vector3(0, JobParts.CARB_TOP, 0))
	_bowl = part("float_bowl", c + JobParts.CARB_BOWL)
	_bowl_shine = slab(Vector3(0.05, 0.002, 0.03), Vector3.ZERO, Color("c9c6b4"))
	for i in 2:
		var jn := part("carb_jet", c + JobParts.CARB_JETS[i], null, JET_AXIS)
		_jet_nodes.append(jn)
	_jet_nodes.append(slab(Vector3(0.006, 0.006, 0.01), c + Vector3(0.0, 0.018, -0.026), JobParts.BRASS.darkened(0.2)))  # the needle seat
	for i in 2:
		_screw_nodes.append(slab(Vector3(0.009, 0.009, 0.004), Vector3.ZERO, JobParts.OLD_STEEL))
	_gasket = slab(Vector3(0.062, 0.002, 0.042), Vector3.ZERO, Color("b0844e"))
	_sel_mark = slab(Vector3(0.008, 0.008, 0.008), Vector3.ZERO, RinkOS.ACTION, 2.0)
	_can = slab(Vector3(0.065, 0.2, 0.065), Vector3.ZERO, Color("c23a2a"))   # the carb cleaner
	_driver = Node3D.new()
	add_child(_driver)
	slab(Vector3(0.004, 0.004, 0.09), Vector3(0, 0, -0.045), JobParts.CHROME, 0.0, _driver)
	slab(Vector3(0.018, 0.018, 0.08), Vector3(0, 0, -0.13), JobParts.RED_GRIP, 0.0, _driver)


func _sync(_dt: float) -> void:
	if _carb == null:
		return
	var sid := step_id()
	var c := carb_at()
	# the air cleaner: rising off the stud with the wing nut, on the stand
	# while it's off
	if step >= 2 and step <= 6:
		_cleaner.position = rag_at + Vector3(0.14, -0.005, 0.12)
	else:
		_cleaner.position = c + Vector3(0, JobParts.CARB_TOP + (wing.thread_turns - wing.run) * PITCH, 0)
	# the bowl: on the carb, on the rag for its scrub, back on
	var bowl_on_carb := step <= 2 or step >= 6
	var bowl_pos := c + JobParts.CARB_BOWL
	if not bowl_on_carb:
		bowl_pos = rag_at + Vector3(-0.04, 0.006, 0.03)
	elif sid == "bowl_off":
		bowl_pos += Vector3(0, 0, -(old_screws[0].thread_turns - old_screws[0].run) * PITCH)
	_bowl.position = bowl_pos
	_bowl_shine.visible = bowl_clean > 0.15
	_bowl_shine.scale = Vector3(maxf(bowl_clean, 0.01), 1, 1)
	_bowl_shine.position = bowl_pos + Vector3(-0.025 + 0.025 * bowl_clean, 0.011, -0.02)
	# the screws: in the bowl's ears, backing out toward the viewer; on the
	# rag while the bowl's off
	for i in 2:
		var fs := screws[i] if step >= 6 else old_screws[i]
		var at: Vector3 = c + JobParts.CARB_SCREWS[i]
		if bowl_on_carb:
			_screw_nodes[i].position = at + Vector3(0, 0, -(fs.thread_turns - fs.run) * PITCH)
			_screw_nodes[i].rotation = Vector3(0, 0, JobScene.spin(fs))
		else:
			_screw_nodes[i].position = rag_at + Vector3(0.05 + i * 0.03, 0.007, -0.05)
			_screw_nodes[i].rotation = Vector3.ZERO
	# the gasket: in the kit on the rag (new) until it's fitted under the bowl
	_gasket.visible = sid == "gasket"
	_gasket.position = rag_at + Vector3(0.06 if selection == 0 else -0.08, 0.007, -0.06)
	# the pick, and the can in the hand while spraying
	_sel_mark.visible = sid == "jets"
	_sel_mark.position = (_jet_nodes[selection].position if sid == "jets" else c) + Vector3(0, 0.0, -0.03)
	var spraying := sid in ["jets", "choke"]
	_can.position = (c + Vector3(0.09, 0.03, -0.12)) if spraying else (rag_at + Vector3(-0.1, 0.105, -0.06))
	# the screwdriver on the screw it's turning
	_driver.visible = tool() == "screwdriver" and sid in ["bowl_off", "bowl_on"]
	if _driver.visible:
		var sn := _screw_nodes[mini(screw_idx, 1)]
		_driver.transform = Transform3D(Basis(Vector3.FORWARD, sn.rotation.z), sn.position)
