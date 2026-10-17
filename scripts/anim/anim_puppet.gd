class_name AnimPuppet
extends Skater
## A skater body on a treadmill for the animation studio: it never runs the
## physics or moves across the ice. Each frame a clip (AnimClips) says what
## it is doing (how fast it skates, whether it pushes, turns or stops, where
## the blade is, wind-ups, checks, falls) and the puppet turns that into the
## same Skater state the game gives SkaterRig, so the studio shows exactly
## the animation a game would.

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
var blade_deg := rad_to_deg(atan2(DEFAULT_BLADE.y, DEFAULT_BLADE.x))
var blade_m := DEFAULT_BLADE.length()
var blade_h := 0.0
## Extra presentation spin (degrees per second), not seen by the rig.
var spin := 0.0
## Puck is on the blade.
var holding := false


## Clears the per-frame intent; clips set what they need after this.
func clear_intent() -> void:
	push = false
	turn_rate = 0.0
	braking = false
	ctrl.tilt = 0.0
	blade_deg = rad_to_deg(atan2(DEFAULT_BLADE.y, DEFAULT_BLADE.x))
	blade_m = DEFAULT_BLADE.length()
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
	if holding:
		puck.controller = self
		puck.last_touch = self
		# a lifted blade (slapshot wind-up) leaves the puck waiting on the ice
		if blade_h < 0.05:
			puck.position = Vector3(blade_pos.x, 0.0, blade_pos.z)
	elif puck.controller == self:
		puck.controller = null
	if _spray:
		_spray.emitting = braking and speed() > 2.0
	rig.update_skater(self, dt)


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
