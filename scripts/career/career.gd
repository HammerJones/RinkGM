class_name Career
extends RefCounted
## The single-player career: one skater, one position, climbing from the
## beginner beer league to minor-league pro. Owns every generated player and
## club, the current season, the calendar and the save file.
##
## Flow: new_career() -> [next_user_game() -> play it live or not ->
## play_round(result)] repeated until the season ends -> invitations ->
## try_out() any of them -> start_next_season().
##
## `day` is a calendar day count so the open-world rink sim can hang events
## (practices, jobs, rink time) on the same clock later.

const SAVE_PATH := "user://career.json"
## Save slots: the open career plus the two playtest demos.
const SLOTS := {
	"career": {"path": "user://career.json", "label": "Career", "desc": "Start at the bottom of the ladder and climb."},
	"demo_low": {"path": "user://demo_low.json", "label": "Demo: low tier", "desc": "A season in Beer League C, then a tryout for Senior AAA."},
	"demo_mid": {"path": "user://demo_mid.json", "label": "Demo: mid tier", "desc": "Jump straight into a Senior AAA season."},
	"owner": {"path": "user://owner_millbrook.json", "label": "Owner: Millbrook", "desc": "Run Millbrook Community Arena and play Beer League D on its late ice."},
}
## Demo careers: the tier each demo starts in, the tier its second season is
## played in, and how fast skills grow (so 12-14 games show real progress).
const DEMOS := {
	"demo_low": {"tier": 1, "next_tier": 3, "base": 41.0, "xp_scale": 1.3},
	"demo_mid": {"tier": 3, "next_tier": -1, "base": 54.0, "xp_scale": 1.3},
}
const VERSION := 1
const ROSTER := {"C": 4, "LW": 4, "RW": 4, "D": 6, "G": 2}
const USER_POSITIONS := ["C", "LW", "RW", "D"]

enum Phase { SEASON, OFFSEASON }

var rng := RandomNumberGenerator.new()
var day := 0
var season_number := 1
var tier := 0
var user_id := 0
var next_id := 1
var players := {}  # id -> PlayerProfile
var teams := {}  # id -> Team
var leagues := {}  # tier -> [team ids]
var season: Season
var settings := GameSettings.new()
var phase := Phase.SEASON
## Offseason tryout offers: [{"team": id, "tier": t}]
var invitations: Array = []
## News feed, oldest first: [{"day", "text"}]
var news: Array = []
## The DEMOS key for a playtest demo, or "" for a normal career.
var demo := ""
## Multiplier on every XP gain (demos grow faster).
var xp_scale := 1.0
## Where save() writes (set by the slot it was created or loaded from).
var save_path := SAVE_PATH
## (world hook) Whether the user may play their next game, set by the rink sim
## when one runs alongside the career (RinkSim.owner_can_play: the owner sits
## while Beer League dues are unpaid). Unset means always.
var league_gate: Callable
## (world hook) True while a rink sim owns the calendar (RINK_SIM.md 6.1):
## Career stops adding days itself and RinkLink calls pass_day() at each of
## the sim's midnights, so `day` always equals the sim's day.
var follows_world := false
## The day the user's team plays its next round, while `follows_world`.
var game_day := 0
## The open world's state under the save's `world` key (RINK_SIM.md 7.4):
## {"rink_sim": ...}. A value is either its saved dictionary or the live
## object (anything with to_dict()), which is saved as it stands.
var world := {}


# ------------------------------------------------------------ setup

static func new_career(first: String, last: String, position: String, seed_: int = 0) -> Career:
	var c := Career.new()
	if seed_ != 0:
		c.rng.seed = seed_
	else:
		c.rng.randomize()
	var u := PlayerProfile.create(c._new_id(), position, 22.0, c.rng)
	u.first_name = first
	u.last_name = last
	u.age = 19.0
	u.is_user = true
	for k in u.potential:
		u.potential[k] = c.rng.randf_range(80.0, 96.0)
	c.players[u.id] = u
	c.user_id = u.id
	c._ensure_league(0)
	var team: Team = c.teams[c.leagues[0][c.rng.randi() % c.leagues[0].size()]]
	c._join(u, team)
	c.season = Season.create(0, 1, c.leagues[0], c.rng)
	c._news("%s signs with the %s of the %s." % [u.full_name(), team.name, LeagueTiers.get_tier(0).name])
	return c


## A playtest demo: the user is a solid regular at the demo's tier, grows
## faster than in a career, and (for the low-tier demo) is guaranteed a
## Senior AAA tryout at the end of the season.
static func new_demo(slot: String, first: String, last: String, position: String, seed_: int = 0) -> Career:
	var cfg: Dictionary = DEMOS[slot]
	var c := Career.new()
	if seed_ != 0:
		c.rng.seed = seed_
	else:
		c.rng.randomize()
	c.demo = slot
	c.xp_scale = cfg.xp_scale
	c.save_path = SLOTS[slot].path
	var t: int = cfg.tier
	c.tier = t
	var u := PlayerProfile.create(c._new_id(), position, cfg.base, c.rng)
	u.first_name = first
	u.last_name = last
	u.age = 23.0
	u.is_user = true
	for k in u.potential:
		u.potential[k] = c.rng.randf_range(78.0, 92.0)
	c.players[u.id] = u
	c.user_id = u.id
	c._ensure_league(t)
	var team: Team = c.teams[c.leagues[t][c.rng.randi() % c.leagues[t].size()]]
	c._join(u, team)
	c.season = Season.create(t, 1, c.leagues[t], c.rng)
	c._news("DEMO: %s signs with the %s of the %s." % [u.full_name(), team.name, LeagueTiers.get_tier(t).name])
	return c


## A one-off game between two generated clubs of a tier (no career, the
## player can switch skaters). Same shape as next_user_game().
## `mirrored` gives the away club the home club's exact ratings, so only
## the AI settings differ (the tier AI check).
static func exhibition(t := 4, mirrored := false) -> Dictionary:
	var c := Career.new()
	c.rng.seed = randi()
	c._ensure_league(t)
	var ids: Array = c.leagues[t].duplicate()
	ids.shuffle()
	var home: Team = c.teams[ids[0]]
	var away: Team = c.teams[ids[1]]
	if mirrored:
		for i in mini(home.roster.size(), away.roster.size()):
			var src: PlayerProfile = c.players[home.roster[i]]
			var dst: PlayerProfile = c.players[away.roster[i]]
			dst.position = src.position
			dst.skills = Skills.from_dict(src.skills.to_dict())
			dst.moves = src.moves.duplicate()
	return {
		"game": {}, "home": home, "away": away, "user_home": true,
		"home_lineup": home.lineup(c.players), "away_lineup": away.lineup(c.players),
		"playoff": false, "settings": c.settings, "user_id": -1, "user_can_play": true, "tier": t,
	}


func user() -> PlayerProfile:
	return players[user_id]


func user_team() -> Team:
	return teams[user().team_id]


func _new_id() -> int:
	next_id += 1
	return next_id - 1


func _ensure_league(t: int) -> void:
	if leagues.has(t):
		return
	var info := LeagueTiers.get_tier(t)
	var clubs := Names.clubs(t)
	var ids: Array = []
	for i in int(info.teams):
		var club: Array = clubs[i % clubs.size()]
		var team := Team.new()
		team.id = _new_id()
		team.name = club[0]
		team.short = club[0].left(3).to_upper()
		team.primary = club[1]
		team.secondary = club[2]
		team.tier = t
		for pos in ROSTER:
			for n in ROSTER[pos]:
				var p := _generate_player(pos, t)
				team.roster.append(p.id)
				p.team_id = team.id
		teams[team.id] = team
		ids.append(team.id)
	leagues[t] = ids


func _generate_player(pos: String, t: int) -> PlayerProfile:
	var info := LeagueTiers.get_tier(t)
	var p := PlayerProfile.create(_new_id(), pos, info.avg + rng.randfn(0.0, info.spread), rng)
	p.first_name = Names.first(rng)
	p.last_name = Names.last(rng)
	# beer leagues skew older, pros skew younger
	p.age = rng.randf_range(24.0, 44.0) if t < 3 else rng.randf_range(19.0, 33.0)
	players[p.id] = p
	return p


## Puts a player on a team, bumping its weakest player in the same group.
func _join(p: PlayerProfile, team: Team) -> void:
	if p.team_id != -1 and teams.has(p.team_id):
		teams[p.team_id].roster.erase(p.id)
	var same: Array = team.roster.filter(func(id): return players[id].group() == p.group())
	if not same.is_empty():
		same.sort_custom(func(a, b): return players[a].overall() < players[b].overall())
		team.roster.erase(same[0])
		players.erase(same[0])
	team.roster.append(p.id)
	p.team_id = team.id


func _news(text: String) -> void:
	news.append({"day": day, "text": text})
	if news.size() > 200:
		news.pop_front()


# ------------------------------------------------------------ the season

## The user's team's game in the current round, or {} (bye, eliminated,
## offseason). Includes everything the engine needs to stage it.
func next_user_game() -> Dictionary:
	if phase != Phase.SEASON:
		return {}
	check_league_gate()
	var tid := user().team_id
	for g in season.games_in_round():
		if g.home == tid or g.away == tid:
			var home: Team = teams[g.home]
			var away: Team = teams[g.away]
			return {
				"game": g, "home": home, "away": away, "user_home": g.home == tid,
				"home_lineup": lineup_for(home), "away_lineup": lineup_for(away),
				"playoff": season.phase == Season.Phase.PLAYOFFS,
				"settings": settings, "user_id": user_id, "user_can_play": user().dressed(), "tier": tier,
			}
	return {}


## Team lineup that always dresses a healthy user, even if they're the
## weakest player on the roster (it's their career).
func lineup_for(team: Team) -> Dictionary:
	var u := user()
	var lu := team.lineup(players)
	if u.team_id != team.id or not u.dressed():
		return lu
	for l in lu.F + lu.D:
		if u in l:
			return lu
	var scratched_user: bool = lu.scratched.has(u)
	if not scratched_user:
		return lu
	# swap the user in for the weakest dressed player of the same group
	var lines: Array = lu.D if u.group() == "D" else lu.F
	var last_line: Array = lines[-1]
	var weakest := 0
	for i in last_line.size():
		if last_line[i] and last_line[i].overall() < last_line[weakest].overall():
			weakest = i
	lu.scratched.erase(u)
	lu.scratched.append(last_line[weakest])
	last_line[weakest] = u
	return lu


## Plays out the current round: the user's game uses `user_result` when it was
## played live, every other game is quick-simmed. Then the days until the
## next game pass (rest, practice, healing). Returns a summary.
func play_round(user_result: Dictionary = {}) -> Dictionary:
	var summary := {"results": [], "user_result": {}, "season_over": false}
	if phase != Phase.SEASON:
		return summary
	check_league_gate()
	var tid := user().team_id
	var playoff := season.phase == Season.Phase.PLAYOFFS
	var played_teams := {}
	for g in season.games_in_round():
		var res: Dictionary
		var users_game: bool = g.home == tid or g.away == tid
		if users_game and not user_result.is_empty():
			res = user_result
		else:
			res = QuickSim.simulate(g.home, g.away, lineup_for(teams[g.home]), lineup_for(teams[g.away]), settings, playoff, rng)
		apply_result(res)
		season.record(g, res)
		summary.results.append(res)
		played_teams[g.home] = true
		played_teams[g.away] = true
		if users_game:
			summary.user_result = res
			_news_for_user_game(g, res)
	_after_round(played_teams)
	season.advance()
	if season.phase == Season.Phase.DONE:
		end_season()
		summary.season_over = true
	return summary


## Benches or reinstates the user from `league_gate`, with a news line when
## that changes.
func check_league_gate() -> void:
	var u := user()
	var benched := league_gate.is_valid() and not bool(league_gate.call())
	if benched != u.benched:
		_news("You're out of the lineup until your league dues are paid." if benched else "Dues paid: you're back in the lineup.")
	u.benched = benched


## Adds a game result to every player's stats, XP, fatigue and health.
func apply_result(res: Dictionary) -> void:
	var glen := settings.game_length()
	for pid in res.box:
		var p: PlayerProfile = players.get(int(pid))
		if p == null:
			continue
		var line: Dictionary = res.box[pid]
		p.add_game_stats(line, res.playoff)
		_xp(p, Progression.game_xp(p, line, glen))
		Progression.add_game_fatigue(p, line.get("toi", 0.0) / glen * 3.0)
	for entry in res.injuries:
		var p: PlayerProfile = players.get(int(entry.pid))
		if p == null:
			continue
		p.add_injury(entry.injury)
		if p.is_user:
			_news("You suffered a %s and will miss %d game%s." % [entry.injury.describe().to_lower(), entry.injury.games_out, "" if entry.injury.games_out == 1 else "s"])


## The days between game days: injuries tick, missed games rust, practice
## and rest happen.
func _after_round(played_teams: Dictionary) -> void:
	var info := LeagueTiers.get_tier(tier)
	var days: int = int(info.days_between_games) if season.phase == Season.Phase.REGULAR else 2
	var practices := int(round(float(info.practices_per_week) * days / 7.0))
	for tid in season.team_ids:
		var team: Team = teams[tid]
		for pid in team.roster:
			var p: PlayerProfile = players[pid]
			if p.injury:
				if played_teams.has(tid) and not p.injury.can_play():
					Progression.apply_rust(p)
				p.injury.tick_game()
				if p.injury.is_healed():
					if p.is_user:
						_news("You're fully healed.")
					p.injury = null
				p.refresh_modifiers()
			if not (follows_world and p.is_user):  # the user rests a day at a time in pass_day()
				Progression.rest(p, days)
			for i in practices:
				_xp(p, Progression.practice_xp(p, 0.8))
	# the user also gets their own weekly stick-and-puck session
	var u := user()
	if u.can_play():
		for i in maxi(1, days / 7):
			_xp(u, Progression.practice_xp(u, 0.6))
	if follows_world:
		game_day = day + days
	else:
		day += days


## One day passes on the world's clock. `rested` is false when the day's work
## left the user too tired to recover (the rink owner's fatigue, RINK_SIM.md 2.1).
func pass_day(rested: bool) -> void:
	day += 1
	if rested:
		Progression.rest(user(), 1)


## Whether the current round is due: always, unless the world's clock hasn't
## reached the next game day yet.
func round_due() -> bool:
	return not follows_world or day >= game_day


func _xp(p: PlayerProfile, xp: Dictionary) -> void:
	if xp_scale != 1.0:
		for k in xp:
			xp[k] *= xp_scale
	Progression.apply_xp(p, xp)
	for m in MoveUnlocks.check(p):
		if p.is_user:
			_news("You learned the %s." % MoveUnlocks.LABELS[m].to_lower())


func _news_for_user_game(g: Dictionary, res: Dictionary) -> void:
	var tid := user().team_id
	var home: bool = g.home == tid
	var us: int = res.hg if home else res.ag
	var them: int = res.ag if home else res.hg
	var opp: Team = teams[g.away if home else g.home]
	var tag := " (OT)" if res.ot else (" (SO)" if res.so else "")
	var line: Dictionary = res.box.get(user_id, {})
	var me := ""
	if not line.is_empty():
		me = "  You: %dG %dA, %d shots, %d hits." % [line.g, line.a, line.shots, line.hits]
	_news("%s %d-%d vs %s%s.%s" % ["Won" if us > them else "Lost", us, them, opp.name, tag, me])


# ------------------------------------------------------------ end of season

func end_season() -> void:
	var u := user()
	var team := user_team()
	var row: Dictionary = season.standings[team.id]
	var champ: Team = teams[season.champion]
	u.history.append({
		"season": season_number, "tier": tier, "team": team.name, "age": int(u.age),
		"record": "%d-%d-%d" % [row.w, row.l, row.otl], "stats": u.season_stats.duplicate(),
		"playoffs": u.playoff_stats.duplicate(), "champion": champ.id == team.id, "overall": snappedf(u.overall(), 0.1),
	})
	_news("%s win the %s championship!" % [champ.name, LeagueTiers.get_tier(tier).name])
	var leader := scoring_leaders(1)
	if not leader.is_empty():
		var p: PlayerProfile = leader[0]
		_news("Scoring title: %s (%s), %d points." % [p.full_name(), teams[p.team_id].name, p.points()])
	invitations = compute_invitations()
	if demo != "":
		invitations = _demo_invitations()
	for inv in invitations:
		_news("Tryout invitation: %s (%s)." % [teams[inv.team].name, LeagueTiers.get_tier(inv.tier).name])
	if invitations.is_empty() and tier < LeagueTiers.count() - 1:
		_news("No tryout invitations this year. Keep working.")
	phase = Phase.OFFSEASON


func scoring_leaders(n: int) -> Array:
	var skaters: Array = []
	for tid in season.team_ids:
		for pid in teams[tid].roster:
			if not players[pid].is_goalie():
				skaters.append(players[pid])
	skaters.sort_custom(func(a, b): return a.points() > b.points() or (a.points() == b.points() and a.season_stats.g > b.season_stats.g))
	return skaters.slice(0, n)


## How scouts see the user: their rating plus how they produced this season
## relative to what's expected at this level.
func scouting_score() -> float:
	var u := user()
	var s := u.season_stats
	var gp: float = maxf(s.gp, 1.0)
	var expected := 0.45 if u.group() == "D" else 0.8
	var production: float = (s.g + s.a) / gp - expected
	var physical: float = s.hits / gp * 0.3 if u.group() == "D" else 0.0
	var bonus := clampf(production * 6.0 + physical, -6.0, 8.0)
	if season.champion == u.team_id:
		bonus += 2.0
	if s.gp < 4:
		bonus -= 3.0  # scouts barely saw them
	return u.overall() + bonus


## The low-tier demo always gets two looks from its next tier; a finished
## demo gets none.
func _demo_invitations() -> Array:
	var nt: int = DEMOS[demo].next_tier
	if nt < 0 or tier >= nt:
		_news("DEMO: that's the end of the demo seasons. Thanks for playtesting!")
		return []
	_ensure_league(nt)
	var ids: Array = leagues[nt].duplicate()
	ids.shuffle()
	return [{"team": ids[0], "tier": nt}, {"team": ids[1], "tier": nt}]


func is_demo_over() -> bool:
	return demo != "" and phase == Phase.OFFSEASON and invitations.is_empty() and (DEMOS[demo].next_tier < 0 or tier >= DEMOS[demo].next_tier)


## Teams one tier up (two for a standout) that want a look at the user.
func compute_invitations() -> Array:
	var out: Array = []
	var score := scouting_score()
	for t in [tier + 1, tier + 2]:
		if t >= LeagueTiers.count():
			break
		var cut: float = LeagueTiers.get_tier(t).tryout_cut
		var margin := score - cut + (3.0 if t == tier + 1 else -2.0)
		var chance := 1.0 / (1.0 + exp(-margin / 2.5))
		_ensure_league(t)
		for tid in leagues[t]:
			if rng.randf() < chance * 0.45 and out.size() < 3:
				out.append({"team": tid, "tier": t})
	return out


## Runs a tryout camp. Returns {"made", "score", "cut", "team"}; on success the
## user joins that team for next season and the other offers lapse.
func try_out(team_id: int) -> Dictionary:
	var inv: Array = invitations.filter(func(i): return i.team == team_id)
	if inv.is_empty():
		return {"made": false, "error": "no invitation"}
	invitations.erase(inv[0])
	var t: int = inv[0].tier
	var cut: float = LeagueTiers.get_tier(t).tryout_cut
	var eval := scouting_score() + rng.randfn(0.0, 3.0)
	var made := eval >= cut or demo != ""
	var team: Team = teams[team_id]
	if made:
		_join(user(), team)
		tier = t
		invitations.clear()
		_news("You made the %s! Welcome to the %s." % [team.name, LeagueTiers.get_tier(t).name])
	else:
		_news("Cut at the %s tryout camp." % team.name)
	return {"made": made, "score": eval, "cut": cut, "team": team_id}


## Ages everyone, turns over rosters and starts the next season.
func start_next_season() -> void:
	if phase != Phase.OFFSEASON:
		return
	invitations.clear()
	for t in leagues:
		for tid in leagues[t]:
			_offseason_team(teams[tid])
	_check_release()
	season_number += 1
	if follows_world:
		game_day = day + 120  # TODO(M4/M5): the summer is played (RINK_SIM.md open question 1)
	else:
		day += 120
	season = Season.create(tier, season_number, leagues[tier], rng)
	phase = Phase.SEASON
	_news("Season %d begins: %s with the %s." % [season_number, LeagueTiers.get_tier(tier).name, user_team().name])


func _offseason_team(team: Team) -> void:
	var info := LeagueTiers.get_tier(team.tier)
	for pid in team.roster.duplicate():
		var p: PlayerProfile = players[pid]
		Progression.age_one_year(p, rng)
		p.fatigue = 0.0
		if p.injury:
			p.injury.games_out -= 12
			if p.injury.games_out <= 0:
				p.injury = null
			p.refresh_modifiers()
		p.reset_season_stats()
		# AI players retire or wash out and get replaced
		if not p.is_user and (p.age > 40.0 or p.overall() < info.avg - info.spread * 2.5):
			team.roster.erase(pid)
			players.erase(pid)
			var fresh := _generate_player(p.position, team.tier)
			fresh.team_id = team.id
			team.roster.append(fresh.id)


## Skills that fall too far below the level get you released down a tier.
func _check_release() -> void:
	var u := user()
	var info := LeagueTiers.get_tier(tier)
	if tier == 0 or u.overall() >= info.avg - info.spread * 2.0:
		return
	var down := tier - 1
	_ensure_league(down)
	var team: Team = teams[leagues[down][rng.randi() % leagues[down].size()]]
	var old := user_team()
	_join(u, team)
	tier = down
	_news("Released by the %s. You catch on with the %s." % [old.name, team.name])


# ------------------------------------------------------------ dev menu
# Playtest levers for scripts/dev/. None of them save; the caller decides.

func dev_set_skill(key: String, value: float) -> void:
	var u := user()
	if u.skills.values.has(key):
		u.skills.values[key] = clampf(value, 1.0, 100.0)
		u.potential[key] = maxf(u.potential.get(key, 0.0), u.skills.values[key])
		MoveUnlocks.check(u)


func dev_unlock_all_moves() -> void:
	for m in MoveUnlocks.ORDER:
		user().unlock_move(m)


## Feeds `amount` XP into one skill (or all of them for "all") through the
## normal growth curve, so age and potential still apply.
func dev_add_xp(key: String, amount: float) -> Dictionary:
	var u := user()
	var xp := {}
	for k in u.skills.values:
		if key == "all" or k == key:
			xp[k] = amount
	var delta := Progression.apply_xp(u, xp)
	MoveUnlocks.check(u)
	return delta


## Injures the user now. `severity` is an Injury.Severity value.
func dev_injure(severity: int) -> Injury:
	var inj := Injury.create(rng, 3.0)
	inj.severity = clampi(severity, 0, Injury.GAMES_OUT.size() - 1)
	var r: Array = Injury.GAMES_OUT[inj.severity]
	inj.games_out = rng.randi_range(r[0], r[1])
	inj.games_total = inj.games_out
	inj.permanent = {}
	var u := user()
	u.injury = inj
	u.refresh_modifiers()
	return inj


func dev_heal() -> void:
	var u := user()
	u.injury = null
	u.fatigue = 0.0
	u.refresh_modifiers()


## Moves the user to a random club of tier `t` and starts a fresh season there.
func dev_set_tier(t: int) -> void:
	t = clampi(t, 0, LeagueTiers.count() - 1)
	_ensure_league(t)
	var team: Team = teams[leagues[t][rng.randi() % leagues[t].size()]]
	_join(user(), team)
	tier = t
	invitations.clear()
	user().reset_season_stats()
	season = Season.create(t, season_number, leagues[t], rng)
	phase = Phase.SEASON
	_news("DEV: moved to the %s (%s)." % [team.name, LeagueTiers.get_tier(t).name])


## Quick-sims every remaining game, the user's included, through the playoffs.
func dev_sim_rest_of_season() -> void:
	var guard := 0
	while phase == Phase.SEASON and guard < 500:
		play_round()
		guard += 1


## Sims rounds until the regular season is over (playoffs not started).
func dev_sim_regular_season() -> void:
	var guard := 0
	while phase == Phase.SEASON and season.phase == Season.Phase.REGULAR and guard < 500:
		play_round()
		guard += 1


## Finishes the season (simming what's left) and hands out invitations from
## clubs one tier up, ignoring scouting.
func dev_force_invitations() -> void:
	dev_sim_rest_of_season()
	var t := mini(tier + 1, LeagueTiers.count() - 1)
	_ensure_league(t)
	invitations = []
	for tid in leagues[t].slice(0, 3):
		invitations.append({"team": tid, "tier": t})


func dev_set_day(d: int) -> void:
	day = maxi(d, 0)


# ------------------------------------------------------------ save / load

func save(path := "") -> Error:
	if path == "":
		path = save_path
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "", false, true))
	return OK


static func load_from(path := SAVE_PATH) -> Career:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return null
	var c := from_dict(data)
	c.save_path = path
	return c


func to_dict() -> Dictionary:
	var ps := {}
	for id in players:
		ps[str(id)] = players[id].to_dict()
	var ts := {}
	for id in teams:
		ts[str(id)] = teams[id].to_dict()
	var ls := {}
	for t in leagues:
		ls[str(t)] = leagues[t]
	return {
		"version": VERSION, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "day": day,
		"season_number": season_number, "tier": tier, "user_id": user_id, "next_id": next_id,
		"players": ps, "teams": ts, "leagues": ls, "season": season.to_dict(),
		"settings": settings.to_dict(), "phase": phase, "invitations": invitations, "news": news,
		"demo": demo, "xp_scale": xp_scale, "follows_world": follows_world, "game_day": game_day,
		"world": _world_dict(),
	}


func _world_dict() -> Dictionary:
	var out := {}
	for k in world:
		out[k] = world[k].to_dict() if world[k] is Object else world[k]
	return out


static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	c.rng.seed = d.rng_seed.to_int()
	c.rng.state = d.rng_state.to_int()
	c.day = int(d.day)
	c.season_number = int(d.season_number)
	c.tier = int(d.tier)
	c.user_id = int(d.user_id)
	c.next_id = int(d.next_id)
	for k in d.players:
		c.players[int(k)] = PlayerProfile.from_dict(d.players[k])
	for k in d.teams:
		c.teams[int(k)] = Team.from_dict(d.teams[k])
	for k in d.leagues:
		c.leagues[int(k)] = d.leagues[k].map(func(x): return int(x))
	c.season = Season.from_dict(d.season)
	c.settings = GameSettings.from_dict(d.settings)
	c.phase = int(d.phase)
	c.invitations = d.invitations.map(func(i): return {"team": int(i.team), "tier": int(i.tier)})
	c.news = d.news
	c.demo = d.get("demo", "")
	c.xp_scale = float(d.get("xp_scale", 1.0))
	c.follows_world = bool(d.get("follows_world", false))
	c.game_day = int(d.get("game_day", 0))
	c.world = d.get("world", {})
	return c
