class_name SkaterRig
extends Node3D
## Voxel character rig: a hierarchy of VoxelParts posed procedurally each
## frame. Skaters have jointed limbs (thigh + shin, upper arm + forearm) posed
## with two-bone IK: the feet follow a skating stride (glide, push out and
## back, lift and recover under the hips), the hips shift over the gliding
## skate, the shoulders counter-rotate, the outside leg crosses over in
## turns, and the hands follow the simulated stick. Goalies keep one-piece
## limbs.

const V := Models.V
const HIP_Y := 12 * V
const STICK_LEN := 23.5 * V   # goalie stick
const SHAFT_LEN := Models.SHAFT_VOX * Models.STICK_V
const BLADE_HEEL := Vector3(-7.5 * Models.STICK_V, 4.5 * Models.STICK_V, 0)  # in blade space
const THIGH := 6.0 * V
const SHIN := 6.5 * V           # knee to the bottom of the blade
const UPPER_ARM := 4.0 * V
const FOREARM := 3.5 * V        # elbow to the middle of the glove
const LEG_X := 2.0 * V

# stride cycle, per leg (u in 0..1): glide under the hips, push out and back,
# then lift and recover forward
const GLIDE_END := 0.45
const PUSH_END := 0.8

var goalie := false
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
var _bf := 0.0
var _time := 0.0
var _feet: Array[Vector3] = [Vector3(-0.15, 0, 0), Vector3(0.15, 0, 0)]
var _yaws: Array[float] = [0.0, 0.0]
var _one_hand := 0.0
var _follow := 0.0
var _follow_side := 1.0
var _shots := -1
var _prev_wind := 0.0
var _prev_ang := 0.0
var _stick_yaw := 0.0


func build(pal: Dictionary, is_goalie: bool) -> void:
	goalie = is_goalie
	body = Node3D.new()
	add_child(body)
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
		add_child(blade)
	add_child(stick)


## The stick follows through high towards the target after a shot. `side` is
## +1 forehand, -1 backhand.
func follow_through(strength: float, side := 1.0) -> void:
	_follow = clampf(strength, 0.3, 1.0)
	_follow_side = side


## Starts a follow-through when this skater's shot just left the blade.
func _watch_shots(s: Skater) -> void:
	var shots: int = s.game.stats.shots
	if _shots >= 0 and shots > _shots and s.puck.last_touch == s and not s.has_puck():
		follow_through(_prev_wind * 1.3 + 0.35, -1.0 if _prev_ang < -0.2 else 1.0)
	_shots = shots
	_prev_wind = s.windup()
	_prev_ang = s.blade_ang


func update_skater(s: Skater, dt: float) -> void:
	_time += dt
	var speed := Vector2(s.vel.x, s.vel.z).length()
	var k := clampf(speed / 9.0, 0.0, 1.0)
	var able := s.stun_timer <= 0.0
	var pushing := s.ctrl.move.length() > 0.2 and not s.braking and able
	var dashing := s.dash_timer > 0.0
	var smooth := 1.0 - exp(-8.0 * dt)

	# stride: long, wide pushes at speed, short quick ones from a standstill
	var amp_target := (0.4 + 0.6 * k) * (1.25 if dashing else 1.0) if pushing else 0.0
	_amp = lerpf(_amp, amp_target, 1.0 - exp(-4.0 * dt))
	var cadence := lerpf(1.7, 1.25, k) * (1.35 if dashing else 1.0)
	if _amp > 0.02:
		_cycle = fmod(_cycle + dt * cadence, 1.0)
	_lean = lerpf(_lean, clampf(s.yaw_rate * speed * 0.05, -0.45, 0.45), smooth)
	_cross = lerpf(_cross, clampf((absf(_lean) - 0.08) / 0.25, 0.0, 1.0) if pushing and speed > 2.5 else 0.0, smooth)
	_brake = lerpf(_brake, 1.15 if s.braking else 0.0, 1.0 - exp(-12.0 * dt))
	_fall = lerpf(_fall, 1.0 if s.stun_timer > 0.25 else 0.0, 1.0 - exp(-7.0 * dt))
	var stop := _brake / 1.15

	# feet: blend the stride with a two-skate glide and the hockey-stop stance
	var outside := 1.0 if _lean > 0.0 else -1.0
	var stride_w := clampf(_amp * 2.5, 0.0, 1.0)
	var support: Array[float] = [0.0, 0.0]
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var u := fmod(_cycle + (0.0 if i == 0 else 0.5), 1.0)
		var r := _stride_foot(sd, u, _amp, _cross if sd == outside else 0.0, _cross if sd != outside else 0.0)
		var glide := Vector3(sd * 0.15, 0, -sd * 0.05 * k)
		var foot: Vector3 = glide.lerp(r[0], stride_w)
		var yaw: float = r[1] * stride_w
		foot = foot.lerp(Vector3(sd * 0.3, 0, sd * 0.04), stop)
		yaw = lerpf(yaw, 0.0, stop)
		_feet[i] = _feet[i].lerp(foot, 1.0 - exp(-30.0 * dt))
		_yaws[i] = lerpf(_yaws[i], yaw, 1.0 - exp(-20.0 * dt))
		support[i] = 1.0 if (u < GLIDE_END or stride_w < 0.5) else 0.0

	# hips: low athletic stance, sink at speed and in the stop, ride over the
	# gliding skate, a little bob with each push
	var sup_x: float = (_feet[0].x * support[0] + _feet[1].x * support[1]) / maxf(support[0] + support[1], 1.0)
	_shift = lerpf(_shift, sup_x * 0.55 * stride_w, 1.0 - exp(-6.0 * dt))
	_crouch = lerpf(_crouch, 0.12 + 0.05 * k + 0.07 * stop + (0.03 if dashing else 0.0), smooth)
	var bob := absf(sin(_cycle * TAU)) * 0.025 * _amp + sin(_time * 2.2) * 0.006 * (1.0 - stride_w)
	hips.position = Vector3(_shift, HIP_Y - _crouch - bob, 0.03 * k)
	_twist = lerpf(_twist, sin(_cycle * TAU) * 0.16 * _amp * (1.0 - _cross * 0.5), smooth)
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
	_follow = maxf(0.0, _follow - dt * 2.2)
	var fol := smoothstep(0.0, 1.0, _follow)
	torso.rotation.x = lerpf(torso.rotation.x, -(0.22 + 0.42 * k) + w * 0.15 + stop * 0.2 - fol * 0.15, smooth)
	torso.rotation.y = lerpf(torso.rotation.y, _twist - _stick_yaw * 0.4 + fol * 0.35 * _follow_side, smooth)
	torso.rotation.z = lerpf(torso.rotation.z, _shift * 1.2, smooth)
	head.rotation = Vector3(-(torso.rotation.x + hips.rotation.x) * 0.85, -(torso.rotation.y + hips.rotation.y) * 0.7, -torso.rotation.z * 0.8)
	body.rotation = Vector3(_fall * 1.35, _brake, _lean + _brake * 0.25)

	for i in 2:
		_pose_leg(i)

	# one hand comes off the stick outside the front 90 degrees (the skater's
	# one_hand(), which also holds both on for a wind-up) and stays on for the
	# follow-through
	var oh := 0.0 if _follow > 0.0 else s.one_hand()
	_one_hand = lerpf(_one_hand, oh, 1.0 - exp(-10.0 * dt))
	var center := Vector3(flat.x, s.blade_height + fol * 0.55, flat.z)
	_pose_stick(center, flat, s.ctrl.tilt, k)


## Foot position (body space, +z is behind) and toe-out yaw for one leg at
## cycle point `u`. `cross` brings the outside skate over in a turn; `under`
## pushes the inside skate under the body.
func _stride_foot(sd: float, u: float, amp: float, cross: float, under: float) -> Array:
	var front := Vector3(sd * 0.11, 0, -0.1 * amp)
	var mid := Vector3(sd * 0.13, 0, 0.06 * amp)
	var out := Vector3(sd * (0.14 + 0.3 * amp), 0, 0.12 + 0.2 * amp)
	out.x = lerpf(out.x, -sd * 0.12, under * 0.7)
	front.x = lerpf(front.x, -sd * 0.12, cross)
	var toe_out := -sd * 0.6 * amp
	if u < GLIDE_END:
		var e := u / GLIDE_END
		return [front.lerp(mid, e), toe_out * 0.2 * e]
	if u < PUSH_END:
		var e := smoothstep(0.0, 1.0, (u - GLIDE_END) / (PUSH_END - GLIDE_END))
		return [mid.lerp(out, e), lerpf(toe_out * 0.2, toe_out, e)]
	var r := (u - PUSH_END) / (1.0 - PUSH_END)
	var p := out.lerp(front, smoothstep(0.0, 1.0, r))
	p.y = sin(PI * r) * (0.09 + 0.06 * cross) * maxf(amp, 0.3)
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


## Blade flat on the ice at `center` (rig space), square to the line from the
## body; the shaft runs from the heel up to the top hand. Two hands: top hand
## on the knob, bottom hand a forearm's length down. One hand: the top hand
## reaches out towards the blade and the bottom hand drops to the hip.
func _pose_stick(center: Vector3, flat: Vector3, tilt: float, k: float) -> void:
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	var toe := Vector3.UP.cross(dir)
	var bb := Basis(toe, Vector3.UP, toe.cross(Vector3.UP))
	# tilt rolls the blade open about its length
	bb = bb.rotated(toe, -tilt * 0.7)
	blade.transform = Transform3D(bb, center)
	var heel := center + bb * BLADE_HEEL
	var hy := 0.95 - 0.1 * k - _crouch + center.y * 0.5
	var two := Vector3(0.0, hy, -0.22) + flat * 0.22
	# one-handed: the top (left) hand reaches from its shoulder towards the blade
	var shoulder := Vector3(-0.3, hy + 0.25, 0.0)
	var one := shoulder + (Vector3(dir.x, 0, dir.z) * 0.65 + Vector3(0, -0.3, 0))
	var grip := two.lerp(one, _one_hand)
	var y := (grip - heel).normalized()
	var x := toe - y * toe.dot(y)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	var sb := Basis(x, y, x.cross(y))
	stick.transform = Transform3D(sb, heel)
	# hands grip where the shaft passes them, never past the knob
	var along := clampf((grip - heel).dot(y), SHAFT_LEN * 0.5, SHAFT_LEN - 0.04)
	var top := heel + y * along
	_pose_arm(0, to_global(top))
	var bottom := heel + y * (along - 0.42)
	var rest := Vector3(0.32, hy - 0.05, -0.05 + sin(_cycle * TAU) * 0.12 * _amp)
	_pose_arm(1, to_global(bottom.lerp(rest, _one_hand)))


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
