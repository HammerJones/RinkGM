class_name Puck
extends Node3D
## Free puck physics: gravity, ice friction, bounces off boards, posts,
## crossbar and the outside of the nets, and goal detection at the goal line.
## Stick control is applied by Game as spring forces before integrate().

signal goal_scored(net_side: int)
signal post_hit

const RADIUS := 0.06
const GRAVITY := 9.8

var vel := Vector3.ZERO
var controller: Skater = null
var last_touch: Skater = null
var pass_target: Skater = null
var pass_bonus := 6.0  # extra trap allowance for pass_target, from the passer's skill
var frozen := false
var in_net_side := 0
var _ignore: Skater = null
var _ignore_timer := 0.0


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.puck().build_mesh()
	add_child(mi)


func reset_at(p: Vector3) -> void:
	position = p
	vel = Vector3.ZERO
	controller = null
	pass_target = null
	last_touch = null
	in_net_side = 0
	frozen = false
	_ignore = null


## Shots and passes: the releasing skater can't re-trap the puck for a moment.
func release(by: Skater, velocity: Vector3) -> void:
	controller = null
	vel = velocity
	last_touch = by
	_ignore = by
	_ignore_timer = 0.25


func can_be_touched_by(s: Skater) -> bool:
	return not (s == _ignore and _ignore_timer > 0.0)


func ignore_briefly(s: Skater, t: float) -> void:
	_ignore = s
	_ignore_timer = t


func horizontal_speed() -> float:
	return Vector2(vel.x, vel.z).length()


func integrate(dt: float) -> void:
	_ignore_timer -= dt
	if frozen:
		return
	var prev := position
	if position.y > 0.001 or vel.y > 0.0:
		vel.y -= GRAVITY * dt
	position += vel * dt
	if position.y < 0.0:
		position.y = 0.0
		if vel.y < -1.2:
			vel.y = -vel.y * 0.35
			vel.x *= 0.92
			vel.z *= 0.92
		else:
			vel.y = 0.0
	if position.y <= 0.001:
		# sliding friction on ice plus a little drag
		var s := horizontal_speed()
		if s > 0.0:
			var ns := maxf(0.0, s - (0.12 + 0.035 * s) * dt)
			vel.x *= ns / s
			vel.z *= ns / s
	_collide_boards()
	if in_net_side != 0:
		_hold_in_net()
	else:
		_collide_nets(prev)


func _collide_boards() -> void:
	var r := Rink.confine(position, RADIUS)
	var n: Vector2 = r[1]
	if n == Vector2.ZERO:
		return
	position = r[0]
	var n3 := Vector3(n.x, 0, n.y)
	var vn := vel.dot(n3)
	if vn > 0.0:
		vel -= n3 * vn * 1.6  # restitution 0.6
		vel *= 0.92


func _collide_nets(prev: Vector3) -> void:
	for side in [-1, 1]:
		var gx: float = side * Rink.GOAL_X
		# posts (vertical cylinders) and crossbar
		if position.y < Rink.NET_H + RADIUS:
			for pz in [-Rink.NET_HALF_W, Rink.NET_HALF_W]:
				var d := Vector2(position.x - gx, position.z - pz)
				var min_d := RADIUS + Rink.POST_R
				if d.length() < min_d and d.length() > 0.0001:
					var n := d.normalized()
					position.x = gx + n.x * min_d
					position.z = pz + n.y * min_d
					var n3 := Vector3(n.x, 0, n.y)
					var vn := vel.dot(n3)
					if vn < 0.0:
						vel -= n3 * vn * 1.75
						post_hit.emit()
		var bar := Vector2(position.x - gx, position.y - Rink.NET_H)
		if absf(position.z) < Rink.NET_HALF_W and bar.length() < RADIUS + Rink.POST_R and bar.length() > 0.0001:
			var n := bar.normalized()
			position.x = gx + n.x * (RADIUS + Rink.POST_R)
			position.y = Rink.NET_H + n.y * (RADIUS + Rink.POST_R)
			var n3 := Vector3(n.x, n.y, 0)
			var vn := vel.dot(n3)
			if vn < 0.0:
				vel -= n3 * vn * 1.7
				post_hit.emit()
		# u: distance behind this goal line (into the net)
		var u: float = (position.x - gx) * side
		var u_prev: float = (prev.x - gx) * side
		var inside := u > 0.0 and u < Rink.NET_DEPTH and absf(position.z) < Rink.NET_HALF_W and position.y < Rink.NET_H
		var was_inside := u_prev > 0.0 and u_prev < Rink.NET_DEPTH and absf(prev.z) < Rink.NET_HALF_W and prev.y < Rink.NET_H
		if not inside or was_inside:
			continue
		if u_prev <= 0.0:
			# crossed the goal line between the posts and under the bar
			in_net_side = side
			vel *= 0.35
			goal_scored.emit(side)
			return
		# hit the outside of the net: bounce off whichever face it came through
		if u_prev >= Rink.NET_DEPTH:
			position.x = gx + side * (Rink.NET_DEPTH + RADIUS)
			vel.x = -vel.x * 0.25
		elif absf(prev.z) >= Rink.NET_HALF_W:
			position.z = signf(prev.z) * (Rink.NET_HALF_W + RADIUS)
			vel.z = -vel.z * 0.25
		else:
			position.y = Rink.NET_H + RADIUS
			vel.y = absf(vel.y) * 0.2
		vel *= 0.6


func _hold_in_net() -> void:
	var side := in_net_side
	var gx: float = side * Rink.GOAL_X
	var u := clampf((position.x - gx) * side, RADIUS, Rink.NET_DEPTH - RADIUS)
	position.x = gx + side * u
	position.z = clampf(position.z, -Rink.NET_HALF_W + RADIUS, Rink.NET_HALF_W - RADIUS)
	position.y = clampf(position.y, 0.0, Rink.NET_H - RADIUS)
	vel *= 0.97
