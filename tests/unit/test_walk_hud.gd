class_name TestWalkHud
extends GdUnitTestSuite
## The overlay sits under the captured cursor (the dot is at the window
## centre, where a captured mouse stays), so none of it may stop mouse
## events: a Control with the default filter there swallowed every mouse
## motion and the first-person body never turned.


func test_overlay_ignores_the_mouse() -> void:
	var hud := WalkHud.new()
	add_child(hud)
	await get_tree().process_frame
	var controls: Array = []
	_collect(hud, controls)
	assert_int(controls.size()).is_greater(0)
	for c in controls:
		(
			assert_int(c.mouse_filter)
			. override_failure_message("%s stops mouse events" % c.get_class())
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)
	hud.queue_free()


func test_toast_shows_then_clears() -> void:
	var hud := WalkHud.new()
	add_child(hud)
	await get_tree().process_frame
	hud.toast("SAVED", 0.01)
	assert_bool(hud.toast_label.visible).is_true()
	assert_str(hud.toast_label.text).is_equal("SAVED")
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	assert_bool(hud.toast_label.visible).is_false()
	hud.queue_free()


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control:
			out.append(c)
		_collect(c, out)
