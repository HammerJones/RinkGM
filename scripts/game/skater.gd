class_name Skater
extends Node3D
## A skater simulated as a point mass on edges:
##  * thrust only along the direction the skates point, so you carve turns
##  * lateral velocity bleeds off through edge grip (part of it is kept as
##    forward speed, the "carve"), turning gets wider the faster you go
##  * the stick blade is its own point with limited speed and reach, and the
##    puck is pulled to it by a spring (see Game._puck_stick_interaction)
## Tuning.blend (0 sim .. 1 arcade) adds grip, turn rate, direct thrust and
## shot/pass assistance on top of the same model.
## Player ratings come from `skills` (scripts/career/skills.gd), which turns
## each 1..100 rating into the speeds, rates and errors used here.

const RADIUS := 0.38
const REACH_MIN := 0.45
const REACH_MAX := 1.55
const DEFAULT_BLADE := Vector2(0.95, 0.3)  # (forward, right) relative to the body
const SLAP_DELAY := 0.22
const STICK_ANGLE_LIMIT := 2.1


## What a controller (human or AI) wants this frame.
class Controls:
	var move := Vector2.ZERO        # world XZ, length <= 1
	var sprint := false
	var brake := false
	var blade_target: Variant = null  # world Vector3 or null for the default carry spot
	var aim_point: Variant = null     # world Vector3 or null to aim at the net
	var shoot_held := false
	var pass_pressed := false
	var pass_dir := Vector2.ZERO
	var pass_hint: Variant = null     # Skater the AI wants to pass to
	var check_pressed := false
	var flick := 0.0                  # >0 when a right-stick flick shot happened, = power

	func reset() -> void:
		move = Vector2.ZERO
		sprint = false
		brake = false
		blade_target = null
		aim_point = null
		shoot_held = false
		pass_pressed = false
		pass_dir = Vector2.ZERO
		pass_hint = null
		check_pressed = false
		flick = 0.0


var game: Node
var puck: Puck
var team := 0
var number := 0
var ctrl := Controls.new()

var vel := Vector3.ZERO
var heading := Vector3(1, 0, 0)
var yaw_rate := 0.0
var braking := false
var stamina := 1.0
var stun_timer := 0.0
var check_timer := 0.0
var check_cd := 0.0
var shoot_hold_time := 0.0

var blade_local := DEFAULT_BLADE
var blade_pos := Vector3.ZERO
var blade_vel := Vector3.ZERO
var blade_height := 0.0

# player ratings, derived from `skills` by apply_skills()
var skills: Skills
var profile: PlayerProfile  # career player on this body right now, or null
var top_speed := 8.6
var accel := 6.5
var shot_power := 1.0
var handling := 1.0
var turn_mult := 1.0
var grip_mult := 1.0

# AI scratch state
var ai_decide := 0.0
var ai_shoot_timer := 0.0
var ai_aim: Variant = null

var rig: SkaterRig
var _prev_shoot := false
var _anchor_local := DEFAULT_BLADE
var _spray: CPUParticles3D


func setup(g: Node, t: int, idx: int, pal: Dictionary) -> void:
	game = g
	puck = g.puck
	team = t
	number = idx
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	apply_skills(Skills.create(Skills.SKATER_KEYS, 62.0, 6.0, rng))
	rig = SkaterRig.new()
	add_child(rig)
	rig.build(pal, false)
	_spray = _make_spray()
	add_child(_spray)


func apply_skills(s: Skills) -> void:
	skills = s
	top_speed = s.top_speed()
	accel = s.accel()
	shot_power = s.shot_speed_mult()
	handling = s.handling()
	turn_mult = s.turn_mult()
	grip_mult = s.grip_mult()


## A rating as 0..1, by the names the controls code uses ("stickhandling",
## "shot_release", ...). Unknown names read as average.
func skill(skill_name: String) -> float:
	var key := "stick_handling" if skill_name == "stickhandling" else skill_name
	return skills.n(key) if skills and skills.values.has(key) else 0.5


## Puts a career player on this body (line changes swap who is out there).
func apply_profile(p: PlayerProfile) -> void:
	profile = p
	number = p.number
	apply_skills(p.skills)


## How well this skater stays upright right now (skills.balance with the
## current turn rate).
func balance() -> float:
	return skills.balance(yaw_rate)


func place(p: Vector2, facing: Vector3) -> void:
	position = Vector3(p.x, 0, p.y)
	vel = Vector3.ZERO
	heading = facing.normalized()
	blade_local = DEFAULT_BLADE
	blade_pos = _blade_world(blade_local)
	blade_vel = Vector3.ZERO
	stun_timer = 0.0
	cancel_shot()
	_apply_transform()


func has_puck() -> bool:
	return puck.controller == self


func right_vec() -> Vector3:
	return heading.cross(Vector3.UP)


func cancel_shot() -> void:
	ctrl.shoot_held = false
	_prev_shoot = false
	shoot_hold_time = 0.0


func windup() -> float:
	if not _prev_shoot or shoot_hold_time < SLAP_DELAY:
		return 0.0
	return clampf((shoot_hold_time - SLAP_DELAY) / 0.45, 0.0, 1.0)


## Where the puck is pulled to while carried. During a slapshot wind-up the
## blade lifts away, so the puck stays where the wind-up started.
func puck_anchor() -> Vector3:
	if windup() > 0.0:
		return _blade_world(_anchor_local)
	return Vector3(blade_pos.x, 0, blade_pos.z)


func knock_down(impulse: Vector3) -> void:
	stun_timer = 1.3
	vel += impulse
	cancel_shot()
	if has_puck():
		puck.release(self, vel * 0.8 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))


func physics_update(dt: float) -> void:
	var blend: float = Tuning.blend
	stun_timer = maxf(0.0, stun_timer - dt)
	check_timer = maxf(0.0, check_timer - dt)
	check_cd = maxf(0.0, check_cd - dt)
	var frozen: bool = game.is_frozen()
	var carrying := has_puck()
	var move := ctrl.move if (stun_timer <= 0.0 and not frozen) else Vector2.ZERO
	if move.length() > 1.0:
		move = move.normalized()
	var amount := move.length()
	var desired := Vector3(move.x, 0, move.y).normalized() if amount > 0.01 else heading
	var speed := Vector2(vel.x, vel.z).length()
	var sprinting := ctrl.sprint and stamina > 0.05 and amount > 0.3
	braking = ctrl.brake and stun_timer <= 0.0 and speed > 0.6 and not frozen
	var prev_heading := heading

	# steering: tight at low speed, wide arcs at full speed
	if amount > 0.15:
		var turn := lerpf(7.5, 2.3, clampf(speed / top_speed, 0.0, 1.0)) * (1.0 + 0.7 * blend) * turn_mult
		if braking:
			turn *= 0.4
		heading = _rotate_toward(heading, desired, turn * dt)

	# stride thrust along the blades, plus arcade direct thrust
	if amount > 0.15 and not braking:
		var top := top_speed * (1.12 if sprinting else 1.0) * (0.94 if carrying else 1.0)
		var a := accel * (1.3 if sprinting else 1.0)
		var align := maxf(0.0, heading.dot(desired))
		var room := clampf(1.0 - vel.dot(heading) / top, 0.0, 1.0)
		vel += heading * a * align * amount * room * dt
		var room_direct := clampf(1.0 - vel.dot(desired) / top, 0.0, 1.0)
		vel += desired * a * 0.35 * blend * amount * room_direct * dt

	# edges: sideways slide decays, most of it is carved into forward speed
	var fwd := vel.dot(heading)
	var lat := vel - heading * fwd
	lat.y = 0.0
	var grip := 0.8 if braking else lerpf(3.0, 9.0, blend) * grip_mult
	var lat_new := lat * exp(-grip * dt)
	if fwd > 0.3:
		fwd += (lat.length() - lat_new.length()) * 0.6
	vel = heading * fwd + lat_new

	if braking:
		var s := vel.length()
		vel *= maxf(0.0, s - 15.0 * dt) / s
	var s2 := vel.length()
	if s2 > 0.0:
		var coast := 0.0 if amount > 0.15 else 0.6 * blend
		vel *= maxf(0.0, s2 - (0.2 + 0.03 * s2 + coast) * dt) / s2

	if sprinting:
		stamina = maxf(0.0, stamina - 0.22 * dt)
	else:
		stamina = minf(1.0, stamina + 0.12 * dt)

	position += vel * dt
	position.y = 0.0
	var r := Rink.confine(position, RADIUS)
	var n: Vector2 = r[1]
	if n != Vector2.ZERO:
		position = r[0]
		var n3 := Vector3(n.x, 0, n.y)
		var vn := vel.dot(n3)
		if vn > 0.0:
			vel -= n3 * vn * 1.3
	var p2 := Rink.push_out_of_nets(Vector2(position.x, position.z), RADIUS)
	position = Vector3(p2.x, 0, p2.y)

	yaw_rate = prev_heading.signed_angle_to(heading, Vector3.UP) / dt
	# agility: cutting harder than you can handle works the puck loose
	if carrying and randf() < skills.turn_puck_loss(yaw_rate) * dt * (1.0 - 0.6 * blend):
		puck.release(self, vel + right_vec() * signf(yaw_rate) * 2.0)
	_update_blade(dt, blend)
	_handle_actions(dt, carrying)
	_apply_transform()
	_spray.emitting = braking and speed > 2.0
	rig.update_skater(self, dt)


func _update_blade(dt: float, blend: float) -> void:
	var target := DEFAULT_BLADE
	if ctrl.blade_target != null and stun_timer <= 0.0:
		var d: Vector3 = ctrl.blade_target - position
		target = Vector2(d.dot(heading), d.dot(right_vec()))
	# reach: an annulus in front of and beside the body
	var reach := clampf(target.length(), REACH_MIN, REACH_MAX)
	var ang := clampf(atan2(target.y, target.x), -STICK_ANGLE_LIMIT, STICK_ANGLE_LIMIT)
	target = Vector2(cos(ang), sin(ang)) * reach
	var w := windup()
	if w > 0.0:
		target = target.lerp(Vector2(-0.35, 0.8), w)
	var max_speed := lerpf(8.0, 12.0, blend) * handling
	var step := (target - blade_local) * minf(1.0, 22.0 * dt)
	blade_local += step.limit_length(max_speed * dt)
	blade_height = w * 0.9
	var prev := blade_pos
	blade_pos = _blade_world(blade_local)
	blade_vel = (blade_pos - prev) / dt


func _handle_actions(dt: float, carrying: bool) -> void:
	var held: bool = ctrl.shoot_held and stun_timer <= 0.0 and not game.is_frozen()
	if held and not _prev_shoot:
		shoot_hold_time = 0.0
		_anchor_local = blade_local
	if held:
		shoot_hold_time += dt
	if not held and _prev_shoot:
		_release_shot()
	_prev_shoot = held

	if ctrl.flick > 0.0 and carrying:
		shoot(false, 0.0, ctrl.flick)
	if ctrl.pass_pressed and has_puck():
		pass_puck()
	if ctrl.check_pressed and check_cd <= 0.0 and stun_timer <= 0.0:
		check_timer = 0.35
		check_cd = 1.2
		game.stats.checks += 1
		vel += heading * 2.5 * lerpf(0.85, 1.15, skills.n("hitting"))


func _release_shot() -> void:
	var slap := shoot_hold_time > SLAP_DELAY
	var charge := clampf((shoot_hold_time - SLAP_DELAY) / skills.slap_windup_time(), 0.0, 1.0)
	# release skill: how good a shot is after winding this long
	var quality := 1.0 if slap else skills.shot_quality(shoot_hold_time)
	shoot_hold_time = 0.0
	if has_puck():
		shoot(slap, charge, 1.0, quality)
		return
	# one-timer / snapshot at a loose puck near the blade
	var reach := lerpf(0.5, 0.95, Tuning.blend)
	var d := Vector2(puck.position.x - blade_pos.x, puck.position.z - blade_pos.z).length()
	if puck.controller == null and not puck.frozen and puck.position.y < 0.6 and d < reach and puck.can_be_touched_by(self):
		shoot(slap, charge, 0.9, quality)


func attack_goal() -> Vector3:
	return Vector3(game.attack_side(team) * Rink.GOAL_X, 0, 0)


func shoot(slap: bool, charge: float, power: float, quality := 1.0) -> void:
	var blend: float = Tuning.blend
	var from := puck.position
	var net := attack_goal()
	var aim: Vector3 = ctrl.aim_point if ctrl.aim_point != null else net
	var dir := Vector3(aim.x - from.x, 0, aim.z - from.z)
	dir = dir.normalized() if dir.length() > 0.3 else heading
	# aim assist: pull shots that are roughly on net toward a spot inside the posts
	var to_net := Vector3(net.x - from.x, 0, net.z - from.z)
	var net_dist := to_net.length()
	if blend > 0.0 and net_dist > 1.0 and dir.angle_to(to_net) < deg_to_rad(18.0 + 30.0 * blend):
		var t := (net.x - from.x) / dir.x if absf(dir.x) > 0.05 else 0.0
		var hit_z := clampf(from.z + dir.z * t, -0.78, 0.78) if t > 0.0 else 0.0
		var assisted := Vector3(net.x - from.x, 0, hit_z - from.z).normalized()
		dir = dir.slerp(assisted, 0.85 * blend)
	# accuracy suffers when moving fast, more so in sim mode and on slapshots
	var err := skills.shot_error(quality) * lerpf(1.5, 0.6, blend) * (1.0 + Vector2(vel.x, vel.z).length() / top_speed * 0.6) * (1.4 if slap else 1.0)
	dir = dir.rotated(Vector3.UP, randf_range(-err, err))
	var spd := (lerpf(27.0, 43.0, charge) if slap else 24.0 * lerpf(0.75, 1.1, power)) * skills.shot_speed_mult(quality)
	# choose a target height at the net and solve for the lift that gets there
	# shooters pick a corner: along the ice or up high
	var h_target := randf_range(0.05, 0.3) if (slap or randf() < 0.5) else randf_range(0.75, 1.15)
	var vy := 0.0
	if net_dist < 22.0:
		var tt := net_dist / spd
		vy = minf((h_target + 0.5 * Puck.GRAVITY * tt * tt) / tt, spd * 0.45)
	else:
		vy = randf_range(0.0, 2.0)
	puck.release(self, dir * spd + Vector3.UP * vy)
	puck.pass_target = null
	game.on_shot(self, slap)


func pass_puck() -> void:
	var blend: float = Tuning.blend
	var dir2: Vector2 = ctrl.pass_dir if ctrl.pass_dir.length() > 0.2 else Vector2(heading.x, heading.z)
	dir2 = dir2.normalized()
	var best: Skater = ctrl.pass_hint
	if best == null:
		var best_score := INF
		var cone := deg_to_rad(45.0 + 55.0 * blend)
		for mate in game.teammates(self):
			var to := Vector2(mate.position.x - position.x, mate.position.z - position.z)
			var ang := absf(dir2.angle_to(to))
			if ang > cone:
				continue
			var score := ang + to.length() * 0.015
			if score < best_score:
				best_score = score
				best = mate
	var target: Vector3
	var spd := 16.0
	if best:
		var dist := position.distance_to(best.position)
		spd = clampf(dist * 0.9 + 8.0, 10.0, 22.0)
		var t := dist / spd
		target = best.position + best.vel * t * (0.6 + 0.4 * blend) + best.heading * 0.7
	else:
		target = position + Vector3(dir2.x, 0, dir2.y) * 12.0
	var d := Vector3(target.x - puck.position.x, 0, target.z - puck.position.z).normalized()
	d = d.rotated(Vector3.UP, randf_range(-1.0, 1.0) * skills.pass_error() * lerpf(1.3, 0.6, blend))
	puck.release(self, d * spd)
	puck.pass_target = best
	puck.pass_bonus = skills.tape_to_tape_bonus()


func _blade_world(local: Vector2) -> Vector3:
	return position + heading * local.x + right_vec() * local.y


func _apply_transform() -> void:
	basis = Basis(Vector3.UP, atan2(-heading.x, -heading.z))


static func _rotate_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var a := from.signed_angle_to(to, Vector3.UP)
	return from.rotated(Vector3.UP, clampf(a, -max_angle, max_angle)).normalized()


func _make_spray() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.45
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	p.position = Vector3(0, 0.05, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f4f6fa")
	m.material = mat
	p.mesh = m
	return p
