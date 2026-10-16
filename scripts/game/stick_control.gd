class_name StickControl
extends RefCounted
## The human's stick: a hybrid of Slapshot Rebound's physical stick and NHL's
## "puck glue". The right stick places the blade inside a 90 degree arc in
## front of the skater; the puck still rides the blade on the simulated spring
## (Game._puck_stick_interaction), but shots, passes, dekes and stick lifts
## come from stick gestures resolved here with the player's skills.
##
##  * Stickhandling: sweep the stick side to side. Blade speed is capped by
##    the stickhandling skill, and moving the blade near that cap risks a
##    fumble, more so at low skill.
##  * Quick shot: flick the stick forward. Releases instantly; weak and wild
##    at low shot release, harder and truer as it improves.
##  * Wind-up shot: pull the stick behind you, hold, then sweep it forward.
##    Charges faster with better shot release.
##  * Slapshot: hold lift while winding up.
##  * Tilt (analog) raises the blade face: shots and passes leave the ice.
##  * Lift with the puck lifts the blade over it (dekes, toe drags); the puck
##    coasts until the stick comes back down. Without the puck, a lift near a
##    carrier's stick tries to lift it and strip the puck.
##  * A wind-up and sweep at a loose puck near the blade is a one-timer.
##
## Ratings come from Skater.skill(name) (0..1) when the skater has it,
## otherwise from `default_skills`.

const ARC_HALF := PI / 4.0              # 90 degree arc in front of the body
const WINDUP_ANGLE := 1.92              # stick further back than ~110 degrees winds up
const REACH_NEAR := 0.6
const REACH_FAR := 1.45
const FLICK_WINDOW := 0.09              # seconds of stick history a flick is measured over
const FLICK_TRAVEL := 0.9               # forward stick travel inside the window that counts as a flick
const SHOT_CONE := 0.7                  # a flick within ~40 degrees of facing shoots...
const WINDUP_SHOT_CONE := 1.4           # ...wider when it comes out of a wind-up
const WINDUP_GRACE := 0.18              # time to start the sweep after leaving the wind-up
const LIFT_RANGE := 0.75                # blade-to-stick distance for a stick lift
const LIFT_COOLDOWN := 0.8

var default_skills := {
	"stickhandling": 0.5, "shot_release": 0.5, "shot_power": 0.5,
	"shot_accuracy": 0.5, "pass_quality": 0.5, "hitting": 0.5,
}

## 0..1 wind-up charge, for the HUD power bar.
var charge := 0.0
## Last thing the stick did ("quick", "wrist", "slap", "one-timer", "pass",
## "fumble", "lift", "lift-miss"), for the HUD and tests.
var last_event := ""
var events := []

var _t := 0.0
var _hist: Array[Vector3] = []          # (stick x, stick z, time)
var _winding := 0.0
var _slap := false
var _left_windup_at := -10.0
var _shot_cd := 0.0
var _lift_cd := 0.0
var _prev_lift := 0.0
var _carry_local := Skater.DEFAULT_BLADE


func skill(s: Skater, name: String) -> float:
	if s.has_method("skill"):
		return clampf(s.call("skill", name), 0.0, 1.0)
	return default_skills.get(name, 0.5)


## `stick` is the right stick in world XZ (length <= 1); lift and tilt 0..1.
func update(s: Skater, stick: Vector2, lift: float, tilt: float, dt: float) -> void:
	_t += dt
	_shot_cd = maxf(0.0, _shot_cd - dt)
	_lift_cd = maxf(0.0, _lift_cd - dt)
	var c := s.ctrl
	var blend: float = Tuning.blend
	c.tilt = tilt
	c.lift = lift
	c.blade_max_speed = lerpf(5.0, 13.0, skill(s, "stickhandling")) * lerpf(0.9, 1.15, blend)

	_hist.append(Vector3(stick.x, stick.y, _t))
	while _hist.size() > 2 and _hist[1].z <= _t - FLICK_WINDOW:
		_hist.pop_front()

	if s.stun_timer > 0.0 or s.game.is_frozen():
		_reset_gesture()
		c.blade_local_target = Skater.DEFAULT_BLADE
		_prev_lift = lift
		return

	var h := Vector2(s.heading.x, s.heading.z)
	var r := Vector2(s.right_vec().x, s.right_vec().z)
	var mag := stick.length()
	var local := Vector2(stick.dot(h), stick.dot(r))
	var ang := atan2(local.y, local.x)
	var carrying := s.has_puck()

	# where the blade goes: inside the arc, or back in the wind-up
	if mag > 0.7 and absf(ang) > WINDUP_ANGLE:
		if _winding == 0.0:
			_slap = false
		_winding += dt
		_slap = _slap or lift > 0.5
		_left_windup_at = _t
		charge = clampf(_winding / _charge_time(s), 0.0, 1.0)
		var side := signf(local.y) if absf(local.y) > 0.05 else 1.0
		c.blade_local_target = Vector2(-0.35, 0.8 * side)
		c.blade_height = charge * (0.9 if _slap else 0.3)
		c.anchor_local = _carry_local
	else:
		if mag < 0.2:
			c.blade_local_target = Skater.DEFAULT_BLADE
		else:
			var a := clampf(ang, -ARC_HALF, ARC_HALF)
			var reach := lerpf(REACH_NEAR, REACH_FAR, clampf((mag - 0.2) / 0.8, 0.0, 1.0))
			c.blade_local_target = Vector2(cos(a), sin(a)) * reach
		_carry_local = c.blade_local_target
		c.blade_height = 0.22 * lift
		if _winding > 0.0 and _t - _left_windup_at > WINDUP_GRACE:
			_reset_gesture()

	_try_flick(s, stick, tilt)
	if carrying and s.has_puck() and _winding == 0.0 and lift < 0.5:
		_fumble_check(s, dt, blend)
	if not carrying and lift > 0.5 and _prev_lift <= 0.5:
		_stick_lift(s, blend)
	if carrying and lift <= 0.5 and _prev_lift > 0.5:
		s.regrab_timer = 0.25
	_prev_lift = lift


func pass_puck(s: Skater, dir: Vector2, tilt: float) -> void:
	if not s.has_puck():
		return
	var quality := skill(s, "pass_quality")
	_reset_gesture()
	s.ctrl.pass_dir = dir
	s.pass_puck()
	# max pass quality is all but perfect; low quality sprays the pass
	var err := lerpf(0.16, 0.004, quality) * (1.0 - 0.5 * Tuning.blend)
	var v := s.puck.vel.rotated(Vector3.UP, _spread(err))
	if tilt > 0.3:
		v.y = lerpf(1.6, 3.6, tilt)  # saucer pass over sticks
	s.puck.vel = v
	_event("pass")


func _try_flick(s: Skater, stick: Vector2, tilt: float) -> void:
	if _shot_cd > 0.0 or _hist.size() < 2 or stick.length() < 0.8:
		return
	var old := Vector2(_hist[0].x, _hist[0].y)
	var d := stick - old
	var h := Vector2(s.heading.x, s.heading.z)
	# side-to-side stickhandling never shoots: the travel has to be forward
	if d.dot(h) < FLICK_TRAVEL:
		return
	var from_windup := _winding > 0.0 and _t - _left_windup_at <= WINDUP_GRACE
	var cone := WINDUP_SHOT_CONE if from_windup else SHOT_CONE
	if absf(h.angle_to(d)) > cone or absf(h.angle_to(stick)) > ARC_HALF + 0.35:
		return
	var dir := (d.normalized() + stick.normalized()).normalized()
	var ch := charge if from_windup else 0.0
	var slap := from_windup and _slap
	if s.has_puck():
		_shoot(s, dir, ch, slap, tilt, "slap" if slap else ("wrist" if from_windup else "quick"))
	elif _loose_puck_on_blade(s):
		_shoot(s, dir, ch, slap, tilt, "one-timer")
	else:
		return
	_reset_gesture()
	_hist.clear()
	_shot_cd = 0.25


func _shoot(s: Skater, dir2: Vector2, ch: float, slap: bool, tilt: float, kind: String) -> void:
	var blend: float = Tuning.blend
	var puck := s.puck
	var release := skill(s, "shot_release")
	var power := skill(s, "shot_power")
	var acc := skill(s, "shot_accuracy")
	# the instant release is weak and wild at low skill and grows with it
	var quick := lerpf(11.0, 25.0, release) * lerpf(0.85, 1.1, power)
	var full := lerpf(27.0, 42.0, power) if slap else lerpf(20.0, 33.0, power)
	var spd := lerpf(quick, full, ch)
	if kind == "one-timer":
		spd = maxf(spd, lerpf(18.0, 30.0, power) * lerpf(0.7, 1.0, ch))
	var err := lerpf(0.11, 0.012, acc) * lerpf(1.8, 1.0, maxf(release, ch))
	err *= (1.5 if slap else 1.0) * (1.0 + Vector2(s.vel.x, s.vel.z).length() / s.top_speed * 0.5)
	err *= 1.0 - 0.4 * blend

	var from := puck.position
	var net := s.attack_goal()
	var dir := Vector3(dir2.x, 0, dir2.y).normalized()
	# arcade aim assist: shots roughly on net are pulled inside the posts
	var to_net := Vector3(net.x - from.x, 0, net.z - from.z)
	var net_dist := to_net.length()
	if blend > 0.0 and net_dist > 1.0 and dir.angle_to(to_net) < deg_to_rad(12.0 + 25.0 * blend):
		var t := (net.x - from.x) / dir.x if absf(dir.x) > 0.05 else 0.0
		var hit_z := clampf(from.z + dir.z * t, -0.78, 0.78) if t > 0.0 else 0.0
		dir = dir.slerp(Vector3(net.x - from.x, 0, hit_z - from.z).normalized(), 0.75 * blend)
	dir = dir.rotated(Vector3.UP, _spread(err))
	# tilt picks the height at the net: flat along the ice up to the top shelf
	var vy := 0.0
	if net_dist < 22.0:
		var h_target := clampf(lerpf(0.04, 1.1, tilt) + _spread(err) * net_dist * 0.4, 0.0, 1.6)
		var tt := net_dist / spd
		vy = minf((h_target + 0.5 * Puck.GRAVITY * tt * tt) / tt, spd * 0.45)
	else:
		vy = tilt * spd * 0.3
	puck.release(s, dir * spd + Vector3.UP * vy)
	puck.pass_target = null
	s.game.on_shot(s, slap)
	_event(kind)


func _loose_puck_on_blade(s: Skater) -> bool:
	var p := s.puck
	if p.controller != null or p.frozen or p.position.y > 0.6 or not p.can_be_touched_by(s):
		return false
	var d := Vector2(p.position.x - s.blade_pos.x, p.position.z - s.blade_pos.z).length()
	return d < lerpf(0.5, 0.95, Tuning.blend)


## Moving the blade near its top speed can work the puck loose.
func _fumble_check(s: Skater, dt: float, blend: float) -> void:
	var sh := skill(s, "stickhandling")
	var rel := (s.blade_vel - s.vel).length() / maxf(s.ctrl.blade_max_speed, 0.1)
	var rate := maxf(0.0, rel - 0.6) * 1.6 * pow(1.0 - sh, 1.5) * (1.0 - 0.6 * blend)
	if randf() < rate * dt:
		var p := s.puck
		var kick := s.right_vec() * randf_range(-1.8, 1.8) + s.heading * randf_range(-0.5, 1.0)
		p.release(s, Vector3(p.vel.x, 0, p.vel.z) * 0.6 + kick)
		p.ignore_briefly(s, 0.35)
		_event("fumble")


## Defensive stick lift: lift an opponent's stick off the puck.
func _stick_lift(s: Skater, blend: float) -> void:
	if _lift_cd > 0.0:
		return
	_lift_cd = LIFT_COOLDOWN
	var holder: Skater = s.puck.controller
	if holder == null or holder.team == s.team:
		return
	# the lift lands on the shaft between their hands and the blade
	var shaft := Geometry3D.get_closest_point_to_segment(s.blade_pos, holder.position, holder.blade_pos)
	if Vector2(shaft.x - s.blade_pos.x, shaft.z - s.blade_pos.z).length() > LIFT_RANGE:
		_event("lift-miss")
		return
	var odds := 0.55 + 0.4 * (skill(s, "hitting") - 0.5) - 0.3 * (_holder_skill(holder) - 0.5) + 0.15 * blend
	if randf() > clampf(odds, 0.15, 0.95):
		_event("lift-miss")
		return
	var p := s.puck
	p.controller = null
	p.vel = Vector3(holder.vel.x, 0, holder.vel.z) * 0.6 + s.heading * 1.5
	p.ignore_briefly(holder, 0.5)
	p.last_touch = s
	_event("lift")


func _holder_skill(h: Skater) -> float:
	if h.has_method("skill"):
		return clampf(h.call("skill", "stickhandling"), 0.0, 1.0)
	return clampf((h.handling - 0.8) / 0.4, 0.0, 1.0)


func _charge_time(s: Skater) -> float:
	var release := skill(s, "shot_release")
	return lerpf(1.1, 0.55, release) if _slap else lerpf(0.9, 0.35, release)


func _reset_gesture() -> void:
	_winding = 0.0
	_slap = false
	charge = 0.0


func _event(kind: String) -> void:
	last_event = kind
	events.append(kind)


static func _spread(err: float) -> float:
	return (randf() + randf() - 1.0) * err * 1.4
