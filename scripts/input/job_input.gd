class_name JobInput
extends Node
## Reads the devices for the rink jobs (RINK_SIM 4.1 verbs) into one
## device-neutral Frame, the way PlayerInput does for hockey. The job scenes
## own what the frame does: they call poll(dt, context) once a tick and feed
## the frame to the verb models in scripts/input/jobs/ (Fastener,
## TorqueWrench, HandPump) and to Doris or the walker.
##
## Contexts:
##   FOOT   walking the rink: move, look, run, interact (doors, job spots)
##   BENCH  hands on a part: look until you grab; while grab is held the
##          mouse / right stick work the tool instead (turn, pump)
##   DRIVE  Doris: steer + throttle, brake, blade and water levers, look
##
##                 keyboard + mouse              gamepad
##   move          WASD                          left stick
##   look          mouse                         right stick
##   run           Shift                         L3
##   interact      E                             A
##   back / drop   X                             B
##   grab          LMB (hold)                    RT (hold)
##   turn          wheel, or drag sideways       circle the right stick, or
##                 while grabbing                LB / RB a step at a time
##   pump          drag up and down while        right stick up and down
##                 grabbing                      while grabbing
##   drive         W/S throttle, A/D steer,      left stick, LT brake,
##                 Space brake, Q blade, F water LB blade, RB water

enum Context { FOOT, BENCH, DRIVE }

class Frame:
	var move := Vector2.ZERO       # x right, y forward; DRIVE: x steer, y throttle (-1 reverse)
	var look := Vector2.ZERO       # radians this tick: x yaw (right +), y pitch (up +)
	var run := false
	var interact_pressed := false
	var back_pressed := false
	var grab := 0.0                # 0..1, analog on a trigger
	var grab_pressed := false
	var grab_released := false
	var turn := 0.0                # revolutions this tick; + is clockwise (tightens)
	var pump := 0.0                # pump handle position, 0 down .. 1 up
	var brake := 0.0
	var blade_lever_pressed := false
	var water_lever_pressed := false

## Look speed: radians per pixel of mouse, radians per second at full stick.
var mouse_look := 0.0025
var stick_look := 2.6
## Turn: one wheel notch or bumper press, and revolutions per pixel of
## sideways drag (a 150 px drag is a quarter turn).
const TURN_STEP := 1.0 / 12.0
var mouse_turn := 1.0 / 600.0
## Pump handle travel per pixel of vertical drag (200 px = a full stroke).
var mouse_pump := 1.0 / 200.0
## The right stick only turns once it's pushed out this far (circling).
const STICK_TURN_RADIUS := 0.6

var frame := Frame.new()
## Tests drive the jobs instead of the devices: Callable(frame, dt, context).
var scripted := Callable()

var _mouse := Vector2.ZERO        # mouse motion since the last poll
var _wheel := 0                   # wheel notches since the last poll (+ = down = clockwise)
var _pump := 1.0
var _stick_ang := NAN
var _prev_grab := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += event.relative
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel += 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel -= 1


## Samples the devices once per physics tick.
func poll(dt: float, context: Context) -> Frame:
	var f := Frame.new()
	if scripted.is_valid():
		scripted.call(f, dt, context)
		_finish(f)
		return f
	# looked up at runtime: `--script` tests have no autoloads
	var setup := get_node_or_null(^"/root/InputSetup")
	var pad: bool = setup != null and setup.get("device") == 1   # InputSetup.Device.PAD
	f.move = Input.get_vector("move_left", "move_right", "move_down", "move_up", 0.15)
	f.run = Input.is_action_pressed("job_run")
	f.interact_pressed = Input.is_action_just_pressed("job_interact")
	f.back_pressed = Input.is_action_just_pressed("job_back")
	f.grab = Input.get_action_strength("job_grab")
	var rs := Input.get_vector("stick_left", "stick_right", "stick_down", "stick_up", 0.15)
	var working := context == Context.BENCH and f.grab > 0.5

	if working:
		# hands on the tool: the mouse and right stick turn or pump
		f.turn = _mouse.x * mouse_turn + _wheel * TURN_STEP + _stick_circle(rs)
		_pump = clampf(_pump - _mouse.y * mouse_pump, 0.0, 1.0)
		if pad and rs.length() > 0.2:
			_pump = 0.5 + 0.5 * rs.y
	else:
		_stick_ang = NAN
		f.look = Vector2(_mouse.x, -_mouse.y) * mouse_look + rs * stick_look * dt
		if context != Context.DRIVE:
			f.turn = _wheel * TURN_STEP
	if context == Context.BENCH:
		# bumpers step the turn (the wheel shares these actions but is counted
		# in _input, so only the pad's presses are read here)
		if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) and Input.is_action_just_pressed("job_turn_cw"):
			f.turn += TURN_STEP
		if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) and Input.is_action_just_pressed("job_turn_ccw"):
			f.turn -= TURN_STEP
	f.pump = _pump
	if context == Context.DRIVE:
		f.brake = Input.get_action_strength("drive_brake")
		f.blade_lever_pressed = Input.is_action_just_pressed("drive_blade")
		f.water_lever_pressed = Input.is_action_just_pressed("drive_water")
		f.turn = 0.0
	_mouse = Vector2.ZERO
	_wheel = 0
	_finish(f)
	return f


func _finish(f: Frame) -> void:
	var held := f.grab > 0.5
	f.grab_pressed = held and not _prev_grab
	f.grab_released = _prev_grab and not held
	_prev_grab = held
	frame = f


## Revolutions turned by circling the right stick since the last tick:
## clockwise (as seen on the screen) tightens.
func _stick_circle(rs: Vector2) -> float:
	if rs.length() < STICK_TURN_RADIUS:
		_stick_ang = NAN
		return 0.0
	var a := atan2(rs.y, rs.x)
	var d := 0.0
	if not is_nan(_stick_ang):
		d = -wrapf(a - _stick_ang, -PI, PI) / TAU
	_stick_ang = a
	return d
