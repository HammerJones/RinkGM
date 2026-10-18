class_name StickGestures
extends RefCounted
## Recognises the stick patterns in Moves.CATALOG that start a MovePhysics
## move. Fed once per tick with the right stick in the skater's frame
## (x forward, y forehand), it returns the move id the stick just traced, or
## &"". Wind-up shots (wrist, backhand, slapshot) aren't recognised here: the
## stick's own shot mechanics in Skater handle them.

const KEEP := 0.5   # seconds of stick history kept
const HOLD := 0.3   # a snapshot pull-out is held this long before the snap

var _hist: Array[Vector3] = []   # (forward, forehand, age)


func feed(local: Vector2, tilt: float, lift: bool, has_puck: bool, dt: float) -> StringName:
	for i in _hist.size():
		_hist[i].z += dt
	_hist.append(Vector3(local.x, local.y, 0.0))
	while _hist.size() > 2 and _hist[0].z > KEEP:
		_hist.pop_front()
	if not has_puck:
		return &""
	var id := _match(local, tilt > 0.5, lift)
	if id != &"":
		_hist.clear()
	return id


func _match(c: Vector2, tilted: bool, lift: bool) -> StringName:
	var r := c.length()
	var ang := rad_to_deg(atan2(c.y, c.x))
	if tilted and r > 0.8 and ang > 45.0:
		# swept round from the backhand: the puck rides up on the blade
		if _was(func(a, rr, age): return a < -45.0 and rr > 0.8 and age < 0.5):
			return &"lacrosse"
	if tilted and r > 0.5 and ang < -55.0:
		# pulled back across from out in front
		if _was(func(a, rr, age): return absf(a) < 35.0 and rr > 0.45 and age < 0.3):
			return &"toe_drag_shot" if lift else &"toe_drag"
	if r > 0.95 and absf(ang) < 20.0:
		# pulled out to the side, then snapped all the way forward (one hand
		# comes off past 45 degrees, so the pull stays inside that)
		# held there a moment first, so rolling the stick round the rim while
		# stickhandling doesn't count
		for sd in [1.0, -1.0]:
			var held := _held_out(sd)
			if held:
				return &"snap_shot" if sd > 0.0 else &"backhand_shot"
	if not tilted and r > 0.6 and ang > 30.0:
		# forehand -> backhand -> forehand inside 0.4 s
		var saw_bh := -1.0
		for g in _hist:
			var a := rad_to_deg(atan2(g.y, g.x))
			if a < -30.0 and Vector2(g.x, g.y).length() > 0.6 and g.z < 0.4:
				saw_bh = maxf(saw_bh, g.z)
		if saw_bh >= 0.0 and _was(func(a, rr, age): return a > 30.0 and rr > 0.6 and age > saw_bh and age < 0.4):
			return &"quick_deke"
	return &""


## True when the stick was just out to one side (30 to 70 deg) and had been
## held there, still, for HOLD seconds before: a deliberate pull-out, not the
## turn of a stickhandling sweep.
func _held_out(sd: float) -> bool:
	var at := INF
	var since := 0.0
	for i in range(_hist.size() - 1, -1, -1):
		var g := _hist[i]
		var a := rad_to_deg(atan2(g.y, g.x)) * sd
		if g.z < 0.1 and a > 30.0 and a < 70.0 and Vector2(g.x, g.y).length() > 0.7:
			at = a
			since = g.z
			break
	if at == INF or _hist[0].z < since + HOLD:
		return false
	for g in _hist:
		if g.z >= since and g.z <= since + HOLD:
			if absf(rad_to_deg(atan2(g.y, g.x)) * sd - at) > 10.0 or Vector2(g.x, g.y).length() < 0.7:
				return false
	return true


func _was(test: Callable) -> bool:
	for g in _hist:
		if test.call(rad_to_deg(atan2(g.y, g.x)), Vector2(g.x, g.y).length(), g.z):
			return true
	return false
