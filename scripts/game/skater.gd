class_name Skater
extends Node3D
## A skater simulated as a point mass on edges:
##  * thrust only along the direction the skates point, so you carve turns
##  * lateral velocity bleeds off through edge grip (part of it is kept as
##    forward speed, the "carve"), turning gets wider the faster you go
##  * a dash is a burst stride up to top speed; the hockey stop scrapes
##    speed off sideways
##  * the stick blade swings around the body (angle + reach) at a limited
##    speed inside a 220 degree arc: two hands on the stick in the front 90
##    degrees, one hand beyond that (more reach, less control and power). The
##    puck follows it on a spring whose force is capped by the skater's grip
##    (see StickPuck), so turning or stickhandling harder than your skill
##    allows works the puck loose
##  * shots and stick moves are patterns traced with the right stick (the
##    catalog is Moves, recognised by controls' StickGestures, which sets
##    Controls.move_id); what each does on the ice is in MovePhysics
## Every number comes from `profile` (PhysicsProfile, built from `stats`), and
## Tuning.blend (0 sim .. 1 arcade) adds grip, turn rate, direct thrust and
## shot/pass assistance on top of the same model.

const RADIUS := 0.38
const MASS := 85.0
const REACH_MIN := 0.55
const REACH_MAX := 1.5                     # two hands on the stick
const REACH_ONE_HAND := 1.8                # one hand, arm out
const ARC_HALF := deg_to_rad(110.0)        # the blade's 220 degree arc
const TWO_HAND_HALF := PI / 4.0            # two hands in the front 90 degrees
const WIND_ANGLE := deg_to_rad(115.0)      # stick further back than this winds up a shot
const WIND_HOLD := 0.08                     # held back that long first, so a wide sweep isn't a wind-up
const DEFAULT_BLADE := Vector2(1.2, 0.35)  # (forward, right) relative to the body: a full-size stick's ready stance
const WIND_SPOT := Vector2(-0.15, 0.85)    # where a button wind-up draws the blade (forehand; y flips for the backhand)
const SLAP_MIN := 0.18                     # a lifted wind-up shorter than this is a wrist shot
const LIFT_HEIGHT := 0.22
const CROSS_HEIGHT := 0.07                 # the blade's hop over the puck when stickhandling
const CROSS_AWAY := 0.12                   # moving the blade this far away from the puck goes round it instead
const STICK_LIFTED_TIME := 0.55
const LIFT_REACH := 0.3      # m: your blade has to be this close under their shaft
const DASH_PUSH := 0.2       # s the dash's push lasts
const FLICK_WINDOW := 0.09   # a flick is measured over this much stick history
const FLICK_TRAVEL := 0.9    # forward stick travel inside the window that counts as a flick


## What a controller (human or AI) wants this frame. Input code fills this in;
## the simulation never reads devices directly.
class Controls:
	var move := Vector2.ZERO          ## world XZ, length <= 1 (left stick)
	var dash := false                 ## pressed this frame (L3)
	var stop := false                 ## held: hockey stop (R3)
	var stick := Vector2.ZERO         ## world XZ, length <= 1 (right stick); back = wind up
	var blade_target: Variant = null  ## world Vector3 (mouse); overrides `stick`
	var lift := false                 ## held: stick lift (LT)
	var tilt := 0.0                   ## 0..1 blade tilt, lofts shots and passes (RT)
	var shoot := false                ## held: button shot, release to fire
	var aim_point: Variant = null     ## world Vector3 or null to aim at the net
	var pass_pressed := false
	var pass_dir := Vector2.ZERO
	var pass_hint: Variant = null     ## Skater the AI wants to pass to
	var check := false                ## pressed this frame: shoulder check
	var turn_around := false          ## pressed this frame: pivot, skate backwards / forwards again
	var move_id := &""                ## a recognised stick move to start (Moves catalog id)

	func reset() -> void:
		move = Vector2.ZERO
		dash = false
		stop = false
		stick = Vector2.ZERO
		blade_target = null
		lift = false
		tilt = 0.0
		shoot = false
		aim_point = null
		pass_pressed = false
		pass_dir = Vector2.ZERO
		pass_hint = null
		check = false
		turn_around = false
		move_id = &""


var game: Node
var puck: Puck
var team := 0
var number := 0
var ctrl := Controls.new()
## Ratings (career/skills.gd, 1..100). Injuries and fatigue arrive as
## Skills.modifiers, so the profile is re-derived every frame.
var skills: Skills
var player: PlayerProfile  # career player on this body right now, or null
var profile := PhysicsProfile.new()

var vel := Vector3.ZERO
var heading := Vector3(1, 0, 0)
var yaw_rate := 0.0
var turn_load := 0.0   ## m/s^2 of sideways load from turning, hurts balance
var braking := false
## Skating backwards (the turn-around toggle): the skater faces away from
## where the left stick points and pushes with backward C-cuts, slower than
## forwards. Physics, for now, from the Controls thread.
var backwards := false
## The human on keyboard + mouse: shots come from traced patterns
## (shoot_traced), not from stick motion, and there are no stick moves.
var traced_shots := false
## Stickhandling rhythm (traced_shots only): how fast the blade is being
## swept side to side against what the stickhandling rating allows; over 1
## the puck starts getting away (handle_rate() for the gauge).
var handle_load := 0.0
var _handle_prev := 0.0
var _handle_from := 0.0           # blade side (m) at the last reversal
var _handle_short := 0.0          # 0..1: how much too short the last handle was
var _handle_hands := 0.0
const BACK_SPEED := 0.72     # top speed backwards, of forwards
const BACK_ACCEL := 0.65     # stride push backwards, of forwards
const PIVOT_TIME := 0.32     # s a turn-around takes
var _pivot := 0.0            # s left in a turn-around
var _pivot_face := Vector3.ZERO
var stamina := 1.0
var stun_timer := 0.0
var check_timer := 0.0
var check_cd := 0.0
var dash_cd := 0.0
var dash_timer := 0.0

var blade_local := DEFAULT_BLADE
var blade_pos := Vector3.ZERO
var blade_vel := Vector3.ZERO
var blade_lvel := Vector2.ZERO  ## blade velocity relative to the body (forward, right)
var blade_ang := atan2(DEFAULT_BLADE.y, DEFAULT_BLADE.x)  ## radians from straight ahead, + = right
var blade_reach := DEFAULT_BLADE.length()
var _blade_pvel := Vector2.ZERO  # (tangential, radial) blade speed in m/s
var _lunge := 0.0               # extra reach from leaning out for a loose puck
var _shot_hand := 0.0            # one_hand() when the current shot was released
## The stick move being performed (Moves catalog id), or &"".
var move_id := &""
var move_time := 0.0             ## seconds along the move's path (at a 50 stickhandler's pace)
var _move_fired := false
## The kind of shot being wound up or just taken (Moves catalog id): a
## wind-up gives &"quick_shot", &"wrist_shot", &"backhand" or &"slapshot";
## a move's shot is the move's id.
var shot_kind := &"wrist_shot"
var _move_from := DEFAULT_BLADE
var _wind_side := 1.0            # +1 forehand wind-up, -1 backhand
var blade_height := 0.0
var lifting := false            ## own blade held up over the puck
var stick_lifted_timer := 0.0   ## an opponent lifted this stick
## Stick condition (StickWear): 1 new .. 0 worn out. Durability comes from the
## stick model (equipment), 1 = a standard stick.
var stick_health := 1.0
var stick_durability := 1.0
var stick_id := &""             ## the shop item, when the career gave one (Mechanics sets it)
var stick_broken := false       ## playing without a stick until the bench hands over a new one
var bench_wait := 0.0
var changing := false           ## called off in a line change: heading for the bench door (Game._change_lines)
var lift_cd := 0.0
var regrab_timer := 0.0         ## grace after a deke to set the blade back on the puck
## Which face of the blade the puck is on (+1 forehand side, -1 backhand, 0
## unknown); StickPuck keeps it up to date.
var puck_side := 0.0
var blade_from := Vector3.ZERO  ## the blade at the start of this frame (StickPuck sweeps it to blade_pos)
var crossing := false           ## lifting the blade over the puck to the other side
## How far the blade is turned from pointing straight out from the body
## (radians, + toward the forehand). It turns to face a puck coming in.
var blade_yaw := 0.0
var _dash_dir := Vector3.FORWARD
var _check_push := 0.0           # m/s^2 while driving into a check
var _clock := 0.0               # seconds this body has been simulated (hand_shake)
var _blade_heading := Vector3.ZERO  ## heading when the blade last moved
var puck_slip := 0.0            ## seconds the puck spent at the grip limit (for tuning)

# shot wind-up: started by drawing the stick back or holding `shoot`
var winding := false
var wind_time := 0.0
var wind_slap := false

# AI scratch state
var ai_decide := 0.0
var ai_shoot_timer := 0.0
var ai_aim: Variant = null
var ai_slap := false
var ai_tilt := 0.0
## who the AI thinks has the puck; it catches up with a change after the
## tier's reaction delay (ai_react counts down, -1 when not waiting)
var ai_owner: Skater = null
var ai_react := -1.0
## The phase of play this skater has read (TeamSystem.Phase, -1 not yet)
## and how long until a change of phase sinks in (tier anticipation).
var ai_phase := -1
var ai_phase_lag := -1.0
var ai_on_puck := false  # the one whose job right now is the puck (F1, the loose-puck chaser)

var rig: SkaterRig
var _prev_shoot := false
var _prev_lift := false
var _stick_wound := false
var _wind_grace := 0.0
var _stick_hist: Array[Vector3] = []  # (x, z, age) of recent right-stick input, for flicks
var _drawn_time := 0.0
var _anchor_local := DEFAULT_BLADE
var _spray: CPUParticles3D


func setup(g: Node, t: int, idx: int, pal: Dictionary, sk: Skills = null) -> void:
	game = g
	puck = g.puck
	team = t
	number = idx
	if sk == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = randi()
		sk = Skills.create(Skills.SKATER_KEYS, 50.0, 6.0, rng)
	set_skills(sk)
	if pal.is_empty():
		return
	rig = SkaterRig.new()
	add_child(rig)
	rig.build(pal, false)
	_spray = _make_spray()
	add_child(_spray)


## Swaps in a player's ratings (line changes call this on a live body).
func set_skills(sk: Skills) -> void:
	skills = sk
	profile.apply(skills)


## Puts a career player on this body (line changes swap who is out there).
func apply_player(p: PlayerProfile) -> void:
	player = p
	number = p.number
	set_skills(p.skills)


## A rating as 0..1 (canonical Skills keys only).
func skill(key: String) -> float:
	if not key in Skills.SKATER_KEYS:
		push_error("unknown skill '%s'" % key)
		return 0.5
	return skills.n(key)


func place(p: Vector2, facing: Vector3) -> void:
	position = Vector3(p.x, 0, p.y)
	vel = Vector3.ZERO
	heading = facing.normalized()
	backwards = false
	_pivot = 0.0
	_set_blade(DEFAULT_BLADE)
	blade_pos = _blade_world(blade_local)
	blade_from = blade_pos
	blade_vel = Vector3.ZERO
	blade_yaw = 0.0
	_blade_heading = heading
	puck_side = 0.0
	crossing = false
	blade_lvel = Vector2.ZERO
	stun_timer = 0.0
	stick_lifted_timer = 0.0
	# a stoppage is time enough to grab a new stick from the bench
	if stick_broken:
		StickWear.fresh(self)
		game.on_new_stick(self)
	cancel_shot()
	_apply_transform()


func has_puck() -> bool:
	return puck.controller == self


func right_vec() -> Vector3:
	return heading.cross(Vector3.UP)


func speed() -> float:
	return Vector2(vel.x, vel.z).length()


func cancel_shot() -> void:
	ctrl.shoot = false
	_prev_shoot = false
	_stick_wound = false
	winding = false
	wind_time = 0.0
	cancel_move()


## 0..1 visual wind-up for the rig and HUD.
func windup() -> float:
	if not winding:
		return 0.0
	return profile.charge(wind_time)


## True while the blade can touch the puck.
func blade_down() -> bool:
	return stun_timer <= 0.0 and stick_lifted_timer <= 0.0 and not lifting and not (winding and wind_slap) \
		and not stick_broken


## Where the puck is pulled to while carried. During a slapshot wind-up the
## blade lifts away, so the puck stays where the wind-up started; a cradling
## move (lacrosse) carries it up on the blade.
func puck_anchor() -> Vector3:
	if MovePhysics.glued(move_id):
		return blade_pos + Vector3.UP * (blade_height + 0.03)
	if winding and wind_slap:
		return _blade_world(_anchor_local)
	# against the face of the blade, on the side it's on (forehand if unknown)
	var n: Vector2 = StickPuck.blade_at(self, 1.0)[2] * (puck_side if puck_side != 0.0 else 1.0)
	return Vector3(blade_pos.x + n.x * StickPuck.gap(), 0, blade_pos.z + n.y * StickPuck.gap())


## Off their feet: the stick comes off the puck (StickPuck lets go of it)
## and they slide where the hit sent them.
func knock_down() -> void:
	stun_timer = 1.3
	cancel_shot()
	StickWear.stress(self, 0.4, &"check")


func physics_update(dt: float) -> void:
	_clock += dt
	var blend: float = Tuning.blend
	stun_timer = maxf(0.0, stun_timer - dt)
	check_timer = maxf(0.0, check_timer - dt)
	check_cd = maxf(0.0, check_cd - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	dash_timer = maxf(0.0, dash_timer - dt)
	lift_cd = maxf(0.0, lift_cd - dt)
	stick_lifted_timer = maxf(0.0, stick_lifted_timer - dt)
	if stick_broken:
		if winding or move_id != &"":
			cancel_shot()
		StickWear.update(self, dt)
	profile.apply(skills)
	var p := profile
	var frozen: bool = game.is_frozen()
	var able := stun_timer <= 0.0 and not frozen
	var mv := ctrl.move if able else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	var amount := mv.length()
	var desired := Vector3(mv.x, 0, mv.y).normalized() if amount > 0.01 else heading
	var spd := speed()
	var top := p.max_speed * lerpf(0.9, 1.0, stamina)
	braking = ctrl.stop and able and spd > 0.6
	var prev_heading := heading

	# turning around: a quick pivot to face the other way, then skating
	# backwards (or forwards again)
	if ctrl.turn_around and able and _pivot <= 0.0:
		backwards = not backwards
		_pivot = PIVOT_TIME
		_pivot_face = -heading
	_pivot = maxf(0.0, _pivot - dt)
	# the way the skater pushes: forwards along the heading, backwards away from it
	var push := -heading if backwards else heading
	if backwards:
		top *= BACK_SPEED

	# steering: tight at low speed, wide arcs at full speed
	if amount > 0.15 or _pivot > 0.0:
		var turn := lerpf(p.turn_slow, p.turn_fast, clampf(spd / p.max_speed, 0.0, 1.0)) * (1.0 + 0.5 * blend)
		if braking:
			turn *= 0.4
		var face := desired
		if backwards:
			face = -desired
		if _pivot > 0.0:
			if amount <= 0.15:
				face = _pivot_face
			turn = maxf(turn, PI / PIVOT_TIME)
		heading = _rotate_toward(heading, face, turn * dt)
		push = -heading if backwards else heading

	# stride thrust along the blades, plus arcade direct thrust
	if amount > 0.15 and not braking:
		var align := maxf(0.0, push.dot(desired))
		# strides stay strong until you're close to top speed
		var room := sqrt(clampf(1.0 - vel.dot(push) / top, 0.0, 1.0))
		var accel := p.accel * (BACK_ACCEL if backwards else 1.0)
		vel += push * accel * align * amount * room * dt
		var room_direct := clampf(1.0 - vel.dot(desired) / top, 0.0, 1.0)
		vel += desired * p.accel * 0.35 * blend * amount * room_direct * dt

	# dash: a few hard strides toward the stick, a push over DASH_PUSH seconds
	# up to (never past) top speed
	if ctrl.dash and able and dash_cd <= 0.0 and stamina > 0.15 and not braking:
		_dash_dir = desired if amount > 0.2 else heading
		dash_cd = p.dash_cooldown
		dash_timer = 0.45
		stamina -= 0.16
	if dash_timer > 0.45 - DASH_PUSH and able:
		var gain := clampf(top - vel.dot(_dash_dir), 0.0, p.dash_boost / DASH_PUSH * dt)
		vel += _dash_dir * gain
	if check_timer > 0.0 and able:
		# driving into a check (strides, so no faster than top speed)
		vel += heading * clampf(top - vel.dot(heading), 0.0, _check_push * dt)

	# edges: sideways slide decays, most of it is carved into forward speed
	var fwd := vel.dot(heading)
	var lat := vel - heading * fwd
	lat.y = 0.0
	var grip := 0.8 if braking else p.edge_grip * lerpf(1.0, 1.8, blend)
	var lat_new := lat * exp(-grip * dt)
	if fwd > 0.3:
		# carving keeps speed through a turn but never adds speed past top
		fwd = minf(fwd + (lat.length() - lat_new.length()) * 0.6, maxf(fwd, top))
	vel = heading * fwd + lat_new

	if braking:
		var s := vel.length()
		vel *= maxf(0.0, s - p.stop_decel * dt) / s
	var s2 := vel.length()
	if s2 > 0.0:
		var coast := 0.0 if amount > 0.15 else 0.6 * blend
		var drag := 0.2 + 0.03 * s2 + coast
		vel *= maxf(0.0, s2 - drag * dt) / s2
	# strides fade out as you near top speed and drag grows with it, so
	# max_speed is where they balance; 25 mph is the hard ceiling for anyone
	# (only hits push a skater past it)
	if stun_timer <= 0.0:
		vel = vel.limit_length(PhysicsProfile.CEILING)

	stamina = minf(1.0, stamina + 0.1 * dt)

	position += vel * dt
	position.y = 0.0
	var r := Rink.confine(position, RADIUS)
	var n: Vector2 = r[1]
	if n != Vector2.ZERO:
		position = r[0]
		var n3 := Vector3(n.x, 0, n.y)
		var vn := vel.dot(n3)
		if vn > 0.0:
			vel -= n3 * vn * 1.3
	var p2 := Rink.push_out_of_nets(Vector2(position.x, position.z), RADIUS)
	position = Vector3(p2.x, 0, p2.y)

	yaw_rate = prev_heading.signed_angle_to(heading, Vector3.UP) / dt
	turn_load = absf(yaw_rate) * speed()
	_update_blade(dt, blend)
	_handle_actions(dt)
	_apply_transform()
	if _spray:
		_spray.emitting = braking and spd > 2.0
	if rig:
		rig.update_skater(self, dt)


## Balance against hits: 1.0 when set, lower while carving hard or stopping.
## Agile skaters lose less of it.
func stability() -> float:
	var agi := skill("agility")
	var load := clampf(turn_load / 30.0, 0.0, 1.0) * lerpf(0.3, 0.1, agi)
	return (1.0 - load) * (0.85 if braking else 1.0) * (0.8 if dash_timer > 0.0 else 1.0)


# ---------------------------------------------------------------- stick

func _stick_local(world: Vector2) -> Vector2:
	var w := Vector3(world.x, 0, world.y)
	return Vector2(w.dot(heading), w.dot(right_vec()))


## True when the right stick points behind the skater (drawing back to shoot).
func _stick_drawn() -> bool:
	if ctrl.stick.length() < 0.5:
		return false
	var l := _stick_local(ctrl.stick)
	return absf(atan2(l.y, l.x)) > WIND_ANGLE


## A loose puck within reach: the blade goes for it on its own, as a
## player's would, when the right stick is left alone or already points
## roughly that way. Better hands reach further for it and read where it's
## sliding. Returns the blade target (body frame) or null.
func _loose_puck_reach(stick_target: Vector2, blend: float) -> Variant:
	if puck == null or puck.controller != null or puck.frozen or puck.position.y > 0.3 \
			or winding or move_id != &"" or lifting or not blade_down() or not puck.can_be_touched_by(self):
		return null
	var sh := skill("stick_handling")
	# go to the near edge of the puck, not through it, so the blade arrives
	# soft
	var d := _puck_edge() - position
	# a puck still coming (or being skated onto): get the blade into its path
	# by the time it arrives
	var rel_v := puck.vel - vel
	rel_v.y = 0.0
	var dist := Vector2(d.x, d.z).length()
	var closing := -Vector2(d.x, d.z).normalized().dot(Vector2(rel_v.x, rel_v.z)) if dist > 0.01 else 0.0
	if closing > 0.3 and dist > DEFAULT_BLADE.length():
		d += rel_v * clampf((dist - DEFAULT_BLADE.length()) / closing, 0.0, lerpf(0.3, 0.6, sh))
	var local := Vector2(d.dot(heading), d.dot(right_vec()))
	var ang := atan2(local.y, local.x)
	var reach := local.length()
	if absf(ang) > ARC_HALF or reach > reach_limit(ang) + lunge() + lerpf(0.05, 0.3, sh) * lerpf(0.6, 1.4, blend):
		return null
	# a puck sliding in too hot to handle isn't one you'd lunge at
	if (puck.vel - vel).length() > 20.0:
		return null
	if ctrl.stick.length() > 0.2 and absf(wrapf(atan2(stick_target.y, stick_target.x) - ang, -PI, PI)) > deg_to_rad(60.0):
		return null
	# the hands only put the blade so close to where it'll arrive
	return local + Vector2(0.0, hand_shake().y * 0.5 * profile.receive_error)


## Turning the blade to receive: a loose puck coming in gets the face, not
## the toe. 0 (blade straight out) otherwise.
func _receive_yaw() -> float:
	if puck == null or puck.controller != null or puck.frozen or puck.position.y > 0.3 or stun_timer > 0.0:
		return 0.0
	var u := Vector2(puck.vel.x - vel.x, puck.vel.z - vel.z)
	var to := Vector2(blade_pos.x - puck.position.x, blade_pos.z - puck.position.z)
	if u.length() < 2.0 or to.length() > 4.0 or u.dot(to) <= 0.0:
		return 0.0
	var radial := Vector2(blade_pos.x - position.x, blade_pos.z - position.z).normalized()
	var face := Vector2(-radial.y, radial.x)
	return clampf(wrapf(face.angle_to(-u), -PI / 2.0, PI / 2.0), -1.0, 1.0)


## The side of the puck nearest the blade, where the blade's face touches it.
func _puck_edge() -> Vector3:
	var n: Vector2 = StickPuck.blade_at(self, 1.0)[2]
	var pp := Vector2(puck.position.x, puck.position.z)
	var side := signf((pp - Vector2(blade_pos.x, blade_pos.z)).dot(n))
	var edge := pp - n * side * StickPuck.gap()
	return Vector3(edge.x, 0, edge.y)


## True when the stick is asking the blade to move away from the puck it's
## carrying (sideways, across the face), which means going round it.
func _wants_round(target: Vector2) -> bool:
	if puck_side == 0.0:
		return false
	var n: Vector2 = StickPuck.blade_at(self, 1.0)[2]
	var tw := _blade_world(target)
	var away := (Vector2(tw.x, tw.z) - Vector2(blade_pos.x, blade_pos.z)).dot(n) * puck_side
	if crossing:
		return away < 0.0
	# not while the puck is still running off the last push: catch it first
	var running := Vector2(puck.vel.x - vel.x, puck.vel.z - vel.z).dot(n) * puck_side
	return away < -CROSS_AWAY and running < 1.2


## Whether this skater has learned a move (Moves catalog id).
## (mechanics hook) A career player's PlayerProfile.moves decides, in career
## games and in practice with a career loaded; otherwise (exhibitions, tests)
## everyone knows everything.
func knows(id: StringName) -> bool:
	if player == null or game == null:
		return true
	if game.get("career_mode") or (game.get("practice") and game.get("user_profile") == player):
		return player.knows_move(id)
	return true


func _update_blade(dt: float, blend: float) -> void:
	if has_puck() and blade_down() and move_id == &"" and _blade_heading != Vector3.ZERO:
		# carrying through a turn, the hands hold the blade with the puck and
		# bring it round after the body rather than whipping it into the puck
		var local_turn := Vector2(_blade_heading.dot(heading), _blade_heading.dot(right_vec())).angle()
		blade_ang = clampf(blade_ang + local_turn, -ARC_HALF, ARC_HALF)
	_blade_heading = heading
	var target := DEFAULT_BLADE
	var able := stun_timer <= 0.0
	if able and ctrl.blade_target != null:
		var bt: Vector3 = ctrl.blade_target
		if puck and puck.controller == null and Vector2(bt.x - puck.position.x, bt.z - puck.position.z).length() < 0.25:
			# reaching for a loose puck: to its near edge, so the blade arrives soft
			bt = _puck_edge()
		var d: Vector3 = bt - position
		target = Vector2(d.dot(heading), d.dot(right_vec()))
	elif able and ctrl.stick.length() > 0.2:
		var l := _stick_local(ctrl.stick)
		var mag := minf(l.length(), 1.0)
		# the stick's travel is the two-handed reach the body has that way;
		# reaching further (a poke, a loose puck) takes a hand off
		var a := atan2(l.y, l.x)
		target = Vector2(cos(a), sin(a)) * lerpf(REACH_MIN, two_hand_reach(a), mag)
	var lunge_to := 0.0
	if able:
		var reach_for: Variant = _loose_puck_reach(target, blend)
		if reach_for != null:
			target = reach_for
			lunge_to = lunge()
	# leaning out comes and goes with the body, not instantly
	_lunge = move_toward(_lunge, lunge_to, LUNGE.y * 4.0 * dt)
	# stickhandling: to move the puck back the other way you go round it,
	# lifting the blade over and setting it down on the far side
	crossing = able and has_puck() and move_id == &"" and not winding and _wants_round(target)
	if crossing:
		var n: Vector2 = StickPuck.blade_at(self, 1.0)[2]
		var far := Vector2(puck.position.x, puck.position.z) + n * puck_side * (StickPuck.gap() + 0.03)
		var d := Vector3(far.x, 0, far.y) - position
		# lift first, then swing over
		target = Vector2(d.dot(heading), d.dot(right_vec())) if blade_height > StickPuck.BLADE_CLEAR else blade_local
	if winding and not _stick_wound:
		target = Vector2(WIND_SPOT.x, WIND_SPOT.y * _wind_side)
	var move_h := 0.0
	if move_id != &"":
		var k := MovePhysics.sample(move_id, move_time, _move_from)
		target = Vector2(cos(k[0]), sin(k[0])) * k[1]
		move_h = k[2]
	# keep it inside the 220 degree arc; one hand reaches further
	var ang := clampf(atan2(target.y, target.x), -ARC_HALF, ARC_HALF)
	var reach := clampf(target.length(), REACH_MIN, reach_limit(ang) + _lunge)
	# the blade swings around the body (it never cuts through it) with limited
	# speed and acceleration; one hand makes it harder to whip around
	var oh := one_hand()
	var tan_err := wrapf(ang - blade_ang, -PI, PI) * blade_reach
	var want := Vector2(tan_err, reach - blade_reach) * profile.blade_response
	want = want.limit_length(profile.blade_speed * lerpf(1.0, 1.25, blend))
	var acc := profile.blade_accel * lerpf(1.0, 1.25, blend) * lerpf(1.0, 0.8, oh)
	if has_puck() and blade_down():
		# carrying, you move the stick about as sharply as your hands can hold
		# the puck: weak hands stickhandle slower rather than throwing it away.
		# It still comes loose when you turn harder than that, or when the
		# grip drops as the bottom hand lets go mid-swing.
		var oh_to := _one_hand_at(ang, reach)
		# stickhandling, the hands are already stretched over the outer
		# quarter of the two-hand reach: ease toward the one-hand cap before
		# the grip changes (moves and a cupped, tilted blade keep their own)
		if move_id == &"" and absf(ctrl.tilt) < 0.1:
			var two := two_hand_reach(ang)
			oh_to = maxf(oh_to, EDGE_HANDS * smoothstep(two * 0.75, two, maxf(reach, blade_reach)))
		# a cradled puck (lacrosse) needs the gentlest hands
		if MovePhysics.glued(move_id):
			oh_to = 1.0
		acc = minf(acc, profile.puck_grip * lerpf(1.0, 0.7, maxf(oh, oh_to)) * 0.9)
	# brake in time to stop on the target instead of swinging past it
	want.x = signf(want.x) * minf(absf(want.x), sqrt(2.0 * acc * absf(tan_err)))
	want.y = signf(want.y) * minf(absf(want.y), sqrt(2.0 * acc * absf(reach - blade_reach)))
	_blade_pvel = _blade_pvel.move_toward(want, acc * dt)
	blade_ang = clampf(blade_ang + _blade_pvel.x / maxf(blade_reach, 0.3) * dt, -ARC_HALF, ARC_HALF)
	blade_reach = clampf(blade_reach + _blade_pvel.y * dt, REACH_MIN, reach_limit(blade_ang) + _lunge)
	var prev_local := blade_local
	blade_local = Vector2(cos(blade_ang), sin(blade_ang)) * blade_reach
	blade_lvel = (blade_local - prev_local) / dt
	var was_lifting := lifting
	# (during a move its own path lifts the blade; the button only picked the move)
	lifting = (ctrl.lift and able and not winding and move_id == &"") or move_h > 0.05
	regrab_timer = 0.3 if (was_lifting and not lifting) else maxf(0.0, regrab_timer - dt)
	var h := 0.0
	if stick_lifted_timer > 0.0:
		h = 0.35
	elif winding and wind_slap:
		h = 0.9 * windup() + 0.2
	elif move_h > 0.05:
		h = move_h
	elif lifting:
		h = LIFT_HEIGHT
	elif crossing:
		h = CROSS_HEIGHT
	blade_yaw = move_toward(blade_yaw, _receive_yaw(), lerpf(5.0, 10.0, skill("stick_handling")) * dt)
	blade_height = lerpf(blade_height, h, minf(1.0, 45.0 * dt))
	var prev := blade_pos
	blade_from = prev
	blade_pos = _blade_world(blade_local)
	blade_vel = (blade_pos - prev) / dt


# ---------------------------------------------------------------- actions

func _handle_actions(dt: float) -> void:
	var able: bool = stun_timer <= 0.0 and not game.is_frozen() and stick_lifted_timer <= 0.0 and not stick_broken
	if traced_shots:
		_stickhandle_rhythm(dt, able)
	elif ctrl.move_id != &"" and move_id == &"" and able:
		start_move(ctrl.move_id)
	if traced_shots:
		pass
	elif move_id != &"":
		_run_move(dt, able)
	else:
		_handle_shot_input(dt, able)
	var lift_pressed := ctrl.lift and not _prev_lift
	_prev_lift = ctrl.lift
	if lift_pressed and able and not has_puck() and lift_cd <= 0.0:
		_try_stick_lift()
	if ctrl.pass_pressed and has_puck() and able:
		pass_puck()
	if ctrl.check and check_cd <= 0.0 and stun_timer <= 0.0:
		check_timer = 0.35
		check_cd = 1.2
		game.stats.checks += 1
		_check_push = lerpf(1.5, 3.0, skill("hitting")) / 0.35


## Starts a stick move. Returns false when it can't be done now (no path for
## it, not learned, already busy, or it needs the puck and you don't have it).
func start_move(id: StringName) -> bool:
	if not MovePhysics.has_move(id) or move_id != &"" or winding or not knows(id):
		return false
	if MovePhysics.MOVES[id].get("needs_puck", false) and not has_puck():
		return false
	move_id = id
	move_time = 0.0
	_move_fired = false
	_move_from = blade_local
	return true


func cancel_move() -> void:
	move_id = &""
	move_time = 0.0


func _run_move(dt: float, able: bool) -> void:
	if not able or not has_puck():
		cancel_move()
		return
	move_time += dt / MovePhysics.time_scale(self)
	var spec: Dictionary = MovePhysics.MOVES[move_id]
	var dur := MovePhysics.duration(move_id)
	var shot: Dictionary = spec.get("shot", {})
	if not shot.is_empty() and not _move_fired and move_time >= shot["release"]:
		# the move's own shot: as strong as a wrist shot of `wind`, with its
		# own power, error and loft, and both hands on the stick
		_move_fired = true
		shot_kind = move_id
		_shot_hand = 0.0
		shoot(shot["wind"], false, 0.0, shot)
		return
	if spec.has("cradle"):
		# cradled on the blade: push the stick forward to throw it, or let go
		# of the tilt (or hold it too long) and it drops back to the ice
		if move_time < dur:
			return
		var l := _stick_local(ctrl.stick)
		if ctrl.stick.length() > 0.6 and l.x > 0.5:
			shot_kind = move_id
			cancel_move()
			wind_time = spec["cradle"]["wind"]
			_fire()
		elif move_time > dur + spec["cradle"]["hold"] or ctrl.tilt < 0.2:
			cancel_move()
		return
	if move_time >= dur:
		cancel_move()


## Two ways to shoot, both through the same wind-up:
##  * stick: pull the right stick back (wind-up), then push it forward
##  * button: hold `shoot` to wind up, release to fire
## Holding lift when the wind-up starts makes it a slapshot.
func _handle_shot_input(dt: float, able: bool) -> void:
	if not able:
		if winding:
			cancel_shot()
		_prev_shoot = ctrl.shoot
		return
	if _flicked(dt):
		shot_kind = &"quick_shot"
		_fire()
		return
	var back := _stick_drawn()
	_drawn_time = _drawn_time + dt if back else 0.0
	var drawn := back and _drawn_time >= WIND_HOLD
	var held := ctrl.shoot
	# with LT held the slapshot starts as soon as the stick heads back on the
	# forehand, so the lifted blade doesn't leave the puck behind
	var sl := _stick_local(ctrl.stick)
	var slap_draw := ctrl.lift and has_puck() and knows(&"slapshot") and ctrl.stick.length() > 0.5 \
		and rad_to_deg(atan2(sl.y, sl.x)) > 60.0
	drawn = drawn or slap_draw
	if not winding and ((held and not _prev_shoot) or drawn):
		winding = true
		wind_time = 0.0
		_wind_side = -1.0 if drawn and sl.y < 0.0 else 1.0
		# the slapshot is a learned move; without it a lifted wind-up is a wrist shot
		wind_slap = ctrl.lift and _wind_side > 0.0 and knows(&"slapshot") and (has_puck() or knows(&"one_timer"))
		shot_kind = &"slapshot" if wind_slap else (&"backhand" if _wind_side < 0.0 else &"wrist_shot")
		_stick_wound = drawn and not held
		_wind_grace = 0.0
		# the puck waits where it is while the blade goes back
		var pd := puck.position - position
		_anchor_local = Vector2(pd.dot(heading), pd.dot(right_vec())) if has_puck() else blade_local
	_prev_shoot = held
	if not winding:
		return
	wind_time += dt
	if _stick_wound:
		if back:
			_wind_grace = 0.0
			return
		var l := _stick_local(ctrl.stick)
		if ctrl.stick.length() > 0.5 and l.x > 0.0:
			_fire()
			return
		_wind_grace += dt
		if _wind_grace > 0.25:
			cancel_shot()
	elif not held:
		_fire()


## A quick forward flick of the right stick from neutral, with no wind-up,
## fires the instant shot (weak and wild until shot release improves).
func _flicked(dt: float) -> bool:
	for i in _stick_hist.size():
		_stick_hist[i].z += dt
	_stick_hist.append(Vector3(ctrl.stick.x, ctrl.stick.y, 0.0))
	while _stick_hist.size() > 2 and _stick_hist[1].z >= FLICK_WINDOW:
		_stick_hist.pop_front()
	if winding or ctrl.stick.length() < 0.8 or not has_puck():
		return false
	# from (near) neutral: a sweep round the rim of the stick is stickhandling
	if Vector2(_stick_hist[0].x, _stick_hist[0].y).length() > 0.4:
		return false
	var l := _stick_local(ctrl.stick)
	if l.x < 0.5:
		return false
	var travel := _stick_local(ctrl.stick - Vector2(_stick_hist[0].x, _stick_hist[0].y)).x
	if travel < FLICK_TRAVEL:
		return false
	_stick_hist.clear()
	return true


func _fire() -> void:
	var held := wind_time
	var slap := wind_slap and held >= SLAP_MIN
	if shot_kind == &"slapshot" and not slap:
		shot_kind = &"wrist_shot"
	elif shot_kind == &"slapshot" and not has_puck():
		shot_kind = &"one_timer"
	# a wound-up shot comes through with both hands; a flick can be one-handed.
	# A lacrosse throw is its own technique (MovePhysics.SHOTS).
	_shot_hand = 0.0 if MovePhysics.SHOTS.get(shot_kind, {}).has("wind") else one_hand()
	winding = false
	_stick_wound = false
	wind_time = 0.0
	# the blade follows through
	var side := -1.0 if shot_kind == &"backhand" else 1.0
	_set_blade(Vector2(REACH_MAX * 0.85, 0.15 * side))
	if rig:
		rig.follow_through(held * 1.5 + (0.4 if slap else 0.0), side)
	if has_puck():
		shoot(held, slap)
		return
	# one-timer / snapshot at a loose puck near the blade
	# the swing only meets a puck that's at the blade
	var d := Vector2(puck.position.x - blade_pos.x, puck.position.z - blade_pos.z).length()
	if puck.controller == null and not puck.frozen and puck.position.y < StickPuck.BLADE_TOP * 2.0 \
			and d < StickPuck.BLADE_HALF + StickPuck.SWEEP * 2.0 and puck.can_be_touched_by(self):
		shoot(held, slap, puck.horizontal_speed())


## The quickest side-to-side the stickhandling rating handles cleanly, in
## blade metres per second: wide slow sweeps for a beginner, quick small
## handles for the best.
func handle_limit() -> float:
	return lerpf(2.5, 9.0, skill("stick_handling"))


## Tracks how hard the blade is being swept across the puck. Small handles
## count for more than their speed at a low rating (the puck needs a wide
## sweep to follow), and past the limit the puck can squirt away.
func _stickhandle_rhythm(dt: float, able: bool) -> void:
	# the hands' side-to-side (where the stick is being pushed, m/s across
	# the body), not the blade, which lags behind them
	var hands := ctrl.stick.dot(Vector2(right_vec().x, right_vec().z)) * REACH_MAX
	var side := (hands - _handle_hands) / maxf(dt, 0.001)
	_handle_hands = hands
	# a reversal: short handles are hard for a weak stickhandler
	if signf(side) != signf(_handle_prev) and absf(_handle_prev) > 0.3:
		var need := lerpf(0.9, 0.25, skill("stick_handling"))
		var width := absf(hands - _handle_from)
		_handle_short = maxf(_handle_short, (need - width) / need)
		_handle_from = hands
	_handle_prev = side
	_handle_short = maxf(0.0, _handle_short - 2.0 * dt)
	var rate := absf(side) * (1.0 + _handle_short)
	var target := rate / handle_limit() if has_puck() else 0.0
	handle_load = lerpf(handle_load, target, 1.0 - exp(-8.0 * dt))
	if able and has_puck() and handle_load > 1.0 and randf() < (handle_load - 1.0) * 4.0 * dt:
		# it got away from the blade
		var away := Vector3(blade_vel.x, 0, blade_vel.z) * 0.6 + heading * 1.0
		puck.release(self, away)
		puck.ignore_briefly(self, 0.3)
		handle_load = 0.6


## A traced shot (ShotPatterns): `kind` the pattern, `speed` m/s off the
## blade, aimed at `target` (a point in the net's plane, already spread by how
## clean the pattern was). Fires from the puck on the blade, or a loose one
## right at the blade.
func shoot_traced(kind: StringName, speed: float, target: Vector3) -> bool:
	if stun_timer > 0.0 or game.is_frozen() or stick_broken:
		return false
	if not has_puck():
		var d := Vector2(puck.position.x - blade_pos.x, puck.position.z - blade_pos.z).length()
		if puck.controller != null or puck.frozen or puck.position.y > StickPuck.BLADE_TOP * 2.0 \
				or d > StickPuck.BLADE_HALF + StickPuck.SWEEP * 2.0 or not puck.can_be_touched_by(self):
			return false
	shot_kind = kind
	var from := puck.position
	var dir := Vector3(target.x - from.x, 0, target.z - from.z)
	var dist := dir.length()
	dir = dir.normalized() if dist > 0.3 else heading
	speed *= lerpf(0.94, 1.0, stick_health)
	var slap := kind == &"slapshot"
	if StickWear.stress(self, (speed / 30.0) * (speed / 30.0) * (2.0 if slap else 0.15), &"slapshot"):
		speed *= 0.25
	# loft to reach the target's height: the drop over the flight added on
	var t := dist / maxf(speed, 1.0)
	var loft := atan2(target.y - from.y + 0.5 * 9.8 * t * t, maxf(dist, 0.5))
	loft = clampf(loft, deg_to_rad(1.0), deg_to_rad(40.0))
	var e := 0.5
	var face := _aim_face(dir, loft, speed, e)
	var n := _face_normal(face, loft)
	_set_blade(Vector2(REACH_MAX * 0.85, 0.15))
	if rig:
		rig.follow_through(0.9 if slap else 0.5, 1.0)
	StickPuck.strike(self, puck, _swing(n, speed, e), n, e)
	puck.pass_target = null
	game.on_shot(self, slap)
	return true


func attack_goal() -> Vector3:
	return Vector3(game.attack_side(team) * Rink.GOAL_X, 0, 0)


## Fires the puck: the blade is swung through it. How fast the skater can
## swing it (shot power, the wind-up, the release), where the face points
## (the aim, give or take how steady the hands are) and how open it is (tilt)
## make the swing; StickPuck.strike works out what the puck does. `held` is
## the wind-up time, `incoming` > 0 for a one-timer; `style` is a move's shot
## (MovePhysics), otherwise `shot_kind`'s entry in MovePhysics.SHOTS.
func shoot(held: float, slap: bool, incoming := 0.0, style := {}) -> void:
	var p := profile
	var from := puck.position
	var aim: Vector3 = ctrl.aim_point if ctrl.aim_point != null else attack_goal()
	var dir := Vector3(aim.x - from.x, 0, aim.z - from.z)
	dir = dir.normalized() if dir.length() > 0.3 else heading
	var spd: float
	var err := p.aim_error(held)
	var flex := p.charge(held)  # how much the wind-up has loaded the shaft
	if slap:
		spd = p.shot_speed * lerpf(0.6, 1.0, clampf((held - SLAP_MIN) / (p.charge_time + 0.25), 0.0, 1.0))
		err *= 1.35
	else:
		spd = p.wrist_speed(held)
	if style.is_empty():
		style = MovePhysics.SHOTS.get(shot_kind, {})
	if style.has("wind"):
		# the shot's own release does the work, not how long it was held
		spd = p.wrist_speed(style["wind"])
		err = p.aim_error(style.get("aim_wind", style["wind"]))
		flex = p.charge(style["wind"])
	if incoming > 0.0:
		err *= 1.3
	# moving fast, carving hard or being off balance costs accuracy
	err *= 1.0 + 0.4 * speed() / p.max_speed + turn_load / 40.0
	spd *= style.get("power", 1.0)
	err *= style.get("error", 1.0)
	# a one-handed shot is weaker and wilder
	spd *= lerpf(1.0, 0.7, _shot_hand)
	err *= lerpf(1.0, 1.6, _shot_hand)
	_shot_hand = 0.0
	# a worn stick has lost some of its pop
	spd *= lerpf(0.94, 1.0, stick_health)
	# the load on the stick: a slapshot or one-timer leans the whole body into
	# the shaft; a wrister or snapshot loads it far less
	var stick_load := (spd / 30.0) * (spd / 30.0) * (2.0 if slap else 0.15) * (1.3 if incoming > 0.0 else 1.0)
	if StickWear.stress(self, stick_load, &"slapshot"):
		# it snapped on the shot: what's left of the blade barely meets the puck
		spd *= 0.25
		err *= 3.0
		flex = 0.0
	# the face: pointed at the aim by the hands, which are only so steady, and
	# opened by the tilt (a flat face still lifts a wrister a touch)
	var e := lerpf(0.35, 0.6, flex)
	var shake := hand_shake()
	var loft := deg_to_rad(style.get("loft_deg", lerpf(4.0, 16.0, ctrl.tilt))) + shake.y * err * 0.5
	var face := _aim_face(dir, loft, spd, e).rotated(Vector3.UP, shake.x * err)
	var n := _face_normal(face, loft)
	StickPuck.strike(self, puck, _swing(n, spd, e), n, e)
	puck.pass_target = null
	game.on_shot(self, slap)


## The blade comes through at the speed the body can swing it, on top of
## the skater's own skating speed.
func _swing(n: Vector3, spd: float, e: float) -> Vector3:
	return Vector3(vel.x, 0, vel.z) + n * (spd / StickPuck.strike_gain(e))


static func _face_normal(face: Vector3, loft: float) -> Vector3:
	return (face * cos(loft) + Vector3.UP * sin(loft)).normalized()


## The puck leaves with what it already had (the skater's speed, the drag
## of the wind-up) on top of what the blade gives it, so a shooter turns the
## face off the aim to cancel that: returns the face direction that sends
## this strike along `dir`, found by trying it.
func _aim_face(dir: Vector3, loft: float, spd: float, e: float) -> Vector3:
	var face := dir
	var share := Contact.share_of(Contact.PUCK_MASS, Contact.BLADE_MASS)
	for k in 3:
		var n := _face_normal(face, loft)
		var out := Contact.bounce(puck.vel, n, _swing(n, spd, e), e, StickPuck.TAPE_GRIP, share)
		var off := Vector2(out.x, out.z).angle_to(Vector2(dir.x, dir.z))
		face = face.rotated(Vector3.UP, -off)
	return face


## Passing: a gentler sweep of the blade through the puck toward the aim,
## the receiver's blade led by where they're skating. Who to pass to is the
## player's (or the AI's) call: `ctrl.pass_hint`, else whoever is nearest the
## direction they're pushing.
func pass_puck() -> void:
	var p := profile
	var dir2: Vector2 = ctrl.pass_dir if ctrl.pass_dir.length() > 0.2 else Vector2(heading.x, heading.z)
	dir2 = dir2.normalized()
	var best: Skater = ctrl.pass_hint if ctrl.pass_hint else _receiver_toward(dir2)
	var target: Vector3
	var spd := 16.0
	if best:
		var dist := position.distance_to(best.position)
		spd = clampf(dist * 0.55 + 7.0, 8.0, 17.0)
		var t := dist / spd
		target = best.blade_pos + best.vel * t
	else:
		target = position + Vector3(dir2.x, 0, dir2.y) * 12.0
	var d := Vector3(target.x - puck.position.x, 0, target.z - puck.position.z).normalized()
	var err := p.pass_error * (1.0 + 0.3 * speed() / p.max_speed)
	var shake := hand_shake()
	# a tilted blade saucers the pass over sticks
	var loft := atan2(ctrl.tilt * 3.2, spd)
	const PASS_E := 0.35  # a sweep barely flexes the shaft
	d = _aim_face(d, loft, spd, PASS_E).rotated(Vector3.UP, shake.x * err)
	var n := _face_normal(d, loft)
	StickPuck.strike(self, puck, _swing(n, spd, PASS_E), n, PASS_E)
	puck.pass_target = best


## The teammate nearest the direction the passer is pushing, inside a 45
## degree cone (the player's intent; null if nobody is there).
func _receiver_toward(dir2: Vector2) -> Skater:
	var best: Skater = null
	var best_score := INF
	for mate in game.teammates(self):
		var to := Vector2(mate.position.x - position.x, mate.position.z - position.z)
		var ang := absf(dir2.angle_to(to))
		if ang > deg_to_rad(45.0):
			continue
		var score := ang + to.length() * 0.015
		if score < best_score:
			best_score = score
			best = mate
	return best


## How far off the hands are right now, about -2..2 in each axis (x: left
## and right, y: up and down): a steady, smooth tremor that's different for
## every skater, scaled by each shot's or pass's error. Nothing is rolled at
## the moment of release; it's where the hands happen to be.
func hand_shake() -> Vector2:
	var t := _clock
	var k := float(number * 7 + team * 3)
	return Vector2(
		1.2 * sin(t * 7.3 + k) + 0.8 * sin(t * 12.9 + k * 1.7),
		1.2 * sin(t * 6.1 + k * 2.3) + 0.8 * sin(t * 15.7 + k * 0.6))


## Defensive stick lift: get your blade under the carrier's shaft and heave
## up. It only works if your blade is actually under their stick, and it's a
## strength contest: your lift (hitting and hands) with the leverage of where
## you got under it (near their blade is easy, near their hands hopeless)
## against how hard they're bearing down (stick handling, two hands better).
func _try_stick_lift() -> void:
	lift_cd = 0.9
	var holder: Skater = puck.controller
	if holder == null or holder.team == team or holder.stick_lifted_timer > 0.0:
		return
	var me := Vector2(blade_pos.x, blade_pos.z)
	var hands := Vector2(holder.position.x, holder.position.z)
	var tip := Vector2(holder.blade_pos.x, holder.blade_pos.z)
	var shaft := tip - hands
	var along := clampf((me - hands).dot(shaft) / maxf(shaft.length_squared(), 0.01), 0.0, 1.0)
	if me.distance_to(hands + shaft * along) > LIFT_REACH:
		return
	var heave := profile.stick_lift * lerpf(0.8, 1.6, along)
	var hold := holder.skill("stick_handling") * lerpf(1.0, 0.5, holder.one_hand())
	if heave <= hold:
		return
	holder.stick_lifted_timer = STICK_LIFTED_TIME
	holder.cancel_shot()
	StickWear.stress(holder, 0.12, &"lift")
	StickWear.stress(self, 0.06, &"lift")
	puck.ignore_briefly(holder, STICK_LIFTED_TIME)
	puck.last_touch = self
	game.on_stick_lift(self, holder)


## 0 with both hands on the stick (front 90 degrees), 1 with one hand.
## While winding up a shot both hands stay on.
func one_hand() -> float:
	if winding:
		return 0.0
	return _one_hand_at(blade_ang, blade_reach)


## The body sets the reach (Sean, 19 Oct): SkaterRig.blade_reach works it
## out from the shoulder, arm and stick in the ready stance. The last
## TWO_HAND_LOSS of it is one-handed; the change
## happens over a 10 cm band past the two-hand reach so the grip doesn't
## flicker.
const TWO_HAND_LOSS := 0.15
## Furthest the blade gets with both hands on (a little past the stick's travel).
const GRIP_MAX := 1.7
## Leaning the shoulders out after a loose puck adds this to the arm's
## reach, at stick handling 0 and 1.
const LUNGE := Vector2(0.35, 0.45)


func lunge() -> float:
	return lerpf(LUNGE.x, LUNGE.y, skill("stick_handling"))
## How much of the one-hand carry cap the edge of the two-hand reach takes.
const EDGE_HANDS := 1.0
const _REACH_STEP := deg_to_rad(10.0)
static var _reach_table := PackedFloat32Array()


static func _one_hand_at(ang: float, reach: float) -> float:
	var two := grip_reach(ang)
	return smoothstep(two, two + 0.1, reach)


## How far out the bottom hand can stay on the stick at this angle: all but
## the last TWO_HAND_LOSS of the body's reach, and no more than GRIP_MAX
## (the bottom arm's own length).
static func grip_reach(ang: float) -> float:
	return maxf(REACH_MIN + 0.05, minf(GRIP_MAX, reach_limit(ang) - TWO_HAND_LOSS))


## How far the stick's travel takes the blade at this angle: as far as
## REACH_MAX, but never past where the bottom hand lets go. Reaching further
## (a poke, a loose puck) is past the stick's travel.
static func two_hand_reach(ang: float) -> float:
	return minf(REACH_MAX, grip_reach(ang))


## How far the blade can reach at this angle (radians from straight ahead,
## + = right): the body's one-handed reach, from a table every 10 degrees.
static func reach_limit(ang: float) -> float:
	if _reach_table.is_empty():
		refresh_reach()
	var u := (wrapf(ang, -PI, PI) + PI) / _REACH_STEP
	var i := mini(int(u), _reach_table.size() - 2)
	return lerpf(_reach_table[i], _reach_table[i + 1], u - i)


## Rebuilds the reach table (after the stance or stick changes in AnimTuning).
static func refresh_reach() -> void:
	_reach_table.clear()
	var n := int(round(TAU / _REACH_STEP))
	for i in n + 1:
		var a := -PI + i * _REACH_STEP
		# body space: -Z forward, +X right
		_reach_table.append(maxf(REACH_MIN + 0.1, SkaterRig.blade_reach(Vector3(sin(a), 0, -cos(a)))))


func _set_blade(local: Vector2) -> void:
	blade_local = local
	blade_ang = atan2(local.y, local.x)
	blade_reach = local.length()
	blade_lvel = Vector2.ZERO
	_blade_pvel = Vector2.ZERO


func _blade_world(local: Vector2) -> Vector3:
	return position + heading * local.x + right_vec() * local.y


func _apply_transform() -> void:
	basis = Basis(Vector3.UP, atan2(-heading.x, -heading.z))


static func _rotate_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var a := from.signed_angle_to(to, Vector3.UP)
	return from.rotated(Vector3.UP, clampf(a, -max_angle, max_angle)).normalized()


func _make_spray() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.45
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	p.position = Vector3(0, 0.05, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f4f6fa")
	m.material = mat
	p.mesh = m
	return p
