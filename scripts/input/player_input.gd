class_name PlayerInput
extends Node
## Reads the human's devices into one device-neutral frame of intent, in
## screen space (x right, y up the screen). HumanController turns it into
## world-space Skater.Controls.
##
## Gamepad (Slapshot Rebound style):
##   left stick  skate              L3  dash          R3  hockey stop
##   right stick the stick blade    LT  lift stick    RT  tilt blade (analog)
##   A / RB      pass, or call for a pass without the puck     B  body check
##   X           turn around (skate backwards / forwards)
##   LB (hold)   look around with the right stick; the blade holds still
##
## Keyboard + mouse (Sean, 19 Oct): the mouse drives a virtual right stick
## (captured cursor); side to side stickhandles. No lift, tilt or stick moves.
##   WASD skate   Shift dash   Space stop   E pass   F check   R turn around
##   LMB (hold) look around, the centre dot aims
##   RMB (hold) draw a shot pattern (ShotPatterns); release to shoot
##   V shot pattern overlay   [ ] mouse sensitivity   Esc free the cursor

class Frame:
	var move := Vector2.ZERO    # screen space, length <= 1
	var stick := Vector2.ZERO   # screen space, length <= 1
	var dash := false           # pressed this frame
	var stop := false
	var lift := 0.0             # 0..1
	var tilt := 0.0             # 0..1
	var pass_pressed := false
	var check_pressed := false
	var turn_pressed := false   # turn around (forwards <-> backwards)
	var looking := false        # free look held: `stick` holds still
	var look := Vector2.ZERO    # radians this tick: x right, y up
	var tracing := false        # RMB held: the mouse draws a shot pattern
	var trace_pos := Vector2.ZERO   # px from where the pattern started, y up
	var trace_done := false     # RMB released this tick: `trace` is the pattern
	var trace: Array = []       # Vector3(x px, y px up, t s)

## Virtual stick travel per pixel of mouse motion.
var mouse_sensitivity := 0.006
## How fast the virtual stick drifts back to centre once the mouse rests
## (per second). 0, the default, keeps it wherever you left it, like a real
## stick held still: inputs are direct, any feel comes from the simulated stick.
var mouse_recenter := 0.0
## Seconds the tilt key takes to ease the tilt in (it has no analog
## travel). 0, the default, is direct: full tilt while held.
var kbm_tilt_ramp := 0.0
## Free look: radians per pixel of mouse, radians per second at full stick.
var mouse_look := 0.004
var stick_look := 2.8

var frame := Frame.new()
## Tests can drive the human instead of the devices: Callable(frame, dt)
## fills in the frame (see tests/controls_test.gd).
var scripted := Callable()
var _vstick := Vector2.ZERO
var _mouse_idle := 0.0
var _kbm_tilt := 0.0
var _look := Vector2.ZERO        # mouse free look since the last poll
var _pad_held := Vector2.ZERO    # the pad stick when free look started
var _trace: Array = []
var _trace_pos := Vector2.ZERO
var _trace_t0 := 0
var _capture := not ("--autoplay" in OS.get_cmdline_user_args()) and DisplayServer.get_name() != "headless"


func _ready() -> void:
	# a pause menu stops the game tree: this node then gets no input, so menu
	# clicks don't recapture the cursor or move the virtual stick
	process_mode = Node.PROCESS_MODE_PAUSABLE
	capture_mouse()


## Takes the cursor back for the virtual stick (the pause menu's Resume calls
## this). The stick restarts from neutral so resuming doesn't flick a shot.
func capture_mouse() -> void:
	_vstick = Vector2.ZERO
	_mouse_idle = 0.0
	if _capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _trace.is_empty():
		# drawing a shot: the stick and the view hold still (in real time, so
		# a slowed clock doesn't change the drawing)
		_trace_pos += Vector2(event.relative.x, -event.relative.y)
		_trace.append(Vector3(_trace_pos.x, _trace_pos.y, (Time.get_ticks_usec() - _trace_t0) / 1e6))
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("free_look"):
		# looking around: the virtual stick stays where it was
		_look += Vector2(event.relative.x, -event.relative.y) * mouse_look
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var d: Vector2 = event.relative * mouse_sensitivity
		_vstick = (_vstick + Vector2(d.x, -d.y)).limit_length(1.0)
		_mouse_idle = 0.0
	elif event is InputEventMouseButton and event.pressed and _capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("sens_up"):
		mouse_sensitivity *= 1.15
	elif event.is_action_pressed("sens_down"):
		mouse_sensitivity /= 1.15


## Samples the devices once per physics tick.
func poll(dt: float) -> Frame:
	var f := frame
	if scripted.is_valid():
		f.move = Vector2.ZERO
		f.stick = Vector2.ZERO
		f.dash = false
		f.stop = false
		f.lift = 0.0
		f.tilt = 0.0
		f.pass_pressed = false
		f.check_pressed = false
		f.turn_pressed = false
		f.looking = false
		f.look = Vector2.ZERO
		f.tracing = false
		f.trace_done = false
		f.trace = []
		scripted.call(f, dt)
		f.stick = f.stick.limit_length(1.0)
		return f
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	f.move = Vector2(mv.x, -mv.y)
	f.dash = Input.is_action_just_pressed("dash")
	f.stop = Input.is_action_pressed("stop")
	f.pass_pressed = Input.is_action_just_pressed("pass")
	f.check_pressed = Input.is_action_just_pressed("check")
	f.turn_pressed = Input.is_action_just_pressed("turn_around")
	f.lift = Input.get_action_strength("lift")
	var was_looking := f.looking
	f.looking = Input.is_action_pressed("free_look")
	f.look = _look
	_look = Vector2.ZERO
	if InputSetup.device == InputSetup.Device.PAD:
		var rs := Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down", 0.15)
		if f.looking:
			# LB held: the right stick looks, the blade stays put
			if not was_looking:
				_pad_held = f.stick
			f.look += Vector2(rs.x, -rs.y) * stick_look * dt
			f.stick = _pad_held
		else:
			f.stick = Vector2(rs.x, -rs.y)
		f.tilt = Input.get_action_strength("tilt")
		_vstick = Vector2.ZERO
	else:
		_mouse_idle += dt
		if _mouse_idle > 0.2 and mouse_recenter > 0.0:
			_vstick = _vstick.move_toward(Vector2.ZERO, mouse_recenter * dt)
		f.stick = _vstick
		f.lift = 0.0
		f.tilt = 0.0
		_poll_trace(f)
	return f


## RMB: start a pattern on the press, hand it over on the release.
func _poll_trace(f: Frame) -> void:
	f.trace_done = false
	var held := Input.is_action_pressed("shot_trace") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if held and _trace.is_empty():
		_trace_t0 = Time.get_ticks_usec()
		_trace_pos = Vector2.ZERO
		_trace = [Vector3.ZERO]
	elif not held and not _trace.is_empty():
		f.trace = _trace
		f.trace_done = true
		_trace = []
	f.tracing = not _trace.is_empty()
	f.trace_pos = _trace_pos if f.tracing else Vector2.ZERO
