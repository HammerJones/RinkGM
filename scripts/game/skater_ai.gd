class_name SkaterAI
extends RefCounted
## Team AI that drives the same Controls a human uses: carry, shoot or pass
## with the puck, get open for a teammate, pressure or mark on defence, and
## chase loose pucks.
##
## How *organised* it plays comes from the team's TierAI (game.ai_for), not
## from ratings: a beer league reacts late, swarms the puck, forces passes and
## shoots from anywhere; a pro side holds lanes and gaps, reads the ice and
## waits for a shot. Ratings still decide how well each body executes.


static func think(s: Skater, g: Node, dt: float) -> void:
	var c := s.ctrl
	var was_moving := c.move
	var was_blade: Variant = c.blade_target
	c.reset()
	s.ai_on_puck = false
	var ai: TierAI = g.ai_for(s.team)
	if s.stick_broken:
		s.ai_shoot_timer = 0.0
		_no_stick(s, g, ai)
		return
	if s.changing:
		# line change: off through the bench's far gate; a fresh body comes on
		_seek(s, ai, g.bench_exit(s.team), 1.0, 6.0)
		return
	if s.ai_shoot_timer > 0.0:
		s.ai_shoot_timer -= dt
		c.shoot = true
		c.lift = s.ai_slap
		c.tilt = s.ai_tilt
		c.aim_point = s.ai_aim
	elif s.winding:
		# letting go of the button: the release still goes where it was aimed
		c.tilt = s.ai_tilt
		c.aim_point = s.ai_aim
	var puck: Puck = g.puck
	var owner := _believed_owner(s, g, puck.controller, ai, dt)
	if s.ai_react > 0.0:
		# hasn't read the change yet: keeps skating the way it was going
		c.move = was_moving
		c.blade_target = was_blade
		return
	_read_phase(s, g, ai, owner, dt)
	if owner == s and g.shootout:
		_shootout_carry(s, g, ai, dt)
	elif owner == s:
		_carry(s, g, ai, dt)
	elif owner != null and owner.team == s.team:
		_support(s, g, ai, owner)
	elif owner != null:
		_defend(s, g, ai, owner, dt)
	else:
		_loose(s, g, ai)


## A broken stick: off to the bench door for a new one. A disciplined
## player with the puck deep in their own end stays to block in front of the
## net until it's cleared.
static func _no_stick(s: Skater, g: Node, ai: TierAI) -> void:
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	var p := _v2(g.puck.position)
	if ai.discipline > 0.5 and p.distance_to(my_goal) < 15.0:
		_seek(s, ai, my_goal + (p - my_goal).normalized() * 3.0, 1.0, 8.0)
		return
	_seek(s, ai, g.bench_spot(s.team), 2.5, 6.0)


## Who this skater acts as if has the puck. Your own puck (and losing it) you
## know about at once; everyone else's changes land after the tier's
## reaction delay.
static func _believed_owner(s: Skater, g: Node, owner: Skater, ai: TierAI, dt: float) -> Skater:
	if owner == s or s.ai_owner == s:
		if owner == s and s.ai_owner != s:
			# just got it: a sharp player releases or moves it at once, a beer
			# leaguer settles it first
			s.ai_decide = randf_range(0.0, ai.decide_min) * (1.0 - ai.anticipation) * 2.0
		s.ai_owner = owner
		s.ai_react = -1.0
	elif owner != s.ai_owner:
		if s.ai_react < 0.0:
			s.ai_react = ai.reaction * randf_range(0.7, 1.3)
		s.ai_react -= dt
		if s.ai_react <= 0.0:
			s.ai_owner = owner
			s.ai_react = -1.0
	else:
		s.ai_react = -1.0
	# a believed carrier who has left the ice (line change) is no one
	if s.ai_owner != null and not s.ai_owner in g.skaters:
		s.ai_owner = owner
	return s.ai_owner


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _seek(s: Skater, ai: TierAI, target: Vector2, arrive: float, sprint_dist: float, effort := 1.0) -> void:
	var d := target - _v2(s.position)
	var dist := d.length()
	if dist < 0.05:
		s.ctrl.move = Vector2.ZERO
		return
	s.ctrl.move = d / dist * clampf(dist / arrive, 0.0, 1.0) * effort
	s.ctrl.move = _avoid(s, s.ctrl.move)
	# dash to close long gaps when the skates already point the right way
	s.ctrl.dash = dist > sprint_dist and s.heading.dot(Vector3(d.x, 0, d.y) / dist) > 0.9 \
		and randf() < lerpf(0.01, 0.09, ai.dash_use)
	var sp := _v2(s.vel)
	s.ctrl.stop = dist < 2.0 and sp.length() > 4.5 and sp.dot(d) < 0.0


## Nobody skates head-on into another body at full speed unless they mean
## to hit it: steer round anyone on a collision course in the next 0.7
## s, more sharply the sooner it would happen (a skater lining up a
## check keeps going at the one they're checking).
static func _avoid(s: Skater, move: Vector2) -> Vector2:
	var me := _v2(s.position)
	var mv := _v2(s.vel)
	var out := move
	for o: Skater in s.game.skaters:
		if o == s or o.stun_timer > 0.0:
			continue
		if s.ctrl.check and o.team != s.team:
			continue
		var r := _v2(o.position) - me
		var dist := r.length()
		if dist > 8.0 or dist < 0.01:
			continue
		var closing := (mv - _v2(o.vel)).dot(r / dist)
		if closing < 1.5:
			continue
		var t := (dist - Skater.RADIUS * 2.0) / closing
		if t > 0.7:
			continue
		var away := Vector2(-r.y, r.x) / dist
		if away.dot(move) < 0.0:
			away = -away
		var w := clampf(1.0 - t / 0.7, 0.0, 1.0)
		out = out.lerp(away * maxf(move.length(), 0.6) - r / dist * 0.4 * w, w)
	return out


## Rank of `s` among its teammates by distance to `p` (0 = closest).
static func _rank_to(s: Skater, g: Node, p: Vector2) -> int:
	var mine := _v2(s.position).distance_squared_to(p)
	var r := 0
	for m in g.teammates(s):
		if _v2(m.position).distance_squared_to(p) < mine:
			r += 1
	return r


## How many skaters go after the puck: one in a structured system, up to
## three in a scramble.
static func _chasers(ai: TierAI) -> int:
	return 1 + int((1.0 - ai.discipline) * 2.5)


static func _carry(s: Skater, g: Node, ai: TierAI, dt: float) -> void:
	var c := s.ctrl
	var att: int = g.attack_side(s.team)
	var me := _v2(s.position)
	if TeamSystem.is_d(TeamSystem.role_of(s, g)) and me.x * att > Rink.BLUE_X and randf() < ai.discipline * 4.0:
		_point_carry(s, g, ai, dt)
		return
	var goal := Vector2(att * Rink.GOAL_X, 0)
	var ahead := (goal.x - me.x) * att
	var d := me.distance_to(goal)
	var sel := ai.shot_selection
	var open_angle := absf(me.y) < maxf(2.5, ahead * lerpf(1.6, 0.8, sel))
	var pressure: float = g.nearest_opponent_distance_to(s.team, me)
	s.ai_decide -= dt
	if s.ai_decide <= 0.0 and s.ai_shoot_timer <= 0.0:
		s.ai_decide = randf_range(ai.decide_min, ai.decide_max)
		var caller: Skater = null if g.autoplay else g.controller.pass_caller(s)
		if caller:
			c.pass_pressed = true
			c.pass_hint = caller
			return
		var aim := Vector3(goal.x, 0, _aim_side(s, g, ai, att) * randf_range(0.45, 0.8))
		var lane_open: bool = g.lane_clear(s.team, me, Vector2(aim.x, aim.z), 0.7)
		# good shot selection means working it in close before letting go
		var max_d := lerpf(24.0, 13.0, sel)
		var sure_d := lerpf(8.0, 6.0, sel)
		if ahead > 1.0 and open_angle and d < max_d and (d < sure_d or randf() < lerpf(0.35, 0.04, sel)) \
				and (lane_open or randf() < lerpf(0.35, 0.02, sel)):
			s.ai_aim = aim
			s.ai_slap = d > 10.0 and randf() < 0.5
			s.ai_tilt = 0.0 if randf() < 0.5 else _tilt_for(s, d, randf_range(0.5, 1.0))
			s.ai_shoot_timer = 0.6 if s.ai_slap else randf_range(0.02, 0.35)
			c.shoot = true
			c.lift = s.ai_slap
			c.tilt = s.ai_tilt
			c.aim_point = s.ai_aim
		else:
			# under pressure everyone looks to move it; a side that reads the
			# ice also moves it early to an open man further up
			var mate: Skater = g.best_pass_option(s, ai.vision)
			if mate:
				var gain: float = (mate.position.x - s.position.x) * att
				var pressed := pressure < lerpf(3.4, 2.4, ai.vision) and randf() < 0.6
				var stretch := gain > lerpf(12.0, 4.0, ai.vision) and randf() < ai.vision * 0.6
				if pressed or stretch:
					c.pass_pressed = true
					c.pass_hint = mate
	# drive to the slot, curling away from the nearest defender
	var target := goal - Vector2(att * lerpf(8.0, 5.5, sel), 0)
	if ahead < 1.0:
		target = Vector2(goal.x - att * 4.0, signf(me.y if me.y != 0.0 else 1.0) * 3.0)
	var opp: Skater = g.nearest_opponent(s.team, me)
	if opp and me.distance_to(_v2(opp.position)) < lerpf(2.5, 5.0, ai.vision):
		target += (me - _v2(opp.position)).normalized() * 3.0
	_seek(s, ai, target, 1.0, 20.0)
	c.blade_target = _carry_blade(s, g, ai)


## A D with the puck on the point: walks the line rather than going to the
## net, moves it D-to-D or down low, and shoots low for a tip when the lane
## is open. The side's discipline decides how often a D stays home like
## this rather than carrying it in.
static func _point_carry(s: Skater, g: Node, ai: TierAI, dt: float) -> void:
	var c := s.ctrl
	var att: int = g.attack_side(s.team)
	var me := _v2(s.position)
	var f := TeamSystem.to_frame(g, s.team, me)
	var goal := Vector2(att * Rink.GOAL_X, 0)
	var pressure: float = g.nearest_opponent_distance_to(s.team, me)
	# walk the line toward the middle, staying inside the blue line
	var walk := TeamSystem.to_world(g, s.team, Vector2(Rink.BLUE_X + 1.6, f.y * 0.6))
	_seek(s, ai, walk, 1.5, 30.0, 0.6)
	c.blade_target = _carry_blade(s, g, ai)
	s.ai_decide -= dt
	if s.ai_decide > 0.0 and pressure > 2.5:
		return
	s.ai_decide = randf_range(ai.decide_min, ai.decide_max)
	var partner: Skater = null
	for m: Skater in g.teammates(s):
		if TeamSystem.is_d(TeamSystem.role_of(m, g)):
			partner = m
	var aim := Vector3(goal.x, 0, randf_range(-0.6, 0.6))
	var lane_open: bool = g.lane_clear(s.team, me, Vector2(aim.x, aim.z), 1.0)
	var roll := randf()
	if lane_open and roll < 0.35:
		# low and hard for a tip or a rebound
		s.ai_aim = aim
		s.ai_slap = randf() < 0.4
		s.ai_tilt = 0.0
		s.ai_shoot_timer = 0.6 if s.ai_slap else randf_range(0.05, 0.25)
		c.shoot = true
		c.lift = s.ai_slap
		c.aim_point = s.ai_aim
		return
	var mate: Skater = g.best_pass_option(s, ai.vision)
	if partner and (roll < 0.65 or mate == null) and g.lane_clear(s.team, me, _v2(partner.position), 0.8):
		mate = partner  # D-to-D to move the goalie and the box
	if mate:
		c.pass_pressed = true
		c.pass_hint = mate


const SETTLED_TURN := 6.0  # m/s^2 of turn load a shootout shooter waits to drop under


## Shootout, alone with the goalie. A shooter comes in wide on their lane,
## squares up, eases off and lets a high shot go for the far side; a deker
## (every third shooter) comes in close, cuts hard across the crease to pull
## the goalie over and shoots for the side they've left. A better
## shot-picker reads the goalie.
static func _shootout_carry(s: Skater, g: Node, ai: TierAI, dt: float) -> void:
	var c := s.ctrl
	var att: int = g.attack_side(s.team)
	var me := _v2(s.position)
	var goal := Vector2(att * Rink.GOAL_X, 0)
	var ahead := (goal.x - me.x) * att
	var lane := 1.6 if s.number % 2 == 0 else -1.6
	var deke := s.number % 3 == 0
	var gk: Goalie = null
	for o: Goalie in g.goalies:
		if o.team != s.team:
			gk = o
	c.blade_target = s.position + s.heading * Skater.DEFAULT_BLADE.x + s.right_vec() * 0.3
	s.ai_decide -= dt
	if s.ai_shoot_timer > 0.0 or s.ai_decide > 0.0:
		# shot away (or the button just let go): follow it in
		_seek(s, ai, goal, 1.0, 30.0)
		return
	var ready := false
	if deke:
		# in to the top of the crease on the lane, then across it
		if ahead > 4.0:
			_seek(s, ai, Vector2(goal.x - att * 3.5, lane), 1.0, 30.0)
			return
		_seek(s, ai, Vector2(goal.x - att * 1.6, -lane * 0.9), 0.6, 30.0)
		var gap := absf(me.y - gk.pos2.y) if gk else 1.0
		ready = gap > 0.7 or ahead < 1.8
	else:
		var release := lerpf(11.0, 8.0, ai.shot_selection) + fmod(s.number * 0.73, 1.0)
		if ahead > release:
			var aim_lane := lane if ahead > release + 6.0 else lane * 0.5
			_seek(s, ai, Vector2(goal.x - att * (release - 1.0), aim_lane), 1.0, 30.0)
			return
		# square up and settle: carving hard or at full speed sprays the shot
		_seek(s, ai, goal, 1.0, 30.0, 0.4)
		ready = s.turn_load < SETTLED_TURN or ahead < release - 3.0
	if not ready:
		return
	# one shot, then let go of the button (a re-press the next frame would
	# start a new wind-up instead of releasing)
	s.ai_decide = 1.0
	var side := -signf(me.y) if absf(me.y) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
	if gk and absf(gk.pos2.y) > 0.1 and (deke or randf() < ai.shot_selection):
		side = -signf(gk.pos2.y)
	s.ai_aim = Vector3(goal.x, 0, side * (Rink.NET_HALF_W - 0.15))
	s.ai_slap = false
	s.ai_tilt = _tilt_for(s, me.distance_to(goal), randf_range(0.55, 1.0)) if randf() < 0.75 else 0.0
	s.ai_shoot_timer = randf_range(0.08, 0.2) if deke else randf_range(0.15, 0.35)
	c.shoot = true
	c.tilt = s.ai_tilt
	c.aim_point = s.ai_aim


## How far to open the blade so a shot from `d` m crosses the goal line
## about `height` m up: a shooter knows roughly how hard they shoot and lifts
## it to match (the hands' wobble still moves it).
static func _tilt_for(s: Skater, d: float, height: float) -> float:
	var blade := s.profile.wrist_speed(0.3)
	var skating := maxf(0.0, s.vel.dot(s.attack_goal() - s.position) / maxf(d, 0.1))
	var t := d / (blade + skating)
	# the lift comes from the blade alone; skating only adds speed along the ice
	var rise := (height + 0.5 * Puck.GRAVITY * t * t) / t
	var loft := rad_to_deg(asin(clampf(rise / blade, 0.0, 1.0)))
	return clampf((loft - 4.0) / 12.0, 0.0, 1.0)


## Which post to shoot for: a disciplined shooter picks the side the goalie
## has left open, a beer leaguer just shoots.
static func _aim_side(s: Skater, g: Node, ai: TierAI, att: int) -> float:
	var coin := 1.0 if randf() < 0.5 else -1.0
	if randf() > ai.shot_selection:
		return coin
	for gk: Goalie in g.goalies:
		if gk.team != s.team:
			return -signf(gk.pos2.y) if absf(gk.pos2.y) > 0.05 else coin
	return coin


## The phase of play as this skater sees it: who has the puck (their
## believed owner; a loose puck still belongs to whoever last had it under
## control, so a deflection or a scramble doesn't flip the whole system) and
## where it is. A change sinks in after the tier's anticipation: a beer
## leaguer is still standing on the point a second after the puck went the
## other way.
static func _read_phase(s: Skater, g: Node, ai: TierAI, owner: Skater, dt: float) -> void:
	var holder := -1
	if owner != null:
		holder = owner.team
	elif s.ai_phase >= 0:
		holder = s.team if TeamSystem.ours(s.ai_phase) else 1 - s.team
	var u := TeamSystem.to_frame(g, s.team, _v2(g.puck.position)).x
	var ph := TeamSystem.phase(s.team, holder, u)
	if s.ai_phase < 0:
		s.ai_phase = ph
	elif ph != s.ai_phase:
		if s.ai_phase_lag < 0.0:
			s.ai_phase_lag = lerpf(1.0, 0.1, ai.anticipation)
		s.ai_phase_lag -= dt
		if s.ai_phase_lag <= 0.0:
			s.ai_phase = ph
			s.ai_phase_lag = -1.0
	else:
		s.ai_phase_lag = -1.0


## Where this skater's position puts them in the phase they've read, and how
## tightly they keep to it: a structured side holds its spots (and rotates
## to cover a teammate), a beer league drifts toward the puck and wanders.
static func _role_spot(s: Skater, g: Node, ai: TierAI, carrier: Skater) -> Vector2:
	var p := TeamSystem.focus(g, s.team)
	var spots := TeamSystem.assignments(g, s.team, s.ai_phase, p, carrier, ai.discipline)
	var spot: Vector2 = spots.get(s, _v2(s.position))
	# squared, so a structured side barely strays while a beer league drifts
	var loose := (1.0 - ai.discipline) * (1.0 - ai.discipline)
	var wander := Vector2(sin(g.time * 0.43 + s.number * 1.7), cos(g.time * 0.37 + s.number * 2.3)) * 4.0 * loose
	var puck := _v2(g.puck.position)
	spot = (spot + wander).lerp(puck, loose * 0.8)
	spot.x = clampf(spot.x, -Rink.GOAL_X - 1.0, Rink.GOAL_X + 1.0)
	spot.y = clampf(spot.y, -Rink.HALF_W + 1.2, Rink.HALF_W - 1.2)
	return spot


static func _support(s: Skater, g: Node, ai: TierAI, owner: Skater) -> void:
	_seek(s, ai, _role_spot(s, g, ai, owner), 2.0, 12.0)
	s.ctrl.blade_target = s.position + (owner.position - s.position).normalized() * 1.0


static func _defend(s: Skater, g: Node, ai: TierAI, owner: Skater, dt: float) -> void:
	var c := s.ctrl
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	var me := _v2(s.position)
	var o := _v2(owner.position)
	var p := TeamSystem.to_frame(g, s.team, o)
	# F1 goes at the carrier; a less disciplined side sends more after it
	var f1 := TeamSystem.presser(g, s.team, s.ai_phase, p)
	s.ai_on_puck = s == f1
	if s == f1 or _rank_to(s, g, o) < _chasers(ai) - 1:
		var dist := me.distance_to(o)
		# a structured presser keeps a gap goal-side until close; a scrambler
		# just goes for the puck
		var gap := lerpf(0.4, 1.4, ai.discipline) * lerpf(1.2, 0.7, ai.aggression)
		var target := o + (my_goal - o).normalized() * gap if dist > 3.0 else _v2(g.puck.position)
		_seek(s, ai, target, 0.8, 8.0)
		c.blade_target = g.puck.position
		if dist < 1.8 and s.check_cd <= 0.0 and randf() < dt * lerpf(0.3, 1.5, ai.aggression):
			c.check = true
		elif dist < 1.6 and s.lift_cd <= 0.0 and randf() < dt * lerpf(0.4, 1.7, ai.aggression):
			c.lift = true
		return
	# everyone else to their spot in the system, taking the man who comes
	# into their area and staying goal-side of him
	var spot := _role_spot(s, g, ai, owner)
	var mark: Skater = null
	var near := lerpf(3.0, 6.0, ai.discipline)
	for x: Skater in g.team_skaters(1 - s.team):
		if x == owner:
			continue
		var d := _v2(x.position).distance_to(spot)
		if d < near:
			near = d
			mark = x
	if mark:
		var m := _v2(mark.position)
		spot = spot.lerp(m + (my_goal - m).normalized() * lerpf(0.8, 1.6, ai.discipline), 0.6)
	_seek(s, ai, spot, 1.5, 10.0, lerpf(0.7, 1.0, ai.discipline))
	c.blade_target = s.position + ((mark.position if mark else owner.position) - s.position).normalized()


static func _loose(s: Skater, g: Node, ai: TierAI) -> void:
	var c := s.ctrl
	var puck: Puck = g.puck
	var p := _v2(puck.position)
	var pv := _v2(puck.vel)
	var ant := ai.anticipation
	if puck.pass_target == s and pv.length() > 1.0:
		# step into the passing lane
		var t := clampf((_v2(s.position) - p).dot(pv.normalized()) / maxf(pv.length(), 1.0), 0.0, 1.5)
		_seek(s, ai, p + pv * t * lerpf(0.4, 1.0, ant), 1.0, 30.0)
		c.blade_target = puck.position + puck.vel * 0.05
		return
	# a reader jumps the lane of a pass meant for an opponent
	var tgt: Skater = puck.pass_target
	if tgt != null and tgt.team != s.team and pv.length() > 3.0 and randf() < ant:
		var q := Geometry2D.get_closest_point_to_segment(_v2(s.position), p, _v2(tgt.position))
		if q.distance_to(_v2(s.position)) < lerpf(1.0, 4.0, ant) and _rank_to(s, g, q) == 0:
			_seek(s, ai, q, 0.6, 6.0)
			c.blade_target = Vector3(q.x, 0, q.y)
			return
	# the nearest player whose position lets them go gets it (D don't chase
	# deep in the other team's end); a less disciplined side sends more
	var chaser := _loose_chaser(g, s.team, p)
	s.ai_on_puck = s == chaser
	if s.ai_on_puck or _rank_to(s, g, p) < _chasers(ai) - 1:
		_seek(s, ai, p + pv * lerpf(0.0, 0.45, ant), 0.6, 6.0)
		c.blade_target = puck.position
		return
	# a structured side sends the next forward in close behind the chaser, on
	# the goal side, to win the battle or pick up what squirts out
	if ai.discipline > 0.5 and s == _loose_support(g, s.team, p, chaser):
		var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
		_seek(s, ai, p + (my_goal - p).normalized() * 2.5, 1.0, 8.0)
		c.blade_target = puck.position
		return
	_seek(s, ai, _role_spot(s, g, ai, null), 2.0, 12.0)
	c.blade_target = puck.position


## Who goes for a loose puck: the nearest skater, except that the D hold
## the blue line when it's in the attacking end beyond the top of the circles.
static func _loose_chaser(g: Node, team: int, p: Vector2) -> Skater:
	var u := TeamSystem.to_frame(g, team, p).x
	var best: Skater = null
	var best_d := INF
	for s: Skater in g.team_skaters(team):
		if s.changing or s.stick_broken or s.stun_timer > 0.0:
			continue
		if u > Rink.BLUE_X + 5.0 and TeamSystem.is_d(TeamSystem.role_of(s, g)):
			continue
		var d := _v2(s.position).distance_to(p)
		if d < best_d:
			best_d = d
			best = s
	return best


## The second forward on a loose puck: the nearest one after the chaser,
## if they're close enough to get there while it matters.
static func _loose_support(g: Node, team: int, p: Vector2, chaser: Skater) -> Skater:
	var best: Skater = null
	var best_d := 12.0
	for s: Skater in g.team_skaters(team):
		if s == chaser or s.changing or s.stick_broken or s.stun_timer > 0.0 or TeamSystem.is_d(TeamSystem.role_of(s, g)):
			continue
		var d := _v2(s.position).distance_to(p)
		if d < best_d:
			best_d = d
			best = s
	return best


## Where a carrier's blade goes: it keeps the puck on its face and works it
## gently from side to side in front, rather than leaving it to chase a spot.
static func _carry_blade(s: Skater, g: Node, ai: TierAI) -> Vector3:
	var puck: Puck = g.puck
	var n: Vector2 = StickPuck.blade_at(s, 1.0)[2] * (s.puck_side if s.puck_side != 0.0 else 1.0)
	var p := Vector2(puck.position.x, puck.position.z)
	var hold := p - n * StickPuck.gap()
	# a beer leaguer stickhandles big and loose; a tidy side keeps it close
	var wobble := lerpf(0.3, 0.12, ai.discipline) * sin(g.time * lerpf(6.0, 4.0, ai.discipline) + s.number)
	var spot := _v2(s.position + s.heading * Skater.DEFAULT_BLADE.x + s.right_vec() * (0.1 + wobble))
	# draw the puck toward the carrying spot through the face it's on
	var at := hold + (spot - hold).limit_length(lerpf(0.2, 0.12, ai.discipline))
	return Vector3(at.x, 0, at.y)

