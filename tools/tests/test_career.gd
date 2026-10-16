extends SceneTree
## Headless career check: plays several seasons with quick sims, takes every
## tryout offered, and prints a season-by-season summary plus balance numbers.
## Fails (exit code 1) if an invariant breaks.
##
##   godot --headless --path . --script tools/tests/test_career.gd -- [--seasons=8] [--seed=7] [--pos=C]

var failures := 0


func _init() -> void:
	var seasons := 3
	var seed_ := 7
	var pos := "C"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = a.trim_prefix("--seasons=").to_int()
		elif a.begins_with("--seed="):
			seed_ = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--pos="):
			pos = a.trim_prefix("--pos=")
	_check_skill_curves()
	_run_career(seasons, seed_, pos)
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _check_skill_curves() -> void:
	# ratings reach the physics as SkaterStats, injury modifiers included
	var s := Skills.new()
	for k in Skills.SKATER_KEYS:
		s.values[k] = 100.0
	s.modifiers["speed"] = -30.0
	var st := s.to_stats()
	_expect(st.agility == 99 and st.speed == 70, "to_stats clamps to 1..99 and applies modifiers (%d, %d)" % [st.agility, st.speed])


func _run_career(seasons: int, seed_: int, pos: String) -> void:
	var c := Career.new_career("Sean", "Rookie", pos, seed_)
	var injuries := 0
	var games_missed := 0
	for n in seasons:
		var info := LeagueTiers.get_tier(c.tier)
		var gp := {}
		for day in c.season.rounds:
			for g in day:
				gp[g.home] = gp.get(g.home, 0) + 1
				gp[g.away] = gp.get(g.away, 0) + 1
		for tid in c.season.team_ids:
			_expect(gp.get(tid, 0) == int(info.games), "%s: team %d plays %d games (want %d)" % [info.name, tid, gp.get(tid, 0), info.games])
		var guard := 0
		while c.phase == Career.Phase.SEASON and guard < 200:
			guard += 1
			var u := c.user()
			var had_injury := u.injury != null and not u.injury.can_play()
			var game := c.next_user_game()
			var r := c.play_round()
			if had_injury and not game.is_empty():
				games_missed += 1
			for res in r.results:
				for e in res.injuries:
					if int(e.pid) == c.user_id:
						injuries += 1
		_expect(guard < 200, "season ends")
		var total := {"gf": 0, "ga": 0}
		for tid in c.season.standings:
			total.gf += c.season.standings[tid].gf
			total.ga += c.season.standings[tid].ga
		_expect(total.gf == total.ga, "standings goals balance")
		var u := c.user()
		var h: Dictionary = u.history[-1]
		var team_row: Dictionary = c.season.standings[u.team_id]
		var s: Dictionary = h.stats
		print("S%d %-17s %-18s age %d  ovr %4.1f  team %2d-%2d-%d  %2dGP %2dG %2dA %3d S %2d H %+d%s%s" % [
			c.season_number, LeagueTiers.get_tier(c.tier).name, c.user_team().name, int(u.age), u.overall(),
			team_row.w, team_row.l, team_row.otl, s.gp, s.g, s.a, s.shots, s.hits, s.pm,
			"  CHAMPS" if h.champion else "", "  injured" if u.injury else ""])
		var league_goals := 0
		var league_games := 0
		for tid in c.season.standings:
			league_goals += c.season.standings[tid].gf
			league_games += c.season.standings[tid].gp
		print("     league avg %.1f goals/game | invitations: %s" % [league_goals * 2.0 / maxf(league_games, 1), ", ".join(c.invitations.map(func(i): return "%s (%s)" % [c.teams[i.team].name, LeagueTiers.get_tier(i.tier).short]))])
		# take the best offer: highest tier first
		var offers := c.invitations.duplicate()
		offers.sort_custom(func(a, b): return a.tier > b.tier)
		for inv in offers:
			if c.phase != Career.Phase.OFFSEASON or not c.invitations.has(inv):
				continue
			var t := c.try_out(inv.team)
			print("     tryout %s: %s (%.1f vs cut %.1f)" % [c.teams[inv.team].name, "MADE IT" if t.made else "cut", t.score, t.cut])
			if t.made:
				break
		# save/load round trip mid-career
		var path := "user://career_test.json"
		_expect(c.save(path) == OK, "save")
		var c2 := Career.load_from(path)
		_expect(c2 != null, "load")
		if c2:
			_expect(is_equal_approx(c2.user().overall(), c.user().overall()) and c2.players.size() == c.players.size(), "round trip keeps players (%f vs %f, %d vs %d)" % [c2.user().overall(), c.user().overall(), c2.players.size(), c.players.size()])
			c = c2
		c.start_next_season()
	print("Career: %d injuries, %d games missed" % [injuries, games_missed])
	print("Last news:")
	for n in c.news.slice(-6):
		print("   ", n.text)
