class_name SkaterAI
extends RefCounted
## Team AI that drives the same Controls a human uses: carry, shoot or pass
## with the puck, get open for a teammate, pressure or mark on defence, and
## chase loose pucks.


static func think(s: Skater, g: Node, dt: float) -> void:
	var c := s.ctrl
	c.reset()
	if s.ai_shoot_timer > 0.0:
		s.ai_shoot_timer -= dt
		c.shoot = true
		c.lift = s.ai_slap
		c.tilt = s.ai_tilt
		c.aim_point = s.ai_aim
	var puck: Puck = g.puck
	var owner: Skater = puck.controller
	if owner == s:
		_carry(s, g, dt)
	elif owner != null and owner.team == s.team:
		_support(s, g, owner)
	elif owner != null:
		_defend(s, g, owner, dt)
	else:
		_loose(s, g)


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _seek(s: Skater, target: Vector2, arrive: float, sprint_dist: float) -> void:
	var d := target - _v2(s.position)
	var dist := d.length()
	if dist < 0.05:
		s.ctrl.move = Vector2.ZERO
		return
	s.ctrl.move = d / dist * clampf(dist / arrive, 0.0, 1.0)
	# dash to close long gaps when the skates already point the right way
	s.ctrl.dash = dist > sprint_dist and s.heading.dot(Vector3(d.x, 0, d.y) / dist) > 0.9 and randf() < 0.05
	var sp := _v2(s.vel)
	s.ctrl.stop = dist < 2.0 and sp.length() > 4.5 and sp.dot(d) < 0.0


static func _carry(s: Skater, g: Node, dt: float) -> void:
	var c := s.ctrl
	var att: int = g.attack_side(s.team)
	var me := _v2(s.position)
	var goal := Vector2(att * Rink.GOAL_X, 0)
	var ahead := (goal.x - me.x) * att
	var d := me.distance_to(goal)
	var open_angle := absf(me.y) < maxf(2.5, ahead * 0.9)
	var pressure: float = g.nearest_opponent_distance_to(s.team, me)
	s.ai_decide -= dt
	if s.ai_decide <= 0.0 and s.ai_shoot_timer <= 0.0:
		s.ai_decide = randf_range(0.15, 0.35)
		var aim := Vector3(goal.x, 0, randf_range(0.45, 0.8) * (1.0 if randf() < 0.5 else -1.0))
		var lane_open: bool = g.lane_clear(s.team, me, Vector2(aim.x, aim.z), 0.7)
		if ahead > 1.0 and open_angle and d < 16.0 and (d < 9.0 or randf() < 0.3) and (lane_open or randf() < 0.25):
			s.ai_aim = aim
			s.ai_slap = d > 10.0 and randf() < 0.5
			s.ai_tilt = 0.0 if randf() < 0.5 else randf_range(0.4, 1.0)
			s.ai_shoot_timer = 0.6 if s.ai_slap else randf_range(0.02, 0.35)
			c.shoot = true
			c.lift = s.ai_slap
			c.tilt = s.ai_tilt
			c.aim_point = s.ai_aim
		elif pressure < 2.6 and randf() < 0.6:
			var mate: Skater = g.best_pass_option(s)
			if mate:
				c.pass_pressed = true
				c.pass_hint = mate
	# drive to the slot, curling away from the nearest defender
	var target := goal - Vector2(att * 7.0, 0)
	if ahead < 1.0:
		target = Vector2(goal.x - att * 4.0, signf(me.y if me.y != 0.0 else 1.0) * 3.0)
	var opp: Skater = g.nearest_opponent(s.team, me)
	if opp and me.distance_to(_v2(opp.position)) < 4.0:
		target += (me - _v2(opp.position)).normalized() * 3.0
	_seek(s, target, 1.0, 20.0)
	var wobble := 0.25 + 0.25 * sin(g.time * 5.0 + s.number)
	c.blade_target = s.position + s.heading * 0.95 + s.right_vec() * wobble


static func _support(s: Skater, g: Node, owner: Skater) -> void:
	var att: int = g.attack_side(s.team)
	var o := _v2(owner.position)
	var others: Array = g.teammates(owner)
	var idx := others.find(s)
	var slot: Vector2
	if idx == 0:
		slot = Vector2(o.x + att * 5.0, -signf(o.y if absf(o.y) > 0.5 else 1.0) * 6.5)
	else:
		slot = Vector2(o.x - att * 6.0, o.y * 0.3)
	slot.x = clampf(slot.x, -Rink.GOAL_X + 3.0, Rink.GOAL_X - 3.0)
	slot.y = clampf(slot.y, -Rink.HALF_W + 2.0, Rink.HALF_W - 2.0)
	_seek(s, slot, 2.0, 12.0)
	s.ctrl.blade_target = s.position + (owner.position - s.position).normalized() * 1.0


static func _defend(s: Skater, g: Node, owner: Skater, dt: float) -> void:
	var c := s.ctrl
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	var me := _v2(s.position)
	var o := _v2(owner.position)
	var presser: Skater = g.nearest_skater(s.team, o)
	if presser == s:
		var dist := me.distance_to(o)
		var target := o + (my_goal - o).normalized() * 1.0 if dist > 3.0 else _v2(g.puck.position)
		_seek(s, target, 0.8, 8.0)
		c.blade_target = g.puck.position
		if dist < 1.8 and s.check_cd <= 0.0 and randf() < dt * 0.8:
			c.check = true
		elif dist < 1.6 and s.lift_cd <= 0.0 and randf() < dt * 1.0:
			c.lift = true
		return
	# mark an opponent who isn't carrying, staying goal-side
	var opps: Array = g.team_skaters(1 - s.team).filter(func(x): return x != owner)
	var mine: Array = g.team_skaters(s.team).filter(func(x): return x != presser)
	var mark: Skater = opps[mine.find(s) % opps.size()]
	var m := _v2(mark.position)
	_seek(s, m + (my_goal - m).normalized() * 2.0, 1.5, 10.0)
	c.blade_target = s.position + (mark.position - s.position).normalized()


static func _loose(s: Skater, g: Node) -> void:
	var c := s.ctrl
	var puck: Puck = g.puck
	var p := _v2(puck.position)
	var pv := _v2(puck.vel)
	if puck.pass_target == s and pv.length() > 1.0:
		# step into the passing lane
		var t := clampf((_v2(s.position) - p).dot(pv.normalized()) / maxf(pv.length(), 1.0), 0.0, 1.5)
		_seek(s, p + pv * t, 1.0, 30.0)
		c.blade_target = puck.position + puck.vel * 0.05
		return
	if g.nearest_skater(s.team, p) == s:
		_seek(s, p + pv * 0.25, 0.6, 6.0)
		c.blade_target = puck.position
		return
	var my_goal := Vector2(-g.attack_side(s.team) * Rink.GOAL_X, 0)
	var spot := p.lerp(my_goal, 0.4) + Vector2(0, 5.0 if s.number % 2 == 0 else -5.0)
	spot.y = clampf(spot.y, -Rink.HALF_W + 2.0, Rink.HALF_W - 2.0)
	_seek(s, spot, 2.0, 12.0)
