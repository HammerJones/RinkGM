class_name DorisDrive
extends JobScene
## Driving Doris (playtest #45): the resurface as a mini game the owner has
## to do until a driver is hired. First person up in the seat of the 1974
## Zambelli 525, on the real rink: fill the tanks at the standpipe, out
## through the gate, conditioner down, the controls set, two laps and the
## loops, back to the bay and dump the snow at the pit. ResurfaceRun does the
## machine and the ice cell by cell; this scene is the cockpit, the input,
## Gus on the first cut and the sound hooks. Numbers: docs/world/ICE.md 4.
##
## Controls (look at one: its name shows in the middle of the screen):
##   wheel / triggers   adjust the control looked at (d-pad picks on a pad)
##   E / A              toggle it (switches, levers, the plunger)
##   W/S, left stick    throttle and reverse; Space brake; A/D steer
##   back               leave before you're on the ice (nothing charged),
##                      or stop and take the job as it stands
##
## The contract is JobScene's: begin(ctx), finished(result). The result is
## ResurfaceRun.result() (with the worked ice as `ice_state`) for
## RinkSim.job("resurface"). ctx extras: "autopilot" (the scene drives
## itself), "preview" ("cockpit": mid-cut, looking at the controls),
## "ice"/"doris" when there's no sim. With a driver hired (sim.earl_hired)
## Earl takes her out and the job finishes at once.

## Sound hooks for the lead's audio (this scene plays nothing).
signal blade_scrape(quality: float, skipping: bool)
signal flood_flow(rate: float, state: String)
signal wash_pump(on: bool)
signal auger(jammed: bool)
signal bin_dump
signal engine(rpm: float)
signal hose(on: bool)

## Doris's model: front faces -Z, origin at the pivot 0.75 m ahead of the
## rear axle. The driver sits up on the left, behind the snow tank.
const AXLE_Z := 0.75
const SEAT := Vector3(-0.47, 2.34, 1.0)
## The console and levers sit up on the tank wall within reach of the seat.
const COCKPIT_AT := Vector3(0.0, 0.32, 0.06)
const LOOK_YAW_MAX := 1.9
const LOOK_PITCH_MAX := 1.0
const PICK_ANGLE := 0.16
const SOUND_EVERY := 0.25
## The controls round the seat, model space: [id, name, position].
const CONTROLS := [
	["dump", "TANK DUMP", Vector3(-0.98, 1.62, 0.62)],
	["valve", "FLOOD VALVE", Vector3(-0.80, 1.55, 0.54)],
	["fill", "STANDPIPE HOSE", Vector3(-0.98, 1.42, 0.96)],
	["blade", "BLADE WHEEL", Vector3(-0.47, 1.50, 0.54)],
	["wash", "WASH PUMP", Vector3(-0.16, 1.55, 0.54)],
	["plunger", "AUGER PLUNGER", Vector3(-0.02, 1.48, 0.62)],
	["conditioner", "CONDITIONER", Vector3(0.06, 1.55, 0.86)],
	["towel", "TOWEL", Vector3(0.06, 1.42, 1.04)],
]
const VALVE_STEP := 0.05
const WHEEL_STEP := 0.125  # turns of the blade wheel a notch

var run: ResurfaceRun
var ap: ResurfaceAutopilot
var autopilot := false
var preview := ""
var ice: IceSlab            # the sim's (the run works on a copy)
var doris_sim: ResurfacerSim
var body: Node3D
var cockpit: Node3D
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
var _bin_level: MeshInstance3D
var _earl := false
var _hint_timer := 0.0


func _build() -> void:
	title = "DORIS"
	environment(Color("0d0f14"), 0.4)
	body = Node3D.new()
	body.name = "Doris"
	add_child(body)
	var model := MeshInstance3D.new()
	model.mesh = Props.mesh("resurfacer", Wear.WORN)
	body.add_child(model)
	_build_cockpit()
	_build_bay_bits()
	_build_ui()


## The console, the levers and the wheel, and the bin window in the tank wall.
func _build_cockpit() -> void:
	cockpit = Node3D.new()
	cockpit.name = "Cockpit"
	cockpit.position = COCKPIT_AT
	body.add_child(cockpit)
	var steel := Color("5b6066")
	var dark := Color("26282c")
	# a console across the front of the seat, on the snow tank's back wall
	slab(Vector3(1.1, 0.08, 0.34), Vector3(-0.47, 1.40, 0.52), dark, 0.0, cockpit)
	slab(Vector3(1.1, 0.30, 0.04), Vector3(-0.47, 1.27, 0.32), dark, 0.0, cockpit)
	# side boxes for the levers
	slab(Vector3(0.14, 0.5, 0.6), Vector3(-1.0, 1.18, 0.8), dark, 0.0, cockpit)
	slab(Vector3(0.14, 0.42, 0.6), Vector3(0.08, 1.14, 0.9), dark, 0.0, cockpit)
	for c in CONTROLS:
		var id: String = c[0]
		var p: Vector3 = c[2]
		_ctrl_pos[id] = p + COCKPIT_AT
		var pivot := Node3D.new()
		pivot.position = p - Vector3(0, 0.08, 0)
		cockpit.add_child(pivot)
		_parts[id] = pivot
		match id:
			"blade":
				# the hand wheel on its column, and its spokes
				var col := slab(Vector3(0.05, 0.12, 0.05), Vector3(0, 0.0, 0), steel, 0.0, pivot)
				col.position = Vector3(0, 0.0, 0)
				# the rim: sixteen blocks round, the voxel way
				for k in 16:
					var a := k * TAU / 16.0
					var seg := slab(Vector3(0.045, 0.022, 0.022), Vector3(cos(a) * 0.112, 0.08, sin(a) * 0.112), Color("a33a2a"), 0.0, pivot)
					seg.rotation.y = -a + PI * 0.5
				for k in 3:
					var sp := slab(Vector3(0.21, 0.015, 0.02), Vector3(0, 0.08, 0), steel, 0.0, pivot)
					sp.rotation.y = k * PI / 3.0
				var knob := slab(Vector3(0.025, 0.06, 0.025), Vector3(0.11, 0.12, 0), Color("1d1e21"), 0.0, pivot)
				knob.name = "Knob"
			"wash":
				slab(Vector3(0.10, 0.03, 0.08), Vector3(0, 0.0, 0), Color("1d1e21"), 0.0, pivot)
				var t := slab(Vector3(0.02, 0.07, 0.02), Vector3(0, 0.04, 0), Color("c9c5bc"), 0.0, pivot)
				t.name = "Toggle"
			"plunger":
				slab(Vector3(0.04, 0.14, 0.04), Vector3(0, 0.02, 0), steel, 0.0, pivot)
				slab(Vector3(0.07, 0.03, 0.07), Vector3(0, 0.1, 0), Color("b8312f"), 0.0, pivot)
			"fill":
				slab(Vector3(0.08, 0.08, 0.08), Vector3(0, 0.0, 0), Color("2f5eb0"), 0.0, pivot)
			_:
				# a lever on a pivot, knob on top
				var arm := slab(Vector3(0.025, 0.24, 0.025), Vector3(0, 0.12, 0), steel, 0.0, pivot)
				arm.name = "Arm"
				var col2 := {"valve": Color("2f5eb0"), "dump": Color("d4a83a"), "conditioner": Color("b8312f"), "towel": Color("e8e4da")}
				slab(Vector3(0.05, 0.05, 0.05), Vector3(0, 0.25, 0), col2.get(id, Color.BLACK), 0.0, pivot)
		# a stencilled label under each
		var l := Label3D.new()
		l.text = str(c[1])
		l.font = RinkOS.PIXEL_FONT
		l.font_size = 16
		l.pixel_size = 0.0011
		l.modulate = Color("e8e4da")
		l.shaded = false
		l.double_sided = true
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.position = p + Vector3(0, -0.13, 0.04)
		l.rotation.x = -0.5
		cockpit.add_child(l)
	# the bin window: a pane in the tank wall with the snow level behind it
	slab(Vector3(0.36, 0.26, 0.02), Vector3(0.24, 1.50, 0.34), Color("1d1e21"), 0.0, cockpit)
	var glass := slab(Vector3(0.30, 0.20, 0.01), Vector3(0.24, 1.50, 0.355), Color("394a5a"), 0.0, cockpit)
	glass.name = "BinWindow"
	_bin_level = slab(Vector3(0.28, 0.18, 0.005), Vector3(0.24, 1.42, 0.362), Color("eef3f6"), 0.2, cockpit)
	var bl := Label3D.new()
	bl.text = "SNOW TANK"
	bl.font = RinkOS.PIXEL_FONT
	bl.font_size = 16
	bl.pixel_size = 0.0011
	bl.modulate = Color("d4a83a")
	bl.shaded = false
	bl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bl.position = Vector3(0.24, 1.66, 0.36)
	cockpit.add_child(bl)
	# the gauge cluster: a speedo and the two tank needles on the dash
	var dash := Label3D.new()
	dash.name = "Dash"
	dash.font = RinkOS.TERM_FONT
	dash.font_size = 32
	dash.pixel_size = 0.0012
	dash.modulate = RinkOS.READOUT
	dash.shaded = false
	dash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dash.position = Vector3(-0.47, 1.28, 0.345)
	cockpit.add_child(dash)


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
	_ly = 0.05
	_lp = -0.78
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
	var throttle := clampf(f.move.y, -1.0, 1.0)
	var brake := f.brake if not _pad() else 0.0
	if throttle < -0.05 and run.speed > 0.2:
		brake = maxf(brake, -throttle)  # pulling back on a moving machine brakes first
		throttle = 0.0
	run.step(dt, throttle, clampf(f.move.x, -1.0, 1.0), brake)
	_after_step(dt)
	if step_id() == "park" and run.in_bay() and absf(run.speed) < 0.05 and f.interact_pressed and focus == "":
		_complete("")


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
	var ids: Array = []
	for c in CONTROLS:
		ids.append(c[0])
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
	_on_control(id)


func _on_control(id: String) -> void:
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
			_say_once("on_ice", "Gus: Valve to sixty-five. Blade two turns down, a sixteenth. Wash on, conditioner down, rag down.")
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
		_say_once("start", "Gus: First thing, water. Pull her up to the standpipe and open the hose, that blue box on your left.")
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
	if run.cond_down and run.on_ice() and run.blade_mm > 0.0 and absf(run.speed) > 0.1:
		blade_scrape.emit(run.blade_quality, run.skipping)
	if run.flood_rate > 0.0:
		flood_flow.emit(run.flood_rate, run.flood_state)


func _update_steps() -> void:
	var s := step
	if s == 0 and (run.flood_l >= ResurfacerSim.FLOOD_TANK_L * 0.95 or run.on_ice()):
		s = 1
	if s == 1 and run.on_ice():
		s = 2
	if s == 2 and run.cond_down and run.flood_valve > 0.0 and run.blade_mm > 0.0:
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
	if run == null:
		return
	var lever := func(id: String, v: float) -> void:
		var p: Node3D = _parts.get(id)
		if p:
			p.rotation.x = lerpf(0.5, -0.5, clampf(v, 0.0, 1.0))
	lever.call("valve", run.flood_valve)
	lever.call("conditioner", 1.0 if run.cond_down else 0.0)
	lever.call("towel", 1.0 if run.towel_down else 0.0)
	lever.call("dump", 1.0 if run.dump else 0.0)
	var w: Node3D = _parts.get("blade")
	if w:
		w.rotation.y = -run.blade_mm / ResurfacerSim.WHEEL_MM_PER_TURN * TAU
	var t: Node3D = _parts.get("wash")
	if t:
		t.rotation.z = -0.5 if run.wash_on else 0.5
	var pl: Node3D = _parts.get("plunger")
	if pl:
		pl.position.y = (_ctrl_pos["plunger"] as Vector3).y - COCKPIT_AT.y - 0.08 - (0.06 if run.plunger else 0.0)
	if _bin_level:
		var k := clampf(run.bin_fill(), 0.0, 1.0)
		_bin_level.scale = Vector3(1.0, maxf(k, 0.01), 1.0)
		_bin_level.position.y = 1.42 - 0.09 + 0.09 * k
	var dash := cockpit.get_node_or_null("Dash") as Label3D
	if dash:
		dash.text = "%4.1f KM/H   FLOOD %4d L   WASH %3d L" % [absf(run.speed) * 3.6, roundi(run.flood_l), roundi(run.wash_l)]


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
	out.append("[%s]COND %s   RAG %s   WATER %s[/color]" % [RinkOS.bb(RinkOS.DIM), "DOWN" if run.cond_down else "up",
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
				"out": "Out through the gate. %s/%s throttle, %s/%s steer, %s brake." % [RinkOS.key("W"), RinkOS.key("S"), RinkOS.key("A"), RinkOS.key("D"), RinkOS.key("SPACE")],
				"set": "Set her up: conditioner and rag down, valve open, blade two turns. Look at a control and use the wheel.",
				"cut": "Two laps round the boards, down the middle, then the loops out to the laps.",
				"home": "Water off, conditioner up. Back to the bay and dump at the pit.",
				"park": "Parked? %s to switch her off and finish." % RinkOS.key("E")}.get(s, "")
		if _hint_timer <= 0.0:
			hint = "%s adjust   %s toggle   %s leave" % [RinkOS.key("WHEEL"), RinkOS.key("E"), RinkOS.key("X")]


## The centred tooltip for control `id`.
func control_tip(id: String) -> String:
	var v := ""
	match id:
		"valve":
			v = "%d%%   wheel: open / close" % roundi(run.flood_valve * 100.0)
		"blade":
			v = "%s   wheel: down / up" % blade_text(run.blade_mm)
		"wash":
			v = ("ON" if run.wash_on else "OFF") + "   E: switch"
		"conditioner":
			v = ("DOWN" if run.cond_down else "UP") + "   E: lower / raise"
		"towel":
			v = ("DOWN" if run.towel_down else "UP") + "   E: lower / raise"
		"dump":
			v = "%.1f m3 in the tank   E: dump at the pit" % run.bin_m3
		"plunger":
			v = ("HELD" if run.plunger else "-") + "   E: hold, conditioner up"
		"fill":
			v = ("OPEN" if run.fill else "SHUT") + ("" if run.at_standpipe() else "   (park by the standpipe)")
	var name := ""
	for c in CONTROLS:
		if c[0] == id:
			name = c[1]
	return "%s\n%s" % [name, v]


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
