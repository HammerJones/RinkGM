extends Node
## Headless checks for the on-ice shootout: a tie goes to a shootout where
## one shooter at a time skates the puck in from centre ice against the other
## goalie, the sides alternate, and it ends with a winner by one goal. Then a
## restart puts the full lines back.
## Run: godot --headless --path . --fixed-fps 120 -- --test=shootout

var game: Node
var _fails := 0


func _ready() -> void:
	game.autoplay = true
	await get_tree().physics_frame
	await _run()
	print("shootout test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


func _run() -> void:
	var n: int = game.settings.skaters_on_ice
	await _frames(240)
	game.dev_set_score(0, 0)
	game.dev_set_score(1, 0)
	game.dev_end_game()
	_check(game.shootout and game.state == game.State.PLAY, "a tie goes to the shootout")
	var so: Shootout = game._so
	var attempts: Array = []  # [team, shooter, touched the puck]
	var lone := true
	var t := 0.0
	while game.state != game.State.OVER and t < 400.0:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if game.skaters.size() != 1:
			lone = false
		# attempt k runs while k attempts are done (and isn't showing its result)
		var k: int = so.taken[0] + so.taken[1]
		if so.phase != Shootout.Phase.RESULT and so.phase != Shootout.Phase.DONE and attempts.size() == k:
			attempts.append([so.team, so.shooter, false])
		if game.puck.controller == so.shooter and not attempts.is_empty():
			attempts[-1][2] = true
	_check(game.state == game.State.OVER, "the shootout ends (%.0f s)" % t)
	_check(lone, "one skater on the ice at a time")
	_check(so.is_done() and so.made[0] != so.made[1] or so.taken[0] >= Shootout.MAX_ROUNDS, "it has a winner (%d-%d)" % so.made)
	_check(absi(game.score[0] - game.score[1]) == 1, "the winner gets one goal (%s)" % str(game.score))
	_check(so.taken[0] >= 1 and absi(so.taken[0] - so.taken[1]) <= 1, "the sides alternate (%s)" % str(so.taken))
	var touched := attempts.filter(func(a): return a[2]).size()
	_check(touched * 2 >= attempts.size(), "shooters skate the puck in (%d of %d)" % [touched, attempts.size()])
	for a in attempts:
		_check(a[1].team == a[0], "each team shoots with its own player")
	print("  shootout %d-%d over %d attempts, %.0f s" % [so.made[0], so.made[1], attempts.size(), t])
	# a restart brings the lines back
	game.restart()
	await _frames(5)
	_check(game._so == null and not game.shootout, "restart clears the shootout")
	_check(game.team_skaters(0).size() == n and game.team_skaters(1).size() == n, "restart puts both lines back")


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
