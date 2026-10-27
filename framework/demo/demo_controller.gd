class_name DemoController
extends HumanController
## The game's keyboard + mouse controller with one more pattern (Sean's
## sketch, 2026-10-26): a straight flick with RMB is a pass, along the
## ice, no lift. The flick's direction is the pass's direction (up the
## screen is where you face) and its speed sets the pace. Anything that
## is not a straight line is graded as a shot as before.

const FLICK_STRAIGHT := 0.1  # share of the chord the path may wander off it
const FLICK_MIN := ShotPatterns.MIN_LENGTH  # px
const PASS_SLOW := 6.0  # m/s at the gentlest flick that counts
const PASS_FAST := 18.0  # m/s at a full stroke

## The last flick pass: {ok, speed (m/s), dir (world XZ), px_s}.
var last_pass := {}
## Called with no arguments when a flick pass goes (the demo lets the puck go).
var pass_hook := Callable()
## A left shot: the traced patterns (drawn for a right shot) are read mirrored.
var mirror_trace := false


func _traced(human: Skater, f: PlayerInput.Frame) -> void:
	if f.trace_done and human.has_puck() and is_flick(f.trace):
		_aim_dot = null
		time_slow = 1.0
		var first: Vector3 = f.trace[0]
		var last: Vector3 = f.trace[f.trace.size() - 1]
		var chord := Vector2(last.x - first.x, last.y - first.y).normalized()
		var w := human.right_vec() * chord.x + human.heading * chord.y
		human.ctrl.pass_dir = Vector2(w.x, w.z)
		human.ctrl.tilt = 0.0  # flat blade: no saucer
		var px_s := (
			Vector2(last.x - first.x, last.y - first.y).length()
			/ maxf(last.z - first.z, 1.0 / 120.0)
		)
		var full := lerpf(FULL_STROKE.x, FULL_STROKE.y, human.skill("shot_power"))
		var power := clampf(px_s / full, 0.0, 1.0)
		var speed := lerpf(PASS_SLOW, PASS_FAST, power)
		if pass_hook.is_valid():
			pass_hook.call()
		human.pass_puck()
		var puck: Puck = human.puck
		var flat := Vector3(puck.vel.x, 0.0, puck.vel.z)
		if flat.length() > 0.01:
			puck.vel = flat.normalized() * speed
		puck.pass_target = null
		last_pass = {"ok": true, "speed": speed, "dir": human.ctrl.pass_dir, "px_s": px_s}
		overlay.show_state(f.looking, false, Vector2.ZERO, -1.0)
		game.hud.show_message("PASS  %.0f M/S" % speed, 0.8)
		return
	super._traced(human, f)


## The game's grading, on the trace mirrored left to right for a left shot
## (a wrist shot's pull back to the forehand goes the other way).
func grade(human: Skater, trace: Array, target: Vector3) -> Dictionary:
	if not mirror_trace or trace.is_empty():
		return super.grade(human, trace, target)
	var x0: float = trace[0].x
	var m := []
	for p in trace:
		m.append(Vector3(2.0 * x0 - p.x, p.y, p.z))
	return super.grade(human, m, target)


## A straight line long enough to mean it: every point within
## FLICK_STRAIGHT of the chord's length from the chord.
static func is_flick(trace: Array) -> bool:
	if trace.size() < 3:
		return false
	var a := Vector2(trace[0].x, trace[0].y)
	var b := Vector2(trace[trace.size() - 1].x, trace[trace.size() - 1].y)
	var chord := b - a
	var l := chord.length()
	if l < FLICK_MIN:
		return false
	var n := chord / l
	for p in trace:
		var d := Vector2(p.x, p.y) - a
		var along := d.dot(n)
		if along < -l * FLICK_STRAIGHT or along > l * (1.0 + FLICK_STRAIGHT):
			return false
		if absf(d.cross(n)) > l * FLICK_STRAIGHT:
			return false
	return true
