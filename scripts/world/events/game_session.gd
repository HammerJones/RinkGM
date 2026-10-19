class_name OnIceGame
extends OnIceSession
## Ambient hockey for games the player isn't in, seen from the stands while
## they walk around (docs/world/ON_ICE.md 6). Not the match engine: a light
## five-on-five with goalies, two refs, line changes through the bench
## gates, shots, saves, goals and whistles.
##
## The five-minute warm-up starts once the nets are out (Mechanics' nets
## job: OnIceSession.nets_out()), a bucket of pucks is on the ice (a player
## carries it out from the bench) and the Zamboni doors are shut (the venue's
## "Bay rink door", or sim.get("zamboni_doors_closed")). Until then the
## teams wait on their benches.
##
## PLACEHOLDER(Mechanics): the clock and rules. If a global class LeagueRules
## with a static for_event(kind) exists its dictionary is used (period
## minutes, periods); otherwise data/world/on_ice.json "game" (20-minute
## running-clock periods, no overtime).

var teams: Array = []        # {name, colors, skaters, goalies, on, bench, gate, dir}
var refs: Array = []
var score := [0, 0]
var period := 0
var clock := 0.0             # seconds left in the period
var game_phase := "waiting"  # waiting, bucket, warmup, faceoff, play, goal, stoppage, intermission, final
var waiting_for := []        # what the warm-up is waiting on
var puck := -1
var rules := {}
var per_side := 5
var phase_t := 0.0
var shots := [0, 0]

var _think_t := 0.0
var _bucket_by := -1
var _bucket_prop := -1
var _shift_t := [0.0, 0.0]
var _faceoff_at := Vector2.ZERO
var _nets := [-1, -1]        # net at -X, net at +X
var _cfg := {}


func _spawn() -> void:
	_cfg = OnIceData.section("game")
	rules = _rules()
	crowd_falls = true
	var r := OnIceData.roster(controller if controller != "broomball" else "broomball")
	per_side = int(r.get("per_side", 5))
	var nplayers := int(ctx.get("count", int(r.get("players", [24, 24])[0])))
	var ngoalies := int(r.get("goalies", [2, 2])[0])
	var ages: Array = r.get("ages", [19, 45])
	var names: Array = ctx.get("teams", ["Home", "Visitors"])
	var cols: Array = ctx.get("colors", [["c8191e", "eeeeea"], ["1f4f9a", "e8c547"]])
	for side in 2:
		var bench_x := -7.0 if side == 0 else 7.0
		teams.append({"name": str(names[side]), "colors": cols[side], "skaters": [], "goalies": [], "on": [],
			"bench": Vector2(bench_x, -14.05), "gate": "home_bench" if side == 0 else "away_bench", "dir": 1.0 if side == 0 else -1.0})
	for i in nplayers:
		var side2 := i % 2
		var age := rng.randi_range(int(ages[0]), int(ages[1]))
		var s := _player(side2, age, "player")
		teams[side2].skaters.append(s.id)
	for i in ngoalies:
		var side3 := i % 2
		var g := _player(side3, rng.randi_range(int(ages[0]), int(ages[1])), "goalie")
		teams[side3].goalies.append(g.id)
	var nrefs := int(r.get("refs", [2, 2])[0])
	for i in nrefs:
		var rf := add_skater("ref", rng.randi_range(25, 55), look_for("ref", 40), 0.75)
		rf.max_speed = 6.0
		_park(rf, Vector2(0.0 + i * 1.0, 13.9))
		refs.append(rf.id)
	for side4 in 2:
		var tm: Dictionary = teams[side4]
		var k := 0
		for sid in tm.skaters + tm.goalies:
			var s2 := by_id(sid)
			_park(s2, _bench_spot(side4, k))
			k += 1
	if ctx.get("fast", false):
		_put_nets()
		_start_warmup(true)


func _player(side: int, age: int, role: String) -> IceSkater:
	var cols: Array = teams[side].colors
	var l := look_for(role, age, {"colors": [cols[0], cols[1]]})
	var s := add_skater(role, age, l, rng.randf_range(0.45, 0.85) * _tier_skill())
	s.team = side
	s.max_speed = lerpf(6.5, 9.0, s.skill)
	s.accel = lerpf(3.0, 5.5, s.skill)
	s.fall_rate = 0.0
	if role == "goalie":
		s.max_speed = 4.0
		s.radius = 0.42
	return s


func _tier_skill() -> float:
	match kind:
		"senior_hockey": return 1.15
		"tournament": return 0.75
		_: return 1.0


func _bench_spot(side: int, k: int) -> Vector2:
	var b: Vector2 = teams[side].bench
	return b + Vector2(-3.6 + (k % 9) * 0.85, 0.55 * float(k / 9))


func _park(s: IceSkater, at: Vector2) -> void:
	s.pos = at
	s.on_ice = false
	s.go(at, 1.0, 0.2)
	s.face = Vector2(0, 1)


func _rules() -> Dictionary:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "LeagueRules":
			var scr: Script = load(str(c.path))
			if scr and scr.has_method("for_event"):
				var v: Variant = scr.call("for_event", kind)
				if v is Dictionary:
					return v
	return {"period_minutes": float(_cfg.get("period_minutes", 20.0)), "periods": int(_cfg.get("periods", 3)),
		"placeholder": true, "running_clock": true}


func doors_closed() -> bool:
	if ctx.has("zamboni_doors_closed"):
		return bool(ctx.zamboni_doors_closed)
	var v: Variant = sim.get("zamboni_doors_closed") if sim else null
	if v != null:
		return bool(v)
	if venue and venue.has_method("door"):
		var d: Variant = venue.call("door", "Bay rink door")
		if d != null and d.get("is_open") != null:
			return not bool(d.get("is_open"))
	return true


func _put_nets() -> void:
	if _nets[0] >= 0:
		return
	_nets[0] = gear.add_net(Vector2(-Rink.GOAL_X, 0), Vector2(1, 0), "full", "game")
	_nets[1] = gear.add_net(Vector2(Rink.GOAL_X, 0), Vector2(-1, 0), "full", "game")


# ------------------------------------------------------------------ think

func _think(dt: float) -> void:
	phase_t += dt
	_think_t -= dt
	var think := _think_t <= 0.0
	if think:
		_think_t = 0.15
	match game_phase:
		"waiting":
			waiting_for = []
			var nets := nets_out()
			if int(nets.full) < 2:
				waiting_for.append("nets")
				if think and phase_t > 1.0 and fmod(phase_t, 30.0) < 0.2:
					nets_needed.emit(2, 0)
			else:
				_put_nets()
			if not doors_closed():
				waiting_for.append("zamboni_doors")
			if waiting_for.is_empty():
				_start_bucket()
		"bucket":
			_bucket_step()
		"warmup":
			if think:
				_warmup()
			if phase_t > float(_cfg.get("warmup_minutes", 5.0)) * 60.0 * float(ctx.get("clock_scale", 1.0)):
				_to_benches()
				period = 1
				clock = float(rules.get("period_minutes", 20.0)) * 60.0 * float(ctx.get("clock_scale", 1.0))
				_faceoff(Vector2.ZERO)
		"faceoff":
			_faceoff_step()
		"play":
			clock -= dt
			if think:
				_play()
			_changes(dt)
			if clock <= 0.0:
				_end_period()
		"goal":
			_celebrate()
			if phase_t > 6.0:
				_faceoff(Vector2.ZERO)
		"stoppage":
			_hold_positions()
			if phase_t > 3.0:
				_faceoff(_faceoff_at)
		"intermission":
			_to_benches()
			if phase_t > float(_cfg.get("intermission_minutes", 2.0)) * 60.0 * float(ctx.get("clock_scale", 1.0)):
				period += 1
				clock = float(rules.get("period_minutes", 20.0)) * 60.0 * float(ctx.get("clock_scale", 1.0))
				for tm: Dictionary in teams:
					tm.dir = -float(tm.dir)
				_faceoff(Vector2.ZERO)
		"final":
			_to_benches()
	_goalie_step()
	_refs()


func _start_bucket() -> void:
	game_phase = "bucket"
	phase_t = 0.0
	var tm: Dictionary = teams[0]
	for side in 2:
		for sid in teams[side].skaters + teams[side].goalies:
			var s := by_id(sid)
			s.task = {"state": "warmup"}
	_bucket_by = int(tm.skaters[0])
	var b := by_id(_bucket_by)
	b.carry = "bucket"
	_bucket_prop = gear.add_prop("bucket", b.pos, 0.0, 0.9)


func _bucket_step() -> void:
	var b := by_id(_bucket_by)
	if b == null:
		_start_warmup(false)
		return
	var at := Vector2(0.0, -4.0)
	route(b, at, 3.0)
	gear.move_prop(_bucket_prop, b.pos + b.forward() * 0.4, 0.6)
	# everybody else heads out too
	_warmup_enter()
	if b.on_ice and b.pos.distance_to(at) < 1.0:
		b.carry = ""
		gear.move_prop(_bucket_prop, Vector2(-5.0, -14.3), 0.0)  # the empty bucket goes back to the bench
		_start_warmup(false)


func _start_warmup(fast: bool) -> void:
	game_phase = "warmup"
	phase_t = 0.0
	gear.dump_bucket(Vector2(0.0, -4.0), int(OnIceData.section("equipment").get("pucks_per_bucket", 50)) / 2)
	gear.dump_bucket(Vector2(0.0, 4.0), int(OnIceData.section("equipment").get("pucks_per_bucket", 50)) / 2)
	if fast:
		_put_nets()
		for side in 2:
			var k := 0
			for sid in teams[side].skaters + teams[side].goalies:
				var s := by_id(sid)
				s.on_ice = true
				s.pos = Vector2(-teams[side].dir * rng.randf_range(4.0, 22.0), rng.randf_range(-9.0, 9.0))
				s.task = {"state": "warmup"}
				k += 1


func _warmup_enter() -> void:
	for side in 2:
		for sid in teams[side].skaters + teams[side].goalies:
			var s := by_id(sid)
			if s and not s.on_ice and s.id != _bucket_by:
				route(s, _half_point(side, s), 3.0)


func _half_point(side: int, s: IceSkater) -> Vector2:
	var own := -float(teams[side].dir)
	return Vector2(own * (8.0 + float(s.id % 7) * 2.0), -8.0 + float(s.id % 9) * 2.0)


## Warm-up: laps of their own half, then grab a puck and shoot on their goalie.
func _warmup() -> void:
	for side in 2:
		var own := -float(teams[side].dir)
		var net: int = _nets[0] if own < 0.0 else _nets[1]
		for sid in teams[side].skaters:
			var s := by_id(sid)
			if s == null or s.down():
				continue
			if not s.on_ice:
				route(s, _half_point(side, s), 3.0)
				continue
			var tk := s.task
			if s.puck >= 0:
				var shoot_from := Vector2(own * (Rink.GOAL_X - 9.0), (float(s.id % 5) - 2.0) * 2.0)
				s.go(shoot_from, s.max_speed * 0.6, 1.0)
				if s.at_target(1.5):
					_shoot(s, net, 0.7)
				continue
			if rng.randf() < 0.04:
				tk.state = "puck"
			if str(tk.get("state", "")) == "puck":
				var near := gear.free_pucks_near(s.pos, 30.0)
				var found := false
				for k: int in near:
					var pp: IceGear.IcePuck = gear.pucks[k]
					if signf(pp.pos.x) == signf(own) or absf(pp.pos.x) < 6.0:
						s.catching = true
						s.go(pp.pos, s.max_speed * 0.6, 0.2)
						found = true
						break
				if not found:
					tk.state = "laps"
				continue
			# a lap of their half, counter-clockwise
			var c := Vector2(own * 15.0, 0.0)
			var off := s.pos - c
			var ang := atan2(off.y, off.x) - 0.6
			var rr := Vector2(10.0, 8.5)
			s.go(c + Vector2(cos(ang) * rr.x, sin(ang) * rr.y), s.max_speed * 0.55, 1.0)
		for gid in teams[side].goalies.slice(0, 1):
			var g := by_id(gid)
			if g:
				gear.nets[net].goalie = g.id
				if not g.on_ice:
					route(g, gear.nets[net].pos + gear.nets[net].face * 0.5, 2.5)
		for gid2 in teams[side].goalies.slice(1):
			var g2 := by_id(gid2)
			if g2:
				g2.go(Vector2(own * 20.0, 9.0), 2.0, 1.0)


func _to_benches() -> void:
	for side in 2:
		var k := 0
		for sid in teams[side].skaters + teams[side].goalies:
			var s := by_id(sid)
			if s == null:
				continue
			if s.puck >= 0:
				gear.release(s.puck, Vector2.ZERO)
				s.puck = -1
			s.catching = false
			route(s, _bench_spot(side, k), 3.0)
			if not s.on_ice:
				s.face = Vector2(0, 1)
			k += 1
		teams[side].on = []
	for rid in refs:
		var r := by_id(rid)
		if r and game_phase in ["final", "intermission"]:
			route(r, Vector2(0.0, 13.9), 3.0)


# --------------------------------------------------------------- the game

func _faceoff(at: Vector2) -> void:
	game_phase = "faceoff"
	phase_t = 0.0
	_faceoff_at = at
	# the loose warm-up pucks go back over the boards to the bench
	if puck < 0:
		for p: IceGear.IcePuck in gear.pucks:
			p.alive = false
		puck = gear.add_puck(at, false, controller == "broomball")
	var p2: IceGear.IcePuck = gear.pucks[puck]
	p2.owner = -1
	p2.in_net = -1
	p2.vel = Vector2.ZERO
	for side in 2:
		var tm: Dictionary = teams[side]
		if (tm.on as Array).size() < per_side:
			tm.on = (tm.skaters as Array).slice(0, per_side)
		for sid in tm.skaters:
			var s := by_id(sid)
			if s:
				s.catching = false
				if s.puck >= 0:
					s.puck = -1
	var r0 := by_id(refs[0]) if not refs.is_empty() else null
	if r0:
		whistle.emit(r0.pos3())


func _faceoff_step() -> void:
	var p: IceGear.IcePuck = gear.pucks[puck]
	p.pos = _faceoff_at
	p.vel = Vector2.ZERO
	var ready := true
	for side in 2:
		var tm: Dictionary = teams[side]
		var d := float(tm.dir)
		var spots := [Vector2(-d * 0.9, 0), Vector2(-d * 1.4, 4.5), Vector2(-d * 1.4, -4.5), Vector2(-d * 8.0, 3.5), Vector2(-d * 8.0, -3.5), Vector2(-d * 4.0, 0)]
		var k := 0
		for sid in tm.on:
			var s := by_id(sid)
			if s == null:
				continue
			var to: Vector2 = _faceoff_at + spots[k % spots.size()]
			to = Vector2(clampf(to.x, -Rink.GOAL_X + 1.0, Rink.GOAL_X - 1.0), clampf(to.y, -11.5, 11.5))
			route(s, to, 3.5)
			s.face = Vector2(d, 0)
			if not s.on_ice or s.pos.distance_to(to) > 1.5:
				ready = false
			k += 1
		for sid2 in tm.skaters:
			if not sid2 in tm.on:
				var s2 := by_id(sid2)
				if s2 and s2.on_ice:
					route(s2, _bench_spot(side, (tm.skaters as Array).find(sid2)), 3.0)
	var r0 := by_id(refs[0]) if not refs.is_empty() else null
	if r0:
		route(r0, _faceoff_at + Vector2(0, 1.2), 3.0)
		if r0.pos.distance_to(_faceoff_at + Vector2(0, 1.2)) > 1.5:
			ready = false
	if (ready and phase_t > 2.5) or phase_t > 15.0:
		game_phase = "play"
		phase_t = 0.0
		p.vel = Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
		if r0:
			r0.go(r0.pos + Vector2(0, 3.0), 3.0, 0.5)
			r0.pose_lock = PeopleArt.Pose.WORK
			get_tree().create_timer(0.6).timeout.connect(func() -> void: r0.pose_lock = -1) if is_inside_tree() else null


func _play() -> void:
	var p: IceGear.IcePuck = gear.pucks[puck]
	if p.in_net >= 0:
		return
	var carrier := by_id(p.owner) if p.owner >= 0 else null
	if carrier and r_is_ref(carrier):
		carrier = null
	for side in 2:
		var tm: Dictionary = teams[side]
		var d := float(tm.dir)
		var opp_net: int = _nets[1] if d > 0.0 else _nets[0]
		var own_net: int = _nets[0] if d > 0.0 else _nets[1]
		var opp_pos: Vector2 = gear.nets[opp_net].pos
		var own_pos: Vector2 = gear.nets[own_net].pos
		var have := carrier != null and carrier.team == side
		var chaser := -1
		if carrier == null or carrier.team != side:
			var bd := INF
			for sid in tm.on:
				var s := by_id(sid)
				if s and s.on_ice and not s.down() and s.pos.distance_to(p.pos) < bd:
					bd = s.pos.distance_to(p.pos)
					chaser = sid
		var k := 0
		for sid2 in tm.on:
			var s2 := by_id(sid2)
			if s2 == null or s2.down() or not s2.on_ice:
				k += 1
				continue
			var lanez: float = [-6.0, 0.0, 6.0, -3.5, 3.5][k % 5]
			var fwd := k < 3
			if s2 == carrier:
				s2.catching = false
				var lane_pt := Vector2(opp_pos.x - d * 4.0, clampf(s2.pos.y * 0.6, -5.0, 5.0))
				s2.go(lane_pt, s2.max_speed * 0.85, 1.0)
				var dist := s2.pos.distance_to(opp_pos)
				if dist < 16.0 and absf(s2.pos.y) < 9.0 and rng.randf() < 0.18 + 0.15 * s2.skill:
					_shoot(s2, opp_net, 1.0)
				elif rng.randf() < 0.07:
					var mate := _open_mate(tm, s2, d)
					if mate:
						mate.catching = true
						var to := mate.pos + mate.vel * 0.5
						gear.release(s2.puck, (to - s2.pos).normalized() * clampf(s2.pos.distance_to(to) * 1.6, 7.0, 20.0))
						s2.puck = -1
			elif sid2 == chaser:
				s2.catching = true
				s2.go(p.pos + p.vel * 0.3, s2.max_speed, 0.1)
				if carrier and carrier.team != side and carrier.pos.distance_to(s2.pos) < carrier.radius + s2.radius + 0.4 and rng.randf() < 0.1 + 0.12 * s2.skill:
					gear.release(carrier.puck, carrier.vel * 0.4 + (carrier.pos - s2.pos).normalized() * 3.0)
					carrier.puck = -1
					bump(s2, carrier, 3.5)
			else:
				s2.catching = carrier == null
				var spot: Vector2
				if have:
					spot = Vector2(p.pos.x + d * (5.0 if fwd else -9.0), lanez)
				else:
					spot = Vector2(lerpf(p.pos.x, own_pos.x, 0.35 if fwd else 0.6), lanez * (0.8 if fwd else 0.6))
				spot.x = clampf(spot.x, -Rink.GOAL_X + 1.5, Rink.GOAL_X - 1.5)
				s2.go(spot, s2.max_speed * 0.7, 1.0)
			k += 1


func r_is_ref(s: IceSkater) -> bool:
	return s.role == "ref"


func _open_mate(tm: Dictionary, me: IceSkater, d: float) -> IceSkater:
	var best: IceSkater = null
	var bs := -INF
	for sid in tm.on:
		var s := by_id(sid)
		if s == null or s == me or s.down() or not s.on_ice:
			continue
		var score_ := (s.pos.x - me.pos.x) * d - absf(s.pos.y) * 0.2
		if score_ > bs:
			bs = score_
			best = s
	return best


func _shoot(s: IceSkater, net: int, power: float) -> void:
	if s.puck < 0 or net < 0:
		return
	var n: Dictionary = gear.nets[net]
	var side := Vector2(-n.face.y, n.face.x)
	var aim: Vector2 = n.pos + side * rng.randf_range(-0.85, 0.85) * float(n.half_w)
	var spd := lerpf(14.0, 30.0, s.skill) * power * _shot_scale()
	gear.release(s.puck, (aim - s.pos).normalized().rotated(rng.randf_range(-0.05, 0.05)) * spd)
	s.puck = -1
	shot_taken(s)


func _shot_scale() -> float:
	return 1.0


func shot_taken(s: IceSkater) -> void:
	if game_phase == "play":
		shots[s.team] = int(shots[s.team]) + 1
		crowd_reaction.emit("ooh", 0.25)


func _on_goal(net: int, _puck: int) -> void:
	if game_phase != "play":
		return
	var scorer := 0 if net == _nets[1] else 1
	if float(teams[0].dir) < 0.0:
		scorer = 1 - scorer
	score[scorer] = int(score[scorer]) + 1
	game_phase = "goal"
	phase_t = 0.0
	crowd_reaction.emit("goal", 1.0)
	var r0 := by_id(refs[0]) if not refs.is_empty() else null
	whistle.emit(r0.pos3() if r0 else Vector3.ZERO)
	_special_goal = scorer


var _special_goal := -1


func _on_save(_net: int, _puck: int) -> void:
	if game_phase != "play":
		return
	crowd_reaction.emit("save", 0.45)
	if rng.randf() < 0.3:
		# the goalie covers it up: whistle, faceoff in that end
		game_phase = "stoppage"
		phase_t = 0.0
		var p: IceGear.IcePuck = gear.pucks[puck]
		_faceoff_at = Vector2(signf(p.pos.x) * Rink.DOT_X, Rink.DOT_Z * (1.0 if p.pos.y >= 0.0 else -1.0))
		var r := _nearest_ref(p.pos)
		whistle.emit(r.pos3() if r else Vector3(p.pos.x, 1.5, p.pos.y))


func _nearest_ref(at: Vector2) -> IceSkater:
	var best: IceSkater = null
	var bd := INF
	for rid in refs:
		var r := by_id(rid)
		if r and r.pos.distance_to(at) < bd:
			bd = r.pos.distance_to(at)
			best = r
	return best


func _celebrate() -> void:
	for side in 2:
		for sid in teams[side].on:
			var s := by_id(sid)
			if s == null:
				continue
			if side == _special_goal:
				var hub: Vector2 = gear.pucks[puck].pos * 0.8
				s.go(hub, 3.0, 1.2)
				s.pose_lock = PeopleArt.Pose.CHEER if s.at_target(1.5) else -1
			else:
				s.speed_want = 0.0
	if phase_t > 5.5:
		for s2: IceSkater in skaters:
			if s2.pose_lock == PeopleArt.Pose.CHEER:
				s2.pose_lock = -1
		var p: IceGear.IcePuck = gear.pucks[puck]
		p.in_net = -1
		p.owner = -1


func _hold_positions() -> void:
	for side in 2:
		for sid in teams[side].on:
			var s := by_id(sid)
			if s and s.puck >= 0:
				s.puck = -1
			if s:
				s.speed_want = 0.0


## Line changes on the fly: tired skaters head for their bench gate, the
## next ones come on through it.
func _changes(dt: float) -> void:
	for side in 2:
		_shift_t[side] = float(_shift_t[side]) + dt
		var tm: Dictionary = teams[side]
		if float(_shift_t[side]) < float(_cfg.get("shift_seconds", 45.0)):
			continue
		_shift_t[side] = 0.0
		var on: Array = tm.on
		var all: Array = tm.skaters
		var start := (all.find(on[0]) + per_side) % maxi(all.size(), 1) if not on.is_empty() else 0
		var fresh: Array = []
		for k in per_side:
			fresh.append(all[(start + k) % all.size()])
		for sid in on:
			var s := by_id(sid)
			if s and not sid in fresh:
				if s.puck >= 0:
					gear.release(s.puck, s.vel * 0.5)
					s.puck = -1
				s.catching = false
				route(s, _bench_spot(side, all.find(sid)), 3.0)
		tm.on = fresh
	# skaters who aren't on keep heading for (or sitting on) the bench
	for side2 in 2:
		var tm2: Dictionary = teams[side2]
		for sid2 in tm2.skaters:
			if sid2 in tm2.on:
				var s2 := by_id(sid2)
				if s2 and not s2.on_ice:
					route(s2, Vector2(s2.pos.x, -9.0), 3.0)
			else:
				var s3 := by_id(sid2)
				if s3:
					route(s3, _bench_spot(side2, (tm2.skaters as Array).find(sid2)), 3.0)


func _end_period() -> void:
	var r0 := by_id(refs[0]) if not refs.is_empty() else null
	whistle.emit(r0.pos3() if r0 else Vector3.ZERO)
	crowd_reaction.emit("period_end", 0.5)
	if period >= int(rules.get("periods", 3)):
		game_phase = "final"
		crowd_reaction.emit("final", 0.8)
	else:
		game_phase = "intermission"
	phase_t = 0.0


func _goalie_step() -> void:
	if game_phase in ["waiting", "bucket"]:
		return
	for side in 2:
		var tm: Dictionary = teams[side]
		if (tm.goalies as Array).is_empty():
			continue
		var g := by_id(tm.goalies[0])
		var own_net: int = _nets[0] if float(tm.dir) > 0.0 else _nets[1]
		if g == null or own_net < 0:
			continue
		if game_phase == "intermission" or game_phase == "final":
			continue
		var n: Dictionary = gear.nets[own_net]
		n.goalie = g.id
		var face: Vector2 = n.face
		var sidev := Vector2(-face.y, face.x)
		var lat := 0.0
		if puck >= 0:
			lat = clampf((gear.pucks[puck].pos - n.pos).dot(sidev) * 0.12, -0.7, 0.7)
		var spot: Vector2 = n.pos + face * 0.5 + sidev * lat
		route(g, spot, 3.0)
		g.face = face
		gear.goalie_check(g, own_net)


func _refs() -> void:
	if refs.is_empty() or game_phase in ["waiting", "bucket", "final", "intermission"]:
		return
	var px: float = gear.pucks[puck].pos.x if puck >= 0 else 0.0
	for k in refs.size():
		var r := by_id(refs[k])
		if r == null:
			continue
		if k == 0 and game_phase == "faceoff":
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var to := Vector2(clampf(px + side * 7.0, -24.0, 24.0), side * 11.2)
		route(r, to, 5.0)
		r.face = Vector2(0, -side)
