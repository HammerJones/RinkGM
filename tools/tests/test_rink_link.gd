extends SceneTree
## Headless check of the career running alongside the owner's rink
## (RinkLink, RINK_SIM.md 6.1): the rink's clock owns the calendar, the
## user's Beer League D game is Tuesday 22:00, an evening of hockey costs
## the owner hours, rest follows the owner's fatigue, league dues gate the
## lineup, and the rink saves under the career's world.rink_sim key.
##
##   godot --headless --path . --script tools/tests/test_rink_link.gd

const PATH := "user://test_rink_link.json"

var failures := 0


func _init() -> void:
	var link := RinkLink.new_owner("Owner", "Test", "C", 11)
	var c := link.career
	var sim := link.sim
	_expect(c.follows_world and c.tier == 0, "an owner career plays Beer League D on the rink's clock")
	_expect(c.day == sim.day, "the career starts on the rink's day")
	_expect(c.save_path == Career.SLOTS.owner.path, "it saves to the owner slot")

	# three rounds, each on a Tuesday at 22:00
	var start_day := sim.day
	for r in 3:
		_expect(link.advance_to_game(), "round %d: the rink runs to game night" % r)
		_expect(sim.weekday() == RinkLink.GAME_WEEKDAY and sim.minute >= RinkLink.GAME_MINUTE, "round %d is on Tuesday night (%s)" % [r, sim.clock_text()])
		_expect(c.day == sim.day, "round %d: the career follows the rink's day (%d vs %d)" % [r, c.day, sim.day])
		var dressed: bool = not c.next_user_game().is_empty() and c.user().dressed()
		var games := sim.games.size()
		var gp: int = c.user().season_stats.gp
		link.play_round()
		if dressed:
			_expect(c.user().season_stats.gp == gp + 1, "round %d: the user's game counts" % r)
			_expect(sim.games.size() == games + 1, "round %d: the rink records the owner's evening" % r)
		_expect(not link.game_due(), "round %d: the next game isn't due yet" % r)
		_expect(posmod(sim.weekday() + c.game_day - sim.day, 7) == RinkLink.GAME_WEEKDAY, "round %d: the next game is on a Tuesday" % r)
	_expect(sim.day - start_day >= 14 and sim.day - start_day <= 21, "three weekly games take two to three weeks (%d days)" % (sim.day - start_day))
	_expect(sim.owner_pay_owed == 0.0 and sim.weekly_reports.size() >= 2, "the Community Ice Agreement's pay is banked each week")

	# an exhausted owner doesn't rest
	c.user().fatigue = 0.5
	sim.fatigue = 80.0
	link.advance(24 * 60)
	_expect(is_equal_approx(c.user().fatigue, 0.5), "a day ending at fatigue 80 doesn't count as rest")
	sim.fatigue = 0.0

	# rest: a day only counts when the owner isn't worn out
	var u := c.user()
	u.fatigue = 0.5
	c.pass_day(false)
	_expect(is_equal_approx(u.fatigue, 0.5), "an unrested day doesn't lower fatigue")
	c.pass_day(true)
	_expect(u.fatigue < 0.5, "a rested day does")
	c.day = sim.day

	# league dues: unpaid dues bench the owner
	sim.league.benched = true
	c.check_league_gate()
	_expect(u.benched, "unpaid dues bench the user")
	sim.league.benched = false
	c.check_league_gate()
	_expect(not u.benched, "paid dues put them back")

	# save and load: the rink comes back under world.rink_sim
	sim.money = 1234.5
	c.save_path = PATH
	_expect(c.save() == OK, "the career saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_expect(data.has("world") and data.world.has("rink_sim"), "the save has world.rink_sim")
	var c2 := Career.load_from(PATH)
	var link2 := RinkLink.resume(c2)
	_expect(link2 != null, "a loaded owner career resumes its rink")
	if link2:
		_expect(link2.sim.day == sim.day and link2.sim.minute == sim.minute, "the rink's clock is restored")
		_expect(is_equal_approx(link2.sim.money, 1234.5), "the owner's money is restored")
		_expect(c2.game_day == c.game_day and c2.day == c.day, "the career's calendar is restored")
		_expect(link2.career.league_gate.is_valid(), "the dues gate is wired again")
	_expect(RinkLink.resume(Career.new_career("A", "B", "C", 3)) == null, "a normal career has no rink")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	print("rink link: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
