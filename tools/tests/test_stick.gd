extends SceneTree
## Checks the skater stick's blade: it sits on the ice, and the heel curves
## up into a hosel at an obtuse angle that ends where the shaft starts.
##   godot --headless --path . --script res://tools/tests/test_stick.gd

var failures := 0


func _initialize() -> void:
	var blade := Models.blade(Models.palette(0))
	if blade.oriented.is_empty():
		_fail("blade has no heel curve")
	var aabb := blade.build_mesh().get_aabb()
	if absf(aabb.position.y) > 0.002:
		_fail("blade bottom is %.3f m off the ice" % aabb.position.y)
	var joint: Vector3 = Models.blade_heel
	var back := (3.0 - Models.BLADE_PIVOT.x) * Models.STICK_V  # the blade's straight part starts here
	if joint.x >= back or joint.y < 4.0 * Models.STICK_V:
		_fail("shaft joint %s should be above and behind the blade's heel" % joint)
	# heel angle between the blade (toward the toe) and the hosel (toward the shaft)
	var hosel := Vector2(joint.x - back, joint.y - 2.0 * Models.STICK_V).normalized()
	var heel_deg := rad_to_deg(Vector2.RIGHT.angle_to(hosel))
	print("stick heel angle %.0f deg, shaft joint %s" % [heel_deg, joint])
	if heel_deg <= 110.0 or heel_deg >= 160.0:
		_fail("heel angle %.0f deg, want an obtuse heel (110-160)" % heel_deg)
	if failures:
		printerr("test_stick: %d failure(s)" % failures)
	else:
		print("test_stick: ok")
	quit(1 if failures else 0)


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
