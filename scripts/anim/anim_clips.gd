class_name AnimClips
extends RefCounted
## The animation studio's clips: short loops that act out one animation on
## the treadmill puppet. Each clip only says what the skater is doing
## (speed, pushing, turning, stopping, the blade's path, shots, checks,
## falls, celebrations); SkaterRig does the animating, with the numbers in
## AnimTuning. `groups` names the AnimTuning groups that shape the clip, so
## the studio shows those sliders with it.

const FOREHAND_WIND := 100.0  # Skater.WIND_SPOT as an angle (deg) ...
const WIND_REACH := 0.86      # ... and reach (m)

const LIST := [
	{"id": &"neutral", "title": "Ready stance", "groups": ["stance", "grip", "stick"], "len": 4.0,
		"note": "Standing still, knees bent, blade on the ice."},
	{"id": &"stickhandle", "title": "Stickhandling", "groups": ["grip", "stick"], "len": 6.0,
		"note": "A loose, physical puck: the blade pushes it across, lifts over it, sets down on the far side and pushes it back."},
	{"id": &"wide_reach", "title": "Wide reach", "groups": ["grip"], "len": 4.0,
		"note": "Past the front 90 degrees the bottom hand lets go; the top hand keeps the knob and swings the stick on a straight arm."},
	{"id": &"poke_check", "title": "Poke check", "groups": ["grip"], "len": 3.0,
		"note": "Stick jabbed straight out front: the bottom hand lets go for the extra reach."},
	{"id": &"stride_easy", "title": "Skating stride: easy", "groups": ["stance", "stride"], "len": 4.0,
		"note": "Striding at about 9 mph."},
	{"id": &"stride_full", "title": "Skating stride: full speed", "groups": ["stance", "stride"], "len": 4.0,
		"note": "Striding at about 22 mph."},
	{"id": &"dash", "title": "Dash", "groups": ["dash", "stride"], "len": 4.0,
		"note": "Burst strides from a cruise, twice per loop."},
	{"id": &"glide", "title": "Glide", "groups": ["stance"], "len": 3.0,
		"note": "Coasting on both skates."},
	{"id": &"cross_left", "title": "Crossovers: left turn", "groups": ["cross", "stride"], "len": 5.0,
		"note": "Striding through a tight left turn: lean in, outside skate crosses over."},
	{"id": &"cross_right", "title": "Crossovers: right turn", "groups": ["cross", "stride"], "len": 5.0,
		"note": "The same turning right."},
	{"id": &"hockey_stop", "title": "Hockey stop", "groups": ["stop"], "len": 3.6,
		"note": "Skate, stop hard sideways with a spray of snow, stand, go again."},
	{"id": &"wrist_shot", "title": "Wrist shot", "groups": ["shot", "grip"], "len": 3.5,
		"note": "Draw the puck back behind the forehand hip, sweep forward, follow through."},
	{"id": &"snap_shot", "title": "Snapshot", "groups": ["shot", "grip"], "len": 3.0,
		"note": "Pull out to the forehand side and snap straight through."},
	{"id": &"slapshot", "title": "Slapshot", "groups": ["shot", "grip"], "len": 3.5,
		"note": "Blade lifted high behind, slammed through, big follow-through."},
	{"id": &"backhand", "title": "Backhand", "groups": ["shot", "grip"], "len": 3.5,
		"note": "Draw back behind the backhand hip, sweep forward."},
	{"id": &"backhand_snap", "title": "Backhand snap", "groups": ["shot", "grip"], "len": 3.0,
		"note": "Pull out to the backhand side and snap through."},
	{"id": &"pass_forehand", "title": "Forehand pass", "groups": ["pass"], "len": 2.5,
		"note": "Short sweep from the forehand side, low follow-through."},
	{"id": &"pass_backhand", "title": "Backhand pass", "groups": ["pass"], "len": 2.5,
		"note": "The same off the backhand."},
	{"id": &"check", "title": "Body check", "groups": ["check"], "len": 2.5,
		"note": "Skating in, load up, drive through with the shoulder."},
	{"id": &"fall_back", "title": "Knocked down: backward", "groups": ["fall"], "len": 3.5,
		"note": "Hit while standing: goes over backwards, then gets up."},
	{"id": &"fall_forward", "title": "Knocked down: forward", "groups": ["fall"], "len": 3.5,
		"note": "Hit from behind at speed: goes down face first, then gets up."},
	{"id": &"cel_arms_up", "title": "Celebration: arms up", "groups": ["celebrate"], "len": 3.2,
		"note": "Gliding with the stick raised overhead."},
	{"id": &"cel_fist_pump", "title": "Celebration: fist pump", "groups": ["celebrate"], "len": 3.2,
		"note": "Gliding, stick out low, pumping the free fist."},
	{"id": &"cel_knee_slide", "title": "Celebration: knee slide", "groups": ["celebrate"], "len": 3.2,
		"note": "Drops to one knee and slides, pumping the fist."},
	# on foot (PersonRig): "person" clips run on AnimPerson instead of the skater
	{"id": &"walk", "title": "On foot: walk", "groups": ["walk"], "len": 4.0, "person": true,
		"note": "A stroll at 1.4 m/s. Planted feet never slide on the floor."},
	{"id": &"run", "title": "On foot: run", "groups": ["walk"], "len": 4.0, "person": true,
		"note": "Running at 4 m/s, both feet off the floor between steps."},
	{"id": &"walk_turn", "title": "On foot: walk and turn", "groups": ["walk"], "len": 6.0, "person": true,
		"note": "Walks a curve, the body turning to face the way it goes."},
	{"id": &"idle", "title": "On foot: idle", "groups": ["walk"], "len": 5.0, "person": true,
		"note": "Standing, shifting weight, looking round the room."},
	{"id": &"sit", "title": "On foot: sit", "groups": ["sit"], "len": 6.0, "person": true,
		"note": "Sits on the bench behind, rests the hands on the knees, gets up."},
	{"id": &"crouch_work", "title": "On foot: crouch at a machine", "groups": ["crouch", "reach"], "len": 5.0, "person": true, "cam": "rear_quarter",
		"note": "Squats at a low panel and turns a valve with both hands."},
	{"id": &"kneel_work", "title": "On foot: kneel at a machine", "groups": ["crouch", "reach"], "len": 5.0, "person": true, "cam": "rear_quarter",
		"note": "Kneels on one knee and works a bolt low on the machine."},
	{"id": &"reach_grab", "title": "On foot: reach and grab", "groups": ["reach"], "len": 6.0, "person": true,
		"note": "Hands land on a high valve, a breaker, then a far low lever (the body bends for it)."},
	{"id": &"first_person", "title": "On foot: first-person arms", "groups": ["reach"], "len": 6.0, "person": true,
		"note": "The player's view: both hands take a valve wheel and turn it."},
]


static func index_of(id: StringName) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1


## Poses the puppet for time `t` (seconds into the loop). `mem` is the
## clip's scratch dictionary, cleared each loop.
static func run(id: StringName, p: AnimPuppet, t: float, dt: float, mem: Dictionary) -> void:
	p.clear_intent()
	match id:
		&"neutral":
			pass
		&"stickhandle":
			_stickhandle(p, dt, mem)
		&"wide_reach":
			p.blade_deg = sin(t * TAU * 0.25) * 95.0
			p.blade_m = 1.2 + 0.3 * absf(sin(t * TAU * 0.25))
		&"poke_check":
			var jab := smoothstep(0.8, 1.0, t) * (1.0 - smoothstep(1.5, 1.9, t))
			p.blade_deg = 5.0
			p.blade_m = lerpf(1.2, 1.9, jab)
		&"stride_easy":
			_skate(p, 4.0)
		&"stride_full":
			_skate(p, 10.0)
		&"dash":
			_skate(p, 8.0)
			if _once(mem, "d1", t >= 0.4) or _once(mem, "d2", t >= 2.4):
				p.dash_timer = 0.45
				p.vel = p.heading * minf(p.speed() + 2.5, 11.2)
		&"glide":
			if _once(mem, "v", true):
				p.vel = p.heading * 7.0
			p.go_speed = 0.0
			p.accel = 0.4
		&"cross_left":
			_skate(p, 7.0)
			p.turn_rate = 1.0
		&"cross_right":
			_skate(p, 7.0)
			p.turn_rate = -1.0
		&"hockey_stop":
			if t < 1.4:
				_skate(p, 9.0)
				p.accel = 30.0
			else:
				p.go_speed = 0.0
				p.accel = 9.0
				p.braking = t < 2.5
		&"wrist_shot":
			_carry(p, t, mem)
			if t >= 0.8 and t < 1.5:
				p.wind(dt)
				p.blade_deg = FOREHAND_WIND
				p.blade_m = WIND_REACH
			elif _once(mem, "fire", t >= 1.5):
				var held := p.unwind()
				p.rig.follow_through(held * 1.5, 1.0)
				_shoot(p, 24.0)
			if t >= 1.5:
				_finish(p, 1.0)
		&"snap_shot":
			_carry(p, t, mem)
			if t >= 0.6 and t < 0.9:
				p.blade_deg = 50.0
				p.blade_m = 0.85
			elif t >= 0.9 and t < 1.0:
				p.blade_deg = -5.0
				p.blade_m = 1.35
				if _once(mem, "fire", t >= 0.96):
					_shoot(p, 22.0)
			elif t >= 1.0:
				_finish(p, 1.0)
		&"slapshot":
			_carry(p, t, mem)
			if t >= 0.6 and t < 1.6:
				p.wind(dt, true)
				p.blade_deg = FOREHAND_WIND
				p.blade_m = WIND_REACH
				p.blade_h = 0.9 * p.windup() + 0.2
			elif _once(mem, "fire", t >= 1.6):
				var held := p.unwind()
				p.rig.follow_through(held * 1.5 + 0.4, 1.0)
				_shoot(p, 30.0)
			if t >= 1.6:
				_finish(p, 1.0)
		&"backhand":
			_carry(p, t, mem)
			if t >= 0.8 and t < 1.5:
				p.wind(dt)
				p.blade_deg = -FOREHAND_WIND
				p.blade_m = WIND_REACH
			elif _once(mem, "fire", t >= 1.5):
				var held := p.unwind()
				p.rig.follow_through(held * 1.5, -1.0)
				_shoot(p, 18.0, 5.0)
			if t >= 1.5:
				_finish(p, -1.0)
		&"backhand_snap":
			_carry(p, t, mem)
			if t >= 0.6 and t < 0.9:
				p.blade_deg = -50.0
				p.blade_m = 0.85
			elif t >= 0.9 and t < 1.0:
				p.blade_deg = 10.0
				p.blade_m = 1.3
				if _once(mem, "fire", t >= 0.97):
					_shoot(p, 17.0, 4.0)
			elif t >= 1.0:
				_finish(p, -1.0)
		&"pass_forehand", &"pass_backhand":
			var sd := 1.0 if id == &"pass_forehand" else -1.0
			_carry(p, t, mem)
			if t >= 0.6 and t < 0.85:
				p.blade_deg = 45.0 * sd
				p.blade_m = 0.9
			elif t >= 0.85 and t < 1.0:
				p.blade_deg = 0.0
				p.blade_m = 1.15
				if _once(mem, "pass", t >= 0.95):
					p.release_puck(Vector3(11.0, 0.0, 0.0))
		&"check":
			_skate(p, 6.0)
			if _once(mem, "hit", t >= 1.0):
				p.check_timer = SkaterRig.CHECK_TIME
				p.vel += p.heading * 2.0
		&"fall_back":
			if _once(mem, "hit", t >= 0.6):
				p.stun_timer = 1.3
				p.vel = -p.heading * 2.5
		&"fall_forward":
			if t < 0.8:
				_skate(p, 7.0)
				p.accel = 30.0
			elif _once(mem, "hit", true):
				p.stun_timer = 1.3
				p.vel = p.heading * 8.0
		&"cel_arms_up", &"cel_fist_pump", &"cel_knee_slide":
			if _once(mem, "v", true):
				p.vel = p.heading * 6.0
			p.go_speed = 0.0
			p.accel = 0.5
			if _once(mem, "go", t >= 0.3):
				p.rig.celebrate(StringName(String(id).trim_prefix("cel_")), 2.5)


## Striding at `speed` m/s.
static func _skate(p: AnimPuppet, speed: float) -> void:
	p.go_speed = speed
	p.accel = 30.0
	p.push = true


## Stickhandling a loose puck. The blade only moves the puck by touching it
## (AnimPuppet rolls it): it catches the puck on one face, pushes it across,
## then lifts, passes over it while it slides, sets down on the far side and
## catches it again with the other face.
const HANDLE_OUT := 1.3       # how far out front the puck is worked (m)
const HANDLE_WIDE := 0.16     # how far either side the puck travels (m)
const HANDLE_SPEED := 0.75     # how fast the blade pushes the puck (m/s)
const HANDLE_ACCEL := 14.0    # how hard it gets there (m/s^2)
const HANDLE_LIFT := 0.06     # blade height going over the puck, above its top (m)

static func _stickhandle(p: AnimPuppet, dt: float, mem: Dictionary) -> void:
	var fwd := p.heading
	var right := p.right_vec()
	var gap := p.blade_gap()
	if not mem.has("side"):
		p.free_puck = true
		p.puck.position = fwd * HANDLE_OUT
		p.puck.vel = Vector3.ZERO
		mem.side = 1.0          # pushing the puck towards +right; blade on its left
		mem.over = false
		mem.bl = -gap - 0.06
		mem.bf = HANDLE_OUT
		mem.vb = 0.0
	var pf := p.puck.position.dot(fwd)
	var pl := p.puck.position.dot(right)
	var s: float = mem.side
	var bl: float = mem.bl
	var vb: float = mem.vb
	var h := 0.0
	if not mem.over:
		var sep := (pl - bl) * s                   # puck ahead of the blade
		var vp := p.puck.vel.dot(right) * s        # puck speed in the push direction
		if sep > gap + 0.015 and not mem.has("pushing"):
			# not touching yet: give with an incoming puck to catch it softly,
			# or go and meet one that has stopped
			# hold still for an incoming puck (the blade's give is the soft
			# bounce), go and meet one that has stopped
			var meet := s * minf(0.8, (sep - gap) * 8.0) if vp > -0.2 else 0.0
			vb = move_toward(vb, meet, HANDLE_ACCEL * dt)
		else:
			# push: speed up towards the far side with the puck in front, and
			# let it go once up to speed
			mem.pushing = true
			vb = move_toward(vb, s * HANDLE_SPEED, HANDLE_ACCEL * dt)
			if absf(vb - s * HANDLE_SPEED) < 0.01:
				mem.over = true
				mem.erase("pushing")
	else:
		# over the top: lift, pass over the sliding puck, set down beyond it
		# where it will arrive, and wait to catch it
		# land at the far side, or just beyond the puck if it is already past
		var vp := maxf(p.puck.vel.dot(right) * s, 0.0)
		var land := s * maxf(HANDLE_WIDE + gap, pl * s + gap + 0.08)
		var past := (bl - pl) * s > gap + 0.03
		var top := SkaterRig.puck_size.y
		h = top + HANDLE_LIFT if not past else 0.0
		var clear := p.blade_height > top + 0.01 or past
		var aim := land if clear else bl
		var want := clampf((aim - bl) * 18.0, -3.2, 3.2)
		vb = move_toward(vb, want if clear else s * HANDLE_SPEED * 0.7, 40.0 * dt)
		if past and p.blade_height < 0.03:
			mem.over = false
			mem.side = -s
	bl += vb * dt
	mem.bl = bl
	mem.vb = vb
	# the blade's middle follows the puck forward and back, and the wrists
	# angle the face so each push also steers the puck back towards its spot
	# out front (pushing a little back when it has run out too far)
	mem.bf = lerpf(mem.bf, pf, 1.0 - exp(-8.0 * dt))
	var face_s: float = -s if mem.over else s       # the face that meets the puck next
	var toe: Vector3 = p.rig.faller.global_basis * p.rig.toe_base
	var normal := Vector3(toe.z, 0.0, -toe.x) * face_s   # perpendicular to the toe, pointing the push way
	if normal.dot(right * face_s) < 0.0:
		normal = -normal
	var fwd_now := asin(clampf(normal.normalized().dot(fwd), -1.0, 1.0))
	var fwd_want := clampf((HANDLE_OUT - pf) * 1.5, -0.35, 0.35)
	var turn := clampf(face_s * (fwd_want - fwd_now), -0.35, 0.35)
	p.rig.blade_turn = lerpf(p.rig.blade_turn, turn, 1.0 - exp(-12.0 * dt))
	var b := Vector2(mem.bf, bl)
	p.blade_deg = rad_to_deg(atan2(b.y, b.x))
	p.blade_m = b.length()
	p.blade_h = h


## Puck on the blade with a little stickhandling until the move starts.
static func _carry(p: AnimPuppet, t: float, mem: Dictionary) -> void:
	if _once(mem, "puck", true):
		p.holding = true
	if p.holding:
		p.blade_deg = 12.0 + sin(t * TAU * 1.4) * 10.0
		p.blade_m = AnimPuppet.READY_BLADE.length()


## The blade out front after the release.
static func _finish(p: AnimPuppet, side: float) -> void:
	p.blade_deg = 7.0 * side
	p.blade_m = 1.27


static func _shoot(p: AnimPuppet, speed: float, lift := 2.5) -> void:
	p.game.stats.shots += 1
	p.release_puck(Vector3(speed, lift, 0.0))


## True the first time `cond` holds this loop.
static func _once(mem: Dictionary, key: String, cond: bool) -> bool:
	if cond and not mem.has(key):
		mem[key] = true
		return true
	return false


# ---------------------------------------------------------------- on foot

## Poses the on-foot puppet for time `t` into the loop.
static func run_person(id: StringName, q: AnimPerson, t: float, dt: float, mem: Dictionary) -> void:
	q.clear_intent()
	var r := q.rig
	match id:
		&"walk":
			q.go = Vector3.FORWARD * VenueWalker.WALK
		&"run":
			q.go = Vector3.FORWARD * VenueWalker.RUN
		&"walk_turn":
			var a := 0.0 if t < 1.0 else (t - 1.0) * 0.7
			q.go = Vector3.FORWARD.rotated(Vector3.UP, a) * VenueWalker.WALK
		&"idle":
			q.go = Vector3.ZERO
			r.look = r.to_global(Vector3(sin(t * 0.9) * 2.0, 1.4 + sin(t * 0.5) * 0.3, -2.0)) if t > 0.8 else PersonRig.NONE
		&"sit":
			q.bench.visible = true
			q.bench.global_position = r.to_global(Vector3(0.0, 0.225, 0.45))
			q.bench.global_basis = r.global_basis
			r.seat = r.to_global(Vector3(0.0, 0.45, 0.25))
			r.pose = PersonRig.Pose.SIT if t > 0.6 and t < 4.6 else PersonRig.Pose.STAND
		&"crouch_work":
			_panel(q, Vector3(0.0, 0.45, -0.5))
			r.pose = PersonRig.Pose.CROUCH if t > 0.4 and t < 4.4 else PersonRig.Pose.STAND
			if t > 1.0 and t < 4.0:
				# a valve wheel on the panel face, turned hand over hand
				var c := Vector3(0.0, 0.42, -0.48)
				var a := (t - 1.0) * 2.0
				q.show_wheel(c, 0.09, -a)
				r.reach[0] = r.to_global(c + Vector3(-cos(a), sin(a), 0.0) * 0.09)
				r.reach[1] = r.to_global(c + Vector3(cos(a), -sin(a), 0.0) * 0.09)
			r.look = r.to_global(Vector3(0.0, 0.42, -0.48)) if t > 0.6 and t < 4.2 else PersonRig.NONE
		&"kneel_work":
			_panel(q, Vector3(0.0, 0.45, -0.55))
			r.pose = PersonRig.Pose.KNEEL if t > 0.4 and t < 4.4 else PersonRig.Pose.STAND
			if t > 1.0 and t < 4.0:
				# a ratchet on a low bolt: short pulls
				var pull := absf(sin((t - 1.0) * 5.0)) * 0.06
				r.reach[1] = r.to_global(Vector3(0.12 + pull, 0.22, -0.53))
				r.reach[0] = r.to_global(Vector3(-0.1, 0.3, -0.53))
			r.look = r.to_global(Vector3(0.05, 0.22, -0.53)) if t > 0.6 and t < 4.2 else PersonRig.NONE
		&"reach_grab":
			var target := PersonRig.NONE
			var hand := 1
			if t > 0.4 and t < 1.9:
				target = Vector3(0.22, 1.75, -0.45)   # a valve overhead
			elif t > 2.2 and t < 3.5:
				target = Vector3(-0.3, 1.05, -0.4)    # a breaker at the hip
				hand = 0
			elif t > 3.8 and t < 5.5:
				target = Vector3(0.25, 0.55, -0.85)   # a lever low and out of reach
			if target != PersonRig.NONE:
				r.reach[hand] = r.to_global(target)
				r.look = r.reach[hand]
			else:
				r.look = PersonRig.NONE
		&"first_person":
			q.first_person = true
			_panel(q, Vector3(0.0, 0.7, -0.66), 1.55)
			var wheel := r.to_global(Vector3(0.0, 1.15, -0.62))
			r.look = wheel
			# a big handwheel turned in pulls: both hands grip at quarter to
			# three, turn it a third of a turn, let go and grip again
			var pulls := maxf(t - 1.6, 0.0) * 0.8
			var turn := (floorf(pulls) + smoothstep(0.0, 0.7, fmod(pulls, 1.0))) * 1.0
			q.show_wheel(Vector3(0.0, 1.15, -0.62), 0.17, -turn)
			if t > 1.6 and t < 5.4 and fmod(pulls, 1.0) < 0.8:
				var a := turn - floorf(pulls) - 0.5
				var c := r.to_local(wheel)
				q.arms.reach[0] = r.to_global(c + Vector3(-cos(a), sin(a), 0.0) * 0.17)
				q.arms.reach[1] = r.to_global(c + Vector3(cos(a), -sin(a), 0.0) * 0.17)


## Shows the machine panel standing on the floor with its front face
## centred at `at` (body space), `tall` times its usual 0.9 m height.
static func _panel(q: AnimPerson, at: Vector3, tall := 1.0) -> void:
	q.panel.visible = true
	q.panel.global_basis = q.rig.global_basis * Basis.from_scale(Vector3(1.0, tall, 1.0))
	q.panel.global_position = q.rig.to_global(at + Vector3(0.0, 0.0, -0.25))

