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
##
## Keyboard + mouse: the mouse drives a virtual right stick (captured cursor).
##   WASD skate   Shift dash   Space stop   RMB lift   LMB tilt   E pass
##   F check      [ ] mouse sensitivity     Esc free the cursor

class Frame:
	var move := Vector2.ZERO    # screen space, length <= 1
	var stick := Vector2.ZERO   # screen space, length <= 1
	var dash := false           # pressed this frame
	var stop := false
	var lift := 0.0             # 0..1
	var tilt := 0.0             # 0..1
	var pass_pressed := false
	var check_pressed := false

## Virtual stick travel per pixel of mouse motion.
var mouse_sensitivity := 0.006
## How fast the virtual stick drifts back to centre once the mouse rests
## (per second). 0 keeps it wherever you left it, like a real stick held still.
var mouse_recenter := 1.2
## LMB has no analog travel, so the tilt eases in while it's held: a tap
## gives a little lift, a hold gives full tilt.
var kbm_tilt_ramp := 0.25

var frame := Frame.new()
## Tests can drive the human instead of the devices: Callable(frame, dt)
## fills in the frame (see tests/controls_test.gd).
var scripted := Callable()
var _vstick := Vector2.ZERO
var _mouse_idle := 0.0
var _kbm_tilt := 0.0
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		scripted.call(f, dt)
		f.stick = f.stick.limit_length(1.0)
		return f
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	f.move = Vector2(mv.x, -mv.y)
	f.dash = Input.is_action_just_pressed("dash")
	f.stop = Input.is_action_pressed("stop")
	f.pass_pressed = Input.is_action_just_pressed("pass")
	f.check_pressed = Input.is_action_just_pressed("check")
	f.lift = Input.get_action_strength("lift")
	if InputSetup.device == InputSetup.Device.PAD:
		var rs := Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down", 0.15)
		f.stick = Vector2(rs.x, -rs.y)
		f.tilt = Input.get_action_strength("tilt")
		_vstick = Vector2.ZERO
	else:
		_mouse_idle += dt
		if _mouse_idle > 0.2 and mouse_recenter > 0.0:
			_vstick = _vstick.move_toward(Vector2.ZERO, mouse_recenter * dt)
		f.stick = _vstick
		var held := Input.is_action_pressed("tilt")
		_kbm_tilt = move_toward(_kbm_tilt, 1.0 if held else 0.0, dt / kbm_tilt_ramp if held else dt * 8.0)
		f.tilt = _kbm_tilt
	return f
