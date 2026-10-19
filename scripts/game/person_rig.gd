class_name PersonRig
extends SkaterRig
## A person on foot: the skater's jointed body (the same joints and the same
## two-bone IK, see SkaterRig) without the stick, posed every frame from a
## walking body such as VenueWalker. It only draws: the walker's capsule is
## the simulated body, and the rig follows its velocity, never the other way.
##
## Walking keeps each foot planted while it carries weight, so a stride is
## exactly as long as the walker's speed makes it, and the hips drop as low
## as the legs need to reach both feet. On top of walking a person can sit,
## squat, kneel on one knee, reach a hand to a point (a valve, a bolt, a
## door handle) and look at something. Owner, coaches, public skaters and
## beer leaguers all use this rig; they differ only in their palette.
##
## Every shaping number lives in AnimTuning's walk, sit, crouch and reach
## groups, tuned in the animation studio.

enum Pose { STAND, SIT, CROUCH, KNEEL }

const NONE := Vector3.INF

## What the person is doing; walking happens in STAND whenever they move.
var pose := Pose.STAND
## SIT: the middle of the seat's front edge (world space). The person sits
## facing away from the seat, so face them that way.
var seat := NONE
## Where each hand reaches (world space, index 0 = left, 1 = right), or NONE.
var reach: Array[Vector3] = [NONE, NONE]
## A point the head turns to, or NONE.
var look := NONE
## The way the body faces (world, flat). It turns towards the walking
## direction on its own; set it to face a job when standing still.
var facing := Vector3.FORWARD
## The walker is off the floor (a jump or a fall); `vel.y` says whether it
## is still rising. The frame it comes back to the floor is the landing.
var airborne := false
## Crouched (sneaking, or under something low): walks low on short steps.
var crouched := false

var _phase := 0.0       # walk cycle, 0..1 per two steps
var _gait := 0.0        # 0 standing .. 1 walking or running
var _run := 0.0         # 0 walking .. 1 running
var _move := Vector3.FORWARD   # body-space walking direction
var _poses := [0.0, 0.0, 0.0]  # how far into SIT, CROUCH, KNEEL
var _hand: Array[Vector3] = [NONE, NONE]   # smoothed hand targets (world)
var _hand_w: Array[float] = [0.0, 0.0]
var _bend := Vector2.ZERO      # upper body turn (x) and lean (y) towards a reach
var _sprint := 0.0      # 0 running .. 1 flat-out sprint
var _air := 0.0         # how far into the in-air pose
var _land := 0.0        # landing: 1 at touchdown, easing to 0
var _low := 0.0         # how far into the crouch
var _was_air := false
var _step: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # each foot on its walk cycle (body space, flat)
var _lift_off: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # where a swing began
var _planted: Array[bool] = [false, false]
var _yaw := 0.0


## Builds the body in palette `pal` (Models palettes), with no stick.
func build_person(pal: Dictionary) -> void:
	build(pal, false)
	stick.visible = false
	blade.visible = false
	# shoes, not skates
	shin_len = (Models.SHIN_V + Models.SHOE_V) * V
	for sh in shins:
		sh.mesh = Models.shin_shoe(pal).build_mesh()


## Poses the body for a walker moving at `vel` (world space).
func update_person(vel: Vector3, dt: float) -> void:
	var T := AnimTuning.current()
	_time += dt
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	if speed > 0.3 and pose == Pose.STAND:
		facing = facing.lerp(flat / speed, 1.0 - exp(-T.walk_turn * dt))
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var yaw := atan2(-facing.x, -facing.z)
	var turned := wrapf(yaw - _yaw, -PI, PI)
	_yaw = yaw
	global_basis = Basis(Vector3.UP, yaw)
	var local := global_basis.inverse() * flat
	if speed > 0.05:
		_move = local / speed

	var moving := 1.0 if speed > 0.15 and pose == Pose.STAND else 0.0
	_gait = lerpf(_gait, moving, 1.0 - exp(-8.0 * dt))
	_run = lerpf(_run, clampf((speed - T.walk_run_from) / (T.walk_run_full - T.walk_run_from), 0.0, 1.0), 1.0 - exp(-6.0 * dt))
	_sprint = lerpf(_sprint, clampf((speed - T.walk_run_full) / (T.walk_sprint_speed - T.walk_run_full), 0.0, 1.0), 1.0 - exp(-6.0 * dt))
	_air = lerpf(_air, 1.0 if airborne else 0.0, 1.0 - exp(-(18.0 if airborne else 30.0) * dt))
	if _was_air and not airborne:
		_land = 1.0
		# the feet come down where the stride says, not where they took off
		_planted = [false, false]
	_was_air = airborne
	_land = maxf(0.0, _land - dt / T.jump_land_time)
	_low = lerpf(_low, 1.0 if crouched else 0.0, 1.0 - exp(-(20.0 if crouched else 8.0) * dt))
	for k in 3:
		_poses[k] = lerpf(_poses[k], 1.0 if pose == k + 1 else 0.0, 1.0 - exp(-T.sit_speed * dt))
	var sit: float = _poses[0]
	var squat: float = _poses[1]
	var kneel: float = _poses[2]

	# the walk cycle: each foot spends `duty` of the cycle on the floor,
	# sliding back under the body at exactly the walking speed
	# quicker steps the faster the walk; at a sprint, quick short contacts
	var walk_cad := T.walk_cadence * sqrt(clampf(speed, 0.6, T.walk_run_full) / 1.4)
	var run_cad := lerpf(T.walk_cadence_run, T.walk_cadence_sprint, _sprint)
	var cadence := lerpf(walk_cad, run_cad, _run)
	var freq := cadence * 0.5
	var duty := lerpf(T.walk_duty, lerpf(T.walk_duty_run, T.walk_duty_sprint, _sprint), _run)
	if _gait > 0.01 and _air < 0.5:
		_phase = fmod(_phase + freq * dt, 1.0)
	var span := speed * duty / freq if speed > 0.05 else 0.0
	var lift := lerpf(T.walk_lift, lerpf(T.walk_lift_run, T.walk_lift_sprint, _sprint), _run)
	var legs := (THIGH + shin_len) * 0.98
	var hip_h := legs * 0.97
	var on_floor: Array[bool] = [true, true]
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var u := fmod(_phase + 0.5 * i, 1.0)
		var base := Vector3(sd * T.walk_width, 0.0, 0.0)
		var up := 0.0
		var land := base + _move * span * 0.5
		if u < duty:
			# planted: the foot stays where it is on the floor while the body
			# moves (and turns) over it
			if not _planted[i]:
				_planted[i] = true
				_step[i] = base + _move * lerpf(span * 0.5, -span * 0.5, u / duty)
			_step[i] = (_step[i] - local * dt).rotated(Vector3.UP, -turned)
			# speeding up, a stance can outlast its stride: the foot drags
			# rather than the leg stretching past what it can reach
			var behind := -(_step[i] - base).dot(_move) - (span * 0.5 + 0.12)
			if behind > 0.0:
				_step[i] += _move * behind
		else:
			if _planted[i]:
				_planted[i] = false
				_lift_off[i] = _step[i]
			var r := (u - duty) / (1.0 - duty)
			_step[i] = _lift_off[i].lerp(land, smoothstep(0.0, 1.0, r))
			up = sin(PI * r) * lift
			on_floor[i] = false
		var stand := base + Vector3(0.0, 0.0, -0.02)
		var foot := stand.lerp(_step[i] + Vector3(0.0, up, 0.0), _gait)
		# idle: weight drifts slowly from foot to foot
		foot.x += sin(_time * 0.7) * T.walk_idle_sway * (1.0 - _gait) * 0.5
		# sitting, squatting and kneeling put the feet where those need them
		var seat_l := to_local(seat) if seat != NONE else Vector3(0.0, 0.45, 0.25)
		foot = foot.lerp(Vector3(sd * T.walk_width * 1.3, 0.0, seat_l.z - T.sit_feet), sit)
		foot = foot.lerp(Vector3(sd * T.walk_width * 1.5, 0.0, -0.06), squat)
		foot = foot.lerp(Vector3(-0.12, 0.0, -0.34) if i == 0 else Vector3(0.12, 0.05, 0.42), kneel)
		# crouched, the feet go a little wider
		foot.x += sd * T.walk_width * 0.4 * _low
		# in the air: going up, one knee drives up and the other leg trails;
		# coming down, both feet come under the body, reaching for the floor
		var rising := clampf(vel.y / 3.0, -1.0, 1.0)
		var drive := Vector3(sd * T.walk_width, T.jump_tuck * (0.6 + 0.4 * rising), -0.12) if i == 1 else Vector3(sd * T.walk_width, T.jump_tuck * 0.3, 0.16 * maxf(rising, 0.0))
		var reach_down := Vector3(sd * T.walk_width * 1.2, T.jump_tuck * 0.25, -0.04)
		var air_foot := drive.lerp(reach_down, clampf(-rising, 0.0, 1.0))
		air_foot += _move * span * 0.25 * (1.0 if i == 1 else -0.6)
		foot = foot.lerp(air_foot, _air)
		_feet[i] = foot
		_yaws[i] = 0.0
		# the hips go only as high as both planted legs reach
		if (on_floor[i] or _gait < 0.5) and _air < 0.5:
			var flat_d := Vector2(foot.x - sd * LEG_X, foot.z).length()
			hip_h = minf(hip_h, sqrt(maxf(legs * legs - flat_d * flat_d, 0.36 * legs * legs)))

	# hips: bounce at a run, sway over the carrying foot, turn with the stride
	var mid := cos(4.0 * PI * (_phase - duty * 0.5))
	hip_h -= T.walk_bob * (1.0 + mid) * 0.5 * _run * _gait
	var sway := -cos(TAU * (_phase - duty * 0.5)) * T.walk_sway * _gait * (1.0 - _run)
	sway += sin(_time * 0.7) * T.walk_idle_sway * (1.0 - _gait)
	var seat_y := to_local(seat).y + 0.06 if seat != NONE else 0.45
	var seat_z := to_local(seat).z + 0.14 if seat != NONE else 0.25
	# a crouch sinks the hips; a landing dips them and springs back
	hip_h = lerpf(hip_h, minf(hip_h, T.crouch_walk_hips), _low)
	if _land > 0.0:
		hip_h -= T.jump_land_dip * sin(PI * sqrt(1.0 - _land))
	var hips_at := Vector3(sway, hip_h, 0.0)
	hips_at = hips_at.lerp(Vector3(0.0, seat_y, seat_z), sit)
	hips_at = hips_at.lerp(Vector3(0.0, T.crouch_hips, 0.08), squat)
	hips_at = hips_at.lerp(Vector3(0.02, T.crouch_kneel_hips, 0.04), kneel)
	hips.position = hips_at
	var hip_turn := sin(TAU * _phase) * T.walk_hip_turn * _gait
	hips.rotation = Vector3(0.0, hip_turn, -sway * 0.8)

	# upper body: leans into a run, sits back, bends over a job, and bends
	# and turns to bring a hand to what it's reaching for
	var bend := Vector2.ZERO
	var reaching := 0.0
	for i in 2:
		var w := 1.0 if reach[i] != NONE else 0.0
		_hand_w[i] = lerpf(_hand_w[i], w, 1.0 - exp(-T.reach_speed * dt))
		if reach[i] != NONE:
			_hand[i] = reach[i] if _hand_w[i] < 0.02 or _hand[i] == NONE else _hand[i].lerp(reach[i], 1.0 - exp(-T.reach_speed * 2.0 * dt))
			var tl := to_local(reach[i])
			var sh := to_local(torso.to_global(_shoulders[i]))
			var reach_len := (UPPER_ARM + FOREARM) * T.grip_arm_length
			var short := maxf(sh.distance_to(tl) - reach_len * 0.95, 0.0)
			var turn := clampf(atan2(-(tl.x - sh.x * 0.5), -tl.z), -0.9, 0.9)
			var lean := clampf(short / 0.45, 0.0, 1.0) * (1.2 if tl.y < sh.y else 0.4)
			bend += Vector2(turn * 0.5, lean) * _hand_w[i]
			reaching = maxf(reaching, _hand_w[i])
	_bend = _bend.lerp(bend * T.reach_bend, 1.0 - exp(-6.0 * dt))
	var lean_x := -(T.walk_run_lean + T.walk_sprint_lean * _sprint) * _run * _gait
	lean_x -= T.crouch_walk_lean * _low + T.jump_land_dip * 1.5 * (_land if _land > 0.0 else 0.0)
	lean_x = lerpf(lean_x, T.sit_lean, sit)
	lean_x = lerpf(lean_x, -T.crouch_lean, maxf(squat, kneel))
	lean_x -= _bend.y
	torso.rotation = Vector3(lean_x, -hip_turn * 1.6 + _bend.x, sway * 0.6)
	# the head stays level and turns to what it looks at
	var head_yaw := 0.0
	var head_pitch := 0.0
	if look != NONE:
		var hl := to_local(look) - to_local(head.global_position)
		head_yaw = clampf(atan2(-hl.x, -hl.z) - torso.rotation.y - hips.rotation.y, -1.1, 1.1)
		head_pitch = clampf(atan2(hl.y, Vector2(hl.x, hl.z).length()), -0.9, 0.6)
	head.rotation = Vector3(head_pitch - (torso.rotation.x + hips.rotation.x), head_yaw, -torso.rotation.z * 0.8)

	for i in 2:
		_pose_leg(i)

	# arms: swing against the legs, bend up at a run, rest on the thighs when
	# sitting or kneeling, and go to whatever they reach for
	var arm := (UPPER_ARM + FOREARM) * T.grip_arm_length
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var other := fmod(_phase + 0.5 * (1 - i), 1.0)
		var swing := -cos(TAU * (other - duty * 0.5)) * T.walk_arm_swing * (1.0 + _run + _sprint) * _gait
		swing *= 1.0 - _air * 0.7
		# arms come forward for balance crouched, and swing up in a jump
		swing += 0.5 * _low + T.jump_arms * _air
		var bent := lerpf(0.95, lerpf(0.7, 0.55, _sprint), _run * _gait)
		bent = lerpf(bent, 0.75, _low)
		var sh: Vector3 = _shoulders[i]
		var hang := sh + Vector3(sd * 0.06, -cos(swing), -sin(swing)) * arm * bent
		hang.z -= 0.12 * _run * _gait
		var rest := torso.to_global(hang)
		var knee := thighs[i].global_transform * Vector3(0.0, -THIGH * 0.8, -0.05)
		rest = rest.lerp(knee + Vector3(0.0, 0.06, 0.0), maxf(sit, kneel) * 0.8)
		var target := rest.lerp(_hand[i], _hand_w[i]) if _hand[i] != NONE else rest
		_pose_arm(i, target)


## Moves the head and arms onto render layer `layer` (1-based), so a
## first-person camera that leaves that layer out sees FirstPersonArms in
## their place while other cameras still see the whole body.
func hide_from_view(layer: int) -> void:
	for part in [head] + Array(uppers) + Array(forearms):
		part.layers = 1 << (layer - 1)


## Where hand `i` is now (world space): the middle of the glove.
func hand_pos(i: int) -> Vector3:
	return forearms[i].global_transform * Vector3(0.0, -FOREARM, 0.0)


## Where foot `i` is now (world space): the bottom of the shin.
func foot_pos(i: int) -> Vector3:
	return shins[i].global_transform * Vector3(0.0, -shin_len, 0.0)
