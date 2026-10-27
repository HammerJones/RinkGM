class_name Team
extends RefCounted
## A club: name, colours and roster. Lines are built from whoever is healthy:
## three forward lines (LW-C-RW) and two defence pairs, best players first,
## plus a starting goalie. Short benches double-shift the top players.

const FORWARD_LINES := 3
const DEFENCE_PAIRS := 2

var id := 0
var name := ""
var short := ""
var primary := "c8191e"
var secondary := "ece7dc"
var tier := 0
var roster: Array = []  # player ids


## Builds tonight's lineup from healthy players.
## Returns {"F": [[LW, C, RW] x3], "D": [[LD, RD] x2], "G": goalie, "scratched": [...]}
## with PlayerProfile entries. `players` maps id -> PlayerProfile.
func lineup(players: Dictionary) -> Dictionary:
	var fwd: Array = []
	var dmen: Array = []
	var goalies: Array = []
	for pid in roster:
		var p: PlayerProfile = players[pid]
		if not p.dressed():
			continue
		match p.group():
			"F": fwd.append(p)
			"D": dmen.append(p)
			"G": goalies.append(p)
	var by_ovr := func(a, b): return a.overall() > b.overall()
	fwd.sort_custom(by_ovr)
	dmen.sort_custom(by_ovr)
	goalies.sort_custom(by_ovr)
	# forwards fill C first (by position), then wings, then anyone left
	var lines: Array = []
	var pool := fwd.duplicate()
	for i in FORWARD_LINES:
		var line: Array = [null, null, null]
		for slot in 3:
			var want: String = ["LW", "C", "RW"][slot]
			for p in pool:
				if p.position == want:
					line[slot] = p
					pool.erase(p)
					break
		lines.append(line)
	for line in lines:
		for slot in 3:
			if line[slot] == null and not pool.is_empty():
				line[slot] = pool.pop_front()
	# short bench: double-shift the top line, then D move up front
	for li in lines.size():
		for slot in 3:
			if lines[li][slot] == null:
				lines[li][slot] = lines[0][slot] if lines[0][slot] else (dmen[0] if not dmen.is_empty() else null)
	var pairs: Array = []
	for i in DEFENCE_PAIRS:
		var a: Variant = dmen[i * 2] if dmen.size() > i * 2 else null
		var b: Variant = dmen[i * 2 + 1] if dmen.size() > i * 2 + 1 else null
		pairs.append([a, b])
	for pi in pairs.size():
		for slot in 2:
			if pairs[pi][slot] == null:
				pairs[pi][slot] = pairs[0][slot] if pairs[0][slot] else (pool.pop_front() if not pool.is_empty() else lines[2][slot])
	var dressed := {}
	for l in lines + pairs:
		for p in l:
			if p:
				dressed[p.id] = true
	var scratched: Array = []
	for p in fwd + dmen:
		if not dressed.has(p.id):
			scratched.append(p)
	return {"F": lines, "D": pairs, "G": goalies[0] if not goalies.is_empty() else null, "scratched": scratched}


## Lineup-weighted skater rating and goalie rating, for quick sims.
static func strength(lu: Dictionary) -> Dictionary:
	var line_w := [0.42, 0.34, 0.24]
	var att := 0.0
	var def := 0.0
	for i in lu.F.size():
		for p in lu.F[i]:
			if p:
				att += p.overall() * line_w[i] / 3.0
				def += p.overall() * line_w[i] / 3.0 * 0.5
	var pair_w := [0.56, 0.44]
	for i in lu.D.size():
		for p in lu.D[i]:
			if p:
				def += p.overall() * pair_w[i] / 2.0 * 0.5
				att += p.overall() * pair_w[i] / 2.0 * 0.25
	att /= 1.25
	var g: PlayerProfile = lu.G
	return {"att": att, "def": def, "goalie": g.overall() if g else 20.0}


## Godot palette for Models (jerseys, socks...) built from the club colours.
func palette() -> Dictionary:
	return Models.team_palette(name.to_upper(), Color(primary), Color(secondary))


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "short": short, "primary": primary, "secondary": secondary, "tier": tier, "roster": roster}


static func from_dict(d: Dictionary) -> Team:
	var t := Team.new()
	t.id = int(d.id)
	t.name = d.name
	t.short = d.short
	t.primary = d.primary
	t.secondary = d.secondary
	t.tier = int(d.tier)
	t.roster = d.roster.map(func(x): return int(x))
	return t
