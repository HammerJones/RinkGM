extends Node
## Headless checks for practice mode: one skater with a puck and the nets, no
## opponents, clock or stats; the puck resets, comes back after a goal, the
## goalie toggles, and a career player's learned moves apply.
## Run: godot --headless --path . --fixed-fps 120 -- --test=practice

var game: Node
var _fails := 0


func _ready() -> void:
	await get_tree().physics_frame
	await _run()
	print("practice test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _run() -> void:
	var h: Skater = game.human
	_check(game.practice and not game.career_mode, "practice mode, not a career game")
	_check(game.skaters.size() == 1 and game.goalies.is_empty(), "one skater, no goalie")
	_check(game.state == game.State.PLAY and not game.puck.frozen, "the puck is live straight away")
	var clock: float = game.clock
	await _wait(1.0)
	_check(game.clock == clock, "no clock")

	# reset puck
	game.puck.reset_at(Vector3(20, 0, 10))
	game.practice_reset_puck()
	var d := Vector2(game.puck.position.x - h.position.x, game.puck.position.z - h.position.z).length()
	_check(d < 2.0 and not game.puck.frozen, "Reset puck puts it in front of you (%.1f m)" % d)

	# a goal: banner, the puck comes back, nothing is counted
	h.place(Vector2(0, 0), Vector3(1, 0, 0))
	game.puck.reset_at(Vector3(Rink.GOAL_X - 1.0, 0.0, 0.0))
	game.puck.vel = Vector3(20, 0, 0)
	await _wait(0.4)
	_check(game.puck.in_net_side != 0 or game._practice_reset > 0.0, "the shot goes in")
	await _wait(1.5)
	d = Vector2(game.puck.position.x - h.position.x, game.puck.position.z - h.position.z).length()
	_check(d < 3.0, "the puck comes back after a goal (%.1f m away)" % d)
	_check(game.score == [0, 0] and game.box.lines.is_empty(), "no score or stats")

	# goalie toggle
	game.set_practice_goalie(true)
	_check(game.goalies.size() == 1 and game.goalies[0].side == 1, "goalie in the net you shoot at")
	await _wait(0.5)
	game.set_practice_goalie(false)
	await get_tree().process_frame
	_check(game.goalies.is_empty(), "goalie off")

	# without a career every move works; with one, only learned moves do
	_check(h.knows(&"lacrosse"), "no career: every move")
	var p := PlayerProfile.create(1, "C", 40.0, RandomNumberGenerator.new())
	game.user_profile = p
	h.apply_player(p)
	_check(h.knows(&"wrist_shot") and not h.knows(&"lacrosse"), "career player: learned moves only")
