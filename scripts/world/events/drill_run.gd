class_name DrillRun
extends RefCounted
## One drill from data/world/drills.json running in an area of the ice with
## a group of players and a coach: the coach fetches the pylons and a bucket
## of pucks from the rack by the Zamboni doors and sets them out, players
## wait in their lines, go in waves along the drill's paths (passes, shots,
## stops, pivots), skate back to the end of their line and go again. A stray
## puck or skate that knocks a pylon over stops the drill: the coach blows
## the whistle, fixes it and play resumes.
##
##   var run := DrillRun.new(session, OnIceData.drill("two_on_one"), Rect2(-30.48, -12.95, 60.96, 25.9))
##   run.players = ids; run.coaches = [coach_id]
##   run.setup(fast)            # fast: gear already out (tests, a load)
##   run.step(dt)               # each frame; run.cycles counts full rounds
##
## `budget` limits the nets it may use ({"full": n, "mini": m}); a drill
## whose net size is "group" uses `net_size`.

var session: Node        # OnIceSession (a Node, so no reference cycle)
var def: Dictionary
var id := ""
var area := Rect2()
var mirror := false
var tag := ""
var players: Array = []  # skater ids
var coaches: Array = []  # skater ids; coaches[0] runs it
var goalies: Array = []  # skater ids put in the nets
var budget := {"full": 4, "mini": 8}
var net_size := "full"
var puck_blue := false
var group := ""          # who owns the nets it uses (a pee-wee group, a team)
var dump := true         # put a bucket of pucks out at setup
var skill_scale := 1.0

var state := "setup"     # setup, run, paused, done
var t := 0.0
var cycles := 0
var reps := 0
var nets: Array = []     # gear net indices
var pylon_ids: Array = []
var pile := Vector2.ZERO
var feeder := Vector2.INF

var _lanes: Array = []   # {start, queue_dir, path, puck, queue: [ids], done}
var _active: Array = []  # {sk, lane, step, wait, back_path, wave, t}
var _wave_t := 0.0
var _wave_no := 0
var _next_lane := 0
var _setup: Array = []   # the coach's setup jobs: {kind, at, i}
var _fix := -1           # pylon the coach is fixing
var _pause_t := 0.0
var _special := {}       # per-type state
var _own_v := {}         # skater id -> their lane v for "*"


func _init(s: Node, d: Dictionary, a: Rect2, mirror_ := false) -> void:
	session = s
	def = d
	id = str(d.get("id", ""))
	area = a
	mirror = mirror_
	tag = "%s@%d,%d" % [id, int(a.position.x), int(a.position.y)]


func type() -> String:
	return str(def.get("type", "lanes"))


## Area coordinates -> venue Vector2(x, z).
func at(u: float, v: float) -> Vector2:
	var c := area.get_center()
	return Vector2(c.x + (-u if mirror else u) * area.size.x * 0.5, c.y + v * area.size.y * 0.5)


func at_a(a: Variant, own_v := 0.0) -> Vector2:
	if a is Array and a.size() >= 2:
		var v := own_v if str(a[1]) == "*" else float(a[1])
		return at(float(a[0]), v)
	return area.get_center()


func dir_a(a: Variant) -> Vector2:
	var d := OnIceData.v2(a, Vector2(-1, 0))
	return Vector2(-d.x if mirror else d.x, d.y).normalized()


func _s(sid: int) -> IceSkater:
	return session.by_id(sid)


func _gear() -> IceGear:
	return session.gear


# ------------------------------------------------------------------- setup

## Puts the drill's nets out (within `budget`), plans the coach's setup (or
## does it at once when `fast`), sets up the lines.
func setup(fast := false) -> void:
	var g := _gear()
	for n in def.get("nets", []):
		var size := str(n.get("size", "full"))
		if size == "group":
			size = net_size
		if int(budget.get(size, 0)) <= 0 and not _parked(size):
			size = "mini" if size == "full" else "full"
		if int(budget.get(size, 0)) <= 0 and not _parked(size):
			continue
		var reuse := g.reuse_net(size, at_a(n.get("at", [0.8, 0.0])), dir_a(n.get("face", [-1, 0])), tag, group)
		if reuse >= 0:
			nets.append(reuse)
			continue
		budget[size] = int(budget[size]) - 1
		var ni := g.add_net(at_a(n.get("at", [0.8, 0.0])), dir_a(n.get("face", [-1, 0])), size, tag)
		g.nets[ni]["group"] = group
		nets.append(ni)
	pile = at_a(def.get("pile", [0.0, 0.8]))
	if def.has("feeder"):
		feeder = at_a(def.feeder)
	var npucks := int(def.get("pucks", 0))
	if type() in ["game", "battle"] and npucks == 0:
		npucks = 6
	for p in def.get("pylons", []):
		var k := g.add_pylon(at_a(p), tag, fast)
		pylon_ids.append(k)
		if not fast:
			_setup.append({"kind": "pylon", "i": k, "at": g.pylons[k].home})
	if npucks > 0 and not dump:
		npucks = 0 if g.free_pucks_near(pile, 6.0).size() >= mini(npucks, 8) else mini(npucks, 12)
	if npucks > 0:
		if fast:
			g.dump_bucket(pile, npucks, puck_blue)
		else:
			_setup.append({"kind": "bucket", "n": npucks, "at": pile})
	_build_lanes()
	_place_goalies()
	if fast or coaches.is_empty():
		if not fast and npucks > 0:
			g.dump_bucket(pile, npucks, puck_blue)
		for k in pylon_ids:
			g.pylons[k].placed = true
		_setup.clear()
		state = "run"


func _parked(size: String) -> bool:
	for n: Dictionary in _gear().nets:
		if n.get("parked", false) and n.size == size and str(n.get("group", "")) == group:
			return true
	return false


## New players for the same drill (pee-wee stations rotate): the lines
## start over with them.
func reassign(new_players: Array) -> void:
	finish()
	players = new_players.duplicate()
	_active.clear()
	_special.clear()
	_own_v.clear()
	_build_lanes()
	state = "run" if _setup.is_empty() else "setup"


## The drill's over: its nets go to the side and the coach stacks the pylons.
func clear_gear(park: Array) -> void:
	var g := _gear()
	for k in nets.size():
		var at: Vector2 = park[k % park.size()] if not park.is_empty() else Vector2(32.4, 5.4)
		g.park_net(nets[k], at + Vector2(0.0, float(k / maxi(park.size(), 1)) * 1.4))
	for k2 in pylon_ids:
		g.pylons[k2].placed = false
	nets.clear()
	pylon_ids.clear()


func _build_lanes() -> void:
	_lanes.clear()
	var lanes: Array = def.get("lanes", [])
	if type() != "lanes" or lanes.is_empty():
		return
	for l in lanes:
		_lanes.append({"start": at_a(l.get("start", [-0.8, 0.0])), "queue_dir": dir_a(l.get("queue", [-1, 0])),
			"path": l.get("path", []), "puck": bool(l.get("puck", false)), "queue": [], "done": 0,
			"spread": float(l.get("spread", 0.0)), "v": float(l.start[1]) if l.has("start") else 0.0})
	for i in players.size():
		var lane: Dictionary = _lanes[i % _lanes.size()]
		lane.queue.append(players[i])
	# an "all" lane spreads everyone along its start line
	for lane: Dictionary in _lanes:
		if lane.spread > 0.0:
			var q: Array = lane.queue
			for k in q.size():
				var v: float = -lane.spread + 2.0 * lane.spread * (float(k) + 0.5) / maxf(q.size(), 1)
				_own_v[q[k]] = v


func _place_goalies() -> void:
	var g := _gear()
	var k := 0
	for ni in nets:
		if k >= goalies.size():
			break
		if g.nets[ni].size != "full":
			continue
		g.nets[ni].goalie = goalies[k]
		var gs := _s(goalies[k])
		if gs:
			gs.task = {"net": ni}
		k += 1


# -------------------------------------------------------------------- step

func step(dt: float) -> void:
	t += dt
	_goalies(dt)
	match state:
		"setup":
			_do_setup(dt)
			_hold_lines()
		"run":
			if _check_pylons():
				return
			match type():
				"lanes": _lanes_step(dt)
				"battle": _battle_step(dt)
				"game": _game_step(dt)
				"tag": _tag_step(dt)
				"signal": _signal_step(dt)
				"circles": _circles_step(dt)
			_coach_idle()
		"paused":
			_fix_step(dt)


## Everyone stops where they are and leaves the gear be (end of the drill).
func finish() -> void:
	state = "done"
	for sid in players:
		var s := _s(sid)
		if s:
			s.backward = false
			s.catching = false
			s.box = session.zone_of(s)
	var g := _gear()
	for sid in players:
		var s2 := _s(sid)
		if s2 and s2.puck >= 0:
			g.release(s2.puck, s2.vel * 0.3)
			s2.puck = -1


func _coach() -> IceSkater:
	return _s(coaches[0]) if not coaches.is_empty() else null


func _do_setup(_dt: float) -> void:
	var c := _coach()
	if c == null:
		state = "run"
		return
	if _setup.is_empty():
		c.carry = ""
		state = "run"
		session.coach_whistle.emit(c.pos3())
		return
	var job: Dictionary = _setup[0]
	var rack: Vector2 = session.rack_gear
	if not job.get("got", false):
		_route(c, rack, 3.0)
		if c.pos.distance_to(rack) < 1.2:
			job["got"] = true
			c.carry = "pylons" if job.kind == "pylon" else "bucket"
		return
	_route(c, job.at, 3.2)
	if c.pos.distance_to(job.at) < 0.7:
		var g := _gear()
		if job.kind == "pylon":
			g.pylons[job.i].placed = true
			g.pylons[job.i].pos = g.pylons[job.i].home
		else:
			g.dump_bucket(job.at, int(job.n), puck_blue)
		_setup.pop_front()
		# a stack of pylons is carried all at once: straight to the next spot
		if not _setup.is_empty() and _setup[0].kind == job.kind and job.kind == "pylon":
			_setup[0]["got"] = true
		else:
			c.carry = ""


## Off the ice and back on goes through the Zamboni gate.
func _route(s: IceSkater, to: Vector2, spd: float) -> void:
	session.route(s, to, spd)


func _hold_lines() -> void:
	for lane: Dictionary in _lanes:
		var q: Array = lane.queue
		for k in q.size():
			var s := _s(q[k])
			if s and not s.down():
				s.go(_queue_spot(lane, k, s), 2.0, 0.3)
				s.face = -lane.queue_dir if lane.spread <= 0.0 else _toward_drill(lane)
	if _lanes.is_empty():
		var c := area.get_center()
		for k in players.size():
			var s2 := _s(players[k])
			if s2:
				var a := TAU * float(k) / maxf(players.size(), 1)
				s2.go(c + Vector2(cos(a), sin(a)) * minf(area.size.x, area.size.y) * 0.25, 1.5, 0.4)


func _toward_drill(lane: Dictionary) -> Vector2:
	var first: Variant = lane.path[0] if not lane.path.is_empty() else [0.0, 0.0]
	return (at_a(first) - lane.start).normalized()


func _queue_spot(lane: Dictionary, k: int, s: IceSkater) -> Vector2:
	if lane.spread > 0.0:
		var ov := float(_own_v.get(s.id, 0.0))
		return at(float(def.lanes[_lanes.find(lane)].start[0]), ov)
	return lane.start + lane.queue_dir * (0.95 * float(k))


func _check_pylons() -> bool:
	if pylon_ids.is_empty() or coaches.is_empty():
		return false
	var bad := _gear().pylons_out_of_place(tag)
	if bad.is_empty():
		return false
	_fix = bad[0]
	state = "paused"
	_pause_t = 0.0
	var c := _coach()
	session.coach_whistle.emit(c.pos3())
	for sid in players:
		var s := _s(sid)
		if s and not s.down():
			s.speed_want = 0.0
	return true


func _fix_step(dt: float) -> void:
	_pause_t += dt
	var c := _coach()
	var g := _gear()
	if c == null or _fix < 0:
		state = "run"
		return
	var pyl: IceGear.IcePylon = g.pylons[_fix]
	c.go(pyl.pos, 3.0, 0.45)
	if c.pos.distance_to(pyl.pos) < 0.55 or _pause_t > 25.0:
		g.fix_pylon(_fix)
		c.pose_lock = PeopleArt.Pose.WORK
		_special["unlock_at"] = t + 0.8
		var more := g.pylons_out_of_place(tag)
		_fix = more[0] if not more.is_empty() else -1
		if _fix < 0:
			state = "run"
			session.coach_whistle.emit(c.pos3())


func _coach_idle() -> void:
	var c := _coach()
	if c == null:
		return
	if c.pose_lock == PeopleArt.Pose.WORK and t > float(_special.get("unlock_at", 0.0)):
		c.pose_lock = -1
	if feeder != Vector2.INF:
		c.go(feeder, 2.5, 0.3)
		c.face = (area.get_center() - feeder).normalized()
	elif type() in ["lanes", "circles"]:
		var spot := at(0.0, 0.92)
		c.go(spot, 2.0, 0.5)
		c.face = (area.get_center() - spot).normalized()
	for k in range(1, coaches.size()):
		var c2 := _s(coaches[k])
		if c2:
			var spot2 := at(-0.5 + k * 0.4, -0.9)
			c2.go(spot2, 2.0, 0.5)
			c2.face = (area.get_center() - spot2).normalized()


func _goalies(_dt: float) -> void:
	var g := _gear()
	for ni in nets:
		var gid := int(g.nets[ni].goalie)
		if gid < 0:
			continue
		var gs := _s(gid)
		if gs == null:
			continue
		var n: Dictionary = g.nets[ni]
		var face: Vector2 = n.face
		var side := Vector2(-face.y, face.x)
		var puck := _nearest_puck(n.pos, 12.0)
		var lat := 0.0
		if puck != Vector2.INF:
			lat = clampf((puck - n.pos).dot(side) * 0.25, -0.6, 0.6)
		gs.go(n.pos + face * 0.45 + side * lat, 2.5, 0.08)
		gs.face = face
		gs.pose_lock = PeopleArt.Pose.WORK if puck != Vector2.INF and puck.distance_to(n.pos) < 9.0 else -1
		g.goalie_check(gs, ni)


func _nearest_puck(from: Vector2, r: float) -> Vector2:
	var best := Vector2.INF
	var bd := r
	for p: IceGear.IcePuck in _gear().pucks:
		if p.alive and p.in_net < 0:
			var d := p.pos.distance_to(from)
			if d < bd:
				bd = d
				best = p.pos
	return best


# ------------------------------------------------------------------ lanes

func _lanes_step(dt: float) -> void:
	if _lanes.is_empty():
		return
	_wave_t -= dt
	var wave := str(def.get("wave", "alternate"))
	if _wave_t <= 0.0:
		_wave_t = float(def.get("interval", 5.0))
		var who: Array = []
		match wave:
			"together":
				var ok := true
				for lane: Dictionary in _lanes:
					if lane.queue.is_empty() or _s(lane.queue[0]) == null or _s(lane.queue[0]).down() or _s(lane.queue[0]).pos.distance_to(_queue_spot(lane, 0, _s(lane.queue[0]))) > 3.0:
						ok = false
				if ok:
					for li in _lanes.size():
						who.append([li, _lanes[li].queue.pop_front()])
				else:
					_wave_t = 0.5
			"all":
				if _active.is_empty():
					for li in _lanes.size():
						for sid in _lanes[li].queue:
							who.append([li, sid])
						_lanes[li].queue.clear()
				else:
					_wave_t = 1.0
			_:
				for _tries in _lanes.size():
					var li2 := _next_lane % _lanes.size()
					_next_lane += 1
					if not _lanes[li2].queue.is_empty():
						who.append([li2, _lanes[li2].queue.pop_front()])
						break
		if not who.is_empty():
			_wave_no += 1
			if wave == "all":
				session.coach_whistle.emit(_coach().pos3() if _coach() else Vector3.ZERO)
		for w in who:
			var s := _s(w[1])
			if s == null:
				continue
			var e := {"sk": s.id, "lane": w[0], "step": 0, "wait": 0.0, "wave": _wave_no, "t": 0.0, "back_path": []}
			_active.append(e)
			s.backward = false
			s.face = Vector2.ZERO
			if _lanes[w[0]].puck and s.puck < 0:
				_grab_puck(s, 3.5)
	var gone: Array = []
	for e: Dictionary in _active:
		var s2 := _s(e.sk)
		if s2 == null:
			gone.append(e)
			continue
		e.t += dt
		if _follow(e, s2, dt):
			gone.append(e)
	for e in gone:
		_active.erase(e)
	_hold_lines()
	var m := 1 << 30
	for lane: Dictionary in _lanes:
		m = mini(m, int(lane.done))
	cycles = m


## Returns true when the skater is back in a line.
func _follow(e: Dictionary, s: IceSkater, dt: float) -> bool:
	var lane: Dictionary = _lanes[e.lane]
	var path: Array = lane.path
	if s.down():
		return false
	if e.wait > 0.0:
		e.wait -= dt
		return false
	if not e.back_path.is_empty():
		var to: Vector2 = e.back_path[0]
		s.go(to, s.max_speed * 0.55, 0.9)
		s.backward = false
		if s.at_target(1.0):
			e.back_path.pop_front()
			if e.back_path.is_empty():
				lane.queue.append(s.id)
				return true
		return false
	if e.step >= path.size() or e.t > 30.0:
		_end_rep(e, s, lane)
		return false
	var wp: Array = path[e.step]
	var acts := (str(wp[2]) if wp.size() > 2 else "").split("+", false)
	var own := float(_own_v.get(s.id, lane.v))
	var to2 := at_a(wp, own)
	var spd := s.max_speed * 0.8 * skill_scale
	if "fast" in acts:
		spd = s.max_speed
	elif "slow" in acts:
		spd = s.max_speed * 0.45
	s.backward = "back" in acts
	if s.backward:
		spd = minf(spd, s.max_speed * 0.6)
	if "catch" in acts and s.puck < 0:
		s.catching = true
	var exact := "stop" in acts or "pivot" in acts or "mohawk" in acts or "shoot" in acts or "pass_next" in acts or "call" in acts or "take" in acts or "pass_coach" in acts
	s.go(to2, spd, 0.6 if exact else 1.1)
	if "cross" in acts:
		s.phase = fmod(s.phase + dt * 0.6, 1.0)  # quicker feet
	if not s.at_target():
		return false
	# arrived: do the thing
	for a in acts:
		match a:
			"stop":
				session.hockey_stop(s)
				e.wait = 0.35
			"pivot", "mohawk":
				s.backward = not s.backward
			"shoot":
				_shoot(s)
			"pass_next":
				_pass_next(e, s)
			"pass_coach":
				if s.puck >= 0 and feeder != Vector2.INF:
					var c := _coach()
					if c:
						c.catching = true
					_pass(s, feeder, 9.0)
			"call":
				_feed(s)
			"take":
				_grab_puck(s, 3.0)
			_:
				if a.begins_with("wait:"):
					e.wait = a.trim_prefix("wait:").to_float()
	e.step += 1
	return false


func _end_rep(e: Dictionary, s: IceSkater, lane: Dictionary) -> void:
	s.catching = false
	s.backward = false
	if s.puck >= 0:
		# leave the puck by the pile on the way back
		_gear().release(s.puck, (pile - s.pos).normalized() * minf(s.pos.distance_to(pile) * 0.9, 10.0))
		s.puck = -1
	lane.done = int(lane.done) + 1
	reps += 1
	# back along the boards on the near side to the end of the line
	var end := _queue_spot(lane, lane.queue.size(), s)
	var side := signf(s.pos.y - area.get_center().y)
	if side == 0.0:
		side = 1.0
	var rail := Vector2(s.pos.x, area.get_center().y + side * area.size.y * 0.42)
	var rail2 := Vector2(end.x, rail.y)
	e.back_path = [rail, rail2, end] if lane.spread <= 0.0 else [end]


func _grab_puck(s: IceSkater, r: float) -> void:
	var g := _gear()
	var near := g.free_pucks_near(s.pos, r)
	if near.is_empty():
		near = g.free_pucks_near(pile, 3.0)
		if near.is_empty() or s.pos.distance_to(pile) > 12.0:
			return
	var k: int = near[0]
	g.pucks[k].owner = s.id
	g.pucks[k].last_touch = s.id
	s.puck = k


func shot_speed(s: IceSkater) -> float:
	var kid := clampf((float(s.age) - 5.0) / 12.0, 0.0, 1.0)
	return lerpf(5.0, 12.0, kid) + lerpf(0.0, 18.0, kid * s.skill) * skill_scale


func _shoot(s: IceSkater) -> void:
	if s.puck < 0:
		return
	var g := _gear()
	var ni := -1
	var bd := INF
	for k in nets:
		var d := s.pos.distance_to(g.nets[k].pos)
		if d < bd:
			bd = d
			ni = k
	var aim := at(1.0, 0.0)
	if ni >= 0:
		var n: Dictionary = g.nets[ni]
		var side := Vector2(-n.face.y, n.face.x)
		aim = n.pos + side * g.rng.randf_range(-1.0, 1.0) * float(n.half_w) * 0.8
	var dir := (aim - s.pos).normalized().rotated(g.rng.randf_range(-0.06, 0.06) * (1.5 - s.skill))
	g.release(s.puck, dir * shot_speed(s))
	s.puck = -1
	session.shot_taken(s)


func _pass(s: IceSkater, to: Vector2, spd: float) -> void:
	if s.puck < 0:
		return
	var g := _gear()
	var d := to - s.pos
	g.release(s.puck, d.normalized() * clampf(d.length() * 1.5, 4.0, spd * skill_scale + 4.0))
	s.puck = -1


func _pass_next(e: Dictionary, s: IceSkater) -> void:
	if s.puck < 0:
		return
	var n := _lanes.size()
	for k in range(1, n):
		var li := (int(e.lane) + k) % n
		for o: Dictionary in _active:
			if int(o.lane) == li and int(o.wave) == int(e.wave):
				var r := _s(o.sk)
				if r and not r.down():
					r.catching = true
					_pass(s, r.pos + r.vel * 0.55, 16.0)
					return
	# nobody to pass to: carry on with it


func _feed(s: IceSkater) -> void:
	var c := _coach()
	var g := _gear()
	var from := feeder if feeder != Vector2.INF else pile
	var near := g.free_pucks_near(from, 3.5)
	if c and c.puck >= 0:
		near = [c.puck]
		c.puck = -1
	if near.is_empty():
		return
	var k: int = near[0]
	var p: IceGear.IcePuck = g.pucks[k]
	p.owner = -1
	if c:
		p.pos = c.pos + (s.pos - c.pos).normalized() * (c.radius + 0.4)
	var lead := s.pos + s.vel * 0.7
	var d := lead - p.pos
	s.catching = true
	g.release(k, d.normalized() * clampf(d.length() * 1.4, 5.0, 17.0))


# ----------------------------------------------------------------- battle

func _battle_step(dt: float) -> void:
	var b := _special
	if not b.has("queue"):
		b["queue"] = players.duplicate()
		b["phase"] = "idle"
	var q: Array = b.queue
	var qdir := dir_a(def.get("queue", [-1, 0]))
	var line_at := at_a(def.get("start_a", [-0.6, 0.0])) + qdir * 2.0
	for k in q.size():
		var s := _s(q[k])
		if s and not s.down():
			s.go(line_at + qdir * 0.95 * k + Vector2(0, 0.0), 2.0, 0.3)
			s.face = -qdir
	match str(b.phase):
		"idle":
			if q.size() >= 2:
				b["a"] = q.pop_front()
				b["b"] = q.pop_front()
				b["phase"] = "set"
				b["t"] = 0.0
		"set":
			b.t = float(b.t) + dt
			var a := _s(b.a)
			var bb := _s(b.b)
			if a == null or bb == null:
				b.phase = "idle"
				return
			a.go(at_a(def.get("start_a")), 2.5, 0.4)
			bb.go(at_a(def.get("start_b")), 2.5, 0.4)
			bb.face = (a.pos - bb.pos).normalized()
			if float(b.t) > 3.0 or (a.at_target(0.6) and bb.at_target(0.6) and float(b.t) > 1.2):
				b.phase = "go"
				b.t = 0.0
				session.coach_whistle.emit(a.pos3())
				if def.get("attacker_puck", false):
					_grab_puck(a, 4.0)
					b["att"] = b.a
				elif def.has("dump_to"):
					_dump(at_a(def.dump_to))
		"go":
			b.t = float(b.t) + dt
			var a2 := _s(b.a)
			var b2 := _s(b.b)
			if a2 == null or b2 == null:
				b.phase = "idle"
				return
			var carrier: IceSkater = null
			for s3: IceSkater in [a2, b2]:
				if s3.puck >= 0:
					carrier = s3
			var g := _gear()
			var net_pos: Vector2 = g.nets[nets[0]].pos if not nets.is_empty() else at(0.8, 0.0)
			var net_face: Vector2 = g.nets[nets[0]].face if not nets.is_empty() else Vector2(-1, 0)
			if carrier == null:
				var loose := _nearest_puck(area.get_center(), 40.0)
				for s4: IceSkater in [a2, b2]:
					s4.catching = true
					if loose != Vector2.INF:
						s4.go(loose, s4.max_speed * 0.95, 0.2)
			else:
				var def_s: IceSkater = b2 if carrier == a2 else a2
				carrier.catching = false
				def_s.catching = true
				carrier.go(net_pos + net_face * 2.0, carrier.max_speed * 0.85, 0.8)
				def_s.go(carrier.pos + (net_pos - carrier.pos).normalized() * 0.8, def_s.max_speed, 0.1)
				if def_s.pos.distance_to(carrier.pos) < def_s.radius + carrier.radius + 0.3:
					b["press"] = float(b.get("press", 0.0)) + dt
					if float(b.press) > 1.1 and g.rng.randf() < 0.5 * def_s.skill * dt * 10.0:
						g.release(carrier.puck, carrier.vel + Vector2(g.rng.randf_range(-3, 3), g.rng.randf_range(-3, 3)))
						carrier.puck = -1
						b.press = 0.0
						session.bump(carrier, def_s, 2.0)
				if carrier.pos.distance_to(net_pos) < 6.0:
					_shoot(carrier)
					b.t = 99.0
			if float(b.t) > float(def.get("seconds", 10.0)):
				for s5: IceSkater in [a2, b2]:
					s5.catching = false
					if s5.puck >= 0:
						g.release(s5.puck, (pile - s5.pos).normalized() * 6.0)
						s5.puck = -1
				q.append(b.a)
				q.append(b.b)
				reps += 1
				b.phase = "idle"
				cycles = (reps * 2) / maxi(players.size(), 2)


func _dump(to: Vector2) -> void:
	var c := _coach()
	var g := _gear()
	var from := feeder if feeder != Vector2.INF else pile
	var near := g.free_pucks_near(from, 4.0)
	if near.is_empty():
		near = g.free_pucks_near(area.get_center(), 30.0)
	if near.is_empty():
		return
	var k: int = near[0]
	if c:
		g.pucks[k].pos = c.pos + (to - c.pos).normalized() * (c.radius + 0.4)
	var d: Vector2 = to - g.pucks[k].pos
	g.release(k, d.normalized() * clampf(d.length() * 1.1, 6.0, 20.0))


# -------------------------------------------------------------------- game

func _game_step(dt: float) -> void:
	var gm := _special
	var g := _gear()
	if not gm.has("fields"):
		_game_init()
	gm.t = float(gm.t) + dt
	gm.think = float(gm.get("think", 0.0)) - dt
	var think := float(gm.think) <= 0.0
	if think:
		gm.think = 0.2
	for f: Dictionary in gm.fields:
		if f.puck < 0 or not g.pucks[f.puck].alive:
			var near := g.free_pucks_near(f.center, 30.0)
			if near.is_empty():
				near = g.free_pucks_near(pile, 6.0)
			if near.is_empty():
				f.puck = g.add_puck(f.center, puck_blue)
			else:
				f.puck = near[0]
		var p: IceGear.IcePuck = g.pucks[f.puck]
		if p.in_net >= 0:
			g.rake_net(p.in_net, f.center)
			session.coach_whistle.emit(Vector3(p.pos.x, 0, p.pos.y))
		if not think:
			continue
		for team in 2:
			var mine: Array = f.teams[team]
			var opp_net: int = f.nets[1 - team] if f.nets.size() > 1 else -1
			var own_net: int = f.nets[team] if f.nets.size() > 1 else -1
			var target_net: Vector2 = g.nets[opp_net].pos if opp_net >= 0 else f.center + Vector2(f.half.x * (1 if team == 0 else -1), 0)
			var tface: Vector2 = g.nets[opp_net].face if opp_net >= 0 else Vector2(-1 if team == 0 else 1, 0)
			var home: Vector2 = g.nets[own_net].pos if own_net >= 0 else f.center - (target_net - f.center)
			var carrier: IceSkater = null
			for sid in mine:
				var s := _s(sid)
				if s and s.puck == f.puck and p.owner == s.id:
					carrier = s
			var chaser := -1
			if carrier == null and p.owner < 0:
				var bd := INF
				for sid in mine:
					var s2 := _s(sid)
					if s2 and not s2.down() and s2.pos.distance_to(p.pos) < bd:
						bd = s2.pos.distance_to(p.pos)
						chaser = sid
			for k in mine.size():
				var s3 := _s(mine[k])
				if s3 == null or s3.down():
					continue
				s3.box = f.box
				if s3 == carrier:
					s3.catching = false
					s3.go(target_net + tface * 1.8, s3.max_speed * 0.75, 0.6)
					if s3.pos.distance_to(target_net) < 6.5 and g.rng.randf() < 0.45:
						_shoot_at(s3, opp_net)
					elif g.rng.randf() < 0.08:
						var mate := _s(mine[(k + 1) % mine.size()])
						if mate and mate != s3:
							mate.catching = true
							_pass(s3, mate.pos + mate.vel * 0.5, 12.0)
				elif mine[k] == chaser or (p.owner >= 0 and carrier == null and k == 0):
					s3.catching = true
					s3.go(p.pos, s3.max_speed * 0.9, 0.15)
					var other := _s(p.owner) if p.owner >= 0 else null
					if other and other.pos.distance_to(s3.pos) < other.radius + s3.radius + 0.35 and g.rng.randf() < 0.12 * s3.skill + 0.04:
						g.release(other.puck, other.vel * 0.5 + (s3.pos - other.pos).normalized() * -2.0)
						other.puck = -1
				else:
					s3.catching = carrier == null
					var lanev: float = (float(k) - (mine.size() - 1) * 0.5) * f.half.y * 0.6
					var side := Vector2(-tface.y, tface.x)
					var base := (p.pos + target_net) * 0.5 if carrier else (p.pos + home) * 0.5
					s3.go(base + side * lanev, s3.max_speed * 0.6, 0.6)
		# line change on the whistle
		if float(gm.t) > float(def.get("shift", 40.0)) * float(gm.shift + 1):
			gm.shift = int(gm.shift) + 1
			cycles = int(gm.shift)
			session.coach_whistle.emit(Vector3(f.center.x, 0, f.center.y))
			_swap_lines(f)


func _game_init() -> void:
	var gm := _special
	var g := _gear()
	gm["t"] = 0.0
	gm["shift"] = 0
	var fields: Array = def.get("fields", [{"u": [-1.0, 1.0], "nets": [0, 1]}])
	var per := int(def.get("per_side", 3))
	var pool := players.duplicate()
	gm["fields"] = []
	gm["bench"] = []
	for fd in fields:
		var u: Array = fd.get("u", [-1.0, 1.0])
		var a := at(float(u[0]), -0.95)
		var b := at(float(u[1]), 0.95)
		var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		var fnets: Array = []
		for ni in fd.get("nets", [0, 1]):
			if int(ni) < nets.size():
				fnets.append(nets[int(ni)])
		var teams := [[], []]
		for side in 2:
			for k in per:
				if not pool.is_empty():
					teams[side].append(pool.pop_front())
		gm.fields.append({"box": box, "center": box.get_center(), "half": box.size * 0.5, "nets": fnets, "teams": teams, "puck": -1})
	gm.bench = pool
	for sid in players:
		var s := _s(sid)
		if s:
			s.team = -1
	for f: Dictionary in gm.fields:
		for side in 2:
			for sid in f.teams[side]:
				var s2 := _s(sid)
				if s2:
					s2.team = side
	if not pile_ok():
		g.dump_bucket(pile, 4, puck_blue)


func pile_ok() -> bool:
	return not _gear().free_pucks_near(pile, 4.0).is_empty()


func _shoot_at(s: IceSkater, net: int) -> void:
	if s.puck < 0:
		return
	var g := _gear()
	if net < 0:
		_pass(s, s.pos + s.forward() * 6.0, 10.0)
		return
	var n: Dictionary = g.nets[net]
	var side := Vector2(-n.face.y, n.face.x)
	var aim: Vector2 = n.pos + side * g.rng.randf_range(-0.8, 0.8) * float(n.half_w)
	g.release(s.puck, (aim - s.pos).normalized() * shot_speed(s))
	s.puck = -1
	session.shot_taken(s)


## Waiting players come on and the tired ones go to the side of the field.
func _swap_lines(f: Dictionary) -> void:
	var gm := _special
	var bench: Array = gm.bench
	if bench.is_empty():
		return
	for side in 2:
		var team: Array = f.teams[side]
		var n := mini(team.size(), bench.size() / 2 + bench.size() % 2)
		for k in n:
			if bench.is_empty():
				break
			var out_id: int = team[k]
			var in_id: int = bench.pop_front()
			team[k] = in_id
			bench.append(out_id)
			var so := _s(out_id)
			if so:
				if so.puck >= 0:
					_gear().release(so.puck, Vector2.ZERO)
					so.puck = -1
				so.team = -1
				so.catching = false
			var si := _s(in_id)
			if si:
				si.team = side
	# the bench waits along the side of the area
	for k in bench.size():
		var sb := _s(bench[k])
		if sb:
			sb.box = session.zone_of(sb)
			sb.go(at(-0.8 + 1.6 * float(k) / maxf(bench.size(), 1), 0.92), 2.0, 0.4)


# --------------------------------------------------------------------- tag

func _tag_step(dt: float) -> void:
	var tg := _special
	if not tg.has("sharks"):
		tg["sharks"] = []
		tg["side"] = -1.0
		tg["phase"] = "line"
		tg["t"] = 0.0
		var ns := maxi(1, players.size() / 6)
		for k in ns:
			tg.sharks.append(players[k])
	tg.t = float(tg.t) + dt
	var side: float = tg.side
	var minnows: Array = players.filter(func(x: int) -> bool: return not x in tg.sharks)
	match str(tg.phase):
		"line":
			for k in minnows.size():
				var s := _s(minnows[k])
				if s:
					s.go(at(0.8 * side, -0.8 + 1.6 * (float(k) + 0.5) / maxf(minnows.size(), 1)), 1.8, 0.3)
			for k in tg.sharks.size():
				var sh := _s(tg.sharks[k])
				if sh:
					sh.go(at(0.0, -0.4 + 0.8 * float(k) / maxf(tg.sharks.size(), 1)), 1.8, 0.3)
			if float(tg.t) > 4.0:
				tg.phase = "go"
				tg.t = 0.0
				var c := _coach()
				session.coach_whistle.emit(c.pos3() if c else Vector3(area.get_center().x, 0, area.get_center().y))
		"go":
			var all_over := true
			for k in minnows.size():
				var s2 := _s(minnows[k])
				if s2 == null:
					continue
				var goal := at(-0.8 * side, -0.8 + 1.6 * (float(k) + 0.5) / maxf(minnows.size(), 1))
				s2.go(goal, s2.max_speed * 0.85, 0.5)
				if not s2.at_target(0.9):
					all_over = false
			var sharks_now: Array = (tg.sharks as Array).duplicate()
			for sid in sharks_now:
				var sh2 := _s(sid)
				if sh2 == null:
					continue
				var best: IceSkater = null
				var bd := INF
				for mid in minnows:
					var m := _s(mid)
					if m and not m.id in tg.sharks and m.pos.distance_to(sh2.pos) < bd and absf(m.pos.x - at(-0.8 * side, 0).x) > 1.0:
						bd = m.pos.distance_to(sh2.pos)
						best = m
				if best:
					sh2.go(best.pos + best.vel * 0.4, sh2.max_speed * 0.8, 0.1)
					if bd < sh2.radius + best.radius + 0.12:
						tg.sharks.append(best.id)  # tagged!
						session.crowd_reaction.emit("giggle", 0.2)
			if all_over or float(tg.t) > float(def.get("seconds", 30.0)):
				tg.side = -side
				tg.phase = "line"
				tg.t = 0.0
				reps += 1
				cycles = reps
				if minnows.size() <= 1:
					tg.sharks = [players[g_rand(players.size())]]


func g_rand(n: int) -> int:
	return _gear().rng.randi() % maxi(n, 1)


# ------------------------------------------------------------------ signal

func _signal_step(dt: float) -> void:
	var sg := _special
	if not sg.has("phase"):
		sg["phase"] = "line"
		sg["side"] = -1.0
		sg["t"] = 0.0
		sg["light"] = 0.0
	sg.t = float(sg.t) + dt
	var side: float = sg.side
	var c := _coach()
	if c:
		c.go(at(0.92 * -side, 0.0), 2.0, 0.4)
		c.face = Vector2(side * (-1 if mirror else 1), 0)
	match str(sg.phase):
		"line":
			for k in players.size():
				var s := _s(players[k])
				if s:
					s.go(at(0.8 * side, -0.8 + 1.6 * (float(k) + 0.5) / maxf(players.size(), 1)), 1.8, 0.3)
			if float(sg.t) > 3.5:
				sg.phase = "green"
				sg.t = 0.0
				sg.light = _gear().rng.randf_range(2.0, 4.0)
				session.coach_whistle.emit(c.pos3() if c else Vector3.ZERO)
		"green", "red":
			var green: bool = sg.phase == "green"
			var arrived := true
			for k in players.size():
				var s2 := _s(players[k])
				if s2 == null:
					continue
				var goal := at(-0.8 * side, -0.8 + 1.6 * (float(k) + 0.5) / maxf(players.size(), 1))
				if green:
					s2.go(goal, s2.max_speed * 0.8, 0.6)
				else:
					s2.speed_want = 0.0
				if not s2.at_target(1.0) and s2.pos.distance_to(goal) > 1.0:
					arrived = false
			if float(sg.t) > float(sg.light):
				sg.t = 0.0
				sg.phase = "red" if green else "green"
				sg.light = _gear().rng.randf_range(1.5, 3.0) if green else _gear().rng.randf_range(2.0, 4.0)
				session.coach_whistle.emit(c.pos3() if c else Vector3.ZERO)
				if green:
					# stopping fast on little legs
					for sid in players:
						var s3 := _s(sid)
						if s3 and s3.vel.length() > 1.0 and _gear().rng.randf() < 0.3 * (1.0 - s3.skill):
							s3.fall(_gear().rng)
							session.on_fell(s3)
			if arrived:
				sg.side = -side
				sg.phase = "line"
				sg.t = 0.0
				reps += 1
				cycles = reps


# ----------------------------------------------------------------- circles

func _circles_step(dt: float) -> void:
	var cs := _special
	var centres: Array = def.get("circles", [[0.0, 0.0]])
	if not cs.has("t"):
		cs["t"] = 0.0
		cs["dir"] = 1.0
		cs["shift"] = 0
		if def.get("puck", false):
			for sid in players:
				var s := _s(sid)
				if s and s.puck < 0:
					_grab_puck(s, 40.0)
	cs.t = float(cs.t) + dt
	var r := float(def.get("radius", 4.2))
	var dirv: float = cs.dir
	for k in players.size():
		var s2 := _s(players[k])
		if s2 == null or s2.down():
			continue
		var ci := (k + (int(cs.shift) if def.get("move", false) else 0)) % centres.size()
		var c := at_a(centres[ci])
		var off := s2.pos - c
		if off.length() < 0.1:
			off = Vector2(1, 0)
		var ang := atan2(off.y, off.x) + dirv * 1.0
		var rr := r + (float(k % 3) - 1.0) * 0.6
		s2.go(c + Vector2(cos(ang), sin(ang)) * rr, s2.max_speed * 0.75, 0.3)
	var sw := float(def.get("switch", 10.0))
	if float(cs.t) > sw * float(int(cs.shift) + 1):
		cs.shift = int(cs.shift) + 1
		var c2 := _coach()
		session.coach_whistle.emit(c2.pos3() if c2 else Vector3.ZERO)
		if not def.get("move", false):
			cs.dir = -dirv
	if float(cs.t) >= float(def.get("seconds", 40.0)) * float(cycles + 1):
		cycles += 1
		reps += 1
