class_name DorisDrive
extends JobScene
## Driving Doris (playtest #45): the resurface as a mini game the owner has
## to do until a driver is hired. First person up in the seat of Doris, a
## Zambelli 552 Electric (DorisModel: every control on the real machine is a
## part here, and moves), on the real rink: fill the tanks at the standpipe, out
## through the gate, conditioner down, the controls set, two laps and the
## loops, back to the bay and dump the snow at the pit. ResurfaceRun does the
## machine and the ice cell by cell; this scene is the cockpit, the input,
## Gus on the first cut and the sound hooks. Numbers: docs/world/ICE.md 4.
##
## Controls (look at one: its name shows in the middle of the screen):
##   wheel / triggers   adjust the control looked at (d-pad picks on a pad)
##   E / A              toggle it (switches, levers, the plunger)
##   W, stick up        the accelerator pedal, in the shifter's direction
##                      (F / N / R: look at the shift knob and move it)
##   S, Space, stick down  the brake pedal; A/D steer
##   back               leave before you're on the ice (nothing charged),
##                      or stop and take the job as it stands
##
## The contract is JobScene's: begin(ctx), finished(result). The result is
## ResurfaceRun.result() (with the worked ice as `ice_state`) for
## RinkSim.job("resurface"). ctx extras: "autopilot" (the scene drives
## itself), "preview" ("cockpit": mid-cut, looking at the controls),
## "ice"/"doris" when there's no sim. With a driver hired (sim.earl_hired)
## Earl takes her out and the job finishes at once.

## Sound hooks (WorldSound plays them; this scene plays nothing).
signal blade_scrape(quality: float, skipping: bool)
signal flood_flow(rate: float, state: String)
signal wash_pump(on: bool)
signal auger(jammed: bool)
signal bin_dump
signal engine(rpm: float)
signal hose(on: bool)
## Any control moved by the driver (a lever's clunk, a valve's squeak): its
## DorisModel.CONTROLS id.
signal control_moved(id: String)

## Doris's model (DorisModel): front faces -Z, origin at the pivot 0.75 m
## ahead of the rear axle. The driver sits up on the left, behind the tank.
const AXLE_Z := DorisModel.AXLE_Z
const SEAT := DorisModel.SEAT
const LOOK_YAW_MAX := 1.9
const LOOK_PITCH_MAX := 1.0
const PICK_ANGLE := 0.16
const SOUND_EVERY := 0.25
const VALVE_STEP := 0.05
const WHEEL_STEP := 0.125  # turns of the blade wheel a notch

var run: ResurfaceRun
var ap: ResurfaceAutopilot
var autopilot := false
var preview := ""
var ice: IceSlab            # the sim's (the run works on a copy)
var doris_sim: ResurfacerSim
var body: Node3D
var model: DorisModel
var focus := ""
var gus_on := false
var gus_text := ""
var started_on_ice := false
var finished_drive := false
var _parts := {}            # control id -> the moving Node3D
var _ctrl_pos := {}         # control id -> model-space position
var _ly := 0.0
var _lp := -0.15
var _wheel_notches := 0
var _pad_idx := -1
var _pad_t := 0.0
var _trig_acc := 0.0
var _plunger_held := false
var _gus_t := 0.0
var _gus_said := {}
var _gus_queue: PackedStringArray = []
var _sound_t := 0.0
var _was := {}
var _view: IceView
var _view_was: IceSlab
var _hidden: Array[Node3D] = []
var _layer: CanvasLayer
var _tip: Label
var _gus_label: Label
var _bin: Control
var _pedal := 0.0
var _brake_pedal := 0.0
var _earl := false
var _hint_timer := 0.0


func _build() -> void:
	title = "DORIS"
	environment(Color("0d0f14"), 0.4)
	model = DorisModel.new(Wear.WORN)
	body = model
	add_child(body)
	for id: String in DorisModel.control_ids():
		_ctrl_pos[id] = DorisModel.grip(id)
	WorldSound.attach(self, body)
	_build_bay_bits()
	_build_ui()


## The standpipe and its hose by the bay wall (the venue's bay has the pit).
func _build_bay_bits() -> void:
	var sp := Vector3(ResurfaceRun.STANDPIPE.x, 0, ResurfaceRun.STANDPIPE.y + 0.15)
	slab(Vector3(0.12, 1.2, 0.12), sp + Vector3(0, 0.6, 0), Color("8a6d3b"))
	slab(Vector3(0.5, 0.5, 0.12), sp + Vector3(0, 1.3, 0.05), Color("2f5eb0"))
	note("HOT WATER\nFLOOD ONLY", sp + Vector3(0, 1.8, -0.02), 180.0, 0.004, Color("e8e4da"))


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_tip = Label.new()
	_tip.add_theme_font_override("font", RinkOS.TERM_FONT)
	_tip.add_theme_font_size_override("font_size", 28)
	_tip.add_theme_color_override("font_color", RinkOS.ACTION)
	_tip.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tip.add_theme_constant_override("shadow_offset_x", 2)
	_tip.add_theme_constant_override("shadow_offset_y", 2)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.set_anchors_preset(Control.PRESET_CENTER)
	_tip.offset_left = -360
	_tip.offset_right = 360
	_tip.offset_top = 18
	_tip.offset_bottom = 90
	_layer.add_child(_tip)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -4
	cross.offset_top = -12
	_layer.add_child(cross)
	_gus_label = Label.new()
	_gus_label.add_theme_font_override("font", RinkOS.TERM_FONT)
	_gus_label.add_theme_font_size_override("font_size", 28)
	_gus_label.add_theme_color_override("font_color", Color("f0e6c8"))
	_gus_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_gus_label.add_theme_constant_override("shadow_offset_x", 2)
	_gus_label.add_theme_constant_override("shadow_offset_y", 2)
	_gus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gus_label.anchor_left = 0.5
	_gus_label.anchor_right = 0.5
	_gus_label.anchor_top = 1.0
	_gus_label.anchor_bottom = 1.0
	_gus_label.offset_left = -440
	_gus_label.offset_right = 440
	_gus_label.offset_top = -250
	_gus_label.offset_bottom = -170
	_layer.add_child(_gus_label)
	_bin = BinWindow.new()
	_bin.anchor_left = 1.0
	_bin.anchor_right = 1.0
	_bin.anchor_top = 1.0
	_bin.anchor_bottom = 1.0
	_bin.offset_left = -250
	_bin.offset_right = -20
	_bin.offset_top = -200
	_bin.offset_bottom = -20
	_layer.add_child(_bin)


# ---------------------------------------------------------------- setup

func begin(ctx: Dictionary) -> void:
	autopilot = bool(ctx.get("autopilot", false))
	preview = str(ctx.get("preview", ""))
	super.begin(ctx)
	ice = sim.get("ice") as IceSlab if sim else null
	doris_sim = sim.get("doris") as ResurfacerSim if sim else null
	if ice == null:
		ice = ctx.get("ice") as IceSlab
	if ice == null:
		ice = IceSlab.create_millbrook()
		ice.wear_sessions(3.0, 20.0)
	if doris_sim == null:
		doris_sim = ctx.get("doris") as ResurfacerSim
	if doris_sim == null:
		doris_sim = ResurfacerSim.create_doris()
	run = ResurfaceRun.start(ice, doris_sim)
	# parked as Earl leaves her: in neutral, augers off, wash valve shut
	run.gear = 0
	run.auger_v = false
	run.auger_h = false
	run.wash_valve = 0.0
	gus_on = doris_sim.cuts_driven == 0 and not autopilot
	_earl = sim != null and bool(sim.get("earl_hired")) and doris_sim.fault() == ""
	_attach_world()
	if _earl or autopilot:
		ap = ResurfaceAutopilot.new(run, ResurfaceAutopilot.NORMAL)
	if _earl:
		# a driver's hired: he takes her out, the job is the result
		while not ap.done and run.time_s < 1800.0:
			ap.tick(1.0 / 10.0)
		_complete("Earl took her out.")
	elif preview == "cockpit":
		_preview_cockpit()
	elif doris_sim.fault() != "":
		prompt = "Doris %s. Nothing to drive till she's fixed: %s to climb down." % [doris_sim.fault(), RinkOS.key("X")]
		gus_on = false
	_sync_body()
	_place_camera()
	if not autopilot and preview == "" and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup() -> void:
	steps = [
		{"id": "fill", "text": "Fill both tanks at the standpipe"},
		{"id": "out", "text": "Out through the gate onto the ice"},
		{"id": "set", "text": "Conditioner down, valve open, blade set"},
		{"id": "cut", "text": "Two laps, the middle, then the loops"},
		{"id": "home", "text": "Back to the bay, dump at the pit"},
		{"id": "park", "text": "Park her and switch off"},
	]


func _enter_step(_i: int) -> void:
	pass


## The venue's rink and ice view when there is one; else a rink of our own.
func _attach_world() -> void:
	var views: Array = []
	if is_inside_tree():
		views = get_tree().get_nodes_in_group("ice_view")
	if not views.is_empty():
		_view = views[0] as IceView
		_view_was = _view.ice
		_view.ice = run.ice
	else:
		var rink := Rink.new()
		add_child(rink)
		_view = IceView.attach(rink, run.ice)
		# a bay floor past the gate
		slab(Vector3(ResurfaceRun.BAY_X1 - ResurfaceRun.BAY_X0 + 3.0, 0.04, ResurfaceRun.BAY_HALF * 2.0),
			Vector3((ResurfaceRun.BAY_X0 + ResurfaceRun.BAY_X1) * 0.5 - 1.0, -0.02, 0.0), Color("6f6c66"))
		slab(Vector3(2.5, 0.05, 2.2), Vector3(ResurfaceRun.PIT.x, 0.0, ResurfaceRun.PIT.y), Color("2e3033"))
		light(Vector3(0, 9, 0), 2.0, 40.0, Color(1, 0.97, 0.9), false)
		light(Vector3(-20, 9, 0), 1.6, 30.0, Color(1, 0.97, 0.9), false)
		light(Vector3(20, 9, 0), 1.6, 30.0, Color(1, 0.97, 0.9), false)
		light(Vector3(40, 4.5, 0), 1.2, 12.0, Color(1, 0.95, 0.85), false)
	# the venue's parked Doris goes out with us
	var parent := get_parent()
	var venue: Variant = parent.get("venue") if parent else null
	for n in get_tree().get_nodes_in_group("doris_model") if is_inside_tree() else []:
		var dm := n as Node3D
		if dm != body and dm.visible:
			dm.visible = false
			_hidden.append(dm)
	if venue is Node:
		var bay: Node = (venue as Node).get("rooms").get("zamboni_bay") if (venue as Node).get("rooms") is Dictionary else null
		if bay:
			for n in bay.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.visible and mi.global_position.distance_to(Vector3(ResurfaceRun.PARK.x, 0, ResurfaceRun.PARK.y)) < 0.3:
					mi.visible = false
					_hidden.append(mi)


func _preview_cockpit() -> void:
	ap = ResurfaceAutopilot.new(run, ResurfaceAutopilot.NORMAL)
	while not ap.done and run.time_s < 260.0:
		ap.tick(1.0 / 20.0)
	ap = null
	run.drain_events()
	_ly = -1.0
	_lp = -0.62
	focus = "blade"
	started_on_ice = true
	step = 3
	gus_on = true
	_say("Gus: Blade's a sixteenth. Two turns of the wheel from the stop. Any deeper and she skips.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_restore_world()
	super._notification(what)


func _restore_world() -> void:
	if is_instance_valid(_view) and _view_was != null:
		_view.ice = _view_was
		_view_was = null
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()


# ---------------------------------------------------------------- the loop

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel_notches += 1
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_notches -= 1


func tick(dt: float) -> void:
	if not _started or closed:
		return
	if complete:
		var f0 := input.poll(dt, JobInput.Context.DRIVE)
		if f0.interact_pressed or f0.back_pressed:
			_close(result)
		_refresh()
		return
	if autopilot and ap:
		ap.tick(dt)
		_after_step(dt)
		if ap.done:
			_complete("")
		return
	var f := input.poll(dt, JobInput.Context.DRIVE)
	if f.back_pressed:
		if not started_on_ice:
			_close({"cancelled": true})
		else:
			_complete("You stopped her where she stood.")
		return
	_look(f, dt)
	_pick_focus(dt)
	_adjust(f, dt)
	# the pedals: the accelerator drives her the way the shifter points, the
	# brake pedal (S, Space, stick down) stops her
	_pedal = clampf(f.move.y, 0.0, 1.0)
	_brake_pedal = maxf(clampf(-f.move.y, 0.0, 1.0), f.brake if not _pad() else 0.0)
	var throttle := _pedal * float(run.gear)
	var brake := _brake_pedal
	if throttle != 0.0 and absf(run.speed) > 0.2 and signf(throttle) != signf(run.speed):
		brake = maxf(brake, absf(throttle))  # shifted against her way: she brakes first
		throttle = 0.0
	run.step(dt, throttle, clampf(f.move.x, -1.0, 1.0), brake)
	_after_step(dt)
	if _can_park() and f.interact_pressed and focus == "":
		_complete("")


func _can_park() -> bool:
	return step_id() == "park" and run.in_bay() and absf(run.speed) < 0.05


func _pad() -> bool:
	var setup := get_node_or_null(^"/root/InputSetup")
	return setup != null and setup.get("device") == 1


func _look(f: JobInput.Frame, _dt: float) -> void:
	_ly = clampf(_ly - f.look.x, -LOOK_YAW_MAX, LOOK_YAW_MAX)
	_lp = clampf(_lp + f.look.y, -LOOK_PITCH_MAX, 0.5)
	if f.look.length() > 0.002:
		_pad_t = 0.0


## The control under the crosshair (or picked with the d-pad).
func _pick_focus(dt: float) -> void:
	var ids: Array = DorisModel.control_ids()
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		if _pad_t <= 0.0 or _pad_t > 2.6:
			var d := 1 if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) else -1
			_pad_idx = posmod((_pad_idx if _pad_idx >= 0 else 0) + d, ids.size())
			_pad_t = 3.0
	if _pad_t > 0.0:
		_pad_t -= dt
		focus = str(ids[_pad_idx])
		return
	focus = ""
	var best := PICK_ANGLE
	# the scene's own space (it sits at the world origin in the venue too)
	var eye := cam.transform.origin
	var fwd := -cam.transform.basis.z
	for id: String in _ctrl_pos:
		var p := body.transform * (_ctrl_pos[id] as Vector3)
		var to := p - eye
		if to.length() > 1.8:
			continue
		var a := fwd.angle_to(to)
		if a < best:
			best = a
			focus = id


## Wheel and triggers adjust the control looked at; interact toggles it.
func _adjust(f: JobInput.Frame, dt: float) -> void:
	var notches := _wheel_notches
	_wheel_notches = 0
	var trig := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(trig) > 0.15:
		_trig_acc += trig * dt * 6.0
		while absf(_trig_acc) >= 1.0:
			notches += int(signf(_trig_acc))
			_trig_acc -= signf(_trig_acc)
	else:
		_trig_acc = 0.0
	if focus == "":
		_plunger_held = false
		run.plunger = false
		return
	if notches != 0:
		set_control(focus, notches)
	if f.interact_pressed:
		toggle_control(focus)
	run.plunger = _plunger_held and focus == "plunger"


## Moves control `id` by `notches` of the wheel (+ opens / deepens / on).
func set_control(id: String, notches: int) -> void:
	match id:
		"valve":
			run.flood_valve = clampf(snappedf(run.flood_valve + notches * VALVE_STEP, VALVE_STEP), 0.0, 1.0)
		"blade":
			run.blade_mm = clampf(run.blade_mm + notches * WHEEL_STEP * ResurfacerSim.WHEEL_MM_PER_TURN, 0.0, ResurfacerSim.BLADE_MAX_MM)
		"wash":
			run.wash_on = notches > 0
		"conditioner":
			run.cond_down = notches < 0
		"towel":
			run.towel_down = notches < 0
		"dump":
			run.dump = notches > 0
		"plunger":
			_plunger_held = notches < 0
		"fill":
			run.fill = notches > 0
		"gear":
			run.gear = clampi(run.gear + signi(notches), -1, 1)
		"auger_v":
			run.auger_v = notches > 0
		"auger_h":
			run.auger_h = notches > 0
		"wash_valve":
			run.wash_valve = clampf(snappedf(run.wash_valve + notches * VALVE_STEP, VALVE_STEP), 0.0, 1.0)
		"key":
			run.engine_on = notches > 0 and doris_sim.fault() == ""
	_on_control(id)


func toggle_control(id: String) -> void:
	match id:
		"valve":
			run.flood_valve = 0.0 if run.flood_valve > 0.0 else 0.65
		"blade":
			run.blade_mm = 0.0 if run.blade_mm > 0.0 else 2.0 * ResurfacerSim.WHEEL_MM_PER_TURN
		"wash":
			run.wash_on = not run.wash_on
		"conditioner":
			run.cond_down = not run.cond_down
		"towel":
			run.towel_down = not run.towel_down
		"dump":
			run.dump = true
		"plunger":
			_plunger_held = not _plunger_held
		"fill":
			run.fill = not run.fill
		"gear":
			run.gear = run.gear - 1 if run.gear > -1 else 1  # F, N, R, F
		"auger_v":
			run.auger_v = not run.auger_v
		"auger_h":
			run.auger_h = not run.auger_h
		"wash_valve":
			run.wash_valve = 0.0 if run.wash_valve > 0.0 else 1.0
		"key":
			if _can_park():
				run.engine_on = false
				_complete("")
				return
			run.engine_on = not run.engine_on and doris_sim.fault() == ""
	_on_control(id)


func _on_control(id: String) -> void:
	control_moved.emit(id)
	if id == "fill":
		hose.emit(run.fill and run.at_standpipe())
		if run.fill and not run.at_standpipe():
			hint = "The hose doesn't reach: park by the standpipe."
			_hint_timer = 4.0
	if id == "dump" and run.dump and not run.at_pit():
		hint = "Back her up to the pit grate first."
		_hint_timer = 4.0


## After each step of the run: events, Gus, sounds, steps, the 3D.
func _after_step(dt: float) -> void:
	_hint_timer -= dt
	for e in run.drain_events():
		_on_event(e)
	_gus(dt)
	_sounds(dt)
	_update_steps()
	_sync_body()
	_place_camera()
	_sync_parts()
	_refresh()


func _on_event(e: String) -> void:
	match e:
		"on_ice":
			started_on_ice = true
			_say_once("on_ice", "Gus: Conditioner down, she takes five seconds. Both augers on. Flood valve to sixty-five, blade two turns, wash pump on and its valve open, rag down.")
		"filled":
			_say_once("filled", "Gus: That's both tanks. Out through the gate, slow, and swing onto the far boards.")
		"jam":
			auger.emit(true)
			_say("Gus: Augers are choked. Conditioner up and hold the plunger till she clears.")
			log_lines.append("Jammed the augers.")
		"unjam":
			auger.emit(false)
			_say_once("unjam%d" % run.jams, "Gus: There she goes. Ease the blade off a touch.")
		"bin_full":
			auger.emit(true)
			_say("Gus: She's packed solid. Nothing for it: back to the pit and dump.")
			log_lines.append("Filled the snow tank solid.")
		"flood_empty":
			_say_once("flood_empty", "Gus: Out of water. Finish dry or go back and fill. I'd fill.")
		"wash_empty":
			_say_once("wash_empty", "Gus: Wash tank's dry. Keep going, but the slush'll ball up.")
		"board_hit":
			_say("Gus: That's the boards. They don't move. You do.")
		"slide":
			_say_once("slide", "Gus: Easy in the turns. She's three tonnes on studs, not a Zamboni ad.")
		"dump_start":
			bin_dump.emit()
		"dump_done":
			_say_once("dump_done", "Gus: Nose to the door and park her.")
		"dump_refused":
			_say("Gus: Not there. Back the tank over the grate.")


## Gus's running commentary on the first cut.
func _gus(dt: float) -> void:
	_gus_t -= dt
	if _gus_t <= 0.0:
		if not _gus_queue.is_empty():
			gus_text = _gus_queue[0]
			_gus_queue.remove_at(0)
			_gus_t = 5.5
		elif _gus_t < -1.0:
			gus_text = ""
	if not gus_on:
		return
	if run.time_s < 1.0:
		_say_once("start", "Gus: First thing, water. Knob to F, ease on the pedal, pull her up to the standpipe and open the hose, the blue cap on the dash.")
	if run.cond_pos >= 1.0 and run.on_ice() and not (run.auger_v and run.auger_h):
		_say_once("augers", "Gus: Augers! Both levers forward, or the snow stays on the ice.")
	if run.in_bay() and run.gear == 1 and run.bin_m3 > 0.2 and not run.on_ice() and absf(run.speed) < 0.05 and run.coverage() > 0.5:
		_say_once("reverse", "Gus: Knob back to R to back her over the pit.")
	if run.skipping and run.cond_down:
		_say_once("skip", "Gus: Hear her chatter? The blade's skipping. Back the wheel off.")
	if run.flood_state == "rush" and run.on_ice():
		_say_once("rush", "Gus: Too much water for that speed. You'll leave a lake at the boards.")
	if run.flood_state == "trickle" and run.on_ice() and absf(run.speed) > 1.0:
		_say_once("trickle", "Gus: You're leaving it dry. More valve, or slow down.")
	if run.on_ice() and run.flood_valve > 0.0 and not run.towel_down:
		_say_once("towel", "Gus: Rag down, or you'll lay stripes.")
	if run.bin_fill() > 0.8:
		_say_once("bin80", "Gus: Tank's getting full. Watch the window.")
	var cov := run.coverage()
	if cov > 0.45:
		_say_once("half", "Gus: Halfway. Keep the overlaps, a hand's width.")
	if cov > 0.9:
		_say_once("done_cut", "Gus: That'll do it. Water off, conditioner up, back to the bay.")
	if not run.on_ice() and run.in_bay() and cov > 0.5 and run.bin_m3 > 0.2:
		_say_once("pit", "Gus: Back the tank over the pit grate and pull the dump lever.")


func _say(line: String) -> void:
	if gus_text == line or line in _gus_queue:
		return
	if gus_text == "" or _gus_t <= 0.0:
		gus_text = line
		_gus_t = 5.5
	elif _gus_queue.size() < 3:
		_gus_queue.append(line)


func _say_once(key: String, line: String) -> void:
	if _gus_said.has(key):
		return
	_gus_said[key] = true
	_say(line)


## The sound hooks: on change, and the continuous ones a few times a second.
func _sounds(dt: float) -> void:
	_sound_t -= dt
	var wash := run.wash_on and run.wash_l > 0.0 and run.on_ice()
	if wash != bool(_was.get("wash", false)):
		wash_pump.emit(wash)
		_was["wash"] = wash
	var fill := run.fill and run.at_standpipe()
	if fill != bool(_was.get("hose", false)):
		hose.emit(fill)
		_was["hose"] = fill
	if run.jammed != bool(_was.get("jam", false)):
		auger.emit(run.jammed)
		_was["jam"] = run.jammed
	if str(_was.get("flood", "off")) != run.flood_state:
		flood_flow.emit(run.flood_rate, run.flood_state)
		_was["flood"] = run.flood_state
	if _sound_t > 0.0:
		return
	_sound_t = SOUND_EVERY
	engine.emit(run.rpm)
	if run.cond_pos >= 1.0 and run.on_ice() and run.blade_mm > 0.0 and absf(run.speed) > 0.1:
		blade_scrape.emit(run.blade_quality, run.skipping)
	if run.flood_rate > 0.0:
		flood_flow.emit(run.flood_rate, run.flood_state)


func _update_steps() -> void:
	var s := step
	if s == 0 and (run.flood_l >= ResurfacerSim.FLOOD_TANK_L * 0.95 or run.on_ice()):
		s = 1
	if s == 1 and run.on_ice():
		s = 2
	if s == 2 and run.cond_down and run.flood_valve > 0.0 and run.blade_mm > 0.0 and run.auger_v and run.auger_h:
		s = 3
	if s == 3 and run.coverage() >= 0.9:
		s = 4
	if s >= 2 and s < 4 and not run.on_ice() and run.in_bay() and run.coverage() > 0.3:
		s = 4
	if s == 4 and run.in_bay() and (run.dumped_m3 > 0.0 and run.bin_m3 <= 0.01):
		s = 5
	if s != step:
		step = s
		if s == 5:
			prompt = "Parked? %s to switch her off and finish." % RinkOS.key("E")


func _complete(note_text: String) -> void:
	if complete:
		return
	result = run.result()
	result["quality"] = float(result.quality)
	result["gus_rode"] = gus_on
	if note_text != "":
		log_lines.append(note_text)
	complete = true
	finished_drive = true
	step = steps.size()
	var r := result
	var verdict := _verdict(float(r.quality))
	prompt = "%s %.0f%% covered, %+.1f mm, gouges %.1f -> %.1f mm. %s" % [str(r.kind).capitalize(), float(r.coverage) * 100.0,
		float(r.thickness_change_mm), float(r.gouge_before_mm), float(r.gouge_after_mm), verdict]
	hint = "%s close" % RinkOS.key("E")
	if gus_on:
		gus_text = _gus_verdict(r)
		_gus_t = 30.0
	_refresh()


static func _gus_verdict(r: Dictionary) -> String:
	if bool(r.jam):
		return "Gus: Everyone jams her the first time. Everyone. Blade off a hair next time."
	if float(r.coverage) < 0.8:
		return "Gus: You missed half the sheet. The beer league will find every inch of it."
	if float(r.evenness) < 0.4:
		return "Gus: Puddles and dry streaks. Steady speed, steady valve."
	if float(r.quality) >= 0.85:
		return "Gus: Not bad. Not bad at all. Don't tell Earl."
	return "Gus: It'll skate. You'll get the feel of her."


# ---------------------------------------------------------------- 3D

func _sync_body() -> void:
	if run == null:
		return
	var f := run.fwd()
	var th := atan2(-f.x, -f.y)
	body.transform = Transform3D(Basis(Vector3.UP, th), Vector3(run.pos.x + f.x * AXLE_Z, 0.0, run.pos.y + f.y * AXLE_Z))


func _place_camera() -> void:
	if cam == null or body == null:
		return
	var b := Basis(Vector3.UP, _ly) * Basis(Vector3.RIGHT, _lp)
	cam.transform = body.transform * Transform3D(b, SEAT)


func _sync_parts() -> void:
	if run == null or model == null:
		return
	var m := model
	m.steer = run.steer / ResurfaceRun.MAX_STEER
	m.accel = _pedal if not autopilot else clampf(absf(run.speed) / ResurfaceRun.TOP_SPEED, 0.0, 1.0)
	m.brake = _brake_pedal
	m.gear = run.gear
	m.auger_v = run.auger_v
	m.auger_h = run.auger_h
	m.cond_down = run.cond_down
	m.cond_pos = run.cond_pos
	m.bin_up = run.dump
	m.flood = run.flood_valve
	m.wash_valve = run.wash_valve
	m.plunger = run.plunger
	m.blade_turns = run.blade_mm / ResurfacerSim.WHEEL_MM_PER_TURN
	m.wash_pump = run.wash_on
	m.key_on = run.engine_on
	m.fill_open = run.fill
	m.towel_down = run.towel_down
	m.speed = run.speed
	m.charge = clampf(0.92 - run.fuel_used * 3.0, 0.05, 1.0)
	m.tick(get_physics_process_delta_time() if is_inside_tree() else 1.0 / 60.0)
	m.apply()
	if m.lcd:
		m.lcd.text = "%s %4.1f KM/H\nFLOOD %3d L\nWASH  %3d L" % ["F" if run.gear > 0 else ("R" if run.gear < 0 else "N"), absf(run.speed) * 3.6,
			roundi(run.flood_l), roundi(run.wash_l)]


# ---------------------------------------------------------------- HUD

func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if run == null:
		return out
	out.append(meter_line("SPEED", absf(run.speed) / ResurfaceRun.TOP_SPEED, RinkOS.READOUT, "%.1f km/h" % (absf(run.speed) * 3.6)))
	out.append(meter_line("FLOOD", run.flood_l / ResurfacerSim.FLOOD_TANK_L, RinkOS.READOUT, "%d L @%d%%" % [roundi(run.flood_l), roundi(run.flood_valve * 100.0)]))
	out.append(meter_line("WASH", run.wash_l / ResurfacerSim.WASH_TANK_L, RinkOS.READOUT, "%d L  %s" % [roundi(run.wash_l), "ON" if run.wash_on else "off"]))
	var bcol := RinkOS.ALERT if run.bin_fill() > 0.9 or run.jammed else RinkOS.READOUT
	out.append(meter_line("SNOW", run.bin_fill(), bcol, "%.1f m3%s" % [run.bin_m3, "  JAMMED" if run.jammed else ""]))
	out.append(meter_line("BLADE", run.blade_mm / ResurfacerSim.BLADE_MAX_MM, RinkOS.ALERT if run.skipping else RinkOS.READOUT, blade_short(run.blade_mm)))
	out.append(meter_line("COVERED", run.coverage(), RinkOS.GOOD if run.coverage() > 0.9 else RinkOS.READOUT, "%d%%" % roundi(run.coverage() * 100.0)))
	out.append("[%s]%s   COND %s   AUGERS %s   RAG %s   WATER %s[/color]" % [RinkOS.bb(RinkOS.DIM),
		["R", "N", "F"][run.gear + 1], "DOWN" if run.cond_pos >= 1.0 else ("up" if run.cond_pos <= 0.0 else "moving"),
		("on" if run.auger_v and run.auger_h else ("half" if run.auger_v or run.auger_h else "off")),
		"DOWN" if run.towel_down else "up", run.flood_state.to_upper()])
	return out


## The blade in a few characters: the inch fraction it's wound to.
static func blade_short(mm: float) -> String:
	var n := roundi(mm / 25.4 * 64.0)
	if n == 0:
		return "up"
	var d := 64
	while n % 2 == 0 and d > 1:
		n /= 2
		d /= 2
	return "%d/%d in" % [n, d]


## The blade wheel as a driver reads it: turns from the stop, inches, mm.
static func blade_text(mm: float) -> String:
	var turns := mm / ResurfacerSim.WHEEL_MM_PER_TURN
	return "%.2f turns, %s, %.2f mm" % [turns, blade_short(mm), mm]


func _refresh() -> void:
	super._refresh()
	if _tip == null or run == null:
		return
	_tip.text = control_tip(focus) if focus != "" and not complete else ""
	_gus_label.text = gus_text
	if _bin:
		(_bin as BinWindow).fill = run.bin_fill()
		(_bin as BinWindow).rate = run.snow_rate / ResurfaceRun.AUGER_CAP
		(_bin as BinWindow).jammed = run.jammed
	if not complete:
		var s := step_id()
		if prompt == "" or s != str(_was.get("step", "")):
			_was["step"] = s
			prompt = {"fill": "Drive to the standpipe by the bay wall and open the hose (look at it, %s)." % RinkOS.key("E"),
				"out": "Out through the gate. Knob in F, %s pedal, %s/%s brake, %s/%s steer." % [RinkOS.key("W"), RinkOS.key("S"), RinkOS.key("SPACE"), RinkOS.key("A"), RinkOS.key("D")],
				"set": "Set her up: conditioner and rag down, both augers on, flood valve open, blade two turns. Look at a control and use the wheel.",
				"cut": "Two laps round the boards, down the middle, then the loops out to the laps.",
				"home": "Water off, conditioner up, augers off. Back to the bay, knob to R, and dump at the pit.",
				"park": "Parked? Turn the key off (or %s) to finish." % RinkOS.key("E")}.get(s, "")
		if _hint_timer <= 0.0:
			hint = "%s adjust   %s toggle   %s leave" % [RinkOS.key("WHEEL"), RinkOS.key("E"), RinkOS.key("X")]


## The centred tooltip for control `id`.
func control_tip(id: String) -> String:
	var v := ""
	match id:
		"gear":
			v = "%s   wheel: forward / back   E: F N R" % ["REVERSE", "NEUTRAL", "FORWARD"][run.gear + 1]
		"auger_v", "auger_h":
			var on: bool = run.auger_v if id == "auger_v" else run.auger_h
			v = ("ON" if on else "OFF") + "   E: switch"
		"valve":
			v = "%d%%   wheel: open / close" % roundi(run.flood_valve * 100.0)
		"wash_valve":
			v = "%d%%   wheel: open / close" % roundi(run.wash_valve * 100.0)
		"blade":
			v = "%s   wheel: down / up" % blade_text(run.blade_mm)
		"wash":
			v = ("ON" if run.wash_on else "OFF") + "   E: switch"
		"key":
			v = ("ON" if run.engine_on else "OFF") + ("   E: switch her off, done" if _can_park() else "   E: turn")
		"conditioner":
			var st := "DOWN" if run.cond_pos >= 1.0 else ("UP" if run.cond_pos <= 0.0 else ("LOWERING" if run.cond_down else "RAISING"))
			v = st + "   E: lower / raise (5 s)"
		"towel":
			v = ("DOWN" if run.towel_down else "UP") + "   E: lower / raise"
		"dump":
			v = "%.1f m3 in the tank   E: raise the bin over the pit" % run.bin_m3
		"plunger":
			v = ("HELD" if run.plunger else "-") + "   E: hold, conditioner up"
		"fill":
			v = ("OPEN" if run.fill else "SHUT") + ("" if run.at_standpipe() else "   (park by the standpipe)")
	return "%s\n%s" % [DorisModel.control_name(id), v]


## The snow tank as seen through its window, with the snow coming up the
## vertical auger at `rate` of what the augers can lift.
class BinWindow extends Control:
	var fill := 0.0
	var rate := 0.0
	var jammed := false
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, RinkOS.PANEL)
		draw_rect(r, RinkOS.BEZEL, false, 2.0)
		draw_string(RinkOS.PIXEL_FONT, Vector2(10, 18), "BIN WINDOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RinkOS.ACTION)
		var win := Rect2(10, 26, size.x - 20, size.y - 52)
		draw_rect(win, Color("1a2733"))
		var h := win.size.y * clampf(fill, 0.0, 1.0)
		draw_rect(Rect2(win.position.x, win.end.y - h, win.size.x, h), Color("e6edf2"))
		# the auger's throw: flakes falling past the glass, more for more snow
		var n := clampi(int(rate * 40.0), 0, 60) if not jammed else 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in n:
			var x := win.position.x + rng.randf() * win.size.x
			var sp := 40.0 + rng.randf() * 60.0
			var y := win.position.y + fposmod(rng.randf() * win.size.y + _t * sp, maxf(win.size.y - h, 1.0))
			draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, 0.9))
		var col := RinkOS.ALERT if fill > 0.9 or jammed else RinkOS.READOUT
		var txt := "JAMMED" if jammed else "%d%%  %s" % [roundi(fill * 100.0), "HEAVY" if rate > 0.9 else ("STEADY" if rate > 0.2 else "-")]
		draw_string(RinkOS.TERM_FONT, Vector2(10, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		draw_line(Vector2(win.position.x, win.position.y + win.size.y * 0.1), Vector2(win.end.x, win.position.y + win.size.y * 0.1), RinkOS.ALERT, 1.0)
