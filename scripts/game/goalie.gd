class_name Goalie
extends Node3D
## Goalie: plays the angle in the crease, reads shots (predicts where the puck
## crosses its body plane, reacts after a short delay and reaches toward it),
## drops into the butterfly for low shots, and either holds the puck or
## kicks out a rebound. Saves come from body coverage + the reaching hand,
## so well-placed shots to the corners can beat it.

const FRONT := 0.22  # the save plane sits this far in front of the goalie

var game: Node
var team := 0
var side := -1  # which net (x sign) this goalie defends
var pos2 := Vector2.ZERO
var facing := Vector2.RIGHT
var butterfly_timer := 0.0
var reach := Vector2(0.0, 0.8)  # (lateral, height) of the reaching hand/pad
var reach_target := Vector2(0.0, 0.8)
var skill := 0.68
var rig: SkaterRig
var _tracking := false
var _reaction := 0.0
var _cover := 0.0
var _last_dt := 1.0 / 120.0
var _save_cd := 0.0


func setup(g: Node, t: int, pal: Dictionary) -> void:
	game = g
	team = t
	side = -g.attack_side(t)
	rig = SkaterRig.new()
	add_child(rig)
	rig.build(pal, true)


func reset() -> void:
	pos2 = Vector2(side * (Rink.GOAL_X - 0.6), 0)
	facing = Vector2(-side, 0)
	butterfly_timer = 0.0
	reach = Vector2(0, 0.8)
	reach_target = reach
	_tracking = false
	_cover = 0.0
	_apply(_last_dt)


func net_center() -> Vector2:
	return Vector2(side * Rink.GOAL_X, 0)


func right2() -> Vector2:
	return Vector2(-facing.y, facing.x)


func physics_update(dt: float) -> void:
	_last_dt = dt
	_save_cd -= dt
	var puck: Puck = game.puck
	var p2 := Vector2(puck.position.x, puck.position.z)
	var nc := net_center()
	var out := Vector2(-side, 0)
	var rel := p2 - nc

	# positioning: on the line between net and puck, deeper when the puck is far
	var desired: Vector2
	if rel.dot(out) < 0.3:
		desired = nc + out * 0.35 + Vector2(0, clampf(rel.y, -0.7, 0.7))
	else:
		desired = nc + rel.normalized() * clampf(rel.length() * 0.07, 0.35, 1.1)
	var max_spd := lerpf(2.5, 4.0, skill) * (0.4 if butterfly_timer > 0.0 else 1.0)
	pos2 += (desired - pos2).limit_length(max_spd * dt)
	var look := p2 - pos2
	if look.length() > 0.3 and look.dot(out) > -0.2:
		facing = facing.lerp(look.normalized(), 1.0 - exp(-10.0 * dt)).normalized()

	# shot reading
	var pv := Vector2(puck.vel.x, puck.vel.z)
	var incoming := puck.controller == null and not puck.frozen and puck.in_net_side == 0 \
		and pv.length() > 6.0 and pv.dot(nc - p2) > 0.0 and rel.dot(out) > 0.0
	var tracked := false
	if incoming:
		var dist := (p2 - pos2).dot(facing) - FRONT
		var closing := -pv.dot(facing)
		if closing > 1.0 and dist > 0.0 and dist / closing < 1.0:
			var t := dist / closing
			tracked = true
			if not _tracking:
				_reaction = lerpf(0.26, 0.12, skill) + randf() * 0.06
			var hit := p2 + pv * t
			var hy := maxf(0.0, puck.position.y + puck.vel.y * t - 0.5 * Puck.GRAVITY * t * t)
			reach_target = Vector2(clampf((hit - pos2).dot(right2()), -1.0, 1.0), clampf(hy, 0.0, 1.5))
			if hy < 0.5 and absf(reach_target.x) < 1.2:
				butterfly_timer = 0.9
	_tracking = tracked
	if not _tracking:
		reach_target = Vector2(0, 0.8)
	_reaction -= dt
	if _reaction <= 0.0 or not _tracking:
		reach = reach.move_toward(reach_target, lerpf(3.0, 5.5, skill) * dt)
	butterfly_timer = maxf(0.0, butterfly_timer - dt)

	# smother a slow loose puck at the goalie's feet
	if puck.controller == null and not puck.frozen and puck.horizontal_speed() < 1.5 \
		and p2.distance_to(pos2) < 0.9 and game.nearest_opponent_distance_to(team, p2) > 1.4:
		_cover += dt
		if _cover > 0.5:
			_freeze(puck)
	else:
		_cover = 0.0
	_apply(dt)


## Called every puck substep with the puck's previous position.
func check_save(puck: Puck, prev: Vector3) -> void:
	if puck.controller != null or puck.frozen or puck.in_net_side != 0 or _save_cd > 0.0:
		return
	var p2 := Vector2(puck.position.x, puck.position.z)
	var q2 := Vector2(prev.x, prev.z)
	var d_now := (p2 - pos2).dot(facing)
	var d_prev := (q2 - pos2).dot(facing)
	if d_prev >= FRONT and d_now < FRONT:
		var f := (d_prev - FRONT) / maxf(d_prev - d_now, 0.0001)
		var cross := q2.lerp(p2, f)
		var y := lerpf(prev.y, puck.position.y, f)
		var lat := (cross - pos2).dot(right2())
		if _covers(lat, y):
			_save(puck, cross, lat, y)
		return
	# body contact for pucks that get behind the save plane (wraparounds, scrambles)
	var d := p2 - pos2
	if d_now < FRONT and d.length() < 0.42 and puck.position.y < 1.2 and d.length() > 0.0001:
		var n := d.normalized()
		puck.position.x = pos2.x + n.x * 0.42
		puck.position.z = pos2.y + n.y * 0.42
		var n3 := Vector3(n.x, 0, n.y)
		var vn := puck.vel.dot(n3)
		if vn < 0.0:
			puck.vel -= n3 * vn * 1.2
			puck.vel *= 0.6


func _covers(lat: float, y: float) -> bool:
	var a := absf(lat)
	if butterfly_timer > 0.0:
		if a < 0.9 and y < 0.38:
			return true
		if a < 0.38 and y < 1.1:
			return true
	else:
		if a < 0.36 and y < 1.4:
			return true
		if a < 0.5 and y < 0.45:
			return true
	return Vector2(lat, y).distance_to(reach) < 0.2


func _save(puck: Puck, cross: Vector2, lat: float, y: float) -> void:
	var spd := puck.vel.length()
	var glove_side := lat < 0.0 and y > 0.5
	if spd < 5.0 or (glove_side and randf() < lerpf(0.35, 0.65, skill)):
		_freeze(puck)
		return
	# rebound: kicked back out in front with some random spread
	var f3 := Vector3(facing.x, 0, facing.y)
	var v := puck.vel
	var vn := v.dot(f3)
	v -= f3 * vn
	v *= 0.4
	v += f3 * maxf(-vn * 0.3, 4.0)
	var r2 := right2()
	v += Vector3(r2.x, 0, r2.y) * randf_range(-4.0, 4.0)
	v.y = randf_range(0.0, 2.5) if y > 0.3 else 0.0
	puck.vel = v
	var front := cross + facing * 0.03
	puck.position = Vector3(front.x, y, front.y)
	puck.pass_target = null
	_save_cd = 0.3
	game.on_save(self, false)


func _freeze(puck: Puck) -> void:
	puck.vel = Vector3.ZERO
	puck.controller = null
	puck.frozen = true
	var p := pos2 + facing * 0.35
	puck.position = Vector3(p.x, 0.0, p.y)
	_cover = 0.0
	game.on_save(self, true)


func _apply(dt: float) -> void:
	position = Vector3(pos2.x, 0, pos2.y)
	basis = Basis(Vector3.UP, atan2(-facing.x, -facing.y))
	if rig:
		rig.update_goalie(self, dt)
