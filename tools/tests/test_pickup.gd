extends SceneTree
## Pickup basketball in the gym (scripts/world/pickup): runs only in peak
## hours, a whole game to 11 plays out headless in simulated time with the
## ball never leaving the gym, a player who calls next swaps out an NPC, and
## playing emits `trained`.
##   godot --headless --path . --script res://tools/tests/test_pickup.gd

var failures := 0
var game: PickupGame
var body: Node3D
var ball_out := 0
var hits := {}
var scores: Array = []
var trained_calls: Array = []
var steps := 0
## The game's physics rate: a fast-forward keeps each step 1/120 s of game
## time (Engine.time_scale in Godot 4 stretches the step, so the tick rate
## goes up with it).
const HZ := 120
const FAST := 96


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(250.0, true, false, true).timeout.connect(func():
		printerr("FAIL: test_pickup timed out")
		quit(1))
	_check_schedule()
	await _check_game()
	print("  %d steps (%.1f game minutes) in %.1f s" % [steps, steps / float(HZ) / 60.0, Time.get_ticks_msec() / 1000.0])
	if failures:
		printerr("test_pickup: %d failure(s)" % failures)
	else:
		print("test_pickup: ok")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = HZ
	quit(1 if failures else 0)


func _check_schedule() -> void:
	var ok := true
	var weekend_more := 0
	for d in 56:
		var wd := d % 7
		var runs := PickupSchedule.sessions(7, d, wd)
		var w := PickupSchedule.window(wd)
		var last := -1
		for r: Dictionary in runs:
			var len := int(r.end) - int(r.start)
			if int(r.start) < w.x or int(r.end) > w.y or len < 30 or len > 90 or int(r.start) < last:
				ok = false
			last = int(r.end)
		if wd == 0 or wd == 6:
			weekend_more += runs.size()
		if str(runs) != str(PickupSchedule.sessions(7, d, wd)):
			ok = false
	_expect(ok, "runs are 30-90 min, in peak hours, never overlap, same every time for a seed and day")
	_expect(weekend_more >= 32, "weekend days get two or three runs")
	_expect(not PickupSchedule.in_peak(2, 7 * 60) and not PickupSchedule.in_peak(2, 22 * 60) and PickupSchedule.in_peak(2, 17 * 60)
		and PickupSchedule.in_peak(6, 11 * 60) and not PickupSchedule.in_peak(0, 21 * 60), "peak hours: weekday 15:30-21:00, weekend 10:00-20:00")


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _on_frame() -> void:
	steps += 1
	if game == null:
		return
	var b := game.ball().position
	if not PickupCourt.in_room(b, -0.05):
		if ball_out == 0:
			printerr("ball out at %s v=%s stage=%s holder=%d" % [str(b), str(game.ball().linear_velocity), game.stage, game.holder])
		ball_out += 1


## Runs the sim until `cond` holds or `seconds` of game time pass.
func _until(cond: Callable, seconds: float) -> bool:
	var n := roundi(seconds * HZ)
	for i in n:
		await physics_frame
		_drive_player()
		if OS.has_environment("PICKUP_DEBUG") and steps % 1200 == 0:
			print("t=%.0f stage=%s mode=%s score=%s holder=%d ball=%s v=%s q=%s" % [steps / float(HZ), game.stage, game.mode, str(game.score), game.holder, str(game.ball().position), str(game.ball().linear_velocity), str(game.queue)])
		if cond.call():
			return true
	return false


## A stand-in for the player: chase loose balls, shoot from wherever they
## catch it, a timing right in the band.
func _drive_player() -> void:
	if game.player_idx < 0 or body == null:
		return
	var me: PickupGame.Hooper = game.hoopers[game.player_idx]
	var to := Vector3.ZERO
	if game.player_has_ball():
		var end := game.attack_end(me.team)
		var rim := PickupCourt.rim(end)
		var aim := Vector3(rim.x, 1.6, rim.z) - body.position
		body.look_at(body.position + aim, Vector3.UP)
		if PickupCourt.dist_to_rim(end, body.position) < 5.5:
			game.player_shot(game.meter_band().x)
		else:
			to = Vector3(rim.x - body.position.x, 0, rim.z - body.position.z)
	elif game.holder < 0 and game.stage in ["loose", "inbound"]:
		var b := game.ball().position
		to = Vector3(b.x - body.position.x, 0, b.z - body.position.z)
	elif game.is_playing():
		var s := PickupCourt.spot(game.attack_end(me.team), 4.5, 2.5)
		to = Vector3(s.x - body.position.x, 0, s.z - body.position.z)
	if to.length() > 0.2:
		body.position += to.normalized() * minf(3.5 / HZ, to.length())


func _check_game() -> void:
	physics_frame.connect(_on_frame)
	var root3d := Node3D.new()
	root.add_child(root3d)
	var cast := Cast.load_region(1)
	# find a weekday with a run big enough for 3 on 3
	var sd := OS.get_environment("PICKUP_SEED").to_int() if OS.has_environment("PICKUP_SEED") else 3
	var day := -1
	var r := {}
	for d in 60:
		if d % 7 in [0, 6]:
			continue
		for x: Dictionary in PickupSchedule.sessions(sd, d, d % 7):
			if int(x.turnout) >= 6 and int(x.turnout) <= 8:  # with the player still 3 on 3
				day = d
				r = x
				break
		if day >= 0:
			break
	_expect(day >= 0, "some weekday has a 3 on 3 sized run")
	game = PickupGame.new()
	game.seed = sd
	game.cast = cast
	game.clock_day = day
	game.clock_weekday = day % 7
	game.clock_minute = 7.0 * 60.0
	root3d.add_child(game)
	body = Node3D.new()
	body.position = Vector3(-6.0, 0, -45.6)
	root3d.add_child(body)
	game.player_body = body
	game.ball().hit.connect(func(kind: String, _at: Vector3, _s: float): hits[kind] = int(hits.get(kind, 0)) + 1)
	game.swished.connect(func(_at: Vector3): hits["swish"] = int(hits.get("swish", 0)) + 1)
	game.bounced.connect(func(_at: Vector3, _s: float): hits["bounce"] = int(hits.get("bounce", 0)) + 1)
	game.squeaked.connect(func(_at: Vector3, _s: float): hits["squeak"] = int(hits.get("squeak", 0)) + 1)
	game.scored.connect(func(t: int, p: int, _sc: Array): scores.append([t, p]))
	game.trained.connect(func(k: Array, m: int, i: float): trained_calls.append([k, m, i]))
	await _ticks(60)
	_expect(not game.is_on() and game.hoopers.is_empty(), "nobody plays at 07:00")
	game.clock_minute = 23.0 * 60.0
	await _ticks(30)
	_expect(not game.is_on(), "nobody plays at 23:00")
	game.clock_minute = float(r.start) + 1.0
	await _ticks(10)
	_expect(game.is_on() and game.hoopers.size() == int(r.turnout), "the run starts in its slot with its turnout (%d)" % int(r.turnout))
	var real := true
	for h: PickupGame.Hooper in game.hoopers:
		if h.person == null or cast.person(h.person.id) != h.person or not (PickupGame.POOL.has(h.person.archetype) or h.person.interest("pickup", "play") > 0.0):
			real = false
		if h.age < PickupGame.AGES.x or h.age > PickupGame.AGES.y:
			real = false
	_expect(real, "the players are real Cast people of a rec-sports archetype and age")
	_expect(game.can_join() == "now", "while they shoot around the player can join the next game (%s)" % game.can_join())

	# fast-forward: many 1/120 s steps a frame
	Engine.max_physics_steps_per_frame = 4000
	Engine.physics_ticks_per_second = HZ * FAST
	Engine.time_scale = FAST
	var started := await _until(func() -> bool: return game.mode == "3v3" and game.stage == "live", 120.0)
	_expect(started, "a 3 on 3 starts once they're all in (%s, %s)" % [game.mode, game.stage])
	var t0 := steps
	var done := await _until(func() -> bool: return game.games_played >= 1, 1800.0)
	var mins := (steps - t0) / float(HZ) / 60.0
	_expect(done, "a whole game to 11 plays out (%.1f sim minutes, %d baskets)" % [mins, scores.size()])
	var pts := [0, 0]
	var ones := 0
	var twos := 0
	for s: Array in scores:
		pts[int(s[0])] += int(s[1])
		ones += 1 if int(s[1]) == 1 else 0
		twos += 1 if int(s[1]) == 2 else 0
	_expect(maxi(pts[0], pts[1]) >= PickupGame.TO and maxi(pts[0], pts[1]) <= PickupGame.TO + 1, "the winner got to 11 (%d-%d, %d ones, %d twos)" % [pts[0], pts[1], ones, twos])
	_expect(ones > 0, "baskets inside the arc count one")
	_expect(int(hits.get("rim", 0)) > 0 and int(hits.get("floor", 0)) > 0 and int(hits.get("bounce", 0)) > 0, "the ball rattles rims and bounces (%s)" % str(hits))
	_expect(int(hits.get("squeak", 0)) > 0, "sneakers squeak")
	_expect(ball_out == 0, "the ball stayed in the gym (%d frames out)" % ball_out)

	# the next game: the player calls next and takes someone's place
	await _until(func() -> bool: return game.stage == "live", 30.0)
	var on_before := _npcs_on_court()
	body.position = Vector3(-6.0, 0, -45.8)
	var how := game.can_join()
	_expect(how == "next", "mid-game with full sides it's join next (%s)" % how)
	game.join()
	_expect(game.player_idx >= 0 and game.queue.front() == game.player_idx, "the player is first in line")
	var g := game.games_played
	# no need to watch all of game two: it's next basket wins
	game.score = [PickupGame.TO - 1, PickupGame.TO - 1]
	var rotated := await _until(func() -> bool: return game.games_played > g and game.stage in ["check", "live", "pass", "inbound"], 1800.0)
	_expect(rotated, "game two finished and the next one is on")
	var on_after := _npcs_on_court()
	var sat := on_before.filter(func(i: int) -> bool: return not on_after.has(i))
	_expect(game.is_playing() and on_after.size() == on_before.size() - 1 and sat.size() >= 1,
		"the player is on and an NPC sat out for them (%d -> %d NPCs on)" % [on_before.size(), on_after.size()])

	# play a bit, then walk off: trained fires
	trained_calls.clear()
	await _until(func() -> bool: return false, 60.0)
	game.leave()
	_expect(trained_calls.size() == 1, "leaving reports the training once")
	if trained_calls.size() > 0:
		var tc: Array = trained_calls[0]
		var keys: Array = tc[0]
		_expect(keys == ["agility", "toughness", "shot_accuracy"], "trained names agility, toughness (stamina) and shot accuracy")
		for k in keys:
			_expect(k in Skills.SKATER_KEYS, "%s is a canonical Skills key" % k)
		_expect(int(tc[1]) >= 1 and float(tc[2]) > 0.0 and float(tc[2]) <= 1.0, "with minutes and an intensity (%d min, %.2f)" % [int(tc[1]), float(tc[2])])
	_expect(not game.is_playing() and _npcs_on_court().size() == on_before.size(), "someone from the line took the player's spot")
	_expect(ball_out == 0, "the ball stayed in the gym all along")

	# the run ends: everyone goes home, the ball goes back on the cart
	game.clock_minute = float(r.end) + 41.0
	var closed := await _until(func() -> bool: return not game.is_on(), 5.0)
	_expect(closed, "the run winds up after its end time")
	var gone := await _until(func() -> bool: return game.hoopers.is_empty(), 120.0)
	_expect(gone and game.ball().position.distance_to(PickupCourt.CART) < 0.01, "everyone left and the ball is back on the cart")
	game.queue_free()
	await _ticks(2)

	# a big turnout runs full court
	var big := {}
	var bday := -1
	for d in 90:
		for x: Dictionary in PickupSchedule.sessions(sd, d, d % 7):
			if int(x.turnout) >= 10:
				big = x
				bday = d
				break
		if bday >= 0:
			break
	game = PickupGame.new()
	game.seed = sd
	game.cast = cast
	game.clock_day = bday
	game.clock_weekday = bday % 7
	game.clock_minute = float(big.start) + 1.0
	root3d.add_child(game)
	scores.clear()
	game.scored.connect(func(t: int, p: int, _sc: Array): scores.append([t, p]))
	var full := await _until(func() -> bool: return game.mode == "5v5" and game.stage == "live", 150.0)
	_expect(full, "ten or more run 5 on 5 full court (%d came)" % int(big.get("turnout", 0)))
	var ends := {}
	await _until(func() -> bool:
		if game.holder >= 0:
			ends[game.attack_end(game.offense)] = true
		return ends.size() == 2 and scores.size() >= 2, 300.0)
	_expect(ends.size() == 2 and scores.size() >= 2, "both ends get used and baskets go in (%d)" % scores.size())
	_expect(ball_out == 0, "the ball stayed in the gym full court too")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = HZ
	physics_frame.disconnect(_on_frame)
	root3d.queue_free()
	await _ticks(2)


func _npcs_on_court() -> Array:
	var out: Array = []
	for t in 2:
		for i in game.teams[t]:
			if not game.hoopers[i].me:
				out.append(i)
	return out
