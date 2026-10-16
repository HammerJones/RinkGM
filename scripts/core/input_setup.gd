extends Node
## Registers the input map in code (keyboard + mouse and gamepad) and tracks
## which device the player touched last, so mouse aiming and the right-stick
## "skill stick" don't fight each other.

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

	_axis("stick_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("stick_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("stick_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("stick_down", JOY_AXIS_RIGHT_Y, 1.0)

	# Placeholder mapping of Sean's scheme so the physics stays playable; the
	# Controls thread owns the final bindings.
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_keys("shoot", [KEY_J])
	_button("shoot", JOY_BUTTON_X)

	_mouse("pass", MOUSE_BUTTON_RIGHT)
	_keys("pass", [KEY_E, KEY_K])
	_button("pass", JOY_BUTTON_A)

	_keys("dash", [KEY_SHIFT])
	_button("dash", JOY_BUTTON_LEFT_STICK)

	_keys("stop", [KEY_SPACE])
	_button("stop", JOY_BUTTON_RIGHT_STICK)

	_keys("lift", [KEY_CTRL])
	_mouse("lift", MOUSE_BUTTON_MIDDLE)
	_axis("lift", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_keys("tilt", [KEY_Z])
	_axis("tilt", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_keys("check", [KEY_F])
	_button("check", JOY_BUTTON_B)

	_keys("switch", [KEY_Q, KEY_TAB])
	_button("switch", JOY_BUTTON_Y)

	_keys("cycle_mode", [KEY_F1])
	_button("cycle_mode", JOY_BUTTON_BACK)
	_keys("camera", [KEY_C])
	_button("camera", JOY_BUTTON_DPAD_UP)
	_keys("reset", [KEY_R])
	_button("reset", JOY_BUTTON_START)
	_keys("help", [KEY_H])


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
