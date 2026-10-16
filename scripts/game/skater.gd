class_name Skater
extends Node3D
## A skater simulated as a point mass on edges:
##  * thrust only along the direction the skates point, so you carve turns
##  * lateral velocity bleeds off through edge grip (part of it is kept as
##    forward speed, the "carve"), turning gets wider the faster you go
##  * a dash is a burst stride up to top speed; the hockey stop scrapes
##    speed off sideways
##  * the stick blade is its own point that moves at a limited speed inside a
##    90 degree arc in front of the body; the puck follows it on a spring whose
##    force is capped by the skater's grip (see StickPuck), so turning or
##    stickhandling harder than your skill allows works the puck loose
## Every number comes from `profile` (PhysicsProfile, built from `stats`), and
## Tuning.blend (0 sim .. 1 arcade) adds grip, turn rate, direct thrust and
## shot/pass assistance on top of the same model.

const RADIUS := 0.38
const MASS := 85.0
const REACH_MIN := 0.55
const REACH_MAX := 1.5
const ARC_HALF := PI / 4.0                 # the blade's 90 degree arc
const DEFAULT_BLADE := Vector2(0.95, 0.3)  # (forward, right) relative to the body
const WIND_SPOT := Vector2(-0.15, 0.8)     # where a drawn-back blade sits
const SLAP_MIN := 0.18                     # a lifted wind-up shorter than this is a wrist shot
const LIFT_HEIGHT := 0.22
const STICK_LIFTED_TIME := 0.55
const FLICK_WINDOW := 0.09   # a flick is measured over this much stick history
const FLICK_TRAVEL := 0.9    # forward stick travel inside the window that counts as a flick


## What a controller (human or AI) wants this frame. Input code fills this in;
## the simulation never reads devices directly.
class Controls:
	var move := Vector2.ZERO          ## world XZ, length <= 1 (left stick)
	var dash := false                 ## pressed this frame (L3)
	var stop := false                 ## held: hockey stop (R3)
	var stick := Vector2.ZERO         ## world XZ, length <= 1 (right stick); back = wind up
	var blade_target: Variant = null  ## world Vector3 (mouse); overrides `stick`
	var lift := false                 ## held: stick lift (LT)
	var tilt := 0.0                   ## 0..1 blade tilt, lofts shots and passes (RT)
	var shoot := false                ## held: button shot, release to fire
	var aim_point: Variant = null     ## world Vector3 or null to aim at the net
	var pass_pressed := false
	var pass_dir := Vector2.ZERO
	var pass_hint: Variant = null     ## Skater the AI wants to pass to
	var check := false                ## pressed this frame: shoulder check

	func reset() -> void:
		move = Vector2.ZERO
		dash = false
		stop = false
		stick = Vector2.ZERO
		blade_target = null
		lift = false
		tilt = 0.0
		shoot = false
		aim_point = null
		pass_pressed = false
		pass_dir = Vector2.ZERO
		pass_hint = null
		check = false


var game: Node
var puck: Puck
var team := 0
var number := 0
var ctrl := Controls.new()
## Ratings (career/skills.gd, 1..100). Injuries and fatigue arrive as
## Skills.modifiers, so the profile is re-derived every frame.
var skills: Skills
var profile := PhysicsProfile.new()

var vel := Vector3.ZERO
var heading := Vector3(1, 0, 0)
var yaw_rate := 0.0
var turn_load := 0.0   ## m/s^2 of sideways load from turning, hurts balance
var braking := false
var stamina := 1.0
var stun_timer := 0.0
var check_timer := 0.0
var check_cd := 0.0
var dash_cd := 0.0
var dash_timer := 0.0

var blade_local := DEFAULT_BLADE
var blade_pos := Vector3.ZERO
var blade_vel := Vector3.ZERO
var blade_lvel := Vector2.ZERO  ## blade velocity relative to the body (forward, right)
var blade_height := 0.0
var lifting := false            ## own blade held up over the puck
var stick_lifted_timer := 0.0   ## an opponent lifted this stick
var lift_cd := 0.0
var regrab_timer := 0.0         ## grace after a deke to set the blade back on the puck
var puck_slip := 0.0            ## seconds the puck spent at the grip limit (for tuning)

# shot wind-up: started by drawing the stick back or holding `shoot`
var winding := false
var wind_time := 0.0
var wind_slap := false

# AI scratch state
var ai_decide := 0.0
var ai_shoot_timer := 0.0
var ai_aim: Variant = null
var ai_slap := false
var ai_tilt := 0.0

var rig: SkaterRig
var _prev_shoot := false
var _prev_lift := false
var _stick_wound := false
var _wind_grace := 0.0
var _stick_hist: Array[Vector3] = []  # (x, z, age) of recent right-stick input, for flicks
var _anchor_local := DEFAULT_BLADE
var _spray: CPUParticles3D


func setup(g: Node, t: int, idx: int, pal: Dictionary, sk: Skills = null) -> void:
	game = g
	puck = g.puck
	team = t
	number = idx
	if sk == null:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		sk = Skills.create(Skills.SKATER_KEYS, 50.0, 6.0, rng)
	set_skills(sk)
	if pal.is_empty():
		return
	rig = SkaterRig.new()
	add_child(rig)
	rig.build(pal, false)
	_spray = _make_spray()
	add_child(_spray)


## Swaps in a player's ratings (line changes call this on a live body).
func set_skills(sk: Skills) -> void:
	skills = sk
	profile.apply(skills)


## A rating as 0..1 (canonical Skills keys only).
func skill(key: String) -> float:
	if not key in Skills.SKATER_KEYS:
		push_error("unknown skill '%s'" % key)
		return 0.5
	return skills.n(key)


func place(p: Vector2, facing: Vector3) -> void:
	position = Vector3(p.x, 0, p.y)
	vel = Vector3.ZERO
	heading = facing.normalized()
	blade_local = DEFAULT_BLADE
	blade_pos = _blade_world(blade_local)
	blade_vel = Vector3.ZERO
	blade_lvel = Vector2.ZERO
	stun_timer = 0.0
	stick_lifted_timer = 0.0
	cancel_shot()
	_apply_transform()


func has_puck() -> bool:
	return puck.controller == self


func right_vec() -> Vector3:
	return heading.cross(Vector3.UP)


func speed() -> float:
	return Vector2(vel.x, vel.z).length()


func cancel_shot() -> void:
	ctrl.shoot = false
	_prev_shoot = false
	_stick_wound = false
	winding = false
	wind_time = 0.0


## 0..1 visual wind-up for the rig and HUD.
func windup() -> float:
	if not winding:
		return 0.0
	return profile.charge(wind_time)


## True while the blade can touch the puck.
func blade_down() -> bool:
	return stun_timer <= 0.0 and stick_lifted_timer <= 0.0 and not lifting and not (winding and wind_slap)


## Where the puck is pulled to while carried. During a slapshot wind-up the
## blade lifts away, so the puck stays where the wind-up started.
func puck_anchor() -> Vector3:
	if winding and wind_slap:
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
	dash_cd = maxf(0.0, dash_cd - dt)
	dash_timer = maxf(0.0, dash_timer - dt)
	lift_cd = maxf(0.0, lift_cd - dt)
	stick_lifted_timer = maxf(0.0, stick_lifted_timer - dt)
	profile.apply(skills)
	var p := profile
	var frozen: bool = game.is_frozen()
	var able := stun_timer <= 0.0 and not frozen
	var move := ctrl.move if able else Vector2.ZERO
	if move.length() > 1.0:
		move = move.normalized()
	var amount := move.length()
	var desired := Vector3(move.x, 0, move.y).normalized() if amount > 0.01 else heading
	var spd := speed()
	var top := p.max_speed * lerpf(0.9, 1.0, stamina)
	braking = ctrl.stop and able and spd > 0.6
	var prev_heading := heading

	# steering: tight at low speed, wide arcs at full speed
	if amount > 0.15:
		var turn := lerpf(p.turn_slow, p.turn_fast, clampf(spd / p.max_speed, 0.0, 1.0)) * (1.0 + 0.5 * blend)
		if braking:
			turn *= 0.4
		heading = _rotate_toward(heading, desired, turn * dt)

	# stride thrust along the blades, plus arcade direct thrust
	if amount > 0.15 and not braking:
		var align := maxf(0.0, heading.dot(desired))
		# strides stay strong until you're close to top speed
		var room := sqrt(clampf(1.0 - vel.dot(heading) / top, 0.0, 1.0))
		vel += heading * p.accel * align * amount * room * dt
		var room_direct := clampf(1.0 - vel.dot(desired) / top, 0.0, 1.0)
		vel += desired * p.accel * 0.35 * blend * amount * room_direct * dt

	# dash: a burst stride toward the stick, up to (never past) top speed
	if ctrl.dash and able and dash_cd <= 0.0 and stamina > 0.15 and not braking:
		var dir := desired if amount > 0.2 else heading
		var gain := clampf(top - vel.dot(dir), 0.0, p.dash_boost)
		vel += dir * gain
		dash_cd = p.dash_cooldown
		dash_timer = 0.45
		stamina -= 0.16

	# edges: sideways slide decays, most of it is carved into forward speed
	var fwd := vel.dot(heading)
	var lat := vel - heading * fwd
	lat.y = 0.0
	var grip := 0.8 if braking else p.edge_grip * lerpf(1.0, 1.8, blend)
	var lat_new := lat * exp(-grip * dt)
	if fwd > 0.3:
		# carving keeps speed through a turn but never adds speed past top
		fwd = minf(fwd + (lat.length() - lat_new.length()) * 0.6, maxf(fwd, top))
	vel = heading * fwd + lat_new

	if braking:
		var s := vel.length()
		vel *= maxf(0.0, s - p.stop_decel * dt) / s
	var s2 := vel.length()
	if s2 > 0.0:
		var coast := 0.0 if amount > 0.15 else 0.6 * blend
		var drag := 0.2 + 0.03 * s2 + coast
		vel *= maxf(0.0, s2 - drag * dt) / s2
	# max_speed is an absolute ceiling for skating (25 mph at speed 100);
	# only hits can push a skater past it
	if stun_timer <= 0.0:
		vel = vel.limit_length(p.max_speed)

	stamina = minf(1.0, stamina + 0.1 * dt)

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
	turn_load = absf(yaw_rate) * speed()
	_update_blade(dt, blend)
	_handle_actions(dt)
	_apply_transform()
	if _spray:
		_spray.emitting = braking and spd > 2.0
	if rig:
		rig.update_skater(self, dt)


## Balance against hits: 1.0 when set, lower while carving hard or stopping.
## Agile skaters lose less of it.
func stability() -> float:
	var agi := skill("agility")
	var load := clampf(turn_load / 30.0, 0.0, 1.0) * lerpf(0.3, 0.1, agi)
	return (1.0 - load) * (0.85 if braking else 1.0) * (0.8 if dash_timer > 0.0 else 1.0)


# ---------------------------------------------------------------- stick

func _stick_local(world: Vector2) -> Vector2:
	var w := Vector3(world.x, 0, world.y)
	return Vector2(w.dot(heading), w.dot(right_vec()))


## True when the right stick points behind the skater (drawing back to shoot).
func _stick_drawn() -> bool:
	if ctrl.stick.length() < 0.5:
		return false
	var l := _stick_local(ctrl.stick)
	return absf(atan2(l.y, l.x)) > deg_to_rad(110.0)


func _update_blade(dt: float, blend: float) -> void:
	var target := DEFAULT_BLADE
	var able := stun_timer <= 0.0
	if able and ctrl.blade_target != null:
		var d: Vector3 = ctrl.blade_target - position
		target = Vector2(d.dot(heading), d.dot(right_vec()))
	elif able and ctrl.stick.length() > 0.2:
		var l := _stick_local(ctrl.stick)
		var mag := minf(l.length(), 1.0)
		target = Vector2(cos(atan2(l.y, l.x)), sin(atan2(l.y, l.x))) * lerpf(REACH_MIN, REACH_MAX, mag)
	# keep it inside the 90 degree arc and the stick's reach
	var reach := clampf(target.length(), REACH_MIN, REACH_MAX)
	var ang := clampf(atan2(target.y, target.x), -ARC_HALF, ARC_HALF)
	target = Vector2(cos(ang), sin(ang)) * reach
	if winding:
		target = target.lerp(WIND_SPOT, minf(1.0, wind_time / 0.12))
	# the blade chases the target with limited speed and acceleration
	var want := (target - blade_local) * profile.blade_response
	want = want.limit_length(profile.blade_speed * lerpf(1.0, 1.25, blend))
	blade_lvel = blade_lvel.move_toward(want, profile.blade_accel * lerpf(1.0, 1.25, blend) * dt)
	blade_local += blade_lvel * dt
	var was_lifting := lifting
	lifting = ctrl.lift and able and not winding
	regrab_timer = 0.3 if (was_lifting and not lifting) else maxf(0.0, regrab_timer - dt)
	var h := 0.0
	if stick_lifted_timer > 0.0:
		h = 0.35
	elif winding and wind_slap:
		h = 0.9 * windup() + 0.2
	elif lifting:
		h = LIFT_HEIGHT
	blade_height = lerpf(blade_height, h, minf(1.0, 25.0 * dt))
	var prev := blade_pos
	blade_pos = _blade_world(blade_local)
	blade_vel = (blade_pos - prev) / dt


# ---------------------------------------------------------------- actions

func _handle_actions(dt: float) -> void:
	var able: bool = stun_timer <= 0.0 and not game.is_frozen() and stick_lifted_timer <= 0.0
	_handle_shot_input(dt, able)
	var lift_pressed := ctrl.lift and not _prev_lift
	_prev_lift = ctrl.lift
	if lift_pressed and able and not has_puck() and lift_cd <= 0.0:
		_try_stick_lift()
	if ctrl.pass_pressed and has_puck() and able:
		pass_puck()
	if ctrl.check and check_cd <= 0.0 and stun_timer <= 0.0:
		check_timer = 0.35
		check_cd = 1.2
		game.stats.checks += 1
		vel += heading * lerpf(1.5, 3.0, skill("hitting"))


## Two ways to shoot, both through the same wind-up:
##  * stick: pull the right stick back (wind-up), then push it forward
##  * button: hold `shoot` to wind up, release to fire
## Holding lift when the wind-up starts makes it a slapshot.
func _handle_shot_input(dt: float, able: bool) -> void:
	if not able:
		if winding:
			cancel_shot()
		_prev_shoot = ctrl.shoot
		return
	if _flicked(dt):
		_fire()
		return
	var drawn := _stick_drawn()
	var held := ctrl.shoot
	if not winding and ((held and not _prev_shoot) or drawn):
		winding = true
		wind_time = 0.0
		wind_slap = ctrl.lift
		_stick_wound = drawn and not held
		_wind_grace = 0.0
		_anchor_local = blade_local
	_prev_shoot = held
	if not winding:
		return
	wind_time += dt
	if _stick_wound:
		if drawn:
			_wind_grace = 0.0
			return
		var l := _stick_local(ctrl.stick)
		if ctrl.stick.length() > 0.5 and l.x > 0.0:
			_fire()
			return
		_wind_grace += dt
		if _wind_grace > 0.25:
			cancel_shot()
	elif not held:
		_fire()


## A quick forward flick of the right stick, with no wind-up, fires the
## instant shot (weak and wild until shot release improves).
func _flicked(dt: float) -> bool:
	for i in _stick_hist.size():
		_stick_hist[i].z += dt
	_stick_hist.append(Vector3(ctrl.stick.x, ctrl.stick.y, 0.0))
	while _stick_hist.size() > 2 and _stick_hist[1].z >= FLICK_WINDOW:
		_stick_hist.pop_front()
	if winding or ctrl.stick.length() < 0.8 or not has_puck():
		return false
	var l := _stick_local(ctrl.stick)
	if l.x < 0.5:
		return false
	var travel := _stick_local(ctrl.stick - Vector2(_stick_hist[0].x, _stick_hist[0].y)).x
	if travel < FLICK_TRAVEL:
		return false
	_stick_hist.clear()
	return true


func _fire() -> void:
	var held := wind_time
	var slap := wind_slap and held >= SLAP_MIN
	winding = false
	_stick_wound = false
	wind_time = 0.0
	# the blade follows through
	blade_local = Vector2(REACH_MAX * 0.85, 0.15)
	blade_lvel = Vector2.ZERO
	if has_puck():
		shoot(held, slap)
		return
	# one-timer / snapshot at a loose puck near the blade
	var reach := profile.catch_radius * 1.8 * lerpf(1.0, 1.4, Tuning.blend)
	var d := Vector2(puck.position.x - blade_pos.x, puck.position.z - blade_pos.z).length()
	if puck.controller == null and not puck.frozen and puck.position.y < 0.6 and d < reach and puck.can_be_touched_by(self):
		shoot(held, slap, puck.horizontal_speed())


func attack_goal() -> Vector3:
	return Vector3(game.attack_side(team) * Rink.GOAL_X, 0, 0)


## Fires the puck. `held` is the wind-up time, `incoming` the speed of a puck
## being one-timed.
func shoot(held: float, slap: bool, incoming := 0.0) -> void:
	var blend: float = Tuning.blend
	var p := profile
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
	var spd: float
	var err := p.aim_error(held)
	if slap:
		spd = p.shot_speed * lerpf(0.6, 1.0, clampf((held - SLAP_MIN) / (p.charge_time + 0.25), 0.0, 1.0))
		err *= 1.35
	else:
		spd = p.wrist_speed(held)
	if incoming > 0.0:
		spd += incoming * 0.25
		err *= 1.3
	# moving fast, carving hard or being off balance costs accuracy
	err *= 1.0 + 0.4 * speed() / p.max_speed + turn_load / 40.0
	err *= lerpf(1.0, 0.6, blend)
	dir = dir.rotated(Vector3.UP, clampf(randfn(0.0, err), -3.0 * err, 3.0 * err))
	# pick a target height at the net and solve for the lift that gets there:
	# tilt opens the blade and raises the shot
	var h_target: float
	if ctrl.tilt > 0.05:
		h_target = lerpf(0.25, 1.1, ctrl.tilt)
	else:
		h_target = randf_range(0.04, 0.22)
	h_target = maxf(0.0, h_target + randfn(0.0, err * net_dist * 0.5))
	var vy := 0.0
	if net_dist < 24.0:
		var tt := net_dist / spd
		vy = minf((h_target + 0.5 * Puck.GRAVITY * tt * tt) / tt, spd * 0.45)
	else:
		vy = ctrl.tilt * 4.0
	puck.release(self, dir * spd + Vector3.UP * vy)
	puck.pass_target = null
	game.on_shot(self, slap)


func pass_puck() -> void:
	var blend: float = Tuning.blend
	var p := profile
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
		spd = clampf(dist * 0.55 + 7.0, 8.0, 17.0)
		var t := dist / spd
		# aim at the receiver's blade, led by where they're skating
		target = best.blade_pos + best.vel * t * (0.6 + 0.4 * blend)
	else:
		target = position + Vector3(dir2.x, 0, dir2.y) * 12.0
	var d := Vector3(target.x - puck.position.x, 0, target.z - puck.position.z).normalized()
	var err := p.pass_error * (1.0 + 0.3 * speed() / p.max_speed) * lerpf(1.0, 0.5, blend)
	d = d.rotated(Vector3.UP, clampf(randfn(0.0, err), -3.0 * err, 3.0 * err))
	# a tilted blade saucers the pass over sticks
	puck.release(self, d * spd + Vector3.UP * ctrl.tilt * 3.2)
	puck.pass_target = best
	puck.pass_touch = p.pass_touch


## Defensive stick lift: lift the carrier's stick off the puck. Works when
## your blade is near their stick; the odds come from both skaters' ratings.
func _try_stick_lift() -> void:
	lift_cd = 0.9
	var holder: Skater = puck.controller
	if holder == null or holder.team == team or holder.stick_lifted_timer > 0.0:
		return
	# anywhere along their stick, from the hands out to the blade
	var me := Vector2(blade_pos.x, blade_pos.z)
	var on_stick := Geometry2D.get_closest_point_to_segment(me,
		Vector2(holder.position.x, holder.position.z), Vector2(holder.blade_pos.x, holder.blade_pos.z))
	if me.distance_to(on_stick) > 0.8:
		return
	var odds := 0.5 + 0.45 * (profile.stick_lift - holder.skill("stick_handling")) + 0.15 * Tuning.blend
	if randf() > clampf(odds, 0.15, 0.92):
		return
	holder.stick_lifted_timer = STICK_LIFTED_TIME
	holder.cancel_shot()
	puck.controller = null
	puck.ignore_briefly(holder, STICK_LIFTED_TIME)
	puck.last_touch = self
	game.on_stick_lift(self, holder)


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
