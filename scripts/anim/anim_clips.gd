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
	{"id": &"neutral", "title": "Ready stance", "groups": ["stance", "grip", "blade", "stick"], "len": 4.0,
		"note": "Standing still, knees bent, blade on the ice."},
	{"id": &"stickhandle", "title": "Stickhandling", "groups": ["grip", "stick"], "len": 4.0,
		"note": "Two hands, quick forehand-backhand moves in front of the body."},
	{"id": &"wide_reach", "title": "Wide reach", "groups": ["grip"], "len": 4.0,
		"note": "Past the front 90 degrees the bottom hand lets go; the top hand keeps the knob and swings the stick on a straight arm."},
	{"id": &"poke_check", "title": "Poke check", "groups": ["grip"], "len": 3.0,
		"note": "Stick jabbed straight out front: the bottom hand lets go for the extra reach."},
	{"id": &"stride_easy", "title": "Skating stride: easy", "groups": ["stance", "stride", "blade"], "len": 4.0,
		"note": "Striding at about 9 mph."},
	{"id": &"stride_full", "title": "Skating stride: full speed", "groups": ["stance", "stride", "blade"], "len": 4.0,
		"note": "Striding at about 22 mph."},
	{"id": &"dash", "title": "Dash", "groups": ["dash", "stride"], "len": 4.0,
		"note": "Burst strides from a cruise, twice per loop."},
	{"id": &"glide", "title": "Glide", "groups": ["stance", "blade"], "len": 3.0,
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
			p.holding = t > 0.2
			p.blade_deg = sin(t * TAU * 1.6) * 35.0
			p.blade_m = 0.8
		&"wide_reach":
			p.blade_deg = sin(t * TAU * 0.25) * 95.0
			p.blade_m = 1.0 + 0.4 * absf(sin(t * TAU * 0.25))
		&"poke_check":
			var jab := smoothstep(0.8, 1.0, t) * (1.0 - smoothstep(1.5, 1.9, t))
			p.blade_deg = 5.0
			p.blade_m = lerpf(0.9, 1.8, jab)
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


## Puck on the blade with a little stickhandling until the move starts.
static func _carry(p: AnimPuppet, t: float, mem: Dictionary) -> void:
	if _once(mem, "puck", true):
		p.holding = true
	if p.holding:
		p.blade_deg = 15.0 + sin(t * TAU * 1.4) * 12.0
		p.blade_m = 0.9


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
