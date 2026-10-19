extends Node
## Headless checks of the office computer's keys (playtest #41 and #2): the
## arrow keys move between its buttons, Enter presses one and the keyboard
## stays on it when the screen rebuilds, and Esc leaves for the hub.
## Run: godot --headless --path . --fixed-fps 120 res://scenes/ui/rink_office.tscn -- --test=office

const SAVE := "user://test_office.json"

var office: Control
var _fails := 0
var _left := false


func _ready() -> void:
	CareerState.career.save_path = SAVE
	office.leaving.connect(func(): _left = true)
	await _frames(3)
	_expect(_focused() == "[ ICE GRID ]", "the open tab has the keyboard (%s)" % _focused())
	await _press("ui_right")
	_expect(_focused() == "[ LOG BOOK ]", "right arrow moves to the next tab (%s)" % _focused())
	await _press("ui_accept")
	_expect(office.tab == "log", "Enter opens it (%s)" % office.tab)
	_expect(_focused() == "[ LOG BOOK ]", "the keyboard stays on it after the screen rebuilds (%s)" % _focused())
	await _press("ui_left")
	_expect(_focused() == "[ ICE GRID ]", "left arrow goes back (%s)" % _focused())
	await _press("ui_cancel")
	_expect(_left, "Esc leaves the computer for the hub")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("office test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _focused() -> String:
	var f = get_viewport().gui_get_focus_owner()
	return f.text if f is Button else str(f)


func _press(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("  ok  ", what)
	else:
		_fails += 1
		printerr("FAIL: ", what)
