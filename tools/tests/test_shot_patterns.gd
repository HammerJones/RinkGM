extends SceneTree
## Checks the traced shot recognizer: each of Sean's patterns reads as its
## own shot, size doesn't matter, a wobble lowers the match, a scribble or a
## click isn't a clean shot, and the forward stroke's speed is measured.
##   godot --headless --path . --script res://tools/tests/test_shot_patterns.gd

var failures := 0


func _initialize() -> void:
	seed(7)
	for kind in ShotPatterns.KINDS:
		var g := ShotPatterns.match(_trace(kind, 1.0, 0.0, 0.5), 0.5)
		_check(g.ok and g.kind == kind and g.match > 0.9, "a clean %s reads as itself (%s %.2f)" % [kind, g.kind, g.match])
		var big := ShotPatterns.match(_trace(kind, 2.5, 0.0, 0.5), 0.5)
		_check(big.kind == kind and big.match > 0.9, "a %s drawn 2.5x bigger still reads (%.2f)" % [kind, big.match])
	var clean := ShotPatterns.match(_trace(&"snap_shot", 1.0, 0.0, 0.5), 0.3)
	# the same wobbly drawing graded at low and high shot accuracy
	var shaky := _trace(&"snap_shot", 1.0, 14.0, 0.5)
	var wobbly := ShotPatterns.match(shaky, 0.3)
	_check(wobbly.match < clean.match - 0.15, "a wobbly snap shot matches worse (%.2f vs %.2f)" % [wobbly.match, clean.match])
	var skilled := ShotPatterns.match(shaky, 1.0)
	_check(skilled.match > wobbly.match + 0.1, "shot accuracy forgives the wobble (%.2f vs %.2f)" % [skilled.match, wobbly.match])
	# drawn sideways it's no shot pattern
	var side := []
	for p in _trace(&"wrist_shot", 1.0, 0.0, 0.5):
		side.append(Vector3(p.y, -p.x, p.z))
	_check(ShotPatterns.match(side, 0.5).match < 0.3, "a pattern drawn sideways doesn't match")
	_check(not ShotPatterns.match([Vector3.ZERO, Vector3(3, 2, 0.05), Vector3(4, 4, 0.1)]).ok, "a click isn't a shot")
	# speed of the forward stroke
	var fast := ShotPatterns.match(_trace(&"slapshot", 1.0, 0.0, 0.3), 0.5)
	var slow := ShotPatterns.match(_trace(&"slapshot", 1.0, 0.0, 1.2), 0.5)
	_check(fast.speed > slow.speed * 3.0, "a quick stroke is faster (%.0f vs %.0f px/s)" % [fast.speed, slow.speed])
	if failures:
		printerr("test_shot_patterns: %d failure(s)" % failures)
	else:
		print("test_shot_patterns: ok")
	quit(1 if failures else 0)


## The template as mouse motion at `scale`, with `noise` px of wobble, drawn
## over `seconds`.
func _trace(kind: StringName, scale: float, noise: float, seconds: float) -> Array:
	var pts := ShotPatterns.outline(kind)
	var out := []
	var steps := 60
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var t := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1] * scale
		var b := pts[i] * scale
		var n := maxi(2, int(steps * pts[i].distance_to(pts[i - 1]) / total))
		for k in n:
			var q := a.lerp(b, float(k) / n)
			var w := Vector2(randf_range(-noise, noise), randf_range(-noise, noise)) if k > 0 else Vector2.ZERO
			out.append(Vector3(q.x + w.x, q.y + w.y, t))
			t += seconds / steps
	var end := pts[pts.size() - 1] * scale
	out.append(Vector3(end.x, end.y, t))
	return out


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		printerr("FAIL ", what)
		failures += 1
