class_name Puck
extends Node3D
## Free puck physics: gravity, ice friction, bounces off boards and the
## nets (NetPhysics), and goal detection at the goal line.
## Stick control is applied by Game as spring forces before integrate().

signal goal_scored(net_side: int)
## Rang off a post or the crossbar: where, and the puck's speed (m/s) coming in.
signal post_hit(at: Vector3, speed: float)
## Hit the boards: where, and the speed (m/s) into them (for sound).
signal boards_hit(at: Vector3, normal_speed: float)
## Over the glass and into the building: play is dead (Mechanics whistles).
signal left_rink(at: Vector3)

const RADIUS := 0.0381  # regulation: 3 in across, 1 in thick
const GRAVITY := 9.8

var vel := Vector3.ZERO
var controller: Skater = null
var last_touch: Skater = null
var pass_target: Skater = null
var frozen := false
var out_of_play := false  ## over the glass: the building's colliders take over from the boards
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
	out_of_play = false
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
	if out_of_play or position.y > 0.001 or vel.y > 0.0:
		vel.y -= GRAVITY * dt
	if out_of_play:
		_fly_in_building(dt)
		return
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
	if VenuePhysics.clears_glass(position, RADIUS):
		# over the glass: the boards don't stop it any more
		out_of_play = true
		controller = null
		left_rink.emit(position)
		return
	_collide_boards()
	_collide_nets(prev)


## Out of the rink: flying through the stands, bouncing off seats, rails,
## fans and walls until it settles (VenuePhysics owns the building's shapes).
func _fly_in_building(dt: float) -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var c := VenuePhysics.contact(space, position, vel, RADIUS, dt)
	if c.is_empty():
		position += vel * dt
		return
	position = c.point
	vel = VenuePhysics.bounce(vel, c)


func _collide_boards() -> void:
	var r := Rink.confine(position, RADIUS)
	var n: Vector2 = r[1]
	if n == Vector2.ZERO:
		return
	position = r[0]
	var n3 := Vector3(n.x, 0, n.y)
	var vn := vel.dot(n3)
	if vn > 0.0:
		boards_hit.emit(position, vn)
		vel -= n3 * vn * 1.6  # restitution 0.6
		vel *= 0.92


## The nets are solid (NetPhysics): posts, crossbar, frame and netting.
## A goal is the whole puck crossing the goal line between the posts and
## under the bar.
func _collide_nets(prev: Vector3) -> void:
	var speed := vel.length()
	if NetPhysics.collide(self):
		post_hit.emit(position, speed)
	if in_net_side != 0:
		return
	for side in [-1, 1]:
		var gx: float = side * Rink.GOAL_X
		var u: float = (position.x - gx) * side
		var u_prev: float = (prev.x - gx) * side
		if u <= RADIUS or u_prev > RADIUS or u > Rink.NET_DEPTH:
			continue
		var at := prev.lerp(position, (RADIUS - u_prev) / (u - u_prev))
		if absf(at.z) < Rink.NET_HALF_W and at.y < Rink.NET_H:
			in_net_side = side
			goal_scored.emit(side)
			return

