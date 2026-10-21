class_name TestInteractPrompt
extends GdUnitTestSuite
## The prompt overlay sits under the captured cursor (the dot is at the
## window centre, where a captured mouse stays), so none of it may stop
## mouse events: a Control with the default filter there swallowed every
## mouse motion and the first-person body never turned.


func test_overlay_ignores_the_mouse() -> void:
	var p := InteractPrompt.new()
	add_child(p)
	await get_tree().process_frame
	var controls: Array = []
	_collect(p, controls)
	assert_int(controls.size()).is_greater(0)
	for c in controls:
		(
			assert_int(c.mouse_filter)
			. override_failure_message("%s stops mouse events" % c.get_class())
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)
	p.queue_free()


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control:
			out.append(c)
		_collect(c, out)
