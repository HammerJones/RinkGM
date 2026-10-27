class_name QuickSim
extends RefCounted
## Simulates a game without the engine: goals from team strength (Poisson),
## then a believable box score (who was on the ice, who shot, who scored,
## who hit whom) and injuries from those hits. Used for every game the user
## doesn't play live, so the whole career runs headless too.
##
## A result is a Dictionary:
##   home, away (team ids), hg, ag, ot, so, playoff,
##   box: {player id: {gp, g, a, shots, hits, pm, toi, sa, ga, w, l, otl, so}},
##   injuries: [{"pid": id, "injury": Injury}], live (played in the engine)

const BASE_GOALS := 3.0
const BASE_SHOTS := 27.0
const FWD_TOI := [0.40, 0.33, 0.27]
const D_TOI := [0.56, 0.44]


## `home_lu` / `away_lu` are Team.lineup() dictionaries.
static func simulate(home_id: int, away_id: int, home_lu: Dictionary, away_lu: Dictionary, settings: GameSettings, playoff: bool, rng: RandomNumberGenerator, rules: Dictionary = {}) -> Dictionary:
	var lu := [home_lu, away_lu]
	var st := [Team.strength(home_lu), Team.strength(away_lu)]
	var res := new_result(home_id, away_id, playoff)
	var glen := settings.game_length()
	for side in 2:
		_dress(res, lu[side], glen)
	var goals := [0, 0]
	var shots := [0, 0]
	for side in 2:
		var me: Dictionary = st[side]
		var opp: Dictionary = st[1 - side]
		var edge: float = 0.045 * (me.att - opp.def) + 0.03 * (me.att - opp.goalie)
		var lam := BASE_GOALS * exp(edge) * (1.05 if side == 0 else 1.0)
		goals[side] = _poisson(lam, rng)
		shots[side] = maxi(goals[side] + 3, _poisson(BASE_SHOTS * exp(0.4 * edge), rng))
	# overtime / shootout, unless the level lets a tie stand (LeagueRules)
	var tie_stands: bool = goals[0] == goals[1] and LeagueRules.after_tie(rules, playoff, true) == "tie" \
		and LeagueRules.after_tie(rules, playoff, false) == "tie"
	if goals[0] == goals[1] and not tie_stands:
		var p_home := 1.0 / (1.0 + exp(-(st[0].att - st[1].att) * 0.06))
		if playoff or rng.randf() < 0.6:
			res.ot = true
		else:
			res.so = true
		goals[0 if rng.randf() < p_home else 1] += 1
		if res.ot:
			var w := 0 if goals[0] > goals[1] else 1
			shots[w] += 1
	res.hg = goals[0]
	res.ag = goals[1]
	for side in 2:
		var scored: int = goals[side] - (1 if res.so and goals[side] > goals[1 - side] else 0)
		_credit_offence(res, lu[side], lu[1 - side], scored, shots[side], rng)
		_credit_goalie(res, lu[side].G, shots[1 - side], goals[1 - side] - (1 if res.so and goals[1 - side] > goals[side] else 0), goals[side] > goals[1 - side], res.ot or res.so)
	for side in 2:
		_credit_hits_and_injuries(res, lu[side], lu[1 - side], rng)
	return res


static func new_result(home_id: int, away_id: int, playoff: bool) -> Dictionary:
	return {"home": home_id, "away": away_id, "hg": 0, "ag": 0, "ot": false, "so": false,
		"playoff": playoff, "box": {}, "injuries": [], "live": false}


static func blank_line() -> Dictionary:
	var d := {}
	for k in PlayerProfile.STAT_KEYS:
		d[k] = 0
	d.gp = 1
	return d


static func _dress(res: Dictionary, lu: Dictionary, glen: float) -> void:
	for i in lu.F.size():
		for p in lu.F[i]:
			if p:
				_line(res, p).toi += glen * FWD_TOI[i]
	for i in lu.D.size():
		for p in lu.D[i]:
			if p:
				_line(res, p).toi += glen * D_TOI[i]
	if lu.G:
		_line(res, lu.G).toi = glen


static func _line(res: Dictionary, p: PlayerProfile) -> Dictionary:
	if not res.box.has(p.id):
		res.box[p.id] = blank_line()
	return res.box[p.id]


## Picks the five on the ice for an event, weighted by ice time.
static func _on_ice(lu: Dictionary, rng: RandomNumberGenerator) -> Array:
	var f: Array = lu.F[_pick_index(FWD_TOI, rng)]
	var d: Array = lu.D[_pick_index(D_TOI, rng)]
	return (f + d).filter(func(p): return p != null)


static func _credit_offence(res: Dictionary, lu: Dictionary, opp: Dictionary, goals: int, shots: int, rng: RandomNumberGenerator) -> void:
	for i in shots:
		var five := _on_ice(lu, rng)
		var shooter: PlayerProfile = _weighted(five, func(p): return _shoot_weight(p), rng)
		_line(res, shooter).shots += 1
	for i in goals:
		var five := _on_ice(lu, rng)
		var scorer: PlayerProfile = _weighted(five, func(p): return _shoot_weight(p) * (1.0 + p.skills.n("shot_accuracy")), rng)
		_line(res, scorer).g += 1
		var mates := five.filter(func(p): return p != scorer)
		for a in 2:
			if mates.is_empty() or rng.randf() < 0.18 * (a + 1):
				break
			var helper: PlayerProfile = _weighted(mates, func(p): return (0.5 + p.skills.n("pass_quality")) * exp(p.overall() / 12.0), rng)
			_line(res, helper).a += 1
			mates.erase(helper)
		for p in five:
			_line(res, p).pm += 1
		for p in _on_ice(opp, rng):
			_line(res, p).pm -= 1


static func _shoot_weight(p: PlayerProfile) -> float:
	var w := 0.6 + p.skills.n("shot_release") + p.skills.n("shot_power") * 0.5
	# better players get more of the puck: +10 overall is about 2.3x the looks
	return w * exp(p.overall() / 12.0) * (0.55 if p.position == "D" else 1.0)


static func _credit_goalie(res: Dictionary, g: PlayerProfile, sa: int, ga: int, won: bool, extra: bool) -> void:
	if g == null:
		return
	var l := _line(res, g)
	l.sa = sa
	l.ga = ga
	if won:
		l.w = 1
	elif extra:
		l.otl = 1
	elif res.hg != res.ag:  # a tie is neither
		l.l = 1
	if ga == 0:
		l.so = 1


## Hits thrown by `lu` on `opp`, each with an injury roll.
static func _credit_hits_and_injuries(res: Dictionary, lu: Dictionary, opp: Dictionary, rng: RandomNumberGenerator) -> void:
	var hitters: Array = []
	for l in lu.F + lu.D:
		for p in l:
			if p and not hitters.has(p):
				hitters.append(p)
	var victims: Array = []
	for l in opp.F + opp.D:
		for p in l:
			if p and not victims.has(p):
				victims.append(p)
	if victims.is_empty():
		return
	var hurt := {}
	for h in hitters:
		var n := _poisson(0.4 + 2.2 * h.skills.n("hitting") * (1.3 if h.position == "D" else 1.0), rng)
		for i in n:
			var v: PlayerProfile = victims[rng.randi() % victims.size()]
			_line(res, h).hits += 1
			if hurt.has(v.id):
				continue
			var inj := Injury.roll_hit(h.skills, v.skills, rng.randf_range(1.5, 5.0) * lerpf(0.6, 1.5, h.skills.n("hitting")), v.fatigue, rng)
			if inj:
				hurt[v.id] = true
				res.injuries.append({"pid": v.id, "injury": inj})
	for v in victims:
		if hurt.has(v.id):
			continue
		var wear := Injury.roll_wear(v.skills, rng)
		if wear:
			res.injuries.append({"pid": v.id, "injury": wear})


static func _pick_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


static func _weighted(items: Array, weight: Callable, rng: RandomNumberGenerator) -> Variant:
	var ws: Array = items.map(weight)
	return items[_pick_index(ws, rng)]


static func _poisson(lam: float, rng: RandomNumberGenerator) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
	return k
