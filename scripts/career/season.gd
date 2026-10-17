class_name Season
extends RefCounted
## One season of one league: a double round-robin schedule (12-16 games
## depending on the tier), standings (2 points a win, 1 for an OT/shootout
## loss), then a top-4 playoff bracket. The career advances it a round at a
## time; each round is one game day.

enum Phase { REGULAR, PLAYOFFS, DONE }

var tier := 0
var number := 1
var team_ids: Array = []
var rounds: Array = []  # [[{"home", "away", "result"}...]...]
var round_index := 0
var phase := Phase.REGULAR
var standings := {}  # team id -> {gp, w, l, otl, pts, gf, ga}
## Playoff rounds: [[{"a", "b", "wa", "wb", "need", "winner"}...]...]
var bracket: Array = []
var champion := -1


static func create(tier_: int, number_: int, teams: Array, rng: RandomNumberGenerator) -> Season:
	var s := Season.new()
	s.tier = tier_
	s.number = number_
	s.team_ids = teams.duplicate()
	s.team_ids.shuffle()
	for t in s.team_ids:
		s.standings[t] = {"gp": 0, "w": 0, "l": 0, "otl": 0, "pts": 0, "gf": 0, "ga": 0}
	s._build_schedule(int(LeagueTiers.get_tier(tier_).games), rng)
	return s


## Circle-method round robin, repeated with home and away swapped until every
## team has its games. Odd leagues get a bye each round.
func _build_schedule(games: int, _rng: RandomNumberGenerator) -> void:
	var ids: Array = team_ids.duplicate()
	if ids.size() % 2 == 1:
		ids.append(-1)
	var n := ids.size()
	var played := {}
	for t in team_ids:
		played[t] = 0
	var cycle := 0
	while played.values().min() < games and cycle < 10:
		var rot := ids.duplicate()
		for r in n - 1:
			var day: Array = []
			for i in n / 2:
				var a: int = rot[i]
				var b: int = rot[n - 1 - i]
				if a == -1 or b == -1 or played[a] >= games or played[b] >= games:
					continue
				var swap := (r + i + cycle) % 2 == 1
				day.append({"home": b if swap else a, "away": a if swap else b, "result": null})
				played[a] += 1
				played[b] += 1
			if not day.is_empty():
				rounds.append(day)
			# rotate everyone but the first slot
			rot.insert(1, rot.pop_back())
		cycle += 1


func games_in_round() -> Array:
	if phase == Phase.REGULAR:
		return rounds[round_index] if round_index < rounds.size() else []
	if phase == Phase.PLAYOFFS:
		var out: Array = []
		for series in bracket[-1]:
			if series.winner == -1:
				var h := playoff_home(series)
				out.append({"home": h, "away": series.b if h == series.a else series.a, "result": null, "series": series})
		return out
	return []


## Records a finished game (regular season or playoff).
func record(game: Dictionary, result: Dictionary) -> void:
	game.result = result
	if game.has("series"):
		var s: Dictionary = game.series
		var home_won: bool = result.hg > result.ag
		if home_won == (game.home == s.a):
			s.wa += 1
		else:
			s.wb += 1
		if s.wa >= s.need:
			s.winner = s.a
		elif s.wb >= s.need:
			s.winner = s.b
		s.games.append({"home": game.home, "hg": result.hg, "ag": result.ag, "ot": result.ot})
		return
	for side in 2:
		var tid: int = game.home if side == 0 else game.away
		var gf: int = result.hg if side == 0 else result.ag
		var ga: int = result.ag if side == 0 else result.hg
		var row: Dictionary = standings[tid]
		row.gp += 1
		row.gf += gf
		row.ga += ga
		if gf > ga:
			row.w += 1
			row.pts += 2
		elif result.ot or result.so:
			row.otl += 1
			row.pts += 1
		else:
			row.l += 1


## Moves to the next round once every game in this one is recorded.
func advance() -> void:
	if phase == Phase.REGULAR:
		round_index += 1
		if round_index >= rounds.size():
			_start_playoffs()
	elif phase == Phase.PLAYOFFS:
		var cur: Array = bracket[-1]
		for s in cur:
			if s.winner == -1:
				return
		if cur.size() == 1:
			champion = cur[0].winner
			phase = Phase.DONE
			return
		var next: Array = []
		for i in range(0, cur.size(), 2):
			next.append(_series(cur[i].winner, cur[i + 1].winner, bracket.size()))
		bracket.append(next)


func _start_playoffs() -> void:
	phase = Phase.PLAYOFFS
	var seeds := ranked()
	var n: int = mini(int(LeagueTiers.get_tier(tier).playoff_teams), seeds.size())
	var first: Array = []
	for i in n / 2:
		first.append(_series(seeds[i], seeds[n - 1 - i], 0))
	bracket = [first]


func _series(a: int, b: int, round_: int) -> Dictionary:
	return {"a": a, "b": b, "wa": 0, "wb": 0, "need": LeagueTiers.series_wins(tier, round_), "winner": -1, "games": []}


## Team ids by points, then wins, then goal difference.
func ranked() -> Array:
	var ids := team_ids.duplicate()
	ids.sort_custom(func(x, y):
		var a: Dictionary = standings[x]
		var b: Dictionary = standings[y]
		if a.pts != b.pts:
			return a.pts > b.pts
		if a.w != b.w:
			return a.w > b.w
		return (a.gf - a.ga) > (b.gf - b.ga))
	return ids


## The higher seed in a series gets home ice in games 1, 2, 5 and 7.
func playoff_home(series: Dictionary) -> int:
	var g: int = series.games.size()
	return series.a if g in [0, 1, 4, 6] else series.b


func is_playoff_team(tid: int) -> bool:
	return not bracket.is_empty() and bracket[0].any(func(s): return s.a == tid or s.b == tid)


func eliminated(tid: int) -> bool:
	if phase == Phase.REGULAR:
		return false
	for r in bracket:
		for s in r:
			if (s.a == tid or s.b == tid) and s.winner != -1 and s.winner != tid:
				return true
	return not is_playoff_team(tid)


func to_dict() -> Dictionary:
	return {"tier": tier, "number": number, "team_ids": team_ids, "rounds": _strip(rounds),
		"round_index": round_index, "phase": phase, "standings": _keys_to_str(standings),
		"bracket": bracket, "champion": champion}


## Results are summarised (score only) when saved; box scores live in stats.
static func _strip(rs: Array) -> Array:
	return rs.map(func(day): return day.map(func(g):
		var r = g.result
		return {"home": g.home, "away": g.away, "result": null if r == null else {"hg": r.hg, "ag": r.ag, "ot": r.ot, "so": r.so}}))


static func _keys_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	s.tier = int(d.tier)
	s.number = int(d.number)
	s.team_ids = d.team_ids.map(func(x): return int(x))
	s.rounds = d.rounds.map(func(day): return day.map(func(g): return {"home": int(g.home), "away": int(g.away), "result": g.result}))
	s.round_index = int(d.round_index)
	s.phase = int(d.phase)
	for k in d.standings:
		var row := {}
		for f in d.standings[k]:
			row[f] = int(d.standings[k][f])
		s.standings[int(k)] = row
	s.bracket = d.bracket.map(func(r): return r.map(func(x): return {
		"a": int(x.a), "b": int(x.b), "wa": int(x.wa), "wb": int(x.wb), "need": int(x.need),
		"winner": int(x.winner), "games": x.games}))
	s.champion = int(d.champion)
	return s
