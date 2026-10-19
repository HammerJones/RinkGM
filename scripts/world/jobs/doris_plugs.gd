extends JobScene
## Doris won't start: the plug change, the tutorial slice of the engine
## tune-up (docs/world/RINK_SIM.md 4.8), job `doris_plugs`. A raised view
## into her engine bay with the DORIS parts cabinet beside it and Gus's note
## on the dash.
##
## Steps and verbs:
##   note     interact: read Gus's note
##   find     move x picks a plug lead, interact pulls it (Number 3)
##   out      grab + turn left with the plug socket on the ratchet
##   drawer   move y picks a drawer, interact opens it (second from the top)
##   gap      grab + turn sets the new plug's gap to 0.035 in
##   thread   start it by HAND (a wrench in the first two turns cross-threads
##            the old head), to hand tight
##   torque   the torque wrench to the click at 15 ft-lb, let go
##   lead     interact: the lead back on, till it clicks
##   morning  interact: say good morning (Gus means it)
##   start    interact: try the key
##
## Result: {quality, cross_threaded, torque_ok, gap_in, plug: 3, flags}.

const PLUG := 2                # index of Number 3
const GAP_TARGET := 0.035
const GAP_TOL := 0.003
const GAP_PER_TURN := 0.010
const PITCH := 0.003
const DRAWERS := ["DORIS", "DORIS", "DORIS", "DORIS (MISC)", "DORIS", "DORIS (DON'T)"]
const DRAWER_SAYS := [
	"Fan belts, a fuel filter and a mitten. Not plugs.",
	"",
	"Fuses, and the 1987 home opener program. Not plugs.",
	"String, three keys to nothing, a photo of Doris in 1979. Not plugs.",
	"Towel clips. Hundreds. Not plugs.",
	"The old points and condenser. Gus kept them. Don't.",
]

var old_plug: Fastener
var plug: Fastener
var wrench: TorqueWrench
var gap := 0.028
var start_text := ""
var _lead_off := false
var _pop := 0.0
var _drawer_open := -1

var _plugs: Array[MeshInstance3D] = []
var _boots: Array[MeshInstance3D] = []
var _new_plug: MeshInstance3D
var _tray: MeshInstance3D
var _gauge: MeshInstance3D
var _tool_node: MeshInstance3D
var _sel_mark: MeshInstance3D

const BAY_AT := Vector3(0.0, 0.5, 0.0)
const CAB_AT := Vector3(-1.05, 0.0, 0.15)
const CAB_YAW := 28.0
const RAG_AT := Vector3(0.66, 0.92, -0.32)


func _setup() -> void:
	title = "Doris // won't start"
	steps = [
		{"id": "note", "text": "Read Gus's note on the dash"},
		{"id": "find", "text": "Find Number 3, pull the lead"},
		{"id": "out", "text": "Take the plug out"},
		{"id": "drawer", "text": "New plug from the DORIS drawer"},
		{"id": "gap", "text": "Gap it: 0.035 in"},
		{"id": "thread", "text": "Thread it in by hand"},
		{"id": "torque", "text": "Torque 15 ft-lb"},
		{"id": "lead", "text": "Lead back on"},
		{"id": "morning", "text": "Say good morning"},
		{"id": "start", "text": "Try the start"},
	]
	var op := Fastener.spark_plug()
	old_plug = JobScene.installed(op, 15.0 / op.stiffness)
	plug = Fastener.spark_plug()
	wrench = TorqueWrench.new(plug)
	gap = 0.028
	start_text = ""
	_lead_off = false
	_drawer_open = -1
	_sync(0.0)
	snap_camera()


func _well(i: int) -> Vector3:
	var p: Vector3 = JobParts.PLUG_WELLS[i]
	return BAY_AT + p


func _enter_step(i: int) -> void:
	_pop = 0.0
	var bay_view := [Vector3(0.05, 1.62, -1.1), BAY_AT + Vector3(0, 0.36, 0)]
	var well_view := [_well(PLUG) + Vector3(0.1, 0.34, -0.38), _well(PLUG) + Vector3(0, -0.02, 0.02)]
	match str(steps[i].id):
		"note":
			view(Vector3(0.55, 1.3, -0.65), Vector3(0.82, 0.95, 0.0))
			prompt = "Gus: \"She won't start cold if Number 3 plug is fouled. Plugs are in the DORIS drawer, second from the top. Hand tight then a quarter. Do NOT cross-thread her, she remembers. Say good morning first. I mean it.\""
			hint = "%s read it" % RinkOS.key("E")
		"find":
			view(bay_view[0], bay_view[1])
			prompt = "Number 1 is at the fan end, on the left. Count along to Number 3 and pull its lead."
			hint = "%s pick a lead   %s pull it" % [RinkOS.key("A/D"), RinkOS.key("E")]
		"out":
			view(well_view[0], well_view[1])
			tools = PackedStringArray(["hand", "ratchet"])
			prompt = "Plug socket on the ratchet. Break it loose; it spins out by hand from there."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"drawer":
			selection_y = 0
			view(CAB_AT + Vector3(0.45, 1.4, -0.95), CAB_AT + Vector3(0, 0.8, 0))
			prompt = "Black and wet: fouled, like Gus said. New one from the DORIS drawer, second from the top."
			hint = "%s pick a drawer   %s open it" % [RinkOS.key("W/S"), RinkOS.key("E")]
		"gap":
			view(RAG_AT + Vector3(-0.12, 0.3, -0.3), RAG_AT + Vector3(0, 0.03, 0))
			prompt = "Out of the box they're never right. Gap it to 0.035 with the gauge: open it up a hair at a time."
			hint = "HOLD %s + drag RIGHT open / LEFT close   %s done" % [RinkOS.key("LMB"), RinkOS.key("E")]
		"thread":
			view(well_view[0], well_view[1])
			tools = PackedStringArray(["hand", "torque_wrench"])
			prompt = "Start it with your FINGERS. Old aluminium head: if it binds, back it out and start again. Spin it down to hand tight."
			hint = "%s pick tool   HOLD %s + drag RIGHT thread it" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"torque":
			view(well_view[0], well_view[1])
			tools = PackedStringArray(["torque_wrench"])
			prompt = "Gus's quarter turn is about 15 on the wrench. Pull to the click and let go."
			hint = "HOLD %s + drag RIGHT pull   release after the click" % RinkOS.key("LMB")
		"lead":
			view(well_view[0], well_view[1])
			prompt = "Push the boot back on till it clicks."
			hint = "%s lead on" % RinkOS.key("E")
		"morning":
			view(Vector3(0.0, 1.35, -1.25), BAY_AT + Vector3(0, 0.35, 0.2))
			prompt = "Gus said to. He meant it."
			hint = "%s \"Good morning, Doris.\"" % RinkOS.key("E")
		"start":
			view(Vector3(0.0, 1.35, -1.25), BAY_AT + Vector3(0, 0.35, 0.2))
			prompt = "Key in, a touch of choke. Try her."
			hint = "%s turn the key" % RinkOS.key("E")


func _on_pick_x(d: int) -> void:
	if step_id() == "find":
		selection = posmod(selection + d, 4)


func _on_pick_y(d: int) -> void:
	if step_id() == "drawer":
		selection_y = clampi(selection_y - d, 0, DRAWERS.size() - 1)  # up the screen is up the cabinet


func _work(f: JobInput.Frame, dt: float) -> void:
	match step_id():
		"note":
			if f.interact_pressed:
				advance()
		"find":
			if f.interact_pressed:
				if selection == PLUG:
					_lead_off = true
					advance("Number 3 lead off")
				else:
					prompt = "That's Number %d. Number 1's at the fan end, on the left; count along." % (selection + 1)
		"out":
			if _pop > 0.0:
				_pop += dt
				old_plug.run = maxf(0.0, old_plug.run - dt * 14.0)
				if old_plug.run <= 0.0:
					advance("Number 3: black and wet")
				return
			work(old_plug, f)
			if JobScene.cracked(old_plug):
				_pop = 0.001
		"drawer":
			if f.interact_pressed:
				_drawer_open = selection_y
				if selection_y == 1:
					advance("New plug from the drawer")
				else:
					prompt = str(DRAWER_SAYS[selection_y])
		"gap":
			if f.grab > 0.5 and f.turn != 0.0:
				gap = clampf(gap + f.turn * GAP_PER_TURN, 0.015, 0.06)
			if f.interact_pressed:
				advance("Gapped %.3f in" % gap)
		"thread":
			work(plug, f, wrench)
			if plug.cross_threaded:
				prompt = "It's binding. That's crossed. She'll remember that."
			if plug.seated() and (plug.stalled or plug.torque() >= plug.hand_limit - 0.01):
				advance("Threaded" + (" (crossed)" if plug.cross_threaded else " by hand"))
		"torque":
			if f.grab > 0.5:
				work(plug, f, wrench)
				if wrench.clicked_now:
					prompt = "Click. Let go."
				if wrench.overpulled:
					prompt = "Past the click. That's more than 15 in an old head. Let go."
			if f.grab_released:
				if wrench.clicked:
					advance("Torqued to %d ft-lb" % roundi(plug.torque()))
				else:
					wrench.release()
		"lead":
			if f.interact_pressed:
				_lead_off = false
				advance()
		"morning":
			if f.interact_pressed:
				advance("Said good morning")
		"start":
			if f.interact_pressed:
				start_text = _start_text()
				advance(start_text)
				prompt = start_text + "  " + prompt


func _gap_score() -> float:
	var widen := lerpf(1.0, 1.6, clampf((skill - 0.3) / 0.6, 0.0, 1.0))
	var err := absf(gap - GAP_TARGET)
	if err > GAP_TOL * widen:
		return 0.7
	return 1.0 - 0.15 * err / (GAP_TOL * widen)


func _start_text() -> String:
	var g := plug.grade(skill)
	var fl: Array = g.flags
	if plug.cross_threaded:
		return "She catches on the third try, with a tick from Number 3. She remembers."
	if _gap_score() <= 0.7:
		return "She coughs twice, then catches and runs rough."
	if not fl.is_empty():
		return "She starts. You'll hear about that plug at the next tune-up."
	return "First turn of the key. She grumbles, then purrs. Good morning, Doris."


func _result() -> Dictionary:
	var g := plug.grade(skill)
	var flags: Array = []
	var torque_ok := true
	for fl in g.flags:
		flags.append(str(fl))
		if str(fl) in ["bolt_overtorqued", "bolt_undertorqued"]:
			torque_ok = false
	var gs := _gap_score()
	if gs <= 0.7:
		flags.append("gap_wide" if gap > GAP_TARGET else "gap_narrow")
	return {
		"quality": float(g.score) * gs, "cross_threaded": plug.cross_threaded,
		"torque_ok": torque_ok, "gap_in": gap, "plug": PLUG + 1, "flags": flags,
	}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match step_id():
		"find":
			var row := PackedStringArray()
			for i in 4:
				row.append(("[%s][ %d ][/color]" if i == selection else "[%s]  %d  [/color]") % [RinkOS.bb(RinkOS.ACTION if i == selection else RinkOS.DIM), i + 1])
			out.append("FAN " + "".join(row) + " DIST")
		"out":
			out.append_array(JobScene.fastener_lines(old_plug))
		"drawer":
			for i in DRAWERS.size():
				var sel := i == selection_y
				out.append("[%s]%s %s[/color]" % [RinkOS.bb(RinkOS.ACTION if sel else RinkOS.TEXT), ">" if sel else " ", DRAWERS[i]])
		"gap":
			var col := RinkOS.GOOD if absf(gap - GAP_TARGET) <= GAP_TOL else RinkOS.READOUT
			out.append(meter_line("GAP", clampf((gap - 0.02) / 0.03, 0.0, 1.0), col, "%.3f in" % gap))
			out.append(RinkOS.dots("WANT", "0.035 in", 10))
		"thread":
			out.append_array(JobScene.fastener_lines(plug))
		"torque":
			out.append_array(JobScene.fastener_lines(plug, wrench))
	return out


# ---------------------------------------------------------------- visuals

func _sync(_dt: float) -> void:
	if _new_plug == null:
		return
	var sid := step_id()
	for i in 4:
		var w := _well(i)
		if i == PLUG:
			var out := (old_plug.thread_turns - old_plug.run) * PITCH
			_plugs[i].visible = step <= 2
			_plugs[i].transform = Transform3D(Basis(Vector3.UP, JobScene.spin(old_plug)), w + Vector3(0, out, 0))
			_boots[i].position = w + Vector3(0, 0.044 + (0.07 if _lead_off else 0.0), 0) + (Vector3(0, 0, -0.06) if _lead_off else Vector3.ZERO)
		else:
			_boots[i].position = w + Vector3(0, 0.044, 0)
	# the fouled plug on the rag once it's out; the new one in the drawer, on
	# the rag for gapping, then in the well
	if step >= 3:
		_plugs[PLUG].visible = true
		_plugs[PLUG].transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), RAG_AT + Vector3(-0.1, 0.012, 0.05))
	_new_plug.visible = step >= 4 or (sid == "drawer" and _drawer_open == 1)
	if step >= 5:
		var out2 := (plug.thread_turns - plug.run) * PITCH
		_new_plug.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(plug)), _well(PLUG) + Vector3(0, out2, 0))
	elif step == 4:
		_new_plug.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), RAG_AT + Vector3(0.0, 0.012, 0.0))
	else:
		_new_plug.transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	_tray.visible = _drawer_open >= 0
	if _drawer_open >= 0:
		var y := JobParts.DRAWER_TOP - _drawer_open * JobParts.DRAWER_STEP - 0.08
		var cb := Basis(Vector3.UP, deg_to_rad(CAB_YAW))
		_tray.transform = Transform3D(cb, CAB_AT + cb * Vector3(0, y, -0.3))
	_gauge.visible = sid == "gap"
	_gauge.position = RAG_AT + Vector3(0.09, 0.01, -0.02)
	_sel_mark.visible = sid == "find"
	_sel_mark.position = _well(selection) + Vector3(0, 0.15, 0)
	_tool_node.visible = false
	if sid == "out" and tool() == "ratchet" or sid == "torque" or (sid == "thread" and tool() == "torque_wrench"):
		var fs := old_plug if sid == "out" else plug
		var top := _plugs[PLUG].position if sid == "out" else _new_plug.position
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet" if sid == "out" else "torque_wrench")
		_tool_node.transform = Transform3D(Basis(Vector3.UP, PI - 0.35 + JobScene.spin(fs) * 0.2), top + Vector3(0, 0.07, 0))


# ---------------------------------------------------------------- the bay

func _build() -> void:
	environment(Color("17181b"), 0.45)
	slab(Vector3(6.0, 0.2, 5.0), Vector3(0, -0.1, 1.0), Color("6a665c"))
	slab(Vector3(6.0, 3.2, 0.2), Vector3(0, 1.6, 2.4), Wear.OLD_CREAM.darkened(0.15))
	slab(Vector3(6.0, 1.0, 0.21), Vector3(0, 0.5, 2.39), Color("3d6fb0").darkened(0.2))
	note("THE ZAMBELLI BRAND\nICE RESURFACER.\nACCEPT NO SUBSTITUTES.", Vector3(-0.2, 1.75, 2.29), 0.0, 0.0035, Color("f1eee4"), Color("1d3557"), 0.75, 0.9)
	note("FLATLEY F-9", Vector3(1.4, 1.7, 2.29), 0.0, 0.004, Color("1a1a1a"), Color("d9a62e"), 0.55, 0.8)
	# Doris's back end round her engine bay: the chassis under it, the deck
	slab(Vector3(1.1, 0.5, 0.75), BAY_AT + Vector3(0, -0.25, 0.0), Wear.CHARCOAL)
	slab(Vector3(1.3, 0.12, 0.25), BAY_AT + Vector3(0, -0.06, -0.48), Wear.OLD_CREAM)
	part("engine_bay", BAY_AT)
	for i in 4:
		var mi := part("spark_plug_fouled" if i == PLUG else "spark_plug", _well(i))
		_plugs.append(mi)
		_boots.append(part("plug_boot", _well(i) + Vector3(0, 0.044, 0)))
	_new_plug = part("spark_plug", Vector3.ZERO)
	_sel_mark = slab(Vector3(0.03, 0.012, 0.03), Vector3.ZERO, RinkOS.ACTION, 2.0)
	# the dash with Gus's note
	var dash := slab(Vector3(0.36, 0.3, 0.05), Vector3(0.84, 0.88, 0.0), Wear.CHARCOAL)
	dash.rotation_degrees = Vector3(-25, -20, 0)
	note("She won't start cold if\nNumber 3 plug is fouled.\nPlugs: DORIS drawer,\nsecond from the top.\nHand tight then a quarter.\nDo NOT cross-thread her,\nshe remembers.\nSay good morning first.\nI mean it.  - G", Vector3(0.83, 0.9, -0.03), -20.0, 0.00075, Color("1b2a4a"), Color("f3e7a2"), 0.24, 0.2).rotation_degrees.x = -25.0
	# the rag on the deck for the plugs
	slab(Vector3(0.3, 0.01, 0.2), RAG_AT, Color("b03a2e"))
	slab(Vector3(0.5, 0.42, 0.45), RAG_AT + Vector3(0, -0.215, 0.05), Wear.OLD_WOOD_DARK)
	_gauge = part("feeler_gauge", Vector3.ZERO)
	# the DORIS cabinet and its labels
	var cab := part("parts_drawer", CAB_AT, null, Basis(Vector3.UP, deg_to_rad(CAB_YAW)))
	cab.name = "DorisDrawers"
	var cb := Basis(Vector3.UP, deg_to_rad(CAB_YAW))
	for i in DRAWERS.size():
		var y := JobParts.DRAWER_TOP + 0.04 - i * JobParts.DRAWER_STEP
		note(str(DRAWERS[i]), CAB_AT + cb * Vector3(0, y, -0.043), CAB_YAW, 0.0011, Color("1a1a1a"))
	_tray = part("drawer_tray", Vector3.ZERO)
	_tool_node = MeshInstance3D.new()
	add_child(_tool_node)
	# lights: the drop light hooked on the cowl, the bay's high bay lamp
	light(Vector3(0.3, 1.25, -0.35), 1.1, 3.0, Color(1.0, 0.9, 0.72))
	light(Vector3(-0.6, 2.8, 0.6), 0.8, 6.0, Wear.SODIUM, false)
	light(Vector3(-0.9, 1.6, -0.6), 0.5, 2.5, Color(0.9, 0.95, 1.0), false)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-60.0, 200.0, 0.0)
	key.light_energy = 0.2
	add_child(key)
