extends Node
## Headless check of the nets as solid objects (NetPhysics with the real
## Puck): a shot between the posts scores and stays in the net, one off the
## post rings and stays out, the back and sides of the net stop a puck from
## outside.
##
## Run: godot --headless --path . --fixed-fps 120 -- --test=nets

const DT := 1.0 / 480.0

var game: Node
var failures := 0
var _puck: Puck
var _goals := 0
var _rings := 0


func _ready() -> void:
	# a puck of its own, away from the game's
	_puck = Puck.new()
	add_child(_puck)
	_puck.goal_scored.connect(func(_s): _goals += 1)
	_puck.post_hit.connect(func(_at, _speed): _rings += 1)
	var gx := Rink.GOAL_X
	_expect(NetPhysics.boxes(1).size() > 4 and NetPhysics.boxes(-1).size() == NetPhysics.boxes(1).size(), "both nets have colliders from the voxel net (%d boxes)" % NetPhysics.boxes(1).size())
	var front := INF
	for b in NetPhysics.boxes(1):
		front = minf(front, (b[0] * AABB(-b[1], b[1] * 2.0)).position.x)
	_expect(front >= gx + NetPhysics.BEHIND - 0.001, "no netting box stands in the goal mouth (front at %.2f m behind the line)" % (front - gx))

	var r := _fly(Vector3(gx - 6, 0.05, 0.3), Vector3(30, 1.5, 0))
	_expect(r.goals == 1, "a shot between the posts scores")
	_expect(r.pos.x > gx and r.pos.x < gx + Rink.NET_DEPTH + 0.05 and absf(r.pos.z) < Rink.NET_HALF_W + 0.1, "and stays in the net (%s)" % r.pos)
	_expect(r.speed < 3.0, "the twine takes the pace off it (%.1f m/s)" % r.speed)

	r = _fly(Vector3(gx - 6, 0.0, Rink.NET_HALF_W + Rink.POST_R), Vector3(30, 0, 0))
	_expect(r.goals == 0 and r.rings >= 1, "a shot at the post rings off it")
	_expect(r.pos.x < gx, "and comes back out (%s)" % r.pos)

	r = _fly(Vector3(gx + 3, 0.0, 0.0), Vector3(-20, 0, 0))
	_expect(r.goals == 0 and r.pos.x > gx + Rink.NET_DEPTH * 0.5, "the back of the net stops a puck from behind (%s)" % r.pos)

	r = _fly(Vector3(gx + 0.5, 0.3, 3.0), Vector3(0, 0, -15))
	_expect(r.goals == 0 and r.pos.z > Rink.NET_HALF_W, "the side netting stops a puck from the side (%s)" % r.pos)

	print("nets test: ", "FAILED %d" % failures if failures else "all passed")
	get_tree().quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _fly(from: Vector3, v: Vector3, secs := 1.5) -> Dictionary:
	_puck.reset_at(from)
	_puck.vel = v
	_goals = 0
	_rings = 0
	for i in int(secs / DT):
		_puck.integrate(DT)
	return {"goals": _goals, "rings": _rings, "pos": _puck.position, "speed": _puck.vel.length()}
