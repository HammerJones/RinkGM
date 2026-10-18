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
	var ai: TierAI = g.ai_for(s.team)
	if s.stick_broken:
		s.ai_shoot_timer = 0.0
		_no_stick(s, g, ai)
		return
	if s.ai_shoot_timer > 0.0:
		s.ai_shoot_timer -= dt
		c.shoot = true
		c.lift = s.ai_slap
		c.tilt = s.ai_tilt
		c.aim_point = s.ai_aim
	var puck: Puck = g.puck
	var owner := _believed_owner(s, g, puck.controller, ai, dt)
	if s.ai_react > 0.0:
		# hasn't read the change yet: keeps skating the way it was going
		c.move = was_moving
		c.blade_target = was_blade
		return
	if owner == s:
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
	# dash to close long gaps when the skates already point the right way
	s.ctrl.dash = dist > sprint_dist and s.heading.dot(Vector3(d.x, 0, d.y) / dist) > 0.9 \
		and randf() < lerpf(0.01, 0.09, ai.dash_use)
	var sp := _v2(s.vel)
	s.ctrl.stop = dist < 2.0 and sp.length() > 4.5 and sp.dot(d) < 0.0


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
		var sure_d := lerpf(10.0, 7.5, sel)
		if ahead > 1.0 and open_angle and d < max_d and (d < sure_d or randf() < lerpf(0.5, 0.05, sel)) \
				and (lane_open or randf() < lerpf(0.6, 0.04, sel)):
			s.ai_aim = aim
			s.ai_slap = d > 10.0 and randf() < 0.5
			s.ai_tilt = 0.0 if randf() < 0.5 else randf_range(0.4, 1.0)
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
	c.blade_target = _carry_blade(s, g)


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


static func _support(s: Skater, g: Node, ai: TierAI, owner: Skater) -> void:
	var att: int = g.attack_side(s.team)
	var o := _v2(owner.position)
	var others: Array = g.teammates(owner)
	var idx := others.find(s)
	var side := signf(o.y if absf(o.y) > 0.5 else 1.0)
	# up to four support spots (5-on-5): wide lane, trailer, net front, high point
	var slots := [
		Vector2(o.x + att * 5.0, -side * 6.5),
		Vector2(o.x - att * 6.0, o.y * 0.3),
		Vector2(o.x + att * 3.5, side * 2.5),
		Vector2(o.x - att * 11.0, -side * 4.5),
	]
	var slot: Vector2 = slots[maxi(idx, 0) % slots.size()]
	# without structure, support drifts in toward the puck and bunches up
	var drift := (1.0 - ai.discipline) * 0.65
	var crowd := o + Vector2(att * 1.5, sin(g.time * 0.7 + s.number * 2.1) * 2.5)
	slot = slot.lerp(crowd, drift)
	slot.x = clampf(slot.x, -Rink.GOAL_X + 3.0, Rink.GOAL_X - 3.0)
	slot.y = clampf(slot.y, -Rink.HALF_W + 2.0, Rink.HALF_W - 2.0)
	_seek(s, ai, slot, 2.0, 12.0)
	s.ctrl.blade_target = s.position + (owner.position - s.position).normalized() * 1.0


static func _defend(s: Skater, g: Node, ai: TierAI, owner: Skater, dt: float) -> void:
	var c := s.ctrl
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	var me := _v2(s.position)
	var o := _v2(owner.position)
	if _rank_to(s, g, o) < _chasers(ai):
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
	# mark an opponent who isn't carrying, staying goal-side; without
	# discipline the mark is loose, the backcheck lazy and eyes on the puck
	var opps: Array = g.team_skaters(1 - s.team).filter(func(x): return x != owner)
	var mine: Array = g.team_skaters(s.team).filter(func(x): return _rank_to(x, g, o) >= _chasers(ai))
	if opps.is_empty():
		return
	var structured := ai.discipline > 0.35
	if structured:
		# a system: the deepest defenders take the most dangerous opponents,
		# and with the puck in our end the deepest one holds the slot
		var by_depth := func(a, b): return _v2(a.position).distance_squared_to(my_goal) < _v2(b.position).distance_squared_to(my_goal)
		opps.sort_custom(by_depth)
		mine.sort_custom(by_depth)
		if o.distance_to(my_goal) < 18.0 and mine.size() > 0:
			if mine[0] == s:
				var slot := my_goal + (o - my_goal).normalized() * 3.0
				_seek(s, ai, slot, 1.2, 10.0)
				c.blade_target = g.puck.position
				return
			mine.pop_front()
	var mark: Skater = opps[maxi(mine.find(s), 0) % opps.size()]
	var m := _v2(mark.position)
	var spot := m + (my_goal - m).normalized() * lerpf(0.8, 2.0, ai.discipline)
	spot = spot.lerp(o, (1.0 - ai.discipline) * 0.45)
	_seek(s, ai, spot, 1.5, 10.0, lerpf(0.7, 1.0, ai.discipline))
	c.blade_target = s.position + (mark.position - s.position).normalized()


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
	var rank := _rank_to(s, g, p)
	var chasers := _chasers(ai)
	if rank < chasers:
		_seek(s, ai, p + pv * lerpf(0.0, 0.45, ant), 0.6, 6.0)
		c.blade_target = puck.position
		return
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	if rank == chasers and ai.discipline > 0.35:
		# second man: close enough to win the puck if the chaser loses it,
		# goal-side and off to one side
		var back := (my_goal - p).normalized()
		var sup := p + pv * lerpf(0.0, 0.45, ant) + back * 3.5 + Vector2(-back.y, back.x) * 2.0 * signf(_v2(s.position).y - p.y + 0.01)
		_seek(s, ai, sup, 1.5, 10.0)
		c.blade_target = puck.position
		return
	var spot := p.lerp(my_goal, lerpf(0.15, 0.4, ai.discipline)) + Vector2(0, 5.0 if s.number % 2 == 0 else -5.0)
	spot.y = clampf(spot.y, -Rink.HALF_W + 2.0, Rink.HALF_W - 2.0)
	_seek(s, ai, spot, 2.0, 12.0)


## Where a carrier's blade goes: it keeps the puck on its face and works it
## gently from side to side in front, rather than leaving it to chase a spot.
static func _carry_blade(s: Skater, g: Node) -> Vector3:
	var puck: Puck = g.puck
	var n: Vector2 = StickPuck.blade_at(s, 1.0)[2] * (s.puck_side if s.puck_side != 0.0 else 1.0)
	var p := Vector2(puck.position.x, puck.position.z)
	var hold := p - n * StickPuck.gap()
	var wobble := 0.15 * sin(g.time * 4.0 + s.number)
	var spot := _v2(s.position + s.heading * Skater.DEFAULT_BLADE.x + s.right_vec() * (0.1 + wobble))
	# draw the puck toward the carrying spot through the face it's on
	var at := hold + (spot - hold).limit_length(0.12)
	return Vector3(at.x, 0, at.y)

