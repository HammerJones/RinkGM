extends Node
## Registers the input map in code (keyboard + mouse and gamepad) and tracks
## which device the player touched last, so the mouse's virtual stick and the
## real right stick don't fight each other. See PlayerInput for the scheme.

enum Device { KBM, PAD }

var device := Device.KBM


func _ready() -> void:
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

	# right stick = the stick blade (the mouse drives a virtual right stick)
	_axis("stick_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("stick_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("stick_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("stick_down", JOY_AXIS_RIGHT_Y, 1.0)

	_keys("dash", [KEY_SHIFT])
	_button("dash", JOY_BUTTON_LEFT_STICK)

	_keys("stop", [KEY_SPACE])
	_button("stop", JOY_BUTTON_RIGHT_STICK)

	# gamepad only for now: the keyboard + mouse scheme has no lift or tilt
	_axis("lift", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis("tilt", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	# hold and draw a shot pattern with the mouse (ShotPatterns)
	_mouse("shot_trace", MOUSE_BUTTON_RIGHT)
	# cycle the shot pattern overlay: off, wrist, snap, slap, toe drag
	_keys("shot_overlay", [KEY_V])

	# hold to look around with the mouse / right stick (the stick holds still)
	_mouse("free_look", MOUSE_BUTTON_LEFT)
	_button("free_look", JOY_BUTTON_LEFT_SHOULDER)
	# turn around: skate backwards, again to face forward
	_keys("turn_around", [KEY_R])
	_button("turn_around", JOY_BUTTON_X)

	_keys("pass", [KEY_E])
	_button("pass", JOY_BUTTON_A)
	_button("pass", JOY_BUTTON_RIGHT_SHOULDER)

	_keys("check", [KEY_F])
	_button("check", JOY_BUTTON_B)

	_keys("sens_down", [KEY_BRACKETLEFT])
	_keys("sens_up", [KEY_BRACKETRIGHT])
	_keys("free_mouse", [KEY_ESCAPE])

	# career: fast-forward while your line is on the bench
	_keys("fast_forward", [KEY_TAB])
	_button("fast_forward", JOY_BUTTON_Y)

	_keys("cycle_mode", [KEY_F1])
	_button("cycle_mode", JOY_BUTTON_BACK)
	_keys("camera", [KEY_C])
	_button("camera", JOY_BUTTON_DPAD_UP)
	_keys("reset", [KEY_BACKSPACE])
	# the Esc / Start menu (PauseMenu); Esc also frees the cursor (free_mouse)
	_keys("pause_menu", [KEY_ESCAPE])
	_button("pause_menu", JOY_BUTTON_START)
	_keys("help", [KEY_H])
	# rink jobs (JobInput): on foot, at the bench and driving Doris. They
	# share keys with the hockey actions; only one set is read at a time.
	_keys("job_interact", [KEY_E])
	_button("job_interact", JOY_BUTTON_A)
	_keys("job_back", [KEY_X])
	_button("job_back", JOY_BUTTON_B)
	_mouse("job_grab", MOUSE_BUTTON_LEFT)
	_axis("job_grab", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_mouse("job_turn_cw", MOUSE_BUTTON_WHEEL_DOWN)
	_button("job_turn_cw", JOY_BUTTON_RIGHT_SHOULDER)
	_mouse("job_turn_ccw", MOUSE_BUTTON_WHEEL_UP)
	_button("job_turn_ccw", JOY_BUTTON_LEFT_SHOULDER)
	_keys("job_run", [KEY_SHIFT])
	_button("job_run", JOY_BUTTON_LEFT_STICK)
	_keys("drive_brake", [KEY_SPACE])
	_axis("drive_brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_keys("drive_blade", [KEY_Q])
	_button("drive_blade", JOY_BUTTON_LEFT_SHOULDER)
	_keys("drive_water", [KEY_F])
	_button("drive_water", JOY_BUTTON_RIGHT_SHOULDER)

	# developer overlay: ` (tilde key) or D-pad down (InputMap has no chords)
	_keys("dev_menu", [KEY_QUOTELEFT])
	_button("dev_menu", JOY_BUTTON_DPAD_DOWN)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		device = Device.PAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		device = Device.PAD
	elif event is InputEventKey or event is InputEventMouseButton:
		device = Device.KBM
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		device = Device.KBM


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)
