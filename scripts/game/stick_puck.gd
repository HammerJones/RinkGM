class_name StickPuck
extends RefCounted
## The puck is a real object on the ice and the blade is a real object
## around it, run every puck substep:
##  * no blade passes through the puck: a moving blade pushes it, its face
##    drags it along a little, and a blade raised off the ice passes over it.
##    Every skater's blade does this, opponents' included, so poke checks and
##    stick battles are just blades hitting the puck.
##  * the carrier's soft hands cup the puck against the face, as hard as their
##    grip (PhysicsProfile.puck_grip) allows; cut or stickhandle harder than
##    that and it slides away. To move it the other way they lift the blade
##    over it and set it down on the far side (Skater does that on its own).
##  * a loose puck that meets a blade slowly enough (trap_speed, plus the
##    passer's touch if it was meant for them) is trapped; a little hotter,
##    good hands can cushion it; hotter still, it comes off the blade.

const BLADE_HALF := 0.16    # half the blade's length (m)
const BLADE_THICK := 0.012  # half the blade's thickness (m)
const BLADE_TOP := 0.09     # a puck higher than this goes over the blade
const BLADE_CLEAR := 0.03   # a blade this high off the ice passes over the puck
const SWEEP := 0.12         # how far past the face a fast blade can get in one substep and still push
const BOUNCE_LOOSE := 0.3   # restitution off a blade
const BOUNCE_CARRY := 0.05  # ... off the carrier's own soft hands
const FACE_GRIP := 0.08     # per substep, share of the along-blade slip the face drags out
const CUP_PULL := 25.0      # 1/s, how quickly the cup draws the puck back onto the face
const CUP_CENTRE := 10.0    # 1/s, ... and towards the middle of the blade


static func blade_at(s: Skater, f: float) -> Array:
	var bp: Vector3 = s.blade_from.lerp(s.blade_pos, f)
	var c := Vector2(bp.x, bp.z)
	var ax := c - Vector2(s.position.x, s.position.z)
	ax = ax.normalized() if ax.length() > 0.05 else Vector2(s.heading.x, s.heading.z)
	ax = ax.rotated(s.blade_yaw)
	return [c, ax, Vector2(-ax.y, ax.x)]


## How close the puck's centre comes to the blade's face.
static func gap() -> float:
	return Puck.RADIUS + BLADE_THICK


static func step(g: Node, puck: Puck, dt: float, f := 1.0) -> void:
	if puck.frozen or puck.in_net_side != 0:
		return
	var blend: float = Tuning.blend
	var carrier := puck.controller
	if carrier and (carrier.stun_timer > 0.0 or carrier.stick_lifted_timer > 0.0 or carrier.stick_broken):
		puck.controller = null
		carrier = null
	if carrier and MovePhysics.glued(carrier.move_id):
		# a cradling move (lacrosse): the puck rides up on the blade until it's done
		var at := carrier.puck_anchor()
		puck.vel = (at - puck.position) / dt if dt > 0.0 else Vector3.ZERO
		puck.vel = puck.vel.limit_length(25.0)
		if at.y <= 0.001:
			puck.vel.y = 0.0
		return
	if carrier and carrier.winding and carrier.wind_slap:
		# the blade is up for the slapshot: the puck slides on where it was
		# left, at about the skater's pace
		puck.vel = puck.vel.lerp(Vector3(carrier.vel.x, puck.vel.y, carrier.vel.z), 1.0 - exp(-4.0 * dt))
	if puck.position.y > BLADE_TOP:
		if carrier and puck.position.distance_to(carrier.blade_pos) > 1.2:
			puck.controller = null
		return
	for s: Skater in g.skaters:
		if _contact(g, s, puck, dt, f, blend):
			return
	carrier = puck.controller
	if carrier and not (carrier.winding and carrier.wind_slap):
		# (a slapshot's puck waits on the ice for the blade to come down)
		_cup(carrier, puck, dt, f, blend)
		_keep(carrier, puck, f, blend)


## The puck against one skater's blade: it can't pass through the blade's
## face, a moving blade pushes it, the face drags it along a little, and a
## raised blade passes over it. A loose puck that meets the blade gently
## enough is trapped. Returns true if this skater just took possession.
static func _contact(g: Node, s: Skater, puck: Puck, dt: float, f: float, blend: float) -> bool:
	if not puck.can_be_touched_by(s) or s.stun_timer > 0.0 or s.stick_lifted_timer > 0.0 or s.stick_broken:
		return false
	var seg := blade_at(s, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var n: Vector2 = seg[2]
	var p := Vector2(puck.position.x, puck.position.z)
	var along := (p - c).dot(ax)
	var q := c + ax * clampf(along, -BLADE_HALF, BLADE_HALF)
	var sd := (p - q).dot(n)
	var gp := gap()
	if s.blade_height > BLADE_CLEAR + puck.position.y or (s.winding and s.wind_slap):
		# the blade is up: it passes over, and the puck is on whichever side it ends up
		if absf(sd) > 0.001 and absf(along) < BLADE_HALF + gp:
			s.puck_side = signf(sd)
		return false
	if absf(along) > BLADE_HALF + gp or absf(sd) > gp + SWEEP:
		if absf(along) < BLADE_HALF + 0.5 and absf(sd) > gp:
			s.puck_side = signf(sd)
		return false
	var side := s.puck_side if s.puck_side != 0.0 else (signf(sd) if sd != 0.0 else 1.0)
	var hit := Vector2.ZERO
	if absf(along) <= BLADE_HALF:
		# along the face: it stays on its own side, even if the blade moved
		# past its centre this substep
		if sd * side < gp:
			hit = n * side
			p = q + hit * gp
	elif p.distance_to(q) < gp:
		# off the heel or the toe
		hit = (p - q).normalized()
		p = q + hit * gp
	if hit == Vector2.ZERO:
		if absf(sd) > gp:
			s.puck_side = signf(sd)
		return false
	s.puck_side = side if absf(along) <= BLADE_HALF else s.puck_side
	var vb := Vector2(s.blade_vel.x, s.blade_vel.z)
	var v := Vector2(puck.vel.x, puck.vel.z)
	var rel := v - vb
	var vn := rel.dot(hit)
	var holder := puck.controller
	var took := false
	if holder == null and vn < 0.0:
		var thresh := s.profile.trap_speed * lerpf(1.0, 1.4, blend)
		if puck.pass_target == s:
			thresh += puck.pass_touch
		var sh := s.skill("stick_handling")
		var cushion := thresh * lerpf(1.15, 1.45, sh)
		var spd := rel.length()
		if spd < thresh:
			# trapped: the blade gives with it and soaks up the speed
			v = vb + rel * 0.15 - hit * minf(vn * 0.15, 0.0)
			puck.controller = s
			puck.pass_target = null
			took = true
		elif spd < cushion and randf() < lerpf(0.3, 0.75, sh):
			# a little hotter than that, good hands cushion it, ready to settle
			v = vb + rel * 0.35
			v -= hit * minf((v - vb).dot(hit), 0.0)
		else:
			# too hot to handle: it comes off the blade
			StickWear.stress(s, pow(vn / 40.0, 4.0), &"block")
			v -= hit * vn * (1.0 + BOUNCE_LOOSE)
			v *= 0.85
	elif vn < 0.0:
		var bounce := BOUNCE_CARRY if holder == s else BOUNCE_LOOSE
		if holder != null and holder != s and holder.team != s.team and -vn > 4.0:
			# stick on stick for the puck
			StickWear.stress(s, 0.01 + (-vn) * 0.004, &"slash")
		v -= hit * vn * (1.0 + bounce)
	# the face drags it along the blade a little
	var tan := Vector2(-hit.y, hit.x)
	v -= tan * (v - vb).dot(tan) * FACE_GRIP
	puck.position.x = p.x
	puck.position.z = p.y
	puck.vel.x = v.x
	puck.vel.z = v.y
	puck.last_touch = s
	if took:
		puck.vel.y = 0.0
		puck.position.y = 0.0
		g.on_possession(s)
	return took


## The carrier's soft hands: with the blade down beside the puck they cup it,
## keeping it on the face and moving with the blade, but only as hard as
## their grip allows. It never pulls the puck through the blade; to move it
## the other way they have to get the blade round to the other side.
static func _cup(carrier: Skater, puck: Puck, dt: float, f: float, blend: float) -> void:
	if carrier.blade_height > BLADE_CLEAR + puck.position.y or carrier.lifting or carrier.puck_side == 0.0:
		return
	var seg := blade_at(carrier, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var n: Vector2 = seg[2]
	var p := Vector2(puck.position.x, puck.position.z)
	var along := (p - c).dot(ax)
	var face := (p - c).dot(n) * carrier.puck_side - gap()
	# soft hands feel for it out to the edge of control
	var reach := lerpf(0.3, 0.45, blend) * lerpf(1.0, 1.35, carrier.one_hand())
	if face < -0.01 or face > reach or absf(along) > BLADE_HALF + 0.1:
		return
	var vb := Vector2(carrier.blade_vel.x, carrier.blade_vel.z)
	var v := Vector2(puck.vel.x, puck.vel.z)
	# where the cup wants it: against the face, near the middle of the blade
	var want := vb - n * carrier.puck_side * face * CUP_PULL - ax * along * CUP_CENTRE
	var dv := want - v
	var grip := carrier.profile.puck_grip * lerpf(1.0, 1.4, blend) * lerpf(1.0, 0.7, carrier.one_hand())
	if dv.length() > grip * dt:
		dv = dv.limit_length(grip * dt)
		carrier.puck_slip += dt
	v += dv
	puck.vel.x = v.x
	puck.vel.z = v.y


## The carrier loses the puck once it's out of reach of the blade. With the
## blade up (going round the puck, a deke) they get the stick's reach.
static func _keep(carrier: Skater, puck: Puck, f: float, blend: float) -> void:
	var seg := blade_at(carrier, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var p := Vector2(puck.position.x, puck.position.z)
	var q := c + ax * clampf((p - c).dot(ax), -BLADE_HALF, BLADE_HALF)
	var keep := lerpf(0.3, 0.45, blend) * lerpf(1.0, 1.35, carrier.one_hand())
	if carrier.lifting or carrier.regrab_timer > 0.0 or carrier.blade_height > BLADE_CLEAR:
		keep = Skater.REACH_ONE_HAND * 0.7
	if p.distance_to(q) > keep:
		puck.controller = null
		puck.last_touch = carrier
