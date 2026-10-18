class_name SkaterRig
extends Node3D
## Voxel character rig: a hierarchy of VoxelParts posed procedurally each
## frame. Skaters have jointed limbs (thigh + shin, upper arm + forearm) posed
## with two-bone IK: the feet follow a skating stride (glide, push out and
## back, lift and recover under the hips), the hips shift over the gliding
## skate, the shoulders counter-rotate, the outside leg crosses over in
## turns, and the hands follow the simulated stick. On top of that come the
## one-shot actions: shot and pass follow-throughs, body checks, falls and
## goal celebrations. Goalies keep one-piece limbs.
##
## Every shaping number lives in AnimTuning (scripts/anim/anim_tuning.gd),
## tuned live in the animation studio (scenes/anim/anim_studio.tscn).
## Animations own the body and (since Sean's grip notes, 2026-10-18) how the
## hands hold the stick in `_pose_stick`; Controls owns the stick's swing.

const V := Models.V
const HIP_Y := 12 * V
const STICK_LEN := 23.5 * V   # goalie stick
const SHAFT_LEN := Models.SHAFT_VOX * Models.STICK_V   # model size; AnimTuning stick_* scale it
const BLADE_HEEL := Vector3(-7.5 * Models.STICK_V, 4.5 * Models.STICK_V, 0)  # in blade space
const THIGH := 6.0 * V
const SHIN := 6.5 * V           # knee to the bottom of the blade
const UPPER_ARM := 4.0 * V
const FOREARM := 3.5 * V        # elbow to the middle of the glove
const LEG_X := 2.0 * V
const CHECK_TIME := 0.35        # Skater sets check_timer to this when a check starts
## Goal celebrations, picked per scorer.
const CELEBRATIONS: Array[StringName] = [&"arms_up", &"fist_pump", &"knee_slide"]

var goalie := false
var faller: Node3D        # tips the whole skater, stick included, in a fall
var body: Node3D
var hips: VoxelPart
var torso: VoxelPart
var head: VoxelPart
var stick: VoxelPart      # goalie stick, or the skater's shaft
var blade: VoxelPart
# goalie (one-piece limbs)
var arm_l: VoxelPart
var arm_r: VoxelPart
var leg_l: VoxelPart
var leg_r: VoxelPart
# skater (jointed limbs), index 0 = left, 1 = right
var thighs: Array[VoxelPart] = []
var shins: Array[VoxelPart] = []
var uppers: Array[VoxelPart] = []
var forearms: Array[VoxelPart] = []

var _cycle := 0.0
var _amp := 0.0
var _crouch := 0.08
var _shift := 0.0
var _twist := 0.0
var _cross := 0.0
var _lean := 0.0
var _brake := 0.0
var _fall := 0.0
var _fall_dir := 1.0      # +1 falls backward, -1 forward
var _check := 0.0
var _bf := 0.0
var _time := 0.0
var _feet: Array[Vector3] = [Vector3(-0.15, 0, 0), Vector3(0.15, 0, 0)]
var _yaws: Array[float] = [0.0, 0.0]
var _one_hand := 0.0
var _follow := 0.0
var _follow_side := 1.0
var _follow_h := 1.0
var _shots := -1
var _had_puck := false
var _prev_wind := 0.0
var _prev_ang := 0.0
var _stick_yaw := 0.0
var _cel_kind := &""
var _cel_t := 0.0
var _cel := 0.0
var _hooked := false
var _grip_top := Vector3.ZERO     # faller space, set by _pose_stick
var _grip_bottom := Vector3.ZERO
var _bottom_d := 0.45            # bottom hand, metres below the knob
var _bottom_off := false          # the bottom hand couldn't reach the shaft last frame
var _shaft_base: Mesh             # stick meshes at model size, rescaled by AnimTuning
var _blade_base: Mesh
var _stick_size := Vector4.ZERO


func build(pal: Dictionary, is_goalie: bool) -> void:
	goalie = is_goalie
	faller = Node3D.new()
	add_child(faller)
	body = Node3D.new()
	faller.add_child(body)
	hips = VoxelPart.make(Models.pants(pal, goalie))
	hips.position.y = HIP_Y
	body.add_child(hips)
	torso = VoxelPart.make(Models.torso(pal, goalie))
	torso.position.y = 3 * V
	hips.add_child(torso)
	head = VoxelPart.make(Models.head(pal, goalie))
	head.position.y = (10 if goalie else 9) * V
	torso.add_child(head)
	var arm_x := (6.5 if goalie else 5.5) * V
	var arm_y := (10 if goalie else 9) * V
	if goalie:
		var leg_x := 2.6 * V
		leg_l = VoxelPart.make(Models.leg(pal, true))
		leg_l.position = Vector3(-leg_x, 0, 0)
		hips.add_child(leg_l)
		leg_r = VoxelPart.make(Models.leg(pal, true))
		leg_r.position = Vector3(leg_x, 0, 0)
		hips.add_child(leg_r)
		arm_l = VoxelPart.make(Models.arm(pal, "glove"))
		arm_l.position = Vector3(-arm_x, arm_y, 0)
		torso.add_child(arm_l)
		arm_r = VoxelPart.make(Models.arm(pal, "blocker"))
		arm_r.position = Vector3(arm_x, arm_y, 0)
		torso.add_child(arm_r)
	else:
		for sd in [-1.0, 1.0]:
			var th := VoxelPart.make(Models.thigh(pal))
			th.position = Vector3(sd * LEG_X, 0, 0)
			hips.add_child(th)
			thighs.append(th)
			var sh := VoxelPart.make(Models.shin(pal))
			hips.add_child(sh)
			shins.append(sh)
			var up := VoxelPart.make(Models.upper_arm(pal))
			up.position = Vector3(sd * arm_x, arm_y, 0)
			torso.add_child(up)
			uppers.append(up)
			var fa := VoxelPart.make(Models.forearm(pal))
			torso.add_child(fa)
			forearms.append(fa)
	if goalie:
		stick = VoxelPart.make(Models.stick(pal, true))
	else:
		stick = VoxelPart.make(Models.shaft(pal))
		blade = VoxelPart.make(Models.blade(pal))
		_shaft_base = stick.mesh
		_blade_base = blade.mesh
		faller.add_child(blade)
	faller.add_child(stick)


## The stick follows through high towards the target after a shot. `side` is
## +1 forehand, -1 backhand.
func follow_through(strength: float, side := 1.0) -> void:
	_follow = clampf(strength, 0.3, 1.0)
	_follow_side = side
	_follow_h = 1.0


## A short, low follow-through after a pass.
func pass_through(side := 1.0) -> void:
	var t := AnimTuning.current()
	_follow = t.pass_follow
	_follow_side = side
	_follow_h = t.pass_height


## Plays a goal celebration (one of CELEBRATIONS) for `seconds`, or the
## tuned length when it is 0.
func celebrate(kind: StringName, seconds := 0.0) -> void:
	_cel_kind = kind
	_cel_t = seconds if seconds > 0.0 else AnimTuning.current().celebrate_time


## The celebration playing now, or &"" when there is none.
func celebrating() -> StringName:
	return _cel_kind if _cel_t > 0.0 else &""


## Starts a follow-through when this skater's shot or pass just left the
## blade, and listens for goals to celebrate.
func _watch_shots(s: Skater) -> void:
	if not _hooked:
		_hooked = true
		var ev: Variant = s.game.get("events") if s.game else null
		if ev and ev.has_signal("goal"):
			ev.goal.connect(_on_goal.bind(s))
	var stats: Variant = s.game.get("stats") if s.game else null
	var shots: int = stats.shots if stats else 0
	var has := s.has_puck()
	var gone := _had_puck and not has and s.puck.last_touch == s and s.stun_timer <= 0.0
	# wind-up shots call follow_through() themselves; this catches move shots
	if _shots >= 0 and shots > _shots and _follow <= 0.0 and s.puck.last_touch == s and not has:
		follow_through(_prev_wind * 1.3 + 0.35, -1.0 if _prev_ang < -0.2 else 1.0)
	elif gone and shots == _shots and _follow <= 0.0 and s.puck.vel.length() > 4.0:
		pass_through(-1.0 if _prev_ang < -0.2 else 1.0)
	_shots = shots
	_had_puck = has
	_prev_wind = s.windup()
	_prev_ang = s.blade_ang


func _on_goal(team: int, scorer: PlayerProfile, _assists: Array, s: Skater) -> void:
	if scorer != null and scorer == s.player:
		celebrate(CELEBRATIONS[s.number % CELEBRATIONS.size()])
	elif team == s.team:
		celebrate(&"arms_up", AnimTuning.current().celebrate_time * 0.6)


func update_skater(s: Skater, dt: float) -> void:
	var T := AnimTuning.current()
	_size_stick(T)
	# a broken stick is lying on the ice (StickDebris)
	stick.visible = not s.stick_broken
	blade.visible = not s.stick_broken
	_time += dt
	var speed := Vector2(s.vel.x, s.vel.z).length()
	var k := clampf(speed / 9.0, 0.0, 1.0)
	var able := s.stun_timer <= 0.0
	var pushing := s.ctrl.move.length() > 0.2 and not s.braking and able
	var dashing := s.dash_timer > 0.0
	var smooth := 1.0 - exp(-8.0 * dt)

	_cel_t = maxf(0.0, _cel_t - dt)
	_cel = lerpf(_cel, 1.0 if _cel_t > 0.0 and able else 0.0, 1.0 - exp(-6.0 * dt))
	var slide := _cel if _cel_kind == &"knee_slide" else 0.0

	# stride: long, wide pushes at speed, short quick ones from a standstill
	var amp_target := (T.stride_amp + T.stride_amp_speed * k) * (T.dash_amp if dashing else 1.0) if pushing else 0.0
	_amp = lerpf(_amp, amp_target * (1.0 - slide), 1.0 - exp(-4.0 * dt))
	var cadence := lerpf(T.stride_cadence, T.stride_cadence_fast, k) * (T.dash_cadence if dashing else 1.0)
	if _amp > 0.02:
		_cycle = fmod(_cycle + dt * cadence, 1.0)
	_lean = lerpf(_lean, clampf(s.yaw_rate * speed * T.cross_lean, -T.cross_lean_max, T.cross_lean_max), smooth)
	_cross = lerpf(_cross, clampf((absf(_lean) - T.cross_start) / T.cross_range, 0.0, 1.0) if pushing and speed > 2.5 else 0.0, smooth)
	_brake = lerpf(_brake, T.stop_turn if s.braking else 0.0, 1.0 - exp(-T.stop_speed * dt))
	var down := s.stun_timer > 0.25
	if down and _fall < 0.05:
		# pushed back while skating slowly (or backwards) goes over backwards
		_fall_dir = -1.0 if s.vel.dot(-s.global_basis.z) > T.fall_forward_speed else 1.0
	_fall = lerpf(_fall, 1.0 if down else 0.0, 1.0 - exp(-(T.fall_speed if down else T.fall_rise_speed) * dt))
	var check_p := 1.0 - s.check_timer / CHECK_TIME if s.check_timer > 0.0 else 1.0
	_check = lerpf(_check, 1.0 if s.check_timer > 0.0 else 0.0, 1.0 - exp(-16.0 * dt))
	var rise := _check * smoothstep(0.3, 0.8, check_p)
	var stop := _brake / maxf(T.stop_turn, 0.01)

	# feet: blend the stride with a two-skate glide and the hockey-stop stance
	var outside := 1.0 if _lean > 0.0 else -1.0
	var stride_w := clampf(_amp * 2.5, 0.0, 1.0)
	var support: Array[float] = [0.0, 0.0]
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var u := fmod(_cycle + (0.0 if i == 0 else 0.5), 1.0)
		var r := _stride_foot(T, sd, u, _amp, _cross if sd == outside else 0.0, _cross if sd != outside else 0.0)
		var glide := Vector3(sd * T.stance_width, 0, -sd * 0.05 * k)
		var foot: Vector3 = glide.lerp(r[0], stride_w)
		var yaw: float = r[1] * stride_w
		foot = foot.lerp(Vector3(sd * T.stop_width, 0, sd * 0.04), stop)
		yaw = lerpf(yaw, 0.0, stop)
		# knee slide: left knee down on the ice behind, right skate out front
		foot = foot.lerp(Vector3(-0.12, 0.02, 0.45) if i == 0 else Vector3(0.18, 0, -0.3), slide)
		_feet[i] = _feet[i].lerp(foot, 1.0 - exp(-30.0 * dt))
		_yaws[i] = lerpf(_yaws[i], yaw, 1.0 - exp(-20.0 * dt))
		support[i] = 1.0 if (u < T.stride_glide_end or stride_w < 0.5) else 0.0

	# hips: low athletic stance, sink at speed and in the stop, ride over the
	# gliding skate, a little bob with each push
	var sup_x: float = (_feet[0].x * support[0] + _feet[1].x * support[1]) / maxf(support[0] + support[1], 1.0)
	_shift = lerpf(_shift, sup_x * T.stride_hip_shift * stride_w, 1.0 - exp(-6.0 * dt))
	var crouch := T.stance_crouch + T.stance_crouch_speed * k + T.stop_crouch * stop + (T.dash_crouch if dashing else 0.0)
	crouch += T.check_crouch * _check - (T.check_crouch + T.check_rise) * rise
	crouch += T.fall_drop * _fall + T.celebrate_knee_drop * slide
	_crouch = lerpf(_crouch, crouch, smooth)
	var bob := absf(sin(_cycle * TAU)) * T.stride_bob * _amp + sin(_time * 2.2) * T.stance_breathe * (1.0 - stride_w)
	hips.position = Vector3(_shift, HIP_Y - _crouch - bob, 0.03 * k)
	_twist = lerpf(_twist, sin(_cycle * TAU) * T.stride_hip_twist * _amp * (1.0 - _cross * 0.5), smooth)
	hips.rotation = Vector3(0.12 * k, -_twist * 0.6, -_shift * 0.6)

	# torso leans forward with speed, counter-rotates the hips, winds up for shots
	_watch_shots(s)
	var w := s.windup()
	# shoulders turn towards the blade: open up for a forehand wind-up, close
	# for the backhand, square up again on the follow-through
	var heel := to_local(s.blade_pos)
	var flat := Vector3(heel.x, 0, heel.z)
	var blade_ang := atan2(flat.x, -flat.z) if flat.length() > 0.05 else 0.0
	_stick_yaw = lerpf(_stick_yaw, blade_ang, 1.0 - exp(-10.0 * dt))
	_follow = maxf(0.0, _follow - dt * T.shot_follow_fade)
	var fol := smoothstep(0.0, 1.0, _follow)
	var lean_x := -(T.stance_lean + T.stance_lean_speed * k) + w * T.shot_windup_rise + stop * T.stop_lean - fol * T.shot_follow_rise * _follow_h
	lean_x -= T.check_lean * _check
	lean_x = lerpf(lean_x, T.celebrate_lean_back, _cel)
	var turn_y := _twist - _stick_yaw * T.shot_shoulder_turn + fol * T.shot_follow_turn * _follow_side
	turn_y = lerpf(turn_y, -T.check_shoulder, _check)
	torso.rotation.x = lerpf(torso.rotation.x, lean_x, smooth)
	torso.rotation.y = lerpf(torso.rotation.y, lerpf(turn_y, 0.0, _cel), smooth)
	torso.rotation.z = lerpf(torso.rotation.z, _shift * 1.2, smooth)
	head.rotation = Vector3(-(torso.rotation.x + hips.rotation.x) * T.stance_head_level, -(torso.rotation.y + hips.rotation.y) * 0.7, -torso.rotation.z * 0.8)
	body.rotation = Vector3(0.0, _brake, _lean + _brake * T.stop_tilt)
	# leaning in a turn or a stop tips the body over its skates: lift it so
	# the low skate stays on the ice instead of sinking through it
	var sink := 0.0
	for f in _feet:
		sink = maxf(sink, -(body.basis * Vector3(f.x, 0.0, f.z)).y)
	body.position.y = sink
	faller.rotation.x = _fall * T.fall_angle * _fall_dir

	for i in 2:
		_pose_leg(i)

	# one hand comes off the stick outside the front 90 degrees (the skater's
	# one_hand(), which also holds both on for a wind-up) and stays on for the
	# follow-through
	var oh := 0.0 if _follow > 0.0 else s.one_hand()
	if _bottom_off:
		oh = 1.0
	_one_hand = lerpf(_one_hand, oh, 1.0 - exp(-10.0 * dt))
	var center := Vector3(flat.x, s.blade_height + fol * T.shot_follow_height * _follow_h, flat.z)
	var bottom := lerpf(T.grip_bottom, T.grip_bottom_slap if s.wind_slap else T.grip_bottom_shot, w)
	_bottom_d = lerpf(_bottom_d, bottom, 1.0 - exp(-T.grip_slide_speed * dt))
	_pose_stick(center, flat, s.ctrl.tilt, _bottom_d)
	_pose_actions(T)


## Foot position (body space, +z is behind) and toe-out yaw for one leg at
## cycle point `u`. `cross` brings the outside skate over in a turn; `under`
## pushes the inside skate under the body.
func _stride_foot(T: AnimTuning, sd: float, u: float, amp: float, cross: float, under: float) -> Array:
	var front := Vector3(sd * 0.11, 0, -0.1 * amp)
	var mid := Vector3(sd * 0.13, 0, 0.06 * amp)
	var out := Vector3(sd * (0.14 + T.stride_push_out * amp), 0, 0.12 + T.stride_push_back * amp)
	out.x = lerpf(out.x, -sd * 0.12, under * T.cross_under)
	front.x = lerpf(front.x, -sd * T.cross_over, cross)
	var toe_out := -sd * T.stride_toe_out * amp
	var glide_end := T.stride_glide_end
	var push_end := maxf(T.stride_push_end, glide_end + 0.05)
	if u < glide_end:
		var e := u / glide_end
		return [front.lerp(mid, e), toe_out * 0.2 * e]
	if u < push_end:
		var e := smoothstep(0.0, 1.0, (u - glide_end) / (push_end - glide_end))
		return [mid.lerp(out, e), lerpf(toe_out * 0.2, toe_out, e)]
	var r := (u - push_end) / (1.0 - push_end)
	var p := out.lerp(front, smoothstep(0.0, 1.0, r))
	p.y = sin(PI * r) * (T.stride_lift + T.cross_lift * cross) * maxf(amp, 0.3)
	return [p, lerpf(toe_out, 0.0, r)]


## Two-bone IK for one leg: knee bends forward and a little out.
func _pose_leg(i: int) -> void:
	var sd := -1.0 if i == 0 else 1.0
	var root := Vector3(sd * LEG_X, 0, 0)
	var target: Vector3 = hips.transform.affine_inverse() * (_feet[i] + Vector3(0, 0, 0))
	var knee := _two_bone(root, target, THIGH, SHIN, Vector3(sd * 0.25, 0, -1))
	var foot := root + (target - root).limit_length(THIGH + SHIN - 0.002) if root.distance_to(target) > THIGH + SHIN else target
	thighs[i].transform = Transform3D(_basis_along(root - knee, 0.0), root)
	shins[i].transform = Transform3D(_basis_along(knee - foot, _yaws[i] - hips.rotation.y), knee)


func update_goalie(g: Goalie, dt: float) -> void:
	var smooth := 1.0 - exp(-14.0 * dt)
	_bf = lerpf(_bf, 1.0 if g.butterfly_timer > 0.0 else 0.0, smooth)
	hips.position.y = lerpf(HIP_Y - 0.1, 0.34, _bf)
	leg_l.rotation = Vector3(lerpf(0.0, -0.25, _bf), 0, -lerpf(0.14, 1.35, _bf))
	leg_r.rotation = Vector3(lerpf(0.0, -0.25, _bf), 0, lerpf(0.14, 1.35, _bf))
	torso.rotation.x = -0.18
	head.rotation.x = 0.1
	# the reaching hand goes to the predicted puck spot, the other stays ready
	var reach := Vector3(g.reach.x, g.reach.y, -0.4)
	var glove_rest := Vector3(-0.5, 0.85 - _bf * 0.3, -0.35)
	var blocker_rest := Vector3(0.45, 0.7 - _bf * 0.3, -0.35)
	_aim_arm(arm_l, to_global(reach if g.reach.x < 0.0 else glove_rest))
	_aim_arm(arm_r, to_global(reach if g.reach.x >= 0.0 else blocker_rest))
	var heel := Vector3(-0.25, 0, -0.55)
	var hand := Vector3(0.35, 0.65, -0.3)
	var stick_basis := _stick_basis(heel, hand, Vector3.RIGHT)
	stick.transform = Transform3D(stick_basis, heel)


## Blade flat on the ice at `center` (rig space), in line with the shaft as
## on a real stick: seen from above, the toe points away from the hands and
## the shaft rises over the heel. The top hand never lets go of the knob: it
## stays in front of the belly on its own side and the stick pivots in it,
## so a wide reach swings the knob out on a straight arm. The bottom hand
## slides along the shaft (`bottom` metres below the knob: higher to
## stickhandle, lower to shoot), slides up when that spot is out of reach and
## lets go when the shaft is out of reach altogether or the blade is past the
## front 90 degrees.
func _pose_stick(center: Vector3, flat: Vector3, tilt: float, bottom: float) -> void:
	var T := AnimTuning.current()
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	var hip_y := HIP_Y - _crouch
	var want := Vector3(T.grip_top_side, hip_y + T.grip_top_height + center.y * 0.5, -T.grip_top_fwd)
	want += Vector3(dir.x, 0, dir.z) * T.grip_top_follow
	# a check pulls the hands in to the chest
	want = want.lerp(Vector3(-0.05, hip_y + T.grip_top_height + 0.15, -0.15), _check * T.check_tuck)
	var reach := Vector3(center.x - want.x, 0, center.z - want.z)
	var toe := reach.normalized() if reach.length() > 0.05 else dir
	# the blade model curves towards +Z, its forehand; a right shot's forehand
	# is left of the toe, so the blade basis is mirrored
	var bb := Basis(toe, Vector3.UP, Vector3.UP.cross(toe))
	# tilt rolls the blade open about its length
	bb = Basis(toe, tilt * 0.7) * bb
	blade.transform = Transform3D(bb, center)
	var heel := center + bb * _blade_heel(T)
	var length := SHAFT_LEN * T.stick_length
	var arm := (UPPER_ARM + FOREARM) * T.grip_reach
	var knob := _knob(heel, want, length, faller.to_local(uppers[0].global_position), arm)
	var y := (knob - heel).normalized()
	var x := toe - y * toe.dot(y)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	stick.transform = Transform3D(Basis(x, y, x.cross(y)), heel)
	_grip_top = heel + y * (length - 0.04)
	_pose_arm(0, faller.to_global(_grip_top))
	var along := _slide(knob, -y, bottom, length, faller.to_local(uppers[1].global_position), arm)
	_bottom_off = along < 0.0
	var on := knob - y * maxf(along, 0.2)
	var rest := Vector3(0.32, hip_y + 0.25, -0.05 + sin(_cycle * TAU) * T.stride_arm_swing * _amp)
	_grip_bottom = on.lerp(rest, _one_hand)
	_pose_arm(1, faller.to_global(_grip_bottom))


## Where the knob goes: `length` from the heel, as close to `want` as it can
## be while the top hand (shoulder `sh`, reach `arm`) still holds it.
static func _knob(heel: Vector3, want: Vector3, length: float, sh: Vector3, arm: float) -> Vector3:
	var k := heel + (want - heel).normalized() * length
	if k.distance_to(sh) <= arm:
		return k
	var v := sh - heel
	var d := v.length()
	if d > length + arm or d < absf(length - arm) or d < 0.001:
		# out of reach: the arm goes straight towards it
		return heel + v.normalized() * length if d > length + arm else k
	# the knob can be anywhere on the circle where the stick's reach meets the
	# arm's; take the point nearest where the hand wants to be
	var n := v / d
	var a := (length * length - arm * arm + d * d) / (2.0 * d)
	var c := heel + n * a
	var q := want - c
	q -= n * q.dot(n)
	if q.length() < 0.0001:
		q = n.cross(Vector3.UP)
	return c + q.normalized() * sqrt(maxf(length * length - a * a, 0.0))


## How far below the knob the bottom hand holds the shaft (running from
## `knob` along `down`): `want` if it can reach, otherwise the nearest spot
## it can, or -1 when it can't reach the shaft at all.
static func _slide(knob: Vector3, down: Vector3, want: float, length: float, sh: Vector3, arm: float) -> float:
	var t0 := (sh - knob).dot(down)
	var perp := (sh - knob).length_squared() - t0 * t0
	if perp > arm * arm:
		return -1.0
	var h := sqrt(arm * arm - perp)
	var lo := maxf(0.2, t0 - h)
	var hi := minf(length - 0.15, t0 + h)
	return -1.0 if lo > hi else clampf(want, lo, hi)


## The blade's heel (where the shaft joins) in blade space, at the tuned size.
static func _blade_heel(T: AnimTuning) -> Vector3:
	return BLADE_HEEL * Vector3(T.stick_blade_length, T.stick_blade_height, T.stick_thickness)


## Rebuilds the shaft and blade meshes when the tuned stick size changes.
func _size_stick(T: AnimTuning) -> void:
	var size := Vector4(T.stick_length, T.stick_thickness, T.stick_blade_length, T.stick_blade_height)
	if size == _stick_size or _shaft_base == null:
		return
	_stick_size = size
	stick.mesh = _scaled_mesh(_shaft_base, Vector3(size.y, size.x, size.y))
	blade.mesh = _scaled_mesh(_blade_base, Vector3(size.z, size.w, size.y))


## A copy of `mesh` stretched by `s` about its pivot.
static func _scaled_mesh(mesh: Mesh, s: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for j in v.size():
			v[j] *= s
		arr[Mesh.ARRAY_VERTEX] = v
		if arr[Mesh.ARRAY_NORMAL] != null:
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for j in n.size():
				n[j] = (n[j] / s).normalized()
			arr[Mesh.ARRAY_NORMAL] = n
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


## Layers the celebration and fall arm poses over the stick pose: the stick
## goes into the top hand and the free hand flails, pumps or reaches.
func _pose_actions(T: AnimTuning) -> void:
	if _cel < 0.01 and _fall < 0.01:
		return
	var hy := HIP_Y - _crouch + 0.55
	var free := Vector3.ZERO
	var stick_dir := Vector3.UP
	var hand := _grip_top
	var w := _cel
	match _cel_kind:
		&"arms_up":
			# stick straight up overhead, other arm raised too
			hand = Vector3(-0.22, hy + 0.35 + T.celebrate_reach, -0.05)
			stick_dir = Vector3(0.1, 1, 0.05).normalized()
			free = Vector3(0.3, hy + 0.3 + T.celebrate_reach * 0.8, -0.05)
		_:
			# stick held out low in the top hand, the free fist pumps
			hand = Vector3(-0.38, hy - 0.2, -0.2)
			stick_dir = Vector3(-0.2, -0.6, -0.75).normalized()
			var pump := 0.5 + 0.5 * sin(_time * TAU * T.celebrate_pump_rate)
			free = Vector3(0.25, hy + 0.05, -0.3).lerp(Vector3(0.22, hy + 0.05 + T.celebrate_pump, -0.12), pump)
	if _fall > _cel:
		# going down: stick stays in the top hand, the other arm flies out
		w = _fall
		hand = _grip_top
		stick_dir = (blade.position + blade.basis * _blade_heel(T) - _grip_top).normalized()
		free = Vector3(0.45 + 0.3 * T.fall_flail, hy + 0.1 + 0.4 * T.fall_flail, -0.1 * _fall_dir)
	var held := _stick_in_hand(T, hand, stick_dir)
	stick.transform = stick.transform.interpolate_with(held[0], w)
	blade.transform = blade.transform.interpolate_with(held[1], w)
	var grip: Vector3 = stick.transform.origin + stick.transform.basis.y.normalized() * (SHAFT_LEN * T.stick_length - 0.04)
	_pose_arm(0, faller.to_global(grip))
	_pose_arm(1, faller.to_global(_grip_bottom.lerp(free, w)))


## Shaft and blade transforms (faller space) for a stick held near the knob
## in `hand`, the blade end pointing along `dir` away from the hand.
func _stick_in_hand(T: AnimTuning, hand: Vector3, dir: Vector3) -> Array:
	# a reference stick lying normally: blade flat at the origin, toe along +X,
	# shaft rising back towards the hands
	var bb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.UP.cross(Vector3.RIGHT))
	var heel := bb * _blade_heel(T)
	var y := Vector3(-0.7, 0.7, 0).normalized()
	var x := Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	x = x.normalized()
	var sb := Basis(x, y, x.cross(y))
	var grip := heel + y * (SHAFT_LEN * T.stick_length - 0.04)
	# turn it so the shaft points from the blade towards the hand along -dir
	var rot := Basis(Quaternion(y, -dir.normalized()))
	var off := hand - rot * grip
	return [Transform3D(rot * sb, rot * heel + off), Transform3D(rot * bb, off)]


## Two-bone IK for one arm: the elbow bends out to the side and back.
func _pose_arm(i: int, target_global: Vector3) -> void:
	var sd := -1.0 if i == 0 else 1.0
	var root := uppers[i].position
	var target := torso.to_local(target_global)
	var elbow := _two_bone(root, target, UPPER_ARM, FOREARM, Vector3(sd, -0.4, 0.7))
	var hand := root + (target - root).limit_length(UPPER_ARM + FOREARM - 0.002) if root.distance_to(target) > UPPER_ARM + FOREARM else target
	uppers[i].transform = Transform3D(_basis_along(root - elbow, 0.0), root)
	forearms[i].transform = Transform3D(_basis_along(elbow - hand, 0.0), elbow)


## Middle joint of a two-bone chain from `root` towards `target`, bending
## towards `pole`.
static func _two_bone(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d := target - root
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.FORWARD
	return root + dir * cos_a * l1 + bend * sqrt(1.0 - cos_a * cos_a) * l1


## Basis whose +Y points along `up` (parts hang down their local -Y from the
## pivot), turned `yaw` radians about that axis.
static func _basis_along(up: Vector3, yaw: float) -> Basis:
	var y := up.normalized() if up.length() > 0.0001 else Vector3.UP
	var z0 := Vector3(sin(yaw), 0, cos(yaw))
	var x := y.cross(z0)
	x = x.normalized() if x.length() > 0.0001 else Vector3.RIGHT
	return Basis(x, y, x.cross(y))


func _stick_basis(heel: Vector3, hand: Vector3, toe: Vector3) -> Basis:
	var y := hand - heel
	y = y.normalized() if y.length() > 0.01 else Vector3.UP
	var x := toe - y * toe.dot(y)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	return Basis(x, y, x.cross(y))


## Rotates a one-piece arm (which hangs along its local -Y) so the hand points at `target`.
func _aim_arm(arm: Node3D, target: Vector3) -> void:
	var parent := arm.get_parent() as Node3D
	var t := parent.to_local(target) - arm.position
	if t.length() < 0.01:
		return
	var up := -t.normalized()
	var x := Vector3.RIGHT - up * Vector3.RIGHT.dot(up)
	x = x.normalized() if x.length() > 0.01 else Vector3.FORWARD
	arm.basis = Basis(x, up, x.cross(up))
