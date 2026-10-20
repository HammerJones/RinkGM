class_name Goalie
extends Node3D
## Goalie: a body with mass that skates its crease (accelerating, not
## teleporting) to play the angle, reads a shot after its reaction time,
## drops into the butterfly for low shots and reaches with the glove or
## blocker toward where the puck will cross. Saves are collisions: the puck
## bounces off whatever it hits (pads, body, blocker, stick, glove), each with
## its own liveliness, and the glove only catches a puck that arrives slower
## than the goalie can squeeze it. Shots to where nothing is get in.

const MASS := 90.0
const ARM := 0.75           # m, how far a hand reaches from its shoulder
const HAND_SPEED := 3.8     # m/s, the hands' top speed (scaled by skill)
const GLOVE_R := 0.17  # an open catcher, about 34 cm across
## restitution off each part: pads are lively, the chest soaks it up
const E_PAD := 0.4
const E_BODY := 0.15
const E_BLOCKER := 0.45
const E_STICK := 0.3
const E_GLOVE := 0.1
const MU := 0.3
const CLOSE := 3.5          # m: a puck this close in front, the goalie drops to block
const SET := 0.8            # reaction time factor for a shot the goalie saw being wound up
## How fast a hand gets going (m/s², scaled by skill): a glove can't jump
## to full speed, so a shot just past the hand beats it.
const HAND_ACCEL := 35.0

var game: Node
var team := 0
var side := -1  # which net (x sign) this goalie defends
var pos2 := Vector2.ZERO
var vel2 := Vector2.ZERO
var facing := Vector2.RIGHT
var butterfly_timer := 0.0
var butterfly := 0.0         ## 0 standing .. 1 down in the butterfly
var reach := Vector2(0.0, 0.8)  ## (lateral, height) of the reaching hand
var reach_target := Vector2(0.0, 0.8)
var glove := Vector3(-0.45, 0.7, 0.25)    ## local (right, up, forward)
var blocker := Vector3(0.45, 0.6, 0.25)
var skill := 0.68
var rig: SkaterRig
var _glove_v := Vector3.ZERO
var _blocker_v := Vector3.ZERO
var _tracking := false
var _alert := false
var _reaction := 0.0
var _cover := 0.0
var _last_dt := 1.0 / 120.0
var _save_cd := 0.0

## the ready stance: crouched, glove and blocker out in front at the sides
const GLOVE_REST := Vector3(-0.45, 0.7, 0.25)
const BLOCKER_REST := Vector3(0.45, 0.6, 0.25)


func setup(g: Node, t: int, pal: Dictionary) -> void:
	game = g
	team = t
	side = -g.attack_side(t)
	rig = SkaterRig.new()
	add_child(rig)
	rig.build(pal, true)


func reset() -> void:
	pos2 = Vector2(side * (Rink.GOAL_X - 0.6), 0)
	vel2 = Vector2.ZERO
	facing = Vector2(-side, 0)
	butterfly_timer = 0.0
	butterfly = 0.0
	reach = Vector2(0, 0.8)
	reach_target = reach
	glove = GLOVE_REST
	blocker = BLOCKER_REST
	_glove_v = Vector3.ZERO
	_blocker_v = Vector3.ZERO
	_tracking = false
	_cover = 0.0
	_apply(_last_dt)


func net_center() -> Vector2:
	return Vector2(side * Rink.GOAL_X, 0)


func right2() -> Vector2:
	return Vector2(-facing.y, facing.x)


## A shove from a skater (an impulse in kg m/s): a goalie can be moved.
func push(impulse: Vector2) -> void:
	vel2 += impulse / MASS


func physics_update(dt: float) -> void:
	_last_dt = dt
	_save_cd -= dt
	var puck: Puck = game.puck
	var p2 := Vector2(puck.position.x, puck.position.z)
	var nc := net_center()
	var out := Vector2(-side, 0)
	var rel := p2 - nc

	# positioning: on the line between net and puck, out at the top of the
	# crease to cut down the angle, backing in when the puck is in tight.
	# A goalie with poor positioning (TierAI) drifts off the angle, comes out
	# less and moves across slower.
	var ai: TierAI = game.ai_for(team)
	var gp := ai.goalie_positioning
	var desired: Vector2
	if rel.dot(out) < 0.3:
		desired = nc + out * 0.35 + Vector2(0, clampf(rel.y, -0.7, 0.7))
	else:
		var dir := rel.normalized().rotated(sin(game.time * 0.9 + side) * lerpf(0.35, 0.0, gp))
		desired = nc + dir * clampf(rel.length() * 0.15, 0.35, lerpf(0.6, 1.1, gp))
	_skate(desired, lerpf(2.5, 4.0, skill) * lerpf(0.75, 1.1, gp), lerpf(9.0, 16.0, skill) * lerpf(0.8, 1.1, gp), dt)
	var look := p2 - pos2
	if look.length() > 0.3 and look.dot(out) > -0.2:
		facing = facing.lerp(look.normalized(), 1.0 - exp(-lerpf(5.0, 12.0, gp) * dt)).normalized()

	# shot reading: where and how high it will cross. A goalie can only start
	# moving to the puck once it has seen it leave the blade: the reaction
	# time (skill and the tier's goaltending) runs from the release. Reading
	# a shooter's wind-up gets the goalie set and squared up, which takes a
	# little off that time, but never tells it where the shot is going.
	var pv := Vector2(puck.vel.x, puck.vel.z)
	var incoming := puck.controller == null and not puck.frozen and puck.in_net_side == 0 \
		and pv.length() > 6.0 and pv.dot(nc - p2) > 0.0 and rel.dot(out) > 0.0
	var shooter := puck.controller
	var reading := shooter != null and shooter.team != team and shooter.winding and rel.dot(out) > 0.0 and rel.length() < 18.0
	_alert = reading or (_alert and incoming)
	var tracked := false
	if incoming:
		var dist := (p2 - pos2).dot(facing) - 0.2
		var closing := -pv.dot(facing)
		if closing > 1.0 and dist > 0.0 and dist / closing < 1.0:
			var t := dist / closing
			tracked = true
			if not _tracking:
				_reaction = lerpf(0.32, 0.17, skill) * ai.goalie_reaction * (SET if _alert else 1.0)
			var hit := p2 + pv * t
			var hy := maxf(0.0, puck.position.y + puck.vel.y * t - 0.5 * Puck.GRAVITY * t * t)
			reach_target = Vector2(clampf((hit - pos2).dot(right2()), -1.2, 1.2), clampf(hy, 0.0, 1.5))
			if _reaction <= 0.0 and hy < 0.5 and absf(reach_target.x) < 1.2:
				butterfly_timer = 0.9
	_tracking = tracked
	if not _tracking:
		reach_target = Vector2(0, 0.8)
	# in tight, get down and take away the bottom of the net
	if rel.dot(out) > 0.0 and (p2 - pos2).length() < CLOSE * lerpf(0.5, 1.0, gp) and puck.position.y < 0.3:
		butterfly_timer = maxf(butterfly_timer, 0.3)
	_reaction -= dt
	butterfly_timer = maxf(0.0, butterfly_timer - dt)
	var drop := lerpf(4.0, 6.5, skill) * lerpf(0.7, 1.1, gp)  # 0.15-0.35 s to get all the way down
	butterfly = move_toward(butterfly, 1.0 if butterfly_timer > 0.0 else 0.0, (drop if butterfly_timer > 0.0 else 2.5) * dt)
	_move_hands(dt, lerpf(0.65, 1.1, gp))

	# smother a slow loose puck at the goalie's feet (where it lies)
	if puck.controller == null and not puck.frozen and puck.horizontal_speed() < 1.5 \
		and p2.distance_to(pos2) < 0.9 and game.nearest_opponent_distance_to(team, p2) > 1.4:
		_cover += dt
		if _cover > 0.5:
			_freeze(puck)
	else:
		_cover = 0.0
	_apply(dt)


## Skates toward `to` with limited acceleration, braking in time to stop.
func _skate(to: Vector2, max_spd: float, acc: float, dt: float) -> void:
	var d := to - pos2
	var want := d.normalized() * minf(max_spd, sqrt(2.0 * acc * d.length())) if d.length() > 0.001 else Vector2.ZERO
	if butterfly > 0.5:
		want *= 0.4  # sliding on the pads
	vel2 = vel2.move_toward(want, acc * dt)
	pos2 += vel2 * dt
	# the net is behind: pushed back into it, the goalie stops at the post line
	var deep := (pos2.x - side * Rink.GOAL_X) * side + 0.15
	if deep > 0.0:
		pos2.x -= side * deep
		vel2.x = 0.0 if vel2.x * side > 0.0 else vel2.x


## The hand on the puck's side reaches for where it will cross (arm's
## length from the shoulder, at hand speed); the other goes back to rest.
func _move_hands(dt: float, sharp: float) -> void:
	var spd := HAND_SPEED * lerpf(0.75, 1.25, skill) * sharp
	var gt := GLOVE_REST
	var bt := BLOCKER_REST
	if _tracking and _reaction <= 0.0:
		var t := Vector3(reach_target.x, reach_target.y, 0.25)
		if reach_target.x < 0.0:
			gt = _arm_limit(t, Vector3(-0.22, 1.2, 0.0))
		else:
			bt = _arm_limit(t, Vector3(0.22, 1.2, 0.0))
	var acc := HAND_ACCEL * lerpf(0.75, 1.25, skill) * sharp
	_glove_v = _hand_v(glove, gt, _glove_v, spd, acc, dt)
	_blocker_v = _hand_v(blocker, bt, _blocker_v, spd, acc, dt)
	glove += _glove_v * dt
	blocker += _blocker_v * dt
	var hand := glove if reach_target.x < 0.0 else blocker
	reach = Vector2(hand.x, hand.y)


## A hand's new velocity toward `to`: accelerating at `acc` up to `spd`,
## braking in time to stop there.
static func _hand_v(at: Vector3, to: Vector3, v: Vector3, spd: float, acc: float, dt: float) -> Vector3:
	var d := to - at
	var want := d.normalized() * minf(spd, sqrt(2.0 * acc * d.length())) if d.length() > 0.001 else Vector3.ZERO
	return v.move_toward(want, acc * dt)


static func _arm_limit(t: Vector3, shoulder: Vector3) -> Vector3:
	return shoulder + (t - shoulder).limit_length(ARM)


## The goalie's equipment as collision shapes, from the current pose:
## [shape, local centre, half extents or radius, restitution, part].
func parts() -> Array:
	var b := butterfly
	var pad_c := Vector3(lerpf(0.24, 0.43, b), lerpf(0.42, 0.13, b), lerpf(0.06, 0.12, b))
	var pad_h := Vector3(lerpf(0.14, 0.42, b), lerpf(0.42, 0.13, b), lerpf(0.10, 0.11, b))
	return [
		[&"box", Vector3(0, lerpf(0.95, 0.68, b), 0.02), Vector3(0.3, lerpf(0.42, 0.34, b), 0.13), E_BODY, &"body"],
		[&"box", Vector3(-pad_c.x, pad_c.y, pad_c.z), pad_h, E_PAD, &"pad"],
		[&"box", pad_c, pad_h, E_PAD, &"pad"],
		[&"box", Vector3(lerpf(0.15, 0.0, b), 0.06, lerpf(0.32, 0.4, b)), Vector3(0.3, 0.06, 0.02), E_STICK, &"stick"],
		[&"box", blocker, Vector3(0.12, 0.19, 0.04), E_BLOCKER, &"blocker"],
		[&"sphere", glove, GLOVE_R, E_GLOVE, &"glove"],
	]


func _frame() -> Transform3D:
	var r := right2()
	var basis3 := Basis(Vector3(r.x, 0, r.y), Vector3.UP, Vector3(facing.x, 0, facing.y))
	return Transform3D(basis3, Vector3(pos2.x, 0, pos2.y))


## Called every puck substep with the puck's previous position: sweeps the
## puck's path against the equipment and bounces it off the first thing hit.
func check_save(puck: Puck, prev: Vector3) -> void:
	if puck.controller != null or puck.frozen or puck.in_net_side != 0:
		return
	var xf := _frame()
	if Vector2(puck.position.x - pos2.x, puck.position.z - pos2.y).length() > 2.5:
		return
	var travel := puck.position.distance_to(prev)
	var steps := maxi(1, ceili(travel / 0.03))
	var parts_now := parts()
	for k in range(1, steps + 1):
		var c := prev.lerp(puck.position, float(k) / steps)
		for part in parts_now:
			var hit := _touch(part, c, xf)
			if hit.is_empty():
				continue
			_bounce(puck, c, hit, part, xf)
			return


func _touch(part: Array, c: Vector3, xf: Transform3D) -> Dictionary:
	if part[0] == &"sphere":
		return Contact.sphere_sphere(c, Puck.RADIUS, xf * part[1], part[2])
	return Contact.sphere_box(c, Puck.RADIUS, xf.translated_local(part[1]), part[2])


func _bounce(puck: Puck, c: Vector3, hit: Dictionary, part: Array, xf: Transform3D) -> void:
	var n: Vector3 = hit["n"]
	var surf := Vector3(vel2.x, 0, vel2.y)
	if part[4] == &"glove":
		surf += xf.basis * _glove_v
	elif part[4] == &"blocker":
		surf += xf.basis * _blocker_v
	var nc := net_center()
	var toward_net := Vector2(puck.vel.x, puck.vel.z).dot((nc - Vector2(c.x, c.z)).normalized())
	var shot := toward_net > 4.0 and _save_cd <= 0.0
	# the glove closes on anything it can hold
	if part[4] == &"glove" and (puck.vel - surf).length() < lerpf(18.0, 32.0, skill):
		puck.position = c
		_freeze(puck)
		return
	puck.position = c + n * hit["depth"]
	puck.vel = Contact.bounce(puck.vel, n, surf, part[3], MU, Contact.share_of(Contact.PUCK_MASS, MASS))
	if shot:
		_save_cd = 0.3
		game.on_save(self, false)


## Holds the puck where it is (in the glove, or smothered under the pads):
## play stops.
func _freeze(puck: Puck) -> void:
	puck.vel = Vector3.ZERO
	puck.controller = null
	puck.frozen = true
	_cover = 0.0
	game.on_save(self, true)


func _apply(dt: float) -> void:
	position = Vector3(pos2.x, 0, pos2.y)
	basis = Basis(Vector3.UP, atan2(-facing.x, -facing.y))
	if rig:
		rig.update_goalie(self, dt)
