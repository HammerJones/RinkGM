class_name IceHand
extends JobScene
## The hand work on the ice (docs/world/ICE.md 5), walked from behind:
##
## target "ice_hose"     the big hose off the wall spool in the bay: 61 m of
##                       1.5 in hose, hot water, for heavy floods only where
##                       they're needed. E opens and shuts the nozzle, the
##                       wheel (or bumpers) sets the flow. The water runs off
##                       downhill and freezes like any flood.
## target "ice_edger"    the walk-behind edger for the strip along the boards
##                       and high corners: E starts and stops the disc, the
##                       wheel sets the depth. It spits its snow a pace out,
##                       where Doris has to pick it up.
## target "ice_chipper"  the long-handled chipper for the slush ridge that
##                       builds along the boards: E swings it, dragging the
##                       ridge out where the blade can reach it.
##
## Move walks (camera relative), mouse or right stick looks round, X finishes.
## The work happens on a copy of the sim's ice that goes back as ice_state.

signal hose(on: bool)
signal hose_flow(rate: float)          # 0..1 of the nozzle wide open
signal edger(on: bool, load: float)    # load 0..1: how hard the disc is biting
signal chipper(hit: float)             # litres of slush the swing moved

## The wall spool in the bay and the gate the hose runs out through.
const SPOOL := Vector2(36.2, 4.55)
const GATE := Vector2(Rink.HALF_L, 0.0)
const HOSE_M := 61.0                  # 200 ft
const HOSE_LPS := 1.6                 # 1.5 in hose wide open off the hot tap, ~95 L/min
const WALK := 1.3                     # m/s on ice in boots
const WALK_EDGER := 0.6               # pushing the edger
const EDGER_MM := [1.0, 1.6, 2.4, 3.2, 4.8]   # 1/25 to 3/16 in a pass
const CHIP_REACH := 0.6
const CHIP_COOLDOWN := 0.55

var mode := "hose"
var ice: IceSlab
var pos := Vector2(28.4, 0.0)
var heading := PI                     # facing up the ice, toward -x
var on := false
var flow := 0.6
var depth_idx := 1
var water_c := IceSlab.FLOOD_TEMP_C
var litres := 0.0
var cut_l := 0.0
var moved_l := 0.0
var swings := 0
var time_s := 0.0
var ridge_l := 0.0
var ridge_l0 := 0.0
var lip0 := 0.0
var preview := ""

var _cy := PI * 0.5                   # camera yaw round the worker
var _cp := 0.42
var _worker: Node3D
var _tool: Node3D
var _hose_mesh: MeshInstance3D
var _hose_im: ImmediateMesh
var _view: IceView
var _view_was: IceSlab
var _freeze_t := 0.0
var _settle_t := 0.0
var _ridge_t := 0.0
var _swing_t := 0.0
var _sound_t := 0.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	title = "ICE"
	environment(Color("101318"), 0.45)


func begin(ctx: Dictionary) -> void:
	preview = str(ctx.get("preview", ""))
	_rng.seed = 7731
	var sm: Object = ctx.get("sim", null) as Object
	var src: IceSlab = sm.get("ice") as IceSlab if sm else null
	if src == null:
		src = ctx.get("ice") as IceSlab
	ice = src.copy() if src else IceSlab.create_millbrook()
	ice.flush()
	var d: Variant = sm.get("doris") if sm else null
	if d is ResurfacerSim:
		water_c = (d as ResurfacerSim).flood_temp_c
	var tg := str(ctx.get("target", ""))
	mode = str({"ice_hose": "hose", "ice_edger": "edger", "ice_chipper": "chipper"}.get(tg,
		{"hose_flood": "hose", "edge_ice": "edger", "chip_ice": "chipper"}.get(str(ctx.get("job", "")), "hose")))
	if preview != "":
		mode = preview
	ridge_l0 = ice.board_ridge_litres()
	ridge_l = ridge_l0
	lip0 = ice.edge_lip_mm()
	super.begin(ctx)
	_world()
	_build_worker()
	_sync_worker()
	_follow(true)
	if preview != "":
		_preview()


func _setup() -> void:
	match mode:
		"hose":
			steps = [{"id": "work", "text": "Flood the low spots with the hose"}, {"id": "done", "text": "Reel it back in"}]
			title = "BIG HOSE"
		"edger":
			steps = [{"id": "work", "text": "Edge the high strip along the boards"}, {"id": "done", "text": "Park the edger"}]
			title = "EDGER"
		_:
			steps = [{"id": "work", "text": "Chip the ridge off the boards"}, {"id": "done", "text": "Hang the chipper up"}]
			title = "ICE CHIPPER"


func _enter_step(_i: int) -> void:
	_prompt()


func _prompt() -> void:
	hint = "%s walk   %s %s   %s %s   %s finish" % [RinkOS.key("WASD"), RinkOS.key("E"),
		{"hose": "nozzle", "edger": "start/stop", "chipper": "swing"}.get(mode, "use"),
		RinkOS.key("WHEEL"), {"hose": "flow", "edger": "depth", "chipper": "-"}.get(mode, ""), RinkOS.key("X")]
	match mode:
		"hose":
			prompt = "Hose %s at %d%%. Hot water, %.0f C. Lay it where the survey said low and let it run off." % ["open" if on else "shut", roundi(flow * 100.0), water_c]
		"edger":
			prompt = "Edger %s, cutting %s a pass. Walk it along the boards where the strip's high." % ["running" if on else "stopped", _depth_text()]
		_:
			prompt = "Swing it at the ridge against the boards. %.0f L of slush still along them." % ridge_l


func _depth_text() -> String:
	var mm: float = EDGER_MM[depth_idx]
	return "%.1f mm (%d/64 in)" % [mm, roundi(mm / 25.4 * 64.0)]


# ---------------------------------------------------------------- the world

func _world() -> void:
	var views: Array = []
	if is_inside_tree():
		for v: Node in get_tree().get_nodes_in_group("ice_view"):
			if not v.is_queued_for_deletion():
				views.append(v)
	if not views.is_empty():
		_view = views[0] as IceView
		_view_was = _view.ice
		_view.ice = ice
	else:
		var rink := Rink.new()
		add_child(rink)
		_view = IceView.attach(rink, ice)
		slab(Vector3(ResurfaceRun.BAY_X1 - ResurfaceRun.BAY_X0 + 3.0, 0.04, ResurfaceRun.BAY_HALF * 2.0),
			Vector3((ResurfaceRun.BAY_X0 + ResurfaceRun.BAY_X1) * 0.5 - 1.0, -0.02, 0.0), Color("6f6c66"))
		light(Vector3(0, 9, 0), 2.0, 40.0, Color(1, 0.97, 0.9), false)
		light(Vector3(-20, 9, 0), 1.6, 30.0, Color(1, 0.97, 0.9), false)
		light(Vector3(20, 9, 0), 1.6, 30.0, Color(1, 0.97, 0.9), false)
	# the spool on the bay wall
	var red := Color("b8312f")
	var reel := slab(Vector3(0.7, 0.7, 0.32), Vector3(SPOOL.x, 1.2, SPOOL.y), red)
	reel.name = "Spool"
	slab(Vector3(0.5, 0.5, 0.34), Vector3(SPOOL.x, 1.2, SPOOL.y), Color("2a2c2e"))
	if mode == "hose" and DisplayServer.get_name() != "headless":  # the dummy renderer has no immediate meshes
		_hose_im = ImmediateMesh.new()
		_hose_mesh = MeshInstance3D.new()
		_hose_mesh.mesh = _hose_im
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("c8a020")
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.7
		_hose_mesh.material_override = m
		_hose_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_hose_mesh)


func _build_worker() -> void:
	_worker = Node3D.new()
	_worker.name = "Worker"
	add_child(_worker)
	slab(Vector3(0.36, 0.85, 0.24), Vector3(0, 0.95, 0), Color("2c4a7a"), 0.0, _worker)   # jacket
	slab(Vector3(0.3, 0.55, 0.2), Vector3(0, 0.28, 0), Color("2a2a2e"), 0.0, _worker)     # legs
	slab(Vector3(0.2, 0.22, 0.2), Vector3(0, 1.5, 0), Color("d9b08c"), 0.0, _worker)      # head
	slab(Vector3(0.22, 0.08, 0.22), Vector3(0, 1.63, 0), Color("c8562a"), 0.0, _worker)   # toque
	_tool = Node3D.new()
	_worker.add_child(_tool)
	match mode:
		"hose":
			slab(Vector3(0.06, 0.06, 0.5), Vector3(0.12, 0.95, -0.3), Color("c8a020"), 0.0, _tool)
			slab(Vector3(0.08, 0.08, 0.14), Vector3(0.12, 0.95, -0.6), Color("8a8f94"), 0.0, _tool)
		"edger":
			slab(Vector3(0.62, 0.32, 0.5), Vector3(0, 0.2, -0.75), Color("c43c2a"), 0.0, _tool)
			slab(Vector3(0.3, 0.26, 0.3), Vector3(0, 0.48, -0.75), Color("3a3c3e"), 0.0, _tool)
			slab(Vector3(0.04, 0.04, 0.7), Vector3(-0.18, 0.8, -0.35), Color("8a8f94"), 0.0, _tool)
			slab(Vector3(0.04, 0.04, 0.7), Vector3(0.18, 0.8, -0.35), Color("8a8f94"), 0.0, _tool)
			slab(Vector3(0.44, 0.04, 0.04), Vector3(0, 1.0, -0.05), Color("2a2a2e"), 0.0, _tool)
		_:
			slab(Vector3(0.04, 0.04, 1.6), Vector3(0.15, 0.6, -0.65), Color("8a6a40"), 0.0, _tool)
			slab(Vector3(0.18, 0.02, 0.14), Vector3(0.15, 0.06, -1.42), Color("8a8f94"), 0.0, _tool)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_view) and _view_was != null:
			_view.ice = _view_was
			_view_was = null
	super._notification(what)


# ---------------------------------------------------------------- the loop

func tick(dt: float) -> void:
	if not _started or closed:
		return
	var f := input.poll(dt, JobInput.Context.FOOT)
	if complete:
		if f.interact_pressed or f.back_pressed:
			_close(result)
		_follow(false, dt)
		_refresh()
		return
	if f.back_pressed:
		_set_on(false)
		if litres <= 0.0 and cut_l <= 0.0 and swings == 0:
			_close({"cancelled": true})
			return
		advance()
		advance(_summary_line())
		_refresh()
		return
	_cy -= f.look.x
	_cp = clampf(_cp + f.look.y, 0.15, 1.1)
	if f.turn != 0.0:
		_adjust(signf(f.turn))
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) and Input.is_action_just_pressed("job_turn_cw"):
		_adjust(1.0)
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) and Input.is_action_just_pressed("job_turn_ccw"):
		_adjust(-1.0)
	if f.interact_pressed:
		_use()
	step_work(dt, f.move)
	_follow(false, dt)
	_refresh()


## Moves the worker and runs the tool for `dt`. Tests drive this directly.
func step_work(dt: float, move: Vector2) -> void:
	time_s += dt
	var spd := WALK_EDGER if mode == "edger" and on else WALK
	var fwd := Vector2(-cos(_cy), -sin(_cy))   # camera-relative: up the screen
	var right := Vector2(-fwd.y, fwd.x)
	var v := (fwd * move.y + right * move.x)
	if v.length() > 1.0:
		v = v.normalized()
	var step_d := v * spd * dt
	var np := pos + step_d
	var conf: Array = Rink.confine(Vector3(np.x, 0, np.y), 0.35)
	var cp: Vector3 = conf[0]
	np = Vector2(cp.x, cp.z)
	if mode == "hose" and hose_out(np) > HOSE_M:
		np = pos  # at the end of the hose
	var moved := np.distance_to(pos)
	pos = np
	if v.length() > 0.05:
		heading = lerp_angle(heading, atan2(v.y, v.x), clampf(dt * 8.0, 0.0, 1.0))
	match mode:
		"hose":
			if on:
				var l := HOSE_LPS * flow * dt
				var at := pos + Vector2(cos(heading), sin(heading)) * (0.9 + 2.2 * flow)
				litres += ice.hose_at(at, l, water_c, 0.35 + 0.5 * flow)
			_settle_t += dt
			if _settle_t >= 0.5:
				_settle_t = 0.0
				ice.settle(1)
		"edger":
			if on:
				var mm: float = EDGER_MM[depth_idx]
				var throw := -Rink.board_normal(pos)
				var c := ice.edge_at(pos + Vector2(cos(heading), sin(heading)) * 0.75, mm * clampf(moved / 0.5, 0.0, 1.0), 0.8 + 0.2 * skill, throw)
				cut_l += c
				if _sound_t <= 0.0:
					edger.emit(true, clampf(c / maxf(dt, 0.001) / 0.4, 0.0, 1.0))
		_:
			pass
	_swing_t = maxf(_swing_t - dt, 0.0)
	_freeze_t += dt
	if _freeze_t >= 2.0:
		ice.freeze(_freeze_t)
		_freeze_t = 0.0
	_sound_t -= dt
	if _sound_t <= 0.0:
		_sound_t = 0.25
		if mode == "hose":
			hose_flow.emit(flow if on else 0.0)
	_ridge_t -= dt
	if _ridge_t <= 0.0 and mode == "chipper":
		_ridge_t = 1.0
		ridge_l = ice.board_ridge_litres()
	_sync_worker()


## How much hose is off the spool to reach `p`: to the gate, then out.
func hose_out(p: Vector2) -> float:
	return SPOOL.distance_to(GATE + Vector2(1.0, 0.0)) + (GATE + Vector2(-0.5, 0.0)).distance_to(p)


func _adjust(d: float) -> void:
	match mode:
		"hose":
			flow = clampf(snappedf(flow + 0.1 * d, 0.1), 0.1, 1.0)
		"edger":
			depth_idx = clampi(depth_idx + int(d), 0, EDGER_MM.size() - 1)
	_prompt()


func _use() -> void:
	match mode:
		"chipper":
			swing()
		_:
			_set_on(not on)
	_prompt()


func _set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	match mode:
		"hose":
			hose.emit(on)
			hose_flow.emit(flow if on else 0.0)
		"edger":
			edger.emit(on, 0.0)


## One swing of the chipper ahead of the worker. Returns litres moved.
func swing() -> float:
	if _swing_t > 0.0:
		return 0.0
	_swing_t = CHIP_COOLDOWN
	swings += 1
	var at := pos + Vector2(cos(heading), sin(heading)) * CHIP_REACH
	var m := ice.chip_at(at, 0.75, 0.8 + 0.15 * skill)
	moved_l += m
	chipper.emit(m)
	return m


func _summary_line() -> String:
	match mode:
		"hose":
			return "Laid %.0f L of %.0f C water off the big hose." % [litres, water_c]
		"edger":
			return "Edged off %.1f L of ice; the strip's %.1f mm over the middle now." % [cut_l, ice.edge_lip_mm()]
		_:
			return "Chipped %.0f L of slush off the boards in %d swings." % [moved_l, swings]


func _result() -> Dictionary:
	_set_on(false)
	ice.resync()
	var q := 0.85 + 0.15 * skill
	if mode == "chipper" and ridge_l0 > 0.0:
		q = clampf(1.0 - ice.board_ridge_litres() / ridge_l0, 0.0, 1.0)
	return {"quality": q, "ice_state": ice, "litres": litres, "temp_c": water_c, "minutes": time_s / 60.0,
		"cut_l": cut_l, "moved_l": moved_l, "swings": swings, "mode": mode}


func _tool_lines() -> PackedStringArray:
	var out := PackedStringArray()
	match mode:
		"hose":
			out.append(meter_line("FLOW", flow if on else 0.0, RinkOS.READOUT, "%d%% %s" % [roundi(flow * 100.0), "OPEN" if on else "SHUT"]))
			out.append(meter_line("HOSE", hose_out(pos) / HOSE_M, RinkOS.ALERT if hose_out(pos) > HOSE_M - 3.0 else RinkOS.READOUT, "%.0f / %.0f m" % [hose_out(pos), HOSE_M]))
			out.append("LAID %.0f L  %.0f C" % [litres, water_c])
		"edger":
			out.append(meter_line("DEPTH", float(depth_idx + 1) / EDGER_MM.size(), RinkOS.READOUT, "%.1f mm" % float(EDGER_MM[depth_idx])))
			out.append("CUT %.1f L  %s" % [cut_l, "RUNNING" if on else "STOPPED"])
			out.append("BOARDS %.0f m off" % maxf(-Rink.sdf(pos), 0.0))
		_:
			out.append(meter_line("RIDGE", ridge_l / maxf(ridge_l0, 1.0), RinkOS.READOUT, "%.0f L" % ridge_l))
			out.append("SWINGS %d  MOVED %.0f L" % [swings, moved_l])
	return out


# ---------------------------------------------------------------- views

func _sync_worker() -> void:
	if _worker == null:
		return
	_worker.position = Vector3(pos.x, 0.0, pos.y)
	# model front is -Z: yaw so -Z points along the heading
	_worker.rotation.y = atan2(-cos(heading), -sin(heading))
	if mode == "chipper" and _tool:
		_tool.rotation.x = 0.5 * (_swing_t / CHIP_COOLDOWN)
	if _hose_im:
		# a flat yellow ribbon from the spool, out the gate, to the nozzle
		var hand := Vector3(pos.x, 0.95, pos.y) + Vector3(cos(heading), 0.0, sin(heading)) * 0.1
		var pts: Array[Vector3] = [Vector3(SPOOL.x, 1.0, SPOOL.y), Vector3(SPOOL.x - 0.3, 0.03, SPOOL.y - 0.4), Vector3(GATE.x + 1.0, 0.03, 0.0),
			Vector3(GATE.x - 0.5, 0.03, 0.0), Vector3(pos.x, 0.03, pos.y), hand]
		_hose_im.clear_surfaces()
		_hose_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var d := b - a
			var side := Vector3(-d.z, 0.0, d.x).normalized() * 0.03 if absf(d.x) + absf(d.z) > 0.01 else Vector3(0.03, 0.0, 0.0)
			for v: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
				_hose_im.surface_set_normal(Vector3.UP)
				_hose_im.surface_add_vertex(v)
		_hose_im.surface_end()


func _follow(snap: bool, _dt := 0.0) -> void:
	var at := Vector3(pos.x, 0.9, pos.y)
	var back := Vector3(cos(_cy), 0.0, sin(_cy))
	var eye := at + back * (4.2 * cos(_cp)) + Vector3.UP * (1.2 + 4.2 * sin(_cp))
	view(eye, at + Vector3.UP * -0.3 - back * 1.5)
	if snap:
		snap_camera()
	else:
		_camera(JobInput.Frame.new(), 1.0 / 60.0)


func _preview() -> void:
	match mode:
		"hose":
			pos = Vector2(22.0, -6.0)
			heading = PI * 0.8
			_set_on(true)
			flow = 0.8
			for i in 300:
				step_work(0.05, Vector2(0.15 * sin(i * 0.05), 0.0))
		"edger":
			pos = Vector2(25.0, -Rink.HALF_W + 0.7)
			heading = PI
			_cy = 0.0
			_set_on(true)
			for i in 200:
				step_work(0.05, Vector2(0.0, 1.0))
			_cy = -0.9
		_:
			pos = Vector2(15.0, Rink.HALF_W - 0.8)
			heading = PI * 0.5
			_cy = -PI * 0.5 + 0.5
			for i in 12:
				_swing_t = 0.0
				swing()
				pos.x += 1.2
				step_work(0.6, Vector2(0.0, 0.0))
	ridge_l = ice.board_ridge_litres()
	_prompt()
	_follow(true)
