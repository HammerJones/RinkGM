class_name StickPuck
extends RefCounted
## Stick-on-puck contact, run every puck substep:
##  * the carrier's blade pulls the puck with a damped spring, but the blade can
##    only push so hard (PhysicsProfile.puck_grip). Turn, stop or stickhandle
##    harder than that and the puck slides off the blade.
##  * a loose puck is trapped when it arrives slow enough for the receiver
##    (trap_speed, plus the passer's touch if it was meant for them), otherwise
##    it deflects off the blade
##  * an opponent's blade can poke a carried puck loose


static func step(g: Node, puck: Puck, dt: float) -> void:
	if puck.frozen or puck.in_net_side != 0:
		return
	var blend: float = Tuning.blend
	var carrier := puck.controller
	if carrier:
		_carry(carrier, puck, dt, blend)
	if puck.position.y > 0.3:
		return
	for s: Skater in g.skaters:
		if s == puck.controller or not s.blade_down() or not puck.can_be_touched_by(s):
			continue
		var d := puck.position - s.blade_pos
		d.y = 0.0
		var dist := d.length()
		var cap := s.profile.catch_radius * lerpf(1.0, 1.2, blend)
		if dist > cap:
			continue
		var holder := puck.controller
		if holder != null:
			if holder.team != s.team:
				_poke(s, holder, puck, d, dist, dt)
			continue
		var rel := puck.vel - s.blade_vel
		rel.y = 0.0
		var thresh := s.profile.trap_speed * lerpf(1.0, 1.4, blend)
		if puck.pass_target == s:
			thresh += puck.pass_touch
		if rel.length() < thresh:
			puck.controller = s
			puck.pass_target = null
			puck.last_touch = s
			puck.vel.y = 0.0
			puck.position.y = 0.0
			g.on_possession(s)
			return
		# too hot to handle: it bounces off the blade
		if dist > 0.001:
			var n := d / dist
			var vn := rel.dot(n)
			if vn < 0.0:
				puck.vel -= n * vn * 1.4
				puck.vel *= 0.8
				puck.last_touch = s
			puck.position += n * (cap - dist)


static func _carry(carrier: Skater, puck: Puck, dt: float, blend: float) -> void:
	if carrier.stun_timer > 0.0 or carrier.stick_lifted_timer > 0.0:
		puck.controller = null
		return
	var to := carrier.puck_anchor() - puck.position
	to.y = 0.0
	# with the blade lifted over the puck there's no contact; you keep it only
	# if you set the blade back down close enough
	if carrier.blade_down():
		var sh := carrier.skill("stick_handling")
		var k := lerpf(180.0, 450.0, blend) * lerpf(0.75, 1.25, sh)
		var rel := puck.vel - carrier.blade_vel
		rel.y = 0.0
		var acc := to * k - rel * 2.0 * sqrt(k) * 0.9
		var grip := carrier.profile.puck_grip * lerpf(1.0, 1.4, blend)
		if acc.length() > grip:
			acc = acc.limit_length(grip)
			carrier.puck_slip += dt
		puck.vel += acc * dt
	# a deke (blade lifted over to the far side, then set back down) gets the
	# stick's full reach before the puck counts as lost
	var keep := lerpf(0.45, 0.7, blend)
	if carrier.lifting or carrier.regrab_timer > 0.0:
		keep = Skater.REACH_MAX * 0.8
	if to.length() > keep:
		puck.controller = null
		puck.last_touch = carrier


## An opponent's blade on a carried puck: a quick poke knocks it loose, and
## steady pressure works it free more often against weak stickhandlers.
static func _poke(s: Skater, holder: Skater, puck: Puck, d: Vector3, dist: float, dt: float) -> void:
	var poke := (s.blade_vel - holder.blade_vel).length()
	var h_sh := holder.skill("stick_handling")
	var s_sh := s.skill("stick_handling")
	var needed := lerpf(2.8, 4.8, h_sh)
	var steal_rate := lerpf(0.6, 2.2, s_sh) * lerpf(1.6, 0.45, h_sh)
	if poke > needed or randf() < dt * steal_rate:
		puck.controller = null
		var away := d.normalized() if dist > 0.001 else s.heading
		puck.vel = away * 3.0 + s.blade_vel * 0.5
		puck.vel.y = 0.0
		puck.ignore_briefly(holder, 0.3)
		puck.last_touch = s
