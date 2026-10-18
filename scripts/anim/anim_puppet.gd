class_name AnimPuppet
extends Skater
## A skater body on a treadmill for the animation studio: it never runs the
## physics or moves across the ice. Each frame a clip (AnimClips) says what
## it is doing (how fast it skates, whether it pushes, turns or stops, where
## the blade is, wind-ups, checks, falls) and the puppet turns that into the
## same Skater state the game gives SkaterRig, so the studio shows exactly
## the animation a game would.

## Where the blade rests (forward, right), further out than the game's
## DEFAULT_BLADE: with a full-size stick and the top hand at the hips the blade
## sits about 1.25 m out, and only there can the bottom hand reach the shaft.
const READY_BLADE := Vector2(1.2, 0.35)

## Forward speed the treadmill runs at (m/s); vel eases towards it.
var go_speed := 0.0
## How quickly vel reaches go_speed (m/s per second).
var accel := 8.0
## Striding (stick pushed forward) rather than gliding.
var push := false
## Turn rate in rad/s; + turns left.
var turn_rate := 0.0
## Blade target: angle in degrees from straight ahead (+ forehand), reach in
## metres, height off the ice in metres.
var blade_deg := rad_to_deg(atan2(READY_BLADE.y, READY_BLADE.x))
var blade_m := READY_BLADE.length()
var blade_h := 0.0
## Extra presentation spin (degrees per second), not seen by the rig.
var spin := 0.0
## Puck is on the blade.
var holding := false
## Puck is loose on the ice: a physical object that only moves when the
## drawn blade hits it (or it slides on), never glued to the blade.
var free_puck := false

const PUCK_DRAG := 0.3        # ice friction on a sliding puck (m/s^2)
const PUCK_BOUNCE := 0.1      # restitution off the blade: a soft, cupping catch
const BLADE_GRIP := 0.2      # how much the blade's face drags the puck along it, per substep

var _blade_prev: Array = []   # last frame's blade footprint
var _puck_side := 0.0         # which face of the blade the puck is on


## Clears the per-frame intent; clips set what they need after this.
func clear_intent() -> void:
	push = false
	turn_rate = 0.0
	braking = false
	ctrl.tilt = 0.0
	blade_deg = rad_to_deg(atan2(READY_BLADE.y, READY_BLADE.x))
	blade_m = READY_BLADE.length()
	blade_h = 0.0


## Back to a standing start at the centre, facing `facing`.
func restart(facing: Vector3) -> void:
	place(Vector2.ZERO, facing)
	go_speed = 0.0
	stun_timer = 0.0
	check_timer = 0.0
	dash_timer = 0.0
	winding = false
	wind_slap = false
	wind_time = 0.0
	holding = false
	free_puck = false
	rig.blade_turn = 0.0
	_blade_prev = []
	_puck_side = 0.0
	clear_intent()


## Applies this frame's intent and poses the rig.
func step(dt: float) -> void:
	stun_timer = maxf(0.0, stun_timer - dt)
	check_timer = maxf(0.0, check_timer - dt)
	dash_timer = maxf(0.0, dash_timer - dt)
	var fwd := vel.dot(heading)
	var want := go_speed if stun_timer <= 0.0 else 0.0
	fwd = move_toward(fwd, want, (accel if stun_timer <= 0.0 else 4.0) * dt)
	heading = heading.rotated(Vector3.UP, (turn_rate + deg_to_rad(spin)) * dt).normalized()
	vel = heading * fwd
	yaw_rate = turn_rate
	braking = braking and stun_timer <= 0.0
	ctrl.move = Vector2(heading.x, heading.z) if push and stun_timer <= 0.0 else Vector2.ZERO
	# the treadmill: the skater stays put, the ice moves
	position = Vector3.ZERO
	var a := deg_to_rad(blade_deg)
	var prev := blade_pos
	_set_blade(Vector2(cos(a), sin(a)) * blade_m)
	blade_height = lerpf(blade_height, blade_h, minf(1.0, 25.0 * dt))
	_apply_transform()
	blade_pos = _blade_world(blade_local)
	blade_vel = (blade_pos - prev) / dt
	if free_puck:
		puck.controller = self
		puck.last_touch = self
	elif holding:
		puck.controller = self
		puck.last_touch = self
		# a lifted blade (slapshot wind-up) leaves the puck waiting on the ice
		if blade_h < 0.05:
			puck.position = Vector3(blade_pos.x, 0.0, blade_pos.z)
	elif puck.controller == self:
		puck.controller = null
	if _spray:
		_spray.emitting = braking and speed() > 2.0
	rig.cup_puck = not free_puck
	rig.update_skater(self, dt)
	if free_puck:
		_roll_puck(dt)


## Lets the puck go with velocity `v` (relative to the body: x forward,
## y up, z to the right).
func release_puck(v: Vector3) -> void:
	holding = false
	puck.controller = null
	puck.last_touch = self
	puck.visible = true
	puck.vel = heading * v.x + Vector3.UP * v.y + right_vec() * v.z


## A wind-up the way Skater does it: both hands on, blade drawn back.
func wind(dt: float, slap := false) -> void:
	if not winding:
		winding = true
		wind_time = 0.0
		wind_slap = slap
	wind_time += dt


## Ends a wind-up; returns how long it was held.
func unwind() -> float:
	var held := wind_time
	winding = false
	wind_slap = false
	wind_time = 0.0
	return held


## How close the puck's centre can come to the blade's middle plane.
func blade_gap() -> float:
	return SkaterRig.puck_size.x + 0.5 * Models.STICK_V * AnimTuning.current().stick_thickness


## The drawn blade on the ice: [heel end, toe end] (x, z), its lowest point.
func _blade_footprint() -> Array:
	var b: Node3D = rig.blade
	var half := 8.5 * Models.STICK_V * AnimTuning.current().stick_blade_length
	var along := b.global_basis.x.normalized() * half
	var a := b.global_position - along
	var c := b.global_position + along
	return [Vector2(a.x, a.z), Vector2(c.x, c.z), minf(a.y, c.y)]


## Slides the loose puck and bounces it off the blade where they touch. The
## blade's move this frame is split into substeps so a quick blade can't pass
## through the puck; a lifted blade passes over it.
func _roll_puck(dt: float) -> void:
	var now := _blade_footprint()
	if _blade_prev.is_empty():
		_blade_prev = now
	var gap := blade_gap()
	var pos := Vector2(puck.position.x, puck.position.z)
	var v := Vector2(puck.vel.x, puck.vel.z)
	const STEPS := 6
	var h := dt / STEPS
	var a0: Vector2 = _blade_prev[0]
	var c0: Vector2 = _blade_prev[1]
	for i in STEPS:
		var f := float(i + 1) / STEPS
		var a: Vector2 = (_blade_prev[0] as Vector2).lerp(now[0], f)
		var c: Vector2 = (_blade_prev[1] as Vector2).lerp(now[1], f)
		var low := lerpf(_blade_prev[2], now[2], f)
		pos += v * h
		v = v.move_toward(Vector2.ZERO, PUCK_DRAG * h)
		var ab := c - a
		if ab.length_squared() < 0.0001:
			continue
		var t := clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		var n := Vector2(-ab.y, ab.x).normalized()
		var sd := (pos - q).dot(n)
		if low >= SkaterRig.puck_size.y:
			# the blade is up: it passes over, and the puck is on whichever
			# side it ends up
			_puck_side = signf(sd) if absf(sd) > 0.001 else _puck_side
		else:
			var side := _puck_side if _puck_side != 0.0 else signf(sd)
			var hit := Vector2.ZERO
			if t > 0.0 and t < 1.0:
				# along the face: keep it on its own side, even if the blade
				# moved past its centre this substep
				if sd * side < gap:
					hit = n * side
					pos = q + hit * gap
			elif pos.distance_to(q) < gap:
				# off the heel or the toe
				hit = (pos - q).normalized()
				pos = q + hit * gap
			if hit != Vector2.ZERO:
				var qp := a0 + (c0 - a0) * t
				var vb := (q - qp) / h
				var rel := v - vb
				var vn := rel.dot(hit)
				if vn < 0.0:
					v -= hit * vn * (1.0 + PUCK_BOUNCE)
				var tan := Vector2(-hit.y, hit.x)
				v -= tan * (v - vb).dot(tan) * BLADE_GRIP
			if absf(sd) > gap:
				_puck_side = signf(sd)
		a0 = a
		c0 = c
	_blade_prev = now
	puck.position = Vector3(pos.x, 0.0, pos.y)
	puck.vel = Vector3(v.x, 0.0, v.y)
