class_name OnIcePractice
extends OnIceSession
## Hockey practices with real drills (docs/world/ON_ICE.md 4).
##
## "peewee_practice" (minor_hockey): three sub-groups share the ice, toddlers
## 5-7, children 8-11 and teens 12-14, each with its nickname, in three zones
## split by black divider pads. The coaches (and a rink hand, or the owner
## through claim_setup()) carry the pads from the rack by the Zamboni room
## and lay them across the ice before the drills start. The youngest use
## only mini nets and light blue pucks, the middle group a mix, the oldest
## full-size nets. The younger groups run 3-4 stations and rotate between
## them on the whistle; the oldest run one team drill at a time.
##
## "team_practice" (high_school, pro_practice): one team on the full ice
## running the plan in data/world/on_ice.json, one drill after another; a
## zone drill runs in both ends at once; the 4-net drill only when 4 nets
## are out. Between drills everybody brings a puck to the next pile.
##
## "stick_and_puck": open ice, everyone with their own puck: laps,
## stickhandling and shooting on the open nets.
##
## Coaches wait at the Zamboni gate when the nets they need aren't out yet
## (nets_needed); the nets themselves are Mechanics' nets job.

const ROTATE_SECONDS := 420.0
const TEAM_DRILL_GATHER := 25.0

var groups: Array = []      # pee-wee: {id, nickname, zone, rect, kids, coaches, runs, budget, state, ...}
var zones := {}             # group index -> Rect2 (venue x, z)
var pads_done := false
var runs: Array = []        # every DrillRun live now
var team := {}
var plan: Array = []
var plan_i := -1
var setup_tasks: Array = [] # {kind, index, state, by}
var nets_waiting := false

var _pp := {}               # practice-phase state
var _cfg := {}
var _think_t := 0.0


func _spawn() -> void:
	match controller:
		"peewee_practice": _spawn_peewee()
		"team_practice": _spawn_team()
		_: _spawn_stick_and_puck()


# ================================================================ pee-wee

func _spawn_peewee() -> void:
	_cfg = OnIceData.section("peewee")
	var pads_x: Array = _cfg.get("pads_x", [-10.16, 10.16])
	var xs := [-Rink.HALF_L, float(pads_x[0]), float(pads_x[1]), Rink.HALF_L]
	var r := OnIceData.roster("peewee_practice")
	var cpg: Array = r.get("coaches_per_group", [2, 4])
	var fast := bool(ctx.get("fast", false)) or bool(ctx.get("pads_out", false))
	var gi := 0
	for gd in _cfg.get("groups", []):
		var zi := int(gd.get("zone", gi))
		var x0 := float(xs[zi]) + (IceGear.PAD_T + 0.05 if zi > 0 else 0.0)
		var x1 := float(xs[zi + 1]) - (IceGear.PAD_T + 0.05 if zi < 2 else 0.0)
		var rect := Rect2(x0, -Rink.HALF_W, x1 - x0, Rink.WIDTH)
		zones[gi] = rect
		var ages: Array = gd.get("ages", [5, 7])
		var cnt: Array = gd.get("count", [10, 16])
		var n := int(ctx.get("count", rng.randi_range(int(cnt[0]), int(cnt[1]))))
		var g := {"id": str(gd.id), "nickname": str(gd.get("nickname", gd.id)), "zone": zi, "rect": rect, "kids": [], "coaches": [],
			"runs": [], "budget": (gd.get("nets", {"full": 0, "mini": 4}) as Dictionary).duplicate(), "puck": str(gd.get("puck", "black")),
			"stations": int(gd.get("stations", 1)), "drills": gd.get("drills", []), "state": "warmup", "t": 0.0, "drill_i": 0, "rot": 0}
		for i in rng.randi_range(int(cpg[0]), int(cpg[1])):
			var c := add_skater("coach", rng.randi_range(28, 55), look_for("coach", 40), 0.7)
			c.group = gi
			c.pos = rect.get_center() + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-8.0, 8.0))
			c.box = rect
			g.coaches.append(c.id)
		for i in n:
			var age := rng.randi_range(int(ages[0]), int(ages[1]))
			var l := look_for("player", age)
			var s := add_skater("kid" if age < 8 else "player", age, l, clampf(rng.randf_range(0.15, 0.45) + (age - 5) * 0.06, 0.08, 0.9))
			s.group = gi
			s.max_speed = lerpf(2.0, 7.0, clampf((age - 5.0) / 10.0, 0.0, 1.0)) * lerpf(0.75, 1.1, s.skill)
			s.fall_rate = lerpf(0.03, 0.002, s.skill)
			s.box = rect
			s.pos = rect.get_center() + Vector2(rng.randf_range(-rect.size.x * 0.35, rect.size.x * 0.35), rng.randf_range(-9.0, 9.0))
			g.kids.append(s.id)
		groups.append(g)
		gi += 1
	# the pads: two lines of them across the ice, far line first
	var L := float(_cfg.get("pad_length", 4.3))
	var nper := maxi(1, roundi(Rink.WIDTH / L))
	L = Rink.WIDTH / nper  # pads butt end to end, board to board
	for li in 2:
		var x := float(pads_x[li])
		for k in nper:
			var z0 := -Rink.HALF_W + k * L
			var z1 := minf(z0 + L, Rink.HALF_W)
			var pi := gear.add_pad(Vector2(x, z0 + 0.02), Vector2(x, z1 - 0.02), fast)
			if not fast:
				var task := {"kind": "pad", "index": pi, "state": "open", "by": -1, "at": Vector2(x, (z0 + z1) * 0.5)}
				setup_tasks.append(task)
	pads_done = fast
	if not fast:
		for task: Dictionary in setup_tasks:
			setup_needed.emit(task)
		if int(ctx.get("staff", 0)) > 0:
			for i in int(ctx.staff):
				var e := add_skater("carrier", rng.randi_range(18, 30), look_for("employee", 22, {"skates": true}), 0.6)
				e.on_ice = false
				e.pos = rack_pads + Vector2(-0.8, 1.0 + i)
	phase = "setup" if not fast else "on"
	if fast:
		for k2 in groups.size():
			_start_group(k2, true)


## The owner (or another system) takes a setup job: a pad to lay out.
func claim_setup(by := "player") -> Dictionary:
	for task: Dictionary in setup_tasks:
		if task.state == "open":
			task.state = "claimed"
			task.by = by
			return task
	return {}


func complete_setup(task: Dictionary) -> void:
	if task.is_empty():
		return
	task.state = "done"
	if task.kind == "pad":
		gear.pads[int(task.index)].placed = true


func _carriers() -> Array:
	var out: Array = []
	for s: IceSkater in skaters:
		if s.role == "carrier":
			out.append(s)
	# the toddler and middle-group coaches help, one each; the teen coaches set up their own
	for gi in mini(2, groups.size()):
		var cs: Array = groups[gi].coaches
		if not cs.is_empty():
			out.append(by_id(cs[cs.size() - 1]))
	return out


func _pads_step() -> void:
	var all_done := true
	for task: Dictionary in setup_tasks:
		if task.state != "done":
			all_done = false
	if all_done:
		pads_done = true
		for s: IceSkater in _carriers():
			if s.role == "carrier":
				route(s, rack_pads + Vector2(-0.8, 1.5), 1.5)
			else:
				s.carry = ""
				s.box = zone_of(s)
				s.task = {}
		coach_whistle.emit(Vector3(0, 0, 0))
		return
	for s2: IceSkater in _carriers():
		if s2 == null or s2.down():
			continue
		var tk := s2.task
		if not tk.has("pad"):
			var job := claim_setup("npc:%d" % s2.id)
			if job.is_empty():
				# nothing left: go back to your group
				s2.box = zone_of(s2)
				if s2.role != "carrier":
					s2.go(zones.get(s2.group, Rect2()).get_center(), 2.0, 1.0)
				continue
			tk["pad"] = job
			tk["got"] = false
			s2.box = Rect2()
		var j: Dictionary = tk.pad
		if not tk.got:
			route(s2, rack_pads + Vector2(-0.9, 0.0), 3.0)
			if s2.pos.distance_to(rack_pads + Vector2(-0.9, 0.0)) < 1.0:
				tk.got = true
				s2.carry = "pad"
		else:
			var to: Vector2 = j.at + Vector2(0.45 * (1.0 if s2.pos.x > j.at.x else -1.0), 0.0)
			route(s2, to, 2.5)
			if s2.on_ice and s2.pos.distance_to(to) < 0.8:
				complete_setup(j)
				s2.carry = ""
				tk.erase("pad")


func _start_group(gi: int, fast: bool) -> void:
	var g: Dictionary = groups[gi]
	var nets := nets_out()
	var need: Dictionary = g.budget
	var have_full := int(nets.full) - _full_used_by_others(gi)
	if int(need.get("full", 0)) > maxi(have_full, 0) and not fast:
		g.state = "wait_nets"
		if not nets_waiting:
			nets_waiting = true
			nets_needed.emit(3, int(OnIceData.section("equipment").get("mini_nets", 8)))
		return
	g.state = "drills"
	g.t = 0.0
	var rect: Rect2 = g.rect
	var areas := _station_areas(rect, int(g.stations))
	var drills: Array = g.drills
	var kids: Array = g.kids
	var cs: Array = g.coaches
	var mirror: bool = rect.get_center().x < 0.0
	g.runs = []
	for k in areas.size():
		var id := str(drills[(int(g.drill_i) + k) % drills.size()])
		var def := OnIceData.drill(id)
		if def.is_empty():
			continue
		var run := DrillRun.new(self, def, areas[k], mirror)
		run.group = str(g.id)
		run.budget = g.budget
		run.net_size = "mini" if g.puck == "blue" else ("full" if g.puck == "black" else ("full" if k == 0 else "mini"))
		run.puck_blue = g.puck == "blue" or (g.puck == "mix" and k > 0)
		run.skill_scale = 0.6 if g.puck == "blue" else (0.8 if g.puck == "mix" else 1.0)
		run.coaches = [cs[k % cs.size()]]
		for i in kids.size():
			if i % areas.size() == k:
				run.players.append(kids[i])
		run.setup(fast)
		g.runs.append(run)
		runs.append(run)


func _full_used_by_others(gi: int) -> int:
	var n := 0
	for k in groups.size():
		if k != gi and groups[k].state == "drills":
			n += int(OnIceData.section("peewee").get("groups", [])[k].get("nets", {}).get("full", 0))
	return n


## 1 station: the whole zone. 3: three bands across the ice. 4: quarters.
func _station_areas(rect: Rect2, n: int) -> Array:
	var out: Array = []
	var m := 0.6
	if n <= 1:
		out.append(rect.grow(-m))
	elif n == 3:
		var h := rect.size.y / 3.0
		for k in 3:
			out.append(Rect2(rect.position.x + m, rect.position.y + k * h + m, rect.size.x - 2 * m, h - 2 * m))
	else:
		var w := rect.size.x * 0.5
		var h2 := rect.size.y * 0.5
		for k in 4:
			out.append(Rect2(rect.position.x + (k % 2) * w + m, rect.position.y + (k / 2) * h2 + m, w - 2 * m, h2 - 2 * m))
	return out


func _peewee_think(dt: float) -> void:
	if not pads_done:
		_pads_step()
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		g.t = float(g.t) + dt
		match str(g.state):
			"warmup", "wait_nets":
				_zone_laps(g)
				if pads_done and (g.state == "warmup" or fmod(float(g.t), 5.0) < dt):
					_start_group(gi, false)
				if g.state == "wait_nets":
					var c := by_id(g.coaches[0])
					if c:
						route(c, Vector2(29.0, 0.0), 2.5)  # at the Zamboni gate, waving for the nets
						c.pose_lock = PeopleArt.Pose.WAVE if c.at_target(1.0) else -1
			"drills":
				for run: DrillRun in g.runs:
					run.step(dt)
				var c2 := by_id(g.coaches[0])
				if c2 and c2.pose_lock == PeopleArt.Pose.WAVE:
					c2.pose_lock = -1
				if float(g.t) > ROTATE_SECONDS:
					g.t = 0.0
					_rotate(gi)


## Warm-up laps of their own zone while the pads go out.
func _zone_laps(g: Dictionary) -> void:
	var rect: Rect2 = g.rect
	var c := rect.get_center()
	for sid in g.kids:
		var s := by_id(sid)
		if s == null or s.down():
			continue
		var off := s.pos - c
		var ang := atan2(off.y, off.x) - 0.5
		s.go(c + Vector2(cos(ang) * rect.size.x * 0.34, sin(ang) * rect.size.y * 0.36), s.max_speed * 0.6, 1.0)
	for k in g.coaches.size():
		var cs := by_id(g.coaches[k])
		if cs and cs.task.is_empty() and cs.carry == "":
			cs.go(c + Vector2(0, -3.0 + 3.0 * k), 1.5, 0.8)


## Stations rotate: each group of kids moves on to the next station.
func _rotate(gi: int) -> void:
	var g: Dictionary = groups[gi]
	var rs: Array = g.runs
	if rs.size() <= 1:
		# one team drill: on to the next drill in their list
		for run: DrillRun in rs:
			run.finish()
			run.clear_gear(_park_spots())
			runs.erase(run)
		g.drill_i = int(g.drill_i) + 1
		_start_group(gi, true)
		coach_whistle.emit(Vector3(g.rect.get_center().x, 0, g.rect.get_center().y))
		return
	var lists: Array = []
	for run: DrillRun in rs:
		lists.append(run.players.duplicate())
	for k in rs.size():
		(rs[k] as DrillRun).reassign(lists[(k + rs.size() - 1) % rs.size()])
	coach_whistle.emit(Vector3(g.rect.get_center().x, 0, g.rect.get_center().y))


func _park_spots() -> Array:
	var out: Array = []
	for a in OnIceData.section("equipment").get("net_park", [[32.4, -5.4], [32.4, 5.4]]):
		out.append(OnIceData.v2(a))
	return out


func zone_of(s: IceSkater) -> Rect2:
	if controller == "peewee_practice" and s.role != "carrier":
		return zones.get(s.group, Rect2())
	return Rect2()


# ========================================================== team practice

func _spawn_team() -> void:
	var tp := OnIceData.section("team_practice")
	var teams_d: Array = tp.get("teams", [])
	if not teams_d.is_empty():
		var tid := str(ctx.get("team", ""))
		team = teams_d[0]
		for td in teams_d:
			if str(td.id) == tid:
				team = td
		if tid == "" and kind == "high_school" and rng.randf() < 0.35:
			team = teams_d[1 + rng.randi() % (teams_d.size() - 1)]  # a team renting the ice
	if kind == "pro_practice":
		team = {"id": "dukes", "name": "Duncannon Dukes", "colors": ["5c3d7a", "e8c547"]}
	plan = tp.get("plan", [])
	var r := OnIceData.roster("team_practice")
	var np := int(ctx.get("count", rng.randi_range(int(r.players[0]), int(r.players[1]))))
	var ages: Array = r.get("ages", [14, 18])
	var cols: Array = team.get("colors", ["2e7d4f", "c9a227"])
	var pro := kind == "pro_practice"
	for i in np:
		var age := rng.randi_range(19, 33) if pro else rng.randi_range(int(ages[0]), int(ages[1]))
		var s := add_skater("player", age, look_for("player", age, {"colors": [cols[0], cols[1]]}), rng.randf_range(0.75, 0.95) if pro else rng.randf_range(0.5, 0.82))
		s.max_speed = lerpf(6.5, 9.0, s.skill)
		s.accel = lerpf(3.0, 5.5, s.skill)
		s.fall_rate = 0.0005
		s.pos = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-9.0, 9.0))
	for i in int(r.goalies[0]):
		var g := add_skater("goalie", rng.randi_range(15, 18), look_for("goalie", 17, {"colors": [cols[0], cols[1]]}), rng.randf_range(0.55, 0.85))
		g.max_speed = 4.0
		g.radius = 0.42
		g.pos = Vector2(-20.0 + i * 40.0, 0.0)
	for i in rng.randi_range(int(r.coaches[0]), int(r.coaches[1])):
		var c := add_skater("coach", rng.randi_range(30, 60), look_for("coach", 45), 0.7)
		c.pos = Vector2(-2.0 + i * 2.0, 10.0)
	_pp = {"state": "gather", "t": 0.0}
	if ctx.get("fast", false):
		_next_team_drill(true)
	else:
		_pp.state = "first"


func _ids(role: String) -> Array:
	var out: Array = []
	for s: IceSkater in skaters:
		if s.role == role:
			out.append(s.id)
	return out


func _next_team_drill(fast: bool) -> void:
	for run: DrillRun in runs:
		run.finish()
		run.clear_gear(_park_spots())
	runs.clear()
	var nets := nets_out()
	var tries := 0
	while tries < plan.size():
		plan_i = (plan_i + 1) % maxi(plan.size(), 1)
		tries += 1
		var d := OnIceData.drill(str(plan[plan_i]))
		if d.is_empty():
			continue
		if (d.get("nets", []) as Array).size() > int(nets.full):
			continue  # the 4-net drill only when 4 nets are out
		if str(d.get("scope", "full")) == "station":
			continue
		_start_team_drill(d, fast)
		return


func _start_team_drill(d: Dictionary, fast: bool) -> void:
	var players := _ids("player")
	var goalies := _ids("goalie")
	var coaches := _ids("coach")
	var full := Rect2(-Rink.HALF_L, -Rink.HALF_W, Rink.LENGTH, Rink.WIDTH)
	var dumping := plan_i == 0 or fast
	if str(d.get("scope", "full")) == "zone":
		# both ends at once, half the team in each
		for side in 2:
			var area := Rect2(0.0 if side == 0 else -Rink.HALF_L, -Rink.HALF_W, Rink.HALF_L, Rink.WIDTH)
			var run := DrillRun.new(self, d, area, side == 1)
			run.group = "team"
			run.budget = {"full": 4, "mini": 0}
			run.dump = dumping
			run.skill_scale = 1.0
			for i in players.size():
				if i % 2 == side:
					run.players.append(players[i])
			if side < goalies.size():
				run.goalies = [goalies[side]]
			run.coaches = [coaches[side % coaches.size()]]
			run.setup(fast or plan_i > 0)
			runs.append(run)
	else:
		var run2 := DrillRun.new(self, d, full)
		run2.group = "team"
		run2.budget = {"full": 4, "mini": 0}
		run2.dump = dumping
		run2.players = players
		run2.goalies = goalies
		run2.coaches = coaches
		run2.setup(fast or plan_i > 0)
		runs.append(run2)
	_pp = {"state": "drill", "t": 0.0, "id": str(d.id)}
	var c := by_id(coaches[0]) if not coaches.is_empty() else null
	coach_whistle.emit(c.pos3() if c else Vector3.ZERO)


func _team_think(dt: float) -> void:
	_pp.t = float(_pp.t) + dt
	match str(_pp.state):
		"first":
			# the nets have to be out first; the coach carries the first bucket
			if int(nets_out().full) < 2:
				if fmod(float(_pp.t), 30.0) < dt:
					nets_needed.emit(2, 0)
				_free_skate()
				return
			_next_team_drill(false)
		"drill":
			for run: DrillRun in runs:
				run.step(dt)
			var mins := float(OnIceData.section("team_practice").get("drill_minutes", 6.0))
			if float(_pp.t) > mins * 60.0 * float(ctx.get("clock_scale", 1.0)):
				_pp = {"state": "gather", "t": 0.0}
				var c := by_id(_ids("coach")[0]) if not _ids("coach").is_empty() else null
				coach_whistle.emit(c.pos3() if c else Vector3.ZERO)
				for run2: DrillRun in runs:
					run2.finish()
		"gather":
			# everybody to the coach at centre ice for the next one
			var cs := _ids("coach")
			var c0 := by_id(cs[0]) if not cs.is_empty() else null
			if c0:
				c0.go(Vector2(0, 0), 2.5, 0.5)
				c0.pose_lock = PeopleArt.Pose.TALK if float(_pp.t) > 8.0 else -1
			var k := 0
			for sid in _ids("player"):
				var s := by_id(sid)
				if s:
					var ang := TAU * float(k) / 20.0
					s.go(Vector2(cos(ang), sin(ang)) * 3.2, s.max_speed * 0.5, 0.5)
					s.face = -Vector2(cos(ang), sin(ang))
					k += 1
			if float(_pp.t) > TEAM_DRILL_GATHER:
				if c0:
					c0.pose_lock = -1
				_next_team_drill(false)


func _free_skate() -> void:
	for s: IceSkater in skaters:
		if s.role == "player" and not s.down():
			var f := OnIcePublicSkate.flow(s.pos, 2.0 + float(s.id % 5))
			s.go(f[0] + f[1] * 4.0, s.max_speed * 0.55, 1.0)


# ========================================================== stick and puck

func _spawn_stick_and_puck() -> void:
	var r := OnIceData.roster("stick_and_puck")
	var n := int(ctx.get("count", rng.randi_range(int(r.players[0]), int(r.players[1]))))
	var ages: Array = r.get("ages", [10, 60])
	for side in 2:
		gear.add_net(Vector2((-1 if side == 0 else 1) * Rink.GOAL_X, 0), Vector2(1 if side == 0 else -1, 0), "full", "snp")
	for i in n:
		var age := rng.randi_range(int(ages[0]), int(ages[1]))
		var s := add_skater("player", age, look_for("player", age), rng.randf_range(0.3, 0.85))
		s.max_speed = lerpf(4.5, 8.0, s.skill)
		s.fall_rate = lerpf(0.004, 0.0, s.skill)
		s.pos = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-9.0, 9.0))
		var k := gear.add_puck(s.pos + Vector2(0.5, 0.0))
		gear.pucks[k].owner = s.id
		s.puck = k
		s.task = {"do": "laps", "until": rng.randf_range(10.0, 40.0)}
	phase = "on"


func _snp_think(_dt: float) -> void:
	for s: IceSkater in skaters:
		if s.down():
			continue
		var tk := s.task
		if t > float(tk.get("until", 0.0)):
			tk.do = ["laps", "handle", "shoot", "shoot", "rest"][rng.randi() % 5]
			tk.until = t + rng.randf_range(15.0, 45.0)
			tk.erase("spot")
			s.pose_lock = -1
		if s.puck < 0 and str(tk.do) != "rest":
			# go and get your puck back
			var near := gear.free_pucks_near(s.pos, 40.0)
			if not near.is_empty():
				s.catching = true
				s.go(gear.pucks[near[0]].pos, s.max_speed * 0.6, 0.2)
				continue
		match str(tk.do):
			"laps":
				var f := OnIcePublicSkate.flow(s.pos, 1.5 + float(s.id % 6))
				s.go(f[0] + f[1] * 4.0, s.max_speed * 0.6, 1.0)
			"handle":
				if not tk.has("spot"):
					tk.spot = Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-7.0, 7.0))
				var a := t * 0.9 + s.id
				s.go(tk.spot + Vector2(cos(a), sin(a * 1.3)) * 2.0, s.max_speed * 0.3, 0.5)
			"shoot":
				var ni := gear.nearest_net(s.pos, "snp")
				if ni >= 0:
					var n: Dictionary = gear.nets[ni]
					var from: Vector2 = n.pos + n.face * 8.0 + Vector2(0, float(s.id % 5 - 2) * 1.5)
					s.go(from, s.max_speed * 0.7, 1.0)
					if s.at_target(1.5) and s.puck >= 0:
						var side := Vector2(-n.face.y, n.face.x)
						var aim: Vector2 = n.pos + side * rng.randf_range(-0.8, 0.8)
						gear.release(s.puck, (aim - s.pos).normalized() * lerpf(12.0, 30.0, s.skill))
						s.puck = -1
						tk.until = t + rng.randf_range(4.0, 12.0)
					for p: IceGear.IcePuck in gear.pucks:
						if p.in_net == ni and rng.randf() < 0.01:
							gear.rake_net(ni, n.pos + n.face * 3.0)
			"rest":
				var b := Vector2(clampf(s.pos.x, -20.0, 20.0), 12.0 if s.pos.y > 0.0 else -12.0)
				s.go(b, 2.0, 0.6)
				s.face = -Rink.board_normal(b)


# ================================================================== think

func _think(dt: float) -> void:
	match controller:
		"peewee_practice": _peewee_think(dt)
		"team_practice": _team_think(dt)
		_: _snp_think(dt)


## Every drill running right now (tests, the debug overlay).
func live_runs() -> Array:
	return runs
