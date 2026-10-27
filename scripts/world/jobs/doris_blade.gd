extends JobScene
## Resurfacer blade change and height setting (docs/world/RINK_SIM.md 4.7),
## job `blade_change`. A raised view of the bay workbench with Doris's
## conditioner on Gus's stands ("DORIS'S SHOES") and the new 77 in blade.
##
## Steps and verbs:
##   prep     interact: gloves on, the guard on the new blade
##   loosen   grab + turn left with the long ratchet, the 7 bolts from the
##            ends to the centre (the scene moves to the next one)
##   out      hold grab: the old blade slides out, slow and heavy
##   in       hold grab: the new one slides in, bolts finger tight
##   height   move x picks the left, centre or right screw; grab + turn sets
##            it (1/6 turn = 0.1 mm, clockwise deeper); the feelers read it
##            under the straightedge; interact when it's set
##   torque   grab + turn with the torque wrench, centre out, to the click
##            at 35 ft-lb; let go after each click (move y sets the dial)
##   finish   interact: guard off, conditioner down, logged
##
## Result: {quality, height_mm (the mean cut depth; 0.8..1.2 shaves clean,
## 1.0 is the target), level_mm (end-to-end difference), bolts_ok, flags}.

const TARGET_MM := 1.0
const HEIGHT_TOL := 0.2
const LEVEL_TOL := 0.1
const MM_PER_TURN := 0.6       # 1/6 turn = 0.1 mm
const LOOSEN_ORDER := [0, 6, 1, 5, 2, 4, 3]
const TORQUE_ORDER := [3, 2, 4, 1, 5, 0, 6]
const SLIDE_S := 1.5
## The feelers' own error at each screw (T0 feeler gauge), mm.
const GAUGE_ERR := [0.02, -0.03, 0.01]

var old_bolts: Array[Fastener] = []
var bolts: Array[Fastener] = []
var wrench: TorqueWrench
var heights := PackedFloat32Array([0.4, 0.55, 0.3])
var bolt_idx := 0              # index into the step's order
var _slide := 0.0
var _pop := 0.0

var _cond: Node3D
var _old_blade: MeshInstance3D
var _new_blade: MeshInstance3D
var _guard: MeshInstance3D
var _bolt_nodes: Array[MeshInstance3D] = []
var _slots: Array[MeshInstance3D] = []
var _feeler: MeshInstance3D
var _tool_node: MeshInstance3D

const BENCH_TOP := 0.9
const COND_AT := Vector3(0.0, BENCH_TOP, 0.05)


func _setup() -> void:
	title = "Doris // blade change"
	steps = [
		{"id": "prep", "text": "Gloves on, guard on the new blade"},
		{"id": "loosen", "text": "Loosen 7 bolts, ends to centre"},
		{"id": "out", "text": "Slide the old blade out"},
		{"id": "in", "text": "Slide the new one in"},
		{"id": "height", "text": "Set the height: 1.0 mm, level"},
		{"id": "torque", "text": "Torque 35 ft-lb, centre out"},
		{"id": "finish", "text": "Guard off, conditioner down, log"},
	]
	old_bolts.clear()
	bolts.clear()
	for i in 7:
		var ob := Fastener.blade_bolt()
		old_bolts.append(JobScene.installed(ob, 35.0 / ob.stiffness))
		var nb := Fastener.blade_bolt()
		bolts.append(JobScene.installed(nb, nb.hand_tight_deg() * 0.6))
	heights = PackedFloat32Array([0.4, 0.55, 0.3])
	bolt_idx = 0
	wrench = null
	_sync(0.0)
	snap_camera()


func _bolt_pos(i: int) -> Vector3:
	return COND_AT + Vector3(float(JobParts.BOLT_X[i]) + 0.01, JobParts.BOLT_TOP, -0.11)


func _screw_pos(i: int) -> Vector3:
	return COND_AT + Vector3(float(JobParts.SCREW_X[i]) + 0.01, 0.28, -0.01)


func _enter_step(i: int) -> void:
	bolt_idx = 0
	_slide = 0.0
	_pop = 0.0
	match str(steps[i].id):
		"prep":
			view(Vector3(0.0, 1.85, -1.35), Vector3(0.0, 0.95, -0.1))
			prompt = "A blade is a two-metre razor. Gloves on, and clip the yellow guard over the new one's edge before you pick it up."
			hint = "%s gloves and guard" % RinkOS.key("E")
		"loosen":
			tools = PackedStringArray(["hand", "ratchet"])
			_bolt_view(LOOSEN_ORDER[0])
			prompt = "Seven bolts, from the ends in to the centre, with the long ratchet."
			hint = "%s pick tool   HOLD %s + drag LEFT loosen" % [RinkOS.key("A/D"), RinkOS.key("LMB")]
		"out":
			view(Vector3(0.0, 1.6, -1.3), Vector3(0.0, 0.95, -0.2))
			prompt = "Slide the old blade out. It's heavy and slow: drop it and you chip the edge."
			hint = "HOLD %s slide it out" % RinkOS.key("LMB")
		"in":
			view(Vector3(0.0, 1.6, -1.3), Vector3(0.0, 0.95, -0.2))
			prompt = "New blade into the slot, edge down and forward. The bolts go back in finger tight."
			hint = "HOLD %s slide it in" % RinkOS.key("LMB")
		"height":
			_screw_view(0)
			prompt = "Three screws set how far the edge sits below the runners. Want 1.0 mm, level end to end. Feelers under the straightedge tell you where you are."
			hint = "%s pick screw   HOLD %s + drag RIGHT deeper / LEFT shallower   %s done" % [RinkOS.key("A/D"), RinkOS.key("LMB"), RinkOS.key("E")]
		"torque":
			tools = PackedStringArray(["torque_wrench"])
			_bolt_view(TORQUE_ORDER[0])
			_new_wrench()
			prompt = "Torque wrench set to 35. Centre bolt first, then out. Pull till it clicks, then let go."
			hint = "HOLD %s + drag RIGHT pull   %s dial   release after the click" % [RinkOS.key("LMB"), RinkOS.key("W/S")]
		"finish":
			view(Vector3(0.0, 1.85, -1.35), Vector3(0.0, 0.95, -0.1))
			prompt = "Guard off, lower the conditioner. Log it: blade hours to zero, the old one to Kessler for sharpening."
			hint = "%s log it" % RinkOS.key("E")


func _bolt_view(i: int) -> void:
	var p := _bolt_pos(i)
	view(Vector3(p.x * 0.6 - 0.15, 1.62, -1.0), p + Vector3(0, -0.1, 0.05))


func _screw_view(i: int) -> void:
	var p := _screw_pos(i)
	view(Vector3(p.x * 0.85, 1.42, -0.78), p + Vector3(0, -0.12, -0.1))


func _new_wrench() -> void:
	var set_point := 35.0
	if wrench:
		set_point = wrench.set_point
	wrench = TorqueWrench.new(bolts[TORQUE_ORDER[bolt_idx]], set_point)


func _on_pick_x(d: int) -> void:
	if step_id() == "height":
		selection = posmod(selection + d, 3)
		_screw_view(selection)


func _on_pick_y(d: int) -> void:
	if step_id() == "torque" and wrench:
		wrench.adjust(d)


func _work(f: JobInput.Frame, dt: float) -> void:
	match step_id():
		"prep":
			if f.interact_pressed:
				advance("Gloves, guard")
		"loosen":
			var i: int = LOOSEN_ORDER[bolt_idx]
			var b := old_bolts[i]
			if _pop > 0.0:
				_pop += dt
				b.run = maxf(0.0, b.run - dt * 12.0)
				if _pop > 0.5:
					_pop = 0.0
					bolt_idx += 1
					if bolt_idx >= 7:
						advance("7 bolts out")
					else:
						_bolt_view(LOOSEN_ORDER[bolt_idx])
						prompt = "Next one. %d to go." % (7 - bolt_idx)
				return
			work(b, f)
			if JobScene.cracked(b):
				_pop = 0.001
		"out", "in":
			if f.grab > 0.5:
				_slide += dt
			elif _slide < SLIDE_S:
				_slide = maxf(0.0, _slide - dt * 2.0)  # set it down gently; no harm
			if _slide >= SLIDE_S:
				advance("Old blade out" if step_id() == "out" else "New blade in, finger tight")
		"height":
			if f.grab > 0.5 and f.turn != 0.0:
				heights[selection] = clampf(heights[selection] + f.turn * MM_PER_TURN, -0.5, 3.0)
			var spread := _level()
			if spread > LEVEL_TOL:
				prompt = "Left %.2f, centre %.2f, right %.2f. One end's deeper than the other: that leaves a ridge every pass." % [_read(0), _read(1), _read(2)]
			if f.interact_pressed:
				advance("Height %.2f mm, level %.2f" % [_mean(), spread])
		"torque":
			var i: int = TORQUE_ORDER[bolt_idx]
			if f.grab > 0.5:
				work(bolts[i], f, wrench)
				if wrench.clicked_now:
					prompt = "Click. Let go."
				if wrench.overpulled:
					prompt = "Past the click: that's more than 35 now. Let go."
			if f.grab_released:
				if wrench.clicked:
					bolt_idx += 1
					if bolt_idx >= 7:
						advance("Blade bolts torqued")
						return
					_new_wrench()
					_bolt_view(TORQUE_ORDER[bolt_idx])
					prompt = "Next bolt out from the centre. %d to go." % (7 - bolt_idx)
				else:
					wrench.release()
		"finish":
			if f.interact_pressed:
				advance("Logged")


func _mean() -> float:
	return (heights[0] + heights[1] + heights[2]) / 3.0


func _level() -> float:
	return maxf(heights[0], maxf(heights[1], heights[2])) - minf(heights[0], minf(heights[1], heights[2]))


## What the feelers say at screw `i`: the true depth plus the gauge's error,
## to the nearest 0.05 leaf.
func _read(i: int) -> float:
	return snappedf(heights[i] + float(GAUGE_ERR[i]), 0.05)


static func _score(err: float, tol: float) -> float:
	if absf(err) > tol:
		return 0.7
	return 1.0 - 0.15 * absf(err) / tol


func _result() -> Dictionary:
	var widen := lerpf(1.0, 1.6, clampf((skill - 0.3) / 0.6, 0.0, 1.0))
	var flags: Array = []
	var h := _mean()
	var hs := _score(h - TARGET_MM, HEIGHT_TOL * widen)
	if absf(h - TARGET_MM) > HEIGHT_TOL * widen:
		flags.append("blade_too_deep" if h > TARGET_MM else "blade_too_shallow")
	var lv := _level()
	var ls := 1.0 if lv <= LEVEL_TOL * widen else 0.7
	if lv > LEVEL_TOL * widen:
		flags.append("misaligned")
	var bs := 0.0
	var bolt_flags := 0
	for b in bolts:
		var g := b.grade(skill)
		bs += float(g.score)
		for fl in g.flags:
			bolt_flags += 1
			if not str(fl) in flags:
				flags.append(str(fl))
	bs /= bolts.size()
	return {
		"quality": hs * ls * bs, "height_mm": h, "level_mm": lv,
		"bolts_ok": bolt_flags == 0, "flags": flags,
	}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match step_id():
		"loosen":
			out.append(RinkOS.dots("BOLT", "%d of 7" % mini(bolt_idx + 1, 7), 10))
			out.append_array(JobScene.fastener_lines(old_bolts[LOOSEN_ORDER[mini(bolt_idx, 6)]]))
		"out", "in":
			out.append(meter_line("SLIDE", _slide / SLIDE_S, RinkOS.ACTION))
		"height":
			var names := ["LEFT", "CENTRE", "RIGHT"]
			for i in 3:
				var r := _read(i)
				var col := RinkOS.GOOD if absf(r - TARGET_MM) <= 0.1 else RinkOS.READOUT
				var sel := ">" if i == selection else " "
				out.append("[%s]%s %s[/color] [%s]%.2f mm[/color]  %s" % [RinkOS.bb(RinkOS.ACTION if i == selection else RinkOS.TEXT), sel,
					RinkOS.dots(names[i], "", 8).strip_edges(), RinkOS.bb(col), r, _feel(r)])
			out.append(RinkOS.dots("LEVEL", "%.2f mm  (1.0 LEAF)" % (_read_max() - _read_min()), 10))
		"torque":
			out.append(RinkOS.dots("BOLT", "%d of 7" % mini(bolt_idx + 1, 7), 10))
			out.append_array(JobScene.fastener_lines(bolts[TORQUE_ORDER[mini(bolt_idx, 6)]], wrench))
	return out


func _read_max() -> float:
	return maxf(_read(0), maxf(_read(1), _read(2)))


func _read_min() -> float:
	return minf(_read(0), minf(_read(1), _read(2)))


## The 1.0 mm leaf's feel under the straightedge.
static func _feel(r: float) -> String:
	if r < 0.9:
		return "won't go"
	if r > 1.1:
		return "loose"
	return "drags. right"


# ---------------------------------------------------------------- visuals

func _sync(_dt: float) -> void:
	if _cond == null:
		return
	var sid := step_id()
	# the bolts: the old set until they're out, then the new set
	var new_set := step >= 3
	for i in 7:
		var b := bolts[i] if new_set else old_bolts[i]
		var n := _bolt_nodes[i]
		var out := (b.thread_turns - b.run) * 0.006
		n.visible = new_set and (step > 3 or _slide >= SLIDE_S * 0.8) or (not new_set and b.run > 0.05)
		if step == 2:
			n.visible = false
		n.transform = Transform3D(Basis(Vector3.UP, JobScene.spin(b)), _bolt_pos(i) + Vector3(0, out, 0))
	# the blades
	var seat := COND_AT + JobParts.BLADE_SEAT
	var bench_front := Vector3(0.0, BENCH_TOP + 0.005, -0.33)
	var k := clampf(_slide / SLIDE_S, 0.0, 1.0)
	if step <= 1:
		_old_blade.position = seat
	elif sid == "out":
		_old_blade.position = seat.lerp(seat + Vector3(0, 0, -0.25), k)
	else:
		_old_blade.position = Vector3(0.0, 0.25, -0.62)  # leaning against the bench's front, off to Kessler
		_old_blade.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	if step < 3:
		_new_blade.position = bench_front + Vector3(0, 0, -0.04)
	elif sid == "in":
		_new_blade.position = (bench_front + Vector3(0, 0, -0.04)).lerp(seat, k)
	else:
		_new_blade.position = seat
	_guard.visible = step >= 1 and step < 6
	_guard.position = _new_blade.position + Vector3(0, 0.005, -0.06)
	# the height screw slots turn with the setting
	for i in 3:
		_slots[i].rotation = Vector3(0, -heights[i] / MM_PER_TURN * TAU, 0)
	_feeler.visible = sid == "height"
	if sid == "height":
		var sp := _screw_pos(selection)
		_feeler.position = Vector3(sp.x - 0.1, COND_AT.y + 0.205, -0.14)
	# the tool on the bolt it's working
	_tool_node.visible = false
	if sid == "loosen" and tool() == "ratchet":
		var i: int = LOOSEN_ORDER[mini(bolt_idx, 6)]
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("ratchet")
		_tool_node.transform = Transform3D(Basis(Vector3.UP, PI - 0.35 + JobScene.spin(old_bolts[i]) * 0.05), _bolt_nodes[i].position + Vector3(0, 0.014, 0))
	elif sid == "torque":
		var i2: int = TORQUE_ORDER[mini(bolt_idx, 6)]
		_tool_node.visible = true
		_tool_node.mesh = JobParts.mesh("torque_wrench")
		_tool_node.transform = Transform3D(Basis(Vector3.UP, PI - 0.35 + JobScene.spin(bolts[i2]) * 0.3), _bolt_nodes[i2].position + Vector3(0, 0.014, 0))


# ---------------------------------------------------------------- the bay

func _build() -> void:
	environment(Color("17181b"), 0.45)
	var floor_c := Color("6a665c")
	slab(Vector3(7.0, 0.2, 6.0), Vector3(0, -0.1, 1.2), floor_c)
	slab(Vector3(7.0, 3.4, 0.2), Vector3(0, 1.7, 3.2), Wear.OLD_CREAM.darkened(0.15))
	slab(Vector3(7.0, 1.0, 0.21), Vector3(0, 0.5, 3.19), Color("3d6fb0").darkened(0.2))
	slab(Vector3(0.2, 3.4, 6.0), Vector3(3.2, 1.7, 1.2), Wear.OLD_CREAM.darkened(0.22))
	# Doris herself, conditioner off, waiting behind the bench
	prop("resurfacer", Vector3(-1.3, 0, 2.0), 90.0)
	# the bay's signs
	note("55 OR DON'T BOTHER.", Vector3(1.6, 1.9, 3.09), 0.0, 0.004, Color("1a1a1a"), Wear.PAPER, 0.62, 0.14)
	note("THE ZAMBELLI BRAND\nICE RESURFACER.\nACCEPT NO SUBSTITUTES.", Vector3(0.5, 1.75, 3.09), 0.0, 0.0035, Color("f1eee4"), Color("1d3557"), 0.75, 0.9)
	part("workbench", Vector3.ZERO)
	_cond = Node3D.new()
	_cond.position = COND_AT
	add_child(_cond)
	part("conditioner", Vector3.ZERO, _cond)
	note("DORIS'S SHOES", COND_AT + Vector3(0.95, 0.04, -0.125), 0.0, 0.0012, Color("2a1a0a"))
	note("DORIS'S SHOES", COND_AT + Vector3(-0.95, 0.04, -0.125), 0.0, 0.0012, Color("2a1a0a"))
	_old_blade = part("blade_old", COND_AT + JobParts.BLADE_SEAT)
	_new_blade = part("blade", Vector3(0, BENCH_TOP + 0.005, -0.37))
	_guard = part("blade_guard", Vector3.ZERO)
	for i in 7:
		_bolt_nodes.append(part("blade_bolt", _bolt_pos(i)))
	for i in 3:
		var s := slab(Vector3(0.05, 0.006, 0.008), _screw_pos(i) + Vector3(0, 0.003, 0), Color("141210"))
		_slots.append(s)
	_feeler = part("feeler_gauge", Vector3.ZERO)
	_feeler.rotation_degrees = Vector3(0, 90, 0)
	_tool_node = MeshInstance3D.new()
	add_child(_tool_node)
	# the straightedge across the runners and a rag
	slab(Vector3(2.0, 0.012, 0.03), COND_AT + Vector3(0, 0.125, -0.19), Wear.STEEL)
	slab(Vector3(0.3, 0.012, 0.22), Vector3(1.05, BENCH_TOP + 0.006, -0.26), Color("b03a2e"))
	# lights: a shop light over the bench, the bay's high bay lamp
	slab(Vector3(1.3, 0.05, 0.14), Vector3(0, 2.4, 0.0), Color(0.9, 0.95, 1.0), 3.0)
	light(Vector3(0.0, 2.1, -0.2), 1.2, 4.5, Color(0.92, 0.96, 1.0))
	light(Vector3(-1.4, 3.0, 1.8), 0.7, 6.0, Wear.SODIUM, false)
	light(Vector3(0.6, 1.3, -1.0), 0.5, 2.5, Color(1.0, 0.88, 0.7), false)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-60.0, 200.0, 0.0)
	key.light_energy = 0.2
	add_child(key)
