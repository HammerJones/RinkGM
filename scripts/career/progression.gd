class_name Progression
extends RefCounted
## How ratings move. Players earn XP from what they actually do in games
## (shooting trains shooting, hitting trains hitting, ice time trains skating)
## and from practice between games. XP turns into rating growth that slows as
## a skill nears the player's potential and with age. Past 29 the body starts
## to go: physical skills decline each season, faster after 33, and missed
## games leave some rust.

const PHYSICAL := ["speed", "agility", "toughness", "hitting", "reflexes"]
## XP -> rating points at full headroom for a 20-year-old.
const GROWTH_RATE := 0.045


## Age multiplier on growth.
static func age_growth(age: float) -> float:
	if age < 23.0:
		return 1.25
	if age < 27.0:
		return 1.0
	if age < 31.0:
		return 0.6
	return 0.3


## XP earned per skill from one game's box score line.
## `line` has the PlayerProfile.STAT_KEYS counted for this game; toi in seconds,
## `game_len` the regulation game length in seconds (so short games still count).
static func game_xp(p: PlayerProfile, line: Dictionary, game_len: float) -> Dictionary:
	var xp := {}
	var ice := clampf(line.get("toi", 0.0) / maxf(game_len, 1.0), 0.0, 1.0) * 3.0
	if p.is_goalie():
		var sv: float = line.get("sa", 0) - line.get("ga", 0)
		for k in Skills.GOALIE_KEYS:
			xp[k] = ice * 1.5 + sv * 0.25
		return xp
	for k in ["speed", "agility", "stick_handling", "pass_quality"]:
		xp[k] = ice * 2.0
	xp["toughness"] = ice + line.get("hits", 0) * 0.5
	xp["hitting"] = ice * 0.5 + line.get("hits", 0) * 1.5
	var shots: float = line.get("shots", 0)
	for k in ["shot_accuracy", "shot_power", "shot_release"]:
		xp[k] = ice * 0.5 + shots * 0.8 + line.get("g", 0) * 2.0
	xp["pass_quality"] += line.get("a", 0) * 2.5
	xp["stick_handling"] += (line.get("g", 0) + line.get("a", 0)) * 1.0
	xp["stamina"] = ice * 1.0
	return xp


## XP from a practice session; most of it goes to the focus skill.
static func practice_xp(p: PlayerProfile, quality: float) -> Dictionary:
	var keys := Skills.GOALIE_KEYS if p.is_goalie() else Skills.SKATER_KEYS
	var xp := {}
	for k in keys:
		xp[k] = 1.5 * quality
	if p.training_focus in keys:
		xp[p.training_focus] += 9.0 * quality
	else:
		for k in keys:
			xp[k] += 9.0 * quality / keys.size() * 2.0
	return xp


## Turns XP into rating. Returns the per-skill change.
static func apply_xp(p: PlayerProfile, xp: Dictionary) -> Dictionary:
	var delta := {}
	var age_k := age_growth(p.age)
	for k in xp:
		if not p.skills.values.has(k):
			continue
		var v: float = p.skills.values[k]
		var cap: float = p.potential.get(k, 100.0)
		var headroom := clampf((cap - v) / 25.0, 0.0, 1.0)
		var d: float = xp[k] * GROWTH_RATE * age_k * headroom
		p.skills.values[k] = minf(v + d, 100.0)
		delta[k] = d
		p.xp_log[k] = p.xp_log.get(k, 0.0) + d
	p.refresh_modifiers()
	return delta


## Rust: a missed game costs a little in the physical skills.
static func apply_rust(p: PlayerProfile) -> void:
	for k in PHYSICAL:
		if p.skills.values.has(k):
			p.skills.values[k] = maxf(1.0, p.skills.values[k] - 0.12)


## End of a season: a year older, plus age decline and a little random drift.
## Returns the per-skill change.
static func age_one_year(p: PlayerProfile, rng: RandomNumberGenerator) -> Dictionary:
	p.age += 1.0
	var delta := {}
	for k in p.skills.values:
		var d := rng.randfn(0.0, 0.6)
		if p.age > 29.0:
			var yrs := p.age - 29.0
			var rate := 0.8 if k in PHYSICAL else 0.35
			d -= rate * yrs * (1.6 if p.age > 33.0 else 1.0)
			# ceilings fall too, so lost speed doesn't fully come back
			p.potential[k] = maxf(1.0, p.potential[k] - rate * yrs * 0.7)
		p.skills.values[k] = clampf(p.skills.values[k] + d, 1.0, 100.0)
		delta[k] = d
	p.refresh_modifiers()
	return delta


## Fatigue: playing raises it, rest days lower it.
static func add_game_fatigue(p: PlayerProfile, toi_frac: float) -> void:
	p.fatigue = clampf(p.fatigue + 0.25 * toi_frac * p.skills.tire_rate(), 0.0, 1.0)


static func rest(p: PlayerProfile, days: int) -> void:
	p.fatigue = maxf(0.0, p.fatigue - 0.12 * days * lerpf(0.8, 1.3, p.skills.n("toughness")))
	p.refresh_modifiers()
