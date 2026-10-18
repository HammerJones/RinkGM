class_name JobAutopilot
extends RefCounted
## Plays a job scene through JobInput.scripted, the way a player would: picks
## tools off the tray, holds grab, turns and pumps. For the tests and the
## preview renders. `sloppy` makes the classic mistakes: a wrench at the
## start of a thread, the oil over the mark, a wrong blade height, pulling on
## past the click.
##
##   var pilot := JobAutopilot.new(scene, false)
##   scene.input.scripted = pilot.drive

var scene: JobScene
var sloppy := false
## Stop driving at this step id (previews hold the scene mid-job there).
var hold_at := ""
## Per-step overrides: step id -> how far into the step to go before holding
## (ticks).
var hold_ticks := 0

var _n := 0
var _step := ""
var _in_step := 0
var _pump := 1.0
var _pump_down := true
var _extra := 0.0
var _bolt := -1
var _release := false


func _init(s: JobScene, sloppy_ := false) -> void:
	scene = s
	sloppy = sloppy_


func drive(f: JobInput.Frame, dt: float, _context: int) -> void:
	_n += 1
	var sid := scene.step_id()
	if sid != _step:
		_step = sid
		_in_step = 0
		_extra = 0.0
		_release = false
	_in_step += 1
	if not hold_at.is_empty() and sid == hold_at and _in_step > hold_ticks:
		f.grab = 1.0 if _holding_grab(sid) else 0.0
		f.pump = _pump
		return
	if sid == "done":
		_press(f)
		return
	match scene.job:
		"compressor_oil_change":
			_oil(f, dt, sid)
		"blade_change":
			_blade(f, dt, sid)
		"doris_plugs":
			_plugs(f, dt, sid)


func _holding_grab(sid: String) -> bool:
	return sid in ["fill", "torque", "filter_on", "plug_in", "thread", "in", "out"]


# ---------------------------------------------------------------- verbs

func _press(f: JobInput.Frame) -> void:
	f.interact_pressed = _n % 2 == 0


## Taps move x until the tray has `t` in hand; true once it has.
func _want(f: JobInput.Frame, t: String) -> bool:
	if scene.tool() == t:
		return true
	if _n % 2 == 0:
		f.move.x = 1.0
	return false


## Tightens by hand to hand tight then with `wrench_tool` to `plus` past it;
## sloppy goes straight in with the wrench. Returns true when it's there.
func _plus_turn(f: JobInput.Frame, fs: Fastener, wrench_tool: String) -> bool:
	var past := fs.turns_past_hand_tight()
	var hand_tight := fs.seated() and past >= -0.0005
	var t := wrench_tool if (sloppy or hand_tight) else "hand"
	if not _want(f, t):
		return false
	var left := fs.plus_turns - past if fs.seated() else 1.0
	if fs.seated() and left <= 0.0005:
		return true
	f.grab = 1.0
	f.turn = 0.05 if not fs.seated() else minf(0.02, left if hand_tight else 0.05)
	if not fs.seated() and fs.run + f.turn > fs.thread_turns:
		f.turn = fs.thread_turns - fs.run + 0.0001
	return false


func _loosen(f: JobInput.Frame, t: String) -> void:
	if _want(f, t):
		f.grab = 1.0
		f.turn = -0.05


## Pulls the torque wrench to the click and lets go (sloppy pulls on).
func _torque(f: JobInput.Frame, wrench: TorqueWrench, bolt: int) -> void:
	if bolt != _bolt:
		_bolt = bolt
		_extra = 0.0
		_release = false
	if not _want(f, "torque_wrench"):
		return
	if _release:
		f.grab = 0.0
		_release = false
		return
	f.grab = 1.0
	if wrench.clicked:
		if sloppy and _extra < 0.12:
			f.turn = 0.02
			_extra += 0.02
			return
		f.grab = 0.0
		return
	f.turn = 0.004


# ---------------------------------------------------------------- jobs

func _oil(f: JobInput.Frame, dt: float, sid: String) -> void:
	var s: Variant = scene
	match sid:
		"read", "gasket", "log":
			_press(f)
		"drain":
			_loosen(f, "ratchet")
		"filter_off":
			_loosen(f, "filter_wrench")
		"filter_on":
			if _plus_turn(f, s.filter, "filter_wrench"):
				_press(f)
		"plug_in":
			if _plus_turn(f, s.plug, "ratchet"):
				_press(f)
		"fill":
			var pump: HandPump = s.pump
			var target := pump.target_l + (3.0 if sloppy else 0.0)
			var left := target - pump.litres
			if left <= 0.0005:
				f.grab = 0.0
				f.pump = _pump
				_press(f)
				return
			f.grab = 1.0
			if _pump_down:
				var d := minf(1.6 * dt, minf(_pump, left / pump.stroke_l))
				_pump -= d
				if _pump <= 0.001:
					_pump_down = false
			else:
				_pump = minf(1.0, _pump + 2.5 * dt)
				if _pump >= 1.0:
					_pump_down = true
			f.pump = _pump


func _blade(f: JobInput.Frame, _dt: float, sid: String) -> void:
	var s: Variant = scene
	match sid:
		"prep", "finish":
			_press(f)
		"loosen":
			_loosen(f, "ratchet")
		"out", "in":
			f.grab = 1.0
		"height":
			var hs: PackedFloat32Array = s.heights
			var want := 1.55 if sloppy else 1.0
			for i in 3:
				if absf(hs[i] - want) > 0.0005:
					if scene.selection != i:
						if _n % 2 == 0:
							f.move.x = 1.0
						return
					f.grab = 1.0
					f.turn = clampf((want - hs[i]) / 0.6, -0.05, 0.05)
					return
			_press(f)
		"torque":
			var order: Array = s.TORQUE_ORDER
			var bi: int = s.bolt_idx
			var w: TorqueWrench = s.wrench
			_torque(f, w, int(order[mini(bi, 6)]) + 10 * bi)


func _plugs(f: JobInput.Frame, _dt: float, sid: String) -> void:
	var s: Variant = scene
	match sid:
		"note", "lead", "morning", "start":
			_press(f)
		"find":
			if scene.selection != 2:
				if _n % 2 == 0:
					f.move.x = 1.0
				return
			_press(f)
		"out":
			_loosen(f, "ratchet")
		"drawer":
			if scene.selection_y != 1:
				if _n % 2 == 0:
					f.move.y = -1.0
				return
			_press(f)
		"gap":
			var g: float = s.gap
			if absf(g - 0.035) > 0.00005:
				f.grab = 1.0
				f.turn = clampf((0.035 - g) / 0.010, -0.05, 0.05)
				return
			_press(f)
		"thread":
			if _want(f, "torque_wrench" if sloppy else "hand"):
				f.grab = 1.0
				f.turn = 0.03
		"torque":
			_torque(f, s.wrench, 0)
