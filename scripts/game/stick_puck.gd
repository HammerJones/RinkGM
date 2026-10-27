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
##  * a loose puck that meets a blade bounces off it. A receiver's soft hands
##    give with the puck (PhysicsProfile.receive_e, low restitution), so a
##    good receiver soaks a pass up; it's theirs once it sits on the face,
##    barely moving against the blade. Nothing is captured by a rule.
##  * shots and passes are the blade swung through the puck (`strike`).

const BLADE_HALF := 0.16    # half the blade's length (m)
const BLADE_THICK := 0.012  # half the blade's thickness (m)
const BLADE_TOP := 0.09     # a puck higher than this goes over the blade
const BLADE_CLEAR := 0.03   # a blade this high off the ice passes over the puck
const SWEEP := 0.12         # how far past the face a fast blade can get in one substep and still push
const BOUNCE_LOOSE := 0.3   # restitution off a blade held stiff (a check, a block)
const TAPE_GRIP := 0.35     # friction coefficient of a taped blade face
const SETTLE := 1.5         # m/s: a puck this slow against the blade face is under control
const BOUNCE_CARRY := 0.05  # ... off the carrier's own soft hands
const FACE_GRIP := 0.08     # per substep, share of the along-blade slip the face drags out
const POCKET := 0.04        # m off the face that the blade's curve still wraps the puck
const CARRY_REACH := 0.375  # m off the face a carrier's hands still feel for it
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
	var carrier := puck.controller
	if carrier and (carrier.stun_timer > 0.0 or carrier.stick_lifted_timer > 0.0 or carrier.stick_broken):
		puck.controller = null
		carrier = null
	if carrier and MovePhysics.glued(carrier.move_id):
		_cradle(carrier, puck, dt)
		return
	if puck.position.y > BLADE_TOP:
		if carrier and puck.position.distance_to(carrier.blade_pos) > 1.2:
			puck.controller = null
		return
	for s: Skater in g.skaters:
		if _contact(g, s, puck, dt, f):
			return
	carrier = puck.controller
	if carrier and not (carrier.winding and carrier.wind_slap):
		# (a slapshot's puck waits on the ice for the blade to come down)
		_cup(carrier, puck, dt, f)
		_keep(carrier, puck, f)
	elif carrier == null:
		# the last blade to touch a loose puck keeps feeling for it: soft
		# hands cushion a pass onto the face the same way they hold a carry
		var r := puck.last_touch
		if r and r.blade_down() and puck.can_be_touched_by(r) and r.stun_timer <= 0.0 and _cup(r, puck, dt, f, false):
			var vb := Vector2(r.blade_vel.x, r.blade_vel.z)
			if (Vector2(puck.vel.x, puck.vel.z) - vb).length() < SETTLE:
				puck.controller = r
				g.on_possession(r)


## The puck against one skater's blade: it can't pass through the blade's
## face, a moving blade pushes it, the face drags it along a little, and a
## raised blade passes over it. A loose puck that meets the blade gently
## enough is trapped. Returns true if this skater just took possession.
static func _contact(g: Node, s: Skater, puck: Puck, dt: float, f: float) -> bool:
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
		# a loose puck meets the blade: a receiver's hands give with it
		var e := s.profile.receive_e if s.blade_down() else BOUNCE_LOOSE
		StickWear.stress(s, pow(vn / 40.0, 4.0), &"block")
		v -= hit * vn * (1.0 + e)
		# tape on the face grips the slip along it
		var slip := (v - vb) - hit * (v - vb).dot(hit)
		v -= slip.limit_length(-vn * (1.0 + e) * TAPE_GRIP)
		if (v - vb).length() < SETTLE:
			puck.controller = s
			took = true
	elif vn < 0.0:
		var bounce := BOUNCE_CARRY if holder == s else BOUNCE_LOOSE
		if holder != null and holder != s and holder.team != s.team and -vn > 4.0:
			# stick on stick for the puck
			StickWear.stress(s, 0.01 + (-vn) * 0.004, &"slash")
		v -= hit * vn * (1.0 + bounce)
	if holder == null and not took and (v - vb).length() < SETTLE:
		# resting against the face, moving with it
		puck.controller = s
		took = true
	# the face drags it along the blade a little
	var tan := Vector2(-hit.y, hit.x)
	v -= tan * (v - vb).dot(tan) * FACE_GRIP
	puck.position.x = p.x
	puck.position.z = p.y
	puck.vel.x = v.x
	puck.vel.z = v.y
	puck.last_touch = s
	if took:
		g.on_possession(s)
	return took


## The carrier's soft hands: with the blade down beside the puck they cup it,
## keeping it on the face and moving with the blade, but only as hard as
## their grip allows. It never pulls the puck through the blade; to move it
## the other way they have to get the blade round to the other side.
static func _cup(carrier: Skater, puck: Puck, dt: float, f: float, holding := true) -> bool:
	if carrier.blade_height > BLADE_CLEAR + puck.position.y or carrier.lifting or carrier.puck_side == 0.0:
		return false
	var seg := blade_at(carrier, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var n: Vector2 = seg[2]
	var p := Vector2(puck.position.x, puck.position.z)
	var along := (p - c).dot(ax)
	var face := (p - c).dot(n) * carrier.puck_side - gap()
	# the curve of the blade wraps the puck (the pocket); a carrier's hands
	# keep feeling for it a little beyond that, less the further it gets
	var reach := CARRY_REACH * lerpf(1.0, 1.35, carrier.one_hand()) if holding else POCKET
	if face < -0.01 or face > reach or absf(along) > BLADE_HALF + 0.1:
		return false
	var hold := 1.0 if face <= POCKET else 1.0 - (face - POCKET) / (reach - POCKET)
	var vb := Vector2(carrier.blade_vel.x, carrier.blade_vel.z)
	var v := Vector2(puck.vel.x, puck.vel.z)
	# where the cup wants it: against the face, near the middle of the blade
	var want := vb - n * carrier.puck_side * face * CUP_PULL - ax * along * CUP_CENTRE
	var dv := want - v
	var grip := carrier.profile.puck_grip * hold * lerpf(1.0, 0.7, carrier.one_hand())
	if dv.length() > grip * dt:
		dv = dv.limit_length(grip * dt)
		carrier.puck_slip += dt
	v += dv
	puck.vel.x = v.x
	puck.vel.z = v.y
	return true


## The carrier loses the puck once it's out of reach of the blade. With the
## blade up (going round the puck, a deke) they get the stick's reach.
static func _keep(carrier: Skater, puck: Puck, f: float) -> void:
	var seg := blade_at(carrier, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var p := Vector2(puck.position.x, puck.position.z)
	var q := c + ax * clampf((p - c).dot(ax), -BLADE_HALF, BLADE_HALF)
	var keep := CARRY_REACH * lerpf(1.0, 1.35, carrier.one_hand())
	if carrier.lifting or carrier.regrab_timer > 0.0 or carrier.blade_height > BLADE_CLEAR:
		keep = Skater.REACH_ONE_HAND * 0.7
	if p.distance_to(q) > keep:
		puck.controller = null
		puck.last_touch = carrier


## A cradling move (lacrosse): the puck sits in the curve of the blade, held
## there by the hands' grip; the blade carries it up and round. It's a force
## on the puck like any other, so a move faster than the grip spills it.
static func _cradle(carrier: Skater, puck: Puck, dt: float) -> void:
	var at := carrier.puck_anchor()
	var bv := carrier.blade_vel
	var want := bv + (at - puck.position) * CUP_PULL
	var dv := want - puck.vel
	# the blade holds it up against gravity while it's on the blade
	dv.y += Puck.GRAVITY * dt
	var grip := carrier.profile.puck_grip * 1.5
	if dv.length() > grip * dt:
		dv = dv.limit_length(grip * dt)
		carrier.puck_slip += dt
	puck.vel += dv
	if puck.position.distance_to(at) > 0.35:
		puck.controller = null
		puck.last_touch = carrier


## The blade swung through the puck: a shot or a pass. The face meets the
## puck moving at `swing` (world m/s, the skater's own speed included) with
## face normal `n` (where the face points, tilted up for loft). The puck
## leaves as it would off a heavy, springy blade: restitution `e` is the
## stick's flex giving back what the wind-up loaded into it. A puck already
## moving (a one-timer) keeps what the collision doesn't take off it.
static func strike(s: Skater, puck: Puck, swing: Vector3, n: Vector3, e: float) -> void:
	var share := Contact.share_of(Contact.PUCK_MASS, Contact.BLADE_MASS)
	var v := Contact.bounce(puck.vel, n, swing, e, TAPE_GRIP, share)
	s.blade_vel = swing
	puck.release(s, v)


## Puck speed a blade swung at `swing` m/s hands over to a puck at rest.
static func strike_gain(e: float) -> float:
	return (1.0 + e) * Contact.share_of(Contact.PUCK_MASS, Contact.BLADE_MASS)

